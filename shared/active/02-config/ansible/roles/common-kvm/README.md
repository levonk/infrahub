# common-kvm

Install and configure the KVM/libvirt/QEMU virtualization stack, bridge networks, and VM storage pools.

## Requirements

- Ansible >= 2.15
- Target host: Debian 12 (bookworm) or Ubuntu 22.04/24.04
- CPU with Intel VT-x or AMD-V virtualization support
- Nested virtualization enabled (for cloud VM workloads)

## Role Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `common_kvm_skip_virtualization_check` | `false` | Skip CPU virtualization check |
| `common_kvm_packages` | `[qemu-kvm, libvirt-daemon-system, virtinst, virt-manager, bridge-utils, qemu-utils, libguestfs-tools]` | Packages to install |
| `common_kvm_libvirtd_service_name` | `libvirtd` | libvirtd systemd service name |
| `common_kvm_nat_bridge_name` | `kvm-nat-br0` | NAT bridge network name |
| `common_kvm_nat_bridge_subnet` | `{{ kvm_nat_bridge_subnet \| default('192.168.100.0/24') }}` | NAT bridge subnet (override in group_vars) |
| `common_kvm_nat_bridge_gateway` | `{{ kvm_nat_bridge_gateway \| default('192.168.100.1') }}` | NAT bridge gateway |
| `common_kvm_nat_bridge_dhcp_start` | `{{ kvm_nat_bridge_dhcp_start \| default('192.168.100.100') }}` | NAT DHCP start |
| `common_kvm_nat_bridge_dhcp_end` | `{{ kvm_nat_bridge_dhcp_end \| default('192.168.100.200') }}` | NAT DHCP end |
| `common_kvm_routed_bridge_name` | `kvm-route-br0` | Routed bridge network name |
| `common_kvm_routed_bridge_subnet` | `{{ kvm_routed_bridge_subnet \| default('192.168.101.0/24') }}` | Routed bridge subnet (override in group_vars) |
| `common_kvm_routed_bridge_gateway` | `{{ kvm_routed_bridge_gateway \| default('192.168.101.1') }}` | Routed bridge gateway |
| `common_kvm_storage_pool_name` | `default` | Storage pool name |
| `common_kvm_storage_pool_path` | `{{ kvm_storage_pool_path \| default('/var/lib/libvirt/images') }}` | Storage pool path (override in group_vars) |
| `common_kvm_storage_pool_type` | `dir` | Storage pool type |
| `common_kvm_vm_default_memory_mb` | `2048` | Default VM memory |
| `common_kvm_vm_default_vcpus` | `2` | Default VM vCPUs |
| `common_kvm_vm_default_disk_gb` | `20` | Default VM disk size |
| `common_kvm_verify_install` | `true` | Run post-install verification |

## Dependencies

None.

## Example Playbook

```yaml
- hosts: cloud_servers
  become: true
  roles:
    - role: common-kvm
      vars:
        kvm_nat_bridge_subnet: "10.0.100.0/24"
        kvm_routed_bridge_subnet: "10.0.101.0/24"
        kvm_storage_pool_path: "/data/kvm/images"
```

## License

MIT
