from unittest.mock import patch, MagicMock
import pytest
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

def test_api_key_header_added():
    """Test that API key is added to headers when set."""
    mock_response = MagicMock(status_code=200, json=lambda: {"data": []})
    mock_response.raise_for_status = MagicMock()
    with patch("src.tools.semantic_scholar.API_KEY", "test-key-123"):
        with patch("src.tools.semantic_scholar.requests.request",
                   return_value=mock_response) as mock_req:
            _request_with_retry("GET", "http://test.com")
    call_kwargs = mock_req.call_args[1]
    assert call_kwargs["headers"]["x-api-key"] == "test-key-123"
