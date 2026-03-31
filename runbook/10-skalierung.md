# 10 — Skalierung auf 1000+ Kunden

## Ausgangslage

Aktuelles Setup: 1 Docker-Container pro Kunde (~400MB RAM).
Funktioniert fuer ~10 Kunden auf einem Server, skaliert nicht weiter.

## Engpaesse

| Problem | Aktuell | Bei 1000 Kunden |
|---------|---------|-----------------|
| Open WebUI Container | 1 pro Kunde | 400GB RAM |
| docker-compose.multi.yml | Haendisch per sed | 40.000 Zeilen |
| Supabase | 1 Projekt pro Kunde | 25.000 EUR/Monat |
| n8n Workflows | 1 shared Instanz | 1000 Workflows |
| LLM-Kosten | Global $50 Budget | Kein Per-Kunde Tracking |

## Phase 1: Foundation (10 → 50 Kunden)

### Was sich aendert

1. **Eine Supabase-Instanz** statt N Projekte — `tenant_id` isoliert Daten
2. **tenants-Tabelle** als Single Source of Truth fuer alle Kunden
3. **provision.py** ersetzt add-customer.sh — DB-driven, generiert Configs aus Templates
4. **LiteLLM Virtual Keys** — Per-Kunde API-Key mit eigenem Budget
5. **Multi-Server** — Shared Services auf Control-Server, WebUI auf Worker-Servern

### Neuen Kunden anlegen (neu)

```bash
# Statt: ./scripts/add-customer.sh mueller-gmbh ki.mueller-gmbh.de "Mueller GmbH"
# Jetzt:
python scripts/provision.py add mueller-gmbh ki.mueller-gmbh.de "Mueller GmbH"
python scripts/provision.py generate
python scripts/provision.py deploy mueller-gmbh
```

### Dateien

| Datei | Aenderung |
|-------|-----------|
| `supabase/init.sql` | + tenants Tabelle, sync_log tenant_id, echte RLS |
| `scripts/provision.py` | Neues Provisioning-Script (ersetzt add-customer.sh) |
| `scripts/templates/*.j2` | Jinja2-Templates fuer Compose + Caddy |
| `litellm/config.yaml` | + database_url fuer Virtual Keys |

### Kosten

~70 EUR/Monat (1x CX41 + 5-10x CX31 bei Hetzner + 1x Supabase Pro)

## Phase 2: Operational Maturity (50 → 200 Kunden)

1. **n8n Workflow-Templating** — Per-Kunde Workflows via n8n REST API erstellen
2. **Admin-Portal** — Next.js App auf Vercel (Kundenliste, Spend, Provisioning)
3. **Caddy Dynamic Config** — Admin API statt statisches Caddyfile
4. **Monitoring** — Uptime Kuma + Telegram-Alerts
5. **LLM Usage Dashboard** — Kosten-Monitoring und Abrechnung (siehe unten)

Kosten: ~200-400 EUR/Monat

## Phase 3: True Multi-Tenancy (200 → 1000+)

1. **Custom Chat Frontend** — Next.js ersetzt Open WebUI (kein Multi-Tenancy in OWUI)
2. **Wildcard-Domain** — `kunde.copllm.de` + Custom-Domain via CNAME
3. **Sync-Worker** — Eigener Service ersetzt n8n fuer Doc-Sync
4. **DB-Partitioning** — documents Tabelle nach tenant_id partitionieren

Von ~200 Containern auf ~5. RAM von 60-100GB auf <4GB.
Kosten: ~300-600 EUR/Monat

## Entscheidungen

- **Open WebUI Multi-Tenancy?** Existiert nicht. Phase 1-2: Container pro Kunde. Phase 3: Eigenes Frontend.
- **Kubernetes?** Nein. Docker Compose + Multi-Server reicht. K8s Overhead lohnt nicht als Solo-Operator.
- **Open WebUI forken?** Nein. Wartung zu hoch. Eigenes Frontend in Phase 3.
- **Billing?** LiteLLM Virtual Keys (eingebaut, kein Custom-Code noetig).

## LLM-Kosten-Monitoring

Siehe `runbook/11-llm-kosten-monitoring.md` fuer das vollstaendige Konzept.

## Learnings & Hacks
<!-- Ergaenze nach jedem Skalierungsschritt -->
