---
date: 2026-03-31
categories:
  - Release
tags:
  - setup
  - architektur
---

# CopLLM v1.0 — Initial Release

Der komplette Stack steht: Open WebUI, LiteLLM, Supabase pgvector, n8n Workflows, Caddy Reverse Proxy.

<!-- more -->

## Was ist dabei

- **Supabase pgvector Schema** mit Tenant-Isolation, HNSW-Index, RLS
- **LiteLLM Router** mit Claude Sonnet/Opus/Haiku + Ollama Fallback
- **8 Integrationen:** Google Drive, OneDrive, SharePoint, Nextcloud, Email/IMAP, Dropbox, Confluence, Notion
- **Multi-Kunden Setup** auf einem Server mit Docker
- **DB-driven Provisioning** statt sed-basiertem Shell-Script
- **OCR fuer Scans** via Gemini Embedding 2 (PDFs direkt embedden)
- **Kosten-Monitoring** via LiteLLM Virtual Keys mit Per-Kunde Budget

## Naechste Schritte

- Erster Kunden-Rollout auf Hetzner VPS
- Grafana Dashboard fuer LLM-Kosten
- Admin-Portal (Next.js auf Vercel)
