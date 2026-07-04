"""QuoteScribe Python SDK.

Thin wrapper around the QuoteScribe REST API. Requires the `requests` library.

Usage:
    from quotescribe import QuoteScribeClient
    qs = QuoteScribeClient(api_key="qsk_live_...", base_url="https://your-app.example.com")
    clients = qs.clients.list()["data"]
"""

from __future__ import annotations

from typing import Any, Optional
import json

try:
    import requests  # type: ignore
except ImportError as e:  # pragma: no cover
    raise ImportError("The quotescribe SDK requires the `requests` package. Install it with `pip install requests`.") from e


class QuoteScribeError(Exception):
    def __init__(self, status: int, message: str):
        super().__init__(f"[{status}] {message}")
        self.status = status
        self.message = message


class _Resource:
    def __init__(self, client: "QuoteScribeClient"):
        self._c = client


class _Clients(_Resource):
    def list(self, limit: int = 50, offset: int = 0) -> dict:
        return self._c._request("GET", "/clients", params={"limit": limit, "offset": offset})

    def get(self, client_id: str) -> dict:
        return self._c._request("GET", f"/clients/{client_id}")

    def create(self, data: dict) -> dict:
        return self._c._request("POST", "/clients", json_body=data)

    def update(self, client_id: str, data: dict) -> dict:
        return self._c._request("PATCH", f"/clients/{client_id}", json_body=data)

    def delete(self, client_id: str) -> dict:
        return self._c._request("DELETE", f"/clients/{client_id}")


class _Documents(_Resource):
    def list(self, limit: int = 50, offset: int = 0, type: Optional[str] = None) -> dict:
        params: dict[str, Any] = {"limit": limit, "offset": offset}
        if type is not None:
            params["type"] = type
        return self._c._request("GET", "/documents", params=params)

    def get(self, document_id: str) -> dict:
        return self._c._request("GET", f"/documents/{document_id}")

    def create(self, data: dict) -> dict:
        return self._c._request("POST", "/documents", json_body=data)

    def update(self, document_id: str, data: dict) -> dict:
        return self._c._request("PATCH", f"/documents/{document_id}", json_body=data)

    def delete(self, document_id: str) -> dict:
        return self._c._request("DELETE", f"/documents/{document_id}")

    def verify(self, document_id: str) -> dict:
        return self._c._request("GET", f"/documents/{document_id}/verify")

    def pdf_url(self, document_id: str, disposition: Optional[str] = None) -> str:
        q = f"?disposition={disposition}" if disposition else ""
        return f"{self._c.base_url}/api/public/v1/documents/{document_id}/pdf{q}"

    def download_pdf(self, document_id: str, disposition: Optional[str] = None) -> bytes:
        """Fetch the rendered PDF bytes for a document."""
        url = self.pdf_url(document_id, disposition)
        headers = {"Authorization": f"Bearer {self._c.api_key}"}
        res = requests.get(url, headers=headers, timeout=self._c.timeout)
        if not res.ok:
            msg = res.reason or "Request failed"
            try:
                msg = (res.json().get("error") or {}).get("message") or msg
            except ValueError:
                pass
            raise QuoteScribeError(res.status_code, msg)
        return res.content


class _Organization(_Resource):
    def get(self) -> dict:
        return self._c._request("GET", "/organization")


class QuoteScribeClient:
    def __init__(self, api_key: str, base_url: str, timeout: int = 30):
        if not api_key:
            raise ValueError("api_key is required")
        if not base_url:
            raise ValueError("base_url is required")
        self.api_key = api_key
        self.base_url = base_url.rstrip("/")
        self.timeout = timeout
        self.clients = _Clients(self)
        self.documents = _Documents(self)
        self.organization = _Organization(self)

    def _request(self, method: str, path: str, params: Optional[dict] = None, json_body: Optional[dict] = None) -> dict:
        url = f"{self.base_url}/api/public/v1{path}"
        headers = {"Authorization": f"Bearer {self.api_key}"}
        if json_body is not None:
            headers["Content-Type"] = "application/json"
        res = requests.request(
            method,
            url,
            headers=headers,
            params=params,
            data=json.dumps(json_body) if json_body is not None else None,
            timeout=self.timeout,
        )
        try:
            payload = res.json() if res.text else {}
        except ValueError:
            payload = {}
        if not res.ok:
            msg = (payload.get("error") or {}).get("message") if isinstance(payload, dict) else None
            raise QuoteScribeError(res.status_code, msg or res.reason or "Request failed")
        return payload


__all__ = ["QuoteScribeClient", "QuoteScribeError"]
