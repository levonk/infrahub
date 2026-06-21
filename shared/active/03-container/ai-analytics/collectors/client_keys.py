"""
Client key extraction and validation for AI analytics pipeline.

This module handles API key and authentication token extraction with
secure hashing and validation.
"""

import hmac
import hashlib
import re
import time
from dataclasses import dataclass
from typing import Dict, Any, Optional, Tuple, List
from enum import Enum


class KeyType(Enum):
    """Types of client keys."""
    BEARER_TOKEN = "bearer"
    API_KEY = "api_key"
    SESSION_TOKEN = "session_token"
    JWT = "jwt"
    CUSTOM = "custom"


class KeyStatus(Enum):
    """Status of client key validation."""
    VALID = "valid"
    INVALID = "invalid"
    EXPIRED = "expired"
    REVOKED = "revoked"
    UNKNOWN = "unknown"


@dataclass
class ClientKeyInfo:
    """Extracted client key information."""
    key_id: Optional[str] = None
    key_hash: Optional[str] = None
    key_type: Optional[KeyType] = None
    provider: Optional[str] = None
    status: KeyStatus = KeyStatus.UNKNOWN
    extracted_at: float = None
    raw_key_present: bool = False


@dataclass
class KeyValidationConfig:
    """Configuration for key validation."""
    enable_hashing: bool = True
    enable_validation: bool = True
    check_expiry: bool = True
    check_revocation: bool = True
    hashing_algorithm: str = "sha256"
    require_https: bool = False


class ClientKeyExtractor:
    """
    Extract and validate client keys from HTTP requests.
    
    This class provides methods to extract API keys, bearer tokens,
    and other authentication credentials from request headers with
    secure hashing and validation.
    """
    
    def __init__(self, config: KeyValidationConfig = None):
        self.config = config or KeyValidationConfig()
        self._key_patterns = self._build_key_patterns()
        self._secret_key = b'ai-analytics-key-extraction-secret'  # In production, load from secure config
        
    def _build_key_patterns(self) -> List[Tuple[str, KeyType, str]]:
        """Build regex patterns for key extraction."""
        return [
            # Bearer tokens (Authorization: Bearer <token>)
            (r'^authorization$', KeyType.BEARER_TOKEN, 'bearer'),
            # API keys (X-API-Key: <key>)
            (r'^x-api-key$', KeyType.API_KEY, 'raw'),
            (r'^api-key$', KeyType.API_KEY, 'raw'),
            (r'^x-auth-token$', KeyType.SESSION_TOKEN, 'raw'),
            (r'^auth-token$', KeyType.SESSION_TOKEN, 'raw'),
            # Custom keys
            (r'^x-client-key$', KeyType.CUSTOM, 'raw'),
            (r'^client-key$', KeyType.CUSTOM, 'raw'),
        ]
    
    def extract_key(
        self,
        headers: Dict[str, str],
        query_params: Optional[Dict[str, str]] = None
    ) -> ClientKeyInfo:
        """
        Extract client key from headers and query parameters.
        
        Args:
            headers: HTTP request headers
            query_params: Optional query parameters
            
        Returns:
            ClientKeyInfo with extracted information
        """
        key_info = ClientKeyInfo(extracted_at=time.time())
        
        # Try headers first
        for pattern, key_type, extract_method in self._key_patterns:
            for header_name, header_value in headers.items():
                if re.match(pattern, header_name.lower()):
                    result = self._extract_from_header(
                        header_value, key_type, extract_method
                    )
                    if result:
                        key_info.key_hash = result
                        key_info.key_type = key_type
                        key_info.raw_key_present = True
                        key_info.status = KeyStatus.VALID
                        return key_info
        
        # Try query parameters if no key in headers
        if query_params:
            for param_name, param_value in query_params.items():
                if param_name.lower() in ['api_key', 'apikey', 'key', 'token']:
                    if self.config.enable_hashing:
                        key_hash = self._hash_key(param_value)
                        key_info.key_hash = key_hash
                        key_info.key_type = KeyType.API_KEY
                        key_info.raw_key_present = True
                        key_info.status = KeyStatus.VALID
                        return key_info
        
        return key_info
    
    def _extract_from_header(
        self,
        header_value: str,
        key_type: KeyType,
        extract_method: str
    ) -> Optional[str]:
        """
        Extract key from header value based on extraction method.
        
        Args:
            header_value: Header value
            key_type: Type of key
            extract_method: Extraction method ('bearer' or 'raw')
            
        Returns:
            Hashed key or None if extraction fails
        """
        value = header_value.strip()
        
        if extract_method == 'bearer':
            # Extract Bearer token
            if value.lower().startswith('bearer '):
                token = value[7:]  # Remove 'Bearer ' prefix
                if self.config.enable_hashing:
                    return self._hash_key(token)
                return token
        elif extract_method == 'raw':
            # Raw key value
            if self.config.enable_hashing:
                return self._hash_key(value)
            return value
        
        return None
    
    def _hash_key(self, key: str) -> str:
        """
        Hash API key for secure storage.
        
        Args:
            key: Raw key value
            
        Returns:
            Hashed key string
        """
        if self.config.hashing_algorithm == "sha256":
            return hmac.new(
                self._secret_key,
                key.encode('utf-8'),
                hashlib.sha256
            ).hexdigest()
        elif self.config.hashing_algorithm == "sha512":
            return hmac.new(
                self._secret_key,
                key.encode('utf-8'),
                hashlib.sha512
            ).hexdigest()
        else:
            # Default to SHA256
            return hmac.new(
                self._secret_key,
                key.encode('utf-8'),
                hashlib.sha256
            ).hexdigest()
    
    def validate_key_format(self, key_hash: str) -> bool:
        """
        Validate key hash format.
        
        Args:
            key_hash: Hashed key to validate
            
        Returns:
            True if format is valid
        """
        # Check hash length based on algorithm
        expected_length = 64 if self.config.hashing_algorithm == "sha256" else 128
        
        if len(key_hash) != expected_length:
            return False
        
        # Check if valid hex string
        try:
            int(key_hash, 16)
            return True
        except ValueError:
            return False
    
    def infer_provider_from_key(self, key_hash: str) -> Optional[str]:
        """
        Infer provider from key characteristics.
        
        This is a heuristic approach - in production, use a proper
        key registry or provider API.
        
        Args:
            key_hash: Hashed key
            
        Returns:
            Inferred provider name or None
        """
        # In production, this would query a key registry
        # For now, return None as we can't reliably infer from hash
        return None
    
    def extract_provider_from_headers(
        self,
        headers: Dict[str, str]
    ) -> Optional[str]:
        """
        Extract AI provider from request headers.
        
        Args:
            headers: HTTP request headers
            
        Returns:
            Provider name or None
        """
        provider_patterns = [
            (r'^x-provider$', 'provider'),
            (r'^provider$', 'provider'),
            (r'^x-ai-provider$', 'provider'),
            (r'^ai-provider$', 'provider'),
            (r'^host$', 'host'),  # Infer from destination host
        ]
        
        for pattern, field in provider_patterns:
            for header_name, header_value in headers.items():
                if re.match(pattern, header_name.lower()):
                    return header_value.strip()
        
        return None
    
    def extract_key_id_from_headers(
        self,
        headers: Dict[str, str]
    ) -> Optional[str]:
        """
        Extract key ID from headers (if provided by client).
        
        Args:
            headers: HTTP request headers
            
        Returns:
            Key ID or None
        """
        key_id_patterns = [
            (r'^x-key-id$', 'key_id'),
            (r'^key-id$', 'key_id'),
            (r'^x-api-key-id$', 'key_id'),
            (r'^api-key-id$', 'key_id'),
        ]
        
        for pattern, field in key_id_patterns:
            for header_name, header_value in headers.items():
                if re.match(pattern, header_name.lower()):
                    return header_value.strip()
        
        return None
    
    def check_key_expiry(
        self,
        key_hash: str,
        expiry_timestamp: Optional[float] = None
    ) -> KeyStatus:
        """
        Check if key has expired.
        
        Args:
            key_hash: Hashed key
            expiry_timestamp: Optional expiry timestamp
            
        Returns:
            KeyStatus indicating if key is expired
        """
        if not self.config.check_expiry or not expiry_timestamp:
            return KeyStatus.VALID
        
        if time.time() > expiry_timestamp:
            return KeyStatus.EXPIRED
        
        return KeyStatus.VALID
    
    def check_key_revocation(
        self,
        key_hash: str,
        revoked_keys: Optional[List[str]] = None
    ) -> KeyStatus:
        """
        Check if key has been revoked.
        
        Args:
            key_hash: Hashed key
            revoked_keys: List of revoked key hashes
            
        Returns:
            KeyStatus indicating if key is revoked
        """
        if not self.config.check_revocation or not revoked_keys:
            return KeyStatus.VALID
        
        if key_hash in revoked_keys:
            return KeyStatus.REVOKED
        
        return KeyStatus.VALID
    
    def validate_key_comprehensive(
        self,
        key_info: ClientKeyInfo,
        expiry_timestamp: Optional[float] = None,
        revoked_keys: Optional[List[str]] = None
    ) -> ClientKeyInfo:
        """
        Perform comprehensive key validation.
        
        Args:
            key_info: Client key information
            expiry_timestamp: Optional expiry timestamp
            revoked_keys: List of revoked key hashes
            
        Returns:
            Updated ClientKeyInfo with validation status
        """
        if not key_info.key_hash:
            key_info.status = KeyStatus.UNKNOWN
            return key_info
        
        # Validate format
        if not self.validate_key_format(key_info.key_hash):
            key_info.status = KeyStatus.INVALID
            return key_info
        
        # Check expiry
        expiry_status = self.check_key_expiry(
            key_info.key_hash, expiry_timestamp
        )
        if expiry_status != KeyStatus.VALID:
            key_info.status = expiry_status
            return key_info
        
        # Check revocation
        revocation_status = self.check_key_revocation(
            key_info.key_hash, revoked_keys
        )
        if revocation_status != KeyStatus.VALID:
            key_info.status = revocation_status
            return key_info
        
        key_info.status = KeyStatus.VALID
        return key_info


def create_key_lookup_or_create(
    key_hash: str,
    key_type: KeyType,
    provider: Optional[str] = None,
    db_connection: Any = None
) -> int:
    """
    Look up or create client key record in database.
    
    Args:
        key_hash: Hashed client key
        key_type: Type of key
        provider: Optional provider name
        db_connection: Database connection
        
    Returns:
        Database ID of the client key record
    """
    # In production, this would query/create in the database
    # For now, return a placeholder
    if db_connection:
        # TODO: Implement database lookup/creation
        pass
    
    return 0  # Placeholder