#!/usr/bin/env python3
"""Generate TOOLS.md — a browsable tool catalog from tools.yml.

Reads:
  - shared/active/02-config/ansible/infrastructure/tools.yml
  - shared/active/02-config/ansible/infrastructure/ports.yml (for port resolution)
  - shared/active/02-config/ansible/infrastructure/networks.yml (for network resolution)

Produces:
  - levonk/TOOLS.md  (in the private client submodule)
  - infrahub/TOOLS.md  (repo-root, shared-defaults-only catalog — use --shared-only)

The script reads tools.yml, resolves {{ }} variable references, and renders:
  1. All Tools (Alphabetical) — every tool with its image, profile, egress, recipe
  2. Tools by Profile — tools grouped by egress profile

Usage:
  python3 generate_tool_catalog.py [--output PATH] [--shared-only]

Run via:
  just generate-tool-catalog              # levonk/TOOLS.md (client-specific)
  just generate-tool-catalog-shared       # infrahub/TOOLS.md (shared defaults only)
"""

import argparse
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
OUTPUT_DEFAULT = INFRAHUB_ROOT / "levonk" / "TOOLS.md"

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
# Tool resolution
# ---------------------------------------------------------------------------
def resolve_tool(tool: dict, all_vars: dict) -> dict:
    """Resolve all {{ }} references in a tool entry."""
    resolved = {}
    for key, val in tool.items():
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


# ---------------------------------------------------------------------------
# Formatting
# ---------------------------------------------------------------------------
def format_source_repo(tool: dict) -> str:
    """Format source_repo as a clickable link."""
    repo = tool.get("source_repo", "")
    if not repo:
        return "—"
    # Extract repo name from URL for display
    if "github.com/" in repo:
        name = repo.split("github.com/")[-1].rstrip("/")
    elif "gitlab.com/" in repo:
        name = repo.split("gitlab.com/")[-1].rstrip("/")
    else:
        # Use the domain or last path segment
        name = repo.rstrip("/").split("/")[-1] or repo
    return f"[{name}]({repo})"


def format_egress(tool: dict) -> str:
    """Format egress policy as 'hosts (methods)'."""
    egress = tool.get("egress", {})
    if not egress:
        return "—"
    hosts = egress.get("hosts", [])
    methods = egress.get("methods", [])
    host_str = ", ".join(f"`{h}`" for h in hosts) if hosts else "—"
    method_str = ", ".join(methods) if methods else "—"
    return f"{host_str} ({method_str})"


def format_recipe(tool: dict) -> str:
    """Format recipe as a code snippet."""
    recipe = tool.get("recipe", "")
    if not recipe:
        return "—"
    return f"`just {recipe}`"


# ---------------------------------------------------------------------------
# Table generation
# ---------------------------------------------------------------------------
def gen_all_tools_table(tools: list) -> str:
    """Generate the alphabetical tools table."""
    lines = [
        "| Tool | Image | Profile | Egress | Recipe | Source |",
        "|------|-------|---------|--------|--------|--------|",
    ]
    for tool in sorted(tools, key=lambda t: t.get("name", "").lower()):
        name = tool.get("name", "—")
        image = f"`{tool.get('image', '—')}`"
        profile = tool.get("profile", "—")
        egress = format_egress(tool)
        recipe = format_recipe(tool)
        source = format_source_repo(tool)
        lines.append(f"| {name} | {image} | {profile} | {egress} | {recipe} | {source} |")
    return "\n".join(lines)


def gen_by_profile_sections(tools: list) -> str:
    """Generate tools grouped by egress profile."""
    profiles = {}
    for tool in tools:
        profile = tool.get("profile", "uncategorized")
        profiles.setdefault(profile, []).append(tool)

    parts = []
    for profile in sorted(profiles.keys()):
        profile_tools = profiles[profile]
        parts.append(f"### {profile.title()}")
        parts.append("")
        parts.append("| Tool | Image | Egress | Recipe | Source |")
        parts.append("|------|-------|--------|--------|--------|")
        for tool in sorted(profile_tools, key=lambda t: t.get("name", "").lower()):
            name = tool.get("name", "—")
            image = f"`{tool.get('image', '—')}`"
            egress = format_egress(tool)
            recipe = format_recipe(tool)
            source = format_source_repo(tool)
            parts.append(f"| {name} | {image} | {egress} | {recipe} | {source} |")
        parts.append("")
    return "\n".join(parts)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main():
    parser = argparse.ArgumentParser(description="Generate TOOLS.md tool catalog")
    parser.add_argument(
        "--output",
        type=Path,
        default=OUTPUT_DEFAULT,
        help=f"Output file path (default: {OUTPUT_DEFAULT})",
    )
    parser.add_argument(
        "--shared-only",
        action="store_true",
        help="Generate repo-root catalog (shared defaults only, no client deployment info)",
    )
    args = parser.parse_args()

    # Load infrastructure YAML
    shared_ports = load_yaml(SHARED_INFRA / "ports.yml")
    shared_networks = load_yaml(SHARED_INFRA / "networks.yml")
    shared_storage = load_yaml(SHARED_INFRA / "storage.yml")
    shared_tools = load_yaml(SHARED_INFRA / "tools.yml")

    all_vars = merge_yaml(
        merge_yaml(shared_ports, shared_networks),
        merge_yaml(shared_storage, {}),
    )

    # Load client overrides (not used in shared-only mode, but loaded for var resolution)
    if not args.shared_only:
        client_ports = load_yaml(CLIENT_INFRA / "ports.yml")
        client_networks = load_yaml(CLIENT_INFRA / "networks.yml")
        client_storage = load_yaml(CLIENT_INFRA / "storage.yml")
        all_vars = merge_yaml(
            merge_yaml(all_vars, client_ports),
            merge_yaml(client_networks, client_storage),
        )

    # Get tools list
    tools = shared_tools if isinstance(shared_tools, list) else []
    if not tools:
        print("No tools found in tools.yml (file is empty or only contains comments)")
        # Still generate an empty catalog

    # Resolve tools
    resolved_tools = [resolve_tool(t, all_vars) for t in tools]

    # Validate source_repo
    missing_source = [t for t in resolved_tools if not t.get("source_repo")]
    for t in missing_source:
        print(f"⚠ Tool '{t.get('name', 'unknown')}' missing source_repo")

    total = len(resolved_tools)

    # Generate markdown
    now = datetime.now().strftime("%Y-%m-%d %H:%M")
    md_parts = []

    if args.shared_only:
        md_parts.append("# Infrahub Tool Catalog (Shared Defaults)")
        md_parts.append("")
        md_parts.append(f"> **Auto-generated** from `infrastructure/tools.yml` — last updated: {now}")
        md_parts.append("> Regenerate with: `just generate-tool-catalog-shared`")
        md_parts.append(f"> Source: `shared/active/02-config/ansible/infrastructure/tools.yml`")
        md_parts.append(
            "> Note: This catalog shows **default profile configurations** only. "
            "Client-specific deployment details are not included. "
            "See `levonk/TOOLS.md` for the deployed client catalog."
        )
    else:
        md_parts.append("# Infrahub Tool Catalog")
        md_parts.append("")
        md_parts.append(f"> **Auto-generated** from `infrastructure/tools.yml` — last updated: {now}")
        md_parts.append("> Regenerate with: `just generate-tool-catalog`")
        md_parts.append(f"> Source: `shared/active/02-config/ansible/infrastructure/tools.yml`")

    md_parts.append("")
    md_parts.append(f"**{total} tool(s)**")
    md_parts.append("")

    # Table of Contents
    md_parts.append("## Table of Contents")
    md_parts.append("")
    md_parts.append("- [All Tools (Alphabetical)](#all-tools-alphabetical)")
    md_parts.append("- [Tools by Profile](#tools-by-profile)")
    md_parts.append("")

    # All Tools
    md_parts.append("## All Tools (Alphabetical)")
    md_parts.append("")
    md_parts.append(gen_all_tools_table(resolved_tools))
    md_parts.append("")

    # By Profile
    md_parts.append("## Tools by Profile")
    md_parts.append("")
    md_parts.append(gen_by_profile_sections(resolved_tools))

    md_parts.append("---")
    md_parts.append("")
    md_parts.append("*This file is generated by `generate_tool_catalog.py`. Do not edit manually.*")
    if args.shared_only:
        md_parts.append(
            "*To add a tool: add an entry to `tools.yml` (including `source_repo`), "
            "then run `just generate-tool-catalog-shared` (repo root) and "
            "`just generate-tool-catalog` (client).*"
        )
    else:
        md_parts.append(
            "*To add a tool: add an entry to `tools.yml` (including `source_repo`), "
            "then run `just generate-tool-catalog`.*"
        )

    output_text = "\n".join(md_parts) + "\n"

    # Write output
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with open(args.output, "w") as f:
        f.write(output_text)

    print(f"Generated {args.output} ({total} tools)")
    if missing_source:
        print(f"⚠ {len(missing_source)} tool(s) missing source_repo — see warnings above")
    else:
        if total > 0:
            print("✓ All tools have source_repo links")


if __name__ == "__main__":
    main()
