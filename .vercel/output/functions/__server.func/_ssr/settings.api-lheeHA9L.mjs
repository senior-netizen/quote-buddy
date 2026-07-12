import { r as reactExports, j as jsxRuntimeExports } from "../_libs/react.mjs";
import { b as useQueryClient, u as useQuery, a as useMutation } from "../_libs/tanstack__react-query.mjs";
import { t as toast } from "../_libs/sonner.mjs";
import { s as supabase } from "./client-U3FzjMwq.mjs";
import { a as useActiveOrg, I as Input, B as Button, o as cn } from "./router-_O5wH3lZ.mjs";
import { L as Link } from "../_libs/tanstack__react-router.mjs";
import "./index.mjs";
import "../_libs/seroval.mjs";
import "../_libs/qrcode.mjs";
import { K as KeyRound, e as Copy, T as Trash2 } from "../_libs/lucide-react.mjs";
import "../_libs/tanstack__query-core.mjs";
import "../_libs/react-dom.mjs";
import "async_hooks";
import "util";
import "crypto";
import "stream";
import "../_libs/supabase__supabase-js.mjs";
import "../_libs/supabase__postgrest-js.mjs";
import "../_libs/supabase__realtime-js.mjs";
import "../_libs/supabase__phoenix.mjs";
import "../_libs/supabase__storage-js.mjs";
import "../_libs/iceberg-js.mjs";
import "../_libs/supabase__auth-js.mjs";
import "tslib";
import "../_libs/supabase__functions-js.mjs";
import "../_libs/tanstack__router-core.mjs";
import "../_libs/tanstack__history.mjs";
import "../_libs/cookie-es.mjs";
import "../_libs/seroval-plugins.mjs";
import "node:stream/web";
import "node:stream";
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
import "../_libs/react-remove-scroll-bar.mjs";
import "../_libs/react-style-singleton.mjs";
import "../_libs/get-nonce.mjs";
import "../_libs/use-sidecar.mjs";
import "../_libs/use-callback-ref.mjs";
import "../_libs/aria-hidden.mjs";
import "./auth-middleware-DJP7Badx.mjs";
import "./createMiddleware-BvN2ghIY.mjs";
import "./client.server-BMj2q4-x.mjs";
import "./calc-BF6zAv6d.mjs";
import "./docTypes-CsATll0j.mjs";
import "../_libs/zod.mjs";
import "./verifySign.server-CnraXCan.mjs";
import "../_libs/isbot.mjs";
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
const Card = reactExports.forwardRef(
  ({ className, ...props }, ref) => /* @__PURE__ */ jsxRuntimeExports.jsx(
    "div",
    {
      ref,
      className: cn("rounded-xl border bg-card text-card-foreground shadow", className),
      ...props
    }
  )
);
Card.displayName = "Card";
const CardHeader = reactExports.forwardRef(
  ({ className, ...props }, ref) => /* @__PURE__ */ jsxRuntimeExports.jsx("div", { ref, className: cn("flex flex-col space-y-1.5 p-6", className), ...props })
);
CardHeader.displayName = "CardHeader";
const CardTitle = reactExports.forwardRef(
  ({ className, ...props }, ref) => /* @__PURE__ */ jsxRuntimeExports.jsx(
    "div",
    {
      ref,
      className: cn("font-semibold leading-none tracking-tight", className),
      ...props
    }
  )
);
CardTitle.displayName = "CardTitle";
const CardDescription = reactExports.forwardRef(
  ({ className, ...props }, ref) => /* @__PURE__ */ jsxRuntimeExports.jsx("div", { ref, className: cn("text-sm text-muted-foreground", className), ...props })
);
CardDescription.displayName = "CardDescription";
const CardContent = reactExports.forwardRef(
  ({ className, ...props }, ref) => /* @__PURE__ */ jsxRuntimeExports.jsx("div", { ref, className: cn("p-6 pt-0", className), ...props })
);
CardContent.displayName = "CardContent";
const CardFooter = reactExports.forwardRef(
  ({ className, ...props }, ref) => /* @__PURE__ */ jsxRuntimeExports.jsx("div", { ref, className: cn("flex items-center p-6 pt-0", className), ...props })
);
CardFooter.displayName = "CardFooter";
const KEY_PREFIX = "qsk_live_";
async function sha256Hex(input) {
  const buf = new TextEncoder().encode(input);
  const digest = await crypto.subtle.digest("SHA-256", buf);
  return Array.from(new Uint8Array(digest)).map((b) => b.toString(16).padStart(2, "0")).join("");
}
function generateKey() {
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  const secret = Array.from(bytes).map((b) => b.toString(16).padStart(2, "0")).join("");
  return `${KEY_PREFIX}${secret}`;
}
function ApiSettingsPage() {
  const {
    data: activeOrg
  } = useActiveOrg();
  const orgId = activeOrg?.org_id;
  const qc = useQueryClient();
  const [name, setName] = reactExports.useState("");
  const [freshKey, setFreshKey] = reactExports.useState(null);
  const keysQuery = useQuery({
    enabled: !!orgId,
    queryKey: ["api-keys", orgId],
    queryFn: async () => {
      const {
        data,
        error
      } = await supabase.from("api_keys").select("id, name, prefix, created_at, last_used_at, revoked_at").eq("org_id", orgId).order("created_at", {
        ascending: false
      });
      if (error) throw error;
      return data ?? [];
    }
  });
  const create = useMutation({
    mutationFn: async () => {
      if (!orgId) throw new Error("No active org");
      const trimmed = name.trim();
      if (!trimmed) throw new Error("Name required");
      const {
        data: userRes
      } = await supabase.auth.getUser();
      const key = generateKey();
      const hash = await sha256Hex(key);
      const prefix = key.slice(0, KEY_PREFIX.length + 6);
      const {
        error
      } = await supabase.from("api_keys").insert({
        org_id: orgId,
        name: trimmed,
        prefix,
        key_hash: hash,
        created_by: userRes.user?.id ?? null
      });
      if (error) throw new Error(error.message);
      return key;
    },
    onSuccess: (key) => {
      setFreshKey(key);
      setName("");
      qc.invalidateQueries({
        queryKey: ["api-keys", orgId]
      });
    },
    onError: (e) => toast.error(e.message)
  });
  const revoke = useMutation({
    mutationFn: async (id) => {
      const {
        error
      } = await supabase.from("api_keys").update({
        revoked_at: (/* @__PURE__ */ new Date()).toISOString()
      }).eq("id", id);
      if (error) throw new Error(error.message);
    },
    onSuccess: () => {
      toast.success("Key revoked");
      qc.invalidateQueries({
        queryKey: ["api-keys", orgId]
      });
    },
    onError: (e) => toast.error(e.message)
  });
  const rotate = useMutation({
    mutationFn: async (existing) => {
      if (!orgId) throw new Error("No active org");
      const {
        data: userRes
      } = await supabase.auth.getUser();
      const key = generateKey();
      const hash = await sha256Hex(key);
      const prefix = key.slice(0, KEY_PREFIX.length + 6);
      const {
        error
      } = await supabase.from("api_keys").insert({
        org_id: orgId,
        name: `${existing.name} (rotated)`,
        prefix,
        key_hash: hash,
        created_by: userRes.user?.id ?? null
      });
      if (error) throw new Error(error.message);
      return key;
    },
    onSuccess: (key) => {
      setFreshKey(key);
      toast.success("New key issued. Old key still works — revoke it once you've migrated.");
      qc.invalidateQueries({
        queryKey: ["api-keys", orgId]
      });
    },
    onError: (e) => toast.error(e.message)
  });
  const remove = useMutation({
    mutationFn: async (id) => {
      const {
        error
      } = await supabase.from("api_keys").delete().eq("id", id);
      if (error) throw new Error(error.message);
    },
    onSuccess: () => {
      toast.success("Key deleted");
      qc.invalidateQueries({
        queryKey: ["api-keys", orgId]
      });
    },
    onError: (e) => toast.error(e.message)
  });
  reactExports.useEffect(() => {
    if (!freshKey) return;
    const t = setTimeout(() => {
    }, 0);
    return () => clearTimeout(t);
  }, [freshKey]);
  return /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "space-y-8 max-w-3xl", children: [
    /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { children: [
      /* @__PURE__ */ jsxRuntimeExports.jsx("h2", { className: "text-xl font-semibold", children: "API keys" }),
      /* @__PURE__ */ jsxRuntimeExports.jsxs("p", { className: "text-sm text-muted-foreground mt-1", children: [
        "Issue keys for external apps to call our",
        " ",
        /* @__PURE__ */ jsxRuntimeExports.jsx(Link, { to: "/developers", className: "underline", children: "public API" }),
        ". Each key acts on behalf of this organization."
      ] })
    ] }),
    /* @__PURE__ */ jsxRuntimeExports.jsxs(Card, { children: [
      /* @__PURE__ */ jsxRuntimeExports.jsx(CardHeader, { children: /* @__PURE__ */ jsxRuntimeExports.jsx(CardTitle, { className: "text-base", children: "Create a new key" }) }),
      /* @__PURE__ */ jsxRuntimeExports.jsxs(CardContent, { className: "space-y-3", children: [
        /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "flex gap-2", children: [
          /* @__PURE__ */ jsxRuntimeExports.jsx(Input, { placeholder: "e.g. Zapier integration", value: name, onChange: (e) => setName(e.target.value), disabled: create.isPending }),
          /* @__PURE__ */ jsxRuntimeExports.jsxs(Button, { onClick: () => create.mutate(), disabled: create.isPending || !name.trim(), children: [
            /* @__PURE__ */ jsxRuntimeExports.jsx(KeyRound, { className: "w-4 h-4 mr-1" }),
            "Generate"
          ] })
        ] }),
        freshKey && /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "rounded-md border border-amber-500/40 bg-amber-500/10 p-3 text-sm", children: [
          /* @__PURE__ */ jsxRuntimeExports.jsx("p", { className: "font-medium", children: "Copy this key now — it won't be shown again." }),
          /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "mt-2 flex items-center gap-2", children: [
            /* @__PURE__ */ jsxRuntimeExports.jsx("code", { className: "flex-1 break-all rounded bg-background/60 px-2 py-1 font-mono text-xs", children: freshKey }),
            /* @__PURE__ */ jsxRuntimeExports.jsx(Button, { size: "sm", variant: "outline", onClick: () => {
              navigator.clipboard.writeText(freshKey);
              toast.success("Copied");
            }, children: /* @__PURE__ */ jsxRuntimeExports.jsx(Copy, { className: "w-3.5 h-3.5" }) }),
            /* @__PURE__ */ jsxRuntimeExports.jsx(Button, { size: "sm", variant: "ghost", onClick: () => setFreshKey(null), children: "Dismiss" })
          ] })
        ] })
      ] })
    ] }),
    /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { children: [
      /* @__PURE__ */ jsxRuntimeExports.jsx("h3", { className: "text-sm font-medium mb-3", children: "Existing keys" }),
      keysQuery.isLoading ? /* @__PURE__ */ jsxRuntimeExports.jsx("p", { className: "text-sm text-muted-foreground", children: "Loading…" }) : keysQuery.data?.length ? /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "border border-hairline rounded-md divide-y divide-hairline", children: keysQuery.data.map((k) => /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "flex items-center justify-between gap-4 p-3", children: [
        /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "min-w-0", children: [
          /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "flex items-center gap-2", children: [
            /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: "font-medium truncate", children: k.name }),
            k.revoked_at ? /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: "text-[10px] uppercase tracking-wide px-1.5 py-0.5 rounded bg-destructive/10 text-destructive", children: "revoked" }) : /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: "text-[10px] uppercase tracking-wide px-1.5 py-0.5 rounded bg-emerald-500/15 text-emerald-600", children: "active" })
          ] }),
          /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "text-xs text-muted-foreground mt-0.5 font-mono", children: [
            k.prefix,
            "…"
          ] }),
          /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "text-[11px] text-muted-foreground mt-0.5", children: [
            "Created ",
            new Date(k.created_at).toLocaleDateString(),
            k.last_used_at ? ` · last used ${new Date(k.last_used_at).toLocaleDateString()}` : " · never used",
            k.revoked_at ? ` · revoked ${new Date(k.revoked_at).toLocaleDateString()}` : ""
          ] })
        ] }),
        /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "flex items-center gap-1", children: [
          !k.revoked_at && /* @__PURE__ */ jsxRuntimeExports.jsxs(jsxRuntimeExports.Fragment, { children: [
            /* @__PURE__ */ jsxRuntimeExports.jsx(Button, { variant: "outline", size: "sm", onClick: () => rotate.mutate(k), disabled: rotate.isPending, title: "Issue a replacement key. The old one keeps working until you revoke it.", children: "Rotate" }),
            /* @__PURE__ */ jsxRuntimeExports.jsx(Button, { variant: "outline", size: "sm", onClick: () => revoke.mutate(k.id), children: "Revoke" })
          ] }),
          /* @__PURE__ */ jsxRuntimeExports.jsx(Button, { variant: "ghost", size: "sm", onClick: () => remove.mutate(k.id), children: /* @__PURE__ */ jsxRuntimeExports.jsx(Trash2, { className: "w-4 h-4" }) })
        ] })
      ] }, k.id)) }) : /* @__PURE__ */ jsxRuntimeExports.jsx("p", { className: "text-sm text-muted-foreground", children: "No keys yet." })
    ] })
  ] });
}
export {
  ApiSettingsPage as component
};
