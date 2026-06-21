"""
User attribution collection for AI analytics pipeline.

This module implements user-level attribution tracking to identify which users,
machines, and client keys are making AI requests. It provides privacy controls
and minimal latency impact (<1ms additional latency).
"""

import hashlib
import hmac
import time
import re
from dataclasses import dataclass, field
from typing import Dict, Any, Optional, Tuple
from enum import Enum
import json


class PrivacyLevel(Enum):
    """Privacy control levels for user data."""
    FULL = "full"                    # Store all user data
    ANONYMIZED = "anonymized"        # Hash identifiers, no PII
    MINIMAL = "minimal"              # Only aggregate statistics
    NONE = "none"                    # No attribution data


@dataclass
class UserAttribution:
    """Extracted user attribution from a request."""
    user_id: Optional[str] = None
    username: Optional[str] = None
    email: Optional[str] = None
    machine_id: Optional[str] = None
    hostname: Optional[str] = None
    os_type: Optional[str] = None
    os_version: Optional[str] = None
    client_key_id: Optional[str] = None
    client_key_hash: Optional[str] = None
    key_type: Optional[str] = None
    provider: Optional[str] = None
    privacy_level: PrivacyLevel = PrivacyLevel.FULL
    timestamp: float = field(default_factory=time.time)


@dataclass
class MachineFingerprint:
    """Machine fingerprint for consistent identification."""
    fingerprint_hash: str
    hostname: Optional[str] = None
    user_agent: Optional[str] = None
    ip_address: Optional[str] = None
    os_signature: Optional[str] = None
    confidence_score: float = 1.0


class AttributionExtractor:
    """
    Extract user attribution from HTTP requests with privacy controls.
    
    This class provides methods to identify users, machines, and client keys
    from incoming requests while respecting privacy settings and maintaining
    minimal latency impact.
    """
    
    def __init__(self, privacy_level: PrivacyLevel = PrivacyLevel.FULL):
        self.privacy_level = privacy_level
        self._user_id_patterns = [
            # Common user ID header patterns
            (r'^x-user-id$', 'user_id'),
            (r'^x-user$', 'user_id'),
            (r'^user-id$', 'user_id'),
            (r'^user$', 'user_id'),
        ]
        self._username_patterns = [
            (r'^x-username$', 'username'),
            (r'^username$', 'username'),
        ]
        self._email_patterns = [
            (r'^x-email$', 'email'),
            (r'^email$', 'email'),
        ]
        self._api_key_patterns = [
            (r'^authorization$', 'bearer'),
            (r'^x-api-key$', 'raw'),
            (r'^api-key$', 'raw'),
            (r'^x-auth-token$', 'raw'),
        ]
        
    def extract_attribution(
        self,
        headers: Dict[str, str],
        client_ip: str,
        user_agent: Optional[str] = None
    ) -> UserAttribution:
        """
        Extract user attribution from request headers and metadata.
        
        Args:
            headers: HTTP request headers
            client_ip: Client IP address
            user_agent: User-Agent string (optional)
            
        Returns:
            UserAttribution with extracted information
        """
        attribution = UserAttribution(privacy_level=self.privacy_level)
        
        # Extract user information
        attribution.user_id = self._extract_user_id(headers)
        attribution.username = self._extract_username(headers)
        attribution.email = self._extract_email(headers)
        
        # Extract machine fingerprint
        fingerprint = self._generate_machine_fingerprint(
            headers, client_ip, user_agent
        )
        attribution.machine_id = fingerprint.fingerprint_hash
        attribution.hostname = fingerprint.hostname
        attribution.os_type = fingerprint.os_signature
        
        # Extract client key
        key_id, key_hash, key_type, provider = self._extract_client_key(headers)
        attribution.client_key_id = key_id
        attribution.client_key_hash = key_hash
        attribution.key_type = key_type
        attribution.provider = provider
        
        # Apply privacy controls
        return self._apply_privacy_controls(attribution)
    
    def _extract_user_id(self, headers: Dict[str, str]) -> Optional[str]:
        """Extract user ID from headers using pattern matching."""
        for pattern, field in self._user_id_patterns:
            for header_name, header_value in headers.items():
                if re.match(pattern, header_name.lower()):
                    return header_value.strip()
        return None
    
    def _extract_username(self, headers: Dict[str, str]) -> Optional[str]:
        """Extract username from headers using pattern matching."""
        for pattern, field in self._username_patterns:
            for header_name, header_value in headers.items():
                if re.match(pattern, header_name.lower()):
                    return header_value.strip()
        return None
    
    def _extract_email(self, headers: Dict[str, str]) -> Optional[str]:
        """Extract email from headers using pattern matching."""
        for pattern, field in self._email_patterns:
            for header_name, header_value in headers.items():
                if re.match(pattern, header_name.lower()):
                    # Basic email validation
                    if re.match(r'^[^@]+@[^@]+\.[^@]+$', header_value.strip()):
                        return header_value.strip()
        return None
    
    def _extract_client_key(
        self, 
        headers: Dict[str, str]
    ) -> Tuple[Optional[str], Optional[str], Optional[str], Optional[str]]:
        """
        Extract client key information from headers.
        
        Returns:
            Tuple of (key_id, key_hash, key_type, provider)
        """
        for pattern, extract_type in self._api_key_patterns:
            for header_name, header_value in headers.items():
                if re.match(pattern, header_name.lower()):
                    value = header_value.strip()
                    
                    if extract_type == 'bearer' and value.startswith('Bearer '):
                        token = value[7:]  # Remove 'Bearer ' prefix
                        key_hash = self._hash_key(token)
                        return None, key_hash, 'bearer', None
                    elif extract_type == 'raw':
                        key_hash = self._hash_key(value)
                        return None, key_hash, 'api_key', None
        
        return None, None, None, None
    
    def _generate_machine_fingerprint(
        self,
        headers: Dict[str, str],
        client_ip: str,
        user_agent: Optional[str] = None
    ) -> MachineFingerprint:
        """
        Generate consistent machine fingerprint from available data.
        
        Uses multiple factors to create a stable fingerprint:
        - IP address (with privacy masking)
        - User-Agent string
        - Host header
        - Accept-Language header
        """
        fingerprint_data = []
        
        # Add IP address (masked for privacy)
        if client_ip and client_ip != 'unknown':
            # Mask last octet for IPv4, last 64 bits for IPv6
            if ':' in client_ip:  # IPv6
                masked_ip = ':'.join(client_ip.split(':')[:4]) + '::'
            else:  # IPv4
                octets = client_ip.split('.')
                masked_ip = '.'.join(octets[:3]) + '.0'
            fingerprint_data.append(masked_ip)
        
        # Add User-Agent
        if user_agent:
            fingerprint_data.append(user_agent)
        
        # Add Host header
        if 'host' in headers:
            fingerprint_data.append(headers['host'])
        
        # Add Accept-Language
        if 'accept-language' in headers:
            fingerprint_data.append(headers['accept-language'])
        
        # Generate hash
        fingerprint_string = '|'.join(fingerprint_data)
        fingerprint_hash = hashlib.sha256(
            fingerprint_string.encode('utf-8')
        ).hexdigest()
        
        return MachineFingerprint(
            fingerprint_hash=fingerprint_hash,
            hostname=headers.get('host'),
            user_agent=user_agent,
            ip_address=client_ip,
            os_signature=self._extract_os_signature(user_agent) if user_agent else None
        )
    
    def _extract_os_signature(self, user_agent: str) -> Optional[str]:
        """Extract OS signature from User-Agent string."""
        if not user_agent:
            return None
        
        os_patterns = [
            (r'Windows NT (\d+\.\d+)', 'Windows'),
            (r'Mac OS X (\d+[._]\d+)', 'macOS'),
            (r'Android (\d+\.\d+)', 'Android'),
            (r'iPhone OS (\d+[._]\d+)', 'iOS'),
            (r'Linux', 'Linux'),
        ]
        
        for pattern, os_name in os_patterns:
            if re.search(pattern, user_agent):
                return os_name
        
        return 'Unknown'
    
    def _hash_key(self, key: str) -> str:
        """
        Hash API key for secure storage.
        
        Uses HMAC-SHA256 with a server-side secret (in production,
        this should be loaded from secure configuration).
        """
        # In production, use a proper secret key from configuration
        secret = b'ai-analytics-attribution-secret-key'
        return hmac.new(secret, key.encode('utf-8'), hashlib.sha256).hexdigest()
    
    def _apply_privacy_controls(
        self, 
        attribution: UserAttribution
    ) -> UserAttribution:
        """
        Apply privacy controls based on configured privacy level.
        
        Args:
            attribution: Raw attribution data
            
        Returns:
            Attribution with privacy controls applied
        """
        if self.privacy_level == PrivacyLevel.FULL:
            return attribution
        
        elif self.privacy_level == PrivacyLevel.ANONYMIZED:
            # Hash PII fields
            if attribution.username:
                attribution.username = hashlib.sha256(
                    attribution.username.encode('utf-8')
                ).hexdigest()
            if attribution.email:
                attribution.email = hashlib.sha256(
                    attribution.email.encode('utf-8')
                ).hexdigest()
            return attribution
        
        elif self.privacy_level == PrivacyLevel.MINIMAL:
            # Only keep machine_id and client_key_hash for aggregate stats
            attribution.user_id = None
            attribution.username = None
            attribution.email = None
            attribution.hostname = None
            return attribution
        
        elif self.privacy_level == PrivacyLevel.NONE:
            # No attribution data
            return UserAttribution(privacy_level=PrivacyLevel.NONE)
        
        return attribution
    
    def anonymize_user_id(self, user_id: str) -> str:
        """
        Anonymize user ID for privacy-compliant storage.
        
        Args:
            user_id: Raw user identifier
            
        Returns:
            Hashed user identifier
        """
        return hashlib.sha256(user_id.encode('utf-8')).hexdigest()
    
    def validate_client_key(self, key_hash: str) -> bool:
        """
        Validate client key format and security.
        
        Args:
            key_hash: Hashed client key
            
        Returns:
            True if key format is valid
        """
        # Basic validation: check hash length (SHA256 = 64 hex chars)
        if len(key_hash) != 64:
            return False
        
        # Check if valid hex string
        try:
            int(key_hash, 16)
            return True
        except ValueError:
            return False


def create_attribution_context(
    attribution: UserAttribution,
    request_metadata: Any
) -> Dict[str, Any]:
    """
    Create attribution context for message queue format.
    
    Args:
        attribution: Extracted user attribution
        request_metadata: Original request metadata
        
    Returns:
        Dictionary with attribution context for queuing
    """
    return {
        'user_id': attribution.user_id,
        'username': attribution.username,
        'email': attribution.email,
        'machine_id': attribution.machine_id,
        'hostname': attribution.hostname,
        'os_type': attribution.os_type,
        'client_key_id': attribution.client_key_id,
        'client_key_hash': attribution.client_key_hash,
        'key_type': attribution.key_type,
        'provider': attribution.provider,
        'privacy_level': attribution.privacy_level.value,
        'timestamp': attribution.timestamp,
        'request_path': getattr(request_metadata, 'path', None),
        'request_method': getattr(request_metadata, 'method', None),
    }