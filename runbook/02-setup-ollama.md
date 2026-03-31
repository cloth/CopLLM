# 02 — Ollama Setup (Embedding + lokales LLM)

## Voraussetzungen

- Ollama installiert (ollama.com)
- Fuer Raspberry Pi: ARM-Version verfuegbar

## Schritt-fuer-Schritt

### 1. Ollama installieren

**Linux / Raspberry Pi:**
```bash
curl -fsSL https://ollama.ai/install.sh | sh
```

**Windows:**
Download von ollama.com → Installer ausfuehren

**Mac:**
```bash
brew install ollama
```

### 2. Modelle laden

```bash
# Embedding-Modell (768 Dimensionen)
ollama pull nomic-embed-text

# Lokales LLM als Fallback
ollama pull llama3.3
```

### 3. Testen

```bash
# Embedding testen
curl http://localhost:11434/api/embeddings -d '{
  "model": "nomic-embed-text",
  "prompt": "Testdokument fuer CopLLM"
}'

# LLM testen
curl http://localhost:11434/api/generate -d '{
  "model": "llama3.3",
  "prompt": "Hallo, wie geht es dir?",
  "stream": false
}'
```

### 4. Raspberry Pi: Im Netz verfuegbar machen

```bash
# Ollama auf allen Interfaces lauschen lassen
sudo systemctl edit ollama.service
# Hinzufuegen:
# [Service]
# Environment="OLLAMA_HOST=0.0.0.0"

sudo systemctl restart ollama

# Testen vom anderen Rechner:
curl http://192.168.x.x:11434/api/tags
```

### 5. Embedding-Provider Alternativen

Wenn OCR-Qualitaet schlecht ist und lokale Embeddings nicht reichen:

In `.env` umstellen:
```env
# Statt Ollama → Google Embeddings (nur Text)
EMBEDDING_PROVIDER=google
GOOGLE_EMBEDDING_MODEL=gemini-embedding-001
EMBEDDING_DIMENSION=768
GOOGLE_AI_API_KEY=AIzaSyXXXXX

# Oder Google Multimodal (kann gescannte PDFs direkt embedden!)
EMBEDDING_PROVIDER=google
GOOGLE_EMBEDDING_MODEL=gemini-embedding-2-preview
EMBEDDING_DIMENSION=768
GOOGLE_AI_API_KEY=AIzaSyXXXXX

# Oder OpenAI
EMBEDDING_PROVIDER=openai
EMBEDDING_MODEL=text-embedding-3-small
OPENAI_API_KEY=sk-xxxxx
```

Die n8n Workflows erkennen den Provider automatisch.

**Wichtig:** Google-Modelle haben default 3072 Dimensionen.
Wir setzen `output_dimensionality=768` fuer Kompatibilitaet mit dem Supabase-Schema.

### Google Embedding Modelle (Stand Maerz 2026)

| Modell | Typ | Preis/1M Tokens | Status |
|--------|-----|-----------------|--------|
| `gemini-embedding-2-preview` | Multimodal (Text+PDF+Bild) | $0.20 | Preview |
| `gemini-embedding-001` | Nur Text | $0.15 | Stabil |
| ~~text-embedding-004~~ | Text | - | Deprecated Jan 2026 |

## Learnings & Hacks
<!-- Ergaenze hier nach jedem Setup was dir aufgefallen ist -->
