# 01 — Supabase Setup

## Voraussetzungen

- Supabase Account (supabase.com)
- Projekt in **Region eu-central-1 (Frankfurt)** erstellen — DSGVO!

## Schritt-fuer-Schritt

### 1. Projekt erstellen

1. supabase.com → New Project
2. Name: z.B. `copllm-clx` (oder Kundenname)
3. Region: **EU Central (Frankfurt)** ← wichtig!
4. Starkes DB-Passwort generieren und sicher ablegen

### 2. Zugangsdaten notieren

Unter Project Settings → API:
- **Project URL** → `SUPABASE_URL` in .env
- **anon key** → `SUPABASE_ANON_KEY`
- **service_role key** → `SUPABASE_SERVICE_ROLE_KEY`

Unter Project Settings → Database → Connection string:
- **URI** → `SUPABASE_DB_URL`

### 3. Schema initialisieren

SQL Editor oeffnen und `supabase/init.sql` ausfuehren.

Oder per CLI:
```bash
psql $SUPABASE_DB_URL -f supabase/init.sql
```

### 4. Pruefen

```sql
-- Extensions vorhanden?
SELECT * FROM pg_extension WHERE extname IN ('vector', 'uuid-ossp');

-- Tabelle erstellt?
SELECT * FROM documents_overview;

-- Funktion vorhanden?
SELECT proname FROM pg_proc WHERE proname = 'match_documents';
```

### 5. Vercel-Integration (optional)

Wenn du Supabase ueber Vercel nutzt:
1. Vercel Dashboard → Integrations → Supabase
2. Projekt verknuepfen
3. Env-Variablen werden automatisch gesetzt

## Learnings & Hacks
<!-- Ergaenze hier nach jedem Setup was dir aufgefallen ist -->
