"""
Unit tests for collector configuration system.
"""

import pytest
import os
import tempfile
from pathlib import Path

from ..config import (
    CollectorConfig,
    ProxyCollectorConfig,
    ConfigManager,
    create_default_config_file
)


class TestCollectorConfig:
    """Test CollectorConfig dataclass."""
    
    def test_default_config(self):
        """Test default configuration values."""
        config = CollectorConfig()
        
        assert config.enabled is True
        assert config.position == "pre_processing"
        assert config.log_level == "INFO"
        assert config.max_request_size == 10 * 1024 * 1024
        assert config.timeout == 5.0
        assert config.enable_metrics is True
    
    def test_config_to_dict(self):
        """Test converting configuration to dictionary."""
        config = CollectorConfig(
            enabled=False,
            log_level="DEBUG"
        )
        
        config_dict = config.to_dict()
        
        assert config_dict['enabled'] is False
        assert config_dict['log_level'] == "DEBUG"
    
    def test_config_from_dict(self):
        """Test creating configuration from dictionary."""
        config_dict = {
            'enabled': False,
            'log_level': 'DEBUG',
            'max_request_size': 5 * 1024 * 1024
        }
        
        config = CollectorConfig.from_dict(config_dict)
        
        assert config.enabled is False
        assert config.log_level == "DEBUG"
        assert config.max_request_size == 5 * 1024 * 1024
    
    def test_config_from_env(self):
        """Test creating configuration from environment variables."""
        os.environ['COLLECTOR_ENABLED'] = 'false'
        os.environ['COLLECTOR_LOG_LEVEL'] = 'DEBUG'
        os.environ['COLLECTOR_MAX_REQUEST_SIZE'] = '5242880'
        
        try:
            config = CollectorConfig.from_env()
            
            assert config.enabled is False
            assert config.log_level == "DEBUG"
            assert config.max_request_size == 5242880
        finally:
            del os.environ['COLLECTOR_ENABLED']
            del os.environ['COLLECTOR_LOG_LEVEL']
            del os.environ['COLLECTOR_MAX_REQUEST_SIZE']


class TestProxyCollectorConfig:
    """Test ProxyCollectorConfig dataclass."""
    
    def test_proxy_config_defaults(self):
        """Test default proxy configuration values."""
        config = ProxyCollectorConfig()
        
        assert config.listen_host == "0.0.0.0"
        assert config.listen_port == 8888
        assert config.target_host == "localhost"
        assert config.target_port == 8080
        assert config.enable_ssl is False
    
    def test_proxy_config_inherits_base(self):
        """Test that proxy config inherits base config."""
        config = ProxyCollectorConfig(
            log_level="DEBUG",
            listen_port=9999
        )
        
        assert config.log_level == "DEBUG"
        assert config.listen_port == 9999
        assert config.enabled is True  # inherited default
    
    def test_proxy_config_from_env(self):
        """Test creating proxy configuration from environment."""
        os.environ['PROXY_LISTEN_HOST'] = '127.0.0.1'
        os.environ['PROXY_LISTEN_PORT'] = '9999'
        os.environ['PROXY_TARGET_HOST'] = 'example.com'
        os.environ['PROXY_TARGET_PORT'] = '443'
        
        try:
            config = ProxyCollectorConfig.from_env()
            
            assert config.listen_host == '127.0.0.1'
            assert config.listen_port == 9999
            assert config.target_host == 'example.com'
            assert config.target_port == 443
        finally:
            del os.environ['PROXY_LISTEN_HOST']
            del os.environ['PROXY_LISTEN_PORT']
            del os.environ['PROXY_TARGET_HOST']
            del os.environ['PROXY_TARGET_PORT']


class TestConfigManager:
    """Test ConfigManager class."""
    
    def test_config_manager_initialization(self):
        """Test config manager initialization."""
        manager = ConfigManager()
        
        assert manager.config_path is None
        assert manager._config is None
        assert manager._deployment_mode == 'development'
    
    def test_config_manager_with_path(self):
        """Test config manager with config path."""
        with tempfile.NamedTemporaryFile(mode='w', suffix='.yml', delete=False) as f:
            f.write("enabled: false\nlog_level: DEBUG\n")
            temp_path = Path(f.name)
        
        try:
            manager = ConfigManager(config_path=temp_path)
            assert manager.config_path == temp_path
        finally:
            temp_path.unlink()
    
    def test_load_config_from_file(self):
        """Test loading configuration from file."""
        with tempfile.NamedTemporaryFile(mode='w', suffix='.yml', delete=False) as f:
            f.write("enabled: false\nlog_level: DEBUG\nmax_request_size: 5242880\n")
            temp_path = Path(f.name)
        
        try:
            manager = ConfigManager(config_path=temp_path)
            config = manager.load_config()
            
            assert config.enabled is False
            assert config.log_level == "DEBUG"
            assert config.max_request_size == 5242880
        finally:
            temp_path.unlink()
    
    def test_load_config_env_override(self):
        """Test that environment variables override file config."""
        with tempfile.NamedTemporaryFile(mode='w', suffix='.yml', delete=False) as f:
            f.write("enabled: false\nlog_level: DEBUG\n")
            temp_path = Path(f.name)
        
        os.environ['COLLECTOR_ENABLED'] = 'true'
        
        try:
            manager = ConfigManager(config_path=temp_path)
            config = manager.load_config()
            
            # Environment should override file
            assert config.enabled is True
            assert config.log_level == "DEBUG"  # from file
        finally:
            temp_path.unlink()
            del os.environ['COLLECTOR_ENABLED']
    
    def test_deployment_mode_overrides(self):
        """Test deployment mode specific overrides."""
        os.environ['DEPLOYMENT_MODE'] = 'production'
        
        try:
            manager = ConfigManager()
            config = manager.load_config()
            
            assert config.log_level == "WARNING"
            assert config.log_request_body is False
        finally:
            del os.environ['DEPLOYMENT_MODE']
    
    def test_get_config_caching(self):
        """Test that get_config caches the configuration."""
        manager = ConfigManager()
        
        config1 = manager.get_config()
        config2 = manager.get_config()
        
        assert config1 is config2
    
    def test_reload_config(self):
        """Test reloading configuration."""
        manager = ConfigManager()
        
        config1 = manager.get_config()
        config2 = manager.reload_config()
        
        assert config1 is not config2
    
    def test_validate_config_valid(self):
        """Test validation of valid configuration."""
        manager = ConfigManager()
        config = manager.load_config()
        
        errors = manager.validate_config()
        
        assert len(errors) == 0
    
    def test_validate_config_invalid_max_size(self):
        """Test validation of invalid max request size."""
        manager = ConfigManager()
        manager._config = CollectorConfig(max_request_size=-1)
        
        errors = manager.validate_config()
        
        assert len(errors) > 0
        assert any('max_request_size' in error for error in errors)
    
    def test_validate_config_invalid_timeout(self):
        """Test validation of invalid timeout."""
        manager = ConfigManager()
        manager._config = CollectorConfig(timeout=-1.0)
        
        errors = manager.validate_config()
        
        assert len(errors) > 0
        assert any('timeout' in error for error in errors)
    
    def test_validate_proxy_config_invalid_port(self):
        """Test validation of invalid proxy port."""
        manager = ConfigManager()
        manager._config = ProxyCollectorConfig(listen_port=99999)
        
        errors = manager.validate_config()
        
        assert len(errors) > 0
        assert any('listen_port' in error for error in errors)
    
    def test_validate_proxy_config_ssl_without_cert(self):
        """Test validation of SSL without certificate."""
        manager = ConfigManager()
        manager._config = ProxyCollectorConfig(
            enable_ssl=True,
            ssl_cert_path=None,
            ssl_key_path=None
        )
        
        errors = manager.validate_config()
        
        assert len(errors) > 0
        assert any('ssl' in error.lower() for error in errors)


class TestCreateDefaultConfigFile:
    """Test create_default_config_file function."""
    
    def test_create_base_config(self):
        """Test creating base configuration file."""
        with tempfile.NamedTemporaryFile(suffix='.yml', delete=False) as f:
            temp_path = Path(f.name)
        
        try:
            create_default_config_file(temp_path, config_type='base')
            
            assert temp_path.exists()
            
            # Load and verify
            import yaml
            with open(temp_path, 'r') as f:
                config = yaml.safe_load(f)
            
            assert 'enabled' in config
            assert 'position' in config
        finally:
            if temp_path.exists():
                temp_path.unlink()
    
    def test_create_proxy_config(self):
        """Test creating proxy configuration file."""
        with tempfile.NamedTemporaryFile(suffix='.yml', delete=False) as f:
            temp_path = Path(f.name)
        
        try:
            create_default_config_file(temp_path, config_type='proxy')
            
            assert temp_path.exists()
            
            # Load and verify
            import yaml
            with open(temp_path, 'r') as f:
                config = yaml.safe_load(f)
            
            assert 'enabled' in config
            assert 'listen_host' in config
            assert 'listen_port' in config
        finally:
            if temp_path.exists():
                temp_path.unlink()
