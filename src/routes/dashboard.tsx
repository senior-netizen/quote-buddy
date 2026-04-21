import { createFileRoute, Link } from "@tanstack/react-router";
import { useQuery } from "@tanstack/react-query";
import { RequireAuth } from "@/components/RequireAuth";
import { AppShell } from "@/components/AppShell";
import { supabase } from "@/integrations/supabase/client";
import { formatMoney } from "@/lib/calc";
import { Plus, ArrowUpRight } from "lucide-react";

export const Route = createFileRoute("/dashboard")({ component: Page });

function Page() {
  return (
    <RequireAuth>
      <AppShell>
        <Dashboard />
      </AppShell>
    </RequireAuth>
  );
}

function Dashboard() {
  const { data: docs = [] } = useQuery({
    queryKey: ["recent-docs"],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("documents")
        .select("id, doc_type, doc_number, total, created_at, client:clients(company_name)")
        .order("created_at", { ascending: false })
        .limit(8);
      if (error) throw error;
      return data ?? [];
    },
  });

  const { data: stats } = useQuery({
    queryKey: ["doc-stats"],
    queryFn: async () => {
      const { data, error } = await supabase.from("documents").select("doc_type, total");
      if (error) throw error;
      const quotes = data.filter((d) => d.doc_type === "quote");
      const invoices = data.filter((d) => d.doc_type === "invoice");
      return {
        quotesCount: quotes.length,
        invoicesCount: invoices.length,
        invoiceValue: invoices.reduce((s, d) => s + Number(d.total || 0), 0),
        quoteValue: quotes.reduce((s, d) => s + Number(d.total || 0), 0),
      };
    },
  });

  return (
    <div>
      <div className="flex items-end justify-between">
        <div>
          <p className="text-[11px] uppercase tracking-[0.2em] text-muted-foreground">Overview</p>
          <h1 className="mt-2 text-4xl font-semibold tracking-tight">Good to see you.</h1>
        </div>
        <Link
          to="/documents/new"
          className="inline-flex items-center gap-1.5 rounded-full bg-primary px-5 py-2 text-[13px] font-medium text-primary-foreground hover:opacity-90"
        >
          <Plus className="h-3.5 w-3.5" /> New document
        </Link>
      </div>

      <div className="mt-10 grid grid-cols-2 gap-px overflow-hidden rounded-2xl border border-hairline bg-hairline md:grid-cols-4">
        <Stat label="Quotations" value={stats?.quotesCount ?? "—"} />
        <Stat label="Invoices" value={stats?.invoicesCount ?? "—"} />
        <Stat label="Quoted value" value={stats ? formatMoney(stats.quoteValue) : "—"} />
        <Stat label="Invoiced value" value={stats ? formatMoney(stats.invoiceValue) : "—"} />
      </div>

      <div className="mt-12">
        <div className="flex items-center justify-between">
          <h2 className="text-sm font-medium tracking-tight">Recent documents</h2>
          <Link to="/documents" className="text-xs text-muted-foreground hover:text-foreground">View all →</Link>
        </div>
        <div className="mt-4 overflow-hidden rounded-xl border border-hairline">
          {docs.length === 0 ? (
            <div className="px-6 py-16 text-center text-sm text-muted-foreground">
              No documents yet. <Link to="/documents/new" className="underline underline-offset-4">Create your first</Link>.
            </div>
          ) : (
            <table className="w-full text-sm">
              <thead className="border-b border-hairline bg-secondary/50">
                <tr className="text-[11px] uppercase tracking-wider text-muted-foreground">
                  <th className="px-5 py-3 text-left font-medium">Number</th>
                  <th className="px-5 py-3 text-left font-medium">Type</th>
                  <th className="px-5 py-3 text-left font-medium">Client</th>
                  <th className="px-5 py-3 text-right font-medium">Total</th>
                  <th className="w-12"></th>
                </tr>
              </thead>
              <tbody>
                {docs.map((d) => (
                  <tr key={d.id} className="border-b border-hairline last:border-0 hover:bg-secondary/30">
                    <td className="px-5 py-3 font-mono text-[12px]">{d.doc_number}</td>
                    <td className="px-5 py-3">
                      <span className="rounded-full border border-hairline px-2 py-0.5 text-[11px] uppercase tracking-wider text-muted-foreground">
                        {d.doc_type === "quote" ? "Quote" : "Invoice"}
                      </span>
                    </td>
                    <td className="px-5 py-3">{(d.client as { company_name: string } | null)?.company_name ?? "—"}</td>
                    <td className="px-5 py-3 text-right tabular">{formatMoney(Number(d.total))}</td>
                    <td className="px-3 py-3 text-right">
                      <Link to="/documents/$id" params={{ id: d.id }} className="text-muted-foreground hover:text-foreground">
                        <ArrowUpRight className="inline h-4 w-4" />
                      </Link>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      </div>
    </div>
  );
}

function Stat({ label, value }: { label: string; value: string | number }) {
  return (
    <div className="bg-card p-6">
      <div className="text-[11px] uppercase tracking-wider text-muted-foreground">{label}</div>
      <div className="mt-2 text-2xl font-semibold tracking-tight tabular">{value}</div>
    </div>
  );
}
