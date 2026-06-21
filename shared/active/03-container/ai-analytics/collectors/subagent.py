"""
Subagent identification and tracking for AI analytics pipeline.

This module implements subagent attribution to track which AI agents
(Claude Code, Codex, Pi, Devin, etc.) are making requests, along with
tool-level analytics to capture tool usage patterns, result sizes, and costs.
"""

import re
import hashlib
import time
from dataclasses import dataclass, field
from typing import Dict, Any, Optional, List, Tuple
from enum import Enum


class SubagentType(Enum):
    """Supported subagent types."""
    CLAUDE_CODE = "claude_code"
    CODEX = "codex"
    PI = "pi"
    DEVIN = "devin"
    CUSTOM = "custom"
    UNKNOWN = "unknown"


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
class SubagentInstance:
    """Subagent instance tracking for session analysis."""
    instance_id: str
    subagent_type: SubagentType
    version: Optional[str] = None
    session_id: Optional[str] = None
    user_id: Optional[str] = None
    machine_id: Optional[str] = None
    first_seen: float = field(default_factory=time.time)
    last_seen: float = field(default_factory=time.time)
    request_count: int = 0
    total_tokens: int = 0
    total_cost: float = 0.0


@dataclass
class ToolCall:
    """Individual tool call analytics."""
    tool_name: str
    tool_category: ToolCategory
    subagent_type: SubagentType
    instance_id: str
    timestamp: float = field(default_factory=time.time)
    duration_ms: float = 0.0
    success: bool = True
    error_message: Optional[str] = None
    input_size: int = 0
    output_size: int = 0
    cost: float = 0.0
    parameters: Dict[str, Any] = field(default_factory=dict)


@dataclass
class SubagentMetrics:
    """Performance metrics for subagent instances."""
    instance_id: str
    subagent_type: SubagentType
    total_requests: int = 0
    successful_requests: int = 0
    failed_requests: int = 0
    avg_duration_ms: float = 0.0
    total_tokens: int = 0
    total_cost: float = 0.0
    tool_calls_count: int = 0
    unique_tools_used: int = 0
    most_used_tool: Optional[str] = None


class SubagentDetector:
    """
    Detect subagent type from request patterns and headers.
    
    Uses signature matching on user agents, headers, and request patterns
    to identify which AI agent is making the request.
    """
    
    def __init__(self):
        # Claude Code signatures
        self._claude_code_patterns = [
            (r'claude-code', 'user-agent'),
            (r'anthropic-claude', 'user-agent'),
            (r'x-claude-code', 'headers'),
            (r'claude-sdk', 'user-agent'),
        ]
        
        # Codex signatures
        self._codex_patterns = [
            (r'openai-codex', 'user-agent'),
            (r'codex-sdk', 'user-agent'),
            (r'x-codex', 'headers'),
        ]
        
        # Pi signatures
        self._pi_patterns = [
            (r'pi-ai', 'user-agent'),
            (r'pi-assistant', 'user-agent'),
            (r'x-pi', 'headers'),
        ]
        
        # Devin signatures
        self._devin_patterns = [
            (r'devin-ai', 'user-agent'),
            (r'devin-assistant', 'user-agent'),
            (r'x-devin', 'headers'),
        ]
        
    def detect_subagent(
        self,
        headers: Dict[str, str],
        user_agent: Optional[str] = None,
        request_body: Optional[Dict[str, Any]] = None
    ) -> Tuple[SubagentType, Optional[str]]:
        """
        Detect subagent type from request metadata.
        
        Args:
            headers: HTTP request headers
            user_agent: User-Agent string
            request_body: Request body for pattern matching
            
        Returns:
            Tuple of (SubagentType, version)
        """
        # Check Claude Code
        claude_match, version = self._check_patterns(
            self._claude_code_patterns, headers, user_agent, request_body
        )
        if claude_match:
            return SubagentType.CLAUDE_CODE, version
        
        # Check Codex
        codex_match, version = self._check_patterns(
            self._codex_patterns, headers, user_agent, request_body
        )
        if codex_match:
            return SubagentType.CODEX, version
        
        # Check Pi
        pi_match, version = self._check_patterns(
            self._pi_patterns, headers, user_agent, request_body
        )
        if pi_match:
            return SubagentType.PI, version
        
        # Check Devin
        devin_match, version = self._check_patterns(
            self._devin_patterns, headers, user_agent, request_body
        )
        if devin_match:
            return SubagentType.DEVIN, version
        
        return SubagentType.UNKNOWN, None
    
    def _check_patterns(
        self,
        patterns: List[Tuple[str, str]],
        headers: Dict[str, str],
        user_agent: Optional[str],
        request_body: Optional[Dict[str, Any]]
    ) -> Tuple[bool, Optional[str]]:
        """Check if any pattern matches."""
        for pattern, location in patterns:
            if location == 'user-agent' and user_agent:
                if re.search(pattern, user_agent, re.IGNORECASE):
                    version = self._extract_version(user_agent)
                    return True, version
            elif location == 'headers':
                for header_name, header_value in headers.items():
                    if re.search(pattern, header_name.lower(), re.IGNORECASE):
                        version = self._extract_version(header_value)
                        return True, version
            elif location == 'body' and request_body:
                body_str = str(request_body)
                if re.search(pattern, body_str, re.IGNORECASE):
                    version = self._extract_version(body_str)
                    return True, version
        return False, None
    
    def _extract_version(self, text: str) -> Optional[str]:
        """Extract version string from text."""
        version_match = re.search(r'(\d+\.\d+\.\d+)', text)
        return version_match.group(1) if version_match else None


class ToolExtractor:
    """
    Extract tool calls from request/response bodies.
    
    Parses different agent-specific formats to extract tool usage information.
    """
    
    def __init__(self):
        # Claude Code tool patterns
        self._claude_tool_patterns = [
            r'tool_calls?:\s*\[(.*?)\]',
            r'function_call?:\s*\{(.*?)\}',
            r'tool_use?:\s*\{(.*?)\}',
        ]
        
        # Generic tool patterns
        self._generic_tool_patterns = [
            r'"tool":\s*"([^"]+)"',
            r'"function":\s*"([^"]+)"',
            r'"name":\s*"([^"]+)"',
        ]
    
    def extract_tool_calls(
        self,
        request_body: Optional[Dict[str, Any]] = None,
        response_body: Optional[Dict[str, Any]] = None,
        subagent_type: SubagentType = SubagentType.UNKNOWN
    ) -> List[ToolCall]:
        """
        Extract tool calls from request/response bodies.
        
        Args:
            request_body: Request body dictionary
            response_body: Response body dictionary
            subagent_type: Type of subagent for specific parsing
            
        Returns:
            List of ToolCall objects
        """
        tool_calls = []
        
        # Try request body first
        if request_body:
            tool_calls.extend(self._extract_from_body(request_body, subagent_type))
        
        # Try response body
        if response_body:
            tool_calls.extend(self._extract_from_body(response_body, subagent_type))
        
        return tool_calls
    
    def _extract_from_body(
        self,
        body: Dict[str, Any],
        subagent_type: SubagentType
    ) -> List[ToolCall]:
        """Extract tool calls from a body dictionary."""
        tool_calls = []
        body_str = str(body)
        
        # Use agent-specific patterns
        if subagent_type == SubagentType.CLAUDE_CODE:
            patterns = self._claude_tool_patterns
        else:
            patterns = self._generic_tool_patterns
        
        for pattern in patterns:
            matches = re.findall(pattern, body_str, re.DOTALL)
            for match in matches:
                tool_name = self._parse_tool_name(match)
                category = self._categorize_tool(tool_name)
                
                tool_call = ToolCall(
                    tool_name=tool_name,
                    tool_category=category,
                    subagent_type=subagent_type,
                    instance_id="",  # Will be set by caller
                )
                tool_calls.append(tool_call)
        
        return tool_calls
    
    def _parse_tool_name(self, match: str) -> str:
        """Parse tool name from pattern match."""
        # Clean up the match string
        tool_name = match.strip().strip('"').strip("'")
        return tool_name if tool_name else "unknown_tool"
    
    def _categorize_tool(self, tool_name: str) -> ToolCategory:
        """Categorize tool based on name patterns."""
        tool_name_lower = tool_name.lower()
        
        if any(keyword in tool_name_lower for keyword in ['file', 'read', 'write', 'edit']):
            return ToolCategory.FILE
        elif any(keyword in tool_name_lower for keyword in ['web', 'search', 'fetch', 'browse']):
            return ToolCategory.WEB
        elif any(keyword in tool_name_lower for keyword in ['database', 'db', 'sql', 'query']):
            return ToolCategory.DATABASE
        elif any(keyword in tool_name_lower for keyword in ['api', 'http', 'request']):
            return ToolCategory.API
        elif any(keyword in tool_name_lower for keyword in ['code', 'execute', 'run']):
            return ToolCategory.CODE
        elif any(keyword in tool_name_lower for keyword in ['shell', 'command', 'bash', 'terminal']):
            return ToolCategory.SHELL
        else:
            return ToolCategory.CUSTOM


class SubagentTracker:
    """
    Track subagent instances and calculate performance metrics.
    
    Maintains state for active subagent instances and calculates
    performance metrics over time.
    """
    
    def __init__(self):
        self._instances: Dict[str, SubagentInstance] = {}
        self._metrics: Dict[str, SubagentMetrics] = {}
    
    def get_or_create_instance(
        self,
        subagent_type: SubagentType,
        version: Optional[str],
        session_id: Optional[str],
        user_id: Optional[str],
        machine_id: Optional[str]
    ) -> SubagentInstance:
        """
        Get existing instance or create new one.
        
        Args:
            subagent_type: Type of subagent
            version: Subagent version
            session_id: Session identifier
            user_id: User identifier
            machine_id: Machine identifier
            
        Returns:
            SubagentInstance object
        """
        # Generate instance ID
        instance_data = f"{subagent_type.value}_{version}_{session_id}_{user_id}_{machine_id}"
        instance_id = hashlib.sha256(instance_data.encode()).hexdigest()[:16]
        
        if instance_id not in self._instances:
            instance = SubagentInstance(
                instance_id=instance_id,
                subagent_type=subagent_type,
                version=version,
                session_id=session_id,
                user_id=user_id,
                machine_id=machine_id,
            )
            self._instances[instance_id] = instance
            self._metrics[instance_id] = SubagentMetrics(
                instance_id=instance_id,
                subagent_type=subagent_type,
            )
        else:
            instance = self._instances[instance_id]
            instance.last_seen = time.time()
        
        return instance
    
    def record_request(
        self,
        instance_id: str,
        duration_ms: float,
        success: bool,
        tokens: int = 0,
        cost: float = 0.0
    ):
        """Record a request for an instance."""
        if instance_id not in self._instances:
            return
        
        instance = self._instances[instance_id]
        metrics = self._metrics[instance_id]
        
        instance.request_count += 1
        instance.total_tokens += tokens
        instance.total_cost += cost
        
        metrics.total_requests += 1
        if success:
            metrics.successful_requests += 1
        else:
            metrics.failed_requests += 1
        
        # Update average duration
        total_duration = metrics.avg_duration_ms * (metrics.total_requests - 1)
        metrics.avg_duration_ms = (total_duration + duration_ms) / metrics.total_requests
    
    def record_tool_call(
        self,
        instance_id: str,
        tool_call: ToolCall
    ):
        """Record a tool call for an instance."""
        if instance_id not in self._metrics:
            return
        
        metrics = self._metrics[instance_id]
        metrics.tool_calls_count += 1
        
        # Track unique tools
        if not hasattr(metrics, '_unique_tools'):
            metrics._unique_tools = set()
        metrics._unique_tools.add(tool_call.tool_name)
        metrics.unique_tools_used = len(metrics._unique_tools)
        
        # Track most used tool
        if not hasattr(metrics, '_tool_counts'):
            metrics._tool_counts = {}
        metrics._tool_counts[tool_call.tool_name] = \
            metrics._tool_counts.get(tool_call.tool_name, 0) + 1
        
        metrics.most_used_tool = max(
            metrics._tool_counts.items(),
            key=lambda x: x[1]
        )[0] if metrics._tool_counts else None
    
    def get_metrics(self, instance_id: str) -> Optional[SubagentMetrics]:
        """Get metrics for an instance."""
        return self._metrics.get(instance_id)
    
    def cleanup_stale_instances(self, max_age_seconds: float = 3600):
        """Remove instances that haven't been seen recently."""
        current_time = time.time()
        stale_ids = [
            instance_id for instance_id, instance in self._instances.items()
            if current_time - instance.last_seen > max_age_seconds
        ]
        
        for instance_id in stale_ids:
            del self._instances[instance_id]
            del self._metrics[instance_id]
        
        return len(stale_ids)


def generate_instance_id(
    subagent_type: SubagentType,
    version: Optional[str],
    session_id: Optional[str],
    user_id: Optional[str],
    machine_id: Optional[str]
) -> str:
    """
    Generate unique instance ID for subagent tracking.
    
    Args:
        subagent_type: Type of subagent
        version: Subagent version
        session_id: Session identifier
        user_id: User identifier
        machine_id: Machine identifier
        
    Returns:
        Unique instance ID
    """
    instance_data = f"{subagent_type.value}_{version}_{session_id}_{user_id}_{machine_id}"
    return hashlib.sha256(instance_data.encode()).hexdigest()[:16]
