"""
Machine fingerprinting for consistent device identification.

This module provides methods to generate consistent machine fingerprints
across requests while respecting privacy concerns.
"""

import hashlib
import re
from dataclasses import dataclass
from typing import Optional, Dict, Any
from enum import Enum


class FingerprintMethod(Enum):
    """Methods for machine fingerprinting."""
    IP_BASED = "ip_based"
    USER_AGENT = "user_agent"
    COMBINED = "combined"
    TOKEN_BASED = "token_based"


@dataclass
class FingerprintConfig:
    """Configuration for fingerprinting behavior."""
    method: FingerprintMethod = FingerprintMethod.COMBINED
    enable_ip_masking: bool = True
    enable_ua_parsing: bool = True
    enable_token_tracking: bool = False
    fingerprint_ttl_seconds: int = 86400  # 24 hours


class MachineFingerprinter:
    """
    Generate consistent machine fingerprints for device identification.
    
    This class provides multiple fingerprinting methods with different
    trade-offs between accuracy and privacy:
    - IP-based: Simple but less accurate (NAT, VPNs)
    - User-Agent: More accurate but can be spoofed
    - Combined: Best accuracy with reasonable privacy
    - Token-based: Most accurate, requires client cooperation
    """
    
    def __init__(self, config: FingerprintConfig = None):
        self.config = config or FingerprintConfig()
        self._fingerprint_cache: Dict[str, tuple] = {}  # cache: (hash, timestamp)
    
    def generate_fingerprint(
        self,
        client_ip: str,
        user_agent: Optional[str] = None,
        headers: Optional[Dict[str, str]] = None,
        client_token: Optional[str] = None
    ) -> str:
        """
        Generate machine fingerprint using configured method.
        
        Args:
            client_ip: Client IP address
            user_agent: User-Agent string
            headers: Additional HTTP headers
            client_token: Optional client-provided token
            
        Returns:
            Fingerprint hash string
        """
        if self.config.method == FingerprintMethod.IP_BASED:
            return self._ip_based_fingerprint(client_ip)
        elif self.config.method == FingerprintMethod.USER_AGENT:
            return self._user_agent_fingerprint(user_agent)
        elif self.config.method == FingerprintMethod.TOKEN_BASED:
            return self._token_based_fingerprint(client_token)
        else:  # COMBINED
            return self._combined_fingerprint(client_ip, user_agent, headers)
    
    def _ip_based_fingerprint(self, client_ip: str) -> str:
        """Generate IP-based fingerprint with optional masking."""
        if self.config.enable_ip_masking:
            masked_ip = self._mask_ip_address(client_ip)
        else:
            masked_ip = client_ip
        
        return hashlib.sha256(masked_ip.encode('utf-8')).hexdigest()
    
    def _user_agent_fingerprint(self, user_agent: Optional[str]) -> str:
        """Generate User-Agent based fingerprint."""
        if not user_agent:
            # Fallback to generic hash
            return hashlib.sha256(b'unknown-ua').hexdigest()
        
        # Normalize User-Agent (remove version numbers for stability)
        normalized_ua = self._normalize_user_agent(user_agent)
        return hashlib.sha256(normalized_ua.encode('utf-8')).hexdigest()
    
    def _combined_fingerprint(
        self,
        client_ip: str,
        user_agent: Optional[str] = None,
        headers: Optional[Dict[str, str]] = None
    ) -> str:
        """Generate combined fingerprint from multiple sources."""
        fingerprint_parts = []
        
        # IP component
        if client_ip:
            if self.config.enable_ip_masking:
                fingerprint_parts.append(self._mask_ip_address(client_ip))
            else:
                fingerprint_parts.append(client_ip)
        
        # User-Agent component
        if user_agent and self.config.enable_ua_parsing:
            normalized_ua = self._normalize_user_agent(user_agent)
            fingerprint_parts.append(normalized_ua)
        
        # Additional headers for uniqueness
        if headers:
            # Use stable headers that don't change often
            stable_headers = ['accept-language', 'accept-encoding']
            for header in stable_headers:
                if header in headers:
                    fingerprint_parts.append(headers[header])
        
        # Generate combined hash
        fingerprint_string = '|'.join(fingerprint_parts)
        return hashlib.sha256(fingerprint_string.encode('utf-8')).hexdigest()
    
    def _token_based_fingerprint(self, client_token: Optional[str]) -> str:
        """Generate token-based fingerprint (most accurate)."""
        if not client_token:
            # Fallback to combined method
            return self._combined_fingerprint('unknown', None, None)
        
        return hashlib.sha256(client_token.encode('utf-8')).hexdigest()
    
    def _mask_ip_address(self, ip: str) -> str:
        """
        Mask IP address for privacy.
        
        IPv4: Mask last octet (192.168.1.100 -> 192.168.1.0)
        IPv6: Mask last 64 bits (2001:db8::1 -> 2001:db8::)
        """
        if ':' in ip:  # IPv6
            parts = ip.split(':')
            # Keep first 4 parts (64 bits), mask the rest
            if len(parts) >= 4:
                masked = ':'.join(parts[:4]) + '::'
            else:
                masked = ip
        else:  # IPv4
            parts = ip.split('.')
            if len(parts) == 4:
                masked = '.'.join(parts[:3]) + '.0'
            else:
                masked = ip
        
        return masked
    
    def _normalize_user_agent(self, user_agent: str) -> str:
        """
        Normalize User-Agent string for consistent fingerprinting.
        
        Removes version numbers and keeps only browser/OS family.
        """
        # Remove version numbers (common patterns)
        normalized = re.sub(r'\d+\.\d+', 'X.X', user_agent)
        normalized = re.sub(r'\d+', 'X', normalized)
        
        # Remove specific build numbers
        normalized = re.sub(r'\([^\)]*\)', '', normalized)
        
        return normalized.strip()
    
    def extract_os_info(self, user_agent: Optional[str]) -> Dict[str, str]:
        """
        Extract OS information from User-Agent string.
        
        Args:
            user_agent: User-Agent string
            
        Returns:
            Dict with os_type and os_version
        """
        if not user_agent:
            return {'os_type': 'Unknown', 'os_version': None}
        
        os_patterns = [
            (r'Windows NT (\d+\.\d+)', 'Windows'),
            (r'Windows (\d+)', 'Windows'),
            (r'Mac OS X (\d+[._]\d+)', 'macOS'),
            (r'Macintosh', 'macOS'),
            (r'Android (\d+\.\d+)', 'Android'),
            (r'Android', 'Android'),
            (r'iPhone OS (\d+[._]\d+)', 'iOS'),
            (r'iPad OS (\d+[._]\d+)', 'iOS'),
            (r'iOS', 'iOS'),
            (r'Linux', 'Linux'),
            (r'Ubuntu', 'Linux'),
            (r'Fedora', 'Linux'),
            (r'Debian', 'Linux'),
        ]
        
        for pattern, os_name in os_patterns:
            match = re.search(pattern, user_agent)
            if match:
                version = match.group(1) if match.groups() else None
                # Normalize version format
                if version:
                    version = version.replace('_', '.')
                return {'os_type': os_name, 'os_version': version}
        
        return {'os_type': 'Unknown', 'os_version': None}
    
    def extract_browser_info(self, user_agent: Optional[str]) -> Dict[str, str]:
        """
        Extract browser information from User-Agent string.
        
        Args:
            user_agent: User-Agent string
            
        Returns:
            Dict with browser_name and browser_version
        """
        if not user_agent:
            return {'browser_name': 'Unknown', 'browser_version': None}
        
        browser_patterns = [
            (r'Chrome/(\d+\.\d+)', 'Chrome'),
            (r'Firefox/(\d+\.\d+)', 'Firefox'),
            (r'Safari/(\d+\.\d+)', 'Safari'),
            (r'Edge/(\d+\.\d+)', 'Edge'),
            (r'OPR/(\d+\.\d+)', 'Opera'),
        ]
        
        for pattern, browser_name in browser_patterns:
            match = re.search(pattern, user_agent)
            if match:
                version = match.group(1) if match.groups() else None
                return {'browser_name': browser_name, 'browser_version': version}
        
        return {'browser_name': 'Unknown', 'browser_version': None}
    
    def get_fingerprint_confidence(
        self,
        fingerprint: str,
        client_ip: str,
        user_agent: Optional[str] = None
    ) -> float:
        """
        Calculate confidence score for fingerprint accuracy.
        
        Args:
            fingerprint: Generated fingerprint
            client_ip: Client IP address
            user_agent: User-Agent string
            
        Returns:
            Confidence score between 0.0 and 1.0
        """
        base_confidence = 0.5
        
        # Higher confidence if we have multiple data points
        if client_ip and user_agent:
            base_confidence += 0.3
        
        # Higher confidence if IP is not a common proxy/VPN range
        if not self._is_suspicious_ip(client_ip):
            base_confidence += 0.1
        
        # Higher confidence if User-Agent is not a bot
        if user_agent and not self._is_bot_user_agent(user_agent):
            base_confidence += 0.1
        
        return min(base_confidence, 1.0)
    
    def _is_suspicious_ip(self, ip: str) -> bool:
        """Check if IP is from common proxy/VPN range."""
        # In production, this should query a real IP reputation service
        # For now, basic heuristics
        suspicious_ranges = [
            '10.',          # Private network
            '192.168.',     # Private network
            '172.16.',      # Private network
        ]
        
        for range_prefix in suspicious_ranges:
            if ip.startswith(range_prefix):
                return True
        
        return False
    
    def _is_bot_user_agent(self, user_agent: str) -> bool:
        """Check if User-Agent is from a bot."""
        bot_patterns = [
            'bot', 'crawler', 'spider', 'scraper', 'curl', 'wget'
        ]
        
        user_agent_lower = user_agent.lower()
        for pattern in bot_patterns:
            if pattern in user_agent_lower:
                return True
        
        return False
    
    def cache_fingerprint(self, fingerprint: str, ttl: int = None) -> None:
        """
        Cache fingerprint with TTL for performance.
        
        Args:
            fingerprint: Fingerprint hash
            ttl: Time-to-live in seconds (uses config default if None)
        """
        import time
        ttl = ttl or self.config.fingerprint_ttl_seconds
        self._fingerprint_cache[fingerprint] = (fingerprint, time.time() + ttl)
    
    def get_cached_fingerprint(self, fingerprint: str) -> Optional[str]:
        """
        Get cached fingerprint if still valid.
        
        Args:
            fingerprint: Fingerprint hash to look up
            
        Returns:
            Cached fingerprint if valid and not expired
        """
        import time
        if fingerprint in self._fingerprint_cache:
            cached_fp, expiry = self._fingerprint_cache[fingerprint]
            if time.time() < expiry:
                return cached_fp
            else:
                # Remove expired entry
                del self._fingerprint_cache[fingerprint]
        
        return None
    
    def clear_expired_cache(self) -> None:
        """Remove expired entries from fingerprint cache."""
        import time
        current_time = time.time()
        expired_keys = [
            fp for fp, (_, expiry) in self._fingerprint_cache.items()
            if current_time >= expiry
        ]
        
        for key in expired_keys:
            del self._fingerprint_cache[key]