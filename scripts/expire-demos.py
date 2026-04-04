#!/usr/bin/env python3
"""
CopLLM — Demo-Account Ablauf-Management

Laeuft taeglich per Cronjob. Prueft abgelaufene Demo-Accounts und:
  1. Loescht den LiteLLM Virtual Key (sofortige Sperrung)
  2. Setzt den Tenant-Status auf 'suspended'
  3. DSGVO-Cleanup: Loescht Dokumente + Vektoren 30 Tage nach Ablauf

Einrichten:
  crontab -e
  0 2 * * * python3 /opt/copllm/scripts/expire-demos.py >> /var/log/copllm-expiry.log 2>&1

Umgebungsvariablen:
  SUPABASE_DB_URL      — PostgreSQL Connection String
  LITELLM_MASTER_KEY   — LiteLLM Admin Key fuer Key-Loeschung
  LITELLM_URL          — LiteLLM API URL (default: http://localhost:4000)
"""

import os
import sys
import logging
from datetime import datetime, timezone

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
log = logging.getLogger(__name__)

try:
    import psycopg2
    import psycopg2.extras
except ImportError:
    log.error("psycopg2 nicht installiert. Ausfuehren: pip install psycopg2-binary")
    sys.exit(1)

try:
    import requests
except ImportError:
    log.error("requests nicht installiert. Ausfuehren: pip install requests")
    sys.exit(1)

SUPABASE_DB_URL  = os.environ.get("SUPABASE_DB_URL", "")
LITELLM_URL      = os.environ.get("LITELLM_URL", "http://localhost:4000")
LITELLM_KEY      = os.environ.get("LITELLM_MASTER_KEY", "")
CLEANUP_AFTER_DAYS = 30   # Tage nach Ablauf bis DSGVO-Vollloeschung


def get_conn():
    if not SUPABASE_DB_URL:
        log.error("SUPABASE_DB_URL nicht gesetzt")
        sys.exit(1)
    return psycopg2.connect(SUPABASE_DB_URL)


def delete_litellm_key(api_key: str) -> bool:
    """LiteLLM Virtual Key loeschen — sperrt den Demo-Zugang sofort."""
    if not LITELLM_KEY or not api_key:
        return False
    try:
        resp = requests.post(
            f"{LITELLM_URL}/key/delete",
            headers={"Authorization": f"Bearer {LITELLM_KEY}"},
            json={"keys": [api_key]},
            timeout=10,
        )
        return resp.status_code == 200
    except Exception as e:
        log.warning(f"LiteLLM Key-Loeschung fehlgeschlagen: {e}")
        return False


def suspend_expired_demos(conn):
    """
    Phase 1: Demo-Accounts die heute ablaufen oder abgelaufen sind deaktivieren.
    Bestandskunden (plan != 'demo') werden NICHT beruehrt.
    """
    with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
        cur.execute("""
            SELECT id, display_name, litellm_api_key, trial_expires_at
            FROM tenants
            WHERE plan = 'demo'
              AND status = 'trial'
              AND trial_expires_at < NOW()
        """)
        expired = cur.fetchall()

    if not expired:
        log.info("Keine abgelaufenen Demo-Accounts gefunden.")
        return

    log.info(f"{len(expired)} abgelaufene Demo-Account(s) gefunden.")

    for tenant in expired:
        tid = tenant["id"]
        log.info(f"  Deaktiviere Demo: {tid} ({tenant['display_name']})")

        # 1. LiteLLM Key loeschen (sofortige API-Sperrung)
        if tenant["litellm_api_key"]:
            ok = delete_litellm_key(tenant["litellm_api_key"])
            log.info(f"    LiteLLM Key geloescht: {'ja' if ok else 'fehlgeschlagen'}")

        # 2. Tenant suspendieren
        with conn.cursor() as cur:
            cur.execute("""
                UPDATE tenants
                SET status = 'suspended',
                    litellm_api_key = NULL
                WHERE id = %s
            """, (tid,))
        conn.commit()
        log.info(f"    Status → suspended")


def cleanup_expired_demos(conn):
    """
    Phase 2: DSGVO-Vollloeschung — 30 Tage nach Demo-Ablauf.
    Loescht alle Dokumente, Chunks und Vektoren des Tenants.
    Bestandskunden werden NICHT beruehrt.
    """
    with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
        cur.execute(f"""
            SELECT id, display_name, trial_expires_at
            FROM tenants
            WHERE plan = 'demo'
              AND status = 'suspended'
              AND trial_expires_at < NOW() - INTERVAL '{CLEANUP_AFTER_DAYS} days'
        """)
        to_delete = cur.fetchall()

    if not to_delete:
        log.info("Keine Tenants fuer DSGVO-Cleanup faellig.")
        return

    log.info(f"{len(to_delete)} Tenant(s) fuer DSGVO-Vollloeschung.")

    for tenant in to_delete:
        tid = tenant["id"]
        log.info(f"  DSGVO-Cleanup: {tid} (abgelaufen: {tenant['trial_expires_at'].date()})")

        with conn.cursor() as cur:
            # Dokumente + Vektoren loeschen
            cur.execute("DELETE FROM documents WHERE tenant_id = %s", (tid,))
            doc_count = cur.rowcount

            # Sync-Log loeschen
            cur.execute("DELETE FROM sync_log WHERE tenant_id = %s", (tid,))

            # Tenant-Eintrag loeschen
            cur.execute("DELETE FROM tenants WHERE id = %s", (tid,))

        conn.commit()
        log.info(f"    {doc_count} Chunks + Tenant-Eintrag geloescht (DSGVO)")


def main():
    log.info("=== CopLLM Demo-Expiry-Job gestartet ===")
    conn = get_conn()

    try:
        suspend_expired_demos(conn)
        cleanup_expired_demos(conn)
    finally:
        conn.close()

    log.info("=== Demo-Expiry-Job abgeschlossen ===")


if __name__ == "__main__":
    main()
