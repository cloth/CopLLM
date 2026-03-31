# Architektur

Das interaktive Architektur-Diagramm zeigt den Datenfluss zwischen allen Komponenten.

[Interaktives Diagramm oeffnen](../docs/architecture.html){ .md-button }

## Uebersicht

```
Google Drive / OneDrive / Nextcloud / Email / Dropbox / Confluence / Notion
        |
        v
   n8n (Sync-Workflows pro Quelle)
        |
        +---> Chunking + Embedding (Ollama / Google Gemini / OpenAI)
        |
        v
  Supabase pgvector (Frankfurt, alle Kunden in einer Instanz via tenant_id)
        ^
        |
  Nutzer --> Open WebUI --> LiteLLM --> Claude API / Ollama
```

## Komponenten

| Service | Container | Port | Shared? |
|---------|-----------|------|---------|
| Caddy | copllm-caddy | 80, 443 | Ja |
| LiteLLM | copllm-litellm | 4000 (intern) | Ja |
| n8n | copllm-n8n | 5678 (intern) | Ja |
| Open WebUI | copllm-webui-{kunde} | 8080 (intern) | Nein (pro Kunde) |
| Supabase | extern (Frankfurt) | — | Ja (tenant_id) |
