#!/usr/bin/env bash
set -euo pipefail

#MISE description="Set up Keycloak for a local Identity Provider (IdP), facilitating production-like user authentication and authorization for apps and services"
#MISE depends=["check:kubecontext"]

# Install the CRDs independently
kubectl apply -f https://raw.githubusercontent.com/keycloak/keycloak-k8s-resources/${KEYCLOAK_VERSION}/kubernetes/keycloaks.k8s.keycloak.org-v1.yml
kubectl apply -f https://raw.githubusercontent.com/keycloak/keycloak-k8s-resources/${KEYCLOAK_VERSION}/kubernetes/keycloakrealmimports.k8s.keycloak.org-v1.yml

# No helm chart available so we'll use kubectl to apply the operator directly (it's namespaced to just watch the 'keycloak' namespace)
kubectl describe ns keycloak &>/dev/null || kubectl create ns keycloak
kubectl -n keycloak apply -f https://raw.githubusercontent.com/keycloak/keycloak-k8s-resources/${KEYCLOAK_VERSION}/kubernetes/kubernetes.yml

# Copy around the postgres secret for Keycloak to use for its db credentials
kubectl apply -n keycloak -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: keycloak-idp-admin-password
type: kubernetes.io/basic-auth
stringData:
  username: admin
  password: iWillNeverTell
---
apiVersion: v1
kind: Secret
metadata:
  name: ${PG_CLUSTER_NAME}-keycloak-admin
type: Opaque
data:
  username: $(kubectl get secret ${PG_CLUSTER_NAME}-keycloak-admin -n streamhouse -o jsonpath='{.data.username}')
  password: $(kubectl get secret ${PG_CLUSTER_NAME}-keycloak-admin -n streamhouse -o jsonpath='{.data.password}')
EOF

# Create a Keycloak instance
kubectl apply -n keycloak -f - <<EOF
apiVersion: k8s.keycloak.org/v2alpha1
kind: Keycloak
metadata:
  name: keycloak-idp
spec:
  instances: 1
  ingress:
    enabled: false
  bootstrapAdmin:
    user:
      secret: keycloak-idp-admin-password
  db:
    vendor: postgres
    usernameSecret:
      name: ${PG_CLUSTER_NAME}-keycloak-admin
      key: username
    passwordSecret:
      name: ${PG_CLUSTER_NAME}-keycloak-admin
      key: password
    host: ${PG_CLUSTER_NAME}-rw.streamhouse.svc
    database: keycloak
    port: 5432
    schema: public
  http:
    httpEnabled: true
  hostname:
    hostname: https://keycloak.${DNSMASQ_DOMAIN}
  proxy:
    headers: xforwarded
EOF
    # networkPolicy:
    #   enabled: false

kubectl apply -n keycloak -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: keycloak
spec:
  parentRefs:
    - kind: Gateway
      name: envoy-gateway
      namespace: gateway-system
      sectionName: https
  hostnames:
    - keycloak.${DNSMASQ_DOMAIN}
  rules:
    - backendRefs:
      - kind: Service
        name: keycloak-idp-service
        port: 8080
EOF
