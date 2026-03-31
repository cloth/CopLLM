# CopLLM Runbook

Dieses Runbook ist ein **lebendes Dokument**. Es waechst mit jeder Erfahrung aus eigenen Tests
und Kunden-Setups. Ziel: Der Kunden-Rollout soll so automatisiert wie moeglich werden.

## Fuer wen?

- **Fuer dich (CLX Digital):** Schritt-fuer-Schritt Setup-Anleitung mit allen Hacks und Learnings
- **Fuer spaeter:** Blaupause fuer automatisierte Kunden-Deployments

## Aufbau

| Datei | Inhalt |
|-------|--------|
| [01-setup-supabase.md](01-setup-supabase.md) | Supabase Projekt anlegen, pgvector, Schema |
| [02-setup-ollama.md](02-setup-ollama.md) | Ollama + Embedding-Modell, Raspberry Pi |
| [03-setup-litellm.md](03-setup-litellm.md) | LiteLLM Router konfigurieren |
| [04-setup-open-webui.md](04-setup-open-webui.md) | Open WebUI, RAG-Settings, System-Prompt |
| [05-setup-n8n-sync.md](05-setup-n8n-sync.md) | n8n Workflows, OCR, Drive/OneDrive Sync |
| [06-kunden-rollout.md](06-kunden-rollout.md) | Rollout-Checkliste, DSGVO, Automatisierung |
| [07-demo-skript.md](07-demo-skript.md) | Demo fuer Kundengespraeche |
| [08-troubleshooting.md](08-troubleshooting.md) | Bekannte Probleme + Loesungen |
| [09-hacks-und-learnings.md](09-hacks-und-learnings.md) | Erfahrungen, Tricks, Workarounds |

## Konvention

Jede Datei hat am Ende einen Abschnitt:

```markdown
## Learnings & Hacks
<!-- Ergaenze hier nach jedem Setup was dir aufgefallen ist -->
```

So wird das Repo mit der Zeit zur Wissensdatenbank.
