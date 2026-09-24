# Dify Knowledge MCP — Thin Adapter

Local stdio MCP server that exposes **only** Dify Knowledge Base retrieval capabilities.
Dify handles ingestion, chunking, embeddings, reranking, vector storage — this server only calls the Dify Knowledge API.

## Tools

| Tool | Dify API | Description |
|---|---|---|
| `list_knowledge_bases` | `GET /datasets` | Paginated list, `keyword` filter |
| `search_knowledge` | `POST /datasets/{id}/retrieve` | Hybrid search; if `dataset_id` omitted, fans out across all bases and merges by score |
| `get_document` | `GET /datasets/{id}/documents/{doc_id}` | Document metadata |

## Configuration

Env:

```
DIFY_BASE_URL=https://api.dify.ai/v1   # or https://dify.company.com/v1
DIFY_API_KEY=dataset-...               # Knowledge Base API key (Bearer)
```

`DIFY_API_KEY` is a **dataset API key** from Dify Console → Knowledge → Service API. One key can access every knowledge base visible to the account that created it.

## OpenCode wiring

In `opencode.json`:

```json
{
  "mcp": {
    "dify-knowledge": {
      "type": "local",
      "command": ["node", "mcp/dify-knowledge/dist/index.js"],
      "environment": {
        "DIFY_BASE_URL": "{env:DIFY_BASE_URL}",
        "DIFY_API_KEY": "{env:DIFY_API_KEY}"
      }
    }
  }
}
```

`{env:…}` is resolved by OpenCode from the shell env / `.env`.

## Build

```bash
cd mcp/dify-knowledge
npm install
npm run build
```

## Test (without OpenCode)

```bash
DIFY_BASE_URL=https://api.dify.ai/v1 DIFY_API_KEY=dataset-... node dist/index.js
# then use MCP Inspector:
npx @modelcontextprotocol/inspector node dist/index.js
```

## Dify API notes (verified 2026-09)

- Auth: `Authorization: Bearer {API_KEY}` for every request.
- List: `GET /datasets?page=1&limit=20&keyword=foo`
- Retrieve: `POST /datasets/{dataset_id}/retrieve` body `{ query, retrieval_model: { search_method, reranking_enable, top_k, score_threshold_enabled } }`
- Document: `GET /datasets/{dataset_id}/documents/{document_id}`

Only tools supported by the current Dify API are implemented. No embedding, vector DB, crawling, or ingestion logic lives here.
