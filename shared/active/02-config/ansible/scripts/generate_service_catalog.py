#!/usr/bin/env python3
"""Generate SERVICES.md — a browsable service catalog from infrastructure YAML files.

Reads:
  - shared/active/02-config/ansible/infrastructure/{ports,domains,networks,services}.yml
  - levonk/active/02-config/ansible/infrastructure/{ports,domains,networks}.yml  (client overrides)

Produces:
  - levonk/SERVICES.md  (in the private client submodule, viewable on GitHub)

The script merges shared + client YAML (client wins), resolves simple {{ var }} references,
and renders three sections:
  1. By Service — every service with its container, machine, domain(s), port(s), network, category
  2. By Category — services grouped by UI / API / Console / Passive / Proxy / VPN / DNS / Security / Infra
  3. Mermaid diagram — all services color-coded by machine, with legend

Usage:
  python3 generate_service_catalog.py [--output PATH]

Run via: just generate-service-catalog
"""
import argparse
import os
import re
import sys
from datetime import datetime
from pathlib import Path

import yaml

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
SCRIPT_DIR = Path(__file__).resolve().parent
INFRAHUB_ROOT = SCRIPT_DIR.parents[4]  # scripts/ → ansible/ → 02-config/ → active/ → shared/ → root

SHARED_INFRA = INFRAHUB_ROOT / "shared" / "active" / "02-config" / "ansible" / "infrastructure"
CLIENT_INFRA = INFRAHUB_ROOT / "levonk" / "active" / "02-config" / "ansible" / "infrastructure"
OUTPUT_DEFAULT = INFRAHUB_ROOT / "levonk" / "SERVICES.md"

# ---------------------------------------------------------------------------
# Machine metadata for the Mermaid legend
# ---------------------------------------------------------------------------
MACHINES = {
    "oci-cloud-server": {
        "label": "OCI Cloud Server (cno)",
        "tailscale": "oci.tale-grouper.ts.net",
        "arch": "arm64",
        "docker_platform": "linux/arm64",
        "color": "#4A90D9",
        "mermaid_class": "machine_oci",
        "ssh_key": "lzkmbp2016-micro-oracle",
        "ansible_user": "opc",
    },
    "kckinai": {
        "label": "kckinai (Inference Host)",
        "tailscale": "kckinai.tale-grouper.ts.net",
        "arch": "arm64",
        "docker_platform": "linux/arm64",
        "color": "#E8743C",
        "mermaid_class": "machine_kckinai",
        "ssh_key": "lzkmbp2016-micro-oracle",
        "ansible_user": "cuser",
    },
    "dtop202311": {
        "label": "dtop202311 (nl — Windows Docker)",
        "tailscale": "dtop202311.tale-grouper.ts.net",
        "arch": "amd64",
        "docker_platform": "linux/amd64",
        "color": "#50C878",
        "mermaid_class": "machine_dtop",
        "ssh_key": "lzkmbp2016-micro-oracle",
        "ansible_user": "ansible",
    },
    "isolation-vm": {
        "label": "Isolation VM (QEMU on OCI)",
        "tailscale": "192.168.100.147 (NAT bridge)",
        "arch": "amd64",
        "docker_platform": "linux/amd64",
        "color": "#9B59B6",
        "mermaid_class": "machine_vm",
        "ssh_key": "lzkmbp2016-micro-oracle",
        "ansible_user": "cuser",
    },
    "lzkmbp2016": {
        "label": "lzkmbp2016 (Laptop — Intel macOS)",
        "tailscale": "lzkmbp2016.tale-grouper.ts.net",
        "arch": "x86_64",
        "docker_platform": "linux/amd64",
        "color": "#F39C12",
        "mermaid_class": "machine_laptop1",
        "ssh_key": "lzkmbp2016-micro-oracle",
        "ansible_user": "auser",
    },
    "lzkmbp2018": {
        "label": "lzkmbp2018 (Laptop — macOS)",
        "tailscale": "lzkmbp2018.tale-grouper.ts.net",
        "arch": "arm64",
        "docker_platform": "linux/arm64",
        "color": "#E67E22",
        "mermaid_class": "machine_laptop2",
        "ssh_key": "lzkmbp2016-micro-oracle",
        "ansible_user": "auser",
    },
}

CATEGORY_ORDER = [
    "ui",
    "api",
    "console",
    "passive",
    "proxy",
    "vpn",
    "dns",
    "security",
    "infra",
]

CATEGORY_LABELS = {
    "ui": "UI (Web Apps)",
    "api": "API (HTTP Services)",
    "console": "Console / Dashboard",
    "passive": "Passive (Databases / Caches / Queues)",
    "proxy": "Proxy Chain (Internal)",
    "vpn": "VPN / Mesh Networking",
    "dns": "DNS",
    "security": "Security / SSO",
    "infra": "Infrastructure",
}

CATEGORY_ICONS = {
    "ui": "🌐",
    "api": "🔌",
    "console": "🖥️",
    "passive": "🗄️",
    "proxy": "🔗",
    "vpn": "🔒",
    "dns": "📡",
    "security": "🛡️",
    "infra": "⚙️",
}


# ---------------------------------------------------------------------------
# YAML loading + merging
# ---------------------------------------------------------------------------
def load_yaml(path: Path) -> dict:
    if not path.exists():
        return {}
    with open(path) as f:
        data = yaml.safe_load(f)
    return data or {}


def merge_yaml(shared: dict, client: dict) -> dict:
    """Merge shared + client. Client keys override shared keys (shallow merge)."""
    result = dict(shared)
    result.update(client)
    return result


def resolve_vars(value, all_vars: dict, _depth: int = 0) -> str:
    """Resolve {{ var_name }} references from all_vars. Handles simple cases only."""
    if _depth > 5:
        return str(value)
    if not isinstance(value, str):
        return str(value)

    def replace_ref(match):
        ref = match.group(1).strip()
        if ref in all_vars:
            return resolve_vars(all_vars[ref], all_vars, _depth + 1)
        return match.group(0)

    return re.sub(r"\{\{\s*([\w.]+)\s*\}\}", replace_ref, value)


# ---------------------------------------------------------------------------
# Service resolution
# ---------------------------------------------------------------------------
def resolve_service(svc: dict, all_vars: dict) -> dict:
    """Resolve all {{ }} references in a service entry."""
    resolved = {}
    for key, val in svc.items():
        if isinstance(val, str):
            resolved[key] = resolve_vars(val, all_vars)
        elif isinstance(val, list):
            resolved[key] = [
                resolve_vars(item, all_vars) if isinstance(item, str) else item for item in val
            ]
        elif isinstance(val, dict):
            resolved[key] = {
                k: resolve_vars(v, all_vars) if isinstance(v, str) else v
                for k, v in val.items()
            }
        else:
            resolved[key] = val
    return resolved


def resolve_domain(var_name: str, all_vars: dict) -> str:
    """Resolve a domain variable name to its value."""
    raw = all_vars.get(var_name, "")
    return resolve_vars(raw, all_vars)


def get_categories(svc: dict) -> list:
    """Get categories from a service — supports 'categories' (list) or 'category' (single)."""
    if "categories" in svc:
        return svc["categories"]
    if "category" in svc:
        return [svc["category"]]
    return ["infra"]


def format_ports(svc: dict) -> str:
    """Format port info as 'host:container (label)' or 'container (label)'."""
    ports = svc.get("ports", [])
    if not ports:
        return "—"
    parts = []
    for p in ports:
        label = p.get("label", "")
        host = p.get("host")
        container = p.get("container")
        if host and container:
            parts.append(f"`{resolve_val(host)}`→`{resolve_val(container)}` ({label})")
        elif container:
            parts.append(f"`{resolve_val(container)}` ({label})")
        elif host:
            parts.append(f"`{resolve_val(host)}` ({label})")
    return "<br>".join(parts)


_val_cache = {}


def resolve_val(var_name_or_literal: str) -> str:
    """If it's an infra_ variable name, look it up from cache. Otherwise return as-is."""
    if var_name_or_literal in _val_cache:
        return _val_cache[var_name_or_literal]
    return var_name_or_literal


def format_domains(svc: dict, all_vars: dict) -> str:
    """Format domain info as clickable links."""
    domain_vars = svc.get("domains", [])
    if not domain_vars:
        return "—"
    parts = []
    for dv in domain_vars:
        if dv.startswith("literal:"):
            domain = dv[len("literal:"):]
            parts.append(f"[{domain}](https://{domain})")
        else:
            domain = resolve_domain(dv, all_vars)
            if domain and not domain.startswith("{{"):
                parts.append(f"[{domain}](https://{domain})")
            else:
                parts.append(f"`{dv}` (unresolved)")
    return "<br>".join(parts)


def format_network(svc: dict, all_vars: dict) -> str:
    """Resolve network name."""
    net = svc.get("network", "")
    if not net:
        return "—"
    if net.startswith("infra_"):
        resolved = resolve_vars(all_vars.get(net, net), all_vars)
        return resolved if resolved and not resolved.startswith("{{") else net
    return net


# ---------------------------------------------------------------------------
# Markdown generation
# ---------------------------------------------------------------------------
def gen_by_service_table(services: list, all_vars: dict) -> str:
    lines = [
        "| Service | Container | Machine | Domain(s) | Port(s) (host→container) | Network | Category |",
        "|---------|-----------|---------|-----------|--------------------------|---------|----------|",
    ]
    for svc in sorted(services, key=lambda s: s["name"].lower()):
        name = svc["name"]
        container = svc.get("container", "—")
        machine = svc.get("machine", "—")
        machine_label = MACHINES.get(machine, {}).get("label", machine)
        domains = format_domains(svc, all_vars)
        ports = format_ports_with_vars(svc, all_vars)
        network = format_network(svc, all_vars)
        cat = svc.get("category", "—")
        cats = get_categories(svc)
        cat_labels = ", ".join(CATEGORY_LABELS.get(c, c) for c in cats)
        lines.append(
            f"| {name} | `{container}` | {machine_label} | {domains} | {ports} | {network} | {cat_labels} |"
        )
    return "\n".join(lines)


def format_ports_with_vars(svc: dict, all_vars: dict) -> str:
    """Format ports, resolving infra_ variable references."""
    ports = svc.get("ports", [])
    if not ports:
        return "—"
    parts = []
    for p in ports:
        label = p.get("label", "")
        host = p.get("host")
        container = p.get("container")
        host_val = resolve_port_val(host, all_vars) if host else None
        container_val = resolve_port_val(container, all_vars) if container else None
        if host_val and container_val:
            parts.append(f"`{host_val}`→`{container_val}` ({label})")
        elif container_val:
            parts.append(f"`{container_val}` ({label})")
        elif host_val:
            parts.append(f"`{host_val}` ({label})")
    return "<br>".join(parts)


def resolve_port_val(var_name_or_literal: str, all_vars: dict) -> str:
    """Resolve a port value — could be an infra_ variable name or a literal."""
    if not var_name_or_literal:
        return ""
    if var_name_or_literal.startswith("infra_"):
        raw = all_vars.get(var_name_or_literal, var_name_or_literal)
        return resolve_vars(raw, all_vars)
    return var_name_or_literal


def gen_by_category_sections(services: list, all_vars: dict) -> str:
    sections = []
    for cat in CATEGORY_ORDER:
        cat_svcs = [s for s in services if cat in get_categories(s)]
        if not cat_svcs:
            continue
        icon = CATEGORY_ICONS.get(cat, "")
        label = CATEGORY_LABELS.get(cat, cat)
        sections.append(f"### {icon} {label}\n")
        sections.append(
            "| Service | Container | Machine | Domain(s) | Port(s) | Network |"
        )
        sections.append(
            "|---------|-----------|---------|-----------|---------|---------|"
        )
        for svc in sorted(cat_svcs, key=lambda s: s["name"].lower()):
            name = svc["name"]
            container = svc.get("container", "—")
            machine = svc.get("machine", "—")
            machine_label = MACHINES.get(machine, {}).get("label", machine)
            domains = format_domains(svc, all_vars)
            ports = format_ports_with_vars(svc, all_vars)
            network = format_network(svc, all_vars)
            sections.append(
                f"| {name} | `{container}` | {machine_label} | {domains} | {ports} | {network} |"
            )
        sections.append("")
    return "\n".join(sections)


def gen_mermaid_diagram(services: list, all_vars: dict) -> str:
    """Generate a Mermaid flowchart with services grouped by machine."""
    lines = ["```mermaid", "---", "title: Levonk Service Topology", "---", "flowchart TD"]

    # Subgraphs per machine
    for machine_key, meta in MACHINES.items():
        machine_svcs = [s for s in services if s.get("machine") == machine_key]
        if not machine_svcs:
            continue
        safe_id = machine_key.replace("-", "_")
        lines.append(f'    subgraph {safe_id}["{meta["label"]}"]')
        for svc in sorted(machine_svcs, key=lambda s: s["name"].lower()):
            node_id = sanitize_node_id(svc["name"])
            cats = get_categories(svc)
            icon = CATEGORY_ICONS.get(cats[0], "")
            lines.append(f'        {node_id}["{icon} {svc["name"]}"]')
        lines.append("    end")

    # AI pipeline chain connections
    lines.append("")
    lines.append("    %% AI Pipeline Chain (request flow)")
    chain = ["LiteLLM", "Privacy Orchestrator", "Forge", "Headroom", "iron-proxy", "OmniRoute"]
    for i in range(len(chain) - 1):
        a = sanitize_node_id(chain[i])
        b = sanitize_node_id(chain[i + 1])
        lines.append(f"    {a} --> {b}")

    # LiteLLM → Langfuse (trace forwarding)
    lines.append("    %% Trace forwarding")
    lines.append(f"    {sanitize_node_id('LiteLLM')} -.-> {sanitize_node_id('Langfuse Web')}")

    # Traefik → UI services
    lines.append("")
    lines.append("    %% Traefik routes to UI/API services")
    traefik_routed = [s for s in services if s.get("traefik") and s["name"] != "Traefik"]
    for svc in traefik_routed:
        node_id = sanitize_node_id(svc["name"])
        lines.append(f"    {sanitize_node_id('Traefik')} --> {node_id}")

    # Authelia ← Traefik (auth middleware)
    lines.append("")
    lines.append("    %% Auth middleware")
    lines.append(f"    {sanitize_node_id('Traefik')} -.-> {sanitize_node_id('Authelia')}")

    # CrowdSec ← Traefik
    lines.append(f"    {sanitize_node_id('Traefik')} -.-> {sanitize_node_id('CrowdSec')}")

    # SearXNG → NordVPN
    lines.append("")
    lines.append("    %% SearXNG routes through NordVPN")
    lines.append(f"    {sanitize_node_id('SearXNG')} -.-> {sanitize_node_id('NordVPN')}")

    # JobOps cross-machine (Traefik on OCI → JobOps on dtop202311)
    lines.append("")
    lines.append("    %% Cross-machine: Traefik (OCI) → JobOps (Windows Docker)")
    lines.append(f"    {sanitize_node_id('Traefik')} -.-> {sanitize_node_id('JobOps')}")

    # Passive DB connections
    lines.append("")
    lines.append("    %% Database connections")
    db_connections = [
        ("LiteLLM", "LiteLLM Postgres"),
        ("LiteLLM", "LiteLLM Redis"),
        ("Omnigent", "Omnigent Postgres"),
        ("Omnigent", "Pi"),
        ("Authelia", "Authelia Postgres"),
        ("Langfuse Web", "Langfuse Postgres"),
        ("Langfuse Web", "Langfuse ClickHouse"),
        ("Langfuse Web", "Langfuse Redis"),
        ("Langfuse Web", "Langfuse MinIO"),
        ("Langfuse Web", "Langfuse Worker"),
        ("WorldMonitor", "WorldMonitor Redis"),
    ]
    for parent, child in db_connections:
        lines.append(f"    {sanitize_node_id(parent)} -.-> {sanitize_node_id(child)}")

    # Styling — color by machine
    lines.append("")
    lines.append("    %% Machine color coding")
    for machine_key, meta in MACHINES.items():
        machine_svcs = [s for s in services if s.get("machine") == machine_key]
        if not machine_svcs:
            continue
        node_ids = [sanitize_node_id(s["name"]) for s in machine_svcs]
        if node_ids:
            lines.append(f'    classDef {meta["mermaid_class"]} fill:{meta["color"]},color:#fff,stroke:#333,stroke-width:1px')
            class_str = ",".join(node_ids)
            lines.append(f'    class {class_str} {meta["mermaid_class"]}')

    lines.append("```")
    return "\n".join(lines)


def gen_mermaid_legend(services: list, all_vars: dict) -> str:
    """Generate a legend showing machines grouped by physical network (cloud vs local)."""
    # Physical network mapping
    # cno = cloud network oracle (OCI ARM64)
    # nl  = network local (dtop202311 X86 Windows Docker Desktop, kckinai inference host)
    PHYSICAL_NETWORKS = {
        "cno (Cloud Network Oracle)": ["oci-cloud-server", "isolation-vm"],
        "nl (Network Local)": ["kckinai", "dtop202311"],
        "Laptops (Roaming)": ["lzkmbp2016", "lzkmbp2018"],
    }

    lines = ["```mermaid", "---", "title: Physical Network Topology", "---", "flowchart LR"]

    for net_name, machine_keys in PHYSICAL_NETWORKS.items():
        net_id = f"phys_{sanitize_node_id(net_name)}"
        label = net_name
        lines.append(f'    subgraph {net_id}["{label}"]')
        for machine_key in machine_keys:
            if machine_key not in MACHINES:
                continue
            meta = MACHINES[machine_key]
            node_id = f"legend_{machine_key.replace('-', '_')}"
            lines.append(f'        {node_id}["{meta["label"]}"]')
        lines.append("    end")

    # Color-code by machine
    lines.append("")
    lines.append("    %% Machine colors")
    for machine_key, meta in MACHINES.items():
        node_id = f"legend_{machine_key.replace('-', '_')}"
        lines.append(f'    classDef {meta["mermaid_class"]}_leg fill:{meta["color"]},color:#fff,stroke:#333')
        lines.append(f'    class {node_id} {meta["mermaid_class"]}_leg')

    lines.append("```")
    return "\n".join(lines)


def sanitize_node_id(name: str) -> str:
    """Convert a service name to a valid Mermaid node ID."""
    return re.sub(r"[^a-zA-Z0-9_]", "_", name)


def gen_toc(services: list) -> str:
    """Generate a table of contents for the markdown document."""
    lines = ["## Table of Contents", ""]
    lines.append("- [Machine Legend](#machine-legend)")
    lines.append("- [Service Topology](#service-topology)")
    lines.append("- [All Services (Alphabetical)](#all-services-alphabetical)")
    lines.append("- [Services by Category](#services-by-category)")
    # Sub-entries for each category that has services
    present_cats = set()
    for s in services:
        present_cats.update(get_categories(s))
    for cat in CATEGORY_ORDER:
        if cat not in present_cats:
            continue
        label = CATEGORY_LABELS.get(cat, cat)
        icon = CATEGORY_ICONS.get(cat, "")
        anchor = label.lower().replace(" / ", "-").replace(" ", "-").replace("(", "").replace(")", "").replace("/", "-")
        lines.append(f"  - [{icon} {label}](#{anchor})")
    lines.append("- [Machine Reference](#machine-reference)")
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main():
    parser = argparse.ArgumentParser(description="Generate SERVICES.md from infrastructure YAML")
    parser.add_argument("--output", type=Path, default=OUTPUT_DEFAULT, help="Output file path")
    args = parser.parse_args()

    # Load all infrastructure YAML files
    shared_ports = load_yaml(SHARED_INFRA / "ports.yml")
    client_ports = load_yaml(CLIENT_INFRA / "ports.yml")
    shared_domains = load_yaml(SHARED_INFRA / "domains.yml")
    client_domains = load_yaml(CLIENT_INFRA / "domains.yml")
    shared_networks = load_yaml(SHARED_INFRA / "networks.yml")
    client_networks = load_yaml(CLIENT_INFRA / "networks.yml")
    services_raw = load_yaml(SHARED_INFRA / "services.yml")

    # Merge shared + client (client wins)
    all_ports = merge_yaml(shared_ports, client_ports)
    all_domains = merge_yaml(shared_domains, client_domains)
    all_networks = merge_yaml(shared_networks, client_networks)

    # Combine all vars for resolution
    all_vars = {}
    all_vars.update(all_ports)
    all_vars.update(all_domains)
    all_vars.update(all_networks)

    # Services can be a top-level list or under a "services:" key
    if isinstance(services_raw, list):
        services = services_raw
    elif isinstance(services_raw, dict):
        services = services_raw.get("services", [])
    else:
        services = []

    if not services:
        print("ERROR: No services found in services.yml", file=sys.stderr)
        sys.exit(1)

    resolved_services = [resolve_service(svc, all_vars) for svc in services]

    # Generate markdown
    now = datetime.now().strftime("%Y-%m-%d %H:%M")

    md_parts = []
    md_parts.append("# Levonk Service Catalog")
    md_parts.append("")
    md_parts.append(f"> **Auto-generated** from `infrastructure/*.yml` — last updated: {now}")
    md_parts.append(f"> Regenerate with: `just generate-service-catalog`")
    md_parts.append(f"> Source: `shared/active/02-config/ansible/infrastructure/services.yml`")
    md_parts.append("")

    # Quick stats
    total = len(resolved_services)
    by_machine = {}
    for s in resolved_services:
        m = s.get("machine", "unknown")
        by_machine[m] = by_machine.get(m, 0) + 1
    stats_parts = [f"**{total} services** across {len(by_machine)} machines:"]
    for mkey in MACHINES:
        if mkey in by_machine:
            stats_parts.append(f"  - {MACHINES[mkey]['label']}: {by_machine[mkey]}")
    md_parts.append("\n".join(stats_parts))
    md_parts.append("")

    # Table of contents
    md_parts.append(gen_toc(resolved_services))
    md_parts.append("")

    # Mermaid legend
    md_parts.append("## Machine Legend")
    md_parts.append("")
    md_parts.append(gen_mermaid_legend(resolved_services, all_vars))
    md_parts.append("")

    # Topology diagram
    md_parts.append("## Service Topology")
    md_parts.append("")
    md_parts.append(gen_mermaid_diagram(resolved_services, all_vars))
    md_parts.append("")

    # By Service
    md_parts.append("## All Services (Alphabetical)")
    md_parts.append("")
    md_parts.append(gen_by_service_table(resolved_services, all_vars))
    md_parts.append("")

    # By Category
    md_parts.append("## Services by Category")
    md_parts.append("")
    md_parts.append(gen_by_category_sections(resolved_services, all_vars))

    # Machine reference
    md_parts.append("## Machine Reference")
    md_parts.append("")
    md_parts.append("| Machine | Tailscale FQDN | Arch | SSH Key | Ansible User | DDNS | Description |")
    md_parts.append("|---------|----------------|------|---------|--------------|------|-------------|")
    for mkey, meta in MACHINES.items():
        ddns = f"{mkey.replace('-cloud-server','')}.mach.levonk.com" if mkey != "isolation-vm" else "—"
        if mkey == "oci-cloud-server":
            ddns = "oci.mach.levonk.com"
        arch = meta.get("arch", "—")
        ssh_key = meta.get("ssh_key", "—")
        ansible_user = meta.get("ansible_user", "—")
        md_parts.append(f"| {meta['label']} | `{meta['tailscale']}` | `{arch}` | `~/.ssh/{ssh_key}` | `{ansible_user}` | `{ddns}` | |")
    md_parts.append("")

    md_parts.append("---")
    md_parts.append("")
    md_parts.append("*This file is generated by `generate_service_catalog.py`. Do not edit manually.*")
    md_parts.append(
        "*To add a service: add its ports/domains to the infrastructure YAML files, "
        "add an entry to `services.yml`, then run `just generate-service-catalog`.*"
    )

    output_text = "\n".join(md_parts) + "\n"

    # Write output
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with open(args.output, "w") as f:
        f.write(output_text)

    print(f"Generated {args.output} ({total} services, {len(by_machine)} machines)")


if __name__ == "__main__":
    main()
