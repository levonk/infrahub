-- AI Analytics Pipeline - SQLite Database Schema
-- Single-tenant analytics database for AI request pipeline monitoring
-- Supports user attribution, subagent tracking, tool analytics, file analytics, and session analysis

-- Enable foreign keys
PRAGMA foreign_keys = ON;

-- ============================================================================
-- User Attribution Tables
-- ============================================================================

-- Users table - tracks individual users
CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT NOT NULL UNIQUE,  -- External user identifier
    username TEXT NOT NULL,
    email TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT 1,
    metadata JSON,  -- Additional user metadata
    INDEX idx_users_user_id (user_id),
    INDEX idx_users_created_at (created_at)
);

-- Machines table - tracks machines/devices
CREATE TABLE IF NOT EXISTS machines (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    machine_id TEXT NOT NULL UNIQUE,  -- External machine identifier
    hostname TEXT NOT NULL,
    os_type TEXT,  -- linux, macos, windows
    os_version TEXT,
    cpu_cores INTEGER,
    memory_gb INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT 1,
    metadata JSON,
    INDEX idx_machines_machine_id (machine_id),
    INDEX idx_machines_hostname (hostname)
);

-- Client keys table - tracks API keys/tokens
CREATE TABLE IF NOT EXISTS client_keys (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    key_id TEXT NOT NULL UNIQUE,  -- External key identifier
    key_name TEXT NOT NULL,
    key_type TEXT NOT NULL,  -- api_key, jwt_token, session_token
    user_id INTEGER,
    machine_id INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP,
    is_active BOOLEAN DEFAULT 1,
    last_used_at TIMESTAMP,
    metadata JSON,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
    FOREIGN KEY (machine_id) REFERENCES machines(id) ON DELETE SET NULL,
    INDEX idx_client_keys_key_id (key_id),
    INDEX idx_client_keys_user_id (user_id),
    INDEX idx_client_keys_machine_id (machine_id)
);

-- ============================================================================
-- Request/Response Events Tables
-- ============================================================================

-- Raw request events table - stores all incoming requests
CREATE TABLE IF NOT EXISTS request_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    event_id TEXT NOT NULL UNIQUE,  -- UUID for event correlation
    timestamp TIMESTAMP NOT NULL,
    client_key_id INTEGER,
    user_id INTEGER,
    machine_id INTEGER,
    pipeline_stage TEXT NOT NULL,  -- pre_headroom, post_omniroute, post_ironproxy
    request_size_bytes INTEGER NOT NULL,
    request_hash TEXT NOT NULL,  -- Content hash for correlation
    estimated_tokens INTEGER,
    content_type TEXT,
    method TEXT,  -- GET, POST, etc.
    endpoint TEXT,
    headers JSON,
    metadata JSON,  -- Additional request metadata
    FOREIGN KEY (client_key_id) REFERENCES client_keys(id) ON DELETE SET NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
    FOREIGN KEY (machine_id) REFERENCES machines(id) ON DELETE SET NULL,
    INDEX idx_request_events_event_id (event_id),
    INDEX idx_request_events_timestamp (timestamp),
    INDEX idx_request_events_pipeline_stage (pipeline_stage),
    INDEX idx_request_events_request_hash (request_hash),
    INDEX idx_request_events_user_id (user_id),
    INDEX idx_request_events_client_key_id (client_key_id)
);

-- Response events table - stores all responses
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
    FOREIGN KEY (request_event_id) REFERENCES request_events(id) ON DELETE CASCADE,
    INDEX idx_response_events_request_event_id (request_event_id),
    INDEX idx_response_events_timestamp (timestamp),
    INDEX idx_response_events_provider_id (provider_id),
    INDEX idx_response_events_status_code (status_code)
);

-- ============================================================================
-- Subagent Attribution Tables
-- ============================================================================

-- Subagents table - tracks AI agents (Claude Code, Codex, Pi, Devin, etc.)
CREATE TABLE IF NOT EXISTS subagents (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    subagent_id TEXT NOT NULL UNIQUE,  -- External subagent identifier
    subagent_name TEXT NOT NULL,  -- claude-code, codex, pi, devin
    subagent_type TEXT NOT NULL,  -- coding_agent, chat_agent, tool_agent
    version TEXT,
    provider TEXT,  -- anthropic, openai, etc.
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT 1,
    metadata JSON,
    INDEX idx_subagents_subagent_id (subagent_id),
    INDEX idx_subagents_subagent_name (subagent_name)
);

-- Subagent requests table - tracks requests made by subagents
CREATE TABLE IF NOT EXISTS subagent_requests (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    request_event_id INTEGER NOT NULL,
    subagent_id INTEGER NOT NULL,
    parent_request_id INTEGER,  -- For nested subagent calls
    turn_number INTEGER,  -- Turn number in conversation
    session_id TEXT,  -- Session identifier
    metadata JSON,
    FOREIGN KEY (request_event_id) REFERENCES request_events(id) ON DELETE CASCADE,
    FOREIGN KEY (subagent_id) REFERENCES subagents(id) ON DELETE CASCADE,
    INDEX idx_subagent_requests_request_event_id (request_event_id),
    INDEX idx_subagent_requests_subagent_id (subagent_id),
    INDEX idx_subagent_requests_session_id (session_id),
    INDEX idx_subagent_requests_parent_request_id (parent_request_id)
);

-- ============================================================================
-- Tool Analytics Tables
-- ============================================================================

-- Tools table - tracks available tools
CREATE TABLE IF NOT EXISTS tools (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    tool_id TEXT NOT NULL UNIQUE,  -- External tool identifier
    tool_name TEXT NOT NULL,  -- file_read, web_search, code_exec, etc.
    tool_category TEXT,  -- file_ops, web, code, system
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT 1,
    metadata JSON,
    INDEX idx_tools_tool_id (tool_id),
    INDEX idx_tools_tool_name (tool_name),
    INDEX idx_tools_tool_category (tool_category)
);

-- Tool invocations table - tracks tool usage
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
    FOREIGN KEY (tool_id) REFERENCES tools(id) ON DELETE CASCADE,
    INDEX idx_tool_invocations_request_event_id (request_event_id),
    INDEX idx_tool_invocations_tool_id (tool_id),
    INDEX idx_tool_invocations_timestamp (invocation_timestamp)
);

-- ============================================================================
-- File Analytics Tables
-- ============================================================================

-- Files table - tracks accessed files
CREATE TABLE IF NOT EXISTS files (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    file_id TEXT NOT NULL UNIQUE,  -- External file identifier (path hash)
    file_path TEXT NOT NULL,
    file_name TEXT NOT NULL,
    file_extension TEXT,
    file_size_bytes INTEGER,
    language TEXT,  -- python, javascript, etc.
    project_path TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_accessed_at TIMESTAMP,
    access_count INTEGER DEFAULT 0,
    total_tokens_used INTEGER DEFAULT 0,
    metadata JSON,
    INDEX idx_files_file_id (file_id),
    INDEX idx_files_file_path (file_path),
    INDEX idx_files_project_path (project_path),
    INDEX idx_files_last_accessed_at (last_accessed_at)
);

-- File accesses table - tracks file access events
CREATE TABLE IF NOT EXISTS file_accesses (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    request_event_id INTEGER NOT NULL,
    subagent_request_id INTEGER,
    file_id INTEGER NOT NULL,
    access_timestamp TIMESTAMP NOT NULL,
    access_type TEXT NOT NULL,  -- read, write, delete
    bytes_read INTEGER,
    bytes_written INTEGER,
    estimated_tokens INTEGER,
    metadata JSON,
    FOREIGN KEY (request_event_id) REFERENCES request_events(id) ON DELETE CASCADE,
    FOREIGN KEY (subagent_request_id) REFERENCES subagent_requests(id) ON DELETE SET NULL,
    FOREIGN KEY (file_id) REFERENCES files(id) ON DELETE CASCADE,
    INDEX idx_file_accesses_request_event_id (request_event_id),
    INDEX idx_file_accesses_file_id (file_id),
    INDEX idx_file_accesses_timestamp (access_timestamp)
);

-- ============================================================================
-- Session Analytics Tables
-- ============================================================================

-- Sessions table - tracks conversation sessions
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
    FOREIGN KEY (subagent_id) REFERENCES subagents(id) ON DELETE SET NULL,
    INDEX idx_sessions_session_id (session_id),
    INDEX idx_sessions_user_id (user_id),
    INDEX idx_sessions_started_at (started_at)
);

-- Session turns table - tracks individual turns in sessions
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
    FOREIGN KEY (request_event_id) REFERENCES request_events(id) ON DELETE CASCADE,
    INDEX idx_session_turns_session_id (session_id),
    INDEX idx_session_turns_turn_number (turn_number),
    INDEX idx_session_turns_timestamp (timestamp)
);

-- ============================================================================
-- Cache Analytics Tables
-- ============================================================================

-- Cache entries table - tracks cache performance
CREATE TABLE IF NOT EXISTS cache_entries (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    cache_key TEXT NOT NULL UNIQUE,
    cache_type TEXT NOT NULL,  -- response_cache, content_cache, model_cache
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
    metadata JSON,
    INDEX idx_cache_entries_cache_key (cache_key),
    INDEX idx_cache_entries_cache_type (cache_type),
    INDEX idx_cache_entries_last_accessed_at (last_accessed_at)
);

-- Cache events table - tracks cache hit/miss events
CREATE TABLE IF NOT EXISTS cache_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    request_event_id INTEGER NOT NULL,
    cache_entry_id INTEGER,
    event_type TEXT NOT NULL,  -- hit, miss, invalidate, update
    timestamp TIMESTAMP NOT NULL,
    cache_type TEXT NOT NULL,
    latency_ms INTEGER,
    saved_bytes INTEGER,
    metadata JSON,
    FOREIGN KEY (request_event_id) REFERENCES request_events(id) ON DELETE CASCADE,
    FOREIGN KEY (cache_entry_id) REFERENCES cache_entries(id) ON DELETE SET NULL,
    INDEX idx_cache_events_request_event_id (request_event_id),
    INDEX idx_cache_events_event_type (event_type),
    INDEX idx_cache_events_timestamp (timestamp)
);

-- ============================================================================
-- Skills Analytics Tables
-- ============================================================================

-- Skills table - tracks available skills
CREATE TABLE IF NOT EXISTS skills (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    skill_id TEXT NOT NULL UNIQUE,
    skill_name TEXT NOT NULL,
    skill_category TEXT,  -- automation, analysis, monitoring
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT 1,
    metadata JSON,
    INDEX idx_skills_skill_id (skill_id),
    INDEX idx_skills_skill_name (skill_name),
    INDEX idx_skills_skill_category (skill_category)
);

-- Skill invocations table - tracks skill usage
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
    FOREIGN KEY (skill_id) REFERENCES skills(id) ON DELETE CASCADE,
    INDEX idx_skill_invocations_request_event_id (request_event_id),
    INDEX idx_skill_invocations_skill_id (skill_id),
    INDEX idx_skill_invocations_timestamp (invocation_timestamp)
);

-- ============================================================================
-- Provider and Model Tracking Tables
-- ============================================================================

-- Providers table - tracks AI providers
CREATE TABLE IF NOT EXISTS providers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    provider_id TEXT NOT NULL UNIQUE,
    provider_name TEXT NOT NULL,  -- anthropic, openai, google, etc.
    provider_type TEXT,  -- api, hosted, local
    base_url TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT 1,
    metadata JSON,
    INDEX idx_providers_provider_id (provider_id),
    INDEX idx_providers_provider_name (provider_name)
);

-- Models table - tracks AI models
CREATE TABLE IF NOT EXISTS models (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    model_id TEXT NOT NULL UNIQUE,
    model_name TEXT NOT NULL,  -- claude-3-opus, gpt-4, etc.
    provider_id INTEGER NOT NULL,
    model_version TEXT,
    context_window INTEGER,
    input_cost_per_1k_tokens_cents INTEGER,
    output_cost_per_1k_tokens_cents INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT 1,
    metadata JSON,
    FOREIGN KEY (provider_id) REFERENCES providers(id) ON DELETE CASCADE,
    INDEX idx_models_model_id (model_id),
    INDEX idx_models_provider_id (provider_id),
    INDEX idx_models_model_name (model_name)
);

-- Model usage history table - tracks model changes over time
CREATE TABLE IF NOT EXISTS model_usage_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    model_id INTEGER NOT NULL,
    effective_from TIMESTAMP NOT NULL,
    effective_to TIMESTAMP,
    input_cost_per_1k_tokens_cents INTEGER,
    output_cost_per_1k_tokens_cents INTEGER,
    context_window INTEGER,
    metadata JSON,
    FOREIGN KEY (model_id) REFERENCES models(id) ON DELETE CASCADE,
    INDEX idx_model_usage_history_model_id (model_id),
    INDEX idx_model_usage_history_effective_from (effective_from)
);

-- ============================================================================
-- Derived Metrics and Aggregation Tables
-- ============================================================================

-- Hourly aggregation table
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
    FOREIGN KEY (subagent_id) REFERENCES subagents(id) ON DELETE CASCADE,
    INDEX idx_hourly_aggregations_timestamp_hour (timestamp_hour),
    INDEX idx_hourly_aggregations_user_id (user_id)
);

-- Daily aggregation table
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
    FOREIGN KEY (subagent_id) REFERENCES subagents(id) ON DELETE CASCADE,
    INDEX idx_daily_aggregations_timestamp_day (timestamp_day),
    INDEX idx_daily_aggregations_user_id (user_id)
);

-- ============================================================================
-- Configuration Data Tables
-- ============================================================================

-- Configuration table - stores system configuration
CREATE TABLE IF NOT EXISTS configuration (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    config_key TEXT NOT NULL UNIQUE,
    config_value TEXT NOT NULL,
    config_type TEXT NOT NULL,  -- string, integer, boolean, json
    description TEXT,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_by TEXT,
    metadata JSON,
    INDEX idx_configuration_config_key (config_key)
);

-- ============================================================================
-- Audit and System Tables
-- ============================================================================

-- Audit log table - tracks system changes
CREATE TABLE IF NOT EXISTS audit_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp TIMESTAMP NOT NULL,
    user_id INTEGER,
    action TEXT NOT NULL,  -- create, update, delete, etc.
    resource_type TEXT NOT NULL,  -- user, config, etc.
    resource_id TEXT,
    changes JSON,
    ip_address TEXT,
    user_agent TEXT,
    metadata JSON,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
    INDEX idx_audit_log_timestamp (timestamp),
    INDEX idx_audit_log_user_id (user_id),
    INDEX idx_audit_log_action (action)
);

-- System health table - tracks system metrics
CREATE TABLE IF NOT EXISTS system_health (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp TIMESTAMP NOT NULL,
    metric_name TEXT NOT NULL,
    metric_value REAL NOT NULL,
    metric_unit TEXT,
    metadata JSON,
    INDEX idx_system_health_timestamp (timestamp),
    INDEX idx_system_health_metric_name (metric_name)
);

-- ============================================================================
-- Triggers for Automatic Timestamp Updates
-- ============================================================================

-- Update users.updated_at on row update
CREATE TRIGGER IF NOT EXISTS update_users_timestamp 
AFTER UPDATE ON users
BEGIN
    UPDATE users SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

-- Update machines.updated_at on row update
CREATE TRIGGER IF NOT EXISTS update_machines_timestamp 
AFTER UPDATE ON machines
BEGIN
    UPDATE machines SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

-- Update subagents.updated_at on row update
CREATE TRIGGER IF NOT EXISTS update_subagents_timestamp 
AFTER UPDATE ON subagents
BEGIN
    UPDATE subagents SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

-- Update tools.updated_at on row update
CREATE TRIGGER IF NOT EXISTS update_tools_timestamp 
AFTER UPDATE ON tools
BEGIN
    UPDATE tools SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

-- Update skills.updated_at on row update
CREATE TRIGGER IF NOT EXISTS update_skills_timestamp 
AFTER UPDATE ON skills
BEGIN
    UPDATE skills SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

-- Update providers.updated_at on row update
CREATE TRIGGER IF NOT EXISTS update_providers_timestamp 
AFTER UPDATE ON providers
BEGIN
    UPDATE providers SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

-- Update models.updated_at on row update
CREATE TRIGGER IF NOT EXISTS update_models_timestamp 
AFTER UPDATE ON models
BEGIN
    UPDATE models SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

-- Update files.updated_at and last_accessed_at on row update
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

-- Request summary view
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

-- Daily cost summary view
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

-- Tool usage summary view
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

-- File access summary view
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

-- Cache performance summary view
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
