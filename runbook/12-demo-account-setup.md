# 12 — Demo-Account Setup (7-Tage-Trial)

Dieses Runbook beschreibt den vollstaendigen Prozess fuer einen kontrollierten
7-Tage-Demo-Zugang fuer potenzielle Kunden.

## Architektur-Prinzip

Demo-Accounts sind eine **neue Tenant-Klasse** (`plan = 'demo'`) neben den
Bestandskunden. Die bestehende Infrastruktur wird nicht veraendert — Demo-Limits
greifen ausschliesslich ueber den LiteLLM Virtual Key.

```
Bestandskunde:  plan=starter/business  → Sonnet, 50 EUR/Monat, kein Ablauf
Demo-Kunde:     plan=demo              → Haiku, 0.50 EUR/Tag, 7 Tage Ablauf
```

## Voraussetzungen

- `LITELLM_DATABASE_URL` muss in `.env` gesetzt sein (Pflicht fuer Virtual Keys)
- LiteLLM laeuft und ist unter `$LITELLM_URL` erreichbar
- Supabase Schema aktualisiert: `psql $SUPABASE_DB_URL -f supabase/init.sql`

## Demo-Account anlegen

```bash
# Demo-Tenant mit allen Limits anlegen
python scripts/provision.py add demo-mueller demo.ki.clx-digital.de "Müller GmbH" --plan demo

# Config generieren und Container starten
python scripts/provision.py generate
python scripts/provision.py deploy demo-mueller
```

**Was passiert intern:**
- LiteLLM Virtual Key wird mit diesen Einschraenkungen erstellt:
  - Modelle: `claude-haiku` (kein Sonnet, kein Opus)
  - Budget: 0.50 EUR/Tag
  - Ablauf: 168h (7 Tage) — danach ist der Key automatisch ungueltig
  - Rate-Limit: 10 Requests/Minute, max. 2 parallele Anfragen
- Tenant-Eintrag in DB: `status=trial`, `trial_starts_at=NOW()`, `trial_expires_at=NOW()+7d`
- Eigener Open WebUI Container mit Demo-Banner und Haiku-Modell-Filter

## Demo-Ablauf automatisieren (Cron)

```bash
# Einmalig einrichten (auf dem Host, nicht im Container)
crontab -e

# Taeglich um 02:00 Uhr pruefen
0 2 * * * python3 /opt/copllm/scripts/expire-demos.py >> /var/log/copllm-expiry.log 2>&1
```

**Was expire-demos.py macht:**
1. Findet alle `plan=demo, status=trial` Tenants mit `trial_expires_at < NOW()`
2. Loescht den LiteLLM Virtual Key → sofortige API-Sperrung
3. Setzt `status=suspended`
4. DSGVO-Cleanup nach 30 Tagen: loescht alle Dokumente, Chunks, Vektoren und den Tenant-Eintrag

## Demo manuell beenden

```bash
# Sofort deaktivieren (z.B. bei Missbrauch)
python scripts/provision.py remove demo-mueller
```

## Demo-Status pruefen

```sql
-- Demo-Dashboard: alle Trial-Accounts im Blick
SELECT * FROM demo_overview;

-- Ergebnis:
-- tenant_id     | display_name | status | demo_start | demo_ablauf | verbleibend | hochgeladene_dateien | chunks_gesamt
-- demo-mueller  | Müller GmbH  | trial  | 2026-04-04 | 2026-04-11  | 6 Tage      | 3                    | 87
```

## Checkliste vor erstem Demo-Launch

| Punkt | Check |
|-------|-------|
| `LITELLM_DATABASE_URL` in `.env` gesetzt | [ ] |
| LiteLLM startet ohne Fehler: `docker logs copllm-litellm` | [ ] |
| Test-Key erstellen und pruefen (siehe unten) | [ ] |
| Cronjob fuer expire-demos.py eingerichtet | [ ] |
| Supabase Schema aktualisiert (init.sql neu ausgefuehrt) | [ ] |
| Demo-Datenschutzerklaerung vorhanden | [ ] |
| Slack-Alerting konfiguriert (`SLACK_WEBHOOK_URL`) | [ ] |

## Test: Demo-Key manuell pruefen

```bash
# 1. Demo-Key erstellen
curl -X POST http://localhost:4000/key/generate \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "key_alias": "test-demo",
    "models": ["claude-haiku"],
    "max_budget": 0.50,
    "budget_duration": "1d",
    "duration": "168h",
    "rpm_limit": 10
  }'

# 2. Anfrage mit Demo-Key → muss funktionieren
curl -X POST http://localhost:4000/v1/chat/completions \
  -H "Authorization: Bearer sk-demo-xxxxx" \
  -d '{"model": "claude-haiku", "messages": [{"role": "user", "content": "Hallo"}]}'

# 3. Anfrage mit Sonnet → muss mit 403 abgelehnt werden
curl -X POST http://localhost:4000/v1/chat/completions \
  -H "Authorization: Bearer sk-demo-xxxxx" \
  -d '{"model": "claude-sonnet", "messages": [{"role": "user", "content": "Hallo"}]}'
# Erwartet: {"error": {"message": "Model not allowed for key", "code": 403}}

# 4. Kosten pruefen
curl http://localhost:4000/spend/logs \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY"
```

## Kosten-Kalkulation

| Szenario | Kosten/Tag | Kosten/Woche |
|----------|-----------|--------------|
| 1 Demo-User aktiv (0.50 EUR Limit) | max. 0.50 EUR | max. 3.50 EUR |
| 10 Demo-User gleichzeitig | max. 5.00 EUR | max. 35.00 EUR |
| 50 Demo-User (Worst Case) | max. 25.00 EUR | max. 175.00 EUR |
| Globales Safety-Net | 500 EUR/Monat | — |

Embedding-Kosten (Gemini) laufen separat ueber Google Cloud — nicht in LiteLLM trackbar.
Orientierungswert: 10 PDFs a 5 MB ≈ 0.10–0.30 EUR Embedding-Kosten.

## DSGVO-Hinweise

- Dokumente bleiben 30 Tage nach Demo-Ablauf gespeichert (Nachfragen moeglich)
- Danach vollstaendige Loeschung durch expire-demos.py
- Gemini Embedding: Dokumente verlassen EU (Google API) → in Datenschutzerklaerung kommunizieren
- Supabase: Frankfurt (eu-central-1) → DSGVO-konform

## Learnings & Hacks

- `LITELLM_DATABASE_URL` vergessen → kein einziger Virtual Key funktioniert nach Neustart
- LiteLLM-Key-Ablauf (`duration`) ist serverseitig — kein Cron noetig fuer die API-Sperrung,
  aber der Cron braucht man fuer den DB-Status und den DSGVO-Cleanup
- Open WebUI zeigt Budget-Fehler als normale Fehlermeldung im Chat — fuer Demo ausreichend
- `MODEL_FILTER_LIST` in Open WebUI nur wirksam wenn `ENABLE_MODEL_FILTER=true` gesetzt ist
