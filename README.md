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
- Kafka (using Strimzi Kubernetes Operator)
  - Rack aware topology
  - Topic Operator (for declarative topic management)
  - Cruise Control (automatic rescaling/rebalancing)
  - Confluent Schema Registry
  - Kafbat (Kafka UI)
- Flink Kubernetes Operator (separate repo contains Flink Application code)
- OpenObserve (Open Source Observability Platform similar to Datadog)
- OpenTelemetry Collectors (integrated with OpenObserve)
- Keycloak (Open Source IdP)
- (there's probably more I forgot to list here)
