import { createFileRoute } from "@tanstack/react-router";
import { useEffect, useState } from "react";
import { publicVerify, type VerifyResult } from "@/lib/verify.functions";
import { getDocumentIssuerBrand } from "@/lib/org.functions";
import { useServerFn } from "@tanstack/react-start";
import { formatDate, formatMoney } from "@/lib/calc";
import { ShieldCheck, ShieldAlert, ShieldX, Loader2, Building2 } from "lucide-react";

type Search = { sig?: string; h?: string };

export const Route = createFileRoute("/verify/$id")({
  validateSearch: (s: Record<string, unknown>): Search => ({
    sig: typeof s.sig === "string" ? s.sig : undefined,
    h: typeof s.h === "string" ? s.h : undefined,
  }),
  head: () => ({
    meta: [
      { title: "Verify Document" },
      { name: "description", content: "Verify the authenticity of an invoice or quotation." },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: VerifyPage,
});

type IssuerBrand = { name: string; short_name: string | null; website: string | null; logo_url: string | null } | null;

function VerifyPage() {
  const { id } = Route.useParams();
  const { sig, h } = Route.useSearch();
  const [result, setResult] = useState<VerifyResult | null>(null);
  const [issuer, setIssuer] = useState<IssuerBrand>(null);
  const [loading, setLoading] = useState(true);
  const getIssuer = useServerFn(getDocumentIssuerBrand);

  useEffect(() => {
    let alive = true;
    (async () => {
      if (!sig || !h) {
        if (alive) { setResult({ status: "invalid_signature" }); setLoading(false); }
        return;
      }
      try {
        const [r, b] = await Promise.all([
          publicVerify({ data: { id, sig, hash: h } }),
          getIssuer({ data: { id } }).catch(() => null),
        ]);
        if (alive) { setResult(r); setIssuer(b); }
      } catch {
        if (alive) setResult({ status: "invalid_signature" });
      } finally {
        if (alive) setLoading(false);
      }
    })();
    return () => { alive = false; };
  }, [id, sig, h, getIssuer]);

  const issuerName = issuer?.name ?? (result?.status === "authentic" ? result.issuer : "the issuer");

  return (
    <div className="min-h-screen bg-background text-foreground flex flex-col">
      <header className="border-b border-hairline">
        <div className="mx-auto flex h-14 max-w-3xl items-center gap-3 px-6">
          {issuer?.logo_url ? (
            <img src={issuer.logo_url} alt={issuer.name} className="h-8 w-auto" />
          ) : (
            <Building2 className="h-5 w-5" />
          )}
          <span className="text-sm font-medium truncate">{issuer?.name ?? "Document"}</span>
          <span className="ml-auto text-[10px] uppercase tracking-[0.25em] text-muted-foreground">Verification</span>
        </div>
      </header>
      <main className="mx-auto w-full max-w-2xl flex-1 px-6 py-16">
        {loading ? (
          <div className="flex items-center gap-2 text-sm text-muted-foreground">
            <Loader2 className="h-4 w-4 animate-spin" /> Verifying…
          </div>
        ) : (
          <ResultCard result={result!} issuerName={issuerName} />
        )}
        <p className="mt-12 text-[11px] uppercase tracking-[0.2em] text-muted-foreground">
          This page confirms a document was issued by {issuerName} and has not been altered.
        </p>
      </main>
    </div>
  );
}

function ResultCard({ result, issuerName }: { result: VerifyResult; issuerName: string }) {
  if (result.status === "authentic") {
    return (
      <div className="rounded-2xl border border-hairline bg-card p-8">
        <div className="flex items-center gap-3">
          <div className="flex h-10 w-10 items-center justify-center rounded-full bg-emerald-500/10 text-emerald-500">
            <ShieldCheck className="h-5 w-5" />
          </div>
          <div>
            <div className="text-[11px] uppercase tracking-[0.2em] text-emerald-500">Authentic</div>
            <h1 className="text-xl font-semibold tracking-tight">Document verified</h1>
          </div>
        </div>
        <dl className="mt-8 grid grid-cols-[auto_1fr] gap-x-4 gap-y-3 text-sm sm:grid-cols-2 sm:gap-y-4">
          <Row label="Issuer" value={result.issuer} />
          <Row label="Type" value={result.doc_type === "invoice" ? "Invoice" : result.doc_type === "credit_note" ? "Credit Note" : result.doc_type === "debit_note" ? "Debit Note" : result.doc_type === "receipt" ? "Receipt" : "Quotation"} />
          <Row label="Document №" value={<span className="font-mono">{result.doc_number}</span>} />
          <Row label="Issue date" value={formatDate(result.issue_date)} />
          <Row
            label={result.doc_type === "invoice" || result.doc_type === "credit_note" ? "Due date" : "Valid until"}
            value={result.due_date ? formatDate(result.due_date) : "—"}
          />
          <Row label="Billed to" value={result.client_company} />
          <Row label="Subtotal" value={<span className="tabular">{formatMoney(result.subtotal)}</span>} />
          <Row label={`Tax (${result.tax_rate}%)`} value={<span className="tabular">{formatMoney(result.tax_amount)}</span>} />
          <Row label="Total" value={<span className="tabular font-semibold">{formatMoney(result.total)}</span>} />
        </dl>
      </div>
    );
  }
  if (result.status === "tampered") {
    return (
      <Warn
        icon={<ShieldAlert className="h-5 w-5" />}
        tone="amber"
        title="This document has been modified"
        body={`The contents of this PDF no longer match what ${issuerName} originally issued. Someone may have edited the totals, line items, dates, or client details after it was sent.`}
        nextSteps={[
          "Do not pay or act on this document.",
          `Contact ${issuerName} directly to request a fresh, signed copy.`,
          `Compare the document number on the PDF with what your contact at ${issuerName} has on file.`,
        ]}
        reason={result.reason}
      />
    );
  }
  if (result.status === "not_found") {
    return (
      <Warn
        icon={<ShieldX className="h-5 w-5" />}
        tone="red"
        title="No matching document found"
        body="We couldn't find a document with this ID. It may have been deleted, or the link may belong to a different system."
        nextSteps={[
          "Check that you opened the link from the original PDF — not a forwarded screenshot.",
          "Ask the sender to re-issue the document and share a fresh verification link.",
          "If you received this from someone claiming to be the issuer, treat it as suspicious.",
        ]}
      />
    );
  }
  return (
    <Warn
      icon={<ShieldX className="h-5 w-5" />}
      tone="red"
      title="Invalid verification link"
      body="This link is missing its signature, has been altered, or wasn't issued by this system. We can't confirm the authenticity of any document from it."
      nextSteps={[
        "Re-open the link directly from the original PDF or QR code — copy/paste can drop characters.",
        "If the link came from an email, check it wasn't truncated by your mail client.",
        "Ask the sender to re-share the verification link from the original document.",
      ]}
    />
  );
}

function Row({ label, value }: { label: string; value: React.ReactNode }) {
  return (
    <>
      <dt className="text-muted-foreground">{label}</dt>
      <dd className="text-right">{value}</dd>
    </>
  );
}

function Warn({
  icon,
  tone,
  title,
  body,
  nextSteps,
  reason,
}: {
  icon: React.ReactNode;
  tone: "amber" | "red";
  title: string;
  body: string;
  nextSteps?: string[];
  reason?: string;
}) {
  const cls = tone === "amber" ? "bg-amber-500/10 text-amber-500" : "bg-red-500/10 text-red-500";
  const label = tone === "amber" ? "text-amber-500" : "text-red-500";
  return (
    <div className="rounded-2xl border border-hairline bg-card p-8">
      <div className="flex items-center gap-3">
        <div className={`flex h-10 w-10 items-center justify-center rounded-full ${cls}`}>{icon}</div>
        <div>
          <div className={`text-[11px] uppercase tracking-[0.2em] ${label}`}>Warning</div>
          <h1 className="text-xl font-semibold tracking-tight">{title}</h1>
        </div>
      </div>
      <p className="mt-6 text-sm text-muted-foreground">{body}</p>
      {reason && (
        <p className="mt-3 rounded-md border border-hairline bg-muted/30 px-3 py-2 text-xs text-muted-foreground">
          <span className="font-medium text-foreground">Detail:</span> {reason}
        </p>
      )}
      {nextSteps && nextSteps.length > 0 && (
        <div className="mt-6">
          <div className="text-[11px] uppercase tracking-[0.2em] text-muted-foreground">What to do next</div>
          <ul className="mt-3 space-y-2 text-sm">
            {nextSteps.map((step, i) => (
              <li key={i} className="flex gap-2">
                <span className="mt-2 h-1 w-1 shrink-0 rounded-full bg-foreground/60" />
                <span>{step}</span>
              </li>
            ))}
          </ul>
        </div>
      )}
    </div>
  );
}
