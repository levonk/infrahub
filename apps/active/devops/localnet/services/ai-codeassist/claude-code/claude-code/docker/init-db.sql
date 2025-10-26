-- Claude Code Integration Database Schema
-- Generated for persistent storage of sessions, conversations, and user preferences

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- UserSession table: Represents authenticated user sessions
CREATE TABLE user_sessions (
    session_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id VARCHAR(255) NOT NULL,
    api_key_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_activity TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,

    -- Constraints
    CONSTRAINT user_sessions_user_id_not_empty CHECK (LENGTH(user_id) > 0),
    CONSTRAINT user_sessions_api_key_hash_not_empty CHECK (LENGTH(api_key_hash) > 0),
    CONSTRAINT user_sessions_expires_future CHECK (expires_at > created_at),
    CONSTRAINT user_sessions_last_activity_after_created CHECK (last_activity >= created_at),
    CONSTRAINT user_sessions_no_concurrent_active EXCLUDE (user_id WITH =) WHERE (is_active = TRUE)
);

-- Conversation table: Stores conversation history and context
CREATE TABLE conversations (
    conversation_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id UUID NOT NULL REFERENCES user_sessions(session_id) ON DELETE CASCADE,
    title VARCHAR(500),
    messages JSONB NOT NULL DEFAULT '[]'::jsonb,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    -- Constraints
    CONSTRAINT conversations_session_fk FOREIGN KEY (session_id) REFERENCES user_sessions(session_id),
    CONSTRAINT conversations_title_length CHECK (LENGTH(title) <= 500),
    CONSTRAINT conversations_messages_array CHECK (jsonb_typeof(messages) = 'array'),
    CONSTRAINT conversations_metadata_object CHECK (jsonb_typeof(metadata) = 'object'),
    CONSTRAINT conversations_updated_after_created CHECK (updated_at >= created_at)
);

-- Message table: Individual messages within conversations
CREATE TABLE messages (
    message_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    conversation_id UUID NOT NULL REFERENCES conversations(conversation_id) ON DELETE CASCADE,
    role VARCHAR(20) NOT NULL CHECK (role IN ('user', 'assistant', 'system')),
    content TEXT NOT NULL,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    token_count INTEGER CHECK (token_count >= 0),
    metadata JSONB DEFAULT '{}'::jsonb,

    -- Constraints
    CONSTRAINT messages_conversation_fk FOREIGN KEY (conversation_id) REFERENCES conversations(conversation_id),
    CONSTRAINT messages_content_not_empty CHECK (LENGTH(content) > 0),
    CONSTRAINT messages_metadata_object CHECK (jsonb_typeof(metadata) = 'object')
);

-- MCPTool table: Registered MCP tools
CREATE TABLE mcp_tools (
    tool_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL UNIQUE,
    description TEXT,
    endpoint VARCHAR(2048) NOT NULL,
    capabilities JSONB DEFAULT '[]'::jsonb,
    authentication JSONB DEFAULT '{}'::jsonb,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    -- Constraints
    CONSTRAINT mcp_tools_name_not_empty CHECK (LENGTH(name) > 0),
    CONSTRAINT mcp_tools_endpoint_valid CHECK (endpoint ~ '^https?://'),
    CONSTRAINT mcp_tools_endpoint_length CHECK (LENGTH(endpoint) <= 2048),
    CONSTRAINT mcp_tools_capabilities_array CHECK (jsonb_typeof(capabilities) = 'array'),
    CONSTRAINT mcp_tools_authentication_object CHECK (jsonb_typeof(authentication) = 'object'),
    CONSTRAINT mcp_tools_description_length CHECK (LENGTH(description) <= 10000)
);

-- ToolUsage table: Tracks MCP tool usage within conversations
CREATE TABLE tool_usage (
    usage_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tool_id UUID NOT NULL REFERENCES mcp_tools(tool_id) ON DELETE CASCADE,
    conversation_id UUID NOT NULL REFERENCES conversations(conversation_id) ON DELETE CASCADE,
    operation VARCHAR(255) NOT NULL,
    parameters JSONB DEFAULT '{}'::jsonb,
    result JSONB,
    duration_ms INTEGER CHECK (duration_ms >= 0),
    success BOOLEAN NOT NULL,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    -- Constraints
    CONSTRAINT tool_usage_tool_fk FOREIGN KEY (tool_id) REFERENCES mcp_tools(tool_id),
    CONSTRAINT tool_usage_conversation_fk FOREIGN KEY (conversation_id) REFERENCES conversations(conversation_id),
    CONSTRAINT tool_usage_operation_not_empty CHECK (LENGTH(operation) > 0),
    CONSTRAINT tool_usage_parameters_object CHECK (jsonb_typeof(parameters) = 'object'),
    CONSTRAINT tool_usage_duration_positive CHECK (duration_ms >= 0)
);

-- UserPreferences table: Stores user preferences and settings
CREATE TABLE user_preferences (
    preference_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id VARCHAR(255) NOT NULL,
    session_id UUID REFERENCES user_sessions(session_id) ON DELETE CASCADE,
    preference_key VARCHAR(255) NOT NULL,
    preference_value JSONB NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    -- Constraints
    CONSTRAINT user_preferences_user_id_not_empty CHECK (LENGTH(user_id) > 0),
    CONSTRAINT user_preferences_key_not_empty CHECK (LENGTH(preference_key) > 0),
    CONSTRAINT user_preferences_value_not_null CHECK (preference_value IS NOT NULL),
    CONSTRAINT user_preferences_updated_after_created CHECK (updated_at >= created_at),
    UNIQUE(user_id, preference_key)
);

-- Indexes for performance
CREATE INDEX idx_user_sessions_user_id ON user_sessions(user_id);
CREATE INDEX idx_user_sessions_active ON user_sessions(is_active) WHERE is_active = TRUE;
CREATE INDEX idx_user_sessions_expires ON user_sessions(expires_at);
CREATE INDEX idx_user_sessions_last_activity ON user_sessions(last_activity);

CREATE INDEX idx_conversations_session_id ON conversations(session_id);
CREATE INDEX idx_conversations_created_at ON conversations(created_at);
CREATE INDEX idx_conversations_updated_at ON conversations(updated_at);

CREATE INDEX idx_messages_conversation_id ON messages(conversation_id);
CREATE INDEX idx_messages_timestamp ON messages(timestamp);
CREATE INDEX idx_messages_role ON messages(role);

CREATE INDEX idx_mcp_tools_active ON mcp_tools(is_active) WHERE is_active = TRUE;
CREATE INDEX idx_mcp_tools_name ON mcp_tools(name);

CREATE INDEX idx_tool_usage_tool_id ON tool_usage(tool_id);
CREATE INDEX idx_tool_usage_conversation_id ON tool_usage(conversation_id);
CREATE INDEX idx_tool_usage_timestamp ON tool_usage(timestamp);
CREATE INDEX idx_tool_usage_success ON tool_usage(success);

CREATE INDEX idx_user_preferences_user_id ON user_preferences(user_id);
CREATE INDEX idx_user_preferences_session_id ON user_preferences(session_id);
CREATE INDEX idx_user_preferences_key ON user_preferences(preference_key);

-- Functions for cleanup and maintenance
CREATE OR REPLACE FUNCTION cleanup_expired_sessions()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM user_sessions
    WHERE expires_at < CURRENT_TIMESTAMP
       OR (last_activity < CURRENT_TIMESTAMP - INTERVAL '24 hours' AND is_active = FALSE);

    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION archive_old_conversations()
RETURNS INTEGER AS $$
DECLARE
    archived_count INTEGER;
BEGIN
    -- Mark conversations from expired sessions as archived (implementation depends on requirements)
    -- For now, just return count of conversations that could be archived
    SELECT COUNT(*) INTO archived_count
    FROM conversations c
    JOIN user_sessions s ON c.session_id = s.session_id
    WHERE s.expires_at < CURRENT_TIMESTAMP - INTERVAL '30 days';

    RETURN archived_count;
END;
$$ LANGUAGE plpgsql;

-- Triggers for automatic timestamp updates
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_conversations_updated_at
    BEFORE UPDATE ON conversations
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_preferences_updated_at
    BEFORE UPDATE ON user_preferences
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Insert default MCP tools (examples)
INSERT INTO mcp_tools (name, description, endpoint, capabilities, authentication) VALUES
('claude-code-mcp', 'Official Claude Code MCP server', 'http://claude-code-mcp:8082', '["tool_discovery", "tool_execution", "context_sharing"]'::jsonb, '{"type": "none"}'::jsonb),
('filesystem-tools', 'File system operations', 'http://pluggedin-mcp-proxy:8085', '["file_read", "file_write", "directory_list"]'::jsonb, '{"type": "bearer", "token_required": true}'::jsonb);

-- Comments for documentation
COMMENT ON TABLE user_sessions IS 'Authenticated user sessions with API key validation';
COMMENT ON TABLE conversations IS 'Conversation history and context for Claude Code interactions';
COMMENT ON TABLE messages IS 'Individual messages within conversations with token counting';
COMMENT ON TABLE mcp_tools IS 'Registered MCP (Model Context Protocol) tools';
COMMENT ON TABLE tool_usage IS 'MCP tool usage tracking and performance metrics';
COMMENT ON TABLE user_preferences IS 'User preferences and settings persistence';

COMMENT ON FUNCTION cleanup_expired_sessions() IS 'Removes expired sessions and associated data';
COMMENT ON FUNCTION archive_old_conversations() IS 'Archives conversations from old sessions for retention';
