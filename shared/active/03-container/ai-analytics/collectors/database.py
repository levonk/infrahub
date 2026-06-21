"""
Database operations for user attribution in AI analytics pipeline.

This module provides database access methods for user, machine, and client key
lookup and creation operations.
"""

import sqlite3
import hashlib
import time
from typing import Optional, Dict, Any, Tuple
from dataclasses import dataclass
from contextlib import contextmanager


@dataclass
class UserRecord:
    """Database record for a user."""
    id: int
    user_id: str
    username: Optional[str] = None
    email: Optional[str] = None
    created_at: str = None
    updated_at: str = None


@dataclass
class MachineRecord:
    """Database record for a machine."""
    id: int
    machine_id: str
    hostname: Optional[str] = None
    os_type: Optional[str] = None
    os_version: Optional[str] = None
    created_at: str = None
    updated_at: str = None


@dataclass
class ClientKeyRecord:
    """Database record for a client key."""
    id: int
    key_id: Optional[str] = None
    key_hash: str
    user_id: Optional[int] = None
    machine_id: Optional[int] = None
    key_type: str = None
    provider: Optional[str] = None
    created_at: str = None
    updated_at: str = None
    expires_at: Optional[str] = None
    is_active: bool = True


class AttributionDatabase:
    """
    Database operations for user attribution.
    
    This class provides methods to lookup and create user, machine,
    and client key records in the analytics database.
    """
    
    def __init__(self, db_path: str):
        self.db_path = db_path
    
    @contextmanager
    def _get_connection(self):
        """Context manager for database connections."""
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        try:
            yield conn
            conn.commit()
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()
    
    def lookup_or_create_user(
        self,
        user_id: str,
        username: Optional[str] = None,
        email: Optional[str] = None
    ) -> UserRecord:
        """
        Look up user by user_id or create if not exists.
        
        Args:
            user_id: Unique user identifier
            username: Optional username
            email: Optional email address
            
        Returns:
            UserRecord with database information
        """
        with self._get_connection() as conn:
            cursor = conn.cursor()
            
            # Try to find existing user
            cursor.execute(
                "SELECT id, user_id, username, email, created_at, updated_at "
                "FROM users WHERE user_id = ?",
                (user_id,)
            )
            row = cursor.fetchone()
            
            if row:
                # Update existing user if new data provided
                if username or email:
                    update_fields = []
                    update_values = []
                    if username:
                        update_fields.append("username = ?")
                        update_values.append(username)
                    if email:
                        update_fields.append("email = ?")
                        update_values.append(email)
                    
                    if update_fields:
                        update_values.append(user_id)
                        cursor.execute(
                            f"UPDATE users SET {', '.join(update_fields)}, updated_at = datetime('now') "
                            "WHERE user_id = ?",
                            update_values
                        )
                
                return UserRecord(
                    id=row['id'],
                    user_id=row['user_id'],
                    username=row['username'],
                    email=row['email'],
                    created_at=row['created_at'],
                    updated_at=row['updated_at']
                )
            
            # Create new user
            cursor.execute(
                "INSERT INTO users (user_id, username, email, created_at, updated_at) "
                "VALUES (?, ?, ?, datetime('now'), datetime('now'))",
                (user_id, username, email)
            )
            
            new_id = cursor.lastrowid
            cursor.execute(
                "SELECT id, user_id, username, email, created_at, updated_at "
                "FROM users WHERE id = ?",
                (new_id,)
            )
            row = cursor.fetchone()
            
            return UserRecord(
                id=row['id'],
                user_id=row['user_id'],
                username=row['username'],
                email=row['email'],
                created_at=row['created_at'],
                updated_at=row['updated_at']
            )
    
    def lookup_or_create_machine(
        self,
        machine_id: str,
        hostname: Optional[str] = None,
        os_type: Optional[str] = None,
        os_version: Optional[str] = None
    ) -> MachineRecord:
        """
        Look up machine by machine_id or create if not exists.
        
        Args:
            machine_id: Unique machine identifier (fingerprint)
            hostname: Optional hostname
            os_type: Optional OS type
            os_version: Optional OS version
            
        Returns:
            MachineRecord with database information
        """
        with self._get_connection() as conn:
            cursor = conn.cursor()
            
            # Try to find existing machine
            cursor.execute(
                "SELECT id, machine_id, hostname, os_type, os_version, created_at, updated_at "
                "FROM machines WHERE machine_id = ?",
                (machine_id,)
            )
            row = cursor.fetchone()
            
            if row:
                # Update existing machine if new data provided
                if hostname or os_type or os_version:
                    update_fields = []
                    update_values = []
                    if hostname:
                        update_fields.append("hostname = ?")
                        update_values.append(hostname)
                    if os_type:
                        update_fields.append("os_type = ?")
                        update_values.append(os_type)
                    if os_version:
                        update_fields.append("os_version = ?")
                        update_values.append(os_version)
                    
                    if update_fields:
                        update_values.append(machine_id)
                        cursor.execute(
                            f"UPDATE machines SET {', '.join(update_fields)}, updated_at = datetime('now') "
                            "WHERE machine_id = ?",
                            update_values
                        )
                
                return MachineRecord(
                    id=row['id'],
                    machine_id=row['machine_id'],
                    hostname=row['hostname'],
                    os_type=row['os_type'],
                    os_version=row['os_version'],
                    created_at=row['created_at'],
                    updated_at=row['updated_at']
                )
            
            # Create new machine
            cursor.execute(
                "INSERT INTO machines (machine_id, hostname, os_type, os_version, created_at, updated_at) "
                "VALUES (?, ?, ?, ?, datetime('now'), datetime('now'))",
                (machine_id, hostname, os_type, os_version)
            )
            
            new_id = cursor.lastrowid
            cursor.execute(
                "SELECT id, machine_id, hostname, os_type, os_version, created_at, updated_at "
                "FROM machines WHERE id = ?",
                (new_id,)
            )
            row = cursor.fetchone()
            
            return MachineRecord(
                id=row['id'],
                machine_id=row['machine_id'],
                hostname=row['hostname'],
                os_type=row['os_type'],
                os_version=row['os_version'],
                created_at=row['created_at'],
                updated_at=row['updated_at']
            )
    
    def lookup_or_create_client_key(
        self,
        key_hash: str,
        key_type: str,
        key_id: Optional[str] = None,
        user_id: Optional[int] = None,
        machine_id: Optional[int] = None,
        provider: Optional[str] = None
    ) -> ClientKeyRecord:
        """
        Look up client key by key_hash or create if not exists.
        
        Args:
            key_hash: Hashed client key
            key_type: Type of key (bearer, api_key, etc.)
            key_id: Optional key identifier
            user_id: Optional user database ID
            machine_id: Optional machine database ID
            provider: Optional provider name
            
        Returns:
            ClientKeyRecord with database information
        """
        with self._get_connection() as conn:
            cursor = conn.cursor()
            
            # Try to find existing client key
            cursor.execute(
                "SELECT id, key_id, key_hash, user_id, machine_id, key_type, provider, "
                "created_at, updated_at, expires_at, is_active "
                "FROM client_keys WHERE key_hash = ?",
                (key_hash,)
            )
            row = cursor.fetchone()
            
            if row:
                # Update existing client key if new data provided
                if key_id or user_id or machine_id or provider:
                    update_fields = []
                    update_values = []
                    if key_id:
                        update_fields.append("key_id = ?")
                        update_values.append(key_id)
                    if user_id is not None:
                        update_fields.append("user_id = ?")
                        update_values.append(user_id)
                    if machine_id is not None:
                        update_fields.append("machine_id = ?")
                        update_values.append(machine_id)
                    if provider:
                        update_fields.append("provider = ?")
                        update_values.append(provider)
                    
                    if update_fields:
                        update_values.append(key_hash)
                        cursor.execute(
                            f"UPDATE client_keys SET {', '.join(update_fields)}, updated_at = datetime('now') "
                            "WHERE key_hash = ?",
                            update_values
                        )
                
                return ClientKeyRecord(
                    id=row['id'],
                    key_id=row['key_id'],
                    key_hash=row['key_hash'],
                    user_id=row['user_id'],
                    machine_id=row['machine_id'],
                    key_type=row['key_type'],
                    provider=row['provider'],
                    created_at=row['created_at'],
                    updated_at=row['updated_at'],
                    expires_at=row['expires_at'],
                    is_active=bool(row['is_active'])
                )
            
            # Create new client key
            cursor.execute(
                "INSERT INTO client_keys (key_id, key_hash, user_id, machine_id, key_type, provider, "
                "created_at, updated_at, is_active) "
                "VALUES (?, ?, ?, ?, ?, ?, datetime('now'), datetime('now'), 1)",
                (key_id, key_hash, user_id, machine_id, key_type, provider)
            )
            
            new_id = cursor.lastrowid
            cursor.execute(
                "SELECT id, key_id, key_hash, user_id, machine_id, key_type, provider, "
                "created_at, updated_at, expires_at, is_active "
                "FROM client_keys WHERE id = ?",
                (new_id,)
            )
            row = cursor.fetchone()
            
            return ClientKeyRecord(
                id=row['id'],
                key_id=row['key_id'],
                key_hash=row['key_hash'],
                user_id=row['user_id'],
                machine_id=row['machine_id'],
                key_type=row['key_type'],
                provider=row['provider'],
                created_at=row['created_at'],
                updated_at=row['updated_at'],
                expires_at=row['expires_at'],
                is_active=bool(row['is_active'])
            )
    
    def get_user_by_id(self, user_db_id: int) -> Optional[UserRecord]:
        """
        Get user by database ID.
        
        Args:
            user_db_id: Database ID of user
            
        Returns:
            UserRecord or None if not found
        """
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(
                "SELECT id, user_id, username, email, created_at, updated_at "
                "FROM users WHERE id = ?",
                (user_db_id,)
            )
            row = cursor.fetchone()
            
            if row:
                return UserRecord(
                    id=row['id'],
                    user_id=row['user_id'],
                    username=row['username'],
                    email=row['email'],
                    created_at=row['created_at'],
                    updated_at=row['updated_at']
                )
            
            return None
    
    def get_machine_by_id(self, machine_db_id: int) -> Optional[MachineRecord]:
        """
        Get machine by database ID.
        
        Args:
            machine_db_id: Database ID of machine
            
        Returns:
            MachineRecord or None if not found
        """
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(
                "SELECT id, machine_id, hostname, os_type, os_version, created_at, updated_at "
                "FROM machines WHERE id = ?",
                (machine_db_id,)
            )
            row = cursor.fetchone()
            
            if row:
                return MachineRecord(
                    id=row['id'],
                    machine_id=row['machine_id'],
                    hostname=row['hostname'],
                    os_type=row['os_type'],
                    os_version=row['os_version'],
                    created_at=row['created_at'],
                    updated_at=row['updated_at']
                )
            
            return None
    
    def get_client_key_by_id(self, key_db_id: int) -> Optional[ClientKeyRecord]:
        """
        Get client key by database ID.
        
        Args:
            key_db_id: Database ID of client key
            
        Returns:
            ClientKeyRecord or None if not found
        """
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(
                "SELECT id, key_id, key_hash, user_id, machine_id, key_type, provider, "
                "created_at, updated_at, expires_at, is_active "
                "FROM client_keys WHERE id = ?",
                (key_db_id,)
            )
            row = cursor.fetchone()
            
            if row:
                return ClientKeyRecord(
                    id=row['id'],
                    key_id=row['key_id'],
                    key_hash=row['key_hash'],
                    user_id=row['user_id'],
                    machine_id=row['machine_id'],
                    key_type=row['key_type'],
                    provider=row['provider'],
                    created_at=row['created_at'],
                    updated_at=row['updated_at'],
                    expires_at=row['expires_at'],
                    is_active=bool(row['is_active'])
                )
            
            return None
    
    def anonymize_user_data(self, user_db_id: int) -> bool:
        """
        Anonymize user data for privacy compliance.
        
        Args:
            user_db_id: Database ID of user
            
        Returns:
            True if anonymization successful
        """
        with self._get_connection() as conn:
            cursor = conn.cursor()
            
            # Hash PII fields
            cursor.execute(
                "UPDATE users SET username = ?, email = ?, updated_at = datetime('now') "
                "WHERE id = ?",
                (hashlib.sha256(str(user_db_id).encode()).hexdigest(),
                 hashlib.sha256(str(user_db_id).encode()).hexdigest(),
                 user_db_id)
            )
            
            return cursor.rowcount > 0