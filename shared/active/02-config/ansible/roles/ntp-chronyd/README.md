# ntp-chronyd

Native chronyd NTP server for the tailnet (`ntp.{infra_domain_base}` → A
record to the cloud server's Tailscale IP). Design:
`shared/docs/pipelines/ntp/ntp-chain.md`.

## Why native and not a container

chronyd must discipline the **host** clock — a container does the same thing
via `SYS_TIME` anyway, so containerizing buys nothing and costs capability
juggling (see `services/ntp/chronyd/internal-docs/troubleshooting/`).
The role also disables `systemd-timesyncd` so two daemons never fight over
the clock. `cloud_servers` set `nix_core_tools_time_sync_method: "chrony"`
so bootstrap does not re-enable it.

## What it does

- Installs `chrony`, templates `chrony.conf` (EL: `/etc/chrony.conf`,
  Debian: `/etc/chrony/chrony.conf`).
- Upstreams: NTS-capable sources (`time.google.com`/`time2.google.com`/
  `time.nist.gov`) get the `nts` flag only when `ntp_chronyd_nts_enabled` —
  **on OCI it is set `false`** because the OCI security list blocks
  outbound TCP 4460 (NTS-KE). Plain-NTP fallbacks: pool, Cloudflare,
  Apple, Microsoft.
- Leap smearing: `smoothtime 400 0.001 leaponly` — Google smears
  server-side; this is the safety net for non-smearing sources.
- Serves NTP on `port {{ infra_port_ntp_server_host }}` (123) bound to
  `{{ infra_tailscale_ip_cloud_server }}` only (chronyd allows one
  `bindaddress` per protocol — last wins; local consumers query the
  tailnet IP), `allow` limited to `{{ infra_network_tailscale_cidr }}` —
  public queries are silently dropped (no amplification reflector).
- systemd drop-in orders chronyd `After=tailscaled.service` so the bind
  address exists at startup.
- Stops + masks `systemd-timesyncd` (defense in depth).

## Variables

See `defaults/main.yml`. Key overrides:

| Var | Default | Purpose |
|-----|---------|---------|
| `ntp_chronyd_tailnet_bind_ip` | `infra_tailscale_ip_cloud_server` | Tailscale IP to bind/serve on |
| `ntp_chronyd_nts_enabled` | `true` (`false` on OCI) | Use `nts` on upstreams (role asserts `+NTS` in `chronyd -v`) |
| `ntp_chronyd_bind_addresses` | tailnet IP only | Listening sockets (one `bindaddress` per protocol) |
| `ntp_chronyd_allow_networks` | localhost + tailnet CIDR | `allow` ACL |
| `ntp_chronyd_verify_health` | `true` | Run `chronyc tracking` retries post-deploy |

## Usage

```bash
just ansible-deploy-ntp       # deploy-ntp.yml → cloud_servers
just ansible-validate-ntp     # validate-ntp.yml → cloud_servers
```
