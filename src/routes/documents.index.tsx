import { createFileRoute, Link } from "@tanstack/react-router";
import { useQuery } from "@tanstack/react-query";
import { useState } from "react";
import { RequireAuth } from "@/components/RequireAuth";
import { AppShell } from "@/components/AppShell";
import { supabase } from "@/integrations/supabase/client";
import { formatMoney, formatDate, type LineItem } from "@/lib/calc";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Plus, Download, Eye } from "lucide-react";
import { toast } from "sonner";
import { generatePdfBlob, type DocForPdf } from "@/lib/pdf";
import { issueVerifyToken } from "@/lib/verify.functions";

export const Route = createFileRoute("/documents/")({ component: Page });

type Filter = "all" | "quote" | "invoice";

function Page() {
  return (
    <RequireAuth>
      <AppShell>
        <Documents />
      </AppShell>
    </RequireAuth>
  );
}

type DocRow = {
  id: string;
  doc_type: "quote" | "invoice";
  doc_number: string;
  issue_date: string;
  total: number;
  client: { company_name: string } | null;
};

function Documents() {
  const [filter, setFilter] = useState<Filter>("all");
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);

  const { data: docs = [] } = useQuery({
    queryKey: ["documents", filter],
    queryFn: async () => {
      let q = supabase
        .from("documents")
        .select("id, doc_type, doc_number, issue_date, total, client:clients(company_name)")
        .order("created_at", { ascending: false });
      if (filter !== "all") q = q.eq("doc_type", filter);
      const { data, error } = await q;
      if (error) throw error;
      return (data ?? []) as unknown as DocRow[];
    },
  });

  const buildBlob = async (id: string): Promise<Blob> => {
    // Fetch full document + client
    const { data: doc, error } = await supabase
      .from("documents")
      .select("*, client:clients(company_name, address, email, phone)")
      .eq("id", id)
      .maybeSingle();
    if (error || !doc) throw new Error("Document not found");

    const client = (doc.client as unknown as {
      company_name: string;
      address: string | null;
      email: string | null;
      phone: string | null;
    } | null) ?? { company_name: "—", address: null, email: null, phone: null };

    // Get signed verify token from server
    const { id: docId, hash, sig } = await issueVerifyToken({ data: { id } });
    const verifyUrl = `${window.location.origin}/verify/${docId}?sig=${encodeURIComponent(sig)}&h=${hash}`;

    const docForPdf: DocForPdf = {
      doc_type: doc.doc_type as "quote" | "invoice",
      doc_number: doc.doc_number,
      issue_date: doc.issue_date,
      due_date: doc.due_date,
      line_items: (doc.line_items as unknown as LineItem[]) ?? [],
      tax_rate: Number(doc.tax_rate),
      discount: Number(doc.discount),
      subtotal: Number(doc.subtotal),
      tax_amount: Number(doc.tax_amount),
      total: Number(doc.total),
      notes: doc.notes,
      client,
      verifyUrl,
    };
    return await generatePdfBlob(docForPdf);
  };

  const handleDownload = async (d: DocRow) => {
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
      setTimeout(() => URL.revokeObjectURL(url), 1000);
    } catch (e) {
      toast.error(e instanceof Error ? e.message : "Download failed");
    } finally {
      setBusyId(null);
    }
  };

  const handlePreview = async (d: DocRow) => {
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

  return (
    <div>
      <div className="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <p className="text-[11px] uppercase tracking-[0.2em] text-muted-foreground">Library</p>
          <h1 className="mt-2 text-3xl sm:text-4xl font-semibold tracking-tight">Documents</h1>
        </div>
        <Link to="/documents/new" className="w-fit">
          <Button className="rounded-full"><Plus className="mr-1.5 h-3.5 w-3.5" />New</Button>
        </Link>
      </div>

      <div className="mt-6 sm:mt-8 inline-flex rounded-full border border-hairline p-0.5">
        {(["all", "quote", "invoice"] as const).map((f) => (
          <button
            key={f}
            onClick={() => setFilter(f)}
            className={`rounded-full px-3 sm:px-4 py-1.5 text-[12px] capitalize transition-colors ${
              filter === f ? "bg-primary text-primary-foreground" : "text-muted-foreground hover:text-foreground"
            }`}
          >
            {f === "all" ? "All" : f === "quote" ? "Quotations" : "Invoices"}
          </button>
        ))}
      </div>

      <div className="mt-6 overflow-hidden rounded-xl border border-hairline">
        {docs.length === 0 ? (
          <div className="px-6 py-16 text-center text-sm text-muted-foreground">No documents.</div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full min-w-[720px] text-sm">
              <thead className="border-b border-hairline bg-secondary/50">
                <tr className="text-[11px] uppercase tracking-wider text-muted-foreground">
                  <th className="px-5 py-3 text-left font-medium">Number</th>
                  <th className="px-5 py-3 text-left font-medium">Type</th>
                  <th className="px-5 py-3 text-left font-medium">Client</th>
                  <th className="px-5 py-3 text-left font-medium">Issued</th>
                  <th className="px-5 py-3 text-right font-medium">Total</th>
                  <th className="px-5 py-3 text-right font-medium">Actions</th>
                </tr>
              </thead>
              <tbody>
                {docs.map((d) => (
                  <tr key={d.id} className="border-b border-hairline last:border-0 hover:bg-secondary/30">
                    <td className="px-5 py-3">
                      <Link to="/documents/$id" params={{ id: d.id }} className="font-mono text-[12px] hover:underline underline-offset-4">
                        {d.doc_number}
                      </Link>
                    </td>
                    <td className="px-5 py-3">
                      <span className="rounded-full border border-hairline px-2 py-0.5 text-[11px] uppercase tracking-wider text-muted-foreground">
                        {d.doc_type === "quote" ? "Quote" : "Invoice"}
                      </span>
                    </td>
                    <td className="px-5 py-3">{d.client?.company_name ?? "—"}</td>
                    <td className="px-5 py-3 text-muted-foreground">{formatDate(d.issue_date)}</td>
                    <td className="px-5 py-3 text-right tabular">{formatMoney(Number(d.total))}</td>
                    <td className="px-5 py-3">
                      <div className="flex justify-end gap-1">
                        <Button
                          variant="ghost"
                          size="sm"
                          className="h-8 rounded-full px-3"
                          onClick={() => handlePreview(d)}
                          disabled={busyId === d.id}
                          aria-label={`Preview ${d.doc_number}`}
                        >
                          <Eye className="h-3.5 w-3.5" />
                        </Button>
                        <Button
                          variant="ghost"
                          size="sm"
                          className="h-8 rounded-full px-3"
                          onClick={() => handleDownload(d)}
                          disabled={busyId === d.id}
                          aria-label={`Download ${d.doc_number}`}
                        >
                          <Download className="h-3.5 w-3.5" />
                        </Button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
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
