// @lovable.dev/vite-tanstack-config bundles tanstackStart, viteReact, tailwindcss,
// tsConfigPaths, the Cloudflare plugin (build-only), dev-only componentTagger,
// VITE_* env injection, @ path alias, React/TanStack dedupe, error logger plugins,
// and sandbox detection. Do NOT add those manually.
//
// Deployment targets:
// - Default (Lovable preview / published site): Cloudflare Workers
// - Vercel: set `DEPLOY_TARGET=vercel` in the Vercel project env. This disables
//   the Cloudflare plugin and switches TanStack Start to emit Vercel Build
//   Output API v3 artifacts (.vercel/output) that Vercel auto-detects.
import { defineConfig } from "@lovable.dev/vite-tanstack-config";

const isVercel = process.env.DEPLOY_TARGET === "vercel" || !!process.env.VERCEL;

export default defineConfig(
  isVercel
    ? { cloudflare: false, tanstackStart: { target: "vercel" } }
    : {},
);
