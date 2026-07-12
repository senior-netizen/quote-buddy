import { r as reactExports, j as jsxRuntimeExports } from "../_libs/react.mjs";
import { e as useNavigate, L as Link } from "../_libs/tanstack__react-router.mjs";
import { u as useAuth } from "./router-_O5wH3lZ.mjs";
import "../_libs/sonner.mjs";
import "./index.mjs";
import "../_libs/seroval.mjs";
import "../_libs/qrcode.mjs";
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
import "../_libs/tanstack__react-query.mjs";
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
import "../_libs/lucide-react.mjs";
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
const url = "/logo.png";
const logo = {
  url
};
function Index() {
  const {
    user,
    loading
  } = useAuth();
  const navigate = useNavigate();
  reactExports.useEffect(() => {
    if (!loading && user) navigate({
      to: "/dashboard"
    });
  }, [loading, user, navigate]);
  return /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "min-h-screen bg-background", children: [
    /* @__PURE__ */ jsxRuntimeExports.jsxs("header", { className: "mx-auto flex h-14 max-w-6xl items-center justify-between px-4 sm:px-6", children: [
      /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "flex items-center gap-2 min-w-0", children: [
        /* @__PURE__ */ jsxRuntimeExports.jsx("img", { src: logo.url, alt: "Qouteflow", className: "h-10 w-10 object-contain" }),
        /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: "text-[17px] font-semibold tracking-tight", children: "Qouteflow" })
      ] }),
      /* @__PURE__ */ jsxRuntimeExports.jsx(Link, { to: "/login", className: "text-[13px] text-muted-foreground hover:text-foreground whitespace-nowrap", children: "Sign in →" })
    ] }),
    /* @__PURE__ */ jsxRuntimeExports.jsxs("main", { className: "mx-auto max-w-3xl px-4 pt-16 pb-16 text-center sm:px-6 sm:pt-32 sm:pb-24", children: [
      /* @__PURE__ */ jsxRuntimeExports.jsx("p", { className: "text-[11px] uppercase tracking-[0.25em] text-muted-foreground", children: "Quotations · Invoices · PDFs" }),
      /* @__PURE__ */ jsxRuntimeExports.jsxs("h1", { className: "mt-6 text-4xl sm:text-6xl font-semibold tracking-tight leading-[1.05]", children: [
        "Beautiful documents.",
        /* @__PURE__ */ jsxRuntimeExports.jsx("br", {}),
        /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: "text-muted-foreground", children: "Generated in seconds." })
      ] }),
      /* @__PURE__ */ jsxRuntimeExports.jsx("p", { className: "mx-auto mt-6 max-w-xl text-[15px] leading-relaxed text-muted-foreground", children: "A focused tool for issuing branded quotations and invoices. No clutter, no busywork — just clean PDFs ready to send." }),
      /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "mt-10 flex items-center justify-center gap-3", children: /* @__PURE__ */ jsxRuntimeExports.jsx(Link, { to: "/login", className: "rounded-full bg-primary px-6 py-2.5 text-[14px] font-medium text-primary-foreground transition-opacity hover:opacity-90", children: "Open QuoteFlow" }) }),
      /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "mt-16 sm:mt-24 grid grid-cols-1 sm:grid-cols-3 gap-px overflow-hidden rounded-2xl border border-hairline bg-hairline text-left", children: [{
        k: "QT-2025-0001",
        l: "Auto-numbered"
      }, {
        k: "Real-time",
        l: "Calculations"
      }, {
        k: "PDF",
        l: "Pixel-perfect output"
      }].map((c) => /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "bg-card p-6", children: [
        /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "text-xs uppercase tracking-wider text-muted-foreground", children: c.l }),
        /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "mt-2 text-lg font-medium tracking-tight", children: c.k })
      ] }, c.k)) })
    ] })
  ] });
}
export {
  Index as component
};
