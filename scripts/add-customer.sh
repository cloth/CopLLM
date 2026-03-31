#!/bin/bash
# =============================================================================
# CopLLM — Neuen Kunden hinzufuegen (One-Click Rollout)
#
# Aufruf:
#   ./scripts/add-customer.sh kunde-name ki.kundendomaene.de "Firmenname GmbH"
#
# Was passiert:
#   1. Generiert Secret Key
#   2. Fuegt Docker-Container in docker-compose.multi.yml ein
#   3. Fuegt Domain in caddy/Caddyfile.multi ein
#   4. Fuegt Secret in .env ein
#   5. Erstellt Supabase-Schema (wenn DB-URL angegeben)
#   6. Startet den neuen Container
#   7. Zeigt Zusammenfassung
#
# Spaeter automatisierbar:
#   - [ ] Supabase Projekt per API erstellen
#   - [ ] n8n Workflows per API importieren
#   - [ ] n8n Credentials per API konfigurieren
#   - [ ] Admin-Account per Open WebUI API anlegen
#   - [ ] System-Prompt per API setzen
#   - [ ] Telegram-Benachrichtigung senden
# =============================================================================

set -e

# --- Farben ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# --- Parameter pruefen ---
if [ -z "$1" ] || [ -z "$2" ]; then
  echo -e "${RED}Fehler: Parameter fehlen${NC}"
  echo ""
  echo "Aufruf:"
  echo "  ./scripts/add-customer.sh <kunde-id> <domain> [firmenname]"
  echo ""
  echo "Beispiel:"
  echo "  ./scripts/add-customer.sh mueller-gmbh ki.mueller-gmbh.de \"Mueller GmbH\""
  echo ""
  exit 1
fi

CUSTOMER_ID="$1"
CUSTOMER_DOMAIN="$2"
CUSTOMER_NAME="${3:-$CUSTOMER_ID}"
COMPOSE_FILE="docker-compose.multi.yml"
CADDYFILE="caddy/Caddyfile.multi"
ENV_FILE=".env"
SECRET=$(openssl rand -hex 32)
CONTAINER_NAME="copllm-webui-${CUSTOMER_ID}"
VOLUME_NAME="webui-data-${CUSTOMER_ID}"
SERVICE_NAME="webui-${CUSTOMER_ID}"
SECRET_VAR="OPENWEBUI_SECRET_$(echo ${CUSTOMER_ID} | tr '-' '_' | tr '[:lower:]' '[:upper:]')"

echo ""
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  CopLLM — Neuer Kunde${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""
echo -e "  Kunde-ID:    ${GREEN}${CUSTOMER_ID}${NC}"
echo -e "  Domain:      ${GREEN}${CUSTOMER_DOMAIN}${NC}"
echo -e "  Firmenname:  ${GREEN}${CUSTOMER_NAME}${NC}"
echo -e "  Container:   ${CONTAINER_NAME}"
echo -e "  Secret Var:  ${SECRET_VAR}"
echo ""

# --- Pruefen ob Kunde schon existiert ---
if grep -q "container_name: ${CONTAINER_NAME}" "${COMPOSE_FILE}" 2>/dev/null; then
  echo -e "${RED}Fehler: Kunde '${CUSTOMER_ID}' existiert bereits in ${COMPOSE_FILE}${NC}"
  exit 1
fi

if grep -q "${CUSTOMER_DOMAIN}" "${CADDYFILE}" 2>/dev/null; then
  echo -e "${RED}Fehler: Domain '${CUSTOMER_DOMAIN}' existiert bereits in ${CADDYFILE}${NC}"
  exit 1
fi

# --- 1. Secret in .env ---
echo -e "${YELLOW}[1/5]${NC} Secret Key generieren..."
if [ -f "${ENV_FILE}" ]; then
  echo "" >> "${ENV_FILE}"
  echo "# --- Kunde: ${CUSTOMER_NAME} ---" >> "${ENV_FILE}"
  echo "${SECRET_VAR}=${SECRET}" >> "${ENV_FILE}"
  echo -e "  ${GREEN}✓${NC} ${SECRET_VAR} in .env geschrieben"
else
  echo -e "  ${YELLOW}!${NC} .env existiert nicht — Secret manuell eintragen:"
  echo "  ${SECRET_VAR}=${SECRET}"
fi

# --- 2. Docker Compose Block ---
echo -e "${YELLOW}[2/5]${NC} Docker Compose Service hinzufuegen..."

# Vor dem volumes: Block einfuegen
DOCKER_BLOCK="
  # =========================================================================
  # KUNDE: ${CUSTOMER_NAME}
  # Domain: ${CUSTOMER_DOMAIN}
  # Erstellt: $(date +%Y-%m-%d)
  # =========================================================================

  ${SERVICE_NAME}:
    image: ghcr.io/open-webui/open-webui:main
    container_name: ${CONTAINER_NAME}
    restart: unless-stopped
    depends_on:
      - litellm
    environment:
      - OPENAI_API_BASE_URLS=http://litellm:4000/v1
      - OPENAI_API_KEYS=\${LITELLM_MASTER_KEY}
      - OLLAMA_BASE_URLS=\${OLLAMA_BASE_URL:-http://host.docker.internal:11434}
      - RAG_EMBEDDING_ENGINE=ollama
      - RAG_EMBEDDING_MODEL=\${EMBEDDING_MODEL:-nomic-embed-text}
      - CHUNK_SIZE=\${CHUNK_SIZE:-500}
      - CHUNK_OVERLAP=\${CHUNK_OVERLAP:-75}
      - WEBUI_SECRET_KEY=\${${SECRET_VAR}:-change-me}
      - ENABLE_SIGNUP=false
      - WEBUI_NAME=${CUSTOMER_NAME} - KI Assistent
    volumes:
      - ${VOLUME_NAME}:/app/backend/data
    networks:
      - copllm-net
    extra_hosts:
      - \"host.docker.internal:host-gateway\""

# Vor "# ====...VOLUMES" einfuegen
sed -i "/^# =\+$/,/^# VOLUMES/{/^# VOLUMES/i\\
${DOCKER_BLOCK}
}" "${COMPOSE_FILE}" 2>/dev/null || {
  # Fallback: Am Ende vor volumes: einfuegen
  sed -i "/^volumes:/i\\${DOCKER_BLOCK}" "${COMPOSE_FILE}"
}

echo -e "  ${GREEN}✓${NC} Service '${SERVICE_NAME}' in ${COMPOSE_FILE}"

# --- 3. Volume hinzufuegen ---
echo -e "${YELLOW}[3/5]${NC} Volume hinzufuegen..."
sed -i "/^  # Neuer Kunde/i\\  ${VOLUME_NAME}:" "${COMPOSE_FILE}" 2>/dev/null || {
  sed -i "/^volumes:/a\\  ${VOLUME_NAME}:" "${COMPOSE_FILE}"
}
echo -e "  ${GREEN}✓${NC} Volume '${VOLUME_NAME}'"

# --- 4. Caddy Domain ---
echo -e "${YELLOW}[4/5]${NC} Domain in Caddy hinzufuegen..."

CADDY_BLOCK="
# =========================================================================
# KUNDE: ${CUSTOMER_NAME} (${CUSTOMER_ID})
# Erstellt: $(date +%Y-%m-%d)
# DNS: A-Record fuer ${CUSTOMER_DOMAIN} → Server-IP
# =========================================================================
${CUSTOMER_DOMAIN} {
    import security_headers
    import access_log ${CUSTOMER_ID}

    reverse_proxy ${CONTAINER_NAME}:8080
}
"

# Vor der Kopiervorlage einfuegen
sed -i "/^# NEUER KUNDE/i\\${CADDY_BLOCK}" "${CADDYFILE}" 2>/dev/null || {
  # Fallback: Am Ende anhaengen
  echo "${CADDY_BLOCK}" >> "${CADDYFILE}"
}

echo -e "  ${GREEN}✓${NC} Domain '${CUSTOMER_DOMAIN}' in ${CADDYFILE}"

# --- 5. Container starten ---
echo -e "${YELLOW}[5/5]${NC} Container starten..."
docker compose -f "${COMPOSE_FILE}" up -d "${SERVICE_NAME}" 2>/dev/null && {
  echo -e "  ${GREEN}✓${NC} Container '${CONTAINER_NAME}' gestartet"
} || {
  echo -e "  ${YELLOW}!${NC} Container konnte nicht gestartet werden (docker compose manuell ausfuehren)"
}

# Caddy reload fuer neue Domain
docker exec copllm-caddy caddy reload --config /etc/caddy/Caddyfile 2>/dev/null && {
  echo -e "  ${GREEN}✓${NC} Caddy Config neu geladen"
} || {
  echo -e "  ${YELLOW}!${NC} Caddy reload fehlgeschlagen (manuell: docker restart copllm-caddy)"
}

# --- Zusammenfassung ---
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Kunde erfolgreich angelegt!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "  URL:         ${CYAN}https://${CUSTOMER_DOMAIN}${NC}"
echo -e "  Container:   ${CONTAINER_NAME}"
echo -e "  Volume:      ${VOLUME_NAME}"
echo -e "  Secret Var:  ${SECRET_VAR}"
echo ""
echo -e "${YELLOW}Naechste manuelle Schritte:${NC}"
echo "  1. DNS: A-Record fuer ${CUSTOMER_DOMAIN} → $(curl -s ifconfig.me 2>/dev/null || echo 'SERVER-IP')"
echo "  2. https://${CUSTOMER_DOMAIN} oeffnen → Admin-Account erstellen"
echo "  3. System-Prompt anpassen (Firmenname: ${CUSTOMER_NAME})"
echo "  4. Supabase Projekt erstellen (Frankfurt!) + init.sql"
echo "  5. n8n Workflow fuer ${CUSTOMER_NAME} konfigurieren"
echo ""
echo -e "${CYAN}Spaeter automatisiert (TODO):${NC}"
echo "  - Supabase Projekt per Management API"
echo "  - n8n Workflow per REST API importieren"
echo "  - Open WebUI Admin per API anlegen"
echo "  - System-Prompt per API setzen"
echo ""
