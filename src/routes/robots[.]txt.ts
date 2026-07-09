import { createFileRoute } from "@tanstack/react-router";

export const Route = createFileRoute("/robots.txt")({
  server: {
    handlers: {
      GET: async ({ request }) => {
        const origin = getCanonicalOrigin(request);

        return new Response(`User-agent: *
Allow: /
Disallow: /api/
Disallow: /dashboard
Disallow: /documents
Disallow: /settings
Disallow: /clients
Disallow: /invite
Disallow: /verify

Sitemap: ${origin}/sitemap.xml
`, {
          headers: {
            "content-type": "text/plain; charset=utf-8",
            "cache-control": "public, max-age=3600",
          },
        });
      },
    },
  },
});

function getCanonicalOrigin(request: Request) {
  const configuredOrigin = process.env.APP_ORIGIN?.trim();
  if (configuredOrigin) return configuredOrigin.replace(/\/$/, "");
  return new URL(request.url).origin;
}
