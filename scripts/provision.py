#!/usr/bin/env python3
"""
CopLLM — Kunden-Provisioning (DB-driven)

Ersetzt das alte add-customer.sh. Liest/schreibt in die tenants-Tabelle
und generiert alle Config-Dateien aus Jinja2-Templates.

Voraussetzungen:
    pip install psycopg2-binary jinja2 requests

Befehle:
    python scripts/provision.py add <kunde-id> <domain> [firmenname] [--plan demo]
    python scripts/provision.py remove <kunde-id>
    python scripts/provision.py list
    python scripts/provision.py generate
    python scripts/provision.py deploy <kunde-id>

Umgebungsvariablen:
    SUPABASE_DB_URL          — PostgreSQL Connection String
    LITELLM_MASTER_KEY       — Fuer Virtual Key Erstellung
    LITELLM_URL              — LiteLLM API URL (default: http://localhost:4000)
"""

import argparse
import os
import secrets
import sys
import json
from datetime import datetime, timezone
from pathlib import Path

try:
    import psycopg2
    import psycopg2.extras
except ImportError:
    print("FEHLER: psycopg2 nicht installiert. Ausfuehren: pip install psycopg2-binary")
    sys.exit(1)

try:
    from jinja2 import Environment, FileSystemLoader
except ImportError:
    print("FEHLER: jinja2 nicht installiert. Ausfuehren: pip install jinja2")
    sys.exit(1)

# --- Konfiguration ---
PROJECT_ROOT = Path(__file__).resolve().parent.parent
TEMPLATES_DIR = PROJECT_ROOT / "scripts" / "templates"
COMPOSE_OUTPUT = PROJECT_ROOT / "docker-compose.multi.yml"
CADDY_OUTPUT = PROJECT_ROOT / "caddy" / "Caddyfile.multi"

LITELLM_URL = os.environ.get("LITELLM_URL", "http://localhost:4000")
LITELLM_MASTER_KEY = os.environ.get("LITELLM_MASTER_KEY", "")

# Demo-Limits
DEMO_DAILY_BUDGET_EUR = 0.50
DEMO_DURATION_HOURS = 168       # 7 Tage
DEMO_RPM_LIMIT = 10
DEMO_MAX_PARALLEL = 2
DEMO_MAX_TOKENS = 2048


def get_db_connection():
    """Verbindung zur Supabase PostgreSQL Datenbank."""
    db_url = os.environ.get("SUPABASE_DB_URL")
    if not db_url:
        print("FEHLER: SUPABASE_DB_URL Umgebungsvariable nicht gesetzt")
        sys.exit(1)
    return psycopg2.connect(db_url)


def get_all_tenants(conn):
    """Alle aktiven Tenants aus der Datenbank laden."""
    with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
        cur.execute(
            "SELECT * FROM tenants WHERE status = 'active' ORDER BY created_at"
        )
        return cur.fetchall()


def add_tenant(conn, tenant_id, domain, display_name, plan="starter"):
    """Neuen Kunden in die tenants-Tabelle einfuegen."""
    webui_secret = secrets.token_hex(32)
    is_demo = (plan == "demo")

    # LiteLLM Virtual Key erstellen (optional, wenn LiteLLM laeuft)
    litellm_api_key, litellm_key_id = create_litellm_key(tenant_id, plan=plan)

    with conn.cursor() as cur:
        # Pruefen ob Kunde schon existiert
        cur.execute("SELECT id FROM tenants WHERE id = %s", (tenant_id,))
        if cur.fetchone():
            print(f"FEHLER: Kunde '{tenant_id}' existiert bereits")
            sys.exit(1)

        cur.execute("SELECT id FROM tenants WHERE domain = %s", (domain,))
        if cur.fetchone():
            print(f"FEHLER: Domain '{domain}' ist bereits vergeben")
            sys.exit(1)

        if is_demo:
            cur.execute(
                """
                INSERT INTO tenants (
                    id, display_name, domain, status, plan,
                    webui_secret, litellm_api_key, litellm_key_id,
                    trial_starts_at, trial_expires_at
                )
                VALUES (%s, %s, %s, 'trial', 'demo', %s, %s, %s, NOW(), NOW() + INTERVAL '7 days')
                """,
                (tenant_id, display_name, domain, webui_secret, litellm_api_key, litellm_key_id),
            )
        else:
            cur.execute(
                """
                INSERT INTO tenants (id, display_name, domain, webui_secret, litellm_api_key, plan)
                VALUES (%s, %s, %s, %s, %s, %s)
                """,
                (tenant_id, display_name, domain, webui_secret, litellm_api_key, plan),
            )
    conn.commit()

    print(f"  Kunde '{tenant_id}' angelegt")
    print(f"  Plan:        {plan}")
    print(f"  Domain:      {domain}")
    print(f"  WebUI Secret: {webui_secret[:8]}...")
    if litellm_api_key:
        print(f"  LiteLLM Key:  {litellm_api_key[:12]}...")
    else:
        print("  LiteLLM Key:  (nicht erstellt — LiteLLM nicht erreichbar)")

    if is_demo:
        print(f"  Demo-Budget:  {DEMO_DAILY_BUDGET_EUR} EUR/Tag")
        print(f"  Demo-Modell:  claude-haiku (Demo only)")
        print(f"  Demo-Ablauf:  in 7 Tagen")
        print(f"  Rate-Limit:   {DEMO_RPM_LIMIT} Requests/Minute")

    return tenant_id


def remove_tenant(conn, tenant_id):
    """Kunden als suspended markieren und LiteLLM Key loeschen."""
    with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
        cur.execute("SELECT id, litellm_api_key FROM tenants WHERE id = %s", (tenant_id,))
        row = cur.fetchone()
        if not row:
            print(f"FEHLER: Kunde '{tenant_id}' nicht gefunden")
            sys.exit(1)

        # LiteLLM Key loeschen falls vorhanden
        if row["litellm_api_key"]:
            _delete_litellm_key(row["litellm_api_key"])

        cur.execute(
            "UPDATE tenants SET status = 'suspended' WHERE id = %s", (tenant_id,)
        )
    conn.commit()
    print(f"  Kunde '{tenant_id}' suspendiert (Container wird beim naechsten generate entfernt)")


def list_tenants(conn):
    """Alle Kunden auflisten."""
    with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
        cur.execute("SELECT * FROM tenants ORDER BY created_at")
        tenants = cur.fetchall()

    if not tenants:
        print("  Keine Kunden vorhanden")
        return

    print(f"  {'ID':<22} {'Domain':<30} {'Status':<12} {'Plan':<10} {'Demo-Ablauf'}")
    print(f"  {'-'*22} {'-'*30} {'-'*12} {'-'*10} {'-'*20}")
    for t in tenants:
        ablauf = ""
        if t.get("trial_expires_at"):
            ablauf = str(t["trial_expires_at"])[:10]
        print(f"  {t['id']:<22} {t['domain']:<30} {t['status']:<12} {t['plan']:<10} {ablauf}")

    active = sum(1 for t in tenants if t["status"] == "active")
    trial  = sum(1 for t in tenants if t["status"] == "trial")
    print(f"\n  Gesamt: {len(tenants)} Kunden ({active} aktiv, {trial} Demo)")


def generate_configs(conn):
    """Docker Compose + Caddyfile aus Templates generieren."""
    tenants = get_all_tenants(conn)

    env = Environment(
        loader=FileSystemLoader(str(TEMPLATES_DIR)),
        keep_trailing_newline=True,
    )

    # Docker Compose generieren
    template = env.get_template("docker-compose.multi.yml.j2")
    output = template.render(tenants=tenants)
    COMPOSE_OUTPUT.write_text(output, encoding="utf-8")
    print(f"  {COMPOSE_OUTPUT} generiert ({len(tenants)} Kunden)")

    # Caddyfile generieren
    template = env.get_template("Caddyfile.multi.j2")
    output = template.render(tenants=tenants)
    CADDY_OUTPUT.write_text(output, encoding="utf-8")
    print(f"  {CADDY_OUTPUT} generiert ({len(tenants)} Domains)")


def deploy_tenant(tenant_id):
    """Einzelnen Kunden-Container starten + Caddy reload."""
    service = f"webui-{tenant_id}"

    print(f"  Starte Container fuer {tenant_id}...")
    ret = os.system(f'docker compose -f "{COMPOSE_OUTPUT}" up -d {service}')
    if ret != 0:
        print("  WARNUNG: Container-Start fehlgeschlagen")

    print("  Caddy Config neu laden...")
    ret = os.system("docker exec copllm-caddy caddy reload --config /etc/caddy/Caddyfile")
    if ret != 0:
        print("  WARNUNG: Caddy reload fehlgeschlagen")


def create_litellm_key(tenant_id, plan="starter"):
    """
    LiteLLM Virtual Key fuer einen Kunden erstellen.

    plan="demo"    → eingeschränkt: Haiku, 0.50 EUR/Tag, 7 Tage Ablauf, RPM-Limit
    plan=andere    → unbeschraenkt: kein Modell-Filter, 50 EUR/Monat Standard-Budget
    """
    if not LITELLM_MASTER_KEY:
        return None, None

    try:
        import requests

        is_demo = (plan == "demo")

        payload = {
            "key_alias": f"copllm-{tenant_id}",
            "metadata": {
                "tenant_id": tenant_id,
                "plan": plan,
            },
        }

        if is_demo:
            payload.update({
                "models": ["claude-haiku"],       # Kein Sonnet/Opus fuer Demo
                "max_budget": DEMO_DAILY_BUDGET_EUR,
                "budget_duration": "1d",
                "duration": f"{DEMO_DURATION_HOURS}h",   # Key laeuft nach 7 Tagen ab
                "rpm_limit": DEMO_RPM_LIMIT,
                "max_parallel_requests": DEMO_MAX_PARALLEL,
                "metadata": {
                    "tenant_id": tenant_id,
                    "plan": "demo",
                    "demo_start": datetime.now(timezone.utc).isoformat(),
                },
            })
        else:
            payload.update({
                "max_budget": 50.0,
                "budget_duration": "1mo",
            })

        resp = requests.post(
            f"{LITELLM_URL}/key/generate",
            headers={"Authorization": f"Bearer {LITELLM_MASTER_KEY}"},
            json=payload,
            timeout=5,
        )
        if resp.status_code == 200:
            data = resp.json()
            return data.get("key"), data.get("token_id") or data.get("id")
    except Exception:
        pass

    return None, None


def _delete_litellm_key(api_key):
    """LiteLLM Virtual Key loeschen (bei Suspend oder Demo-Ablauf)."""
    if not LITELLM_MASTER_KEY or not api_key:
        return
    try:
        import requests
        requests.post(
            f"{LITELLM_URL}/key/delete",
            headers={"Authorization": f"Bearer {LITELLM_MASTER_KEY}"},
            json={"keys": [api_key]},
            timeout=5,
        )
    except Exception:
        pass


def main():
    parser = argparse.ArgumentParser(description="CopLLM Kunden-Provisioning")
    sub = parser.add_subparsers(dest="command", required=True)

    # add
    p_add = sub.add_parser("add", help="Neuen Kunden anlegen")
    p_add.add_argument("tenant_id", help="Kunde-ID (z.B. mueller-gmbh)")
    p_add.add_argument("domain", help="Domain (z.B. ki.mueller-gmbh.de)")
    p_add.add_argument("display_name", nargs="?", help="Firmenname (optional)")
    p_add.add_argument(
        "--plan",
        choices=["starter", "business", "enterprise", "demo"],
        default="starter",
        help="Kunden-Plan (default: starter). 'demo' = 7-Tage-Trial mit Haiku + Budget-Limit",
    )

    # remove
    p_rm = sub.add_parser("remove", help="Kunden suspendieren")
    p_rm.add_argument("tenant_id", help="Kunde-ID")

    # list
    sub.add_parser("list", help="Alle Kunden auflisten")

    # generate
    sub.add_parser("generate", help="Compose + Caddyfile aus DB generieren")

    # deploy
    p_dep = sub.add_parser("deploy", help="Kunden-Container starten")
    p_dep.add_argument("tenant_id", help="Kunde-ID")

    args = parser.parse_args()

    print()
    print("========================================")
    print("  CopLLM — Provisioning")
    print("========================================")
    print()

    if args.command == "list":
        conn = get_db_connection()
        list_tenants(conn)
        conn.close()
        return

    if args.command == "add":
        display_name = args.display_name or args.tenant_id
        conn = get_db_connection()
        add_tenant(conn, args.tenant_id, args.domain, display_name, plan=args.plan)
        print("\n  Naechste Schritte:")
        print("    python scripts/provision.py generate")
        print(f"    python scripts/provision.py deploy {args.tenant_id}")
        if args.plan == "demo":
            print("\n  Demo-Ablauf automatisieren:")
            print("    crontab -e")
            print("    0 2 * * * python /opt/copllm/scripts/expire-demos.py")
        conn.close()
        return

    if args.command == "remove":
        conn = get_db_connection()
        remove_tenant(conn, args.tenant_id)
        print("\n  Naechste Schritte:")
        print("    python scripts/provision.py generate")
        print(f"    docker compose -f docker-compose.multi.yml stop webui-{args.tenant_id}")
        conn.close()
        return

    if args.command == "generate":
        conn = get_db_connection()
        generate_configs(conn)
        conn.close()
        return

    if args.command == "deploy":
        deploy_tenant(args.tenant_id)
        return


if __name__ == "__main__":
    main()
