"""
Collector configuration system for AI analytics pipeline.

This module provides configuration management for collectors, supporting
different deployment modes and environments.
"""

import os
import json
import yaml
from typing import Dict, Any, Optional, List
from dataclasses import dataclass, field, asdict
from pathlib import Path


@dataclass
class CollectorConfig:
    """Base configuration for collectors."""
    enabled: bool = True
    position: str = "pre_processing"  # pre_processing or post_processing
    log_level: str = "INFO"
    max_request_size: int = 10 * 1024 * 1024  # 10MB
    timeout: float = 5.0
    enable_metrics: bool = True
    enable_health_check: bool = True
    degraded_mode_timeout: float = 30.0  # seconds before entering degraded mode
    
    # Analytics queue configuration
    queue_enabled: bool = True
    queue_max_size: int = 10000
    queue_timeout: float = 1.0  # seconds
    
    # Security configuration
    sanitize_headers: bool = True
    redact_sensitive_data: bool = True
    log_request_body: bool = False
    log_response_body: bool = False
    
    # Performance configuration
    hot_path_latency_threshold_ms: float = 5.0
    enable_async_processing: bool = True
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert configuration to dictionary."""
        return asdict(self)
    
    @classmethod
    def from_dict(cls, config_dict: Dict[str, Any]) -> 'CollectorConfig':
        """Create configuration from dictionary."""
        return cls(**config_dict)
    
    @classmethod
    def from_env(cls) -> 'CollectorConfig':
        """Create configuration from environment variables."""
        return cls(
            enabled=os.getenv('COLLECTOR_ENABLED', 'true').lower() == 'true',
            position=os.getenv('COLLECTOR_POSITION', 'pre_processing'),
            log_level=os.getenv('COLLECTOR_LOG_LEVEL', 'INFO'),
            max_request_size=int(os.getenv('COLLECTOR_MAX_REQUEST_SIZE', str(10 * 1024 * 1024))),
            timeout=float(os.getenv('COLLECTOR_TIMEOUT', '5.0')),
            enable_metrics=os.getenv('COLLECTOR_ENABLE_METRICS', 'true').lower() == 'true',
            enable_health_check=os.getenv('COLLECTOR_ENABLE_HEALTH_CHECK', 'true').lower() == 'true',
            degraded_mode_timeout=float(os.getenv('COLLECTOR_DEGRADED_MODE_TIMEOUT', '30.0')),
            queue_enabled=os.getenv('COLLECTOR_QUEUE_ENABLED', 'true').lower() == 'true',
            queue_max_size=int(os.getenv('COLLECTOR_QUEUE_MAX_SIZE', '10000')),
            queue_timeout=float(os.getenv('COLLECTOR_QUEUE_TIMEOUT', '1.0')),
            sanitize_headers=os.getenv('COLLECTOR_SANITIZE_HEADERS', 'true').lower() == 'true',
            redact_sensitive_data=os.getenv('COLLECTOR_REDACT_SENSITIVE_DATA', 'true').lower() == 'true',
            log_request_body=os.getenv('COLLECTOR_LOG_REQUEST_BODY', 'false').lower() == 'true',
            log_response_body=os.getenv('COLLECTOR_LOG_RESPONSE_BODY', 'false').lower() == 'true',
            hot_path_latency_threshold_ms=float(os.getenv('COLLECTOR_HOT_PATH_LATENCY_THRESHOLD_MS', '5.0')),
            enable_async_processing=os.getenv('COLLECTOR_ENABLE_ASYNC_PROCESSING', 'true').lower() == 'true'
        )


@dataclass
class ProxyCollectorConfig(CollectorConfig):
    """Configuration specific to HTTP proxy collector."""
    listen_host: str = "0.0.0.0"
    listen_port: int = 8888
    target_host: str = "localhost"
    target_port: int = 8080
    enable_ssl: bool = False
    ssl_cert_path: Optional[str] = None
    ssl_key_path: Optional[str] = None
    
    # Connection pooling
    max_connections: int = 1000
    connection_timeout: float = 10.0
    keepalive_timeout: float = 30.0
    
    @classmethod
    def from_env(cls) -> 'ProxyCollectorConfig':
        """Create proxy configuration from environment variables."""
        base_config = super().from_env()
        return cls(
            **base_config.to_dict(),
            listen_host=os.getenv('PROXY_LISTEN_HOST', '0.0.0.0'),
            listen_port=int(os.getenv('PROXY_LISTEN_PORT', '8888')),
            target_host=os.getenv('PROXY_TARGET_HOST', 'localhost'),
            target_port=int(os.getenv('PROXY_TARGET_PORT', '8080')),
            enable_ssl=os.getenv('PROXY_ENABLE_SSL', 'false').lower() == 'true',
            ssl_cert_path=os.getenv('PROXY_SSL_CERT_PATH'),
            ssl_key_path=os.getenv('PROXY_SSL_KEY_PATH'),
            max_connections=int(os.getenv('PROXY_MAX_CONNECTIONS', '1000')),
            connection_timeout=float(os.getenv('PROXY_CONNECTION_TIMEOUT', '10.0')),
            keepalive_timeout=float(os.getenv('PROXY_KEEPALIVE_TIMEOUT', '30.0'))
        )


class ConfigManager:
    """
    Manager for collector configuration with support for multiple sources.
    
    Configuration can be loaded from:
    - Environment variables (highest priority)
    - Configuration files (YAML/JSON)
    - Default values (lowest priority)
    """
    
    def __init__(self, config_path: Optional[Path] = None):
        self.config_path = config_path
        self._config: Optional[CollectorConfig] = None
        self._deployment_mode = self._detect_deployment_mode()
        
    def _detect_deployment_mode(self) -> str:
        """Detect deployment mode from environment."""
        return os.getenv('DEPLOYMENT_MODE', 'development')
    
    def load_config(self) -> CollectorConfig:
        """Load configuration from all sources."""
        # Start with defaults
        config_dict = {}
        
        # Load from file if available
        if self.config_path and self.config_path.exists():
            file_config = self._load_config_file(self.config_path)
            config_dict.update(file_config)
        
        # Override with environment variables
        env_config = self._load_env_config()
        config_dict.update(env_config)
        
        # Apply deployment mode specific overrides
        mode_overrides = self._get_deployment_mode_overrides()
        config_dict.update(mode_overrides)
        
        # Create configuration object
        if self._is_proxy_config():
            self._config = ProxyCollectorConfig.from_dict(config_dict)
        else:
            self._config = CollectorConfig.from_dict(config_dict)
        
        return self._config
    
    def _load_config_file(self, path: Path) -> Dict[str, Any]:
        """Load configuration from file."""
        with open(path, 'r') as f:
            if path.suffix in ['.yml', '.yaml']:
                return yaml.safe_load(f) or {}
            elif path.suffix == '.json':
                return json.load(f)
            else:
                raise ValueError(f"Unsupported config file format: {path.suffix}")
    
    def _load_env_config(self) -> Dict[str, Any]:
        """Load configuration from environment variables."""
        return CollectorConfig.from_env().to_dict()
    
    def _get_deployment_mode_overrides(self) -> Dict[str, Any]:
        """Get configuration overrides for current deployment mode."""
        overrides = {
            'development': {
                'log_level': 'DEBUG',
                'log_request_body': True,
                'log_response_body': True,
                'enable_metrics': True
            },
            'production': {
                'log_level': 'WARNING',
                'log_request_body': False,
                'log_response_body': False,
                'enable_metrics': True
            },
            'testing': {
                'log_level': 'DEBUG',
                'log_request_body': True,
                'log_response_body': True,
                'enable_metrics': False
            }
        }
        return overrides.get(self._deployment_mode, {})
    
    def _is_proxy_config(self) -> bool:
        """Check if this is a proxy collector configuration."""
        return os.getenv('COLLECTOR_TYPE') == 'proxy'
    
    def get_config(self) -> CollectorConfig:
        """Get current configuration."""
        if self._config is None:
            self._config = self.load_config()
        return self._config
    
    def reload_config(self) -> CollectorConfig:
        """Reload configuration from sources."""
        self._config = None
        return self.load_config()
    
    def validate_config(self) -> List[str]:
        """Validate current configuration and return any errors."""
        errors = []
        config = self.get_config()
        
        # Validate required fields
        if config.max_request_size <= 0:
            errors.append("max_request_size must be positive")
        
        if config.timeout <= 0:
            errors.append("timeout must be positive")
        
        if config.hot_path_latency_threshold_ms <= 0:
            errors.append("hot_path_latency_threshold_ms must be positive")
        
        # Validate proxy-specific config
        if isinstance(config, ProxyCollectorConfig):
            if config.listen_port <= 0 or config.listen_port > 65535:
                errors.append("listen_port must be between 1 and 65535")
            
            if config.target_port <= 0 or config.target_port > 65535:
                errors.append("target_port must be between 1 and 65535")
            
            if config.enable_ssl and (not config.ssl_cert_path or not config.ssl_key_path):
                errors.append("ssl_cert_path and ssl_key_path required when SSL is enabled")
        
        return errors


def create_default_config_file(path: Path, config_type: str = 'base') -> None:
    """
    Create a default configuration file.
    
    Args:
        path: Path where to create the config file
        config_type: Type of configuration ('base' or 'proxy')
    """
    if config_type == 'proxy':
        config = ProxyCollectorConfig()
    else:
        config = CollectorConfig()
    
    with open(path, 'w') as f:
        yaml.dump(config.to_dict(), f, default_flow_style=False)
