#!/usr/bin/env bash
set -euo pipefail

#MISE description="Set up an envoy proxy gateway for ingress"
#MISE depends=["check:kubecontext"]

# Step 1: Install or upgrade the Envoy Gateway API controller (control plane)
helm upgrade envoy-gateway-controller oci://docker.io/envoyproxy/gateway-helm \
  --version ${ENVOY_PROXY_GATEWAY_VERSION} \
  --namespace gateway-system \
  --create-namespace \
  --install \
  --skip-crds \
  --rollback-on-failure \
  --cleanup-on-fail \
  --values - <<EOF
deployment:
  replicas: 2
  pod:
    nodeSelector:
      ingress-ready: "true"
EOF

# Step 2: Now that the Gateway control plane is installed, the Deployment and Service for the Proxy (data plane) can be configured with EnvoyProxy CRD
kubectl apply -f - <<EOF
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: EnvoyProxy
metadata:
  name: envoy-proxy-data-plane
  namespace: gateway-system
spec:
  provider:
    type: Kubernetes
    kubernetes:
      envoyDeployment:
        name: envoy-proxy
        replicas: 3
        pod:
          nodeSelector:
            ingress-ready: "true"
      envoyService:
        name: envoy-proxy
        externalTrafficPolicy: Local
        type: NodePort
        patch:
          value:
            spec:
              ports:
              # Port 80 on your laptop gets forwarded to NodePort 30000 of the kind cluster
              - name: http-80
                nodePort: 30000
                port: 80
                protocol: TCP
                targetPort: 10080
              # Port 443 on your laptop gets forwarded to NodePort 30001 of the kind cluster
              - name: http-443
                nodePort: 30001
                port: 443
                protocol: TCP
                targetPort: 10443
              # Port 5432 on your laptop gets forwarded to NodePort 30002 of the kind cluster
              - name: postgres-5432
                nodePort: 30002
                port: 5432
                protocol: TCP
                targetPort: 5432
EOF

# Step 3: Setup the standard k8s GatewayClass having it use the Envoy Gateway controller (by creating the EnvoyProxy first we avoid re-configure/deploy disruption)
kubectl apply -n gateway-system -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: envoy-gateway
spec:
  controllerName: gateway.envoyproxy.io/gatewayclass-controller
  parametersRef:
    group: gateway.envoyproxy.io
    kind: EnvoyProxy
    name: envoy-proxy-data-plane
    namespace: gateway-system
EOF

# Step 4: Setup the standard k8s Gateway and configure attaching listeners (linking to the EnvoyProxy)
kubectl apply -n gateway-system -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: envoy-gateway
  annotations:
    cert-manager.io/cluster-issuer: ca-issuer
spec:
  gatewayClassName: envoy-gateway
  listeners:
    - name: http
      protocol: HTTP
      port: 80
      allowedRoutes:
        namespaces:
          from: All
    - name: https
      protocol: HTTPS
      port: 443
      allowedRoutes:
        namespaces:
          from: All
      hostname: "*.${DNSMASQ_DOMAIN}"
      tls:
        mode: Terminate
        certificateRefs:
          - name: wildcard-dnsmasq-domain-tls
            kind: Secret
    - name: postgres
      protocol: TCP
      port: 5432
      allowedRoutes:
        kinds:
          - kind: TCPRoute
        namespaces:
          from: All
    - name: kafka
      protocol: TCP
      port: 9092
      allowedRoutes:
        kinds:
          - kind: TCPRoute
        namespaces:
          from: All
EOF

# See cilium.sh for comment about Hubble UI route creation timing
kubectl apply -n kube-system -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: hubble-ui
spec:
  parentRefs:
    - kind: Gateway
      name: envoy-gateway
      namespace: gateway-system
      sectionName: https
  hostnames:
    - hubble-ui.${DNSMASQ_DOMAIN}
  rules:
    - backendRefs:
      - kind: Service
        name: hubble-ui
        port: 80
EOF
