"""
Unit tests for provider identification and tracking.
"""

import unittest
import time
import sys
from pathlib import Path
from unittest.mock import Mock, patch

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from providers import (
    ProviderType,
    ProviderDetector,
    ModelDetector,
    ModelVersionTracker,
    ProviderMetricsCollector,
    ProviderInfo,
    ModelInfo,
    ModelCategory
)


class TestProviderDetector(unittest.TestCase):
    """Test cases for ProviderDetector."""
    
    def setUp(self):
        """Set up test fixtures."""
        self.detector = ProviderDetector()
    
    def test_detect_anthropic(self):
        """Test detection of Anthropic provider."""
        headers = {'x-api-key': 'test-key', 'anthropic-version': '2023-06-01'}
        provider_type, version = self.detector.detect_provider(headers, 'https://api.anthropic.com/v1/messages')
        
        self.assertEqual(provider_type, ProviderType.ANTHROPIC)
    
    def test_detect_openai(self):
        """Test detection of OpenAI provider."""
        headers = {'authorization': 'Bearer test-key'}
        provider_type, version = self.detector.detect_provider(headers, 'https://api.openai.com/v1/chat/completions')
        
        self.assertEqual(provider_type, ProviderType.OPENAI)
    
    def test_detect_google(self):
        """Test detection of Google provider."""
        headers = {'x-goog-api-key': 'test-key'}
        provider_type, version = self.detector.detect_provider(headers, 'https://generativelanguage.googleapis.com/v1/models')
        
        self.assertEqual(provider_type, ProviderType.GOOGLE)
    
    def test_detect_microsoft(self):
        """Test detection of Microsoft provider."""
        headers = {'api-key': 'test-key'}
        provider_type, version = self.detector.detect_provider(headers, 'https://openai.azure.com/openai/deployments')
        
        self.assertEqual(provider_type, ProviderType.MICROSOFT)
    
    def test_detect_aws(self):
        """Test detection of AWS provider."""
        headers = {'x-amz-date': '20230101T000000Z'}
        provider_type, version = self.detector.detect_provider(headers, 'https://bedrock.amazonaws.com')
        
        self.assertEqual(provider_type, ProviderType.AWS)
    
    def test_detect_unknown(self):
        """Test detection of unknown provider."""
        headers = {'x-unknown': 'test-key'}
        provider_type, version = self.detector.detect_provider(headers, 'https://unknown-provider.com/api')
        
        self.assertEqual(provider_type, ProviderType.UNKNOWN)
        self.assertIsNone(version)
    
    def test_model_based_detection(self):
        """Test provider detection based on model name."""
        headers = {}
        provider_type, version = self.detector.detect_provider(headers, model_name='claude-3-opus')
        
        self.assertEqual(provider_type, ProviderType.ANTHROPIC)


class TestModelDetector(unittest.TestCase):
    """Test cases for ModelDetector."""
    
    def setUp(self):
        """Set up test fixtures."""
        self.detector = ModelDetector()
    
    def test_detect_anthropic_model(self):
        """Test detection of Anthropic model."""
        model_info = self.detector.detect_model('claude-3-opus', ProviderType.ANTHROPIC)
        
        self.assertIsNotNone(model_info)
        self.assertEqual(model_info.model_name, 'claude-3-opus')
        self.assertEqual(model_info.provider_type, ProviderType.ANTHROPIC)
        self.assertEqual(model_info.model_category, ModelCategory.CHAT)
    
    def test_detect_openai_model(self):
        """Test detection of OpenAI model."""
        model_info = self.detector.detect_model('gpt-4', ProviderType.OPENAI)
        
        self.assertIsNotNone(model_info)
        self.assertEqual(model_info.model_name, 'gpt-4')
        self.assertEqual(model_info.provider_type, ProviderType.OPENAI)
        self.assertEqual(model_info.model_category, ModelCategory.CHAT)
    
    def test_detect_google_model(self):
        """Test detection of Google model."""
        model_info = self.detector.detect_model('gemini-pro', ProviderType.GOOGLE)
        
        self.assertIsNotNone(model_info)
        self.assertEqual(model_info.model_name, 'gemini-pro')
        self.assertEqual(model_info.provider_type, ProviderType.GOOGLE)
        self.assertEqual(model_info.model_category, ModelCategory.CHAT)
    
    def test_detect_embedding_model(self):
        """Test detection of embedding model."""
        model_info = self.detector.detect_model('text-embedding-ada-002', ProviderType.OPENAI)
        
        self.assertIsNotNone(model_info)
        self.assertEqual(model_info.model_category, ModelCategory.EMBEDDING)
    
    def test_detect_image_model(self):
        """Test detection of image model."""
        model_info = self.detector.detect_model('dall-e-3', ProviderType.OPENAI)
        
        self.assertIsNotNone(model_info)
        self.assertEqual(model_info.model_category, ModelCategory.IMAGE)
    
    def test_detect_unknown_model(self):
        """Test detection of unknown model."""
        model_info = self.detector.detect_model('unknown-model', ProviderType.UNKNOWN)
        
        self.assertIsNotNone(model_info)
        self.assertEqual(model_info.model_category, ModelCategory.CUSTOM)
    
    def test_model_id_generation(self):
        """Test model ID generation."""
        model_info = self.detector.detect_model('gpt-4', ProviderType.OPENAI)
        
        self.assertIsNotNone(model_info.model_id)
        self.assertEqual(len(model_info.model_id), 16)  # First 16 chars of SHA256


class TestModelVersionTracker(unittest.TestCase):
    """Test cases for ModelVersionTracker."""
    
    def setUp(self):
        """Set up test fixtures."""
        self.tracker = ModelVersionTracker()
    
    def test_record_model_usage(self):
        """Test recording model usage."""
        self.tracker.record_model_usage(
            model_id='model-123',
            version='1.0.0',
            tokens=1000,
            cost=0.01
        )
        
        versions = self.tracker.get_version_history('model-123')
        
        self.assertEqual(len(versions), 1)
        self.assertEqual(versions[0].version, '1.0.0')
        self.assertEqual(versions[0].request_count, 1)
        self.assertEqual(versions[0].total_tokens, 1000)
    
    def test_record_multiple_usages(self):
        """Test recording multiple model usages."""
        for i in range(5):
            self.tracker.record_model_usage(
                model_id='model-123',
                version='1.0.0',
                tokens=1000 + i * 100,
                cost=0.01 + i * 0.001
            )
        
        version = self.tracker.get_version_history('model-123')[0]
        
        self.assertEqual(version.request_count, 5)
        self.assertEqual(version.total_tokens, 6000)
        self.assertAlmostEqual(version.total_cost, 0.06, places=3)
    
    def test_mark_deprecated(self):
        """Test marking model as deprecated."""
        self.tracker.record_model_usage('model-123', '1.0.0')
        self.tracker.mark_deprecated('model-123', '1.0.0', 'model-456')
        
        version = self.tracker.get_version_history('model-123')[0]
        
        self.assertTrue(version.is_deprecated)
        self.assertIsNotNone(version.deprecation_date)
        self.assertEqual(version.replacement_model, 'model-456')
    
    def test_get_current_version(self):
        """Test getting current version."""
        self.tracker.record_model_usage('model-123', '1.0.0')
        self.tracker.record_model_usage('model-123', '2.0.0')
        self.tracker.mark_deprecated('model-123', '1.0.0')
        
        current = self.tracker.get_current_version('model-123')
        
        self.assertIsNotNone(current)
        self.assertEqual(current.version, '2.0.0')
        self.assertFalse(current.is_deprecated)
    
    def test_get_deprecated_models(self):
        """Test getting deprecated models."""
        self.tracker.record_model_usage('model-123', '1.0.0')
        self.tracker.record_model_usage('model-456', '1.0.0')
        self.tracker.mark_deprecated('model-123', '1.0.0')
        
        deprecated = self.tracker.get_deprecated_models()
        
        self.assertEqual(len(deprecated), 1)
        self.assertEqual(deprecated[0].model_id, 'model-123')


class TestProviderMetricsCollector(unittest.TestCase):
    """Test cases for ProviderMetricsCollector."""
    
    def setUp(self):
        """Set up test fixtures."""
        self.collector = ProviderMetricsCollector()
    
    def test_record_request(self):
        """Test recording a request."""
        self.collector.record_request(
            provider_type=ProviderType.ANTHROPIC,
            model_id='claude-3-opus',
            latency_ms=100.0,
            success=True,
            tokens=1000,
            cost=0.01
        )
        
        metrics = self.collector.get_metrics(ProviderType.ANTHROPIC)
        
        self.assertIsNotNone(metrics)
        self.assertEqual(metrics.total_requests, 1)
        self.assertEqual(metrics.successful_requests, 1)
        self.assertEqual(metrics.total_tokens, 1000)
    
    def test_record_multiple_requests(self):
        """Test recording multiple requests."""
        for i in range(5):
            self.collector.record_request(
                provider_type=ProviderType.OPENAI,
                model_id='gpt-4',
                latency_ms=100.0 + i * 10,
                success=i < 4,  # Last one fails
                tokens=1000 + i * 100,
                cost=0.01 + i * 0.001
            )
        
        metrics = self.collector.get_metrics(ProviderType.OPENAI)
        
        self.assertEqual(metrics.total_requests, 5)
        self.assertEqual(metrics.successful_requests, 4)
        self.assertEqual(metrics.failed_requests, 1)
    
    def test_average_latency_calculation(self):
        """Test average latency calculation."""
        latencies = [100.0, 200.0, 300.0]
        for latency in latencies:
            self.collector.record_request(
                provider_type=ProviderType.ANTHROPIC,
                model_id='claude-3-opus',
                latency_ms=latency,
                success=True
            )
        
        metrics = self.collector.get_metrics(ProviderType.ANTHROPIC)
        expected_avg = sum(latencies) / len(latencies)
        
        self.assertAlmostEqual(metrics.avg_latency_ms, expected_avg)
    
    def test_get_all_metrics(self):
        """Test getting metrics for all providers."""
        self.collector.record_request(
            provider_type=ProviderType.ANTHROPIC,
            model_id='claude-3-opus',
            latency_ms=100.0,
            success=True
        )
        
        self.collector.record_request(
            provider_type=ProviderType.OPENAI,
            model_id='gpt-4',
            latency_ms=150.0,
            success=True
        )
        
        all_metrics = self.collector.get_all_metrics()
        
        self.assertEqual(len(all_metrics), 2)
        self.assertIn(ProviderType.ANTHROPIC, all_metrics)
        self.assertIn(ProviderType.OPENAI, all_metrics)


if __name__ == '__main__':
    unittest.main()
