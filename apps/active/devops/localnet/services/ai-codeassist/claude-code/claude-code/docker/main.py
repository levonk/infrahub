#!/usr/bin/env python3
"""
Claude Code Integration Service
Provides persistent storage for sessions, conversations, and user preferences
"""

import os
import sys
import json
import logging
from datetime import datetime
from typing import Optional, Dict, List, Any

import uvicorn
from fastapi import FastAPI, HTTPException, Depends, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from dotenv import load_dotenv

# Import database adapter
from database_adapter import get_database_adapter, lifespan, UserSession, Conversation

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Application configuration
CLAUDE_API_KEY = os.getenv('CLAUDE_API_KEY')
JWT_SECRET = os.getenv('JWT_SECRET', 'your-secret-key-change-in-production')

# Models
class UserSessionCreate(BaseModel):
    user_id: str = Field(..., description="User identifier")
    preferences: Dict[str, Any] = Field(default_factory=dict, description="User preferences")

class ConversationCreate(BaseModel):
    session_id: str
    title: Optional[str] = None

class MessageCreate(BaseModel):
    conversation_id: str
    role: str = Field(..., regex="^(user|assistant|system)$")
    content: str
    metadata: Dict[str, Any] = Field(default_factory=dict)

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

# Dependency to get database adapter
async def get_db():
    return await get_database_adapter()

# API Routes
@app.post("/sessions", response_model=UserSession)
async def create_session(session_data: UserSessionCreate, db=Depends(get_db)):
    """Create a new user session"""
    try:
        return await db.create_session(session_data.user_id, session_data.preferences)
    except ValueError as e:
        raise HTTPException(status_code=409, detail=str(e))

@app.get("/sessions/{session_id}", response_model=UserSession)
async def get_session(session_id: str, db=Depends(get_db)):
    """Get session by ID"""
    session = await db.get_session(session_id)
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    return session

@app.post("/conversations", response_model=Conversation)
async def create_conversation(conv_data: ConversationCreate, db=Depends(get_db)):
    """Create a new conversation"""
    try:
        return await db.create_conversation(conv_data.session_id, conv_data.title)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.get("/conversations/{conversation_id}", response_model=Conversation)
async def get_conversation(conversation_id: str, db=Depends(get_db)):
    """Get conversation by ID"""
    conversation = await db.get_conversation(conversation_id)
    if not conversation:
        raise HTTPException(status_code=404, detail="Conversation not found")
    return conversation

@app.post("/messages")
async def add_message(message_data: MessageCreate, background_tasks: BackgroundTasks, db=Depends(get_db)):
    """Add a message to a conversation"""
    try:
        message_id = await db.add_message(
            message_data.conversation_id,
            message_data.role,
            message_data.content,
            message_data.metadata
        )

        # If this is a user message, trigger Claude Code processing in background
        if message_data.role == 'user':
            background_tasks.add_task(process_claude_request, message_data.conversation_id, message_data.content)

        return {"message_id": message_id, "status": "accepted"}

    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.get("/sessions/{session_id}/conversations")
async def get_session_conversations(session_id: str, db=Depends(get_db)):
    """Get all conversations for a session"""
    try:
        conversations = await db.get_session_conversations(session_id)
        return conversations
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.get("/health")
async def health_check(db=Depends(get_db)):
    """Health check endpoint"""
    try:
        healthy = await db.health_check()
        if healthy:
            return {"status": "healthy", "database": "connected"}
        else:
            raise HTTPException(status_code=503, detail="Database health check failed")
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"Health check failed: {str(e)}")

async def process_claude_request(conversation_id: str, user_message: str):
    """Process user message with Claude Code (placeholder for integration)"""
    try:
        # This would integrate with cc-tools or Claude API
        # For now, just log the request
        logger.info(f"Processing Claude request for conversation {conversation_id}")

        # Placeholder: Add assistant response
        assistant_response = f"I received your message: '{user_message[:100]}...'"

        db = await get_database_adapter()
        await db.add_message(conversation_id, "assistant", assistant_response, {"model": "claude-3-5-sonnet-20241022"})

    except Exception as e:
        logger.error(f"Error processing Claude request: {e}")

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
