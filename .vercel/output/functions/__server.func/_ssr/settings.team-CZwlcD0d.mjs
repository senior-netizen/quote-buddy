import { r as reactExports, j as jsxRuntimeExports } from "../_libs/react.mjs";
import { b as useQueryClient, u as useQuery, a as useMutation } from "../_libs/tanstack__react-query.mjs";
import { a as useActiveOrg, h as useServerFn, I as Input, B as Button, n as changeMemberRole, m as removeMember, r as revokeInvitation, k as inviteMember, v as verifyEmailConfiguration, l as listMembers, j as listInvitations } from "./router-DjPnTx2E.mjs";
import { S as Select, a as SelectTrigger, b as SelectValue, c as SelectContent, d as SelectItem } from "./select-B8Qi6qJp.mjs";
import { t as toast } from "../_libs/sonner.mjs";
import "./index.mjs";
import "../_libs/seroval.mjs";
import "../_libs/qrcode.mjs";
import { l as CircleCheck, m as CircleX, T as Trash2, e as Copy } from "../_libs/lucide-react.mjs";
import "../_libs/tanstack__query-core.mjs";
import "../_libs/tanstack__react-router.mjs";
import "../_libs/tanstack__router-core.mjs";
import "../_libs/tanstack__history.mjs";
import "../_libs/cookie-es.mjs";
import "../_libs/seroval-plugins.mjs";
import "node:stream/web";
import "node:stream";
import "../_libs/react-dom.mjs";
import "async_hooks";
import "util";
import "crypto";
import "stream";
import "../_libs/isbot.mjs";
import "./client-U3FzjMwq.mjs";
import "../_libs/supabase__supabase-js.mjs";
import "../_libs/supabase__postgrest-js.mjs";
import "../_libs/supabase__realtime-js.mjs";
import "../_libs/supabase__phoenix.mjs";
import "../_libs/supabase__storage-js.mjs";
import "../_libs/iceberg-js.mjs";
import "../_libs/supabase__auth-js.mjs";
import "tslib";
import "../_libs/supabase__functions-js.mjs";
import "../_libs/radix-ui__react-slot.mjs";
import "../_libs/radix-ui__react-compose-refs.mjs";
import "../_libs/class-variance-authority.mjs";
import "../_libs/clsx.mjs";
import "../_libs/tailwind-merge.mjs";
import "../_libs/radix-ui__react-label.mjs";
import "../_libs/radix-ui__react-primitive.mjs";
import "../_libs/radix-ui__react-dialog.mjs";
import "../_libs/radix-ui__primitive.mjs";
import "../_libs/radix-ui__react-context.mjs";
import "../_libs/radix-ui__react-id.mjs";
import "../_libs/@radix-ui/react-use-layout-effect+[...].mjs";
import "../_libs/@radix-ui/react-use-controllable-state+[...].mjs";
import "../_libs/@radix-ui/react-dismissable-layer+[...].mjs";
import "../_libs/@radix-ui/react-use-callback-ref+[...].mjs";
import "../_libs/@radix-ui/react-use-escape-keydown+[...].mjs";
import "../_libs/radix-ui__react-focus-scope.mjs";
import "../_libs/radix-ui__react-portal.mjs";
import "../_libs/radix-ui__react-presence.mjs";
import "../_libs/radix-ui__react-focus-guards.mjs";
import "../_libs/react-remove-scroll.mjs";
import "../_libs/react-remove-scroll-bar.mjs";
import "../_libs/react-style-singleton.mjs";
import "../_libs/get-nonce.mjs";
import "../_libs/use-sidecar.mjs";
import "../_libs/use-callback-ref.mjs";
import "../_libs/aria-hidden.mjs";
import "./auth-middleware-DJP7Badx.mjs";
import "./createMiddleware-BvN2ghIY.mjs";
import "./client.server-BMj2q4-x.mjs";
import "./calc-BF6zAv6d.mjs";
import "./docTypes-CsATll0j.mjs";
import "../_libs/zod.mjs";
import "./verifySign.server-CnraXCan.mjs";
import "node:async_hooks";
import "../_libs/h3-v2.mjs";
import "../_libs/rou3.mjs";
import "../_libs/srvx.mjs";
import "../_libs/dijkstrajs.mjs";
import "fs";
import "../_libs/pngjs.mjs";
import "zlib";
import "assert";
import "buffer";
import "../_libs/radix-ui__react-select.mjs";
import "../_libs/radix-ui__number.mjs";
import "../_libs/radix-ui__react-collection.mjs";
import "../_libs/radix-ui__react-direction.mjs";
import "../_libs/radix-ui__react-popper.mjs";
import "../_libs/floating-ui__react-dom.mjs";
import "../_libs/floating-ui__dom.mjs";
import "../_libs/floating-ui__core.mjs";
import "../_libs/floating-ui__utils.mjs";
import "../_libs/radix-ui__react-arrow.mjs";
import "../_libs/radix-ui__react-use-size.mjs";
import "../_libs/radix-ui__react-use-previous.mjs";
import "../_libs/@radix-ui/react-visually-hidden+[...].mjs";
function Team() {
  const {
    data: activeOrg
  } = useActiveOrg();
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
    queryFn: () => listMembersFn({
      data: {
        org_id: orgId
      }
    }),
    enabled: !!orgId
  });
  const invites = useQuery({
    queryKey: ["invites", orgId],
    queryFn: () => listInvitationsFn({
      data: {
        org_id: orgId
      }
    }),
    enabled: !!orgId
  });
  const [email, setEmail] = reactExports.useState("");
  const [role, setRole] = reactExports.useState("member");
  const [emailCheck, setEmailCheck] = reactExports.useState(null);
  const canAdmin = activeOrg?.role === "owner" || activeOrg?.role === "admin";
  const send = useMutation({
    mutationFn: async () => {
      if (!orgId) throw new Error("No org");
      return inviteFn({
        data: {
          org_id: orgId,
          email: email.trim(),
          role
        }
      });
    },
    onSuccess: () => {
      toast.success("Invitation email sent");
      setEmail("");
      qc.invalidateQueries({
        queryKey: ["invites", orgId]
      });
    },
    onError: (e) => toast.error(e instanceof Error ? e.message : "Failed")
  });
  const verifyEmail = useMutation({
    mutationFn: async () => {
      if (!orgId) throw new Error("No org");
      return verifyEmailFn({
        data: {
          org_id: orgId
        }
      });
    },
    onSuccess: (result) => {
      setEmailCheck(result);
      if (result.ok) {
        toast.success("Invitation email configuration verified");
      } else {
        toast.error("Invitation email configuration needs attention");
      }
    },
    onError: (e) => toast.error(e instanceof Error ? e.message : "Failed")
  });
  if (!activeOrg) return null;
  return /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "space-y-10 max-w-3xl", children: [
    canAdmin && /* @__PURE__ */ jsxRuntimeExports.jsxs("section", { className: "space-y-3", children: [
      /* @__PURE__ */ jsxRuntimeExports.jsx("h2", { className: "text-sm font-medium", children: "Invite teammate" }),
      /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "flex flex-col gap-2 sm:flex-row", children: [
        /* @__PURE__ */ jsxRuntimeExports.jsx(Input, { type: "email", placeholder: "email@company.com", value: email, onChange: (e) => setEmail(e.target.value), className: "flex-1" }),
        /* @__PURE__ */ jsxRuntimeExports.jsxs(Select, { value: role, onValueChange: (v) => setRole(v), children: [
          /* @__PURE__ */ jsxRuntimeExports.jsx(SelectTrigger, { className: "sm:w-32", children: /* @__PURE__ */ jsxRuntimeExports.jsx(SelectValue, {}) }),
          /* @__PURE__ */ jsxRuntimeExports.jsxs(SelectContent, { children: [
            /* @__PURE__ */ jsxRuntimeExports.jsx(SelectItem, { value: "member", children: "Member" }),
            /* @__PURE__ */ jsxRuntimeExports.jsx(SelectItem, { value: "admin", children: "Admin" }),
            activeOrg.role === "owner" && /* @__PURE__ */ jsxRuntimeExports.jsx(SelectItem, { value: "owner", children: "Owner" })
          ] })
        ] }),
        /* @__PURE__ */ jsxRuntimeExports.jsx(Button, { onClick: () => send.mutate(), disabled: send.isPending || !email.trim(), className: "rounded-full", children: send.isPending ? "Sending…" : "Invite" })
      ] }),
      /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "space-y-2", children: [
        /* @__PURE__ */ jsxRuntimeExports.jsx("p", { className: "text-[11px] text-muted-foreground", children: "We'll email the invitation and keep a pending link below so admins can copy it if needed." }),
        /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "rounded-xl border border-hairline bg-secondary/30 p-3 text-xs", children: [
          /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between", children: [
            /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { children: [
              /* @__PURE__ */ jsxRuntimeExports.jsx("p", { className: "font-medium", children: "Resend invitation email configuration" }),
              /* @__PURE__ */ jsxRuntimeExports.jsx("p", { className: "text-muted-foreground", children: "Verify APP_ORIGIN, sender address, API access, and sender domain readiness before sending invites." })
            ] }),
            /* @__PURE__ */ jsxRuntimeExports.jsx(Button, { type: "button", variant: "outline", size: "sm", onClick: () => verifyEmail.mutate(), disabled: verifyEmail.isPending, className: "rounded-full", children: verifyEmail.isPending ? "Checking…" : "Verify email" })
          ] }),
          emailCheck && /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "mt-3 flex gap-2", children: [
            emailCheck.ok ? /* @__PURE__ */ jsxRuntimeExports.jsx(CircleCheck, { className: "mt-0.5 h-4 w-4 text-green-600" }) : /* @__PURE__ */ jsxRuntimeExports.jsx(CircleX, { className: "mt-0.5 h-4 w-4 text-destructive" }),
            /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "space-y-1", children: [
              /* @__PURE__ */ jsxRuntimeExports.jsx("p", { className: "font-medium", children: emailCheck.ok ? "Ready to send invitations" : "Configuration check failed" }),
              /* @__PURE__ */ jsxRuntimeExports.jsxs("ul", { className: "list-disc space-y-0.5 pl-4 text-muted-foreground", children: [
                emailCheck.messages.map((message) => /* @__PURE__ */ jsxRuntimeExports.jsx("li", { children: message }, message)),
                emailCheck.fromDomain && /* @__PURE__ */ jsxRuntimeExports.jsxs("li", { children: [
                  "Sender domain: ",
                  emailCheck.fromDomain
                ] })
              ] })
            ] })
          ] })
        ] })
      ] })
    ] }),
    /* @__PURE__ */ jsxRuntimeExports.jsxs("section", { className: "space-y-3", children: [
      /* @__PURE__ */ jsxRuntimeExports.jsxs("h2", { className: "text-sm font-medium", children: [
        "Members (",
        members.data?.length ?? 0,
        ")"
      ] }),
      /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "overflow-hidden rounded-xl border border-hairline", children: /* @__PURE__ */ jsxRuntimeExports.jsxs("table", { className: "w-full text-sm", children: [
        /* @__PURE__ */ jsxRuntimeExports.jsx("thead", { className: "border-b border-hairline bg-secondary/50", children: /* @__PURE__ */ jsxRuntimeExports.jsxs("tr", { className: "text-[11px] uppercase tracking-wider text-muted-foreground", children: [
          /* @__PURE__ */ jsxRuntimeExports.jsx("th", { className: "px-4 py-2.5 text-left font-medium", children: "Email" }),
          /* @__PURE__ */ jsxRuntimeExports.jsx("th", { className: "px-4 py-2.5 text-left font-medium", children: "Role" }),
          /* @__PURE__ */ jsxRuntimeExports.jsx("th", { className: "w-16" })
        ] }) }),
        /* @__PURE__ */ jsxRuntimeExports.jsx("tbody", { children: (members.data ?? []).map((m) => /* @__PURE__ */ jsxRuntimeExports.jsxs("tr", { className: "border-b border-hairline last:border-0", children: [
          /* @__PURE__ */ jsxRuntimeExports.jsx("td", { className: "px-4 py-2.5", children: m.email ?? "—" }),
          /* @__PURE__ */ jsxRuntimeExports.jsx("td", { className: "px-4 py-2.5", children: canAdmin ? /* @__PURE__ */ jsxRuntimeExports.jsxs(Select, { value: m.role, onValueChange: async (v) => {
            try {
              await changeFn({
                data: {
                  id: m.id,
                  org_id: orgId,
                  role: v
                }
              });
              qc.invalidateQueries({
                queryKey: ["members", orgId]
              });
            } catch (e) {
              toast.error(e instanceof Error ? e.message : "Failed");
            }
          }, children: [
            /* @__PURE__ */ jsxRuntimeExports.jsx(SelectTrigger, { className: "h-7 w-28 text-xs", children: /* @__PURE__ */ jsxRuntimeExports.jsx(SelectValue, {}) }),
            /* @__PURE__ */ jsxRuntimeExports.jsxs(SelectContent, { children: [
              /* @__PURE__ */ jsxRuntimeExports.jsx(SelectItem, { value: "member", children: "Member" }),
              /* @__PURE__ */ jsxRuntimeExports.jsx(SelectItem, { value: "admin", children: "Admin" }),
              activeOrg.role === "owner" && /* @__PURE__ */ jsxRuntimeExports.jsx(SelectItem, { value: "owner", children: "Owner" })
            ] })
          ] }) : /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: "text-xs uppercase tracking-wider text-muted-foreground", children: m.role }) }),
          /* @__PURE__ */ jsxRuntimeExports.jsx("td", { className: "px-3 py-2.5 text-right", children: canAdmin && /* @__PURE__ */ jsxRuntimeExports.jsx(Button, { variant: "ghost", size: "sm", onClick: async () => {
            if (!confirm("Remove this member?")) return;
            try {
              await removeFn({
                data: {
                  id: m.id,
                  org_id: orgId
                }
              });
              qc.invalidateQueries({
                queryKey: ["members", orgId]
              });
            } catch (e) {
              toast.error(e instanceof Error ? e.message : "Failed");
            }
          }, children: /* @__PURE__ */ jsxRuntimeExports.jsx(Trash2, { className: "h-3.5 w-3.5 text-muted-foreground hover:text-destructive" }) }) })
        ] }, m.id)) })
      ] }) })
    ] }),
    canAdmin && (invites.data?.length ?? 0) > 0 && /* @__PURE__ */ jsxRuntimeExports.jsxs("section", { className: "space-y-3", children: [
      /* @__PURE__ */ jsxRuntimeExports.jsx("h2", { className: "text-sm font-medium", children: "Pending invitations" }),
      /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "overflow-hidden rounded-xl border border-hairline", children: /* @__PURE__ */ jsxRuntimeExports.jsxs("table", { className: "w-full text-sm", children: [
        /* @__PURE__ */ jsxRuntimeExports.jsx("thead", { className: "border-b border-hairline bg-secondary/50", children: /* @__PURE__ */ jsxRuntimeExports.jsxs("tr", { className: "text-[11px] uppercase tracking-wider text-muted-foreground", children: [
          /* @__PURE__ */ jsxRuntimeExports.jsx("th", { className: "px-4 py-2.5 text-left font-medium", children: "Email" }),
          /* @__PURE__ */ jsxRuntimeExports.jsx("th", { className: "px-4 py-2.5 text-left font-medium", children: "Role" }),
          /* @__PURE__ */ jsxRuntimeExports.jsx("th", { className: "px-4 py-2.5 text-left font-medium", children: "Expires" }),
          /* @__PURE__ */ jsxRuntimeExports.jsx("th", { className: "w-32" })
        ] }) }),
        /* @__PURE__ */ jsxRuntimeExports.jsx("tbody", { children: (invites.data ?? []).map((i) => {
          const link = `${window.location.origin}/invite/${encodeURIComponent(i.token)}`;
          return /* @__PURE__ */ jsxRuntimeExports.jsxs("tr", { className: "border-b border-hairline last:border-0", children: [
            /* @__PURE__ */ jsxRuntimeExports.jsx("td", { className: "px-4 py-2.5", children: i.email }),
            /* @__PURE__ */ jsxRuntimeExports.jsx("td", { className: "px-4 py-2.5 text-xs uppercase tracking-wider text-muted-foreground", children: i.role }),
            /* @__PURE__ */ jsxRuntimeExports.jsx("td", { className: "px-4 py-2.5 text-xs text-muted-foreground", children: new Date(i.expires_at).toLocaleDateString() }),
            /* @__PURE__ */ jsxRuntimeExports.jsx("td", { className: "px-3 py-2.5", children: /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "flex justify-end gap-1", children: [
              /* @__PURE__ */ jsxRuntimeExports.jsx(Button, { variant: "ghost", size: "sm", onClick: async () => {
                await navigator.clipboard.writeText(link);
                toast.success("Pending invitation link copied");
              }, children: /* @__PURE__ */ jsxRuntimeExports.jsx(Copy, { className: "h-3.5 w-3.5" }) }),
              /* @__PURE__ */ jsxRuntimeExports.jsx(Button, { variant: "ghost", size: "sm", onClick: async () => {
                try {
                  await revokeFn({
                    data: {
                      id: i.id,
                      org_id: orgId
                    }
                  });
                  qc.invalidateQueries({
                    queryKey: ["invites", orgId]
                  });
                } catch (e) {
                  toast.error(e instanceof Error ? e.message : "Failed");
                }
              }, children: /* @__PURE__ */ jsxRuntimeExports.jsx(Trash2, { className: "h-3.5 w-3.5 text-muted-foreground hover:text-destructive" }) })
            ] }) })
          ] }, i.id);
        }) })
      ] }) })
    ] })
  ] });
}
export {
  Team as component
};
