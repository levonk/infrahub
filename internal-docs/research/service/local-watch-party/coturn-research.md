# coturn Research for Local-Watch-Party on OCI ARM64

This doc covers a coturn TURN/STUN deployment for WebRTC voice chat on an Oracle Cloud ARM64 server. The application is already fronted by Traefik (HTTPS + Authelia), so the TURN layer must be designed separately from that HTTP path.

---

## 1. Coturn Docker Images

### Recommended image

- **`coturn/coturn`** is the official image and is actively maintained.
- It publishes multi-platform manifests for `linux/amd64`, `arm32v6`, `arm32v7`, `arm64v8`, `i386`, `ppc64le`, and `s390x` (source: GitHub `docker/coturn` README and Docker Hub tags page).
- For ARM64 OCI, use an `arm64v8` tag. Good pinning options:
  - `coturn/coturn:4.17.2-alpine`
  - `coturn/coturn:4.17.2-debian`
  - `coturn/coturn:4-alpine`
- The `4.17.x` release stream is current as of the latest research (GitHub Releases lists `4.17.2`/`docker/4.17.2-r0` and later).
- `4.17.2-alpine` is ~50 MB compressed; `debian` is slightly larger but uses glibc if you hit musl issues.

### Alternatives

- **`ghcr.io/coturn/coturn:4.17.2-alpine`** — same official image, good fallback if Docker Hub rate-limits.
- **`woahbase/alpine-coturn`** — community multi-arch build; not as current as official.
- **`instrumentisto/coturn`** — deprecated; the maintainers point users at `coturn/coturn`.

**Recommendation:** Use `coturn/coturn:4.17.2-alpine` (or the current latest patch at deploy time) and pin by digest in production.

---

## 2. Ports and Exposure

| Port(s) | Protocol | Purpose | Needs to be public? |
|---|---|---|---|
| `3478` | TCP + UDP | STUN/TURN control (`listening-port`) | Yes, if any peer is outside Tailscale |
| `5349` | TCP (TLS) + UDP (DTLS) | TURN over TLS/DTLS (`tls-listening-port`) | Optional; only if you want `turns://` |
| `49152-65535` | UDP | TURN relay (`min-port` / `max-port`) | Yes, if peers outside Tailscale need a relay |

### Public vs Tailscale

- If every participant is on Tailscale, the TURN server can be bound to the Tailscale interface and all ports restricted to Tailscale source ranges (`100.64.0.0/10`, `fd7a:115c:a1e0::/48`). In that case no public firewall opening is needed.
- If any one peer is **not** on Tailscale, `3478` (TCP/UDP) and the entire relay range must be reachable on the server's public IP. `5349` only needs to be exposed if you enable TURNS.
- The relay range is where the actual media flows. If it is blocked, TURN allocation succeeds but no media flows.

### Port range sizing

- Default: `49152-65535` (full IANA ephemeral range).
- For a small deployment, you can narrow it. For 5-10 concurrent voice users, a few hundred ports is plenty, e.g. `49160-49300`. Each concurrent TURN allocation needs one relay UDP port (plus an outgoing source port on the same range).

---

## 3. Minimal `turnserver.conf`

A friend-only, non-TLS TURN server that covers the common WebRTC case:

```ini
# Network
listening-port=3478
tls-listening-port=5349
listening-ip=0.0.0.0
# external-ip=<PUBLIC_IP>
# If the VM is behind 1:1 NAT, use: external-ip=<PUBLIC_IP>/<PRIVATE_IP>
# Alternatively use Docker env DETECT_EXTERNAL_IP=yes

# Relay
min-port=49152
max-port=65535
# relay-ip=<PRIVATE_IP>  # usually not needed on a single-NIC OCI VM

# Authentication
lt-cred-mech
realm=watch.levonk.com
fingerprint
user=watchparty:CHANGE_ME_STRONG_PASSWORD

# Hardening
no-multicast-peers
no-loopback-peers
stale-nonce=600

# Logging
log-file=stdout
```

Key settings:

- `lt-cred-mech` — WebRTC requires long-term credentials.
- `fingerprint` — required by WebRTC/ICE.
- `realm` — used during credential derivation; conventionally your domain.
- `user` — a static `username:password` pair. Can also use `user=username:0x<turnadmin-generated-key>`.
- `stale-nonce` — forces nonce re-issue after 10 minutes.
- `log-file=stdout` — keeps container logs visible to Docker.

**If you prefer to auto-detect the OCI public IP inside the container**, run with `network_mode: host` and pass `DETECT_EXTERNAL_IP=yes DETECT_RELAY_IP=yes`.

---

## 4. Authentication for a Friends-Only Deployment

### Option A — Static user credentials (simplest)

```ini
lt-cred-mech
realm=watch.levonk.com
user=watchparty:CHANGE_ME_STRONG_PASSWORD
```

Then in the WebRTC client:

```js
{ urls: 'turn:watch.levonk.com:3478?transport=udp', username: 'watchparty', credential: 'CHANGE_ME_STRONG_PASSWORD' }
```

This is sufficient for a small, closed group. Rotate the password occasionally.

### Option B — Pre-hashed long-term key

Generate a key with `turnadmin`:

```bash
docker run --rm coturn/coturn:4.17.2-alpine turnadmin -k -u watchparty -r watch.levonk.com -p 'CHANGE_ME_STRONG_PASSWORD'
# output: 0x...
```

Use in config:

```ini
user=watchparty:0x<key-from-turnadmin>
```

This keeps the plaintext password out of the coturn config file (the key is still derivable from the password, so the client still needs the original password).

### Option C — Shared secret / TURN REST API

```ini
lt-cred-mech
use-auth-secret
static-auth-secret=CHANGE_ME_LONG_RANDOM_SECRET
realm=watch.levonk.com
```

The Local-Watch-Party backend mints short-lived credentials:

- `username = "<unix-expiry>:<user-id>"`
- `credential = base64(hmac-sha1(username, static-auth-secret))`

This is the most robust pattern for production but needs backend work. For a small friends setup, **Option A** is fine to start.

---

## 5. Firewall on OCI

Open the ports in firewalld (public zone is the default on Oracle Linux):

```bash
# STUN/TURN control
sudo firewall-cmd --permanent --zone=public --add-port=3478/tcp
sudo firewall-cmd --permanent --zone=public --add-port=3478/udp

# TURNS, only if enabled
sudo firewall-cmd --permanent --zone=public --add-port=5349/tcp
sudo firewall-cmd --permanent --zone=public --add-port=5349/udp

# TURN relay range — or the smaller range you configured
sudo firewall-cmd --permanent --zone=public --add-port=49152-65535/udp

# Reload
sudo firewall-cmd --reload
```

Also open the same ports in the **OCI Security List / Network Security Group** attached to the VM's subnet. The cloud security group is the outer layer and can block traffic before it reaches the VM.

If you only want Tailscale users, replace the public zone rules with source-restricted rules:

```bash
sudo firewall-cmd --permanent --zone=public --add-source=100.64.0.0/10
sudo firewall-cmd --permanent --zone=public --add-source=fd7a:115c:a1e0::/48
```

---

## 6. Integration with Local-Watch-Party

The Local-Watch-Party frontend should pass an `iceServers` array when creating the `RTCPeerConnection`.

Example:

```js
const pc = new RTCPeerConnection({
  iceServers: [
    { urls: 'stun:watch.levonk.com:3478' },
    {
      urls: [
        'turn:watch.levonk.com:3478?transport=udp',
        'turn:watch.levonk.com:3478?transport=tcp',
      ],
      username: 'watchparty',
      credential: 'CHANGE_ME_STRONG_PASSWORD',
    },
  ],
});
```

If you enable TURNS on 5349, add:

```js
{
  urls: 'turns:watch.levonk.com:5349?transport=tcp',
  username: 'watchparty',
  credential: 'CHANGE_ME_STRONG_PASSWORD',
}
```

Notes:

- `turn:` without `?transport` defaults to UDP in browsers.
- `turns:` with `?transport=tcp` uses TLS over TCP.
- `stun:` does **not** take a username/credential; `turn:`/ `turns:` does.
- The `username`/`credential` in the client must match the coturn account or the REST-API credentials your backend mints.

---

## 7. Traefik Considerations

**Coturn should NOT be routed through Traefik.**

- Traefik is primarily an HTTP/TCP/UDP edge router, but TURN requires a huge, dynamic UDP relay port range and stateful UDP sessions.
- UDP relay through Traefik is not practical and not supported in a way that preserves TURN allocation lifetimes and peer ports.
- The HTTPS/Authelia flow covers the Local-Watch-Party web UI; TURN runs as a separate, directly exposed service.
- If you want TURNS, terminate TLS inside coturn with a certificate volume, not via Traefik.

Recommended setup:

- Keep the app on `watch.levonk.com:443` through Traefik.
- Run coturn on the same public IP but on `3478`/`5349` and the relay range, bound directly to the host or via `network_mode: host` in Docker.

---

## 8. Security and Abuse Mitigation

TURN servers can be abused as open bandwidth relays. Mitigations:

| Setting | Recommendation |
|---|---|
| **Require auth** | Always use `lt-cred-mech` or `use-auth-secret`. Never run anonymous TURN. |
| **Rotate secrets** | For static users, rotate the password every few months or after any leak. For REST API, rotate the `static-auth-secret` periodically. |
| **Rate-limit 401s** | `unauthorized-ratelimit` and `unauthorized-ratelimit-rps=10` to mitigate UDP reflection/amplification (coturn 4.14.0+). |
| **Quotas** | `user-quota=10` and `total-quota=100` (tune to expected load). This caps allocations per account and globally. |
| **Bandwidth limits** | `max-bps=1048576` (1 Mbps) and `total-bps=10485760` (10 Mbps) for a small voice deployment. |
| **Nonce lifetime** | `stale-nonce=600` (10 minutes). |
| **Multicast/loopback** | `no-multicast-peers` and `no-loopback-peers` in production. |
| **Disable unused admin** | Do not enable the web admin interface unless you specifically need it. |
| **Small relay range** | If you can, narrow `min-port`/`max-port` so the exposed UDP surface is smaller. |
| **Monitor logs** | Ship coturn logs to a log aggregator and alert on repeated allocation failures. |

Example extra hardening block:

```ini
unauthorized-ratelimit
unauthorized-ratelimit-rps=10
user-quota=10
total-quota=100
max-bps=1048576
total-bps=10485760
stale-nonce=600
no-multicast-peers
no-loopback-peers
```

---

## 9. Resource Usage for 5-10 Concurrent Users

- **Idle:** ~64-128 MB RAM, <1% CPU.
- **5-10 concurrent voice sessions:** roughly 128-256 MB RAM and a small fraction of one ARM core. coturn handles thousands of concurrent calls per core when loaded, so 5-10 users is trivial.
- **Bandwidth:** Assume ~64-128 kbps per audio track. Each TURN allocation will see the media in both directions. For 10 participants you are unlikely to saturate anything above a few megabits.
- **Disk:** Minimal; logs are the main consumer. Use `log-file=stdout` and let Docker handle rotation.

The OCI A1 ARM64 shape (4 OCPU / 24 GB RAM) is overkill for this workload. Even the smallest free-tier instance has plenty of headroom.

---

## 10. Recommended First-Pass Deployment

1. Run `coturn/coturn:4.17.2-alpine` with `network_mode: host` and a mounted `turnserver.conf`.
2. Use `lt-cred-mech` with a single static user for the friends group.
3. Expose public TCP/UDP `3478` and UDP `49152-65535` (or a narrower range) on OCI and firewalld.
4. Skip `5349`/TURNS initially unless you hit firewall DPI.
5. Set `iceServers` in Local-Watch-Party to `turn:watch.levonk.com:3478?transport=udp`.
6. Verify with a tool like [Trickle ICE](https://webrtc.github.io/samples/src/content/peerconnection/trickle-ice/) to confirm relay candidates are gathered.
7. Later, move to the TURN REST API (`use-auth-secret`) if you want short-lived, per-user credentials and better abuse controls.

---

## Sources

- `coturn/coturn` Docker README: https://github.com/coturn/coturn/tree/master/docker/coturn
- `coturn/coturn` Docker Hub tags: https://hub.docker.com/r/coturn/coturn/tags
- `turnserver` wiki / man page: https://github.com/coturn/coturn/wiki/turnserver
- Example `turnserver.conf`: https://github.com/coturn/coturn/blob/master/examples/etc/turnserver.conf
- coturn 401 ratelimit docs: https://github.com/coturn/coturn/blob/66833df4/docs/401-ratelimit.md
- TURN REST API auth: https://github.com/coturn/coturn/blob/master/README.turnserver
- RFC 8656 / RFC 7065 TURN URI schemes
- Oracle Linux firewalld docs: https://docs.oracle.com/en/operating-systems/oracle-linux/9/firewall/firewall-ConfiguringfirewalldZones.html
