# CopLLM

**Corporate AI Workspace** — RAG-basierte KI-Assistenten fuer KMU im DACH-Raum.

**Dokumentation:** https://cloth.github.io/CopLLM/

Firmendokumente aus Google Drive, OneDrive, Nextcloud, Email und mehr werden automatisch eingelesen, in Chunks zerlegt, vektorisiert und in einer Datenbank gespeichert. Mitarbeiter stellen Fragen im Chat und bekommen Antworten auf Basis der echten Firmendokumente — mit Quellenangabe, ohne Halluzination.

## Was ist das hier?

Dieses Repo ist gleichzeitig:

- **Eigene Demo** — der KI-Assistent von [CLX Digital](https://clx-digital.de)
- **Blaupause** — wiederverwendbares Setup fuer neue Kundenprojekte
- **Lebendes Tutorial** — waechst mit jedem Kunden-Setup (Runbook, Learnings, Hacks)
- **Automatisierungs-Toolkit** — Kunden-Rollout per Script (`scripts/add-customer.sh`)

## Architektur

```
Google Drive / OneDrive
        |
        v
   n8n (Sync-Workflow)
        |
        +---> Chunking + Embedding (Ollama / Google Gemini / OpenAI)
        |
        v
  Supabase pgvector (Frankfurt)
        ^
        |
  Nutzer --> Open WebUI --> LiteLLM --> Claude API / Ollama (lokal)
                                          |
                                     RAG: relevante Chunks
                                     aus Vektordatenbank holen
```

## Stack

| Komponente | Technologie | Zweck |
|------------|-------------|-------|
| Chat-Interface | Open WebUI | Nutzer-Frontend |
| LLM-Router | LiteLLM | Modell-Routing, Kosten-Tracking |
| LLM | Claude Sonnet/Opus | Hauptmodell |
| LLM-Fallback | Ollama (Llama 3.3) | Lokaler Fallback, DSGVO-sicher |
| Embedding | Ollama / Google Gemini / OpenAI | Vektorisierung (konfigurierbar) |
| OCR | Gemini Embedding 2 / Tesseract | Gescannte PDFs direkt embedden |
| Vektordatenbank | Supabase pgvector | Frankfurt, EU, DSGVO-konform |
| Dokument-Sync | n8n | Google Drive + OneDrive Trigger |
| Reverse Proxy | Caddy | Auto-HTTPS, Multi-Domain-Routing |

## Multi-Kunden-Betrieb

Alle Kunden laufen auf einem Server mit Docker:

- **1x Caddy** — routet Kunden-Domains (auto-HTTPS)
- **1x LiteLLM** — shared, spart Ressourcen
- **1x n8n** — Dokument-Sync fuer alle Kunden
- **Nx Open WebUI** — pro Kunde eine eigene Instanz + eigenes Volume

Neuen Kunden hinzufuegen:

```bash
./scripts/add-customer.sh mueller-gmbh ki.mueller-gmbh.de "Mueller GmbH"
```

## Schnellstart

```bash
# 1. Secrets konfigurieren
cp .env.example .env
# .env bearbeiten: API-Keys, Supabase-URL, etc.

# 2. Supabase Schema initialisieren
psql $SUPABASE_DB_URL -f supabase/init.sql

# 3. Stack starten
docker compose up -d

# 4. Open WebUI oeffnen → Admin-Account erstellen
```

Fuer den einfachsten Einstieg (ohne LiteLLM/Caddy):

```bash
docker compose -f docker-compose.quick.yml up -d
```

## Deployment-Stufen

| Stufe | Compose-File | Was laeuft |
|-------|-------------|------------|
| **Weg A** — Schnellstart | `docker-compose.quick.yml` | Open WebUI + Anthropic API direkt |
| **Weg C** — Produktion | `docker-compose.yml` | Open WebUI + LiteLLM + Caddy |
| **Multi-Kunden** | `docker-compose.multi.yml` | Shared Services + N Kunden-Instanzen |

## Sicherheits-Pflichttest vor Start/Deployment

**Hintergrund:** [CVE-2026-40217](https://nvd.nist.gov/vuln/detail/CVE-2026-40217) / [GHSA-wxxx-gvqv-xp7p](https://github.com/BerriAI/litellm/security/advisories/GHSA-wxxx-gvqv-xp7p) — Sandbox-Escape in `POST /guardrails/test_custom_code`.

Vor **jeder Reaktivierung** und **jedem neuen Deployment** von CopLLM ist folgender Test **Pflicht**:

1. Stack mit aktuellem Image-Stand starten:
   ```bash
   docker compose pull
   docker compose up -d
   ```
   (Multi-Kunden: `-f docker-compose.multi.yml` verwenden.)
2. **Laufende LiteLLM-Version prüfen** — mindestens **v1.110.1** mit dem in `docker-compose.yml` / `docker-compose.multi.yml` gepinnten Digest (`ghcr.io/berriai/litellm:v1.110.1@sha256:…`).
3. **Open WebUI:** Login.
4. **Chat** über ein LiteLLM-Modell (z. B. `copllm-default`).
5. **RAG:** Dokument importieren und eine Referenzfrage stellen.
6. **`POST /guardrails/test_custom_code` muss abgewiesen werden** (LiteLLM typisch nur auf `127.0.0.1:${LITELLM_PORT:-4000}`):
   ```bash
   curl -s -o /dev/null -w "%{http_code}" -X POST \
     -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
     -H "Content-Type: application/json" \
     -d '{}' \
     http://127.0.0.1:4000/guardrails/test_custom_code
   ```
7. **Logs prüfen:** nach Aufrufen von `/guardrails/test_custom_code` suchen, z. B.:
   ```bash
   docker logs copllm-litellm 2>&1 | grep 'test_custom_code'
   ```

Erst wenn alle Schritte bestanden sind, den Stack produktiv nutzen oder freigeben.

## Repo-Struktur

```
supabase/init.sql            pgvector Schema, Funktionen, RLS
litellm/config.yaml          Modell-Routing (Claude + Ollama Fallback)
caddy/Caddyfile              Reverse Proxy (Single-Kunde)
caddy/Caddyfile.multi        Reverse Proxy (Multi-Kunde)
open-webui/system-prompt.md  Corporate System-Prompt Vorlage
n8n/google-drive-sync.json   Sync-Workflow (Drive + OneDrive)
n8n/initial-import.json      Bulk-Import bestehender Dokumente
scripts/add-customer.sh      One-Click Kunden-Rollout
docs/architecture.html       Interaktives Architektur-Diagramm
runbook/                     Setup-Anleitungen + Troubleshooting
```

## Runbook

Das `runbook/` Verzeichnis ist ein lebendes Tutorial — jede Datei hat einen `Learnings & Hacks` Abschnitt, der nach jedem Setup ergaenzt wird:

01. Supabase einrichten
02. Ollama + Embedding-Modelle
03. LiteLLM konfigurieren
04. Open WebUI deployen
05. n8n Dokument-Sync + OCR
06. Kunden-Rollout (Checkliste)
07. Demo-Skript fuer Kundengespraeche
08. Troubleshooting
09. Hacks und Learnings

## DSGVO

- Supabase + Hetzner: Region Frankfurt (eu-central-1)
- AVV mit Anthropic und Supabase
- API-Keys statt Web-Chat (kein Training auf Kundendaten)
- Row Level Security auf Vektordatenbank
- Audit-Log via `sync_log` Tabelle

## Lizenz

Privates Repository — CLX Digital.
