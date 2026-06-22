"""
Pipeline integration for AI analytics collectors.

This module integrates collectors into the AI request pipeline by placing
Collector 1 before Headroom (to capture original requests) and Collector 2
after OmniRoute and before Iron-Proxy (to capture transformed requests).
"""

import time
import uuid
import hashlib
from dataclasses import dataclass, field
from typing import Dict, Any, Optional, List, Tuple
from enum import Enum


class PipelineStage(Enum):
    """Pipeline stages for collector placement."""
    PRE_HEADROOM = "pre_headroom"
    POST_HEADROOM = "post_headroom"
    POST_OMNIROUTE = "post_omniroute"
    PRE_IRON_PROXY = "pre_iron_proxy"
    POST_IRON_PROXY = "post_iron_proxy"


class CollectorPosition(Enum):
    """Collector positions in the pipeline."""
    COLLECTOR_1 = PipelineStage.PRE_HEADROOM
    COLLECTOR_2 = PipelineStage.POST_OMNIROUTE


@dataclass
class PipelineMetadata:
    """Metadata about pipeline stage and transformations."""
    stage: PipelineStage
    correlation_id: str
    timestamp: float = field(default_factory=time.time)
    compression_ratio: Optional[float] = None
    routing_decision: Optional[str] = None
    original_size: Optional[int] = None
    transformed_size: Optional[int] = None
    transformation_chain: List[str] = field(default_factory=list)


@dataclass
class CollectorHealth:
    """Health status of a collector in the pipeline."""
    collector_id: str
    position: CollectorPosition
    is_healthy: bool = True
    last_heartbeat: float = field(default_factory=time.time)
    total_requests: int = 0
    successful_requests: int = 0
    failed_requests: int = 0
    avg_latency_ms: float = 0.0
    error_message: Optional[str] = None


class PipelineIntegrator:
    """
    Integrates collectors into the AI request pipeline.
    
    Manages collector placement, request correlation, and metadata capture
    across different pipeline stages.
    """
    
    def __init__(self):
        self._correlation_map: Dict[str, Dict[str, Any]] = {}
        self._collectors: Dict[CollectorPosition, Any] = {}
        self._health_status: Dict[CollectorPosition, CollectorHealth] = {}
        self._degraded_mode = False
    
    def register_collector(
        self,
        collector_id: str,
        position: CollectorPosition,
        collector_instance: Any
    ):
        """
        Register a collector at a specific pipeline position.
        
        Args:
            collector_id: Unique identifier for the collector
            position: Position in the pipeline
            collector_instance: The collector instance
        """
        self._collectors[position] = collector_instance
        self._health_status[position] = CollectorHealth(
            collector_id=collector_id,
            position=position
        )
    
    def generate_correlation_id(self, request_data: Any) -> str:
        """
        Generate a correlation ID for request tracking.
        
        Args:
            request_data: Request data to correlate
            
        Returns:
            Unique correlation ID
        """
        # Generate unique ID based on request content and timestamp
        request_str = str(request_data) + str(time.time())
        correlation_id = hashlib.sha256(request_str.encode()).hexdigest()[:16]
        
        # Store correlation metadata
        self._correlation_map[correlation_id] = {
            'created_at': time.time(),
            'stages': [],
            'original_data': request_str[:1000],  # Store first 1000 chars
        }
        
        return correlation_id
    
    def add_pipeline_stage(
        self,
        correlation_id: str,
        stage: PipelineStage,
        metadata: Optional[Dict[str, Any]] = None
    ):
        """
        Add a pipeline stage marker to the correlation.
        
        Args:
            correlation_id: Request correlation ID
            stage: Pipeline stage
            metadata: Additional metadata for this stage
        """
        if correlation_id not in self._correlation_map:
            return
        
        stage_info = {
            'stage': stage.value,
            'timestamp': time.time(),
            'metadata': metadata or {}
        }
        
        self._correlation_map[correlation_id]['stages'].append(stage_info)
    
    def capture_compression_metadata(
        self,
        correlation_id: str,
        original_size: int,
        compressed_size: int
    ) -> Optional[float]:
        """
        Capture compression metadata from Headroom.
        
        Args:
            correlation_id: Request correlation ID
            original_size: Original request size
            compressed_size: Compressed request size
            
        Returns:
            Compression ratio
        """
        if original_size == 0:
            return None
        
        compression_ratio = compressed_size / original_size
        
        if correlation_id in self._correlation_map:
            self._correlation_map[correlation_id]['compression'] = {
                'original_size': original_size,
                'compressed_size': compressed_size,
                'ratio': compression_ratio
            }
        
        return compression_ratio
    
    def capture_routing_metadata(
        self,
        correlation_id: str,
        routing_decision: str,
        routing_metadata: Optional[Dict[str, Any]] = None
    ):
        """
        Capture routing metadata from OmniRoute.
        
        Args:
            correlation_id: Request correlation ID
            routing_decision: Routing decision made by OmniRoute
            routing_metadata: Additional routing metadata
        """
        if correlation_id not in self._correlation_map:
            return
        
        self._correlation_map[correlation_id]['routing'] = {
            'decision': routing_decision,
            'metadata': routing_metadata or {},
            'timestamp': time.time()
        }
    
    def get_correlation_data(self, correlation_id: str) -> Optional[Dict[str, Any]]:
        """
        Get all correlation data for a request.
        
        Args:
            correlation_id: Request correlation ID
            
        Returns:
            Correlation data dictionary
        """
        return self._correlation_map.get(correlation_id)
    
    def correlate_requests(
        self,
        collector1_data: Dict[str, Any],
        collector2_data: Dict[str, Any]
    ) -> bool:
        """
        Correlate requests between Collector 1 and Collector 2.
        
        Args:
            collector1_data: Data from Collector 1 (pre-Headroom)
            collector2_data: Data from Collector 2 (post-OmniRoute)
            
        Returns:
            True if correlation successful, False otherwise
        """
        # Try to match by correlation ID
        if 'correlation_id' in collector1_data and 'correlation_id' in collector2_data:
            return collector1_data['correlation_id'] == collector2_data['correlation_id']
        
        # Fallback: match by content hash
        content1 = str(collector1_data.get('content', ''))
        content2 = str(collector2_data.get('content', ''))
        
        hash1 = hashlib.sha256(content1.encode()).hexdigest()
        hash2 = hashlib.sha256(content2.encode()).hexdigest()
        
        return hash1 == hash2
    
    def record_collector_request(
        self,
        position: CollectorPosition,
        success: bool,
        latency_ms: float
    ):
        """
        Record a collector request for health monitoring.
        
        Args:
            position: Collector position
            success: Whether the request was successful
            latency_ms: Request latency
        """
        if position not in self._health_status:
            return
        
        health = self._health_status[position]
        health.total_requests += 1
        health.last_heartbeat = time.time()
        
        if success:
            health.successful_requests += 1
        else:
            health.failed_requests += 1
        
        # Update average latency
        total_latency = health.avg_latency_ms * (health.total_requests - 1)
        health.avg_latency_ms = (total_latency + latency_ms) / health.total_requests
    
    def get_health_status(self, position: CollectorPosition) -> Optional[CollectorHealth]:
        """Get health status for a collector."""
        return self._health_status.get(position)
    
    def get_all_health_status(self) -> Dict[CollectorPosition, CollectorHealth]:
        """Get health status for all collectors."""
        return self._health_status.copy()
    
    def set_degraded_mode(self, degraded: bool):
        """Enable or disable degraded mode for all collectors."""
        self._degraded_mode = degraded
        for position, health in self._health_status.items():
            if degraded:
                health.is_healthy = False
                health.error_message = "Degraded mode enabled"
            else:
                health.is_healthy = True
                health.error_message = None
    
    def cleanup_old_correlations(self, max_age_seconds: float = 3600):
        """
        Clean up old correlation data.
        
        Args:
            max_age_seconds: Maximum age for correlation data
        """
        current_time = time.time()
        stale_ids = [
            correlation_id for correlation_id, data in self._correlation_map.items()
            if current_time - data['created_at'] > max_age_seconds
        ]
        
        for correlation_id in stale_ids:
            del self._correlation_map[correlation_id]
        
        return len(stale_ids)


class Collector1:
    """
    Collector 1: Placed before Headroom to capture original requests.
    
    Captures the original request before any transformations occur.
    """
    
    def __init__(self, integrator: PipelineIntegrator):
        self.integrator = integrator
        self.collector_id = "collector-1"
        self.position = CollectorPosition.COLLECTOR_1
    
    def intercept_request(self, request: Any) -> Dict[str, Any]:
        """
        Intercept request before Headroom.
        
        Args:
            request: The incoming request
            
        Returns:
            Collected metadata
        """
        start_time = time.time()
        
        try:
            # Generate correlation ID
            correlation_id = self.integrator.generate_correlation_id(request)
            
            # Add pipeline stage marker
            self.integrator.add_pipeline_stage(
                correlation_id,
                PipelineStage.PRE_HEADROOM
            )
            
            # Collect metadata
            metadata = {
                'correlation_id': correlation_id,
                'stage': PipelineStage.PRE_HEADROOM.value,
                'timestamp': time.time(),
                'request_size': len(str(request)),
                'collector_id': self.collector_id
            }
            
            # Record health
            latency_ms = (time.time() - start_time) * 1000
            self.integrator.record_collector_request(
                self.position,
                True,
                latency_ms
            )
            
            return metadata
            
        except Exception as e:
            # Record failure
            latency_ms = (time.time() - start_time) * 1000
            self.integrator.record_collector_request(
                self.position,
                False,
                latency_ms
            )
            
            # Set error in health status
            health = self.integrator.get_health_status(self.position)
            if health:
                health.error_message = str(e)
            
            raise


class Collector2:
    """
    Collector 2: Placed after OmniRoute and before Iron-Proxy.
    
    Captures the transformed request after routing decisions.
    """
    
    def __init__(self, integrator: PipelineIntegrator):
        self.integrator = integrator
        self.collector_id = "collector-2"
        self.position = CollectorPosition.COLLECTOR_2
    
    def intercept_request(
        self,
        request: Any,
        correlation_id: Optional[str] = None,
        compression_metadata: Optional[Dict[str, Any]] = None,
        routing_metadata: Optional[Dict[str, Any]] = None
    ) -> Dict[str, Any]:
        """
        Intercept request after OmniRoute.
        
        Args:
            request: The transformed request
            correlation_id: Correlation ID from Collector 1
            compression_metadata: Compression metadata from Headroom
            routing_metadata: Routing metadata from OmniRoute
            
        Returns:
            Collected metadata
        """
        start_time = time.time()
        
        try:
            # Use provided correlation ID or generate new one
            if not correlation_id:
                correlation_id = self.integrator.generate_correlation_id(request)
            
            # Add pipeline stage marker
            self.integrator.add_pipeline_stage(
                correlation_id,
                PipelineStage.POST_OMNIROUTE
            )
            
            # Capture compression metadata
            if compression_metadata:
                self.integrator.capture_compression_metadata(
                    correlation_id,
                    compression_metadata.get('original_size', 0),
                    compression_metadata.get('compressed_size', 0)
                )
            
            # Capture routing metadata
            if routing_metadata:
                self.integrator.capture_routing_metadata(
                    correlation_id,
                    routing_metadata.get('decision', 'unknown'),
                    routing_metadata.get('metadata')
                )
            
            # Collect metadata
            metadata = {
                'correlation_id': correlation_id,
                'stage': PipelineStage.POST_OMNIROUTE.value,
                'timestamp': time.time(),
                'request_size': len(str(request)),
                'collector_id': self.collector_id,
                'compression_ratio': compression_metadata.get('ratio') if compression_metadata else None,
                'routing_decision': routing_metadata.get('decision') if routing_metadata else None
            }
            
            # Record health
            latency_ms = (time.time() - start_time) * 1000
            self.integrator.record_collector_request(
                self.position,
                True,
                latency_ms
            )
            
            return metadata
            
        except Exception as e:
            # Record failure
            latency_ms = (time.time() - start_time) * 1000
            self.integrator.record_collector_request(
                self.position,
                False,
                latency_ms
            )
            
            # Set error in health status
            health = self.integrator.get_health_status(self.position)
            if health:
                health.error_message = str(e)
            
            raise


def create_pipeline_integration() -> PipelineIntegrator:
    """
    Create and configure pipeline integration.
    
    Returns:
        Configured PipelineIntegrator instance
    """
    integrator = PipelineIntegrator()
    
    # Create collectors
    collector1 = Collector1(integrator)
    collector2 = Collector2(integrator)
    
    # Register collectors
    integrator.register_collector(
        collector1.collector_id,
        CollectorPosition.COLLECTOR_1,
        collector1
    )
    
    integrator.register_collector(
        collector2.collector_id,
        CollectorPosition.COLLECTOR_2,
        collector2
    )
    
    return integrator
