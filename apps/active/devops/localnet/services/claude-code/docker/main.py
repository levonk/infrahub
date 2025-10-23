#!/usr/bin/env python3
"""
Claude Code Integration Service
Provides persistent storage for sessions, conversations, and user preferences
"""

import os
import sys
import json
import uuid
import asyncio
import logging
from datetime import datetime, timedelta
from typing import Optional, Dict, List, Any
from contextlib import asynccontextmanager

import asyncpg
import uvicorn
from fastapi import FastAPI, HTTPException, Depends, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
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
DATABASE_URL = os.getenv('DATABASE_URL', 'postgresql://claude_user:password@claude-code-db:5432/claude_code')

# Application configuration
CLAUDE_API_KEY = os.getenv('CLAUDE_API_KEY')
JWT_SECRET = os.getenv('JWT_SECRET', 'your-secret-key-change-in-production')

# Models
class UserSessionCreate(BaseModel):
    user_id: str = Field(..., description="User identifier")
    preferences: Dict[str, Any] = Field(default_factory=dict, description="User preferences")

class UserSession(BaseModel):
    session_id: str
    user_id: str
    created_at: datetime
    last_activity: datetime
    expires_at: datetime
    is_active: bool
    preferences: Dict[str, Any]

class ConversationCreate(BaseModel):
    session_id: str
    title: Optional[str] = None

class Conversation(BaseModel):
    conversation_id: str
    session_id: str
    title: Optional[str]
    messages: List[Dict[str, Any]]
    metadata: Dict[str, Any]
    created_at: datetime
    updated_at: datetime

class MessageCreate(BaseModel):
    conversation_id: str
    role: str = Field(..., regex="^(user|assistant|system)$")
    content: str
    metadata: Dict[str, Any] = Field(default_factory=dict)

# Database connection pool
pool: Optional[asyncpg.Pool] = None

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan manager"""
    global pool
    try:
        # Create database connection pool
        pool = await asyncpg.create_pool(
            DATABASE_URL,
            min_size=5,
            max_size=20,
            command_timeout=60,
            init=init_connection
        )
        logger.info("Database connection pool created")

        # Initialize database if needed
        await init_database()

        yield
    finally:
        if pool:
            await pool.close()
            logger.info("Database connection pool closed")

async def init_connection(conn):
    """Initialize database connection"""
    # Set timezone to UTC
    await conn.execute("SET timezone = 'UTC'")

async def init_database():
    """Initialize database schema if not exists"""
    async with pool.acquire() as conn:
        # Check if tables exist
        result = await conn.fetchval("""
            SELECT COUNT(*) FROM information_schema.tables
            WHERE table_schema = 'public' AND table_name = 'user_sessions'
        """)

        if result == 0:
            logger.info("Initializing database schema...")
            # Schema will be created by init-db.sql, but we can add any additional setup here
            pass

# Create FastAPI app
app = FastAPI(
    title="Claude Code Integration API",
    description="API for managing Claude Code sessions, conversations, and user preferences",
    version="1.0.0",
    lifespan=lifespan
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure appropriately for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Dependency to get database connection
async def get_db():
    async with pool.acquire() as conn:
        yield conn

# API Routes
@app.post("/sessions", response_model=UserSession)
async def create_session(session_data: UserSessionCreate, db=Depends(get_db)):
    """Create a new user session"""
    session_id = str(uuid.uuid4())
    expires_at = datetime.utcnow() + timedelta(hours=24)

    # Check if user already has an active session
    existing = await db.fetchval("""
        SELECT session_id FROM user_sessions
        WHERE user_id = $1 AND is_active = TRUE AND expires_at > CURRENT_TIMESTAMP
    """, session_data.user_id)

    if existing:
        raise HTTPException(
            status_code=409,
            detail="User already has an active session"
        )

    # Create new session
    await db.execute("""
        INSERT INTO user_sessions (session_id, user_id, expires_at, preferences)
        VALUES ($1, $2, $3, $4)
    """, session_id, session_data.user_id, expires_at, json.dumps(session_data.preferences))

    # Create user preferences record
    await db.execute("""
        INSERT INTO user_preferences (user_id, session_id, preference_key, preference_value)
        VALUES ($1, $2, 'default', $3)
        ON CONFLICT (user_id, preference_key) DO UPDATE SET
            preference_value = EXCLUDED.preference_value,
            updated_at = CURRENT_TIMESTAMP
    """, session_data.user_id, session_id, json.dumps(session_data.preferences))

    # Get created session
    row = await db.fetchrow("""
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

@app.get("/sessions/{session_id}", response_model=UserSession)
async def get_session(session_id: str, db=Depends(get_db)):
    """Get session by ID"""
    row = await db.fetchrow("""
        SELECT session_id, user_id, created_at, last_activity, expires_at, is_active,
               preferences
        FROM user_sessions WHERE session_id = $1
    """, session_id)

    if not row:
        raise HTTPException(status_code=404, detail="Session not found")

    return UserSession(
        session_id=row['session_id'],
        user_id=row['user_id'],
        created_at=row['created_at'],
        last_activity=row['last_activity'],
        expires_at=row['expires_at'],
        is_active=row['is_active'],
        preferences=json.loads(row['preferences']) if row['preferences'] else {}
    )

@app.post("/conversations", response_model=Conversation)
async def create_conversation(conv_data: ConversationCreate, db=Depends(get_db)):
    """Create a new conversation"""
    # Verify session exists and is active
    session = await db.fetchrow("""
        SELECT session_id, is_active, expires_at FROM user_sessions
        WHERE session_id = $1
    """, conv_data.session_id)

    if not session or not session['is_active'] or session['expires_at'] < datetime.utcnow():
        raise HTTPException(status_code=404, detail="Invalid or expired session")

    conversation_id = str(uuid.uuid4())

    await db.execute("""
        INSERT INTO conversations (conversation_id, session_id, title, messages, metadata)
        VALUES ($1, $2, $3, $4, $5)
    """, conversation_id, conv_data.session_id, conv_data.title,
        json.dumps([]), json.dumps({}))

    # Update session last activity
    await db.execute("""
        UPDATE user_sessions SET last_activity = CURRENT_TIMESTAMP
        WHERE session_id = $1
    """, conv_data.session_id)

    row = await db.fetchrow("""
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

@app.post("/messages")
async def add_message(message_data: MessageCreate, background_tasks: BackgroundTasks, db=Depends(get_db)):
    """Add a message to a conversation"""
    # Verify conversation exists
    conv = await db.fetchrow("""
        SELECT c.conversation_id, c.session_id, s.is_active, s.expires_at
        FROM conversations c
        JOIN user_sessions s ON c.session_id = s.session_id
        WHERE c.conversation_id = $1
    """, message_data.conversation_id)

    if not conv or not conv['is_active'] or conv['expires_at'] < datetime.utcnow():
        raise HTTPException(status_code=404, detail="Invalid conversation or expired session")

    message_id = str(uuid.uuid4())
    token_count = len(message_data.content.split())  # Simple token estimation

    await db.execute("""
        INSERT INTO messages (message_id, conversation_id, role, content, token_count, metadata)
        VALUES ($1, $2, $3, $4, $5, $6)
    """, message_id, message_data.conversation_id, message_data.role,
        message_data.content, token_count, json.dumps(message_data.metadata))

    # Update conversation
    await db.execute("""
        UPDATE conversations SET updated_at = CURRENT_TIMESTAMP
        WHERE conversation_id = $1
    """, message_data.conversation_id)

    # Update session last activity
    await db.execute("""
        UPDATE user_sessions SET last_activity = CURRENT_TIMESTAMP
        WHERE session_id = $1
    """, conv['session_id'])

    # If this is a user message, trigger Claude Code processing in background
    if message_data.role == 'user':
        background_tasks.add_task(process_claude_request, conv['session_id'], message_data.conversation_id, message_data.content)

    return {"message_id": message_id, "status": "accepted"}

async def process_claude_request(session_id: str, conversation_id: str, user_message: str):
    """Process user message with Claude Code (placeholder for integration)"""
    try:
        # This would integrate with cc-tools or Claude API
        # For now, just log the request
        logger.info(f"Processing Claude request for session {session_id}, conversation {conversation_id}")

        # Placeholder: Add assistant response
        assistant_response = f"I received your message: '{user_message[:100]}...'"

        async with pool.acquire() as conn:
            await conn.execute("""
                INSERT INTO messages (message_id, conversation_id, role, content, token_count, metadata)
                VALUES ($1, $2, 'assistant', $3, $4, $5)
            """, str(uuid.uuid4()), conversation_id, assistant_response,
                len(assistant_response.split()), json.dumps({"model": "claude-3-5-sonnet-20241022"}))

            await conn.execute("""
                UPDATE conversations SET updated_at = CURRENT_TIMESTAMP
                WHERE conversation_id = $1
            """, conversation_id)

    except Exception as e:
        logger.error(f"Error processing Claude request: {e}")

@app.get("/conversations/{conversation_id}", response_model=Conversation)
async def get_conversation(conversation_id: str, db=Depends(get_db)):
    """Get conversation by ID"""
    row = await db.fetchrow("""
        SELECT c.conversation_id, c.session_id, c.title, c.messages, c.metadata, c.created_at, c.updated_at,
               s.is_active, s.expires_at
        FROM conversations c
        JOIN user_sessions s ON c.session_id = s.session_id
        WHERE c.conversation_id = $1
    """, conversation_id)

    if not row or not row['is_active'] or row['expires_at'] < datetime.utcnow():
        raise HTTPException(status_code=404, detail="Conversation not found or session expired")

    return Conversation(
        conversation_id=row['conversation_id'],
        session_id=row['session_id'],
        title=row['title'],
        messages=json.loads(row['messages']) if row['messages'] else [],
        metadata=json.loads(row['metadata']) if row['metadata'] else {},
        created_at=row['created_at'],
        updated_at=row['updated_at']
    )

@app.get("/health")
async def health_check(db=Depends(get_db)):
    """Health check endpoint"""
    try:
        # Test database connectivity
        await db.fetchval("SELECT 1")
        return {"status": "healthy", "database": "connected"}
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"Database connection failed: {str(e)}")

@app.get("/sessions/{session_id}/conversations")
async def get_session_conversations(session_id: str, db=Depends(get_db)):
    """Get all conversations for a session"""
    # Verify session
    session = await db.fetchrow("""
        SELECT session_id, is_active, expires_at FROM user_sessions
        WHERE session_id = $1
    """, session_id)

    if not session or not session['is_active'] or session['expires_at'] < datetime.utcnow():
        raise HTTPException(status_code=404, detail="Session not found or expired")

    rows = await db.fetch("""
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

if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8081,
        reload=False,
        log_level="info"
    )
