import { createFileRoute, useNavigate, Link } from "@tanstack/react-router";
import { useEffect, useMemo, useState } from "react";
import { useQuery, useMutation } from "@tanstack/react-query";
import { RequireAuth } from "@/components/RequireAuth";
import { AppShell } from "@/components/AppShell";
import { supabase } from "@/integrations/supabase/client";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Trash2, Plus, ArrowLeft } from "lucide-react";
import { computeTotals, formatMoney, rowTotal, type LineItem } from "@/lib/calc";
import { getDocumentTypeLabel, getDueDateLabel, type DocumentType } from "@/lib/docTypes";
import { useActiveOrg } from "@/lib/org";
import { toast } from "sonner";

export const Route = createFileRoute("/documents/$id/edit")({ component: Page });

function Page() {
  return (
    <RequireAuth>
      <AppShell>
        <Editor />
      </AppShell>
    </RequireAuth>
  );
}

type ClientRow = { id: string; company_name: string };

function Editor() {
  const { id } = Route.useParams();
  const navigate = useNavigate();
  const { data: activeOrg } = useActiveOrg();
  const currency = activeOrg?.profile.currency || "USD";

  const [docNumber, setDocNumber] = useState("");
  const [issueDate, setIssueDate] = useState("");
  const [dueDate, setDueDate] = useState("");
  const [clientId, setClientId] = useState("");
  const [items, setItems] = useState<LineItem[]>([{ description: "", quantity: 1, unit_price: 0 }]);
  const [taxRate, setTaxRate] = useState(15);
  const [discount, setDiscount] = useState(0);
  const [notes, setNotes] = useState("");
  const [docType, setDocType] = useState<DocumentType>("quote");
  const [loaded, setLoaded] = useState(false);

  const { data: doc } = useQuery({
    queryKey: ["doc-edit", id],
    queryFn: async () => {
      const { data, error } = await supabase.from("documents").select("*").eq("id", id).single();
      if (error) throw error;
      return data;
    },
  });

  const { data: clients = [] } = useQuery({
    queryKey: ["clients"],
    queryFn: async () => {
      const { data, error } = await supabase.from("clients").select("id, company_name").order("company_name");
      if (error) throw error;
      return data as ClientRow[];
    },
  });

  useEffect(() => {
    if (!doc || loaded) return;
    setDocNumber(doc.doc_number);
    setIssueDate(doc.issue_date);
    setDueDate(doc.due_date ?? "");
    setClientId(doc.client_id);
    setItems((doc.line_items as unknown as LineItem[]) ?? []);
    setTaxRate(Number(doc.tax_rate));
    setDiscount(Number(doc.discount));
    setNotes(doc.notes ?? "");
    setDocType((doc.doc_type as DocumentType | undefined) ?? "quote");
    setLoaded(true);
  }, [doc, loaded]);

  const totals = useMemo(() => computeTotals(items, taxRate, discount), [items, taxRate, discount]);

  const updateItem = (i: number, patch: Partial<LineItem>) =>
    setItems((arr) => arr.map((it, idx) => (idx === i ? { ...it, ...patch } : it)));
  const addItem = () => setItems((arr) => [...arr, { description: "", quantity: 1, unit_price: 0 }]);
  const removeItem = (i: number) => setItems((arr) => (arr.length === 1 ? arr : arr.filter((_, idx) => idx !== i)));

  const save = useMutation({
    mutationFn: async () => {
      if (!clientId) throw new Error("Select a client");
      if (items.some((i) => !i.description.trim())) throw new Error("All line items need a description");
      const { error } = await supabase
        .from("documents")
        .update({
          client_id: clientId,
          doc_number: docNumber,
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
        .eq("id", id);
      if (error) throw error;
    },
    onSuccess: () => {
      toast.success("Changes saved");
      navigate({ to: "/documents/$id", params: { id } });
    },
    onError: (e) => toast.error(e instanceof Error ? e.message : "Save failed"),
  });

  if (!loaded) return <div className="text-sm text-muted-foreground">Loading…</div>;

  return (
    <div className="grid grid-cols-1 gap-8 lg:grid-cols-[1fr_320px] lg:gap-10">
      <div className="min-w-0">
        <Link to="/documents/$id" params={{ id }} className="inline-flex items-center gap-1 text-xs text-muted-foreground hover:text-foreground">
          <ArrowLeft className="h-3.5 w-3.5" /> Back
        </Link>
        <p className="mt-4 text-[11px] uppercase tracking-[0.2em] text-muted-foreground">Edit</p>
        <h1 className="mt-2 text-3xl sm:text-4xl font-semibold tracking-tight">
          {getDocumentTypeLabel(docType)} {docNumber}
        </h1>

        <div className="mt-8 grid grid-cols-1 gap-4 sm:grid-cols-2">
          <Field label="Document number">
            <Input value={docNumber} onChange={(e) => setDocNumber(e.target.value)} className="font-mono" />
          </Field>
          <Field label="Client">
            <Select value={clientId} onValueChange={setClientId}>
              <SelectTrigger><SelectValue placeholder="Select a client" /></SelectTrigger>
              <SelectContent>
                {clients.map((c) => (
                  <SelectItem key={c.id} value={c.id}>{c.company_name}</SelectItem>
                ))}
              </SelectContent>
            </Select>
          </Field>
          <Field label="Issue date">
            <Input type="date" value={issueDate} onChange={(e) => setIssueDate(e.target.value)} />
          </Field>
          <Field label={getDueDateLabel(docType)}>
            <Input type="date" value={dueDate} onChange={(e) => setDueDate(e.target.value)} />
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
              <div key={i} className="flex flex-col gap-2 border-b border-hairline px-3 py-3 last:border-0 sm:grid sm:grid-cols-[1fr_90px_120px_120px_40px] sm:items-center sm:gap-2 sm:px-4 sm:py-2">
                <Input
                  placeholder="Item or service description"
                  value={it.description}
                  onChange={(e) => updateItem(i, { description: e.target.value })}
                  className="w-full border border-hairline bg-transparent shadow-none sm:border-0"
                />
                <div className="grid grid-cols-[1fr_1fr_1fr_auto] items-center gap-2 sm:contents">
                  <Input
                    type="number" min={0} step="0.01" value={it.quantity}
                    onChange={(e) => updateItem(i, { quantity: parseFloat(e.target.value) || 0 })}
                    className="border border-hairline bg-transparent text-right shadow-none tabular sm:border-0"
                  />
                  <Input
                    type="number" min={0} step="0.01" value={it.unit_price}
                    onChange={(e) => updateItem(i, { unit_price: parseFloat(e.target.value) || 0 })}
                    className="border border-hairline bg-transparent text-right shadow-none tabular sm:border-0"
                  />
                  <div className="text-right text-sm tabular py-2">{formatMoney(rowTotal(it))}</div>
                  <button type="button" onClick={() => removeItem(i)} className="text-muted-foreground hover:text-destructive disabled:opacity-30" disabled={items.length === 1}>
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
            <Textarea rows={3} value={notes} onChange={(e) => setNotes(e.target.value)} />
          </Field>
        </div>
      </div>

      <aside className="lg:sticky lg:top-20 lg:h-fit">
        <div className="rounded-2xl border border-hairline bg-card p-5 sm:p-6">
          <div className="text-[11px] uppercase tracking-[0.2em] text-muted-foreground">Summary</div>
          <dl className="mt-5 space-y-3 text-sm">
            <div className="flex justify-between"><dt className="text-muted-foreground">Subtotal</dt><dd className="tabular">{formatMoney(totals.subtotal)}</dd></div>
            <div className="flex justify-between"><dt className="text-muted-foreground">Tax ({taxRate}%)</dt><dd className="tabular">{formatMoney(totals.tax_amount)}</dd></div>
            {discount > 0 && <div className="flex justify-between"><dt className="text-muted-foreground">Discount</dt><dd className="tabular">− {formatMoney(discount)}</dd></div>}
            <div className="my-3 border-t border-hairline" />
            <div className="flex items-baseline justify-between">
              <dt className="text-sm font-medium">Total</dt>
              <dd className="text-2xl font-semibold tracking-tight tabular">{formatMoney(totals.total)}</dd>
            </div>
          </dl>
          <div className="mt-6 flex flex-col gap-2">
            <Button onClick={() => save.mutate()} disabled={save.isPending} className="rounded-full">
              {save.isPending ? "Saving…" : "Save changes"}
            </Button>
            <Link to="/documents/$id" params={{ id }}>
              <Button variant="outline" className="w-full rounded-full">Cancel</Button>
            </Link>
          </div>
        </div>
      </aside>
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
