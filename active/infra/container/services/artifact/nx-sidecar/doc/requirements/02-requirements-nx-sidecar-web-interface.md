---
---

See [[00-initial-vision-nx-sidecar]] for background
See [[01-inital-requirements-nx-sidecar]] for functionality this ADDS to

---


### **Interfaces exposed**
1. **Local filesystem mount**  
2. **HTTP Nx Cache API**  

### **All read/write the same underlying data.**

This gives you compatibility across AI agents, build systems, and environments.


### **B. HTTP Nx Cache API**
A tiny service (Rust) exposing:

```
GET /cache/<hash>
PUT /cache/<hash>
```

Responsibilities:
- Validate Nx cache structure  
- Compress/decompress artifacts  
- Enforce TTL/eviction  
- Provide a dead‑simple protocol for agents  

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
If the agent is local → **use FS**.
If no constraints and need is distributed → **S3 is preferred**.
If the agent is simple, ephemeral, or AI‑driven → **use HTTP**.

---