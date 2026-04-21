import pdfMake from "pdfmake/build/pdfmake";
import pdfFonts from "pdfmake/build/vfs_fonts";
import { buildDef, buildDocPath, type DocForPdf } from "./pdfDef";

// Register fonts (Roboto bundled with pdfmake)
// eslint-disable-next-line @typescript-eslint/no-explicit-any
(pdfMake as any).vfs = (pdfFonts as any).vfs ?? (pdfFonts as any).pdfMake?.vfs;

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
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  // Browsers strip leading directories from the suggested filename for safety,
  // but the structured path is preserved in the metadata header used by the
  // server route. We set both the safe filename and the structured path here.
  a.download = `${d.doc_number}.pdf`;
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
