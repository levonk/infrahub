# OCI Cloud Server — SSH Access Guide

This document explains how SSH access to the OCI cloud server works,
including the fwknop SPA (Single Packet Authorization) layer, the
Tailscale parallel path, and the per-client key architecture.

## Access Paths Overview

There are two ways to reach the OCI cloud server via SSH:

```mermaid
graph LR
    subgraph "Client Machines"
        Mac1["lzkmbp2016<br/>(macOS, micro)"]
        Mac2["lzkmbp2018<br/>(macOS, micro)"]
        Linux["kckinai<br/>(Ubuntu, lk)"]
        OCI["oci-cloud-server<br/>(Oracle Linux, opc)"]
    end

    subgraph "Path 1: Tailscale (Always Open)"
        TSNet["Tailscale Tailnet<br/>100.64.0.0/10"]
        TSIP["OCI Tailscale IP<br/>100.90.22.85:22"]
    end

    subgraph "Path 2: Public IP (SPA Required)"
        PubDNS["oci.mach.levonk.com<br/>DDNS → Public IP"]
        SPA["fwknopd<br/>UDP 62271"]
        iptables["iptables<br/>FWKNOP_INPUT chain"]
        SSH["sshd<br/>Port 22"]
    end

    Mac1 -->|"ssh oci<br/>(no knock)"| TSNet
    Mac2 -->|"ssh oci<br/>(no knock)"| TSNet
    Linux -->|"ssh oci<br/>(no knock)"| TSNet
    OCI -->|"ssh oci<br/>(no knock)"| TSNet
    TSNet --> TSIP

    Mac1 -->|"ssh ocispa<br/>(auto-knock)"| PubDNS
    Mac2 -->|"ssh ocispa<br/>(auto-knock)"| PubDNS
    Linux -->|"ssh ocispa<br/>(auto-knock)"| PubDNS
    OCI -->|"ssh ocispa<br/>(auto-knock)"| PubDNS
    PubDNS -->|"1. Send SPA packet<br/>(encrypted UDP)"| SPA
    SPA -->|"2. Validate + insert<br/>temp iptables rule"| iptables
    iptables -->|"3. Port 22 open<br/>for 120 seconds"| SSH

    style TSNet fill:#99ccff
    style TSIP fill:#99ccff
    style SPA fill:#ff9966
    style iptables fill:#ffcc99
    style SSH fill:#99ff99
```

| Path | Command | Knock needed? | Always works? |
|------|---------|---------------|---------------|
| Tailscale | `ssh oci` | No | Yes (if Tailscale is up) |
| Public IP + SPA | `ssh ocispa` | Yes (automatic) | Yes (if public IP + fwknopd are up) |

## SPA Flow: Step by Step

When you run `ssh ocispa`, the ProxyCommand does three things in sequence:

```mermaid
sequenceDiagram
    participant User as User<br/>ssh ocispa
    participant FW as fwknop client<br/>~/.fwknoprc
    participant Net as Internet<br/>UDP 62271
    participant Fwknopd as fwknopd<br/>(pcap sniffing)
    participant IPTables as iptables<br/>FWKNOP_INPUT
    participant SSHD as sshd<br/>Port 22
    participant NC as nc<br/>(netcat)

    User->>FW: 1. ProxyCommand triggers<br/>fwknop -n oci-cloud-server
    FW->>FW: 2. Build SPA packet<br/>(encrypt + HMAC sign<br/>with per-client key)
    FW->>Net: 3. Send single UDP packet<br/>to port 62271
    Note over FW,NC: sleep 2 seconds
    Fwknopd->>Net: 4. pcap captures packet
    Fwknopd->>Fwknopd: 5. Try each access.conf stanza<br/>(per-client keys)
    Fwknopd->>Fwknopd: 6. Matching key found<br/>(HMAC validates)
    Fwknopd->>IPTables: 7. Insert ACCEPT rule<br/>for client IP → tcp/22<br/>(expires in 120s)
    User->>NC: 8. nc connects to<br/>oci.mach.levonk.com:22
    NC->>SSHD: 9. TCP handshake
    SSHD->>NC: 10. SSH banner exchange
    NC->>User: 11. SSH session established
    Note over IPTables: 12. After 120 seconds<br/>iptables rule auto-removed<br/>Port 22 closes again
```

### What happens without a knock

If you try `ssh opc@oci.mach.levonk.com` directly (no knock):

```mermaid
sequenceDiagram
    participant User as User
    participant Net as Internet
    participant IPTables as iptables INPUT
    participant SSHD as sshd

    User->>Net: TCP SYN to port 22
    Net->>IPTables: Packet arrives
    IPTables->>IPTables: Check rules:<br/>1. FWKNOP_INPUT (empty — no knock)<br/>2. Tailscale ACCEPT (wrong source IP)<br/>3. libvirt ACCEPT (wrong source IP)<br/>4. SPA UDP ACCEPT (wrong port)<br/>5. DROP tcp/22 (matches!)
    IPTables-->>Net: Packet dropped silently
    Net-->>User: Connection timeout
    Note over SSHD: sshd never sees the packet<br/>Port scanner sees nothing
```

## Per-Client Key Architecture

Each machine has its own SPA key pair. The server's `access.conf` has
one stanza per client. This provides compartmentalization: compromise
of one client only exposes that client's key.

```mermaid
graph TB
    subgraph "Ansible Vault (Encrypted)"
      VK1["vault_fwknop_spa_key_kckinai"]
      VK2["vault_fwknop_spa_key_lzkmbp2016"]
      VK3["vault_fwknop_spa_key_lzkmbp2018"]
      VK4["vault_fwknop_spa_key_oci_cloud_server"]
    end

    subgraph "Server: /etc/fwknop/access.conf"
      S1["Stanza #1<br/>KEY: kckinai<br/>HMAC: kckinai"]
      S2["Stanza #2<br/>KEY: lzkmbp2016<br/>HMAC: lzkmbp2016"]
      S3["Stanza #3<br/>KEY: lzkmbp2018<br/>HMAC: lzkmbp2018"]
      S4["Stanza #4<br/>KEY: oci-cloud-server<br/>HMAC: oci-cloud-server"]
    end

    subgraph "Client: ~/.fwknoprc"
      C1["kckinai<br/>uses kckinai key only"]
      C2["lzkmbp2016<br/>uses lzkmbp2016 key only"]
      C3["lzkmbp2018<br/>uses lzkmbp2018 key only"]
      C4["oci-cloud-server<br/>uses oci-cloud-server key only"]
    end

    VK1 --> S1
    VK2 --> S2
    VK3 --> S3
    VK4 --> S4

    VK1 -.->|"Ansible deploy"| C1
    VK2 -.->|"chezmoi apply"| C2
    VK3 -.->|"chezmoi apply"| C3
    VK4 -.->|"Ansible deploy"| C4

    C1 -->|"SPA packet"| S1
    C2 -->|"SPA packet"| S2
    C3 -->|"SPA packet"| S3
    C4 -->|"SPA packet"| S4

    C1 -.->|"wrong key → HMAC fail"| S2
    C2 -.->|"wrong key → HMAC fail"| S1

    style VK1 fill:#ffcc99
    style VK2 fill:#ffcc99
    style VK3 fill:#ffcc99
    style VK4 fill:#ffcc99
    style S1 fill:#99ff99
    style S2 fill:#99ff99
    style S3 fill:#99ff99
    style S4 fill:#99ff99
```

### How stanza matching works

When a SPA packet arrives, fwknopd tries each stanza in order:

```mermaid
flowchart TD
    Start["SPA packet arrives<br/>(UDP 62271)"] --> Try1["Try stanza #1<br/>(kckinai key)"]
    Try1 --> Check1{"HMAC validates?"}
    Check1 -->|"Yes"| Accept1["Insert iptables rule<br/>for client IP<br/>→ tcp/22 for 120s"]
    Check1 -->|"No"| Try2["Try stanza #2<br/>(lzkmbp2016 key)"]
    Try2 --> Check2{"HMAC validates?"}
    Check2 -->|"Yes"| Accept2["Insert iptables rule<br/>for client IP<br/>→ tcp/22 for 120s"]
    Check2 -->|"No"| Try3["Try stanza #3<br/>(lzkmbp2018 key)"]
    Try3 --> Check3{"HMAC validates?"}
    Check3 -->|"Yes"| Accept3["Insert iptables rule<br/>for client IP<br/>→ tcp/22 for 120s"]
    Check3 -->|"No"| Try4["Try stanza #4<br/>(oci-cloud-server key)"]
    Try4 --> Check4{"HMAC validates?"}
    Check4 -->|"Yes"| Accept4["Insert iptables rule<br/>for client IP<br/>→ tcp/22 for 120s"]
    Check4 -->|"No"| Reject["Packet rejected<br/>No matching key"]
    Accept1 --> Done["Access granted"]
    Accept2 --> Done
    Accept3 --> Done
    Accept4 --> Done

    style Start fill:#99ccff
    style Done fill:#99ff99
    style Reject fill:#ff9999
```

### Server log example

When lzkmbp2016 sends a knock, the server logs show:

```
(stanza #1) SPA Packet from IP: 172.56.120.5 received with access source match
[172.56.120.5] (stanza #1) Error creating fko context: HMAC_COMPAREFAIL
(stanza #2) SPA Packet from IP: 172.56.120.5 received with access source match
Added access rule to FWKNOP_INPUT for 172.56.120.5 -> 0.0.0.0/0 tcp/22, expires at 1786840865
```

- Stanza #1 (kckinai key) — tried first, HMAC fails (wrong key)
- Stanza #2 (lzkmbp2016 key) — matches, access rule inserted

The "HMAC_COMPAREFAIL" for non-matching stanzas is **expected** and not an error.

## iptables Rule Chain

The OCI server uses raw iptables (no UFW, no firewalld). The INPUT
chain has this order:

```mermaid
graph TD
    Input["INPUT chain<br/>(policy ACCEPT)"] --> Rule1["1. FWKNOP_INPUT<br/>(jump to fwknop sub-chain)"]
    Rule1 --> Rule2["2. LIBVIRT_INP<br/>(jump to libvirt sub-chain)"]
    Rule2 --> Rule3["3. ACCEPT udp/62271<br/>(SPA UDP port — always open)"]
    Rule3 --> Rule4["4. ACCEPT tcp/22<br/>from 100.64.0.0/10<br/>(Tailscale — always open)"]
    Rule4 --> Rule5["5. ACCEPT tcp/22<br/>from 192.168.100.0/24<br/>(libvirt — always open)"]
    Rule5 --> Rule6["6. ACCEPT tcp/22<br/>from 192.168.101.0/24<br/>(libvirt — always open)"]
    Rule6 --> Rule7["7. DROP tcp/22<br/>(public SSH closed)<br/>Only when fwknop_close_public_ssh=true"]
    Rule7 --> Default["Default policy: ACCEPT"]

    FWKNOP["FWKNOP_INPUT sub-chain<br/>(populated by fwknopd<br/>after valid SPA packet)"]
    Rule1 -.-> FWKNOP
    FWKNOP -.->|"Temp ACCEPT tcp/22<br/>for client IP (120s)"| Rule7

    style Rule3 fill:#99ccff
    style Rule4 fill:#99ff99
    style Rule5 fill:#99ff99
    style Rule6 fill:#99ff99
    style Rule7 fill:#ff9999
    style FWKNOP fill:#ffcc99
```

### Rule evaluation order

1. **FWKNOP_INPUT** — fwknopd's dynamic chain. After a valid knock, this
   contains a temporary ACCEPT rule for the client's IP. If no knock has
   been sent, this chain is empty and packets fall through.
2. **LIBVIRT_INP** — libvirt's chain for VM traffic.
3. **SPA UDP port** — always allows UDP 62271 so SPA packets can reach fwknopd.
4. **Tailscale SSH** — always allows TCP/22 from the Tailscale CGNAT range.
5. **libvirt SSH** — always allows TCP/22 from libvirt bridge networks.
6. **DROP public SSH** — drops TCP/22 from anywhere else. This is the rule
   that makes port 22 invisible to scanners. Only present when
   `fwknop_close_public_ssh=true`.
7. **Default policy** — ACCEPT (but the DROP rule above catches public SSH first).

## Key Distribution Model

Keys are distributed through different channels depending on the machine type:

```mermaid
graph TB
    subgraph "Ansible Vault"
      Vault["infrahub-levonk-all.vault.yml<br/>(encrypted)"]
    end

    subgraph "Linux Machines (Ansible)"
      Ansible["common-fwknop-client role<br/>deploy-fwknop-client.yml"]
      K["kckinai<br/>~/.fwknoprc (user: lk)"]
      O["oci-cloud-server<br/>~/.fwknoprc (user: opc)"]
    end

    subgraph "macOS Machines (chezmoi + nix-darwin)"
      Chezmoi["dot_fwknoprc.tmpl<br/>(chezmoi template)"]
      Secrets["~/.secrets/secrets-env/fwknop.env<br/>(per-host key, not committed)"]
      Nix["nix-darwin fleet/default.nix<br/>installs fwknop binary"]
      M1["lzkmbp2016<br/>~/.fwknoprc (user: micro)"]
      M2["lzkmbp2018<br/>~/.fwknoprc (user: micro)"]
    end

    subgraph "Server (Ansible)"
      ServerRole["common-fwknop-server role<br/>deploy-fwknop.yml"]
      AccessConf["/etc/fwknop/access.conf<br/>(all client stanzas)"]
    end

    Vault -->|"selects key by<br/>inventory_hostname"| Ansible
    Ansible --> K
    Ansible --> O

    Vault -->|"manual copy to<br/>~/.secrets/"| Secrets
    Secrets -->|"template reads<br/>FWKNOP_SPA_KEY_<hostname>"| Chezmoi
    Chezmoi --> M1
    Chezmoi --> M2
    Nix --> M1
    Nix --> M2

    Vault -->|"all client keys"| ServerRole
    ServerRole --> AccessConf

    style Vault fill:#ffcc99
    style AccessConf fill:#ff9999
    style Chezmoi fill:#99ccff
    style Secrets fill:#ffcc99
```

### Key selection by hostname

| Machine | Hostname | Username | Key variable | Distribution |
|---------|----------|----------|-------------|-------------|
| kckinai | `kckinai` | `lk` | `vault_fwknop_spa_key_kckinai` | Ansible role |
| lzkmbp2016 | `lzkmbp2016` | `micro` | `vault_fwknop_spa_key_lzkmbp2016` | chezmoi template |
| lzkmbp2018 | `lzkmbp2018` | `micro` | `vault_fwknop_spa_key_lzkmbp2018` | chezmoi template |
| oci-cloud-server | `oci-cloud-server` | `opc` | `vault_fwknop_spa_key_oci_cloud_server` | Ansible role |

## Operational Procedures

### Closing public SSH (require SPA)

```bash
just ansible-deploy-fwknop-close-ssh
```

This adds the iptables DROP rule for public TCP/22. Tailscale and
SPA-opened access remain unaffected.

### Reopening public SSH (disable SPA requirement)

```bash
just ansible-deploy-fwknop
```

This removes the DROP rule. Port 22 is open to the public again. fwknopd
keeps running but the SPA knock is no longer required.

### Adding a new client

1. Generate a key pair:
   ```bash
   fwknop --key-gen --key-len 32 --hmac-key-len 64
   ```
2. Add to vault:
   ```yaml
   vault_fwknop_spa_key_<hostname>: "<KEY_BASE64 value>"
   vault_fwknop_hmac_key_<hostname>: "<HMAC_KEY_BASE64 value>"
   ```
3. Add to `fwknop_clients` in `common-fwknop-server/defaults/main.yml`
4. Add to `fwknop_client_key_map` in `common-fwknop-client/defaults/main.yml`
5. Redeploy server: `just ansible-deploy-fwknop-close-ssh`
6. Deploy client config: `just ansible-deploy-fwknop-client` (Linux)
   or `chezmoi apply` (macOS)

### Revoking a client

1. Remove the client's entry from `fwknop_clients` in the server role
2. Redeploy server: `just ansible-deploy-fwknop-close-ssh`
3. The client's key will no longer match any stanza — SPA packets rejected

### Rotating a client's key

1. Generate a new key pair: `fwknop --key-gen --key-len 32 --hmac-key-len 64`
2. Update the vault entry for that client
3. Redeploy server: `just ansible-deploy-fwknop-close-ssh`
4. Redeploy client: `just ansible-deploy-fwknop-client` or `chezmoi apply`

## Troubleshooting

### SPA knock doesn't work

```mermaid
flowchart TD
    Problem["SPA knock fails"] --> Q1{"fwknop -n oci-cloud-server<br/>sends packet?"}
    Q1 -->|"No"| Fix1["Check ~/.fwknoprc exists<br/>and has keys for this hostname"]
    Q1 -->|"Yes"| Q2{"Server logs show<br/>packet received?"}
    Q2 -->|"No"| Fix2["Check OCI VCN security list<br/>allows UDP 62271"]
    Q2 -->|"Yes, all stanzas fail"| Fix3["Key mismatch —<br/>verify vault key matches<br/>client's ~/.fwknoprc"]
    Q2 -->|"Yes, stanza matched<br/>but SSH still fails"| Q3{"nc can reach<br/>port 22?"}
    Q3 -->|"No"| Fix4["iptables rule expired<br/>(120s window) —<br/>resend knock"]
    Q3 -->|"Yes"| Fix5["SSH key issue —<br/>check IdentityFile<br/>in ssh config"]

    style Problem fill:#ff9999
    style Fix1 fill:#ffcc99
    style Fix2 fill:#ffcc99
    style Fix3 fill:#ffcc99
    style Fix4 fill:#ffcc99
    style Fix5 fill:#ffcc99
```

### Locked out of public SSH

If SPA is broken and you can't reach the server via public IP:

1. **Use Tailscale** (always works, no knock needed):
   ```bash
   ssh oci
   ```
2. **Redeploy fwknop** from the control machine:
   ```bash
   just ansible-deploy-fwknop
   ```
3. **Or reopen port 22** temporarily:
   ```bash
   just ansible-deploy-fwknop  # runs without fwknop_close_public_ssh=true
   ```

### Checking server logs

```bash
# Via Tailscale (always available)
ssh oci 'sudo journalctl -u fwknopd -n 20'

# Look for:
# - "SPA Packet from IP: X received" = packet arrived
# - "Added access rule to FWKNOP_INPUT" = key matched, rule inserted
# - "HMAC_COMPAREFAIL" = wrong key (expected for non-matching stanzas)
# - "Sniffing interface: any" = fwknopd is running
```

### Checking iptables rules

```bash
ssh oci 'sudo iptables -L INPUT -n --line-numbers'
ssh oci 'sudo iptables -L FWKNOP_INPUT -n'
```

The `FWKNOP_INPUT` chain shows temporary ACCEPT rules with expiry
timestamps in the comment field.
