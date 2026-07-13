import { r as reactExports, j as jsxRuntimeExports } from "../_libs/react.mjs";
import { p as publicVerify } from "./verify.functions-f03lAinK.mjs";
import { g as Route$h, h as useServerFn, i as getDocumentIssuerBrand } from "./router-BDMLDL80.mjs";
import { a as formatDate, f as formatMoney } from "./calc-BF6zAv6d.mjs";
import "./index.mjs";
import "../_libs/seroval.mjs";
import "../_libs/sonner.mjs";
import "../_libs/qrcode.mjs";
import { B as Building2, h as LoaderCircle, i as ShieldCheck, j as ShieldAlert, k as ShieldX } from "../_libs/lucide-react.mjs";
import "./auth-middleware-DJP7Badx.mjs";
import "../_libs/supabase__supabase-js.mjs";
import "../_libs/supabase__postgrest-js.mjs";
import "../_libs/supabase__realtime-js.mjs";
import "../_libs/supabase__phoenix.mjs";
import "../_libs/supabase__storage-js.mjs";
import "../_libs/iceberg-js.mjs";
import "../_libs/supabase__auth-js.mjs";
import "tslib";
import "../_libs/supabase__functions-js.mjs";
import "./createMiddleware-BvN2ghIY.mjs";
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
function VerifyPage() {
  const {
    id
  } = Route$h.useParams();
  const {
    sig,
    h
  } = Route$h.useSearch();
  const [result, setResult] = reactExports.useState(null);
  const [issuer, setIssuer] = reactExports.useState(null);
  const [loading, setLoading] = reactExports.useState(true);
  const getIssuer = useServerFn(getDocumentIssuerBrand);
  reactExports.useEffect(() => {
    let alive = true;
    (async () => {
      if (!sig || !h) {
        if (alive) {
          setResult({
            status: "invalid_signature"
          });
          setLoading(false);
        }
        return;
      }
      try {
        const [r, b] = await Promise.all([publicVerify({
          data: {
            id,
            sig,
            hash: h
          }
        }), getIssuer({
          data: {
            id
          }
        }).catch(() => null)]);
        if (alive) {
          setResult(r);
          setIssuer(b);
        }
      } catch {
        if (alive) setResult({
          status: "invalid_signature"
        });
      } finally {
        if (alive) setLoading(false);
      }
    })();
    return () => {
      alive = false;
    };
  }, [id, sig, h, getIssuer]);
  const issuerName = issuer?.name ?? (result?.status === "authentic" ? result.issuer : "the issuer");
  return /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "min-h-screen bg-background text-foreground flex flex-col", children: [
    /* @__PURE__ */ jsxRuntimeExports.jsx("header", { className: "border-b border-hairline", children: /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "mx-auto flex h-14 max-w-3xl items-center gap-3 px-6", children: [
      issuer?.logo_url ? /* @__PURE__ */ jsxRuntimeExports.jsx("img", { src: issuer.logo_url, alt: issuer.name, className: "h-8 w-auto" }) : /* @__PURE__ */ jsxRuntimeExports.jsx(Building2, { className: "h-5 w-5" }),
      /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: "text-sm font-medium truncate", children: issuer?.name ?? "Document" }),
      /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: "ml-auto text-[10px] uppercase tracking-[0.25em] text-muted-foreground", children: "Verification" })
    ] }) }),
    /* @__PURE__ */ jsxRuntimeExports.jsxs("main", { className: "mx-auto w-full max-w-2xl flex-1 px-6 py-16", children: [
      loading ? /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "flex items-center gap-2 text-sm text-muted-foreground", children: [
        /* @__PURE__ */ jsxRuntimeExports.jsx(LoaderCircle, { className: "h-4 w-4 animate-spin" }),
        " Verifying…"
      ] }) : /* @__PURE__ */ jsxRuntimeExports.jsx(ResultCard, { result, issuerName }),
      /* @__PURE__ */ jsxRuntimeExports.jsxs("p", { className: "mt-12 text-[11px] uppercase tracking-[0.2em] text-muted-foreground", children: [
        "This page confirms a document was issued by ",
        issuerName,
        " and has not been altered."
      ] })
    ] })
  ] });
}
function ResultCard({
  result,
  issuerName
}) {
  if (result.status === "authentic") {
    return /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "rounded-2xl border border-hairline bg-card p-8", children: [
      /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "flex items-center gap-3", children: [
        /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "flex h-10 w-10 items-center justify-center rounded-full bg-emerald-500/10 text-emerald-500", children: /* @__PURE__ */ jsxRuntimeExports.jsx(ShieldCheck, { className: "h-5 w-5" }) }),
        /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { children: [
          /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "text-[11px] uppercase tracking-[0.2em] text-emerald-500", children: "Authentic" }),
          /* @__PURE__ */ jsxRuntimeExports.jsx("h1", { className: "text-xl font-semibold tracking-tight", children: "Document verified" })
        ] })
      ] }),
      /* @__PURE__ */ jsxRuntimeExports.jsxs("dl", { className: "mt-8 grid grid-cols-[auto_1fr] gap-x-4 gap-y-3 text-sm sm:grid-cols-2 sm:gap-y-4", children: [
        /* @__PURE__ */ jsxRuntimeExports.jsx(Row, { label: "Issuer", value: result.issuer }),
        /* @__PURE__ */ jsxRuntimeExports.jsx(Row, { label: "Type", value: result.doc_type === "invoice" ? "Invoice" : result.doc_type === "credit_note" ? "Credit Note" : result.doc_type === "debit_note" ? "Debit Note" : result.doc_type === "receipt" ? "Receipt" : "Quotation" }),
        /* @__PURE__ */ jsxRuntimeExports.jsx(Row, { label: "Document №", value: /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: "font-mono", children: result.doc_number }) }),
        /* @__PURE__ */ jsxRuntimeExports.jsx(Row, { label: "Issue date", value: formatDate(result.issue_date) }),
        /* @__PURE__ */ jsxRuntimeExports.jsx(Row, { label: result.doc_type === "invoice" || result.doc_type === "credit_note" ? "Due date" : "Valid until", value: result.due_date ? formatDate(result.due_date) : "—" }),
        /* @__PURE__ */ jsxRuntimeExports.jsx(Row, { label: "Billed to", value: result.client_company }),
        /* @__PURE__ */ jsxRuntimeExports.jsx(Row, { label: "Subtotal", value: /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: "tabular", children: formatMoney(result.subtotal) }) }),
        /* @__PURE__ */ jsxRuntimeExports.jsx(Row, { label: `Tax (${result.tax_rate}%)`, value: /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: "tabular", children: formatMoney(result.tax_amount) }) }),
        /* @__PURE__ */ jsxRuntimeExports.jsx(Row, { label: "Total", value: /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: "tabular font-semibold", children: formatMoney(result.total) }) })
      ] })
    ] });
  }
  if (result.status === "tampered") {
    return /* @__PURE__ */ jsxRuntimeExports.jsx(Warn, { icon: /* @__PURE__ */ jsxRuntimeExports.jsx(ShieldAlert, { className: "h-5 w-5" }), tone: "amber", title: "This document has been modified", body: `The contents of this PDF no longer match what ${issuerName} originally issued. Someone may have edited the totals, line items, dates, or client details after it was sent.`, nextSteps: ["Do not pay or act on this document.", `Contact ${issuerName} directly to request a fresh, signed copy.`, `Compare the document number on the PDF with what your contact at ${issuerName} has on file.`], reason: result.reason });
  }
  if (result.status === "not_found") {
    return /* @__PURE__ */ jsxRuntimeExports.jsx(Warn, { icon: /* @__PURE__ */ jsxRuntimeExports.jsx(ShieldX, { className: "h-5 w-5" }), tone: "red", title: "No matching document found", body: "We couldn't find a document with this ID. It may have been deleted, or the link may belong to a different system.", nextSteps: ["Check that you opened the link from the original PDF — not a forwarded screenshot.", "Ask the sender to re-issue the document and share a fresh verification link.", "If you received this from someone claiming to be the issuer, treat it as suspicious."] });
  }
  return /* @__PURE__ */ jsxRuntimeExports.jsx(Warn, { icon: /* @__PURE__ */ jsxRuntimeExports.jsx(ShieldX, { className: "h-5 w-5" }), tone: "red", title: "Invalid verification link", body: "This link is missing its signature, has been altered, or wasn't issued by this system. We can't confirm the authenticity of any document from it.", nextSteps: ["Re-open the link directly from the original PDF or QR code — copy/paste can drop characters.", "If the link came from an email, check it wasn't truncated by your mail client.", "Ask the sender to re-share the verification link from the original document."] });
}
function Row({
  label,
  value
}) {
  return /* @__PURE__ */ jsxRuntimeExports.jsxs(jsxRuntimeExports.Fragment, { children: [
    /* @__PURE__ */ jsxRuntimeExports.jsx("dt", { className: "text-muted-foreground", children: label }),
    /* @__PURE__ */ jsxRuntimeExports.jsx("dd", { className: "text-right", children: value })
  ] });
}
function Warn({
  icon,
  tone,
  title,
  body,
  nextSteps,
  reason
}) {
  const cls = tone === "amber" ? "bg-amber-500/10 text-amber-500" : "bg-red-500/10 text-red-500";
  const label = tone === "amber" ? "text-amber-500" : "text-red-500";
  return /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "rounded-2xl border border-hairline bg-card p-8", children: [
    /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "flex items-center gap-3", children: [
      /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: `flex h-10 w-10 items-center justify-center rounded-full ${cls}`, children: icon }),
      /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { children: [
        /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: `text-[11px] uppercase tracking-[0.2em] ${label}`, children: "Warning" }),
        /* @__PURE__ */ jsxRuntimeExports.jsx("h1", { className: "text-xl font-semibold tracking-tight", children: title })
      ] })
    ] }),
    /* @__PURE__ */ jsxRuntimeExports.jsx("p", { className: "mt-6 text-sm text-muted-foreground", children: body }),
    reason && /* @__PURE__ */ jsxRuntimeExports.jsxs("p", { className: "mt-3 rounded-md border border-hairline bg-muted/30 px-3 py-2 text-xs text-muted-foreground", children: [
      /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: "font-medium text-foreground", children: "Detail:" }),
      " ",
      reason
    ] }),
    nextSteps && nextSteps.length > 0 && /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "mt-6", children: [
      /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "text-[11px] uppercase tracking-[0.2em] text-muted-foreground", children: "What to do next" }),
      /* @__PURE__ */ jsxRuntimeExports.jsx("ul", { className: "mt-3 space-y-2 text-sm", children: nextSteps.map((step, i) => /* @__PURE__ */ jsxRuntimeExports.jsxs("li", { className: "flex gap-2", children: [
        /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: "mt-2 h-1 w-1 shrink-0 rounded-full bg-foreground/60" }),
        /* @__PURE__ */ jsxRuntimeExports.jsx("span", { children: step })
      ] }, i)) })
    ] })
  ] });
}
export {
  VerifyPage as component
};
