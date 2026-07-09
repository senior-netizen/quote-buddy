import { createFileRoute } from "@tanstack/react-router";
import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useServerFn } from "@tanstack/react-start";
import { useActiveOrg } from "@/lib/org";
import {
  listMembers,
  listInvitations,
  inviteMember,
  revokeInvitation,
  removeMember,
  changeMemberRole,
  verifyEmailConfiguration,
} from "@/lib/org.functions";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { toast } from "sonner";
import { CheckCircle2, Copy, Trash2, XCircle } from "lucide-react";

export const Route = createFileRoute("/settings/team")({ component: Team });

type Role = "owner" | "admin" | "member";

function Team() {
  const { data: activeOrg } = useActiveOrg();
  const qc = useQueryClient();
  const orgId = activeOrg?.org_id;

  const listMembersFn = useServerFn(listMembers);
  const listInvitationsFn = useServerFn(listInvitations);
  const inviteFn = useServerFn(inviteMember);
  const revokeFn = useServerFn(revokeInvitation);
  const removeFn = useServerFn(removeMember);
  const changeFn = useServerFn(changeMemberRole);
  const verifyEmailFn = useServerFn(verifyEmailConfiguration);

  const members = useQuery({
    queryKey: ["members", orgId],
    queryFn: () => listMembersFn({ data: { org_id: orgId! } }),
    enabled: !!orgId,
  });
  const invites = useQuery({
    queryKey: ["invites", orgId],
    queryFn: () => listInvitationsFn({ data: { org_id: orgId! } }),
    enabled: !!orgId,
  });

  const [email, setEmail] = useState("");
  const [role, setRole] = useState<Role>("member");
  const [emailCheck, setEmailCheck] = useState<Awaited<ReturnType<typeof verifyEmailFn>> | null>(null);

  const canAdmin = activeOrg?.role === "owner" || activeOrg?.role === "admin";

  const send = useMutation({
    mutationFn: async () => {
      if (!orgId) throw new Error("No org");
      return inviteFn({ data: { org_id: orgId, email: email.trim(), role } });
    },
    onSuccess: () => {
      toast.success("Invitation email sent");
      setEmail("");
      qc.invalidateQueries({ queryKey: ["invites", orgId] });
    },
    onError: (e) => toast.error(e instanceof Error ? e.message : "Failed"),
  });

  const verifyEmail = useMutation({
    mutationFn: async () => {
      if (!orgId) throw new Error("No org");
      return verifyEmailFn({ data: { org_id: orgId } });
    },
    onSuccess: (result) => {
      setEmailCheck(result);
      if (result.ok) {
        toast.success("Invitation email configuration verified");
      } else {
        toast.error("Invitation email configuration needs attention");
      }
    },
    onError: (e) => toast.error(e instanceof Error ? e.message : "Failed"),
  });

  if (!activeOrg) return null;

  return (
    <div className="space-y-10 max-w-3xl">
      {canAdmin && (
        <section className="space-y-3">
          <h2 className="text-sm font-medium">Invite teammate</h2>
          <div className="flex flex-col gap-2 sm:flex-row">
            <Input
              type="email"
              placeholder="email@company.com"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="flex-1"
            />
            <Select value={role} onValueChange={(v) => setRole(v as Role)}>
              <SelectTrigger className="sm:w-32"><SelectValue /></SelectTrigger>
              <SelectContent>
                <SelectItem value="member">Member</SelectItem>
                <SelectItem value="admin">Admin</SelectItem>
                {activeOrg.role === "owner" && <SelectItem value="owner">Owner</SelectItem>}
              </SelectContent>
            </Select>
            <Button onClick={() => send.mutate()} disabled={send.isPending || !email.trim()} className="rounded-full">
              {send.isPending ? "Sending…" : "Invite"}
            </Button>
          </div>
          <div className="space-y-2">
            <p className="text-[11px] text-muted-foreground">
              We'll email the invitation and keep a pending link below so admins can copy it if needed.
            </p>
            <div className="rounded-xl border border-hairline bg-secondary/30 p-3 text-xs">
              <div className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
                <div>
                  <p className="font-medium">Resend invitation email configuration</p>
                  <p className="text-muted-foreground">
                    Verify APP_ORIGIN, sender address, API access, and sender domain readiness before sending invites.
                  </p>
                </div>
                <Button
                  type="button"
                  variant="outline"
                  size="sm"
                  onClick={() => verifyEmail.mutate()}
                  disabled={verifyEmail.isPending}
                  className="rounded-full"
                >
                  {verifyEmail.isPending ? "Checking…" : "Verify email"}
                </Button>
              </div>
              {emailCheck && (
                <div className="mt-3 flex gap-2">
                  {emailCheck.ok ? (
                    <CheckCircle2 className="mt-0.5 h-4 w-4 text-green-600" />
                  ) : (
                    <XCircle className="mt-0.5 h-4 w-4 text-destructive" />
                  )}
                  <div className="space-y-1">
                    <p className="font-medium">{emailCheck.ok ? "Ready to send invitations" : "Configuration check failed"}</p>
                    <ul className="list-disc space-y-0.5 pl-4 text-muted-foreground">
                      {emailCheck.messages.map((message) => (
                        <li key={message}>{message}</li>
                      ))}
                      {emailCheck.fromDomain && <li>Sender domain: {emailCheck.fromDomain}</li>}
                    </ul>
                  </div>
                </div>
              )}
            </div>
          </div>
        </section>
      )}

      <section className="space-y-3">
        <h2 className="text-sm font-medium">Members ({members.data?.length ?? 0})</h2>
        <div className="overflow-hidden rounded-xl border border-hairline">
          <table className="w-full text-sm">
            <thead className="border-b border-hairline bg-secondary/50">
              <tr className="text-[11px] uppercase tracking-wider text-muted-foreground">
                <th className="px-4 py-2.5 text-left font-medium">Email</th>
                <th className="px-4 py-2.5 text-left font-medium">Role</th>
                <th className="w-16"></th>
              </tr>
            </thead>
            <tbody>
              {(members.data ?? []).map((m) => (
                <tr key={m.id} className="border-b border-hairline last:border-0">
                  <td className="px-4 py-2.5">{m.email ?? "—"}</td>
                  <td className="px-4 py-2.5">
                    {canAdmin ? (
                      <Select
                        value={m.role}
                        onValueChange={async (v) => {
                          try {
                            await changeFn({ data: { id: m.id, org_id: orgId!, role: v as Role } });
                            qc.invalidateQueries({ queryKey: ["members", orgId] });
                          } catch (e) {
                            toast.error(e instanceof Error ? e.message : "Failed");
                          }
                        }}
                      >
                        <SelectTrigger className="h-7 w-28 text-xs"><SelectValue /></SelectTrigger>
                        <SelectContent>
                          <SelectItem value="member">Member</SelectItem>
                          <SelectItem value="admin">Admin</SelectItem>
                          {activeOrg.role === "owner" && <SelectItem value="owner">Owner</SelectItem>}
                        </SelectContent>
                      </Select>
                    ) : (
                      <span className="text-xs uppercase tracking-wider text-muted-foreground">{m.role}</span>
                    )}
                  </td>
                  <td className="px-3 py-2.5 text-right">
                    {canAdmin && (
                      <Button
                        variant="ghost"
                        size="sm"
                        onClick={async () => {
                          if (!confirm("Remove this member?")) return;
                          try {
                            await removeFn({ data: { id: m.id, org_id: orgId! } });
                            qc.invalidateQueries({ queryKey: ["members", orgId] });
                          } catch (e) {
                            toast.error(e instanceof Error ? e.message : "Failed");
                          }
                        }}
                      >
                        <Trash2 className="h-3.5 w-3.5 text-muted-foreground hover:text-destructive" />
                      </Button>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      {canAdmin && (invites.data?.length ?? 0) > 0 && (
        <section className="space-y-3">
          <h2 className="text-sm font-medium">Pending invitations</h2>
          <div className="overflow-hidden rounded-xl border border-hairline">
            <table className="w-full text-sm">
              <thead className="border-b border-hairline bg-secondary/50">
                <tr className="text-[11px] uppercase tracking-wider text-muted-foreground">
                  <th className="px-4 py-2.5 text-left font-medium">Email</th>
                  <th className="px-4 py-2.5 text-left font-medium">Role</th>
                  <th className="px-4 py-2.5 text-left font-medium">Expires</th>
                  <th className="w-32"></th>
                </tr>
              </thead>
              <tbody>
                {(invites.data ?? []).map((i) => {
                  const link = `${window.location.origin}/invite/${i.token}`;
                  return (
                    <tr key={i.id} className="border-b border-hairline last:border-0">
                      <td className="px-4 py-2.5">{i.email}</td>
                      <td className="px-4 py-2.5 text-xs uppercase tracking-wider text-muted-foreground">{i.role}</td>
                      <td className="px-4 py-2.5 text-xs text-muted-foreground">{new Date(i.expires_at).toLocaleDateString()}</td>
                      <td className="px-3 py-2.5">
                        <div className="flex justify-end gap-1">
                          <Button
                            variant="ghost"
                            size="sm"
                            onClick={async () => {
                              await navigator.clipboard.writeText(link);
                              toast.success("Pending invitation link copied");
                            }}
                          >
                            <Copy className="h-3.5 w-3.5" />
                          </Button>
                          <Button
                            variant="ghost"
                            size="sm"
                            onClick={async () => {
                              try {
                                await revokeFn({ data: { id: i.id, org_id: orgId! } });
                                qc.invalidateQueries({ queryKey: ["invites", orgId] });
                              } catch (e) {
                                toast.error(e instanceof Error ? e.message : "Failed");
                              }
                            }}
                          >
                            <Trash2 className="h-3.5 w-3.5 text-muted-foreground hover:text-destructive" />
                          </Button>
                        </div>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </section>
      )}
    </div>
  );
}

