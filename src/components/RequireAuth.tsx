import { useEffect, type ReactNode } from "react";
import { useNavigate } from "@tanstack/react-router";
import { useAuth } from "@/lib/auth";

export function RequireAuth({ children }: { children: ReactNode }) {
  const { user, loading, configError } = useAuth();
  const navigate = useNavigate();
  useEffect(() => {
    if (!configError && !loading && !user) navigate({ to: "/login" });
  }, [configError, loading, user, navigate]);

  if (configError) {
    return (
      <div className="flex min-h-screen items-center justify-center px-4">
        <div className="max-w-md text-center">
          <h1 className="text-2xl font-semibold tracking-tight text-foreground">
            Service temporarily unavailable
          </h1>
          <p className="mt-2 text-sm text-muted-foreground">{configError.message}</p>
          <p className="mt-2 font-mono text-xs text-muted-foreground">
            Error code: {configError.code}
          </p>
        </div>
      </div>
    );
  }

  if (loading || !user) {
    return (
      <div className="flex min-h-screen items-center justify-center text-sm text-muted-foreground">
        Loading…
      </div>
    );
  }
  return <>{children}</>;
}
