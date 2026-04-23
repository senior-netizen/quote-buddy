import pdfMake from "pdfmake/build/pdfmake";
import pdfFonts from "pdfmake/build/vfs_fonts";
import { buildDef, buildDocPath, type DocForPdf } from "./pdfDef";

// Register fonts (Roboto bundled with pdfmake).
// pdfmake's vfs_fonts module shape varies by version: sometimes it exports
// `{ vfs: {...} }`, sometimes `{ pdfMake: { vfs: {...} } }`, and in current
// builds it exports the font files directly as top-level keys. Resolve all three.
/* eslint-disable @typescript-eslint/no-explicit-any */
const fontsAny = pdfFonts as any;
const resolvedVfs =
  fontsAny?.vfs ??
  fontsAny?.pdfMake?.vfs ??
  fontsAny?.default?.vfs ??
  fontsAny?.default ??
  fontsAny;
(pdfMake as any).vfs = resolvedVfs;
/* eslint-enable @typescript-eslint/no-explicit-any */

export type { DocForPdf };
export { buildDocPath };

/** Generates a Blob locally (used by Preview to render in an iframe). */
export async function generatePdfBlob(d: DocForPdf): Promise<Blob> {
  const def = await buildDef(d);
  return new Promise<Blob>((resolve, reject) => {
    try {
      pdfMake.createPdf(def).getBlob((blob: Blob) => resolve(blob));
    } catch (e) {
      reject(e);
    }
  });
}

/** Triggers a download in the browser using a structured filename path. */
export async function downloadPdf(d: DocForPdf): Promise<void> {
  const blob = await generatePdfBlob(d);
  const fileBlob = blob.type === "application/pdf" ? blob : new Blob([blob], { type: "application/pdf" });
  const filename = `${d.doc_number}.pdf`;
  type MaybeMsNavigator = Navigator & { msSaveOrOpenBlob?: (blob: Blob, defaultName?: string) => boolean };
  const nav = window.navigator as MaybeMsNavigator;
  if (typeof nav.msSaveOrOpenBlob === "function") {
    nav.msSaveOrOpenBlob(fileBlob, filename);
    return;
  }

  const url = URL.createObjectURL(fileBlob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  a.rel = "noopener";
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

/** Returns an object URL suitable for iframe preview. Caller must revoke. */
export async function openPdfPreview(d: DocForPdf): Promise<string> {
  const blob = await generatePdfBlob(d);
  return URL.createObjectURL(blob);
}
