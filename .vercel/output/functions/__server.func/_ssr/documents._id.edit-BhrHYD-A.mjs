import { j as jsxRuntimeExports, r as reactExports } from "../_libs/react.mjs";
import { e as useNavigate, L as Link } from "../_libs/tanstack__react-router.mjs";
import { u as useQuery, a as useMutation } from "../_libs/tanstack__react-query.mjs";
import { R as RequireAuth, A as AppShell } from "./AppShell-B2WYeB1G.mjs";
import { s as supabase } from "./client-U3FzjMwq.mjs";
import { z as Route$9, I as Input, B as Button, T as Textarea, L as Label } from "./router-_O5wH3lZ.mjs";
import { S as Select, a as SelectTrigger, b as SelectValue, c as SelectContent, d as SelectItem } from "./select-8vh32Vcs.mjs";
import { c as computeTotals, f as formatMoney, r as rowTotal } from "./calc-BF6zAv6d.mjs";
import { b as getDocumentTypeLabel, c as getDueDateLabel } from "./docTypes-CsATll0j.mjs";
import { t as toast } from "../_libs/sonner.mjs";
import "./index.mjs";
import "../_libs/seroval.mjs";
import "../_libs/qrcode.mjs";
import { p as ArrowLeft, P as Plus, T as Trash2 } from "../_libs/lucide-react.mjs";
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
import "../_libs/radix-ui__react-dropdown-menu.mjs";
import "../_libs/radix-ui__primitive.mjs";
import "../_libs/radix-ui__react-compose-refs.mjs";
import "../_libs/radix-ui__react-context.mjs";
import "../_libs/@radix-ui/react-use-controllable-state+[...].mjs";
import "../_libs/@radix-ui/react-use-layout-effect+[...].mjs";
import "../_libs/radix-ui__react-primitive.mjs";
import "../_libs/radix-ui__react-slot.mjs";
import "../_libs/radix-ui__react-menu.mjs";
import "../_libs/radix-ui__react-collection.mjs";
import "../_libs/radix-ui__react-direction.mjs";
import "../_libs/@radix-ui/react-dismissable-layer+[...].mjs";
import "../_libs/@radix-ui/react-use-callback-ref+[...].mjs";
import "../_libs/@radix-ui/react-use-escape-keydown+[...].mjs";
import "../_libs/radix-ui__react-focus-guards.mjs";
import "../_libs/radix-ui__react-focus-scope.mjs";
import "../_libs/radix-ui__react-popper.mjs";
import "../_libs/floating-ui__react-dom.mjs";
import "../_libs/floating-ui__dom.mjs";
import "../_libs/floating-ui__core.mjs";
import "../_libs/floating-ui__utils.mjs";
import "../_libs/radix-ui__react-arrow.mjs";
import "../_libs/radix-ui__react-use-size.mjs";
import "../_libs/radix-ui__react-portal.mjs";
import "../_libs/radix-ui__react-presence.mjs";
import "../_libs/radix-ui__react-roving-focus.mjs";
import "../_libs/radix-ui__react-id.mjs";
import "../_libs/aria-hidden.mjs";
import "../_libs/react-remove-scroll.mjs";
import "tslib";
import "../_libs/react-remove-scroll-bar.mjs";
import "../_libs/react-style-singleton.mjs";
import "../_libs/get-nonce.mjs";
import "../_libs/use-sidecar.mjs";
import "../_libs/use-callback-ref.mjs";
import "../_libs/supabase__supabase-js.mjs";
import "../_libs/supabase__postgrest-js.mjs";
import "../_libs/supabase__realtime-js.mjs";
import "../_libs/supabase__phoenix.mjs";
import "../_libs/supabase__storage-js.mjs";
import "../_libs/iceberg-js.mjs";
import "../_libs/supabase__auth-js.mjs";
import "../_libs/supabase__functions-js.mjs";
import "../_libs/class-variance-authority.mjs";
import "../_libs/clsx.mjs";
import "../_libs/tailwind-merge.mjs";
import "../_libs/radix-ui__react-label.mjs";
import "../_libs/radix-ui__react-dialog.mjs";
import "./auth-middleware-DJP7Badx.mjs";
import "./createMiddleware-BvN2ghIY.mjs";
import "./client.server-BMj2q4-x.mjs";
import "./verifySign.server-CnraXCan.mjs";
import "../_libs/zod.mjs";
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
import "../_libs/radix-ui__react-select.mjs";
import "../_libs/radix-ui__number.mjs";
import "../_libs/radix-ui__react-use-previous.mjs";
import "../_libs/@radix-ui/react-visually-hidden+[...].mjs";
function Page() {
  return /* @__PURE__ */ jsxRuntimeExports.jsx(RequireAuth, { children: /* @__PURE__ */ jsxRuntimeExports.jsx(AppShell, { children: /* @__PURE__ */ jsxRuntimeExports.jsx(Editor, {}) }) });
}
function Editor() {
  const {
    id
  } = Route$9.useParams();
  const navigate = useNavigate();
  const [docNumber, setDocNumber] = reactExports.useState("");
  const [issueDate, setIssueDate] = reactExports.useState("");
  const [dueDate, setDueDate] = reactExports.useState("");
  const [clientId, setClientId] = reactExports.useState("");
  const [items, setItems] = reactExports.useState([{
    description: "",
    quantity: 1,
    unit_price: 0
  }]);
  const [taxRate, setTaxRate] = reactExports.useState(15);
  const [discount, setDiscount] = reactExports.useState(0);
  const [notes, setNotes] = reactExports.useState("");
  const [docType, setDocType] = reactExports.useState("quote");
  const [loaded, setLoaded] = reactExports.useState(false);
  const {
    data: doc
  } = useQuery({
    queryKey: ["doc-edit", id],
    queryFn: async () => {
      const {
        data,
        error
      } = await supabase.from("documents").select("*").eq("id", id).single();
      if (error) throw error;
      return data;
    }
  });
  const {
    data: clients = []
  } = useQuery({
    queryKey: ["clients"],
    queryFn: async () => {
      const {
        data,
        error
      } = await supabase.from("clients").select("id, company_name").order("company_name");
      if (error) throw error;
      return data;
    }
  });
  reactExports.useEffect(() => {
    if (!doc || loaded) return;
    setDocNumber(doc.doc_number);
    setIssueDate(doc.issue_date);
    setDueDate(doc.due_date ?? "");
    setClientId(doc.client_id);
    setItems(doc.line_items ?? []);
    setTaxRate(Number(doc.tax_rate));
    setDiscount(Number(doc.discount));
    setNotes(doc.notes ?? "");
    setDocType(doc.doc_type ?? "quote");
    setLoaded(true);
  }, [doc, loaded]);
  const totals = reactExports.useMemo(() => computeTotals(items, taxRate, discount), [items, taxRate, discount]);
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
  const save = useMutation({
    mutationFn: async () => {
      if (!clientId) throw new Error("Select a client");
      if (items.some((i) => !i.description.trim())) throw new Error("All line items need a description");
      const {
        error
      } = await supabase.from("documents").update({
        client_id: clientId,
        doc_number: docNumber,
        issue_date: issueDate,
        due_date: dueDate || null,
        line_items: items,
        tax_rate: taxRate,
        discount,
        subtotal: totals.subtotal,
        tax_amount: totals.tax_amount,
        total: totals.total,
        notes: notes || null
      }).eq("id", id);
      if (error) throw error;
    },
    onSuccess: () => {
      toast.success("Changes saved");
      navigate({
        to: "/documents/$id",
        params: {
          id
        }
      });
    },
    onError: (e) => toast.error(e instanceof Error ? e.message : "Save failed")
  });
  if (!loaded) return /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "text-sm text-muted-foreground", children: "Loading…" });
  return /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "grid grid-cols-1 gap-8 lg:grid-cols-[1fr_320px] lg:gap-10", children: [
    /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "min-w-0", children: [
      /* @__PURE__ */ jsxRuntimeExports.jsxs(Link, { to: "/documents/$id", params: {
        id
      }, className: "inline-flex items-center gap-1 text-xs text-muted-foreground hover:text-foreground", children: [
        /* @__PURE__ */ jsxRuntimeExports.jsx(ArrowLeft, { className: "h-3.5 w-3.5" }),
        " Back"
      ] }),
      /* @__PURE__ */ jsxRuntimeExports.jsx("p", { className: "mt-4 text-[11px] uppercase tracking-[0.2em] text-muted-foreground", children: "Edit" }),
      /* @__PURE__ */ jsxRuntimeExports.jsxs("h1", { className: "mt-2 text-3xl sm:text-4xl font-semibold tracking-tight", children: [
        getDocumentTypeLabel(docType),
        " ",
        docNumber
      ] }),
      /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "mt-8 grid grid-cols-1 gap-4 sm:grid-cols-2", children: [
        /* @__PURE__ */ jsxRuntimeExports.jsx(Field, { label: "Document number", children: /* @__PURE__ */ jsxRuntimeExports.jsx(Input, { value: docNumber, onChange: (e) => setDocNumber(e.target.value), className: "font-mono" }) }),
        /* @__PURE__ */ jsxRuntimeExports.jsx(Field, { label: "Client", children: /* @__PURE__ */ jsxRuntimeExports.jsxs(Select, { value: clientId, onValueChange: setClientId, children: [
          /* @__PURE__ */ jsxRuntimeExports.jsx(SelectTrigger, { children: /* @__PURE__ */ jsxRuntimeExports.jsx(SelectValue, { placeholder: "Select a client" }) }),
          /* @__PURE__ */ jsxRuntimeExports.jsx(SelectContent, { children: clients.map((c) => /* @__PURE__ */ jsxRuntimeExports.jsx(SelectItem, { value: c.id, children: c.company_name }, c.id)) })
        ] }) }),
        /* @__PURE__ */ jsxRuntimeExports.jsx(Field, { label: "Issue date", children: /* @__PURE__ */ jsxRuntimeExports.jsx(Input, { type: "date", value: issueDate, onChange: (e) => setIssueDate(e.target.value) }) }),
        /* @__PURE__ */ jsxRuntimeExports.jsx(Field, { label: getDueDateLabel(docType), children: /* @__PURE__ */ jsxRuntimeExports.jsx(Input, { type: "date", value: dueDate, onChange: (e) => setDueDate(e.target.value) }) })
      ] }),
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
            }), className: "w-full border border-hairline bg-transparent shadow-none sm:border-0" }),
            /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "grid grid-cols-[1fr_1fr_1fr_auto] items-center gap-2 sm:contents", children: [
              /* @__PURE__ */ jsxRuntimeExports.jsx(Input, { type: "number", min: 0, step: "0.01", value: it.quantity, onChange: (e) => updateItem(i, {
                quantity: parseFloat(e.target.value) || 0
              }), className: "border border-hairline bg-transparent text-right shadow-none tabular sm:border-0" }),
              /* @__PURE__ */ jsxRuntimeExports.jsx(Input, { type: "number", min: 0, step: "0.01", value: it.unit_price, onChange: (e) => updateItem(i, {
                unit_price: parseFloat(e.target.value) || 0
              }), className: "border border-hairline bg-transparent text-right shadow-none tabular sm:border-0" }),
              /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "text-right text-sm tabular py-2", children: formatMoney(rowTotal(it)) }),
              /* @__PURE__ */ jsxRuntimeExports.jsx("button", { type: "button", onClick: () => removeItem(i), className: "text-muted-foreground hover:text-destructive disabled:opacity-30", disabled: items.length === 1, children: /* @__PURE__ */ jsxRuntimeExports.jsx(Trash2, { className: "h-3.5 w-3.5" }) })
            ] })
          ] }, i))
        ] })
      ] }),
      /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "mt-8 grid grid-cols-2 gap-4", children: [
        /* @__PURE__ */ jsxRuntimeExports.jsx(Field, { label: "Tax rate (%)", children: /* @__PURE__ */ jsxRuntimeExports.jsx(Input, { type: "number", min: 0, step: "0.01", value: taxRate, onChange: (e) => setTaxRate(parseFloat(e.target.value) || 0), className: "tabular" }) }),
        /* @__PURE__ */ jsxRuntimeExports.jsx(Field, { label: "Discount", children: /* @__PURE__ */ jsxRuntimeExports.jsx(Input, { type: "number", min: 0, step: "0.01", value: discount, onChange: (e) => setDiscount(parseFloat(e.target.value) || 0), className: "tabular" }) })
      ] }),
      /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "mt-6", children: /* @__PURE__ */ jsxRuntimeExports.jsx(Field, { label: "Notes (optional)", children: /* @__PURE__ */ jsxRuntimeExports.jsx(Textarea, { rows: 3, value: notes, onChange: (e) => setNotes(e.target.value) }) }) })
    ] }),
    /* @__PURE__ */ jsxRuntimeExports.jsx("aside", { className: "lg:sticky lg:top-20 lg:h-fit", children: /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "rounded-2xl border border-hairline bg-card p-5 sm:p-6", children: [
      /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "text-[11px] uppercase tracking-[0.2em] text-muted-foreground", children: "Summary" }),
      /* @__PURE__ */ jsxRuntimeExports.jsxs("dl", { className: "mt-5 space-y-3 text-sm", children: [
        /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "flex justify-between", children: [
          /* @__PURE__ */ jsxRuntimeExports.jsx("dt", { className: "text-muted-foreground", children: "Subtotal" }),
          /* @__PURE__ */ jsxRuntimeExports.jsx("dd", { className: "tabular", children: formatMoney(totals.subtotal) })
        ] }),
        /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "flex justify-between", children: [
          /* @__PURE__ */ jsxRuntimeExports.jsxs("dt", { className: "text-muted-foreground", children: [
            "Tax (",
            taxRate,
            "%)"
          ] }),
          /* @__PURE__ */ jsxRuntimeExports.jsx("dd", { className: "tabular", children: formatMoney(totals.tax_amount) })
        ] }),
        discount > 0 && /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "flex justify-between", children: [
          /* @__PURE__ */ jsxRuntimeExports.jsx("dt", { className: "text-muted-foreground", children: "Discount" }),
          /* @__PURE__ */ jsxRuntimeExports.jsxs("dd", { className: "tabular", children: [
            "− ",
            formatMoney(discount)
          ] })
        ] }),
        /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "my-3 border-t border-hairline" }),
        /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "flex items-baseline justify-between", children: [
          /* @__PURE__ */ jsxRuntimeExports.jsx("dt", { className: "text-sm font-medium", children: "Total" }),
          /* @__PURE__ */ jsxRuntimeExports.jsx("dd", { className: "text-2xl font-semibold tracking-tight tabular", children: formatMoney(totals.total) })
        ] })
      ] }),
      /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "mt-6 flex flex-col gap-2", children: [
        /* @__PURE__ */ jsxRuntimeExports.jsx(Button, { onClick: () => save.mutate(), disabled: save.isPending, className: "rounded-full", children: save.isPending ? "Saving…" : "Save changes" }),
        /* @__PURE__ */ jsxRuntimeExports.jsx(Link, { to: "/documents/$id", params: {
          id
        }, children: /* @__PURE__ */ jsxRuntimeExports.jsx(Button, { variant: "outline", className: "w-full rounded-full", children: "Cancel" }) })
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
export {
  Page as component
};
