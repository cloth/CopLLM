# CopLLM — Corporate AI Workspace

RAG-basierte KI-Assistenten fuer KMU im DACH-Raum.

Firmendokumente aus Google Drive, OneDrive, Nextcloud, Email und mehr werden automatisch eingelesen. Mitarbeiter stellen Fragen im Chat und bekommen Antworten auf Basis echter Firmendokumente — mit Quellenangabe.

## Schnellstart

```bash
cp .env.example .env
docker compose up -d
```

## Dokumentation

- **[Setup-Anleitungen](01-setup-supabase.md)** — Schritt fuer Schritt vom leeren Server zum laufenden System
- **[Kunden-Rollout](06-kunden-rollout.md)** — Checkliste fuer neue Kunden
- **[Integrationen](12-integrationen.md)** — Alle unterstuetzten Dokumentenquellen
- **[Skalierung](10-skalierung.md)** — Von 10 auf 1000+ Kunden
- **[LLM-Kosten](11-llm-kosten-monitoring.md)** — Monitoring, Dashboard, Abrechnung

## Stack

| Komponente | Technologie |
|------------|-------------|
| Chat | Open WebUI |
| LLM-Router | LiteLLM (Claude + Ollama) |
| Vektordatenbank | Supabase pgvector (Frankfurt) |
| Dokument-Sync | n8n |
| Reverse Proxy | Caddy |
