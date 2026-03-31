# 05 — n8n Sync-Workflows (Google Drive + OneDrive + OCR)

## Uebersicht

Zwei Workflows:
1. **google-drive-sync.json** — Laufende Ueberwachung (alle 5 Min)
2. **initial-import.json** — Einmaliger Bulk-Import aller bestehenden Dateien

## Voraussetzungen

- n8n laeuft (Raspberry Pi oder Docker)
- Google Drive OAuth2 Credentials konfiguriert
- OneDrive / Microsoft Graph OAuth2 Credentials konfiguriert
- Supabase Schema initialisiert (init.sql)
- Ollama erreichbar (oder Google/OpenAI API Key fuer Embeddings)

## Schritt-fuer-Schritt

### 1. Workflows importieren

In n8n: Menu → Import from File → JSON auswaehlen

- `n8n/google-drive-sync.json`
- `n8n/initial-import.json`

### 2. Google Drive Credentials einrichten

1. Google Cloud Console → APIs & Services → Credentials
2. OAuth 2.0 Client ID erstellen (Desktop App)
3. Google Drive API aktivieren
4. In n8n: Credentials → Google Drive OAuth2 → Client ID + Secret eintragen
5. Autorisieren (Browser-Popup)

### 3. OneDrive Credentials einrichten

1. Azure Portal → App Registrations → New Registration
2. Redirect URI: `http://localhost:5678/rest/oauth2-credential/callback`
3. API Permissions: `Files.Read.All`, `offline_access`
4. Client Secret erstellen
5. In n8n: Credentials → OAuth2 → Microsoft Graph Werte eintragen

### 4. Environment-Variablen in n8n setzen

n8n Settings → Environment Variables (oder in Docker .env):
```env
SUPABASE_URL=https://xxxxx.supabase.co
SUPABASE_SERVICE_ROLE_KEY=eyJxxxxx
GOOGLE_DRIVE_FOLDER_ID=1ABCxxxxx
ONEDRIVE_FOLDER_PATH=/CopLLM/Dokumente
OLLAMA_BASE_URL=http://localhost:11434
EMBEDDING_PROVIDER=ollama
EMBEDDING_MODEL=nomic-embed-text
TELEGRAM_CHAT_ID=-100xxxxx
```

### 5. Credential-IDs in Workflows anpassen

Nach dem Import muessen die Credential-Referenzen in den Workflow-Nodes
auf die tatsaechlich angelegten Credentials verweisen:
- Google Drive Nodes → deine Google Drive OAuth2 Credential
- Telegram Nodes → dein Telegram Bot
- OneDrive OAuth2 → deine Microsoft Graph Credential

### 6. Initialen Import ausfuehren

1. `initial-import.json` Workflow oeffnen
2. "Execute Workflow" klicken
3. Warten (bei vielen Dateien: Telegram-Benachrichtigung am Ende)
4. Pruefen: Supabase → SQL Editor → `SELECT * FROM documents_overview;`

### 7. Sync-Workflow aktivieren

1. `google-drive-sync.json` Workflow oeffnen
2. Toggle: "Active" einschalten
3. Workflow laeuft jetzt alle 5 Minuten im Hintergrund

## OCR fuer gescannte Dokumente

### Das Problem

`pdf-parse` liest nur eingebetteten Text aus PDFs.
Gescannte Dokumente (Bilder-PDFs) enthalten keinen Text → leerer Output.

Der Workflow erkennt das: Wenn weniger als 50 Zeichen extrahiert werden,
wird `[OCR_NEEDED]` als Marker gesetzt.

### Loesung 0: Gemini Embedding 2 — PDF direkt embedden (EMPFOHLEN)

**Seit Maerz 2026 die beste Loesung!**

`gemini-embedding-2-preview` ist **multimodal** — es kann PDFs (bis 6 Seiten),
Bilder, Audio und Video direkt embedden, OHNE vorher Text zu extrahieren.

Das bedeutet: Kein OCR noetig. Das Modell "sieht" das gescannte Dokument direkt.

In `.env`:
```env
EMBEDDING_PROVIDER=google
GOOGLE_EMBEDDING_MODEL=gemini-embedding-2-preview
EMBEDDING_DIMENSION=768
```

API-Call (n8n HTTP Node):
```
POST https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-2-preview:embedContent?key=API_KEY
Body:
{
  "model": "models/gemini-embedding-2-preview",
  "content": {
    "parts": [
      { "inline_data": { "mime_type": "application/pdf", "data": "BASE64_PDF_DATA" } }
    ]
  },
  "output_dimensionality": 768
}
```

| Eigenschaft | Wert |
|-------------|------|
| Max. Input | 8.192 Tokens / 6 PDF-Seiten |
| Dimensionen | 3072 default, 128-3072 konfigurierbar |
| Preis | $0.20 / 1M Tokens (Free Tier verfuegbar!) |
| Unterstuetzte Formate | Text, PDF, Bilder, Audio, Video |

**Einschraenkung:** Max. 6 Seiten pro PDF. Laengere PDFs muessen vorher gesplittet werden.

**Vorteil gegenueber OCR:** Keine Zwischenschritte, keine OCR-Fehler, versteht auch
Tabellen, Diagramme und Layouts direkt.

### Loesung 1: gemini-embedding-001 + Text-Extraktion

Fuer reine Text-Dokumente (kein Scan):

```env
EMBEDDING_PROVIDER=google
GOOGLE_EMBEDDING_MODEL=gemini-embedding-001
EMBEDDING_DIMENSION=768
```

| Eigenschaft | Wert |
|-------------|------|
| Max. Input | 2.048 Tokens |
| Preis | $0.15 / 1M Tokens |
| Nur Text | Ja |

Nutzt `taskType: RETRIEVAL_DOCUMENT` fuer bessere RAG-Qualitaet.

### Loesung 2: Tesseract OCR (lokal, kostenlos, Fallback)

Wenn kein Google API Key vorhanden oder Offline-Betrieb noetig:

```bash
sudo apt install tesseract-ocr tesseract-ocr-deu
```

Im n8n Code Node (Text extrahieren) den OCR-Block aktivieren:
```javascript
// Nach pdf-parse, wenn text.length < 50:
const { execSync } = require('child_process');
execSync(`pdftoppm -png input.pdf /tmp/page`);
text = execSync(`tesseract /tmp/page-1.png - -l deu`).toString();
```

### Loesung 3: Google Document AI (strukturierte Dokumente)

Fuer Formulare, Rechnungen, Vertraege mit Key-Value-Extraktion:

```
POST https://documentai.googleapis.com/v1/projects/PROJECT/locations/eu/processors/PROC_ID:process
Body: { "rawDocument": { "content": BASE64_PDF, "mimeType": "application/pdf" } }
```

### Empfehlung

| Szenario | Loesung |
|----------|---------|
| Gescannte PDFs (Standard) | **gemini-embedding-2-preview** (direkt embedden) |
| Text-PDFs, Office-Docs | gemini-embedding-001 + Text-Extraktion |
| Offline / kein API-Key | Tesseract OCR + nomic-embed-text (Ollama) |
| Strukturierte Formulare | Google Document AI + gemini-embedding-001 |

### Deprecated (nicht mehr verwenden)

- `text-embedding-004` — deprecated seit Jan 2026
- `text-embedding-005` — durch `gemini-embedding-001` ersetzt

## Learnings & Hacks
<!-- Ergaenze hier nach jedem Setup was dir aufgefallen ist -->
