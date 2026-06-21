# AI Analytics Pipeline - API Reference

## Base URL

```
http://localhost:8080/api/v1
```

## Authentication

For single-tenant deployments, authentication is optional. For multi-tenant deployments, use API keys or JWT tokens.

## Endpoints

### Health Check

```http
GET /health
```

Returns the health status of the API service.

**Response:**
```json
{
  "status": "healthy",
  "version": "1.0.0",
  "timestamp": "2025-01-20T00:00:00Z"
}
```

### Analytics Query

```http
GET /analytics/query
```

Query analytics data with filters and aggregations.

**Query Parameters:**
- `client` (optional): Filter by client ID
- `ai_client` (optional): Filter by AI client
- `team` (optional): Filter by team
- `provider` (optional): Filter by provider
- `model` (optional): Filter by model
- `start_date` (required): Start date (ISO 8601)
- `end_date` (required): End date (ISO 8601)
- `granularity` (optional): Time granularity (hour, day, week, month)
- `dimensions` (optional): Comma-separated list of dimensions

**Response:**
```json
{
  "data": [
    {
      "client": "acme-corp",
      "ai_client": "claude-code",
      "requests": 1000,
      "tokens": 50000,
      "cost": 10.50
    }
  ],
  "total": 1000,
  "page": 1,
  "pages": 10
}
```

### Aggregation

```http
GET /analytics/aggregation
```

Get aggregated metrics across dimensions.

**Query Parameters:**
- `metric` (required): Metric to aggregate (requests, tokens, cost)
- `dimension` (required): Dimension to aggregate by
- `start_date` (required): Start date (ISO 8601)
- `end_date` (required): End date (ISO 8601)

**Response:**
```json
{
  "data": [
    {
      "dimension_value": "claude-code",
      "metric_value": 50000
    }
  ]
}
```

### Real-time Events

```http
GET /analytics/events
```

Stream real-time analytics events via Server-Sent Events (SSE).

**Query Parameters:**
- `client` (optional): Filter by client ID
- `ai_client` (optional): Filter by AI client

**Response:** SSE stream of event objects.

## Error Responses

All endpoints may return error responses:

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid request parameters",
    "details": {
      "field": "start_date",
      "reason": "Required field is missing"
    }
  }
}
```

## Rate Limiting

API requests are rate-limited to 100 requests per minute per IP address by default.

## CORS

CORS is enabled for the following origins in development:
- http://localhost:3000
- http://localhost:8080

Configure additional origins in the API configuration.
