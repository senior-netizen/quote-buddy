import { j as jsxRuntimeExports, r as reactExports } from "../_libs/react.mjs";
import { c as createRouter, u as useRouter, a as createRootRoute, b as createFileRoute, l as lazyRouteComponent, H as HeadContent, S as Scripts, O as Outlet } from "../_libs/tanstack__react-router.mjs";
import { l as isRedirect } from "../_libs/tanstack__router-core.mjs";
import { b as QueryClient } from "../_libs/tanstack__query-core.mjs";
import { Q as QueryClientProvider, u as useQuery, a as useMutation, b as useQueryClient } from "../_libs/tanstack__react-query.mjs";
import { T as Toaster, t as toast } from "../_libs/sonner.mjs";
import { s as supabase } from "./client-U3FzjMwq.mjs";
import { S as Slot } from "../_libs/radix-ui__react-slot.mjs";
import { c as cva } from "../_libs/class-variance-authority.mjs";
import { c as clsx } from "../_libs/clsx.mjs";
import { t as twMerge } from "../_libs/tailwind-merge.mjs";
import { R as Root } from "../_libs/radix-ui__react-label.mjs";
import { O as Overlay, P as Portal, C as Content, a as Close, T as Title, D as Description, R as Root$1, b as Trigger } from "../_libs/radix-ui__react-dialog.mjs";
import { c as createServerFn, T as TSS_SERVER_FUNCTION, g as getServerFnById } from "./index.mjs";
import { r as requireSupabaseAuth } from "./auth-middleware-DJP7Badx.mjs";
import { supabaseAdmin } from "./client.server-BMj2q4-x.mjs";
import { f as formatMoney, r as rowTotal, a as formatDate, c as computeTotals } from "./calc-BF6zAv6d.mjs";
import { d as documentTypeSchema } from "./docTypes-CsATll0j.mjs";
import { c as createClient } from "../_libs/supabase__supabase-js.mjs";
import { Q as QRCode } from "../_libs/qrcode.mjs";
import { c as computeDocHash, s as signVerifyToken } from "./verifySign.server-CnraXCan.mjs";
import { X } from "../_libs/lucide-react.mjs";
import { o as object, s as string, n as number, a as array, _ as _enum, l as literal } from "../_libs/zod.mjs";
import "../_libs/react-dom.mjs";
import "async_hooks";
import "util";
import "crypto";
import "stream";
import "node:stream";
import "../_libs/isbot.mjs";
import "../_libs/tanstack__history.mjs";
import "../_libs/cookie-es.mjs";
import "../_libs/seroval.mjs";
import "../_libs/seroval-plugins.mjs";
import "node:stream/web";
import "../_libs/radix-ui__react-compose-refs.mjs";
import "../_libs/radix-ui__react-primitive.mjs";
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
import "node:async_hooks";
import "../_libs/h3-v2.mjs";
import "../_libs/rou3.mjs";
import "../_libs/srvx.mjs";
import "./createMiddleware-BvN2ghIY.mjs";
import "../_libs/supabase__postgrest-js.mjs";
import "../_libs/supabase__realtime-js.mjs";
import "../_libs/supabase__phoenix.mjs";
import "../_libs/supabase__storage-js.mjs";
import "../_libs/iceberg-js.mjs";
import "../_libs/supabase__auth-js.mjs";
import "../_libs/supabase__functions-js.mjs";
import "../_libs/dijkstrajs.mjs";
import "fs";
import "../_libs/pngjs.mjs";
import "zlib";
import "assert";
import "buffer";
function useServerFn(serverFn) {
  const router2 = useRouter();
  return reactExports.useCallback(async (...args) => {
    try {
      const res = await serverFn(...args);
      if (isRedirect(res)) throw res;
      return res;
    } catch (err) {
      if (isRedirect(err)) {
        err.options._fromLocation = router2.stores.location.get();
        return router2.navigate(router2.resolveRedirect(err).options);
      }
      throw err;
    }
  }, [router2, serverFn]);
}
const Ctx = reactExports.createContext(null);
function AuthProvider({ children }) {
  const [user, setUser] = reactExports.useState(null);
  const [session, setSession] = reactExports.useState(null);
  const [loading, setLoading] = reactExports.useState(true);
  reactExports.useEffect(() => {
    const { data: sub } = supabase.auth.onAuthStateChange((_e, s) => {
      setSession(s);
      setUser(s?.user ?? null);
    });
    supabase.auth.getSession().then(({ data }) => {
      setSession(data.session);
      setUser(data.session?.user ?? null);
      setLoading(false);
    });
    return () => sub.subscription.unsubscribe();
  }, []);
  const signIn = async (email, password) => {
    const { error } = await supabase.auth.signInWithPassword({ email, password });
    if (error) throw error;
  };
  const signUp = async (email, password, redirectTo = "/dashboard") => {
    const { error } = await supabase.auth.signUp({
      email,
      password,
      options: { emailRedirectTo: `${window.location.origin}${redirectTo}` }
    });
    if (error) throw error;
  };
  const signOut = async () => {
    await supabase.auth.signOut();
  };
  return /* @__PURE__ */ jsxRuntimeExports.jsx(Ctx.Provider, { value: { user, session, loading, signIn, signUp, signOut }, children });
}
function useAuth() {
  const ctx = reactExports.useContext(Ctx);
  if (!ctx) throw new Error("useAuth must be used inside AuthProvider");
  return ctx;
}
const appCss = "/assets/styles-DYEVi6pR.css";
const Route$r = createRootRoute({
  head: () => ({
    meta: [
      { charSet: "utf-8" },
      { name: "viewport", content: "width=device-width, initial-scale=1" },
      { title: "QuoteFlow — Quotations & Invoices" },
      { name: "description", content: "Generate branded quotations and invoices as downloadable PDFs." },
      { property: "og:title", content: "QuoteFlow — Quotations & Invoices" },
      { name: "twitter:title", content: "QuoteFlow — Quotations & Invoices" },
      { property: "og:description", content: "Generate branded quotations and invoices as downloadable PDFs." },
      { name: "twitter:description", content: "Generate branded quotations and invoices as downloadable PDFs." },
      { property: "og:image", content: "/favicon.png?v=2" },
      { name: "twitter:image", content: "/favicon.png?v=2" },
      { name: "twitter:card", content: "summary_large_image" },
      { property: "og:type", content: "website" }
    ],
    links: [
      { rel: "stylesheet", href: appCss },
      { rel: "icon", type: "image/png", href: "/favicon.png?v=2" },
      { rel: "sitemap", type: "application/xml", href: "/sitemap.xml" }
    ]
  }),
  shellComponent: RootShell,
  component: RootComponent,
  notFoundComponent: () => /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "flex min-h-screen items-center justify-center px-4", children: /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "max-w-md text-center", children: [
    /* @__PURE__ */ jsxRuntimeExports.jsx("h1", { className: "text-7xl font-semibold tracking-tight", children: "404" }),
    /* @__PURE__ */ jsxRuntimeExports.jsx("p", { className: "mt-4 text-sm text-muted-foreground", children: "This page doesn't exist." }),
    /* @__PURE__ */ jsxRuntimeExports.jsx("a", { href: "/", className: "mt-6 inline-block text-sm underline underline-offset-4", children: "Go home" })
  ] }) })
});
function RootShell({ children }) {
  return /* @__PURE__ */ jsxRuntimeExports.jsxs("html", { lang: "en", children: [
    /* @__PURE__ */ jsxRuntimeExports.jsx("head", { children: /* @__PURE__ */ jsxRuntimeExports.jsx(HeadContent, {}) }),
    /* @__PURE__ */ jsxRuntimeExports.jsxs("body", { children: [
      children,
      /* @__PURE__ */ jsxRuntimeExports.jsx(Scripts, {})
    ] })
  ] });
}
function RootComponent() {
  const [qc] = reactExports.useState(() => new QueryClient({ defaultOptions: { queries: { staleTime: 3e4, refetchOnWindowFocus: false } } }));
  return /* @__PURE__ */ jsxRuntimeExports.jsx(QueryClientProvider, { client: qc, children: /* @__PURE__ */ jsxRuntimeExports.jsxs(AuthProvider, { children: [
    /* @__PURE__ */ jsxRuntimeExports.jsx(Outlet, {}),
    /* @__PURE__ */ jsxRuntimeExports.jsx(Toaster, { position: "top-center" })
  ] }) });
}
const SITEMAP_ROUTES = [
  { path: "/", priority: "1.0", changefreq: "weekly" },
  { path: "/developers", priority: "0.7", changefreq: "monthly" }
];
const Route$q = createFileRoute("/sitemap.xml")({
  server: {
    handlers: {
      GET: async ({ request }) => {
        const origin = getCanonicalOrigin$1(request);
        const lastmod = (/* @__PURE__ */ new Date()).toISOString().split("T")[0];
        const urls = SITEMAP_ROUTES.map(
          ({ path, priority, changefreq }) => `  <url>
    <loc>${escapeXml(`${origin}${path}`)}</loc>
    <lastmod>${lastmod}</lastmod>
    <changefreq>${changefreq}</changefreq>
    <priority>${priority}</priority>
  </url>`
        ).join("\n");
        return new Response(`<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${urls}
</urlset>
`, {
          headers: {
            "content-type": "application/xml; charset=utf-8",
            "cache-control": "public, max-age=3600"
          }
        });
      }
    }
  }
});
function getCanonicalOrigin$1(request) {
  const configuredOrigin = process.env.APP_ORIGIN?.trim();
  if (configuredOrigin) return configuredOrigin.replace(/\/$/, "");
  return new URL(request.url).origin;
}
function escapeXml(value) {
  return value.replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;").replaceAll('"', "&quot;").replaceAll("'", "&apos;");
}
const $$splitComponentImporter$f = () => import("./settings-D58AdmSF.mjs");
const Route$p = createFileRoute("/settings")({
  component: lazyRouteComponent($$splitComponentImporter$f, "component")
});
const Route$o = createFileRoute("/robots.txt")({
  server: {
    handlers: {
      GET: async ({ request }) => {
        const origin = getCanonicalOrigin(request);
        return new Response(`User-agent: *
Allow: /
Disallow: /api/
Disallow: /dashboard
Disallow: /documents
Disallow: /settings
Disallow: /clients
Disallow: /invite
Disallow: /verify

Sitemap: ${origin}/sitemap.xml
`, {
          headers: {
            "content-type": "text/plain; charset=utf-8",
            "cache-control": "public, max-age=3600"
          }
        });
      }
    }
  }
});
function getCanonicalOrigin(request) {
  const configuredOrigin = process.env.APP_ORIGIN?.trim();
  if (configuredOrigin) return configuredOrigin.replace(/\/$/, "");
  return new URL(request.url).origin;
}
const $$splitComponentImporter$e = () => import("./login-B1w15uKL.mjs");
function getInternalRedirect(value) {
  if (typeof value !== "string") return void 0;
  if (!value.startsWith("/") || value.startsWith("//") || value.includes("\\")) return void 0;
  return value;
}
const Route$n = createFileRoute("/login")({
  validateSearch: (search) => ({
    redirect: getInternalRedirect(search.redirect)
  }),
  component: lazyRouteComponent($$splitComponentImporter$e, "component")
});
const $$splitComponentImporter$d = () => import("./developers-DL_gC3xU.mjs");
const Route$m = createFileRoute("/developers")({
  head: () => ({
    meta: [{
      title: "Developer API — QuoteScribe"
    }, {
      name: "description",
      content: "REST API and SDKs for managing clients, quotes, and invoices programmatically."
    }]
  }),
  component: lazyRouteComponent($$splitComponentImporter$d, "component")
});
const $$splitComponentImporter$c = () => import("./dashboard-dHEyEB-8.mjs");
const Route$l = createFileRoute("/dashboard")({
  component: lazyRouteComponent($$splitComponentImporter$c, "component")
});
function cn(...inputs) {
  return twMerge(clsx(inputs));
}
const buttonVariants = cva(
  "inline-flex items-center justify-center gap-2 whitespace-nowrap rounded-md text-sm font-medium transition-colors focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring disabled:pointer-events-none disabled:opacity-50 [&_svg]:pointer-events-none [&_svg]:size-4 [&_svg]:shrink-0",
  {
    variants: {
      variant: {
        default: "bg-primary text-primary-foreground shadow hover:bg-primary/90",
        destructive: "bg-destructive text-destructive-foreground shadow-sm hover:bg-destructive/90",
        outline: "border border-input bg-background shadow-sm hover:bg-accent hover:text-accent-foreground",
        secondary: "bg-secondary text-secondary-foreground shadow-sm hover:bg-secondary/80",
        ghost: "hover:bg-accent hover:text-accent-foreground",
        link: "text-primary underline-offset-4 hover:underline"
      },
      size: {
        default: "h-9 px-4 py-2",
        sm: "h-8 rounded-md px-3 text-xs",
        lg: "h-10 rounded-md px-8",
        icon: "h-9 w-9"
      }
    },
    defaultVariants: {
      variant: "default",
      size: "default"
    }
  }
);
const Button = reactExports.forwardRef(
  ({ className, variant, size, asChild = false, ...props }, ref) => {
    const Comp = asChild ? Slot : "button";
    return /* @__PURE__ */ jsxRuntimeExports.jsx(Comp, { className: cn(buttonVariants({ variant, size, className })), ref, ...props });
  }
);
Button.displayName = "Button";
const Input = reactExports.forwardRef(
  ({ className, type, ...props }, ref) => {
    return /* @__PURE__ */ jsxRuntimeExports.jsx(
      "input",
      {
        type,
        className: cn(
          "flex h-9 w-full rounded-md border border-input bg-transparent px-3 py-1 text-base shadow-sm transition-colors file:border-0 file:bg-transparent file:text-sm file:font-medium file:text-foreground placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring disabled:cursor-not-allowed disabled:opacity-50 md:text-sm",
          className
        ),
        ref,
        ...props
      }
    );
  }
);
Input.displayName = "Input";
const labelVariants = cva(
  "text-sm font-medium leading-none peer-disabled:cursor-not-allowed peer-disabled:opacity-70"
);
const Label = reactExports.forwardRef(({ className, ...props }, ref) => /* @__PURE__ */ jsxRuntimeExports.jsx(Root, { ref, className: cn(labelVariants(), className), ...props }));
Label.displayName = Root.displayName;
const Textarea = reactExports.forwardRef(
  ({ className, ...props }, ref) => {
    return /* @__PURE__ */ jsxRuntimeExports.jsx(
      "textarea",
      {
        className: cn(
          "flex min-h-[60px] w-full rounded-md border border-input bg-transparent px-3 py-2 text-base shadow-sm placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring disabled:cursor-not-allowed disabled:opacity-50 md:text-sm",
          className
        ),
        ref,
        ...props
      }
    );
  }
);
Textarea.displayName = "Textarea";
const Dialog = Root$1;
const DialogTrigger = Trigger;
const DialogPortal = Portal;
const DialogOverlay = reactExports.forwardRef(({ className, ...props }, ref) => /* @__PURE__ */ jsxRuntimeExports.jsx(
  Overlay,
  {
    ref,
    className: cn(
      "fixed inset-0 z-50 bg-black/80  data-[state=open]:animate-in data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0",
      className
    ),
    ...props
  }
));
DialogOverlay.displayName = Overlay.displayName;
const DialogContent = reactExports.forwardRef(({ className, children, ...props }, ref) => /* @__PURE__ */ jsxRuntimeExports.jsxs(DialogPortal, { children: [
  /* @__PURE__ */ jsxRuntimeExports.jsx(DialogOverlay, {}),
  /* @__PURE__ */ jsxRuntimeExports.jsxs(
    Content,
    {
      ref,
      className: cn(
        "fixed left-[50%] top-[50%] z-50 grid w-[calc(100vw-2rem)] max-w-lg max-h-[calc(100dvh-2rem)] overflow-y-auto translate-x-[-50%] translate-y-[-50%] gap-4 border bg-background p-6 shadow-lg duration-200 rounded-lg data-[state=open]:animate-in data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0 data-[state=closed]:zoom-out-95 data-[state=open]:zoom-in-95 data-[state=closed]:slide-out-to-left-1/2 data-[state=closed]:slide-out-to-top-[48%] data-[state=open]:slide-in-from-left-1/2 data-[state=open]:slide-in-from-top-[48%]",
        className
      ),
      ...props,
      children: [
        children,
        /* @__PURE__ */ jsxRuntimeExports.jsxs(Close, { className: "absolute right-4 top-4 rounded-sm opacity-70 ring-offset-background transition-opacity hover:opacity-100 focus:outline-none focus:ring-2 focus:ring-ring focus:ring-offset-2 disabled:pointer-events-none data-[state=open]:bg-accent data-[state=open]:text-muted-foreground", children: [
          /* @__PURE__ */ jsxRuntimeExports.jsx(X, { className: "h-4 w-4" }),
          /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: "sr-only", children: "Close" })
        ] })
      ]
    }
  )
] }));
DialogContent.displayName = Content.displayName;
const DialogHeader = ({ className, ...props }) => /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: cn("flex flex-col space-y-1.5 text-center sm:text-left", className), ...props });
DialogHeader.displayName = "DialogHeader";
const DialogFooter = ({ className, ...props }) => /* @__PURE__ */ jsxRuntimeExports.jsx(
  "div",
  {
    className: cn("flex flex-col-reverse sm:flex-row sm:justify-end sm:space-x-2", className),
    ...props
  }
);
DialogFooter.displayName = "DialogFooter";
const DialogTitle = reactExports.forwardRef(({ className, ...props }, ref) => /* @__PURE__ */ jsxRuntimeExports.jsx(
  Title,
  {
    ref,
    className: cn("text-lg font-semibold leading-none tracking-tight", className),
    ...props
  }
));
DialogTitle.displayName = Title.displayName;
const DialogDescription = reactExports.forwardRef(({ className, ...props }, ref) => /* @__PURE__ */ jsxRuntimeExports.jsx(
  Description,
  {
    ref,
    className: cn("text-sm text-muted-foreground", className),
    ...props
  }
));
DialogDescription.displayName = Description.displayName;
var createSsrRpc = (functionId) => {
  const url = "/_serverFn/" + functionId;
  const serverFnMeta = { id: functionId };
  const fn = async (...args) => {
    return (await getServerFnById(functionId))(...args);
  };
  return Object.assign(fn, {
    url,
    serverFnMeta,
    [TSS_SERVER_FUNCTION]: true
  });
};
const getActiveOrg = createServerFn({
  method: "GET"
}).middleware([requireSupabaseAuth]).handler(createSsrRpc("a712b874dcb0ba56f949ac0ba011125a966c33b5fee3f7860a15c94f9f419f84"));
const getMyOrganizations = createServerFn({
  method: "GET"
}).middleware([requireSupabaseAuth]).handler(createSsrRpc("f6df55ef7fb88800491b81ab55dd21438f9af2d5b3f72405fa4a43d34dd4b4c8"));
const setActiveOrg = createServerFn({
  method: "POST"
}).middleware([requireSupabaseAuth]).inputValidator((d) => object({
  org_id: string().uuid()
}).parse(d)).handler(createSsrRpc("fd7499eddb13ac796ed2536f123650591c4c896dc31515c9627671dfd3a67093"));
const createOrganization = createServerFn({
  method: "POST"
}).middleware([requireSupabaseAuth]).inputValidator((d) => object({
  name: string().trim().min(1).max(200)
}).parse(d)).handler(createSsrRpc("84b0c2eecdbf4659ef0c593620079dbe3c2111e6a133e76e79a176da6d860713"));
const ProfileUpdateSchema = object({
  name: string().trim().min(1).max(200),
  short_name: string().trim().max(80).optional().nullable(),
  logo_url: string().trim().url().max(2e3).optional().nullable(),
  emails: array(string().trim().email().max(255)).max(10).default([]),
  website: string().trim().max(255).optional().nullable(),
  registration: string().trim().max(80).optional().nullable(),
  tin: string().trim().max(80).optional().nullable(),
  duns: string().trim().max(80).optional().nullable(),
  praz: string().trim().max(80).optional().nullable(),
  currency: string().trim().min(1).max(8),
  default_tax_rate: number().min(0).max(100),
  address: string().trim().max(500).optional().nullable(),
  phone: string().trim().max(40).optional().nullable(),
  payment_instructions: string().trim().max(1e3).optional().nullable()
});
createServerFn({
  method: "POST"
}).middleware([requireSupabaseAuth]).inputValidator((d) => object({
  org_id: string().uuid(),
  patch: ProfileUpdateSchema
}).parse(d)).handler(createSsrRpc("f9486fae176dc8b4aebdd0a79c382df56fe80902ff4ee323327d968d2f5514c9"));
const listMembers = createServerFn({
  method: "GET"
}).middleware([requireSupabaseAuth]).inputValidator((d) => object({
  org_id: string().uuid()
}).parse(d)).handler(createSsrRpc("9eb59f5b6ed98c991d38bc0c6f97b2596050741426092f4a6d6b418df4973982"));
const verifyEmailConfiguration = createServerFn({
  method: "POST"
}).middleware([requireSupabaseAuth]).inputValidator((d) => object({
  org_id: string().uuid()
}).parse(d)).handler(createSsrRpc("2256e1bfd5d91b72f7e1fc49d84f822d96b2cdbd133520f127a379ab8773a788"));
const inviteMember = createServerFn({
  method: "POST"
}).middleware([requireSupabaseAuth]).inputValidator((d) => object({
  org_id: string().uuid(),
  email: string().trim().email().max(255),
  role: _enum(["owner", "admin", "member"])
}).parse(d)).handler(createSsrRpc("b426aeeef2518b0319c52f7c77edfbcff23decd9c46a9eccdeda2c88b8fd6ecb"));
const listInvitations = createServerFn({
  method: "GET"
}).middleware([requireSupabaseAuth]).inputValidator((d) => object({
  org_id: string().uuid()
}).parse(d)).handler(createSsrRpc("cf705c555671f0b12ea8d915d942b8fdc5adeafb09d0597e28fff6c239955315"));
const revokeInvitation = createServerFn({
  method: "POST"
}).middleware([requireSupabaseAuth]).inputValidator((d) => object({
  id: string().uuid(),
  org_id: string().uuid()
}).parse(d)).handler(createSsrRpc("aaf774323bd8740e9a9bb00cf585ba963e2c90da6cb3b4272491b50cda9e7e8f"));
const removeMember = createServerFn({
  method: "POST"
}).middleware([requireSupabaseAuth]).inputValidator((d) => object({
  id: string().uuid(),
  org_id: string().uuid()
}).parse(d)).handler(createSsrRpc("4bf7f32b4392bf2b7eeab37fa0189fbe8e625a84022323b98d66ad05ac9580f3"));
const changeMemberRole = createServerFn({
  method: "POST"
}).middleware([requireSupabaseAuth]).inputValidator((d) => object({
  id: string().uuid(),
  org_id: string().uuid(),
  role: _enum(["owner", "admin", "member"])
}).parse(d)).handler(createSsrRpc("5b6fb3943afd9658925d57f7c7db2425dc5e088f15813e85c5dceab2bf210015"));
const getInvitation = createServerFn({
  method: "POST"
}).inputValidator((d) => object({
  token: string().trim().min(1).max(128)
}).parse(d)).handler(createSsrRpc("8a1a326815219806a6afe2fbfebff5f7a631ade78d6eb18a322567b5a24c0d37"));
const acceptInvitation = createServerFn({
  method: "POST"
}).middleware([requireSupabaseAuth]).inputValidator((d) => object({
  token: string().trim().min(1).max(128)
}).parse(d)).handler(createSsrRpc("f0e3a4b46b51e1ef7c6ad701ca9ea4a1f855dd767589c6e69b9392d20bfa8c39"));
const getDocumentIssuerBrand = createServerFn({
  method: "POST"
}).inputValidator((d) => object({
  id: string().trim().min(1).max(64)
}).parse(d)).handler(createSsrRpc("6ad53436a5e87e5dc7122d5cc9863663c4018b62b43d563e9efdcd77a69e5723"));
async function urlToDataUrl(url) {
  try {
    const res = await fetch(url, { cache: "force-cache" });
    if (!res.ok) return null;
    const blob = await res.blob();
    return await new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = () => resolve(reader.result);
      reader.onerror = () => reject(reader.error);
      reader.readAsDataURL(blob);
    });
  } catch {
    return null;
  }
}
const ACTIVE_ORG_KEY = ["active-org"];
const MY_ORGS_KEY = ["my-orgs"];
function profileFallback(activeOrg) {
  return {
    org_id: activeOrg.org_id,
    name: activeOrg.org_name,
    short_name: null,
    logo_url: null,
    emails: [],
    website: null,
    registration: null,
    tin: null,
    duns: null,
    praz: null,
    currency: "USD",
    default_tax_rate: 15,
    address: null,
    phone: null,
    payment_instructions: null
  };
}
function normalizeActiveOrg(activeOrg) {
  if (!activeOrg) return activeOrg;
  return {
    ...activeOrg,
    profile: {
      ...profileFallback(activeOrg),
      ...activeOrg.profile ?? {},
      emails: activeOrg.profile?.emails ?? []
    }
  };
}
function useActiveOrg() {
  const getActive = useServerFn(getActiveOrg);
  return useQuery({
    queryKey: ACTIVE_ORG_KEY,
    queryFn: async () => normalizeActiveOrg(await getActive()),
    staleTime: 6e4
  });
}
function useMyOrganizations() {
  const list = useServerFn(getMyOrganizations);
  return useQuery({
    queryKey: MY_ORGS_KEY,
    queryFn: () => list(),
    staleTime: 6e4
  });
}
function useSwitchActiveOrg() {
  const setFn = useServerFn(setActiveOrg);
  const qc = useQueryClient();
  return reactExports.useCallback(
    async (org_id) => {
      await setFn({ data: { org_id } });
      await qc.invalidateQueries({ queryKey: ACTIVE_ORG_KEY });
      await qc.invalidateQueries({ queryKey: MY_ORGS_KEY });
      await qc.invalidateQueries();
    },
    [setFn, qc]
  );
}
async function profileToBrand(profile) {
  const logo_data_url = profile.logo_url ? await urlToDataUrl(profile.logo_url) : null;
  return {
    name: profile.name,
    short_name: profile.short_name,
    logo_data_url,
    emails: profile.emails ?? [],
    website: profile.website,
    registration: profile.registration,
    tin: profile.tin,
    duns: profile.duns,
    praz: profile.praz,
    currency: profile.currency,
    default_tax_rate: Number(profile.default_tax_rate),
    address: profile.address,
    phone: profile.phone,
    payment_instructions: profile.payment_instructions
  };
}
const $$splitComponentImporter$b = () => import("./clients-bxge_HLJ.mjs");
const Route$k = createFileRoute("/clients")({
  component: lazyRouteComponent($$splitComponentImporter$b, "component")
});
const ClientSchema = object({
  company_name: string().trim().min(1, "Required").max(200),
  address: string().trim().max(500).optional().or(literal("")),
  email: string().trim().email("Invalid email").max(255).optional().or(literal("")),
  phone: string().trim().max(40).optional().or(literal(""))
});
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
const $$splitComponentImporter$a = () => import("./index-DquQh4O6.mjs");
const Route$j = createFileRoute("/")({
  component: lazyRouteComponent($$splitComponentImporter$a, "component")
});
const $$splitComponentImporter$9 = () => import("./documents.index-B2Zrc-O2.mjs");
const Route$i = createFileRoute("/documents/")({
  component: lazyRouteComponent($$splitComponentImporter$9, "component")
});
const $$splitComponentImporter$8 = () => import("./verify._id-BFFQO3nc.mjs");
const Route$h = createFileRoute("/verify/$id")({
  validateSearch: (s) => ({
    sig: typeof s.sig === "string" ? s.sig : void 0,
    h: typeof s.h === "string" ? s.h : void 0
  }),
  head: () => ({
    meta: [{
      title: "Verify Document"
    }, {
      name: "description",
      content: "Verify the authenticity of an invoice or quotation."
    }, {
      name: "robots",
      content: "noindex"
    }]
  }),
  component: lazyRouteComponent($$splitComponentImporter$8, "component")
});
const $$splitComponentImporter$7 = () => import("./settings.team-B9CF6mxr.mjs");
const Route$g = createFileRoute("/settings/team")({
  component: lazyRouteComponent($$splitComponentImporter$7, "component")
});
const $$splitComponentImporter$6 = () => import("./settings.organization-CPLhF1u-.mjs");
const Route$f = createFileRoute("/settings/organization")({
  component: lazyRouteComponent($$splitComponentImporter$6, "component")
});
const $$splitComponentImporter$5 = () => import("./settings.fiscal-DRt2_tP6.mjs");
const Route$e = createFileRoute("/settings/fiscal")({
  component: lazyRouteComponent($$splitComponentImporter$5, "component")
});
const $$splitComponentImporter$4 = () => import("./settings.api-jkKilbg9.mjs");
const Route$d = createFileRoute("/settings/api")({
  component: lazyRouteComponent($$splitComponentImporter$4, "component")
});
const $$splitComponentImporter$3 = () => import("./invite._token-CpHUlzQG.mjs");
const Route$c = createFileRoute("/invite/$token")({
  component: lazyRouteComponent($$splitComponentImporter$3, "component")
});
const $$splitComponentImporter$2 = () => import("./documents.new-Cba1wDpX.mjs");
const Route$b = createFileRoute("/documents/new")({
  component: lazyRouteComponent($$splitComponentImporter$2, "component")
});
const $$splitComponentImporter$1 = () => import("./documents._id.index-eOHyGMl4.mjs");
const Route$a = createFileRoute("/documents/$id/")({
  component: lazyRouteComponent($$splitComponentImporter$1, "component")
});
const $$splitComponentImporter = () => import("./documents._id.edit-C8D8R1JU.mjs");
const Route$9 = createFileRoute("/documents/$id/edit")({
  component: lazyRouteComponent($$splitComponentImporter, "component")
});
const KEY_PREFIX = "qsk_live_";
async function sha256Hex(input) {
  const buf = new TextEncoder().encode(input);
  const digest = await crypto.subtle.digest("SHA-256", buf);
  return Array.from(new Uint8Array(digest)).map((b) => b.toString(16).padStart(2, "0")).join("");
}
async function authenticateApiRequest(request) {
  const h = request.headers.get("authorization");
  if (!h || !h.toLowerCase().startsWith("bearer ")) {
    return { ok: false, status: 401, message: "Missing bearer token" };
  }
  const token = h.slice(7).trim();
  if (!token.startsWith(KEY_PREFIX)) {
    return { ok: false, status: 401, message: "Invalid API key format" };
  }
  const hash = await sha256Hex(token);
  const { data, error } = await supabaseAdmin.from("api_keys").select("id, org_id, revoked_at").eq("key_hash", hash).maybeSingle();
  if (error || !data) return { ok: false, status: 401, message: "Invalid API key" };
  if (data.revoked_at) return { ok: false, status: 401, message: "API key revoked" };
  supabaseAdmin.from("api_keys").update({ last_used_at: (/* @__PURE__ */ new Date()).toISOString() }).eq("id", data.id).then(() => {
  });
  return { ok: true, orgId: data.org_id, keyId: data.id };
}
function jsonResponse(body, init = {}) {
  return new Response(JSON.stringify(body), {
    ...init,
    headers: {
      "content-type": "application/json",
      "access-control-allow-origin": "*",
      "access-control-allow-headers": "authorization, content-type",
      "access-control-allow-methods": "GET, POST, PATCH, DELETE, OPTIONS",
      ...init.headers ?? {}
    }
  });
}
function errorResponse(status, message) {
  return jsonResponse({ error: { status, message } }, { status });
}
function optionsResponse() {
  return new Response(null, {
    status: 204,
    headers: {
      "access-control-allow-origin": "*",
      "access-control-allow-headers": "authorization, content-type",
      "access-control-allow-methods": "GET, POST, PATCH, DELETE, OPTIONS",
      "access-control-max-age": "86400"
    }
  });
}
const Route$8 = createFileRoute("/api/public/v1/organization")({
  server: {
    handlers: {
      OPTIONS: async () => optionsResponse(),
      GET: async ({ request }) => {
        const auth = await authenticateApiRequest(request);
        if (!auth.ok) return errorResponse(auth.status, auth.message);
        const { data, error } = await supabaseAdmin.from("organization_profiles").select("org_id, name, short_name, address, phone, emails, website, currency, default_tax_rate, tin, praz, duns, registration, logo_url").eq("org_id", auth.orgId).maybeSingle();
        if (error) return errorResponse(500, error.message);
        if (!data) return errorResponse(404, "Organization not found");
        return jsonResponse({ data });
      }
    }
  }
});
const Route$7 = createFileRoute("/api/public/v1/openapi.json")({
  server: {
    handlers: {
      OPTIONS: async () => new Response(null, {
        status: 204,
        headers: {
          "access-control-allow-origin": "*",
          "access-control-allow-headers": "authorization, content-type",
          "access-control-allow-methods": "GET, OPTIONS"
        }
      }),
      GET: async ({ request }) => {
        const origin = new URL(request.url).origin;
        const spec = buildSpec(origin);
        return new Response(JSON.stringify(spec, null, 2), {
          status: 200,
          headers: {
            "content-type": "application/json",
            "access-control-allow-origin": "*",
            "cache-control": "public, max-age=300"
          }
        });
      }
    }
  }
});
function buildSpec(origin) {
  const bearer = { BearerAuth: [] };
  return {
    openapi: "3.1.0",
    info: {
      title: "QuoteScribe Public API",
      version: "1.0.0",
      description: "REST API for managing clients, quotes, and invoices. All requests are scoped to a single organization by API key."
    },
    servers: [{ url: `${origin}/api/public/v1` }],
    security: [bearer],
    components: {
      securitySchemes: {
        BearerAuth: { type: "http", scheme: "bearer", bearerFormat: "qsk_live_*" }
      },
      schemas: {
        Error: {
          type: "object",
          properties: {
            error: {
              type: "object",
              properties: {
                status: { type: "integer" },
                message: { type: "string" }
              },
              required: ["status", "message"]
            }
          }
        },
        LineItem: {
          type: "object",
          required: ["description", "quantity", "unit_price"],
          properties: {
            description: { type: "string", maxLength: 500 },
            quantity: { type: "number", minimum: 0 },
            unit_price: { type: "number", minimum: 0 }
          }
        },
        Client: {
          type: "object",
          properties: {
            id: { type: "string", format: "uuid" },
            company_name: { type: "string" },
            email: { type: "string", nullable: true },
            phone: { type: "string", nullable: true },
            address: { type: "string", nullable: true },
            created_at: { type: "string", format: "date-time" },
            updated_at: { type: "string", format: "date-time" }
          }
        },
        ClientInput: {
          type: "object",
          required: ["company_name"],
          properties: {
            company_name: { type: "string", maxLength: 200 },
            email: { type: "string", nullable: true },
            phone: { type: "string", nullable: true },
            address: { type: "string", nullable: true }
          }
        },
        Document: {
          type: "object",
          properties: {
            id: { type: "string", format: "uuid" },
            doc_type: { type: "string", enum: ["quote", "invoice"] },
            doc_number: { type: "string" },
            client_id: { type: "string", format: "uuid" },
            issue_date: { type: "string", format: "date" },
            due_date: { type: "string", format: "date", nullable: true },
            line_items: { type: "array", items: { $ref: "#/components/schemas/LineItem" } },
            tax_rate: { type: "number" },
            discount: { type: "number" },
            subtotal: { type: "number" },
            tax_amount: { type: "number" },
            total: { type: "number" },
            notes: { type: "string", nullable: true },
            created_at: { type: "string", format: "date-time" },
            updated_at: { type: "string", format: "date-time" }
          }
        },
        DocumentInput: {
          type: "object",
          required: ["client_id", "doc_type", "doc_number", "issue_date", "line_items"],
          properties: {
            client_id: { type: "string", format: "uuid" },
            doc_type: { type: "string", enum: ["quote", "invoice"] },
            doc_number: { type: "string" },
            issue_date: { type: "string", format: "date" },
            due_date: { type: "string", format: "date", nullable: true },
            line_items: { type: "array", items: { $ref: "#/components/schemas/LineItem" }, minItems: 1 },
            tax_rate: { type: "number", default: 0 },
            discount: { type: "number", default: 0 },
            notes: { type: "string", nullable: true }
          }
        },
        Organization: {
          type: "object",
          properties: {
            org_id: { type: "string", format: "uuid" },
            name: { type: "string" },
            short_name: { type: "string", nullable: true },
            address: { type: "string", nullable: true },
            phone: { type: "string", nullable: true },
            emails: { type: "array", items: { type: "string" } },
            website: { type: "string", nullable: true },
            currency: { type: "string" },
            default_tax_rate: { type: "number" },
            tin: { type: "string", nullable: true },
            praz: { type: "string", nullable: true },
            duns: { type: "string", nullable: true },
            registration: { type: "string", nullable: true },
            logo_url: { type: "string", nullable: true }
          }
        }
      },
      responses: {
        Unauthorized: {
          description: "Missing or invalid API key",
          content: { "application/json": { schema: { $ref: "#/components/schemas/Error" } } }
        },
        NotFound: {
          description: "Resource not found",
          content: { "application/json": { schema: { $ref: "#/components/schemas/Error" } } }
        }
      }
    },
    paths: {
      "/organization": {
        get: {
          summary: "Get organization",
          responses: {
            "200": {
              description: "OK",
              content: {
                "application/json": {
                  schema: {
                    type: "object",
                    properties: { data: { $ref: "#/components/schemas/Organization" } }
                  }
                }
              }
            },
            "401": { $ref: "#/components/responses/Unauthorized" }
          }
        }
      },
      "/clients": {
        get: {
          summary: "List clients",
          parameters: [
            { name: "limit", in: "query", schema: { type: "integer", default: 50, maximum: 200 } },
            { name: "offset", in: "query", schema: { type: "integer", default: 0 } }
          ],
          responses: {
            "200": {
              description: "OK",
              content: {
                "application/json": {
                  schema: {
                    type: "object",
                    properties: {
                      data: { type: "array", items: { $ref: "#/components/schemas/Client" } },
                      limit: { type: "integer" },
                      offset: { type: "integer" }
                    }
                  }
                }
              }
            }
          }
        },
        post: {
          summary: "Create client",
          requestBody: {
            required: true,
            content: { "application/json": { schema: { $ref: "#/components/schemas/ClientInput" } } }
          },
          responses: {
            "200": {
              description: "OK",
              content: {
                "application/json": {
                  schema: {
                    type: "object",
                    properties: { data: { $ref: "#/components/schemas/Client" } }
                  }
                }
              }
            }
          }
        }
      },
      "/clients/{id}": {
        parameters: [{ name: "id", in: "path", required: true, schema: { type: "string", format: "uuid" } }],
        get: { summary: "Get client", responses: { "200": { description: "OK" }, "404": { $ref: "#/components/responses/NotFound" } } },
        patch: {
          summary: "Update client",
          requestBody: {
            required: true,
            content: { "application/json": { schema: { $ref: "#/components/schemas/ClientInput" } } }
          },
          responses: { "200": { description: "OK" }, "404": { $ref: "#/components/responses/NotFound" } }
        },
        delete: { summary: "Delete client", responses: { "200": { description: "OK" }, "404": { $ref: "#/components/responses/NotFound" } } }
      },
      "/documents": {
        get: {
          summary: "List documents",
          parameters: [
            { name: "limit", in: "query", schema: { type: "integer", default: 50, maximum: 200 } },
            { name: "offset", in: "query", schema: { type: "integer", default: 0 } },
            { name: "type", in: "query", schema: { type: "string", enum: ["quote", "invoice"] } }
          ],
          responses: { "200": { description: "OK" } }
        },
        post: {
          summary: "Create document",
          requestBody: {
            required: true,
            content: { "application/json": { schema: { $ref: "#/components/schemas/DocumentInput" } } }
          },
          responses: { "200": { description: "OK" } }
        }
      },
      "/documents/{id}": {
        parameters: [{ name: "id", in: "path", required: true, schema: { type: "string", format: "uuid" } }],
        get: { summary: "Get document", responses: { "200": { description: "OK" }, "404": { $ref: "#/components/responses/NotFound" } } },
        patch: {
          summary: "Update document",
          requestBody: {
            required: true,
            content: { "application/json": { schema: { $ref: "#/components/schemas/DocumentInput" } } }
          },
          responses: { "200": { description: "OK" }, "404": { $ref: "#/components/responses/NotFound" } }
        },
        delete: { summary: "Delete document", responses: { "200": { description: "OK" }, "404": { $ref: "#/components/responses/NotFound" } } }
      },
      "/documents/{id}/verify": {
        get: {
          summary: "Get signed verification URL",
          parameters: [{ name: "id", in: "path", required: true, schema: { type: "string", format: "uuid" } }],
          responses: {
            "200": {
              description: "OK",
              content: {
                "application/json": {
                  schema: {
                    type: "object",
                    properties: {
                      id: { type: "string" },
                      hash: { type: "string" },
                      sig: { type: "string" },
                      verify_url: { type: "string", format: "uri" }
                    }
                  }
                }
              }
            }
          }
        }
      },
      "/documents/{id}/pdf": {
        get: {
          summary: "Download document PDF",
          description: "Returns the rendered PDF bytes for the document.",
          parameters: [
            { name: "id", in: "path", required: true, schema: { type: "string", format: "uuid" } },
            {
              name: "disposition",
              in: "query",
              schema: { type: "string", enum: ["inline", "attachment"], default: "attachment" }
            }
          ],
          responses: {
            "200": {
              description: "PDF bytes",
              content: { "application/pdf": { schema: { type: "string", format: "binary" } } }
            },
            "404": { $ref: "#/components/responses/NotFound" }
          }
        }
      }
    }
  };
}
const lineItem$1 = object({
  description: string().min(1).max(500),
  quantity: number().finite().min(0),
  unit_price: number().finite().min(0)
});
const docInput = object({
  client_id: string().uuid(),
  doc_type: documentTypeSchema,
  doc_number: string().min(1).max(50),
  issue_date: string(),
  due_date: string().nullable().optional(),
  line_items: array(lineItem$1).min(1),
  tax_rate: number().finite().min(0).max(100).default(0),
  discount: number().finite().min(0).default(0),
  notes: string().max(2e3).nullable().optional()
});
const Route$6 = createFileRoute("/api/public/v1/documents")({
  server: {
    handlers: {
      OPTIONS: async () => optionsResponse(),
      GET: async ({ request }) => {
        const auth = await authenticateApiRequest(request);
        if (!auth.ok) return errorResponse(auth.status, auth.message);
        const url = new URL(request.url);
        const limit = Math.min(Number(url.searchParams.get("limit") ?? 50) || 50, 200);
        const offset = Math.max(Number(url.searchParams.get("offset") ?? 0) || 0, 0);
        const type = url.searchParams.get("type");
        let q = supabaseAdmin.from("documents").select("id, doc_type, doc_number, client_id, issue_date, due_date, subtotal, tax_rate, tax_amount, discount, total, notes, line_items, created_at, updated_at").eq("org_id", auth.orgId).order("created_at", { ascending: false }).range(offset, offset + limit - 1);
        if (type) q = q.eq("doc_type", type);
        const { data, error } = await q;
        if (error) return errorResponse(500, error.message);
        return jsonResponse({ data, limit, offset });
      },
      POST: async ({ request }) => {
        const auth = await authenticateApiRequest(request);
        if (!auth.ok) return errorResponse(auth.status, auth.message);
        let body;
        try {
          body = await request.json();
        } catch {
          return errorResponse(400, "Invalid JSON body");
        }
        const parsed = docInput.safeParse(body);
        if (!parsed.success) return errorResponse(400, parsed.error.message);
        const input = parsed.data;
        const { data: client } = await supabaseAdmin.from("clients").select("id").eq("id", input.client_id).eq("org_id", auth.orgId).maybeSingle();
        if (!client) return errorResponse(400, "client_id not found in this organization");
        const totals = computeTotals(input.line_items, input.tax_rate, input.discount);
        const { data: org } = await supabaseAdmin.from("organizations").select("created_by").eq("id", auth.orgId).maybeSingle();
        const userId = org?.created_by;
        if (!userId) return errorResponse(500, "Organization has no owner");
        const { data, error } = await supabaseAdmin.from("documents").insert({
          org_id: auth.orgId,
          user_id: userId,
          client_id: input.client_id,
          doc_type: input.doc_type,
          doc_number: input.doc_number,
          issue_date: input.issue_date,
          due_date: input.due_date ?? null,
          line_items: input.line_items,
          tax_rate: input.tax_rate,
          discount: input.discount,
          subtotal: totals.subtotal,
          tax_amount: totals.tax_amount,
          total: totals.total,
          notes: input.notes ?? null
        }).select("id, doc_type, doc_number, client_id, issue_date, due_date, subtotal, tax_rate, tax_amount, discount, total, notes, line_items, created_at, updated_at").single();
        if (error) return errorResponse(500, error.message);
        return jsonResponse({ data }, { status: 201 });
      }
    }
  }
});
const clientInput = object({
  company_name: string().min(1).max(200),
  email: string().email().max(200).nullable().optional(),
  phone: string().max(50).nullable().optional(),
  address: string().max(500).nullable().optional()
});
const Route$5 = createFileRoute("/api/public/v1/clients")({
  server: {
    handlers: {
      OPTIONS: async () => optionsResponse(),
      GET: async ({ request }) => {
        const auth = await authenticateApiRequest(request);
        if (!auth.ok) return errorResponse(auth.status, auth.message);
        const url = new URL(request.url);
        const limit = Math.min(Number(url.searchParams.get("limit") ?? 50) || 50, 200);
        const offset = Math.max(Number(url.searchParams.get("offset") ?? 0) || 0, 0);
        const { data, error } = await supabaseAdmin.from("clients").select("id, company_name, email, phone, address, created_at, updated_at").eq("org_id", auth.orgId).order("created_at", { ascending: false }).range(offset, offset + limit - 1);
        if (error) return errorResponse(500, error.message);
        return jsonResponse({ data, limit, offset });
      },
      POST: async ({ request }) => {
        const auth = await authenticateApiRequest(request);
        if (!auth.ok) return errorResponse(auth.status, auth.message);
        let body;
        try {
          body = await request.json();
        } catch {
          return errorResponse(400, "Invalid JSON body");
        }
        const parsed = clientInput.safeParse(body);
        if (!parsed.success) return errorResponse(400, parsed.error.message);
        const { data: org } = await supabaseAdmin.from("organizations").select("created_by").eq("id", auth.orgId).maybeSingle();
        const userId = org?.created_by;
        if (!userId) return errorResponse(500, "Organization has no owner");
        const { data, error } = await supabaseAdmin.from("clients").insert({
          org_id: auth.orgId,
          user_id: userId,
          company_name: parsed.data.company_name,
          email: parsed.data.email ?? null,
          phone: parsed.data.phone ?? null,
          address: parsed.data.address ?? null
        }).select("id, company_name, email, phone, address, created_at, updated_at").single();
        if (error) return errorResponse(500, error.message);
        return jsonResponse({ data }, { status: 201 });
      }
    }
  }
});
const lineItem = object({
  description: string().min(1).max(500),
  quantity: number().finite().min(0),
  unit_price: number().finite().min(0)
});
const docPatch = object({
  doc_number: string().min(1).max(50).optional(),
  issue_date: string().optional(),
  due_date: string().nullable().optional(),
  line_items: array(lineItem).min(1).optional(),
  tax_rate: number().finite().min(0).max(100).optional(),
  discount: number().finite().min(0).optional(),
  notes: string().max(2e3).nullable().optional()
});
const Route$4 = createFileRoute("/api/public/v1/documents/$id")({
  server: {
    handlers: {
      OPTIONS: async () => optionsResponse(),
      GET: async ({ request, params }) => {
        const auth = await authenticateApiRequest(request);
        if (!auth.ok) return errorResponse(auth.status, auth.message);
        const { data, error } = await supabaseAdmin.from("documents").select("id, doc_type, doc_number, client_id, issue_date, due_date, subtotal, tax_rate, tax_amount, discount, total, notes, line_items, created_at, updated_at, client:clients(id, company_name, email, phone, address)").eq("id", params.id).eq("org_id", auth.orgId).maybeSingle();
        if (error) return errorResponse(500, error.message);
        if (!data) return errorResponse(404, "Document not found");
        return jsonResponse({ data });
      },
      PATCH: async ({ request, params }) => {
        const auth = await authenticateApiRequest(request);
        if (!auth.ok) return errorResponse(auth.status, auth.message);
        let body;
        try {
          body = await request.json();
        } catch {
          return errorResponse(400, "Invalid JSON body");
        }
        const parsed = docPatch.safeParse(body);
        if (!parsed.success) return errorResponse(400, parsed.error.message);
        const patch = parsed.data;
        const { data: current } = await supabaseAdmin.from("documents").select("line_items, tax_rate, discount").eq("id", params.id).eq("org_id", auth.orgId).maybeSingle();
        if (!current) return errorResponse(404, "Document not found");
        const items = patch.line_items ?? current.line_items;
        const taxRate = patch.tax_rate ?? Number(current.tax_rate);
        const discount = patch.discount ?? Number(current.discount);
        const totals = computeTotals(items, taxRate, discount);
        const { data, error } = await supabaseAdmin.from("documents").update({
          ...patch,
          subtotal: totals.subtotal,
          tax_amount: totals.tax_amount,
          total: totals.total
        }).eq("id", params.id).eq("org_id", auth.orgId).select("id, doc_type, doc_number, client_id, issue_date, due_date, subtotal, tax_rate, tax_amount, discount, total, notes, line_items, created_at, updated_at").maybeSingle();
        if (error) return errorResponse(500, error.message);
        if (!data) return errorResponse(404, "Document not found");
        return jsonResponse({ data });
      },
      DELETE: async ({ request, params }) => {
        const auth = await authenticateApiRequest(request);
        if (!auth.ok) return errorResponse(auth.status, auth.message);
        const { error, count } = await supabaseAdmin.from("documents").delete({ count: "exact" }).eq("id", params.id).eq("org_id", auth.orgId);
        if (error) return errorResponse(500, error.message);
        if (!count) return errorResponse(404, "Document not found");
        return jsonResponse({ deleted: true });
      }
    }
  }
});
const clientPatch = object({
  company_name: string().min(1).max(200).optional(),
  email: string().email().max(200).nullable().optional(),
  phone: string().max(50).nullable().optional(),
  address: string().max(500).nullable().optional()
});
const Route$3 = createFileRoute("/api/public/v1/clients/$id")({
  server: {
    handlers: {
      OPTIONS: async () => optionsResponse(),
      GET: async ({ request, params }) => {
        const auth = await authenticateApiRequest(request);
        if (!auth.ok) return errorResponse(auth.status, auth.message);
        const { data, error } = await supabaseAdmin.from("clients").select("id, company_name, email, phone, address, created_at, updated_at").eq("id", params.id).eq("org_id", auth.orgId).maybeSingle();
        if (error) return errorResponse(500, error.message);
        if (!data) return errorResponse(404, "Client not found");
        return jsonResponse({ data });
      },
      PATCH: async ({ request, params }) => {
        const auth = await authenticateApiRequest(request);
        if (!auth.ok) return errorResponse(auth.status, auth.message);
        let body;
        try {
          body = await request.json();
        } catch {
          return errorResponse(400, "Invalid JSON body");
        }
        const parsed = clientPatch.safeParse(body);
        if (!parsed.success) return errorResponse(400, parsed.error.message);
        const { data, error } = await supabaseAdmin.from("clients").update(parsed.data).eq("id", params.id).eq("org_id", auth.orgId).select("id, company_name, email, phone, address, created_at, updated_at").maybeSingle();
        if (error) return errorResponse(500, error.message);
        if (!data) return errorResponse(404, "Client not found");
        return jsonResponse({ data });
      },
      DELETE: async ({ request, params }) => {
        const auth = await authenticateApiRequest(request);
        if (!auth.ok) return errorResponse(auth.status, auth.message);
        const { error, count } = await supabaseAdmin.from("clients").delete({ count: "exact" }).eq("id", params.id).eq("org_id", auth.orgId);
        if (error) return errorResponse(500, error.message);
        if (!count) return errorResponse(404, "Client not found");
        return jsonResponse({ deleted: true });
      }
    }
  }
});
const INK = "#0a0a0a";
const MUTED = "#6b7280";
const HAIR = "#e5e7eb";
function buildDocPath(d) {
  const year = (d.issue_date || (/* @__PURE__ */ new Date()).toISOString()).slice(0, 4);
  const type = d.doc_type === "invoice" ? "invoices" : d.doc_type === "credit_note" ? "credit-notes" : d.doc_type === "debit_note" ? "debit-notes" : d.doc_type === "receipt" ? "receipts" : "quotes";
  const safeNumber = d.doc_number.replace(/[^A-Za-z0-9._-]/g, "_");
  return `documents/${year}/${type}/${safeNumber}.pdf`;
}
async function buildDef(d) {
  const isInvoice = d.doc_type === "invoice";
  const title = d.doc_type === "invoice" ? "Invoice" : d.doc_type === "credit_note" ? "Credit Note" : d.doc_type === "debit_note" ? "Debit Note" : d.doc_type === "receipt" ? "Receipt" : "Quotation";
  const brand = d.brand;
  const qrDataUrl = d.verifyUrl ? await QRCode.toDataURL(d.verifyUrl, { margin: 0, width: 220, errorCorrectionLevel: "M" }) : null;
  const zimraQrDataUrl = d.fiscal?.receiptQrUrl ? await QRCode.toDataURL(d.fiscal.receiptQrUrl, { margin: 0, width: 220, errorCorrectionLevel: "M" }) : null;
  const itemRows = d.line_items.map((li, i) => [
    { text: String(i + 1), color: MUTED, fontSize: 9 },
    { text: li.description || "—", fontSize: 10 },
    { text: String(li.quantity), alignment: "right", fontSize: 10 },
    { text: formatMoney(li.unit_price), alignment: "right", fontSize: 10 },
    { text: formatMoney(rowTotal(li)), alignment: "right", fontSize: 10 }
  ]);
  const header = brand.logo_data_url ? { image: brand.logo_data_url, fit: [110, 110], alignment: "center" } : { text: brand.name, alignment: "center", fontSize: 20, bold: true, color: INK };
  const fromLines = [
    { text: "FROM", fontSize: 8, color: MUTED, margin: [0, 0, 0, 6] },
    { text: brand.name, bold: true, fontSize: 10 }
  ];
  if (brand.emails.length > 0) fromLines.push({ text: brand.emails.join("  ·  "), fontSize: 9, color: MUTED, margin: [0, 2, 0, 0] });
  if (brand.website) fromLines.push({ text: brand.website, fontSize: 9, color: MUTED });
  const regBits = [
    brand.registration ? `Reg ${brand.registration}` : null,
    brand.tin ? `TIN ${brand.tin}` : null,
    brand.duns ? `DUNS ${brand.duns}` : null
  ].filter(Boolean);
  if (regBits.length > 0) fromLines.push({ text: regBits.join("  ·  "), fontSize: 8, color: MUTED, margin: [0, 4, 0, 0] });
  if (brand.praz) fromLines.push({ text: `PRAZ Registration: ${brand.praz}`, fontSize: 9, color: INK, bold: true, margin: [0, 6, 0, 0] });
  if (brand.address) fromLines.push({ text: brand.address, fontSize: 8, color: MUTED, margin: [0, 2, 0, 0] });
  if (brand.phone) fromLines.push({ text: brand.phone, fontSize: 8, color: MUTED });
  const paymentText = brand.payment_instructions ? brand.payment_instructions : "Bank transfer details to be provided. Please reference document number on payment.";
  return {
    pageSize: "A4",
    pageMargins: [48, 56, 48, 72],
    defaultStyle: { font: "Roboto", color: INK, fontSize: 10, lineHeight: 1.35 },
    footer: (currentPage, pageCount) => ({
      margin: [48, 16, 48, 0],
      stack: [
        { canvas: [{ type: "line", x1: 0, y1: 0, x2: 499, y2: 0, lineWidth: 0.5, lineColor: HAIR }] },
        {
          columns: [
            {
              text: [
                { text: "Payment instructions: ", color: MUTED, fontSize: 8 },
                { text: paymentText, fontSize: 8 }
              ],
              width: "*"
            },
            { text: `${currentPage} / ${pageCount}`, alignment: "right", color: MUTED, fontSize: 8, width: 60 }
          ],
          margin: [0, 8, 0, 0]
        }
      ]
    }),
    content: [
      header,
      {
        margin: [0, 16, 0, 0],
        stack: [
          { text: title.toUpperCase(), alignment: "center", fontSize: 9, color: MUTED, characterSpacing: 3 },
          { text: d.doc_number, alignment: "center", fontSize: 16, bold: true, margin: [0, 4, 0, 0] }
        ]
      },
      { canvas: [{ type: "line", x1: 0, y1: 0, x2: 499, y2: 0, lineWidth: 0.5, lineColor: HAIR }], margin: [0, 20, 0, 20] },
      {
        columns: [
          { width: "*", stack: fromLines },
          {
            width: "*",
            stack: [
              { text: "BILLED TO", fontSize: 8, color: MUTED, characterSpacing: 1.5, margin: [0, 0, 0, 6] },
              { text: d.client.company_name, bold: true, fontSize: 10 },
              d.client.address ? { text: d.client.address, fontSize: 9, color: MUTED, margin: [0, 2, 0, 0] } : {},
              d.client.email ? { text: d.client.email, fontSize: 9, color: MUTED } : {},
              d.client.phone ? { text: d.client.phone, fontSize: 9, color: MUTED } : {}
            ]
          },
          {
            width: 140,
            stack: [
              { text: "ISSUE DATE", fontSize: 8, color: MUTED, characterSpacing: 1.5 },
              { text: formatDate(d.issue_date), fontSize: 10, margin: [0, 2, 0, 10] },
              ...d.due_date ? [
                { text: isInvoice ? "DUE DATE" : "VALID UNTIL", fontSize: 8, color: MUTED, characterSpacing: 1.5 },
                { text: formatDate(d.due_date), fontSize: 10, margin: [0, 2, 0, 0] }
              ] : []
            ]
          }
        ],
        columnGap: 24
      },
      { text: "", margin: [0, 0, 0, 24] },
      {
        table: {
          headerRows: 1,
          widths: [16, "*", 50, 80, 80],
          body: [
            [
              { text: "#", color: MUTED, fontSize: 8, characterSpacing: 1.5, border: [false, false, false, true], borderColor: [HAIR, HAIR, HAIR, INK] },
              { text: "DESCRIPTION", color: MUTED, fontSize: 8, characterSpacing: 1.5, border: [false, false, false, true], borderColor: [HAIR, HAIR, HAIR, INK] },
              { text: "QTY", color: MUTED, fontSize: 8, characterSpacing: 1.5, alignment: "right", border: [false, false, false, true], borderColor: [HAIR, HAIR, HAIR, INK] },
              { text: "UNIT PRICE", color: MUTED, fontSize: 8, characterSpacing: 1.5, alignment: "right", border: [false, false, false, true], borderColor: [HAIR, HAIR, HAIR, INK] },
              { text: "AMOUNT", color: MUTED, fontSize: 8, characterSpacing: 1.5, alignment: "right", border: [false, false, false, true], borderColor: [HAIR, HAIR, HAIR, INK] }
            ],
            ...itemRows.map(
              (row) => row.map((cell) => ({
                ...typeof cell === "string" ? { text: cell } : cell,
                border: [false, false, false, true],
                borderColor: [HAIR, HAIR, HAIR, HAIR],
                margin: [0, 8, 0, 8]
              }))
            )
          ]
        },
        layout: "noBorders"
      },
      { text: "", margin: [0, 0, 0, 16] },
      {
        columns: [
          { width: "*", text: "" },
          {
            width: 240,
            table: {
              widths: ["*", "auto"],
              body: [
                [{ text: "Subtotal", color: MUTED, fontSize: 10, border: [false, false, false, false] }, { text: formatMoney(d.subtotal), alignment: "right", fontSize: 10, border: [false, false, false, false] }],
                [{ text: `Tax (${d.tax_rate}%)`, color: MUTED, fontSize: 10, border: [false, false, false, false] }, { text: formatMoney(d.tax_amount), alignment: "right", fontSize: 10, border: [false, false, false, false] }],
                ...d.discount > 0 ? [[{ text: "Discount", color: MUTED, fontSize: 10, border: [false, false, false, false] }, { text: `− ${formatMoney(d.discount)}`, alignment: "right", fontSize: 10, border: [false, false, false, false] }]] : [],
                [
                  { text: "Total", bold: true, fontSize: 12, border: [false, true, false, false], borderColor: [HAIR, INK, HAIR, HAIR], margin: [0, 8, 0, 0] },
                  { text: formatMoney(d.total), alignment: "right", bold: true, fontSize: 14, border: [false, true, false, false], borderColor: [HAIR, INK, HAIR, HAIR], margin: [0, 8, 0, 0] }
                ]
              ]
            },
            layout: "noBorders"
          }
        ]
      },
      ...d.notes ? [
        { text: "", margin: [0, 24, 0, 0] },
        { text: "NOTES", fontSize: 8, color: MUTED, characterSpacing: 1.5, margin: [0, 0, 0, 4] },
        { text: d.notes, fontSize: 9, color: INK }
      ] : [],
      ...qrDataUrl && d.verifyUrl ? [
        { text: "", margin: [0, 28, 0, 0] },
        { canvas: [{ type: "line", x1: 0, y1: 0, x2: 499, y2: 0, lineWidth: 0.5, lineColor: HAIR }] },
        {
          margin: [0, 16, 0, 0],
          columns: [
            { image: qrDataUrl, width: 76 },
            {
              width: "*",
              margin: [16, 4, 0, 0],
              stack: [
                { text: "VERIFY THIS DOCUMENT", fontSize: 8, color: MUTED, characterSpacing: 2 },
                { text: `Scan the QR code to confirm this document was issued by ${brand.short_name ?? brand.name} and has not been altered.`, fontSize: 9, color: INK, margin: [0, 4, 0, 6] },
                ...d.docHash ? [
                  { text: "DOCUMENT HASH (SHA-256)", fontSize: 7, color: MUTED, characterSpacing: 1.5, margin: [0, 8, 0, 2] },
                  { text: d.docHash, fontSize: 7, color: INK, font: "Roboto", characterSpacing: 0.2 }
                ] : [],
                ...d.signatureId ? [
                  { text: "SIGNATURE ID (HMAC-SHA256)", fontSize: 7, color: MUTED, characterSpacing: 1.5, margin: [0, 6, 0, 2] },
                  { text: d.signatureId, fontSize: 7, color: INK, font: "Roboto", characterSpacing: 0.2 }
                ] : []
              ]
            }
          ]
        }
      ] : [],
      ...d.fiscal && zimraQrDataUrl ? [
        { text: "", margin: [0, 24, 0, 0] },
        { canvas: [{ type: "line", x1: 0, y1: 0, x2: 499, y2: 0, lineWidth: 0.5, lineColor: HAIR }] },
        {
          margin: [0, 16, 0, 0],
          columns: [
            { image: zimraQrDataUrl, width: 76 },
            {
              width: "*",
              margin: [16, 4, 0, 0],
              stack: [
                { text: "ZIMRA FISCAL RECEIPT", fontSize: 8, color: MUTED, characterSpacing: 2 },
                {
                  text: `Verification Code: ${d.fiscal.verificationCode}`,
                  fontSize: 10,
                  bold: true,
                  color: INK,
                  margin: [0, 4, 0, 4]
                },
                {
                  columns: [
                    {
                      width: "*",
                      stack: [
                        { text: "RECEIPT NO.", fontSize: 7, color: MUTED, characterSpacing: 1.5 },
                        { text: String(d.fiscal.receiptGlobalNo), fontSize: 9, color: INK, margin: [0, 1, 0, 4] },
                        { text: "FISCAL DAY", fontSize: 7, color: MUTED, characterSpacing: 1.5 },
                        { text: d.fiscal.fiscalDayNo != null ? `#${d.fiscal.fiscalDayNo}` : "—", fontSize: 9, color: INK, margin: [0, 1, 0, 0] }
                      ]
                    },
                    {
                      width: "*",
                      stack: [
                        { text: "DEVICE", fontSize: 7, color: MUTED, characterSpacing: 1.5 },
                        { text: d.fiscal.deviceSerial ?? d.fiscal.deviceId ?? "—", fontSize: 9, color: INK, margin: [0, 1, 0, 4] },
                        ...d.fiscal.vatNumber ? [
                          { text: "VAT NUMBER", fontSize: 7, color: MUTED, characterSpacing: 1.5 },
                          { text: d.fiscal.vatNumber, fontSize: 9, color: INK, margin: [0, 1, 0, 0] }
                        ] : []
                      ]
                    }
                  ]
                }
              ]
            }
          ]
        }
      ] : []
    ]
  };
}
const Route$2 = createFileRoute("/api/documents/$year/$type/$id")({
  server: {
    handlers: {
      GET: async ({ request, params }) => {
        const idRaw = params.id.endsWith(".pdf") ? params.id.slice(0, -4) : params.id;
        const previewMode = new URL(request.url).searchParams.get("preview") === "1";
        const url = new URL(request.url);
        const authHeader = request.headers.get("authorization");
        const token = authHeader?.startsWith("Bearer ") ? authHeader.slice("Bearer ".length) : null;
        if (!token) {
          return new Response("Unauthorized", { status: 401 });
        }
        const SUPABASE_URL = process.env.SUPABASE_URL;
        const SUPABASE_PUBLISHABLE_KEY = process.env.SUPABASE_PUBLISHABLE_KEY;
        if (!SUPABASE_URL || !SUPABASE_PUBLISHABLE_KEY) {
          return new Response("Server misconfigured", { status: 500 });
        }
        const userClient = createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, {
          global: { headers: { Authorization: `Bearer ${token}` } },
          auth: { storage: void 0, persistSession: false, autoRefreshToken: false }
        });
        const { data: claimsRes, error: claimsErr } = await userClient.auth.getClaims(token);
        if (claimsErr || !claimsRes?.claims?.sub) {
          return new Response("Unauthorized", { status: 401 });
        }
        const userId = claimsRes.claims.sub;
        const { data: doc, error } = await supabaseAdmin.from("documents").select("*, client:clients(company_name, address, email, phone)").eq("id", idRaw).maybeSingle();
        if (error || !doc) return new Response("Not found", { status: 404 });
        if (doc.user_id !== userId) return new Response("Forbidden", { status: 403 });
        const expectedYear = doc.issue_date.slice(0, 4);
        const expectedType = doc.doc_type === "invoice" ? "invoices" : doc.doc_type === "credit_note" ? "credit-notes" : doc.doc_type === "debit_note" ? "debit-notes" : doc.doc_type === "receipt" ? "receipts" : "quotes";
        if (params.year !== expectedYear || params.type !== expectedType) {
          return new Response("Not found", { status: 404 });
        }
        const client = doc.client ?? { company_name: "—", address: null, email: null, phone: null };
        const lineItems = doc.line_items ?? [];
        const { data: orgProfile } = await supabaseAdmin.from("organization_profiles").select("*").eq("org_id", doc.org_id).maybeSingle();
        let logoDataUrl = null;
        if (orgProfile?.logo_url) {
          try {
            const r = await fetch(orgProfile.logo_url);
            if (r.ok) {
              const buf = new Uint8Array(await r.arrayBuffer());
              const ct = r.headers.get("content-type") || "image/png";
              const b64 = Buffer.from(buf).toString("base64");
              logoDataUrl = `data:${ct};base64,${b64}`;
            }
          } catch {
          }
        }
        const brand = {
          name: orgProfile?.name ?? "Your Company",
          short_name: orgProfile?.short_name ?? null,
          logo_data_url: logoDataUrl,
          emails: orgProfile?.emails ?? [],
          website: orgProfile?.website ?? null,
          registration: orgProfile?.registration ?? null,
          tin: orgProfile?.tin ?? null,
          duns: orgProfile?.duns ?? null,
          praz: orgProfile?.praz ?? null,
          currency: orgProfile?.currency ?? "USD",
          default_tax_rate: Number(orgProfile?.default_tax_rate ?? 15),
          address: orgProfile?.address ?? null,
          phone: orgProfile?.phone ?? null,
          payment_instructions: orgProfile?.payment_instructions ?? null
        };
        const canonical = {
          doc_type: doc.doc_type,
          doc_number: doc.doc_number,
          issue_date: doc.issue_date,
          due_date: doc.due_date,
          line_items: lineItems,
          tax_rate: Number(doc.tax_rate),
          discount: Number(doc.discount),
          subtotal: Number(doc.subtotal),
          tax_amount: Number(doc.tax_amount),
          total: Number(doc.total),
          notes: doc.notes,
          client: { company_name: client.company_name, email: client.email }
        };
        const hash = await computeDocHash(canonical);
        const sig = signVerifyToken(doc.id, hash);
        const origin = url.origin;
        const verifyUrl = `${origin}/verify/${doc.id}?sig=${encodeURIComponent(sig)}&h=${hash}`;
        const docForPdf = {
          doc_type: doc.doc_type,
          doc_number: doc.doc_number,
          issue_date: doc.issue_date,
          due_date: doc.due_date,
          line_items: lineItems,
          tax_rate: Number(doc.tax_rate),
          discount: Number(doc.discount),
          subtotal: Number(doc.subtotal),
          tax_amount: Number(doc.tax_amount),
          total: Number(doc.total),
          notes: doc.notes,
          client,
          brand,
          verifyUrl,
          docHash: hash,
          signatureId: sig
        };
        const def = await buildDef(docForPdf);
        const pdfMakeMod = await import("../_libs/pdfmake.mjs").then(function(n) {
          return n.p;
        });
        const pdfFontsMod = await import("../_libs/pdfmake.mjs").then(function(n) {
          return n.v;
        });
        const pdfMake = pdfMakeMod.default;
        pdfMake.vfs = pdfFontsMod.default.vfs ?? pdfFontsMod.default.pdfMake?.vfs ?? {};
        const bytes = await new Promise((resolve) => {
          pdfMake.createPdf(def).getBuffer((buf) => resolve(buf));
        });
        const storagePath = buildDocPath(docForPdf);
        const filename = `${doc.doc_number}.pdf`;
        const disposition = previewMode ? "inline" : "attachment";
        return new Response(new Uint8Array(bytes), {
          status: 200,
          headers: {
            "Content-Type": "application/pdf",
            "Content-Disposition": `${disposition}; filename="${filename}"`,
            "X-Document-Path": storagePath,
            "Cache-Control": "private, no-store"
          }
        });
      }
    }
  }
});
const Route$1 = createFileRoute("/api/public/v1/documents/$id/verify")({
  server: {
    handlers: {
      OPTIONS: async () => optionsResponse(),
      GET: async ({ request, params }) => {
        const auth = await authenticateApiRequest(request);
        if (!auth.ok) return errorResponse(auth.status, auth.message);
        const { data: doc, error } = await supabaseAdmin.from("documents").select("id, doc_type, doc_number, issue_date, due_date, line_items, tax_rate, discount, subtotal, tax_amount, total, notes, client:clients(company_name, email)").eq("id", params.id).eq("org_id", auth.orgId).maybeSingle();
        if (error) return errorResponse(500, error.message);
        if (!doc) return errorResponse(404, "Document not found");
        const client = doc.client ?? {
          company_name: "—",
          email: null
        };
        const canonical = {
          doc_type: doc.doc_type,
          doc_number: doc.doc_number,
          issue_date: doc.issue_date,
          due_date: doc.due_date,
          line_items: doc.line_items ?? [],
          tax_rate: Number(doc.tax_rate),
          discount: Number(doc.discount),
          subtotal: Number(doc.subtotal),
          tax_amount: Number(doc.tax_amount),
          total: Number(doc.total),
          notes: doc.notes,
          client: { company_name: client.company_name, email: client.email }
        };
        const hash = await computeDocHash(canonical);
        const sig = signVerifyToken(doc.id, hash);
        const origin = new URL(request.url).origin;
        const verify_url = `${origin}/verify/${doc.id}?sig=${encodeURIComponent(sig)}&h=${hash}`;
        return jsonResponse({ id: doc.id, hash, sig, verify_url });
      }
    }
  }
});
const Route = createFileRoute("/api/public/v1/documents/$id/pdf")({
  server: {
    handlers: {
      OPTIONS: async () => optionsResponse(),
      GET: async ({ request, params }) => {
        const auth = await authenticateApiRequest(request);
        if (!auth.ok) return errorResponse(auth.status, auth.message);
        const url = new URL(request.url);
        const disposition = url.searchParams.get("disposition") === "inline" ? "inline" : "attachment";
        const { data: doc, error } = await supabaseAdmin.from("documents").select("*, client:clients(company_name, address, email, phone)").eq("id", params.id).eq("org_id", auth.orgId).maybeSingle();
        if (error) return errorResponse(500, error.message);
        if (!doc) return errorResponse(404, "Document not found");
        const client = doc.client ?? { company_name: "—", address: null, email: null, phone: null };
        const lineItems = doc.line_items ?? [];
        const { data: orgProfile } = await supabaseAdmin.from("organization_profiles").select("*").eq("org_id", doc.org_id).maybeSingle();
        let logoDataUrl = null;
        if (orgProfile?.logo_url) {
          try {
            const r = await fetch(orgProfile.logo_url);
            if (r.ok) {
              const buf = new Uint8Array(await r.arrayBuffer());
              const ct = r.headers.get("content-type") || "image/png";
              const b64 = Buffer.from(buf).toString("base64");
              logoDataUrl = `data:${ct};base64,${b64}`;
            }
          } catch {
          }
        }
        const brand = {
          name: orgProfile?.name ?? "Your Company",
          short_name: orgProfile?.short_name ?? null,
          logo_data_url: logoDataUrl,
          emails: orgProfile?.emails ?? [],
          website: orgProfile?.website ?? null,
          registration: orgProfile?.registration ?? null,
          tin: orgProfile?.tin ?? null,
          duns: orgProfile?.duns ?? null,
          praz: orgProfile?.praz ?? null,
          currency: orgProfile?.currency ?? "USD",
          default_tax_rate: Number(orgProfile?.default_tax_rate ?? 15),
          address: orgProfile?.address ?? null,
          phone: orgProfile?.phone ?? null,
          payment_instructions: orgProfile?.payment_instructions ?? null
        };
        const canonical = {
          doc_type: doc.doc_type,
          doc_number: doc.doc_number,
          issue_date: doc.issue_date,
          due_date: doc.due_date,
          line_items: lineItems,
          tax_rate: Number(doc.tax_rate),
          discount: Number(doc.discount),
          subtotal: Number(doc.subtotal),
          tax_amount: Number(doc.tax_amount),
          total: Number(doc.total),
          notes: doc.notes,
          client: { company_name: client.company_name, email: client.email }
        };
        const hash = await computeDocHash(canonical);
        const sig = signVerifyToken(doc.id, hash);
        const verifyUrl = `${url.origin}/verify/${doc.id}?sig=${encodeURIComponent(sig)}&h=${hash}`;
        const docForPdf = {
          doc_type: doc.doc_type,
          doc_number: doc.doc_number,
          issue_date: doc.issue_date,
          due_date: doc.due_date,
          line_items: lineItems,
          tax_rate: Number(doc.tax_rate),
          discount: Number(doc.discount),
          subtotal: Number(doc.subtotal),
          tax_amount: Number(doc.tax_amount),
          total: Number(doc.total),
          notes: doc.notes,
          client,
          brand,
          verifyUrl,
          docHash: hash,
          signatureId: sig
        };
        const def = await buildDef(docForPdf);
        const pdfMakeMod = await import("../_libs/pdfmake.mjs").then(function(n) {
          return n.p;
        });
        const pdfFontsMod = await import("../_libs/pdfmake.mjs").then(function(n) {
          return n.v;
        });
        const pdfMake = pdfMakeMod.default;
        pdfMake.vfs = pdfFontsMod.default.vfs ?? pdfFontsMod.default.pdfMake?.vfs ?? {};
        const bytes = await new Promise((resolve) => {
          pdfMake.createPdf(def).getBuffer((buf) => resolve(buf));
        });
        const filename = `${doc.doc_number}.pdf`;
        return new Response(new Uint8Array(bytes), {
          status: 200,
          headers: {
            "Content-Type": "application/pdf",
            "Content-Disposition": `${disposition}; filename="${filename}"`,
            "Cache-Control": "private, no-store",
            "access-control-allow-origin": "*"
          }
        });
      }
    }
  }
});
const SitemapDotxmlRoute = Route$q.update({
  id: "/sitemap.xml",
  path: "/sitemap.xml",
  getParentRoute: () => Route$r
});
const SettingsRoute = Route$p.update({
  id: "/settings",
  path: "/settings",
  getParentRoute: () => Route$r
});
const RobotsDottxtRoute = Route$o.update({
  id: "/robots.txt",
  path: "/robots.txt",
  getParentRoute: () => Route$r
});
const LoginRoute = Route$n.update({
  id: "/login",
  path: "/login",
  getParentRoute: () => Route$r
});
const DevelopersRoute = Route$m.update({
  id: "/developers",
  path: "/developers",
  getParentRoute: () => Route$r
});
const DashboardRoute = Route$l.update({
  id: "/dashboard",
  path: "/dashboard",
  getParentRoute: () => Route$r
});
const ClientsRoute = Route$k.update({
  id: "/clients",
  path: "/clients",
  getParentRoute: () => Route$r
});
const IndexRoute = Route$j.update({
  id: "/",
  path: "/",
  getParentRoute: () => Route$r
});
const DocumentsIndexRoute = Route$i.update({
  id: "/documents/",
  path: "/documents/",
  getParentRoute: () => Route$r
});
const VerifyIdRoute = Route$h.update({
  id: "/verify/$id",
  path: "/verify/$id",
  getParentRoute: () => Route$r
});
const SettingsTeamRoute = Route$g.update({
  id: "/team",
  path: "/team",
  getParentRoute: () => SettingsRoute
});
const SettingsOrganizationRoute = Route$f.update({
  id: "/organization",
  path: "/organization",
  getParentRoute: () => SettingsRoute
});
const SettingsFiscalRoute = Route$e.update({
  id: "/fiscal",
  path: "/fiscal",
  getParentRoute: () => SettingsRoute
});
const SettingsApiRoute = Route$d.update({
  id: "/api",
  path: "/api",
  getParentRoute: () => SettingsRoute
});
const InviteTokenRoute = Route$c.update({
  id: "/invite/$token",
  path: "/invite/$token",
  getParentRoute: () => Route$r
});
const DocumentsNewRoute = Route$b.update({
  id: "/documents/new",
  path: "/documents/new",
  getParentRoute: () => Route$r
});
const DocumentsIdIndexRoute = Route$a.update({
  id: "/documents/$id/",
  path: "/documents/$id/",
  getParentRoute: () => Route$r
});
const DocumentsIdEditRoute = Route$9.update({
  id: "/documents/$id/edit",
  path: "/documents/$id/edit",
  getParentRoute: () => Route$r
});
const ApiPublicV1OrganizationRoute = Route$8.update({
  id: "/api/public/v1/organization",
  path: "/api/public/v1/organization",
  getParentRoute: () => Route$r
});
const ApiPublicV1OpenapiDotjsonRoute = Route$7.update({
  id: "/api/public/v1/openapi.json",
  path: "/api/public/v1/openapi.json",
  getParentRoute: () => Route$r
});
const ApiPublicV1DocumentsRoute = Route$6.update({
  id: "/api/public/v1/documents",
  path: "/api/public/v1/documents",
  getParentRoute: () => Route$r
});
const ApiPublicV1ClientsRoute = Route$5.update({
  id: "/api/public/v1/clients",
  path: "/api/public/v1/clients",
  getParentRoute: () => Route$r
});
const ApiPublicV1DocumentsIdRoute = Route$4.update({
  id: "/$id",
  path: "/$id",
  getParentRoute: () => ApiPublicV1DocumentsRoute
});
const ApiPublicV1ClientsIdRoute = Route$3.update({
  id: "/$id",
  path: "/$id",
  getParentRoute: () => ApiPublicV1ClientsRoute
});
const ApiDocumentsYearTypeIdRoute = Route$2.update({
  id: "/api/documents/$year/$type/$id",
  path: "/api/documents/$year/$type/$id",
  getParentRoute: () => Route$r
});
const ApiPublicV1DocumentsIdVerifyRoute = Route$1.update({
  id: "/verify",
  path: "/verify",
  getParentRoute: () => ApiPublicV1DocumentsIdRoute
});
const ApiPublicV1DocumentsIdPdfRoute = Route.update({
  id: "/pdf",
  path: "/pdf",
  getParentRoute: () => ApiPublicV1DocumentsIdRoute
});
const SettingsRouteChildren = {
  SettingsApiRoute,
  SettingsFiscalRoute,
  SettingsOrganizationRoute,
  SettingsTeamRoute
};
const SettingsRouteWithChildren = SettingsRoute._addFileChildren(
  SettingsRouteChildren
);
const ApiPublicV1ClientsRouteChildren = {
  ApiPublicV1ClientsIdRoute
};
const ApiPublicV1ClientsRouteWithChildren = ApiPublicV1ClientsRoute._addFileChildren(ApiPublicV1ClientsRouteChildren);
const ApiPublicV1DocumentsIdRouteChildren = {
  ApiPublicV1DocumentsIdPdfRoute,
  ApiPublicV1DocumentsIdVerifyRoute
};
const ApiPublicV1DocumentsIdRouteWithChildren = ApiPublicV1DocumentsIdRoute._addFileChildren(
  ApiPublicV1DocumentsIdRouteChildren
);
const ApiPublicV1DocumentsRouteChildren = {
  ApiPublicV1DocumentsIdRoute: ApiPublicV1DocumentsIdRouteWithChildren
};
const ApiPublicV1DocumentsRouteWithChildren = ApiPublicV1DocumentsRoute._addFileChildren(ApiPublicV1DocumentsRouteChildren);
const rootRouteChildren = {
  IndexRoute,
  ClientsRoute,
  DashboardRoute,
  DevelopersRoute,
  LoginRoute,
  RobotsDottxtRoute,
  SettingsRoute: SettingsRouteWithChildren,
  SitemapDotxmlRoute,
  DocumentsNewRoute,
  InviteTokenRoute,
  VerifyIdRoute,
  DocumentsIndexRoute,
  DocumentsIdEditRoute,
  DocumentsIdIndexRoute,
  ApiPublicV1ClientsRoute: ApiPublicV1ClientsRouteWithChildren,
  ApiPublicV1DocumentsRoute: ApiPublicV1DocumentsRouteWithChildren,
  ApiPublicV1OpenapiDotjsonRoute,
  ApiPublicV1OrganizationRoute,
  ApiDocumentsYearTypeIdRoute
};
const routeTree = Route$r._addFileChildren(rootRouteChildren)._addFileTypes();
function DefaultErrorComponent({ error, reset }) {
  const router2 = useRouter();
  return /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "flex min-h-screen items-center justify-center bg-background px-4", children: /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "max-w-md text-center", children: [
    /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "mx-auto mb-6 flex h-16 w-16 items-center justify-center rounded-full bg-destructive/10", children: /* @__PURE__ */ jsxRuntimeExports.jsx(
      "svg",
      {
        xmlns: "http://www.w3.org/2000/svg",
        className: "h-8 w-8 text-destructive",
        fill: "none",
        viewBox: "0 0 24 24",
        stroke: "currentColor",
        strokeWidth: 2,
        children: /* @__PURE__ */ jsxRuntimeExports.jsx(
          "path",
          {
            strokeLinecap: "round",
            strokeLinejoin: "round",
            d: "M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126ZM12 15.75h.007v.008H12v-.008Z"
          }
        )
      }
    ) }),
    /* @__PURE__ */ jsxRuntimeExports.jsx("h1", { className: "text-2xl font-bold tracking-tight text-foreground", children: "Something went wrong" }),
    /* @__PURE__ */ jsxRuntimeExports.jsx("p", { className: "mt-2 text-sm text-muted-foreground", children: "An unexpected error occurred. Please try again." }),
    false,
    /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "mt-6 flex items-center justify-center gap-3", children: [
      /* @__PURE__ */ jsxRuntimeExports.jsx(
        "button",
        {
          onClick: () => {
            router2.invalidate();
            reset();
          },
          className: "inline-flex items-center justify-center rounded-md bg-primary px-4 py-2 text-sm font-medium text-primary-foreground transition-colors hover:bg-primary/90",
          children: "Try again"
        }
      ),
      /* @__PURE__ */ jsxRuntimeExports.jsx(
        "a",
        {
          href: "/",
          className: "inline-flex items-center justify-center rounded-md border border-input bg-background px-4 py-2 text-sm font-medium text-foreground transition-colors hover:bg-accent",
          children: "Go home"
        }
      )
    ] })
  ] }) });
}
const getRouter = () => {
  const router2 = createRouter({
    routeTree,
    context: {},
    scrollRestoration: true,
    defaultPreloadStaleTime: 0,
    defaultErrorComponent: DefaultErrorComponent
  });
  return router2;
};
const router = /* @__PURE__ */ Object.freeze(/* @__PURE__ */ Object.defineProperty({
  __proto__: null,
  getRouter
}, Symbol.toStringTag, { value: "Module" }));
export {
  createOrganization as A,
  Button as B,
  ClientFormDialog as C,
  Dialog as D,
  useMyOrganizations as E,
  useSwitchActiveOrg as F,
  router as G,
  Input as I,
  Label as L,
  Route$n as R,
  Textarea as T,
  useActiveOrg as a,
  DialogTrigger as b,
  DialogContent as c,
  DialogHeader as d,
  DialogTitle as e,
  DialogFooter as f,
  Route$h as g,
  useServerFn as h,
  getDocumentIssuerBrand as i,
  listInvitations as j,
  inviteMember as k,
  listMembers as l,
  removeMember as m,
  changeMemberRole as n,
  cn as o,
  profileToBrand as p,
  Route$c as q,
  revokeInvitation as r,
  getInvitation as s,
  acceptInvitation as t,
  useAuth as u,
  verifyEmailConfiguration as v,
  createSsrRpc as w,
  Route$a as x,
  buildDef as y,
  Route$9 as z
};
