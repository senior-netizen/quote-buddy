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
} from "@/lib/org.functions";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { toast } from "sonner";
import { Copy, Trash2 } from "lucide-react";

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

  const canAdmin = activeOrg?.role === "owner" || activeOrg?.role === "admin";

  const send = useMutation({
    mutationFn: async () => {
      if (!orgId) throw new Error("No org");
      return inviteFn({ data: { org_id: orgId, email: email.trim(), role } });
    },
    onSuccess: () => {
      toast.success("Invitation created");
      setEmail("");
      qc.invalidateQueries({ queryKey: ["invites", orgId] });
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
          <p className="text-[11px] text-muted-foreground">
            We don't send emails yet — copy the invitation link below and share it with the person.
          </p>
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
                              toast.success("Link copied");
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
// Label is imported but unused intentionally? remove
void Label;
