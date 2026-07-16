import { createFileRoute } from "@tanstack/react-router";

/**
 * Handles the automatic /favicon.ico browser request.
 * Redirects to the actual PNG favicon to prevent a 500 SSR crash.
 */
export const Route = createFileRoute("/favicon.ico")({
  server: {
    handlers: {
      GET: async () => {
        return new Response(null, {
          status: 301,
          headers: {
            Location: "/favicon.png",
            "Cache-Control": "public, max-age=86400",
          },
        });
      },
    },
  },
});
