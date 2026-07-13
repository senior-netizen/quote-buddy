import { r as reactExports, j as jsxRuntimeExports } from "../_libs/react.mjs";
import { e as useNavigate, d as useRouterState, L as Link } from "../_libs/tanstack__react-router.mjs";
import { u as useAuth, a as useActiveOrg, B as Button, h as useServerFn, A as createOrganization, L as Label, I as Input, E as useMyOrganizations, F as useSwitchActiveOrg, o as cn } from "./router-BDMLDL80.mjs";
import { t as toast } from "../_libs/sonner.mjs";
import { b as useQueryClient } from "../_libs/tanstack__react-query.mjs";
import { R as Root2, T as Trigger, P as Portal2, C as Content2, L as Label2, I as Item2, S as Separator2, a as SubTrigger2, b as SubContent2, c as CheckboxItem2, d as ItemIndicator2, e as RadioItem2 } from "../_libs/radix-ui__react-dropdown-menu.mjs";
import { L as LayoutDashboard, P as Plus, U as Users, F as FileText, S as Settings, a as LogOut, X, M as Menu, B as Building2, C as ChevronDown, b as Check, c as ChevronRight, d as Circle } from "../_libs/lucide-react.mjs";
function RequireAuth({ children }) {
  const { user, loading } = useAuth();
  const navigate = useNavigate();
  reactExports.useEffect(() => {
    if (!loading && !user) navigate({ to: "/login" });
  }, [loading, user, navigate]);
  if (loading || !user) {
    return /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "flex min-h-screen items-center justify-center text-sm text-muted-foreground", children: "Loading…" });
  }
  return /* @__PURE__ */ jsxRuntimeExports.jsx(jsxRuntimeExports.Fragment, { children });
}
const DropdownMenu = Root2;
const DropdownMenuTrigger = Trigger;
const DropdownMenuSubTrigger = reactExports.forwardRef(({ className, inset, children, ...props }, ref) => /* @__PURE__ */ jsxRuntimeExports.jsxs(
  SubTrigger2,
  {
    ref,
    className: cn(
      "flex cursor-default select-none items-center gap-2 rounded-sm px-2 py-1.5 text-sm outline-none focus:bg-accent data-[state=open]:bg-accent [&_svg]:pointer-events-none [&_svg]:size-4 [&_svg]:shrink-0",
      inset && "pl-8",
      className
    ),
    ...props,
    children: [
      children,
      /* @__PURE__ */ jsxRuntimeExports.jsx(ChevronRight, { className: "ml-auto" })
    ]
  }
));
DropdownMenuSubTrigger.displayName = SubTrigger2.displayName;
const DropdownMenuSubContent = reactExports.forwardRef(({ className, ...props }, ref) => /* @__PURE__ */ jsxRuntimeExports.jsx(
  SubContent2,
  {
    ref,
    className: cn(
      "z-50 min-w-[8rem] overflow-hidden rounded-md border bg-popover p-1 text-popover-foreground shadow-lg data-[state=open]:animate-in data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0 data-[state=closed]:zoom-out-95 data-[state=open]:zoom-in-95 data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2 origin-(--radix-dropdown-menu-content-transform-origin)",
      className
    ),
    ...props
  }
));
DropdownMenuSubContent.displayName = SubContent2.displayName;
const DropdownMenuContent = reactExports.forwardRef(({ className, sideOffset = 4, ...props }, ref) => /* @__PURE__ */ jsxRuntimeExports.jsx(Portal2, { children: /* @__PURE__ */ jsxRuntimeExports.jsx(
  Content2,
  {
    ref,
    sideOffset,
    className: cn(
      "z-50 max-h-[var(--radix-dropdown-menu-content-available-height)] min-w-[8rem] overflow-y-auto overflow-x-hidden rounded-md border bg-popover p-1 text-popover-foreground shadow-md",
      "data-[state=open]:animate-in data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0 data-[state=closed]:zoom-out-95 data-[state=open]:zoom-in-95 data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2 origin-(--radix-dropdown-menu-content-transform-origin)",
      className
    ),
    ...props
  }
) }));
DropdownMenuContent.displayName = Content2.displayName;
const DropdownMenuItem = reactExports.forwardRef(({ className, inset, ...props }, ref) => /* @__PURE__ */ jsxRuntimeExports.jsx(
  Item2,
  {
    ref,
    className: cn(
      "relative flex cursor-default select-none items-center gap-2 rounded-sm px-2 py-1.5 text-sm outline-none transition-colors focus:bg-accent focus:text-accent-foreground data-[disabled]:pointer-events-none data-[disabled]:opacity-50 [&>svg]:size-4 [&>svg]:shrink-0",
      inset && "pl-8",
      className
    ),
    ...props
  }
));
DropdownMenuItem.displayName = Item2.displayName;
const DropdownMenuCheckboxItem = reactExports.forwardRef(({ className, children, checked, ...props }, ref) => /* @__PURE__ */ jsxRuntimeExports.jsxs(
  CheckboxItem2,
  {
    ref,
    className: cn(
      "relative flex cursor-default select-none items-center rounded-sm py-1.5 pl-8 pr-2 text-sm outline-none transition-colors focus:bg-accent focus:text-accent-foreground data-[disabled]:pointer-events-none data-[disabled]:opacity-50",
      className
    ),
    checked,
    ...props,
    children: [
      /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: "absolute left-2 flex h-3.5 w-3.5 items-center justify-center", children: /* @__PURE__ */ jsxRuntimeExports.jsx(ItemIndicator2, { children: /* @__PURE__ */ jsxRuntimeExports.jsx(Check, { className: "h-4 w-4" }) }) }),
      children
    ]
  }
));
DropdownMenuCheckboxItem.displayName = CheckboxItem2.displayName;
const DropdownMenuRadioItem = reactExports.forwardRef(({ className, children, ...props }, ref) => /* @__PURE__ */ jsxRuntimeExports.jsxs(
  RadioItem2,
  {
    ref,
    className: cn(
      "relative flex cursor-default select-none items-center rounded-sm py-1.5 pl-8 pr-2 text-sm outline-none transition-colors focus:bg-accent focus:text-accent-foreground data-[disabled]:pointer-events-none data-[disabled]:opacity-50",
      className
    ),
    ...props,
    children: [
      /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: "absolute left-2 flex h-3.5 w-3.5 items-center justify-center", children: /* @__PURE__ */ jsxRuntimeExports.jsx(ItemIndicator2, { children: /* @__PURE__ */ jsxRuntimeExports.jsx(Circle, { className: "h-2 w-2 fill-current" }) }) }),
      children
    ]
  }
));
DropdownMenuRadioItem.displayName = RadioItem2.displayName;
const DropdownMenuLabel = reactExports.forwardRef(({ className, inset, ...props }, ref) => /* @__PURE__ */ jsxRuntimeExports.jsx(
  Label2,
  {
    ref,
    className: cn("px-2 py-1.5 text-sm font-semibold", inset && "pl-8", className),
    ...props
  }
));
DropdownMenuLabel.displayName = Label2.displayName;
const DropdownMenuSeparator = reactExports.forwardRef(({ className, ...props }, ref) => /* @__PURE__ */ jsxRuntimeExports.jsx(
  Separator2,
  {
    ref,
    className: cn("-mx-1 my-1 h-px bg-muted", className),
    ...props
  }
));
DropdownMenuSeparator.displayName = Separator2.displayName;
const AUTH_CONFIGURATION_ERROR_PATTERNS = ["invalid api key", "missing supabase", "unauthorized"];
const ORGANIZATION_CREATE_ERROR_MESSAGE = "We couldn’t create the organization. Please try again or contact support.";
const SESSION_VERIFICATION_ERROR_MESSAGE = "We couldn’t verify your session. Please sign out and sign in again. If this continues, contact support.";
function errorMessage(error) {
  return error instanceof Error ? error.message : String(error ?? "");
}
function isAuthConfigurationError(error) {
  const message = errorMessage(error).toLowerCase();
  return AUTH_CONFIGURATION_ERROR_PATTERNS.some((pattern) => message.includes(pattern));
}
function organizationCreateToastMessage(error) {
  return isAuthConfigurationError(error) ? SESSION_VERIFICATION_ERROR_MESSAGE : ORGANIZATION_CREATE_ERROR_MESSAGE;
}
const nav = [
  { to: "/dashboard", label: "Overview", icon: LayoutDashboard },
  { to: "/documents/new", label: "Create", icon: Plus },
  { to: "/clients", label: "Clients", icon: Users },
  { to: "/documents", label: "Documents", icon: FileText }
];
function AppShell({ children }) {
  const { user, signOut } = useAuth();
  const navigate = useNavigate();
  const path = useRouterState({ select: (s) => s.location.pathname });
  const [open, setOpen] = reactExports.useState(false);
  const { data: activeOrg, error: activeOrgError, isError: activeOrgIsError, isLoading: orgLoading } = useActiveOrg();
  reactExports.useEffect(() => {
    if (activeOrgIsError) {
      console.error("Failed to load active organization", activeOrgError);
    }
  }, [activeOrgError, activeOrgIsError]);
  const handleSignOut = async () => {
    try {
      await signOut();
      toast.success("Signed out");
    } catch (e) {
      toast.error("Sign out failed", { description: e instanceof Error ? e.message : "Please try again." });
    } finally {
      navigate({ to: "/login" });
    }
  };
  if (activeOrgIsError) {
    return /* @__PURE__ */ jsxRuntimeExports.jsx(ActiveOrgErrorScreen, { error: activeOrgError, onSignOut: handleSignOut });
  }
  if (!orgLoading && activeOrg === null) {
    return /* @__PURE__ */ jsxRuntimeExports.jsx(OnboardingScreen, {});
  }
  return /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "min-h-screen bg-background text-foreground", children: [
    /* @__PURE__ */ jsxRuntimeExports.jsxs("header", { className: "sticky top-0 z-30 border-b border-hairline bg-background/80 backdrop-blur-xl", children: [
      /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "mx-auto flex h-14 max-w-7xl items-center gap-4 px-4 sm:gap-6 sm:px-6", children: [
        /* @__PURE__ */ jsxRuntimeExports.jsxs(Link, { to: "/dashboard", className: "flex items-center gap-3 min-w-0", children: [
          /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "flex h-10 w-10 shrink-0 items-center justify-center overflow-hidden rounded-lg bg-transparent p-0", children: /* @__PURE__ */ jsxRuntimeExports.jsx(
            "img",
            {
              src: "/logo.png",
              alt: "Qouteflow",
              className: "h-full w-full object-contain"
            }
          ) }),
          /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: "text-[17px] font-semibold tracking-tight", children: "Qouteflow" })
        ] }),
        /* @__PURE__ */ jsxRuntimeExports.jsx(OrgSwitcher, {}),
        /* @__PURE__ */ jsxRuntimeExports.jsx("nav", { className: "hidden md:flex items-center gap-1", children: nav.map((n) => {
          const active = path === n.to || n.to !== "/dashboard" && path.startsWith(n.to);
          return /* @__PURE__ */ jsxRuntimeExports.jsxs(
            Link,
            {
              to: n.to,
              className: `flex items-center gap-1.5 rounded-md px-3 py-1.5 text-[13px] transition-colors ${active ? "bg-secondary text-foreground" : "text-muted-foreground hover:text-foreground"}`,
              children: [
                /* @__PURE__ */ jsxRuntimeExports.jsx(n.icon, { className: "h-3.5 w-3.5" }),
                n.label
              ]
            },
            n.to
          );
        }) }),
        /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "ml-auto flex items-center gap-2 sm:gap-3", children: [
          /* @__PURE__ */ jsxRuntimeExports.jsx(
            Link,
            {
              to: "/settings/organization",
              className: `hidden md:inline-flex items-center gap-1 rounded-md px-2 py-1.5 text-[12px] text-muted-foreground hover:text-foreground ${path.startsWith("/settings") ? "text-foreground" : ""}`,
              children: /* @__PURE__ */ jsxRuntimeExports.jsx(Settings, { className: "h-3.5 w-3.5" })
            }
          ),
          /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: "hidden lg:inline text-[12px] text-muted-foreground", children: user?.email }),
          /* @__PURE__ */ jsxRuntimeExports.jsx(Button, { variant: "ghost", size: "sm", onClick: handleSignOut, className: "hidden md:inline-flex", children: /* @__PURE__ */ jsxRuntimeExports.jsx(LogOut, { className: "h-3.5 w-3.5" }) }),
          /* @__PURE__ */ jsxRuntimeExports.jsx(
            Button,
            {
              variant: "ghost",
              size: "sm",
              className: "md:hidden",
              onClick: () => setOpen((o) => !o),
              "aria-label": "Toggle menu",
              children: open ? /* @__PURE__ */ jsxRuntimeExports.jsx(X, { className: "h-4 w-4" }) : /* @__PURE__ */ jsxRuntimeExports.jsx(Menu, { className: "h-4 w-4" })
            }
          )
        ] })
      ] }),
      open && /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "md:hidden border-t border-hairline bg-background", children: /* @__PURE__ */ jsxRuntimeExports.jsxs("nav", { className: "mx-auto flex max-w-7xl flex-col px-4 py-2", children: [
        nav.map((n) => {
          const active = path === n.to || n.to !== "/dashboard" && path.startsWith(n.to);
          return /* @__PURE__ */ jsxRuntimeExports.jsxs(
            Link,
            {
              to: n.to,
              onClick: () => setOpen(false),
              className: `flex items-center gap-2 rounded-md px-3 py-2.5 text-sm transition-colors ${active ? "bg-secondary text-foreground" : "text-muted-foreground hover:text-foreground"}`,
              children: [
                /* @__PURE__ */ jsxRuntimeExports.jsx(n.icon, { className: "h-4 w-4" }),
                n.label
              ]
            },
            n.to
          );
        }),
        /* @__PURE__ */ jsxRuntimeExports.jsxs(
          Link,
          {
            to: "/settings/organization",
            onClick: () => setOpen(false),
            className: "flex items-center gap-2 rounded-md px-3 py-2.5 text-sm text-muted-foreground hover:text-foreground",
            children: [
              /* @__PURE__ */ jsxRuntimeExports.jsx(Settings, { className: "h-4 w-4" }),
              " Settings"
            ]
          }
        ),
        /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "mt-2 border-t border-hairline pt-2", children: [
          user?.email && /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "px-3 py-1 text-[11px] text-muted-foreground truncate", children: user.email }),
          /* @__PURE__ */ jsxRuntimeExports.jsxs(
            "button",
            {
              onClick: () => {
                setOpen(false);
                handleSignOut();
              },
              className: "flex w-full items-center gap-2 rounded-md px-3 py-2.5 text-sm text-muted-foreground hover:text-foreground",
              children: [
                /* @__PURE__ */ jsxRuntimeExports.jsx(LogOut, { className: "h-4 w-4" }),
                " Sign out"
              ]
            }
          )
        ] })
      ] }) })
    ] }),
    /* @__PURE__ */ jsxRuntimeExports.jsx("main", { className: "mx-auto max-w-7xl px-4 py-6 sm:px-6 sm:py-10", children })
  ] });
}
function ActiveOrgErrorScreen({ error, onSignOut }) {
  const message = isAuthConfigurationError(error) ? SESSION_VERIFICATION_ERROR_MESSAGE : "We couldn’t load your organization. Please refresh the page or contact support if this continues.";
  return /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "flex min-h-screen items-center justify-center px-6", children: /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "w-full max-w-md rounded-xl border border-hairline bg-background p-6 text-center shadow-sm", children: [
    /* @__PURE__ */ jsxRuntimeExports.jsx(Building2, { className: "mx-auto h-8 w-8 text-muted-foreground" }),
    /* @__PURE__ */ jsxRuntimeExports.jsx("h1", { className: "mt-6 text-2xl font-semibold tracking-tight", children: "We couldn’t load your workspace" }),
    /* @__PURE__ */ jsxRuntimeExports.jsx("p", { className: "mt-2 text-sm text-muted-foreground", children: message }),
    /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "mt-6 flex flex-col gap-2 sm:flex-row sm:justify-center", children: [
      /* @__PURE__ */ jsxRuntimeExports.jsx(Button, { type: "button", onClick: () => window.location.reload(), className: "rounded-full", children: "Refresh" }),
      isAuthConfigurationError(error) && /* @__PURE__ */ jsxRuntimeExports.jsx(Button, { type: "button", variant: "outline", onClick: onSignOut, className: "rounded-full", children: "Sign out" })
    ] })
  ] }) });
}
function OrgSwitcher() {
  const { data: activeOrg } = useActiveOrg();
  const { data: orgs = [] } = useMyOrganizations();
  const switchOrg = useSwitchActiveOrg();
  const navigate = useNavigate();
  const [creating, setCreating] = reactExports.useState(false);
  const [name, setName] = reactExports.useState("");
  const createFn = useServerFn(createOrganization);
  const qc = useQueryClient();
  if (!activeOrg) return null;
  const activeOrgProfile = activeOrg.profile;
  return /* @__PURE__ */ jsxRuntimeExports.jsxs(DropdownMenu, { children: [
    /* @__PURE__ */ jsxRuntimeExports.jsx(DropdownMenuTrigger, { asChild: true, children: /* @__PURE__ */ jsxRuntimeExports.jsxs("button", { className: "flex items-center gap-1.5 rounded-md border border-hairline px-2.5 py-1 text-[12px] hover:bg-secondary/50 max-w-[180px]", children: [
      activeOrgProfile?.logo_url ? /* @__PURE__ */ jsxRuntimeExports.jsx("img", { src: activeOrgProfile.logo_url, alt: "", className: "h-4 w-4 rounded object-contain" }) : /* @__PURE__ */ jsxRuntimeExports.jsx(Building2, { className: "h-3.5 w-3.5 shrink-0" }),
      /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: "truncate", children: activeOrg.org_name }),
      /* @__PURE__ */ jsxRuntimeExports.jsx(ChevronDown, { className: "h-3 w-3 shrink-0 text-muted-foreground" })
    ] }) }),
    /* @__PURE__ */ jsxRuntimeExports.jsxs(DropdownMenuContent, { align: "start", className: "w-64", children: [
      /* @__PURE__ */ jsxRuntimeExports.jsx(DropdownMenuLabel, { className: "text-[10px] uppercase tracking-wider text-muted-foreground", children: "Organizations" }),
      orgs.map((o) => /* @__PURE__ */ jsxRuntimeExports.jsxs(
        DropdownMenuItem,
        {
          onClick: () => switchOrg(o.id),
          className: "flex items-center justify-between",
          children: [
            /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: "truncate", children: o.name }),
            o.id === activeOrg.org_id && /* @__PURE__ */ jsxRuntimeExports.jsx(Check, { className: "h-3.5 w-3.5" })
          ]
        },
        o.id
      )),
      /* @__PURE__ */ jsxRuntimeExports.jsx(DropdownMenuSeparator, {}),
      !creating ? /* @__PURE__ */ jsxRuntimeExports.jsxs(DropdownMenuItem, { onSelect: (e) => {
        e.preventDefault();
        setCreating(true);
      }, children: [
        /* @__PURE__ */ jsxRuntimeExports.jsx(Plus, { className: "mr-2 h-3.5 w-3.5" }),
        " Create organization"
      ] }) : /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "p-2 space-y-2", onClick: (e) => e.stopPropagation(), children: [
        /* @__PURE__ */ jsxRuntimeExports.jsx(
          Input,
          {
            autoFocus: true,
            placeholder: "Company name",
            value: name,
            onChange: (e) => setName(e.target.value),
            onKeyDown: async (e) => {
              if (e.key === "Enter" && name.trim()) {
                try {
                  const r = await createFn({ data: { name: name.trim() } });
                  await switchOrg(r.org_id);
                  await qc.invalidateQueries();
                  setCreating(false);
                  setName("");
                  navigate({ to: "/settings/organization" });
                } catch (err) {
                  console.error("Failed to create organization from switcher", err);
                  toast.error(organizationCreateToastMessage(err));
                }
              }
            },
            className: "h-8 text-xs"
          }
        ),
        /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "flex justify-end gap-1", children: /* @__PURE__ */ jsxRuntimeExports.jsx(Button, { variant: "ghost", size: "sm", onClick: () => {
          setCreating(false);
          setName("");
        }, children: "Cancel" }) })
      ] }),
      /* @__PURE__ */ jsxRuntimeExports.jsx(DropdownMenuSeparator, {}),
      /* @__PURE__ */ jsxRuntimeExports.jsxs(DropdownMenuItem, { onSelect: () => navigate({ to: "/settings/organization" }), children: [
        /* @__PURE__ */ jsxRuntimeExports.jsx(Settings, { className: "mr-2 h-3.5 w-3.5" }),
        " Organization settings"
      ] }),
      /* @__PURE__ */ jsxRuntimeExports.jsxs(DropdownMenuItem, { onSelect: () => navigate({ to: "/settings/team" }), children: [
        /* @__PURE__ */ jsxRuntimeExports.jsx(Users, { className: "mr-2 h-3.5 w-3.5" }),
        " Team"
      ] })
    ] })
  ] });
}
function OnboardingScreen() {
  const [name, setName] = reactExports.useState("");
  const [busy, setBusy] = reactExports.useState(false);
  const createFn = useServerFn(createOrganization);
  const qc = useQueryClient();
  const navigate = useNavigate();
  const submit = async (e) => {
    e.preventDefault();
    if (!name.trim()) return;
    setBusy(true);
    try {
      await createFn({ data: { name: name.trim() } });
      await qc.invalidateQueries();
      toast.success("Workspace created");
      navigate({ to: "/settings/organization" });
    } catch (err) {
      console.error("Failed to create organization during onboarding", err);
      toast.error(organizationCreateToastMessage(err));
    } finally {
      setBusy(false);
    }
  };
  return /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "flex min-h-screen items-center justify-center px-6", children: /* @__PURE__ */ jsxRuntimeExports.jsxs("form", { onSubmit: submit, className: "w-full max-w-sm", children: [
    /* @__PURE__ */ jsxRuntimeExports.jsx(Building2, { className: "mx-auto h-8 w-8" }),
    /* @__PURE__ */ jsxRuntimeExports.jsx("h1", { className: "mt-6 text-2xl font-semibold tracking-tight text-center", children: "Set up your workspace" }),
    /* @__PURE__ */ jsxRuntimeExports.jsx("p", { className: "mt-1 text-sm text-muted-foreground text-center", children: "Name your company. You can change this later." }),
    /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "mt-8 space-y-2", children: [
      /* @__PURE__ */ jsxRuntimeExports.jsx(Label, { className: "text-xs", htmlFor: "orgname", children: "Company name" }),
      /* @__PURE__ */ jsxRuntimeExports.jsx(
        Input,
        {
          id: "orgname",
          autoFocus: true,
          required: true,
          value: name,
          onChange: (e) => setName(e.target.value),
          placeholder: "Acme Inc."
        }
      )
    ] }),
    /* @__PURE__ */ jsxRuntimeExports.jsx(Button, { type: "submit", disabled: busy, className: "mt-6 w-full rounded-full", children: busy ? "Creating…" : "Continue" })
  ] }) });
}
export {
  AppShell as A,
  RequireAuth as R
};
