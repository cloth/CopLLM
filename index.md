# CopLLM — Corporate AI Workspace

RAG-basierte KI-Assistenten fuer KMU im DACH-Raum.

Firmendokumente aus Google Drive, OneDrive, Nextcloud, Email und mehr werden automatisch eingelesen. Mitarbeiter stellen Fragen im Chat und bekommen Antworten auf Basis echter Firmendokumente — mit Quellenangabe.

## Schnellstart

```bash
cp .env.example .env
docker compose up -d
```

## Dokumentation

- **[Setup-Anleitungen](runbook/01-setup-supabase.md)** — Schritt fuer Schritt vom leeren Server zum laufenden System
- **[Kunden-Rollout](runbook/06-kunden-rollout.md)** — Checkliste fuer neue Kunden
- **[Integrationen](runbook/12-integrationen.md)** — Alle unterstuetzten Dokumentenquellen
- **[Skalierung](runbook/10-skalierung.md)** — Von 10 auf 1000+ Kunden
- **[LLM-Kosten](runbook/11-llm-kosten-monitoring.md)** — Monitoring, Dashboard, Abrechnung

## Stack

| Komponente | Technologie |
|------------|-------------|
| Chat | Open WebUI |
| LLM-Router | LiteLLM (Claude + Ollama) |
| Vektordatenbank | Supabase pgvector (Frankfurt) |
| Dokument-Sync | n8n |
| Reverse Proxy | Caddy |
