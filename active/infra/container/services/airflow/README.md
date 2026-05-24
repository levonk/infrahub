# Airflow Layered Images (LocalNet)

Env-driven image naming:

- REGISTRY: http://localhost:8081/repository/docker-localnet
- NAMESPACE: localnet (default)
- IMAGE_PREFIX: a3i
- TAG: git short SHA (optionally date-prefixed)

PyPI:

- PIP_INDEX_URL: http://localhost:8081/repository/pip-public/simple
- BuildKit secret: nexus-pip-conf (pip.conf mounted at build)

Registry auth:

- Docker imagePullSecret: nexus-docker-creds (K8s)

Layers (per OS: Debian/Alpine):

- airflow-base-common: adds tzdata + tini; inherits non-root appuser
- base-python-{debian,alpine}: Python 3.14 + pip (Alpine fallback 3.13)
- airflow-core: Airflow 3.1.2 + constraints guard
- airflow-platform: providers (cncf.kubernetes, postgres, http, slack) with compatible ranges
- airflow-py: task base; no Airflow

Deployment:

- Official Airflow Helm chart; KubernetesExecutor; Postgres metadata DB
- Security: non-root, drop caps, read-only root FS, tmpfs for /tmp/logs, seccomp RuntimeDefault
- Observability: logs, Prometheus metrics, OpenTelemetry traces

## Quickstart

Follow these steps to build images and deploy Airflow on Kubernetes using the layered images.

### 1) Prerequisites

- **Docker Buildx** and Kubernetes cluster with `kubectl` and `helm`.
- **Nexus** running locally with Docker and PyPI proxies:
  - Docker registry: `http://localhost:8081/repository/docker-localnet/`
  - PyPI index: `http://localhost:8081/repository/pip-public/simple`
- Kubernetes namespace and secrets prepared:
  - `kubectl create namespace airflow || true`
  - Image pull secret `nexus-docker-creds` in `airflow` namespace.
  - Postgres connection Secret referenced in values (see below).

### 2) Environment

Set the tag scheme via environment variables (defaults shown):

```bash
REGISTRY="http://localhost:8081/repository/docker-localnet" && NAMESPACE="localnet" && IMAGE_PREFIX="a3i" && TAG="dev"
```

For PyPI during build, ensure BuildKit secret `nexus-pip-conf` exists and points to the Nexus index.

### 3) Build base images

Debian variant examples:

```bash
bash apps/active/devops/localnet/services/airflow/airflow-base-common/debian/docker/build.sh && bash apps/active/devops/localnet/services/airflow/base-python-debian/docker/build.sh
```

Alpine variant examples:

```bash
bash apps/active/devops/localnet/services/airflow/airflow-base-common/alpine/docker/build.sh && bash apps/active/devops/localnet/services/airflow/base-python-alpine/docker/build.sh
```

### 4) Build layered images

Debian:

```bash
bash apps/active/devops/localnet/services/airflow/airflow-core/docker/build-debian.sh && bash apps/active/devops/localnet/services/airflow/airflow-platform/docker/build-debian.sh && bash apps/active/devops/localnet/services/airflow/airflow-py/docker/build-debian.sh
```

Alpine:

```bash
bash apps/active/devops/localnet/services/airflow/airflow-core/docker/build-alpine.sh && bash apps/active/devops/localnet/services/airflow/airflow-platform/docker/build-alpine.sh && bash apps/active/devops/localnet/services/airflow/airflow-py/docker/build-alpine.sh
```

### 5) Push images to Nexus

Debian:

```bash
bash apps/active/devops/localnet/services/airflow/airflow-base-common/debian/docker/push.sh && bash apps/active/devops/localnet/services/airflow/base-python-debian/docker/push.sh && bash apps/active/devops/localnet/services/airflow/airflow-core/docker/push-debian.sh && bash apps/active/devops/localnet/services/airflow/airflow-platform/docker/push-debian.sh && bash apps/active/devops/localnet/services/airflow/airflow-py/docker/push-debian.sh
```

Alpine:

```bash
bash apps/active/devops/localnet/services/airflow/airflow-base-common/alpine/docker/push.sh && bash apps/active/devops/localnet/services/airflow/base-python-alpine/docker/push.sh && bash apps/active/devops/localnet/services/airflow/airflow-core/docker/push-alpine.sh && bash apps/active/devops/localnet/services/airflow/airflow-platform/docker/push-alpine.sh && bash apps/active/devops/localnet/services/airflow/airflow-py/docker/push-alpine.sh
```

### 6) Helm values

Use the provided values file to point the chart at your images, securityContext, observability, and DB Secret:

```text
specs/005-airflow-layered-images-spec/helm/values.localnet.yaml
```

Key toggles already set in values:

- `images.repository` and `tag` using the env-driven scheme above.
- `metrics.serviceMonitor.enabled: true` for Prometheus scraping.
- Component securityContext with `readOnlyRootFilesystem`, `allowPrivilegeEscalation: false`, tmpfs for logs/tmp.

Optional examples:

- NetworkPolicy: `specs/005-airflow-layered-images-spec/helm/networkpolicy.example.yaml`

### 7) Install Airflow (Helm)

```bash
helm repo add apache-airflow https://airflow.apache.org && helm repo update && helm upgrade --install airflow apache-airflow/airflow -n airflow -f specs/005-airflow-layered-images-spec/helm/values.localnet.yaml
```

### 8) Readiness checks

Wait for core components:

```bash
kubectl -n airflow wait --for=condition=available --timeout=600s deploy/airflow-webserver && kubectl -n airflow wait --for=condition=available --timeout=600s deploy/airflow-scheduler
```

Port-forward the webserver (if no Ingress):

```bash
kubectl -n airflow port-forward svc/airflow-webserver 8080:8080
```

### 9) Observability

- If the Prometheus Operator runs in another namespace, ensure a NetworkPolicy allow exists for its scrape traffic to the Airflow metrics Service.
- ServiceMonitor is enabled in values; verify targets appear in Prometheus.

### 10) NetworkPolicy (default-deny, minimal allows)

Apply examples selectively and add explicit egress for Postgres/K8s API and ingress for Prometheus, as needed:

```bash
kubectl -n airflow apply -f specs/005-airflow-layered-images-spec/helm/networkpolicy.example.yaml
```

## References

- Feature Quickstart: `specs/005-airflow-layered-images-spec/quickstart.md`
- Values file: `specs/005-airflow-layered-images-spec/helm/values.localnet.yaml`
- NetworkPolicy example: `specs/005-airflow-layered-images-spec/helm/networkpolicy.example.yaml`
