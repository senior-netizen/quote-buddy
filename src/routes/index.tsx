import { createFileRoute, Link, useNavigate } from "@tanstack/react-router";
import { useEffect } from "react";
import { useAuth } from "@/lib/auth";
import logo from "@/assets/quoteflow-logo.png.asset.json";

export const Route = createFileRoute("/")({ component: Index });

function Index() {
  const { user, loading } = useAuth();
  const navigate = useNavigate();
  useEffect(() => {
    if (!loading && user) navigate({ to: "/dashboard" });
  }, [loading, user, navigate]);

  return (
    <div className="min-h-screen bg-background">
      <header className="mx-auto flex h-14 max-w-6xl items-center justify-between px-4 sm:px-6">
        <div className="flex items-baseline gap-2 min-w-0">
          <span className="text-[17px] font-semibold tracking-tight">Squirrellabs</span>
          <span className="hidden sm:inline text-[10px] uppercase tracking-[0.2em] text-muted-foreground">QuoteFlow</span>
        </div>
        <Link to="/login" className="text-[13px] text-muted-foreground hover:text-foreground whitespace-nowrap">
          Sign in →
        </Link>
      </header>
      <main className="mx-auto max-w-3xl px-4 pt-16 pb-16 text-center sm:px-6 sm:pt-32 sm:pb-24">
        <p className="text-[11px] uppercase tracking-[0.25em] text-muted-foreground">Quotations · Invoices · PDFs</p>
        <h1 className="mt-6 text-4xl sm:text-6xl font-semibold tracking-tight leading-[1.05]">
          Beautiful documents.<br />
          <span className="text-muted-foreground">Generated in seconds.</span>
        </h1>
        <p className="mx-auto mt-6 max-w-xl text-[15px] leading-relaxed text-muted-foreground">
          A focused tool for issuing branded quotations and invoices.
          No clutter, no busywork — just clean PDFs ready to send.
        </p>
        <div className="mt-10 flex items-center justify-center gap-3">
          <Link
            to="/login"
            className="rounded-full bg-primary px-6 py-2.5 text-[14px] font-medium text-primary-foreground transition-opacity hover:opacity-90"
          >
            Open QuoteFlow
          </Link>
        </div>
        <div className="mt-16 sm:mt-24 grid grid-cols-1 sm:grid-cols-3 gap-px overflow-hidden rounded-2xl border border-hairline bg-hairline text-left">
          {[
            { k: "QT-2025-0001", l: "Auto-numbered" },
            { k: "Real-time", l: "Calculations" },
            { k: "PDF", l: "Pixel-perfect output" },
          ].map((c) => (
            <div key={c.k} className="bg-card p-6">
              <div className="text-xs uppercase tracking-wider text-muted-foreground">{c.l}</div>
              <div className="mt-2 text-lg font-medium tracking-tight">{c.k}</div>
            </div>
          ))}
        </div>
      </main>
    </div>
  );
}
