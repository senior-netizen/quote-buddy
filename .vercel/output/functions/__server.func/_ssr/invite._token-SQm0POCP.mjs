import { r as reactExports, j as jsxRuntimeExports } from "../_libs/react.mjs";
import { e as useNavigate, L as Link } from "../_libs/tanstack__react-router.mjs";
import { q as Route$c, u as useAuth, h as useServerFn, B as Button, s as getInvitation, t as acceptInvitation } from "./router-DjPnTx2E.mjs";
import { b as useQueryClient } from "../_libs/tanstack__react-query.mjs";
import { t as toast } from "../_libs/sonner.mjs";
import "./index.mjs";
import "../_libs/seroval.mjs";
import "../_libs/qrcode.mjs";
import { h as LoaderCircle, B as Building2 } from "../_libs/lucide-react.mjs";
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
import "../_libs/tanstack__query-core.mjs";
import "./client-U3FzjMwq.mjs";
import "../_libs/supabase__supabase-js.mjs";
import "../_libs/supabase__postgrest-js.mjs";
import "../_libs/supabase__realtime-js.mjs";
import "../_libs/supabase__phoenix.mjs";
import "../_libs/supabase__storage-js.mjs";
import "../_libs/iceberg-js.mjs";
import "../_libs/supabase__auth-js.mjs";
import "tslib";
import "../_libs/supabase__functions-js.mjs";
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
function InvitePage() {
  const {
    token
  } = Route$c.useParams();
  const inviteRedirect = `/invite/${encodeURIComponent(token)}`;
  const navigate = useNavigate();
  const {
    user,
    loading: authLoading
  } = useAuth();
  const lookupFn = useServerFn(getInvitation);
  const acceptFn = useServerFn(acceptInvitation);
  const qc = useQueryClient();
  const [info, setInfo] = reactExports.useState(null);
  const [loading, setLoading] = reactExports.useState(true);
  const [busy, setBusy] = reactExports.useState(false);
  reactExports.useEffect(() => {
    lookupFn({
      data: {
        token
      }
    }).then((r) => setInfo(r)).catch(() => setInfo({
      status: "not_found"
    })).finally(() => setLoading(false));
  }, [lookupFn, token]);
  const accept = async () => {
    setBusy(true);
    try {
      await acceptFn({
        data: {
          token
        }
      });
      await qc.invalidateQueries();
      toast.success("Joined organization");
      navigate({
        to: "/dashboard"
      });
    } catch (e) {
      toast.error(e instanceof Error ? e.message : "Failed");
    } finally {
      setBusy(false);
    }
  };
  if (loading) {
    return /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "flex min-h-screen items-center justify-center text-sm text-muted-foreground gap-2", children: [
      /* @__PURE__ */ jsxRuntimeExports.jsx(LoaderCircle, { className: "h-4 w-4 animate-spin" }),
      " Loading invitation…"
    ] });
  }
  return /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "flex min-h-screen items-center justify-center px-6", children: /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "w-full max-w-sm text-center", children: [
    /* @__PURE__ */ jsxRuntimeExports.jsx(Building2, { className: "mx-auto h-8 w-8" }),
    info?.status === "ok" ? /* @__PURE__ */ jsxRuntimeExports.jsxs(jsxRuntimeExports.Fragment, { children: [
      /* @__PURE__ */ jsxRuntimeExports.jsxs("h1", { className: "mt-6 text-2xl font-semibold tracking-tight", children: [
        "Join ",
        info.org_name
      ] }),
      /* @__PURE__ */ jsxRuntimeExports.jsxs("p", { className: "mt-2 text-sm text-muted-foreground", children: [
        "You've been invited to join as a ",
        /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: "font-medium", children: info.role }),
        "."
      ] }),
      /* @__PURE__ */ jsxRuntimeExports.jsxs("p", { className: "mt-1 text-xs text-muted-foreground", children: [
        "Invitation for ",
        info.email
      ] }),
      authLoading ? /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "mt-8 text-sm text-muted-foreground", children: "Loading…" }) : !user ? /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "mt-8 space-y-4", children: [
        /* @__PURE__ */ jsxRuntimeExports.jsx("p", { className: "text-sm text-muted-foreground", children: "Sign in or create an account before accepting this invitation." }),
        /* @__PURE__ */ jsxRuntimeExports.jsx(Link, { to: "/login", search: {
          redirect: inviteRedirect
        }, className: "inline-block w-full", children: /* @__PURE__ */ jsxRuntimeExports.jsx(Button, { className: "w-full rounded-full", children: "Sign in or create account to accept" }) })
      ] }) : /* @__PURE__ */ jsxRuntimeExports.jsx(Button, { onClick: accept, disabled: busy, className: "mt-8 w-full rounded-full", children: busy ? "Joining…" : "Accept invitation" })
    ] }) : info?.status === "expired" ? /* @__PURE__ */ jsxRuntimeExports.jsx(Msg, { title: "Invitation expired", body: "Ask the organization owner to send a new one." }) : info?.status === "accepted" ? /* @__PURE__ */ jsxRuntimeExports.jsx(Msg, { title: "Already accepted", body: "This invitation has already been used." }) : /* @__PURE__ */ jsxRuntimeExports.jsx(Msg, { title: "Invitation not found", body: "The link may be incorrect or revoked." })
  ] }) });
}
function Msg({
  title,
  body
}) {
  return /* @__PURE__ */ jsxRuntimeExports.jsxs(jsxRuntimeExports.Fragment, { children: [
    /* @__PURE__ */ jsxRuntimeExports.jsx("h1", { className: "mt-6 text-2xl font-semibold tracking-tight", children: title }),
    /* @__PURE__ */ jsxRuntimeExports.jsx("p", { className: "mt-2 text-sm text-muted-foreground", children: body }),
    /* @__PURE__ */ jsxRuntimeExports.jsx(Link, { to: "/", className: "mt-8 inline-block text-xs underline underline-offset-4", children: "Go home" })
  ] });
}
export {
  InvitePage as component
};
