# Iron-Proxy Service Diagram Pack

⭐ **Purpose**

Illustrate the default control flow for the generated iron-proxy stack so the service owner can adapt it once custom dependencies or sidecars are added.

☑️ **Mermaid Flow**

```mermaid
flowchart LR
    Client["Client (user or upstream)"]


    Service["iron-proxy (backend)"]
    Dependency["Downstream dependency"]
    Health["Health endpoint /health"]
    Observability[(Observability stack)]



    Client --> Service

    Service --> Dependency
    Service --> Health
    Service --> Observability

```

☑️ **Mermaid Sequence**

```mermaid
sequenceDiagram
    participant Client as Client


    participant Service as iron-proxy
    participant Dependency as Downstream dependency
    participant Observability as Observability pipeline



    Client->>Service: Request

    Service->>Dependency: Query/command
    Dependency-->>Service: Result
    Service-->>Client: Response
    Service--)Observability: Log/trace event

```

✅ **Implementation Notes**

- Replace the `Downstream dependency` placeholder with real integrations such as databases, queues, or external APIs.
- Extend the diagrams when adding sidecars (migrations, workers, cron jobs) so the operational runbooks stay accurate.
- Ensure docker-compose overrides or k8s manifests remain in sync with this documentation when topologies change.
- Export finalized diagrams as SVG/PNG (`mmdc`) to embed in higher-level design docs or dashboards.
