import { a as pdfMake, b as pdfFonts } from "../_libs/pdfmake.mjs";
import { y as buildDef } from "./router-DjPnTx2E.mjs";
const fontsAny = pdfFonts;
const pdfMakeAny = pdfMake;
const resolvedFonts = fontsAny?.default ?? fontsAny;
if (typeof pdfMakeAny.addVirtualFileSystem === "function") {
  pdfMakeAny.addVirtualFileSystem(resolvedFonts);
} else {
  pdfMakeAny.vfs = resolvedFonts?.vfs ?? resolvedFonts?.pdfMake?.vfs ?? resolvedFonts;
}
if (typeof pdfMakeAny.addFonts === "function") {
  pdfMakeAny.addFonts({
    Roboto: {
      normal: "Roboto-Regular.ttf",
      bold: "Roboto-Medium.ttf",
      italics: "Roboto-Italic.ttf",
      bolditalics: "Roboto-MediumItalic.ttf"
    }
  });
} else {
  pdfMakeAny.fonts = {
    ...pdfMakeAny.fonts ?? {},
    Roboto: {
      normal: "Roboto-Regular.ttf",
      bold: "Roboto-Medium.ttf",
      italics: "Roboto-Italic.ttf",
      bolditalics: "Roboto-MediumItalic.ttf"
    }
  };
}
async function generatePdfBlob(d) {
  const def = await buildDef(d);
  const pdfApi = pdfMake.createPdf(def);
  const blob = await Promise.resolve(pdfApi.getBlob());
  if (!blob || typeof blob.size !== "number" || blob.size === 0) {
    throw new Error("PDF generation failed");
  }
  return blob;
}
async function downloadPdf(d) {
  const blob = await generatePdfBlob(d);
  const fileBlob = blob.type === "application/pdf" ? blob : new Blob([blob], { type: "application/pdf" });
  const filename = `${d.doc_number}.pdf`;
  const nav = window.navigator;
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
  setTimeout(() => URL.revokeObjectURL(url), 1e3);
}
async function openPdfPreview(d) {
  const blob = await generatePdfBlob(d);
  return URL.createObjectURL(blob);
}
export {
  downloadPdf as d,
  generatePdfBlob as g,
  openPdfPreview as o
};
