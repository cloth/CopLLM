# 04 — Open WebUI Setup

## Was ist Open WebUI?

Chat-Interface fuer LLMs. Sieht aus wie ChatGPT, laeuft aber auf eigener Infrastruktur.
Unterstuetzt RAG (Dokumente hochladen), mehrere Modelle, Nutzerverwaltung.

## Warum nicht auf Vercel?

Open WebUI ist eine Python-App (FastAPI) die einen **dauerhaft laufenden Server** braucht.
Vercel ist fuer Serverless-Functions gebaut — das passt nicht zusammen:

- Braucht dauerhaften Python-Prozess → Vercel hat nur kurzlebige Functions
- Braucht WebSockets fuer Streaming → Vercel unterstuetzt das kaum
- Braucht persistenten Speicher (SQLite, Uploads) → Vercel hat keinen
- Braucht Docker → Vercel unterstuetzt kein Docker

**Wo Vercel trotzdem passt:**
- Supabase-Integration (native Vercel-Anbindung fuer Env-Variablen)
- Spaeter: Eigenes Kunden-Dashboard oder Landing Page
- Spaeter: Custom Frontend das die Supabase API + LiteLLM direkt nutzt

## Hosting-Optionen fuer Open WebUI

| Plattform | Docker | Preis | DX | Empfehlung |
|-----------|--------|-------|-----|------------|
| **Lokal (Docker Desktop)** | Ja | 0 EUR | docker compose up | Eigene Demo |
| **Railway** | Ja | ab $5/Mo | Git-Push-Deploy, Vercel-aehnlich | Weg B |
| **Render** | Ja | ab $7/Mo | Dashboard-Deploy | Weg B |
| **Fly.io** | Ja | ab $3/Mo | CLI-basiert | Weg B |
| **Hetzner VPS** | Ja | ab 4 EUR/Mo | docker compose + Caddy | Weg C (Kunden) |
| **Coolify** (self-hosted) | Ja | 0 EUR | Vercel-Klon auf eigenem VPS | Weg C Alternative |

**Empfehlung:**
- Eigene Demo: **Lokal** (docker compose)
- Produktiv / Kunden testen: **Railway** (am naechsten an Vercel-Erlebnis)
- Kunden-Deployment: **Hetzner VPS** (guenstig, volle Kontrolle, DSGVO Frankfurt)

### Railway Deployment (Weg B)

```bash
# Railway CLI installieren
npm install -g @railway/cli

# Login
railway login

# Neues Projekt
railway init

# Open WebUI deployen (nutzt Dockerfile automatisch)
railway up

# Umgebungsvariablen setzen
railway variables set OPENAI_API_BASE_URLS=http://litellm:4000/v1
railway variables set OPENAI_API_KEYS=$LITELLM_MASTER_KEY
railway variables set WEBUI_SECRET_KEY=$(openssl rand -hex 32)
railway variables set ENABLE_SIGNUP=false
```

### Hetzner VPS Deployment (Weg C)

```bash
# Auf dem VPS:
git clone <dein-repo> /opt/copllm
cd /opt/copllm
cp .env.example .env
# .env mit Kundenwerten fuellen
docker compose up -d
# Caddy kuemmert sich automatisch um HTTPS
```

## Schritt-fuer-Schritt (lokal / VPS)

### 1. Schnellstart (Weg A)

```bash
docker compose -f docker-compose.quick.yml up -d
# Oeffnen: http://localhost:3000
```

### 2. Produktions-Stack (Weg C)

```bash
docker compose up -d
# Oeffnen: https://DOMAIN (via Caddy)
```

### 3. Erster Login

1. http://localhost:3000 oeffnen
2. Admin-Account erstellen (erster Benutzer = Admin)
3. Settings → Admin → ENABLE_SIGNUP deaktivieren

### 4. Modell-Verbindung pruefen

Settings → Connections:
- Wenn LiteLLM: URL = `http://litellm:4000/v1`, Key = `LITELLM_MASTER_KEY`
- Wenn direkt Anthropic: URL = `https://api.anthropic.com/v1`, Key = Anthropic API Key

Unter Models sollten die konfigurierten Modelle erscheinen.

### 5. RAG-Einstellungen

Settings → Documents:
- Chunk Size: `500`
- Chunk Overlap: `75`
- Top K: `5`
- Relevance Threshold: `0.75`
- Embedding Engine: `ollama`
- Embedding Model: `nomic-embed-text`

### 6. System-Prompt setzen

Settings → General → System Prompt:
Inhalt aus `open-webui/system-prompt.md` einfuegen.

Fuer Kunden `[Unternehmen]` durch den echten Firmennamen ersetzen.

### 7. Knowledge Base anlegen

Workspace → Knowledge:
1. Collection erstellen (z.B. "Vertraege", "Handbuecher")
2. Dokumente hochladen
3. In neuem Chat: Collection auswaehlen, dann fragen

### 8. Nutzer einladen

Settings → Admin → Users:
- Neue Nutzer per E-Mail einladen
- Rollen: Admin, User
- Pro Nutzer eigene Chat-History

## Learnings & Hacks
<!-- Ergaenze hier nach jedem Setup was dir aufgefallen ist -->
