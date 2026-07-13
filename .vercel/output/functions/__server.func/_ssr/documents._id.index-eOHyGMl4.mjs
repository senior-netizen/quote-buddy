import { j as jsxRuntimeExports, r as reactExports } from "../_libs/react.mjs";
import { e as useNavigate, L as Link } from "../_libs/tanstack__react-router.mjs";
import { u as useQuery, a as useMutation } from "../_libs/tanstack__react-query.mjs";
import { x as Route$a, a as useActiveOrg, h as useServerFn, B as Button, D as Dialog, c as DialogContent, d as DialogHeader, e as DialogTitle, p as profileToBrand } from "./router-BDMLDL80.mjs";
import { R as RequireAuth, A as AppShell } from "./AppShell-DM6M-RSe.mjs";
import { s as supabase } from "./client-U3FzjMwq.mjs";
import { a as formatDate, f as formatMoney, r as rowTotal } from "./calc-BF6zAv6d.mjs";
import { b as getDocumentTypeLabel, i as isFiscalDocumentType, c as getDueDateLabel, g as getDocumentTypePrefix } from "./docTypes-CsATll0j.mjs";
import { t as toast } from "../_libs/sonner.mjs";
import { i as issueVerifyToken } from "./verify.functions-f03lAinK.mjs";
import { o as openPdfPreview, d as downloadPdf } from "./pdf-DAix565a.mjs";
import { g as getFiscalConfig, s as submitInvoiceToZimra } from "./fiscal.functions-CwD_knTK.mjs";
import "./index.mjs";
import "../_libs/seroval.mjs";
import "../_libs/qrcode.mjs";
import "../_libs/pdfmake.mjs";
import { p as ArrowLeft, R as Repeat, q as Receipt, f as Pencil, i as ShieldCheck, E as Eye, D as Download } from "../_libs/lucide-react.mjs";
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
import "tslib";
import "../_libs/react-remove-scroll-bar.mjs";
import "../_libs/react-style-singleton.mjs";
import "../_libs/get-nonce.mjs";
import "../_libs/use-sidecar.mjs";
import "../_libs/use-callback-ref.mjs";
import "../_libs/aria-hidden.mjs";
import "./auth-middleware-DJP7Badx.mjs";
import "../_libs/supabase__supabase-js.mjs";
import "../_libs/supabase__postgrest-js.mjs";
import "../_libs/supabase__realtime-js.mjs";
import "../_libs/supabase__phoenix.mjs";
import "../_libs/supabase__storage-js.mjs";
import "../_libs/iceberg-js.mjs";
import "../_libs/supabase__auth-js.mjs";
import "../_libs/supabase__functions-js.mjs";
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
async function generateDocNumber(type, orgId) {
  const prefix = getDocumentTypePrefix(type);
  const year = (/* @__PURE__ */ new Date()).getFullYear();
  const like = `${prefix}-${year}-%`;
  const { data, error } = await supabase.from("documents").select("doc_number").eq("org_id", orgId).like("doc_number", like).order("doc_number", { ascending: false }).limit(1);
  if (error) throw error;
  let next = 1;
  if (data && data.length > 0) {
    const last = data[0].doc_number;
    const seq = parseInt(last.split("-").pop() || "0", 10);
    if (!Number.isNaN(seq)) next = seq + 1;
  }
  return `${prefix}-${year}-${String(next).padStart(4, "0")}`;
}
function Page() {
  return /* @__PURE__ */ jsxRuntimeExports.jsx(RequireAuth, { children: /* @__PURE__ */ jsxRuntimeExports.jsx(AppShell, { children: /* @__PURE__ */ jsxRuntimeExports.jsx(Detail, {}) }) });
}
function Detail() {
  const {
    id
  } = Route$a.useParams();
  const navigate = useNavigate();
  const {
    data: activeOrg
  } = useActiveOrg();
  const getFiscal = useServerFn(getFiscalConfig);
  const fiscalize = useServerFn(submitInvoiceToZimra);
  const {
    data: fiscalCfg
  } = useQuery({
    queryKey: ["fiscal-config"],
    queryFn: () => getFiscal()
  });
  const [previewUrl, setPreviewUrl] = reactExports.useState(null);
  const {
    data: doc,
    isLoading,
    refetch
  } = useQuery({
    queryKey: ["doc", id],
    queryFn: async () => {
      const {
        data,
        error
      } = await supabase.from("documents").select("*, client:clients(company_name, address, email, phone)").eq("id", id).single();
      if (error) throw error;
      const {
        data: status,
        error: statusError
      } = await supabase.from("current_receipt_status").select("status, message").eq("document_id", id).maybeSingle();
      if (statusError) throw statusError;
      return {
        ...data,
        current_receipt_status: status?.status ?? "Draft",
        current_receipt_status_message: status?.message ?? null
      };
    }
  });
  const buildDocForPdf = async (d) => {
    if (!activeOrg) throw new Error("No active organization");
    const brand = await profileToBrand(activeOrg.profile);
    let verifyUrl;
    let hash;
    let sig;
    try {
      const t = await issueVerifyToken({
        data: {
          id: d.id
        }
      });
      hash = t.hash;
      sig = t.sig;
      verifyUrl = `${window.location.origin}/verify/${t.id}?sig=${encodeURIComponent(t.sig)}&h=${t.hash}`;
    } catch (e) {
      console.warn("Verify token issuance failed; generating PDF without QR", e);
    }
    return {
      doc_type: d.doc_type,
      doc_number: d.doc_number,
      issue_date: d.issue_date,
      due_date: d.due_date,
      line_items: d.line_items,
      tax_rate: Number(d.tax_rate),
      discount: Number(d.discount),
      subtotal: Number(d.subtotal),
      tax_amount: Number(d.tax_amount),
      total: Number(d.total),
      notes: d.notes,
      client: d.client ?? {
        company_name: "—",
        address: null,
        email: null,
        phone: null
      },
      brand,
      verifyUrl,
      docHash: hash,
      signatureId: sig,
      fiscal: d.current_receipt_status === "Accepted" && d.verification_code && d.receipt_global_no && d.receipt_qr_url ? {
        verificationCode: d.verification_code,
        receiptGlobalNo: d.receipt_global_no,
        receiptCounter: d.receipt_counter,
        fiscalDayNo: d.fiscal_day_no,
        deviceSerial: fiscalCfg?.device_serial ?? null,
        deviceId: fiscalCfg?.device_id ?? null,
        vatNumber: fiscalCfg?.vat_number ?? null,
        tin: fiscalCfg?.tax_payer_tin ?? null,
        receiptQrUrl: d.receipt_qr_url
      } : null
    };
  };
  const handleDownload = async () => {
    if (!doc) return;
    try {
      const payload = await buildDocForPdf(doc);
      await downloadPdf(payload);
    } catch (e) {
      toast.error(e instanceof Error ? e.message : "Download failed");
    }
  };
  const handlePreview = async () => {
    if (!doc) return;
    try {
      const payload = await buildDocForPdf(doc);
      const url = await openPdfPreview(payload);
      setPreviewUrl((prev) => {
        if (prev) URL.revokeObjectURL(prev);
        return url;
      });
    } catch (e) {
      toast.error(e instanceof Error ? e.message : "Preview failed");
    }
  };
  const handleVerify = async () => {
    if (!doc) return;
    try {
      const {
        id: docId,
        hash,
        sig
      } = await issueVerifyToken({
        data: {
          id: doc.id
        }
      });
      const url = `${window.location.origin}/verify/${docId}?sig=${encodeURIComponent(sig)}&h=${hash}`;
      window.open(url, "_blank", "noopener,noreferrer");
    } catch (e) {
      toast.error(e instanceof Error ? e.message : "Could not generate verification link");
    }
  };
  const convert = useMutation({
    mutationFn: async () => {
      if (!doc) throw new Error("No doc");
      if (!activeOrg?.org_id) throw new Error("No active organization");
      const {
        data: u
      } = await supabase.auth.getUser();
      if (!u.user) throw new Error("Not authenticated");
      const newNumber = await generateDocNumber("invoice", activeOrg.org_id);
      const {
        data,
        error
      } = await supabase.from("documents").insert({
        user_id: u.user.id,
        org_id: activeOrg.org_id,
        client_id: doc.client_id,
        doc_type: "invoice",
        doc_number: newNumber,
        issue_date: (/* @__PURE__ */ new Date()).toISOString().slice(0, 10),
        due_date: doc.due_date,
        line_items: doc.line_items,
        tax_rate: doc.tax_rate,
        discount: doc.discount,
        subtotal: doc.subtotal,
        tax_amount: doc.tax_amount,
        total: doc.total,
        notes: doc.notes,
        converted_from: doc.id
      }).select("id").single();
      if (error) throw error;
      return data.id;
    },
    onSuccess: (newId) => {
      toast.success("Converted to invoice");
      navigate({
        to: "/documents/$id",
        params: {
          id: newId
        }
      });
      refetch();
    },
    onError: (e) => toast.error(e instanceof Error ? e.message : "Conversion failed")
  });
  if (isLoading || !doc) {
    return /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "text-sm text-muted-foreground", children: "Loading…" });
  }
  return /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { children: [
    /* @__PURE__ */ jsxRuntimeExports.jsxs(Link, { to: "/documents", className: "inline-flex items-center gap-1 text-xs text-muted-foreground hover:text-foreground", children: [
      /* @__PURE__ */ jsxRuntimeExports.jsx(ArrowLeft, { className: "h-3.5 w-3.5" }),
      " All documents"
    ] }),
    /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "mt-4 flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between", children: [
      /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "min-w-0", children: [
        /* @__PURE__ */ jsxRuntimeExports.jsx("p", { className: "text-[11px] uppercase tracking-[0.2em] text-muted-foreground", children: getDocumentTypeLabel(doc.doc_type) }),
        /* @__PURE__ */ jsxRuntimeExports.jsx("h1", { className: "mt-2 font-mono text-2xl sm:text-3xl font-semibold tracking-tight break-all", children: doc.doc_number }),
        /* @__PURE__ */ jsxRuntimeExports.jsxs("p", { className: "mt-1 text-sm text-muted-foreground", children: [
          doc.client?.company_name,
          " · Issued ",
          formatDate(doc.issue_date)
        ] })
      ] }),
      /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "flex flex-wrap gap-2", children: [
        doc.doc_type === "quote" && /* @__PURE__ */ jsxRuntimeExports.jsxs(Button, { variant: "outline", className: "rounded-full", onClick: () => convert.mutate(), disabled: convert.isPending, children: [
          /* @__PURE__ */ jsxRuntimeExports.jsx(Repeat, { className: "mr-1.5 h-3.5 w-3.5" }),
          /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: "hidden sm:inline", children: convert.isPending ? "Converting…" : "Convert to Invoice" }),
          /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: "sm:hidden", children: convert.isPending ? "…" : "Convert" })
        ] }),
        isFiscalDocumentType(doc.doc_type) && fiscalCfg?.enabled && doc.current_receipt_status !== "Accepted" && /* @__PURE__ */ jsxRuntimeExports.jsxs(Button, { variant: "outline", className: "rounded-full", onClick: () => {
          toast.promise(fiscalize({
            data: {
              documentId: doc.id
            }
          }).then(() => refetch()), {
            loading: "Submitting to ZIMRA…",
            success: "Fiscalised",
            error: (e) => e instanceof Error ? e.message : "Failed"
          });
        }, children: [
          /* @__PURE__ */ jsxRuntimeExports.jsx(Receipt, { className: "mr-1.5 h-3.5 w-3.5" }),
          "Fiscalise"
        ] }),
        doc.current_receipt_status === "Accepted" && /* @__PURE__ */ jsxRuntimeExports.jsxs("span", { className: "inline-flex items-center rounded-full bg-green-100 px-3 py-1 text-xs text-green-800", children: [
          "ZIMRA · ",
          doc.verification_code
        ] }),
        /* @__PURE__ */ jsxRuntimeExports.jsx(Link, { to: "/documents/$id/edit", params: {
          id: doc.id
        }, children: /* @__PURE__ */ jsxRuntimeExports.jsxs(Button, { variant: "outline", className: "rounded-full", children: [
          /* @__PURE__ */ jsxRuntimeExports.jsx(Pencil, { className: "mr-1.5 h-3.5 w-3.5" }),
          "Edit"
        ] }) }),
        /* @__PURE__ */ jsxRuntimeExports.jsxs(Button, { variant: "outline", className: "rounded-full", onClick: handleVerify, children: [
          /* @__PURE__ */ jsxRuntimeExports.jsx(ShieldCheck, { className: "mr-1.5 h-3.5 w-3.5" }),
          /* @__PURE__ */ jsxRuntimeExports.jsxs("span", { className: "hidden sm:inline", children: [
            "Verify ",
            getDocumentTypeLabel(doc.doc_type)
          ] }),
          /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: "sm:hidden", children: "Verify" })
        ] }),
        /* @__PURE__ */ jsxRuntimeExports.jsxs(Button, { variant: "outline", className: "rounded-full", onClick: handlePreview, children: [
          /* @__PURE__ */ jsxRuntimeExports.jsx(Eye, { className: "mr-1.5 h-3.5 w-3.5" }),
          "Preview"
        ] }),
        /* @__PURE__ */ jsxRuntimeExports.jsxs(Button, { className: "rounded-full", onClick: handleDownload, children: [
          /* @__PURE__ */ jsxRuntimeExports.jsx(Download, { className: "mr-1.5 h-3.5 w-3.5" }),
          /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: "hidden sm:inline", children: "Download PDF" }),
          /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: "sm:hidden", children: "PDF" })
        ] })
      ] })
    ] }),
    /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "mt-8 sm:mt-10 grid grid-cols-1 gap-6 lg:grid-cols-[1fr_320px] lg:gap-10", children: [
      /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "min-w-0 rounded-2xl border border-hairline bg-card p-5 sm:p-8", children: [
        /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "grid grid-cols-1 gap-6 sm:grid-cols-2 sm:gap-8 text-sm", children: [
          /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { children: [
            /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "text-[11px] uppercase tracking-[0.2em] text-muted-foreground", children: "Billed to" }),
            /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "mt-2 font-medium", children: doc.client?.company_name }),
            doc.client?.address && /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "text-muted-foreground whitespace-pre-line", children: doc.client.address }),
            doc.client?.email && /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "text-muted-foreground break-all", children: doc.client.email }),
            doc.client?.phone && /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "text-muted-foreground", children: doc.client.phone })
          ] }),
          /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "sm:text-right", children: [
            /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "text-[11px] uppercase tracking-[0.2em] text-muted-foreground", children: getDueDateLabel(doc.doc_type) === "Due date" ? "Due" : "Valid until" }),
            /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "mt-2", children: doc.due_date ? formatDate(doc.due_date) : "—" })
          ] })
        ] }),
        /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "mt-8 sm:mt-10 -mx-5 sm:mx-0 overflow-x-auto", children: /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "min-w-[480px] px-5 sm:px-0", children: [
          /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "grid grid-cols-[1fr_60px_120px_120px] gap-2 border-b border-foreground pb-2 text-[11px] uppercase tracking-wider text-muted-foreground", children: [
            /* @__PURE__ */ jsxRuntimeExports.jsx("div", { children: "Description" }),
            /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "text-right", children: "Qty" }),
            /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "text-right", children: "Unit" }),
            /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "text-right", children: "Amount" })
          ] }),
          doc.line_items.map((it, i) => /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "grid grid-cols-[1fr_60px_120px_120px] gap-2 border-b border-hairline py-3 text-sm", children: [
            /* @__PURE__ */ jsxRuntimeExports.jsx("div", { children: it.description }),
            /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "text-right tabular", children: it.quantity }),
            /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "text-right tabular", children: formatMoney(it.unit_price) }),
            /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "text-right tabular", children: formatMoney(rowTotal(it)) })
          ] }, i))
        ] }) }),
        /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "mt-6 flex justify-end", children: /* @__PURE__ */ jsxRuntimeExports.jsxs("dl", { className: "w-full sm:w-72 space-y-2 text-sm", children: [
          /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "flex justify-between", children: [
            /* @__PURE__ */ jsxRuntimeExports.jsx("dt", { className: "text-muted-foreground", children: "Subtotal" }),
            /* @__PURE__ */ jsxRuntimeExports.jsx("dd", { className: "tabular", children: formatMoney(Number(doc.subtotal)) })
          ] }),
          /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "flex justify-between", children: [
            /* @__PURE__ */ jsxRuntimeExports.jsxs("dt", { className: "text-muted-foreground", children: [
              "Tax (",
              doc.tax_rate,
              "%)"
            ] }),
            /* @__PURE__ */ jsxRuntimeExports.jsx("dd", { className: "tabular", children: formatMoney(Number(doc.tax_amount)) })
          ] }),
          Number(doc.discount) > 0 && /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "flex justify-between", children: [
            /* @__PURE__ */ jsxRuntimeExports.jsx("dt", { className: "text-muted-foreground", children: "Discount" }),
            /* @__PURE__ */ jsxRuntimeExports.jsxs("dd", { className: "tabular", children: [
              "− ",
              formatMoney(Number(doc.discount))
            ] })
          ] }),
          /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "mt-2 flex items-baseline justify-between border-t border-foreground pt-3", children: [
            /* @__PURE__ */ jsxRuntimeExports.jsx("dt", { className: "font-medium", children: "Total" }),
            /* @__PURE__ */ jsxRuntimeExports.jsx("dd", { className: "text-xl font-semibold tracking-tight tabular", children: formatMoney(Number(doc.total)) })
          ] })
        ] }) }),
        doc.notes && /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "mt-8 border-t border-hairline pt-6", children: [
          /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "text-[11px] uppercase tracking-[0.2em] text-muted-foreground", children: "Notes" }),
          /* @__PURE__ */ jsxRuntimeExports.jsx("p", { className: "mt-2 text-sm whitespace-pre-line", children: doc.notes })
        ] })
      ] }),
      /* @__PURE__ */ jsxRuntimeExports.jsxs("aside", { className: "space-y-4", children: [
        isFiscalDocumentType(doc.doc_type) && fiscalCfg?.enabled && /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "rounded-2xl border border-hairline bg-card p-6", children: [
          /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "text-[11px] uppercase tracking-[0.2em] text-muted-foreground", children: "Fiscal receipt state" }),
          /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "mt-2 flex items-center gap-2", children: /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: "inline-flex rounded-full bg-muted px-3 py-1 text-sm font-medium", children: doc.current_receipt_status }) }),
          doc.current_receipt_status_message && /* @__PURE__ */ jsxRuntimeExports.jsx("p", { className: "mt-3 text-xs text-muted-foreground", children: doc.current_receipt_status_message }),
          doc.fiscal_error && doc.current_receipt_status === "Rejected" && /* @__PURE__ */ jsxRuntimeExports.jsx("p", { className: "mt-3 text-xs text-destructive", children: doc.fiscal_error })
        ] }),
        /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "rounded-2xl border border-hairline bg-card p-6", children: [
          /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "text-[11px] uppercase tracking-[0.2em] text-muted-foreground", children: "Total" }),
          /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "mt-2 text-3xl font-semibold tracking-tight tabular", children: formatMoney(Number(doc.total)) })
        ] })
      ] })
    ] }),
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
