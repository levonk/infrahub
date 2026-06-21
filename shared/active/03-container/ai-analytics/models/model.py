"""
Database models for model analytics.

This module provides database access methods for storing and retrieving
model-related analytics data including version tracking and historical changes.
"""

import sqlite3
import json
import time
from typing import Dict, Any, Optional, List
from dataclasses import dataclass, asdict
from datetime import datetime


@dataclass
class ModelVersion:
    """Model version tracking database model."""
    id: Optional[int] = None
    model_id: str = ""
    version: str = ""
    first_seen: str = ""
    last_seen: str = ""
    request_count: int = 0
    total_tokens: int = 0
    total_cost: float = 0.0
    is_deprecated: bool = False
    deprecation_date: Optional[str] = None
    replacement_model_id: Optional[str] = None
    created_at: Optional[str] = None
    updated_at: Optional[str] = None


@dataclass
class ModelPerformance:
    """Model performance metrics database model."""
    id: Optional[int] = None
    model_id: str = ""
    version: str = ""
    provider_type: str = ""
    total_requests: int = 0
    successful_requests: int = 0
    failed_requests: int = 0
    avg_latency_ms: float = 0.0
    avg_input_tokens: int = 0
    avg_output_tokens: int = 0
    total_cost: float = 0.0
    cost_per_1k_tokens: float = 0.0
    period_start: str = ""
    period_end: str = ""
    created_at: Optional[str] = None
    updated_at: Optional[str] = None


class ModelDatabase:
    """
    Database operations for model analytics.
    
    Handles CRUD operations for model versions, performance metrics,
    and historical tracking.
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
    
    def upsert_model_version(self, version: ModelVersion) -> bool:
        """
        Insert or update a model version.
        
        Args:
            version: ModelVersion object to upsert
            
        Returns:
            True if successful, False otherwise
        """
        try:
            conn = self.connect()
            cursor = conn.cursor()
            
            if version.created_at is None:
                version.created_at = datetime.utcnow().isoformat()
            
            version.updated_at = datetime.utcnow().isoformat()
            
            cursor.execute("""
                INSERT INTO model_versions (
                    model_id, version, first_seen, last_seen, request_count,
                    total_tokens, total_cost, is_deprecated, deprecation_date,
                    replacement_model_id, created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(model_id, version) DO UPDATE SET
                    last_seen = excluded.last_seen,
                    request_count = request_count + excluded.request_count,
                    total_tokens = total_tokens + excluded.total_tokens,
                    total_cost = total_cost + excluded.total_cost,
                    is_deprecated = excluded.is_deprecated,
                    deprecation_date = excluded.deprecation_date,
                    replacement_model_id = excluded.replacement_model_id,
                    updated_at = excluded.updated_at
            """, (
                version.model_id,
                version.version,
                version.first_seen,
                version.last_seen,
                version.request_count,
                version.total_tokens,
                version.total_cost,
                version.is_deprecated,
                version.deprecation_date,
                version.replacement_model_id,
                version.created_at,
                version.updated_at
            ))
            
            conn.commit()
            return True
            
        except sqlite3.Error as e:
            print(f"Error upserting model version: {e}")
            return False
    
    def get_model_versions(self, model_id: str) -> List[ModelVersion]:
        """
        Get all versions for a model.
        
        Args:
            model_id: Model identifier
            
        Returns:
            List of ModelVersion objects
        """
        try:
            conn = self.connect()
            cursor = conn.cursor()
            
            cursor.execute("""
                SELECT * FROM model_versions
                WHERE model_id = ?
                ORDER BY first_seen DESC
            """, (model_id,))
            
            rows = cursor.fetchall()
            return [ModelVersion(**dict(row)) for row in rows]
            
        except sqlite3.Error as e:
            print(f"Error retrieving model versions: {e}")
            return []
    
    def get_current_version(self, model_id: str) -> Optional[ModelVersion]:
        """
        Get the current (non-deprecated) version of a model.
        
        Args:
            model_id: Model identifier
            
        Returns:
            ModelVersion object if found, None otherwise
        """
        try:
            conn = self.connect()
            cursor = conn.cursor()
            
            cursor.execute("""
                SELECT * FROM model_versions
                WHERE model_id = ? AND is_deprecated = 0
                ORDER BY last_seen DESC
                LIMIT 1
            """, (model_id,))
            
            row = cursor.fetchone()
            if row:
                return ModelVersion(**dict(row))
            return None
            
        except sqlite3.Error as e:
            print(f"Error retrieving current version: {e}")
            return None
    
    def mark_deprecated(
        self,
        model_id: str,
        version: str,
        replacement_model_id: Optional[str] = None
    ) -> bool:
        """
        Mark a model version as deprecated.
        
        Args:
            model_id: Model identifier
            version: Version to deprecate
            replacement_model_id: Replacement model ID
            
        Returns:
            True if successful, False otherwise
        """
        try:
            conn = self.connect()
            cursor = conn.cursor()
            
            deprecation_date = datetime.utcnow().isoformat()
            
            cursor.execute("""
                UPDATE model_versions
                SET is_deprecated = 1,
                    deprecation_date = ?,
                    replacement_model_id = ?,
                    updated_at = ?
                WHERE model_id = ? AND version = ?
            """, (deprecation_date, replacement_model_id, deprecation_date, model_id, version))
            
            conn.commit()
            return True
            
        except sqlite3.Error as e:
            print(f"Error marking model as deprecated: {e}")
            return False
    
    def upsert_model_performance(self, performance: ModelPerformance) -> bool:
        """
        Insert or update model performance metrics.
        
        Args:
            performance: ModelPerformance object to upsert
            
        Returns:
            True if successful, False otherwise
        """
        try:
            conn = self.connect()
            cursor = conn.cursor()
            
            if performance.created_at is None:
                performance.created_at = datetime.utcnow().isoformat()
            
            performance.updated_at = datetime.utcnow().isoformat()
            
            cursor.execute("""
                INSERT INTO model_performance (
                    model_id, version, provider_type, total_requests,
                    successful_requests, failed_requests, avg_latency_ms,
                    avg_input_tokens, avg_output_tokens, total_cost,
                    cost_per_1k_tokens, period_start, period_end,
                    created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(model_id, version, period_start, period_end) DO UPDATE SET
                    total_requests = total_requests + excluded.total_requests,
                    successful_requests = successful_requests + excluded.successful_requests,
                    failed_requests = failed_requests + excluded.failed_requests,
                    avg_latency_ms = excluded.avg_latency_ms,
                    avg_input_tokens = excluded.avg_input_tokens,
                    avg_output_tokens = excluded.avg_output_tokens,
                    total_cost = total_cost + excluded.total_cost,
                    cost_per_1k_tokens = excluded.cost_per_1k_tokens,
                    updated_at = excluded.updated_at
            """, (
                performance.model_id,
                performance.version,
                performance.provider_type,
                performance.total_requests,
                performance.successful_requests,
                performance.failed_requests,
                performance.avg_latency_ms,
                performance.avg_input_tokens,
                performance.avg_output_tokens,
                performance.total_cost,
                performance.cost_per_1k_tokens,
                performance.period_start,
                performance.period_end,
                performance.created_at,
                performance.updated_at
            ))
            
            conn.commit()
            return True
            
        except sqlite3.Error as e:
            print(f"Error upserting model performance: {e}")
            return False
    
    def get_model_performance(
        self,
        model_id: Optional[str] = None,
        provider_type: Optional[str] = None,
        start_time: Optional[str] = None,
        end_time: Optional[str] = None
    ) -> List[ModelPerformance]:
        """
        Get model performance metrics.
        
        Args:
            model_id: Filter by model ID (optional)
            provider_type: Filter by provider type (optional)
            start_time: Filter by start time (optional)
            end_time: Filter by end time (optional)
            
        Returns:
            List of ModelPerformance objects
        """
        try:
            conn = self.connect()
            cursor = conn.cursor()
            
            query = """
                SELECT * FROM model_performance
                WHERE 1=1
            """
            params = []
            
            if model_id:
                query += " AND model_id = ?"
                params.append(model_id)
            
            if provider_type:
                query += " AND provider_type = ?"
                params.append(provider_type)
            
            if start_time:
                query += " AND period_start >= ?"
                params.append(start_time)
            
            if end_time:
                query += " AND period_end <= ?"
                params.append(end_time)
            
            query += " ORDER BY period_start DESC"
            
            cursor.execute(query, params)
            rows = cursor.fetchall()
            
            return [ModelPerformance(**dict(row)) for row in rows]
            
        except sqlite3.Error as e:
            print(f"Error retrieving model performance: {e}")
            return []
    
    def get_deprecated_models(self) -> List[ModelVersion]:
        """
        Get all deprecated model versions.
        
        Returns:
            List of ModelVersion objects
        """
        try:
            conn = self.connect()
            cursor = conn.cursor()
            
            cursor.execute("""
                SELECT * FROM model_versions
                WHERE is_deprecated = 1
                ORDER BY deprecation_date DESC
            """)
            
            rows = cursor.fetchall()
            return [ModelVersion(**dict(row)) for row in rows]
            
        except sqlite3.Error as e:
            print(f"Error retrieving deprecated models: {e}")
            return []
    
    def get_model_cost_summary(
        self,
        start_time: Optional[str] = None,
        end_time: Optional[str] = None
    ) -> List[Dict[str, Any]]:
        """
        Get cost summary by model.
        
        Args:
            start_time: Filter by start time (optional)
            end_time: Filter by end time (optional)
            
        Returns:
            List of cost summary dictionaries
        """
        try:
            conn = self.connect()
            cursor = conn.cursor()
            
            query = """
                SELECT
                    model_id,
                    model_name,
                    version,
                    SUM(total_cost) as total_cost,
                    SUM(request_count) as total_requests,
                    SUM(total_tokens) as total_tokens,
                    AVG(total_cost / request_count) as avg_cost_per_request
                FROM model_versions
                WHERE 1=1
            """
            params = []
            
            if start_time:
                query += " AND first_seen >= ?"
                params.append(start_time)
            
            if end_time:
                query += " AND last_seen <= ?"
                params.append(end_time)
            
            query += " GROUP BY model_id, model_name, version ORDER BY total_cost DESC"
            
            cursor.execute(query, params)
            rows = cursor.fetchall()
            
            return [dict(row) for row in rows]
            
        except sqlite3.Error as e:
            print(f"Error retrieving model cost summary: {e}")
            return []
