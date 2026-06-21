"""
Attribution metadata enrichment for AI analytics pipeline.

This module integrates user attribution extraction with the collector framework
to enrich request metadata with user, machine, and client key information.
"""

import time
from typing import Dict, Any, Optional
from dataclasses import dataclass, field

from .base import RequestMetadata, ResponseMetadata, AnalyticsEvent
from .attribution import (
    AttributionExtractor, 
    UserAttribution, 
    PrivacyLevel,
    create_attribution_context
)
from .fingerprint import MachineFingerprinter, FingerprintConfig
from .client_keys import ClientKeyExtractor, KeyValidationConfig
from .database import AttributionDatabase


@dataclass
class EnrichmentConfig:
    """Configuration for attribution enrichment."""
    enable_user_attribution: bool = True
    enable_machine_fingerprinting: bool = True
    enable_client_key_extraction: bool = True
    enable_database_lookup: bool = True
    privacy_level: PrivacyLevel = PrivacyLevel.FULL
    db_path: str = "analytics.db"
    enrichment_timeout_ms: float = 1.0  # 1ms timeout for enrichment


@dataclass
class EnrichmentResult:
    """Result of attribution enrichment process."""
    success: bool
    attribution: Optional[UserAttribution] = None
    user_db_id: Optional[int] = None
    machine_db_id: Optional[int] = None
    client_key_db_id: Optional[int] = None
    enrichment_latency_ms: float = 0.0
    error_message: Optional[str] = None
    additional_metadata: Dict[str, Any] = field(default_factory=dict)


class AttributionEnricher:
    """
    Enrich request metadata with user attribution information.
    
    This class integrates attribution extraction, machine fingerprinting,
    and client key extraction to provide comprehensive user attribution
    while maintaining minimal latency impact (<1ms).
    """
    
    def __init__(self, config: EnrichmentConfig = None):
        self.config = config or EnrichmentConfig()
        
        # Initialize extractors
        self.attribution_extractor = AttributionExtractor(
            privacy_level=self.config.privacy_level
        )
        self.fingerprinter = MachineFingerprinter()
        self.key_extractor = ClientKeyExtractor()
        
        # Initialize database if enabled
        self.db: Optional[AttributionDatabase] = None
        if self.config.enable_database_lookup:
            self.db = AttributionDatabase(self.config.db_path)
    
    def enrich_request_metadata(
        self,
        request_metadata: RequestMetadata,
        response_metadata: Optional[ResponseMetadata] = None
    ) -> EnrichmentResult:
        """
        Enrich request metadata with attribution information.
        
        Args:
            request_metadata: Original request metadata
            response_metadata: Optional response metadata
            
        Returns:
            EnrichmentResult with attribution data
        """
        start_time = time.time()
        result = EnrichmentResult(success=False)
        
        try:
            # Extract attribution from request
            attribution = self.attribution_extractor.extract_attribution(
                headers=request_metadata.headers,
                client_ip=request_metadata.client_ip,
                user_agent=request_metadata.headers.get('user-agent')
            )
            result.attribution = attribution
            
            # Database lookup/creation if enabled
            if self.config.enable_database_lookup and self.db:
                user_db_id = None
                machine_db_id = None
                client_key_db_id = None
                
                # Look up or create user
                if attribution.user_id:
                    user_record = self.db.lookup_or_create_user(
                        user_id=attribution.user_id,
                        username=attribution.username,
                        email=attribution.email
                    )
                    user_db_id = user_record.id
                    result.user_db_id = user_db_id
                
                # Look up or create machine
                if attribution.machine_id:
                    machine_record = self.db.lookup_or_create_machine(
                        machine_id=attribution.machine_id,
                        hostname=attribution.hostname,
                        os_type=attribution.os_type,
                        os_version=None  # Could be extracted from user agent
                    )
                    machine_db_id = machine_record.id
                    result.machine_db_id = machine_db_id
                
                # Look up or create client key
                if attribution.client_key_hash:
                    client_key_record = self.db.lookup_or_create_client_key(
                        key_hash=attribution.client_key_hash,
                        key_type=attribution.key_type or 'unknown',
                        key_id=attribution.client_key_id,
                        user_id=user_db_id,
                        machine_id=machine_db_id,
                        provider=attribution.provider
                    )
                    client_key_db_id = client_key_record.id
                    result.client_key_db_id = client_key_db_id
            
            # Calculate enrichment latency
            result.enrichment_latency_ms = (time.time() - start_time) * 1000
            
            # Check if enrichment completed within timeout
            if result.enrichment_latency_ms > self.config.enrichment_timeout_ms:
                result.error_message = f"Enrichment timeout: {result.enrichment_latency_ms:.2f}ms"
                # Still mark as success but note the timeout
                result.success = True
            else:
                result.success = True
            
            return result
            
        except Exception as e:
            result.enrichment_latency_ms = (time.time() - start_time) * 1000
            result.error_message = f"Enrichment failed: {str(e)}"
            return result
    
    def enrich_analytics_event(
        self,
        event: AnalyticsEvent
    ) -> AnalyticsEvent:
        """
        Enrich analytics event with attribution information.
        
        Args:
            event: Original analytics event
            
        Returns:
            Enriched analytics event with attribution data
        """
        # Enrich request metadata
        enrichment_result = self.enrich_request_metadata(
            event.request_metadata,
            event.response_metadata
        )
        
        # Add attribution context to event
        if enrichment_result.success and enrichment_result.attribution:
            attribution_context = create_attribution_context(
                enrichment_result.attribution,
                event.request_metadata
            )
            
            # Add database IDs if available
            if enrichment_result.user_db_id:
                attribution_context['user_db_id'] = enrichment_result.user_db_id
            if enrichment_result.machine_db_id:
                attribution_context['machine_db_id'] = enrichment_result.machine_db_id
            if enrichment_result.client_key_db_id:
                attribution_context['client_key_db_id'] = enrichment_result.client_key_db_id
            
            # Add enrichment metadata
            attribution_context['enrichment_latency_ms'] = enrichment_result.enrichment_latency_ms
            if enrichment_result.error_message:
                attribution_context['enrichment_error'] = enrichment_result.error_message
            
            # Merge into event's additional_data
            event.additional_data.update(attribution_context)
        
        return event
    
    def enrich_batch(
        self,
        events: list[AnalyticsEvent]
    ) -> list[AnalyticsEvent]:
        """
        Enrich a batch of analytics events.
        
        Args:
            events: List of analytics events
            
        Returns:
            List of enriched analytics events
        """
        enriched_events = []
        for event in events:
            enriched_event = self.enrich_analytics_event(event)
            enriched_events.append(enriched_event)
        return enriched_events
    
    def get_attribution_summary(
        self,
        enrichment_result: EnrichmentResult
    ) -> Dict[str, Any]:
        """
        Get a summary of attribution data for logging/monitoring.
        
        Args:
            enrichment_result: Result from enrichment process
            
        Returns:
            Summary dictionary with key attribution information
        """
        summary = {
            'success': enrichment_result.success,
            'enrichment_latency_ms': enrichment_result.enrichment_latency_ms,
            'has_user_id': enrichment_result.attribution.user_id is not None if enrichment_result.attribution else False,
            'has_machine_id': enrichment_result.attribution.machine_id is not None if enrichment_result.attribution else False,
            'has_client_key': enrichment_result.attribution.client_key_hash is not None if enrichment_result.attribution else False,
            'privacy_level': enrichment_result.attribution.privacy_level.value if enrichment_result.attribution else None,
        }
        
        if enrichment_result.user_db_id:
            summary['user_db_id'] = enrichment_result.user_db_id
        if enrichment_result.machine_db_id:
            summary['machine_db_id'] = enrichment_result.machine_db_id
        if enrichment_result.client_key_db_id:
            summary['client_key_db_id'] = enrichment_result.client_key_db_id
        
        if enrichment_result.error_message:
            summary['error'] = enrichment_result.error_message
        
        return summary
    
    def apply_privacy_controls_to_event(
        self,
        event: AnalyticsEvent,
        privacy_level: PrivacyLevel
    ) -> AnalyticsEvent:
        """
        Apply privacy controls to an analytics event.
        
        Args:
            event: Analytics event to apply controls to
            privacy_level: Privacy level to apply
            
        Returns:
            Event with privacy controls applied
        """
        if privacy_level == PrivacyLevel.NONE:
            # Remove all attribution data
            keys_to_remove = [
                'user_id', 'username', 'email', 'machine_id', 'hostname',
                'client_key_id', 'client_key_hash', 'user_db_id',
                'machine_db_id', 'client_key_db_id'
            ]
            for key in keys_to_remove:
                event.additional_data.pop(key, None)
        
        elif privacy_level == PrivacyLevel.MINIMAL:
            # Keep only database IDs for aggregate stats
            keys_to_remove = [
                'user_id', 'username', 'email', 'machine_id', 'hostname',
                'client_key_id', 'client_key_hash'
            ]
            for key in keys_to_remove:
                event.additional_data.pop(key, None)
        
        elif privacy_level == PrivacyLevel.ANONYMIZED:
            # Hash PII fields
            pii_fields = ['username', 'email']
            for field in pii_fields:
                if field in event.additional_data and event.additional_data[field]:
                    import hashlib
                    event.additional_data[field] = hashlib.sha256(
                        str(event.additional_data[field]).encode('utf-8')
                    ).hexdigest()
        
        # FULL privacy level - no changes needed
        
        return event


def create_enricher_from_config(config_dict: Dict[str, Any]) -> AttributionEnricher:
    """
    Create AttributionEnricher from configuration dictionary.
    
    Args:
        config_dict: Configuration dictionary
        
    Returns:
        Configured AttributionEnricher instance
    """
    config = EnrichmentConfig(
        enable_user_attribution=config_dict.get('enable_user_attribution', True),
        enable_machine_fingerprinting=config_dict.get('enable_machine_fingerprinting', True),
        enable_client_key_extraction=config_dict.get('enable_client_key_extraction', True),
        enable_database_lookup=config_dict.get('enable_database_lookup', True),
        privacy_level=PrivacyLevel(config_dict.get('privacy_level', 'full')),
        db_path=config_dict.get('db_path', 'analytics.db'),
        enrichment_timeout_ms=config_dict.get('enrichment_timeout_ms', 1.0)
    )
    
    return AttributionEnricher(config)