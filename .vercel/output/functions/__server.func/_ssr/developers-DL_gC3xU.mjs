import { r as reactExports, j as jsxRuntimeExports } from "../_libs/react.mjs";
import { B as Button } from "./router-BDMLDL80.mjs";
import { t as toast } from "../_libs/sonner.mjs";
import "./index.mjs";
import "../_libs/seroval.mjs";
import "../_libs/qrcode.mjs";
import { e as Copy } from "../_libs/lucide-react.mjs";
import "../_libs/tanstack__react-router.mjs";
import "../_libs/tanstack__router-core.mjs";
import "../_libs/tanstack__history.mjs";
import "../_libs/cookie-es.mjs";
import "../_libs/seroval-plugins.mjs";
import "node:stream/web";
import "node:stream";
import "../_libs/react-dom.mjs";
import "async_hooks";
import "util";
import "crypto";
import "stream";
import "../_libs/isbot.mjs";
import "../_libs/tanstack__query-core.mjs";
import "../_libs/tanstack__react-query.mjs";
import "./client-U3FzjMwq.mjs";
import "../_libs/supabase__supabase-js.mjs";
import "../_libs/supabase__postgrest-js.mjs";
import "../_libs/supabase__realtime-js.mjs";
import "../_libs/supabase__phoenix.mjs";
import "../_libs/supabase__storage-js.mjs";
import "../_libs/iceberg-js.mjs";
import "../_libs/supabase__auth-js.mjs";
import "tslib";
import "../_libs/supabase__functions-js.mjs";
import "../_libs/radix-ui__react-slot.mjs";
import "../_libs/radix-ui__react-compose-refs.mjs";
import "../_libs/class-variance-authority.mjs";
import "../_libs/clsx.mjs";
import "../_libs/tailwind-merge.mjs";
import "../_libs/radix-ui__react-label.mjs";
import "../_libs/radix-ui__react-primitive.mjs";
import "../_libs/radix-ui__react-dialog.mjs";
import "../_libs/radix-ui__primitive.mjs";
import "../_libs/radix-ui__react-context.mjs";
import "../_libs/radix-ui__react-id.mjs";
import "../_libs/@radix-ui/react-use-layout-effect+[...].mjs";
import "../_libs/@radix-ui/react-use-controllable-state+[...].mjs";
import "../_libs/@radix-ui/react-dismissable-layer+[...].mjs";
import "../_libs/@radix-ui/react-use-callback-ref+[...].mjs";
import "../_libs/@radix-ui/react-use-escape-keydown+[...].mjs";
import "../_libs/radix-ui__react-focus-scope.mjs";
import "../_libs/radix-ui__react-portal.mjs";
import "../_libs/radix-ui__react-presence.mjs";
import "../_libs/radix-ui__react-focus-guards.mjs";
import "../_libs/react-remove-scroll.mjs";
import "../_libs/react-remove-scroll-bar.mjs";
import "../_libs/react-style-singleton.mjs";
import "../_libs/get-nonce.mjs";
import "../_libs/use-sidecar.mjs";
import "../_libs/use-callback-ref.mjs";
import "../_libs/aria-hidden.mjs";
import "./auth-middleware-DJP7Badx.mjs";
import "./createMiddleware-BvN2ghIY.mjs";
import "./client.server-BMj2q4-x.mjs";
import "./calc-BF6zAv6d.mjs";
import "./docTypes-CsATll0j.mjs";
import "../_libs/zod.mjs";
import "./verifySign.server-CnraXCan.mjs";
import "node:async_hooks";
import "../_libs/h3-v2.mjs";
import "../_libs/rou3.mjs";
import "../_libs/srvx.mjs";
import "../_libs/dijkstrajs.mjs";
import "fs";
import "../_libs/pngjs.mjs";
import "zlib";
import "assert";
import "buffer";
function Code({
  children,
  lang = "bash"
}) {
  return /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "relative group", children: [
    /* @__PURE__ */ jsxRuntimeExports.jsx("pre", { className: "rounded-md border border-hairline bg-muted/30 p-4 text-xs overflow-x-auto font-mono whitespace-pre", children: /* @__PURE__ */ jsxRuntimeExports.jsx("code", { "data-lang": lang, children }) }),
    /* @__PURE__ */ jsxRuntimeExports.jsx(Button, { size: "sm", variant: "ghost", className: "absolute right-2 top-2 opacity-0 group-hover:opacity-100", onClick: () => {
      navigator.clipboard.writeText(children);
      toast.success("Copied");
    }, children: /* @__PURE__ */ jsxRuntimeExports.jsx(Copy, { className: "w-3.5 h-3.5" }) })
  ] });
}
function Endpoint({
  method,
  path,
  desc
}) {
  const color = method === "GET" ? "bg-emerald-500/15 text-emerald-600" : method === "POST" ? "bg-blue-500/15 text-blue-600" : method === "PATCH" ? "bg-amber-500/15 text-amber-600" : "bg-destructive/15 text-destructive";
  return /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "flex items-start gap-3 py-2 border-b border-hairline last:border-0", children: [
    /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: `text-[10px] uppercase tracking-wide px-1.5 py-0.5 rounded font-semibold ${color} min-w-[3rem] text-center`, children: method }),
    /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "min-w-0", children: [
      /* @__PURE__ */ jsxRuntimeExports.jsx("code", { className: "text-sm font-mono", children: path }),
      /* @__PURE__ */ jsxRuntimeExports.jsx("p", { className: "text-xs text-muted-foreground mt-0.5", children: desc })
    ] })
  ] });
}
function DevelopersPage() {
  const [tab, setTab] = reactExports.useState("curl");
  const base = typeof window !== "undefined" ? window.location.origin : "https://your-app.example.com";
  return /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "mx-auto max-w-4xl px-6 py-16", children: [
    /* @__PURE__ */ jsxRuntimeExports.jsx("p", { className: "text-[11px] uppercase tracking-[0.2em] text-muted-foreground", children: "Developers" }),
    /* @__PURE__ */ jsxRuntimeExports.jsx("h1", { className: "mt-2 text-4xl font-semibold tracking-tight", children: "Public API" }),
    /* @__PURE__ */ jsxRuntimeExports.jsx("p", { className: "mt-3 text-muted-foreground max-w-2xl", children: "A REST API for managing clients, quotes, and invoices from your own systems. Every request is scoped to a single organization by its API key." }),
    /* @__PURE__ */ jsxRuntimeExports.jsxs("section", { className: "mt-12", children: [
      /* @__PURE__ */ jsxRuntimeExports.jsx("h2", { className: "text-xl font-semibold", children: "Authentication" }),
      /* @__PURE__ */ jsxRuntimeExports.jsxs("p", { className: "mt-2 text-sm text-muted-foreground", children: [
        "Create a key in ",
        /* @__PURE__ */ jsxRuntimeExports.jsx("a", { href: "/settings/api", className: "underline", children: "Settings → API" }),
        ". Pass it as a Bearer token on every request."
      ] }),
      /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "mt-4", children: /* @__PURE__ */ jsxRuntimeExports.jsx(Code, { children: `Authorization: Bearer qsk_live_...` }) })
    ] }),
    /* @__PURE__ */ jsxRuntimeExports.jsxs("section", { className: "mt-12", children: [
      /* @__PURE__ */ jsxRuntimeExports.jsx("h2", { className: "text-xl font-semibold", children: "Endpoints" }),
      /* @__PURE__ */ jsxRuntimeExports.jsxs("p", { className: "mt-2 text-sm text-muted-foreground", children: [
        "Base URL: ",
        /* @__PURE__ */ jsxRuntimeExports.jsxs("code", { className: "font-mono", children: [
          base,
          "/api/public/v1"
        ] })
      ] }),
      /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "mt-4 rounded-md border border-hairline p-4", children: [
        /* @__PURE__ */ jsxRuntimeExports.jsx(Endpoint, { method: "GET", path: "/organization", desc: "Read your organization profile and branding." }),
        /* @__PURE__ */ jsxRuntimeExports.jsx(Endpoint, { method: "GET", path: "/clients", desc: "List clients. Supports ?limit and ?offset." }),
        /* @__PURE__ */ jsxRuntimeExports.jsx(Endpoint, { method: "POST", path: "/clients", desc: "Create a client." }),
        /* @__PURE__ */ jsxRuntimeExports.jsx(Endpoint, { method: "GET", path: "/clients/{id}", desc: "Read a client." }),
        /* @__PURE__ */ jsxRuntimeExports.jsx(Endpoint, { method: "PATCH", path: "/clients/{id}", desc: "Update a client." }),
        /* @__PURE__ */ jsxRuntimeExports.jsx(Endpoint, { method: "DELETE", path: "/clients/{id}", desc: "Delete a client." }),
        /* @__PURE__ */ jsxRuntimeExports.jsx(Endpoint, { method: "GET", path: "/documents", desc: "List documents. Filter with ?type=quote or ?type=invoice." }),
        /* @__PURE__ */ jsxRuntimeExports.jsx(Endpoint, { method: "POST", path: "/documents", desc: "Create a quote or invoice. Totals are computed server-side." }),
        /* @__PURE__ */ jsxRuntimeExports.jsx(Endpoint, { method: "GET", path: "/documents/{id}", desc: "Read a document with its client." }),
        /* @__PURE__ */ jsxRuntimeExports.jsx(Endpoint, { method: "PATCH", path: "/documents/{id}", desc: "Amend a document. Totals recomputed automatically." }),
        /* @__PURE__ */ jsxRuntimeExports.jsx(Endpoint, { method: "DELETE", path: "/documents/{id}", desc: "Delete a document." }),
        /* @__PURE__ */ jsxRuntimeExports.jsx(Endpoint, { method: "GET", path: "/documents/{id}/verify", desc: "Get a signed verification URL for a document." }),
        /* @__PURE__ */ jsxRuntimeExports.jsx(Endpoint, { method: "GET", path: "/documents/{id}/pdf", desc: "Download the rendered PDF (application/pdf)." })
      ] })
    ] }),
    /* @__PURE__ */ jsxRuntimeExports.jsxs("section", { className: "mt-12", children: [
      /* @__PURE__ */ jsxRuntimeExports.jsx("h2", { className: "text-xl font-semibold", children: "OpenAPI spec" }),
      /* @__PURE__ */ jsxRuntimeExports.jsx("p", { className: "mt-2 text-sm text-muted-foreground", children: "Import the spec into Postman, Insomnia, or any OpenAPI codegen tool." }),
      /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "mt-4 flex flex-wrap gap-2", children: [
        /* @__PURE__ */ jsxRuntimeExports.jsx("a", { href: `${base}/api/public/v1/openapi.json`, target: "_blank", rel: "noreferrer", className: "text-sm underline", children: "openapi.json" }),
        /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: "text-muted-foreground text-sm", children: "·" }),
        /* @__PURE__ */ jsxRuntimeExports.jsx("a", { href: `https://petstore.swagger.io/?url=${encodeURIComponent(`${base}/api/public/v1/openapi.json`)}`, target: "_blank", rel: "noreferrer", className: "text-sm underline", children: "Open in Swagger UI" })
      ] })
    ] }),
    /* @__PURE__ */ jsxRuntimeExports.jsxs("section", { className: "mt-12", children: [
      /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "flex items-center justify-between", children: [
        /* @__PURE__ */ jsxRuntimeExports.jsx("h2", { className: "text-xl font-semibold", children: "Quick start" }),
        /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "flex gap-1 border border-hairline rounded-md p-0.5", children: ["curl", "ts", "python"].map((t) => /* @__PURE__ */ jsxRuntimeExports.jsx("button", { onClick: () => setTab(t), className: `px-3 py-1 text-xs rounded ${tab === t ? "bg-foreground text-background" : "text-muted-foreground"}`, children: t === "curl" ? "cURL" : t === "ts" ? "TypeScript" : "Python" }, t)) })
      ] }),
      tab === "curl" && /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "mt-4 space-y-4", children: [
        /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { children: [
          /* @__PURE__ */ jsxRuntimeExports.jsx("h3", { className: "text-sm font-medium mb-2", children: "List clients" }),
          /* @__PURE__ */ jsxRuntimeExports.jsx(Code, { children: `curl ${base}/api/public/v1/clients \\
  -H "Authorization: Bearer $QSK_API_KEY"` })
        ] }),
        /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { children: [
          /* @__PURE__ */ jsxRuntimeExports.jsx("h3", { className: "text-sm font-medium mb-2", children: "Create an invoice" }),
          /* @__PURE__ */ jsxRuntimeExports.jsx(Code, { children: `curl -X POST ${base}/api/public/v1/documents \\
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
  }'` })
        ] })
      ] }),
      tab === "ts" && /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "mt-4 space-y-4", children: [
        /* @__PURE__ */ jsxRuntimeExports.jsxs("p", { className: "text-sm text-muted-foreground", children: [
          "Install the TypeScript SDK from the ",
          /* @__PURE__ */ jsxRuntimeExports.jsx("code", { className: "font-mono", children: "/sdk/typescript" }),
          " directory in the source repo."
        ] }),
        /* @__PURE__ */ jsxRuntimeExports.jsx(Code, { lang: "ts", children: `import { QuoteScribeClient } from "@quotescribe/sdk";

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
console.log(verify_url);` })
      ] }),
      tab === "python" && /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "mt-4 space-y-4", children: [
        /* @__PURE__ */ jsxRuntimeExports.jsxs("p", { className: "text-sm text-muted-foreground", children: [
          "Install the Python SDK from the ",
          /* @__PURE__ */ jsxRuntimeExports.jsx("code", { className: "font-mono", children: "/sdk/python" }),
          " directory in the source repo."
        ] }),
        /* @__PURE__ */ jsxRuntimeExports.jsx(Code, { lang: "python", children: `from quotescribe import QuoteScribeClient

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

print(qs.documents.verify(invoice["id"])["verify_url"])` })
      ] })
    ] }),
    /* @__PURE__ */ jsxRuntimeExports.jsxs("section", { className: "mt-12", children: [
      /* @__PURE__ */ jsxRuntimeExports.jsx("h2", { className: "text-xl font-semibold", children: "Errors" }),
      /* @__PURE__ */ jsxRuntimeExports.jsxs("p", { className: "mt-2 text-sm text-muted-foreground", children: [
        "Errors come back as JSON with an ",
        /* @__PURE__ */ jsxRuntimeExports.jsx("code", { className: "font-mono", children: "error" }),
        " object and an appropriate HTTP status code."
      ] }),
      /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "mt-4", children: /* @__PURE__ */ jsxRuntimeExports.jsx(Code, { lang: "json", children: `{ "error": { "status": 401, "message": "Invalid API key" } }` }) })
    ] })
  ] });
}
export {
  DevelopersPage as component
};
