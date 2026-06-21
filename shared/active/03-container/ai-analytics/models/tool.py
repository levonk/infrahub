"""
Database models for tool analytics.

This module provides database access methods for storing and retrieving
tool-related analytics data.
"""

import sqlite3
import json
import time
from typing import Dict, Any, Optional, List
from dataclasses import dataclass, asdict
from datetime import datetime


@dataclass
class ToolEvent:
    """Tool event database model."""
    event_id: str
    request_event_id: str
    tool_type_id: int
    tool_name: str
    start_time: str
    subagent_event_id: Optional[str] = None
    end_time: Optional[str] = None
    duration_ms: Optional[int] = None
    parameters: Optional[str] = None
    result: Optional[str] = None
    status: str = "running"
    error_message: Optional[str] = None
    created_at: Optional[str] = None


@dataclass
class ToolType:
    """Tool type database model."""
    id: Optional[int] = None
    type_name: str = ""
    category: Optional[str] = None
    description: Optional[str] = None
    created_at: Optional[str] = None


@dataclass
class ToolHeatmap:
    """Tool heatmap database model."""
    id: Optional[int] = None
    tool_name: str = ""
    tool_type_id: Optional[int] = None
    user_id: Optional[int] = None
    machine_id: Optional[int] = None
    usage_count: int = 0
    total_duration_ms: int = 0
    success_count: int = 0
    failure_count: int = 0
    last_used_at: Optional[str] = None
    period_start: str = ""
    period_end: str = ""
    created_at: Optional[str] = None
    updated_at: Optional[str] = None


class ToolDatabase:
    """
    Database operations for tool analytics.
    
    Handles CRUD operations for tool events, types, and heatmaps.
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
    
    def insert_tool_event(self, event: ToolEvent) -> bool:
        """
        Insert a new tool event.
        
        Args:
            event: ToolEvent object to insert
            
        Returns:
            True if successful, False otherwise
        """
        try:
            conn = self.connect()
            cursor = conn.cursor()
            
            if event.created_at is None:
                event.created_at = datetime.utcnow().isoformat()
            
            cursor.execute("""
                INSERT INTO tool_events (
                    event_id, request_event_id, subagent_event_id, tool_type_id,
                    tool_name, start_time, end_time, duration_ms, parameters,
                    result, status, error_message, created_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                event.event_id,
                event.request_event_id,
                event.subagent_event_id,
                event.tool_type_id,
                event.tool_name,
                event.start_time,
                event.end_time,
                event.duration_ms,
                event.parameters,
                event.result,
                event.status,
                event.error_message,
                event.created_at
            ))
            
            conn.commit()
            return True
            
        except sqlite3.Error as e:
            print(f"Error inserting tool event: {e}")
            return False
    
    def update_tool_event(self, event_id: str, updates: Dict[str, Any]) -> bool:
        """
        Update an existing tool event.
        
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
                UPDATE tool_events
                SET {set_clause}
                WHERE event_id = ?
            """, values)
            
            conn.commit()
            return True
            
        except sqlite3.Error as e:
            print(f"Error updating tool event: {e}")
            return False
    
    def get_tool_event(self, event_id: str) -> Optional[ToolEvent]:
        """
        Retrieve a tool event by ID.
        
        Args:
            event_id: Event ID to retrieve
            
        Returns:
            ToolEvent object if found, None otherwise
        """
        try:
            conn = self.connect()
            cursor = conn.cursor()
            
            cursor.execute("""
                SELECT * FROM tool_events
                WHERE event_id = ?
            """, (event_id,))
            
            row = cursor.fetchone()
            if row:
                return ToolEvent(**dict(row))
            return None
            
        except sqlite3.Error as e:
            print(f"Error retrieving tool event: {e}")
            return None
    
    def get_tool_events_by_request(self, request_event_id: str) -> List[ToolEvent]:
        """
        Retrieve all tool events for a request.
        
        Args:
            request_event_id: Request event ID
            
        Returns:
            List of ToolEvent objects
        """
        try:
            conn = self.connect()
            cursor = conn.cursor()
            
            cursor.execute("""
                SELECT * FROM tool_events
                WHERE request_event_id = ?
                ORDER BY start_time
            """, (request_event_id,))
            
            rows = cursor.fetchall()
            return [ToolEvent(**dict(row)) for row in rows]
            
        except sqlite3.Error as e:
            print(f"Error retrieving tool events: {e}")
            return []
    
    def get_tool_events_by_subagent(self, subagent_event_id: str) -> List[ToolEvent]:
        """
        Retrieve all tool events for a subagent.
        
        Args:
            subagent_event_id: Subagent event ID
            
        Returns:
            List of ToolEvent objects
        """
        try:
            conn = self.connect()
            cursor = conn.cursor()
            
            cursor.execute("""
                SELECT * FROM tool_events
                WHERE subagent_event_id = ?
                ORDER BY start_time
            """, (subagent_event_id,))
            
            rows = cursor.fetchall()
            return [ToolEvent(**dict(row)) for row in rows]
            
        except sqlite3.Error as e:
            print(f"Error retrieving tool events: {e}")
            return []
    
    def get_tool_type_by_name(self, type_name: str) -> Optional[ToolType]:
        """
        Retrieve a tool type by name.
        
        Args:
            type_name: Type name to retrieve
            
        Returns:
            ToolType object if found, None otherwise
        """
        try:
            conn = self.connect()
            cursor = conn.cursor()
            
            cursor.execute("""
                SELECT * FROM tool_types
                WHERE type_name = ?
            """, (type_name,))
            
            row = cursor.fetchone()
            if row:
                return ToolType(**dict(row))
            return None
            
        except sqlite3.Error as e:
            print(f"Error retrieving tool type: {e}")
            return None
    
    def insert_tool_type(self, tool_type: ToolType) -> bool:
        """
        Insert a new tool type.
        
        Args:
            tool_type: ToolType object to insert
            
        Returns:
            True if successful, False otherwise
        """
        try:
            conn = self.connect()
            cursor = conn.cursor()
            
            if tool_type.created_at is None:
                tool_type.created_at = datetime.utcnow().isoformat()
            
            cursor.execute("""
                INSERT INTO tool_types (type_name, category, description, created_at)
                VALUES (?, ?, ?, ?)
            """, (
                tool_type.type_name,
                tool_type.category,
                tool_type.description,
                tool_type.created_at
            ))
            
            conn.commit()
            tool_type.id = cursor.lastrowid
            return True
            
        except sqlite3.Error as e:
            print(f"Error inserting tool type: {e}")
            return False
    
    def upsert_tool_heatmap(self, heatmap: ToolHeatmap) -> bool:
        """
        Insert or update a tool heatmap entry.
        
        Args:
            heatmap: ToolHeatmap object to upsert
            
        Returns:
            True if successful, False otherwise
        """
        try:
            conn = self.connect()
            cursor = conn.cursor()
            
            if heatmap.created_at is None:
                heatmap.created_at = datetime.utcnow().isoformat()
            
            heatmap.updated_at = datetime.utcnow().isoformat()
            
            cursor.execute("""
                INSERT INTO tool_heatmaps (
                    tool_name, tool_type_id, user_id, machine_id,
                    usage_count, total_duration_ms, success_count, failure_count,
                    last_used_at, period_start, period_end, created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(tool_name, user_id, machine_id, period_start, period_end)
                DO UPDATE SET
                    usage_count = usage_count + excluded.usage_count,
                    total_duration_ms = total_duration_ms + excluded.total_duration_ms,
                    success_count = success_count + excluded.success_count,
                    failure_count = failure_count + excluded.failure_count,
                    last_used_at = excluded.last_used_at,
                    updated_at = excluded.updated_at
            """, (
                heatmap.tool_name,
                heatmap.tool_type_id,
                heatmap.user_id,
                heatmap.machine_id,
                heatmap.usage_count,
                heatmap.total_duration_ms,
                heatmap.success_count,
                heatmap.failure_count,
                heatmap.last_used_at,
                heatmap.period_start,
                heatmap.period_end,
                heatmap.created_at,
                heatmap.updated_at
            ))
            
            conn.commit()
            return True
            
        except sqlite3.Error as e:
            print(f"Error upserting tool heatmap: {e}")
            return False
    
    def get_tool_statistics(
        self,
        tool_name: Optional[str] = None,
        tool_type_id: Optional[int] = None,
        start_time: Optional[str] = None,
        end_time: Optional[str] = None
    ) -> List[Dict[str, Any]]:
        """
        Get aggregated statistics for tool events.
        
        Args:
            tool_name: Filter by tool name (optional)
            tool_type_id: Filter by tool type (optional)
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
                    tool_name,
                    tool_type_id,
                    COUNT(*) as total_events,
                    SUM(duration_ms) as total_duration_ms,
                    AVG(duration_ms) as avg_duration_ms,
                    COUNT(CASE WHEN status = 'completed' THEN 1 END) as successful_events,
                    COUNT(CASE WHEN status = 'failed' THEN 1 END) as failed_events
                FROM tool_events
                WHERE 1=1
            """
            params = []
            
            if tool_name:
                query += " AND tool_name = ?"
                params.append(tool_name)
            
            if tool_type_id:
                query += " AND tool_type_id = ?"
                params.append(tool_type_id)
            
            if start_time:
                query += " AND start_time >= ?"
                params.append(start_time)
            
            if end_time:
                query += " AND start_time <= ?"
                params.append(end_time)
            
            query += " GROUP BY tool_name, tool_type_id"
            
            cursor.execute(query, params)
            rows = cursor.fetchall()
            
            return [dict(row) for row in rows]
            
        except sqlite3.Error as e:
            print(f"Error retrieving tool statistics: {e}")
            return []
    
    def get_top_tools_by_usage(
        self,
        limit: int = 10,
        start_time: Optional[str] = None,
        end_time: Optional[str] = None
    ) -> List[Dict[str, Any]]:
        """
        Get top tools by usage count.
        
        Args:
            limit: Maximum number of results
            start_time: Filter by start time (optional)
            end_time: Filter by end time (optional)
            
        Returns:
            List of tool usage statistics
        """
        try:
            conn = self.connect()
            cursor = conn.cursor()
            
            query = """
                SELECT
                    tool_name,
                    COUNT(*) as usage_count,
                    AVG(duration_ms) as avg_duration_ms,
                    COUNT(CASE WHEN status = 'completed' THEN 1 END) as success_count,
                    COUNT(CASE WHEN status = 'failed' THEN 1 END) as failure_count
                FROM tool_events
                WHERE 1=1
            """
            params = []
            
            if start_time:
                query += " AND start_time >= ?"
                params.append(start_time)
            
            if end_time:
                query += " AND start_time <= ?"
                params.append(end_time)
            
            query += " GROUP BY tool_name ORDER BY usage_count DESC LIMIT ?"
            params.append(limit)
            
            cursor.execute(query, params)
            rows = cursor.fetchall()
            
            return [dict(row) for row in rows]
            
        except sqlite3.Error as e:
            print(f"Error retrieving top tools: {e}")
            return []
