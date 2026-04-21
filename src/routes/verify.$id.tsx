import { createFileRoute } from "@tanstack/react-router";
import { useEffect, useState } from "react";
import { publicVerify, type VerifyResult } from "@/lib/verify.functions";
import { formatDate, formatMoney } from "@/lib/calc";
import { ShieldCheck, ShieldAlert, ShieldX, Loader2 } from "lucide-react";
import squirrellLogo from "@/assets/squirrell-logo.png";

type Search = { sig?: string; h?: string };

export const Route = createFileRoute("/verify/$id")({
  validateSearch: (s: Record<string, unknown>): Search => ({
    sig: typeof s.sig === "string" ? s.sig : undefined,
    h: typeof s.h === "string" ? s.h : undefined,
  }),
  head: () => ({
    meta: [
      { title: "Verify Document — Squirrellabs" },
      { name: "description", content: "Verify the authenticity of a Squirrellabs invoice or quotation." },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: VerifyPage,
});

function VerifyPage() {
  const { id } = Route.useParams();
  const { sig, h } = Route.useSearch();
  const [result, setResult] = useState<VerifyResult | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let alive = true;
    (async () => {
      if (!sig || !h) {
        if (alive) { setResult({ status: "invalid_signature" }); setLoading(false); }
        return;
      }
      try {
        const r = await publicVerify({ data: { id, sig, hash: h } });
        if (alive) setResult(r);
      } catch {
        if (alive) setResult({ status: "invalid_signature" });
      } finally {
        if (alive) setLoading(false);
      }
    })();
    return () => { alive = false; };
  }, [id, sig, h]);

  return (
    <div className="min-h-screen bg-background text-foreground flex flex-col">
      <header className="border-b border-hairline">
        <div className="mx-auto flex h-14 max-w-3xl items-center gap-2 px-6">
          <img src={squirrellLogo} alt="Squirrell" className="h-8 w-auto" />
          <span className="text-[10px] uppercase tracking-[0.25em] text-muted-foreground">Document Verification</span>
        </div>
      </header>
      <main className="mx-auto w-full max-w-2xl flex-1 px-6 py-16">
        {loading ? (
          <div className="flex items-center gap-2 text-sm text-muted-foreground">
            <Loader2 className="h-4 w-4 animate-spin" /> Verifying…
          </div>
        ) : (
          <ResultCard result={result!} />
        )}
        <p className="mt-12 text-[11px] uppercase tracking-[0.2em] text-muted-foreground">
          This page confirms a document was issued by Squirrellabs and has not been altered.
        </p>
      </main>
    </div>
  );
}

function ResultCard({ result }: { result: VerifyResult }) {
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
        <dl className="mt-8 grid grid-cols-2 gap-y-4 text-sm">
          <Row label="Issuer" value={result.issuer} />
          <Row label="Type" value={result.doc_type === "invoice" ? "Invoice" : "Quotation"} />
          <Row label="Document №" value={<span className="font-mono">{result.doc_number}</span>} />
          <Row label="Issue date" value={formatDate(result.issue_date)} />
          <Row label="Billed to" value={result.client_company} />
          <Row label="Total" value={<span className="tabular">{formatMoney(result.total)}</span>} />
        </dl>
      </div>
    );
  }
  if (result.status === "tampered") {
    return (
      <Warn icon={<ShieldAlert className="h-5 w-5" />} tone="amber" title="Document was modified" body={result.reason} />
    );
  }
  if (result.status === "not_found") {
    return <Warn icon={<ShieldX className="h-5 w-5" />} tone="red" title="Document not found" body="No matching document is on file." />;
  }
  return <Warn icon={<ShieldX className="h-5 w-5" />} tone="red" title="Invalid verification link" body="This link is malformed or wasn't issued by Squirrellabs." />;
}

function Row({ label, value }: { label: string; value: React.ReactNode }) {
  return (
    <>
      <dt className="text-muted-foreground">{label}</dt>
      <dd className="text-right">{value}</dd>
    </>
  );
}

function Warn({ icon, tone, title, body }: { icon: React.ReactNode; tone: "amber" | "red"; title: string; body: string }) {
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
    </div>
  );
}
