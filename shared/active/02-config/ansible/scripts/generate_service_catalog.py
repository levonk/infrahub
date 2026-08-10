#!/usr/bin/env python3
"""Generate SERVICES.md — a browsable service catalog from infrastructure YAML files.

Reads:
  - shared/active/02-config/ansible/infrastructure/{ports,domains,networks,services,storage}.yml
  - levonk/active/02-config/ansible/infrastructure/{ports,domains,networks,storage}.yml  (client overrides)

Produces:
  - levonk/SERVICES.md  (in the private client submodule, viewable on GitHub)
  - infrahub/SERVICES.md  (repo-root, shared-defaults-only catalog — use --shared-only)

The script merges shared + client YAML (client wins), resolves simple {{ var }} references,
and renders three sections:
  1. By Service — every service with its container, machine, domain(s), port(s), network, storage, category
  2. By Category — services grouped by UI / API / Console / Passive / Proxy / VPN / DNS / Security / Infra
  3. Mermaid diagram — all services color-coded by machine, with legend

Usage:
  python3 generate_service_catalog.py [--output PATH] [--shared-only]

Run via:
  just generate-service-catalog              # levonk/SERVICES.md (client-specific)
  just generate-service-catalog-shared       # infrahub/SERVICES.md (shared defaults only)

The --shared-only flag produces a repo-root catalog that shows only shared default
ports, suggested hostnames (no custom domain names), and no deployed machine info.
This is useful for the public repo view where client-specific deployment details
should not be exposed.
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
# Machine metadata — loaded from client-specific YAML (see machines.yml)
# ---------------------------------------------------------------------------
MACHINES_YML = CLIENT_INFRA / "machines.yml"

def _load_machines():
    """Load machine metadata from levonk/active/02-config/ansible/infrastructure/machines.yml.

    Returns (machines_dict, physical_networks_dict). Falls back to empty
    dicts if the file doesn't exist (e.g. --shared-only mode).
    """
    if not MACHINES_YML.exists():
        return {}, {}
    with open(MACHINES_YML) as f:
        data = yaml.safe_load(f) or {}
    return data.get("machines", {}), data.get("physical_networks", {})

MACHINES, PHYSICAL_NETWORKS = _load_machines()

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


def format_source_repo(svc: dict) -> str:
    """Format source_repo as a clickable link. Returns '⚠ MISSING' if not set."""
    repo = svc.get("source_repo", "")
    if not repo:
        return "⚠ MISSING"
    # Extract a short label from the URL for display
    # e.g. https://github.com/BerriAI/litellm -> BerriAI/litellm
    # e.g. https://www.qemu.org/ -> qemu.org
    if "github.com/" in repo:
        parts = repo.split("github.com/", 1)[1]
        label = parts.rstrip("/")
    elif "gitlab.com/" in repo:
        parts = repo.split("gitlab.com/", 1)[1]
        label = parts.rstrip("/")
    else:
        # Product page — use the domain
        label = repo.replace("https://", "").replace("http://", "").rstrip("/")
        # Truncate long product page URLs
        if len(label) > 40:
            label = label[:37] + "..."
    return f"[{label}]({repo})"


def format_storage(svc: dict, all_vars: dict) -> str:
    """Format storage/volume info for a service.

    Looks for storage variables matching the service name pattern:
    infra_storage_{service}_volume, infra_storage_{service}_data,
    infra_storage_{service}_config, infra_storage_{service}_data_volume,
    infra_storage_{service}_config_volume.
    """
    name = svc.get("name", "")
    # Build candidate service slugs from the service name (lowercase, no spaces)
    slug = name.lower().replace(" ", "").replace("-", "_").replace(".", "_")
    # Also try with underscores converted (e.g., "LiteLLM Postgres" -> "litellm_postgres")
    slug_alt = name.lower().replace(" ", "_").replace("-", "_").replace(".", "_")

    candidates = [
        f"infra_storage_{slug}_volume",
        f"infra_storage_{slug}_data_volume",
        f"infra_storage_{slug}_config_volume",
        f"infra_storage_{slug}_data",
        f"infra_storage_{slug}_config",
        f"infra_storage_{slug_alt}_volume",
        f"infra_storage_{slug_alt}_data_volume",
        f"infra_storage_{slug_alt}_config_volume",
        f"infra_storage_{slug_alt}_data",
        f"infra_storage_{slug_alt}_config",
    ]

    found = []
    seen = set()
    for var_name in candidates:
        if var_name in all_vars and var_name not in seen:
            seen.add(var_name)
            val = resolve_vars(all_vars[var_name], all_vars)
            if val and not val.startswith("{{"):
                # Distinguish volumes (named docker volumes) from paths
                if "_volume" in var_name:
                    found.append(f"`{val}` (volume)")
                else:
                    found.append(f"`{val}`")

    if not found:
        return "—"
    return "<br>".join(found)


# ---------------------------------------------------------------------------
# Markdown generation
# ---------------------------------------------------------------------------
def gen_by_service_table(services: list, all_vars: dict, shared_only: bool = False) -> str:
    if shared_only:
        lines = [
            "| Service | Container | Suggested Hostname | Port(s) (default) | Network | Storage | Category | Source |",
            "|---------|-----------|--------------------|-------------------|---------|---------|----------|--------|",
        ]
    else:
        lines = [
            "| Service | Container | Machine | Domain(s) | Port(s) (host→container) | Network | Storage | Category | Source |",
            "|---------|-----------|---------|-----------|--------------------------|---------|---------|----------|--------|",
        ]
    for svc in sorted(services, key=lambda s: s["name"].lower()):
        name = svc["name"]
        container = svc.get("container", "—")
        ports = format_ports_with_vars(svc, all_vars)
        network = format_network(svc, all_vars)
        storage = format_storage(svc, all_vars)
        cats = get_categories(svc)
        cat_labels = ", ".join(CATEGORY_LABELS.get(c, c) for c in cats)
        source = format_source_repo(svc)
        if shared_only:
            # In shared-only mode: show suggested hostname (from domain var name), no machine, no custom domain
            hostname = format_suggested_hostname(svc, all_vars)
            lines.append(
                f"| {name} | `{container}` | {hostname} | {ports} | {network} | {storage} | {cat_labels} | {source} |"
            )
        else:
            machine = svc.get("machine", "—")
            machine_label = MACHINES.get(machine, {}).get("label", machine)
            domains = format_domains(svc, all_vars)
            lines.append(
                f"| {name} | `{container}` | {machine_label} | {domains} | {ports} | {network} | {storage} | {cat_labels} | {source} |"
            )
    return "\n".join(lines)


def format_suggested_hostname(svc: dict, all_vars: dict) -> str:
    """Format a suggested hostname for shared-only mode.

    Shows the domain variable name (e.g., infra_domain_ai_litellm) as a suggestion,
    rather than the resolved client-specific domain value. If no domain var, returns '—'.
    """
    domain_vars = svc.get("domains", [])
    if not domain_vars:
        return "—"
    parts = []
    for dv in domain_vars:
        if dv.startswith("literal:"):
            parts.append(f"`{dv[len('literal:'):]}` (literal)")
        elif dv.startswith("infra_"):
            parts.append(f"`{dv}` (suggested)")
        else:
            parts.append(f"`{dv}`")
    return "<br>".join(parts)


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


def gen_by_category_sections(services: list, all_vars: dict, shared_only: bool = False) -> str:
    sections = []
    for cat in CATEGORY_ORDER:
        cat_svcs = [s for s in services if cat in get_categories(s)]
        if not cat_svcs:
            continue
        icon = CATEGORY_ICONS.get(cat, "")
        label = CATEGORY_LABELS.get(cat, cat)
        sections.append(f"### {icon} {label}\n")
        if shared_only:
            sections.append(
                "| Service | Container | Suggested Hostname | Port(s) (default) | Network | Storage | Source |"
            )
            sections.append(
                "|---------|-----------|--------------------|-------------------|---------|---------|--------|"
            )
        else:
            sections.append(
                "| Service | Container | Machine | Domain(s) | Port(s) | Network | Storage | Source |"
            )
            sections.append(
                "|---------|-----------|---------|-----------|---------|---------|---------|--------|"
            )
        for svc in sorted(cat_svcs, key=lambda s: s["name"].lower()):
            name = svc["name"]
            container = svc.get("container", "—")
            ports = format_ports_with_vars(svc, all_vars)
            network = format_network(svc, all_vars)
            storage = format_storage(svc, all_vars)
            source = format_source_repo(svc)
            if shared_only:
                hostname = format_suggested_hostname(svc, all_vars)
                sections.append(
                    f"| {name} | `{container}` | {hostname} | {ports} | {network} | {storage} | {source} |"
                )
            else:
                machine = svc.get("machine", "—")
                machine_label = MACHINES.get(machine, {}).get("label", machine)
                domains = format_domains(svc, all_vars)
                sections.append(
                    f"| {name} | `{container}` | {machine_label} | {domains} | {ports} | {network} | {storage} | {source} |"
                )
        sections.append("")
    return "\n".join(sections)


def gen_mermaid_diagram(services: list, all_vars: dict, chains: list = None) -> str:
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

    # Data-driven chain connections (replaces hardcoded AI pipeline)
    if chains:
        chain_connections = get_chain_connections(chains)
        lines.append("")
        lines.append("    %% Service chain connections (data-driven from services.yml)")
        for src, tgt, role in chain_connections:
            a = sanitize_node_id(src)
            b = sanitize_node_id(tgt)
            if role:
                lines.append(f"    {a} -->|{role}| {b}")
            else:
                lines.append(f"    {a} --> {b}")
    else:
        # Fallback: no chains defined — no chain connections
        pass

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
    # Physical networks are loaded from machines.yml (client-specific)
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


def sanitize_chain_id(name: str) -> str:
    """Convert a chain name to a valid Mermaid subgraph/node ID prefix."""
    return re.sub(r"[^a-zA-Z0-9_]", "_", name)


def gen_chains_section(chains: list, services: list, all_vars: dict) -> str:
    """Generate a Mermaid diagram per chain, showing request flow and branch points.

    Each chain gets its own Mermaid block with:
    - Linear flow: A --> B --> C
    - Fan-out: A --> B, B --> C1, B --> C2 (branches)
    - Edge labels from 'role' fields
    - External upstreams rendered as cloud-shaped nodes
    - Service nodes colored by machine (same classDef as main topology)
    """
    if not chains:
        return ""

    # Build a lookup: service name → service dict (for machine info)
    svc_by_name = {}
    for svc in services:
        svc_by_name[svc["name"]] = svc

    sections = []
    for chain in chains:
        chain_name = chain.get("name", "Unnamed Chain")
        chain_desc = chain.get("description", "")
        chain_id = sanitize_chain_id(chain_name)
        flow = chain.get("flow", [])

        lines = ["```mermaid", "---", f"title: {chain_name}", "---", "flowchart TD"]

        # Track which machine classes are used in this chain for styling
        used_machines = set()
        # Track all node IDs that are services (for machine coloring)
        svc_node_ids = set()

        # Render nodes and edges
        prev_node = None
        for i, step in enumerate(flow):
            svc_name = step.get("service")
            role = step.get("role", "")
            branches = step.get("branches", [])

            if svc_name:
                node_id = sanitize_node_id(svc_name)
                svc_node_ids.add(node_id)
                # Determine machine for coloring
                svc = svc_by_name.get(svc_name)
                if svc:
                    machine = svc.get("machine", "")
                    if machine:
                        used_machines.add(machine)
                # Node label — just the service name
                lines.append(f'    {node_id}["{svc_name}"]')
            else:
                node_id = None

            # Connect from previous step to this step
            if prev_node and node_id:
                if role:
                    lines.append(f"    {prev_node} -->|{role}| {node_id}")
                else:
                    lines.append(f"    {prev_node} --> {node_id}")

            # Handle branches (fan-out from this step)
            if branches:
                for branch in branches:
                    b_svc = branch.get("service")
                    b_upstream = branch.get("upstream")
                    b_role = branch.get("role", "")

                    if b_svc:
                        b_node_id = sanitize_node_id(b_svc)
                        svc_node_ids.add(b_node_id)
                        b_svc_obj = svc_by_name.get(b_svc)
                        if b_svc_obj:
                            b_machine = b_svc_obj.get("machine", "")
                            if b_machine:
                                used_machines.add(b_machine)
                        lines.append(f'    {b_node_id}["{b_svc}"]')
                        if node_id:
                            if b_role:
                                lines.append(f"    {node_id} -->|{b_role}| {b_node_id}")
                            else:
                                lines.append(f"    {node_id} --> {b_node_id}")
                    elif b_upstream:
                        # External upstream — cloud-shaped node
                        b_node_id = sanitize_chain_id(b_upstream) + f"_{chain_id}"
                        # Extract short label from URL
                        short = b_upstream.replace("https://", "").replace("http://", "").rstrip("/")
                        lines.append(f'    {b_node_id}[("{short}")]')
                        if node_id:
                            if b_role:
                                lines.append(f"    {node_id} -.->|{b_role}| {b_node_id}")
                            else:
                                lines.append(f"    {node_id} -.-> {b_node_id}")

            if node_id:
                prev_node = node_id

        # Machine color coding for service nodes in this chain
        lines.append("")
        lines.append("    %% Machine color coding")
        for machine_key in used_machines:
            meta = MACHINES.get(machine_key)
            if not meta:
                continue
            # Find service node IDs on this machine within this chain
            machine_svc_ids = []
            for nid in svc_node_ids:
                # Reverse-lookup: node_id → service name → service dict → machine
                for svc in services:
                    if sanitize_node_id(svc["name"]) == nid and svc.get("machine") == machine_key:
                        machine_svc_ids.append(nid)
            if machine_svc_ids:
                cls = f"{meta['mermaid_class']}_{chain_id}"
                lines.append(f'    classDef {cls} fill:{meta["color"]},color:#fff,stroke:#333,stroke-width:1px')
                lines.append(f'    class {",".join(machine_svc_ids)} {cls}')

        lines.append("```")
        sections.append(f"### {chain_name}\n")
        if chain_desc:
            sections.append(f"*{chain_desc}*\n")
        sections.append("\n".join(lines))
        sections.append("")

    return "\n".join(sections)


def get_chain_connections(chains: list) -> list:
    """Extract all (source_service, target_service) pairs from chains for the main topology diagram.

    Returns a list of (source, target, role) tuples where source/target are service names.
    External upstreams are excluded (they're not service nodes in the main topology).
    """
    connections = []
    for chain in chains:
        flow = chain.get("flow", [])
        prev_svc = None
        for step in flow:
            svc_name = step.get("service")
            role = step.get("role", "")
            branches = step.get("branches", [])

            # Linear connection from previous to current
            if prev_svc and svc_name:
                connections.append((prev_svc, svc_name, role))

            # Branch connections
            if branches:
                for branch in branches:
                    b_svc = branch.get("service")
                    b_role = branch.get("role", "")
                    if b_svc and svc_name:
                        connections.append((svc_name, b_svc, b_role))

            if svc_name:
                prev_svc = svc_name
    return connections


def gen_toc(services: list, chains: list = None) -> str:
    """Generate a table of contents for the markdown document."""
    lines = ["## Table of Contents", ""]
    lines.append("- [Machine Legend](#machine-legend)")
    lines.append("- [Service Topology](#service-topology)")
    if chains:
        lines.append("- [Service Chains](#service-chains)")
        for chain in chains:
            chain_name = chain.get("name", "")
            if chain_name:
                anchor = chain_name.lower().replace(" ", "-").replace("(", "").replace(")", "")
                lines.append(f"  - [{chain_name}](#{anchor})")
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


def gen_toc_shared(services: list, chains: list = None) -> str:
    """Generate a table of contents for the shared-only catalog (no machine sections)."""
    lines = ["## Table of Contents", ""]
    if chains:
        lines.append("- [Service Chains](#service-chains)")
        for chain in chains:
            chain_name = chain.get("name", "")
            if chain_name:
                anchor = chain_name.lower().replace(" ", "-").replace("(", "").replace(")", "")
                lines.append(f"  - [{chain_name}](#{anchor})")
    lines.append("- [All Services (Alphabetical)](#all-services-alphabetical)")
    lines.append("- [Services by Category](#services-by-category)")
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
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main():
    parser = argparse.ArgumentParser(description="Generate SERVICES.md from infrastructure YAML")
    parser.add_argument("--output", type=Path, default=OUTPUT_DEFAULT, help="Output file path")
    parser.add_argument(
        "--shared-only",
        action="store_true",
        help="Generate a shared-defaults-only catalog (no client overrides, no deployed machines, "
        "default ports only, suggested hostnames instead of custom domains). "
        "Use this for the repo-root SERVICES.md.",
    )
    args = parser.parse_args()

    shared_only = args.shared_only

    # Load all infrastructure YAML files
    shared_ports = load_yaml(SHARED_INFRA / "ports.yml")
    shared_domains = load_yaml(SHARED_INFRA / "domains.yml")
    shared_networks = load_yaml(SHARED_INFRA / "networks.yml")
    shared_storage = load_yaml(SHARED_INFRA / "storage.yml")
    services_raw = load_yaml(SHARED_INFRA / "services.yml")

    if shared_only:
        # Shared-defaults-only mode: skip client overrides entirely
        all_ports = shared_ports
        all_domains = shared_domains
        all_networks = shared_networks
        all_storage = shared_storage
    else:
        # Full mode: merge shared + client (client wins)
        client_ports = load_yaml(CLIENT_INFRA / "ports.yml")
        client_domains = load_yaml(CLIENT_INFRA / "domains.yml")
        client_networks = load_yaml(CLIENT_INFRA / "networks.yml")
        client_storage = load_yaml(CLIENT_INFRA / "storage.yml")
        all_ports = merge_yaml(shared_ports, client_ports)
        all_domains = merge_yaml(shared_domains, client_domains)
        all_networks = merge_yaml(shared_networks, client_networks)
        all_storage = merge_yaml(shared_storage, client_storage)

    # Combine all vars for resolution
    all_vars = {}
    all_vars.update(all_ports)
    all_vars.update(all_domains)
    all_vars.update(all_networks)
    all_vars.update(all_storage)

    # Services can be a top-level list or under a "services:" key
    # Chains are optional, under a "chains:" key (only when services_raw is a dict)
    chains = []
    if isinstance(services_raw, list):
        services = services_raw
    elif isinstance(services_raw, dict):
        services = services_raw.get("services", [])
        chains = services_raw.get("chains", [])
    else:
        services = []

    if not services:
        print("ERROR: No services found in services.yml", file=sys.stderr)
        sys.exit(1)

    resolved_services = [resolve_service(svc, all_vars) for svc in services]

    # Validate source_repo presence — warn for missing entries
    missing_source = [s["name"] for s in services if not s.get("source_repo")]
    if missing_source:
        print("\n⚠ WARNING: The following services are missing 'source_repo' in services.yml:", file=sys.stderr)
        for name in missing_source:
            print(f"  - {name}", file=sys.stderr)
        print(f"\nTotal: {len(missing_source)} service(s) missing source_repo.", file=sys.stderr)
        print("Every service entry MUST have a source_repo field linking to its", file=sys.stderr)
        print("primary source repository or product page.", file=sys.stderr)
        print("See: infrahub-add-new-service.md → Phase 2f\n", file=sys.stderr)

    # Generate markdown
    now = datetime.now().strftime("%Y-%m-%d %H:%M")

    md_parts = []
    if shared_only:
        md_parts.append("# Infrahub Service Catalog (Shared Defaults)")
        md_parts.append("")
        md_parts.append(f"> **Auto-generated** from `infrastructure/*.yml` (shared defaults only) — last updated: {now}")
        md_parts.append(f"> Regenerate with: `just generate-service-catalog-shared`")
        md_parts.append(f"> Source: `shared/active/02-config/ansible/infrastructure/services.yml`")
        md_parts.append(f"> Note: This catalog shows **default ports and suggested hostnames** only. "
                        "Client-specific deployment details (custom domains, deployed machines, "
                        "client port overrides) are not included. See `levonk/SERVICES.md` for the "
                        "deployed client catalog.")
        md_parts.append("")
    else:
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
    if shared_only:
        stats_parts = [f"**{total} services** (shared defaults — no deployment info)"]
    else:
        stats_parts = [f"**{total} services** across {len(by_machine)} machines:"]
        for mkey in MACHINES:
            if mkey in by_machine:
                stats_parts.append(f"  - {MACHINES[mkey]['label']}: {by_machine[mkey]}")
    md_parts.append("\n".join(stats_parts))
    md_parts.append("")

    # Table of contents — shared-only mode skips machine legend and topology
    if shared_only:
        md_parts.append(gen_toc_shared(resolved_services, chains))
    else:
        md_parts.append(gen_toc(resolved_services, chains))
    md_parts.append("")

    if not shared_only:
        # Mermaid legend (client mode only — shows deployed machines)
        md_parts.append("## Machine Legend")
        md_parts.append("")
        md_parts.append(gen_mermaid_legend(resolved_services, all_vars))
        md_parts.append("")

        # Topology diagram (client mode only — shows deployment topology)
        md_parts.append("## Service Topology")
        md_parts.append("")
        md_parts.append(gen_mermaid_diagram(resolved_services, all_vars, chains))
        md_parts.append("")

    # Service Chains (both modes — chains are shared defaults, not client-specific)
    if chains:
        md_parts.append("## Service Chains")
        md_parts.append("")
        md_parts.append(gen_chains_section(chains, resolved_services, all_vars))

    # By Service
    md_parts.append("## All Services (Alphabetical)")
    md_parts.append("")
    md_parts.append(gen_by_service_table(resolved_services, all_vars, shared_only=shared_only))
    md_parts.append("")

    # By Category
    md_parts.append("## Services by Category")
    md_parts.append("")
    md_parts.append(gen_by_category_sections(resolved_services, all_vars, shared_only=shared_only))

    if not shared_only:
        # Machine reference (client mode only — contains client-specific SSH/Tailscale info)
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
    if shared_only:
        md_parts.append(
            "*To add a service: add its ports/domains/storage to the shared infrastructure YAML files, "
            "add an entry to `services.yml` (including `source_repo`), then run "
            "`just generate-service-catalog-shared` (repo root) and `just generate-service-catalog` (client).*"
        )
    else:
        md_parts.append(
            "*To add a service: add its ports/domains/storage to the infrastructure YAML files, "
            "add an entry to `services.yml` (including `source_repo`), then run `just generate-service-catalog`.*"
        )

    output_text = "\n".join(md_parts) + "\n"

    # Write output
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with open(args.output, "w") as f:
        f.write(output_text)

    print(f"Generated {args.output} ({total} services, {len(by_machine)} machines, {len(chains)} chains)")
    if missing_source:
        print(f"⚠ {len(missing_source)} service(s) missing source_repo — see warnings above")
    else:
        print("✓ All services have source_repo links")


if __name__ == "__main__":
    main()
