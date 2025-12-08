#!/usr/bin/env bash

#MISE description="Set up a HA PostgreSQL cluster and a database schema and pgadmin4 preconfigured to connect"
#MISE depends=["check:kubecontext"]

kubectl apply -n streamhouse -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: ${PG_CLUSTER_NAME}-catalog-admin
type: kubernetes.io/basic-auth
stringData:
  username: catalog_admin
  password: iWillNeverTell
EOF

while ! kubectl get secret ${PG_CLUSTER_NAME}-catalog-admin -n streamhouse &>/dev/null; do echo "Waiting for ${PG_CLUSTER_NAME}-catalog-admin secret. CTRL-C to exit."; sleep 1; done

# Create the Postgres cluster
kubectl apply -n streamhouse -f - <<EOF
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: ${PG_CLUSTER_NAME}
spec:
  description: "Relational database for ${STACK_NAME}."
  imageName: ${POSTGRES_IMAGE}
  instances: 3

  primaryUpdateStrategy: unsupervised

  postgresql:
    parameters:
      shared_buffers: 256MB
      pg_stat_statements.max: '10000'
      pg_stat_statements.track: all
      auto_explain.log_min_duration: '10s'
      pgaudit.log: 'all, -misc'
      pgaudit.log_catalog: 'off'
      pgaudit.log_parameter: 'on'
      pgaudit.log_relation: 'on'
      pgaudit.log_client: 'on'

  bootstrap:
    initdb:
      database: operational_datastore
      owner: operational_datastore

  enableSuperuserAccess: true

  storage:
    storageClass: standard
    size: 1Gi
  
  managed:
    roles:
      - name: catalog_admin
        login: true
        passwordSecret:
          name: ${PG_CLUSTER_NAME}-catalog-admin
        createdb: true
EOF

# Wait for the operator to do its thing
while ! kubectl get secret ${PG_CLUSTER_NAME}-superuser -n streamhouse &>/dev/null; do echo "Waiting for ${PG_CLUSTER_NAME}-superuser secret. CTRL-C to exit."; sleep 1; done
kubectl wait --for=condition=Ready --timeout=600s cluster/${PG_CLUSTER_NAME} -n streamhouse

# Manage the operational_datastore db schema
kubectl apply -n streamhouse -f - <<EOF
apiVersion: db.atlasgo.io/v1alpha1
kind: AtlasSchema
metadata:
  name: operational-datastore
spec:
  credentials:
    scheme: postgres
    host: ${PG_CLUSTER_NAME}-rw.streamhouse.svc
    userFrom:
      secretKeyRef:
        key: user
        name: ${PG_CLUSTER_NAME}-app
    passwordFrom:
      secretKeyRef:
        key: password
        name: ${PG_CLUSTER_NAME}-app
    database: operational_datastore
    port: 5432
  schema:
    sql: |
      create table public.product (
        id int not null generated always as identity,
        name varchar(600) not null,
        primary key (id)
      );

      create table public.feature (
        id int not null generated always as identity,
        name varchar(600) not null,
        primary key (id)
      );

      create table public.product_feature (
        product_id int not null,
        feature_id int not null,
        primary key (product_id, feature_id),
        constraint fk_product foreign key(product_id) references public.product(id),
        constraint fk_feature foreign key(feature_id) references public.feature(id)
      );

      create table public.feature_metric (
        timestamp timestamptz not null,
        start_timestamp timestamptz,
        account_id varchar(255) not null,
        graph_id varchar(255) not null,
        graph_variant varchar(255) not null,
        agent_version varchar(255) not null,
        router_id varchar(255) not null,
        metric_name varchar(255) not null,
        metric_value jsonb null,
        attributes jsonb
      );
EOF

# Create the iceberg_catalog database
kubectl apply -n streamhouse -f - <<EOF
apiVersion: postgresql.cnpg.io/v1
kind: Database
metadata:
  name: iceberg-catalog
spec:
  cluster:
    name: ${PG_CLUSTER_NAME}
  name: iceberg_catalog
  owner: catalog_admin
EOF

export PG_USERNAME=$(kubectl get secret -n streamhouse ${PG_CLUSTER_NAME}-superuser -o jsonpath='{.data.username}' | base64 -d)
export PG_PASSWORD=$(kubectl get secret -n streamhouse ${PG_CLUSTER_NAME}-superuser -o jsonpath='{.data.password}' | base64 -d)

# Deploy pgadmin4 preconfigured to connect to the Postgres cluster
kubectl apply -n streamhouse -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: pgadmin4-server-connections
stringData:
  servers.json: |
    {
        "Servers": {
            "1": {
                "Name": "${PG_CLUSTER_NAME}-rw",
                "Group": "Local K8s HA Cluster",
                "Port": 5432,
                "Username": "${PG_USERNAME}",
                "Host": "${PG_CLUSTER_NAME}-rw",
                "SSLMode": "prefer",
                "MaintenanceDB": "postgres",
                "ConnectionParameters": {
                    "sslmode": "prefer",
                    "connect_timeout": 10,
                    "passfile": "/var/lib/pgadmin/storage/pgadmin4_pgadmin.org/pgpass"
                }
            }
        }
    }
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app.kubernetes.io/name: pgadmin4
  name: pgadmin4
spec:
  replicas: 1
  selector:
    matchLabels:
      app: pgadmin4
  template:
    metadata:
      labels:
        app: pgadmin4
    spec:
      containers:
      - image: dpage/pgadmin4:latest
        name: pgadmin4
        securityContext:
          runAsUser: 0
        command: ["/bin/sh","-c","mkdir -p /var/lib/pgadmin/storage/pgadmin4_pgadmin.org;
                  cp /etc/secret-volume/pgpass /var/lib/pgadmin/storage/pgadmin4_pgadmin.org/pgpass;
                  chmod 600 /var/lib/pgadmin/storage/pgadmin4_pgadmin.org/pgpass;
                  /entrypoint.sh;
                  "]
        env:
        - name: PGADMIN_DEFAULT_EMAIL
          value: "pgadmin4@pgadmin.org"
        - name: PGADMIN_DEFAULT_PASSWORD
          value: "weak"
        - name: PGADMIN_CONFIG_SERVER_MODE
          value: "False"
        - name: PGADMIN_CONFIG_MASTER_PASSWORD_REQUIRED
          value: "False"
        - name: PGADMIN_SERVER_JSON_FILE
          value: "/etc/server-connections/servers.json"
        volumeMounts:
          - name: secret-volume
            readOnly: true
            mountPath: "/etc/secret-volume"
          - name: server-connections
            readOnly: true
            mountPath: "/etc/server-connections"
      volumes:
        - name: secret-volume
          secret:
            secretName: ${PG_CLUSTER_NAME}-superuser
            defaultMode: 0600
        - name: server-connections
          secret:
            secretName: pgadmin4-server-connections
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app.kubernetes.io/name: pgadmin4
  name: pgadmin4
spec:
  ports:
  - name: http
    port: 80
    protocol: TCP
    targetPort: 80
  selector:
    app: pgadmin4
  type: ClusterIP
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: pgadmin4
  labels:
    app.kubernetes.io/name: pgadmin4
spec:
  parentRefs:
    - kind: Gateway
      name: envoy-gateway
      namespace: gateway-system
      sectionName: https
  hostnames:
    - pgadmin4.${DNSMASQ_DOMAIN}
  rules:
    - backendRefs:
      - kind: Service
        name: pgadmin4
        port: 80
EOF

# Make postgres externally accessible via the gateway
kubectl apply -n streamhouse -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1alpha2
kind: TCPRoute
metadata:
  name: postgres
spec:
  parentRefs:
    - kind: Gateway
      name: envoy-gateway
      namespace: gateway-system
      sectionName: postgres
  rules:
  - backendRefs:
    - name: ${PG_CLUSTER_NAME}-rw
      port: 5432
EOF