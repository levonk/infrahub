"""
Unit tests for subagent identification and tracking.
"""

import unittest
import time
import sys
from pathlib import Path
from unittest.mock import Mock, patch

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from subagent import (
    SubagentType,
    SubagentDetector,
    SubagentTracker,
    SubagentInstance,
    SubagentMetrics,
    generate_instance_id
)


class TestSubagentDetector(unittest.TestCase):
    """Test cases for SubagentDetector."""
    
    def setUp(self):
        """Set up test fixtures."""
        self.detector = SubagentDetector()
    
    def test_detect_claude_code(self):
        """Test detection of Claude Code agent."""
        headers = {'x-claude-code': '1.0.0'}
        subagent_type, version = self.detector.detect_subagent(headers, 'claude-code/1.0.0')
        
        self.assertEqual(subagent_type, SubagentType.CLAUDE_CODE)
        self.assertEqual(version, '1.0.0')
    
    def test_detect_codex(self):
        """Test detection of Codex agent."""
        headers = {'x-codex': '2.1.0'}
        subagent_type, version = self.detector.detect_subagent(headers, 'openai-codex/2.1.0')
        
        self.assertEqual(subagent_type, SubagentType.CODEX)
        self.assertEqual(version, '2.1.0')
    
    def test_detect_pi(self):
        """Test detection of Pi agent."""
        headers = {'x-pi': '3.0.0'}
        subagent_type, version = self.detector.detect_subagent(headers, 'pi-ai/3.0.0')
        
        self.assertEqual(subagent_type, SubagentType.PI)
        self.assertEqual(version, '3.0.0')
    
    def test_detect_devin(self):
        """Test detection of Devin agent."""
        headers = {'x-devin': '1.5.0'}
        subagent_type, version = self.detector.detect_subagent(headers, 'devin-ai/1.5.0')
        
        self.assertEqual(subagent_type, SubagentType.DEVIN)
        self.assertEqual(version, '1.5.0')
    
    def test_detect_unknown(self):
        """Test detection of unknown agent."""
        headers = {'x-unknown': '1.0.0'}
        subagent_type, version = self.detector.detect_subagent(headers, 'unknown-agent/1.0.0')
        
        self.assertEqual(subagent_type, SubagentType.UNKNOWN)
        self.assertIsNone(version)
    
    def test_version_extraction(self):
        """Test version string extraction."""
        user_agent = 'claude-code/1.2.3'
        version = self.detector._extract_version(user_agent)
        
        self.assertEqual(version, '1.2.3')
    
    def test_version_extraction_none(self):
        """Test version extraction when no version present."""
        user_agent = 'claude-code'
        version = self.detector._extract_version(user_agent)
        
        self.assertIsNone(version)


class TestSubagentTracker(unittest.TestCase):
    """Test cases for SubagentTracker."""
    
    def setUp(self):
        """Set up test fixtures."""
        self.tracker = SubagentTracker()
    
    def test_create_new_instance(self):
        """Test creation of new subagent instance."""
        instance = self.tracker.get_or_create_instance(
            SubagentType.CLAUDE_CODE,
            '1.0.0',
            'session-123',
            'user-456',
            'machine-789'
        )
        
        self.assertIsInstance(instance, SubagentInstance)
        self.assertEqual(instance.subagent_type, SubagentType.CLAUDE_CODE)
        self.assertEqual(instance.version, '1.0.0')
        self.assertEqual(instance.request_count, 0)
    
    def test_reuse_existing_instance(self):
        """Test reuse of existing subagent instance."""
        # Create instance first time
        instance1 = self.tracker.get_or_create_instance(
            SubagentType.CLAUDE_CODE,
            '1.0.0',
            'session-123',
            'user-456',
            'machine-789'
        )
        
        # Create instance second time with same parameters
        instance2 = self.tracker.get_or_create_instance(
            SubagentType.CLAUDE_CODE,
            '1.0.0',
            'session-123',
            'user-456',
            'machine-789'
        )
        
        self.assertEqual(instance1.instance_id, instance2.instance_id)
    
    def test_record_request(self):
        """Test recording a request for an instance."""
        instance = self.tracker.get_or_create_instance(
            SubagentType.CLAUDE_CODE,
            '1.0.0',
            'session-123',
            'user-456',
            'machine-789'
        )
        
        self.tracker.record_request(
            instance.instance_id,
            duration_ms=100.0,
            success=True,
            tokens=1000,
            cost=0.01
        )
        
        self.assertEqual(instance.request_count, 1)
        self.assertEqual(instance.total_tokens, 1000)
        self.assertEqual(instance.total_cost, 0.01)
    
    def test_record_multiple_requests(self):
        """Test recording multiple requests."""
        instance = self.tracker.get_or_create_instance(
            SubagentType.CLAUDE_CODE,
            '1.0.0',
            'session-123',
            'user-456',
            'machine-789'
        )
        
        for i in range(5):
            self.tracker.record_request(
                instance.instance_id,
                duration_ms=100.0 + i * 10,
                success=True,
                tokens=1000 + i * 100,
                cost=0.01 + i * 0.001
            )
        
        self.assertEqual(instance.request_count, 5)
        self.assertEqual(instance.total_tokens, 6000)
        self.assertAlmostEqual(instance.total_cost, 0.06, places=3)
    
    def test_get_metrics(self):
        """Test getting metrics for an instance."""
        instance = self.tracker.get_or_create_instance(
            SubagentType.CLAUDE_CODE,
            '1.0.0',
            'session-123',
            'user-456',
            'machine-789'
        )
        
        self.tracker.record_request(
            instance.instance_id,
            duration_ms=100.0,
            success=True,
            tokens=1000,
            cost=0.01
        )
        
        metrics = self.tracker.get_metrics(instance.instance_id)
        
        self.assertIsInstance(metrics, SubagentMetrics)
        self.assertEqual(metrics.total_requests, 1)
        self.assertEqual(metrics.successful_requests, 1)
        self.assertEqual(metrics.failed_requests, 0)
    
    def test_cleanup_stale_instances(self):
        """Test cleanup of stale instances."""
        instance = self.tracker.get_or_create_instance(
            SubagentType.CLAUDE_CODE,
            '1.0.0',
            'session-123',
            'user-456',
            'machine-789'
        )
        
        # Manually set last_seen to old time
        instance.last_seen = time.time() - 7200  # 2 hours ago
        
        cleaned = self.tracker.cleanup_stale_instances(max_age_seconds=3600)
        
        self.assertEqual(cleaned, 1)
        self.assertIsNone(self.tracker.get_metrics(instance.instance_id))
    
    def test_average_duration_calculation(self):
        """Test average duration calculation."""
        instance = self.tracker.get_or_create_instance(
            SubagentType.CLAUDE_CODE,
            '1.0.0',
            'session-123',
            'user-456',
            'machine-789'
        )
        
        durations = [100.0, 200.0, 300.0]
        for duration in durations:
            self.tracker.record_request(
                instance.instance_id,
                duration_ms=duration,
                success=True
            )
        
        metrics = self.tracker.get_metrics(instance.instance_id)
        expected_avg = sum(durations) / len(durations)
        
        self.assertAlmostEqual(metrics.avg_duration_ms, expected_avg)


class TestGenerateInstanceId(unittest.TestCase):
    """Test cases for generate_instance_id function."""
    
    def test_unique_ids(self):
        """Test that different parameters generate different IDs."""
        id1 = generate_instance_id(
            SubagentType.CLAUDE_CODE,
            '1.0.0',
            'session-1',
            'user-1',
            'machine-1'
        )
        
        id2 = generate_instance_id(
            SubagentType.CLAUDE_CODE,
            '1.0.0',
            'session-2',
            'user-1',
            'machine-1'
        )
        
        self.assertNotEqual(id1, id2)
    
    def test_same_parameters_same_id(self):
        """Test that same parameters generate same ID."""
        id1 = generate_instance_id(
            SubagentType.CLAUDE_CODE,
            '1.0.0',
            'session-1',
            'user-1',
            'machine-1'
        )
        
        id2 = generate_instance_id(
            SubagentType.CLAUDE_CODE,
            '1.0.0',
            'session-1',
            'user-1',
            'machine-1'
        )
        
        self.assertEqual(id1, id2)
    
    def test_id_length(self):
        """Test that generated IDs have correct length."""
        instance_id = generate_instance_id(
            SubagentType.CLAUDE_CODE,
            '1.0.0',
            'session-1',
            'user-1',
            'machine-1'
        )
        
        self.assertEqual(len(instance_id), 16)  # First 16 chars of SHA256


if __name__ == '__main__':
    unittest.main()
