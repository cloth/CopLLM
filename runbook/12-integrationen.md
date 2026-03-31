# 12 — Dokumentenquellen & Integrationen

## Uebersicht

CopLLM synchronisiert Firmendokumente aus verschiedenen Quellen automatisch in die Vektordatenbank. Neue Dokumente, Aenderungen und Loeschungen werden erkannt und verarbeitet.

| Quelle | Status | n8n Node | Workflow-Datei | Verbreitung (DE KMU) |
|--------|--------|----------|----------------|---------------------|
| Google Drive | Fertig | Ja (Trigger) | `google-drive-sync.json` | 30-40% |
| OneDrive | Fertig | Ja (Graph API) | `google-drive-sync.json` | 40-50% |
| SharePoint | Fertig | Ja (Graph API) | via OneDrive Integration | 50-60% |
| **Nextcloud** | **Fertig** | **Ja (WebDAV)** | **`nextcloud-sync.json`** | **20-30%** |
| **Email/IMAP** | **Fertig** | **Ja** | **`email-sync.json`** | **90%+** |
| Dropbox | Template | Ja | Anpassung von Drive Workflow | 15-20% |
| Confluence | Template | Ja | Anpassung noetig | 10-15% |
| Notion | Template | Ja | Anpassung noetig | 5-8% |
| DocuWare | Geplant | Nein (HTTP) | Custom Workflow | 5-10% |
| Lokaler NAS | Geplant | Ja (SFTP) | Custom Workflow | 40-55% |

## Phase 1: Kern-Integrationen

### Google Drive (fertig)

**Workflow:** `n8n/google-drive-sync.json`

- Google Drive Trigger (fileCreated/Updated) — Echtzeit
- OAuth2 Credentials in n8n
- Unterstuetzte Formate: PDF, DOCX, TXT, MD, XLSX, PPTX
- OCR fuer gescannte PDFs via Gemini Embedding 2

**Setup:**
1. Google Cloud Console → OAuth2 Client erstellen
2. n8n → Credentials → Google Drive OAuth2
3. Workflow importieren → Credential verknuepfen → Aktivieren

### OneDrive + SharePoint (fertig)

**Workflow:** `n8n/google-drive-sync.json` (selber Workflow, zweiter Trigger)

- Schedule Trigger (5 Min) + Microsoft Graph Delta API
- Delta-Token wird in n8n Static Data persistiert
- **SharePoint funktioniert automatisch** — OneDrive und SharePoint nutzen dieselbe Graph API. SharePoint Document Libraries sind ueber denselben Endpoint erreichbar.

**Setup:**
1. Azure Portal → App Registration → Graph API Permissions (Files.Read.All)
2. n8n → Credentials → Microsoft OAuth2
3. Workflow importieren → Credential verknuepfen → Aktivieren

**Hinweis SharePoint:** Wenn der Kunde sagt "wir nutzen OneDrive", sind die geteilten Dokumente oft in SharePoint. Die Graph API greift auf beides zu — kein separater Workflow noetig.

### Nextcloud (fertig)

**Workflow:** `n8n/nextcloud-sync.json`

- Schedule Trigger (5 Min) + Nextcloud WebDAV API
- Delta-Erkennung ueber `lastModified` Zeitstempel
- n8n hat nativen Nextcloud Node (List, Download)
- **Wichtigste DACH-Integration!** Nextcloud ist Standard bei datenschutzbewussten KMUs (Anwaelte, Steuerberater, Aerzte, Behoerden)

**Setup:**
1. Nextcloud → Einstellungen → App-Passwort generieren
2. n8n → Credentials → NextCloud API (URL + User + App-Passwort)
3. Workflow importieren → `watchFolder` auf Kunden-Ordner setzen → Aktivieren

**Nextcloud Besonderheiten:**
- WebDAV ist etwas langsamer als Google/Microsoft APIs
- Keine natuerlichen Trigger — Polling alle 5 Min
- Vorteil: Komplett self-hosted, kein Cloud-Abhaengigkeit
- Self-hosted Nextcloud = Dokumente verlassen nie den Server (DSGVO-Argument!)

### Email/IMAP (fertig)

**Workflow:** `n8n/email-sync.json`

- IMAP Trigger — prueft Postfach auf neue Emails
- Extrahiert Attachments (PDF, DOCX, TXT, etc.)
- Email-Metadaten (Absender, Betreff, Datum) werden als Kontext mitgespeichert
- Ideal fuer: Vertraege, Rechnungen, Angebote die per Email kommen

**Setup:**
1. n8n → Credentials → IMAP (Server, Port, User, Passwort)
2. Workflow importieren → Postfach konfigurieren → Aktivieren

**Empfehlung:** Dediziertes Postfach einrichten (z.B. `ki@firma.de`), an das relevante Dokumente weitergeleitet werden. Nicht das gesamte Firmen-Postfach scannen!

**IMAP-Server Beispiele:**

| Provider | Server | Port |
|----------|--------|------|
| Gmail | imap.gmail.com | 993 |
| Outlook/M365 | outlook.office365.com | 993 |
| Ionos/1&1 | imap.ionos.de | 993 |
| Strato | imap.strato.de | 993 |
| All-Inkl | imap.all-inkl.com | 993 |

## Phase 2: Quick-Win Integrationen

### Dropbox Business

**Aufwand:** Gering — n8n hat nativen Dropbox Node mit Trigger.

1. n8n → Credentials → Dropbox OAuth2
2. Bestehenden Google Drive Workflow kopieren
3. Trigger ersetzen: Dropbox Trigger (File Created/Updated)
4. Download Node ersetzen: Dropbox Download
5. `source` auf `'dropbox'` setzen

**Tipp:** Dropbox API ist sehr aehnlich zu Google Drive API. Der Hauptunterschied ist nur der Trigger + Download Node, die Pipeline dahinter (Chunking, Embedding, Supabase) ist identisch.

### Confluence

**Aufwand:** Gering — n8n hat nativen Confluence Node.

1. n8n → Credentials → Atlassian (API Token)
2. Confluence Node: Pages auflisten (Space Key filtern)
3. Page Content als HTML holen → in Text konvertieren
4. Gleiche Pipeline: Chunken → Embedden → Supabase

**Besonderheit:** Confluence Seiten haben HTML-Content, nicht Dateien. Der Text muss aus HTML extrahiert werden (HTML-Tags strippen). n8n Code Node mit einfachem Regex reicht.

```javascript
// HTML zu Text (einfach)
const text = htmlContent.replace(/<[^>]*>/g, ' ').replace(/\s+/g, ' ').trim();
```

### Notion

**Aufwand:** Gering — n8n hat nativen Notion Node, exzellente API.

1. n8n → Credentials → Notion API (Internal Integration Token)
2. Notion: Database Query oder Page Search
3. Notion Blocks als Text extrahieren (Notion API liefert strukturierte Blocks)
4. Gleiche Pipeline: Chunken → Embedden → Supabase

**Notion-Tipp:** Notion Pages bestehen aus "Blocks". Fuer RAG am besten alle Blocks eines Pages in einen Text zusammenfuegen und dann chunken.

## Pipeline-Architektur (alle Quellen)

Jede Integration folgt demselben Muster:

```
1. TRIGGER    → Neue/geaenderte Datei erkennen
2. DOWNLOAD   → Datei-Inhalt holen
3. EXTRACT    → Text aus Datei extrahieren (+ OCR fuer Scans)
4. CHUNK      → Text in 500-Zeichen Abschnitte zerlegen
5. EMBED      → Chunks vektorisieren (Ollama/Google/OpenAI)
6. STORE      → In Supabase speichern (mit tenant_id)
7. LOG        → sync_log Eintrag schreiben
8. NOTIFY     → Telegram Benachrichtigung (optional)
```

**Schritte 3-8 sind bei allen Quellen identisch.** Nur der Trigger (1) und Download (2) unterscheiden sich. Deshalb ist eine neue Integration hauptsaechlich:
- Trigger konfigurieren (n8n Node oder Schedule + API)
- Download-Methode anpassen
- `source` Feld auf den richtigen Enum-Wert setzen

## Pro Kunde konfigurieren

Jeder Kunde nutzt andere Quellen. Die `tenants` Tabelle hat ein `config` JSONB-Feld:

```json
{
  "sources": [
    {
      "type": "nextcloud",
      "url": "https://cloud.mueller-gmbh.de",
      "folder": "/Dokumente/KI-Wissen"
    },
    {
      "type": "email",
      "imap_server": "imap.ionos.de",
      "mailbox": "ki@mueller-gmbh.de"
    }
  ]
}
```

Das `provision.py` Script kann diese Config auslesen und die passenden n8n Workflows pro Kunde erstellen (Phase 2).

## Supabase doc_source Enum

Alle Quellen sind im Schema registriert:

```sql
CREATE TYPE doc_source AS ENUM (
    'google_drive', 'onedrive', 'sharepoint',
    'nextcloud', 'email', 'dropbox',
    'confluence', 'notion', 'manual_upload'
);
```

## Geplante Integrationen (Phase 3)

### Lokaler NAS / Fileserver (SMB/SFTP)

Viele deutsche KMUs haben einen Synology/QNAP NAS oder Windows Fileserver als primaere Dokumentenablage. Integration via:

- **SFTP:** n8n hat SFTP Node. Schedule Trigger + Dateiliste vergleichen.
- **SMB:** Kein nativer n8n Node. Workaround: rclone oder Syncthing als Sync-Agent der NAS-Dateien in einen lokalen Ordner spiegelt, dann via Filesystem-Watch verarbeiten.
- **Synology Drive:** Synology hat eine REST API. Custom HTTP Workflow moeglich.

### DocuWare

DMS-Marktfuehrer in Deutschland (Steuerberater, Handwerk, Fertigung). REST API seit Version 7. Custom HTTP Workflow in n8n:

1. `GET /FileCabinets/{id}/Documents` — Dokumente auflisten
2. `GET /Documents/{id}/FileDownload` — Datei herunterladen
3. Gleiche Pipeline dahinter

### ELO / d.velop

Deutsche DMS-Anbieter. d.velop hat die bessere API (cloud-first). ELO ist staerker on-premise. Bei Bedarf Custom HTTP Integration.

### DATEV

Relevant fuer 100% aller Steuerberater. API ist restriktiv und erfordert DATEV-Partnerschaft. **Workaround:** DATEV-Export in einen ueberwachten Ordner (Nextcloud oder NAS), dann via bestehende Nextcloud/SFTP Integration einlesen.

## Learnings & Hacks
<!-- Ergaenze nach jeder neuen Integration -->
