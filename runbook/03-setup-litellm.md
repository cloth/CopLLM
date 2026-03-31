# 03 — LiteLLM Router Setup

## Was macht LiteLLM?

- Einheitliche OpenAI-kompatible API fuer alle Modelle
- Kostentracking pro Modell
- Fallback wenn ein Modell ausfaellt
- Budget-Limits als Sicherheitsnetz

## Schritt-fuer-Schritt

### 1. Konfiguration pruefen

`litellm/config.yaml` enthaelt:
- `claude-sonnet` — Standard (Anthropic)
- `claude-opus` — Komplex (Anthropic)
- `claude-haiku` — Schnell/Guenstig (Anthropic)
- `llama-local` — 100% lokal (Ollama)
- `copllm-default` — Default fuer Open WebUI

### 2. Starten (Docker)

Im vollen Stack (`docker compose up -d`) startet LiteLLM automatisch.

Einzeln testen:
```bash
docker run -d --name litellm-test \
  -p 4000:4000 \
  -v ./litellm/config.yaml:/app/config.yaml \
  -e ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY \
  -e OLLAMA_BASE_URL=http://host.docker.internal:11434 \
  -e LITELLM_MASTER_KEY=sk-test-key \
  ghcr.io/berriai/litellm:main-latest \
  --config /app/config.yaml --port 4000
```

### 3. Pruefen

```bash
# Verfuegbare Modelle
curl http://localhost:4000/v1/models \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY"

# Test-Anfrage
curl http://localhost:4000/v1/chat/completions \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-sonnet",
    "messages": [{"role": "user", "content": "Hallo"}]
  }'
```

### 4. Budget-Limit anpassen

In `litellm/config.yaml`:
```yaml
litellm_settings:
  max_budget: 50.0      # Fuer Demo: $50/Monat
  budget_duration: "1mo"
```

Fuer Kunden anpassen je nach Paket.

## Learnings & Hacks
<!-- Ergaenze hier nach jedem Setup was dir aufgefallen ist -->
