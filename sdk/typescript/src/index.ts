// QuoteScribe TypeScript SDK
// Thin, dependency-free wrapper around the QuoteScribe REST API.
//
// Usage:
//   import { QuoteScribeClient } from "@quotescribe/sdk";
//   const qs = new QuoteScribeClient({ apiKey: process.env.QSK_API_KEY!, baseUrl: "https://your-app.example.com" });
//   const { data } = await qs.clients.list();

export type LineItem = {
  description: string;
  quantity: number;
  unit_price: number;
};

export type ClientRecord = {
  id: string;
  company_name: string;
  email: string | null;
  phone: string | null;
  address: string | null;
  created_at: string;
  updated_at: string;
};

export type Document = {
  id: string;
  doc_type: "quote" | "invoice";
  doc_number: string;
  client_id: string;
  issue_date: string;
  due_date: string | null;
  line_items: LineItem[];
  tax_rate: number;
  discount: number;
  subtotal: number;
  tax_amount: number;
  total: number;
  notes: string | null;
  created_at: string;
  updated_at: string;
};

export type Organization = {
  org_id: string;
  name: string;
  short_name: string | null;
  address: string | null;
  phone: string | null;
  emails: string[];
  website: string | null;
  currency: string;
  default_tax_rate: number;
  tin: string | null;
  praz: string | null;
  duns: string | null;
  registration: string | null;
  logo_url: string | null;
};

export type Paginated<T> = { data: T[]; limit: number; offset: number };
export type Single<T> = { data: T };

export type CreateClientInput = {
  company_name: string;
  email?: string | null;
  phone?: string | null;
  address?: string | null;
};

export type UpdateClientInput = Partial<CreateClientInput>;

export type CreateDocumentInput = {
  client_id: string;
  doc_type: "quote" | "invoice";
  doc_number: string;
  issue_date: string;
  due_date?: string | null;
  line_items: LineItem[];
  tax_rate?: number;
  discount?: number;
  notes?: string | null;
};

export type UpdateDocumentInput = {
  doc_number?: string;
  issue_date?: string;
  due_date?: string | null;
  line_items?: LineItem[];
  tax_rate?: number;
  discount?: number;
  notes?: string | null;
};

export type VerifyPayload = {
  id: string;
  hash: string;
  sig: string;
  verify_url: string;
};

export class QuoteScribeError extends Error {
  status: number;
  constructor(status: number, message: string) {
    super(message);
    this.name = "QuoteScribeError";
    this.status = status;
  }
}

export type ClientOptions = {
  apiKey: string;
  baseUrl: string;
  fetch?: typeof fetch;
};

export class QuoteScribeClient {
  private apiKey: string;
  private baseUrl: string;
  private fetchImpl: typeof fetch;

  clients: {
    list: (params?: { limit?: number; offset?: number }) => Promise<Paginated<ClientRecord>>;
    get: (id: string) => Promise<Single<ClientRecord>>;
    create: (input: CreateClientInput) => Promise<Single<ClientRecord>>;
    update: (id: string, input: UpdateClientInput) => Promise<Single<ClientRecord>>;
    delete: (id: string) => Promise<{ deleted: true }>;
  };

  documents: {
    list: (params?: { limit?: number; offset?: number; type?: "quote" | "invoice" }) => Promise<Paginated<Document>>;
    get: (id: string) => Promise<Single<Document & { client: ClientRecord }>>;
    create: (input: CreateDocumentInput) => Promise<Single<Document>>;
    update: (id: string, input: UpdateDocumentInput) => Promise<Single<Document>>;
    delete: (id: string) => Promise<{ deleted: true }>;
    verify: (id: string) => Promise<VerifyPayload>;
    /** Direct URL developers can pass to a browser (still requires the Bearer header when fetched). */
    pdfUrl: (id: string, opts?: { disposition?: "inline" | "attachment" }) => string;
    /** Fetch the rendered PDF bytes. */
    downloadPdf: (id: string, opts?: { disposition?: "inline" | "attachment" }) => Promise<Uint8Array>;
  };

  organization: {
    get: () => Promise<Single<Organization>>;
  };

  constructor(opts: ClientOptions) {
    if (!opts.apiKey) throw new Error("apiKey is required");
    if (!opts.baseUrl) throw new Error("baseUrl is required");
    this.apiKey = opts.apiKey;
    this.baseUrl = opts.baseUrl.replace(/\/$/, "");
    this.fetchImpl = opts.fetch ?? fetch;

    this.clients = {
      list: (p) => this.request("GET", `/clients${query(p)}`),
      get: (id) => this.request("GET", `/clients/${encodeURIComponent(id)}`),
      create: (input) => this.request("POST", `/clients`, input),
      update: (id, input) => this.request("PATCH", `/clients/${encodeURIComponent(id)}`, input),
      delete: (id) => this.request("DELETE", `/clients/${encodeURIComponent(id)}`),
    };

    this.documents = {
      list: (p) => this.request("GET", `/documents${query(p)}`),
      get: (id) => this.request("GET", `/documents/${encodeURIComponent(id)}`),
      create: (input) => this.request("POST", `/documents`, input),
      update: (id, input) => this.request("PATCH", `/documents/${encodeURIComponent(id)}`, input),
      delete: (id) => this.request("DELETE", `/documents/${encodeURIComponent(id)}`),
      verify: (id) => this.request("GET", `/documents/${encodeURIComponent(id)}/verify`),
    };

    this.organization = {
      get: () => this.request("GET", `/organization`),
    };
  }

  private async request<T>(method: string, path: string, body?: unknown): Promise<T> {
    const res = await this.fetchImpl(`${this.baseUrl}/api/public/v1${path}`, {
      method,
      headers: {
        Authorization: `Bearer ${this.apiKey}`,
        ...(body !== undefined ? { "Content-Type": "application/json" } : {}),
      },
      body: body !== undefined ? JSON.stringify(body) : undefined,
    });
    const text = await res.text();
    const parsed = text ? JSON.parse(text) : {};
    if (!res.ok) {
      const msg = parsed?.error?.message ?? res.statusText;
      throw new QuoteScribeError(res.status, msg);
    }
    return parsed as T;
  }
}

function query(p?: Record<string, unknown>): string {
  if (!p) return "";
  const entries = Object.entries(p).filter(([, v]) => v !== undefined && v !== null);
  if (!entries.length) return "";
  return "?" + entries.map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(String(v))}`).join("&");
}
