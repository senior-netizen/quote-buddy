import { createContext, useContext, useEffect, useState, type ReactNode } from "react";
import type { Session, User } from "@supabase/supabase-js";
import {
  supabase,
  getSupabaseClientConfig,
  CLIENT_CONFIG_MISSING_CODE,
} from "@/integrations/supabase/client";

export type AuthConfigError = {
  code: string;
  missingVariables: string[];
  message: string;
};

type AuthCtx = {
  user: User | null;
  session: Session | null;
  loading: boolean;
  /** Set when auth cannot be initialized due to missing configuration. */
  configError: AuthConfigError | null;
  signIn: (email: string, password: string) => Promise<void>;
  signUp: (email: string, password: string, redirectTo?: string) => Promise<void>;
  signOut: () => Promise<void>;
};

const Ctx = createContext<AuthCtx | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [session, setSession] = useState<Session | null>(null);
  const [loading, setLoading] = useState(true);
  const [configError, setConfigError] = useState<AuthConfigError | null>(null);

  useEffect(() => {
    // Never hang on a blank/loading screen when the browser Supabase client is
    // not configured. Detect it up front, surface a coded error, and let the
    // rest of the app render.
    const { configured, missingVariables } = getSupabaseClientConfig();
    if (!configured) {
      console.error("Auth disabled: missing Supabase browser configuration", {
        code: CLIENT_CONFIG_MISSING_CODE,
        missingVariables,
      });
      setConfigError({
        code: CLIENT_CONFIG_MISSING_CODE,
        missingVariables,
        message: "Authentication is temporarily unavailable.",
      });
      setLoading(false);
      return;
    }

    let subscription: { unsubscribe: () => void } | undefined;
    try {
      const { data: sub } = supabase.auth.onAuthStateChange((_e, s) => {
        setSession(s);
        setUser(s?.user ?? null);
      });
      subscription = sub.subscription;
      supabase.auth
        .getSession()
        .then(({ data }) => {
          setSession(data.session);
          setUser(data.session?.user ?? null);
        })
        .catch((err) => {
          console.error("Failed to read Supabase session", err);
        })
        .finally(() => setLoading(false));
    } catch (err) {
      console.error("Failed to initialize Supabase auth", err);
      setConfigError({
        code: CLIENT_CONFIG_MISSING_CODE,
        missingVariables,
        message: "Authentication is temporarily unavailable.",
      });
      setLoading(false);
    }

    return () => subscription?.unsubscribe();
  }, []);

  const ensureConfigured = () => {
    if (configError) {
      const err = new Error(configError.message) as Error & { code: string };
      err.code = configError.code;
      throw err;
    }
  };

  const signIn = async (email: string, password: string) => {
    ensureConfigured();
    const { error } = await supabase.auth.signInWithPassword({ email, password });
    if (error) throw error;
  };
  const signUp = async (email: string, password: string, redirectTo = "/dashboard") => {
    ensureConfigured();
    const { error } = await supabase.auth.signUp({
      email,
      password,
      options: { emailRedirectTo: `${window.location.origin}${redirectTo}` },
    });
    if (error) throw error;
  };
  const signOut = async () => {
    ensureConfigured();
    await supabase.auth.signOut();
  };

  return (
    <Ctx.Provider value={{ user, session, loading, configError, signIn, signUp, signOut }}>
      {children}
    </Ctx.Provider>
  );
}

export function useAuth() {
  const ctx = useContext(Ctx);
  if (!ctx) throw new Error("useAuth must be used inside AuthProvider");
  return ctx;
}
