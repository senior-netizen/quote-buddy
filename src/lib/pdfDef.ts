import type { TDocumentDefinitions } from "pdfmake/interfaces";
import QRCode from "qrcode";
import type { Brand } from "./brand";
import { formatDate, formatMoney, rowTotal, type LineItem } from "./calc";

export type DocForPdf = {
  doc_type: "quote" | "invoice";
  doc_number: string;
  issue_date: string;
  due_date: string | null;
  line_items: LineItem[];
  tax_rate: number;
  discount: number;
  subtotal: number;
  tax_amount: number;
  total: number;
  notes?: string | null;
  client: {
    company_name: string;
    address?: string | null;
    email?: string | null;
    phone?: string | null;
  };
  /** Organization brand to render in header / footer. */
  brand: Brand;
  /** Optional verification URL — when provided, a QR code is embedded. */
  verifyUrl?: string;
  /** SHA-256 content hash (hex). Shown in the verification block. */
  docHash?: string;
  /** HMAC signature ID (base64url). Shown in the verification block. */
  signatureId?: string;
};

const INK = "#0a0a0a";
const MUTED = "#6b7280";
const HAIR = "#e5e7eb";

/** Builds the structured storage path for a given document. */
export function buildDocPath(d: Pick<DocForPdf, "doc_type" | "doc_number" | "issue_date">): string {
  const year = (d.issue_date || new Date().toISOString()).slice(0, 4);
  const type = d.doc_type === "invoice" ? "invoices" : "quotes";
  const safeNumber = d.doc_number.replace(/[^A-Za-z0-9._-]/g, "_");
  return `documents/${year}/${type}/${safeNumber}.pdf`;
}

export async function buildDef(d: DocForPdf): Promise<TDocumentDefinitions> {
  const isInvoice = d.doc_type === "invoice";
  const title = isInvoice ? "Invoice" : "Quotation";
  const brand = d.brand;

  const qrDataUrl = d.verifyUrl
    ? await QRCode.toDataURL(d.verifyUrl, { margin: 0, width: 220, errorCorrectionLevel: "M" })
    : null;

  const itemRows = d.line_items.map((li, i) => [
    { text: String(i + 1), color: MUTED, fontSize: 9 },
    { text: li.description || "—", fontSize: 10 },
    { text: String(li.quantity), alignment: "right", fontSize: 10 },
    { text: formatMoney(li.unit_price), alignment: "right", fontSize: 10 },
    { text: formatMoney(rowTotal(li)), alignment: "right", fontSize: 10 },
  ]);

  // Header: logo if present, otherwise org name as wordmark
  const header = brand.logo_data_url
    ? { image: brand.logo_data_url, fit: [110, 110] as [number, number], alignment: "center" as const }
    : { text: brand.name, alignment: "center" as const, fontSize: 20, bold: true, color: INK };

  const fromLines: Array<{ text: string; fontSize: number; color?: string; bold?: boolean; margin?: [number, number, number, number] }> = [
    { text: "FROM", fontSize: 8, color: MUTED, margin: [0, 0, 0, 6] },
    { text: brand.name, bold: true, fontSize: 10 },
  ];
  if (brand.emails.length > 0) fromLines.push({ text: brand.emails.join("  ·  "), fontSize: 9, color: MUTED, margin: [0, 2, 0, 0] });
  if (brand.website) fromLines.push({ text: brand.website, fontSize: 9, color: MUTED });
  const regBits = [
    brand.registration ? `Reg ${brand.registration}` : null,
    brand.tin ? `TIN ${brand.tin}` : null,
    brand.duns ? `DUNS ${brand.duns}` : null,
  ].filter(Boolean);
  if (regBits.length > 0) fromLines.push({ text: regBits.join("  ·  "), fontSize: 8, color: MUTED, margin: [0, 4, 0, 0] });
  if (brand.praz) fromLines.push({ text: `PRAZ Registration: ${brand.praz}`, fontSize: 9, color: INK, bold: true, margin: [0, 6, 0, 0] });
  if (brand.address) fromLines.push({ text: brand.address, fontSize: 8, color: MUTED, margin: [0, 2, 0, 0] });
  if (brand.phone) fromLines.push({ text: brand.phone, fontSize: 8, color: MUTED });

  const paymentText = brand.payment_instructions
    ? brand.payment_instructions
    : "Bank transfer details to be provided. Please reference document number on payment.";

  return {
    pageSize: "A4",
    pageMargins: [48, 56, 48, 72],
    defaultStyle: { font: "Roboto", color: INK, fontSize: 10, lineHeight: 1.35 },
    footer: (currentPage: number, pageCount: number) => ({
      margin: [48, 16, 48, 0],
      stack: [
        { canvas: [{ type: "line", x1: 0, y1: 0, x2: 499, y2: 0, lineWidth: 0.5, lineColor: HAIR }] },
        {
          columns: [
            {
              text: [
                { text: "Payment instructions: ", color: MUTED, fontSize: 8 },
                { text: paymentText, fontSize: 8 },
              ],
              width: "*",
            },
            { text: `${currentPage} / ${pageCount}`, alignment: "right", color: MUTED, fontSize: 8, width: 60 },
          ],
          margin: [0, 8, 0, 0],
        },
      ],
    }),
    content: [
      header,
      {
        margin: [0, 16, 0, 0],
        stack: [
          { text: title.toUpperCase(), alignment: "center", fontSize: 9, color: MUTED, characterSpacing: 3 },
          { text: d.doc_number, alignment: "center", fontSize: 16, bold: true, margin: [0, 4, 0, 0] },
        ],
      },
      { canvas: [{ type: "line", x1: 0, y1: 0, x2: 499, y2: 0, lineWidth: 0.5, lineColor: HAIR }], margin: [0, 20, 0, 20] },

      {
        columns: [
          { width: "*", stack: fromLines },
          {
            width: "*",
            stack: [
              { text: "BILLED TO", fontSize: 8, color: MUTED, characterSpacing: 1.5, margin: [0, 0, 0, 6] },
              { text: d.client.company_name, bold: true, fontSize: 10 },
              d.client.address ? { text: d.client.address, fontSize: 9, color: MUTED, margin: [0, 2, 0, 0] } : {},
              d.client.email ? { text: d.client.email, fontSize: 9, color: MUTED } : {},
              d.client.phone ? { text: d.client.phone, fontSize: 9, color: MUTED } : {},
            ],
          },
          {
            width: 140,
            stack: [
              { text: "ISSUE DATE", fontSize: 8, color: MUTED, characterSpacing: 1.5 },
              { text: formatDate(d.issue_date), fontSize: 10, margin: [0, 2, 0, 10] },
              ...(d.due_date
                ? [
                    { text: isInvoice ? "DUE DATE" : "VALID UNTIL", fontSize: 8, color: MUTED, characterSpacing: 1.5 },
                    { text: formatDate(d.due_date), fontSize: 10, margin: [0, 2, 0, 0] },
                  ]
                : []),
            ],
          },
        ],
        columnGap: 24,
      },

      { text: "", margin: [0, 0, 0, 24] },

      {
        table: {
          headerRows: 1,
          widths: [16, "*", 50, 80, 80],
          body: [
            [
              { text: "#", color: MUTED, fontSize: 8, characterSpacing: 1.5, border: [false, false, false, true], borderColor: [HAIR, HAIR, HAIR, INK] },
              { text: "DESCRIPTION", color: MUTED, fontSize: 8, characterSpacing: 1.5, border: [false, false, false, true], borderColor: [HAIR, HAIR, HAIR, INK] },
              { text: "QTY", color: MUTED, fontSize: 8, characterSpacing: 1.5, alignment: "right", border: [false, false, false, true], borderColor: [HAIR, HAIR, HAIR, INK] },
              { text: "UNIT PRICE", color: MUTED, fontSize: 8, characterSpacing: 1.5, alignment: "right", border: [false, false, false, true], borderColor: [HAIR, HAIR, HAIR, INK] },
              { text: "AMOUNT", color: MUTED, fontSize: 8, characterSpacing: 1.5, alignment: "right", border: [false, false, false, true], borderColor: [HAIR, HAIR, HAIR, INK] },
            ],
            ...itemRows.map((row) =>
              row.map((cell) => ({
                ...(typeof cell === "string" ? { text: cell } : cell),
                border: [false, false, false, true],
                borderColor: [HAIR, HAIR, HAIR, HAIR],
                margin: [0, 8, 0, 8],
              }))
            ),
          ],
        },
        layout: "noBorders",
      },

      { text: "", margin: [0, 0, 0, 16] },

      {
        columns: [
          { width: "*", text: "" },
          {
            width: 240,
            table: {
              widths: ["*", "auto"],
              body: [
                [{ text: "Subtotal", color: MUTED, fontSize: 10, border: [false, false, false, false] }, { text: formatMoney(d.subtotal), alignment: "right", fontSize: 10, border: [false, false, false, false] }],
                [{ text: `Tax (${d.tax_rate}%)`, color: MUTED, fontSize: 10, border: [false, false, false, false] }, { text: formatMoney(d.tax_amount), alignment: "right", fontSize: 10, border: [false, false, false, false] }],
                ...(d.discount > 0
                  ? [[{ text: "Discount", color: MUTED, fontSize: 10, border: [false, false, false, false] }, { text: `− ${formatMoney(d.discount)}`, alignment: "right", fontSize: 10, border: [false, false, false, false] }]]
                  : []),
                [
                  { text: "Total", bold: true, fontSize: 12, border: [false, true, false, false], borderColor: [HAIR, INK, HAIR, HAIR], margin: [0, 8, 0, 0] },
                  { text: formatMoney(d.total), alignment: "right", bold: true, fontSize: 14, border: [false, true, false, false], borderColor: [HAIR, INK, HAIR, HAIR], margin: [0, 8, 0, 0] },
                ],
              ],
            },
            layout: "noBorders",
          },
        ],
      },

      ...(d.notes
        ? ([
            { text: "", margin: [0, 24, 0, 0] },
            { text: "NOTES", fontSize: 8, color: MUTED, characterSpacing: 1.5, margin: [0, 0, 0, 4] },
            { text: d.notes, fontSize: 9, color: INK },
          ] as const)
        : []),

      ...(qrDataUrl && d.verifyUrl
        ? ([
            { text: "", margin: [0, 28, 0, 0] },
            { canvas: [{ type: "line", x1: 0, y1: 0, x2: 499, y2: 0, lineWidth: 0.5, lineColor: HAIR }] },
            {
              margin: [0, 16, 0, 0],
              columns: [
                { image: qrDataUrl, width: 76 },
                {
                  width: "*",
                  margin: [16, 4, 0, 0],
                  stack: [
                    { text: "VERIFY THIS DOCUMENT", fontSize: 8, color: MUTED, characterSpacing: 2 },
                    { text: `Scan the QR code to confirm this document was issued by ${brand.short_name ?? brand.name} and has not been altered.`, fontSize: 9, color: INK, margin: [0, 4, 0, 6] },
                    ...(d.docHash
                      ? [
                          { text: "DOCUMENT HASH (SHA-256)", fontSize: 7, color: MUTED, characterSpacing: 1.5, margin: [0, 8, 0, 2] as [number, number, number, number] },
                          { text: d.docHash, fontSize: 7, color: INK, font: "Roboto", characterSpacing: 0.2 },
                        ]
                      : []),
                    ...(d.signatureId
                      ? [
                          { text: "SIGNATURE ID (HMAC-SHA256)", fontSize: 7, color: MUTED, characterSpacing: 1.5, margin: [0, 6, 0, 2] as [number, number, number, number] },
                          { text: d.signatureId, fontSize: 7, color: INK, font: "Roboto", characterSpacing: 0.2 },
                        ]
                      : []),
                  ],
                },
              ],
            },
          ] as const)
        : []),
    ],
  };
}
