# @quotescribe/sdk

Official TypeScript SDK for the QuoteScribe public API.

## Install

```bash
npm install @quotescribe/sdk
```

## Usage

```ts
import { QuoteScribeClient } from "@quotescribe/sdk";

const qs = new QuoteScribeClient({
  apiKey: process.env.QSK_API_KEY!,
  baseUrl: "https://your-app.example.com",
});

const { data: clients } = await qs.clients.list();

const { data: invoice } = await qs.documents.create({
  client_id: clients[0].id,
  doc_type: "invoice",
  doc_number: "INV-2026-001",
  issue_date: "2026-07-03",
  due_date: "2026-08-03",
  tax_rate: 15,
  line_items: [{ description: "Consulting", quantity: 10, unit_price: 150 }],
});

const verify = await qs.documents.verify(invoice.id);
console.log(verify.verify_url);
```

## Resources

- `qs.clients` — list / get / create / update / delete
- `qs.documents` — list / get / create / update / delete / verify
- `qs.organization.get()`

Errors throw `QuoteScribeError` with `status` and `message`.

Generate an API key in the app under **Settings → API**.
