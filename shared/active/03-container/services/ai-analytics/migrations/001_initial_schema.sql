-- Migration 001: Initial Schema
-- Description: Create the complete database schema for AI Analytics Pipeline
-- Version: 1.0.0
-- Date: 2025-01-20

-- This migration applies the complete schema.sql
-- It's idempotent - can be run multiple times safely

BEGIN TRANSACTION;

-- Enable foreign keys
PRAGMA foreign_keys = ON;

-- ============================================================================
-- User Attribution Tables
-- ============================================================================

CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT NOT NULL UNIQUE,
    username TEXT NOT NULL,
    email TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT 1,
    metadata JSON
);

CREATE TABLE IF NOT EXISTS machines (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    machine_id TEXT NOT NULL UNIQUE,
    hostname TEXT NOT NULL,
    os_type TEXT,
    os_version TEXT,
    cpu_cores INTEGER,
    memory_gb INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT 1,
    metadata JSON
);

CREATE TABLE IF NOT EXISTS client_keys (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    key_id TEXT NOT NULL UNIQUE,
    key_name TEXT NOT NULL,
    key_type TEXT NOT NULL,
    user_id INTEGER,
    machine_id INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP,
    is_active BOOLEAN DEFAULT 1,
    last_used_at TIMESTAMP,
    metadata JSON,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
    FOREIGN KEY (machine_id) REFERENCES machines(id) ON DELETE SET NULL
);

-- ============================================================================
-- Request/Response Events Tables
-- ============================================================================

CREATE TABLE IF NOT EXISTS request_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    event_id TEXT NOT NULL UNIQUE,
    timestamp TIMESTAMP NOT NULL,
    client_key_id INTEGER,
    user_id INTEGER,
    machine_id INTEGER,
    pipeline_stage TEXT NOT NULL,
    request_size_bytes INTEGER NOT NULL,
    request_hash TEXT NOT NULL,
    estimated_tokens INTEGER,
    content_type TEXT,
    method TEXT,
    endpoint TEXT,
    headers JSON,
    metadata JSON,
    FOREIGN KEY (client_key_id) REFERENCES client_keys(id) ON DELETE SET NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
    FOREIGN KEY (machine_id) REFERENCES machines(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS response_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    request_event_id INTEGER NOT NULL,
    timestamp TIMESTAMP NOT NULL,
    response_size_bytes INTEGER NOT NULL,
    response_time_ms INTEGER NOT NULL,
    status_code INTEGER,
    provider_id INTEGER,
    model_id INTEGER,
    model_version TEXT,
    success BOOLEAN DEFAULT 1,
    error_message TEXT,
    headers JSON,
    metadata JSON,
    FOREIGN KEY (request_event_id) REFERENCES request_events(id) ON DELETE CASCADE
);

-- ============================================================================
-- Subagent Attribution Tables
-- ============================================================================

CREATE TABLE IF NOT EXISTS subagents (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    subagent_id TEXT NOT NULL UNIQUE,
    subagent_name TEXT NOT NULL,
    subagent_type TEXT NOT NULL,
    version TEXT,
    provider TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT 1,
    metadata JSON
);

CREATE TABLE IF NOT EXISTS subagent_requests (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    request_event_id INTEGER NOT NULL,
    subagent_id INTEGER NOT NULL,
    parent_request_id INTEGER,
    turn_number INTEGER,
    session_id TEXT,
    metadata JSON,
    FOREIGN KEY (request_event_id) REFERENCES request_events(id) ON DELETE CASCADE,
    FOREIGN KEY (subagent_id) REFERENCES subagents(id) ON DELETE CASCADE
);

-- ============================================================================
-- Tool Analytics Tables
-- ============================================================================

CREATE TABLE IF NOT EXISTS tools (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    tool_id TEXT NOT NULL UNIQUE,
    tool_name TEXT NOT NULL,
    tool_category TEXT,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT 1,
    metadata JSON
);

CREATE TABLE IF NOT EXISTS tool_invocations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    request_event_id INTEGER NOT NULL,
    subagent_request_id INTEGER,
    tool_id INTEGER NOT NULL,
    invocation_timestamp TIMESTAMP NOT NULL,
    duration_ms INTEGER,
    success BOOLEAN DEFAULT 1,
    error_message TEXT,
    input_size_bytes INTEGER,
    output_size_bytes INTEGER,
    estimated_tokens INTEGER,
    metadata JSON,
    FOREIGN KEY (request_event_id) REFERENCES request_events(id) ON DELETE CASCADE,
    FOREIGN KEY (subagent_request_id) REFERENCES subagent_requests(id) ON DELETE SET NULL,
    FOREIGN KEY (tool_id) REFERENCES tools(id) ON DELETE CASCADE
);

-- ============================================================================
-- File Analytics Tables
-- ============================================================================

CREATE TABLE IF NOT EXISTS files (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    file_id TEXT NOT NULL UNIQUE,
    file_path TEXT NOT NULL,
    file_name TEXT NOT NULL,
    file_extension TEXT,
    file_size_bytes INTEGER,
    language TEXT,
    project_path TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_accessed_at TIMESTAMP,
    access_count INTEGER DEFAULT 0,
    total_tokens_used INTEGER DEFAULT 0,
    metadata JSON
);

CREATE TABLE IF NOT EXISTS file_accesses (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    request_event_id INTEGER NOT NULL,
    subagent_request_id INTEGER,
    file_id INTEGER NOT NULL,
    access_timestamp TIMESTAMP NOT NULL,
    access_type TEXT NOT NULL,
    bytes_read INTEGER,
    bytes_written INTEGER,
    estimated_tokens INTEGER,
    metadata JSON,
    FOREIGN KEY (request_event_id) REFERENCES request_events(id) ON DELETE CASCADE,
    FOREIGN KEY (subagent_request_id) REFERENCES subagent_requests(id) ON DELETE SET NULL,
    FOREIGN KEY (file_id) REFERENCES files(id) ON DELETE CASCADE
);

-- ============================================================================
-- Session Analytics Tables
-- ============================================================================

CREATE TABLE IF NOT EXISTS sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT NOT NULL UNIQUE,
    user_id INTEGER,
    machine_id INTEGER,
    subagent_id INTEGER,
    started_at TIMESTAMP NOT NULL,
    ended_at TIMESTAMP,
    total_turns INTEGER DEFAULT 0,
    total_tokens INTEGER DEFAULT 0,
    total_cost_cents INTEGER DEFAULT 0,
    metadata JSON,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
    FOREIGN KEY (machine_id) REFERENCES machines(id) ON DELETE SET NULL,
    FOREIGN KEY (subagent_id) REFERENCES subagents(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS session_turns (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id INTEGER NOT NULL,
    turn_number INTEGER NOT NULL,
    request_event_id INTEGER NOT NULL,
    timestamp TIMESTAMP NOT NULL,
    user_input_tokens INTEGER,
    assistant_output_tokens INTEGER,
    total_tokens INTEGER,
    duration_ms INTEGER,
    metadata JSON,
    FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE CASCADE,
    FOREIGN KEY (request_event_id) REFERENCES request_events(id) ON DELETE CASCADE
);

-- ============================================================================
-- Cache Analytics Tables
-- ============================================================================

CREATE TABLE IF NOT EXISTS cache_entries (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    cache_key TEXT NOT NULL UNIQUE,
    cache_type TEXT NOT NULL,
    content_hash TEXT,
    created_at TIMESTAMP NOT NULL,
    last_accessed_at TIMESTAMP,
    access_count INTEGER DEFAULT 0,
    hit_count INTEGER DEFAULT 0,
    miss_count INTEGER DEFAULT 0,
    size_bytes INTEGER,
    ttl_seconds INTEGER,
    expires_at TIMESTAMP,
    is_valid BOOLEAN DEFAULT 1,
    metadata JSON
);

CREATE TABLE IF NOT EXISTS cache_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    request_event_id INTEGER NOT NULL,
    cache_entry_id INTEGER,
    event_type TEXT NOT NULL,
    timestamp TIMESTAMP NOT NULL,
    cache_type TEXT NOT NULL,
    latency_ms INTEGER,
    saved_bytes INTEGER,
    metadata JSON,
    FOREIGN KEY (request_event_id) REFERENCES request_events(id) ON DELETE CASCADE,
    FOREIGN KEY (cache_entry_id) REFERENCES cache_entries(id) ON DELETE SET NULL
);

-- ============================================================================
-- Skills Analytics Tables
-- ============================================================================

CREATE TABLE IF NOT EXISTS skills (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    skill_id TEXT NOT NULL UNIQUE,
    skill_name TEXT NOT NULL,
    skill_category TEXT,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT 1,
    metadata JSON
);

CREATE TABLE IF NOT EXISTS skill_invocations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    request_event_id INTEGER NOT NULL,
    subagent_request_id INTEGER,
    skill_id INTEGER NOT NULL,
    invocation_timestamp TIMESTAMP NOT NULL,
    duration_ms INTEGER,
    success BOOLEAN DEFAULT 1,
    error_message TEXT,
    input_size_bytes INTEGER,
    output_size_bytes INTEGER,
    estimated_tokens INTEGER,
    metadata JSON,
    FOREIGN KEY (request_event_id) REFERENCES request_events(id) ON DELETE CASCADE,
    FOREIGN KEY (subagent_request_id) REFERENCES subagent_requests(id) ON DELETE SET NULL,
    FOREIGN KEY (skill_id) REFERENCES skills(id) ON DELETE CASCADE
);

-- ============================================================================
-- Provider and Model Tracking Tables
-- ============================================================================

CREATE TABLE IF NOT EXISTS providers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    provider_id TEXT NOT NULL UNIQUE,
    provider_name TEXT NOT NULL,
    provider_type TEXT,
    base_url TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT 1,
    metadata JSON
);

CREATE TABLE IF NOT EXISTS models (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    model_id TEXT NOT NULL UNIQUE,
    model_name TEXT NOT NULL,
    provider_id INTEGER NOT NULL,
    model_version TEXT,
    context_window INTEGER,
    input_cost_per_1k_tokens_cents INTEGER,
    output_cost_per_1k_tokens_cents INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT 1,
    metadata JSON,
    FOREIGN KEY (provider_id) REFERENCES providers(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS model_usage_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    model_id INTEGER NOT NULL,
    effective_from TIMESTAMP NOT NULL,
    effective_to TIMESTAMP,
    input_cost_per_1k_tokens_cents INTEGER,
    output_cost_per_1k_tokens_cents INTEGER,
    context_window INTEGER,
    metadata JSON,
    FOREIGN KEY (model_id) REFERENCES models(id) ON DELETE CASCADE
);

-- ============================================================================
-- Derived Metrics and Aggregation Tables
-- ============================================================================

CREATE TABLE IF NOT EXISTS hourly_aggregations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp_hour TIMESTAMP NOT NULL,
    user_id INTEGER,
    machine_id INTEGER,
    provider_id INTEGER,
    model_id INTEGER,
    subagent_id INTEGER,
    total_requests INTEGER DEFAULT 0,
    total_tokens INTEGER DEFAULT 0,
    total_cost_cents INTEGER DEFAULT 0,
    avg_response_time_ms REAL,
    success_rate REAL,
    metadata JSON,
    UNIQUE(timestamp_hour, user_id, machine_id, provider_id, model_id, subagent_id),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (machine_id) REFERENCES machines(id) ON DELETE CASCADE,
    FOREIGN KEY (provider_id) REFERENCES providers(id) ON DELETE CASCADE,
    FOREIGN KEY (model_id) REFERENCES models(id) ON DELETE CASCADE,
    FOREIGN KEY (subagent_id) REFERENCES subagents(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS daily_aggregations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp_day DATE NOT NULL,
    user_id INTEGER,
    machine_id INTEGER,
    provider_id INTEGER,
    model_id INTEGER,
    subagent_id INTEGER,
    total_requests INTEGER DEFAULT 0,
    total_tokens INTEGER DEFAULT 0,
    total_cost_cents INTEGER DEFAULT 0,
    avg_response_time_ms REAL,
    success_rate REAL,
    metadata JSON,
    UNIQUE(timestamp_day, user_id, machine_id, provider_id, model_id, subagent_id),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (machine_id) REFERENCES machines(id) ON DELETE CASCADE,
    FOREIGN KEY (provider_id) REFERENCES providers(id) ON DELETE CASCADE,
    FOREIGN KEY (model_id) REFERENCES models(id) ON DELETE CASCADE,
    FOREIGN KEY (subagent_id) REFERENCES subagents(id) ON DELETE CASCADE
);

-- ============================================================================
-- Configuration Data Tables
-- ============================================================================

CREATE TABLE IF NOT EXISTS configuration (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    config_key TEXT NOT NULL UNIQUE,
    config_value TEXT NOT NULL,
    config_type TEXT NOT NULL,
    description TEXT,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_by TEXT,
    metadata JSON
);

-- ============================================================================
-- Audit and System Tables
-- ============================================================================

CREATE TABLE IF NOT EXISTS audit_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp TIMESTAMP NOT NULL,
    user_id INTEGER,
    action TEXT NOT NULL,
    resource_type TEXT NOT NULL,
    resource_id TEXT,
    changes JSON,
    ip_address TEXT,
    user_agent TEXT,
    metadata JSON,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS system_health (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp TIMESTAMP NOT NULL,
    metric_name TEXT NOT NULL,
    metric_value REAL NOT NULL,
    metric_unit TEXT,
    metadata JSON
);

-- ============================================================================
-- Migration Tracking Table
-- ============================================================================

CREATE TABLE IF NOT EXISTS schema_migrations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    version TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    rollback_sql TEXT,
    checksum TEXT
);

-- Record this migration
INSERT OR IGNORE INTO schema_migrations (version, name, checksum) 
VALUES ('001', 'initial_schema', 'sha256_placeholder');

-- ============================================================================
-- Indexes
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_users_user_id ON users(user_id);
CREATE INDEX IF NOT EXISTS idx_users_created_at ON users(created_at);

CREATE INDEX IF NOT EXISTS idx_machines_machine_id ON machines(machine_id);
CREATE INDEX IF NOT EXISTS idx_machines_hostname ON machines(hostname);

CREATE INDEX IF NOT EXISTS idx_client_keys_key_id ON client_keys(key_id);
CREATE INDEX IF NOT EXISTS idx_client_keys_user_id ON client_keys(user_id);
CREATE INDEX IF NOT EXISTS idx_client_keys_machine_id ON client_keys(machine_id);

CREATE INDEX IF NOT EXISTS idx_request_events_event_id ON request_events(event_id);
CREATE INDEX IF NOT EXISTS idx_request_events_timestamp ON request_events(timestamp);
CREATE INDEX IF NOT EXISTS idx_request_events_pipeline_stage ON request_events(pipeline_stage);
CREATE INDEX IF NOT EXISTS idx_request_events_request_hash ON request_events(request_hash);
CREATE INDEX IF NOT EXISTS idx_request_events_user_id ON request_events(user_id);
CREATE INDEX IF NOT EXISTS idx_request_events_client_key_id ON request_events(client_key_id);

CREATE INDEX IF NOT EXISTS idx_response_events_request_event_id ON response_events(request_event_id);
CREATE INDEX IF NOT EXISTS idx_response_events_timestamp ON response_events(timestamp);
CREATE INDEX IF NOT EXISTS idx_response_events_provider_id ON response_events(provider_id);
CREATE INDEX IF NOT EXISTS idx_response_events_status_code ON response_events(status_code);

CREATE INDEX IF NOT EXISTS idx_subagents_subagent_id ON subagents(subagent_id);
CREATE INDEX IF NOT EXISTS idx_subagents_subagent_name ON subagents(subagent_name);

CREATE INDEX IF NOT EXISTS idx_subagent_requests_request_event_id ON subagent_requests(request_event_id);
CREATE INDEX IF NOT EXISTS idx_subagent_requests_subagent_id ON subagent_requests(subagent_id);
CREATE INDEX IF NOT EXISTS idx_subagent_requests_session_id ON subagent_requests(session_id);
CREATE INDEX IF NOT EXISTS idx_subagent_requests_parent_request_id ON subagent_requests(parent_request_id);

CREATE INDEX IF NOT EXISTS idx_tools_tool_id ON tools(tool_id);
CREATE INDEX IF NOT EXISTS idx_tools_tool_name ON tools(tool_name);
CREATE INDEX IF NOT EXISTS idx_tools_tool_category ON tools(tool_category);

CREATE INDEX IF NOT EXISTS idx_tool_invocations_request_event_id ON tool_invocations(request_event_id);
CREATE INDEX IF NOT EXISTS idx_tool_invocations_tool_id ON tool_invocations(tool_id);
CREATE INDEX IF NOT EXISTS idx_tool_invocations_timestamp ON tool_invocations(invocation_timestamp);

CREATE INDEX IF NOT EXISTS idx_files_file_id ON files(file_id);
CREATE INDEX IF NOT EXISTS idx_files_file_path ON files(file_path);
CREATE INDEX IF NOT EXISTS idx_files_project_path ON files(project_path);
CREATE INDEX IF NOT EXISTS idx_files_last_accessed_at ON files(last_accessed_at);

CREATE INDEX IF NOT EXISTS idx_file_accesses_request_event_id ON file_accesses(request_event_id);
CREATE INDEX IF NOT EXISTS idx_file_accesses_file_id ON file_accesses(file_id);
CREATE INDEX IF NOT EXISTS idx_file_accesses_timestamp ON file_accesses(access_timestamp);

CREATE INDEX IF NOT EXISTS idx_sessions_session_id ON sessions(session_id);
CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_started_at ON sessions(started_at);

CREATE INDEX IF NOT EXISTS idx_session_turns_session_id ON session_turns(session_id);
CREATE INDEX IF NOT EXISTS idx_session_turns_turn_number ON session_turns(turn_number);
CREATE INDEX IF NOT EXISTS idx_session_turns_timestamp ON session_turns(timestamp);

CREATE INDEX IF NOT EXISTS idx_cache_entries_cache_key ON cache_entries(cache_key);
CREATE INDEX IF NOT EXISTS idx_cache_entries_cache_type ON cache_entries(cache_type);
CREATE INDEX IF NOT EXISTS idx_cache_entries_last_accessed_at ON cache_entries(last_accessed_at);

CREATE INDEX IF NOT EXISTS idx_cache_events_request_event_id ON cache_events(request_event_id);
CREATE INDEX IF NOT EXISTS idx_cache_events_event_type ON cache_events(event_type);
CREATE INDEX IF NOT EXISTS idx_cache_events_timestamp ON cache_events(timestamp);

CREATE INDEX IF NOT EXISTS idx_skills_skill_id ON skills(skill_id);
CREATE INDEX IF NOT EXISTS idx_skills_skill_name ON skills(skill_name);
CREATE INDEX IF NOT EXISTS idx_skills_skill_category ON skills(skill_category);

CREATE INDEX IF NOT EXISTS idx_skill_invocations_request_event_id ON skill_invocations(request_event_id);
CREATE INDEX IF NOT EXISTS idx_skill_invocations_skill_id ON skill_invocations(skill_id);
CREATE INDEX IF NOT EXISTS idx_skill_invocations_timestamp ON skill_invocations(invocation_timestamp);

CREATE INDEX IF NOT EXISTS idx_providers_provider_id ON providers(provider_id);
CREATE INDEX IF NOT EXISTS idx_providers_provider_name ON providers(provider_name);

CREATE INDEX IF NOT EXISTS idx_models_model_id ON models(model_id);
CREATE INDEX IF NOT EXISTS idx_models_provider_id ON models(provider_id);
CREATE INDEX IF NOT EXISTS idx_models_model_name ON models(model_name);

CREATE INDEX IF NOT EXISTS idx_model_usage_history_model_id ON model_usage_history(model_id);
CREATE INDEX IF NOT EXISTS idx_model_usage_history_effective_from ON model_usage_history(effective_from);

CREATE INDEX IF NOT EXISTS idx_hourly_aggregations_timestamp_hour ON hourly_aggregations(timestamp_hour);
CREATE INDEX IF NOT EXISTS idx_hourly_aggregations_user_id ON hourly_aggregations(user_id);

CREATE INDEX IF NOT EXISTS idx_daily_aggregations_timestamp_day ON daily_aggregations(timestamp_day);
CREATE INDEX IF NOT EXISTS idx_daily_aggregations_user_id ON daily_aggregations(user_id);

CREATE INDEX IF NOT EXISTS idx_configuration_config_key ON configuration(config_key);

CREATE INDEX IF NOT EXISTS idx_audit_log_timestamp ON audit_log(timestamp);
CREATE INDEX IF NOT EXISTS idx_audit_log_user_id ON audit_log(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_log_action ON audit_log(action);

CREATE INDEX IF NOT EXISTS idx_system_health_timestamp ON system_health(timestamp);
CREATE INDEX IF NOT EXISTS idx_system_health_metric_name ON system_health(metric_name);

-- ============================================================================
-- Triggers for Automatic Timestamp Updates
-- ============================================================================

CREATE TRIGGER IF NOT EXISTS update_users_timestamp 
AFTER UPDATE ON users
BEGIN
    UPDATE users SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

CREATE TRIGGER IF NOT EXISTS update_machines_timestamp 
AFTER UPDATE ON machines
BEGIN
    UPDATE machines SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

CREATE TRIGGER IF NOT EXISTS update_subagents_timestamp 
AFTER UPDATE ON subagents
BEGIN
    UPDATE subagents SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

CREATE TRIGGER IF NOT EXISTS update_tools_timestamp 
AFTER UPDATE ON tools
BEGIN
    UPDATE tools SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

CREATE TRIGGER IF NOT EXISTS update_skills_timestamp 
AFTER UPDATE ON skills
BEGIN
    UPDATE skills SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

CREATE TRIGGER IF NOT EXISTS update_providers_timestamp 
AFTER UPDATE ON providers
BEGIN
    UPDATE providers SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

CREATE TRIGGER IF NOT EXISTS update_models_timestamp 
AFTER UPDATE ON models
BEGIN
    UPDATE models SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

CREATE TRIGGER IF NOT EXISTS update_files_timestamp 
AFTER UPDATE ON files
BEGIN
    UPDATE files SET 
        updated_at = CURRENT_TIMESTAMP,
        last_accessed_at = CURRENT_TIMESTAMP 
    WHERE id = NEW.id;
END;

-- ============================================================================
-- Views for Common Queries
-- ============================================================================

CREATE VIEW IF NOT EXISTS v_request_summary AS
SELECT 
    re.id,
    re.timestamp,
    re.pipeline_stage,
    re.request_size_bytes,
    re.estimated_tokens,
    re.request_hash,
    u.username,
    m.hostname,
    ck.key_name,
    s.subagent_name,
    p.provider_name,
    mo.model_name,
    resp.response_size_bytes,
    resp.response_time_ms,
    resp.status_code,
    resp.success
FROM request_events re
LEFT JOIN users u ON re.user_id = u.id
LEFT JOIN machines m ON re.machine_id = m.id
LEFT JOIN client_keys ck ON re.client_key_id = ck.id
LEFT JOIN subagent_requests sr ON re.id = sr.request_event_id
LEFT JOIN subagents s ON sr.subagent_id = s.id
LEFT JOIN response_events resp ON re.id = resp.request_event_id
LEFT JOIN providers p ON resp.provider_id = p.id
LEFT JOIN models mo ON resp.model_id = mo.id;

CREATE VIEW IF NOT EXISTS v_daily_cost_summary AS
SELECT 
    DATE(timestamp) as date,
    u.username,
    p.provider_name,
    mo.model_name,
    COUNT(*) as total_requests,
    SUM(re.estimated_tokens) as total_tokens,
    SUM(resp.response_time_ms) as total_response_time_ms,
    AVG(resp.response_time_ms) as avg_response_time_ms,
    SUM(CASE WHEN resp.success = 1 THEN 1 ELSE 0 END) as successful_requests,
    SUM(CASE WHEN resp.success = 0 THEN 1 ELSE 0 END) as failed_requests
FROM request_events re
LEFT JOIN response_events resp ON re.id = resp.request_event_id
LEFT JOIN users u ON re.user_id = u.id
LEFT JOIN providers p ON resp.provider_id = p.id
LEFT JOIN models mo ON resp.model_id = mo.id
GROUP BY DATE(timestamp), u.username, p.provider_name, mo.model_name;

CREATE VIEW IF NOT EXISTS v_tool_usage_summary AS
SELECT 
    DATE(ti.invocation_timestamp) as date,
    t.tool_name,
    t.tool_category,
    COUNT(*) as total_invocations,
    SUM(ti.duration_ms) as total_duration_ms,
    AVG(ti.duration_ms) as avg_duration_ms,
    SUM(CASE WHEN ti.success = 1 THEN 1 ELSE 0 END) as successful_invocations,
    SUM(CASE WHEN ti.success = 0 THEN 1 ELSE 0 END) as failed_invocations,
    SUM(ti.estimated_tokens) as total_tokens
FROM tool_invocations ti
LEFT JOIN tools t ON ti.tool_id = t.id
GROUP BY DATE(ti.invocation_timestamp), t.tool_name, t.tool_category;

CREATE VIEW IF NOT EXISTS v_file_access_summary AS
SELECT 
    DATE(fa.access_timestamp) as date,
    f.file_path,
    f.file_extension,
    f.language,
    COUNT(*) as total_accesses,
    SUM(fa.bytes_read) as total_bytes_read,
    SUM(fa.bytes_written) as total_bytes_written,
    SUM(fa.estimated_tokens) as total_tokens
FROM file_accesses fa
LEFT JOIN files f ON fa.file_id = f.id
GROUP BY DATE(fa.access_timestamp), f.file_path, f.file_extension, f.language;

CREATE VIEW IF NOT EXISTS v_cache_performance_summary AS
SELECT 
    DATE(ce.timestamp) as date,
    ce.cache_type,
    COUNT(*) as total_events,
    SUM(CASE WHEN ce.event_type = 'hit' THEN 1 ELSE 0 END) as total_hits,
    SUM(CASE WHEN ce.event_type = 'miss' THEN 1 ELSE 0 END) as total_misses,
    CAST(SUM(CASE WHEN ce.event_type = 'hit' THEN 1 ELSE 0 END) AS FLOAT) / COUNT(*) as hit_rate,
    SUM(ce.saved_bytes) as total_saved_bytes,
    AVG(ce.latency_ms) as avg_latency_ms
FROM cache_events ce
GROUP BY DATE(ce.timestamp), ce.cache_type;

COMMIT;
