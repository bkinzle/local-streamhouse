#!/usr/bin/env bash

#MISE description="Set up a HA PostgreSQL cluster using cloud-native postgres operator and declarative database schema management with Atlas and pgadmin4 preconfigured to connect"
#MISE depends=["check:kubecontext"]

helm upgrade --repo https://cloudnative-pg.github.io/charts cnpg cloudnative-pg \
  --version 0.26.1 \
  --namespace cnpg-system \
  --create-namespace \
  --install \
  --rollback-on-failure \
  --cleanup-on-fail \
  --values - <<EOF
config:
  data:
    WATCH_NAMESPACE: postgres
EOF

helm upgrade atlas-operator oci://ghcr.io/ariga/charts/atlas-operator \
  --version 0.7.13 \
  --namespace postgres \
  --create-namespace \
  --install \
  --rollback-on-failure \
  --cleanup-on-fail

envsubst < ./postgres/postgres-cluster.yaml | kubectl apply -n postgres -f -

# Wait for the operator to do its thing
while ! kubectl get secret ${STACK_NAME}-superuser -n postgres &>/dev/null; do echo "Waiting for ${STACK_NAME}-superuser secret. CTRL-C to exit."; sleep 1; done
kubectl wait --for=condition=Ready --timeout=600s cluster/${STACK_NAME} -n postgres

envsubst < ./postgres/db-schema.yaml | kubectl apply -n postgres -f -

export PG_USERNAME=$(kubectl get secret -n postgres ${STACK_NAME}-superuser -o jsonpath='{.data.username}' | base64 -d)
export PG_PASSWORD=$(kubectl get secret -n postgres ${STACK_NAME}-superuser -o jsonpath='{.data.password}' | base64 -d)

envsubst < ./postgres/pgadmin4.yaml | kubectl apply -n postgres -f -
