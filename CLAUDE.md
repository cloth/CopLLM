# CopLLM — Corporate AI Workspace fuer CLX Digital

## Projektuebersicht

Corporate AI Workspace: RAG-basierter KI-Assistent, der auf Basis echter Firmendokumente antwortet.
Dient als eigene Demo, Referenz und Blaupause fuer Kundenprojekte (KMU, DACH-Raum).

**Dieses Repo ist ein lebendes Tutorial** — es waechst mit jeder Erfahrung und jedem Kunden-Setup.
Ziel: Kunden-Rollout so automatisiert wie moeglich.

## Architektur

```
Nutzer → Open WebUI → LiteLLM Router → Claude API / Ollama (lokal)
                                ↓
                          RAG Engine → Supabase pgvector
                                          ↑
                                    n8n Sync-Workflow
                                    (Google Drive / OneDrive / lokale PDFs)
                                          ↑
                                    OCR Pipeline (Tesseract / Google Document AI)
```

## Stack

| Komponente         | Technologie                          | Zweck                        |
|--------------------|--------------------------------------|------------------------------|
| Chat-Interface     | Open WebUI (Docker)                  | Nutzer-Frontend              |
| LLM-Router         | LiteLLM                             | Modell-Routing, Kostentracking |
| LLM-Backend        | Anthropic API (Claude Sonnet/Opus)   | Hauptmodell                  |
| LLM-Fallback       | Ollama (Llama 3.3)                   | Lokaler Fallback, DSGVO-sicher |
| Embedding          | Konfigurierbar: Ollama / Google / OpenAI | Vektorisierung             |
| Vektordatenbank    | Supabase pgvector (Frankfurt)        | Eigene Demo + Kunden         |
| Dokument-Sync      | n8n (Raspberry Pi)                   | Automatisches Einlesen       |
| OCR/Scans          | gemini-embedding-2-preview (direkt) / Tesseract (Fallback) | Gescannte PDFs |
| Reverse Proxy      | Caddy                                | HTTPS, Enterprise-Deployment |

## Verzeichnisstruktur

```
CopLLM/
├── CLAUDE.md                        # Dieses Dokument
├── .gitignore
├── .env.example                     # Vorlage fuer alle Secrets und Konfig
│
├── supabase/
│   └── init.sql                     # pgvector Schema, Funktionen, Indizes, RLS
│
├── litellm/
│   └── config.yaml                  # Modell-Router (Claude + Ollama Fallback)
│
├── caddy/
│   └── Caddyfile                    # Reverse Proxy, auto-HTTPS
│
├── open-webui/
│   └── system-prompt.md             # Corporate System-Prompt Vorlage
│
├── n8n/
│   ├── google-drive-sync.json       # Workflow: Drive/OneDrive → Chunks → Supabase
│   ├── nextcloud-sync.json          # Workflow: Nextcloud WebDAV → Chunks → Supabase
│   ├── email-sync.json              # Workflow: Email IMAP Attachments → Chunks → Supabase
│   └── initial-import.json          # Workflow: Bulk-Import aller bestehenden Docs
│
├── docker-compose.quick.yml         # Weg A: Schnellstart (nur Open WebUI + API)
├── docker-compose.yml               # Weg C: Vollstack (WebUI + LiteLLM + Caddy)
│
├── runbook/                         # Lebendes Tutorial — waechst mit Erfahrung
│   ├── README.md                    # Uebersicht
│   ├── 01-setup-supabase.md
│   ├── 02-setup-ollama.md
│   ├── 03-setup-litellm.md
│   ├── 04-setup-open-webui.md
│   ├── 05-setup-n8n-sync.md         # Inkl. OCR-Setup
│   ├── 06-kunden-rollout.md
│   ├── 07-demo-skript.md
│   ├── 08-troubleshooting.md
│   ├── 09-hacks-und-learnings.md
│   ├── 10-skalierung.md             # 3-Phasen-Plan: 10 → 1000+ Kunden
│   └── 11-llm-kosten-monitoring.md  # Usage Dashboard, Abrechnung, Alerting
│
└── scripts/                         # Automatisierung fuer Kunden-Rollout
    ├── add-customer.sh              # Legacy (wird durch provision.py ersetzt)
    ├── provision.py                 # DB-driven Provisioning (Phase 1)
    └── templates/                   # Jinja2-Templates fuer Config-Generierung
        ├── docker-compose.multi.yml.j2
        └── Caddyfile.multi.j2
```

## Deployment-Stufen

- **Weg A (Schnellstart):** `docker-compose.quick.yml` — Open WebUI lokal + Anthropic API + manuelle Uploads
- **Weg B (Produktionsreif):** Weg A + LiteLLM + n8n-Sync + Supabase pgvector
- **Weg C (Enterprise):** `docker-compose.yml` — Hetzner VPS + Caddy + vollstaendiger Stack

## Konventionen

- **Sprache:** Dokumentation und Kommentare auf Deutsch. Code und Variablennamen auf Englisch.
- **Secrets:** Niemals committen. Immer ueber `.env` (Vorlage: `.env.example`).
- **Docker:** `restart: unless-stopped` fuer Produktion.
- **Embedding-Dimension:** 768 (nomic-embed-text / Google gemini-embedding-001 mit output_dimensionality=768). Bei Wechsel zu OpenAI (1536): Schema anpassen!
- **Chunk-Einstellungen:** 300-600 Zeichen, 10-15% Ueberlappung. Top-K: 3-5. Similarity Threshold: 0.75.
- **Embedding-Provider:** Konfigurierbar via `EMBEDDING_PROVIDER` env var (ollama, google, openai).
- **OCR:** Bevorzugt `gemini-embedding-2-preview` (embeddet gescannte PDFs direkt, kein OCR noetig). Fallback: Tesseract lokal. `[OCR_NEEDED]` Marker im Workflow fuer Text-basierte Pipelines.
- **Runbook:** Jede Datei hat `## Learnings & Hacks` am Ende — nach jedem Setup ergaenzen.

## Wichtige Befehle

```bash
# Schnellstart (Weg A)
docker compose -f docker-compose.quick.yml up -d

# Produktions-Stack (Weg C)
cp .env.example .env   # Secrets eintragen
docker compose up -d

# LiteLLM testen
curl http://localhost:4000/v1/models -H "Authorization: Bearer $LITELLM_MASTER_KEY"

# Supabase Schema initialisieren
psql $SUPABASE_DB_URL -f supabase/init.sql

# Ollama Embedding testen
curl http://localhost:11434/api/embeddings -d '{"model":"nomic-embed-text","prompt":"Test"}'

# Dokument-Uebersicht in Supabase
# SQL: SELECT * FROM documents_overview;
```

## DSGVO

- Supabase/Hetzner: Region eu-central-1 (Frankfurt)
- AVV mit Anthropic, Supabase abschliessen
- API-Keys nutzen (kein Web-Chat, kein Training auf Kundendaten)
- Row Level Security auf Vektordatenbank aktiviert
- Audit-Log: sync_log Tabelle in Supabase
