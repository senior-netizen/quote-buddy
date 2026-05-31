import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useServerFn } from "@tanstack/react-start";
import { useCallback } from "react";
import {
  getActiveOrg,
  getMyOrganizations,
  setActiveOrg as setActiveOrgFn,
  type ActiveOrg,
  type OrgListItem,
  type OrgProfile,
} from "./org.functions";
import type { Brand } from "./brand";
import { BRAND_FALLBACK } from "./brand";

export type { ActiveOrg, OrgListItem, OrgProfile };

const ACTIVE_ORG_KEY = ["active-org"] as const;
const MY_ORGS_KEY = ["my-orgs"] as const;

/** React hook: returns the user's active organization (with brand profile). */
export function useActiveOrg() {
  const getActive = useServerFn(getActiveOrg);
  return useQuery({
    queryKey: ACTIVE_ORG_KEY,
    queryFn: () => getActive(),
    staleTime: 60_000,
  });
}

export function useMyOrganizations() {
  const list = useServerFn(getMyOrganizations);
  return useQuery({
    queryKey: MY_ORGS_KEY,
    queryFn: () => list(),
    staleTime: 60_000,
  });
}

export function useSwitchActiveOrg() {
  const setFn = useServerFn(setActiveOrgFn);
  const qc = useQueryClient();
  return useCallback(
    async (org_id: string) => {
      await setFn({ data: { org_id } });
      await qc.invalidateQueries({ queryKey: ACTIVE_ORG_KEY });
      await qc.invalidateQueries({ queryKey: MY_ORGS_KEY });
      await qc.invalidateQueries(); // refresh all org-scoped data
    },
    [setFn, qc],
  );
}

/** Fetch a remote image URL and return a data: URL suitable for pdfmake. */
async function urlToDataUrl(url: string): Promise<string | null> {
  try {
    const res = await fetch(url, { cache: "force-cache" });
    if (!res.ok) return null;
    const blob = await res.blob();
    return await new Promise<string>((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = () => resolve(reader.result as string);
      reader.onerror = () => reject(reader.error);
      reader.readAsDataURL(blob);
    });
  } catch {
    return null;
  }
}

/** Convert an OrgProfile into a Brand object suitable for the PDF renderer. */
export async function profileToBrand(profile: OrgProfile): Promise<Brand> {
  const logo_data_url = profile.logo_url ? await urlToDataUrl(profile.logo_url) : null;
  return {
    name: profile.name,
    short_name: profile.short_name,
    logo_data_url,
    emails: profile.emails ?? [],
    website: profile.website,
    registration: profile.registration,
    tin: profile.tin,
    duns: profile.duns,
    currency: profile.currency,
    default_tax_rate: Number(profile.default_tax_rate),
    address: profile.address,
    phone: profile.phone,
    payment_instructions: profile.payment_instructions,
  };
}

export { BRAND_FALLBACK };
