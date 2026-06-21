"""
Provider identification and tracking for AI analytics pipeline.

This module implements downstream tracking to capture which AI providers
and models are being used, including model version tracking and historical changes.
"""

import re
import hashlib
import time
from dataclasses import dataclass, field
from typing import Dict, Any, Optional, List, Tuple
from enum import Enum


class ProviderType(Enum):
    """Supported AI provider types."""
    ANTHROPIC = "anthropic"
    OPENAI = "openai"
    GOOGLE = "google"
    MICROSOFT = "microsoft"
    AWS = "aws"
    OPENROUTER = "openrouter"
    COHERE = "cohere"
    HUGGINGFACE = "huggingface"
    CUSTOM = "custom"
    UNKNOWN = "unknown"


class ModelCategory(Enum):
    """Model categories for analytics."""
    CHAT = "chat"
    COMPLETION = "completion"
    EMBEDDING = "embedding"
    IMAGE = "image"
    AUDIO = "audio"
    CODE = "code"
    CUSTOM = "custom"


@dataclass
class ProviderInfo:
    """Provider information extracted from requests/responses."""
    provider_type: ProviderType
    provider_name: str
    api_endpoint: Optional[str] = None
    region: Optional[str] = None
    version: Optional[str] = None
    timestamp: float = field(default_factory=time.time)


@dataclass
class ModelInfo:
    """Model information extracted from requests/responses."""
    model_id: str
    model_name: str
    provider_type: ProviderType
    model_category: ModelCategory
    version: Optional[str] = None
    context_window: Optional[int] = None
    max_tokens: Optional[int] = None
    pricing_input: Optional[float] = None
    pricing_output: Optional[float] = None
    timestamp: float = field(default_factory=time.time)


@dataclass
class ModelVersion:
    """Model version tracking for historical analysis."""
    model_id: str
    version: str
    first_seen: float = field(default_factory=time.time)
    last_seen: float = field(default_factory=time.time)
    request_count: int = 0
    total_tokens: int = 0
    total_cost: float = 0.0
    is_deprecated: bool = False
    deprecation_date: Optional[str] = None
    replacement_model: Optional[str] = None


@dataclass
class ProviderMetrics:
    """Performance metrics for providers."""
    provider_type: ProviderType
    total_requests: int = 0
    successful_requests: int = 0
    failed_requests: int = 0
    avg_latency_ms: float = 0.0
    total_tokens: int = 0
    total_cost: float = 0.0
    model_count: int = 0
    most_used_model: Optional[str] = None


class ProviderDetector:
    """
    Detect AI provider from request/response patterns.
    
    Uses signature matching on headers, URLs, and response patterns
    to identify which AI provider is being used.
    """
    
    def __init__(self):
        # Anthropic patterns
        self._anthropic_patterns = [
            (r'anthropic\.com', 'url'),
            (r'x-api-key', 'headers'),
            (r'anthropic-version', 'headers'),
            (r'claude-3', 'model'),
        ]
        
        # OpenAI patterns
        self._openai_patterns = [
            (r'openai\.com', 'url'),
            (r'api\.openai\.com', 'url'),
            (r'authorization: bearer', 'headers'),
            (r'gpt-', 'model'),
        ]
        
        # Google patterns
        self._google_patterns = [
            (r'googleapis\.com', 'url'),
            (r'generativelanguage\.googleapis\.com', 'url'),
            (r'x-goog-api-key', 'headers'),
            (r'gemini-', 'model'),
        ]
        
        # Microsoft patterns
        self._microsoft_patterns = [
            (r'azure\.com', 'url'),
            (r'openai\.azure\.com', 'url'),
            (r'api-key', 'headers'),
            (r'deployment-id', 'headers'),
        ]
        
        # AWS patterns
        self._aws_patterns = [
            (r'aws\.amazon\.com', 'url'),
            (r'bedrock\.amazonaws\.com', 'url'),
            (r'x-amz-', 'headers'),
        ]
        
        # OpenRouter patterns
        self._openrouter_patterns = [
            (r'openrouter\.ai', 'url'),
            (r'openrouter\.net', 'url'),
            (r'authorization: bearer', 'headers'),
        ]
        
        # Cohere patterns
        self._cohere_patterns = [
            (r'cohere\.ai', 'url'),
            (r'api\.cohere\.ai', 'url'),
            (r'cohere-', 'model'),
        ]
        
        # HuggingFace patterns
        self._huggingface_patterns = [
            (r'huggingface\.co', 'url'),
            (r'api\.huggingface\.co', 'url'),
            (r'hf-', 'model'),
        ]
    
    def detect_provider(
        self,
        headers: Dict[str, str],
        url: Optional[str] = None,
        model_name: Optional[str] = None,
        response_body: Optional[Dict[str, Any]] = None
    ) -> Tuple[ProviderType, Optional[str]]:
        """
        Detect provider from request/response metadata.
        
        Args:
            headers: HTTP request/response headers
            url: Request URL
            model_name: Model name from request
            response_body: Response body for pattern matching
            
        Returns:
            Tuple of (ProviderType, version)
        """
        # Check Anthropic
        anthropic_match, version = self._check_patterns(
            self._anthropic_patterns, headers, url, model_name, response_body
        )
        if anthropic_match:
            return ProviderType.ANTHROPIC, version
        
        # Check OpenAI
        openai_match, version = self._check_patterns(
            self._openai_patterns, headers, url, model_name, response_body
        )
        if openai_match:
            return ProviderType.OPENAI, version
        
        # Check Google
        google_match, version = self._check_patterns(
            self._google_patterns, headers, url, model_name, response_body
        )
        if google_match:
            return ProviderType.GOOGLE, version
        
        # Check Microsoft
        microsoft_match, version = self._check_patterns(
            self._microsoft_patterns, headers, url, model_name, response_body
        )
        if microsoft_match:
            return ProviderType.MICROSOFT, version
        
        # Check AWS
        aws_match, version = self._check_patterns(
            self._aws_patterns, headers, url, model_name, response_body
        )
        if aws_match:
            return ProviderType.AWS, version
        
        # Check OpenRouter
        openrouter_match, version = self._check_patterns(
            self._openrouter_patterns, headers, url, model_name, response_body
        )
        if openrouter_match:
            return ProviderType.OPENROUTER, version
        
        # Check Cohere
        cohere_match, version = self._check_patterns(
            self._cohere_patterns, headers, url, model_name, response_body
        )
        if cohere_match:
            return ProviderType.COHERE, version
        
        # Check HuggingFace
        huggingface_match, version = self._check_patterns(
            self._huggingface_patterns, headers, url, model_name, response_body
        )
        if huggingface_match:
            return ProviderType.HUGGINGFACE, version
        
        return ProviderType.UNKNOWN, None
    
    def _check_patterns(
        self,
        patterns: List[Tuple[str, str]],
        headers: Dict[str, str],
        url: Optional[str],
        model_name: Optional[str],
        response_body: Optional[Dict[str, Any]]
    ) -> Tuple[bool, Optional[str]]:
        """Check if any pattern matches."""
        for pattern, location in patterns:
            if location == 'url' and url:
                if re.search(pattern, url, re.IGNORECASE):
                    version = self._extract_version(url)
                    return True, version
            elif location == 'headers':
                for header_name, header_value in headers.items():
                    if re.search(pattern, header_name.lower(), re.IGNORECASE):
                        version = self._extract_version(header_value)
                        return True, version
            elif location == 'model' and model_name:
                if re.search(pattern, model_name, re.IGNORECASE):
                    version = self._extract_version(model_name)
                    return True, version
            elif location == 'body' and response_body:
                body_str = str(response_body)
                if re.search(pattern, body_str, re.IGNORECASE):
                    version = self._extract_version(body_str)
                    return True, version
        return False, None
    
    def _extract_version(self, text: str) -> Optional[str]:
        """Extract version string from text."""
        version_match = re.search(r'(\d+\.\d+\.\d+)', text)
        return version_match.group(1) if version_match else None


class ModelDetector:
    """
    Detect model information from requests/responses.
    
    Parses model names, versions, and capabilities from API calls.
    """
    
    def __init__(self):
        # Anthropic model patterns
        self._anthropic_models = {
            'claude-3-opus': ModelCategory.CHAT,
            'claude-3-sonnet': ModelCategory.CHAT,
            'claude-3-haiku': ModelCategory.CHAT,
            'claude-2': ModelCategory.CHAT,
            'claude-instant': ModelCategory.CHAT,
        }
        
        # OpenAI model patterns
        self._openai_models = {
            'gpt-4': ModelCategory.CHAT,
            'gpt-3.5': ModelCategory.CHAT,
            'gpt-4-turbo': ModelCategory.CHAT,
            'text-embedding': ModelCategory.EMBEDDING,
            'dall-e': ModelCategory.IMAGE,
            'whisper': ModelCategory.AUDIO,
        }
        
        # Google model patterns
        self._google_models = {
            'gemini-pro': ModelCategory.CHAT,
            'gemini-ultra': ModelCategory.CHAT,
            'palm': ModelCategory.CHAT,
            'embedding': ModelCategory.EMBEDDING,
        }
        
        # Generic model patterns
        self._generic_patterns = [
            r'([a-z]+-?[0-9.]+)',  # Standard model naming
            r'(gpt-[0-9.]+)',      # OpenAI style
            r'(claude-[0-9.]+)',   # Anthropic style
            r'(gemini-[a-z]+)',    # Google style
        ]
    
    def detect_model(
        self,
        model_name: str,
        provider_type: ProviderType = ProviderType.UNKNOWN
    ) -> Optional[ModelInfo]:
        """
        Detect model information from model name.
        
        Args:
            model_name: Model name from request
            provider_type: Detected provider type
            
        Returns:
            ModelInfo object if detected, None otherwise
        """
        if not model_name:
            return None
        
        # Try provider-specific models first
        if provider_type == ProviderType.ANTHROPIC:
            category = self._anthropic_models.get(model_name.lower())
            if category:
                return ModelInfo(
                    model_id=self._generate_model_id(model_name, provider_type),
                    model_name=model_name,
                    provider_type=provider_type,
                    model_category=category
                )
        
        elif provider_type == ProviderType.OPENAI:
            category = self._openai_models.get(model_name.lower())
            if category:
                return ModelInfo(
                    model_id=self._generate_model_id(model_name, provider_type),
                    model_name=model_name,
                    provider_type=provider_type,
                    model_category=category
                )
        
        elif provider_type == ProviderType.GOOGLE:
            category = self._google_models.get(model_name.lower())
            if category:
                return ModelInfo(
                    model_id=self._generate_model_id(model_name, provider_type),
                    model_name=model_name,
                    provider_type=provider_type,
                    model_category=category
                )
        
        # Try generic patterns
        category = self._categorize_model_generic(model_name)
        if category:
            return ModelInfo(
                model_id=self._generate_model_id(model_name, provider_type),
                model_name=model_name,
                provider_type=provider_type,
                model_category=category
            )
        
        return None
    
    def _categorize_model_generic(self, model_name: str) -> Optional[ModelCategory]:
        """Categorize model based on name patterns."""
        model_name_lower = model_name.lower()
        
        if any(keyword in model_name_lower for keyword in ['embedding', 'embed']):
            return ModelCategory.EMBEDDING
        elif any(keyword in model_name_lower for keyword in ['image', 'dall-e', 'stable-diffusion']):
            return ModelCategory.IMAGE
        elif any(keyword in model_name_lower for keyword in ['audio', 'whisper', 'tts']):
            return ModelCategory.AUDIO
        elif any(keyword in model_name_lower for keyword in ['code', 'codex']):
            return ModelCategory.CODE
        elif any(keyword in model_name_lower for keyword in ['gpt', 'claude', 'gemini', 'chat']):
            return ModelCategory.CHAT
        else:
            return ModelCategory.CUSTOM
    
    def _generate_model_id(self, model_name: str, provider_type: ProviderType) -> str:
        """Generate unique model ID."""
        model_data = f"{provider_type.value}_{model_name}"
        return hashlib.sha256(model_data.encode()).hexdigest()[:16]


class ModelVersionTracker:
    """
    Track model versions and historical changes.
    
    Maintains version history and tracks model deprecations.
    """
    
    def __init__(self):
        self._versions: Dict[str, ModelVersion] = {}
        self._model_history: Dict[str, List[ModelVersion]] = {}
    
    def record_model_usage(
        self,
        model_id: str,
        version: str,
        tokens: int = 0,
        cost: float = 0.0
    ):
        """
        Record model usage for version tracking.
        
        Args:
            model_id: Model identifier
            version: Model version
            tokens: Number of tokens used
            cost: Cost of the request
        """
        version_key = f"{model_id}_{version}"
        
        if version_key not in self._versions:
            self._versions[version_key] = ModelVersion(
                model_id=model_id,
                version=version
            )
            
            if model_id not in self._model_history:
                self._model_history[model_id] = []
            self._model_history[model_id].append(self._versions[version_key])
        
        model_version = self._versions[version_key]
        model_version.last_seen = time.time()
        model_version.request_count += 1
        model_version.total_tokens += tokens
        model_version.total_cost += cost
    
    def mark_deprecated(
        self,
        model_id: str,
        version: str,
        replacement_model: Optional[str] = None
    ):
        """
        Mark a model version as deprecated.
        
        Args:
            model_id: Model identifier
            version: Model version to deprecate
            replacement_model: Replacement model ID
        """
        version_key = f"{model_id}_{version}"
        if version_key in self._versions:
            self._versions[version_key].is_deprecated = True
            self._versions[version_key].deprecation_date = time.strftime('%Y-%m-%d')
            self._versions[version_key].replacement_model = replacement_model
    
    def get_version_history(self, model_id: str) -> List[ModelVersion]:
        """Get version history for a model."""
        return self._model_history.get(model_id, [])
    
    def get_current_version(self, model_id: str) -> Optional[ModelVersion]:
        """Get the most recent (non-deprecated) version of a model."""
        versions = self._model_history.get(model_id, [])
        non_deprecated = [v for v in versions if not v.is_deprecated]
        
        if non_deprecated:
            return max(non_deprecated, key=lambda v: v.last_seen)
        return None
    
    def get_deprecated_models(self) -> List[ModelVersion]:
        """Get all deprecated model versions."""
        return [v for v in self._versions.values() if v.is_deprecated]


class ProviderMetricsCollector:
    """
    Collect provider performance metrics.
    
    Tracks request counts, latency, costs, and usage patterns per provider.
    """
    
    def __init__(self):
        self._metrics: Dict[ProviderType, ProviderMetrics] = {}
        self._model_usage: Dict[str, int] = {}
    
    def record_request(
        self,
        provider_type: ProviderType,
        model_id: str,
        latency_ms: float,
        success: bool,
        tokens: int = 0,
        cost: float = 0.0
    ):
        """
        Record a request for provider metrics.
        
        Args:
            provider_type: Type of provider
            model_id: Model identifier
            latency_ms: Request latency
            success: Whether request was successful
            tokens: Number of tokens
            cost: Cost of the request
        """
        if provider_type not in self._metrics:
            self._metrics[provider_type] = ProviderMetrics(
                provider_type=provider_type
            )
        
        metrics = self._metrics[provider_type]
        metrics.total_requests += 1
        if success:
            metrics.successful_requests += 1
        else:
            metrics.failed_requests += 1
        
        # Update average latency
        total_latency = metrics.avg_latency_ms * (metrics.total_requests - 1)
        metrics.avg_latency_ms = (total_latency + latency_ms) / metrics.total_requests
        
        metrics.total_tokens += tokens
        metrics.total_cost += cost
        
        # Track model usage
        self._model_usage[model_id] = self._model_usage.get(model_id, 0) + 1
        
        # Update most used model
        if not hasattr(metrics, '_model_counts'):
            metrics._model_counts = {}
        metrics._model_counts[model_id] = metrics._model_counts.get(model_id, 0) + 1
        metrics.most_used_model = max(
            metrics._model_counts.items(),
            key=lambda x: x[1]
        )[0] if metrics._model_counts else None
    
    def get_metrics(self, provider_type: ProviderType) -> Optional[ProviderMetrics]:
        """Get metrics for a provider."""
        return self._metrics.get(provider_type)
    
    def get_all_metrics(self) -> Dict[ProviderType, ProviderMetrics]:
        """Get metrics for all providers."""
        return self._metrics.copy()
