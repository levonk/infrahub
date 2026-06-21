"""
Database models for provider analytics.

This module provides database access methods for storing and retrieving
provider-related analytics data.
"""

import sqlite3
import json
import time
from typing import Dict, Any, Optional, List
from dataclasses import dataclass, asdict
from datetime import datetime


@dataclass
class ProviderEvent:
    """Provider event database model."""
    event_id: str
    request_event_id: str
    provider_type: str
    provider_name: str
    model_id: str
    model_name: str
    model_version: Optional[str] = None
    start_time: str = ""
    end_time: Optional[str] = None
    duration_ms: Optional[int] = None
    input_tokens: Optional[int] = None
    output_tokens: Optional[int] = None
    total_tokens: Optional[int] = None
    cost_usd: Optional[float] = None
    status: str = "running"
    error_message: Optional[str] = None
    created_at: Optional[str] = None


@dataclass
class ProviderType:
    """Provider type database model."""
    id: Optional[int] = None
    type_name: str = ""
    description: Optional[str] = None
    api_endpoint: Optional[str] = None
    created_at: Optional[str] = None


@dataclass
class ModelRecord:
    """Model record database model."""
    id: Optional[int] = None
    model_id: str = ""
    model_name: str = ""
    provider_type_id: Optional[int] = None
    model_category: Optional[str] = None
    version: Optional[str] = None
    context_window: Optional[int] = None
    max_tokens: Optional[int] = None
    pricing_input: Optional[float] = None
    pricing_output: Optional[float] = None
    is_deprecated: bool = False
    deprecation_date: Optional[str] = None
    replacement_model_id: Optional[str] = None
    created_at: Optional[str] = None
    updated_at: Optional[str] = None


class ProviderDatabase:
    """
    Database operations for provider analytics.
    
    Handles CRUD operations for provider events, types, and models.
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
    
    def insert_provider_event(self, event: ProviderEvent) -> bool:
        """
        Insert a new provider event.
        
        Args:
            event: ProviderEvent object to insert
            
        Returns:
            True if successful, False otherwise
        """
        try:
            conn = self.connect()
            cursor = conn.cursor()
            
            if event.created_at is None:
                event.created_at = datetime.utcnow().isoformat()
            
            cursor.execute("""
                INSERT INTO provider_events (
                    event_id, request_event_id, provider_type, provider_name,
                    model_id, model_name, model_version, start_time, end_time,
                    duration_ms, input_tokens, output_tokens, total_tokens,
                    cost_usd, status, error_message, created_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                event.event_id,
                event.request_event_id,
                event.provider_type,
                event.provider_name,
                event.model_id,
                event.model_name,
                event.model_version,
                event.start_time,
                event.end_time,
                event.duration_ms,
                event.input_tokens,
                event.output_tokens,
                event.total_tokens,
                event.cost_usd,
                event.status,
                event.error_message,
                event.created_at
            ))
            
            conn.commit()
            return True
            
        except sqlite3.Error as e:
            print(f"Error inserting provider event: {e}")
            return False
    
    def update_provider_event(self, event_id: str, updates: Dict[str, Any]) -> bool:
        """
        Update an existing provider event.
        
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
                UPDATE provider_events
                SET {set_clause}
                WHERE event_id = ?
            """, values)
            
            conn.commit()
            return True
            
        except sqlite3.Error as e:
            print(f"Error updating provider event: {e}")
            return False
    
    def get_provider_event(self, event_id: str) -> Optional[ProviderEvent]:
        """
        Retrieve a provider event by ID.
        
        Args:
            event_id: Event ID to retrieve
            
        Returns:
            ProviderEvent object if found, None otherwise
        """
        try:
            conn = self.connect()
            cursor = conn.cursor()
            
            cursor.execute("""
                SELECT * FROM provider_events
                WHERE event_id = ?
            """, (event_id,))
            
            row = cursor.fetchone()
            if row:
                return ProviderEvent(**dict(row))
            return None
            
        except sqlite3.Error as e:
            print(f"Error retrieving provider event: {e}")
            return None
    
    def get_provider_events_by_request(self, request_event_id: str) -> List[ProviderEvent]:
        """
        Retrieve all provider events for a request.
        
        Args:
            request_event_id: Request event ID
            
        Returns:
            List of ProviderEvent objects
        """
        try:
            conn = self.connect()
            cursor = conn.cursor()
            
            cursor.execute("""
                SELECT * FROM provider_events
                WHERE request_event_id = ?
                ORDER BY start_time
            """, (request_event_id,))
            
            rows = cursor.fetchall()
            return [ProviderEvent(**dict(row)) for row in rows]
            
        except sqlite3.Error as e:
            print(f"Error retrieving provider events: {e}")
            return []
    
    def get_provider_type_by_name(self, type_name: str) -> Optional[ProviderType]:
        """
        Retrieve a provider type by name.
        
        Args:
            type_name: Type name to retrieve
            
        Returns:
            ProviderType object if found, None otherwise
        """
        try:
            conn = self.connect()
            cursor = conn.cursor()
            
            cursor.execute("""
                SELECT * FROM provider_types
                WHERE type_name = ?
            """, (type_name,))
            
            row = cursor.fetchone()
            if row:
                return ProviderType(**dict(row))
            return None
            
        except sqlite3.Error as e:
            print(f"Error retrieving provider type: {e}")
            return None
    
    def insert_provider_type(self, provider_type: ProviderType) -> bool:
        """
        Insert a new provider type.
        
        Args:
            provider_type: ProviderType object to insert
            
        Returns:
            True if successful, False otherwise
        """
        try:
            conn = self.connect()
            cursor = conn.cursor()
            
            if provider_type.created_at is None:
                provider_type.created_at = datetime.utcnow().isoformat()
            
            cursor.execute("""
                INSERT INTO provider_types (type_name, description, api_endpoint, created_at)
                VALUES (?, ?, ?, ?)
            """, (
                provider_type.type_name,
                provider_type.description,
                provider_type.api_endpoint,
                provider_type.created_at
            ))
            
            conn.commit()
            provider_type.id = cursor.lastrowid
            return True
            
        except sqlite3.Error as e:
            print(f"Error inserting provider type: {e}")
            return False
    
    def upsert_model(self, model: ModelRecord) -> bool:
        """
        Insert or update a model record.
        
        Args:
            model: ModelRecord object to upsert
            
        Returns:
            True if successful, False otherwise
        """
        try:
            conn = self.connect()
            cursor = conn.cursor()
            
            if model.created_at is None:
                model.created_at = datetime.utcnow().isoformat()
            
            model.updated_at = datetime.utcnow().isoformat()
            
            cursor.execute("""
                INSERT INTO models (
                    model_id, model_name, provider_type_id, model_category,
                    version, context_window, max_tokens, pricing_input,
                    pricing_output, is_deprecated, deprecation_date,
                    replacement_model_id, created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(model_id) DO UPDATE SET
                    model_name = excluded.model_name,
                    model_category = excluded.model_category,
                    version = excluded.version,
                    context_window = excluded.context_window,
                    max_tokens = excluded.max_tokens,
                    pricing_input = excluded.pricing_input,
                    pricing_output = excluded.pricing_output,
                    is_deprecated = excluded.is_deprecated,
                    deprecation_date = excluded.deprecation_date,
                    replacement_model_id = excluded.replacement_model_id,
                    updated_at = excluded.updated_at
            """, (
                model.model_id,
                model.model_name,
                model.provider_type_id,
                model.model_category,
                model.version,
                model.context_window,
                model.max_tokens,
                model.pricing_input,
                model.pricing_output,
                model.is_deprecated,
                model.deprecation_date,
                model.replacement_model_id,
                model.created_at,
                model.updated_at
            ))
            
            conn.commit()
            return True
            
        except sqlite3.Error as e:
            print(f"Error upserting model: {e}")
            return False
    
    def get_provider_statistics(
        self,
        provider_type: Optional[str] = None,
        start_time: Optional[str] = None,
        end_time: Optional[str] = None
    ) -> List[Dict[str, Any]]:
        """
        Get aggregated statistics for provider events.
        
        Args:
            provider_type: Filter by provider type (optional)
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
                    provider_type,
                    provider_name,
                    COUNT(*) as total_events,
                    SUM(duration_ms) as total_duration_ms,
                    AVG(duration_ms) as avg_duration_ms,
                    SUM(input_tokens) as total_input_tokens,
                    SUM(output_tokens) as total_output_tokens,
                    SUM(total_tokens) as total_tokens,
                    SUM(cost_usd) as total_cost,
                    COUNT(CASE WHEN status = 'completed' THEN 1 END) as successful_events,
                    COUNT(CASE WHEN status = 'failed' THEN 1 END) as failed_events
                FROM provider_events
                WHERE 1=1
            """
            params = []
            
            if provider_type:
                query += " AND provider_type = ?"
                params.append(provider_type)
            
            if start_time:
                query += " AND start_time >= ?"
                params.append(start_time)
            
            if end_time:
                query += " AND start_time <= ?"
                params.append(end_time)
            
            query += " GROUP BY provider_type, provider_name"
            
            cursor.execute(query, params)
            rows = cursor.fetchall()
            
            return [dict(row) for row in rows]
            
        except sqlite3.Error as e:
            print(f"Error retrieving provider statistics: {e}")
            return []
    
    def get_model_usage_statistics(
        self,
        model_id: Optional[str] = None,
        start_time: Optional[str] = None,
        end_time: Optional[str] = None
    ) -> List[Dict[str, Any]]:
        """
        Get usage statistics for models.
        
        Args:
            model_id: Filter by model ID (optional)
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
                    model_id,
                    model_name,
                    model_version,
                    COUNT(*) as total_requests,
                    SUM(total_tokens) as total_tokens,
                    SUM(cost_usd) as total_cost,
                    AVG(duration_ms) as avg_duration_ms,
                    COUNT(CASE WHEN status = 'completed' THEN 1 END) as successful_requests,
                    COUNT(CASE WHEN status = 'failed' THEN 1 END) as failed_requests
                FROM provider_events
                WHERE 1=1
            """
            params = []
            
            if model_id:
                query += " AND model_id = ?"
                params.append(model_id)
            
            if start_time:
                query += " AND start_time >= ?"
                params.append(start_time)
            
            if end_time:
                query += " AND start_time <= ?"
                params.append(end_time)
            
            query += " GROUP BY model_id, model_name, model_version"
            
            cursor.execute(query, params)
            rows = cursor.fetchall()
            
            return [dict(row) for row in rows]
            
        except sqlite3.Error as e:
            print(f"Error retrieving model statistics: {e}")
            return []
