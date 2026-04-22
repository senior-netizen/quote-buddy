import { createFileRoute, useNavigate, Link } from "@tanstack/react-router";
import { useQuery, useMutation } from "@tanstack/react-query";
import { useState } from "react";
import { RequireAuth } from "@/components/RequireAuth";
import { AppShell } from "@/components/AppShell";
import { supabase } from "@/integrations/supabase/client";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { formatDate, formatMoney, rowTotal, type LineItem } from "@/lib/calc";
import { generateDocNumber } from "@/lib/docNumber";
import { toast } from "sonner";
import { ArrowLeft, Download, Eye, Repeat, ShieldCheck } from "lucide-react";
import { issueVerifyToken } from "@/lib/verify.functions";

export const Route = createFileRoute("/documents/$id")({ component: Page });

function Page() {
  return (
    <RequireAuth>
      <AppShell>
        <Detail />
      </AppShell>
    </RequireAuth>
  );
}

type DocFull = {
  id: string;
  doc_type: "quote" | "invoice";
  doc_number: string;
  issue_date: string;
  due_date: string | null;
  line_items: LineItem[];
  tax_rate: number;
  discount: number;
  subtotal: number;
  tax_amount: number;
  total: number;
  notes: string | null;
  client_id: string;
  client: { company_name: string; address: string | null; email: string | null; phone: string | null } | null;
};

function Detail() {
  const { id } = Route.useParams();
  const navigate = useNavigate();
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);

  const { data: doc, isLoading, refetch } = useQuery({
    queryKey: ["doc", id],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("documents")
        .select("*, client:clients(company_name, address, email, phone)")
        .eq("id", id)
        .single();
      if (error) throw error;
      return data as unknown as DocFull;
    },
  });

  /** Build the structured server URL for the document. */
  const buildServerUrl = (d: DocFull, preview: boolean, token: string) => {
    const year = d.issue_date.slice(0, 4);
    const type = d.doc_type === "invoice" ? "invoices" : "quotes";
    const qs = new URLSearchParams({ token });
    if (preview) qs.set("preview", "1");
    return `/api/documents/${year}/${type}/${d.id}.pdf?${qs.toString()}`;
  };

  /** Fetch the PDF from the server route as a blob, using the user's auth token. */
  const fetchPdfBlob = async (d: DocFull, preview: boolean): Promise<Blob> => {
    const { data: sess } = await supabase.auth.getSession();
    const token = sess.session?.access_token;
    if (!token) throw new Error("Not authenticated");
    const res = await fetch(buildServerUrl(d, preview, token), {
      headers: { Authorization: `Bearer ${token}` },
    });
    if (!res.ok) throw new Error(`Failed (${res.status})`);
    return await res.blob();
  };

  const handleDownload = async () => {
    if (!doc) return;
    try {
      const blob = await fetchPdfBlob(doc, false);
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = `${doc.doc_number}.pdf`;
      document.body.appendChild(a);
      a.click();
      a.remove();
      setTimeout(() => URL.revokeObjectURL(url), 1000);
    } catch (e) {
      toast.error(e instanceof Error ? e.message : "Download failed");
    }
  };

  const handlePreview = async () => {
    if (!doc) return;
    try {
      const blob = await fetchPdfBlob(doc, true);
      const url = URL.createObjectURL(blob);
      // Revoke any prior preview URL
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
      const { id: docId, hash, sig } = await issueVerifyToken({ data: { id: doc.id } });
      const url = `${window.location.origin}/verify/${docId}?sig=${encodeURIComponent(sig)}&h=${hash}`;
      window.open(url, "_blank", "noopener,noreferrer");
    } catch (e) {
      toast.error(e instanceof Error ? e.message : "Could not generate verification link");
    }
  };

  const convert = useMutation({
    mutationFn: async () => {
      if (!doc) throw new Error("No doc");
      const { data: u } = await supabase.auth.getUser();
      if (!u.user) throw new Error("Not authenticated");
      const newNumber = await generateDocNumber("invoice");
      const { data, error } = await supabase
        .from("documents")
        .insert({
          user_id: u.user.id,
          client_id: doc.client_id,
          doc_type: "invoice",
          doc_number: newNumber,
          issue_date: new Date().toISOString().slice(0, 10),
          due_date: doc.due_date,
          line_items: doc.line_items as unknown as never,
          tax_rate: doc.tax_rate,
          discount: doc.discount,
          subtotal: doc.subtotal,
          tax_amount: doc.tax_amount,
          total: doc.total,
          notes: doc.notes,
          converted_from: doc.id,
        })
        .select("id")
        .single();
      if (error) throw error;
      return data.id as string;
    },
    onSuccess: (newId) => {
      toast.success("Converted to invoice");
      navigate({ to: "/documents/$id", params: { id: newId } });
      refetch();
    },
    onError: (e) => toast.error(e instanceof Error ? e.message : "Conversion failed"),
  });

  if (isLoading || !doc) {
    return <div className="text-sm text-muted-foreground">Loading…</div>;
  }

  return (
    <div>
      <Link to="/documents" className="inline-flex items-center gap-1 text-xs text-muted-foreground hover:text-foreground">
        <ArrowLeft className="h-3.5 w-3.5" /> All documents
      </Link>

      <div className="mt-4 flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
        <div className="min-w-0">
          <p className="text-[11px] uppercase tracking-[0.2em] text-muted-foreground">
            {doc.doc_type === "quote" ? "Quotation" : "Invoice"}
          </p>
          <h1 className="mt-2 font-mono text-2xl sm:text-3xl font-semibold tracking-tight break-all">{doc.doc_number}</h1>
          <p className="mt-1 text-sm text-muted-foreground">
            {doc.client?.company_name} · Issued {formatDate(doc.issue_date)}
          </p>
        </div>
        <div className="flex flex-wrap gap-2">
          {doc.doc_type === "quote" && (
            <Button variant="outline" className="rounded-full" onClick={() => convert.mutate()} disabled={convert.isPending}>
              <Repeat className="mr-1.5 h-3.5 w-3.5" />
              <span className="hidden sm:inline">{convert.isPending ? "Converting…" : "Convert to Invoice"}</span>
              <span className="sm:hidden">{convert.isPending ? "…" : "Convert"}</span>
            </Button>
          )}
          <Button variant="outline" className="rounded-full" onClick={handleVerify}>
            <ShieldCheck className="mr-1.5 h-3.5 w-3.5" />
            <span className="hidden sm:inline">Verify {doc.doc_type === "quote" ? "Quotation" : "Invoice"}</span>
            <span className="sm:hidden">Verify</span>
          </Button>
          <Button variant="outline" className="rounded-full" onClick={handlePreview}>
            <Eye className="mr-1.5 h-3.5 w-3.5" />Preview
          </Button>
          <Button className="rounded-full" onClick={handleDownload}>
            <Download className="mr-1.5 h-3.5 w-3.5" />
            <span className="hidden sm:inline">Download PDF</span>
            <span className="sm:hidden">PDF</span>
          </Button>
        </div>
      </div>

      <div className="mt-8 sm:mt-10 grid grid-cols-1 gap-6 lg:grid-cols-[1fr_320px] lg:gap-10">
        <div className="min-w-0 rounded-2xl border border-hairline bg-card p-5 sm:p-8">
          <div className="grid grid-cols-1 gap-6 sm:grid-cols-2 sm:gap-8 text-sm">
            <div>
              <div className="text-[11px] uppercase tracking-[0.2em] text-muted-foreground">Billed to</div>
              <div className="mt-2 font-medium">{doc.client?.company_name}</div>
              {doc.client?.address && <div className="text-muted-foreground whitespace-pre-line">{doc.client.address}</div>}
              {doc.client?.email && <div className="text-muted-foreground break-all">{doc.client.email}</div>}
              {doc.client?.phone && <div className="text-muted-foreground">{doc.client.phone}</div>}
            </div>
            <div className="sm:text-right">
              <div className="text-[11px] uppercase tracking-[0.2em] text-muted-foreground">
                {doc.doc_type === "invoice" ? "Due" : "Valid until"}
              </div>
              <div className="mt-2">{doc.due_date ? formatDate(doc.due_date) : "—"}</div>
            </div>
          </div>

          <div className="mt-8 sm:mt-10 -mx-5 sm:mx-0 overflow-x-auto">
            <div className="min-w-[480px] px-5 sm:px-0">
              <div className="grid grid-cols-[1fr_60px_120px_120px] gap-2 border-b border-foreground pb-2 text-[11px] uppercase tracking-wider text-muted-foreground">
                <div>Description</div>
                <div className="text-right">Qty</div>
                <div className="text-right">Unit</div>
                <div className="text-right">Amount</div>
              </div>
              {doc.line_items.map((it, i) => (
                <div key={i} className="grid grid-cols-[1fr_60px_120px_120px] gap-2 border-b border-hairline py-3 text-sm">
                  <div>{it.description}</div>
                  <div className="text-right tabular">{it.quantity}</div>
                  <div className="text-right tabular">{formatMoney(it.unit_price)}</div>
                  <div className="text-right tabular">{formatMoney(rowTotal(it))}</div>
                </div>
              ))}
            </div>
          </div>

          <div className="mt-6 flex justify-end">
            <dl className="w-full sm:w-72 space-y-2 text-sm">
              <div className="flex justify-between"><dt className="text-muted-foreground">Subtotal</dt><dd className="tabular">{formatMoney(Number(doc.subtotal))}</dd></div>
              <div className="flex justify-between"><dt className="text-muted-foreground">Tax ({doc.tax_rate}%)</dt><dd className="tabular">{formatMoney(Number(doc.tax_amount))}</dd></div>
              {Number(doc.discount) > 0 && (
                <div className="flex justify-between"><dt className="text-muted-foreground">Discount</dt><dd className="tabular">− {formatMoney(Number(doc.discount))}</dd></div>
              )}
              <div className="mt-2 flex items-baseline justify-between border-t border-foreground pt-3">
                <dt className="font-medium">Total</dt>
                <dd className="text-xl font-semibold tracking-tight tabular">{formatMoney(Number(doc.total))}</dd>
              </div>
            </dl>
          </div>

          {doc.notes && (
            <div className="mt-8 border-t border-hairline pt-6">
              <div className="text-[11px] uppercase tracking-[0.2em] text-muted-foreground">Notes</div>
              <p className="mt-2 text-sm whitespace-pre-line">{doc.notes}</p>
            </div>
          )}
        </div>

        <aside className="space-y-4">
          <div className="rounded-2xl border border-hairline bg-card p-6">
            <div className="text-[11px] uppercase tracking-[0.2em] text-muted-foreground">Total</div>
            <div className="mt-2 text-3xl font-semibold tracking-tight tabular">{formatMoney(Number(doc.total))}</div>
          </div>
        </aside>
      </div>

      <Dialog
        open={!!previewUrl}
        onOpenChange={(o) => {
          if (!o) {
            if (previewUrl) URL.revokeObjectURL(previewUrl);
            setPreviewUrl(null);
          }
        }}
      >
        <DialogContent className="sm:max-w-4xl p-3 sm:p-6">
          <DialogHeader><DialogTitle>PDF Preview</DialogTitle></DialogHeader>
          {previewUrl && <iframe src={previewUrl} title="PDF preview" className="h-[70vh] w-full rounded-md border border-hairline" />}
        </DialogContent>
      </Dialog>
    </div>
  );
}
