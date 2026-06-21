"""
Redis connection management for AI analytics pipeline.

This module provides a robust Redis client with connection pooling,
automatic reconnection, and health monitoring for the message queue system.
"""

import time
import threading
from typing import Optional, Callable
from contextlib import contextmanager
import logging

logger = logging.getLogger(__name__)


class RedisConnectionError(Exception):
    """Raised when Redis connection fails."""
    pass


class RedisClient:
    """
    Redis client with connection pooling and automatic reconnection.
    
    This client provides a reliable interface to Redis with:
    - Connection pooling for performance
    - Automatic reconnection on failure
    - Health monitoring
    - Thread-safe operations
    """
    
    def __init__(self, config):
        """
        Initialize Redis client with configuration.
        
        Args:
            config: RedisConfig instance with connection parameters
        """
        self.config = config
        self._pool = None
        self._connection_lock = threading.Lock()
        self._is_connected = False
        self._reconnect_attempts = 0
        self._last_reconnect_time = 0
        
    def connect(self) -> bool:
        """
        Establish connection to Redis with connection pooling.
        
        Returns:
            True if connection successful, False otherwise
        """
        try:
            import redis
            
            self._pool = redis.ConnectionPool(
                host=self.config.host,
                port=self.config.port,
                db=self.config.db,
                password=self.config.password,
                socket_timeout=self.config.socket_timeout,
                socket_connect_timeout=self.config.socket_connect_timeout,
                retry_on_timeout=self.config.retry_on_timeout,
                max_connections=self.config.max_connections,
                health_check_interval=self.config.health_check_interval,
                decode_responses=True
            )
            
            # Test connection
            with self._get_connection() as conn:
                conn.ping()
            
            self._is_connected = True
            self._reconnect_attempts = 0
            logger.info(f"Connected to Redis at {self.config.host}:{self.config.port}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to connect to Redis: {e}")
            self._is_connected = False
            return False
    
    def disconnect(self):
        """Close all connections in the pool."""
        if self._pool:
            self._pool.disconnect()
            self._pool = None
            self._is_connected = False
            logger.info("Disconnected from Redis")
    
    def reconnect(self, max_attempts: int = 5, backoff_seconds: float = 1.0) -> bool:
        """
        Attempt to reconnect to Redis with exponential backoff.
        
        Args:
            max_attempts: Maximum number of reconnection attempts
            backoff_seconds: Initial backoff time in seconds
            
        Returns:
            True if reconnection successful, False otherwise
        """
        for attempt in range(1, max_attempts + 1):
            self._reconnect_attempts += 1
            self._last_reconnect_time = time.time()
            
            logger.info(f"Reconnection attempt {attempt}/{max_attempts}")
            
            if self.connect():
                logger.info("Reconnection successful")
                return True
            
            if attempt < max_attempts:
                wait_time = backoff_seconds * (2 ** (attempt - 1))
                logger.info(f"Waiting {wait_time}s before next attempt")
                time.sleep(wait_time)
        
        logger.error(f"Failed to reconnect after {max_attempts} attempts")
        return False
    
    @contextmanager
    def _get_connection(self):
        """
        Context manager for getting a connection from the pool.
        
        Yields:
            Redis connection object
            
        Raises:
            RedisConnectionError: If connection cannot be established
        """
        if not self._is_connected or not self._pool:
            raise RedisConnectionError("Not connected to Redis")
        
        import redis
        conn = redis.Redis(connection_pool=self._pool)
        
        try:
            yield conn
        except redis.ConnectionError as e:
            logger.error(f"Redis connection error: {e}")
            self._is_connected = False
            raise RedisConnectionError(f"Connection lost: {e}")
        except Exception as e:
            logger.error(f"Redis error: {e}")
            raise
    
    def execute_command(self, *args, **kwargs):
        """
        Execute a Redis command with automatic reconnection.
        
        Args:
            *args: Command arguments
            **kwargs: Command keyword arguments
            
        Returns:
            Command result
            
        Raises:
            RedisConnectionError: If command fails after reconnection attempts
        """
        try:
            with self._get_connection() as conn:
                return conn.execute_command(*args, **kwargs)
        except RedisConnectionError:
            # Attempt reconnection
            if self.reconnect():
                with self._get_connection() as conn:
                    return conn.execute_command(*args, **kwargs)
            raise
    
    def ping(self) -> bool:
        """
        Check if Redis connection is alive.
        
        Returns:
            True if ping successful, False otherwise
        """
        try:
            with self._get_connection() as conn:
                result = conn.ping()
                return result
        except Exception as e:
            logger.error(f"Ping failed: {e}")
            self._is_connected = False
            return False
    
    def is_connected(self) -> bool:
        """
        Check if client is currently connected.
        
        Returns:
            True if connected, False otherwise
        """
        return self._is_connected
    
    def get_connection_info(self) -> dict:
        """
        Get connection status and statistics.
        
        Returns:
            Dict with connection information
        """
        return {
            "connected": self._is_connected,
            "host": self.config.host,
            "port": self.config.port,
            "db": self.config.db,
            "reconnect_attempts": self._reconnect_attempts,
            "last_reconnect_time": self._last_reconnect_time,
            "pool_size": self._pool.connection_pool_size if self._pool else 0
        }
    
    def __enter__(self):
        """Context manager entry."""
        if not self._is_connected:
            self.connect()
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit."""
        self.disconnect()
