import { createFileRoute } from "@tanstack/react-router";
import { useEffect, useState } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useActiveOrg } from "@/lib/org";
import { supabase } from "@/integrations/supabase/client";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { toast } from "sonner";
import { Upload, Trash2 } from "lucide-react";

export const Route = createFileRoute("/settings/organization")({ component: OrgSettings });

function OrgSettings() {
  const { data: activeOrg, isLoading } = useActiveOrg();
  const qc = useQueryClient();
  const updateFn = useServerFn(updateOrganizationProfile);

  const [form, setForm] = useState({
    name: "",
    short_name: "",
    logo_url: "",
    emails: "",
    website: "",
    registration: "",
    tin: "",
    duns: "",
    praz: "",
    currency: "USD",
    default_tax_rate: 15,
    address: "",
    phone: "",
    payment_instructions: "",
  });
  const [uploading, setUploading] = useState(false);

  useEffect(() => {
    if (!activeOrg) return;
    const p = activeOrg.profile;
    setForm({
      name: p.name,
      short_name: p.short_name ?? "",
      logo_url: p.logo_url ?? "",
      emails: (p.emails ?? []).join(", "),
      website: p.website ?? "",
      registration: p.registration ?? "",
      tin: p.tin ?? "",
      duns: p.duns ?? "",
      praz: p.praz ?? "",
      currency: p.currency,
      default_tax_rate: Number(p.default_tax_rate),
      address: p.address ?? "",
      phone: p.phone ?? "",
      payment_instructions: p.payment_instructions ?? "",
    });
  }, [activeOrg]);

  const canEdit = activeOrg?.role === "owner" || activeOrg?.role === "admin";

  const save = useMutation({
    mutationFn: async () => {
      if (!activeOrg?.org_id) throw new Error("No active org");
      const emails = form.emails
        .split(",")
        .map((s) => s.trim())
        .filter(Boolean);
      await updateFn({
        data: {
          org_id: activeOrg.org_id,
          patch: {
            name: form.name.trim(),
            short_name: form.short_name.trim() || null,
            logo_url: form.logo_url.trim() || null,
            emails,
            website: form.website.trim() || null,
            registration: form.registration.trim() || null,
            tin: form.tin.trim() || null,
            duns: form.duns.trim() || null,
            praz: form.praz.trim() || null,
            currency: form.currency.trim().toUpperCase(),
            default_tax_rate: Number(form.default_tax_rate) || 0,
            address: form.address.trim() || null,
            phone: form.phone.trim() || null,
            payment_instructions: form.payment_instructions.trim() || null,
          },
        },
      });
    },
    onSuccess: async () => {
      toast.success("Saved");
      await qc.invalidateQueries({ queryKey: ["active-org"] });
    },
    onError: (e) => toast.error(e instanceof Error ? e.message : "Save failed"),
  });

  const onLogo = async (file: File) => {
    if (!activeOrg?.org_id) return;
    if (file.size > 2 * 1024 * 1024) {
      toast.error("Logo must be under 2MB");
      return;
    }
    setUploading(true);
    try {
      const ext = file.name.split(".").pop()?.toLowerCase() || "png";
      const path = `${activeOrg.org_id}/logo-${Date.now()}.${ext}`;
      const { error } = await supabase.storage
        .from("org-logos")
        .upload(path, file, { upsert: true, cacheControl: "3600", contentType: file.type });
      if (error) throw error;
      const { data: pub } = supabase.storage.from("org-logos").getPublicUrl(path);
      setForm((f) => ({ ...f, logo_url: pub.publicUrl }));
      toast.success("Logo uploaded — remember to save");
    } catch (e) {
      toast.error(e instanceof Error ? e.message : "Upload failed");
    } finally {
      setUploading(false);
    }
  };

  if (isLoading) return <div className="text-sm text-muted-foreground">Loading…</div>;
  if (!activeOrg) return null;

  return (
    <div className="max-w-2xl space-y-8">
      {!canEdit && (
        <div className="rounded-md border border-hairline bg-muted/30 px-4 py-3 text-xs text-muted-foreground">
          Only admins and owners can edit organization settings.
        </div>
      )}

      <section className="space-y-4">
        <h2 className="text-sm font-medium">Branding</h2>
        <div className="flex items-start gap-4">
          <div className="flex h-20 w-20 items-center justify-center rounded-md border border-hairline bg-muted/30 overflow-hidden">
            {form.logo_url ? (
              <img src={form.logo_url} alt="Logo" className="h-full w-full object-contain" />
            ) : (
              <span className="text-[10px] text-muted-foreground">No logo</span>
            )}
          </div>
          <div className="flex flex-col gap-2">
            <label className="inline-flex w-fit cursor-pointer items-center gap-1.5 rounded-md border border-hairline px-3 py-1.5 text-xs hover:bg-secondary/50">
              <Upload className="h-3.5 w-3.5" />
              {uploading ? "Uploading…" : "Upload logo"}
              <input
                type="file"
                accept="image/png,image/jpeg,image/svg+xml,image/webp"
                className="hidden"
                disabled={!canEdit || uploading}
                onChange={(e) => {
                  const f = e.target.files?.[0];
                  if (f) onLogo(f);
                  e.target.value = "";
                }}
              />
            </label>
            {form.logo_url && (
              <button
                type="button"
                onClick={() => setForm((f) => ({ ...f, logo_url: "" }))}
                className="inline-flex w-fit items-center gap-1 text-[11px] text-muted-foreground hover:text-destructive"
                disabled={!canEdit}
              >
                <Trash2 className="h-3 w-3" /> Remove
              </button>
            )}
            <p className="text-[11px] text-muted-foreground">PNG or SVG. Max 2MB.</p>
          </div>
        </div>
      </section>

      {form.praz && (
        <section className="rounded-lg border border-primary/20 bg-primary/5 px-5 py-4">
          <div className="flex items-center justify-between gap-4">
            <div>
              <p className="text-[11px] font-medium uppercase tracking-wider text-primary/70">PRAZ Registration Number</p>
              <p className="mt-1 text-xl font-bold tracking-tight text-foreground">{form.praz}</p>
            </div>
            <div className="hidden rounded-md bg-primary/10 px-3 py-1.5 text-xs font-semibold text-primary sm:block">
              Verified Contractor
            </div>
          </div>
        </section>
      )}

      <section className="space-y-4">
        <h2 className="text-sm font-medium">Identity</h2>
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
          <Field label="Company name *">
            <Input value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} disabled={!canEdit} />
          </Field>
          <Field label="Short name (for header)">
            <Input value={form.short_name} onChange={(e) => setForm({ ...form, short_name: e.target.value })} disabled={!canEdit} />
          </Field>
          <Field label="Emails (comma-separated)">
            <Input value={form.emails} onChange={(e) => setForm({ ...form, emails: e.target.value })} disabled={!canEdit} placeholder="hello@acme.com" />
          </Field>
          <Field label="Website">
            <Input value={form.website} onChange={(e) => setForm({ ...form, website: e.target.value })} disabled={!canEdit} placeholder="acme.com" />
          </Field>
          <Field label="Registration №">
            <Input value={form.registration} onChange={(e) => setForm({ ...form, registration: e.target.value })} disabled={!canEdit} />
          </Field>
          <Field label="TIN">
            <Input value={form.tin} onChange={(e) => setForm({ ...form, tin: e.target.value })} disabled={!canEdit} />
          </Field>
          <Field label="DUNS">
            <Input value={form.duns} onChange={(e) => setForm({ ...form, duns: e.target.value })} disabled={!canEdit} />
          </Field>
          <Field label="PRAZ">
            <Input value={form.praz} onChange={(e) => setForm({ ...form, praz: e.target.value })} disabled={!canEdit} placeholder="PR2651456473" />
          </Field>
          <Field label="Phone">
            <Input value={form.phone} onChange={(e) => setForm({ ...form, phone: e.target.value })} disabled={!canEdit} />
          </Field>
        </div>
        <Field label="Address">
          <Textarea rows={2} value={form.address} onChange={(e) => setForm({ ...form, address: e.target.value })} disabled={!canEdit} />
        </Field>
      </section>

      <section className="space-y-4">
        <h2 className="text-sm font-medium">Document defaults</h2>
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
          <Field label="Currency">
            <Input value={form.currency} onChange={(e) => setForm({ ...form, currency: e.target.value })} disabled={!canEdit} />
          </Field>
          <Field label="Default tax rate (%)">
            <Input
              type="number"
              min={0}
              step="0.01"
              value={form.default_tax_rate}
              onChange={(e) => setForm({ ...form, default_tax_rate: parseFloat(e.target.value) || 0 })}
              disabled={!canEdit}
            />
          </Field>
        </div>
        <Field label="Payment instructions (footer)">
          <Textarea rows={3} value={form.payment_instructions} onChange={(e) => setForm({ ...form, payment_instructions: e.target.value })} disabled={!canEdit} />
        </Field>
      </section>

      <div className="flex justify-end gap-2 border-t border-hairline pt-6">
        <Button onClick={() => save.mutate()} disabled={!canEdit || save.isPending} className="rounded-full">
          {save.isPending ? "Saving…" : "Save changes"}
        </Button>
      </div>
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
