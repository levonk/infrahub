"""
Database models for subagent analytics.

This module provides database access methods for storing and retrieving
subagent-related analytics data.
"""

import sqlite3
import json
import time
from typing import Dict, Any, Optional, List
from dataclasses import dataclass, asdict
from datetime import datetime


@dataclass
class SubagentEvent:
    """Subagent event database model."""
    event_id: str
    request_event_id: str
    subagent_type_id: int
    subagent_name: str
    start_time: str
    end_time: Optional[str] = None
    duration_ms: Optional[int] = None
    input_tokens: Optional[int] = None
    output_tokens: Optional[int] = None
    tool_calls_count: Optional[int] = None
    status: str = "running"
    error_message: Optional[str] = None
    created_at: Optional[str] = None


@dataclass
class SubagentType:
    """Subagent type database model."""
    id: Optional[int] = None
    type_name: str = ""
    description: Optional[str] = None
    created_at: Optional[str] = None


class SubagentDatabase:
    """
    Database operations for subagent analytics.
    
    Handles CRUD operations for subagent events and types.
    """
    
    def __init__(self, db_path: str):
        """
        Initialize database connection.
        
        Args:
            db_path: Path to SQLite database file
        """
        self.db_path = db_path
        self._conn: Optional[sqlite3.Connection] = None
    
    def connect(self) -> sqlite3.Connection:
        """Establish database connection."""
        if self._conn is None:
            self._conn = sqlite3.connect(self.db_path)
            self._conn.row_factory = sqlite3.Row
        return self._conn
    
    def close(self):
        """Close database connection."""
        if self._conn:
            self._conn.close()
            self._conn = None
    
    def __enter__(self):
        """Context manager entry."""
        return self.connect()
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit."""
        self.close()
    
    def insert_subagent_event(self, event: SubagentEvent) -> bool:
        """
        Insert a new subagent event.
        
        Args:
            event: SubagentEvent object to insert
            
        Returns:
            True if successful, False otherwise
        """
        try:
            conn = self.connect()
            cursor = conn.cursor()
            
            if event.created_at is None:
                event.created_at = datetime.utcnow().isoformat()
            
            cursor.execute("""
                INSERT INTO subagent_events (
                    event_id, request_event_id, subagent_type_id, subagent_name,
                    start_time, end_time, duration_ms, input_tokens, output_tokens,
                    tool_calls_count, status, error_message, created_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                event.event_id,
                event.request_event_id,
                event.subagent_type_id,
                event.subagent_name,
                event.start_time,
                event.end_time,
                event.duration_ms,
                event.input_tokens,
                event.output_tokens,
                event.tool_calls_count,
                event.status,
                event.error_message,
                event.created_at
            ))
            
            conn.commit()
            return True
            
        except sqlite3.Error as e:
            print(f"Error inserting subagent event: {e}")
            return False
    
    def update_subagent_event(self, event_id: str, updates: Dict[str, Any]) -> bool:
        """
        Update an existing subagent event.
        
        Args:
            event_id: Event ID to update
            updates: Dictionary of fields to update
            
        Returns:
            True if successful, False otherwise
        """
        try:
            conn = self.connect()
            cursor = conn.cursor()
            
            # Build dynamic update query
            set_clause = ", ".join([f"{k} = ?" for k in updates.keys()])
            values = list(updates.values()) + [event_id]
            
            cursor.execute(f"""
                UPDATE subagent_events
                SET {set_clause}
                WHERE event_id = ?
            """, values)
            
            conn.commit()
            return True
            
        except sqlite3.Error as e:
            print(f"Error updating subagent event: {e}")
            return False
    
    def get_subagent_event(self, event_id: str) -> Optional[SubagentEvent]:
        """
        Retrieve a subagent event by ID.
        
        Args:
            event_id: Event ID to retrieve
            
        Returns:
            SubagentEvent object if found, None otherwise
        """
        try:
            conn = self.connect()
            cursor = conn.cursor()
            
            cursor.execute("""
                SELECT * FROM subagent_events
                WHERE event_id = ?
            """, (event_id,))
            
            row = cursor.fetchone()
            if row:
                return SubagentEvent(**dict(row))
            return None
            
        except sqlite3.Error as e:
            print(f"Error retrieving subagent event: {e}")
            return None
    
    def get_subagent_events_by_request(self, request_event_id: str) -> List[SubagentEvent]:
        """
        Retrieve all subagent events for a request.
        
        Args:
            request_event_id: Request event ID
            
        Returns:
            List of SubagentEvent objects
        """
        try:
            conn = self.connect()
            cursor = conn.cursor()
            
            cursor.execute("""
                SELECT * FROM subagent_events
                WHERE request_event_id = ?
                ORDER BY start_time
            """, (request_event_id,))
            
            rows = cursor.fetchall()
            return [SubagentEvent(**dict(row)) for row in rows]
            
        except sqlite3.Error as e:
            print(f"Error retrieving subagent events: {e}")
            return []
    
    def get_subagent_type_by_name(self, type_name: str) -> Optional[SubagentType]:
        """
        Retrieve a subagent type by name.
        
        Args:
            type_name: Type name to retrieve
            
        Returns:
            SubagentType object if found, None otherwise
        """
        try:
            conn = self.connect()
            cursor = conn.cursor()
            
            cursor.execute("""
                SELECT * FROM subagent_types
                WHERE type_name = ?
            """, (type_name,))
            
            row = cursor.fetchone()
            if row:
                return SubagentType(**dict(row))
            return None
            
        except sqlite3.Error as e:
            print(f"Error retrieving subagent type: {e}")
            return None
    
    def insert_subagent_type(self, subagent_type: SubagentType) -> bool:
        """
        Insert a new subagent type.
        
        Args:
            subagent_type: SubagentType object to insert
            
        Returns:
            True if successful, False otherwise
        """
        try:
            conn = self.connect()
            cursor = conn.cursor()
            
            if subagent_type.created_at is None:
                subagent_type.created_at = datetime.utcnow().isoformat()
            
            cursor.execute("""
                INSERT INTO subagent_types (type_name, description, created_at)
                VALUES (?, ?, ?)
            """, (
                subagent_type.type_name,
                subagent_type.description,
                subagent_type.created_at
            ))
            
            conn.commit()
            subagent_type.id = cursor.lastrowid
            return True
            
        except sqlite3.Error as e:
            print(f"Error inserting subagent type: {e}")
            return False
    
    def get_subagent_statistics(
        self,
        subagent_type_id: Optional[int] = None,
        start_time: Optional[str] = None,
        end_time: Optional[str] = None
    ) -> List[Dict[str, Any]]:
        """
        Get aggregated statistics for subagent events.
        
        Args:
            subagent_type_id: Filter by subagent type (optional)
            start_time: Filter by start time (optional)
            end_time: Filter by end time (optional)
            
        Returns:
            List of statistics dictionaries
        """
        try:
            conn = self.connect()
            cursor = conn.cursor()
            
            query = """
                SELECT
                    subagent_type_id,
                    subagent_name,
                    COUNT(*) as total_events,
                    SUM(duration_ms) as total_duration_ms,
                    AVG(duration_ms) as avg_duration_ms,
                    SUM(input_tokens) as total_input_tokens,
                    SUM(output_tokens) as total_output_tokens,
                    SUM(tool_calls_count) as total_tool_calls,
                    COUNT(CASE WHEN status = 'completed' THEN 1 END) as successful_events,
                    COUNT(CASE WHEN status = 'failed' THEN 1 END) as failed_events
                FROM subagent_events
                WHERE 1=1
            """
            params = []
            
            if subagent_type_id:
                query += " AND subagent_type_id = ?"
                params.append(subagent_type_id)
            
            if start_time:
                query += " AND start_time >= ?"
                params.append(start_time)
            
            if end_time:
                query += " AND start_time <= ?"
                params.append(end_time)
            
            query += " GROUP BY subagent_type_id, subagent_name"
            
            cursor.execute(query, params)
            rows = cursor.fetchall()
            
            return [dict(row) for row in rows]
            
        except sqlite3.Error as e:
            print(f"Error retrieving subagent statistics: {e}")
            return []
