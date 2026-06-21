-- AI Analytics Pipeline Database Schema
-- SQLite Database Schema for Multi-Dimensional AI Usage Analytics
-- Supports user attribution, subagent tracking, tool analytics, file analytics, session data, cache analytics, and skills analytics

-- Enable foreign keys
PRAGMA foreign_keys = ON;

-- ============================================================================
-- USER ATTRIBUTION TABLES
-- ============================================================================

-- Users table: Individual users who make AI requests
CREATE TABLE users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT NOT NULL UNIQUE,  -- External user identifier (e.g., email, username)
    username TEXT,                  -- Display name
    email TEXT,                     -- Email address
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Machines table: Physical or virtual machines making requests
CREATE TABLE machines (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    machine_id TEXT NOT NULL UNIQUE,  -- External machine identifier (hostname, IP)
    hostname TEXT,                    -- Machine hostname
    os_type TEXT,                     -- Operating system type
    os_version TEXT,                  -- Operating system version
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Client keys table: API keys or authentication tokens
CREATE TABLE client_keys (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    key_id TEXT NOT NULL UNIQUE,      -- External key identifier
    key_hash TEXT NOT NULL,            -- Hashed key for security
    user_id INTEGER,                   -- Associated user
    machine_id INTEGER,                -- Associated machine
    key_type TEXT NOT NULL,            -- Type of key (api_key, token, etc.)
    provider TEXT,                     -- AI provider this key is for
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    expires_at TEXT,                   -- Key expiration date
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
    event_id TEXT NOT NULL UNIQUE,     -- Unique event identifier
    timestamp TEXT NOT NULL,           -- Request timestamp
    user_id INTEGER,                   -- User who made the request
    machine_id INTEGER,                -- Machine that made the request
    client_key_id INTEGER,             -- Client key used
    ai_client TEXT NOT NULL,           -- AI client type (claude_code, codex, pi, devin, etc.)
    provider TEXT NOT NULL,             -- AI provider (anthropic, openai, google, etc.)
    model TEXT NOT NULL,               -- AI model used
    input_type TEXT NOT NULL,          -- Input type (text, image, audio, etc.)
    input_tokens INTEGER,              -- Input token count
    output_tokens INTEGER,             -- Output token count
    total_tokens INTEGER,              -- Total token count
    cache_read_tokens INTEGER,         -- Cache read tokens (if applicable)
    cache_write_tokens INTEGER,        -- Cache write tokens (if applicable)
    request_duration_ms INTEGER,       -- Request duration in milliseconds
    status_code INTEGER,               -- HTTP status code
    error_message TEXT,                -- Error message if failed
    request_size_bytes INTEGER,        -- Request size in bytes
    response_size_bytes INTEGER,       -- Response size in bytes
    cost_usd REAL,                     -- Cost in USD
    session_id TEXT,                   -- Session identifier for grouping related requests
    parent_event_id TEXT,              -- Parent event for nested requests
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
    type_name TEXT NOT NULL UNIQUE,    -- Subagent type name
    description TEXT,                  -- Type description
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Subagent events: Tracking subagent usage within requests
CREATE TABLE subagent_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    event_id TEXT NOT NULL UNIQUE,     -- Unique subagent event identifier
    request_event_id TEXT NOT NULL,    -- Parent request event
    subagent_type_id INTEGER NOT NULL, -- Type of subagent
    subagent_name TEXT NOT NULL,       -- Subagent name/identifier
    start_time TEXT NOT NULL,          -- Subagent start time
    end_time TEXT,                      -- Subagent end time
    duration_ms INTEGER,               -- Duration in milliseconds
    input_tokens INTEGER,              -- Tokens sent to subagent
    output_tokens INTEGER,             -- Tokens received from subagent
    tool_calls_count INTEGER,          -- Number of tool calls made
    status TEXT NOT NULL,               -- Subagent status (success, failed, etc.)
    error_message TEXT,                -- Error message if failed
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (request_event_id) REFERENCES request_events(event_id) ON DELETE CASCADE,
    FOREIGN KEY (subagent_type_id) REFERENCES subagent_types(id) ON DELETE RESTRICT
);

-- ============================================================================
-- TOOL ANALYTICS TABLES
-- ============================================================================

-- Tool types: Different types of tools used by AI agents
CREATE TABLE tool_types (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    type_name TEXT NOT NULL UNIQUE,    -- Tool type name
    category TEXT,                     -- Tool category (file, web, database, etc.)
    description TEXT,                  -- Tool description
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Tool usage events: Individual tool invocations
CREATE TABLE tool_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    event_id TEXT NOT NULL UNIQUE,     -- Unique tool event identifier
    request_event_id TEXT NOT NULL,    -- Parent request event
    subagent_event_id TEXT,             -- Parent subagent event (if applicable)
    tool_type_id INTEGER NOT NULL,     -- Type of tool
    tool_name TEXT NOT NULL,           -- Tool name/identifier
    start_time TEXT NOT NULL,          -- Tool start time
    end_time TEXT,                      -- Tool end time
    duration_ms INTEGER,               -- Duration in milliseconds
    parameters TEXT,                   -- Tool parameters (JSON)
    result TEXT,                       -- Tool result (JSON, truncated if large)
    status TEXT NOT NULL,               -- Tool status (success, failed, etc.)
    error_message TEXT,                -- Error message if failed
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (request_event_id) REFERENCES request_events(event_id) ON DELETE CASCADE,
    FOREIGN KEY (subagent_event_id) REFERENCES subagent_events(event_id) ON DELETE SET NULL,
    FOREIGN KEY (tool_type_id) REFERENCES tool_types(id) ON DELETE RESTRICT
);

-- Tool heatmaps: Aggregated tool usage statistics
CREATE TABLE tool_heatmaps (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    tool_name TEXT NOT NULL,           -- Tool name
    tool_type_id INTEGER,              -- Tool type
    user_id INTEGER,                   -- User who used the tool
    machine_id INTEGER,                -- Machine that used the tool
    usage_count INTEGER NOT NULL DEFAULT 0,  -- Number of times used
    total_duration_ms INTEGER DEFAULT 0,     -- Total duration
    success_count INTEGER DEFAULT 0,        -- Number of successful uses
    failure_count INTEGER DEFAULT 0,        -- Number of failed uses
    last_used_at TEXT,                  -- Last usage timestamp
    period_start TEXT NOT NULL,        -- Aggregation period start
    period_end TEXT NOT NULL,          -- Aggregation period end
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
    event_id TEXT NOT NULL UNIQUE,     -- Unique file event identifier
    request_event_id TEXT NOT NULL,    -- Parent request event
    tool_event_id TEXT,                -- Parent tool event (if applicable)
    file_path TEXT NOT NULL,           -- File path
    file_hash TEXT,                    -- File content hash
    operation TEXT NOT NULL,           -- Operation type (read, write, delete, etc.)
    file_size_bytes INTEGER,           -- File size in bytes
    duration_ms INTEGER,               -- Operation duration in milliseconds
    status TEXT NOT NULL,               -- Operation status (success, failed, etc.)
    error_message TEXT,                -- Error message if failed
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (request_event_id) REFERENCES request_events(event_id) ON DELETE CASCADE,
    FOREIGN KEY (tool_event_id) REFERENCES tool_events(event_id) ON DELETE SET NULL
);

-- File heatmaps: Aggregated file access statistics
CREATE TABLE file_heatmaps (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    file_path TEXT NOT NULL,           -- File path
    file_hash TEXT,                    -- File content hash
    user_id INTEGER,                   -- User who accessed the file
    machine_id INTEGER,                -- Machine that accessed the file
    read_count INTEGER NOT NULL DEFAULT 0,   -- Number of reads
    write_count INTEGER NOT NULL DEFAULT 0,  -- Number of writes
    total_bytes_read INTEGER DEFAULT 0,      -- Total bytes read
    total_bytes_written INTEGER DEFAULT 0,   -- Total bytes written
    last_accessed_at TEXT,             -- Last access timestamp
    period_start TEXT NOT NULL,        -- Aggregation period start
    period_end TEXT NOT NULL,          -- Aggregation period end
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
    session_id TEXT NOT NULL UNIQUE,   -- Session identifier
    user_id INTEGER,                   -- User who owns the session
    machine_id INTEGER,                -- Machine for the session
    ai_client TEXT NOT NULL,           -- AI client type
    start_time TEXT NOT NULL,           -- Session start time
    end_time TEXT,                      -- Session end time
    total_requests INTEGER DEFAULT 0,   -- Total requests in session
    total_tokens INTEGER DEFAULT 0,     -- Total tokens used
    total_cost_usd REAL DEFAULT 0,     -- Total cost in USD
    status TEXT NOT NULL DEFAULT 'active',  -- Session status (active, completed, etc.)
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
    FOREIGN KEY (machine_id) REFERENCES machines(id) ON DELETE SET NULL
);

-- Session turns: Individual turns within a session
CREATE TABLE session_turns (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    turn_id TEXT NOT NULL UNIQUE,      -- Turn identifier
    session_id TEXT NOT NULL,          -- Parent session
    request_event_id TEXT NOT NULL,    -- Associated request event
    turn_number INTEGER NOT NULL,       -- Turn number within session
    start_time TEXT NOT NULL,          -- Turn start time
    end_time TEXT,                      -- Turn end time
    input_tokens INTEGER,              -- Input tokens for this turn
    output_tokens INTEGER,             -- Output tokens for this turn
    total_tokens INTEGER,              -- Total tokens for this turn
    cost_usd REAL,                     -- Cost for this turn
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
    event_id TEXT NOT NULL UNIQUE,     -- Unique cache event identifier
    request_event_id TEXT NOT NULL,    -- Parent request event
    cache_type TEXT NOT NULL,           -- Cache type (prompt_cache, response_cache, etc.)
    cache_key TEXT NOT NULL,            -- Cache key
    hit INTEGER NOT NULL,               -- Cache hit (1) or miss (0)
    tokens_saved INTEGER,              -- Tokens saved by cache hit
    latency_ms INTEGER,                 -- Cache access latency
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (request_event_id) REFERENCES request_events(event_id) ON DELETE CASCADE
);

-- Cache statistics: Aggregated cache performance
CREATE TABLE cache_statistics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    cache_type TEXT NOT NULL,           -- Cache type
    user_id INTEGER,                   -- User
    machine_id INTEGER,                -- Machine
    total_requests INTEGER NOT NULL DEFAULT 0,  -- Total requests
    cache_hits INTEGER NOT NULL DEFAULT 0,     -- Cache hits
    cache_misses INTEGER NOT NULL DEFAULT 0,    -- Cache misses
    total_tokens_saved INTEGER DEFAULT 0,       -- Total tokens saved
    hit_rate REAL DEFAULT 0,           -- Cache hit rate
    period_start TEXT NOT NULL,        -- Aggregation period start
    period_end TEXT NOT NULL,          -- Aggregation period end
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
    skill_id TEXT NOT NULL UNIQUE,     -- Skill identifier
    skill_name TEXT NOT NULL,           -- Skill name
    category TEXT,                     -- Skill category
    description TEXT,                  -- Skill description
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Skill usage events: Individual skill invocations
CREATE TABLE skill_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    event_id TEXT NOT NULL UNIQUE,     -- Unique skill event identifier
    request_event_id TEXT NOT NULL,    -- Parent request event
    subagent_event_id TEXT,             -- Parent subagent event (if applicable)
    skill_id TEXT NOT NULL,            -- Skill used
    start_time TEXT NOT NULL,          -- Skill start time
    end_time TEXT,                      -- Skill end time
    duration_ms INTEGER,               -- Duration in milliseconds
    input_tokens INTEGER,              -- Input tokens
    output_tokens INTEGER,             -- Output tokens
    status TEXT NOT NULL,               -- Skill status (success, failed, etc.)
    error_message TEXT,                -- Error message if failed
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
    metric_date TEXT NOT NULL,          -- Metric date
    user_id INTEGER,                   -- User
    machine_id INTEGER,                -- Machine
    ai_client TEXT,                    -- AI client
    provider TEXT,                     -- Provider
    model TEXT,                        -- Model
    total_requests INTEGER NOT NULL DEFAULT 0,  -- Total requests
    total_tokens INTEGER NOT NULL DEFAULT 0,    -- Total tokens
    total_cost_usd REAL NOT NULL DEFAULT 0,     -- Total cost
    avg_request_duration_ms REAL,      -- Average request duration
    success_rate REAL,                 -- Success rate
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
    timestamp TEXT NOT NULL,            -- Data timestamp
    granularity TEXT NOT NULL,          -- Time granularity (minute, hour, day, week, month, etc.)
    metric_name TEXT NOT NULL,          -- Metric name
    metric_value REAL NOT NULL,         -- Metric value
    dimensions TEXT,                    -- Additional dimensions (JSON)
    user_id INTEGER,                   -- User dimension
    machine_id INTEGER,                -- Machine dimension
    ai_client TEXT,                    -- AI client dimension
    provider TEXT,                     -- Provider dimension
    model TEXT,                        -- Model dimension
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
    config_key TEXT NOT NULL UNIQUE,   -- Configuration key
    config_value TEXT NOT NULL,         -- Configuration value
    config_type TEXT NOT NULL,          -- Value type (string, number, boolean, json)
    description TEXT,                  -- Configuration description
    is_sensitive INTEGER NOT NULL DEFAULT 0,  -- Whether value is sensitive
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Provider configuration: AI provider-specific configuration
CREATE TABLE provider_config (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    provider TEXT NOT NULL,            -- Provider name
    config_key TEXT NOT NULL,           -- Configuration key
    config_value TEXT NOT NULL,         -- Configuration value
    config_type TEXT NOT NULL,          -- Value type
    description TEXT,                  -- Configuration description
    is_sensitive INTEGER NOT NULL DEFAULT 0,  -- Whether value is sensitive
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    UNIQUE(provider, config_key)
);

-- Model configuration: AI model-specific configuration
CREATE TABLE model_config (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    provider TEXT NOT NULL,            -- Provider name
    model TEXT NOT NULL,               -- Model name
    config_key TEXT NOT NULL,           -- Configuration key
    config_value TEXT NOT NULL,         -- Configuration value
    config_type TEXT NOT NULL,          -- Value type
    description TEXT,                  -- Configuration description
    is_sensitive INTEGER NOT NULL DEFAULT 0,  -- Whether value is sensitive
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
