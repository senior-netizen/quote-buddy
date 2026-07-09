import { cloudflare } from "@cloudflare/vite-plugin";
import tailwindcss from "@tailwindcss/vite";
import { tanstackStart } from "@tanstack/react-start/plugin/vite";
import viteReact from "@vitejs/plugin-react";
import { nitro } from "nitro/vite";
import { defineConfig } from "vite";
import tsConfigPaths from "vite-tsconfig-paths";

const isVercel = process.env.DEPLOY_TARGET === "vercel" || !!process.env.VERCEL;

export default defineConfig({
  plugins: [
    tanstackStart(isVercel ? { target: "vercel" } : {}),
    viteReact(),
    tailwindcss(),
    tsConfigPaths(),
    nitro({ preset: "vercel" }),
    ...(!isVercel ? [cloudflare()] : []),
  ],
  resolve: {
    alias: {
      "@": "/src",
    },
    dedupe: ["react", "react-dom", "@tanstack/react-router"],
  },
});
