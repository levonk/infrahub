# DNS Testing Strategy

**Date:** 2026-09-04
**Status:** Proposed — not yet implemented
**Related:** `complete-dns-chain.md`, `dnssec-gap-and-unbound-fix.md`, `cross-cluster-dns-failover.md`

## The Problem

The DNS stack has 12 tiers, DNSSEC validation, cross-cluster failover,
and multiple upstream providers. Currently, all verification is manual
(`dig` commands in deployment plans). There is no automated test suite
that verifies:

1. DNSSEC validation works (bogus responses are dropped)
2. Tier failover works (killing tier 1 falls back to tier 2, etc.)
3. Trust anchor rollover works (shifting time doesn't break validation)
4. Cross-cluster failover works (cloud DNS down → local cluster picks up)
5. Blocklist changes propagate to all clusters

## Reference: desec-stack e2e tests

desec-stack (`github.com/desec-io/desec-stack`) has a full pytest-based
e2e test suite under `test/e2e2/`. Key patterns we adopt:

### 1. Docker Compose overlay for tests

desec-stack uses `docker-compose.test-e2e2.yml` as an overlay that
overrides config for testing (e.g., exposing captcha solutions). We
should create a similar overlay that:

- Exposes internal ports for test access
- Disables rate limiting for test reliability
- Uses test-specific blocklists with known domains

### 2. FaketimeShift for DNSSEC rollover testing

desec-stack's `conftest.py` includes a `FaketimeShift` context manager
that shifts time forward to test RRSIG rollover. This is directly
applicable to our Unbound trust anchor and DNSSEC signature validation:

```python
class FaketimeShift:
    """Shift time forward to test DNSSEC signature/key rollover.
    
    Uses libfaketime to intercept time() calls in the Unbound container,
    so signatures that haven't expired yet appear expired.
    """
    def __init__(self, days=0, hours=0):
        self.shift = f"+{days}d{hours}h"
    
    def __enter__(self):
        # Set FAKETIME env var on the unbound container
        # Requires unbound built with libfaketime preload
        os.environ["FAKETIME"] = self.shift
        restart_container("dns-unbound-validator")
        return self
    
    def __exit__(self, *args):
        os.environ["FAKETIME"] = "+0d"
        restart_container("dns-unbound-validator")
```

### 3. assert_all_ns pattern — retry across all nameservers

desec-stack's `assert_all_ns` retries an assertion across all
nameservers, handling propagation delays. We need the same for our
multi-tier, multi-cluster setup:

```python
def assert_all_ns(assertion, retry_on=(AssertionError, TypeError), timeout=30):
    """Retry an assertion until it passes or times out.
    
    Handles DNS propagation delays across tiers and clusters.
    """
    deadline = time.time() + timeout
    last_exc = None
    while time.time() < deadline:
        try:
            return assertion(query)
        except retry_on as e:
            last_exc = e
            time.sleep(1)
    raise last_exc
```

### 4. Performance test marker

desec-stack marks expensive tests with `@pytest.mark.performance` and
provides `--skip-performance-tests`. We should do the same for tests
that involve Tor (slow) or cross-cluster failover (requires SSH to
remote hosts).

## Proposed test suite

### Test categories

| Category | Tests | Speed | Requires |
|----------|-------|-------|----------|
| **DNSSEC validation** | Bogus response dropped, AD flag present, EDE codes correct | Fast | Unbound validator running |
| **Tier failover** | Kill tier 1 → tier 2 responds, kill 1-3 → tier 10 responds | Medium | All active tiers running |
| **Trust anchor rollover** | FaketimeShift forward → validation still works | Medium | libfaketime in Unbound container |
| **Blocklist** | Blocked domain returns NXDOMAIN, allowed domain resolves | Fast | Blocklist compiler + dnsdist |
| **Cross-cluster failover** | OCI DNS down → local cluster responds | Slow | SSH access to OCI + local nodes |
| **Change propagation** | Blocklist change visible on all clusters | Slow | Both clusters running |
| **Performance** | Query latency under load, cache hit ratio | Slow | Load testing tool |

### Test file structure

```
tests/dns/
  conftest.py                    # Fixtures: DNSClient, FaketimeShift, assert_all_ns
  spec/
    test_dnssec_validation.py    # DNSSEC validation tests
    test_tier_failover.py        # Tier fallback chain tests
    test_trust_anchor_rollover.py # FaketimeShift-based rollover tests
    test_blocklist.py            # Blocklist enforcement tests
    test_cross_cluster.py        # Cross-cluster failover tests
    test_change_propagation.py   # Config change propagation tests
    test_performance.py          # Latency and cache hit ratio tests
  docker-compose.test-dns.yml    # Test overlay compose file
```

### Key test: DNSSEC validation

```python
def test_dnssec_ad_flag_present(dns_client):
    """Valid DNSSEC response should have the AD (Authenticated Data) flag."""
    result = dns_client.query("example.com", dnssec=True)
    assert result.flags & dns.flags.AD, "AD flag not set — DNSSEC validation failed"

def test_dnssec_bogus_response_dropped(dns_client, mock_upstream):
    """Bogus DNSSEC response should be dropped by Unbound validator."""
    # Configure mock upstream to return a response with invalid RRSIG
    mock_upstream.set_response("example.com", rdata="1.2.3.4", bogus_rrsig=True)
    
    result = dns_client.query("example.com", dnssec=True)
    assert result.rcode == dns.rcode.SERVFAIL, \
        "Bogus DNSSEC response was not dropped by validator"

def test_dnssec_ede_code_on_servfail(dns_client, mock_upstream):
    """SERVFAIL should include Extended DNS Error code for debugging."""
    mock_upstream.set_response("example.com", rdata="1.2.3.4", bogus_rrsig=True)
    
    result = dns_client.query("example.com", dnssec=True, ede=True)
    assert result.rcode == dns.rcode.SERVFAIL
    assert result.ede_code is not None, "No EDE code on SERVFAIL — enable ede: yes in unbound.conf"
```

### Key test: tier failover

```python
def test_tier1_to_tier2_failover(dns_client, docker_containers):
    """When tier 1 (ODoH) is down, tier 2 (Anon DNSCrypt) should respond."""
    # Baseline: tier 1 works
    result = dns_client.query("example.com")
    assert result.returncode == 0
    
    # Stop tier 1
    docker_containers.stop("dns-dnscrypt-odoh")
    
    # Tier 2 should pick up (CoreDNS forward plugin tries next in sequence)
    result = dns_client.query("example.com", timeout=10)
    assert result.returncode == 0
    assert result.answer is not None
    
    # Restart tier 1
    docker_containers.start("dns-dnscrypt-odoh")

def test_all_active_tiers_to_root_failover(dns_client, docker_containers):
    """When all encrypted tiers are down, Unbound root (tier 10) should resolve."""
    for tier in ["dns-dnscrypt-odoh", "dns-dnscrypt-anon", "dns-unbound-tor"]:
        docker_containers.stop(tier)
    
    try:
        result = dns_client.query("example.com", timeout=15)
        assert result.returncode == 0
        # Tier 10 is recursive — it should still resolve
    finally:
        for tier in ["dns-dnscrypt-odoh", "dns-dnscrypt-anon", "dns-unbound-tor"]:
            docker_containers.start(tier)
```

### Key test: trust anchor rollover

```python
@pytest.mark.performance
def test_trust_anchor_rollover(dns_client):
    """DNSSEC validation should survive trust anchor rollover via FaketimeShift."""
    with FaketimeShift(days=30):
        # After 30 days, some RRSIGs may have expired
        # Unbound should still validate using refreshed trust anchor
        result = dns_client.query("example.com", dnssec=True)
        assert result.flags & dns.flags.AD, \
            "DNSSEC validation broke after 30-day time shift"
```

## Implementation plan

1. Add `tests/dns/` directory with `conftest.py` and test specs
2. Create `docker-compose.test-dns.yml` overlay with test-specific config
3. Add `libfaketime` to the Unbound Dockerfile for FaketimeShift support
4. Add a `just test-dns` recipe to the DNS service justfile
5. Integrate with the existing `just test` command via profile
6. Add CI pipeline step to run DNS tests on every change to `services/dns/`

## References

- [desec-stack e2e tests](https://github.com/desec-io/desec-stack/tree/main/test/e2e2) — reference implementation
- [desec-stack conftest.py](https://github.com/desec-io/desec-stack/blob/main/test/e2e2/conftest.py) — FaketimeShift, assert_all_ns patterns
- [libfaketime](https://github.com/wolfcw/libfaketime) — time interception for testing
- [dnspython](https://www.dnspython.org/) — Python DNS library for test clients
- `dnssec-gap-and-unbound-fix.md` — deployment plan with manual test steps
- `cross-cluster-dns-failover.md` — cross-cluster failover test patterns
