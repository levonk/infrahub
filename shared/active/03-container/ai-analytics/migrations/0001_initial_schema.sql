-- Migration 0001: Initial Schema
-- This migration creates the initial database schema for AI Analytics Pipeline
-- All tables, indexes, and views are created in this initial migration

-- Note: The actual schema content should be included here for production use
-- For development, we'll reference the main schema file
-- In production, copy the content of schema.sql into this migration file

-- Enable foreign keys
PRAGMA foreign_keys = ON;

-- ============================================================================
-- USER ATTRIBUTION TABLES
-- ============================================================================

-- Users table: Individual users who make AI requests
CREATE TABLE users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT NOT NULL UNIQUE,
    username TEXT,
    email TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Machines table: Physical or virtual machines making requests
CREATE TABLE machines (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    machine_id TEXT NOT NULL UNIQUE,
    hostname TEXT,
    os_type TEXT,
    os_version TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Client keys table: API keys or authentication tokens
CREATE TABLE client_keys (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    key_id TEXT NOT NULL UNIQUE,
    key_hash TEXT NOT NULL,
    user_id INTEGER,
    machine_id INTEGER,
    key_type TEXT NOT NULL,
    provider TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    expires_at TEXT,
    is_active INTEGER NOT NULL DEFAULT 1,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
    FOREIGN KEY (machine_id) REFERENCES machines(id) ON DELETE SET NULL
);

-- ============================================================================
-- REQUEST/RESPONSE EVENT TABLES
-- ============================================================================

-- Request events: Individual AI API requests
CREATE TABLE request_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    event_id TEXT NOT NULL UNIQUE,
    timestamp TEXT NOT NULL,
    user_id INTEGER,
    machine_id INTEGER,
    client_key_id INTEGER,
    ai_client TEXT NOT NULL,
    provider TEXT NOT NULL,
    model TEXT NOT NULL,
    input_type TEXT NOT NULL,
    input_tokens INTEGER,
    output_tokens INTEGER,
    total_tokens INTEGER,
    cache_read_tokens INTEGER,
    cache_write_tokens INTEGER,
    request_duration_ms INTEGER,
    status_code INTEGER,
    error_message TEXT,
    request_size_bytes INTEGER,
    response_size_bytes INTEGER,
    cost_usd REAL,
    session_id TEXT,
    parent_event_id TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
    FOREIGN KEY (machine_id) REFERENCES machines(id) ON DELETE SET NULL,
    FOREIGN KEY (client_key_id) REFERENCES client_keys(id) ON DELETE SET NULL
);

-- ============================================================================
-- SUBAGENT ATTRIBUTION TABLES
-- ============================================================================

-- Subagent types: Different types of AI subagents
CREATE TABLE subagent_types (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    type_name TEXT NOT NULL UNIQUE,
    description TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Subagent events: Tracking subagent usage within requests
CREATE TABLE subagent_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    event_id TEXT NOT NULL UNIQUE,
    request_event_id TEXT NOT NULL,
    subagent_type_id INTEGER NOT NULL,
    subagent_name TEXT NOT NULL,
    start_time TEXT NOT NULL,
    end_time TEXT,
    duration_ms INTEGER,
    input_tokens INTEGER,
    output_tokens INTEGER,
    tool_calls_count INTEGER,
    status TEXT NOT NULL,
    error_message TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (request_event_id) REFERENCES request_events(event_id) ON DELETE CASCADE,
    FOREIGN KEY (subagent_type_id) REFERENCES subagent_types(id) ON DELETE RESTRICT
);

-- ============================================================================
-- PROVIDER AND MODEL ANALYTICS TABLES
-- ============================================================================

-- Provider types: Different AI providers
CREATE TABLE provider_types (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    type_name TEXT NOT NULL UNIQUE,
    description TEXT,
    api_endpoint TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Provider events: Tracking provider usage within requests
CREATE TABLE provider_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    event_id TEXT NOT NULL UNIQUE,
    request_event_id TEXT NOT NULL,
    provider_type TEXT NOT NULL,
    provider_name TEXT NOT NULL,
    model_id TEXT NOT NULL,
    model_name TEXT NOT NULL,
    model_version TEXT,
    start_time TEXT NOT NULL,
    end_time TEXT,
    duration_ms INTEGER,
    input_tokens INTEGER,
    output_tokens INTEGER,
    total_tokens INTEGER,
    cost_usd REAL,
    status TEXT NOT NULL,
    error_message TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (request_event_id) REFERENCES request_events(event_id) ON DELETE CASCADE
);

-- Models: AI models and their metadata
CREATE TABLE models (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    model_id TEXT NOT NULL UNIQUE,
    model_name TEXT NOT NULL,
    provider_type_id INTEGER,
    model_category TEXT,
    version TEXT,
    context_window INTEGER,
    max_tokens INTEGER,
    pricing_input REAL,
    pricing_output REAL,
    is_deprecated INTEGER NOT NULL DEFAULT 0,
    deprecation_date TEXT,
    replacement_model_id TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (provider_type_id) REFERENCES provider_types(id) ON DELETE SET NULL
);

-- Model versions: Historical version tracking
CREATE TABLE model_versions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    model_id TEXT NOT NULL,
    version TEXT NOT NULL,
    first_seen TEXT NOT NULL,
    last_seen TEXT NOT NULL,
    request_count INTEGER NOT NULL DEFAULT 0,
    total_tokens INTEGER DEFAULT 0,
    total_cost REAL DEFAULT 0.0,
    is_deprecated INTEGER NOT NULL DEFAULT 0,
    deprecation_date TEXT,
    replacement_model_id TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    UNIQUE(model_id, version),
    FOREIGN KEY (model_id) REFERENCES models(model_id) ON DELETE CASCADE
);

-- Model performance: Aggregated performance metrics
CREATE TABLE model_performance (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    model_id TEXT NOT NULL,
    version TEXT NOT NULL,
    provider_type TEXT NOT NULL,
    total_requests INTEGER NOT NULL DEFAULT 0,
    successful_requests INTEGER DEFAULT 0,
    failed_requests INTEGER DEFAULT 0,
    avg_latency_ms REAL DEFAULT 0.0,
    avg_input_tokens INTEGER DEFAULT 0,
    avg_output_tokens INTEGER DEFAULT 0,
    total_cost REAL DEFAULT 0.0,
    cost_per_1k_tokens REAL DEFAULT 0.0,
    period_start TEXT NOT NULL,
    period_end TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    UNIQUE(model_id, version, period_start, period_end)
);

-- ============================================================================
-- TOOL ANALYTICS TABLES
-- ============================================================================

-- Tool types: Different types of tools used by AI agents
CREATE TABLE tool_types (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    type_name TEXT NOT NULL UNIQUE,
    category TEXT,
    description TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Tool usage events: Individual tool invocations
CREATE TABLE tool_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    event_id TEXT NOT NULL UNIQUE,
    request_event_id TEXT NOT NULL,
    subagent_event_id TEXT,
    tool_type_id INTEGER NOT NULL,
    tool_name TEXT NOT NULL,
    start_time TEXT NOT NULL,
    end_time TEXT,
    duration_ms INTEGER,
    parameters TEXT,
    result TEXT,
    status TEXT NOT NULL,
    error_message TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (request_event_id) REFERENCES request_events(event_id) ON DELETE CASCADE,
    FOREIGN KEY (subagent_event_id) REFERENCES subagent_events(event_id) ON DELETE SET NULL,
    FOREIGN KEY (tool_type_id) REFERENCES tool_types(id) ON DELETE RESTRICT
);

-- Tool heatmaps: Aggregated tool usage statistics
CREATE TABLE tool_heatmaps (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    tool_name TEXT NOT NULL,
    tool_type_id INTEGER,
    user_id INTEGER,
    machine_id INTEGER,
    usage_count INTEGER NOT NULL DEFAULT 0,
    total_duration_ms INTEGER DEFAULT 0,
    success_count INTEGER DEFAULT 0,
    failure_count INTEGER DEFAULT 0,
    last_used_at TEXT,
    period_start TEXT NOT NULL,
    period_end TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
    FOREIGN KEY (machine_id) REFERENCES machines(id) ON DELETE SET NULL,
    FOREIGN KEY (tool_type_id) REFERENCES tool_types(id) ON DELETE SET NULL,
    UNIQUE(tool_name, user_id, machine_id, period_start, period_end)
);

-- ============================================================================
-- FILE ANALYTICS TABLES
-- ============================================================================

-- File access events: File read/write operations by AI agents
CREATE TABLE file_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    event_id TEXT NOT NULL UNIQUE,
    request_event_id TEXT NOT NULL,
    tool_event_id TEXT,
    file_path TEXT NOT NULL,
    file_hash TEXT,
    operation TEXT NOT NULL,
    file_size_bytes INTEGER,
    duration_ms INTEGER,
    status TEXT NOT NULL,
    error_message TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (request_event_id) REFERENCES request_events(event_id) ON DELETE CASCADE,
    FOREIGN KEY (tool_event_id) REFERENCES tool_events(event_id) ON DELETE SET NULL
);

-- File heatmaps: Aggregated file access statistics
CREATE TABLE file_heatmaps (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    file_path TEXT NOT NULL,
    file_hash TEXT,
    user_id INTEGER,
    machine_id INTEGER,
    read_count INTEGER NOT NULL DEFAULT 0,
    write_count INTEGER NOT NULL DEFAULT 0,
    total_bytes_read INTEGER DEFAULT 0,
    total_bytes_written INTEGER DEFAULT 0,
    last_accessed_at TEXT,
    period_start TEXT NOT NULL,
    period_end TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
    FOREIGN KEY (machine_id) REFERENCES machines(id) ON DELETE SET NULL,
    UNIQUE(file_path, user_id, machine_id, period_start, period_end)
);

-- ============================================================================
-- SESSION ANALYTICS TABLES
-- ============================================================================

-- Sessions: Grouping of related requests
CREATE TABLE sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT NOT NULL UNIQUE,
    user_id INTEGER,
    machine_id INTEGER,
    ai_client TEXT NOT NULL,
    start_time TEXT NOT NULL,
    end_time TEXT,
    total_requests INTEGER DEFAULT 0,
    total_tokens INTEGER DEFAULT 0,
    total_cost_usd REAL DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'active',
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
    FOREIGN KEY (machine_id) REFERENCES machines(id) ON DELETE SET NULL
);

-- Session turns: Individual turns within a session
CREATE TABLE session_turns (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    turn_id TEXT NOT NULL UNIQUE,
    session_id TEXT NOT NULL,
    request_event_id TEXT NOT NULL,
    turn_number INTEGER NOT NULL,
    start_time TEXT NOT NULL,
    end_time TEXT,
    input_tokens INTEGER,
    output_tokens INTEGER,
    total_tokens INTEGER,
    cost_usd REAL,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (session_id) REFERENCES sessions(session_id) ON DELETE CASCADE,
    FOREIGN KEY (request_event_id) REFERENCES request_events(event_id) ON DELETE CASCADE
);

-- ============================================================================
-- CACHE ANALYTICS TABLES
-- ============================================================================

-- Cache events: Cache hit/miss events
CREATE TABLE cache_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    event_id TEXT NOT NULL UNIQUE,
    request_event_id TEXT NOT NULL,
    cache_type TEXT NOT NULL,
    cache_key TEXT NOT NULL,
    hit INTEGER NOT NULL,
    tokens_saved INTEGER,
    latency_ms INTEGER,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (request_event_id) REFERENCES request_events(event_id) ON DELETE CASCADE
);

-- Cache statistics: Aggregated cache performance
CREATE TABLE cache_statistics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    cache_type TEXT NOT NULL,
    user_id INTEGER,
    machine_id INTEGER,
    total_requests INTEGER NOT NULL DEFAULT 0,
    cache_hits INTEGER NOT NULL DEFAULT 0,
    cache_misses INTEGER NOT NULL DEFAULT 0,
    total_tokens_saved INTEGER DEFAULT 0,
    hit_rate REAL DEFAULT 0,
    period_start TEXT NOT NULL,
    period_end TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
    FOREIGN KEY (machine_id) REFERENCES machines(id) ON DELETE SET NULL,
    UNIQUE(cache_type, user_id, machine_id, period_start, period_end)
);

-- ============================================================================
-- SKILLS ANALYTICS TABLES
-- ============================================================================

-- Skills: AI skills/capabilities used
CREATE TABLE skills (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    skill_id TEXT NOT NULL UNIQUE,
    skill_name TEXT NOT NULL,
    category TEXT,
    description TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Skill usage events: Individual skill invocations
CREATE TABLE skill_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    event_id TEXT NOT NULL UNIQUE,
    request_event_id TEXT NOT NULL,
    subagent_event_id TEXT,
    skill_id TEXT NOT NULL,
    start_time TEXT NOT NULL,
    end_time TEXT,
    duration_ms INTEGER,
    input_tokens INTEGER,
    output_tokens INTEGER,
    status TEXT NOT NULL,
    error_message TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (request_event_id) REFERENCES request_events(event_id) ON DELETE CASCADE,
    FOREIGN KEY (subagent_event_id) REFERENCES subagent_events(event_id) ON DELETE SET NULL,
    FOREIGN KEY (skill_id) REFERENCES skills(skill_id) ON DELETE RESTRICT
);

-- ============================================================================
-- DERIVED METRICS TABLES
-- ============================================================================

-- Daily metrics: Pre-computed daily aggregations
CREATE TABLE daily_metrics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    metric_date TEXT NOT NULL,
    user_id INTEGER,
    machine_id INTEGER,
    ai_client TEXT,
    provider TEXT,
    model TEXT,
    total_requests INTEGER NOT NULL DEFAULT 0,
    total_tokens INTEGER NOT NULL DEFAULT 0,
    total_cost_usd REAL NOT NULL DEFAULT 0,
    avg_request_duration_ms REAL,
    success_rate REAL,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
    FOREIGN KEY (machine_id) REFERENCES machines(id) ON DELETE SET NULL,
    UNIQUE(metric_date, user_id, machine_id, ai_client, provider, model)
);

-- ============================================================================
-- TIME-SERIES AGGREGATION TABLES
-- ============================================================================

-- Time series data: Flexible time-series aggregations
CREATE TABLE time_series_data (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp TEXT NOT NULL,
    granularity TEXT NOT NULL,
    metric_name TEXT NOT NULL,
    metric_value REAL NOT NULL,
    dimensions TEXT,
    user_id INTEGER,
    machine_id INTEGER,
    ai_client TEXT,
    provider TEXT,
    model TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
    FOREIGN KEY (machine_id) REFERENCES machines(id) ON DELETE SET NULL
);

-- ============================================================================
-- CONFIGURATION DATA TABLES
-- ============================================================================

-- Configuration: System configuration data
CREATE TABLE configuration (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    config_key TEXT NOT NULL UNIQUE,
    config_value TEXT NOT NULL,
    config_type TEXT NOT NULL,
    description TEXT,
    is_sensitive INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Provider configuration: AI provider-specific configuration
CREATE TABLE provider_config (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    provider TEXT NOT NULL,
    config_key TEXT NOT NULL,
    config_value TEXT NOT NULL,
    config_type TEXT NOT NULL,
    description TEXT,
    is_sensitive INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    UNIQUE(provider, config_key)
);

-- Model configuration: AI model-specific configuration
CREATE TABLE model_config (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    provider TEXT NOT NULL,
    model TEXT NOT NULL,
    config_key TEXT NOT NULL,
    config_value TEXT NOT NULL,
    config_type TEXT NOT NULL,
    description TEXT,
    is_sensitive INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    UNIQUE(provider, model, config_key)
);

-- ============================================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================================

-- User attribution indexes
CREATE INDEX idx_request_events_user_id ON request_events(user_id);
CREATE INDEX idx_request_events_machine_id ON request_events(machine_id);
CREATE INDEX idx_request_events_client_key_id ON request_events(client_key_id);

-- Time-based indexes
CREATE INDEX idx_request_events_timestamp ON request_events(timestamp);
CREATE INDEX idx_subagent_events_start_time ON subagent_events(start_time);
CREATE INDEX idx_tool_events_start_time ON tool_events(start_time);
CREATE INDEX idx_file_events_created_at ON file_events(created_at);
CREATE INDEX idx_sessions_start_time ON sessions(start_time);

-- Provider and model indexes
CREATE INDEX idx_request_events_provider ON request_events(provider);
CREATE INDEX idx_request_events_model ON request_events(model);
CREATE INDEX idx_request_events_ai_client ON request_events(ai_client);

-- Session and correlation indexes
CREATE INDEX idx_request_events_session_id ON request_events(session_id);
CREATE INDEX idx_request_events_parent_event_id ON request_events(parent_event_id);
CREATE INDEX idx_subagent_events_request_event_id ON subagent_events(request_event_id);
CREATE INDEX idx_tool_events_request_event_id ON tool_events(request_event_id);
CREATE INDEX idx_tool_events_subagent_event_id ON tool_events(subagent_event_id);
CREATE INDEX idx_file_events_request_event_id ON file_events(request_event_id);
CREATE INDEX idx_file_events_tool_event_id ON file_events(tool_event_id);
CREATE INDEX idx_cache_events_request_event_id ON cache_events(request_event_id);
CREATE INDEX idx_skill_events_request_event_id ON skill_events(request_event_id);
CREATE INDEX idx_skill_events_subagent_event_id ON skill_events(subagent_event_id);

-- Aggregation indexes
CREATE INDEX idx_time_series_data_timestamp_granularity ON time_series_data(timestamp, granularity);
CREATE INDEX idx_time_series_data_metric_name ON time_series_data(metric_name);
CREATE INDEX idx_daily_metrics_metric_date ON daily_metrics(metric_date);

-- Heatmap indexes
CREATE INDEX idx_tool_heatmaps_tool_name ON tool_heatmaps(tool_name);
CREATE INDEX idx_file_heatmaps_file_path ON file_heatmaps(file_path);

-- Cache statistics indexes
CREATE INDEX idx_cache_statistics_cache_type ON cache_statistics(cache_type);
CREATE INDEX idx_cache_statistics_period ON cache_statistics(period_start, period_end);

-- ============================================================================
-- VIEWS FOR COMMON QUERIES
-- ============================================================================

-- Request summary view
CREATE VIEW request_summary AS
SELECT 
    re.id,
    re.event_id,
    re.timestamp,
    u.username,
    u.email,
    m.hostname,
    re.ai_client,
    re.provider,
    re.model,
    re.input_type,
    re.total_tokens,
    re.cost_usd,
    re.status_code,
    re.session_id
FROM request_events re
LEFT JOIN users u ON re.user_id = u.id
LEFT JOIN machines m ON re.machine_id = m.id;

-- Daily cost summary view
CREATE VIEW daily_cost_summary AS
SELECT 
    DATE(timestamp) as date,
    provider,
    model,
    COUNT(*) as request_count,
    SUM(total_tokens) as total_tokens,
    SUM(cost_usd) as total_cost
FROM request_events
GROUP BY DATE(timestamp), provider, model;

-- User activity summary view
CREATE VIEW user_activity_summary AS
SELECT 
    u.username,
    u.email,
    COUNT(re.id) as total_requests,
    SUM(re.total_tokens) as total_tokens,
    SUM(re.cost_usd) as total_cost,
    MIN(re.timestamp) as first_request,
    MAX(re.timestamp) as last_request
FROM users u
LEFT JOIN request_events re ON u.id = re.user_id
GROUP BY u.id;

-- Tool usage summary view
CREATE VIEW tool_usage_summary AS
SELECT 
    te.tool_name,
    tt.category as tool_category,
    COUNT(*) as usage_count,
    AVG(te.duration_ms) as avg_duration_ms,
    SUM(CASE WHEN te.status = 'success' THEN 1 ELSE 0 END) as success_count,
    SUM(CASE WHEN te.status != 'success' THEN 1 ELSE 0 END) as failure_count
FROM tool_events te
JOIN tool_types tt ON te.tool_type_id = tt.id
GROUP BY te.tool_name;

-- Session summary view
CREATE VIEW session_summary AS
SELECT 
    s.session_id,
    u.username,
    s.ai_client,
    s.start_time,
    s.end_time,
    s.total_requests,
    s.total_tokens,
    s.total_cost_usd,
    s.status
FROM sessions s
LEFT JOIN users u ON s.user_id = u.id;

-- Cache performance summary view
CREATE VIEW cache_performance_summary AS
SELECT 
    cs.cache_type,
    cs.user_id,
    u.username,
    cs.total_requests,
    cs.cache_hits,
    cs.cache_misses,
    cs.hit_rate,
    cs.total_tokens_saved
FROM cache_statistics cs
LEFT JOIN users u ON cs.user_id = u.id
WHERE cs.period_end = (SELECT MAX(period_end) FROM cache_statistics);
