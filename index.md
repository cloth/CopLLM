---
hide:
  - navigation
  - toc
---

<div class="hero" markdown>

# CopLLM

**Corporate AI Workspace fuer KMU im DACH-Raum**

Firmendokumente aus Google Drive, OneDrive, Nextcloud, Email und mehr —
automatisch eingelesen, vektorisiert und per KI-Chat durchsuchbar.

</div>

<div class="grid" markdown>

<div class="card" markdown>
### 8+ Integrationen
Google Drive, OneDrive, SharePoint, Nextcloud, Email/IMAP, Dropbox, Confluence, Notion
</div>

<div class="card" markdown>
### Multi-Kunden
Ein Server, beliebig viele Kunden. Jeder mit eigener Instanz, eigener Domain, eigenem Budget.
</div>

<div class="card" markdown>
### DSGVO-konform
Supabase Frankfurt, Hetzner Deutschland. Lokaler Ollama-Fallback. Row Level Security.
</div>

<div class="card" markdown>
### OCR fuer Scans
Gescannte PDFs direkt embedden via Gemini Embedding 2 — kein separater OCR-Schritt noetig.
</div>

<div class="card" markdown>
### Kosten-Tracking
Per-Kunde LLM-Budget, Spend-Monitoring via LiteLLM Virtual Keys, Grafana Dashboard.
</div>

<div class="card" markdown>
### One-Click Rollout
Neuer Kunde in 3 Befehlen: `add` → `generate` → `deploy`. Alles DB-driven.
</div>

</div>

## Schnellstart

```bash
cp .env.example .env          # Secrets eintragen
psql $SUPABASE_DB_URL -f supabase/init.sql
docker compose up -d
```

## Dokumentation

| Bereich | Inhalt |
|---------|--------|
| [Setup](01-setup-supabase.md) | Supabase, Ollama, LiteLLM, Open WebUI, n8n |
| [Betrieb](06-kunden-rollout.md) | Rollout-Checkliste, Demo-Skript, Troubleshooting |
| [Skalierung](10-skalierung.md) | Von 10 auf 1000+ Kunden (3-Phasen-Plan) |
| [Integrationen](12-integrationen.md) | Alle Dokumentenquellen + Setup-Anleitungen |
| [LLM-Kosten](11-llm-kosten-monitoring.md) | Monitoring, Dashboard, Abrechnung |
| [Architektur](architecture.md) | Datenfluss-Diagramm, Komponenten |

## Stack

| Komponente | Technologie | Zweck |
|------------|-------------|-------|
| Chat | Open WebUI | Nutzer-Frontend |
| LLM-Router | LiteLLM | Claude + Ollama Fallback |
| Vektordatenbank | Supabase pgvector | Frankfurt, DSGVO |
| Dokument-Sync | n8n | Google Drive, OneDrive, Nextcloud, Email |
| Reverse Proxy | Caddy | Auto-HTTPS, Multi-Domain |
