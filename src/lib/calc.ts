import { formatCurrency } from "./currencies";

export type LineItem = {
  description: string;
  quantity: number;
  unit_price: number;
};

export function round2(n: number): number {
  return Math.round((n + Number.EPSILON) * 100) / 100;
}

export function rowTotal(item: LineItem): number {
  return round2((Number(item.quantity) || 0) * (Number(item.unit_price) || 0));
}

export function computeTotals(items: LineItem[], taxRate: number, discount: number) {
  const subtotal = round2(items.reduce((s, i) => s + rowTotal(i), 0));
  const tax_amount = round2(subtotal * ((Number(taxRate) || 0) / 100));
  const total = round2(subtotal + tax_amount - (Number(discount) || 0));
  return { subtotal, tax_amount, total };
}

/** Formats a monetary value. Handles standard ISO codes and newer ones like ZWG. */
export function formatMoney(n: number, currency = "USD"): string {
  return formatCurrency(n, currency);
}

export function formatDate(d: string | Date): string {
  const date = typeof d === "string" ? new Date(d) : d;
  return date.toLocaleDateString("en-US", { year: "numeric", month: "long", day: "numeric" });
}
