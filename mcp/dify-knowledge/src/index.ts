#!/usr/bin/env node
/**
 * Dify Knowledge MCP — thin adapter
 * Exposes 3 tools backed by Dify Knowledge (Dataset) API:
 *  - list_knowledge_bases
 *  - search_knowledge
 *  - get_document
 *
 * Env:
 *  DIFY_BASE_URL  — e.g. https://api.dify.ai/v1  or https://dify.company.com/v1
 *  DIFY_API_KEY   — Dataset API key (Bearer). Scoped to visible datasets.
 *
 * Docs verified 2026-09:
 *  POST /datasets/{dataset_id}/retrieve  (retrieve chunks)
 *  GET  /datasets                        (list)
 *  GET  /datasets/{dataset_id}           (get one)
 *  GET  /datasets/{dataset_id}/documents/{document_id}  (document metadata)
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

// ---------------------------------------------------------------------------
// Config
// ---------------------------------------------------------------------------
const BASE_URL = (process.env.DIFY_BASE_URL || "").replace(/\/+$/, "");
const API_KEY = process.env.DIFY_API_KEY || "";

function requireEnv(): void {
  const missing: string[] = [];
  if (!BASE_URL) missing.push("DIFY_BASE_URL");
  if (!API_KEY) missing.push("DIFY_API_KEY");
  if (missing.length) {
    // Log to stderr — stdout is reserved for MCP JSON-RPC
    console.error(
      `[dify-knowledge-mcp] Missing required env: ${missing.join(", ")}. ` +
        `Set them in .env or environment before starting OpenCode. ` +
        `Example: DIFY_BASE_URL=https://api.dify.ai/v1 DIFY_API_KEY=dataset-...`
    );
  }
}

function apiHeaders(): Record<string, string> {
  return {
    Authorization: `Bearer ${API_KEY}`,
    "Content-Type": "application/json",
  };
}

function apiUrl(path: string): string {
  // BASE_URL already includes /v1; ensure no double slash
  return `${BASE_URL}${path}`;
}

async function difyFetch(
  path: string,
  init: RequestInit = {}
): Promise<{ ok: boolean; status: number; json: unknown; text: string }> {
  const url = apiUrl(path);
  const res = await fetch(url, {
    ...init,
    headers: { ...apiHeaders(), ...(init.headers as Record<string, string> | undefined) },
  });
  const text = await res.text();
  let json: unknown = null;
  try {
    json = text ? JSON.parse(text) : null;
  } catch {
    // keep text
  }
  return { ok: res.ok, status: res.status, json, text };
}

function errText(status: number, body: unknown, fallback: string): string {
  if (body && typeof body === "object") {
    const o = body as Record<string, unknown>;
    if (typeof o.message === "string") return `Dify error ${status}: ${o.message} (${String(o.code ?? "")})`.trim();
    if (typeof o.error === "string") return `Dify error ${status}: ${o.error}`;
  }
  return `Dify error ${status}: ${fallback}`;
}

// ---------------------------------------------------------------------------
// Server
// ---------------------------------------------------------------------------
const server = new McpServer(
  { name: "dify-knowledge", version: "1.0.0" },
  { capabilities: { tools: {} } }
);

// ---------------------------------------------------------------------------
// Tool: list_knowledge_bases
// GET /datasets?page=&limit=&keyword=
// ---------------------------------------------------------------------------
server.tool(
  "list_knowledge_bases",
  "List available Dify Knowledge Bases (datasets). Filter by keyword, paginated.",
  {
    keyword: z.string().optional().describe("Optional keyword filter on name"),
    page: z.number().int().min(1).optional().describe("Page number (default 1)"),
    limit: z.number().int().min(1).max(100).optional().describe("Items per page (1-100, default 20)"),
  },
  async ({ keyword, page, limit }) => {
    if (!BASE_URL || !API_KEY) {
      return {
        content: [{ type: "text", text: "DIFY_BASE_URL and DIFY_API_KEY must be set. Copy .env.example to .env and configure." }],
        isError: true,
      };
    }
    const qs = new URLSearchParams();
    if (page) qs.set("page", String(page));
    if (limit) qs.set("limit", String(limit));
    if (keyword) qs.set("keyword", keyword);
    const q = qs.toString() ? `?${qs.toString()}` : "";
    const { ok, status, json, text } = await difyFetch(`/datasets${q}`, { method: "GET" });
    if (!ok) {
      return { content: [{ type: "text", text: errText(status, json, text || "list_knowledge_bases failed") }], isError: true };
    }
    // Dify returns { data: [...], has_more, limit, total, page }
    const pretty = JSON.stringify(json, null, 2);
    return { content: [{ type: "text", text: pretty }] };
  }
);

// ---------------------------------------------------------------------------
// Tool: get_document
// GET /datasets/{dataset_id}/documents/{document_id}
// ---------------------------------------------------------------------------
server.tool(
  "get_document",
  "Get document metadata from a Dify Knowledge Base. Returns name, status, word count, chunk count, etc. Chunk content is via search_knowledge.",
  {
    dataset_id: z.string().describe("Knowledge Base (dataset) ID"),
    document_id: z.string().describe("Document ID within that base"),
  },
  async ({ dataset_id, document_id }) => {
    if (!BASE_URL || !API_KEY) {
      return {
        content: [{ type: "text", text: "DIFY_BASE_URL and DIFY_API_KEY must be set." }],
        isError: true,
      };
    }
    const { ok, status, json, text } = await difyFetch(
      `/datasets/${encodeURIComponent(dataset_id)}/documents/${encodeURIComponent(document_id)}`,
      { method: "GET" }
    );
    if (!ok) {
      return { content: [{ type: "text", text: errText(status, json, text || "get_document failed") }], isError: true };
    }
    return { content: [{ type: "text", text: JSON.stringify(json, null, 2) }] };
  }
);

// ---------------------------------------------------------------------------
// Tool: search_knowledge
// POST /datasets/{dataset_id}/retrieve
// If dataset_id omitted, list bases then search each and aggregate by score.
// ---------------------------------------------------------------------------

/* eslint-disable @typescript-eslint/no-explicit-any */
type RetrieveRecord = {
  score: number;
  segment?: { content: string; document_id?: string; document?: { name?: string }; position?: number };
  content?: string;
  title?: string;
  source_url?: string;
};

function formatRecord(r: any, datasetId: string, fallbackScore: number): string {
  // Dify retrieve returns { records: [{ score, segment: {content, document:{name}, document_id}, ...}] }
  const score: number = typeof r.score === "number" ? r.score : fallbackScore;
  const segment = r.segment ?? {};
  const content: string = segment.content ?? r.content ?? "";
  const docName: string = segment.document?.name ?? r.title ?? "";
  const docId: string = segment.document_id ?? r.document_id ?? segment.document?.id ?? "";
  const position = segment.position ?? "";
  // Truncate content for display (keep agent-optimized)
  const snippet = content.length > 1200 ? content.slice(0, 1200) + " …" : content;
  return [
    `Source: ${docName || docId || "unknown"}${position ? ` #${position}` : ""}`,
    `Knowledge Base: ${datasetId}`,
    `Document ID: ${docId || "-"}`,
    `Score: ${score.toFixed(4)}`,
    `Content: ${snippet}`,
  ].join("\n");
}

server.tool(
  "search_knowledge",
  "Search Dify Knowledge Base(s) and return relevant chunks. If dataset_id omitted, searches across all accessible bases (aggregated, sorted by score).",
  {
    query: z.string().min(1).max(250).describe("Search query text (max 250 chars)"),
    dataset_id: z.string().optional().describe("Knowledge Base (dataset) ID. If omitted, searches across all accessible bases."),
    top_k: z.number().int().min(1).max(20).optional().describe("Max chunks to return (1-20, default 5). When searching all bases, total across bases."),
  },
  async ({ query, dataset_id, top_k }) => {
    if (!BASE_URL || !API_KEY) {
      return {
        content: [{ type: "text", text: "DIFY_BASE_URL and DIFY_API_KEY must be set. Copy .env.example to .env and configure." }],
        isError: true,
      };
    }
    const k = top_k ?? 5;

    // Helper: single dataset retrieve
    async function retrieveOne(
      dsId: string,
      kPerDs: number
    ): Promise<{ records: any[]; error?: string }> {
      const body = JSON.stringify({
        query,
        retrieval_model: {
          search_method: "hybrid_search",
          reranking_enable: false,
          top_k: kPerDs,
          score_threshold_enabled: false,
        },
      });
      const { ok, status, json, text } = await difyFetch(`/datasets/${encodeURIComponent(dsId)}/retrieve`, {
        method: "POST",
        body,
      });
      if (!ok) {
        return { records: [], error: errText(status, json, text || "retrieve failed") };
      }
      const j = json as any;
      const records: any[] = Array.isArray(j?.records) ? j.records : Array.isArray(j?.data) ? j.data : [];
      return { records };
    }

    if (dataset_id) {
      const { records, error } = await retrieveOne(dataset_id, k);
      if (error && records.length === 0) {
        return { content: [{ type: "text", text: error }], isError: true };
      }
      if (records.length === 0) {
        return { content: [{ type: "text", text: `No relevant chunks found for "${query}" in dataset ${dataset_id}.` }] };
      }
      // Sort by score desc, take k
      const sorted = [...records].sort((a, b) => (b.score ?? 0) - (a.score ?? 0)).slice(0, k);
      const out = sorted.map((r) => formatRecord(r, dataset_id, 0)).join("\n\n---\n\n");
      const header = `Found ${sorted.length} chunk(s) for "${query}" in ${dataset_id}:\n\n`;
      return { content: [{ type: "text", text: header + out }] };
    }

    // Aggregated search: list datasets then fan out
    const { ok, status, json, text } = await difyFetch(`/datasets?limit=100&page=1`, { method: "GET" });
    if (!ok) {
      return { content: [{ type: "text", text: errText(status, json, text || "list datasets failed for aggregated search") }], isError: true };
    }
    const j = json as any;
    const datasets: any[] = Array.isArray(j?.data) ? j.data : [];
    if (datasets.length === 0) {
      return { content: [{ type: "text", text: "No knowledge bases found. Create one in Dify Console > Knowledge." }] };
    }

    // Fan out with limited concurrency (3 at a time)
    const CONCURRENCY = 3;
    const allRecords: Array<{ r: any; dsId: string }> = [];
    const errors: string[] = [];
    for (let i = 0; i < datasets.length; i += CONCURRENCY) {
      const batch = datasets.slice(i, i + CONCURRENCY);
      const results = await Promise.all(
        batch.map(async (ds) => {
          const dsId: string = ds.id;
          // Distribute top_k budget: search each with k, then global sort/truncate
          const res = await retrieveOne(dsId, k);
          if (res.error) errors.push(`${dsId}: ${res.error}`);
          return { dsId, records: res.records };
        })
      );
      for (const { dsId, records } of results) {
        for (const r of records) allRecords.push({ r, dsId });
      }
    }

    if (allRecords.length === 0) {
      const errPart = errors.length ? `\nErrors: ${errors.slice(0, 3).join("; ")}` : "";
      return { content: [{ type: "text", text: `No relevant chunks found for "${query}" across ${datasets.length} knowledge base(s).${errPart}` }] };
    }

    const sorted = [...allRecords].sort((a, b) => (b.r.score ?? 0) - (a.r.score ?? 0)).slice(0, k);
    const out = sorted.map(({ r, dsId }) => formatRecord(r, dsId, 0)).join("\n\n---\n\n");
    const header = `Found ${sorted.length} chunk(s) for "${query}" across ${datasets.length} base(s) (sorted by score):\n\n`;
    const errNote = errors.length ? `\n\nNote: ${errors.length} base(s) had errors (showing partial results).` : "";
    return { content: [{ type: "text", text: header + out + errNote }] };
  }
);

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------
async function main(): Promise<void> {
  requireEnv();
  const transport = new StdioServerTransport();
  await server.connect(transport);
  // Log to stderr only
  console.error("[dify-knowledge-mcp] running on stdio");
}

main().catch((e) => {
  console.error("[dify-knowledge-mcp] fatal:", e);
  process.exit(1);
});
