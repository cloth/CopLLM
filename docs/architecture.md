# Architektur

## Datenfluss — Dokument-Sync

```mermaid
flowchart LR
    GD[Google Drive] --> N8N
    OD[OneDrive] --> N8N
    NC[Nextcloud] --> N8N
    EM[Email/IMAP] --> N8N
    DB[Dropbox] --> N8N

    N8N[n8n Sync] --> CH[Chunking]
    CH --> EMB[Embedding]
    EMB --> SB[(Supabase pgvector)]

    style GD fill:#4285f4,color:#fff
    style OD fill:#0078d4,color:#fff
    style NC fill:#0082c9,color:#fff
    style EM fill:#ea4335,color:#fff
    style DB fill:#0061fe,color:#fff
    style N8N fill:#ff6d5a,color:#fff
    style SB fill:#3ecf8e,color:#fff
```

## Datenfluss — User-Anfrage (RAG)

```mermaid
flowchart LR
    U[Nutzer] --> OW[Open WebUI]
    OW --> LT[LiteLLM Router]
    LT --> CL[Claude API]
    LT --> OL[Ollama Lokal]

    OW --> |"Frage embedden"| EMB[Embedding]
    EMB --> SB[(Supabase)]
    SB --> |"Top-K Chunks"| OW

    style U fill:#6366f1,color:#fff
    style OW fill:#0088ee,color:#fff
    style LT fill:#f59e0b,color:#fff
    style CL fill:#d97706,color:#fff
    style OL fill:#22c55e,color:#fff
    style SB fill:#3ecf8e,color:#fff
```

## Multi-Kunden Architektur

```mermaid
flowchart TB
    subgraph Shared["Shared Services"]
        CAD[Caddy Reverse Proxy]
        LIT[LiteLLM Router]
        N8N[n8n Workflows]
    end

    subgraph Kunden["Pro Kunde"]
        WA[WebUI Kunde A]
        WB[WebUI Kunde B]
        WC[WebUI Kunde C]
    end

    subgraph DB["Datenbank"]
        SB[(Supabase pgvector<br/>tenant_id Isolation)]
    end

    CAD --> WA & WB & WC
    WA & WB & WC --> LIT
    N8N --> SB
    WA & WB & WC --> SB

    style CAD fill:#00bbcc,color:#fff
    style LIT fill:#f59e0b,color:#fff
    style N8N fill:#ff6d5a,color:#fff
    style SB fill:#3ecf8e,color:#fff
    style WA fill:#0088ee,color:#fff
    style WB fill:#0088ee,color:#fff
    style WC fill:#0088ee,color:#fff
```

## Komponenten

| Service | Container | Port | Shared? |
|---------|-----------|------|---------|
| Caddy | copllm-caddy | 80, 443 | Ja |
| LiteLLM | copllm-litellm | 4000 (intern) | Ja |
| n8n | copllm-n8n | 5678 (intern) | Ja |
| Open WebUI | copllm-webui-{kunde} | 8080 (intern) | Nein (pro Kunde) |
| Supabase | extern (Frankfurt) | — | Ja (tenant_id) |

## Skalierungs-Phasen

```mermaid
timeline
    title CopLLM Skalierung
    Phase 1 : 10-50 Kunden
            : Docker Compose Multi-Server
            : 1 Supabase + tenant_id
            : LiteLLM Virtual Keys
    Phase 2 : 50-200 Kunden
            : Admin-Portal
            : Caddy Dynamic Config
            : n8n API Provisioning
    Phase 3 : 200-1000+ Kunden
            : Custom Chat Frontend
            : Wildcard Domain
            : Sync-Worker statt n8n
```
