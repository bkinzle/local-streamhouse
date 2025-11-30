#!/usr/bin/env bash

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
        replicas: 3
        pod:
          nodeSelector:
            ingress-ready: "true"
      envoyService:
        externalTrafficPolicy: Local
        type: NodePort
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
    - name: https
      protocol: HTTPS
      port: 443
      hostname: "*.${DNSMASQ_DOMAIN}"
      tls:
        mode: Terminate
        certificateRefs:
          - name: wildcard-dnsmasq-domain-tls
            kind: Secret
EOF
