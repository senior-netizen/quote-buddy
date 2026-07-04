import { createFileRoute } from "@tanstack/react-router";

/**
 * OpenAPI 3.1 spec for the public API. Served as JSON so tools like
 * Swagger UI, Postman, and codegen can consume it.
 *   GET /api/public/v1/openapi.json
 */
export const Route = createFileRoute("/api/public/v1/openapi.json")({
  server: {
    handlers: {
      OPTIONS: async () =>
        new Response(null, {
          status: 204,
          headers: {
            "access-control-allow-origin": "*",
            "access-control-allow-headers": "authorization, content-type",
            "access-control-allow-methods": "GET, OPTIONS",
          },
        }),
      GET: async ({ request }) => {
        const origin = new URL(request.url).origin;
        const spec = buildSpec(origin);
        return new Response(JSON.stringify(spec, null, 2), {
          status: 200,
          headers: {
            "content-type": "application/json",
            "access-control-allow-origin": "*",
            "cache-control": "public, max-age=300",
          },
        });
      },
    },
  },
});

function buildSpec(origin: string) {
  const bearer = { BearerAuth: [] as string[] };
  return {
    openapi: "3.1.0",
    info: {
      title: "QuoteScribe Public API",
      version: "1.0.0",
      description:
        "REST API for managing clients, quotes, and invoices. All requests are scoped to a single organization by API key.",
    },
    servers: [{ url: `${origin}/api/public/v1` }],
    security: [bearer],
    components: {
      securitySchemes: {
        BearerAuth: { type: "http", scheme: "bearer", bearerFormat: "qsk_live_*" },
      },
      schemas: {
        Error: {
          type: "object",
          properties: {
            error: {
              type: "object",
              properties: {
                status: { type: "integer" },
                message: { type: "string" },
              },
              required: ["status", "message"],
            },
          },
        },
        LineItem: {
          type: "object",
          required: ["description", "quantity", "unit_price"],
          properties: {
            description: { type: "string", maxLength: 500 },
            quantity: { type: "number", minimum: 0 },
            unit_price: { type: "number", minimum: 0 },
          },
        },
        Client: {
          type: "object",
          properties: {
            id: { type: "string", format: "uuid" },
            company_name: { type: "string" },
            email: { type: "string", nullable: true },
            phone: { type: "string", nullable: true },
            address: { type: "string", nullable: true },
            created_at: { type: "string", format: "date-time" },
            updated_at: { type: "string", format: "date-time" },
          },
        },
        ClientInput: {
          type: "object",
          required: ["company_name"],
          properties: {
            company_name: { type: "string", maxLength: 200 },
            email: { type: "string", nullable: true },
            phone: { type: "string", nullable: true },
            address: { type: "string", nullable: true },
          },
        },
        Document: {
          type: "object",
          properties: {
            id: { type: "string", format: "uuid" },
            doc_type: { type: "string", enum: ["quote", "invoice"] },
            doc_number: { type: "string" },
            client_id: { type: "string", format: "uuid" },
            issue_date: { type: "string", format: "date" },
            due_date: { type: "string", format: "date", nullable: true },
            line_items: { type: "array", items: { $ref: "#/components/schemas/LineItem" } },
            tax_rate: { type: "number" },
            discount: { type: "number" },
            subtotal: { type: "number" },
            tax_amount: { type: "number" },
            total: { type: "number" },
            notes: { type: "string", nullable: true },
            created_at: { type: "string", format: "date-time" },
            updated_at: { type: "string", format: "date-time" },
          },
        },
        DocumentInput: {
          type: "object",
          required: ["client_id", "doc_type", "doc_number", "issue_date", "line_items"],
          properties: {
            client_id: { type: "string", format: "uuid" },
            doc_type: { type: "string", enum: ["quote", "invoice"] },
            doc_number: { type: "string" },
            issue_date: { type: "string", format: "date" },
            due_date: { type: "string", format: "date", nullable: true },
            line_items: { type: "array", items: { $ref: "#/components/schemas/LineItem" }, minItems: 1 },
            tax_rate: { type: "number", default: 0 },
            discount: { type: "number", default: 0 },
            notes: { type: "string", nullable: true },
          },
        },
        Organization: {
          type: "object",
          properties: {
            org_id: { type: "string", format: "uuid" },
            name: { type: "string" },
            short_name: { type: "string", nullable: true },
            address: { type: "string", nullable: true },
            phone: { type: "string", nullable: true },
            emails: { type: "array", items: { type: "string" } },
            website: { type: "string", nullable: true },
            currency: { type: "string" },
            default_tax_rate: { type: "number" },
            tin: { type: "string", nullable: true },
            praz: { type: "string", nullable: true },
            duns: { type: "string", nullable: true },
            registration: { type: "string", nullable: true },
            logo_url: { type: "string", nullable: true },
          },
        },
      },
      responses: {
        Unauthorized: {
          description: "Missing or invalid API key",
          content: { "application/json": { schema: { $ref: "#/components/schemas/Error" } } },
        },
        NotFound: {
          description: "Resource not found",
          content: { "application/json": { schema: { $ref: "#/components/schemas/Error" } } },
        },
      },
    },
    paths: {
      "/organization": {
        get: {
          summary: "Get organization",
          responses: {
            "200": {
              description: "OK",
              content: {
                "application/json": {
                  schema: {
                    type: "object",
                    properties: { data: { $ref: "#/components/schemas/Organization" } },
                  },
                },
              },
            },
            "401": { $ref: "#/components/responses/Unauthorized" },
          },
        },
      },
      "/clients": {
        get: {
          summary: "List clients",
          parameters: [
            { name: "limit", in: "query", schema: { type: "integer", default: 50, maximum: 200 } },
            { name: "offset", in: "query", schema: { type: "integer", default: 0 } },
          ],
          responses: {
            "200": {
              description: "OK",
              content: {
                "application/json": {
                  schema: {
                    type: "object",
                    properties: {
                      data: { type: "array", items: { $ref: "#/components/schemas/Client" } },
                      limit: { type: "integer" },
                      offset: { type: "integer" },
                    },
                  },
                },
              },
            },
          },
        },
        post: {
          summary: "Create client",
          requestBody: {
            required: true,
            content: { "application/json": { schema: { $ref: "#/components/schemas/ClientInput" } } },
          },
          responses: {
            "200": {
              description: "OK",
              content: {
                "application/json": {
                  schema: {
                    type: "object",
                    properties: { data: { $ref: "#/components/schemas/Client" } },
                  },
                },
              },
            },
          },
        },
      },
      "/clients/{id}": {
        parameters: [{ name: "id", in: "path", required: true, schema: { type: "string", format: "uuid" } }],
        get: { summary: "Get client", responses: { "200": { description: "OK" }, "404": { $ref: "#/components/responses/NotFound" } } },
        patch: {
          summary: "Update client",
          requestBody: {
            required: true,
            content: { "application/json": { schema: { $ref: "#/components/schemas/ClientInput" } } },
          },
          responses: { "200": { description: "OK" }, "404": { $ref: "#/components/responses/NotFound" } },
        },
        delete: { summary: "Delete client", responses: { "200": { description: "OK" }, "404": { $ref: "#/components/responses/NotFound" } } },
      },
      "/documents": {
        get: {
          summary: "List documents",
          parameters: [
            { name: "limit", in: "query", schema: { type: "integer", default: 50, maximum: 200 } },
            { name: "offset", in: "query", schema: { type: "integer", default: 0 } },
            { name: "type", in: "query", schema: { type: "string", enum: ["quote", "invoice"] } },
          ],
          responses: { "200": { description: "OK" } },
        },
        post: {
          summary: "Create document",
          requestBody: {
            required: true,
            content: { "application/json": { schema: { $ref: "#/components/schemas/DocumentInput" } } },
          },
          responses: { "200": { description: "OK" } },
        },
      },
      "/documents/{id}": {
        parameters: [{ name: "id", in: "path", required: true, schema: { type: "string", format: "uuid" } }],
        get: { summary: "Get document", responses: { "200": { description: "OK" }, "404": { $ref: "#/components/responses/NotFound" } } },
        patch: {
          summary: "Update document",
          requestBody: {
            required: true,
            content: { "application/json": { schema: { $ref: "#/components/schemas/DocumentInput" } } },
          },
          responses: { "200": { description: "OK" }, "404": { $ref: "#/components/responses/NotFound" } },
        },
        delete: { summary: "Delete document", responses: { "200": { description: "OK" }, "404": { $ref: "#/components/responses/NotFound" } } },
      },
      "/documents/{id}/verify": {
        get: {
          summary: "Get signed verification URL",
          parameters: [{ name: "id", in: "path", required: true, schema: { type: "string", format: "uuid" } }],
          responses: {
            "200": {
              description: "OK",
              content: {
                "application/json": {
                  schema: {
                    type: "object",
                    properties: {
                      id: { type: "string" },
                      hash: { type: "string" },
                      sig: { type: "string" },
                      verify_url: { type: "string", format: "uri" },
                    },
                  },
                },
              },
            },
          },
        },
      },
      "/documents/{id}/pdf": {
        get: {
          summary: "Download document PDF",
          description: "Returns the rendered PDF bytes for the document.",
          parameters: [
            { name: "id", in: "path", required: true, schema: { type: "string", format: "uuid" } },
            {
              name: "disposition",
              in: "query",
              schema: { type: "string", enum: ["inline", "attachment"], default: "attachment" },
            },
          ],
          responses: {
            "200": {
              description: "PDF bytes",
              content: { "application/pdf": { schema: { type: "string", format: "binary" } } },
            },
            "404": { $ref: "#/components/responses/NotFound" },
          },
        },
      },
    },
  };
}
