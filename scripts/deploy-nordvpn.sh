#!/bin/bash
# Deploy NordVPN with OpenVPN credentials from vault

cd /Users/micro/p/gh/levonk/infrahub

echo "Extracting OpenVPN credentials from vault..."
OPENVPN_USER=$(devbox run -- ansible-vault view levonk/active/02-config/ansible/inventories/group_vars/infrahub-levonk-all.vault.yml --vault-password-file ~/.ansible/vault_password 2>/dev/null | grep vault_nordvpn_openvpn_user | cut -d: -f2 | tr -d ' ')
OPENVPN_PASS=$(devbox run -- ansible-vault view levonk/active/02-config/ansible/inventories/group_vars/infrahub-levonk-all.vault.yml --vault-password-file ~/.ansible/vault_password 2>/dev/null | grep vault_nordvpn_openvpn_pass | cut -d: -f2 | tr -d ' ')

if [ -z "$OPENVPN_USER" ] || [ -z "$OPENVPN_PASS" ]; then
    echo "ERROR: Failed to extract OpenVPN credentials from vault"
    exit 1
fi

echo "OpenVPN credentials extracted successfully"
devbox run -- ansible-playbook -i levonk/active/02-config/ansible/inventories/oci.yml shared/active/02-config/ansible/playbooks/cloud-server-nordvpn.yml --extra-vars "vpn_nordvpn_openvpn_user=$OPENVPN_USER vpn_nordvpn_openvpn_pass=$OPENVPN_PASS"
