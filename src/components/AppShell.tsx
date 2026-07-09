import { Link, useNavigate, useRouterState } from "@tanstack/react-router";
import { useAuth } from "@/lib/auth";
import { Button } from "@/components/ui/button";
import { LayoutDashboard, Users, FileText, Plus, LogOut, Menu, X, Settings, Building2, ChevronDown, Check } from "lucide-react";
import { useEffect, useState, type ReactNode } from "react";
import { toast } from "sonner";
import { useActiveOrg, useMyOrganizations, useSwitchActiveOrg } from "@/lib/org";
import { useServerFn } from "@tanstack/react-start";
import { createOrganization } from "@/lib/org.functions";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { useQueryClient } from "@tanstack/react-query";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";

const AUTH_CONFIGURATION_ERROR_PATTERNS = ["invalid api key", "missing supabase", "unauthorized"] as const;

const ORGANIZATION_CREATE_ERROR_MESSAGE =
  "We couldn’t create the organization. Please try again or contact support.";

const SESSION_VERIFICATION_ERROR_MESSAGE =
  "We couldn’t verify your session. Please sign out and sign in again. If this continues, contact support.";

function errorMessage(error: unknown) {
  return error instanceof Error ? error.message : String(error ?? "");
}

function isAuthConfigurationError(error: unknown) {
  const message = errorMessage(error).toLowerCase();
  return AUTH_CONFIGURATION_ERROR_PATTERNS.some((pattern) => message.includes(pattern));
}

function organizationCreateToastMessage(error: unknown) {
  return isAuthConfigurationError(error) ? SESSION_VERIFICATION_ERROR_MESSAGE : ORGANIZATION_CREATE_ERROR_MESSAGE;
}

const nav = [
  { to: "/dashboard", label: "Overview", icon: LayoutDashboard },
  { to: "/documents/new", label: "Create", icon: Plus },
  { to: "/clients", label: "Clients", icon: Users },
  { to: "/documents", label: "Documents", icon: FileText },
] as const;

export function AppShell({ children }: { children: ReactNode }) {
  const { user, signOut } = useAuth();
  const navigate = useNavigate();
  const path = useRouterState({ select: (s) => s.location.pathname });
  const [open, setOpen] = useState(false);
  const { data: activeOrg, error: activeOrgError, isError: activeOrgIsError, isLoading: orgLoading } = useActiveOrg();

  useEffect(() => {
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
    return <ActiveOrgErrorScreen error={activeOrgError} onSignOut={handleSignOut} />;
  }

  // Onboarding gate: user has no organization yet
  if (!orgLoading && activeOrg === null) {
    return <OnboardingScreen />;
  }

  return (
    <div className="min-h-screen bg-background text-foreground">
      <header className="sticky top-0 z-30 border-b border-hairline bg-background/80 backdrop-blur-xl">
        <div className="mx-auto flex h-14 max-w-7xl items-center gap-4 px-4 sm:gap-6 sm:px-6">
          <Link to="/dashboard" className="flex items-center gap-2 min-w-0">
            <img
              src="/ChatGPT%20Image%20Jul%207%2C%202026%2C%2011_23_14%20AM.png"
              alt="Qouteflow"
              className="h-6 w-6 object-contain"
            />
            <span className="text-[14px] font-semibold tracking-tight">Qouteflow</span>
          </Link>
          <OrgSwitcher />
          <nav className="hidden md:flex items-center gap-1">
            {nav.map((n) => {
              const active = path === n.to || (n.to !== "/dashboard" && path.startsWith(n.to));
              return (
                <Link
                  key={n.to}
                  to={n.to}
                  className={`flex items-center gap-1.5 rounded-md px-3 py-1.5 text-[13px] transition-colors ${
                    active ? "bg-secondary text-foreground" : "text-muted-foreground hover:text-foreground"
                  }`}
                >
                  <n.icon className="h-3.5 w-3.5" />
                  {n.label}
                </Link>
              );
            })}
          </nav>
          <div className="ml-auto flex items-center gap-2 sm:gap-3">
            <Link
              to="/settings/organization"
              className={`hidden md:inline-flex items-center gap-1 rounded-md px-2 py-1.5 text-[12px] text-muted-foreground hover:text-foreground ${
                path.startsWith("/settings") ? "text-foreground" : ""
              }`}
            >
              <Settings className="h-3.5 w-3.5" />
            </Link>
            <span className="hidden lg:inline text-[12px] text-muted-foreground">{user?.email}</span>
            <Button variant="ghost" size="sm" onClick={handleSignOut} className="hidden md:inline-flex">
              <LogOut className="h-3.5 w-3.5" />
            </Button>
            <Button
              variant="ghost"
              size="sm"
              className="md:hidden"
              onClick={() => setOpen((o) => !o)}
              aria-label="Toggle menu"
            >
              {open ? <X className="h-4 w-4" /> : <Menu className="h-4 w-4" />}
            </Button>
          </div>
        </div>
        {open && (
          <div className="md:hidden border-t border-hairline bg-background">
            <nav className="mx-auto flex max-w-7xl flex-col px-4 py-2">
              {nav.map((n) => {
                const active = path === n.to || (n.to !== "/dashboard" && path.startsWith(n.to));
                return (
                  <Link
                    key={n.to}
                    to={n.to}
                    onClick={() => setOpen(false)}
                    className={`flex items-center gap-2 rounded-md px-3 py-2.5 text-sm transition-colors ${
                      active ? "bg-secondary text-foreground" : "text-muted-foreground hover:text-foreground"
                    }`}
                  >
                    <n.icon className="h-4 w-4" />
                    {n.label}
                  </Link>
                );
              })}
              <Link
                to="/settings/organization"
                onClick={() => setOpen(false)}
                className="flex items-center gap-2 rounded-md px-3 py-2.5 text-sm text-muted-foreground hover:text-foreground"
              >
                <Settings className="h-4 w-4" /> Settings
              </Link>
              <div className="mt-2 border-t border-hairline pt-2">
                {user?.email && <div className="px-3 py-1 text-[11px] text-muted-foreground truncate">{user.email}</div>}
                <button
                  onClick={() => { setOpen(false); handleSignOut(); }}
                  className="flex w-full items-center gap-2 rounded-md px-3 py-2.5 text-sm text-muted-foreground hover:text-foreground"
                >
                  <LogOut className="h-4 w-4" /> Sign out
                </button>
              </div>
            </nav>
          </div>
        )}
      </header>
      <main className="mx-auto max-w-7xl px-4 py-6 sm:px-6 sm:py-10">{children}</main>
    </div>
  );
}

function ActiveOrgErrorScreen({ error, onSignOut }: { error: unknown; onSignOut: () => void | Promise<void> }) {
  const message = isAuthConfigurationError(error)
    ? SESSION_VERIFICATION_ERROR_MESSAGE
    : "We couldn’t load your organization. Please refresh the page or contact support if this continues.";

  return (
    <div className="flex min-h-screen items-center justify-center px-6">
      <div className="w-full max-w-md rounded-xl border border-hairline bg-background p-6 text-center shadow-sm">
        <Building2 className="mx-auto h-8 w-8 text-muted-foreground" />
        <h1 className="mt-6 text-2xl font-semibold tracking-tight">We couldn’t load your workspace</h1>
        <p className="mt-2 text-sm text-muted-foreground">{message}</p>
        <div className="mt-6 flex flex-col gap-2 sm:flex-row sm:justify-center">
          <Button type="button" onClick={() => window.location.reload()} className="rounded-full">
            Refresh
          </Button>
          {isAuthConfigurationError(error) && (
            <Button type="button" variant="outline" onClick={onSignOut} className="rounded-full">
              Sign out
            </Button>
          )}
        </div>
      </div>
    </div>
  );
}

function OrgSwitcher() {
  const { data: activeOrg } = useActiveOrg();
  const { data: orgs = [] } = useMyOrganizations();
  const switchOrg = useSwitchActiveOrg();
  const navigate = useNavigate();
  const [creating, setCreating] = useState(false);
  const [name, setName] = useState("");
  const createFn = useServerFn(createOrganization);
  const qc = useQueryClient();

  if (!activeOrg) return null;

  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <button className="flex items-center gap-1.5 rounded-md border border-hairline px-2.5 py-1 text-[12px] hover:bg-secondary/50 max-w-[180px]">
          {activeOrg.profile.logo_url ? (
            <img src={activeOrg.profile.logo_url} alt="" className="h-4 w-4 rounded object-contain" />
          ) : (
            <Building2 className="h-3.5 w-3.5 shrink-0" />
          )}
          <span className="truncate">{activeOrg.org_name}</span>
          <ChevronDown className="h-3 w-3 shrink-0 text-muted-foreground" />
        </button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="start" className="w-64">
        <DropdownMenuLabel className="text-[10px] uppercase tracking-wider text-muted-foreground">Organizations</DropdownMenuLabel>
        {orgs.map((o) => (
          <DropdownMenuItem
            key={o.id}
            onClick={() => switchOrg(o.id)}
            className="flex items-center justify-between"
          >
            <span className="truncate">{o.name}</span>
            {o.id === activeOrg.org_id && <Check className="h-3.5 w-3.5" />}
          </DropdownMenuItem>
        ))}
        <DropdownMenuSeparator />
        {!creating ? (
          <DropdownMenuItem onSelect={(e) => { e.preventDefault(); setCreating(true); }}>
            <Plus className="mr-2 h-3.5 w-3.5" /> Create organization
          </DropdownMenuItem>
        ) : (
          <div className="p-2 space-y-2" onClick={(e) => e.stopPropagation()}>
            <Input
              autoFocus
              placeholder="Company name"
              value={name}
              onChange={(e) => setName(e.target.value)}
              onKeyDown={async (e) => {
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
              }}
              className="h-8 text-xs"
            />
            <div className="flex justify-end gap-1">
              <Button variant="ghost" size="sm" onClick={() => { setCreating(false); setName(""); }}>Cancel</Button>
            </div>
          </div>
        )}
        <DropdownMenuSeparator />
        <DropdownMenuItem onSelect={() => navigate({ to: "/settings/organization" })}>
          <Settings className="mr-2 h-3.5 w-3.5" /> Organization settings
        </DropdownMenuItem>
        <DropdownMenuItem onSelect={() => navigate({ to: "/settings/team" })}>
          <Users className="mr-2 h-3.5 w-3.5" /> Team
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  );
}

function OrganizationErrorScreen({ message }: { message: string }) {
  return (
    <div className="flex min-h-screen items-center justify-center px-6">
      <div className="w-full max-w-sm text-center">
        <Building2 className="mx-auto h-8 w-8 text-muted-foreground" />
        <h1 className="mt-6 text-2xl font-semibold tracking-tight">Could not load your organization</h1>
        <p className="mt-2 text-sm text-muted-foreground">{message}</p>
      </div>
    </div>
  );
}

function OnboardingScreen() {
  const [name, setName] = useState("");
  const [busy, setBusy] = useState(false);
  const createFn = useServerFn(createOrganization);
  const qc = useQueryClient();
  const navigate = useNavigate();

  const submit = async (e: React.FormEvent) => {
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

  return (
    <div className="flex min-h-screen items-center justify-center px-6">
      <form onSubmit={submit} className="w-full max-w-sm">
        <Building2 className="mx-auto h-8 w-8" />
        <h1 className="mt-6 text-2xl font-semibold tracking-tight text-center">Set up your workspace</h1>
        <p className="mt-1 text-sm text-muted-foreground text-center">
          Name your company. You can change this later.
        </p>
        <div className="mt-8 space-y-2">
          <Label className="text-xs" htmlFor="orgname">Company name</Label>
          <Input
            id="orgname"
            autoFocus
            required
            value={name}
            onChange={(e) => setName(e.target.value)}
            placeholder="Acme Inc."
          />
        </div>
        <Button type="submit" disabled={busy} className="mt-6 w-full rounded-full">
          {busy ? "Creating…" : "Continue"}
        </Button>
      </form>
    </div>
  );
}
