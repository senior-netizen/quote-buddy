import { createFileRoute } from "@tanstack/react-router";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useState } from "react";
import { RequireAuth } from "@/components/RequireAuth";
import { AppShell } from "@/components/AppShell";
import { supabase } from "@/integrations/supabase/client";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger, DialogFooter } from "@/components/ui/dialog";
import { Plus, Pencil } from "lucide-react";
import { toast } from "sonner";
import { z } from "zod";
import { useActiveOrg } from "@/lib/org";

export const Route = createFileRoute("/clients")({ component: Page });

const ClientSchema = z.object({
  company_name: z.string().trim().min(1, "Required").max(200),
  address: z.string().trim().max(500).optional().or(z.literal("")),
  email: z.string().trim().email("Invalid email").max(255).optional().or(z.literal("")),
  phone: z.string().trim().max(40).optional().or(z.literal("")),
});

type ClientRow = {
  id: string;
  company_name: string;
  address: string | null;
  email: string | null;
  phone: string | null;
};

function Page() {
  return (
    <RequireAuth>
      <AppShell>
        <Clients />
      </AppShell>
    </RequireAuth>
  );
}

function Clients() {
  const qc = useQueryClient();
  const { data: clients = [] } = useQuery({
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

  return (
    <div>
      <div className="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <p className="text-[11px] uppercase tracking-[0.2em] text-muted-foreground">Directory</p>
          <h1 className="mt-2 text-3xl sm:text-4xl font-semibold tracking-tight">Clients</h1>
        </div>
        <ClientFormDialog
          trigger={
            <Button className="w-fit rounded-full"><Plus className="mr-1.5 h-3.5 w-3.5" />New client</Button>
          }
          onSaved={() => qc.invalidateQueries({ queryKey: ["clients"] })}
        />
      </div>

      <div className="mt-8 sm:mt-10 overflow-hidden rounded-xl border border-hairline">
        {clients.length === 0 ? (
          <div className="px-6 py-16 text-center text-sm text-muted-foreground">
            No clients yet.
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full min-w-[560px] text-sm">
              <thead className="border-b border-hairline bg-secondary/50">
                <tr className="text-[11px] uppercase tracking-wider text-muted-foreground">
                  <th className="px-5 py-3 text-left font-medium">Company</th>
                  <th className="px-5 py-3 text-left font-medium">Email</th>
                  <th className="px-5 py-3 text-left font-medium">Phone</th>
                  <th className="w-16"></th>
                </tr>
              </thead>
              <tbody>
                {clients.map((c) => (
                  <tr key={c.id} className="border-b border-hairline last:border-0">
                    <td className="px-5 py-3 font-medium">{c.company_name}</td>
                    <td className="px-5 py-3 text-muted-foreground">{c.email ?? "—"}</td>
                    <td className="px-5 py-3 text-muted-foreground">{c.phone ?? "—"}</td>
                    <td className="px-3 py-3 text-right">
                      <ClientFormDialog
                        initial={c}
                        trigger={
                          <Button variant="ghost" size="sm"><Pencil className="h-3.5 w-3.5" /></Button>
                        }
                        onSaved={() => qc.invalidateQueries({ queryKey: ["clients"] })}
                      />
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}

export function ClientFormDialog({
  trigger,
  initial,
  onSaved,
}: {
  trigger: React.ReactNode;
  initial?: Partial<ClientRow> & { id?: string };
  onSaved?: (client: ClientRow) => void;
}) {
  const [open, setOpen] = useState(false);
  const { data: activeOrg } = useActiveOrg();
  const [form, setForm] = useState({
    company_name: initial?.company_name ?? "",
    address: initial?.address ?? "",
    email: initial?.email ?? "",
    phone: initial?.phone ?? "",
  });

  const save = useMutation({
    mutationFn: async () => {
      const parsed = ClientSchema.parse(form);
      const payload = {
        company_name: parsed.company_name,
        address: parsed.address || null,
        email: parsed.email || null,
        phone: parsed.phone || null,
      };
      if (initial?.id) {
        const { data, error } = await supabase.from("clients").update(payload).eq("id", initial.id).select().single();
        if (error) throw error;
        return data as ClientRow;
      }
      const { data: u } = await supabase.auth.getUser();
      if (!u.user) throw new Error("Not authenticated");
      if (!activeOrg?.org_id) throw new Error("No active organization");
      const { data, error } = await supabase
        .from("clients")
        .insert({ ...payload, user_id: u.user.id, org_id: activeOrg.org_id })
        .select()
        .single();
      if (error) throw error;
      return data as ClientRow;
    },
    onSuccess: (c) => {
      toast.success(initial?.id ? "Client updated" : "Client created");
      onSaved?.(c);
      setOpen(false);
    },
    onError: (e) => toast.error(e instanceof Error ? e.message : "Save failed"),
  });

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>{trigger}</DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{initial?.id ? "Edit client" : "New client"}</DialogTitle>
        </DialogHeader>
        <div className="space-y-4">
          <Field label="Company name *">
            <Input value={form.company_name} onChange={(e) => setForm({ ...form, company_name: e.target.value })} />
          </Field>
          <Field label="Address">
            <Textarea rows={2} value={form.address ?? ""} onChange={(e) => setForm({ ...form, address: e.target.value })} />
          </Field>
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
            <Field label="Email">
              <Input type="email" value={form.email ?? ""} onChange={(e) => setForm({ ...form, email: e.target.value })} />
            </Field>
            <Field label="Phone">
              <Input value={form.phone ?? ""} onChange={(e) => setForm({ ...form, phone: e.target.value })} />
            </Field>
          </div>
        </div>
        <DialogFooter className="flex-col-reverse gap-2 sm:flex-row">
          <Button variant="ghost" onClick={() => setOpen(false)}>Cancel</Button>
          <Button onClick={() => save.mutate()} disabled={save.isPending}>
            {save.isPending ? "Saving…" : "Save client"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
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
