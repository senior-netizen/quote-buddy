import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { useEffect, useMemo, useState } from "react";
import { useQuery, useMutation } from "@tanstack/react-query";
import { RequireAuth } from "@/components/RequireAuth";
import { AppShell } from "@/components/AppShell";
import { ClientFormDialog } from "@/routes/clients";
import { supabase } from "@/integrations/supabase/client";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Trash2, Plus } from "lucide-react";
import { computeTotals, formatMoney, rowTotal, type LineItem } from "@/lib/calc";
import { generateDocNumber } from "@/lib/docNumber";
import { useActiveOrg, profileToBrand } from "@/lib/org";
import { downloadPdf, openPdfPreview, type DocForPdf } from "@/lib/pdf";
import { toast } from "sonner";

export const Route = createFileRoute("/documents/new")({ component: Page });

function Page() {
  return (
    <RequireAuth>
      <AppShell>
        <Creator />
      </AppShell>
    </RequireAuth>
  );
}

type ClientRow = { id: string; company_name: string; address: string | null; email: string | null; phone: string | null };

function todayISO() {
  return new Date().toISOString().slice(0, 10);
}
function plusDaysISO(days: number) {
  const d = new Date();
  d.setDate(d.getDate() + days);
  return d.toISOString().slice(0, 10);
}

function Creator() {
  const navigate = useNavigate();
  const { data: activeOrg } = useActiveOrg();
  const [docType, setDocType] = useState<"quote" | "invoice">("quote");
  const [docNumber, setDocNumber] = useState("");
  const [issueDate, setIssueDate] = useState(todayISO());
  const [dueDate, setDueDate] = useState(plusDaysISO(14));
  const [clientId, setClientId] = useState<string>("");
  const [items, setItems] = useState<LineItem[]>([{ description: "", quantity: 1, unit_price: 0 }]);
  const [taxRate, setTaxRate] = useState<number>(15);
  const [discount, setDiscount] = useState<number>(0);
  const [notes, setNotes] = useState("");
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);

  // Sync default tax rate once org loads
  useEffect(() => {
    if (activeOrg) setTaxRate(Number(activeOrg.profile.default_tax_rate));
  }, [activeOrg]);

  const { data: clients = [], refetch: refetchClients } = useQuery({
    queryKey: ["clients"],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("clients")
        .select("id, company_name, address, email, phone")
        .order("company_name");
      if (error) throw error;
      return data as ClientRow[];
    },
  });

  useEffect(() => {
    if (!activeOrg?.org_id) return;
    generateDocNumber(docType, activeOrg.org_id).then(setDocNumber).catch(() => setDocNumber(""));
  }, [docType, activeOrg?.org_id]);

  const totals = useMemo(() => computeTotals(items, taxRate, discount), [items, taxRate, discount]);
  const client = clients.find((c) => c.id === clientId) ?? null;

  const updateItem = (i: number, patch: Partial<LineItem>) =>
    setItems((arr) => arr.map((it, idx) => (idx === i ? { ...it, ...patch } : it)));
  const addItem = () => setItems((arr) => [...arr, { description: "", quantity: 1, unit_price: 0 }]);
  const removeItem = (i: number) => setItems((arr) => (arr.length === 1 ? arr : arr.filter((_, idx) => idx !== i)));

  const buildDocForPdf = async (): Promise<DocForPdf | null> => {
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
        phone: client.phone,
      },
      brand,
    };
  };

  const validate = (): string | null => {
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
      const { data: u } = await supabase.auth.getUser();
      if (!u.user) throw new Error("Not authenticated");
      if (!activeOrg?.org_id) throw new Error("No active org");

      const MAX_ATTEMPTS = 5;
      let attemptNumber = docNumber;
      let regenerated = false;

      for (let attempt = 1; attempt <= MAX_ATTEMPTS; attempt++) {
        const { data, error } = await supabase
          .from("documents")
          .insert({
            user_id: u.user.id,
            org_id: activeOrg.org_id,
            client_id: clientId,
            doc_type: docType,
            doc_number: attemptNumber,
            issue_date: issueDate,
            due_date: dueDate || null,
            line_items: items as unknown as never,
            tax_rate: taxRate,
            discount,
            subtotal: totals.subtotal,
            tax_amount: totals.tax_amount,
            total: totals.total,
            notes: notes || null,
          })
          .select("id")
          .single();

        if (!error) {
          if (attemptNumber !== docNumber) setDocNumber(attemptNumber);
          if (regenerated) toast.message(`Document number reassigned to ${attemptNumber}`);
          return data.id as string;
        }

        if ((error as { code?: string }).code === "23505" && attempt < MAX_ATTEMPTS) {
          attemptNumber = await generateDocNumber(docType, activeOrg.org_id);
          regenerated = true;
          continue;
        }
        throw error;
      }
      throw new Error("Could not allocate a unique document number. Please try again.");
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
      navigate({ to: "/documents/$id", params: { id } });
    },
    onError: (e) => {
      toast.error(e instanceof Error ? e.message : "Save failed");
    },
  });

  const handlePreview = async () => {
    const v = validate();
    if (v) return toast.error(v);
    const d = await buildDocForPdf();
    if (!d) return;
    const url = await openPdfPreview(d);
    setPreviewUrl(url);
  };

  return (
    <div className="grid grid-cols-1 gap-8 lg:grid-cols-[1fr_320px] lg:gap-10">
      <div className="min-w-0">
        <p className="text-[11px] uppercase tracking-[0.2em] text-muted-foreground">Create</p>
        <h1 className="mt-2 text-3xl sm:text-4xl font-semibold tracking-tight">
          New {docType === "quote" ? "quotation" : "invoice"}
        </h1>

        <div className="mt-8 grid grid-cols-1 gap-4 sm:grid-cols-2">
          <Field label="Document type">
            <div className="inline-flex w-full rounded-full border border-hairline p-0.5">
              {(["quote", "invoice"] as const).map((t) => (
                <button
                  key={t}
                  type="button"
                  onClick={() => setDocType(t)}
                  className={`flex-1 rounded-full px-4 py-1.5 text-[13px] capitalize transition-colors ${
                    docType === t ? "bg-primary text-primary-foreground" : "text-muted-foreground hover:text-foreground"
                  }`}
                >
                  {t === "quote" ? "Quotation" : "Invoice"}
                </button>
              ))}
            </div>
          </Field>
          <Field label="Document number">
            <Input value={docNumber} onChange={(e) => setDocNumber(e.target.value)} className="font-mono" />
          </Field>
          <Field label="Issue date">
            <Input type="date" value={issueDate} onChange={(e) => setIssueDate(e.target.value)} />
          </Field>
          <Field label={docType === "invoice" ? "Due date" : "Valid until"}>
            <Input type="date" value={dueDate} onChange={(e) => setDueDate(e.target.value)} />
          </Field>
        </div>

        <div className="mt-8">
          <Field label="Client">
            <div className="flex gap-2">
              <Select value={clientId} onValueChange={setClientId}>
                <SelectTrigger className="flex-1"><SelectValue placeholder="Select a client" /></SelectTrigger>
                <SelectContent>
                  {clients.map((c) => (
                    <SelectItem key={c.id} value={c.id}>{c.company_name}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
              <ClientFormDialog
                trigger={<Button variant="outline" type="button"><Plus className="h-4 w-4" /></Button>}
                onSaved={async (c) => {
                  await refetchClients();
                  setClientId(c.id);
                }}
              />
            </div>
          </Field>
        </div>

        <div className="mt-10">
          <div className="flex items-center justify-between">
            <h2 className="text-sm font-medium tracking-tight">Line items</h2>
            <Button type="button" variant="ghost" size="sm" onClick={addItem}>
              <Plus className="mr-1 h-3.5 w-3.5" />Add row
            </Button>
          </div>
          <div className="mt-3 overflow-hidden rounded-xl border border-hairline">
            <div className="hidden sm:grid grid-cols-[1fr_90px_120px_120px_40px] items-center gap-2 border-b border-hairline bg-secondary/50 px-4 py-2.5 text-[11px] uppercase tracking-wider text-muted-foreground">
              <div>Description</div>
              <div className="text-right">Qty</div>
              <div className="text-right">Unit price</div>
              <div className="text-right">Amount</div>
              <div></div>
            </div>
            {items.map((it, i) => (
              <div
                key={i}
                className="flex flex-col gap-2 border-b border-hairline px-3 py-3 last:border-0 sm:grid sm:grid-cols-[1fr_90px_120px_120px_40px] sm:items-center sm:gap-2 sm:px-4 sm:py-2"
              >
                <Input
                  placeholder="Item or service description"
                  value={it.description}
                  onChange={(e) => updateItem(i, { description: e.target.value })}
                  className="w-full border border-hairline bg-transparent shadow-none focus-visible:ring-1 focus-visible:ring-ring sm:border-0 sm:focus-visible:ring-0 sm:focus-visible:ring-offset-0"
                />
                <div className="grid grid-cols-[1fr_1fr_1fr_auto] items-center gap-2 sm:contents">
                  <div>
                    <div className="text-[10px] uppercase tracking-wider text-muted-foreground sm:hidden">Qty</div>
                    <Input
                      type="number"
                      min={0}
                      step="0.01"
                      value={it.quantity}
                      onChange={(e) => updateItem(i, { quantity: parseFloat(e.target.value) || 0 })}
                      className="border border-hairline bg-transparent text-right shadow-none focus-visible:ring-1 focus-visible:ring-ring tabular sm:border-0 sm:focus-visible:ring-0 sm:focus-visible:ring-offset-0"
                    />
                  </div>
                  <div>
                    <div className="text-[10px] uppercase tracking-wider text-muted-foreground sm:hidden">Unit price</div>
                    <Input
                      type="number"
                      min={0}
                      step="0.01"
                      value={it.unit_price}
                      onChange={(e) => updateItem(i, { unit_price: parseFloat(e.target.value) || 0 })}
                      className="border border-hairline bg-transparent text-right shadow-none focus-visible:ring-1 focus-visible:ring-ring tabular sm:border-0 sm:focus-visible:ring-0 sm:focus-visible:ring-offset-0"
                    />
                  </div>
                  <div className="text-right">
                    <div className="text-[10px] uppercase tracking-wider text-muted-foreground sm:hidden">Amount</div>
                    <div className="text-sm tabular py-2">{formatMoney(rowTotal(it))}</div>
                  </div>
                  <button
                    type="button"
                    onClick={() => removeItem(i)}
                    className="text-muted-foreground hover:text-destructive disabled:opacity-30"
                    disabled={items.length === 1}
                  >
                    <Trash2 className="h-3.5 w-3.5" />
                  </button>
                </div>
              </div>
            ))}
          </div>
        </div>

        <div className="mt-8 grid grid-cols-2 gap-4">
          <Field label="Tax rate (%)">
            <Input type="number" min={0} step="0.01" value={taxRate} onChange={(e) => setTaxRate(parseFloat(e.target.value) || 0)} className="tabular" />
          </Field>
          <Field label="Discount">
            <Input type="number" min={0} step="0.01" value={discount} onChange={(e) => setDiscount(parseFloat(e.target.value) || 0)} className="tabular" />
          </Field>
        </div>

        <div className="mt-6">
          <Field label="Notes (optional)">
            <Textarea rows={3} value={notes} onChange={(e) => setNotes(e.target.value)} placeholder="Payment terms, delivery details, etc." />
          </Field>
        </div>
      </div>

      <aside className="lg:sticky lg:top-20 lg:h-fit">
        <div className="rounded-2xl border border-hairline bg-card p-5 sm:p-6">
          <div className="text-[11px] uppercase tracking-[0.2em] text-muted-foreground">Summary</div>
          <dl className="mt-5 space-y-3 text-sm">
            <Row label="Subtotal" value={formatMoney(totals.subtotal)} />
            <Row label={`Tax (${taxRate}%)`} value={formatMoney(totals.tax_amount)} />
            {discount > 0 && <Row label="Discount" value={`− ${formatMoney(discount)}`} />}
            <div className="my-3 border-t border-hairline" />
            <div className="flex items-baseline justify-between">
              <dt className="text-sm font-medium">Total</dt>
              <dd className="text-2xl font-semibold tracking-tight tabular">{formatMoney(totals.total)}</dd>
            </div>
          </dl>
          <div className="mt-6 flex flex-col gap-2">
            <Button onClick={handlePreview} variant="outline" className="rounded-full">Preview PDF</Button>
            <Button onClick={() => save.mutate()} disabled={save.isPending} className="rounded-full">
              {save.isPending ? "Saving…" : "Save & download"}
            </Button>
          </div>
          <p className="mt-4 text-[11px] leading-relaxed text-muted-foreground">
            Document {docNumber || "—"} · {client?.company_name ?? "No client selected"}
          </p>
        </div>
      </aside>

      <Dialog open={!!previewUrl} onOpenChange={(o) => !o && setPreviewUrl(null)}>
        <DialogContent className="sm:max-w-4xl p-3 sm:p-6">
          <DialogHeader><DialogTitle>PDF Preview</DialogTitle></DialogHeader>
          {previewUrl && (
            <iframe src={previewUrl} title="PDF preview" className="h-[70vh] w-full rounded-md border border-hairline" />
          )}
          <div className="flex flex-col-reverse gap-2 sm:flex-row sm:justify-end">
            <Button variant="ghost" onClick={() => setPreviewUrl(null)}>Close</Button>
            <Button
              onClick={async () => {
                const d = await buildDocForPdf();
                if (d) downloadPdf(d);
              }}
            >Download</Button>
          </div>
        </DialogContent>
      </Dialog>
    </div>
  );
}

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className="space-y-1.5">
      <Label className="text-xs">{label}</Label>
      {children}
    </div>
  );
}
function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-baseline justify-between">
      <dt className="text-muted-foreground">{label}</dt>
      <dd className="tabular">{value}</dd>
    </div>
  );
}
