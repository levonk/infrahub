---
---

See [[00-initial-vision-nx-sidecar]] for background
See [[01-inital-requirements-nx-sidecar]] for local functionality this ADDS to
See [[02-requirements-nx-sidecar-web-interface]] for constrainted distributed functionality this ADDS to

---

---

# **3. Sidecar Components**

### **A. RustFS (S3 API)**
- Runs inside the sidecar container  
- Uses `/var/cache/nx-cache/` as its bucket root  
- Provides full S3 compatibility  
- Ideal for distributed agents  

---

# **4. When to Use Each Interface**

This is the part you asked for explicitly — here’s the authoritative guidance.

---

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

---

## **S3 Interface via RustFS (Preferred when distributed)**  
**Use when:**
- Agents run on different machines  
- You want a standard protocol  
- You want compatibility with existing S3 tooling  
- You want durability and replication (RustFS supports this)  

**Pros**
- Best for multi‑machine setups  
- Standardized  
- Works with any language  
- RustFS is fast and safe  

**Cons**
- Slightly more overhead than FS  
- Requires credentials (even if trivial)  

**Recommendation:**  
If the agent is remote → **use S3**.

If no constraints and agents are distributed → **S3 is preferred**.

---

## **HTTP Nx Cache API (Preferred for AI agents or minimal environments)**  
**Use when:**
- Agents cannot speak S3  
- Agents run in restricted sandboxes  
- You want Nx‑specific semantics  
- You want a simple, debuggable protocol  
- You want to enforce structure/validation  

**Pros**
- Easiest for AI agents  
- No S3 semantics (buckets, ACLs, multipart uploads)  
- Easy to debug with curl  
- Lets you enforce Nx‑specific rules  

**Cons**
- Not a standard object store  
- Slightly more work to implement  

**Recommendation:**  
If the agent is simple, ephemeral, or AI‑driven → **use HTTP**.

---

# **5. Do You Need Two Domain Names?**

### **Short answer:**  
**No — you do NOT need two domain names.**

### **Long answer:**  
You can expose all interfaces under **one domain**, using different ports or paths.

### **Recommended layout**

```
https://cache.example.com/s3/        → RustFS S3 API
https://cache.example.com/http/      → HTTP Nx Cache API
```

Or via ports:

```
cache.example.com:9000   → S3 (RustFS)
cache.example.com:8080   → HTTP Nx Cache API
```

### **When two domains *might* help**
Only if:
- You want separate TLS certs  
- You want separate auth policies  
- You want to isolate traffic for observability  

But **not required**.

---

# **6. Full Sidecar Specification (Implementation‑Ready)**

### **Container Responsibilities**
- Run RustFS (S3 API)  
- Run HTTP Nx Cache API  
- Mount `/var/cache/nx-cache/`  
- Expose ports:  
  - `9000` for S3  
  - `8080` for HTTP  
- Provide health checks  
- Provide metrics (optional)  

### **Environment Variables**
- `RUSTFS_ROOT=/var/cache/nx-cache/`  
- `NX_CACHE_DIR=/var/cache/nx-cache/`  
- `HTTP_CACHE_ROOT=/var/cache/nx-cache/`  

### **Volumes**
```
- /var/cache/nx-cache:/var/cache/nx-cache
```

### **Networking**
- Single domain recommended  
- TLS termination at reverse proxy (Caddy, Traefik, Nginx)  

### **Security**
- S3 auth keys (simple static keys)  
- HTTP API token (optional)  
- FS mount read/write for sidecar, read-only for agents  

---

# **7. Final Recommendation Summary**

### **If agent is local → use Local FS**  
Fastest, simplest, zero overhead.

### **If agent is remote → use S3 (RustFS)**  
Best distributed protocol, standard, robust.

### **If agent is minimal/AI‑driven → use HTTP**  
Simplest protocol, easiest to debug, no S3 semantics.

### **Domain names**
- **One domain is enough**  
- Use different ports or paths for S3 vs HTTP  

---
