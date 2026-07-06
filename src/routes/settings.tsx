import { createFileRoute, Outlet, Link, useRouterState } from "@tanstack/react-router";
import { RequireAuth } from "@/components/RequireAuth";
import { AppShell } from "@/components/AppShell";

export const Route = createFileRoute("/settings")({
  component: SettingsLayout,
});

function SettingsLayout() {
  return (
    <RequireAuth>
      <AppShell>
        <SettingsInner />
      </AppShell>
    </RequireAuth>
  );
}

function SettingsInner() {
  const path = useRouterState({ select: (s) => s.location.pathname });
  const tabs = [
    { to: "/settings/organization", label: "Organization" },
    { to: "/settings/team", label: "Team" },
    { to: "/settings/fiscal", label: "ZIMRA" },
    { to: "/settings/api", label: "API" },
  ] as const;
  return (
    <div>
      <p className="text-[11px] uppercase tracking-[0.2em] text-muted-foreground">Settings</p>
      <h1 className="mt-2 text-3xl sm:text-4xl font-semibold tracking-tight">Workspace</h1>
      <nav className="mt-6 flex gap-1 border-b border-hairline">
        {tabs.map((t) => {
          const active = path === t.to;
          return (
            <Link
              key={t.to}
              to={t.to}
              className={`px-4 py-2 text-sm border-b-2 -mb-px transition-colors ${
                active ? "border-foreground text-foreground" : "border-transparent text-muted-foreground hover:text-foreground"
              }`}
            >
              {t.label}
            </Link>
          );
        })}
      </nav>
      <div className="mt-8">
        <Outlet />
      </div>
    </div>
  );
}
