import { createFileRoute, useNavigate, Link } from "@tanstack/react-router";
import { useEffect, useState } from "react";
import { useServerFn } from "@tanstack/react-start";
import { useQueryClient } from "@tanstack/react-query";
import { getInvitation, acceptInvitation, type InvitationLookup } from "@/lib/org.functions";
import { useAuth } from "@/lib/auth";
import { Button } from "@/components/ui/button";
import { toast } from "sonner";
import { Building2, Loader2 } from "lucide-react";

export const Route = createFileRoute("/invite/$token")({ component: InvitePage });

function InvitePage() {
  const { token } = Route.useParams();
  const inviteRedirect = `/invite/${encodeURIComponent(token)}`;
  const navigate = useNavigate();
  const { user, loading: authLoading } = useAuth();
  const lookupFn = useServerFn(getInvitation);
  const acceptFn = useServerFn(acceptInvitation);
  const qc = useQueryClient();

  const [info, setInfo] = useState<InvitationLookup | null>(null);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    lookupFn({ data: { token } })
      .then((r) => setInfo(r))
      .catch(() => setInfo({ status: "not_found" }))
      .finally(() => setLoading(false));
  }, [lookupFn, token]);

  const accept = async () => {
    setBusy(true);
    try {
      await acceptFn({ data: { token } });
      await qc.invalidateQueries();
      toast.success("Joined organization");
      navigate({ to: "/dashboard" });
    } catch (e) {
      toast.error(e instanceof Error ? e.message : "Failed");
    } finally {
      setBusy(false);
    }
  };

  if (loading) {
    return (
      <div className="flex min-h-screen items-center justify-center text-sm text-muted-foreground gap-2">
        <Loader2 className="h-4 w-4 animate-spin" /> Loading invitation…
      </div>
    );
  }

  return (
    <div className="flex min-h-screen items-center justify-center px-6">
      <div className="w-full max-w-sm text-center">
        <Building2 className="mx-auto h-8 w-8" />
        {info?.status === "ok" ? (
          <>
            <h1 className="mt-6 text-2xl font-semibold tracking-tight">Join {info.org_name}</h1>
            <p className="mt-2 text-sm text-muted-foreground">
              You've been invited to join as a <span className="font-medium">{info.role}</span>.
            </p>
            <p className="mt-1 text-xs text-muted-foreground">Invitation for {info.email}</p>
            {authLoading ? (
              <div className="mt-8 text-sm text-muted-foreground">Loading…</div>
            ) : !user ? (
              <div className="mt-8 space-y-4">
                <p className="text-sm text-muted-foreground">
                  Sign in or create an account before accepting this invitation.
                </p>
                <Link to="/login" search={{ redirect: inviteRedirect }} className="inline-block w-full">
                  <Button className="w-full rounded-full">
                    Sign in or create account to accept
                  </Button>
                </Link>
              </div>
            ) : (
              <Button onClick={accept} disabled={busy} className="mt-8 w-full rounded-full">
                {busy ? "Joining…" : "Accept invitation"}
              </Button>
            )}
          </>
        ) : info?.status === "expired" ? (
          <Msg title="Invitation expired" body="Ask the organization owner to send a new one." />
        ) : info?.status === "accepted" ? (
          <Msg title="Already accepted" body="This invitation has already been used." />
        ) : (
          <Msg title="Invitation not found" body="The link may be incorrect or revoked." />
        )}
      </div>
    </div>
  );
}

function Msg({ title, body }: { title: string; body: string }) {
  return (
    <>
      <h1 className="mt-6 text-2xl font-semibold tracking-tight">{title}</h1>
      <p className="mt-2 text-sm text-muted-foreground">{body}</p>
      <Link to="/" className="mt-8 inline-block text-xs underline underline-offset-4">Go home</Link>
    </>
  );
}
