# Local Streamhouse
Creates local cloud native infrastructure for an Open Streamhouse, striving for parity with production.  Helpful for chaos engineering, experimenting with different fault modes as well as testing and understanding recovery methods.

## Quick Start
The following idempotent, all-in-one command will spin up the stack:
```shell
mise setup
```

When you're done, spin it down:
```shell
mise teardown
```

## Infrastructure
The following infrastructure components are automatically spun up:

- Realistic DNS using the `localtest.me` domain (which automatically resolves to `127.0.0.1`) and TLS certs
- OCI compliant Container Registry
- Kubernetes Cluster
  - Control plane (1 node)
  - Data plane (3 nodes)
    - Each labeled with one of `topology.kubernetes.io/zone` {us-central1-a, us-central1-b, us-central1-c}
  - Port-forwards to simulate north/south traffic into cluster {80, 443, 5234, 9094, etc.}
  - Trusted self-signed CA cert (only works on macOS)
  - Integrated to trust Container Registry
  - Automatically sets active kubecontext to use cluster
- Cilium CNI (for parity with GKE)
- cert-manager (cloud native certificate management)
- Kubernetes Gateway API (Ingress v2) implemented with Envoy Proxy Gateway
- metrics-server (container resource metrics for Kubernetes)
- MinIO (S3 compatible Object Storage)
- PostgreSQL (using CloudNativePG for HA architecture)
  - Atlas Operator (for declarative database management)
  - pgAdmin (integrated with server)
- Kafka (using Strimzi Kubernetes Operator)
  - Rack aware topology
  - Topic Operator (for declarative topic management)
  - Cruise Control (automatic rescaling/rebalancing)
  - Confluent Schema Registry
  - Kafbat (Kafka UI)
- Flink Kubernetes Operator (separate repo contains Flink Application code)
- Druid (real-time OLAP)
- OpenObserve (Open Source Observability Platform similar to Datadog)
- OpenTelemetry Collectors (integrated with OpenObserve)
- Keycloak (Open Source IdP)
- Lakekeeper (Iceberg REST Catalog)

## Endpoints
Once spun up the following endpoints are available:

- https://pgadmin4.localtest.me
- https://kafka-ui.localtest.me
- https://datalake.localtest.me
- https://druid-router.localtest.me
- https://openobserve.localtest.me
- https://hubble-ui.localtest.me
- https://keycloak.localtest.me
- https://lakekeeper.localtest.me
- datalake-api.localtest.me:80
- openobserve-grpc.localtest.me:443
- localtest.me:5432 (for postgres)
- bootstrap.stable-kafka.localtest.me:9094 (for kafka)
- localhost:5010 (for container registry outside of cluster)
- streamhouse-registry:4678 (for container registry inside of cluster)
- (Flink UI endpoints per Flink app will come from separate repo with application code)
