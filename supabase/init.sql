-- =============================================================================
-- CopLLM — Supabase pgvector Schema
-- Ausfuehren mit: psql $SUPABASE_DB_URL -f supabase/init.sql
-- Oder im Supabase SQL Editor einfuegen
-- =============================================================================

-- 1. Extensions aktivieren
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. Tenants-Tabelle (Kunden-Registry — Single Source of Truth)
CREATE TABLE IF NOT EXISTS tenants (
    id TEXT PRIMARY KEY,                        -- z.B. 'mueller-gmbh'
    display_name TEXT NOT NULL,                 -- z.B. 'Mueller GmbH'
    domain TEXT UNIQUE NOT NULL,                -- z.B. 'ki.mueller-gmbh.de'
    status TEXT NOT NULL DEFAULT 'active',      -- active, suspended, trial
    plan TEXT NOT NULL DEFAULT 'starter',       -- starter, business, enterprise
    webui_secret TEXT NOT NULL,
    litellm_api_key TEXT,                       -- per-Kunde LiteLLM Virtual Key
    drive_type TEXT,                            -- google_drive, onedrive, both
    drive_folder_id TEXT,
    monthly_budget_eur NUMERIC DEFAULT 50,
    config JSONB DEFAULT '{}',                  -- flexible Kunden-Konfiguration
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_tenants_domain ON tenants (domain);
CREATE INDEX IF NOT EXISTS idx_tenants_status ON tenants (status);

-- 3. Enum fuer Dokumenten-Quellen (unveraendert)
DO $$ BEGIN
    CREATE TYPE doc_source AS ENUM ('google_drive', 'onedrive', 'manual_upload');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- 3. Haupttabelle: documents (Chunks mit Embeddings)
CREATE TABLE IF NOT EXISTS documents (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Quelle und Identifikation
    source doc_source NOT NULL DEFAULT 'manual_upload',
    source_id TEXT,                          -- Google Drive File ID / OneDrive Item ID
    file_name TEXT NOT NULL,
    file_path TEXT,                          -- Pfad in Drive/OneDrive
    mime_type TEXT,

    -- Chunk-Daten
    content TEXT NOT NULL,
    chunk_index INTEGER NOT NULL DEFAULT 0,

    -- Embedding (768 Dimensionen fuer nomic-embed-text)
    embedding vector(768),

    -- Metadaten
    metadata JSONB DEFAULT '{}',

    -- Zeitstempel
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    source_modified_at TIMESTAMPTZ,         -- Letzte Aenderung in Drive/OneDrive

    -- Tenant-Support (fuer Kunden-Deployments)
    tenant_id TEXT DEFAULT 'clx-digital'
);

-- 4. Indizes

-- HNSW-Index fuer Vektorsuche (schneller als IVFFlat bei < 100k Chunks)
CREATE INDEX IF NOT EXISTS idx_documents_embedding
    ON documents
    USING hnsw (embedding vector_cosine_ops)
    WITH (m = 16, ef_construction = 64);

-- B-Tree Indizes fuer Filterung
CREATE INDEX IF NOT EXISTS idx_documents_source_id
    ON documents (source_id);

CREATE INDEX IF NOT EXISTS idx_documents_tenant
    ON documents (tenant_id);

CREATE INDEX IF NOT EXISTS idx_documents_file_name
    ON documents (file_name);

CREATE INDEX IF NOT EXISTS idx_documents_source
    ON documents (source);

-- Composite Index fuer n8n Delete/Update Operationen
CREATE INDEX IF NOT EXISTS idx_documents_source_source_id
    ON documents (source, source_id);

-- 5. Funktion: match_documents (RAG-Retrieval)
CREATE OR REPLACE FUNCTION match_documents(
    query_embedding vector(768),
    match_count INTEGER DEFAULT 5,
    match_threshold FLOAT DEFAULT 0.75,
    filter_tenant TEXT DEFAULT 'clx-digital'
)
RETURNS TABLE (
    id UUID,
    content TEXT,
    file_name TEXT,
    source doc_source,
    chunk_index INTEGER,
    metadata JSONB,
    similarity FLOAT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        d.id,
        d.content,
        d.file_name,
        d.source,
        d.chunk_index,
        d.metadata,
        1 - (d.embedding <=> query_embedding) AS similarity
    FROM documents d
    WHERE
        d.tenant_id = filter_tenant
        AND d.embedding IS NOT NULL
        AND 1 - (d.embedding <=> query_embedding) > match_threshold
    ORDER BY d.embedding <=> query_embedding
    LIMIT match_count;
END;
$$;

-- 6. Funktion: delete_by_source_id (fuer n8n Sync)
-- Loescht alle Chunks eines Dokuments und gibt Anzahl zurueck
CREATE OR REPLACE FUNCTION delete_by_source_id(
    p_source doc_source,
    p_source_id TEXT
)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM documents
    WHERE source = p_source AND source_id = p_source_id;

    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$;

-- 7. Trigger: updated_at automatisch setzen
CREATE OR REPLACE FUNCTION update_modified_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_updated_at ON documents;
CREATE TRIGGER set_updated_at
    BEFORE UPDATE ON documents
    FOR EACH ROW
    EXECUTE FUNCTION update_modified_column();

-- 8. Row Level Security (DSGVO)
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE sync_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE tenants ENABLE ROW LEVEL SECURITY;

-- Service-Role: Vollzugriff (fuer n8n + Provisioning)
DROP POLICY IF EXISTS "Service role full access" ON documents;
CREATE POLICY "Service role full access" ON documents
    FOR ALL TO service_role
    USING (true)
    WITH CHECK (true);

DROP POLICY IF EXISTS "Service role full access sync_log" ON sync_log;
CREATE POLICY "Service role full access sync_log" ON sync_log
    FOR ALL TO service_role
    USING (true)
    WITH CHECK (true);

DROP POLICY IF EXISTS "Service role full access tenants" ON tenants;
CREATE POLICY "Service role full access tenants" ON tenants
    FOR ALL TO service_role
    USING (true)
    WITH CHECK (true);

-- Anon-Role: Nur eigenen Tenant lesen (fuer zukuenftiges Frontend)
-- Tenant wird via app.tenant_id Session-Variable gesetzt
DROP POLICY IF EXISTS "Tenant read own documents" ON documents;
CREATE POLICY "Tenant read own documents" ON documents
    FOR SELECT TO anon
    USING (tenant_id = current_setting('app.tenant_id', true));

-- 9. Sync-Log Tabelle (fuer n8n Monitoring)
CREATE TABLE IF NOT EXISTS sync_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id TEXT REFERENCES tenants(id),
    source doc_source NOT NULL,
    action TEXT NOT NULL,              -- 'add', 'update', 'delete'
    source_id TEXT,
    file_name TEXT,
    chunks_count INTEGER DEFAULT 0,
    status TEXT DEFAULT 'success',     -- 'success', 'error'
    error_message TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sync_log_created
    ON sync_log (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_sync_log_tenant
    ON sync_log (tenant_id);

-- 10. View: Dokumenten-Uebersicht (Debugging / Demo)
CREATE OR REPLACE VIEW documents_overview AS
SELECT
    tenant_id,
    source,
    source_id,
    file_name,
    COUNT(*) AS chunk_count,
    MIN(created_at) AS first_indexed,
    MAX(updated_at) AS last_updated
FROM documents
GROUP BY tenant_id, source, source_id, file_name
ORDER BY MAX(updated_at) DESC;

-- 11. View: Tenant-Uebersicht (Admin / Monitoring)
CREATE OR REPLACE VIEW tenant_overview AS
SELECT
    t.id,
    t.display_name,
    t.domain,
    t.status,
    t.plan,
    t.created_at,
    COUNT(DISTINCT d.source_id) AS document_count,
    COUNT(d.id) AS chunk_count,
    MAX(d.updated_at) AS last_sync
FROM tenants t
LEFT JOIN documents d ON d.tenant_id = t.id
GROUP BY t.id, t.display_name, t.domain, t.status, t.plan, t.created_at
ORDER BY t.created_at DESC;

-- 12. Trigger: updated_at fuer tenants
DROP TRIGGER IF EXISTS set_updated_at_tenants ON tenants;
CREATE TRIGGER set_updated_at_tenants
    BEFORE UPDATE ON tenants
    FOR EACH ROW
    EXECUTE FUNCTION update_modified_column();
