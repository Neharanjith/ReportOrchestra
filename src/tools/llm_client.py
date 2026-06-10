"""Unified LLM client. Dispatches by 'provider:model' prefix.

Supports:
- ollama: Local Ollama models (free)
- asksage: Claude models via AskSage's Anthropic-compatible API
"""
from __future__ import annotations
import yaml, requests, os, sys, time
from pathlib import Path
from functools import lru_cache

CONFIG_PATH = Path(__file__).resolve().parents[2] / "config" / "config.yaml"
PROMPTS_DIR = Path(__file__).resolve().parents[1] / "prompts"

@lru_cache(maxsize=1)
def load_config() -> dict:
    with open(CONFIG_PATH) as f:
        return yaml.safe_load(f)

def resolve_model(role: str) -> str:
    cfg = load_config()
    if role not in cfg["models"]:
        raise KeyError(f"Role '{role}' not in config.yaml")
    return cfg["models"][role]

def call_llm(role: str, system: str, user: str, *,
             anti_leakage: bool = False, temperature: float = 0.2,
             max_tokens: int = 4096) -> str:
    model_id = resolve_model(role)
    provider, model = model_id.split(":", 1)
    if anti_leakage:
        anti = PROMPTS_DIR / "00_anti_leakage.txt"
        if anti.exists():
            system = anti.read_text() + "\n\n" + system
    if provider == "ollama":
        return _call_ollama(model, system, user, temperature, max_tokens)
    if provider == "asksage":
        return _call_asksage(model, system, user, temperature, max_tokens)
    raise ValueError(f"Unknown provider: {provider}")

def _call_ollama(model, system, user, temperature, max_tokens):
    url = load_config()["ollama"]["base_url"] + "/api/chat"
    r = requests.post(url, json={
        "model": model,
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
        "stream": False,
        "options": {"temperature": temperature, "num_predict": max_tokens},
    }, timeout=600)
    r.raise_for_status()
    return r.json()["message"]["content"]

def _call_asksage(model, system, user, temperature, max_tokens):
    """Call Claude models via AskSage's Anthropic-compatible endpoint.

    AskSage provides an Anthropic Messages API compatible endpoint at:
    https://api.genai.army.mil/server/anthropic/v1/messages

    Authentication: Bearer token via ASKSAGE_API_KEY environment variable.
    Certificate: DoD cert bundle via ASKSAGE_CERT_PATH environment variable.
    
    Includes retry logic for transient server errors (502, 503, 504).
    """
    cfg = load_config()
    base_url = cfg.get("asksage", {}).get("base_url", 
                "https://api.genai.army.mil/server/anthropic")
    api_key = os.environ.get("ASKSAGE_API_KEY", "")
    cert_path = os.environ.get("ASKSAGE_CERT_PATH", "")

    if not api_key:
        raise ValueError("ASKSAGE_API_KEY environment variable not set")
    if not cert_path:
        raise ValueError("ASKSAGE_CERT_PATH environment variable not set "
                         "(path to DoD certificate bundle)")
    if not Path(cert_path).exists():
        raise ValueError(f"Certificate file not found: {cert_path}")

    url = f"{base_url}/v1/messages"
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }
    payload = {
        "model": model,
        "max_tokens": max_tokens,
        "temperature": temperature,
        "system": system,
        "messages": [{"role": "user", "content": user}],
    }
    
    # Retry logic for transient server errors
    max_retries = 3
    for attempt in range(max_retries):
        r = requests.post(url, headers=headers, json=payload, 
                          verify=cert_path, timeout=600)
        
        if r.status_code in (502, 503, 504):
            if attempt < max_retries - 1:
                wait_time = 2 ** (attempt + 1)
                print(f"  [asksage] Server error ({r.status_code}), "
                      f"retrying in {wait_time}s... "
                      f"(attempt {attempt + 1}/{max_retries})",
                      file=sys.stderr, flush=True)
                time.sleep(wait_time)
                continue
        
        r.raise_for_status()
        resp = r.json()
        content = resp.get("content", [])
        return "".join(block.get("text", "") for block in content 
                       if block.get("type") == "text")
    
    # If we exhausted retries, raise the last error
    r.raise_for_status()
