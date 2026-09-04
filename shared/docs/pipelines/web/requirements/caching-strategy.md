# Caching Strategy: Varnish vs Squid

**Date:** 2026-08-10
**Status:** Decision — Varnish
**Related:** `shared/docs/pipelines/web/complete-web-proxy-chain.mmd`

## Decision

Use **Varnish Cache** as the caching layer (Layer 4) in the web proxy chain.

## Background

The original V2 design (`04-web-proxy-flow.md`) already made this decision
and documented the rationale. This file preserves and extends that analysis
for the revised chain design.

## Rationale

### Why not Squid?

Squid was initially considered but has a critical limitation: modern versions
do not support the `stale-while-revalidate` Cache-Control directive. This
feature is essential for a performant user experience — it serves stale
content immediately while refreshing in the background.

Squid does support a `stale-if-error` equivalent via its proprietary
`max-stale` directive, but the lack of `stale-while-revalidate` was
considered a significant drawback.

### Why Varnish?

1. **Full support for modern caching**: Varnish provides first-class,
   native support for both `stale-while-revalidate` and `stale-if-error`
   via the `beresp.grace` VCL parameter.

2. **Purpose-built HTTP accelerator**: Varnish is designed specifically for
   high-performance reverse proxy caching, making it a specialist tool for
   this layer.

3. **VCL flexibility**: The Varnish Configuration Language offers
   unparalleled control over caching logic, enabling fine-grained
   manipulation of requests and responses.

## Stale-While-Revalidate (built-in)

Varnish handles this via `beresp.grace`:

```vcl
sub vcl_backend_response {
    # Serve stale for up to 10 seconds while revalidating
    set beresp.grace = 10s;
    set beresp.ttl = 1h;
}

sub vcl_hit {
    if (obj.ttl >= 0s) {
        return (deliver);
    }
    if (obj.ttl + obj.grace > 0s) {
        # Object is stale but within grace — deliver and background fetch
        return (deliver);
    }
    return (miss);
}
```

## Stale-If-Error (VCL workaround)

Open-source Varnish doesn't have a dedicated `stale-if-error` vmod (that's
Varnish Enterprise's `vmod_stale`). However, the `beresp.grace` mechanism
covers most use cases: if the backend returns an error, Varnish will serve
the stale object if it's within the grace period.

```vcl
sub vcl_backend_error {
    # If backend errors, try to serve stale from cache
    if (stale.exists) {
        return (deliver);
    }
}
```

This is slightly less robust than the Enterprise vmod but sufficient for a
home/small-business proxy.

## Forward Proxy Consideration

Varnish is typically used as a reverse proxy cache (in front of a specific
backend). Using it as a forward proxy cache (caching arbitrary upstream
sites) requires custom VCL that dynamically sets the backend based on the
request's Host header.

```vcl
sub vcl_recv {
    # Dynamic backend — set based on Host header
    set req.backend_hint = default.backend();
    # Pass through non-cacheable requests
    if (req.method != "GET" && req.method != "HEAD") {
        return (pass);
    }
}
```

This is a known pattern for Varnish-as-forward-proxy and is documented in
the Varnish community.

## Configuration

- **Image**: `varnish:latest` (upstream Docker Hub)
- **Port**: 6081 (HTTP cache, also used for bypass access)
- **VCL file**: Custom VCL at `shared/active/03-container/services/proxy/varnish/default.vcl`
- **tmpfs**: `/var/lib/varnish:exec` (required by Varnish for shared memory)
- **Cache size**: Configurable via `VARNISH_SIZE` env var (default: 1G)
- **Backend**: Gost egress multiplexer (for cache misses)

## Alternatives Considered

| Cache | stale-while-revalidate | stale-if-error | Forward proxy | Verdict |
|-------|----------------------|-----------------|---------------|---------|
| Varnish | Yes (beresp.grace) | Yes (grace workaround) | Custom VCL | **Selected** |
| Squid | No | Yes (max-stale) | Native | Rejected (no SWR) |
| Nginx | Yes (proxy_cache) | Yes (proxy_cache_use_stale) | Native | Rejected (less flexible than Varnish for caching logic) |
