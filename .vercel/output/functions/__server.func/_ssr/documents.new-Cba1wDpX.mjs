import { j as jsxRuntimeExports, r as reactExports } from "../_libs/react.mjs";
import { e as useNavigate } from "../_libs/tanstack__react-router.mjs";
import { h as useServerFn, a as useActiveOrg, I as Input, C as ClientFormDialog, B as Button, T as Textarea, D as Dialog, c as DialogContent, d as DialogHeader, e as DialogTitle, w as createSsrRpc, p as profileToBrand, L as Label } from "./router-BDMLDL80.mjs";
import { u as useQuery, a as useMutation } from "../_libs/tanstack__react-query.mjs";
import { R as RequireAuth, A as AppShell } from "./AppShell-DM6M-RSe.mjs";
import { S as Select, a as SelectTrigger, b as SelectValue, c as SelectContent, d as SelectItem } from "./select-ByBIAI-D.mjs";
import { c as computeTotals, f as formatMoney, r as rowTotal } from "./calc-BF6zAv6d.mjs";
import { r as requireSupabaseAuth } from "./auth-middleware-DJP7Badx.mjs";
import { D as DEFAULT_DOCUMENT_TYPE, b as getDocumentTypeLabel, c as getDueDateLabel, d as documentTypeSchema } from "./docTypes-CsATll0j.mjs";
import { c as createServerFn } from "./index.mjs";
import { d as downloadPdf, o as openPdfPreview } from "./pdf-DAix565a.mjs";
import { t as toast } from "../_libs/sonner.mjs";
import "../_libs/qrcode.mjs";
import "../_libs/seroval.mjs";
import "../_libs/pdfmake.mjs";
import { P as Plus, T as Trash2 } from "../_libs/lucide-react.mjs";
import { o as object, s as string, n as number, a as array } from "../_libs/zod.mjs";
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
import "./client.server-BMj2q4-x.mjs";
import "./verifySign.server-CnraXCan.mjs";
import "node:async_hooks";
import "../_libs/h3-v2.mjs";
import "../_libs/rou3.mjs";
import "../_libs/srvx.mjs";
import "./createMiddleware-BvN2ghIY.mjs";
import "../_libs/dijkstrajs.mjs";
import "fs";
import "../_libs/pngjs.mjs";
import "zlib";
import "assert";
import "buffer";
import "../_libs/radix-ui__react-dropdown-menu.mjs";
import "../_libs/radix-ui__react-menu.mjs";
import "../_libs/radix-ui__react-collection.mjs";
import "../_libs/radix-ui__react-direction.mjs";
import "../_libs/radix-ui__react-popper.mjs";
import "../_libs/floating-ui__react-dom.mjs";
import "../_libs/floating-ui__dom.mjs";
import "../_libs/floating-ui__core.mjs";
import "../_libs/floating-ui__utils.mjs";
import "../_libs/radix-ui__react-arrow.mjs";
import "../_libs/radix-ui__react-use-size.mjs";
import "../_libs/radix-ui__react-roving-focus.mjs";
import "../_libs/radix-ui__react-select.mjs";
import "../_libs/radix-ui__number.mjs";
import "../_libs/radix-ui__react-use-previous.mjs";
import "../_libs/@radix-ui/react-visually-hidden+[...].mjs";
const lineItemSchema = object({
  description: string(),
  quantity: number(),
  unit_price: number()
});
const createDocumentSchema = object({
  clientId: string().uuid(),
  docType: documentTypeSchema,
  docNumber: string().min(1),
  issueDate: string().min(1),
  dueDate: string().nullable(),
  lineItems: array(lineItemSchema),
  taxRate: number(),
  discount: number(),
  notes: string().nullable()
});
const getNextDocumentNumber = createServerFn({
  method: "POST"
}).middleware([requireSupabaseAuth]).inputValidator((data) => object({
  docType: documentTypeSchema
}).parse(data)).handler(createSsrRpc("30bf6b89af29e3b571a688483b15fef5a113de06e9ceb35278995eea8dbbfc73"));
const listDocumentClients = createServerFn({
  method: "GET"
}).middleware([requireSupabaseAuth]).handler(createSsrRpc("293f0c3d8e09ee1044d9afc326adfce7991af79a1fb6c566a7d37357ed0f84a6"));
const createDocument = createServerFn({
  method: "POST"
}).middleware([requireSupabaseAuth]).inputValidator((data) => createDocumentSchema.parse(data)).handler(createSsrRpc("076f0d27c3d7b1fba7365afd1647231a0b13d6f0dd851a947be0c6d6c54fdc74"));
function Page() {
  return /* @__PURE__ */ jsxRuntimeExports.jsx(RequireAuth, { children: /* @__PURE__ */ jsxRuntimeExports.jsx(AppShell, { children: /* @__PURE__ */ jsxRuntimeExports.jsx(Creator, {}) }) });
}
function todayISO() {
  return (/* @__PURE__ */ new Date()).toISOString().slice(0, 10);
}
function plusDaysISO(days) {
  const d = /* @__PURE__ */ new Date();
  d.setDate(d.getDate() + days);
  return d.toISOString().slice(0, 10);
}
function Creator() {
  const navigate = useNavigate();
  const createDocumentFn = useServerFn(createDocument);
  const getNextDocumentNumberFn = useServerFn(getNextDocumentNumber);
  const listDocumentClientsFn = useServerFn(listDocumentClients);
  const {
    data: activeOrg
  } = useActiveOrg();
  const [docType, setDocType] = reactExports.useState(DEFAULT_DOCUMENT_TYPE);
  const [docNumber, setDocNumber] = reactExports.useState("");
  const [issueDate, setIssueDate] = reactExports.useState(todayISO());
  const [dueDate, setDueDate] = reactExports.useState(plusDaysISO(14));
  const [clientId, setClientId] = reactExports.useState("");
  const [items, setItems] = reactExports.useState([{
    description: "",
    quantity: 1,
    unit_price: 0
  }]);
  const [taxRate, setTaxRate] = reactExports.useState(15);
  const [discount, setDiscount] = reactExports.useState(0);
  const [notes, setNotes] = reactExports.useState("");
  const [previewUrl, setPreviewUrl] = reactExports.useState(null);
  reactExports.useEffect(() => {
    if (activeOrg) setTaxRate(Number(activeOrg.profile.default_tax_rate));
  }, [activeOrg]);
  const {
    data: clients = [],
    refetch: refetchClients
  } = useQuery({
    queryKey: ["clients"],
    queryFn: async () => await listDocumentClientsFn()
  });
  reactExports.useEffect(() => {
    if (!activeOrg?.org_id) return;
    getNextDocumentNumberFn({
      data: {
        docType
      }
    }).then(setDocNumber).catch(() => setDocNumber(""));
  }, [docType, activeOrg?.org_id, getNextDocumentNumberFn]);
  const totals = reactExports.useMemo(() => computeTotals(items, taxRate, discount), [items, taxRate, discount]);
  const client = clients.find((c) => c.id === clientId) ?? null;
  const updateItem = (i, patch) => setItems((arr) => arr.map((it, idx) => idx === i ? {
    ...it,
    ...patch
  } : it));
  const addItem = () => setItems((arr) => [...arr, {
    description: "",
    quantity: 1,
    unit_price: 0
  }]);
  const removeItem = (i) => setItems((arr) => arr.length === 1 ? arr : arr.filter((_, idx) => idx !== i));
  const buildDocForPdf = async () => {
    if (!client || !activeOrg) return null;
    const brand = await profileToBrand(activeOrg.profile);
    return {
      doc_type: docType,
      doc_number: docNumber,
      issue_date: issueDate,
      due_date: dueDate || null,
      line_items: items,
      tax_rate: taxRate,
      discount,
      ...totals,
      notes: notes || null,
      client: {
        company_name: client.company_name,
        address: client.address,
        email: client.email,
        phone: client.phone
      },
      brand
    };
  };
  const validate = () => {
    if (!activeOrg?.org_id) return "No active organization";
    if (!clientId) return "Select a client";
    if (!docNumber) return "Document number missing";
    if (items.length === 0) return "Add at least one line item";
    if (items.some((i) => !i.description.trim())) return "All line items need a description";
    return null;
  };
  const save = useMutation({
    mutationFn: async () => {
      const err = validate();
      if (err) throw new Error(err);
      if (!activeOrg?.org_id) throw new Error("No active org");
      return await createDocumentFn({
        data: {
          clientId,
          docType,
          docNumber,
          issueDate,
          dueDate: dueDate || null,
          lineItems: items,
          taxRate,
          discount,
          notes: notes || null
        }
      });
    },
    onSuccess: async (id) => {
      toast.success("Document saved");
      const d = await buildDocForPdf();
      if (d) {
        try {
          await downloadPdf(d);
        } catch (e) {
          toast.error(e instanceof Error ? e.message : "Download failed");
        }
      }
      navigate({
        to: "/documents/$id",
        params: {
          id
        }
      });
    },
    onError: (e) => {
      toast.error(e instanceof Error ? e.message : "Save failed");
    }
  });
  const handlePreview = async () => {
    const v = validate();
    if (v) return toast.error(v);
    const d = await buildDocForPdf();
    if (!d) return;
    const url = await openPdfPreview(d);
    setPreviewUrl(url);
  };
  return /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "grid grid-cols-1 gap-8 lg:grid-cols-[1fr_320px] lg:gap-10", children: [
    /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "min-w-0", children: [
      /* @__PURE__ */ jsxRuntimeExports.jsx("p", { className: "text-[11px] uppercase tracking-[0.2em] text-muted-foreground", children: "Create" }),
      /* @__PURE__ */ jsxRuntimeExports.jsxs("h1", { className: "mt-2 text-3xl sm:text-4xl font-semibold tracking-tight", children: [
        "New ",
        getDocumentTypeLabel(docType).toLowerCase()
      ] }),
      /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "mt-8 grid grid-cols-1 gap-4 sm:grid-cols-2", children: [
        /* @__PURE__ */ jsxRuntimeExports.jsx(Field, { label: "Document type", children: /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "inline-flex w-full rounded-full border border-hairline p-0.5", children: ["quote", "invoice", "credit_note", "debit_note", "receipt"].map((t) => /* @__PURE__ */ jsxRuntimeExports.jsx("button", { type: "button", onClick: () => setDocType(t), className: `flex-1 rounded-full px-4 py-1.5 text-[13px] capitalize transition-colors ${docType === t ? "bg-primary text-primary-foreground" : "text-muted-foreground hover:text-foreground"}`, children: t === "quote" ? "Quotation" : t === "invoice" ? "Invoice" : t === "credit_note" ? "Credit Note" : t === "debit_note" ? "Debit Note" : "Receipt" }, t)) }) }),
        /* @__PURE__ */ jsxRuntimeExports.jsx(Field, { label: "Document number", children: /* @__PURE__ */ jsxRuntimeExports.jsx(Input, { value: docNumber, onChange: (e) => setDocNumber(e.target.value), className: "font-mono" }) }),
        /* @__PURE__ */ jsxRuntimeExports.jsx(Field, { label: "Issue date", children: /* @__PURE__ */ jsxRuntimeExports.jsx(Input, { type: "date", value: issueDate, onChange: (e) => setIssueDate(e.target.value) }) }),
        /* @__PURE__ */ jsxRuntimeExports.jsx(Field, { label: getDueDateLabel(docType), children: /* @__PURE__ */ jsxRuntimeExports.jsx(Input, { type: "date", value: dueDate, onChange: (e) => setDueDate(e.target.value) }) })
      ] }),
      /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "mt-8", children: /* @__PURE__ */ jsxRuntimeExports.jsx(Field, { label: "Client", children: /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "flex gap-2", children: [
        /* @__PURE__ */ jsxRuntimeExports.jsxs(Select, { value: clientId, onValueChange: setClientId, children: [
          /* @__PURE__ */ jsxRuntimeExports.jsx(SelectTrigger, { className: "flex-1", children: /* @__PURE__ */ jsxRuntimeExports.jsx(SelectValue, { placeholder: "Select a client" }) }),
          /* @__PURE__ */ jsxRuntimeExports.jsx(SelectContent, { children: clients.map((c) => /* @__PURE__ */ jsxRuntimeExports.jsx(SelectItem, { value: c.id, children: c.company_name }, c.id)) })
        ] }),
        /* @__PURE__ */ jsxRuntimeExports.jsx(ClientFormDialog, { trigger: /* @__PURE__ */ jsxRuntimeExports.jsx(Button, { variant: "outline", type: "button", children: /* @__PURE__ */ jsxRuntimeExports.jsx(Plus, { className: "h-4 w-4" }) }), onSaved: async (c) => {
          await refetchClients();
          setClientId(c.id);
        } })
      ] }) }) }),
      /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "mt-10", children: [
        /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "flex items-center justify-between", children: [
          /* @__PURE__ */ jsxRuntimeExports.jsx("h2", { className: "text-sm font-medium tracking-tight", children: "Line items" }),
          /* @__PURE__ */ jsxRuntimeExports.jsxs(Button, { type: "button", variant: "ghost", size: "sm", onClick: addItem, children: [
            /* @__PURE__ */ jsxRuntimeExports.jsx(Plus, { className: "mr-1 h-3.5 w-3.5" }),
            "Add row"
          ] })
        ] }),
        /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "mt-3 overflow-hidden rounded-xl border border-hairline", children: [
          /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "hidden sm:grid grid-cols-[1fr_90px_120px_120px_40px] items-center gap-2 border-b border-hairline bg-secondary/50 px-4 py-2.5 text-[11px] uppercase tracking-wider text-muted-foreground", children: [
            /* @__PURE__ */ jsxRuntimeExports.jsx("div", { children: "Description" }),
            /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "text-right", children: "Qty" }),
            /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "text-right", children: "Unit price" }),
            /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "text-right", children: "Amount" }),
            /* @__PURE__ */ jsxRuntimeExports.jsx("div", {})
          ] }),
          items.map((it, i) => /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "flex flex-col gap-2 border-b border-hairline px-3 py-3 last:border-0 sm:grid sm:grid-cols-[1fr_90px_120px_120px_40px] sm:items-center sm:gap-2 sm:px-4 sm:py-2", children: [
            /* @__PURE__ */ jsxRuntimeExports.jsx(Input, { placeholder: "Item or service description", value: it.description, onChange: (e) => updateItem(i, {
              description: e.target.value
            }), className: "w-full border border-hairline bg-transparent shadow-none focus-visible:ring-1 focus-visible:ring-ring sm:border-0 sm:focus-visible:ring-0 sm:focus-visible:ring-offset-0" }),
            /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "grid grid-cols-[1fr_1fr_1fr_auto] items-center gap-2 sm:contents", children: [
              /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { children: [
                /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "text-[10px] uppercase tracking-wider text-muted-foreground sm:hidden", children: "Qty" }),
                /* @__PURE__ */ jsxRuntimeExports.jsx(Input, { type: "number", min: 0, step: "0.01", value: it.quantity, onChange: (e) => updateItem(i, {
                  quantity: parseFloat(e.target.value) || 0
                }), className: "border border-hairline bg-transparent text-right shadow-none focus-visible:ring-1 focus-visible:ring-ring tabular sm:border-0 sm:focus-visible:ring-0 sm:focus-visible:ring-offset-0" })
              ] }),
              /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { children: [
                /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "text-[10px] uppercase tracking-wider text-muted-foreground sm:hidden", children: "Unit price" }),
                /* @__PURE__ */ jsxRuntimeExports.jsx(Input, { type: "number", min: 0, step: "0.01", value: it.unit_price, onChange: (e) => updateItem(i, {
                  unit_price: parseFloat(e.target.value) || 0
                }), className: "border border-hairline bg-transparent text-right shadow-none focus-visible:ring-1 focus-visible:ring-ring tabular sm:border-0 sm:focus-visible:ring-0 sm:focus-visible:ring-offset-0" })
              ] }),
              /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "text-right", children: [
                /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "text-[10px] uppercase tracking-wider text-muted-foreground sm:hidden", children: "Amount" }),
                /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "text-sm tabular py-2", children: formatMoney(rowTotal(it)) })
              ] }),
              /* @__PURE__ */ jsxRuntimeExports.jsx("button", { type: "button", onClick: () => removeItem(i), className: "text-muted-foreground hover:text-destructive disabled:opacity-30", disabled: items.length === 1, children: /* @__PURE__ */ jsxRuntimeExports.jsx(Trash2, { className: "h-3.5 w-3.5" }) })
            ] })
          ] }, i))
        ] })
      ] }),
      /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "mt-8 grid grid-cols-2 gap-4", children: [
        /* @__PURE__ */ jsxRuntimeExports.jsx(Field, { label: "Tax rate (%)", children: /* @__PURE__ */ jsxRuntimeExports.jsx(Input, { type: "number", min: 0, step: "0.01", value: taxRate, onChange: (e) => setTaxRate(parseFloat(e.target.value) || 0), className: "tabular" }) }),
        /* @__PURE__ */ jsxRuntimeExports.jsx(Field, { label: "Discount", children: /* @__PURE__ */ jsxRuntimeExports.jsx(Input, { type: "number", min: 0, step: "0.01", value: discount, onChange: (e) => setDiscount(parseFloat(e.target.value) || 0), className: "tabular" }) })
      ] }),
      /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "mt-6", children: /* @__PURE__ */ jsxRuntimeExports.jsx(Field, { label: "Notes (optional)", children: /* @__PURE__ */ jsxRuntimeExports.jsx(Textarea, { rows: 3, value: notes, onChange: (e) => setNotes(e.target.value), placeholder: "Payment terms, delivery details, etc." }) }) })
    ] }),
    /* @__PURE__ */ jsxRuntimeExports.jsx("aside", { className: "lg:sticky lg:top-20 lg:h-fit", children: /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "rounded-2xl border border-hairline bg-card p-5 sm:p-6", children: [
      /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "text-[11px] uppercase tracking-[0.2em] text-muted-foreground", children: "Summary" }),
      /* @__PURE__ */ jsxRuntimeExports.jsxs("dl", { className: "mt-5 space-y-3 text-sm", children: [
        /* @__PURE__ */ jsxRuntimeExports.jsx(Row, { label: "Subtotal", value: formatMoney(totals.subtotal) }),
        /* @__PURE__ */ jsxRuntimeExports.jsx(Row, { label: `Tax (${taxRate}%)`, value: formatMoney(totals.tax_amount) }),
        discount > 0 && /* @__PURE__ */ jsxRuntimeExports.jsx(Row, { label: "Discount", value: `− ${formatMoney(discount)}` }),
        /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "my-3 border-t border-hairline" }),
        /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "flex items-baseline justify-between", children: [
          /* @__PURE__ */ jsxRuntimeExports.jsx("dt", { className: "text-sm font-medium", children: "Total" }),
          /* @__PURE__ */ jsxRuntimeExports.jsx("dd", { className: "text-2xl font-semibold tracking-tight tabular", children: formatMoney(totals.total) })
        ] })
      ] }),
      /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "mt-6 flex flex-col gap-2", children: [
        /* @__PURE__ */ jsxRuntimeExports.jsx(Button, { onClick: handlePreview, variant: "outline", className: "rounded-full", children: "Preview PDF" }),
        /* @__PURE__ */ jsxRuntimeExports.jsx(Button, { onClick: () => save.mutate(), disabled: save.isPending, className: "rounded-full", children: save.isPending ? "Saving…" : "Save & download" })
      ] }),
      /* @__PURE__ */ jsxRuntimeExports.jsxs("p", { className: "mt-4 text-[11px] leading-relaxed text-muted-foreground", children: [
        "Document ",
        docNumber || "—",
        " · ",
        client?.company_name ?? "No client selected"
      ] })
    ] }) }),
    /* @__PURE__ */ jsxRuntimeExports.jsx(Dialog, { open: !!previewUrl, onOpenChange: (o) => !o && setPreviewUrl(null), children: /* @__PURE__ */ jsxRuntimeExports.jsxs(DialogContent, { className: "sm:max-w-4xl p-3 sm:p-6", children: [
      /* @__PURE__ */ jsxRuntimeExports.jsx(DialogHeader, { children: /* @__PURE__ */ jsxRuntimeExports.jsx(DialogTitle, { children: "PDF Preview" }) }),
      previewUrl && /* @__PURE__ */ jsxRuntimeExports.jsx("iframe", { src: previewUrl, title: "PDF preview", className: "h-[70vh] w-full rounded-md border border-hairline" }),
      /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "flex flex-col-reverse gap-2 sm:flex-row sm:justify-end", children: [
        /* @__PURE__ */ jsxRuntimeExports.jsx(Button, { variant: "ghost", onClick: () => setPreviewUrl(null), children: "Close" }),
        /* @__PURE__ */ jsxRuntimeExports.jsx(Button, { onClick: async () => {
          const d = await buildDocForPdf();
          if (d) downloadPdf(d);
        }, children: "Download" })
      ] })
    ] }) })
  ] });
}
function Field({
  label,
  children
}) {
  return /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "space-y-1.5", children: [
    /* @__PURE__ */ jsxRuntimeExports.jsx(Label, { className: "text-xs", children: label }),
    children
  ] });
}
function Row({
  label,
  value
}) {
  return /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "flex items-baseline justify-between", children: [
    /* @__PURE__ */ jsxRuntimeExports.jsx("dt", { className: "text-muted-foreground", children: label }),
    /* @__PURE__ */ jsxRuntimeExports.jsx("dd", { className: "tabular", children: value })
  ] });
}
export {
  Page as component
};
