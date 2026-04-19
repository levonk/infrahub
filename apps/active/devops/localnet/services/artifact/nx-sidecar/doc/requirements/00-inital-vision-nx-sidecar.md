---

NX Sidecar
- Providing NX centralized caching

# **1. High‑Level Architecture**

Your sidecar exposes **three cache interfaces**, all backed by the same underlying directory:

```
/var/cache/nx-cache/vANY
```

### **Interfaces exposed**
1. [[01-inital-requirements-nx-sidecar]] - Provides local docker service cache, has no dependencies, essentially a shared volume
1. [[02-requirements-nx-sidecar-web-interface]] - Provides remote web based service cache using the same data source as local data cache, depends on a sidecar installed web server and provides a pcnx plugin to integrate with it
1. [[03-requirements-nx-sidecar-s3-interface]] - Provides remote S3 based service cache using the same data source as local data cache, depends on S3 service like RustFS

### **All three read/write the same underlying data.**

This gives you maximum compatibility across AI agents, build systems, and environments.

---

# **2. Directory Layout (FHS‑compliant)**

```
/var/cache/nx-cache/
    ├── vANY/                     # Current Nx version ignorant storage
    │     ├── hashes/
    │     ├── outputs/
    │     └── terminalOutputs/
    └── v29/                     # future version that is incompatible with vANY
```
---