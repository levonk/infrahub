# Traefik Stack Operational Runbook

## Overview
This runbook provides operational procedures for managing the Traefik proxy stack with Authelia, CrowdSec, and Cloudflare integration.

## Prerequisites
- Access to OCI cloud server (100.90.22.85)
- Ansible vault password file at `~/.ansible/vault_password`
- Devbox environment configured
- SSH access to opc@100.90.22.85

## Common Operations

### Check Service Status
```bash
cd ~/p/gh/levonk/infrahub
devbox run -- rtk ssh opc@100.90.22.85 -i ~/.ssh/lzkmbp2016-micro-oracle -o StrictHostKeyChecking=no "sudo docker ps --format 'table {{.Names}}\t{{.Status}}'"
```

### View Traefik Logs
```bash
cd ~/p/gh/levonk/infrahub
devbox run -- rtk ssh opc@100.90.22.85 -i ~/.ssh/lzkmbp2016-micro-oracle -o StrictHostKeyChecking=no "sudo docker logs traefik --tail=50"
```

### View Authelia Logs
```bash
cd ~/p/gh/levonk/infrahub
devbox run -- rtk ssh opc@100.90.22.85 -i ~/.ssh/lzkmbp2016-micro-oracle -o StrictHostKeyChecking=no "sudo docker logs proxy-authelia --tail=50"
```

### Restart Traefik
```bash
cd ~/p/gh/levonk/infrahub
devbox run -- rtk ssh opc@100.90.22.85 -i ~/.ssh/lzkmbp2016-micro-oracle -o StrictHostKeyChecking=no "sudo docker restart traefik"
```

### Reload Traefik Configuration
```bash
cd ~/p/gh/levonk/infrahub
devbox run -- rtk ssh opc@100.90.22.85 -i ~/.ssh/lzkmbp2016-micro-oracle -o StrictHostKeyChecking=no "sudo docker kill --signal=HUP traefik"
```

## Troubleshooting

### Traefik Not Starting
1. Check logs: `sudo docker logs traefik`
2. Verify configuration: `sudo docker exec traefik cat /etc/traefik/traefik.yml`
3. Check for syntax errors in dynamic config
4. Verify Docker network exists: `sudo docker network inspect traefik-network`

### SSL Certificate Issues
1. Check ACME status: `sudo docker exec traefik cat /letsencrypt/acme.json`
2. Verify Cloudflare API credentials in vault
3. Check DNS propagation for domain
4. Review Traefik logs for ACME errors

### Authelia Not Working
1. Check Authelia health: `sudo docker logs proxy-authelia`
2. Verify database connectivity
3. Check Redis connection
4. Test Authelia API: `curl http://100.90.22.85:9091/api/verify`

### CrowdSec Not Blocking
1. Check CrowdSec status: `sudo docker logs crowdsec`
2. Verify bouncer connection: `sudo docker logs crowdsec-bouncer`
3. Check acquisition sources configuration
4. Review CrowdSec decisions: `sudo docker exec crowdsec cscli decisions list`

### Service Not Accessible
1. Check Traefik routing: `sudo docker exec traefik cat /etc/traefik/dynamic/`
2. Verify service is running: `sudo docker ps`
3. Check service network connectivity
4. Test service directly: `curl http://<service-ip>:<port>`

## Emergency Procedures

### Full Stack Restart
```bash
cd ~/p/gh/levonk/infrahub
devbox run -- rtk ssh opc@100.90.22.85 -i ~/.ssh/lzkmbp2016-micro-oracle -o StrictHostKeyChecking=no "sudo docker restart traefik proxy-authelia crowdsec crowdsec-bouncer"
```

### Configuration Rollback
1. Identify last working commit in git
2. Revert configuration files
3. Redeploy with Ansible
4. Verify services start correctly

### Disaster Recovery
1. Restore from configuration backups in `/opt/traefik/config/`
2. Restore Docker volumes if needed
3. Redeploy entire stack using Ansible playbooks
4. Verify all services are healthy

## Monitoring

### Resource Usage
```bash
cd ~/p/gh/levonk/infrahub
devbox run -- rtk ssh opc@100.90.22.85 -i ~/.ssh/lzkmbp2016-micro-oracle -o StrictHostKeyChecking=no "sudo docker stats --no-stream"
```

### Network Connectivity
```bash
cd ~/p/gh/levonk/infrahub
devbox run -- rtk ssh opc@100.90.22.85 -i ~/.ssh/lzkmbp2016-micro-oracle -o StrictHostKeyChecking=no "sudo docker network inspect traefik-network"
```

### SSL Certificate Expiry
```bash
cd ~/p/gh/levonk/infrahub
devbox run -- rtk ssh opc@100.90.22.85 -i ~/.ssh/lzkmbp2016-micro-oracle -o StrictHostKeyChecking=no "sudo docker exec traefik cat /letsencrypt/acme.json | jq '.letsencrypt.Certificates'"
```

## Maintenance

### Update Traefik Configuration
1. Edit Ansible templates in `shared/active/02-config/ansible/roles/proxy-traefik/templates/`
2. Deploy with: `cd ~/p/gh/levonk/infrahub && devbox run -- rtk ansible-playbook -i levonk/active/02-config/ansible/inventories/oci.yml shared/active/02-config/ansible/playbooks/deploy-traefik.yml --vault-password-file ~/.ansible/vault_password`
3. Reload Traefik configuration

### Add New Service
1. Add service to appropriate Docker network
2. Create Traefik dynamic configuration
3. Add Authelia middleware if needed
4. Test routing and authentication
5. Document in service registration guide

### Rotate Secrets
1. Update vault with new credentials
2. Redeploy affected services
3. Verify services work with new credentials
4. Remove old credentials from vault

## Contact Information
- Infrastructure Team: [contact info]
- On-call: [contact info]
- Documentation: `~/p/gh/levonk/infrahub/shared/active/08-docs/`