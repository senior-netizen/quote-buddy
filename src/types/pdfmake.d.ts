declare module "pdfmake/build/pdfmake" {
  const pdfMake: {
    vfs: Record<string, string>;
    createPdf: (def: unknown) => {
      download: (filename?: string) => void;
      getDataUrl: (cb: (url: string) => void) => void;
      getBlob: (cb: (blob: Blob) => void) => void;
      getBuffer: (cb: (buffer: Uint8Array) => void) => void;
      open: () => void;
    };
  };
  export default pdfMake;
}
declare module "pdfmake/build/vfs_fonts" {
  const fonts: { vfs?: Record<string, string>; pdfMake?: { vfs: Record<string, string> } };
  export default fonts;
}
declare module "pdfmake/interfaces" {
  export type TDocumentDefinitions = unknown;
}
