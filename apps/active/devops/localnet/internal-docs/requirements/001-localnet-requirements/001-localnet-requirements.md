

I'm interested in creating a full featured home lab in-a-box setup. The idea is that it would be a docker-compose setup with a transparent gateway. Almost every service has a transparent interception (for legacy non-configurable systems), and also the ports exposed to allow applications to opt-int that may not even be on the transparent intercept network. The tools I'm thinking about are: nftables, dnsdist, iproute2, eBPF, Envoy, Squid, Tproxy, logging pipeline, grafana, prometheus, chrony, tor daemon, logstash, elasticsearch, and other modern best featured tools as necessary.   The DNS chain might look like 

1. dnsdist, 2. CoreDNS, stubby, European Union lookup

## All Services
- expose a 
	- **direct connection**,
	- There will be a a gateway that does **transparent proxying** if used as a gateway, but upstream is not configured to access these services directly
	- Fully Transparent (no responsive headers) proxying if there is a service that can't be configured otherwise
- **Traffic Monitoring**: Real-time monitoring of all traffic
- **Metrics Collection**: Prometheus for collecting and storing time-series metrics
- **Caching**: cache upstream results for performance benefits
- **Visualization**: Grafana dashboards for visualizing metrics and traffic patterns
- **Distributed Tracing**: Jaeger for end-to-end request tracing
- **Centralized Logging**: Loki and Vector for log aggregation and querying
- **Project Isolation**: Dedicated project container with automatic monitoring
- **Heartbeat Monitoring**: Built-in health checks and external connectivity testing
- **Detailed Documentation**: Document Purpose, Getting Started, Stacks, Links to services and documentation
- 
- All services should log the details of all connections to an ElasticSearch stack making clear if it is the transparent stack, vs. those of other users/apps 
- All services should instrument metrics to Grafana, and make it obvious if it's transparent or another user
- All services should have health-check monitoring
- If there is caching, then cache as long as reasonable, and provide a way to flush caches
- Everything should be well documented about the chains (tool & purpose with links), the ports, the services
- If a service depends on an externals service for lists like malware domains, then it should pull the lists on a configurable basis via `systemd_timers`
- If a service depends on having an optimized lookup data storage format (like CDB), the build mechanism (`docker`) should accept the input in standard readable form, and then convert it to its optimized form, and once it's successfully build, replace the currently running ones.

---

## NTP

**Goals**
1. Support Leap Smearing
2. Support transparent and direct access modes
3. Logs all requests and makes it clear if it was transparent or direct access

**Requirements**
1. DNS & port level rewrites for transparent proxy, reroute external services to internal service
	1. DNS rewrite should be all the public time servers listed below and otherwise
2. `chronyd` transparently routed, and explicit port
3. Ordered list of Preferred upstream lookups
	1. `time.google.com` (supports Leap Smearing)
	2. Fallbacks 1..n


### Chain

### Suggestions and Considerations

1.  **`tor` for NTS Requests**:

    *   **Rationale**: While using `tor` adds anonymity, it also introduces latency and potential instability. NTS already provides encryption and authentication, so the added benefit of `tor` might not outweigh the performance impact, *unless* hiding the source IP is a critical requirement.
    *   **Suggestion**: Consider making `tor` conditional. Only route NTP requests through `tor` if the primary NTS server fails or if there's a specific need to hide the source IP.
    *   **Revised Layer 2**:

        ```
        2         | `tor` (optional)                | Route NTS requests (conditional based on policy/failure)
        ```
2.  **Server Selection**:

    *   **Suggestion**: Consider the geographic proximity of the NTP servers to your location. Choosing servers that are geographically closer can reduce latency and improve accuracy.
3. **NTS over UDP port 123**:

    *   **Warning**: NTS typically runs on UDP port 4460. Check that you are using a compatible time source.

4.  **Monitoring**:

    *   **Suggestion**: Implement monitoring to track the accuracy and stability of the NTP synchronization. Monitor the offset between your system clock and the NTP servers, as well as the reachability of the servers.
5.  **Configuration**:

    *   **Suggestion**: Ensure that `chronyd` is properly configured to use NTS and to automatically switch between servers based on their reliability and accuracy.
6.  **Stratum Levels**:

    *   **Suggestion**: Be aware of the stratum levels of the NTP servers. Lower stratum levels (closer to the reference clock) are generally more accurate and reliable. Ensure that your chosen servers have low stratum levels.


| **Layer** | **Service**                       | **Purpose**                                                                                                                     |
| --------- | --------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| 0         | `nftables` + `TPROXY`             | Transparently route if necessary                                                                                                |
| 1         | `chronyd`                         | Resolve time and sync time, must use NTS (Network Time Security)                                                                 |
| 2         | `tor` (optional)                  | Route NTS requests (conditional based on policy/failure)                                                                      |
| 3         | `time.google.com` (primary)       | Primary upstream supporting Leap Smear                                                                                          |
|   | `time2.google.com` (primary)        | Primary upstream supporting Leap Smear                                                                                          |
| 4         | Fallback 01 `time.nist.gov`       | Non-commercial, governmental                                                                                                    |
| 4         | Fallback 02 `0.pool.ntp.org`      | Non-commercial, non-governmental                                                                                                |
| 4         | Fallback 03 `time.cloudflare.com` | Commercial, privacy assured, not advertising based                                                                                |
| 4         | Fallback 04 `time.apple.com`      | Commercial, privacy suggested, not advertising based                                                                            |
| 4         | Fallback 05 `time.windows.com`    | Commercial, privacy not acknowledged, has advertising businesses                                                                 |


---

## DNS

### Goals
1. Prevent DNS Leaks
2. Support transparent and direct access modes
3. Logs all requests and makes it clear if it was transparent or direct access
4. Block malware sites
5. Block tracking sites that wont interfere with use of web
6. Block advertising services
7. Block paid adult content
8. Provide Unfiltered and multiple entry points for direct access mode with combinations of the below
	1. Protective (malware sites, phishing sites, misspellings, )
	2. Ad Filtering
	3. Tracking Filtering
	4. Paid Porn Filtering
9. Operate over [Oblivious DoH](https://blog.cloudflare.com/oblivious-dns/) as primary resolver
10. Domain Blocklists
	1. [StevenBlack hosts](https://github.com/StevenBlack/hosts)
	2. [AdAway](https://adaway.org/)
	3. [PhishTank](https://phishtank.org/)
	4. [EasyList](https://easylist.to/)
	5. [Disconnect.me](https://disconnect.me/trackerprotection)
	6. [MalwareDomains & AutoShun $$](https://riskanalytics.com/community/)


### Chain


| **Layer** | **Service**           | **Purpose**                                                                                                                                   |
| --------- | --------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| 0         | `nftables` + `TPROXY` | Transparent routing enforcement                                                                                                                |
| 1         | `dnsdist`             | Initial filtering, remapping, ECS stripping, route, rate-limit (global policies)                                                              |
| 2         | `CoreDNS`             | Local resolution, DNSSEC caching (for local domains and frequently accessed external domains), *optional local filtering/rewriting*            |
| 3         | `dnscrypt-proxy`      | Encrypt DNS queries (DoH/DoT/DNSCrypt/ODoH), DNSSEC validation, *filtering (blocklists/allowlists)*, route traffic to ODoH or standard resolvers |
| 4         | `tor` via SOCKS proxy | Anonymize IP before reaching external DNS resolvers (used when not employing ODoH)                                                              |
| 5         | External DNS Resolver | Forwards encrypted query to target DNS resolver (e.g., Cloudflare, Google Public DNS, NextDNS, or a self-hosted resolver), or ODoH proxy      |
| 6         | Fallback Logic        | Retry other DNS resolvers, switch between ODoH and standard resolvers, or fallback to plaintext upstreams if encrypted DNS fails                |
| 7         | ICANN `.` resolvers   | Queried by the external DNS resolver if domain resolution requires root zone traversal                                                        |
| 8         | Final Resolver        | Authoritative DNS server for the requested domain                                                                                             |


### Implementation Considerations

*   **`dnsdist`**: Configure `dnsdist` to use blocklists and allowlists to filter domains.
*   **`CoreDNS`**: Use the `rewrite` plugin in `CoreDNS` to rewrite DNS queries.
*   **`dnscrypt-proxy`**: Configure `dnscrypt-proxy` to use blocklists and allowlists to filter domains.

### Domain Endpoints
1. ODoH
	1. 1.1.1.1 - [Cloudflare](https://developers.cloudflare.com/1.1.1.1/privacy/public-dns-resolver/)
	2. 8.8.8.8 - 
	3. 9.9.9.9 - 
---

## Web

**Goals**


**Chain**

| **Layer** | **Service**                         | **Purpose**                                                                                             |
| --------- | ----------------------------------- | ----------------------------------------------------------------------------------------------------- |
| 0         | `nftables` + `TPROXY`               | Transparent routing enforcement                                                                       |
| 1         | `Envoy`                             | Main proxy: filtering, remapping, rate-limiting, route                                                |
| 2         | `Squid`                             | Cache                                                                                                 |
| 3         | `Privoxy` OR `Polipo`               | Filter                                                                                                |
| 4         | `ohoh-proxy`                       | Oblivious HTTP over HTTPS forwarder (HTTP/HTTPS) to encrypt queries to upstream when available.                             |
| 5         | VPN: `Tor` OR `Shadowsocks`         | Anonymize IP when not using OHoH proxy                                                              |
| 7         | Fallback Logic                      | Retry, or other OHoH proxies, or fallback to direct proxy or VPN upstreams if initial OHoH fails.    |
| 8         | Remote HTTP server                  | Queried by OHoH target if domain resolution requires root zone traversal                                 |
| 9         | Final Web Server                    | Authoritative web server for the requested content                                                      |
| 10        | Fallbacks                           | OHoH, Direct Proxy, or VPN upstreams if OHoH fails                                                      |

### Configuration Considerations

*   **Envoy Configuration**: Configure `Envoy` for advanced filtering, remapping, and rate limiting.
*   **Squid Configuration**: Optimize `Squid` for caching web content efficiently.
*   **Privoxy/Polipo Configuration**: Configure content filtering rules to block unwanted content.
*   **odoh-client Configuration**: Set up the OHoH client to encrypt and forward queries to the OHoH proxy.
*   **VPN Configuration**: Configure `Tor` or `Shadowsocks` for anonymity and final egress, ensuring they are properly integrated into the proxy chain.
*   **Fallback Logic Implementation**: Implement scripts or configurations to handle fallback scenarios, ensuring seamless operation in case of failures.



---

## Log and Monitoring


**Chain**

| **Layer** | **Service**                                         | **Purpose**                                                                                      |     |
| --------- | --------------------------------------------------- | ------------------------------------------------------------------------------------------------ | --- |
| 1         | [Vector Components](https://vector.dev/)            | main proxy                                                                                       |     |
| 2         | [Vector Transforms](https://vector.dev/)            | Cache                                                                                            |     |
| 3         | [Vector Outputs](https://vector.dev/)               | Filter                                                                                           |     |
| 4a1       | Local Storage                                       |                                                                                                  |     |
| 4b1       | `promtail`                                          | Push Logs to Loki. It's end-of-lifing to [Grafana Alloy](https://grafana.com/docs/alloy/latest/) |     |
| 4b2       | `loki`                                              | Log storage for query                                                                            |     |
| 4c1       | `prometheus`                                        |                                                                                                  |     |
| 4bc3      | `grafana`                                           | Local Query interface                                                                            |     |
| 4d1       | [Vector Outputs Consolidation](https://vector.dev/) | Combines logs from multiple services and adds annotation to filter                               |     |
| 4d2       | VPN: `Tor` OR `Shadowsocks`                         | Anonymity & final egress                                                                         |     |
| 4d3       | [BetterStack](https://betterstack.com/pricing)      | Use Free Tier                                                                                    |     |

---

## DHCP

---

## TFTP

--- 

## Email

---

## SSO
