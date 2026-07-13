function round2(n) {
  return Math.round((n + Number.EPSILON) * 100) / 100;
}
function rowTotal(item) {
  return round2((Number(item.quantity) || 0) * (Number(item.unit_price) || 0));
}
function computeTotals(items, taxRate, discount) {
  const subtotal = round2(items.reduce((s, i) => s + rowTotal(i), 0));
  const tax_amount = round2(subtotal * ((Number(taxRate) || 0) / 100));
  const total = round2(subtotal + tax_amount - (Number(discount) || 0));
  return { subtotal, tax_amount, total };
}
function formatMoney(n, currency = "USD") {
  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency,
    minimumFractionDigits: 2
  }).format(Number(n) || 0);
}
function formatDate(d) {
  const date = typeof d === "string" ? new Date(d) : d;
  return date.toLocaleDateString("en-US", { year: "numeric", month: "long", day: "numeric" });
}
export {
  formatDate as a,
  computeTotals as c,
  formatMoney as f,
  rowTotal as r
};
