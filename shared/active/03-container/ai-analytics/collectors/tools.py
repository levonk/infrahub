"""
Tool usage analytics for AI analytics pipeline.

This module implements tool-level analytics to capture tool usage patterns,
result sizes, costs, and invocation frequency across different subagents.
"""

import time
import hashlib
from dataclasses import dataclass, field
from typing import Dict, Any, Optional, List, Tuple
from enum import Enum
from collections import defaultdict


class ToolCategory(Enum):
    """Tool categories for analytics."""
    FILE = "file"
    WEB = "web"
    DATABASE = "database"
    API = "api"
    CODE = "code"
    SHELL = "shell"
    CUSTOM = "custom"


@dataclass
class ToolUsagePattern:
    """Tool usage pattern analysis."""
    tool_name: str
    tool_category: ToolCategory
    total_calls: int = 0
    successful_calls: int = 0
    failed_calls: int = 0
    avg_duration_ms: float = 0.0
    avg_input_size: int = 0
    avg_output_size: int = 0
    total_cost: float = 0.0
    first_used: float = field(default_factory=time.time)
    last_used: float = field(default_factory=time.time)
    subagent_usage: Dict[str, int] = field(default_factory=dict)


@dataclass
class ToolCostBreakdown:
    """Cost breakdown for tool usage."""
    tool_name: str
    tool_category: ToolCategory
    input_cost: float = 0.0
    output_cost: float = 0.0
    execution_cost: float = 0.0
    total_cost: float = 0.0
    cost_per_call: float = 0.0
    call_count: int = 0


@dataclass
class ToolInvocationFrequency:
    """Tool invocation frequency over time."""
    tool_name: str
    hourly_frequency: Dict[int, int] = field(default_factory=dict)
    daily_frequency: Dict[int, int] = field(default_factory=dict)
    peak_hour: Optional[int] = None
    peak_day: Optional[int] = None
    total_invocations: int = 0


class ToolUsageAnalyzer:
    """
    Analyze tool usage patterns across subagents and sessions.
    
    Tracks tool call frequency, success rates, performance metrics,
    and cost analysis for each tool.
    """
    
    def __init__(self):
        self._patterns: Dict[str, ToolUsagePattern] = {}
        self._costs: Dict[str, ToolCostBreakdown] = {}
        self._frequencies: Dict[str, ToolInvocationFrequency] = {}
        self._tool_categories: Dict[str, ToolCategory] = {}
    
    def record_tool_call(
        self,
        tool_name: str,
        tool_category: ToolCategory,
        duration_ms: float,
        success: bool,
        input_size: int,
        output_size: int,
        cost: float,
        subagent_type: str,
        timestamp: Optional[float] = None
    ):
        """
        Record a tool call for analysis.
        
        Args:
            tool_name: Name of the tool
            tool_category: Category of the tool
            duration_ms: Duration of the tool call
            success: Whether the call was successful
            input_size: Size of input in bytes
            output_size: Size of output in bytes
            cost: Cost of the tool call
            subagent_type: Type of subagent that made the call
            timestamp: Timestamp of the call (defaults to now)
        """
        if timestamp is None:
            timestamp = time.time()
        
        # Initialize if needed
        if tool_name not in self._patterns:
            self._patterns[tool_name] = ToolUsagePattern(
                tool_name=tool_name,
                tool_category=tool_category
            )
            self._costs[tool_name] = ToolCostBreakdown(
                tool_name=tool_name,
                tool_category=tool_category
            )
            self._frequencies[tool_name] = ToolInvocationFrequency(
                tool_name=tool_name
            )
            self._tool_categories[tool_name] = tool_category
        
        # Update pattern
        pattern = self._patterns[tool_name]
        pattern.total_calls += 1
        if success:
            pattern.successful_calls += 1
        else:
            pattern.failed_calls += 1
        
        # Update average duration
        total_duration = pattern.avg_duration_ms * (pattern.total_calls - 1)
        pattern.avg_duration_ms = (total_duration + duration_ms) / pattern.total_calls
        
        # Update average sizes
        total_input = pattern.avg_input_size * (pattern.total_calls - 1)
        pattern.avg_input_size = (total_input + input_size) / pattern.total_calls
        
        total_output = pattern.avg_output_size * (pattern.total_calls - 1)
        pattern.avg_output_size = (total_output + output_size) / pattern.total_calls
        
        pattern.total_cost += cost
        pattern.last_used = timestamp
        
        # Update subagent usage
        pattern.subagent_usage[subagent_type] = \
            pattern.subagent_usage.get(subagent_type, 0) + 1
        
        # Update cost breakdown
        cost_breakdown = self._costs[tool_name]
        cost_breakdown.total_cost += cost
        cost_breakdown.call_count += 1
        cost_breakdown.cost_per_call = cost_breakdown.total_cost / cost_breakdown.call_count
        
        # Simple cost allocation (can be refined)
        cost_breakdown.input_cost += cost * 0.3
        cost_breakdown.output_cost += cost * 0.5
        cost_breakdown.execution_cost += cost * 0.2
        
        # Update frequency
        frequency = self._frequencies[tool_name]
        frequency.total_invocations += 1
        
        hour = int(timestamp // 3600) % 24
        day = int(timestamp // 86400)
        
        frequency.hourly_frequency[hour] = frequency.hourly_frequency.get(hour, 0) + 1
        frequency.daily_frequency[day] = frequency.daily_frequency.get(day, 0) + 1
        
        # Update peaks
        if frequency.peak_hour is None or frequency.hourly_frequency[hour] > frequency.hourly_frequency.get(frequency.peak_hour, 0):
            frequency.peak_hour = hour
        
        if frequency.peak_day is None or frequency.daily_frequency[day] > frequency.daily_frequency.get(frequency.peak_day, 0):
            frequency.peak_day = day
    
    def get_pattern(self, tool_name: str) -> Optional[ToolUsagePattern]:
        """Get usage pattern for a tool."""
        return self._patterns.get(tool_name)
    
    def get_cost_breakdown(self, tool_name: str) -> Optional[ToolCostBreakdown]:
        """Get cost breakdown for a tool."""
        return self._costs.get(tool_name)
    
    def get_frequency(self, tool_name: str) -> Optional[ToolInvocationFrequency]:
        """Get invocation frequency for a tool."""
        return self._frequencies.get(tool_name)
    
    def get_all_patterns(self) -> List[ToolUsagePattern]:
        """Get all tool usage patterns."""
        return list(self._patterns.values())
    
    def get_tools_by_category(self, category: ToolCategory) -> List[str]:
        """Get all tools in a specific category."""
        return [
            tool_name for tool_name, tool_cat in self._tool_categories.items()
            if tool_cat == category
        ]
    
    def get_most_used_tools(self, limit: int = 10) -> List[Tuple[str, int]]:
        """Get most used tools by call count."""
        sorted_tools = sorted(
            self._patterns.items(),
            key=lambda x: x[1].total_calls,
            reverse=True
        )
        return [(tool_name, pattern.total_calls) for tool_name, pattern in sorted_tools[:limit]]
    
    def get_most_expensive_tools(self, limit: int = 10) -> List[Tuple[str, float]]:
        """Get most expensive tools by total cost."""
        sorted_tools = sorted(
            self._costs.items(),
            key=lambda x: x[1].total_cost,
            reverse=True
        )
        return [(tool_name, cost.total_cost) for tool_name, cost in sorted_tools[:limit]]
    
    def get_slowest_tools(self, limit: int = 10) -> List[Tuple[str, float]]:
        """Get slowest tools by average duration."""
        sorted_tools = sorted(
            self._patterns.items(),
            key=lambda x: x[1].avg_duration_ms,
            reverse=True
        )
        return [(tool_name, pattern.avg_duration_ms) for tool_name, pattern in sorted_tools[:limit]]
    
    def get_failure_rates(self) -> Dict[str, float]:
        """Get failure rates for all tools."""
        failure_rates = {}
        for tool_name, pattern in self._patterns.items():
            if pattern.total_calls > 0:
                failure_rates[tool_name] = pattern.failed_calls / pattern.total_calls
        return failure_rates


class ToolResultSizeAnalyzer:
    """
    Analyze tool result sizes for optimization insights.
    
    Tracks input/output sizes, identifies unusually large results,
    and provides recommendations for optimization.
    """
    
    def __init__(self):
        self._size_history: Dict[str, List[Tuple[float, int, int]]] = {}  # tool_name -> [(timestamp, input_size, output_size)]
        self._size_stats: Dict[str, Dict[str, float]] = {}
    
    def record_result_size(
        self,
        tool_name: str,
        input_size: int,
        output_size: int,
        timestamp: Optional[float] = None
    ):
        """
        Record result size for a tool call.
        
        Args:
            tool_name: Name of the tool
            input_size: Size of input in bytes
            output_size: Size of output in bytes
            timestamp: Timestamp of the call
        """
        if timestamp is None:
            timestamp = time.time()
        
        if tool_name not in self._size_history:
            self._size_history[tool_name] = []
        
        self._size_history[tool_name].append((timestamp, input_size, output_size))
        
        # Keep only last 1000 records per tool
        if len(self._size_history[tool_name]) > 1000:
            self._size_history[tool_name] = self._size_history[tool_name][-1000:]
        
        # Update statistics
        self._update_size_stats(tool_name)
    
    def _update_size_stats(self, tool_name: str):
        """Update size statistics for a tool."""
        history = self._size_history[tool_name]
        if not history:
            return
        
        input_sizes = [record[1] for record in history]
        output_sizes = [record[2] for record in history]
        
        self._size_stats[tool_name] = {
            'avg_input_size': sum(input_sizes) / len(input_sizes),
            'max_input_size': max(input_sizes),
            'min_input_size': min(input_sizes),
            'avg_output_size': sum(output_sizes) / len(output_sizes),
            'max_output_size': max(output_sizes),
            'min_output_size': min(output_sizes),
            'total_records': len(history),
        }
    
    def get_size_stats(self, tool_name: str) -> Optional[Dict[str, float]]:
        """Get size statistics for a tool."""
        return self._size_stats.get(tool_name)
    
    def get_large_results(self, threshold_bytes: int = 1024 * 1024) -> List[Tuple[str, int]]:
        """Get tools with unusually large results."""
        large_results = []
        for tool_name, stats in self._size_stats.items():
            if stats.get('max_output_size', 0) > threshold_bytes:
                large_results.append((tool_name, stats['max_output_size']))
        
        return sorted(large_results, key=lambda x: x[1], reverse=True)
    
    def get_size_trends(self, tool_name: str) -> Optional[Dict[str, List[float]]]:
        """Get size trends over time for a tool."""
        if tool_name not in self._size_history:
            return None
        
        history = self._size_history[tool_name]
        # Group by hour
        hourly_data = defaultdict(lambda: {'input': [], 'output': []})
        
        for timestamp, input_size, output_size in history:
            hour = int(timestamp // 3600)
            hourly_data[hour]['input'].append(input_size)
            hourly_data[hour]['output'].append(output_size)
        
        # Calculate hourly averages
        trends = {
            'timestamps': sorted(hourly_data.keys()),
            'avg_input_sizes': [],
            'avg_output_sizes': [],
        }
        
        for hour in trends['timestamps']:
            data = hourly_data[hour]
            trends['avg_input_sizes'].append(sum(data['input']) / len(data['input']))
            trends['avg_output_sizes'].append(sum(data['output']) / len(data['output']))
        
        return trends


class ToolCostCalculator:
    """
    Calculate costs for tool usage based on various pricing models.
    
    Supports different pricing models for different subagents and tools.
    """
    
    def __init__(self):
        # Default cost per 1K tokens (can be overridden per tool)
        self._default_input_cost_per_1k = 0.001  # $0.001 per 1K input tokens
        self._default_output_cost_per_1k = 0.002  # $0.002 per 1K output tokens
        
        # Tool-specific cost multipliers
        self._tool_cost_multipliers: Dict[str, float] = {
            'web_search': 1.0,
            'web_fetch': 0.5,
            'file_read': 0.1,
            'file_write': 0.2,
            'database_query': 0.8,
            'api_call': 0.6,
            'code_execution': 1.5,
            'shell_command': 1.2,
        }
        
        # Subagent-specific cost multipliers
        self._subagent_cost_multipliers: Dict[str, float] = {
            'claude_code': 1.0,
            'codex': 0.8,
            'pi': 0.9,
            'devin': 1.1,
        }
    
    def calculate_cost(
        self,
        tool_name: str,
        subagent_type: str,
        input_tokens: int = 0,
        output_tokens: int = 0,
        input_size: int = 0,
        output_size: int = 0,
        duration_ms: float = 0.0
    ) -> float:
        """
        Calculate cost for a tool call.
        
        Args:
            tool_name: Name of the tool
            subagent_type: Type of subagent
            input_tokens: Number of input tokens
            output_tokens: Number of output tokens
            input_size: Size of input in bytes
            output_size: Size of output in bytes
            duration_ms: Duration of the call
            
        Returns:
            Calculated cost in dollars
        """
        # Get multipliers
        tool_multiplier = self._tool_cost_multipliers.get(tool_name, 1.0)
        subagent_multiplier = self._subagent_cost_multipliers.get(subagent_type, 1.0)
        
        # Calculate token-based cost
        token_cost = (
            (input_tokens / 1000) * self._default_input_cost_per_1k +
            (output_tokens / 1000) * self._default_output_cost_per_1k
        )
        
        # Calculate size-based cost (fallback if no tokens)
        size_cost = (
            (input_size / 1024) * 0.0001 +  # $0.0001 per KB input
            (output_size / 1024) * 0.0002   # $0.0002 per KB output
        )
        
        # Calculate time-based cost
        time_cost = (duration_ms / 1000) * 0.0001  # $0.0001 per second
        
        # Use token cost if available, otherwise size cost
        base_cost = token_cost if input_tokens + output_tokens > 0 else size_cost
        base_cost += time_cost
        
        # Apply multipliers
        total_cost = base_cost * tool_multiplier * subagent_multiplier
        
        return total_cost
    
    def set_tool_cost_multiplier(self, tool_name: str, multiplier: float):
        """Set cost multiplier for a specific tool."""
        self._tool_cost_multipliers[tool_name] = multiplier
    
    def set_subagent_cost_multiplier(self, subagent_type: str, multiplier: float):
        """Set cost multiplier for a specific subagent."""
        self._subagent_cost_multipliers[subagent_type] = multiplier
    
    def set_default_costs(self, input_cost_per_1k: float, output_cost_per_1k: float):
        """Set default token costs."""
        self._default_input_cost_per_1k = input_cost_per_1k
        self._default_output_cost_per_1k = output_cost_per_1k


def measure_result_size(data: Any) -> int:
    """
    Measure the size of data in bytes.
    
    Args:
        data: Data to measure (string, dict, list, etc.)
        
    Returns:
        Size in bytes
    """
    if isinstance(data, str):
        return len(data.encode('utf-8'))
    elif isinstance(data, (dict, list)):
        return len(str(data).encode('utf-8'))
    elif isinstance(data, bytes):
        return len(data)
    else:
        return len(str(data).encode('utf-8'))
