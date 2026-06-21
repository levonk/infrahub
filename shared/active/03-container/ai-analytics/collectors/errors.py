"""
Error handling and graceful degradation for AI analytics collectors.

This module provides comprehensive error handling, graceful degradation
strategies, and recovery mechanisms for collectors.
"""

import logging
import time
import asyncio
from typing import Optional, Callable, Dict, Any, List
from dataclasses import dataclass, field
from enum import Enum
from datetime import datetime, timedelta
from functools import wraps


class ErrorSeverity(Enum):
    """Severity levels for errors."""
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    CRITICAL = "critical"


class ErrorCategory(Enum):
    """Categories of errors that can occur."""
    NETWORK = "network"
    TIMEOUT = "timeout"
    VALIDATION = "validation"
    RESOURCE = "resource"
    CONFIGURATION = "configuration"
    DEPENDENCY = "dependency"
    UNKNOWN = "unknown"


@dataclass
class ErrorContext:
    """Context information about an error."""
    error_type: str
    error_message: str
    severity: ErrorSeverity
    category: ErrorCategory
    timestamp: datetime = field(default_factory=datetime.utcnow)
    stack_trace: Optional[str] = None
    metadata: Dict[str, Any] = field(default_factory=dict)
    recoverable: bool = True


class CollectorError(Exception):
    """Base exception for collector errors."""
    
    def __init__(
        self, 
        message: str, 
        severity: ErrorSeverity = ErrorSeverity.MEDIUM,
        category: ErrorCategory = ErrorCategory.UNKNOWN,
        recoverable: bool = True
    ):
        super().__init__(message)
        self.severity = severity
        self.category = category
        self.recoverable = recoverable
        self.timestamp = datetime.utcnow()


class NetworkError(CollectorError):
    """Network-related errors."""
    
    def __init__(self, message: str, recoverable: bool = True):
        super().__init__(message, ErrorSeverity.HIGH, ErrorCategory.NETWORK, recoverable)


class TimeoutError(CollectorError):
    """Timeout-related errors."""
    
    def __init__(self, message: str, recoverable: bool = True):
        super().__init__(message, ErrorSeverity.MEDIUM, ErrorCategory.TIMEOUT, recoverable)


class ValidationError(CollectorError):
    """Validation-related errors."""
    
    def __init__(self, message: str, recoverable: bool = False):
        super().__init__(message, ErrorSeverity.LOW, ErrorCategory.VALIDATION, recoverable)


class ResourceError(CollectorError):
    """Resource-related errors (memory, disk, etc.)."""
    
    def __init__(self, message: str, recoverable: bool = True):
        super().__init__(message, ErrorSeverity.CRITICAL, ErrorCategory.RESOURCE, recoverable)


class DegradedModeError(CollectorError):
    """Error indicating collector is in degraded mode."""
    
    def __init__(self, message: str = "Collector is in degraded mode"):
        super().__init__(message, ErrorSeverity.LOW, ErrorCategory.DEPENDENCY, True)


class ErrorHandler:
    """
    Centralized error handler for collectors.
    
    Provides error logging, categorization, and recovery strategies.
    """
    
    def __init__(self, log_level: str = "INFO"):
        self.logger = logging.getLogger(__name__)
        self.logger.setLevel(getattr(logging, log_level.upper()))
        
        self._error_history: List[ErrorContext] = []
        self._max_history_size = 1000
        self._error_counts: Dict[str, int] = {}
        self._recovery_strategies: Dict[ErrorCategory, Callable] = {}
        
        # Register default recovery strategies
        self._register_default_strategies()
    
    def _register_default_strategies(self):
        """Register default recovery strategies for error categories."""
        self._recovery_strategies[ErrorCategory.NETWORK] = self._recover_network
        self._recovery_strategies[ErrorCategory.TIMEOUT] = self._recover_timeout
        self._recovery_strategies[ErrorCategory.RESOURCE] = self._recover_resource
        self._recovery_strategies[ErrorCategory.DEPENDENCY] = self._recover_dependency
    
    def handle_error(
        self, 
        error: Exception, 
        context: Optional[Dict[str, Any]] = None
    ) -> ErrorContext:
        """
        Handle an error with logging and recovery attempt.
        
        Args:
            error: The exception that occurred
            context: Additional context about the error
            
        Returns:
            ErrorContext with information about the error
        """
        # Determine error category and severity
        if isinstance(error, CollectorError):
            category = error.category
            severity = error.severity
            recoverable = error.recoverable
        else:
            category = ErrorCategory.UNKNOWN
            severity = ErrorSeverity.MEDIUM
            recoverable = True
        
        # Create error context
        error_context = ErrorContext(
            error_type=type(error).__name__,
            error_message=str(error),
            severity=severity,
            category=category,
            stack_trace=self._get_stack_trace(error),
            metadata=context or {},
            recoverable=recoverable
        )
        
        # Log error
        self._log_error(error_context)
        
        # Track error statistics
        self._track_error(error_context)
        
        # Attempt recovery if recoverable
        if recoverable and category in self._recovery_strategies:
            try:
                self._recovery_strategies[category](error_context)
            except Exception as recovery_error:
                self.logger.error(f"Recovery failed: {recovery_error}")
        
        return error_context
    
    def _log_error(self, error_context: ErrorContext):
        """Log error with appropriate level."""
        log_message = f"[{error_context.category.value}] {error_context.error_message}"
        
        if error_context.severity == ErrorSeverity.CRITICAL:
            self.logger.critical(log_message, exc_info=True)
        elif error_context.severity == ErrorSeverity.HIGH:
            self.logger.error(log_message, exc_info=True)
        elif error_context.severity == ErrorSeverity.MEDIUM:
            self.logger.warning(log_message)
        else:
            self.logger.info(log_message)
    
    def _track_error(self, error_context: ErrorContext):
        """Track error statistics."""
        # Add to history
        self._error_history.append(error_context)
        if len(self._error_history) > self._max_history_size:
            self._error_history.pop(0)
        
        # Update counts
        error_key = f"{error_context.category.value}:{error_context.error_type}"
        self._error_counts[error_key] = self._error_counts.get(error_key, 0) + 1
    
    def _get_stack_trace(self, error: Exception) -> str:
        """Get stack trace from exception."""
        import traceback
        return ''.join(traceback.format_exception(type(error), error, error.__traceback__))
    
    def _recover_network(self, error_context: ErrorContext):
        """Recovery strategy for network errors."""
        self.logger.info("Attempting network recovery: retry with backoff")
        # In real implementation, this would trigger connection reset/retry logic
    
    def _recover_timeout(self, error_context: ErrorContext):
        """Recovery strategy for timeout errors."""
        self.logger.info("Attempting timeout recovery: increase timeout or retry")
        # In real implementation, this would adjust timeout parameters
    
    def _recover_resource(self, error_context: ErrorContext):
        """Recovery strategy for resource errors."""
        self.logger.warning("Resource error - may require manual intervention")
        # Resource errors often require manual intervention
    
    def _recover_dependency(self, error_context: ErrorContext):
        """Recovery strategy for dependency errors."""
        self.logger.info("Attempting dependency recovery: enter degraded mode")
        # This would trigger degraded mode activation
    
    def get_error_stats(self) -> Dict[str, Any]:
        """Get error statistics."""
        total_errors = len(self._error_history)
        if total_errors == 0:
            return {'total_errors': 0}
        
        # Count by category
        category_counts = {}
        for context in self._error_history:
            category_counts[context.category.value] = category_counts.get(context.category.value, 0) + 1
        
        # Count by severity
        severity_counts = {}
        for context in self._error_history:
            severity_counts[context.severity.value] = severity_counts.get(context.severity.value, 0) + 1
        
        return {
            'total_errors': total_errors,
            'by_category': category_counts,
            'by_severity': severity_counts,
            'recent_errors': [
                {
                    'type': ctx.error_type,
                    'message': ctx.error_message,
                    'timestamp': ctx.timestamp.isoformat()
                }
                for ctx in self._error_history[-10:]
            ]
        }
    
    def clear_history(self):
        """Clear error history."""
        self._error_history.clear()
        self._error_counts.clear()


class GracefulDegradationManager:
    """
    Manages graceful degradation for collectors.
    
    Automatically enters degraded mode when error rates exceed thresholds
    and attempts recovery when conditions improve.
    """
    
    def __init__(
        self,
        error_rate_threshold: float = 0.1,
        latency_threshold_ms: float = 100.0,
        recovery_check_interval_seconds: float = 30.0
    ):
        self.error_rate_threshold = error_rate_threshold
        self.latency_threshold_ms = latency_threshold_ms
        self.recovery_check_interval_seconds = recovery_check_interval_seconds
        
        self._degraded_mode = False
        self._degraded_since: Optional[datetime] = None
        self._recovery_task: Optional[asyncio.Task] = None
        self._error_handler: Optional[ErrorHandler] = None
        
    def set_error_handler(self, error_handler: ErrorHandler):
        """Set the error handler to monitor."""
        self._error_handler = error_handler
    
    def check_degradation(self, error_rate: float, avg_latency_ms: float) -> bool:
        """
        Check if degradation should be activated.
        
        Args:
            error_rate: Current error rate (0.0 to 1.0)
            avg_latency_ms: Current average latency in milliseconds
            
        Returns:
            True if degradation should be activated
        """
        should_degrade = False
        
        if error_rate > self.error_rate_threshold:
            should_degrade = True
        
        if avg_latency_ms > self.latency_threshold_ms:
            should_degrade = True
        
        if should_degrade and not self._degraded_mode:
            self._enter_degraded_mode()
        
        return should_degrade
    
    def _enter_degraded_mode(self):
        """Enter degraded mode."""
        self._degraded_mode = True
        self._degraded_since = datetime.utcnow()
        print("Entering degraded mode")
        
        # Start recovery task
        if self._recovery_task is None or self._recovery_task.done():
            self._recovery_task = asyncio.create_task(self._recovery_loop())
    
    def _exit_degraded_mode(self):
        """Exit degraded mode."""
        self._degraded_mode = False
        self._degraded_since = None
        print("Exiting degraded mode")
    
    def is_degraded(self) -> bool:
        """Check if currently in degraded mode."""
        return self._degraded_mode
    
    async def _recovery_loop(self):
        """Periodic recovery check loop."""
        while self._degraded_mode:
            await asyncio.sleep(self.recovery_check_interval_seconds)
            
            if self._should_attempt_recovery():
                if self._attempt_recovery():
                    self._exit_degraded_mode()
                    break
    
    def _should_attempt_recovery(self) -> bool:
        """Check if recovery should be attempted."""
        if not self._error_handler:
            return True
        
        stats = self._error_handler.get_error_stats()
        recent_errors = stats.get('recent_errors', [])
        
        # Check if recent error rate is acceptable
        if len(recent_errors) < 5:  # Few recent errors
            return True
        
        return False
    
    def _attempt_recovery(self) -> bool:
        """Attempt to recover from degraded mode."""
        print("Attempting recovery from degraded mode")
        # In real implementation, this would run health checks
        # For now, we'll just return True
        return True
    
    def get_status(self) -> Dict[str, Any]:
        """Get current degradation status."""
        return {
            'degraded_mode': self._degraded_mode,
            'degraded_since': self._degraded_since.isoformat() if self._degraded_since else None,
            'thresholds': {
                'error_rate_threshold': self.error_rate_threshold,
                'latency_threshold_ms': self.latency_threshold_ms
            }
        }


def handle_errors(error_handler: ErrorHandler):
    """
    Decorator for handling errors in functions.
    
    Args:
        error_handler: The error handler to use
        
    Returns:
        Decorated function that handles errors
    """
    def decorator(func):
        @wraps(func)
        async def async_wrapper(*args, **kwargs):
            try:
                return await func(*args, **kwargs)
            except Exception as e:
                error_handler.handle_error(e, {'function': func.__name__})
                raise
        
        @wraps(func)
        def sync_wrapper(*args, **kwargs):
            try:
                return func(*args, **kwargs)
            except Exception as e:
                error_handler.handle_error(e, {'function': func.__name__})
                raise
        
        if asyncio.iscoroutinefunction(func):
            return async_wrapper
        else:
            return sync_wrapper
    
    return decorator
