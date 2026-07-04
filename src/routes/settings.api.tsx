import { createFileRoute } from "@tanstack/react-router";
import { useEffect, useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { toast } from "sonner";
import { supabase } from "@/integrations/supabase/client";
import { useActiveOrg } from "@/lib/org";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Copy, Trash2, KeyRound } from "lucide-react";
import { Link } from "@tanstack/react-router";

export const Route = createFileRoute("/settings/api")({
  component: ApiSettingsPage,
});

const KEY_PREFIX = "qsk_live_";

async function sha256Hex(input: string) {
  const buf = new TextEncoder().encode(input);
  const digest = await crypto.subtle.digest("SHA-256", buf);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

function generateKey(): string {
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  const secret = Array.from(bytes)
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
  return `${KEY_PREFIX}${secret}`;
}

type ApiKeyRow = {
  id: string;
  name: string;
  prefix: string;
  created_at: string;
  last_used_at: string | null;
  revoked_at: string | null;
};

function ApiSettingsPage() {
  const { data: activeOrg } = useActiveOrg();
  const orgId = activeOrg?.org_id;
  const qc = useQueryClient();
  const [name, setName] = useState("");
  const [freshKey, setFreshKey] = useState<string | null>(null);

  const keysQuery = useQuery({
    enabled: !!orgId,
    queryKey: ["api-keys", orgId],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("api_keys")
        .select("id, name, prefix, created_at, last_used_at, revoked_at")
        .eq("org_id", orgId!)
        .order("created_at", { ascending: false });
      if (error) throw error;
      return (data ?? []) as ApiKeyRow[];
    },
  });

  const create = useMutation({
    mutationFn: async () => {
      if (!orgId) throw new Error("No active org");
      const trimmed = name.trim();
      if (!trimmed) throw new Error("Name required");
      const { data: userRes } = await supabase.auth.getUser();
      const key = generateKey();
      const hash = await sha256Hex(key);
      const prefix = key.slice(0, KEY_PREFIX.length + 6);
      const { error } = await supabase.from("api_keys").insert({
        org_id: orgId,
        name: trimmed,
        prefix,
        key_hash: hash,
        created_by: userRes.user?.id ?? null,
      });
      if (error) throw new Error(error.message);
      return key;
    },
    onSuccess: (key) => {
      setFreshKey(key);
      setName("");
      qc.invalidateQueries({ queryKey: ["api-keys", orgId] });
    },
    onError: (e: Error) => toast.error(e.message),
  });

  const revoke = useMutation({
    mutationFn: async (id: string) => {
      const { error } = await supabase
        .from("api_keys")
        .update({ revoked_at: new Date().toISOString() })
        .eq("id", id);
      if (error) throw new Error(error.message);
    },
    onSuccess: () => {
      toast.success("Key revoked");
      qc.invalidateQueries({ queryKey: ["api-keys", orgId] });
    },
    onError: (e: Error) => toast.error(e.message),
  });

  const rotate = useMutation({
    mutationFn: async (existing: ApiKeyRow) => {
      if (!orgId) throw new Error("No active org");
      const { data: userRes } = await supabase.auth.getUser();
      const key = generateKey();
      const hash = await sha256Hex(key);
      const prefix = key.slice(0, KEY_PREFIX.length + 6);
      // Insert the replacement first — existing key keeps working until you revoke it.
      const { error } = await supabase.from("api_keys").insert({
        org_id: orgId,
        name: `${existing.name} (rotated)`,
        prefix,
        key_hash: hash,
        created_by: userRes.user?.id ?? null,
      });
      if (error) throw new Error(error.message);
      return key;
    },
    onSuccess: (key) => {
      setFreshKey(key);
      toast.success("New key issued. Old key still works — revoke it once you've migrated.");
      qc.invalidateQueries({ queryKey: ["api-keys", orgId] });
    },
    onError: (e: Error) => toast.error(e.message),
  });

  const remove = useMutation({
    mutationFn: async (id: string) => {
      const { error } = await supabase.from("api_keys").delete().eq("id", id);
      if (error) throw new Error(error.message);
    },
    onSuccess: () => {
      toast.success("Key deleted");
      qc.invalidateQueries({ queryKey: ["api-keys", orgId] });
    },
    onError: (e: Error) => toast.error(e.message),
  });

  useEffect(() => {
    if (!freshKey) return;
    const t = setTimeout(() => {}, 0);
    return () => clearTimeout(t);
  }, [freshKey]);

  return (
    <div className="space-y-8 max-w-3xl">
      <div>
        <h2 className="text-xl font-semibold">API keys</h2>
        <p className="text-sm text-muted-foreground mt-1">
          Issue keys for external apps to call our{" "}
          <Link to="/developers" className="underline">public API</Link>. Each key acts on behalf of this organization.
        </p>
      </div>

      <Card>
        <CardHeader>
          <CardTitle className="text-base">Create a new key</CardTitle>
        </CardHeader>
        <CardContent className="space-y-3">
          <div className="flex gap-2">
            <Input
              placeholder="e.g. Zapier integration"
              value={name}
              onChange={(e) => setName(e.target.value)}
              disabled={create.isPending}
            />
            <Button onClick={() => create.mutate()} disabled={create.isPending || !name.trim()}>
              <KeyRound className="w-4 h-4 mr-1" />
              Generate
            </Button>
          </div>
          {freshKey && (
            <div className="rounded-md border border-amber-500/40 bg-amber-500/10 p-3 text-sm">
              <p className="font-medium">Copy this key now — it won't be shown again.</p>
              <div className="mt-2 flex items-center gap-2">
                <code className="flex-1 break-all rounded bg-background/60 px-2 py-1 font-mono text-xs">
                  {freshKey}
                </code>
                <Button
                  size="sm"
                  variant="outline"
                  onClick={() => {
                    navigator.clipboard.writeText(freshKey);
                    toast.success("Copied");
                  }}
                >
                  <Copy className="w-3.5 h-3.5" />
                </Button>
                <Button size="sm" variant="ghost" onClick={() => setFreshKey(null)}>
                  Dismiss
                </Button>
              </div>
            </div>
          )}
        </CardContent>
      </Card>

      <div>
        <h3 className="text-sm font-medium mb-3">Existing keys</h3>
        {keysQuery.isLoading ? (
          <p className="text-sm text-muted-foreground">Loading…</p>
        ) : keysQuery.data?.length ? (
          <div className="border border-hairline rounded-md divide-y divide-hairline">
            {keysQuery.data.map((k) => (
              <div key={k.id} className="flex items-center justify-between gap-4 p-3">
                <div className="min-w-0">
                  <div className="flex items-center gap-2">
                    <span className="font-medium truncate">{k.name}</span>
                    {k.revoked_at && (
                      <span className="text-[10px] uppercase tracking-wide px-1.5 py-0.5 rounded bg-destructive/10 text-destructive">
                        revoked
                      </span>
                    )}
                  </div>
                  <div className="text-xs text-muted-foreground mt-0.5 font-mono">
                    {k.prefix}…
                  </div>
                  <div className="text-[11px] text-muted-foreground mt-0.5">
                    Created {new Date(k.created_at).toLocaleDateString()}
                    {k.last_used_at ? ` · last used ${new Date(k.last_used_at).toLocaleDateString()}` : " · never used"}
                  </div>
                </div>
                <div className="flex items-center gap-1">
                  {!k.revoked_at && (
                    <Button variant="outline" size="sm" onClick={() => revoke.mutate(k.id)}>
                      Revoke
                    </Button>
                  )}
                  <Button variant="ghost" size="sm" onClick={() => remove.mutate(k.id)}>
                    <Trash2 className="w-4 h-4" />
                  </Button>
                </div>
              </div>
            ))}
          </div>
        ) : (
          <p className="text-sm text-muted-foreground">No keys yet.</p>
        )}
      </div>
    </div>
  );
}
