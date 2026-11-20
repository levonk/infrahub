"""Config-policy unit tests for Ansible playbooks and infrastructure vars.

Catches the class of bug that made search.levonk.com intermittently
NXDOMAIN ("server not found"): a tailnet-only DNS record pointing at a
*.ts.net CNAME, which MagicDNS fails when the tailnet name is reached by
chasing a CNAME across zones. Also guards missing record fields,
A records pointing at hostnames, and infra_* variable references that
are defined nowhere.

Run inside devbox:  python3 -m unittest discover -s tests -v
                  (or: just test-config)
Dependencies: stdlib + PyYAML only — both already in the devbox env.
"""

import re
import unittest
import warnings
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
ANSIBLE = ROOT / "shared" / "active" / "02-config" / "ansible"
CLIENT = ROOT / "levonk" / "active" / "02-config" / "ansible"
DNS_PLAYBOOK = ANSIBLE / "playbooks" / "configure-cloudflare-dns.yml"

# Directories whose *.yml files define top-level variables. Vault files
# are skipped (ciphertext; vault vars use the vault_ prefix anyway).
VAR_DIRS = [
    ANSIBLE / "infrastructure",
    ANSIBLE / "group_vars",
    ANSIBLE / "vars",
    CLIENT / "infrastructure",
    CLIENT / "inventories" / "group_vars",
    CLIENT / "host_vars",
]

IPV4 = re.compile(r"^\d{1,3}(\.\d{1,3}){3}$")
INFRA_VAR_REF = re.compile(r"\binfra_[a-z0-9_]+\b")
TSNET_TARGET = re.compile(r"ts_fqdn|tailscale_fqdn|\.ts\.net")
# YAML comments: '#' at line start or preceded by whitespace.
_COMMENT = re.compile(r"(?m)(^|\s)#.*$")

# Pre-existing undefined infra_* references (technical debt). These are
# referenced by playbooks but defined in no var file — mostly dead
# | default() fallbacks in deploy-omnigent/deploy-langfuse/test-* that
# would explode at render time if ever reached, plus a few legit
# `is defined` guards. New missing vars FAIL the test; shrinking this
# baseline is welcome — remove an entry when you fix its definition.
KNOWN_UNDEFINED_INFRA_VARS = {
    "infra_count_zero",
    "infra_network_ai_subnet",
    "infra_network_ai_subnet_alt_ip_30",
    "infra_network_ai_subnet_gateway",
    "infra_network_ai_subnet_ip_13",
    "infra_network_ai_subnet_ip_14",
    "infra_network_ai_subnet_ip_17",
    "infra_network_ai_subnet_ip_18",
    "infra_network_ai_subnet_ip_30",
    "infra_network_external_dns_test",
    "infra_network_ip_omniroute_1",
    "infra_network_ip_omniroute_2",
    "infra_network_lan_gateway_1",
    "infra_network_lan_gateway_2",
    "infra_network_lan_host_2",
    "infra_network_monitoring_subnet",
    "infra_network_monitoring_subnet_ip_10",
    "infra_network_monitoring_subnet_ip_11",
    "infra_network_monitoring_subnet_ip_20",
    "infra_network_monitoring_subnet_ip_30",
    "infra_network_monitoring_subnet_ip_40",
    "infra_network_monitoring_subnet_ip_50",
    "infra_network_private_class_b",
    "infra_network_proxy_alt_subnet",
    "infra_network_proxy_alt_subnet_ip_30",
    "infra_network_proxy_subnet",
    "infra_network_proxy_subnet_gateway",
    "infra_network_proxy_subnet_ip_10",
    "infra_network_proxy_subnet_ip_20",
    "infra_network_proxy_subnet_ip_30",
}


def _strip_comments(text):
    return _COMMENT.sub(r"\1", text)


def _load_yaml(path):
    try:
        return yaml.safe_load(path.read_text())
    except yaml.YAMLError:
        return None


def _defined_vars():
    """All top-level variable names defined in plaintext var files."""
    keys = set()
    for d in VAR_DIRS:
        if not d.is_dir():
            continue
        for f in d.rglob("*.yml"):
            if f.name.endswith(".vault.yml"):
                continue
            doc = _load_yaml(f)
            if isinstance(doc, dict):
                keys.update(doc.keys())
    return keys


def _dns_records():
    data = _load_yaml(DNS_PLAYBOOK)
    assert isinstance(data, list), f"{DNS_PLAYBOOK.name} did not parse to a play list"
    for play in data:
        if isinstance(play, dict) and "cloudflare_dns_records" in play.get("vars", {}):
            return play["vars"]["cloudflare_dns_records"]
    raise AssertionError("cloudflare_dns_records not found in vars")


class TestDnsRecordPolicy(unittest.TestCase):
    """Policy checks over configure-cloudflare-dns.yml's record list."""

    @classmethod
    def setUpClass(cls):
        cls.records = _dns_records()

    def test_records_have_required_fields(self):
        """Every record entry has non-empty name, type, and content."""
        valid_types = {"A", "AAAA", "CNAME", "MX", "TXT", "SRV", "NS"}
        for i, r in enumerate(self.records):
            with self.subTest(index=i, record=r.get("name", "<no name>")):
                self.assertIsInstance(r, dict, f"record #{i} is not a mapping")
                self.assertTrue(r.get("name"), f"record #{i} missing name")
                self.assertTrue(r.get("content"), f"{r.get('name')} missing content")
                self.assertIn(r.get("type"), valid_types, f"{r.get('name')} bad type {r.get('type')!r}")

    def test_a_records_have_ip_content(self):
        """A records must resolve to an IP — literal or an *_ip variable.

        An A record pointing at a hostname is a Cloudflare API error.
        """
        for r in self.records:
            if r.get("type") != "A":
                continue
            content = str(r.get("content", ""))
            tokens = re.findall(r"[a-z0-9_]+", content.lower())
            with self.subTest(record=r.get("name")):
                self.assertTrue(
                    IPV4.match(content) or any("ip" in t for t in tokens),
                    f"A record {r.get('name')} content {content!r} is neither "
                    "an IPv4 literal nor an *_ip variable reference",
                )

    def test_cname_records_have_hostname_content(self):
        """CNAME records must not point at a bare IPv4 literal."""
        for r in self.records:
            if r.get("type") != "CNAME":
                continue
            content = str(r.get("content", ""))
            with self.subTest(record=r.get("name")):
                self.assertFalse(
                    IPV4.match(content),
                    f"CNAME {r.get('name')} points at bare IP {content!r}",
                )

    def test_search_record_is_direct_tailscale_ip(self):
        """Regression: search.* must be an A record to a Tailscale IP.

        MagicDNS intermittently NXDOMAINs tailnet names reached by chasing
        a CNAME from a public zone — see git history / PR #28. The record
        must stay A → infra_tailscale_ip_* (same pattern as stirling-api.nl).
        """
        search = [r for r in self.records if "proxy_search" in str(r.get("name", ""))]
        self.assertEqual(len(search), 1, "expected exactly one proxy_search record")
        with self.subTest(record=search[0].get("name")):
            self.assertEqual(search[0].get("type"), "A")
            self.assertIn("tailscale_ip", str(search[0].get("content", "")))

    def test_infra_vars_referenced_are_defined(self):
        """Every NEW infra_* var referenced by playbooks resolves to a
        definition. Tokens ending in '_' are prose wildcards like
        `infra_foo_*` in doc strings, never real var names — filtered out.
        Pre-existing debt is baselined in KNOWN_UNDEFINED_INFRA_VARS; a
        reference missing from BOTH var files and the baseline fails.
        """
        defined = _defined_vars()
        playbook_dir = ANSIBLE / "playbooks"
        referenced = set()
        for f in playbook_dir.glob("*.yml"):
            referenced.update(INFRA_VAR_REF.findall(_strip_comments(f.read_text())))
        referenced = {v for v in referenced if not v.endswith("_")}
        missing = sorted(v for v in referenced if v not in defined)
        new_missing = [v for v in missing if v not in KNOWN_UNDEFINED_INFRA_VARS]
        self.assertEqual(
            new_missing, [],
            "infra_* vars referenced in playbooks but not defined in any "
            "infrastructure/group_vars/host_vars file:\n  " + "\n  ".join(new_missing),
        )

    def test_warn_on_tsnet_cname_surface(self):
        """Report the residual *.ts.net CNAME surface (warning, not failure).

        Each of these records shares the same intermittent-NXDOMAIN flake
        that hit search.levonk.com. Migrated to A records they are fixed;
        tracked here so new additions are visible.
        """
        def _label(r):
            m = re.search(r"infra_domain_\w+", str(r.get("name", "")))
            return m.group(0) if m else str(r.get("name"))

        flaky = [
            _label(r)
            for r in self.records
            if r.get("type") == "CNAME" and TSNET_TARGET.search(str(r.get("content", "")))
        ]
        warnings.warn(
            f"{len(flaky)} CNAME records resolve into *.ts.net and share the "
            f"MagicDNS CNAME-chase NXDOMAIN flake: {', '.join(flaky)}",
            stacklevel=1,
        )


class TestInfraVarIntegrity(unittest.TestCase):
    """Cross-checks on the tailnet IP vars the A records depend on."""

    def test_cloud_server_tailscale_ip_is_valid(self):
        """infra_tailscale_ip_cloud_server must be a non-empty IPv4 literal
        in the resolved client config (shared default is intentionally "").
        """
        val = None
        # Shared defaults first, client overrides last (client wins).
        for d in (ANSIBLE / "infrastructure", CLIENT / "infrastructure"):
            for f in sorted(d.rglob("*.yml")):
                doc = _load_yaml(f)
                if isinstance(doc, dict) and "infra_tailscale_ip_cloud_server" in doc:
                    val = doc["infra_tailscale_ip_cloud_server"]
        self.assertIsNotNone(val, "infra_tailscale_ip_cloud_server defined nowhere")
        self.assertTrue(
            IPV4.match(str(val)),
            f"infra_tailscale_ip_cloud_server={val!r} is not a valid IPv4 "
            "address — set it in the client's infrastructure/domains.yml",
        )


if __name__ == "__main__":
    unittest.main()
