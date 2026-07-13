/** Supported currencies for document formatting. */
export type CurrencyCode = string;

export const CURRENCIES: { code: string; label: string; symbol?: string }[] = [
  // Regional / local currencies prominently listed first
  { code: "ZWG", label: "Zimbabwe Gold (ZWG)" },
  { code: "ZWL", label: "Zimbabwe Dollar (ZWL)" },

  // Major world currencies
  { code: "USD", label: "US Dollar (USD)", symbol: "$" },
  { code: "EUR", label: "Euro (EUR)", symbol: "€" },
  { code: "GBP", label: "British Pound (GBP)", symbol: "£" },
  { code: "JPY", label: "Japanese Yen (JPY)", symbol: "¥" },
  { code: "CNY", label: "Chinese Yuan (CNY)", symbol: "¥" },
  { code: "CHF", label: "Swiss Franc (CHF)" },
  { code: "CAD", label: "Canadian Dollar (CAD)" },
  { code: "AUD", label: "Australian Dollar (AUD)" },
  { code: "NZD", label: "New Zealand Dollar (NZD)" },
  { code: "SEK", label: "Swedish Krona (SEK)" },
  { code: "NOK", label: "Norwegian Krone (NOK)" },
  { code: "DKK", label: "Danish Krone (DKK)" },
  { code: "SGD", label: "Singapore Dollar (SGD)" },
  { code: "HKD", label: "Hong Kong Dollar (HKD)" },
  { code: "KRW", label: "South Korean Won (KRW)" },
  { code: "INR", label: "Indian Rupee (INR)", symbol: "₹" },
  { code: "BRL", label: "Brazilian Real (BRL)" },
  { code: "MXN", label: "Mexican Peso (MXN)" },
  { code: "RUB", label: "Russian Ruble (RUB)" },
  { code: "TRY", label: "Turkish Lira (TRY)" },
  { code: "SAR", label: "Saudi Riyal (SAR)" },
  { code: "AED", label: "UAE Dirham (AED)" },
  { code: "QAR", label: "Qatari Riyal (QAR)" },
  { code: "KWD", label: "Kuwaiti Dinar (KWD)" },
  { code: "BHD", label: "Bahraini Dinar (BHD)" },
  { code: "OMR", label: "Omani Rial (OMR)" },
  { code: "EGP", label: "Egyptian Pound (EGP)" },
  { code: "NGN", label: "Nigerian Naira (NGN)", symbol: "₦" },
  { code: "GHS", label: "Ghanaian Cedi (GHS)" },
  { code: "KES", label: "Kenyan Shilling (KES)" },
  { code: "UGX", label: "Ugandan Shilling (UGX)" },
  { code: "TZS", label: "Tanzanian Shilling (TZS)" },
  { code: "ZAR", label: "South African Rand (ZAR)" },
  { code: "BWP", label: "Botswana Pula (BWP)" },
  { code: "MWK", label: "Malawian Kwacha (MWK)" },
  { code: "ZMW", label: "Zambian Kwacha (ZMW)" },
  { code: "MZN", label: "Mozambican Metical (MZN)" },
  { code: "AOA", label: "Angolan Kwanza (AOA)" },
  { code: "ETB", label: "Ethiopian Birr (ETB)" },
  { code: "XOF", label: "West African CFA Franc (XOF)" },
  { code: "XAF", label: "Central African CFA Franc (XAF)" },
  { code: "PLN", label: "Polish Zloty (PLN)" },
  { code: "CZK", label: "Czech Koruna (CZK)" },
  { code: "HUF", label: "Hungarian Forint (HUF)" },
  { code: "RON", label: "Romanian Leu (RON)" },
  { code: "IDR", label: "Indonesian Rupiah (IDR)" },
  { code: "MYR", label: "Malaysian Ringgit (MYR)" },
  { code: "THB", label: "Thai Baht (THB)" },
  { code: "VND", label: "Vietnamese Dong (VND)" },
  { code: "PHP", label: "Philippine Peso (PHP)" },
  { code: "PKR", label: "Pakistani Rupee (PKR)" },
  { code: "BDT", label: "Bangladeshi Taka (BDT)" },
  { code: "LKR", label: "Sri Lankan Rupee (LKR)" },
  { code: "ARS", label: "Argentine Peso (ARS)" },
  { code: "CLP", label: "Chilean Peso (CLP)" },
  { code: "COP", label: "Colombian Peso (COP)" },
  { code: "PEN", label: "Peruvian Sol (PEN)" },
  { code: "ILS", label: "Israeli Shekel (ILS)", symbol: "₪" },
  { code: "CZK", label: "Czech Koruna (CZK)" },
  { code: "UAH", label: "Ukrainian Hryvnia (UAH)" },
];

/**
 * Returns a label for a currency code. Falls back to the code itself
 * if the currency isn't in the list (e.g. custom codes).
 */
export function getCurrencyLabel(code: string): string {
  return CURRENCIES.find((c) => c.code === code)?.label ?? code;
}

/**
 * Formats a number as currency. Falls back to a plain number with the
 * currency code prefixed when Intl cannot handle the currency (e.g. ZWG).
 */
export function formatCurrency(n: number, currency = "USD"): string {
  try {
    return new Intl.NumberFormat("en-US", {
      style: "currency",
      currency,
      minimumFractionDigits: 2,
    }).format(Number(n) || 0);
  } catch {
    // Intl doesn't know about newer/custom ISO codes like ZWG — fall back gracefully
    return `${currency} ${new Intl.NumberFormat("en-US", {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
    }).format(Number(n) || 0)}`;
  }
}
