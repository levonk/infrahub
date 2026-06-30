# Cloudflare DNS Management Procedures

## Overview

This document outlines the procedures for managing Cloudflare DNS records for the Traefik proxy stack on the OCI cloud server. DNS records enable external access to services through the Traefik reverse proxy with SSL termination.

## Prerequisites

- Cloudflare account with domain `levonk.com` configured
- Cloudflare API token with `Zone - DNS - Edit` and `Zone - Zone - Read` permissions
- Ansible vault password file at `~/.ansible/vault_password`
- Access to the infrahub repository

## Security Considerations

- **API Token Security**: Cloudflare API tokens are stored in Ansible vault (`shared/active/02-config/ansible/inventories/group_vars/all.vault`)
- **Principle of Least Privilege**: API tokens have minimum required permissions only
- **Token Rotation**: API tokens should be rotated regularly (recommended every 90 days)
- **Access Control**: Vault access is restricted to authorized personnel only

## DNS Record Configuration

### Current DNS Records

| Domain | Type | Content | TTL | Proxy Mode | Purpose |
|--------|------|---------|-----|------------|---------|
| search.levonk.com | A | 161.153.91.163 | 300 | DNS-only | SearXNG search service |
| traefik.levonk.com | A | 161.153.91.163 | 300 | DNS-only | Traefik dashboard (optional) |

### Configuration Variables

DNS configuration is managed through the following variables:

**Playbook**: `shared/active/02-config/ansible/playbooks/configure-cloudflare-dns.yml`

```yaml
# DNS Record Configuration
cloudflare_dns_state: "present"           # present, absent
cloudflare_dns_ttl: 300                    # Time-to-live in seconds
cloudflare_dns_proxied: false              # DNS-only mode (not full proxy)
cloudflare_dns_verify: true                # Verify DNS record creation
cloudflare_dns_validate_ip: true           # Validate IP address format
cloudflare_dns_allow_private_ip: false     # Reject private IP addresses
```

## Management Procedures

### Initial DNS Setup

1. **Generate Cloudflare API Token**:
   - Go to Cloudflare Dashboard → My Profile → API Tokens
   - Click "Create Token"
   - Use template "Edit zone DNS" or create custom token with:
     - `Zone - DNS - Edit`
     - `Zone - Zone - Read`
   - Specify zone resources (specific zones or all zones)
   - Copy the generated token

2. **Get Cloudflare Zone ID**:
   - Go to Cloudflare Dashboard → Select domain `levonk.com`
   - Scroll down to "API" section on the right sidebar
   - Copy the "Zone ID"

3. **Update Vault Credentials**:
   ```bash
   cd ~/p/gh/levonk/infrahub
   devbox run -- ansible-vault edit shared/active/02-config/ansible/inventories/group_vars/all.vault
   ```
   - Update `vault_cloudflare_api_token` with your API token
   - Update `vault_cloudflare_zone_id` with your zone ID
   - Save and exit

4. **Deploy DNS Records**:
   ```bash
   cd ~/p/gh/levonk/infrahub
   devbox run -- ansible-playbook \
     shared/active/02-config/ansible/playbooks/configure-cloudflare-dns.yml \
     --vault-password-file ~/.ansible/vault_password
   ```

### Adding New DNS Records

1. **Edit the DNS configuration playbook**:
   ```bash
   vim shared/active/02-config/ansible/playbooks/configure-cloudflare-dns.yml
   ```

2. **Add new record to `cloudflare_dns_records` list**:
   ```yaml
   cloudflare_dns_records:
     - name: "new-service.levonk.com"
       type: "A"
       content: "{{ cloud_server_ansible_host_ip }}"
       ttl: "{{ cloudflare_dns_ttl }}"
       proxied: "{{ cloudflare_dns_proxied }}"
       state: "{{ cloudflare_dns_state }}"
   ```

3. **Deploy the updated configuration**:
   ```bash
   devbox run -- ansible-playbook \
     shared/active/02-config/ansible/playbooks/configure-cloudflare-dns.yml \
     --vault-password-file ~/.ansible/vault_password
   ```

### Updating DNS Records

1. **Edit the DNS configuration playbook** and modify the record
2. **Deploy the updated configuration** - the cloudflare-dns role will automatically update existing records

### Deleting DNS Records

1. **Edit the DNS configuration playbook** and set `state: "absent"` for the record:
   ```yaml
   - name: "old-service.levonk.com"
     type: "A"
     content: "{{ cloud_server_ansible_host_ip }}"
     state: "absent"  # This will delete the record
   ```

2. **Deploy the configuration** to delete the record

### Testing DNS Resolution

1. **Run the DNS resolution test playbook**:
   ```bash
   devbox run -- ansible-playbook \
     shared/active/02-config/ansible/playbooks/test-dns-resolution.yml
   ```

2. **Manual DNS testing**:
   ```bash
   # Test A record resolution
   dig +short search.levonk.com
   dig +short traefik.levonk.com

   # Test with specific DNS server
   dig @8.8.8.8 search.levonk.com

   # Check DNS propagation
   dig search.levonk.com +nssearch
   ```

### Monitoring DNS Propagation

1. **Use online tools**:
   - https://dnschecker.org/
   - https://www.whatsmydns.net/
   - https://dnspropagation.net/

2. **Monitor from multiple locations** to ensure global propagation

3. **Typical propagation time**: 5-15 minutes for Cloudflare DNS

## Troubleshooting

### API Authentication Errors

**Error**: `403 Forbidden`

**Solutions**:
- Verify API token has correct permissions (`Zone - DNS - Edit`, `Zone - Zone - Read`)
- Check token is not expired
- Ensure zone ID is correct for the domain
- Verify vault password is correct

### DNS Record Not Found

**Error**: `DNS record not found during verification`

**Solutions**:
- Check record name matches exactly (including subdomain)
- Verify zone ID corresponds to correct domain
- Ensure record type is correct (A, CNAME, etc.)
- Check if record was actually created in Cloudflare dashboard

### Rate Limiting

**Error**: `429 Too Many Requests`

**Solutions**:
- Increase `cloudflare_dns_rate_limit_delay` in role defaults
- Reduce number of concurrent operations
- Implement batch processing for multiple records
- Wait a few minutes before retrying

### IP Validation Failures

**Error**: `Invalid IP address format`

**Solutions**:
- Verify IP address format (IPv4 or IPv6)
- Check if private IP addresses are allowed
- Disable IP validation if needed: `cloudflare_dns_validate_ip: false`

### DNS Propagation Delays

**Symptoms**: DNS records not resolving globally

**Solutions**:
- Wait 15-30 minutes for full propagation
- Check DNS from multiple locations
- Verify Cloudflare proxy status (should be "DNS only")
- Check TTL settings (lower TTL = faster propagation)

## Backup and Restore Procedures

### DNS Record Backup

1. **Export current DNS records**:
   ```bash
   # Use Cloudflare API to export all records
   # This can be automated with a script
   ```

2. **Document current configuration** in this file

3. **Keep playbook version control** - git history provides backup

### DNS Record Restore

1. **Restore from playbook**:
   - Revert playbook to previous version using git
   - Deploy the previous configuration

2. **Manual restore**:
   - Use Cloudflare dashboard to manually recreate records
   - Refer to this documentation for correct values

## Compliance and Best Practices

### AGENTS.md Compliance

- ✅ All IP addresses and ports are variables (no hardcoded values)
- ✅ API tokens stored in Ansible vault
- ✅ Variable-driven configuration
- ✅ References to AGENTS.md in documentation

### Cloudflare Best Practices

- Use DNS-only mode (not full proxy) for SSL certificate management
- Set appropriate TTL values (300 seconds for balance)
- Enable DNSSEC if supported by domain registrar
- Use Cloudflare's security features (WAF, rate limiting)
- Monitor DNS query analytics in Cloudflare dashboard

### Security Best Practices

- Rotate API tokens regularly
- Use separate tokens for different environments
- Enable IP filtering in Cloudflare if possible
- Monitor API usage in Cloudflare dashboard
- Implement proper access controls for vault

## References

- [Cloudflare API Documentation](https://developers.cloudflare.com/api/)
- [Cloudflare DNS Records](https://developers.cloudflare.com/dns/)
- [Ansible Vault Documentation](https://docs.ansible.com/ansible/latest/vault_guide/index.html)
- [AGENTS.md](/AGENTS.md) - Project guidelines
- [Ansible AGENTS.md](shared/active/02-config/ansible/AGENTS.md) - Ansible-specific guidelines

## Change Log

| Date | Change | Author |
|------|--------|--------|
| 2026-06-20 | Initial documentation | Story 03-002 |
