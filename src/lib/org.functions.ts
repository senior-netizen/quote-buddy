import { randomBytes } from "node:crypto";
import { createServerFn } from "@tanstack/react-start";
import { z } from "zod";
import { requireSupabaseAuth } from "@/integrations/supabase/auth-middleware";
import { supabaseAdmin } from "@/integrations/supabase/client.server";

// ============================================================
// Types
// ============================================================

export type OrgProfile = {
  org_id: string;
  name: string;
  short_name: string | null;
  logo_url: string | null;
  emails: string[];
  website: string | null;
  registration: string | null;
  tin: string | null;
  duns: string | null;
  praz: string | null;
  currency: string;
  default_tax_rate: number;
  address: string | null;
  phone: string | null;
  payment_instructions: string | null;
};

export type ActiveOrg = {
  org_id: string;
  org_name: string;
  role: "owner" | "admin" | "member";
  profile: OrgProfile;
};

export type OrgListItem = {
  id: string;
  name: string;
  role: "owner" | "admin" | "member";
};

export type MemberRow = {
  id: string;
  user_id: string;
  email: string | null;
  role: "owner" | "admin" | "member";
  created_at: string;
};

export type InvitationRow = {
  id: string;
  email: string;
  role: "owner" | "admin" | "member";
  token: string;
  expires_at: string;
  accepted_at: string | null;
  created_at: string;
};

// ============================================================
// Helpers (server-only)
// ============================================================

async function loadActiveOrg(userId: string): Promise<ActiveOrg | null> {
  // Ensure profile row exists
  await supabaseAdmin
    .from("profiles")
    .upsert({ user_id: userId }, { onConflict: "user_id" });

  const { data: profile } = await supabaseAdmin
    .from("profiles")
    .select("active_org_id")
    .eq("user_id", userId)
    .maybeSingle();

  let activeOrgId = profile?.active_org_id ?? null;

  // If no active org set, pick the first membership and persist
  if (!activeOrgId) {
    const { data: first } = await supabaseAdmin
      .from("organization_members")
      .select("org_id")
      .eq("user_id", userId)
      .order("created_at", { ascending: true })
      .limit(1)
      .maybeSingle();
    if (first) {
      activeOrgId = first.org_id;
      await supabaseAdmin
        .from("profiles")
        .update({ active_org_id: activeOrgId })
        .eq("user_id", userId);
    }
  }

  if (!activeOrgId) return null;

  // Verify user is still a member of this org (in case they were removed)
  const { data: member } = await supabaseAdmin
    .from("organization_members")
    .select("role")
    .eq("user_id", userId)
    .eq("org_id", activeOrgId)
    .maybeSingle();

  if (!member) {
    // User was removed from active org — clear and recurse
    await supabaseAdmin.from("profiles").update({ active_org_id: null }).eq("user_id", userId);
    return loadActiveOrg(userId);
  }

  const { data: org } = await supabaseAdmin
    .from("organizations")
    .select("id, name")
    .eq("id", activeOrgId)
    .maybeSingle();
  if (!org) return null;

  const { data: prof } = await supabaseAdmin
    .from("organization_profiles")
    .select("*")
    .eq("org_id", activeOrgId)
    .maybeSingle();

  const fallback: OrgProfile = {
    org_id: activeOrgId,
    name: org.name,
    short_name: null,
    logo_url: null,
    emails: [],
    website: null,
    registration: null,
    tin: null,
    duns: null,
    praz: null,
    currency: "USD",
    default_tax_rate: 15,
    address: null,
    phone: null,
    payment_instructions: null,
  };

  return {
    org_id: activeOrgId,
    org_name: org.name,
    role: member.role as ActiveOrg["role"],
    profile: prof ? { ...fallback, ...prof, emails: prof.emails ?? [] } : fallback,
  };
}

// ============================================================
// Server functions
// ============================================================

export const getActiveOrg = createServerFn({ method: "GET" })
  .middleware([requireSupabaseAuth])
  .handler(async ({ context }): Promise<ActiveOrg | null> => {
    return loadActiveOrg(context.userId);
  });

export const getMyOrganizations = createServerFn({ method: "GET" })
  .middleware([requireSupabaseAuth])
  .handler(async ({ context }): Promise<OrgListItem[]> => {
    const { data } = await supabaseAdmin
      .from("organization_members")
      .select("role, org:organizations(id, name)")
      .eq("user_id", context.userId)
      .order("created_at", { ascending: true });
    return (data ?? [])
      .map((r) => {
        const o = r.org as unknown as { id: string; name: string } | null;
        return o ? { id: o.id, name: o.name, role: r.role as OrgListItem["role"] } : null;
      })
      .filter((x): x is OrgListItem => x !== null);
  });

export const setActiveOrg = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((d: { org_id: string }) => z.object({ org_id: z.string().uuid() }).parse(d))
  .handler(async ({ data, context }) => {
    // Verify membership
    const { data: m } = await supabaseAdmin
      .from("organization_members")
      .select("id")
      .eq("user_id", context.userId)
      .eq("org_id", data.org_id)
      .maybeSingle();
    if (!m) throw new Error("Not a member of that organization");

    await supabaseAdmin
      .from("profiles")
      .upsert(
        { user_id: context.userId, active_org_id: data.org_id },
        { onConflict: "user_id" },
      );
    return { ok: true as const };
  });

export const createOrganization = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((d: { name: string }) =>
    z.object({ name: z.string().trim().min(1).max(200) }).parse(d),
  )
  .handler(async ({ data, context }) => {
    const { data: org, error } = await supabaseAdmin
      .from("organizations")
      .insert({ name: data.name, created_by: context.userId })
      .select("id")
      .single();
    if (error) throw new Error(error.message);

    // Trigger created owner membership + blank profile + sets active_org_id via on_member_added
    return { org_id: org.id };
  });

const ProfileUpdateSchema = z.object({
  name: z.string().trim().min(1).max(200),
  short_name: z.string().trim().max(80).optional().nullable(),
  logo_url: z.string().trim().url().max(2000).optional().nullable(),
  emails: z.array(z.string().trim().email().max(255)).max(10).default([]),
  website: z.string().trim().max(255).optional().nullable(),
  registration: z.string().trim().max(80).optional().nullable(),
  tin: z.string().trim().max(80).optional().nullable(),
  duns: z.string().trim().max(80).optional().nullable(),
  praz: z.string().trim().max(80).optional().nullable(),
  currency: z.string().trim().min(1).max(8),
  default_tax_rate: z.number().min(0).max(100),
  address: z.string().trim().max(500).optional().nullable(),
  phone: z.string().trim().max(40).optional().nullable(),
  payment_instructions: z.string().trim().max(1000).optional().nullable(),
});

export const updateOrganizationProfile = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((d: unknown) =>
    z.object({ org_id: z.string().uuid(), patch: ProfileUpdateSchema }).parse(d),
  )
  .handler(async ({ data, context }) => {
    // Verify role
    const { data: m } = await supabaseAdmin
      .from("organization_members")
      .select("role")
      .eq("user_id", context.userId)
      .eq("org_id", data.org_id)
      .maybeSingle();
    if (!m || (m.role !== "admin" && m.role !== "owner")) {
      throw new Error("Only admins or owners can update organization profile");
    }

    // Update both the org's display name and the profile
    await supabaseAdmin
      .from("organizations")
      .update({ name: data.patch.name })
      .eq("id", data.org_id);

    const { error } = await supabaseAdmin
      .from("organization_profiles")
      .update({
        name: data.patch.name,
        short_name: data.patch.short_name ?? null,
        logo_url: data.patch.logo_url ?? null,
        emails: data.patch.emails,
        website: data.patch.website ?? null,
        registration: data.patch.registration ?? null,
        tin: data.patch.tin ?? null,
        duns: data.patch.duns ?? null,
        praz: data.patch.praz ?? null,
        currency: data.patch.currency,
        default_tax_rate: data.patch.default_tax_rate,
        address: data.patch.address ?? null,
        phone: data.patch.phone ?? null,
        payment_instructions: data.patch.payment_instructions ?? null,
      })
      .eq("org_id", data.org_id);
    if (error) throw new Error(error.message);
    return { ok: true as const };
  });

// ----- Members -----

export const listMembers = createServerFn({ method: "GET" })
  .middleware([requireSupabaseAuth])
  .inputValidator((d: { org_id: string }) => z.object({ org_id: z.string().uuid() }).parse(d))
  .handler(async ({ data, context }): Promise<MemberRow[]> => {
    const { data: m } = await supabaseAdmin
      .from("organization_members")
      .select("id")
      .eq("user_id", context.userId)
      .eq("org_id", data.org_id)
      .maybeSingle();
    if (!m) throw new Error("Not a member");

    const { data: rows } = await supabaseAdmin
      .from("organization_members")
      .select("id, user_id, role, created_at")
      .eq("org_id", data.org_id)
      .order("created_at", { ascending: true });

    if (!rows) return [];

    // Resolve emails via auth.admin
    const out: MemberRow[] = [];
    for (const r of rows) {
      let email: string | null = null;
      try {
        const { data: u } = await supabaseAdmin.auth.admin.getUserById(r.user_id);
        email = u?.user?.email ?? null;
      } catch {
        email = null;
      }
      out.push({
        id: r.id,
        user_id: r.user_id,
        email,
        role: r.role as MemberRow["role"],
        created_at: r.created_at,
      });
    }
    return out;
  });

function randomToken(): string {
  return randomBytes(32).toString("hex");
}

export const inviteMember = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((d: unknown) =>
    z
      .object({
        org_id: z.string().uuid(),
        email: z.string().trim().email().max(255),
        role: z.enum(["owner", "admin", "member"]),
      })
      .parse(d),
  )
  .handler(async ({ data, context }) => {
    const { data: m } = await supabaseAdmin
      .from("organization_members")
      .select("role")
      .eq("user_id", context.userId)
      .eq("org_id", data.org_id)
      .maybeSingle();
    if (!m || (m.role !== "admin" && m.role !== "owner")) {
      throw new Error("Only admins or owners can invite");
    }
    if (data.role === "owner" && m.role !== "owner") {
      throw new Error("Only owners can invite other owners");
    }

    const token = randomToken();
    const { data: inv, error } = await supabaseAdmin
      .from("organization_invitations")
      .insert({
        org_id: data.org_id,
        email: data.email.toLowerCase(),
        role: data.role,
        token,
        invited_by: context.userId,
      })
      .select("id, token, expires_at")
      .single();
    if (error) throw new Error(error.message);
    return { id: inv.id, token: inv.token, expires_at: inv.expires_at };
  });

export const listInvitations = createServerFn({ method: "GET" })
  .middleware([requireSupabaseAuth])
  .inputValidator((d: { org_id: string }) => z.object({ org_id: z.string().uuid() }).parse(d))
  .handler(async ({ data, context }): Promise<InvitationRow[]> => {
    const { data: m } = await supabaseAdmin
      .from("organization_members")
      .select("role")
      .eq("user_id", context.userId)
      .eq("org_id", data.org_id)
      .maybeSingle();
    if (!m || (m.role !== "admin" && m.role !== "owner")) {
      throw new Error("Only admins or owners can view invitations");
    }

    const { data: rows } = await supabaseAdmin
      .from("organization_invitations")
      .select("id, email, role, token, expires_at, accepted_at, created_at")
      .eq("org_id", data.org_id)
      .is("accepted_at", null)
      .order("created_at", { ascending: false });
    return (rows ?? []) as InvitationRow[];
  });

export const revokeInvitation = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((d: { id: string; org_id: string }) =>
    z.object({ id: z.string().uuid(), org_id: z.string().uuid() }).parse(d),
  )
  .handler(async ({ data, context }) => {
    const { data: m } = await supabaseAdmin
      .from("organization_members")
      .select("role")
      .eq("user_id", context.userId)
      .eq("org_id", data.org_id)
      .maybeSingle();
    if (!m || (m.role !== "admin" && m.role !== "owner")) {
      throw new Error("Only admins or owners can revoke invitations");
    }
    await supabaseAdmin
      .from("organization_invitations")
      .delete()
      .eq("id", data.id)
      .eq("org_id", data.org_id);
    return { ok: true as const };
  });

export const removeMember = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((d: { id: string; org_id: string }) =>
    z.object({ id: z.string().uuid(), org_id: z.string().uuid() }).parse(d),
  )
  .handler(async ({ data, context }) => {
    const { data: caller } = await supabaseAdmin
      .from("organization_members")
      .select("role, user_id")
      .eq("user_id", context.userId)
      .eq("org_id", data.org_id)
      .maybeSingle();
    if (!caller) throw new Error("Not a member");

    const { data: target } = await supabaseAdmin
      .from("organization_members")
      .select("user_id, role")
      .eq("id", data.id)
      .maybeSingle();
    if (!target) throw new Error("Member not found");

    const isSelf = target.user_id === context.userId;
    const isAdmin = caller.role === "owner" || caller.role === "admin";
    if (!isSelf && !isAdmin) throw new Error("Not allowed");
    if (target.role === "owner" && caller.role !== "owner") {
      throw new Error("Only owners can remove owners");
    }

    // Prevent removing the last owner
    if (target.role === "owner") {
      const { count } = await supabaseAdmin
        .from("organization_members")
        .select("id", { count: "exact", head: true })
        .eq("org_id", data.org_id)
        .eq("role", "owner");
      if ((count ?? 0) <= 1) throw new Error("Cannot remove the last owner");
    }

    await supabaseAdmin.from("organization_members").delete().eq("id", data.id);
    return { ok: true as const };
  });

export const changeMemberRole = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((d: unknown) =>
    z
      .object({
        id: z.string().uuid(),
        org_id: z.string().uuid(),
        role: z.enum(["owner", "admin", "member"]),
      })
      .parse(d),
  )
  .handler(async ({ data, context }) => {
    const { data: caller } = await supabaseAdmin
      .from("organization_members")
      .select("role")
      .eq("user_id", context.userId)
      .eq("org_id", data.org_id)
      .maybeSingle();
    if (!caller || (caller.role !== "owner" && caller.role !== "admin")) {
      throw new Error("Only admins or owners can change roles");
    }
    if (data.role === "owner" && caller.role !== "owner") {
      throw new Error("Only owners can promote to owner");
    }

    const { data: target } = await supabaseAdmin
      .from("organization_members")
      .select("user_id, role")
      .eq("id", data.id)
      .maybeSingle();
    if (!target) throw new Error("Member not found");

    // Prevent demoting the last owner
    if (target.role === "owner" && data.role !== "owner") {
      const { count } = await supabaseAdmin
        .from("organization_members")
        .select("id", { count: "exact", head: true })
        .eq("org_id", data.org_id)
        .eq("role", "owner");
      if ((count ?? 0) <= 1) throw new Error("Cannot demote the last owner");
    }

    await supabaseAdmin.from("organization_members").update({ role: data.role }).eq("id", data.id);
    return { ok: true as const };
  });

// ----- Invitation lookup + accept (public + authed) -----

export type InvitationLookup =
  | { status: "ok"; org_id: string; org_name: string; email: string; role: "owner" | "admin" | "member"; expires_at: string }
  | { status: "expired" }
  | { status: "accepted" }
  | { status: "not_found" };

export const getInvitation = createServerFn({ method: "POST" })
  .inputValidator((d: { token: string }) =>
    z.object({ token: z.string().trim().min(1).max(128) }).parse(d),
  )
  .handler(async ({ data }): Promise<InvitationLookup> => {
    const { data: inv } = await supabaseAdmin
      .from("organization_invitations")
      .select("org_id, email, role, expires_at, accepted_at, org:organizations(name)")
      .eq("token", data.token)
      .maybeSingle();
    if (!inv) return { status: "not_found" };
    if (inv.accepted_at) return { status: "accepted" };
    if (new Date(inv.expires_at).getTime() < Date.now()) return { status: "expired" };
    const orgName = (inv.org as unknown as { name: string } | null)?.name ?? "Organization";
    return {
      status: "ok",
      org_id: inv.org_id,
      org_name: orgName,
      email: inv.email,
      role: inv.role as "owner" | "admin" | "member",
      expires_at: inv.expires_at,
    };
  });

export const acceptInvitation = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((d: { token: string }) =>
    z.object({ token: z.string().trim().min(1).max(128) }).parse(d),
  )
  .handler(async ({ data, context }) => {
    const { data: inv } = await supabaseAdmin
      .from("organization_invitations")
      .select("id, org_id, email, role, expires_at, accepted_at")
      .eq("token", data.token)
      .maybeSingle();
    if (!inv) throw new Error("Invitation not found");
    if (inv.accepted_at) throw new Error("Invitation already used");
    if (new Date(inv.expires_at).getTime() < Date.now()) throw new Error("Invitation expired");

    // Verify the email matches the signed-in user
    const userEmail = (context.claims.email as string | undefined)?.toLowerCase();
    if (userEmail && userEmail !== inv.email.toLowerCase()) {
      throw new Error(`This invitation is for ${inv.email}. Sign in with that email to accept.`);
    }

    // Add membership (ignore unique-violation if already member)
    const { error: insErr } = await supabaseAdmin
      .from("organization_members")
      .insert({ org_id: inv.org_id, user_id: context.userId, role: inv.role });
    if (insErr && !insErr.message.includes("duplicate")) {
      // best-effort; continue regardless
    }

    // Mark invitation accepted
    await supabaseAdmin
      .from("organization_invitations")
      .update({ accepted_at: new Date().toISOString() })
      .eq("id", inv.id);

    // Switch active org to this one
    await supabaseAdmin
      .from("profiles")
      .upsert(
        { user_id: context.userId, active_org_id: inv.org_id },
        { onConflict: "user_id" },
      );

    return { org_id: inv.org_id };
  });

// ----- Brand resolution for PDF / verify -----

/** Public-readable brand info for a given document id (used by /verify page). */
export const getDocumentIssuerBrand = createServerFn({ method: "POST" })
  .inputValidator((d: { id: string }) =>
    z.object({ id: z.string().trim().min(1).max(64) }).parse(d),
  )
  .handler(async ({ data }) => {
    const { data: doc } = await supabaseAdmin
      .from("documents")
      .select("org_id")
      .eq("id", data.id)
      .maybeSingle();
    if (!doc) return null;
    const { data: prof } = await supabaseAdmin
      .from("organization_profiles")
      .select("name, short_name, website, logo_url")
      .eq("org_id", doc.org_id)
      .maybeSingle();
    return prof
      ? {
          name: prof.name,
          short_name: prof.short_name,
          website: prof.website,
          logo_url: prof.logo_url,
        }
      : null;
  });
