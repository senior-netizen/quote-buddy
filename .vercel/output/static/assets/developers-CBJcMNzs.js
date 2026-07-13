import{r,j as e,B as c,t as d}from"./index-DrPnbl9j.js";import{C as l}from"./copy-DdT8QLBM.js";function a({children:s,lang:o="bash"}){return e.jsxs("div",{className:"relative group",children:[e.jsx("pre",{className:"rounded-md border border-hairline bg-muted/30 p-4 text-xs overflow-x-auto font-mono whitespace-pre",children:e.jsx("code",{"data-lang":o,children:s})}),e.jsx(c,{size:"sm",variant:"ghost",className:"absolute right-2 top-2 opacity-0 group-hover:opacity-100",onClick:()=>{navigator.clipboard.writeText(s),d.success("Copied")},children:e.jsx(l,{className:"w-3.5 h-3.5"})})]})}function t({method:s,path:o,desc:i}){const n=s==="GET"?"bg-emerald-500/15 text-emerald-600":s==="POST"?"bg-blue-500/15 text-blue-600":s==="PATCH"?"bg-amber-500/15 text-amber-600":"bg-destructive/15 text-destructive";return e.jsxs("div",{className:"flex items-start gap-3 py-2 border-b border-hairline last:border-0",children:[e.jsx("span",{className:`text-[10px] uppercase tracking-wide px-1.5 py-0.5 rounded font-semibold ${n} min-w-[3rem] text-center`,children:s}),e.jsxs("div",{className:"min-w-0",children:[e.jsx("code",{className:"text-sm font-mono",children:o}),e.jsx("p",{className:"text-xs text-muted-foreground mt-0.5",children:i})]})]})}function x(){const[s,o]=r.useState("curl"),i=typeof window<"u"?window.location.origin:"https://your-app.example.com";return e.jsxs("div",{className:"mx-auto max-w-4xl px-6 py-16",children:[e.jsx("p",{className:"text-[11px] uppercase tracking-[0.2em] text-muted-foreground",children:"Developers"}),e.jsx("h1",{className:"mt-2 text-4xl font-semibold tracking-tight",children:"Public API"}),e.jsx("p",{className:"mt-3 text-muted-foreground max-w-2xl",children:"A REST API for managing clients, quotes, and invoices from your own systems. Every request is scoped to a single organization by its API key."}),e.jsxs("section",{className:"mt-12",children:[e.jsx("h2",{className:"text-xl font-semibold",children:"Authentication"}),e.jsxs("p",{className:"mt-2 text-sm text-muted-foreground",children:["Create a key in ",e.jsx("a",{href:"/settings/api",className:"underline",children:"Settings → API"}),". Pass it as a Bearer token on every request."]}),e.jsx("div",{className:"mt-4",children:e.jsx(a,{children:"Authorization: Bearer qsk_live_..."})})]}),e.jsxs("section",{className:"mt-12",children:[e.jsx("h2",{className:"text-xl font-semibold",children:"Endpoints"}),e.jsxs("p",{className:"mt-2 text-sm text-muted-foreground",children:["Base URL: ",e.jsxs("code",{className:"font-mono",children:[i,"/api/public/v1"]})]}),e.jsxs("div",{className:"mt-4 rounded-md border border-hairline p-4",children:[e.jsx(t,{method:"GET",path:"/organization",desc:"Read your organization profile and branding."}),e.jsx(t,{method:"GET",path:"/clients",desc:"List clients. Supports ?limit and ?offset."}),e.jsx(t,{method:"POST",path:"/clients",desc:"Create a client."}),e.jsx(t,{method:"GET",path:"/clients/{id}",desc:"Read a client."}),e.jsx(t,{method:"PATCH",path:"/clients/{id}",desc:"Update a client."}),e.jsx(t,{method:"DELETE",path:"/clients/{id}",desc:"Delete a client."}),e.jsx(t,{method:"GET",path:"/documents",desc:"List documents. Filter with ?type=quote or ?type=invoice."}),e.jsx(t,{method:"POST",path:"/documents",desc:"Create a quote or invoice. Totals are computed server-side."}),e.jsx(t,{method:"GET",path:"/documents/{id}",desc:"Read a document with its client."}),e.jsx(t,{method:"PATCH",path:"/documents/{id}",desc:"Amend a document. Totals recomputed automatically."}),e.jsx(t,{method:"DELETE",path:"/documents/{id}",desc:"Delete a document."}),e.jsx(t,{method:"GET",path:"/documents/{id}/verify",desc:"Get a signed verification URL for a document."}),e.jsx(t,{method:"GET",path:"/documents/{id}/pdf",desc:"Download the rendered PDF (application/pdf)."})]})]}),e.jsxs("section",{className:"mt-12",children:[e.jsx("h2",{className:"text-xl font-semibold",children:"OpenAPI spec"}),e.jsx("p",{className:"mt-2 text-sm text-muted-foreground",children:"Import the spec into Postman, Insomnia, or any OpenAPI codegen tool."}),e.jsxs("div",{className:"mt-4 flex flex-wrap gap-2",children:[e.jsx("a",{href:`${i}/api/public/v1/openapi.json`,target:"_blank",rel:"noreferrer",className:"text-sm underline",children:"openapi.json"}),e.jsx("span",{className:"text-muted-foreground text-sm",children:"·"}),e.jsx("a",{href:`https://petstore.swagger.io/?url=${encodeURIComponent(`${i}/api/public/v1/openapi.json`)}`,target:"_blank",rel:"noreferrer",className:"text-sm underline",children:"Open in Swagger UI"})]})]}),e.jsxs("section",{className:"mt-12",children:[e.jsxs("div",{className:"flex items-center justify-between",children:[e.jsx("h2",{className:"text-xl font-semibold",children:"Quick start"}),e.jsx("div",{className:"flex gap-1 border border-hairline rounded-md p-0.5",children:["curl","ts","python"].map(n=>e.jsx("button",{onClick:()=>o(n),className:`px-3 py-1 text-xs rounded ${s===n?"bg-foreground text-background":"text-muted-foreground"}`,children:n==="curl"?"cURL":n==="ts"?"TypeScript":"Python"},n))})]}),s==="curl"&&e.jsxs("div",{className:"mt-4 space-y-4",children:[e.jsxs("div",{children:[e.jsx("h3",{className:"text-sm font-medium mb-2",children:"List clients"}),e.jsx(a,{children:`curl ${i}/api/public/v1/clients \\
  -H "Authorization: Bearer $QSK_API_KEY"`})]}),e.jsxs("div",{children:[e.jsx("h3",{className:"text-sm font-medium mb-2",children:"Create an invoice"}),e.jsx(a,{children:`curl -X POST ${i}/api/public/v1/documents \\
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
  }'`})]})]}),s==="ts"&&e.jsxs("div",{className:"mt-4 space-y-4",children:[e.jsxs("p",{className:"text-sm text-muted-foreground",children:["Install the TypeScript SDK from the ",e.jsx("code",{className:"font-mono",children:"/sdk/typescript"})," directory in the source repo."]}),e.jsx(a,{lang:"ts",children:`import { QuoteScribeClient } from "@quotescribe/sdk";

const qs = new QuoteScribeClient({
  apiKey: process.env.QSK_API_KEY!,
  baseUrl: "${i}",
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
console.log(verify_url);`})]}),s==="python"&&e.jsxs("div",{className:"mt-4 space-y-4",children:[e.jsxs("p",{className:"text-sm text-muted-foreground",children:["Install the Python SDK from the ",e.jsx("code",{className:"font-mono",children:"/sdk/python"})," directory in the source repo."]}),e.jsx(a,{lang:"python",children:`from quotescribe import QuoteScribeClient

qs = QuoteScribeClient(
    api_key=os.environ["QSK_API_KEY"],
    base_url="${i}",
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

print(qs.documents.verify(invoice["id"])["verify_url"])`})]})]}),e.jsxs("section",{className:"mt-12",children:[e.jsx("h2",{className:"text-xl font-semibold",children:"Errors"}),e.jsxs("p",{className:"mt-2 text-sm text-muted-foreground",children:["Errors come back as JSON with an ",e.jsx("code",{className:"font-mono",children:"error"})," object and an appropriate HTTP status code."]}),e.jsx("div",{className:"mt-4",children:e.jsx(a,{lang:"json",children:'{ "error": { "status": 401, "message": "Invalid API key" } }'})})]})]})}export{x as component};
