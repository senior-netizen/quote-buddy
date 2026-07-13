import { c as createClient } from "../_libs/supabase__supabase-js.mjs";
function createSupabaseClient() {
  const serverEnv = typeof process !== "undefined" ? process.env : void 0;
  const readEnv = (...values) => values.find((value) => value && value.trim().length > 0);
  const SUPABASE_URL = readEnv("https://bqbsqlzpjmnrtaimwbmd.supabase.co", serverEnv?.SUPABASE_URL);
  const SUPABASE_PUBLISHABLE_KEY = readEnv(
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJxYnNxbHpwam1ucnRhaW13Ym1kIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY3ODk4MTgsImV4cCI6MjA5MjM2NTgxOH0.ZUYtDDC3jRBHCdFufMAZTQ1IZPOTmmZ1vT2OFItnCMk",
    serverEnv?.SUPABASE_PUBLISHABLE_KEY
  );
  if (!SUPABASE_URL || !SUPABASE_PUBLISHABLE_KEY) {
    throw new Error(
      "Missing Supabase environment variables. Ensure SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY (or VITE_ prefixed versions) are set in your .env file."
    );
  }
  return createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, {
    auth: {
      storage: typeof window !== "undefined" ? localStorage : void 0,
      persistSession: true,
      autoRefreshToken: true
    }
  });
}
let _supabase;
const supabase = new Proxy({}, {
  get(_, prop, receiver) {
    if (!_supabase) _supabase = createSupabaseClient();
    return Reflect.get(_supabase, prop, receiver);
  }
});
export {
  supabase as s
};
