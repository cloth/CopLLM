# 11 — LLM-Kosten-Monitoring & Usage Dashboard

## Warum?

Ohne Kosten-Monitoring fliegst du blind:
- Kein Ueberblick welcher Kunde wie viel verbraucht
- Keine Grundlage fuer faire Abrechnung
- Kein Fruehwarnsystem bei Cost-Spikes
- Kein Vergleich zwischen Modellen (Claude Sonnet vs. Opus vs. Haiku)

## Architektur

```
Kunde → Open WebUI → LiteLLM (Virtual Key pro Kunde)
                          |
                          ↓
                    PostgreSQL (Spend-Logs)
                          |
                    +-----+------+
                    |            |
              Usage Dashboard   Telegram Alert
              (Next.js/Vercel)  (n8n Workflow)
```

**Kern-Idee:** LiteLLM trackt bereits alle API-Calls mit Kosten pro Request.
Wir muessen nur die Daten abfragen und visualisieren.

## Was LiteLLM bereits liefert

LiteLLM hat eingebautes Spend-Tracking wenn `database_url` gesetzt ist:

### Daten pro Request (automatisch)

| Feld | Beschreibung |
|------|-------------|
| `api_key` | Welcher Virtual Key (= welcher Kunde) |
| `model` | Welches Modell (claude-sonnet, claude-opus, ...) |
| `spend` | Kosten in USD fuer diesen Call |
| `total_tokens` | Input + Output Tokens |
| `prompt_tokens` | Nur Input Tokens |
| `completion_tokens` | Nur Output Tokens |
| `startTime` / `endTime` | Zeitstempel |
| `metadata` | Custom-Felder (tenant_id) |

### API-Endpoints

```bash
# Gesamtausgaben
curl http://localhost:4000/spend/logs \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY"

# Ausgaben pro Key (= pro Kunde)
curl http://localhost:4000/spend/keys \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY"

# Ausgaben pro Modell
curl "http://localhost:4000/spend/tags?start_date=2026-03-01&end_date=2026-03-31" \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY"

# Budget-Status eines Keys
curl "http://localhost:4000/key/info?key=sk-kunde-key" \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY"

# Alle Keys auflisten
curl http://localhost:4000/key/list \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY"
```

## Virtual Keys einrichten

### Key pro Kunde erstellen

```bash
curl -X POST http://localhost:4000/key/generate \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "key_alias": "copllm-mueller-gmbh",
    "max_budget": 50.0,
    "budget_duration": "1mo",
    "metadata": {"tenant_id": "mueller-gmbh"},
    "models": ["claude-sonnet", "claude-haiku", "copllm-default"],
    "tpm_limit": 100000,
    "rpm_limit": 100
  }'
```

**Wichtige Parameter:**
- `max_budget` — Monatliches Limit in USD (wird automatisch resettet)
- `budget_duration` — Reset-Intervall (`1mo`, `1d`, `7d`)
- `models` — Welche Modelle der Kunde nutzen darf
- `tpm_limit` / `rpm_limit` — Rate Limits (Tokens/Requests pro Minute)

### Key in Open WebUI verwenden

In `docker-compose.multi.yml` pro Kunde:
```yaml
environment:
  - OPENAI_API_KEYS=sk-litellm-kunde-key    # statt ${LITELLM_MASTER_KEY}
```

Das `provision.py` Script macht das automatisch.

## Usage Dashboard (3 Stufen)

### Stufe 1: CLI-basiert (sofort nutzbar)

```bash
# Top-Kunden nach Spend diesen Monat
python scripts/usage-report.py --month 2026-03

# Ausgabe:
#   Kunde              | Spend (USD) | Requests | Tokens
#   -------------------|-------------|----------|--------
#   mueller-gmbh       |       12.50 |      340 | 125.000
#   schmidt-ag         |        8.20 |      210 |  82.000
#   clx-digital        |        5.10 |      180 |  51.000
#   ---
#   GESAMT             |       25.80 |      730 | 258.000
```

### Stufe 2: Grafana (Self-Hosted, empfohlen)

LiteLLM schreibt Spend-Daten in PostgreSQL. Grafana kann direkt darauf zugreifen.

**Setup:**
1. Grafana als Docker Container hinzufuegen (~100MB RAM)
2. PostgreSQL Data Source auf `LITELLM_DATABASE_URL`
3. Dashboard mit vorgefertigten Panels

**Dashboard-Panels:**

| Panel | Typ | Query-Basis |
|-------|-----|-------------|
| Gesamtkosten (Monat) | Stat | `SUM(spend) FROM spend_logs WHERE ...` |
| Kosten pro Kunde | Bar Chart | `GROUP BY api_key` |
| Kosten pro Modell | Pie Chart | `GROUP BY model` |
| Kosten-Verlauf (30 Tage) | Time Series | `GROUP BY DATE(startTime)` |
| Top 10 teuerste Requests | Table | `ORDER BY spend DESC LIMIT 10` |
| Token-Verbrauch | Time Series | `SUM(total_tokens) GROUP BY DATE` |
| Budget-Auslastung pro Kunde | Gauge | `spend / max_budget * 100` |
| Modell-Verteilung | Pie Chart | `COUNT(*) GROUP BY model` |
| Avg. Response Time | Time Series | `AVG(endTime - startTime)` |
| Requests pro Stunde | Heatmap | `COUNT(*) GROUP BY HOUR, DOW` |

**Docker-Compose Ergaenzung:**
```yaml
grafana:
  image: grafana/grafana-oss
  container_name: copllm-grafana
  restart: unless-stopped
  ports:
    - "127.0.0.1:3001:3000"
  environment:
    - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_PASSWORD:-change-me}
  volumes:
    - grafana-data:/var/lib/grafana
  networks:
    - copllm-net
```

Zugriff: Ueber Caddy als `grafana.clx-digital.de` (IP-Whitelist!).

### Stufe 3: Custom Dashboard (Phase 2+)

Next.js App auf Vercel die LiteLLM API abfragt:

```
/dashboard
  ├── /overview        — Gesamtkosten, Trend, Modellverteilung
  ├── /customers       — Per-Kunde Spend, Budget-Status
  ├── /customers/:id   — Detail: Requests, Tokens, Modelle, Timeline
  ├── /models          — Vergleich: Kosten/Token, Latenz, Nutzung
  └── /alerts          — Budget-Warnungen, Anomalien
```

**Datenquelle:** LiteLLM REST API (`/spend/logs`, `/spend/keys`, `/key/info`)
**Auth:** Supabase Auth (nur Admin-Zugang)

## Alerting

### Budget-Warnung via n8n

n8n Workflow der taeglich laeuft:

1. **Schedule Trigger** (taeglich 08:00)
2. **HTTP Request** → `GET /key/list` (alle Keys mit Budget-Info)
3. **Filter** → Keys wo `spend > max_budget * 0.8` (80% verbraucht)
4. **Telegram** → Nachricht: "Mueller GmbH hat 80% des Budgets verbraucht (40/50 USD)"

### Cost-Spike Alert

1. **Schedule Trigger** (stuendlich)
2. **HTTP Request** → `GET /spend/logs?start_date=today`
3. **Code Node** → Vergleich mit Durchschnitt der letzten 7 Tage
4. **Wenn Spend > 2x Durchschnitt** → Telegram Alert

## Abrechnung

### Kosten berechnen (Beispiel)

```
Kunde: Mueller GmbH
Monat: Maerz 2026

LLM-Kosten (Claude Sonnet):     12.50 USD ≈ 11.50 EUR
LLM-Kosten (Claude Haiku):       3.20 USD ≈  2.95 EUR
                                 ─────────────────────
LLM-Kosten gesamt:                          14.45 EUR

Infrastruktur-Anteil:                        5.00 EUR
(1 WebUI Container auf geteiltem Server)

Monatlicher Aufschlag:                     +30.00 EUR
(Support, Updates, Monitoring)
                                 ═════════════════════
Rechnung an Kunde:                          49.45 EUR
```

### Preismodelle

| Plan | Inklusiv-Tokens | Preis/Monat | Ueber-Tokens |
|------|----------------|-------------|--------------|
| Starter | 100.000 | 199 EUR | 0.002 EUR/1K |
| Business | 500.000 | 399 EUR | 0.0015 EUR/1K |
| Enterprise | Unlimitiert | Individuell | — |

## Wichtige Befehle

```bash
# LiteLLM Spend-Daten abfragen
curl http://localhost:4000/spend/keys -H "Authorization: Bearer $LITELLM_MASTER_KEY"

# Key-Budget pruefen
curl "http://localhost:4000/key/info?key=sk-kunde-key" -H "Authorization: Bearer $LITELLM_MASTER_KEY"

# Key-Budget erhoehen
curl -X POST http://localhost:4000/key/update \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -d '{"key": "sk-kunde-key", "max_budget": 100.0}'

# Grafana starten
docker compose -f docker-compose.multi.yml up -d grafana
```

## Learnings & Hacks
<!-- Ergaenze nach der ersten Monatsabrechnung -->
