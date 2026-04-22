import { Outlet, createRootRoute, HeadContent, Scripts } from "@tanstack/react-router";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { useState } from "react";
import { Toaster } from "sonner";
import { AuthProvider } from "@/lib/auth";

import appCss from "../styles.css?url";

export const Route = createRootRoute({
  head: () => ({
    meta: [
      { charSet: "utf-8" },
      { name: "viewport", content: "width=device-width, initial-scale=1" },
      { title: "QuoteFlow — Quotations & Invoices" },
      { name: "description", content: "Generate branded quotations and invoices as downloadable PDFs." },
      { property: "og:title", content: "QuoteFlow — Quotations & Invoices" },
      { name: "twitter:title", content: "QuoteFlow — Quotations & Invoices" },
      { property: "og:description", content: "Generate branded quotations and invoices as downloadable PDFs." },
      { name: "twitter:description", content: "Generate branded quotations and invoices as downloadable PDFs." },
      { property: "og:image", content: "https://pub-bb2e103a32db4e198524a2e9ed8f35b4.r2.dev/7b7b8dbc-2983-449b-b7f1-5327ad709efc/id-preview-7cadae0f--811256b6-3890-4817-b639-3123035fdea0.lovable.app-1776841948871.png" },
      { name: "twitter:image", content: "https://pub-bb2e103a32db4e198524a2e9ed8f35b4.r2.dev/7b7b8dbc-2983-449b-b7f1-5327ad709efc/id-preview-7cadae0f--811256b6-3890-4817-b639-3123035fdea0.lovable.app-1776841948871.png" },
      { name: "twitter:card", content: "summary_large_image" },
      { property: "og:type", content: "website" },
    ],
    links: [{ rel: "stylesheet", href: appCss }],
  }),
  shellComponent: RootShell,
  component: RootComponent,
  notFoundComponent: () => (
    <div className="flex min-h-screen items-center justify-center px-4">
      <div className="max-w-md text-center">
        <h1 className="text-7xl font-semibold tracking-tight">404</h1>
        <p className="mt-4 text-sm text-muted-foreground">This page doesn't exist.</p>
        <a href="/" className="mt-6 inline-block text-sm underline underline-offset-4">Go home</a>
      </div>
    </div>
  ),
});

function RootShell({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <head><HeadContent /></head>
      <body>{children}<Scripts /></body>
    </html>
  );
}

function RootComponent() {
  const [qc] = useState(() => new QueryClient({ defaultOptions: { queries: { staleTime: 30_000, refetchOnWindowFocus: false } } }));
  return (
    <QueryClientProvider client={qc}>
      <AuthProvider>
        <Outlet />
        <Toaster position="top-center" />
      </AuthProvider>
    </QueryClientProvider>
  );
}
