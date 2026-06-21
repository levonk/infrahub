"""
Tests for user attribution collection in AI analytics pipeline.

This module provides comprehensive tests for attribution extraction,
machine fingerprinting, client key handling, and database operations.
"""

import pytest
import time
import tempfile
import os
from pathlib import Path

from ..attribution import (
    AttributionExtractor,
    UserAttribution,
    PrivacyLevel,
    create_attribution_context
)
from ..fingerprint import (
    MachineFingerprinter,
    FingerprintConfig,
    FingerprintMethod
)
from ..client_keys import (
    ClientKeyExtractor,
    KeyValidationConfig,
    KeyType,
    KeyStatus
)
from ..database import AttributionDatabase
from ..enrichment import (
    AttributionEnricher,
    EnrichmentConfig,
    EnrichmentResult
)
from ..base import RequestMetadata, AnalyticsEvent, CollectorPosition


class TestAttributionExtractor:
    """Tests for AttributionExtractor class."""
    
    def test_extract_user_id_from_headers(self):
        """Test user ID extraction from various header patterns."""
        extractor = AttributionExtractor()
        
        # Test x-user-id header
        headers = {'x-user-id': 'user123'}
        attribution = extractor.extract_attribution(headers, '127.0.0.1')
        assert attribution.user_id == 'user123'
        
        # Test user-id header
        headers = {'user-id': 'user456'}
        attribution = extractor.extract_attribution(headers, '127.0.0.1')
        assert attribution.user_id == 'user456'
    
    def test_extract_username_from_headers(self):
        """Test username extraction from headers."""
        extractor = AttributionExtractor()
        
        headers = {'x-username': 'john_doe'}
        attribution = extractor.extract_attribution(headers, '127.0.0.1')
        assert attribution.username == 'john_doe'
    
    def test_extract_email_from_headers(self):
        """Test email extraction with validation."""
        extractor = AttributionExtractor()
        
        # Valid email
        headers = {'x-email': 'user@example.com'}
        attribution = extractor.extract_attribution(headers, '127.0.0.1')
        assert attribution.email == 'user@example.com'
        
        # Invalid email (should not be extracted)
        headers = {'x-email': 'invalid-email'}
        attribution = extractor.extract_attribution(headers, '127.0.0.1')
        assert attribution.email is None
    
    def test_extract_bearer_token(self):
        """Test bearer token extraction from Authorization header."""
        extractor = AttributionExtractor()
        
        headers = {'authorization': 'Bearer secret_token_123'}
        attribution = extractor.extract_attribution(headers, '127.0.0.1')
        assert attribution.client_key_hash is not None
        assert attribution.key_type == 'bearer'
    
    def test_extract_api_key(self):
        """Test API key extraction from custom headers."""
        extractor = AttributionExtractor()
        
        headers = {'x-api-key': 'api_key_456'}
        attribution = extractor.extract_attribution(headers, '127.0.0.1')
        assert attribution.client_key_hash is not None
        assert attribution.key_type == 'api_key'
    
    def test_machine_fingerprint_generation(self):
        """Test machine fingerprint generation."""
        extractor = AttributionExtractor()
        
        headers = {
            'user-agent': 'Mozilla/5.0 (Windows NT 10.0)',
            'host': 'example.com',
            'accept-language': 'en-US'
        }
        attribution = extractor.extract_attribution(headers, '192.168.1.100')
        
        assert attribution.machine_id is not None
        assert len(attribution.machine_id) == 64  # SHA256 hex length
        assert attribution.hostname == 'example.com'
    
    def test_privacy_controls_full(self):
        """Test privacy controls with FULL level."""
        extractor = AttributionExtractor(privacy_level=PrivacyLevel.FULL)
        
        headers = {
            'x-user-id': 'user123',
            'x-username': 'john_doe',
            'x-email': 'user@example.com'
        }
        attribution = extractor.extract_attribution(headers, '127.0.0.1')
        
        # All data should be present
        assert attribution.user_id == 'user123'
        assert attribution.username == 'john_doe'
        assert attribution.email == 'user@example.com'
    
    def test_privacy_controls_anonymized(self):
        """Test privacy controls with ANONYMIZED level."""
        extractor = AttributionExtractor(privacy_level=PrivacyLevel.ANONYMIZED)
        
        headers = {
            'x-username': 'john_doe',
            'x-email': 'user@example.com'
        }
        attribution = extractor.extract_attribution(headers, '127.0.0.1')
        
        # PII should be hashed
        assert attribution.username != 'john_doe'
        assert attribution.email != 'user@example.com'
        assert len(attribution.username) == 64  # SHA256 hex length
    
    def test_privacy_controls_minimal(self):
        """Test privacy controls with MINIMAL level."""
        extractor = AttributionExtractor(privacy_level=PrivacyLevel.MINIMAL)
        
        headers = {
            'x-user-id': 'user123',
            'x-username': 'john_doe'
        }
        attribution = extractor.extract_attribution(headers, '127.0.0.1')
        
        # Only machine_id and client_key_hash should be present
        assert attribution.user_id is None
        assert attribution.username is None
        assert attribution.hostname is None
    
    def test_privacy_controls_none(self):
        """Test privacy controls with NONE level."""
        extractor = AttributionExtractor(privacy_level=PrivacyLevel.NONE)
        
        headers = {'x-user-id': 'user123'}
        attribution = extractor.extract_attribution(headers, '127.0.0.1')
        
        # No attribution data should be present
        assert attribution.user_id is None
        assert attribution.machine_id is None
        assert attribution.client_key_hash is None


class TestMachineFingerprinter:
    """Tests for MachineFingerprinter class."""
    
    def test_ip_based_fingerprint(self):
        """Test IP-based fingerprint generation."""
        config = FingerprintConfig(method=FingerprintMethod.IP_BASED)
        fingerprinter = MachineFingerprinter(config)
        
        fingerprint = fingerprinter.generate_fingerprint('192.168.1.100')
        assert fingerprint is not None
        assert len(fingerprint) == 64  # SHA256 hex length
    
    def test_user_agent_fingerprint(self):
        """Test User-Agent based fingerprint generation."""
        config = FingerprintConfig(method=FingerprintMethod.USER_AGENT)
        fingerprinter = MachineFingerprinter(config)
        
        fingerprint = fingerprinter.generate_fingerprint(
            '127.0.0.1',
            user_agent='Mozilla/5.0 (Windows NT 10.0)'
        )
        assert fingerprint is not None
        assert len(fingerprint) == 64
    
    def test_combined_fingerprint(self):
        """Test combined fingerprint generation."""
        config = FingerprintConfig(method=FingerprintMethod.COMBINED)
        fingerprinter = MachineFingerprinter(config)
        
        fingerprint = fingerprinter.generate_fingerprint(
            '192.168.1.100',
            user_agent='Mozilla/5.0 (Windows NT 10.0)',
            headers={'host': 'example.com'}
        )
        assert fingerprint is not None
        assert len(fingerprint) == 64
    
    def test_ip_masking(self):
        """Test IP address masking for privacy."""
        config = FingerprintConfig(enable_ip_masking=True)
        fingerprinter = MachineFingerprinter(config)
        
        # IPv4 masking
        masked = fingerprinter._mask_ip_address('192.168.1.100')
        assert masked == '192.168.1.0'
        
        # IPv6 masking
        masked = fingerprinter._mask_ip_address('2001:db8::1')
        assert masked == '2001:db8::'
    
    def test_os_extraction(self):
        """Test OS information extraction from User-Agent."""
        fingerprinter = MachineFingerprinter()
        
        os_info = fingerprinter.extract_os_info('Mozilla/5.0 (Windows NT 10.0)')
        assert os_info['os_type'] == 'Windows'
        
        os_info = fingerprinter.extract_os_info('Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)')
        assert os_info['os_type'] == 'macOS'
        
        os_info = fingerprinter.extract_os_info('Mozilla/5.0 (Android 10)')
        assert os_info['os_type'] == 'Android'
    
    def test_browser_extraction(self):
        """Test browser information extraction from User-Agent."""
        fingerprinter = MachineFingerprinter()
        
        browser_info = fingerprinter.extract_browser_info(
            'Mozilla/5.0 (Windows NT 10.0) Chrome/91.0.4472.124'
        )
        assert browser_info['browser_name'] == 'Chrome'
        
        browser_info = fingerprinter.extract_browser_info(
            'Mozilla/5.0 (Windows NT 10.0) Firefox/89.0'
        )
        assert browser_info['browser_name'] == 'Firefox'


class TestClientKeyExtractor:
    """Tests for ClientKeyExtractor class."""
    
    def test_extract_bearer_token(self):
        """Test bearer token extraction."""
        extractor = ClientKeyExtractor()
        
        headers = {'authorization': 'Bearer secret_token'}
        key_info = extractor.extract_key(headers)
        
        assert key_info.key_hash is not None
        assert key_info.key_type == KeyType.BEARER_TOKEN
        assert key_info.raw_key_present is True
        assert key_info.status == KeyStatus.VALID
    
    def test_extract_api_key(self):
        """Test API key extraction."""
        extractor = ClientKeyExtractor()
        
        headers = {'x-api-key': 'api_key_123'}
        key_info = extractor.extract_key(headers)
        
        assert key_info.key_hash is not None
        assert key_info.key_type == KeyType.API_KEY
        assert key_info.raw_key_present is True
    
    def test_extract_from_query_params(self):
        """Test key extraction from query parameters."""
        extractor = ClientKeyExtractor()
        
        headers = {}
        query_params = {'api_key': 'query_key_456'}
        key_info = extractor.extract_key(headers, query_params)
        
        assert key_info.key_hash is not None
        assert key_info.key_type == KeyType.API_KEY
    
    def test_key_validation(self):
        """Test key hash format validation."""
        extractor = ClientKeyExtractor()
        
        # Valid SHA256 hash (64 hex characters)
        valid_hash = 'a' * 64
        assert extractor.validate_key_format(valid_hash) is True
        
        # Invalid hash (wrong length)
        invalid_hash = 'a' * 32
        assert extractor.validate_key_format(invalid_hash) is False
        
        # Invalid hash (not hex)
        invalid_hash = 'z' * 64
        assert extractor.validate_key_format(invalid_hash) is False
    
    def test_provider_extraction(self):
        """Test provider extraction from headers."""
        extractor = ClientKeyExtractor()
        
        headers = {'x-provider': 'anthropic'}
        provider = extractor.extract_provider_from_headers(headers)
        assert provider == 'anthropic'
    
    def test_key_id_extraction(self):
        """Test key ID extraction from headers."""
        extractor = ClientKeyExtractor()
        
        headers = {'x-key-id': 'key_123'}
        key_id = extractor.extract_key_id_from_headers(headers)
        assert key_id == 'key_123'


class TestAttributionDatabase:
    """Tests for AttributionDatabase class."""
    
    @pytest.fixture
    def temp_db(self):
        """Create temporary database for testing."""
        with tempfile.NamedTemporaryFile(delete=False, suffix='.db') as f:
            db_path = f.name
        
        # Initialize database schema
        from migrate import MigrationManager
        migrations_dir = Path(__file__).parent.parent.parent / 'migrations'
        manager = MigrationManager(db_path, str(migrations_dir))
        manager.migrate()
        
        yield db_path
        
        # Cleanup
        os.unlink(db_path)
    
    def test_lookup_or_create_user(self, temp_db):
        """Test user lookup and creation."""
        db = AttributionDatabase(temp_db)
        
        # Create new user
        user = db.lookup_or_create_user('user123', 'john_doe', 'user@example.com')
        assert user.user_id == 'user123'
        assert user.username == 'john_doe'
        assert user.email == 'user@example.com'
        assert user.id > 0
        
        # Lookup existing user
        user2 = db.lookup_or_create_user('user123')
        assert user2.id == user.id
        assert user2.user_id == 'user123'
    
    def test_lookup_or_create_machine(self, temp_db):
        """Test machine lookup and creation."""
        db = AttributionDatabase(temp_db)
        
        # Create new machine
        machine = db.lookup_or_create_machine(
            'machine123',
            'hostname',
            'Linux',
            '5.4.0'
        )
        assert machine.machine_id == 'machine123'
        assert machine.hostname == 'hostname'
        assert machine.os_type == 'Linux'
        assert machine.id > 0
        
        # Lookup existing machine
        machine2 = db.lookup_or_create_machine('machine123')
        assert machine2.id == machine.id
    
    def test_lookup_or_create_client_key(self, temp_db):
        """Test client key lookup and creation."""
        db = AttributionDatabase(temp_db)
        
        # Create user and machine first
        user = db.lookup_or_create_user('user123')
        machine = db.lookup_or_create_machine('machine123')
        
        # Create new client key
        client_key = db.lookup_or_create_client_key(
            'hash123',
            'bearer',
            'key_id_123',
            user.id,
            machine.id,
            'anthropic'
        )
        assert client_key.key_hash == 'hash123'
        assert client_key.key_type == 'bearer'
        assert client_key.user_id == user.id
        assert client_key.machine_id == machine.id
        assert client_key.id > 0
        
        # Lookup existing client key
        client_key2 = db.lookup_or_create_client_key('hash123', 'bearer')
        assert client_key2.id == client_key.id
    
    def test_anonymize_user_data(self, temp_db):
        """Test user data anonymization."""
        db = AttributionDatabase(temp_db)
        
        # Create user with PII
        user = db.lookup_or_create_user('user123', 'john_doe', 'user@example.com')
        
        # Anonymize
        result = db.anonymize_user_data(user.id)
        assert result is True
        
        # Verify anonymization
        anonymized_user = db.get_user_by_id(user.id)
        assert anonymized_user.username != 'john_doe'
        assert anonymized_user.email != 'user@example.com'


class TestAttributionEnricher:
    """Tests for AttributionEnricher class."""
    
    @pytest.fixture
    def temp_db(self):
        """Create temporary database for testing."""
        with tempfile.NamedTemporaryFile(delete=False, suffix='.db') as f:
            db_path = f.name
        
        # Initialize database schema
        from migrate import MigrationManager
        migrations_dir = Path(__file__).parent.parent.parent / 'migrations'
        manager = MigrationManager(db_path, str(migrations_dir))
        manager.migrate()
        
        yield db_path
        
        # Cleanup
        os.unlink(db_path)
    
    def test_enrich_request_metadata(self, temp_db):
        """Test request metadata enrichment."""
        config = EnrichmentConfig(db_path=temp_db)
        enricher = AttributionEnricher(config)
        
        request_metadata = RequestMetadata(
            method='POST',
            path='/api/v1/chat',
            headers={
                'x-user-id': 'user123',
                'authorization': 'Bearer token123',
                'user-agent': 'Mozilla/5.0'
            },
            query_params={},
            client_ip='192.168.1.100'
        )
        
        result = enricher.enrich_request_metadata(request_metadata)
        
        assert result.success is True
        assert result.attribution is not None
        assert result.attribution.user_id == 'user123'
        assert result.attribution.client_key_hash is not None
        assert result.enrichment_latency_ms < 2.0  # Should be fast
    
    def test_enrich_analytics_event(self, temp_db):
        """Test analytics event enrichment."""
        config = EnrichmentConfig(db_path=temp_db)
        enricher = AttributionEnricher(config)
        
        request_metadata = RequestMetadata(
            method='POST',
            path='/api/v1/chat',
            headers={'x-user-id': 'user123'},
            query_params={},
            client_ip='192.168.1.100'
        )
        
        event = AnalyticsEvent(
            request_metadata=request_metadata,
            position=CollectorPosition.PRE_PROCESSING
        )
        
        enriched_event = enricher.enrich_analytics_event(event)
        
        assert 'user_id' in enriched_event.additional_data
        assert 'machine_id' in enriched_event.additional_data
        assert enriched_event.additional_data['user_id'] == 'user123'
    
    def test_enrichment_latency(self, temp_db):
        """Test that enrichment completes within timeout."""
        config = EnrichmentConfig(db_path=temp_db, enrichment_timeout_ms=1.0)
        enricher = AttributionEnricher(config)
        
        request_metadata = RequestMetadata(
            method='POST',
            path='/api/v1/chat',
            headers={'x-user-id': 'user123'},
            query_params={},
            client_ip='192.168.1.100'
        )
        
        result = enricher.enrich_request_metadata(request_metadata)
        
        assert result.success is True
        assert result.enrichment_latency_ms < 1.0
    
    def test_privacy_controls_in_enrichment(self, temp_db):
        """Test privacy controls in enrichment."""
        config = EnrichmentConfig(
            db_path=temp_db,
            privacy_level=PrivacyLevel.ANONYMIZED
        )
        enricher = AttributionEnricher(config)
        
        request_metadata = RequestMetadata(
            method='POST',
            path='/api/v1/chat',
            headers={
                'x-username': 'john_doe',
                'x-email': 'user@example.com'
            },
            query_params={},
            client_ip='192.168.1.100'
        )
        
        result = enricher.enrich_request_metadata(request_metadata)
        
        # PII should be anonymized
        assert result.attribution.username != 'john_doe'
        assert result.attribution.email != 'user@example.com'


class TestAttributionContext:
    """Tests for attribution context creation."""
    
    def test_create_attribution_context(self):
        """Test attribution context creation for message queue."""
        attribution = UserAttribution(
            user_id='user123',
            username='john_doe',
            machine_id='machine123',
            client_key_hash='hash123'
        )
        
        request_metadata = RequestMetadata(
            method='POST',
            path='/api/v1/chat',
            headers={},
            query_params={},
            client_ip='192.168.1.100'
        )
        
        context = create_attribution_context(attribution, request_metadata)
        
        assert context['user_id'] == 'user123'
        assert context['username'] == 'john_doe'
        assert context['machine_id'] == 'machine123'
        assert context['client_key_hash'] == 'hash123'
        assert context['request_path'] == '/api/v1/chat'
        assert context['request_method'] == 'POST'


if __name__ == '__main__':
    pytest.main([__file__, '-v'])