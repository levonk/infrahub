"""
Simple test runner for attribution collection without pytest dependency.
"""

import sys
import os
import tempfile
from pathlib import Path

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from attribution import (
    AttributionExtractor,
    UserAttribution,
    PrivacyLevel
)
from fingerprint import (
    MachineFingerprinter,
    FingerprintConfig,
    FingerprintMethod
)
from client_keys import (
    ClientKeyExtractor,
    KeyValidationConfig,
    KeyType,
    KeyStatus
)


def test_attributon_extractor():
    """Test basic attribution extraction."""
    print("Testing AttributionExtractor...")
    
    extractor = AttributionExtractor()
    
    # Test user ID extraction
    headers = {'x-user-id': 'user123'}
    attribution = extractor.extract_attribution(headers, '127.0.0.1')
    assert attribution.user_id == 'user123', f"Expected user123, got {attribution.user_id}"
    print("✓ User ID extraction works")
    
    # Test bearer token extraction
    headers = {'authorization': 'Bearer secret_token_123'}
    attribution = extractor.extract_attribution(headers, '127.0.0.1')
    assert attribution.client_key_hash is not None, "Expected client key hash"
    assert attribution.key_type == 'bearer', f"Expected bearer, got {attribution.key_type}"
    print("✓ Bearer token extraction works")
    
    # Test machine fingerprint
    headers = {'user-agent': 'Mozilla/5.0 (Windows NT 10.0)', 'host': 'example.com'}
    attribution = extractor.extract_attribution(headers, '192.168.1.100')
    assert attribution.machine_id is not None, "Expected machine ID"
    assert len(attribution.machine_id) == 64, f"Expected 64 char hash, got {len(attribution.machine_id)}"
    print("✓ Machine fingerprint generation works")
    
    # Test privacy controls
    extractor_anon = AttributionExtractor(privacy_level=PrivacyLevel.ANONYMIZED)
    headers = {'x-username': 'john_doe'}
    attribution = extractor_anon.extract_attribution(headers, '127.0.0.1')
    assert attribution.username != 'john_doe', "Expected anonymized username"
    print("✓ Privacy controls work")


def test_machine_fingerprinter():
    """Test machine fingerprinting."""
    print("\nTesting MachineFingerprinter...")
    
    fingerprinter = MachineFingerprinter()
    
    # Test IP-based fingerprint
    fingerprint = fingerprinter.generate_fingerprint('192.168.1.100')
    assert fingerprint is not None, "Expected fingerprint"
    assert len(fingerprint) == 64, f"Expected 64 char hash, got {len(fingerprint)}"
    print("✓ IP-based fingerprint works")
    
    # Test User-Agent based fingerprint
    fingerprint = fingerprinter.generate_fingerprint(
        '127.0.0.1',
        user_agent='Mozilla/5.0 (Windows NT 10.0)'
    )
    assert fingerprint is not None, "Expected fingerprint"
    print("✓ User-Agent based fingerprint works")
    
    # Test OS extraction
    os_info = fingerprinter.extract_os_info('Mozilla/5.0 (Windows NT 10.0)')
    assert os_info['os_type'] == 'Windows', f"Expected Windows, got {os_info['os_type']}"
    print("✓ OS extraction works")
    
    # Test IP masking
    masked = fingerprinter._mask_ip_address('192.168.1.100')
    assert masked == '192.168.1.0', f"Expected 192.168.1.0, got {masked}"
    print("✓ IP masking works")


def test_client_key_extractor():
    """Test client key extraction."""
    print("\nTesting ClientKeyExtractor...")
    
    extractor = ClientKeyExtractor()
    
    # Test bearer token extraction
    headers = {'authorization': 'Bearer secret_token'}
    key_info = extractor.extract_key(headers)
    assert key_info.key_hash is not None, "Expected key hash"
    assert key_info.key_type == KeyType.BEARER_TOKEN, f"Expected bearer, got {key_info.key_type}"
    assert key_info.raw_key_present is True, "Expected raw key present"
    print("✓ Bearer token extraction works")
    
    # Test API key extraction
    headers = {'x-api-key': 'api_key_123'}
    key_info = extractor.extract_key(headers)
    assert key_info.key_hash is not None, "Expected key hash"
    assert key_info.key_type == KeyType.API_KEY, f"Expected api_key, got {key_info.key_type}"
    print("✓ API key extraction works")
    
    # Test key validation
    valid_hash = 'a' * 64
    assert extractor.validate_key_format(valid_hash) is True, "Expected valid hash"
    invalid_hash = 'a' * 32
    assert extractor.validate_key_format(invalid_hash) is False, "Expected invalid hash"
    print("✓ Key validation works")


def test_integration():
    """Test integration of all components."""
    print("\nTesting integration...")
    
    # Create extractors
    attribution_extractor = AttributionExtractor()
    fingerprinter = MachineFingerprinter()
    key_extractor = ClientKeyExtractor()
    
    # Simulate a request
    headers = {
        'x-user-id': 'user123',
        'authorization': 'Bearer secret_token',
        'user-agent': 'Mozilla/5.0 (Windows NT 10.0)',
        'host': 'example.com'
    }
    
    # Extract attribution
    attribution = attribution_extractor.extract_attribution(headers, '192.168.1.100')
    
    # Verify all components worked
    assert attribution.user_id == 'user123', "Expected user ID"
    assert attribution.client_key_hash is not None, "Expected client key hash"
    assert attribution.machine_id is not None, "Expected machine ID"
    assert attribution.hostname == 'example.com', "Expected hostname"
    
    print("✓ Integration test passed")


def main():
    """Run all tests."""
    print("=" * 60)
    print("Running Attribution Collection Tests")
    print("=" * 60)
    
    try:
        test_attributon_extractor()
        test_machine_fingerprinter()
        test_client_key_extractor()
        test_integration()
        
        print("\n" + "=" * 60)
        print("✓ All tests passed!")
        print("=" * 60)
        return 0
    except AssertionError as e:
        print(f"\n✗ Test failed: {e}")
        return 1
    except Exception as e:
        print(f"\n✗ Unexpected error: {e}")
        import traceback
        traceback.print_exc()
        return 1


if __name__ == '__main__':
    sys.exit(main())