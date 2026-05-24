---
---

See [[00-initial-vision-nx-sidecar]] for background

---




### **C. Local Filesystem**
Bind‑mount `/var/cache/nx-cache/` into agent containers.

Materialized path will be:

```text
/var/cache/nx-cache/vANY/
  ├── hashes/
  ├── terminalOutputs/
  └── outputs/
```



## **Local Filesystem (Preferred when local)**  
**Use when:**
- Agents run on the same host  
- You want maximum speed  
- You want zero network overhead  
- You want deterministic, POSIX‑level behavior  

**Pros**
- Fastest  
- Simplest  
- Zero serialization overhead  
- No auth needed  

**Cons**
- Only works on same machine or shared volume  
- Not suitable for distributed agents  

**Recommendation:**  
If the agent is local → **use FS**.


## Decisions
- depend on shared volume mounted from  `pnpm-sidecar` to install the `nx` package 
- Use `pnpm` to install the `nx` package in /apps/active/devops/localnet/services/artifact/nx-sidecar/assets/static/nx-sidecar/entrypoint-nx-sidecar.sh

## Open Querstions
- Can this use the pnpm-builder stage from pnpm-sidecar to leverage the pnpm install? Should it?
- Nx needs to be installed in the entrypoint script to leverage the shared volume since it's not available in alpine linux repo
- would it be easier to make this depend on pnpm-sidcar so it has pnpm tooling, or should it cotniue to depend on localnet-base-sidecar (which pnpm-sidecar does already) to prevent unecessary inter-dependency?