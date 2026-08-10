# MITM CA Certificate Distribution

**Date:** 2026-08-10
**Status:** Proposed
**Related:** `diagrams/proxy/complete-web-proxy-chain.mmd`

## The Problem

The MITM proxy (mitmproxy) decrypts HTTPS traffic by generating a custom CA
certificate and signing per-domain certificates on the fly. For this to work,
every client device must trust the MITM CA certificate. Without trust, clients
see TLS certificate errors for every HTTPS site.

The challenge is distributing the CA certificate to:
- Windows clients (dtop202311 LAN)
- Linux clients (kckinai, OCI)
- macOS clients
- Mobile devices
- Containers that need HTTPS interception

## Architecture

### CA Generation

The MITM proxy generates its CA on first start and stores it in a persistent
Docker volume (`localnet-proxy-mitm-ca-volume`). The CA is generated once and
persists across container restarts.

```
mitmproxy container
  └── /home/mitmproxy/.mitmproxy/
      ├── mitmproxy-ca.pem       (CA cert + private key)
      ├── mitmproxy-ca-cert.cer  (CA cert only — DER format)
      └── mitmproxy-ca-cert.pem  (CA cert only — PEM format)
```

### CA Distribution via Traefik

The CA certificate is served via Traefik at a well-known URL, protected by
Authelia authentication:

```
https://ca.<base>/mitmproxy-ca-cert.cer  →  Authelia auth  →  CA cert download
```

This allows authorized users to download the CA cert from any device with a
browser, without SSH access to the proxy host.

### Client Trust Configuration

| OS | Trust Store | Installation Method |
|----|-------------|---------------------|
| Windows | Certificate Store | Double-click `.cer` → Install → Trusted Root CAs |
| macOS | Keychain | `security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain mitmproxy-ca-cert.pem` |
| Linux | `/usr/local/share/ca-certificates/` | `cp mitmproxy-ca-cert.crt /usr/local/share/ca-certificates/ && update-ca-certificates` |
| Firefox | NSS database | `certutil -d sql:~/.mozilla/firefox/*.default/ -A -t "C,," -n "MITM Proxy CA" -i mitmproxy-ca-cert.pem` |
| Containers | Mount CA volume | `-v localnet-proxy-mitm-ca-volume:/ca:ro` + `SSL_CERT_FILE=/ca/mitmproxy-ca-cert.pem` |

### Certificate Pinning

Some applications use certificate pinning and will reject the MITM CA:
- Mobile banking apps
- Some Google services (Chrome pins Google certs)
- Signal, WhatsApp
- Apps using `okhttp` CertificatePinner

These apps will fail through the MITM proxy. The bypass ports (3129 direct
to MITM, 6081 direct to Varnish, 1080 direct to Gost) allow traffic to
bypass MITM decryption when needed.

## Security Considerations

- **CA private key security**: The CA private key is in the Docker volume,
  not exposed via Traefik. Only the public cert is served.
- **Trust scope**: The MITM CA should only be trusted on devices that
  explicitly opt into the proxy chain. It should NOT be distributed via MDM
  or group policy to devices that don't use the proxy.
- **CA rotation**: If the CA is compromised, it must be regenerated and
  re-distributed to all clients. The old CA must be removed from all trust
  stores.
- **Volume backup**: The CA volume should be backed up to avoid regenerating
  the CA (which would require re-distribution to all clients).

## Implementation Plan

1. Deploy MITM proxy with persistent CA volume
2. Configure Traefik route for CA cert download (`ca.<base>`)
3. Document client trust configuration per OS
4. Test HTTPS interception with a trusted client
5. Document bypass ports for pinned-cert apps
