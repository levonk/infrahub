# Sysbox for LocalStack

This directory contains resources for using [Sysbox](https://github.com/nestybox/sysbox) with LocalStack. Sysbox allows running system containers (like Docker-in-Docker) securely without using privileged mode or mounting the host's Docker socket.

## Compatibility Notes

- **Mise**: Sysbox is a system-level container runtime and is **not** available as a `mise` plugin. It must be installed as a system package.
- **WSL2**: Sysbox is **not officially supported** on WSL2. While it may work with specific kernel configurations, it is generally recommended to use the standard Docker socket mount on WSL2 to avoid compatibility issues.

## Installation

Sysbox must be installed on the host machine.

### Debian/Ubuntu

Run the provided installation script:

```bash
sudo ./install.sh
```

**Note**: The script includes a warning if it detects WSL2.

Or follow the official [installation guide](https://github.com/nestybox/sysbox/blob/master/docs/user-guide/install-package.md).

## Usage

Once installed, services configured with `runtime: sysbox-runc` will automatically use Sysbox.

### Verification

You can verify the installation by running the test service:

```bash
docker-compose -f ../docker-compose.security.yml up -d sysbox-test
docker exec -it localnet-security-sysbox-test docker ps
```

(Note: The test container should have a running Docker daemon inside).
