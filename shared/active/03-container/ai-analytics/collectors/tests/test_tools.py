"""
Unit tests for tool usage analytics.
"""

import unittest
import time
import sys
from pathlib import Path
from unittest.mock import Mock, patch

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from tools import (
    ToolCategory,
    ToolUsageAnalyzer,
    ToolResultSizeAnalyzer,
    ToolCostCalculator,
    ToolUsagePattern,
    ToolCostBreakdown,
    ToolInvocationFrequency,
    measure_result_size
)


class TestToolUsageAnalyzer(unittest.TestCase):
    """Test cases for ToolUsageAnalyzer."""
    
    def setUp(self):
        """Set up test fixtures."""
        self.analyzer = ToolUsageAnalyzer()
    
    def test_record_tool_call(self):
        """Test recording a tool call."""
        self.analyzer.record_tool_call(
            tool_name='file_read',
            tool_category=ToolCategory.FILE,
            duration_ms=100.0,
            success=True,
            input_size=1024,
            output_size=2048,
            cost=0.01,
            subagent_type='claude_code'
        )
        
        pattern = self.analyzer.get_pattern('file_read')
        
        self.assertIsNotNone(pattern)
        self.assertEqual(pattern.tool_name, 'file_read')
        self.assertEqual(pattern.total_calls, 1)
        self.assertEqual(pattern.successful_calls, 1)
        self.assertEqual(pattern.failed_calls, 0)
    
    def test_record_multiple_calls(self):
        """Test recording multiple tool calls."""
        for i in range(5):
            self.analyzer.record_tool_call(
                tool_name='file_read',
                tool_category=ToolCategory.FILE,
                duration_ms=100.0 + i * 10,
                success=i < 4,  # Last one fails
                input_size=1024,
                output_size=2048,
                cost=0.01,
                subagent_type='claude_code'
            )
        
        pattern = self.analyzer.get_pattern('file_read')
        
        self.assertEqual(pattern.total_calls, 5)
        self.assertEqual(pattern.successful_calls, 4)
        self.assertEqual(pattern.failed_calls, 1)
    
    def test_average_duration_calculation(self):
        """Test average duration calculation."""
        durations = [100.0, 200.0, 300.0]
        for duration in durations:
            self.analyzer.record_tool_call(
                tool_name='file_read',
                tool_category=ToolCategory.FILE,
                duration_ms=duration,
                success=True,
                input_size=1024,
                output_size=2048,
                cost=0.01,
                subagent_type='claude_code'
            )
        
        pattern = self.analyzer.get_pattern('file_read')
        expected_avg = sum(durations) / len(durations)
        
        self.assertAlmostEqual(pattern.avg_duration_ms, expected_avg)
    
    def test_cost_breakdown(self):
        """Test cost breakdown calculation."""
        self.analyzer.record_tool_call(
            tool_name='file_read',
            tool_category=ToolCategory.FILE,
            duration_ms=100.0,
            success=True,
            input_size=1024,
            output_size=2048,
            cost=0.01,
            subagent_type='claude_code'
        )
        
        cost_breakdown = self.analyzer.get_cost_breakdown('file_read')
        
        self.assertIsNotNone(cost_breakdown)
        self.assertEqual(cost_breakdown.total_cost, 0.01)
        self.assertEqual(cost_breakdown.call_count, 1)
        self.assertAlmostEqual(cost_breakdown.cost_per_call, 0.01)
    
    def test_invocation_frequency(self):
        """Test invocation frequency tracking."""
        # Record calls at different times
        base_time = time.time()
        for i in range(5):
            self.analyzer.record_tool_call(
                tool_name='file_read',
                tool_category=ToolCategory.FILE,
                duration_ms=100.0,
                success=True,
                input_size=1024,
                output_size=2048,
                cost=0.01,
                subagent_type='claude_code',
                timestamp=base_time + i * 3600  # 1 hour apart
            )
        
        frequency = self.analyzer.get_frequency('file_read')
        
        self.assertIsNotNone(frequency)
        self.assertEqual(frequency.total_invocations, 5)
        self.assertEqual(len(frequency.hourly_frequency), 5)
    
    def test_get_most_used_tools(self):
        """Test getting most used tools."""
        # Record calls for different tools
        for i in range(10):
            self.analyzer.record_tool_call(
                tool_name='file_read',
                tool_category=ToolCategory.FILE,
                duration_ms=100.0,
                success=True,
                input_size=1024,
                output_size=2048,
                cost=0.01,
                subagent_type='claude_code'
            )
        
        for i in range(5):
            self.analyzer.record_tool_call(
                tool_name='web_search',
                tool_category=ToolCategory.WEB,
                duration_ms=200.0,
                success=True,
                input_size=512,
                output_size=1024,
                cost=0.02,
                subagent_type='claude_code'
            )
        
        most_used = self.analyzer.get_most_used_tools(limit=5)
        
        self.assertEqual(len(most_used), 2)
        self.assertEqual(most_used[0][0], 'file_read')
        self.assertEqual(most_used[0][1], 10)
    
    def test_get_failure_rates(self):
        """Test getting failure rates."""
        # Record some successful and failed calls
        for i in range(8):
            self.analyzer.record_tool_call(
                tool_name='file_read',
                tool_category=ToolCategory.FILE,
                duration_ms=100.0,
                success=i < 6,  # 2 failures
                input_size=1024,
                output_size=2048,
                cost=0.01,
                subagent_type='claude_code'
            )
        
        failure_rates = self.analyzer.get_failure_rates()
        
        self.assertIn('file_read', failure_rates)
        self.assertAlmostEqual(failure_rates['file_read'], 2/8, places=2)
    
    def test_subagent_usage_tracking(self):
        """Test subagent usage tracking."""
        self.analyzer.record_tool_call(
            tool_name='file_read',
            tool_category=ToolCategory.FILE,
            duration_ms=100.0,
            success=True,
            input_size=1024,
            output_size=2048,
            cost=0.01,
            subagent_type='claude_code'
        )
        
        self.analyzer.record_tool_call(
            tool_name='file_read',
            tool_category=ToolCategory.FILE,
            duration_ms=100.0,
            success=True,
            input_size=1024,
            output_size=2048,
            cost=0.01,
            subagent_type='codex'
        )
        
        pattern = self.analyzer.get_pattern('file_read')
        
        self.assertEqual(pattern.subagent_usage['claude_code'], 1)
        self.assertEqual(pattern.subagent_usage['codex'], 1)


class TestToolResultSizeAnalyzer(unittest.TestCase):
    """Test cases for ToolResultSizeAnalyzer."""
    
    def setUp(self):
        """Set up test fixtures."""
        self.analyzer = ToolResultSizeAnalyzer()
    
    def test_record_result_size(self):
        """Test recording result size."""
        self.analyzer.record_result_size(
            tool_name='file_read',
            input_size=1024,
            output_size=2048
        )
        
        stats = self.analyzer.get_size_stats('file_read')
        
        self.assertIsNotNone(stats)
        self.assertEqual(stats['avg_input_size'], 1024)
        self.assertEqual(stats['avg_output_size'], 2048)
    
    def test_size_statistics(self):
        """Test size statistics calculation."""
        sizes = [(1024, 2048), (2048, 4096), (512, 1024)]
        for input_size, output_size in sizes:
            self.analyzer.record_result_size(
                tool_name='file_read',
                input_size=input_size,
                output_size=output_size
            )
        
        stats = self.analyzer.get_size_stats('file_read')
        
        expected_avg_input = sum(s[0] for s in sizes) / len(sizes)
        expected_avg_output = sum(s[1] for s in sizes) / len(sizes)
        
        self.assertAlmostEqual(stats['avg_input_size'], expected_avg_input)
        self.assertAlmostEqual(stats['avg_output_size'], expected_avg_output)
        self.assertEqual(stats['max_input_size'], 2048)
        self.assertEqual(stats['max_output_size'], 4096)
    
    def test_get_large_results(self):
        """Test getting tools with large results."""
        self.analyzer.record_result_size(
            tool_name='file_read',
            input_size=1024,
            output_size=1024 * 1024  # 1MB
        )
        
        self.analyzer.record_result_size(
            tool_name='web_search',
            input_size=512,
            output_size=512  # Small
        )
        
        large_results = self.analyzer.get_large_results(threshold_bytes=1024 * 512)
        
        self.assertEqual(len(large_results), 1)
        self.assertEqual(large_results[0][0], 'file_read')
    
    def test_size_trends(self):
        """Test size trends over time."""
        base_time = time.time()
        for i in range(5):
            self.analyzer.record_result_size(
                tool_name='file_read',
                input_size=1024 + i * 100,
                output_size=2048 + i * 200,
                timestamp=base_time + i * 3600
            )
        
        trends = self.analyzer.get_size_trends('file_read')
        
        self.assertIsNotNone(trends)
        self.assertEqual(len(trends['timestamps']), 5)
        self.assertEqual(len(trends['avg_input_sizes']), 5)
        self.assertEqual(len(trends['avg_output_sizes']), 5)


class TestToolCostCalculator(unittest.TestCase):
    """Test cases for ToolCostCalculator."""
    
    def setUp(self):
        """Set up test fixtures."""
        self.calculator = ToolCostCalculator()
    
    def test_calculate_cost_with_tokens(self):
        """Test cost calculation with tokens."""
        cost = self.calculator.calculate_cost(
            tool_name='file_read',
            subagent_type='claude_code',
            input_tokens=1000,
            output_tokens=2000
        )
        
        # Expected: (1000/1000 * 0.001) + (2000/1000 * 0.002) = 0.001 + 0.004 = 0.005
        # With tool multiplier 0.1 for file_read: 0.005 * 0.1 = 0.0005
        expected_cost = 0.0005
        self.assertAlmostEqual(cost, expected_cost, places=4)
    
    def test_calculate_cost_with_size(self):
        """Test cost calculation with size (no tokens)."""
        cost = self.calculator.calculate_cost(
            tool_name='file_read',
            subagent_type='claude_code',
            input_size=1024,  # 1KB
            output_size=2048,  # 2KB
            duration_ms=1000   # 1 second
        )
        
        # Expected: size cost + time cost
        # size: (1024/1024 * 0.0001) + (2048/1024 * 0.0002) = 0.0001 + 0.0004 = 0.0005
        # time: (1000/1000 * 0.0001) = 0.0001
        # total: 0.0006
        # With tool multiplier 0.1 for file_read: 0.0006 * 0.1 = 0.00006
        expected_cost = 0.00006
        self.assertAlmostEqual(cost, expected_cost, places=5)
    
    def test_tool_cost_multiplier(self):
        """Test tool-specific cost multiplier."""
        self.calculator.set_tool_cost_multiplier('file_read', 2.0)
        
        cost = self.calculator.calculate_cost(
            tool_name='file_read',
            subagent_type='claude_code',
            input_tokens=1000,
            output_tokens=2000
        )
        
        # Should be 2x the normal cost
        # Base: 0.005, with default tool multiplier 0.1: 0.0005
        # With custom tool multiplier 2.0: 0.005 * 2.0 = 0.01
        expected_cost = 0.01
        self.assertAlmostEqual(cost, expected_cost, places=4)
    
    def test_subagent_cost_multiplier(self):
        """Test subagent-specific cost multiplier."""
        self.calculator.set_subagent_cost_multiplier('claude_code', 1.5)
        
        cost = self.calculator.calculate_cost(
            tool_name='file_read',
            subagent_type='claude_code',
            input_tokens=1000,
            output_tokens=2000
        )
        
        # Should be 1.5x the normal cost
        # Base: 0.005, with tool multiplier 0.1: 0.0005
        # With subagent multiplier 1.5: 0.0005 * 1.5 = 0.00075
        expected_cost = 0.00075
        self.assertAlmostEqual(cost, expected_cost, places=4)
    
    def test_combined_multipliers(self):
        """Test combined tool and subagent multipliers."""
        self.calculator.set_tool_cost_multiplier('file_read', 2.0)
        self.calculator.set_subagent_cost_multiplier('claude_code', 1.5)
        
        cost = self.calculator.calculate_cost(
            tool_name='file_read',
            subagent_type='claude_code',
            input_tokens=1000,
            output_tokens=2000
        )
        
        # Should be 2.0 * 1.5 = 3x the normal cost
        # Base: 0.005, with custom tool multiplier 2.0: 0.005 * 2.0 = 0.01
        # With subagent multiplier 1.5: 0.01 * 1.5 = 0.015
        expected_cost = 0.015
        self.assertAlmostEqual(cost, expected_cost, places=4)


class TestMeasureResultSize(unittest.TestCase):
    """Test cases for measure_result_size function."""
    
    def test_measure_string_size(self):
        """Test measuring string size."""
        text = "Hello, World!"
        size = measure_result_size(text)
        
        self.assertEqual(size, len(text.encode('utf-8')))
    
    def test_measure_dict_size(self):
        """Test measuring dict size."""
        data = {'key': 'value', 'number': 42}
        size = measure_result_size(data)
        
        self.assertGreater(size, 0)
    
    def test_measure_list_size(self):
        """Test measuring list size."""
        data = [1, 2, 3, 'four', 'five']
        size = measure_result_size(data)
        
        self.assertGreater(size, 0)
    
    def test_measure_bytes_size(self):
        """Test measuring bytes size."""
        data = b'Hello, World!'
        size = measure_result_size(data)
        
        self.assertEqual(size, len(data))
    
    def test_measure_unknown_type(self):
        """Test measuring unknown type (converts to string)."""
        data = 42
        size = measure_result_size(data)
        
        self.assertGreater(size, 0)


if __name__ == '__main__':
    unittest.main()
