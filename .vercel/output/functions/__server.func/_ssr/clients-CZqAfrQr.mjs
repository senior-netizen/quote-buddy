import { r as reactExports, j as jsxRuntimeExports } from "../_libs/react.mjs";
import { a as useMutation, b as useQueryClient, u as useQuery } from "../_libs/tanstack__react-query.mjs";
import { R as RequireAuth, A as AppShell } from "./AppShell-B2WYeB1G.mjs";
import { s as supabase } from "./client-U3FzjMwq.mjs";
import { a as useActiveOrg, D as Dialog, b as DialogTrigger, c as DialogContent, d as DialogHeader, e as DialogTitle, I as Input, T as Textarea, f as DialogFooter, B as Button, L as Label } from "./router-_O5wH3lZ.mjs";
import { t as toast } from "../_libs/sonner.mjs";
import "./index.mjs";
import "../_libs/seroval.mjs";
import "../_libs/qrcode.mjs";
import { P as Plus, f as Pencil } from "../_libs/lucide-react.mjs";
import { o as object, s as string, l as literal } from "../_libs/zod.mjs";
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
import "../_libs/radix-ui__react-dropdown-menu.mjs";
import "../_libs/radix-ui__primitive.mjs";
import "../_libs/radix-ui__react-compose-refs.mjs";
import "../_libs/radix-ui__react-context.mjs";
import "../_libs/@radix-ui/react-use-controllable-state+[...].mjs";
import "../_libs/@radix-ui/react-use-layout-effect+[...].mjs";
import "../_libs/radix-ui__react-primitive.mjs";
import "../_libs/radix-ui__react-slot.mjs";
import "../_libs/radix-ui__react-menu.mjs";
import "../_libs/radix-ui__react-collection.mjs";
import "../_libs/radix-ui__react-direction.mjs";
import "../_libs/@radix-ui/react-dismissable-layer+[...].mjs";
import "../_libs/@radix-ui/react-use-callback-ref+[...].mjs";
import "../_libs/@radix-ui/react-use-escape-keydown+[...].mjs";
import "../_libs/radix-ui__react-focus-guards.mjs";
import "../_libs/radix-ui__react-focus-scope.mjs";
import "../_libs/radix-ui__react-popper.mjs";
import "../_libs/floating-ui__react-dom.mjs";
import "../_libs/floating-ui__dom.mjs";
import "../_libs/floating-ui__core.mjs";
import "../_libs/floating-ui__utils.mjs";
import "../_libs/radix-ui__react-arrow.mjs";
import "../_libs/radix-ui__react-use-size.mjs";
import "../_libs/radix-ui__react-portal.mjs";
import "../_libs/radix-ui__react-presence.mjs";
import "../_libs/radix-ui__react-roving-focus.mjs";
import "../_libs/radix-ui__react-id.mjs";
import "../_libs/aria-hidden.mjs";
import "../_libs/react-remove-scroll.mjs";
import "tslib";
import "../_libs/react-remove-scroll-bar.mjs";
import "../_libs/react-style-singleton.mjs";
import "../_libs/get-nonce.mjs";
import "../_libs/use-sidecar.mjs";
import "../_libs/use-callback-ref.mjs";
import "../_libs/supabase__supabase-js.mjs";
import "../_libs/supabase__postgrest-js.mjs";
import "../_libs/supabase__realtime-js.mjs";
import "../_libs/supabase__phoenix.mjs";
import "../_libs/supabase__storage-js.mjs";
import "../_libs/iceberg-js.mjs";
import "../_libs/supabase__auth-js.mjs";
import "../_libs/supabase__functions-js.mjs";
import "../_libs/class-variance-authority.mjs";
import "../_libs/clsx.mjs";
import "../_libs/tailwind-merge.mjs";
import "../_libs/radix-ui__react-label.mjs";
import "../_libs/radix-ui__react-dialog.mjs";
import "./auth-middleware-DJP7Badx.mjs";
import "./createMiddleware-BvN2ghIY.mjs";
import "./client.server-BMj2q4-x.mjs";
import "./calc-BF6zAv6d.mjs";
import "./docTypes-CsATll0j.mjs";
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
const ClientSchema = object({
  company_name: string().trim().min(1, "Required").max(200),
  address: string().trim().max(500).optional().or(literal("")),
  email: string().trim().email("Invalid email").max(255).optional().or(literal("")),
  phone: string().trim().max(40).optional().or(literal(""))
});
function Page() {
  return /* @__PURE__ */ jsxRuntimeExports.jsx(RequireAuth, { children: /* @__PURE__ */ jsxRuntimeExports.jsx(AppShell, { children: /* @__PURE__ */ jsxRuntimeExports.jsx(Clients, {}) }) });
}
function Clients() {
  const qc = useQueryClient();
  const {
    data: clients = []
  } = useQuery({
    queryKey: ["clients"],
    queryFn: async () => {
      const {
        data,
        error
      } = await supabase.from("clients").select("id, company_name, address, email, phone").order("company_name");
      if (error) throw error;
      return data;
    }
  });
  return /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { children: [
    /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between", children: [
      /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { children: [
        /* @__PURE__ */ jsxRuntimeExports.jsx("p", { className: "text-[11px] uppercase tracking-[0.2em] text-muted-foreground", children: "Directory" }),
        /* @__PURE__ */ jsxRuntimeExports.jsx("h1", { className: "mt-2 text-3xl sm:text-4xl font-semibold tracking-tight", children: "Clients" })
      ] }),
      /* @__PURE__ */ jsxRuntimeExports.jsx(ClientFormDialog, { trigger: /* @__PURE__ */ jsxRuntimeExports.jsxs(Button, { className: "w-fit rounded-full", children: [
        /* @__PURE__ */ jsxRuntimeExports.jsx(Plus, { className: "mr-1.5 h-3.5 w-3.5" }),
        "New client"
      ] }), onSaved: () => qc.invalidateQueries({
        queryKey: ["clients"]
      }) })
    ] }),
    /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "mt-8 sm:mt-10 overflow-hidden rounded-xl border border-hairline", children: clients.length === 0 ? /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "px-6 py-16 text-center text-sm text-muted-foreground", children: "No clients yet." }) : /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "overflow-x-auto", children: /* @__PURE__ */ jsxRuntimeExports.jsxs("table", { className: "w-full min-w-[560px] text-sm", children: [
      /* @__PURE__ */ jsxRuntimeExports.jsx("thead", { className: "border-b border-hairline bg-secondary/50", children: /* @__PURE__ */ jsxRuntimeExports.jsxs("tr", { className: "text-[11px] uppercase tracking-wider text-muted-foreground", children: [
        /* @__PURE__ */ jsxRuntimeExports.jsx("th", { className: "px-5 py-3 text-left font-medium", children: "Company" }),
        /* @__PURE__ */ jsxRuntimeExports.jsx("th", { className: "px-5 py-3 text-left font-medium", children: "Email" }),
        /* @__PURE__ */ jsxRuntimeExports.jsx("th", { className: "px-5 py-3 text-left font-medium", children: "Phone" }),
        /* @__PURE__ */ jsxRuntimeExports.jsx("th", { className: "w-16" })
      ] }) }),
      /* @__PURE__ */ jsxRuntimeExports.jsx("tbody", { children: clients.map((c) => /* @__PURE__ */ jsxRuntimeExports.jsxs("tr", { className: "border-b border-hairline last:border-0", children: [
        /* @__PURE__ */ jsxRuntimeExports.jsx("td", { className: "px-5 py-3 font-medium", children: c.company_name }),
        /* @__PURE__ */ jsxRuntimeExports.jsx("td", { className: "px-5 py-3 text-muted-foreground", children: c.email ?? "—" }),
        /* @__PURE__ */ jsxRuntimeExports.jsx("td", { className: "px-5 py-3 text-muted-foreground", children: c.phone ?? "—" }),
        /* @__PURE__ */ jsxRuntimeExports.jsx("td", { className: "px-3 py-3 text-right", children: /* @__PURE__ */ jsxRuntimeExports.jsx(ClientFormDialog, { initial: c, trigger: /* @__PURE__ */ jsxRuntimeExports.jsx(Button, { variant: "ghost", size: "sm", children: /* @__PURE__ */ jsxRuntimeExports.jsx(Pencil, { className: "h-3.5 w-3.5" }) }), onSaved: () => qc.invalidateQueries({
          queryKey: ["clients"]
        }) }) })
      ] }, c.id)) })
    ] }) }) })
  ] });
}
function ClientFormDialog({
  trigger,
  initial,
  onSaved
}) {
  const [open, setOpen] = reactExports.useState(false);
  const {
    data: activeOrg
  } = useActiveOrg();
  const [form, setForm] = reactExports.useState({
    company_name: initial?.company_name ?? "",
    address: initial?.address ?? "",
    email: initial?.email ?? "",
    phone: initial?.phone ?? ""
  });
  const save = useMutation({
    mutationFn: async () => {
      const parsed = ClientSchema.parse(form);
      const payload = {
        company_name: parsed.company_name,
        address: parsed.address || null,
        email: parsed.email || null,
        phone: parsed.phone || null
      };
      if (initial?.id) {
        const {
          data: data2,
          error: error2
        } = await supabase.from("clients").update(payload).eq("id", initial.id).select().single();
        if (error2) throw error2;
        return data2;
      }
      const {
        data: u
      } = await supabase.auth.getUser();
      if (!u.user) throw new Error("Not authenticated");
      if (!activeOrg?.org_id) throw new Error("No active organization");
      const {
        data,
        error
      } = await supabase.from("clients").insert({
        ...payload,
        user_id: u.user.id,
        org_id: activeOrg.org_id
      }).select().single();
      if (error) throw error;
      return data;
    },
    onSuccess: (c) => {
      toast.success(initial?.id ? "Client updated" : "Client created");
      onSaved?.(c);
      setOpen(false);
    },
    onError: (e) => toast.error(e instanceof Error ? e.message : "Save failed")
  });
  return /* @__PURE__ */ jsxRuntimeExports.jsxs(Dialog, { open, onOpenChange: setOpen, children: [
    /* @__PURE__ */ jsxRuntimeExports.jsx(DialogTrigger, { asChild: true, children: trigger }),
    /* @__PURE__ */ jsxRuntimeExports.jsxs(DialogContent, { children: [
      /* @__PURE__ */ jsxRuntimeExports.jsx(DialogHeader, { children: /* @__PURE__ */ jsxRuntimeExports.jsx(DialogTitle, { children: initial?.id ? "Edit client" : "New client" }) }),
      /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "space-y-4", children: [
        /* @__PURE__ */ jsxRuntimeExports.jsx(Field, { label: "Company name *", children: /* @__PURE__ */ jsxRuntimeExports.jsx(Input, { value: form.company_name, onChange: (e) => setForm({
          ...form,
          company_name: e.target.value
        }) }) }),
        /* @__PURE__ */ jsxRuntimeExports.jsx(Field, { label: "Address", children: /* @__PURE__ */ jsxRuntimeExports.jsx(Textarea, { rows: 2, value: form.address ?? "", onChange: (e) => setForm({
          ...form,
          address: e.target.value
        }) }) }),
        /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "grid grid-cols-1 gap-3 sm:grid-cols-2", children: [
          /* @__PURE__ */ jsxRuntimeExports.jsx(Field, { label: "Email", children: /* @__PURE__ */ jsxRuntimeExports.jsx(Input, { type: "email", value: form.email ?? "", onChange: (e) => setForm({
            ...form,
            email: e.target.value
          }) }) }),
          /* @__PURE__ */ jsxRuntimeExports.jsx(Field, { label: "Phone", children: /* @__PURE__ */ jsxRuntimeExports.jsx(Input, { value: form.phone ?? "", onChange: (e) => setForm({
            ...form,
            phone: e.target.value
          }) }) })
        ] })
      ] }),
      /* @__PURE__ */ jsxRuntimeExports.jsxs(DialogFooter, { className: "flex-col-reverse gap-2 sm:flex-row", children: [
        /* @__PURE__ */ jsxRuntimeExports.jsx(Button, { variant: "ghost", onClick: () => setOpen(false), children: "Cancel" }),
        /* @__PURE__ */ jsxRuntimeExports.jsx(Button, { onClick: () => save.mutate(), disabled: save.isPending, children: save.isPending ? "Saving…" : "Save client" })
      ] })
    ] })
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
  ClientFormDialog,
  Page as component
};
