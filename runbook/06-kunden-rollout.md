# 06 — Kunden-Rollout

## Rollout-Checkliste

### Vor dem Rollout
- [ ] Kundenname und Domain geklaert
- [ ] Welche Dokumentenquellen? (Google Drive / OneDrive / beides)
- [ ] Wie viele Nutzer?
- [ ] Welche Dokumente sollen rein? (Ordner definieren)
- [ ] Sensibilitaet der Daten? (→ lokal vs. Cloud LLM)
- [ ] Budget/Paket geklaert

### Infrastruktur aufsetzen
- [ ] Supabase Projekt erstellen (Frankfurt!) → `01-setup-supabase.md`
- [ ] init.sql ausfuehren
- [ ] `tenant_id` auf Kundennamen setzen
- [ ] Hetzner VPS bestellen (oder Docker lokal)
- [ ] Domain DNS auf Server zeigen
- [ ] `.env` mit Kunden-spezifischen Werten fuellen
- [ ] `docker compose up -d`
- [ ] HTTPS pruefen (Caddy)

### Dokumente einrichten
- [ ] Google Drive / OneDrive Ordner definieren
- [ ] n8n Credentials fuer Kunden-Drive einrichten
- [ ] n8n Workflows importieren + Credentials verknuepfen
- [ ] Initialen Import ausfuehren
- [ ] Pruefen: `SELECT * FROM documents_overview;`

### Open WebUI konfigurieren
- [ ] Admin-Account erstellen
- [ ] System-Prompt mit Kundennamen anpassen
- [ ] Nutzer-Accounts anlegen (oder Einladungs-Links)
- [ ] Registrierung deaktivieren
- [ ] Modelle pruefen (LiteLLM Verbindung)
- [ ] RAG-Settings setzen

### Testen
- [ ] 5 Test-Fragen die korrekt beantwortet werden muessen
- [ ] 3 Fragen die NICHT in Dokumenten stehen (→ "Keine Information")
- [ ] Neues Dokument in Drive legen → nach 5 Min in Supabase?
- [ ] Dokument loeschen → Chunks weg?

### DSGVO
- [ ] AVV mit Anthropic (console.anthropic.com → Privacy)
- [ ] AVV mit Supabase (supabase.com/privacy)
- [ ] Datenschutzerklaerung des Kunden aktualisiert?
- [ ] Welche Daten wo gespeichert: dokumentiert?
- [ ] Row Level Security aktiv?

### Uebergabe
- [ ] Bedienungsanleitung uebergeben (max. 1 Seite)
- [ ] Schulung durchgefuehrt (60 Min)
- [ ] Zugangsdaten-Dokument uebergeben
- [ ] Support-Kontakt kommuniziert
- [ ] Erste Rechnung gestellt

## Was ist automatisiert vs. manuell?

| Schritt | Status | Ziel |
|---------|--------|------|
| Supabase Projekt erstellen | Manuell | Spaeter: Script |
| Schema initialisieren | `supabase/init.sql` | Automatisiert |
| Docker Stack starten | `docker compose up -d` | Automatisiert |
| n8n Workflows importieren | Manuell (Import JSON) | Spaeter: n8n API |
| Credentials einrichten | Manuell | Bleibt manuell (OAuth) |
| System-Prompt anpassen | Manuell | Spaeter: Template-Script |
| Nutzer anlegen | Manuell | Spaeter: Open WebUI API |

## Multi-Kunden Setup (Hybrid-Architektur)

Alle Kunden laufen auf **einem Ubuntu-Server** mit Docker:

```
1x Caddy          → routet Subdomains
1x LiteLLM        → shared fuer alle Kunden
Nx Open WebUI     → pro Kunde eigene Instanz + eigenes Volume
Nx Supabase       → pro Kunde eigenes Projekt (Frankfurt)
1x n8n            → laeuft mit auf dem Docker-Server
```

### Neuen Kunden hinzufuegen (5 Schritte)

1. **docker-compose.multi.yml:** Block "KUNDE KOPIERVORLAGE" kopieren, Namen anpassen
2. **caddy/Caddyfile.multi:** Neue Domain + reverse_proxy Zeile
3. **.env:** Neuen `OPENWEBUI_SECRET_KUNDE_X` Key generieren (`openssl rand -hex 32`)
4. **Supabase:** Neues Projekt in Frankfurt erstellen, `init.sql` ausfuehren
5. **Starten:** `docker compose -f docker-compose.multi.yml up -d`

### DNS pro Kunde

Kunde richtet einen **A-Record** auf die Server-IP ein:
```
ki.kundendomaene.de → A → 1.2.3.4 (dein Server)
```
Caddy holt sich automatisch ein Let's Encrypt Zertifikat.

Falls Kunde keine eigene Domain will:
```
kunde-name.ai.clx-digital.de → CNAME → dein-server.clx-digital.de
```

### Ressourcen pro Kunde

| Komponente | RAM | Disk |
|------------|-----|------|
| Open WebUI Instanz | ~300-500 MB | ~200 MB + Uploads |
| Supabase (extern) | 0 MB (Cloud) | — |

**Hetzner CX31 (8 GB RAM):** Realistisch 5-8 Kunden
**Hetzner CX41 (16 GB RAM):** Realistisch 10-15 Kunden

## Learnings & Hacks
<!-- Ergaenze hier nach jedem Setup was dir aufgefallen ist -->
