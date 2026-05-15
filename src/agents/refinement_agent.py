"""Score-driven refinement loop."""
from __future__ import annotations
import json
from pathlib import Path
from src.tools.llm_client import call_llm

PROMPTS = Path(__file__).parent.parent / "prompts"

AXES = ["objective_clarity", "technical_progress_evidence",
        "data_and_metrics_rigor", "transitions_concreteness",
        "citation_grounding", "writing_clarity"]

def review(latex_src: str) -> dict:
    system = (PROMPTS / "07_reviewer.txt").read_text()
    text = call_llm("refinement_reviewer", system, latex_src,
                    temperature=0.0, max_tokens=2000)
    return _strip_and_load(text)

def revise(latex_src: str, review_json: dict) -> str:
    template = (PROMPTS / "07_revisor.txt").read_text()
    user = template.format(
        review_json=json.dumps(review_json, indent=2),
        latex_source=latex_src)
    return call_llm("refinement_revisor",
                    "You revise a LaTeX document.",
                    user, temperature=0.2, max_tokens=16000)

def loop(latex_src: str, max_iter: int = 3,
         log_path="work/07_refined/scores.json") -> tuple:
    history = []
    cur = latex_src
    cur_review = review(cur)
    history.append({"iter": 0, "review": cur_review})
    for i in range(1, max_iter + 1):
        candidate = revise(cur, cur_review)
        cand_review = review(candidate)
        accept = _accept(cur_review, cand_review)
        history.append({"iter": i, "accepted": accept,
                        "review": cand_review})
        if not accept:
            break
        cur, cur_review = candidate, cand_review
        if cur_review.get("overall", {}).get("score", 0) >= 5:
            break
    Path(log_path).parent.mkdir(parents=True, exist_ok=True)
    Path(log_path).write_text(json.dumps(history, indent=2))
    return cur, history

def _accept(old: dict, new: dict) -> bool:
    o = old.get("overall", {}).get("score", 0)
    n = new.get("overall", {}).get("score", 0)
    if n > o: return True
    if n < o: return False
    for ax in AXES:
        if new.get(ax, {}).get("score", 0) < old.get(ax, {}).get("score", 0):
            return False
    return True

def _strip_and_load(text: str) -> dict:
    text = text.strip()
    if text.startswith("```"):
        text = text.split("\n", 1)[1]
        if text.endswith("```"):
            text = text[:-3]
    return json.loads(text.strip())
