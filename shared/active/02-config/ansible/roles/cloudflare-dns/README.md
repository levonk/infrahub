# cloudflare-dns Ansible Role

Manage Cloudflare DNS records using Cloudflare API v4. This role provides automated DNS record creation, updates, and deletion with secure API credential management.

## Requirements

- Ansible 2.9 or higher
- Cloudflare API token with appropriate permissions
- Internet connectivity to Cloudflare API

## Role Variables

### Required Variables

These variables must be set in your playbook or inventory:

```yaml
# Cloudflare API Configuration
cloudflare_api_token: "your-cloudflare-api-token"  # Store in Ansible vault
cloudflare_zone_id: "your-cloudflare-zone-id"      # Store in Ansible vault
```

### DNS Record Configuration

```yaml
# DNS Record Configuration
cloudflare_dns_state: "present"  # present, absent
cloudflare_dns_record_name: "example.com"
cloudflare_dns_record_type: "A"  # A, AAAA, CNAME, MX, TXT, SRV, etc.
cloudflare_dns_record_content: "192.0.2.1"
cloudflare_dns_ttl: 300
cloudflare_dns_proxied: false
```

### Optional Variables

```yaml
# DNS Record Validation
cloudflare_dns_verify: true
cloudflare_dns_verify_propagation: false
cloudflare_dns_propagation_wait: 10

# IP Address Validation (for A records)
cloudflare_dns_validate_ip: true
cloudflare_dns_allow_private_ip: false

# Multiple DNS Records Support
cloudflare_dns_records: []

# API Rate Limiting
cloudflare_dns_rate_limit_delay: 0.5
cloudflare_dns_max_retries: 3

# Dry Run Mode
cloudflare_dns_dry_run: false

# Logging
cloudflare_dns_log_operations: true
cloudflare_dns_log_file: "/var/log/cloudflare-dns.log"
```

## Vault Setup

### Create Encrypted Vault

```bash
# Create new vault file
ansible-vault create group_vars/all/vault.yml

# Edit existing vault
ansible-vault edit group_vars/all/vault.yml
```

### Vault Content

```yaml
# group_vars/all/vault.yml
cloudflare_api_token: "your-actual-cloudflare-api-token"
cloudflare_zone_id: "your-actual-cloudflare-zone-id"
```

### Use Vault in Playbook

```bash
# Run playbook with vault password
ansible-playbook -i inventory playbook.yml --ask-vault-pass

# Or use vault password file
ansible-playbook -i inventory playbook.yml --vault-password-file ~/.vault-pass
```

## Dependencies

None

## Example Playbook

### Single DNS Record

```yaml
---
- name: Manage Cloudflare DNS records
  hosts: localhost
  gather_facts: false
  vars:
    cloudflare_dns_record_name: "www.example.com"
    cloudflare_dns_record_type: "A"
    cloudflare_dns_record_content: "192.0.2.1"
    cloudflare_dns_ttl: 300
    cloudflare_dns_proxied: false

  roles:
    - cloudflare-dns
```

### Multiple DNS Records

```yaml
---
- name: Manage multiple Cloudflare DNS records
  hosts: localhost
  gather_facts: false
  vars:
    cloudflare_dns_records:
      - name: "www.example.com"
        type: "A"
        content: "192.0.2.1"
        ttl: 300
        proxied: false
      - name: "mail.example.com"
        type: "A"
        content: "192.0.2.2"
        ttl: 300
        proxied: false
      - name: "api.example.com"
        type: "CNAME"
        content: "www.example.com"
        ttl: 300
        proxied: false

  roles:
    - cloudflare-dns
```

### Delete DNS Record

```yaml
---
- name: Delete Cloudflare DNS record
  hosts: localhost
  gather_facts: false
  vars:
    cloudflare_dns_state: "absent"
    cloudflare_dns_record_name: "old.example.com"
    cloudflare_dns_record_type: "A"

  roles:
    - cloudflare-dns
```

## Cloudflare API Token Setup

### Create API Token

1. Go to Cloudflare Dashboard → My Profile → API Tokens
2. Click "Create Token"
3. Use template "Edit zone DNS" or create custom token with permissions:
   - Zone - DNS - Edit
   - Zone - Zone - Read
4. Specify zone resources (specific zones or all zones)
5. Copy the generated token

### Token Permissions

Minimum required permissions:
- `Zone - DNS - Edit`
- `Zone - Zone - Read`

## Security Considerations

- **Always store API tokens in Ansible vault** - never in plain text
- Use principle of least privilege for API token permissions
- Rotate API tokens regularly
- Use separate tokens for different environments
- Enable Cloudflare IP filtering if possible
- Monitor API usage in Cloudflare dashboard

## Compliance

This role follows AGENTS.md guidelines:
- Variable-driven configuration (no hardcoded values)
- Secure credential management via Ansible vault
- Reference to `/AGENTS.md` (root), `shared/active/02-config/ansible/AGENTS.md`

## Troubleshooting

### API Authentication Errors

```
Error: 403 Forbidden
```
- Verify API token has correct permissions
- Check token is not expired
- Ensure zone ID is correct

### DNS Record Not Found

```
Error: DNS record not found during verification
```
- Check record name matches exactly (including subdomain)
- Verify zone ID corresponds to correct domain
- Ensure record type is correct (A, CNAME, etc.)

### Rate Limiting

```
Error: 429 Too Many Requests
```
- Increase `cloudflare_dns_rate_limit_delay`
- Reduce number of concurrent operations
- Implement batch processing for multiple records

### IP Validation Failures

```
Error: Invalid IP address format
```
- Verify IP address format (IPv4 or IPv6)
- Check if private IP addresses are allowed
- Disable IP validation if needed: `cloudflare_dns_validate_ip: false`

## License

MIT

## Author Information

This role was created for the infrahub project following AGENTS.md guidelines for Ansible automation and security best practices.
