import os
from unittest.mock import patch, MagicMock
import pytest
import src.tools.semantic_scholar as sem
from src.tools.semantic_scholar import _request_with_retry

def test_retry_on_429(capsys):
    """Test that 429 triggers retry with console output."""
    mock_responses = [
        MagicMock(status_code=429, raise_for_status=MagicMock(
            side_effect=__import__('requests').exceptions.HTTPError(
                response=MagicMock(status_code=429)))),
        MagicMock(status_code=200, json=lambda: {"data": []},
                  raise_for_status=MagicMock()),
    ]
    with patch("src.tools.semantic_scholar.requests.request",
               side_effect=mock_responses):
        with patch("src.tools.semantic_scholar.time.sleep"):
            r = _request_with_retry("GET", "http://test.com")
    assert r.status_code == 200
    captured = capsys.readouterr()
    assert "Rate limited (429)" in captured.err
    assert "retrying" in captured.err

def test_max_retries_exhausted():
    """Test that max retries raises after exhaustion."""
    mock_response = MagicMock(status_code=429)
    mock_response.raise_for_status.side_effect = (
        __import__('requests').exceptions.HTTPError(
            response=MagicMock(status_code=429)))
    with patch("src.tools.semantic_scholar.requests.request",
               return_value=mock_response):
        with patch("src.tools.semantic_scholar.time.sleep"):
            with pytest.raises(__import__('requests').exceptions.HTTPError):
                _request_with_retry("GET", "http://test.com")

def test_auth_header_sent_when_s2_api_key_set():
    """x-api-key header is included in every request when S2_API_KEY is set."""
    mock_resp = MagicMock(status_code=200, json=lambda: {"data": []},
                          raise_for_status=MagicMock())
    with patch.dict(os.environ, {"S2_API_KEY": "test-key-123"}):
        with patch("src.tools.semantic_scholar.requests.request",
                   return_value=mock_resp) as mock_req:
            with patch("src.tools.semantic_scholar.time.sleep"):
                sem.search("neural networks")
    headers_sent = mock_req.call_args[1].get("headers", {})
    assert headers_sent.get("x-api-key") == "test-key-123"

def test_no_auth_header_when_s2_api_key_absent():
    """No x-api-key header is sent when S2_API_KEY is not in the environment."""
    mock_resp = MagicMock(status_code=200, json=lambda: {"data": []},
                          raise_for_status=MagicMock())
    env_without_key = {k: v for k, v in os.environ.items() if k != "S2_API_KEY"}
    with patch.dict(os.environ, env_without_key, clear=True):
        with patch("src.tools.semantic_scholar.requests.request",
                   return_value=mock_resp) as mock_req:
            with patch("src.tools.semantic_scholar.time.sleep"):
                sem.search("neural networks")
    headers_sent = mock_req.call_args[1].get("headers", {})
    assert "x-api-key" not in headers_sent
