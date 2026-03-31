# 08 — Troubleshooting

Bekannte Probleme und Loesungen. Waechst mit jedem Setup.

---

## Ollama

### Ollama nicht erreichbar aus Docker

**Symptom:** `Connection refused` beim Embedding oder LLM-Call aus Docker.

**Ursache:** Docker-Container kann `localhost` des Host nicht erreichen.

**Loesung:**
- `extra_hosts: ["host.docker.internal:host-gateway"]` in docker-compose
- URL: `http://host.docker.internal:11434` (nicht `localhost`)

### Ollama auf Raspberry Pi langsam

**Symptom:** Embedding dauert 5+ Sekunden pro Chunk.

**Loesung:**
- `nomic-embed-text` ist das leichteste Modell, schneller geht lokal nicht
- Fuer Bulk-Import: Pausen einbauen (2s), damit der Pi nicht ueberhitzt
- Alternative: Google/OpenAI Embeddings nutzen (schneller, kostet minimal)

---

## Supabase

### "Could not find the function match_documents"

**Ursache:** `init.sql` nicht vollstaendig ausgefuehrt.

**Loesung:** Im SQL Editor nochmal ausfuehren. Auf Fehlermeldungen achten.

### Embedding-Insert schlaegt fehl

**Symptom:** `invalid input syntax for type vector`

**Ursache:** Embedding wird als JSON-Array statt als String gesendet.

**Loesung:** Embedding muss als String formatiert sein: `"[0.1, 0.2, ...]"` (mit Anfuehrungszeichen)
Im n8n Code Node: `'[' + embedding.join(',') + ']'`

### Dimension Mismatch

**Symptom:** `expected 768 dimensions, not 1536`

**Ursache:** Embedding-Modell hat andere Dimension als in init.sql definiert.

**Loesung:**
- nomic-embed-text = 768
- text-embedding-3-small (OpenAI) = 1536
- text-embedding-004 (Google) = 768
- Bei Wechsel: Schema anpassen oder neues Projekt mit richtiger Dimension

---

## n8n

### Google Drive Trigger feuert nicht

**Ursache:** OAuth Token abgelaufen oder Folder ID falsch.

**Loesung:**
1. Credentials pruefen (Re-Auth)
2. Folder ID pruefen (in Google Drive URL sichtbar)
3. Manuell testen: Workflow ausfuehren, dann Datei in Ordner legen

### OneDrive Delta Token ungueltig

**Symptom:** `resyncRequired` oder `410 Gone` von Graph API.

**Loesung:** Static Data im Workflow zuruecksetzen:
n8n → Workflow → Settings → Static Data → Loeschen
Beim naechsten Lauf wird ein neuer Delta-Token geholt.

### pdf-parse gibt leeren Text zurueck

**Ursache:** PDF ist ein gescanntes Bild, kein Text-PDF.

**Loesung:** → Siehe `05-setup-n8n-sync.md` Abschnitt "OCR fuer gescannte Dokumente"

---

## Open WebUI

### Modelle werden nicht angezeigt

**Ursache:** LiteLLM Verbindung nicht konfiguriert oder Master Key falsch.

**Loesung:**
1. `curl http://localhost:4000/v1/models -H "Authorization: Bearer $LITELLM_MASTER_KEY"` testen
2. In Open WebUI: Settings → Connections → URL und Key pruefen
3. Docker: Sind beide Container im gleichen Netzwerk?

### RAG findet nichts

**Ursache:** Embedding-Modell in Open WebUI stimmt nicht mit Supabase ueberein.

**Loesung:**
- Open WebUI nutzt intern ChromaDB, nicht Supabase
- Fuer Supabase-RAG: Custom Pipeline noetig (Weg C)
- Quick-Fix: Dokumente direkt in Open WebUI hochladen (nutzt dann ChromaDB)

---

## Docker

### Port bereits belegt

**Symptom:** `bind: address already in use`

**Loesung:**
```bash
# Wer nutzt den Port?
netstat -tlnp | grep :3000
# Oder anderen Port in .env setzen
OPENWEBUI_PORT=3001
```

---

## Learnings & Hacks
<!-- Ergaenze hier nach jedem Setup was dir aufgefallen ist -->
