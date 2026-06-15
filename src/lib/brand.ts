/**
 * Organization brand. Loaded per-active-org from `organization_profiles`.
 * Used by the PDF renderer, verification page, and document defaults.
 */
export type Brand = {
  name: string;
  short_name: string | null;
  logo_data_url: string | null;
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

/** Safe defaults when the current org has no profile filled in. */
export const BRAND_FALLBACK: Brand = {
  name: "Your Company",
  short_name: null,
  logo_data_url: null,
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

/** Fetch a remote image URL and return a data: URL suitable for pdfmake. */
export async function urlToDataUrl(url: string): Promise<string | null> {
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
