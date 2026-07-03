# quotescribe (Python SDK)

Official Python SDK for the QuoteScribe public API.

## Install

```bash
pip install quotescribe
```

## Usage

```python
import os
from quotescribe import QuoteScribeClient

qs = QuoteScribeClient(
    api_key=os.environ["QSK_API_KEY"],
    base_url="https://your-app.example.com",
)

clients = qs.clients.list()["data"]

invoice = qs.documents.create({
    "client_id": clients[0]["id"],
    "doc_type": "invoice",
    "doc_number": "INV-2026-001",
    "issue_date": "2026-07-03",
    "due_date": "2026-08-03",
    "tax_rate": 15,
    "line_items": [
        {"description": "Consulting", "quantity": 10, "unit_price": 150},
    ],
})["data"]

print(qs.documents.verify(invoice["id"])["verify_url"])
```

## Resources

- `qs.clients` — `list`, `get`, `create`, `update`, `delete`
- `qs.documents` — `list`, `get`, `create`, `update`, `delete`, `verify`
- `qs.organization.get()`

Failures raise `QuoteScribeError` with `status` and `message`.

Generate an API key in the app under **Settings → API**.
