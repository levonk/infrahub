"""
Unit tests for pipeline integration.
"""

import unittest
import time
import sys
from pathlib import Path
from unittest.mock import Mock, patch

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from pipeline_integration import (
    PipelineStage,
    CollectorPosition,
    PipelineIntegrator,
    Collector1,
    Collector2,
    PipelineMetadata,
    CollectorHealth,
    create_pipeline_integration
)


class TestPipelineIntegrator(unittest.TestCase):
    """Test cases for PipelineIntegrator."""
    
    def setUp(self):
        """Set up test fixtures."""
        self.integrator = PipelineIntegrator()
    
    def test_register_collector(self):
        """Test collector registration."""
        collector = Mock()
        self.integrator.register_collector(
            'test-collector',
            CollectorPosition.COLLECTOR_1,
            collector
        )
        
        self.assertIn(CollectorPosition.COLLECTOR_1, self.integrator._collectors)
        self.assertIn(CollectorPosition.COLLECTOR_1, self.integrator._health_status)
    
    def test_generate_correlation_id(self):
        """Test correlation ID generation."""
        request_data = "test request data"
        correlation_id = self.integrator.generate_correlation_id(request_data)
        
        self.assertIsNotNone(correlation_id)
        self.assertEqual(len(correlation_id), 16)
        self.assertIn(correlation_id, self.integrator._correlation_map)
    
    def test_add_pipeline_stage(self):
        """Test adding pipeline stage marker."""
        correlation_id = self.integrator.generate_correlation_id("test")
        self.integrator.add_pipeline_stage(
            correlation_id,
            PipelineStage.PRE_HEADROOM,
            {'test': 'metadata'}
        )
        
        correlation_data = self.integrator.get_correlation_data(correlation_id)
        self.assertEqual(len(correlation_data['stages']), 1)
        self.assertEqual(correlation_data['stages'][0]['stage'], 'pre_headroom')
    
    def test_capture_compression_metadata(self):
        """Test compression metadata capture."""
        correlation_id = self.integrator.generate_correlation_id("test")
        compression_ratio = self.integrator.capture_compression_metadata(
            correlation_id,
            original_size=1000,
            compressed_size=500
        )
        
        self.assertEqual(compression_ratio, 0.5)
        
        correlation_data = self.integrator.get_correlation_data(correlation_id)
        self.assertIn('compression', correlation_data)
        self.assertEqual(correlation_data['compression']['ratio'], 0.5)
    
    def test_capture_routing_metadata(self):
        """Test routing metadata capture."""
        correlation_id = self.integrator.generate_correlation_id("test")
        self.integrator.capture_routing_metadata(
            correlation_id,
            routing_decision='provider-a',
            routing_metadata={'region': 'us-east'}
        )
        
        correlation_data = self.integrator.get_correlation_data(correlation_id)
        self.assertIn('routing', correlation_data)
        self.assertEqual(correlation_data['routing']['decision'], 'provider-a')
    
    def test_correlate_requests_by_id(self):
        """Test request correlation by ID."""
        data1 = {'correlation_id': 'test-id', 'content': 'test'}
        data2 = {'correlation_id': 'test-id', 'content': 'test'}
        
        result = self.integrator.correlate_requests(data1, data2)
        self.assertTrue(result)
    
    def test_correlate_requests_by_hash(self):
        """Test request correlation by content hash."""
        data1 = {'content': 'test content'}
        data2 = {'content': 'test content'}
        
        result = self.integrator.correlate_requests(data1, data2)
        self.assertTrue(result)
    
    def test_correlate_requests_fail(self):
        """Test failed request correlation."""
        data1 = {'content': 'test content 1'}
        data2 = {'content': 'test content 2'}
        
        result = self.integrator.correlate_requests(data1, data2)
        self.assertFalse(result)
    
    def test_record_collector_request(self):
        """Test recording collector request."""
        self.integrator.register_collector(
            'test-collector',
            CollectorPosition.COLLECTOR_1,
            Mock()
        )
        
        self.integrator.record_collector_request(
            CollectorPosition.COLLECTOR_1,
            success=True,
            latency_ms=100.0
        )
        
        health = self.integrator.get_health_status(CollectorPosition.COLLECTOR_1)
        self.assertEqual(health.total_requests, 1)
        self.assertEqual(health.successful_requests, 1)
        self.assertEqual(health.avg_latency_ms, 100.0)
    
    def test_health_status_tracking(self):
        """Test health status tracking."""
        self.integrator.register_collector(
            'test-collector',
            CollectorPosition.COLLECTOR_1,
            Mock()
        )
        
        # Record successful request
        self.integrator.record_collector_request(
            CollectorPosition.COLLECTOR_1,
            success=True,
            latency_ms=100.0
        )
        
        # Record failed request
        self.integrator.record_collector_request(
            CollectorPosition.COLLECTOR_1,
            success=False,
            latency_ms=200.0
        )
        
        health = self.integrator.get_health_status(CollectorPosition.COLLECTOR_1)
        self.assertEqual(health.total_requests, 2)
        self.assertEqual(health.successful_requests, 1)
        self.assertEqual(health.failed_requests, 1)
        self.assertEqual(health.avg_latency_ms, 150.0)
    
    def test_degraded_mode(self):
        """Test degraded mode."""
        self.integrator.register_collector(
            'test-collector',
            CollectorPosition.COLLECTOR_1,
            Mock()
        )
        
        self.integrator.set_degraded_mode(True)
        
        health = self.integrator.get_health_status(CollectorPosition.COLLECTOR_1)
        self.assertFalse(health.is_healthy)
        self.assertEqual(health.error_message, "Degraded mode enabled")
        
        self.integrator.set_degraded_mode(False)
        
        health = self.integrator.get_health_status(CollectorPosition.COLLECTOR_1)
        self.assertTrue(health.is_healthy)
        self.assertIsNone(health.error_message)
    
    def test_cleanup_old_correlations(self):
        """Test cleanup of old correlation data."""
        # Create some correlation data
        for i in range(5):
            self.integrator.generate_correlation_id(f"test-{i}")
        
        # Manually age one correlation
        old_id = list(self.integrator._correlation_map.keys())[0]
        self.integrator._correlation_map[old_id]['created_at'] = time.time() - 7200  # 2 hours ago
        
        # Cleanup
        cleaned = self.integrator.cleanup_old_correlations(max_age_seconds=3600)
        
        self.assertEqual(cleaned, 1)
        self.assertNotIn(old_id, self.integrator._correlation_map)


class TestCollector1(unittest.TestCase):
    """Test cases for Collector1."""
    
    def setUp(self):
        """Set up test fixtures."""
        self.integrator = PipelineIntegrator()
        self.collector = Collector1(self.integrator)
        # Register the collector
        self.integrator.register_collector(
            self.collector.collector_id,
            self.collector.position,
            self.collector
        )
    
    def test_intercept_request(self):
        """Test request interception."""
        request = "test request data"
        metadata = self.collector.intercept_request(request)
        
        self.assertIsNotNone(metadata)
        self.assertIn('correlation_id', metadata)
        self.assertEqual(metadata['stage'], 'pre_headroom')
        self.assertEqual(metadata['collector_id'], 'collector-1')
    
    def test_pipeline_stage_marker(self):
        """Test pipeline stage marker addition."""
        request = "test request data"
        metadata = self.collector.intercept_request(request)
        
        # Verify the correlation ID was generated
        self.assertIn('correlation_id', metadata)
        
        # Verify the stage was added to correlation data
        correlation_data = self.integrator.get_correlation_data(metadata['correlation_id'])
        self.assertIsNotNone(correlation_data)
        self.assertEqual(len(correlation_data['stages']), 1)
        
        # Verify the request was recorded
        health = self.integrator.get_health_status(CollectorPosition.COLLECTOR_1)
        self.assertEqual(health.total_requests, 1)
    
    def test_health_recording(self):
        """Test health recording."""
        request = "test request data"
        self.collector.intercept_request(request)
        
        health = self.integrator.get_health_status(CollectorPosition.COLLECTOR_1)
        self.assertEqual(health.total_requests, 1)
        self.assertEqual(health.successful_requests, 1)
        self.assertTrue(health.is_healthy)


class TestCollector2(unittest.TestCase):
    """Test cases for Collector2."""
    
    def setUp(self):
        """Set up test fixtures."""
        self.integrator = PipelineIntegrator()
        self.collector = Collector2(self.integrator)
        # Register the collector
        self.integrator.register_collector(
            self.collector.collector_id,
            self.collector.position,
            self.collector
        )
    
    def test_intercept_request(self):
        """Test request interception."""
        request = "transformed request data"
        correlation_id = "test-correlation-id"
        
        metadata = self.collector.intercept_request(
            request,
            correlation_id=correlation_id
        )
        
        self.assertIsNotNone(metadata)
        self.assertEqual(metadata['correlation_id'], correlation_id)
        self.assertEqual(metadata['stage'], 'post_omniroute')
        self.assertEqual(metadata['collector_id'], 'collector-2')
    
    def test_with_compression_metadata(self):
        """Test with compression metadata."""
        request = "transformed request data"
        correlation_id = "test-correlation-id"
        
        # Add correlation_id to the map first (simulating Collector 1)
        self.integrator._correlation_map[correlation_id] = {
            'created_at': time.time(),
            'stages': [],
            'original_data': str(request)[:1000]
        }
        
        compression_metadata = {
            'original_size': 1000,
            'compressed_size': 500,
            'ratio': 0.5
        }
        
        metadata = self.collector.intercept_request(
            request,
            correlation_id=correlation_id,
            compression_metadata=compression_metadata
        )
        
        self.assertEqual(metadata['compression_ratio'], 0.5)
        
        correlation_data = self.integrator.get_correlation_data(correlation_id)
        self.assertIsNotNone(correlation_data)
        self.assertIn('compression', correlation_data)
    
    def test_with_routing_metadata(self):
        """Test with routing metadata."""
        request = "transformed request data"
        correlation_id = "test-correlation-id"
        
        # Add correlation_id to the map first (simulating Collector 1)
        self.integrator._correlation_map[correlation_id] = {
            'created_at': time.time(),
            'stages': [],
            'original_data': str(request)[:1000]
        }
        
        routing_metadata = {
            'decision': 'provider-a',
            'metadata': {'region': 'us-east'}
        }
        
        metadata = self.collector.intercept_request(
            request,
            correlation_id=correlation_id,
            routing_metadata=routing_metadata
        )
        
        self.assertEqual(metadata['routing_decision'], 'provider-a')
        
        correlation_data = self.integrator.get_correlation_data(correlation_id)
        self.assertIsNotNone(correlation_data)
        self.assertIn('routing', correlation_data)
    
    def test_auto_generate_correlation_id(self):
        """Test automatic correlation ID generation."""
        request = "transformed request data"
        
        metadata = self.collector.intercept_request(request)
        
        self.assertIsNotNone(metadata['correlation_id'])
        self.assertIn(metadata['correlation_id'], self.integrator._correlation_map)


class TestCreatePipelineIntegration(unittest.TestCase):
    """Test cases for create_pipeline_integration function."""
    
    def test_create_integration(self):
        """Test pipeline integration creation."""
        integrator = create_pipeline_integration()
        
        self.assertIsInstance(integrator, PipelineIntegrator)
        self.assertEqual(len(integrator._collectors), 2)
        self.assertEqual(len(integrator._health_status), 2)
        
        self.assertIn(CollectorPosition.COLLECTOR_1, integrator._collectors)
        self.assertIn(CollectorPosition.COLLECTOR_2, integrator._collectors)


if __name__ == '__main__':
    unittest.main()
