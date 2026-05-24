#!/usr/bin/env python3
"""
Database abstraction layer for Claude Code Integration Service
Supports both PostgreSQL and SQLite backends for flexible deployment options
"""

import os
import sys
import json
import uuid
import asyncio
import logging
from datetime import datetime, timedelta
from typing import Optional, Dict, List, Any, Protocol
from abc import ABC, abstractmethod
from contextlib import asynccontextmanager

import asyncpg
import aiosqlite
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Database configuration
DATABASE_TYPE = os.getenv('DATABASE_TYPE', 'postgresql').lower()
DATABASE_URL = os.getenv('DATABASE_URL', 'postgresql://claude_user:password@claude-code-db:5432/claude_code')
SQLITE_PATH = os.getenv('SQLITE_PATH', '/app/data/claude_code.db')

# Models (shared across adapters)
class UserSession:
    def __init__(self, session_id: str, user_id: str, created_at: datetime,
                 last_activity: datetime, expires_at: datetime, is_active: bool,
                 preferences: Dict[str, Any]):
        self.session_id = session_id
        self.user_id = user_id
        self.created_at = created_at
        self.last_activity = last_activity
        self.expires_at = expires_at
        self.is_active = is_active
        self.preferences = preferences

class Conversation:
    def __init__(self, conversation_id: str, session_id: str, title: Optional[str],
                 messages: List[Dict[str, Any]], metadata: Dict[str, Any],
                 created_at: datetime, updated_at: datetime):
        self.conversation_id = conversation_id
        self.session_id = session_id
        self.title = title
        self.messages = messages
        self.metadata = metadata
        self.created_at = created_at
        self.updated_at = updated_at

class Message:
    def __init__(self, message_id: str, conversation_id: str, role: str,
                 content: str, timestamp: datetime, token_count: Optional[int],
                 metadata: Dict[str, Any]):
        self.message_id = message_id
        self.conversation_id = conversation_id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.token_count = token_count
        self.metadata = metadata

# Database Adapter Protocol
class DatabaseAdapter(ABC):
    @abstractmethod
    async def connect(self) -> None:
        pass

    @abstractmethod
    async def disconnect(self) -> None:
        pass

    @abstractmethod
    async def create_session(self, user_id: str, preferences: Dict[str, Any]) -> UserSession:
        pass

    @abstractmethod
    async def get_session(self, session_id: str) -> Optional[UserSession]:
        pass

    @abstractmethod
    async def create_conversation(self, session_id: str, title: Optional[str]) -> Conversation:
        pass

    @abstractmethod
    async def get_conversation(self, conversation_id: str) -> Optional[Conversation]:
        pass

    @abstractmethod
    async def add_message(self, conversation_id: str, role: str, content: str,
                         metadata: Dict[str, Any]) -> str:
        pass

    @abstractmethod
    async def get_session_conversations(self, session_id: str) -> List[Conversation]:
        pass

    @abstractmethod
    async def update_session_activity(self, session_id: str) -> None:
        pass

    @abstractmethod
    async def health_check(self) -> bool:
        pass

# PostgreSQL Adapter
class PostgreSQLAdapter(DatabaseAdapter):
    def __init__(self):
        self.pool: Optional[asyncpg.Pool] = None

    async def connect(self) -> None:
        self.pool = await asyncpg.create_pool(
            DATABASE_URL,
            min_size=5,
            max_size=20,
            command_timeout=60
        )
        logger.info("PostgreSQL connection pool created")

        # Initialize database if needed
        await self._init_database()

    async def disconnect(self) -> None:
        if self.pool:
            await self.pool.close()
            logger.info("PostgreSQL connection pool closed")

    async def _init_database(self) -> None:
        """Initialize database schema if not exists"""
        async with self.pool.acquire() as conn:
            # Check if tables exist
            result = await conn.fetchval("""
                SELECT COUNT(*) FROM information_schema.tables
                WHERE table_schema = 'public' AND table_name = 'user_sessions'
            """)

            if result == 0:
                logger.info("Initializing PostgreSQL database schema...")
                # Schema will be created by init-db.sql, but we can add any additional setup here
                pass

    async def create_session(self, user_id: str, preferences: Dict[str, Any]) -> UserSession:
        session_id = str(uuid.uuid4())
        expires_at = datetime.utcnow() + timedelta(hours=24)

        # Check if user already has an active session
        async with self.pool.acquire() as conn:
            existing = await conn.fetchval("""
                SELECT session_id FROM user_sessions
                WHERE user_id = $1 AND is_active = TRUE AND expires_at > CURRENT_TIMESTAMP
            """, user_id)

            if existing:
                raise ValueError(f"User {user_id} already has an active session")

            # Create new session
            await conn.execute("""
                INSERT INTO user_sessions (session_id, user_id, expires_at, preferences)
                VALUES ($1, $2, $3, $4)
            """, session_id, user_id, expires_at, json.dumps(preferences))

            # Create user preferences record
            await conn.execute("""
                INSERT INTO user_preferences (user_id, session_id, preference_key, preference_value)
                VALUES ($1, $2, 'default', $3)
                ON CONFLICT (user_id, preference_key) DO UPDATE SET
                    preference_value = EXCLUDED.preference_value,
                    updated_at = CURRENT_TIMESTAMP
            """, user_id, session_id, json.dumps(preferences))

            # Get created session
            row = await conn.fetchrow("""
                SELECT session_id, user_id, created_at, last_activity, expires_at, is_active,
                       preferences
                FROM user_sessions WHERE session_id = $1
            """, session_id)

        return UserSession(
            session_id=row['session_id'],
            user_id=row['user_id'],
            created_at=row['created_at'],
            last_activity=row['last_activity'],
            expires_at=row['expires_at'],
            is_active=row['is_active'],
            preferences=json.loads(row['preferences']) if row['preferences'] else {}
        )

    async def get_session(self, session_id: str) -> Optional[UserSession]:
        async with self.pool.acquire() as conn:
            row = await conn.fetchrow("""
                SELECT session_id, user_id, created_at, last_activity, expires_at, is_active,
                       preferences
                FROM user_sessions WHERE session_id = $1
            """, session_id)

        if not row:
            return None

        return UserSession(
            session_id=row['session_id'],
            user_id=row['user_id'],
            created_at=row['created_at'],
            last_activity=row['last_activity'],
            expires_at=row['expires_at'],
            is_active=row['is_active'],
            preferences=json.loads(row['preferences']) if row['preferences'] else {}
        )

    async def create_conversation(self, session_id: str, title: Optional[str]) -> Conversation:
        # Verify session exists and is active
        session = await self.get_session(session_id)
        if not session or not session.is_active or session.expires_at < datetime.utcnow():
            raise ValueError("Invalid or expired session")

        conversation_id = str(uuid.uuid4())

        async with self.pool.acquire() as conn:
            await conn.execute("""
                INSERT INTO conversations (conversation_id, session_id, title, messages, metadata)
                VALUES ($1, $2, $3, $4, $5)
            """, conversation_id, session_id, title, json.dumps([]), json.dumps({}))

            # Get created conversation
            row = await conn.fetchrow("""
                SELECT conversation_id, session_id, title, messages, metadata, created_at, updated_at
                FROM conversations WHERE conversation_id = $1
            """, conversation_id)

        return Conversation(
            conversation_id=row['conversation_id'],
            session_id=row['session_id'],
            title=row['title'],
            messages=json.loads(row['messages']) if row['messages'] else [],
            metadata=json.loads(row['metadata']) if row['metadata'] else {},
            created_at=row['created_at'],
            updated_at=row['updated_at']
        )

    async def get_conversation(self, conversation_id: str) -> Optional[Conversation]:
        async with self.pool.acquire() as conn:
            row = await conn.fetchrow("""
                SELECT c.conversation_id, c.session_id, c.title, c.messages, c.metadata, c.created_at, c.updated_at,
                       s.is_active, s.expires_at
                FROM conversations c
                JOIN user_sessions s ON c.session_id = s.session_id
                WHERE c.conversation_id = $1
            """, conversation_id)

        if not row or not row['is_active'] or row['expires_at'] < datetime.utcnow():
            return None

        return Conversation(
            conversation_id=row['conversation_id'],
            session_id=row['session_id'],
            title=row['title'],
            messages=json.loads(row['messages']) if row['messages'] else [],
            metadata=json.loads(row['metadata']) if row['metadata'] else {},
            created_at=row['created_at'],
            updated_at=row['updated_at']
        )

    async def add_message(self, conversation_id: str, role: str, content: str,
                         metadata: Dict[str, Any]) -> str:
        message_id = str(uuid.uuid4())
        token_count = len(content.split())  # Simple token estimation

        async with self.pool.acquire() as conn:
            # Verify conversation exists
            conv = await conn.fetchrow("""
                SELECT c.conversation_id, c.session_id, s.is_active, s.expires_at
                FROM conversations c
                JOIN user_sessions s ON c.session_id = s.session_id
                WHERE c.conversation_id = $1
            """, conversation_id)

            if not conv or not conv['is_active'] or conv['expires_at'] < datetime.utcnow():
                raise ValueError("Invalid conversation or expired session")

            await conn.execute("""
                INSERT INTO messages (message_id, conversation_id, role, content, token_count, metadata)
                VALUES ($1, $2, $3, $4, $5, $6)
            """, message_id, conversation_id, role, content, token_count, json.dumps(metadata))

            # Update conversation
            await conn.execute("""
                UPDATE conversations SET updated_at = CURRENT_TIMESTAMP
                WHERE conversation_id = $1
            """, conversation_id)

            # Update session last activity
            await conn.execute("""
                UPDATE user_sessions SET last_activity = CURRENT_TIMESTAMP
                WHERE session_id = $1
            """, conv['session_id'])

        return message_id

    async def get_session_conversations(self, session_id: str) -> List[Conversation]:
        # Verify session
        session = await self.get_session(session_id)
        if not session or not session.is_active or session.expires_at < datetime.utcnow():
            return []

        async with self.pool.acquire() as conn:
            rows = await conn.fetch("""
                SELECT conversation_id, session_id, title, messages, metadata, created_at, updated_at
                FROM conversations
                WHERE session_id = $1
                ORDER BY updated_at DESC
            """, session_id)

        conversations = []
        for row in rows:
            conversations.append(Conversation(
                conversation_id=row['conversation_id'],
                session_id=row['session_id'],
                title=row['title'],
                messages=json.loads(row['messages']) if row['messages'] else [],
                metadata=json.loads(row['metadata']) if row['metadata'] else {},
                created_at=row['created_at'],
                updated_at=row['updated_at']
            ))

        return conversations

    async def update_session_activity(self, session_id: str) -> None:
        async with self.pool.acquire() as conn:
            await conn.execute("""
                UPDATE user_sessions SET last_activity = CURRENT_TIMESTAMP
                WHERE session_id = $1
            """, session_id)

    async def health_check(self) -> bool:
        try:
            async with self.pool.acquire() as conn:
                await conn.fetchval("SELECT 1")
            return True
        except Exception as e:
            logger.error(f"PostgreSQL health check failed: {e}")
            return False

# SQLite Adapter
class SQLiteAdapter(DatabaseAdapter):
    def __init__(self):
        self.db_path = SQLITE_PATH
        self.conn: Optional[aiosqlite.Connection] = None

    async def connect(self) -> None:
        # Ensure directory exists
        os.makedirs(os.path.dirname(self.db_path), exist_ok=True)

        self.conn = await aiosqlite.connect(self.db_path)
        self.conn.row_factory = aiosqlite.Row

        # Enable WAL mode for better concurrency
        await self.conn.execute("PRAGMA journal_mode=WAL")
        await self.conn.execute("PRAGMA synchronous=NORMAL")
        await self.conn.execute("PRAGMA cache_size=-64000")  # 64MB cache
        await self.conn.commit()

        logger.info(f"SQLite database connected: {self.db_path}")

        # Initialize database schema
        await self._init_database()

    async def disconnect(self) -> None:
        if self.conn:
            await self.conn.close()
            logger.info("SQLite database disconnected")

    async def _init_database(self) -> None:
        """Initialize SQLite database schema"""
        schema_sql = """
        -- User sessions table
        CREATE TABLE IF NOT EXISTS user_sessions (
            session_id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            api_key_hash TEXT,
            created_at TEXT NOT NULL DEFAULT (datetime('now')),
            last_activity TEXT NOT NULL DEFAULT (datetime('now')),
            expires_at TEXT NOT NULL,
            is_active INTEGER NOT NULL DEFAULT 1,
            preferences TEXT DEFAULT '{}'
        );

        -- User preferences table
        CREATE TABLE IF NOT EXISTS user_preferences (
            user_id TEXT NOT NULL,
            session_id TEXT,
            preference_key TEXT NOT NULL,
            preference_value TEXT DEFAULT '{}',
            created_at TEXT NOT NULL DEFAULT (datetime('now')),
            updated_at TEXT NOT NULL DEFAULT (datetime('now')),
            PRIMARY KEY (user_id, preference_key)
        );

        -- Conversations table
        CREATE TABLE IF NOT EXISTS conversations (
            conversation_id TEXT PRIMARY KEY,
            session_id TEXT NOT NULL,
            title TEXT,
            messages TEXT NOT NULL DEFAULT '[]',
            metadata TEXT DEFAULT '{}',
            created_at TEXT NOT NULL DEFAULT (datetime('now')),
            updated_at TEXT NOT NULL DEFAULT (datetime('now')),
            FOREIGN KEY (session_id) REFERENCES user_sessions(session_id) ON DELETE CASCADE
        );

        -- Messages table
        CREATE TABLE IF NOT EXISTS messages (
            message_id TEXT PRIMARY KEY,
            conversation_id TEXT NOT NULL,
            role TEXT NOT NULL CHECK (role IN ('user', 'assistant', 'system')),
            content TEXT NOT NULL,
            timestamp TEXT NOT NULL DEFAULT (datetime('now')),
            token_count INTEGER,
            metadata TEXT DEFAULT '{}',
            FOREIGN KEY (conversation_id) REFERENCES conversations(conversation_id) ON DELETE CASCADE
        );

        -- MCP Tools table
        CREATE TABLE IF NOT EXISTS mcp_tools (
            tool_id TEXT PRIMARY KEY,
            name TEXT NOT NULL UNIQUE,
            description TEXT,
            endpoint TEXT NOT NULL,
            capabilities TEXT DEFAULT '[]',
            authentication TEXT DEFAULT '{}',
            is_active INTEGER NOT NULL DEFAULT 1,
            created_at TEXT NOT NULL DEFAULT (datetime('now'))
        );

        -- Tool usage table
        CREATE TABLE IF NOT EXISTS tool_usage (
            usage_id TEXT PRIMARY KEY,
            tool_id TEXT NOT NULL,
            conversation_id TEXT NOT NULL,
            operation TEXT NOT NULL,
            parameters TEXT DEFAULT '{}',
            result TEXT,
            duration_ms INTEGER,
            success INTEGER NOT NULL,
            timestamp TEXT NOT NULL DEFAULT (datetime('now')),
            FOREIGN KEY (tool_id) REFERENCES mcp_tools(tool_id) ON DELETE CASCADE,
            FOREIGN KEY (conversation_id) REFERENCES conversations(conversation_id) ON DELETE CASCADE
        );

        -- Indexes for performance
        CREATE INDEX IF NOT EXISTS idx_user_sessions_user_id ON user_sessions(user_id);
        CREATE INDEX IF NOT EXISTS idx_user_sessions_active ON user_sessions(is_active, expires_at);
        CREATE INDEX IF NOT EXISTS idx_conversations_session_id ON conversations(session_id);
        CREATE INDEX IF NOT EXISTS idx_conversations_updated ON conversations(updated_at DESC);
        CREATE INDEX IF NOT EXISTS idx_messages_conversation_id ON messages(conversation_id);
        CREATE INDEX IF NOT EXISTS idx_messages_timestamp ON messages(timestamp DESC);
        """

        await self.conn.executescript(schema_sql)
        await self.conn.commit()
        logger.info("SQLite database schema initialized")

    async def create_session(self, user_id: str, preferences: Dict[str, Any]) -> UserSession:
        session_id = str(uuid.uuid4())
        expires_at = (datetime.utcnow() + timedelta(hours=24)).isoformat()

        # Check if user already has an active session
        cursor = await self.conn.execute("""
            SELECT session_id FROM user_sessions
            WHERE user_id = ? AND is_active = 1 AND datetime(expires_at) > datetime('now')
        """, (user_id,))

        existing = await cursor.fetchone()
        if existing:
            raise ValueError(f"User {user_id} already has an active session")

        # Create new session
        await self.conn.execute("""
            INSERT INTO user_sessions (session_id, user_id, expires_at, preferences)
            VALUES (?, ?, ?, ?)
        """, (session_id, user_id, expires_at, json.dumps(preferences)))

        # Create user preferences record
        await self.conn.execute("""
            INSERT OR REPLACE INTO user_preferences (user_id, session_id, preference_key, preference_value)
            VALUES (?, ?, 'default', ?)
        """, (user_id, session_id, json.dumps(preferences)))

        await self.conn.commit()

        # Get created session
        cursor = await self.conn.execute("""
            SELECT session_id, user_id, created_at, last_activity, expires_at, is_active, preferences
            FROM user_sessions WHERE session_id = ?
        """, (session_id,))

        row = await cursor.fetchone()

        return UserSession(
            session_id=row['session_id'],
            user_id=row['user_id'],
            created_at=datetime.fromisoformat(row['created_at']),
            last_activity=datetime.fromisoformat(row['last_activity']),
            expires_at=datetime.fromisoformat(row['expires_at']),
            is_active=bool(row['is_active']),
            preferences=json.loads(row['preferences']) if row['preferences'] else {}
        )

    async def get_session(self, session_id: str) -> Optional[UserSession]:
        cursor = await self.conn.execute("""
            SELECT session_id, user_id, created_at, last_activity, expires_at, is_active, preferences
            FROM user_sessions WHERE session_id = ?
        """, (session_id,))

        row = await cursor.fetchone()
        if not row:
            return None

        return UserSession(
            session_id=row['session_id'],
            user_id=row['user_id'],
            created_at=datetime.fromisoformat(row['created_at']),
            last_activity=datetime.fromisoformat(row['last_activity']),
            expires_at=datetime.fromisoformat(row['expires_at']),
            is_active=bool(row['is_active']),
            preferences=json.loads(row['preferences']) if row['preferences'] else {}
        )

    async def create_conversation(self, session_id: str, title: Optional[str]) -> Conversation:
        # Verify session exists and is active
        session = await self.get_session(session_id)
        if not session or not session.is_active or session.expires_at < datetime.utcnow():
            raise ValueError("Invalid or expired session")

        conversation_id = str(uuid.uuid4())

        await self.conn.execute("""
            INSERT INTO conversations (conversation_id, session_id, title, messages, metadata)
            VALUES (?, ?, ?, ?, ?)
        """, (conversation_id, session_id, title, json.dumps([]), json.dumps({})))

        await self.conn.commit()

        # Get created conversation
        cursor = await self.conn.execute("""
            SELECT conversation_id, session_id, title, messages, metadata, created_at, updated_at
            FROM conversations WHERE conversation_id = ?
        """, (conversation_id,))

        row = await cursor.fetchone()

        return Conversation(
            conversation_id=row['conversation_id'],
            session_id=row['session_id'],
            title=row['title'],
            messages=json.loads(row['messages']) if row['messages'] else [],
            metadata=json.loads(row['metadata']) if row['metadata'] else {},
            created_at=datetime.fromisoformat(row['created_at']),
            updated_at=datetime.fromisoformat(row['updated_at'])
        )

    async def get_conversation(self, conversation_id: str) -> Optional[Conversation]:
        cursor = await self.conn.execute("""
            SELECT c.conversation_id, c.session_id, c.title, c.messages, c.metadata, c.created_at, c.updated_at,
                   s.is_active, s.expires_at
            FROM conversations c
            JOIN user_sessions s ON c.session_id = s.session_id
            WHERE c.conversation_id = ?
        """, (conversation_id,))

        row = await cursor.fetchone()
        if not row or not row['is_active'] or datetime.fromisoformat(row['expires_at']) < datetime.utcnow():
            return None

        return Conversation(
            conversation_id=row['conversation_id'],
            session_id=row['session_id'],
            title=row['title'],
            messages=json.loads(row['messages']) if row['messages'] else [],
            metadata=json.loads(row['metadata']) if row['metadata'] else {},
            created_at=datetime.fromisoformat(row['created_at']),
            updated_at=datetime.fromisoformat(row['updated_at'])
        )

    async def add_message(self, conversation_id: str, role: str, content: str,
                         metadata: Dict[str, Any]) -> str:
        message_id = str(uuid.uuid4())
        token_count = len(content.split())  # Simple token estimation

        # Verify conversation exists
        cursor = await self.conn.execute("""
            SELECT c.conversation_id, c.session_id, s.is_active, s.expires_at
            FROM conversations c
            JOIN user_sessions s ON c.session_id = s.session_id
            WHERE c.conversation_id = ?
        """, (conversation_id,))

        conv = await cursor.fetchone()
        if not conv or not conv['is_active'] or datetime.fromisoformat(conv['expires_at']) < datetime.utcnow():
            raise ValueError("Invalid conversation or expired session")

        await self.conn.execute("""
            INSERT INTO messages (message_id, conversation_id, role, content, token_count, metadata)
            VALUES (?, ?, ?, ?, ?, ?)
        """, (message_id, conversation_id, role, content, token_count, json.dumps(metadata)))

        # Update conversation
        await self.conn.execute("""
            UPDATE conversations SET updated_at = datetime('now')
            WHERE conversation_id = ?
        """, (conversation_id,))

        # Update session last activity
        await self.conn.execute("""
            UPDATE user_sessions SET last_activity = datetime('now')
            WHERE session_id = ?
        """, (conv['session_id'],))

        await self.conn.commit()

        return message_id

    async def get_session_conversations(self, session_id: str) -> List[Conversation]:
        # Verify session
        session = await self.get_session(session_id)
        if not session or not session.is_active or session.expires_at < datetime.utcnow():
            return []

        cursor = await self.conn.execute("""
            SELECT conversation_id, session_id, title, messages, metadata, created_at, updated_at
            FROM conversations
            WHERE session_id = ?
            ORDER BY updated_at DESC
        """, (session_id,))

        rows = await cursor.fetchall()

        conversations = []
        for row in rows:
            conversations.append(Conversation(
                conversation_id=row['conversation_id'],
                session_id=row['session_id'],
                title=row['title'],
                messages=json.loads(row['messages']) if row['messages'] else [],
                metadata=json.loads(row['metadata']) if row['metadata'] else {},
                created_at=datetime.fromisoformat(row['created_at']),
                updated_at=datetime.fromisoformat(row['updated_at'])
            ))

        return conversations

    async def update_session_activity(self, session_id: str) -> None:
        await self.conn.execute("""
            UPDATE user_sessions SET last_activity = datetime('now')
            WHERE session_id = ?
        """, (session_id,))
        await self.conn.commit()

    async def health_check(self) -> bool:
        try:
            cursor = await self.conn.execute("SELECT 1")
            await cursor.fetchone()
            return True
        except Exception as e:
            logger.error(f"SQLite health check failed: {e}")
            return False

# Factory function to create the appropriate adapter
def create_database_adapter() -> DatabaseAdapter:
    if DATABASE_TYPE == 'sqlite':
        logger.info("Using SQLite database adapter")
        return SQLiteAdapter()
    elif DATABASE_TYPE == 'postgresql':
        logger.info("Using PostgreSQL database adapter")
        return PostgreSQLAdapter()
    else:
        raise ValueError(f"Unsupported database type: {DATABASE_TYPE}")

# Global database adapter instance
db_adapter: Optional[DatabaseAdapter] = None

@asynccontextmanager
async def lifespan(app):
    """Application lifespan manager"""
    global db_adapter
    try:
        db_adapter = create_database_adapter()
        await db_adapter.connect()
        yield
    finally:
        if db_adapter:
            await db_adapter.disconnect()

# Export the adapter for use in the main application
async def get_database_adapter() -> DatabaseAdapter:
    if db_adapter is None:
        raise RuntimeError("Database adapter not initialized")
    return db_adapter
