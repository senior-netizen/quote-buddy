// @lovable.dev/vite-tanstack-config bundles tanstackStart, viteReact, tailwindcss,
// tsConfigPaths, the Cloudflare plugin (build-only), dev-only componentTagger,
// VITE_* env injection, @ path alias, React/TanStack dedupe, error logger plugins,
// and sandbox detection. Do NOT add those manually.
//
// Vercel deployment: we disable the Cloudflare plugin and set the TanStack Start
// build target to `vercel`, which emits the Vercel Build Output API v3 artifacts
// (.vercel/output) that Vercel auto-detects — no extra vercel.json needed.
import { defineConfig } from "@lovable.dev/vite-tanstack-config";

export default defineConfig({
  cloudflare: false,
  tanstackStart: { target: "vercel" },
});
