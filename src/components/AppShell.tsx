import { Link, useNavigate, useRouterState } from "@tanstack/react-router";
import { useAuth } from "@/lib/auth";
import { Button } from "@/components/ui/button";
import { LayoutDashboard, Users, FileText, Plus, LogOut, Menu, X } from "lucide-react";
import { useState, type ReactNode } from "react";
import squirrellLogo from "@/assets/squirrell-logo.png";

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

  const handleSignOut = async () => {
    await signOut();
    navigate({ to: "/login" });
  };

  return (
    <div className="min-h-screen bg-background text-foreground">
      <header className="sticky top-0 z-30 border-b border-hairline bg-background/80 backdrop-blur-xl">
        <div className="mx-auto flex h-14 max-w-7xl items-center gap-4 px-4 sm:gap-8 sm:px-6">
          <Link to="/dashboard" className="flex items-center gap-2 min-w-0">
            <img src={squirrellLogo} alt="Squirrell" className="h-9 w-auto -my-2 sm:h-10" />
            <span className="hidden sm:inline text-[10px] uppercase tracking-[0.2em] text-muted-foreground">QuoteFlow</span>
          </Link>
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
