import { createFileRoute } from "@tanstack/react-router";
import { useState } from "react";
import { Button } from "@/components/ui/button";
import { Copy } from "lucide-react";
import { toast } from "sonner";

export const Route = createFileRoute("/developers")({
  head: () => ({
    meta: [
      { title: "Developer API — QuoteScribe" },
      { name: "description", content: "REST API and SDKs for managing clients, quotes, and invoices programmatically." },
    ],
  }),
  component: DevelopersPage,
});

function Code({ children, lang = "bash" }: { children: string; lang?: string }) {
  return (
    <div className="relative group">
      <pre className="rounded-md border border-hairline bg-muted/30 p-4 text-xs overflow-x-auto font-mono whitespace-pre">
        <code data-lang={lang}>{children}</code>
      </pre>
      <Button
        size="sm"
        variant="ghost"
        className="absolute right-2 top-2 opacity-0 group-hover:opacity-100"
        onClick={() => {
          navigator.clipboard.writeText(children);
          toast.success("Copied");
        }}
      >
        <Copy className="w-3.5 h-3.5" />
      </Button>
    </div>
  );
}

function Endpoint({ method, path, desc }: { method: string; path: string; desc: string }) {
  const color =
    method === "GET" ? "bg-emerald-500/15 text-emerald-600" :
    method === "POST" ? "bg-blue-500/15 text-blue-600" :
    method === "PATCH" ? "bg-amber-500/15 text-amber-600" :
    "bg-destructive/15 text-destructive";
  return (
    <div className="flex items-start gap-3 py-2 border-b border-hairline last:border-0">
      <span className={`text-[10px] uppercase tracking-wide px-1.5 py-0.5 rounded font-semibold ${color} min-w-[3rem] text-center`}>
        {method}
      </span>
      <div className="min-w-0">
        <code className="text-sm font-mono">{path}</code>
        <p className="text-xs text-muted-foreground mt-0.5">{desc}</p>
      </div>
    </div>
  );
}

function DevelopersPage() {
  const [tab, setTab] = useState<"curl" | "ts" | "python">("curl");
  const base = typeof window !== "undefined" ? window.location.origin : "https://your-app.example.com";

  return (
    <div className="mx-auto max-w-4xl px-6 py-16">
      <p className="text-[11px] uppercase tracking-[0.2em] text-muted-foreground">Developers</p>
      <h1 className="mt-2 text-4xl font-semibold tracking-tight">Public API</h1>
      <p className="mt-3 text-muted-foreground max-w-2xl">
        A REST API for managing clients, quotes, and invoices from your own systems.
        Every request is scoped to a single organization by its API key.
      </p>

      <section className="mt-12">
        <h2 className="text-xl font-semibold">Authentication</h2>
        <p className="mt-2 text-sm text-muted-foreground">
          Create a key in <a href="/settings/api" className="underline">Settings → API</a>. Pass it as a Bearer token on every request.
        </p>
        <div className="mt-4">
          <Code>{`Authorization: Bearer qsk_live_...`}</Code>
        </div>
      </section>

      <section className="mt-12">
        <h2 className="text-xl font-semibold">Endpoints</h2>
        <p className="mt-2 text-sm text-muted-foreground">Base URL: <code className="font-mono">{base}/api/public/v1</code></p>
        <div className="mt-4 rounded-md border border-hairline p-4">
          <Endpoint method="GET" path="/organization" desc="Read your organization profile and branding." />
          <Endpoint method="GET" path="/clients" desc="List clients. Supports ?limit and ?offset." />
          <Endpoint method="POST" path="/clients" desc="Create a client." />
          <Endpoint method="GET" path="/clients/{id}" desc="Read a client." />
          <Endpoint method="PATCH" path="/clients/{id}" desc="Update a client." />
          <Endpoint method="DELETE" path="/clients/{id}" desc="Delete a client." />
          <Endpoint method="GET" path="/documents" desc="List documents. Filter with ?type=quote or ?type=invoice." />
          <Endpoint method="POST" path="/documents" desc="Create a quote or invoice. Totals are computed server-side." />
          <Endpoint method="GET" path="/documents/{id}" desc="Read a document with its client." />
          <Endpoint method="PATCH" path="/documents/{id}" desc="Amend a document. Totals recomputed automatically." />
          <Endpoint method="DELETE" path="/documents/{id}" desc="Delete a document." />
          <Endpoint method="GET" path="/documents/{id}/verify" desc="Get a signed verification URL for a document." />
          <Endpoint method="GET" path="/documents/{id}/pdf" desc="Download the rendered PDF (application/pdf)." />
        </div>
      </section>

      <section className="mt-12">
        <h2 className="text-xl font-semibold">OpenAPI spec</h2>
        <p className="mt-2 text-sm text-muted-foreground">
          Import the spec into Postman, Insomnia, or any OpenAPI codegen tool.
        </p>
        <div className="mt-4 flex flex-wrap gap-2">
          <a
            href={`${base}/api/public/v1/openapi.json`}
            target="_blank"
            rel="noreferrer"
            className="text-sm underline"
          >
            openapi.json
          </a>
          <span className="text-muted-foreground text-sm">·</span>
          <a
            href={`https://petstore.swagger.io/?url=${encodeURIComponent(`${base}/api/public/v1/openapi.json`)}`}
            target="_blank"
            rel="noreferrer"
            className="text-sm underline"
          >
            Open in Swagger UI
          </a>
        </div>
      </section>

      <section className="mt-12">
        <div className="flex items-center justify-between">
          <h2 className="text-xl font-semibold">Quick start</h2>
          <div className="flex gap-1 border border-hairline rounded-md p-0.5">
            {(["curl", "ts", "python"] as const).map((t) => (
              <button
                key={t}
                onClick={() => setTab(t)}
                className={`px-3 py-1 text-xs rounded ${tab === t ? "bg-foreground text-background" : "text-muted-foreground"}`}
              >
                {t === "curl" ? "cURL" : t === "ts" ? "TypeScript" : "Python"}
              </button>
            ))}
          </div>
        </div>

        {tab === "curl" && (
          <div className="mt-4 space-y-4">
            <div>
              <h3 className="text-sm font-medium mb-2">List clients</h3>
              <Code>{`curl ${base}/api/public/v1/clients \\
  -H "Authorization: Bearer $QSK_API_KEY"`}</Code>
            </div>
            <div>
              <h3 className="text-sm font-medium mb-2">Create an invoice</h3>
              <Code>{`curl -X POST ${base}/api/public/v1/documents \\
  -H "Authorization: Bearer $QSK_API_KEY" \\
  -H "Content-Type: application/json" \\
  -d '{
    "client_id": "CLIENT_UUID",
    "doc_type": "invoice",
    "doc_number": "INV-2026-001",
    "issue_date": "2026-07-03",
    "due_date": "2026-08-03",
    "tax_rate": 15,
    "discount": 0,
    "line_items": [
      { "description": "Consulting", "quantity": 10, "unit_price": 150 }
    ]
  }'`}</Code>
            </div>
          </div>
        )}

        {tab === "ts" && (
          <div className="mt-4 space-y-4">
            <p className="text-sm text-muted-foreground">
              Install the TypeScript SDK from the <code className="font-mono">/sdk/typescript</code> directory in the source repo.
            </p>
            <Code lang="ts">{`import { QuoteScribeClient } from "@quotescribe/sdk";

const qs = new QuoteScribeClient({
  apiKey: process.env.QSK_API_KEY!,
  baseUrl: "${base}",
});

const { data: clients } = await qs.clients.list();

const { data: invoice } = await qs.documents.create({
  client_id: clients[0].id,
  doc_type: "invoice",
  doc_number: "INV-2026-001",
  issue_date: "2026-07-03",
  due_date: "2026-08-03",
  tax_rate: 15,
  discount: 0,
  line_items: [
    { description: "Consulting", quantity: 10, unit_price: 150 },
  ],
});

const { verify_url } = await qs.documents.verify(invoice.id);
console.log(verify_url);`}</Code>
          </div>
        )}

        {tab === "python" && (
          <div className="mt-4 space-y-4">
            <p className="text-sm text-muted-foreground">
              Install the Python SDK from the <code className="font-mono">/sdk/python</code> directory in the source repo.
            </p>
            <Code lang="python">{`from quotescribe import QuoteScribeClient

qs = QuoteScribeClient(
    api_key=os.environ["QSK_API_KEY"],
    base_url="${base}",
)

clients = qs.clients.list()["data"]

invoice = qs.documents.create({
    "client_id": clients[0]["id"],
    "doc_type": "invoice",
    "doc_number": "INV-2026-001",
    "issue_date": "2026-07-03",
    "due_date": "2026-08-03",
    "tax_rate": 15,
    "discount": 0,
    "line_items": [
        {"description": "Consulting", "quantity": 10, "unit_price": 150},
    ],
})["data"]

print(qs.documents.verify(invoice["id"])["verify_url"])`}</Code>
          </div>
        )}
      </section>

      <section className="mt-12">
        <h2 className="text-xl font-semibold">Errors</h2>
        <p className="mt-2 text-sm text-muted-foreground">
          Errors come back as JSON with an <code className="font-mono">error</code> object and an appropriate HTTP status code.
        </p>
        <div className="mt-4">
          <Code lang="json">{`{ "error": { "status": 401, "message": "Invalid API key" } }`}</Code>
        </div>
      </section>
    </div>
  );
}
