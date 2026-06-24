# Ansible Vault Management

## Overview

This directory contains documentation and procedures for managing Ansible vault encryption in the infrahub project. Ansible vault is used to secure sensitive data such as passwords, API tokens, and private keys.

## Vault Password Location

The standard vault password file is located at:
```
~/.ansible/vault_password
```

This file contains the plaintext password used to encrypt/decrypt vault files. **Never commit this file to git.**

## Vault Files

### Encrypted Vault File
- **Location**: `shared/active/02-config/ansible/group_vars/all.vault`
- **Purpose**: Contains all sensitive variables for the infrastructure
- **Status**: Encrypted with ansible-vault

### Vault Contents
The vault contains sensitive data for:
- NordVPN credentials
- Traefik ACME email
- Authelia database passwords and session secrets
- Authelia admin credentials
- CrowdSec API tokens
- Cloudflare API tokens and zone IDs

## Vault Operations

### Encrypt a Vault File
```bash
cd ~/p/gh/levonk/infrahub
devbox run -- rtk ansible-vault encrypt shared/active/02-config/ansible/group_vars/all.vault --vault-password-file ~/.ansible/vault_password
```

### Decrypt a Vault File
```bash
cd ~/p/gh/levonk/infrahub
devbox run -- rtk ansible-vault decrypt shared/active/02-config/ansible/group_vars/all.vault --vault-password-file ~/.ansible/vault_password
```

### Edit a Vault File
```bash
cd ~/p/gh/levonk/infrahub
devbox run -- rtk ansible-vault edit shared/active/02-config/ansible/group_vars/all.vault --vault-password-file ~/.ansible/vault_password
```

### View Vault Contents
```bash
cd ~/p/gh/levonk/infrahub
devbox run -- rtk ansible-vault view shared/active/02-config/ansible/group_vars/all.vault --vault-password-file ~/.ansible/vault_password
```

### Re-encrypt with New Password
```bash
cd ~/p/gh/levonk/infrahub
devbox run -- rtk ansible-vault rekey shared/active/02-config/ansible/group_vars/all.vault --vault-password-file ~/.ansible/vault_password --new-vault-password-file ~/.ansible/new_vault_password
```

## Running Playbooks with Vault

When running Ansible playbooks that use vault variables, always specify the vault password file:

```bash
cd ~/p/gh/levonk/infrahub
devbox run -- rtk ansible-playbook -i levonk/active/02-config/ansible/inventories/oci.yml shared/active/02-config/ansible/playbooks/cloud-server-infra.yml --vault-password-file ~/.ansible/vault_password
```

## Security Best Practices

### Password Storage
- Store the vault password file in `~/.ansible/vault_password` (standard location)
- Set file permissions: `chmod 600 ~/.ansible/vault_password`
- Never commit the vault password file to git
- Use a strong, unique password for vault encryption
- Consider using a password manager for the vault password

### Git Configuration
Vault files (`.vault`) are git-ignored to prevent accidental commits. The `.gitignore` entry:
```
*.vault
```

### Secret Generation
When adding new secrets to the vault:
1. Use strong, random passwords (minimum 32 characters)
2. Use unique API tokens for each service
3. Generate cryptographically secure random strings for session secrets
4. Never reuse passwords across services

### Secret Rotation
- Rotate passwords and API tokens regularly (recommended: every 90 days)
- Document rotation procedures in service-specific documentation
- Test rotation in non-production environments first
- Update vault immediately after rotation

## Variable Naming Conventions

All vault variables follow the pattern:
```
vault_<service>_<variable_name>
```

Examples:
- `vault_authelia_admin_password`
- `vault_crowdsec_api_token`
- `vault_cloudflare_api_token`

## Placeholder Values

New vault entries use placeholder values:
```
vault_<variable>: "change-me-in-vault-<instruction>"
```

Before deployment:
1. Replace placeholder with actual secure value
2. Test with the actual value in a safe environment
3. Ensure the vault is re-encrypted after changes

## Troubleshooting

### Vault Password Not Found
If you get "Vault password file not found":
```bash
# Create the vault password file
echo "your-secure-password" > ~/.ansible/vault_password
chmod 600 ~/.ansible/vault_password
```

### Incorrect Vault Password
If you get "Decryption failed":
- Verify the vault password file location
- Ensure the password file contains the correct password
- Check for trailing whitespace in the password file

### Playbook Can't Access Vault Variables
If Ansible can't access vault variables:
- Ensure you're using `--vault-password-file` flag
- Verify the vault file is encrypted (not plaintext)
- Check that vault variable names match between host_vars and vault

## Compliance

All vault operations must comply with:
- AGENTS.md security guidelines
- No hardcoded credentials in source code
- Proper secret management procedures
- Git ignore patterns for vault files

## References

- [Ansible Vault Documentation](https://docs.ansible.com/ansible/latest/vault_guide/index.html)
- AGENTS.md: `/Users/micro/p/gh/levonk/infrahub/AGENTS.md`
- Project security guidelines: `shared/active/02-config/ansible/AGENTS.md`
