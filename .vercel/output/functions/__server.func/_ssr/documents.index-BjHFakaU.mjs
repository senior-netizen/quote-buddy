import { j as jsxRuntimeExports, r as reactExports } from "../_libs/react.mjs";
import { L as Link } from "../_libs/tanstack__react-router.mjs";
import { u as useQuery } from "../_libs/tanstack__react-query.mjs";
import { R as RequireAuth, A as AppShell } from "./AppShell-DTvx3DtV.mjs";
import { s as supabase } from "./client-U3FzjMwq.mjs";
import { a as formatDate, f as formatMoney } from "./calc-BF6zAv6d.mjs";
import { a as useActiveOrg, B as Button, I as Input, D as Dialog, c as DialogContent, d as DialogHeader, e as DialogTitle, p as profileToBrand } from "./router-DjPnTx2E.mjs";
import { t as toast } from "../_libs/sonner.mjs";
import { g as generatePdfBlob } from "./pdf-cCtP0MMi.mjs";
import { i as issueVerifyToken } from "./verify.functions-Dw7Por_X.mjs";
import { a as getDocumentTypeShortLabel } from "./docTypes-CsATll0j.mjs";
import "./index.mjs";
import "../_libs/seroval.mjs";
import "../_libs/qrcode.mjs";
import "../_libs/pdfmake.mjs";
import { P as Plus, g as Search, E as Eye, D as Download } from "../_libs/lucide-react.mjs";
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
function Page() {
  return /* @__PURE__ */ jsxRuntimeExports.jsx(RequireAuth, { children: /* @__PURE__ */ jsxRuntimeExports.jsx(AppShell, { children: /* @__PURE__ */ jsxRuntimeExports.jsx(Documents, {}) }) });
}
function Documents() {
  const [filter, setFilter] = reactExports.useState("all");
  const [search, setSearch] = reactExports.useState("");
  const [previewUrl, setPreviewUrl] = reactExports.useState(null);
  const [busyId, setBusyId] = reactExports.useState(null);
  const {
    data: activeOrg
  } = useActiveOrg();
  const {
    data: docs = []
  } = useQuery({
    queryKey: ["documents", filter],
    queryFn: async () => {
      let q = supabase.from("documents").select("id, doc_type, doc_number, issue_date, total, client:clients(company_name)").order("created_at", {
        ascending: false
      });
      if (filter !== "all") q = q.eq("doc_type", filter);
      const {
        data,
        error
      } = await q;
      if (error) throw error;
      return data ?? [];
    }
  });
  const buildBlob = async (id) => {
    if (!activeOrg) throw new Error("No active organization");
    const {
      data: doc,
      error
    } = await supabase.from("documents").select("*, client:clients(company_name, address, email, phone)").eq("id", id).maybeSingle();
    if (error || !doc) throw new Error("Document not found");
    const client = doc.client ?? {
      company_name: "—",
      address: null,
      email: null,
      phone: null
    };
    const {
      id: docId,
      hash,
      sig
    } = await issueVerifyToken({
      data: {
        id
      }
    }).catch((e) => {
      console.warn("Verify token issuance failed; generating PDF without QR", e);
      return {
        id: "",
        hash: "",
        sig: ""
      };
    });
    const verifyUrl = docId ? `${window.location.origin}/verify/${docId}?sig=${encodeURIComponent(sig)}&h=${hash}` : void 0;
    const brand = await profileToBrand(activeOrg.profile);
    const docForPdf = {
      doc_type: doc.doc_type,
      doc_number: doc.doc_number,
      issue_date: doc.issue_date,
      due_date: doc.due_date,
      line_items: doc.line_items ?? [],
      tax_rate: Number(doc.tax_rate),
      discount: Number(doc.discount),
      subtotal: Number(doc.subtotal),
      tax_amount: Number(doc.tax_amount),
      total: Number(doc.total),
      notes: doc.notes,
      client,
      brand,
      verifyUrl
    };
    return await generatePdfBlob(docForPdf);
  };
  const handleDownload = async (d) => {
    setBusyId(d.id);
    try {
      const blob = await buildBlob(d.id);
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = `${d.doc_number}.pdf`;
      document.body.appendChild(a);
      a.click();
      a.remove();
      setTimeout(() => URL.revokeObjectURL(url), 1e3);
    } catch (e) {
      toast.error(e instanceof Error ? e.message : "Download failed");
    } finally {
      setBusyId(null);
    }
  };
  const handlePreview = async (d) => {
    setBusyId(d.id);
    try {
      const blob = await buildBlob(d.id);
      const url = URL.createObjectURL(blob);
      setPreviewUrl((prev) => {
        if (prev) URL.revokeObjectURL(prev);
        return url;
      });
    } catch (e) {
      toast.error(e instanceof Error ? e.message : "Preview failed");
    } finally {
      setBusyId(null);
    }
  };
  return /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { children: [
    /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between", children: [
      /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { children: [
        /* @__PURE__ */ jsxRuntimeExports.jsx("p", { className: "text-[11px] uppercase tracking-[0.2em] text-muted-foreground", children: "Library" }),
        /* @__PURE__ */ jsxRuntimeExports.jsx("h1", { className: "mt-2 text-3xl sm:text-4xl font-semibold tracking-tight", children: "Documents" })
      ] }),
      /* @__PURE__ */ jsxRuntimeExports.jsx(Link, { to: "/documents/new", className: "w-fit", children: /* @__PURE__ */ jsxRuntimeExports.jsxs(Button, { className: "rounded-full", children: [
        /* @__PURE__ */ jsxRuntimeExports.jsx(Plus, { className: "mr-1.5 h-3.5 w-3.5" }),
        "New"
      ] }) })
    ] }),
    /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "mt-6 sm:mt-8 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between", children: [
      /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "inline-flex w-fit rounded-full border border-hairline p-0.5", children: ["all", "quote", "invoice", "credit_note", "debit_note", "receipt"].map((f) => /* @__PURE__ */ jsxRuntimeExports.jsx("button", { onClick: () => setFilter(f), className: `rounded-full px-3 sm:px-4 py-1.5 text-[12px] capitalize transition-colors ${filter === f ? "bg-primary text-primary-foreground" : "text-muted-foreground hover:text-foreground"}`, children: f === "all" ? "All" : f === "quote" ? "Quotes" : f === "invoice" ? "Invoices" : f === "credit_note" ? "Credit notes" : f === "debit_note" ? "Debit notes" : "Receipts" }, f)) }),
      /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "relative w-full sm:w-72", children: [
        /* @__PURE__ */ jsxRuntimeExports.jsx(Search, { className: "pointer-events-none absolute left-3 top-1/2 h-3.5 w-3.5 -translate-y-1/2 text-muted-foreground" }),
        /* @__PURE__ */ jsxRuntimeExports.jsx(Input, { type: "search", value: search, onChange: (e) => setSearch(e.target.value), placeholder: "Search number or client…", className: "h-9 rounded-full pl-9", "aria-label": "Search documents" })
      ] })
    ] }),
    (() => {
      const q = search.trim().toLowerCase();
      const filtered = q ? docs.filter((d) => d.doc_number.toLowerCase().includes(q) || (d.client?.company_name ?? "").toLowerCase().includes(q)) : docs;
      return /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "mt-6 overflow-hidden rounded-xl border border-hairline", children: filtered.length === 0 ? /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "px-6 py-16 text-center text-sm text-muted-foreground", children: docs.length === 0 ? "No documents." : "No matches for your search." }) : /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "overflow-x-auto", children: /* @__PURE__ */ jsxRuntimeExports.jsxs("table", { className: "w-full min-w-[720px] text-sm", children: [
        /* @__PURE__ */ jsxRuntimeExports.jsx("thead", { className: "border-b border-hairline bg-secondary/50", children: /* @__PURE__ */ jsxRuntimeExports.jsxs("tr", { className: "text-[11px] uppercase tracking-wider text-muted-foreground", children: [
          /* @__PURE__ */ jsxRuntimeExports.jsx("th", { className: "px-5 py-3 text-left font-medium", children: "Number" }),
          /* @__PURE__ */ jsxRuntimeExports.jsx("th", { className: "px-5 py-3 text-left font-medium", children: "Type" }),
          /* @__PURE__ */ jsxRuntimeExports.jsx("th", { className: "px-5 py-3 text-left font-medium", children: "Client" }),
          /* @__PURE__ */ jsxRuntimeExports.jsx("th", { className: "px-5 py-3 text-left font-medium", children: "Issued" }),
          /* @__PURE__ */ jsxRuntimeExports.jsx("th", { className: "px-5 py-3 text-right font-medium", children: "Total" }),
          /* @__PURE__ */ jsxRuntimeExports.jsx("th", { className: "px-5 py-3 text-right font-medium", children: "Actions" })
        ] }) }),
        /* @__PURE__ */ jsxRuntimeExports.jsx("tbody", { children: filtered.map((d) => /* @__PURE__ */ jsxRuntimeExports.jsxs("tr", { className: "border-b border-hairline last:border-0 hover:bg-secondary/30", children: [
          /* @__PURE__ */ jsxRuntimeExports.jsx("td", { className: "px-5 py-3", children: /* @__PURE__ */ jsxRuntimeExports.jsx(Link, { to: "/documents/$id", params: {
            id: d.id
          }, className: "font-mono text-[12px] hover:underline underline-offset-4", children: d.doc_number }) }),
          /* @__PURE__ */ jsxRuntimeExports.jsx("td", { className: "px-5 py-3", children: /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: "rounded-full border border-hairline px-2 py-0.5 text-[11px] uppercase tracking-wider text-muted-foreground", children: getDocumentTypeShortLabel(d.doc_type) }) }),
          /* @__PURE__ */ jsxRuntimeExports.jsx("td", { className: "px-5 py-3", children: d.client?.company_name ?? "—" }),
          /* @__PURE__ */ jsxRuntimeExports.jsx("td", { className: "px-5 py-3 text-muted-foreground", children: formatDate(d.issue_date) }),
          /* @__PURE__ */ jsxRuntimeExports.jsx("td", { className: "px-5 py-3 text-right tabular", children: formatMoney(Number(d.total)) }),
          /* @__PURE__ */ jsxRuntimeExports.jsx("td", { className: "px-5 py-3", children: /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "flex justify-end gap-1", children: [
            /* @__PURE__ */ jsxRuntimeExports.jsx(Button, { variant: "ghost", size: "sm", className: "h-8 rounded-full px-3", onClick: () => handlePreview(d), disabled: busyId === d.id, "aria-label": `Preview ${d.doc_number}`, children: /* @__PURE__ */ jsxRuntimeExports.jsx(Eye, { className: "h-3.5 w-3.5" }) }),
            /* @__PURE__ */ jsxRuntimeExports.jsx(Button, { variant: "ghost", size: "sm", className: "h-8 rounded-full px-3", onClick: () => handleDownload(d), disabled: busyId === d.id, "aria-label": `Download ${d.doc_number}`, children: /* @__PURE__ */ jsxRuntimeExports.jsx(Download, { className: "h-3.5 w-3.5" }) })
          ] }) })
        ] }, d.id)) })
      ] }) }) });
    })(),
    /* @__PURE__ */ jsxRuntimeExports.jsx(Dialog, { open: !!previewUrl, onOpenChange: (o) => {
      if (!o) {
        if (previewUrl) URL.revokeObjectURL(previewUrl);
        setPreviewUrl(null);
      }
    }, children: /* @__PURE__ */ jsxRuntimeExports.jsxs(DialogContent, { className: "sm:max-w-4xl p-3 sm:p-6", children: [
      /* @__PURE__ */ jsxRuntimeExports.jsx(DialogHeader, { children: /* @__PURE__ */ jsxRuntimeExports.jsx(DialogTitle, { children: "PDF Preview" }) }),
      previewUrl && /* @__PURE__ */ jsxRuntimeExports.jsx("iframe", { src: previewUrl, title: "PDF preview", className: "h-[70vh] w-full rounded-md border border-hairline" })
    ] }) })
  ] });
}
export {
  Page as component
};
