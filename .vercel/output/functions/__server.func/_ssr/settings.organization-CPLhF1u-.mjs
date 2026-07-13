import { r as reactExports, j as jsxRuntimeExports } from "../_libs/react.mjs";
import { b as useQueryClient, a as useMutation } from "../_libs/tanstack__react-query.mjs";
import { a as useActiveOrg, I as Input, T as Textarea, B as Button, L as Label } from "./router-BDMLDL80.mjs";
import { s as supabase } from "./client-U3FzjMwq.mjs";
import { t as toast } from "../_libs/sonner.mjs";
import "./index.mjs";
import "../_libs/seroval.mjs";
import "../_libs/qrcode.mjs";
import { o as Upload, T as Trash2 } from "../_libs/lucide-react.mjs";
import "../_libs/tanstack__query-core.mjs";
import "../_libs/tanstack__react-router.mjs";
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
import "./calc-BF6zAv6d.mjs";
import "./docTypes-CsATll0j.mjs";
import "../_libs/zod.mjs";
import "./verifySign.server-CnraXCan.mjs";
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
function OrgSettings() {
  const {
    data: activeOrg,
    isLoading
  } = useActiveOrg();
  const qc = useQueryClient();
  const [form, setForm] = reactExports.useState({
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
    payment_instructions: ""
  });
  const [uploading, setUploading] = reactExports.useState(false);
  reactExports.useEffect(() => {
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
      payment_instructions: p.payment_instructions ?? ""
    });
  }, [activeOrg]);
  const canEdit = activeOrg?.role === "owner" || activeOrg?.role === "admin";
  const save = useMutation({
    mutationFn: async () => {
      if (!activeOrg?.org_id) throw new Error("No active org");
      const emails = form.emails.split(",").map((s) => s.trim()).filter(Boolean);
      const name = form.name.trim();
      if (!name) throw new Error("Company name is required");
      const patch = {
        name,
        short_name: form.short_name.trim() || null,
        logo_url: form.logo_url.trim() || null,
        emails,
        website: form.website.trim() || null,
        registration: form.registration.trim() || null,
        tin: form.tin.trim() || null,
        duns: form.duns.trim() || null,
        praz: form.praz.trim() || null,
        currency: (form.currency.trim() || "USD").toUpperCase(),
        default_tax_rate: Number(form.default_tax_rate) || 0,
        address: form.address.trim() || null,
        phone: form.phone.trim() || null,
        payment_instructions: form.payment_instructions.trim() || null
      };
      const {
        error: pErr
      } = await supabase.from("organization_profiles").update(patch).eq("org_id", activeOrg.org_id);
      if (pErr) throw new Error(pErr.message);
      const {
        error: oErr
      } = await supabase.from("organizations").update({
        name
      }).eq("id", activeOrg.org_id);
      if (oErr) throw new Error(oErr.message);
    },
    onSuccess: async () => {
      toast.success("Saved");
      await qc.invalidateQueries({
        queryKey: ["active-org"]
      });
      await qc.invalidateQueries({
        queryKey: ["my-orgs"]
      });
    },
    onError: (e) => toast.error(e instanceof Error ? e.message : "Save failed")
  });
  const onLogo = async (file) => {
    if (!activeOrg?.org_id) return;
    if (file.size > 2 * 1024 * 1024) {
      toast.error("Logo must be under 2MB");
      return;
    }
    setUploading(true);
    try {
      const ext = file.name.split(".").pop()?.toLowerCase() || "png";
      const path = `${activeOrg.org_id}/logo-${Date.now()}.${ext}`;
      const {
        error
      } = await supabase.storage.from("org-logos").upload(path, file, {
        upsert: true,
        cacheControl: "3600",
        contentType: file.type
      });
      if (error) throw error;
      const {
        data: pub
      } = supabase.storage.from("org-logos").getPublicUrl(path);
      setForm((f) => ({
        ...f,
        logo_url: pub.publicUrl
      }));
      toast.success("Logo uploaded — remember to save");
    } catch (e) {
      toast.error(e instanceof Error ? e.message : "Upload failed");
    } finally {
      setUploading(false);
    }
  };
  if (isLoading) return /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "text-sm text-muted-foreground", children: "Loading…" });
  if (!activeOrg) return null;
  return /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "max-w-2xl space-y-8", children: [
    !canEdit && /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "rounded-md border border-hairline bg-muted/30 px-4 py-3 text-xs text-muted-foreground", children: "Only admins and owners can edit organization settings." }),
    /* @__PURE__ */ jsxRuntimeExports.jsxs("section", { className: "space-y-4", children: [
      /* @__PURE__ */ jsxRuntimeExports.jsx("h2", { className: "text-sm font-medium", children: "Branding" }),
      /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "flex items-start gap-4", children: [
        /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "flex h-20 w-20 items-center justify-center rounded-md border border-hairline bg-muted/30 overflow-hidden", children: form.logo_url ? /* @__PURE__ */ jsxRuntimeExports.jsx("img", { src: form.logo_url, alt: "Logo", className: "h-full w-full object-contain" }) : /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: "text-[10px] text-muted-foreground", children: "No logo" }) }),
        /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "flex flex-col gap-2", children: [
          /* @__PURE__ */ jsxRuntimeExports.jsxs("label", { className: "inline-flex w-fit cursor-pointer items-center gap-1.5 rounded-md border border-hairline px-3 py-1.5 text-xs hover:bg-secondary/50", children: [
            /* @__PURE__ */ jsxRuntimeExports.jsx(Upload, { className: "h-3.5 w-3.5" }),
            uploading ? "Uploading…" : "Upload logo",
            /* @__PURE__ */ jsxRuntimeExports.jsx("input", { type: "file", accept: "image/png,image/jpeg,image/svg+xml,image/webp", className: "hidden", disabled: !canEdit || uploading, onChange: (e) => {
              const f = e.target.files?.[0];
              if (f) onLogo(f);
              e.target.value = "";
            } })
          ] }),
          form.logo_url && /* @__PURE__ */ jsxRuntimeExports.jsxs("button", { type: "button", onClick: () => setForm((f) => ({
            ...f,
            logo_url: ""
          })), className: "inline-flex w-fit items-center gap-1 text-[11px] text-muted-foreground hover:text-destructive", disabled: !canEdit, children: [
            /* @__PURE__ */ jsxRuntimeExports.jsx(Trash2, { className: "h-3 w-3" }),
            " Remove"
          ] }),
          /* @__PURE__ */ jsxRuntimeExports.jsx("p", { className: "text-[11px] text-muted-foreground", children: "PNG or SVG. Max 2MB." })
        ] })
      ] })
    ] }),
    form.praz && /* @__PURE__ */ jsxRuntimeExports.jsx("section", { className: "rounded-lg border border-primary/20 bg-primary/5 px-5 py-4", children: /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "flex items-center justify-between gap-4", children: [
      /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { children: [
        /* @__PURE__ */ jsxRuntimeExports.jsx("p", { className: "text-[11px] font-medium uppercase tracking-wider text-primary/70", children: "PRAZ Registration Number" }),
        /* @__PURE__ */ jsxRuntimeExports.jsx("p", { className: "mt-1 text-xl font-bold tracking-tight text-foreground", children: form.praz })
      ] }),
      /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "hidden rounded-md bg-primary/10 px-3 py-1.5 text-xs font-semibold text-primary sm:block", children: "Verified Contractor" })
    ] }) }),
    /* @__PURE__ */ jsxRuntimeExports.jsxs("section", { className: "space-y-4", children: [
      /* @__PURE__ */ jsxRuntimeExports.jsx("h2", { className: "text-sm font-medium", children: "Identity" }),
      /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "grid grid-cols-1 gap-4 sm:grid-cols-2", children: [
        /* @__PURE__ */ jsxRuntimeExports.jsx(Field, { label: "Company name *", children: /* @__PURE__ */ jsxRuntimeExports.jsx(Input, { value: form.name, onChange: (e) => setForm({
          ...form,
          name: e.target.value
        }), disabled: !canEdit }) }),
        /* @__PURE__ */ jsxRuntimeExports.jsx(Field, { label: "Short name (for header)", children: /* @__PURE__ */ jsxRuntimeExports.jsx(Input, { value: form.short_name, onChange: (e) => setForm({
          ...form,
          short_name: e.target.value
        }), disabled: !canEdit }) }),
        /* @__PURE__ */ jsxRuntimeExports.jsx(Field, { label: "Emails (comma-separated)", children: /* @__PURE__ */ jsxRuntimeExports.jsx(Input, { value: form.emails, onChange: (e) => setForm({
          ...form,
          emails: e.target.value
        }), disabled: !canEdit, placeholder: "hello@acme.com" }) }),
        /* @__PURE__ */ jsxRuntimeExports.jsx(Field, { label: "Website", children: /* @__PURE__ */ jsxRuntimeExports.jsx(Input, { value: form.website, onChange: (e) => setForm({
          ...form,
          website: e.target.value
        }), disabled: !canEdit, placeholder: "acme.com" }) }),
        /* @__PURE__ */ jsxRuntimeExports.jsx(Field, { label: "Registration №", children: /* @__PURE__ */ jsxRuntimeExports.jsx(Input, { value: form.registration, onChange: (e) => setForm({
          ...form,
          registration: e.target.value
        }), disabled: !canEdit }) }),
        /* @__PURE__ */ jsxRuntimeExports.jsx(Field, { label: "TIN", children: /* @__PURE__ */ jsxRuntimeExports.jsx(Input, { value: form.tin, onChange: (e) => setForm({
          ...form,
          tin: e.target.value
        }), disabled: !canEdit }) }),
        /* @__PURE__ */ jsxRuntimeExports.jsx(Field, { label: "DUNS", children: /* @__PURE__ */ jsxRuntimeExports.jsx(Input, { value: form.duns, onChange: (e) => setForm({
          ...form,
          duns: e.target.value
        }), disabled: !canEdit }) }),
        /* @__PURE__ */ jsxRuntimeExports.jsx(Field, { label: "PRAZ", children: /* @__PURE__ */ jsxRuntimeExports.jsx(Input, { value: form.praz, onChange: (e) => setForm({
          ...form,
          praz: e.target.value
        }), disabled: !canEdit, placeholder: "PR2651456473" }) }),
        /* @__PURE__ */ jsxRuntimeExports.jsx(Field, { label: "Phone", children: /* @__PURE__ */ jsxRuntimeExports.jsx(Input, { value: form.phone, onChange: (e) => setForm({
          ...form,
          phone: e.target.value
        }), disabled: !canEdit }) })
      ] }),
      /* @__PURE__ */ jsxRuntimeExports.jsx(Field, { label: "Address", children: /* @__PURE__ */ jsxRuntimeExports.jsx(Textarea, { rows: 2, value: form.address, onChange: (e) => setForm({
        ...form,
        address: e.target.value
      }), disabled: !canEdit }) })
    ] }),
    /* @__PURE__ */ jsxRuntimeExports.jsxs("section", { className: "space-y-4", children: [
      /* @__PURE__ */ jsxRuntimeExports.jsx("h2", { className: "text-sm font-medium", children: "Document defaults" }),
      /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "grid grid-cols-1 gap-4 sm:grid-cols-2", children: [
        /* @__PURE__ */ jsxRuntimeExports.jsx(Field, { label: "Currency", children: /* @__PURE__ */ jsxRuntimeExports.jsx(Input, { value: form.currency, onChange: (e) => setForm({
          ...form,
          currency: e.target.value
        }), disabled: !canEdit }) }),
        /* @__PURE__ */ jsxRuntimeExports.jsx(Field, { label: "Default tax rate (%)", children: /* @__PURE__ */ jsxRuntimeExports.jsx(Input, { type: "number", min: 0, step: "0.01", value: form.default_tax_rate, onChange: (e) => setForm({
          ...form,
          default_tax_rate: parseFloat(e.target.value) || 0
        }), disabled: !canEdit }) })
      ] }),
      /* @__PURE__ */ jsxRuntimeExports.jsx(Field, { label: "Payment instructions (footer)", children: /* @__PURE__ */ jsxRuntimeExports.jsx(Textarea, { rows: 3, value: form.payment_instructions, onChange: (e) => setForm({
        ...form,
        payment_instructions: e.target.value
      }), disabled: !canEdit }) })
    ] }),
    /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "flex justify-end gap-2 border-t border-hairline pt-6", children: /* @__PURE__ */ jsxRuntimeExports.jsx(Button, { onClick: () => save.mutate(), disabled: !canEdit || save.isPending, className: "rounded-full", children: save.isPending ? "Saving…" : "Save changes" }) })
  ] });
}
function Field({
  label,
  children
}) {
  return /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "space-y-1.5", children: [
    /* @__PURE__ */ jsxRuntimeExports.jsx(Label, { className: "text-xs", children: label }),
    children
  ] });
}
export {
  OrgSettings as component
};
