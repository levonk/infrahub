
# **Infrastructure Monorepo — Unified Overview**

This repository is a **multi‑tenant, multi‑department, fully declarative infrastructure monorepo**.  
It contains everything required to build, configure, deploy, operate, and govern:

- the **shared global platform**, and  
- multiple **customers**, each with  
- multiple **departments**, each with  
- their own isolated infrastructure pipeline.

The repo is organized into **three top‑level namespaces**:

```
shared/      → global platform code
tenants/     → customer-specific code
<repo root>  → no platform or tenant code lives here
```

Inside each namespace, infrastructure is structured using a **numbered 00–08 pipeline**, representing the full lifecycle of infrastructure:

> **00‑os → 01‑build → 02‑config → 03‑container → 04‑deploy → 05‑gitops → 06‑provision → 07‑local → 08‑docs**

This ensures reproducibility, clarity, and strict separation of concerns.

---

# **📁 Top‑Level Structure**

```
shared/
tenants/
  customer-a/
  customer-b/
```

## **shared/**  
The **global platform** used by all customers.

Contains:

- global OS modules  
- global build pipelines  
- global Ansible roles  
- global container templates  
- global Helm charts  
- global GitOps platform components  
- global provisioning modules  
- global runbooks, ADRs, postmortems  

### Structure:

```
shared/
  active/
    00-os/
    01-build/
    02-config/
    03-container/
    04-deploy/
    05-gitops/
    06-provision/
    07-local/
    08-docs/
```

**Purpose:**  
Provide the shared backbone for all tenants.

**Excluded:**  
No tenant‑specific secrets, policies, apps, or overlays.

---

## **tenants/**  
Contains all **customer‑specific** and **department‑specific** infrastructure.

Each customer is isolated under its own directory:

```
tenants/
  customer-a/
  customer-b/
```

Inside each customer, you may optionally have departments:

```
tenants/
  customer-a/
    finance/
    ops/
    security/
```

Inside each department, you place the **00–08 pipeline**:

```
tenants/
  customer-a/
    finance/
      active/
        00-os/
        01-build/
        02-config/
        03-container/
        04-deploy/
        05-gitops/
        06-provision/
        07-local/
        08-docs/
```

### What goes here:

- tenant‑specific OS overlays  
- tenant‑specific build overrides  
- tenant‑specific Ansible inventories  
- tenant‑specific container services  
- tenant‑specific Helm values  
- tenant‑specific GitOps (apps, clusters, secrets, policies)  
- tenant‑specific provisioning (VMs, networks, cloud resources)  
- tenant‑specific runbooks, postmortems, ADRs  

### What does *not* go here:

- global platform components  
- global Helm charts  
- global Ansible roles  
- global OS modules  
- global provisioning modules  

---

# **📦 The 00–08 Pipeline (applies to shared/ and each tenant)**

Each namespace contains the same lifecycle structure:

### **00‑os — Base Operating System Layer**
- Nix modules  
- OS profiles  
- system‑level configuration primitives  

### **01‑build — Image Factories & Supply Chain Security**
- bootc images  
- packer templates  
- SBOM generation  
- Trivy scanning  
- Cosign signing  

### **02‑config — Host Configuration (Ansible)**
- playbooks  
- roles  
- inventories  
- requirements  

### **03‑container — Containerized Services**
- Dockerfiles / Containerfiles  
- Quadlets  
- service configs  
- internal docs  

### **04‑deploy — Deployment Artifacts (Helm)**
- Helm charts  
- Helm values templates  

### **05‑gitops — Declarative Cluster State**
- clusters/  
- apps/  
- platform/ (shared only)  
- secrets/  
- policy/  
- argo/ (bootstrap only)  
- flux/ (bootstrap only)  

### **06‑provision — Infrastructure Provisioning**
- Pulumi stacks  
- VM provisioning  
- cloud resources  
- network provisioning  

### **07‑local — Local Development Environments**
- Vagrant  
- local cluster setups  
- sandbox environments  

### **08‑docs — Operational Knowledge**
- runbooks  
- postmortems  
- ADRs  
- diagrams  
- architecture docs  
- security docs  

---

# **🚫 What Is Explicitly Kept Out of This Repo**

To maintain security and reproducibility:

- **No plaintext secrets**  
- **No machine‑specific state** (`/etc`, `/var`, etc.)  
- **No build artifacts** (images, binaries, qcow2, ISOs)  
- **No local developer clutter**  
- **No runtime logs or ephemeral data**  
- **No cloud credentials or SSH private keys**  
- **No generated manifests** (only source manifests)  

---

# **🧠 Philosophy of the Stack**

### **1. Multi‑tenant by design**  
Each customer and department is isolated.

### **2. Platform‑as‑shared‑service**  
The global platform lives in `shared/`.

### **3. Declarative Everything**  
Every layer is reproducible and versioned.

### **4. GitOps as the control plane**  
Clusters reconcile themselves from `05-gitops/`.

### **5. Security as a first‑class layer**  
Supply chain → cluster policy → operational security.

---

