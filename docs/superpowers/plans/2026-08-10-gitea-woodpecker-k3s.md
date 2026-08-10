# Gitea + Woodpecker CI on k3s — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deploy Gitea (self-hosted Git) and Woodpecker CI (Kubernetes-native CI/CD) on existing k3s cluster, integrating with existing PostgreSQL, Mailpit, and Cloudflare ingress.

**Architecture:** Two new services under `kubernetes/infra/` following existing Kustomize single-file (`all.yaml`) pattern. Gitea on port 3000, Woodpecker server on port 8000 + agent using Kubernetes backend. Both share existing PostgreSQL. Secrets centralized via `.env` → `secrets-template.yaml` → `infra-secrets` Secret → `secretKeyRef`.

**Tech Stack:** k3s, Kustomize, Gitea 1.25, Woodpecker 3.4, PostgreSQL (existing), nginx ingress (existing), Cloudflare Tunnel (existing)

---

### File Map

| File | Action | Responsibility |
|------|--------|---------------|
| `.env` | Modify | Add Gitea + Woodpecker env vars |
| `.env.example` | Modify | Sync from `.env` |
| `kubernetes/infra/base/secrets-template.yaml` | Modify | Add Gitea/Woodpecker secret keys |
| `kubernetes/infra/gitea/all.yaml` | Create | PVC, Service, Deployment, ConfigMap |
| `kubernetes/infra/gitea/kustomization.yaml` | Create | Kustomize resource ref |
| `kubernetes/infra/woodpecker/all.yaml` | Create | PVC, Services, Server Deployment, Agent Deployment, RBAC, ConfigMap |
| `kubernetes/infra/woodpecker/kustomization.yaml` | Create | Kustomize resource ref |
| `kubernetes/infra/kustomization.yaml` | Modify | Add gitea + woodpecker to resource list |
| `kubernetes/infra/ingress/ingress.yaml` | Modify | Add git. and ci. host routes |

---

### Task 1: Add Gitea + Woodpecker env vars to `.env`

**Files:**
- Modify: `DEVOPS/.env` — append after existing Mailpit section (before NATS)

- [ ] **Step 1: Append Gitea section to `.env`**

Append after the Mailpit block (line ~164):

```bash
# ── Gitea ─────────────────────────────────────────────────────
GITEA_VERSION=1.25
GITEA_HTTP_PORT=3000
GITEA_SSH_PORT=2222
GITEA_DOMAIN=git.faisalaffan.com
GITEA_DB_HOST=postgres.infra.svc.cluster.local
GITEA_DB_PORT=5432
GITEA_DB_NAME=gitea
GITEA_DB_USER=postgres
GITEA_DB_PASSWORD=postgres_super_secret_2026
GITEA_ADMIN_USER=admin
GITEA_ADMIN_PASSWORD=gitea_admin_secret_2026
GITEA_ADMIN_EMAIL=faisallionel@gmail.com
GITEA_SMTP_HOST=mailpit.infra.svc.cluster.local
GITEA_SMTP_PORT=1025
GITEA_SMTP_FROM=gitea@faisalaffan.com
GITEA_DATA_SIZE=20Gi

# ── Woodpecker CI ─────────────────────────────────────────────
WOODPECKER_VERSION=3.4
WOODPECKER_SERVER_HOST=ci.faisalaffan.com
WOODPECKER_SERVER_PORT=8000
WOODPECKER_DB_HOST=postgres.infra.svc.cluster.local
WOODPECKER_DB_PORT=5432
WOODPECKER_DB_NAME=woodpecker
WOODPECKER_DB_USER=postgres
WOODPECKER_DB_PASSWORD=postgres_super_secret_2026
WOODPECKER_AGENT_SECRET=wp_agent_secret_replace_me_2026
WOODPECKER_GITEA_CLIENT=
WOODPECKER_GITEA_SECRET=
WOODPECKER_ADMIN_USER=admin
WOODPECKER_DATA_SIZE=10Gi
```

- [ ] **Step 2: Verify env vars readable**

Run: `grep -E "^GITEA_|^WOODPECKER_" .env | wc -l`
Expected: `20`

---

### Task 2: Add secrets to `secrets-template.yaml`

**Files:**
- Modify: `DEVOPS/kubernetes/infra/base/secrets-template.yaml` — append new keys

- [ ] **Step 1: Append secret entries**

Append these lines to `kubernetes/infra/base/secrets-template.yaml` under `stringData:`:

```yaml
  GITEA_DB_PASSWORD: "${GITEA_DB_PASSWORD}"
  GITEA_ADMIN_PASSWORD: "${GITEA_ADMIN_PASSWORD}"
  WOODPECKER_DB_PASSWORD: "${WOODPECKER_DB_PASSWORD}"
  WOODPECKER_AGENT_SECRET: "${WOODPECKER_AGENT_SECRET}"
  WOODPECKER_GITEA_CLIENT: "${WOODPECKER_GITEA_CLIENT}"
  WOODPECKER_GITEA_SECRET: "${WOODPECKER_GITEA_SECRET}"
```

- [ ] **Step 2: Verify file syntax**

Run: `kubectl kustomize kubernetes/infra/base/`
Expected: Secret manifest output with new keys, no errors.

---

### Task 3: Create Gitea manifests

**Files:**
- Create: `DEVOPS/kubernetes/infra/gitea/all.yaml`
- Create: `DEVOPS/kubernetes/infra/gitea/kustomization.yaml`

- [ ] **Step 1: Create `kubernetes/infra/gitea/kustomization.yaml`**

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: infra
resources:
  - all.yaml
```

- [ ] **Step 2: Create `kubernetes/infra/gitea/all.yaml`**

```yaml
# =========================================================================
# Gitea 1.25 — Self-hosted Git server
# HTTP: 3000 → Ingress (git.faisalaffan.com)
# DB: External PostgreSQL on postgres-0
# SMTP: Mailpit (mailpit.infra.svc.cluster.local:1025)
# =========================================================================
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: gitea-data
  namespace: infra
spec:
  accessModes: ["ReadWriteOnce"]
  storageClassName: local-path
  resources:
    requests:
      storage: ${GITEA_DATA_SIZE}
---
apiVersion: v1
kind: Service
metadata:
  name: gitea
  namespace: infra
spec:
  type: ClusterIP
  ports:
    - port: 3000
      targetPort: 3000
      name: http
  selector:
    app: gitea
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: gitea-config
  namespace: infra
data:
  app.ini: |
    APP_NAME = Gitea
    RUN_MODE = prod
    RUN_USER = git

    [server]
    PROTOCOL = http
    DOMAIN = ${GITEA_DOMAIN}
    ROOT_URL = https://${GITEA_DOMAIN}/
    HTTP_PORT = 3000
    LFS_START_SERVER = true
    DISABLE_SSH = true

    [database]
    DB_TYPE = postgres
    HOST = ${GITEA_DB_HOST}:${GITEA_DB_PORT}
    NAME = ${GITEA_DB_NAME}
    USER = ${GITEA_DB_USER}
    PASSWD = # filled via env GITEA__database__PASSWD

    [mailer]
    ENABLED = true
    PROTOCOL = smtp
    SMTP_ADDR = ${GITEA_SMTP_HOST}
    SMTP_PORT = ${GITEA_SMTP_PORT}
    FROM = ${GITEA_SMTP_FROM}
    SKIP_VERIFY = true

    [service]
    DISABLE_REGISTRATION = false
    REQUIRE_SIGNIN_VIEW = false

    [oauth2]
    ENABLED = true

    [log]
    MODE = console
    LEVEL = Info

    [security]
    INSTALL_LOCK = true
    SECRET_KEY = # auto-generated on first run, override via env to persist

    [repository]
    ENABLE_PUSH_CREATE_USER = true
    ENABLE_PUSH_CREATE_ORG = true
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: gitea
  namespace: infra
spec:
  replicas: 1
  selector:
    matchLabels:
      app: gitea
  template:
    metadata:
      labels:
        app: gitea
    spec:
      enableServiceLinks: false
      containers:
        - name: gitea
          image: gitea/gitea:${GITEA_VERSION}
          ports:
            - containerPort: 3000
              name: http
          env:
            - name: GITEA__database__PASSWD
              valueFrom:
                secretKeyRef:
                  name: infra-secrets
                  key: GITEA_DB_PASSWORD
            - name: GITEA__security__INSTALL_LOCK
              value: "true"
            - name: USER
              value: "git"
            - name: GITEA_ADMIN_USER
              value: "${GITEA_ADMIN_USER}"
            - name: GITEA_ADMIN_EMAIL
              value: "${GITEA_ADMIN_EMAIL}"
          envFrom:
            - configMapRef:
                name: gitea-config
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop: [ALL]
            seccompProfile:
              type: RuntimeDefault
          volumeMounts:
            - name: data
              mountPath: /data
            - name: config
              mountPath: /etc/gitea/app.ini
              subPath: app.ini
          resources:
            requests:
              memory: "256Mi"
              cpu: "100m"
            limits:
              memory: "1Gi"
              cpu: "1000m"
          readinessProbe:
            httpGet:
              path: /
              port: 3000
            initialDelaySeconds: 10
            periodSeconds: 5
          livenessProbe:
            httpGet:
              path: /
              port: 3000
            initialDelaySeconds: 30
            periodSeconds: 15
          startupProbe:
            httpGet:
              path: /
              port: 3000
            initialDelaySeconds: 5
            periodSeconds: 5
            failureThreshold: 30
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: gitea-data
        - name: config
          configMap:
            name: gitea-config
```

---

### Task 4: Create Woodpecker CI manifests

**Files:**
- Create: `DEVOPS/kubernetes/infra/woodpecker/all.yaml`
- Create: `DEVOPS/kubernetes/infra/woodpecker/kustomization.yaml`

- [ ] **Step 1: Create `kubernetes/infra/woodpecker/kustomization.yaml`**

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: infra
resources:
  - all.yaml
```

- [ ] **Step 2: Create `kubernetes/infra/woodpecker/all.yaml`**

```yaml
# =========================================================================
# Woodpecker CI 3.4 — Kubernetes-native CI/CD
# Server: 8000 → Ingress (ci.faisalaffan.com)
# Agent: Kubernetes backend, spawns pods per pipeline step
# DB: External PostgreSQL on postgres-0
# OAuth2: Gitea
# =========================================================================

# ── PVC for pipeline artifacts/logs ─────────────────────────
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: woodpecker-data
  namespace: infra
spec:
  accessModes: ["ReadWriteOnce"]
  storageClassName: local-path
  resources:
    requests:
      storage: ${WOODPECKER_DATA_SIZE}
---
# ── Server Service ──────────────────────────────────────────
apiVersion: v1
kind: Service
metadata:
  name: woodpecker-server
  namespace: infra
spec:
  type: ClusterIP
  ports:
    - port: 8000
      targetPort: 8000
      name: http
  selector:
    app: woodpecker-server
---
# ── Agent Service (gRPC, for other agents if needed) ────────
apiVersion: v1
kind: Service
metadata:
  name: woodpecker-agent
  namespace: infra
spec:
  type: ClusterIP
  ports:
    - port: 9000
      targetPort: 9000
      name: grpc
  selector:
    app: woodpecker-agent
---
# ── Server ConfigMap ────────────────────────────────────────
apiVersion: v1
kind: ConfigMap
metadata:
  name: woodpecker-server-config
  namespace: infra
data:
  WOODPECKER_HOST: https://${WOODPECKER_SERVER_HOST}
  WOODPECKER_OPEN: "true"
  WOODPECKER_ADMIN: "${WOODPECKER_ADMIN_USER}"
---
# ── Agent ConfigMap ────────────────────────────────────────
apiVersion: v1
kind: ConfigMap
metadata:
  name: woodpecker-agent-config
  namespace: infra
data:
  WOODPECKER_SERVER: "woodpecker-server.infra.svc.cluster.local:9000"
  WOODPECKER_BACKEND: kubernetes
  WOODPECKER_BACKEND_K8S_NAMESPACE: infra
  WOODPECKER_BACKEND_K8S_STORAGE_CLASS: local-path
  WOODPECKER_BACKEND_K8S_STORAGE_RWX: "false"
  WOODPECKER_BACKEND_K8S_POD_LABELS: "managed-by=woodpecker-ci"
  WOODPECKER_BACKEND_K8S_POD_ANNOTATIONS: "sidecar.istio.io/inject=false"
---
# ── Server Deployment ───────────────────────────────────────
apiVersion: apps/v1
kind: Deployment
metadata:
  name: woodpecker-server
  namespace: infra
spec:
  replicas: 1
  selector:
    matchLabels:
      app: woodpecker-server
  template:
    metadata:
      labels:
        app: woodpecker-server
    spec:
      enableServiceLinks: false
      containers:
        - name: woodpecker-server
          image: woodpeckerci/woodpecker-server:v${WOODPECKER_VERSION}
          ports:
            - containerPort: 8000
              name: http
            - containerPort: 9000
              name: grpc
          env:
            - name: WOODPECKER_HOST
              valueFrom:
                configMapKeyRef:
                  name: woodpecker-server-config
                  key: WOODPECKER_HOST
            - name: WOODPECKER_OPEN
              valueFrom:
                configMapKeyRef:
                  name: woodpecker-server-config
                  key: WOODPECKER_OPEN
            - name: WOODPECKER_ADMIN
              valueFrom:
                configMapKeyRef:
                  name: woodpecker-server-config
                  key: WOODPECKER_ADMIN
            - name: WOODPECKER_DATABASE_DRIVER
              value: "postgres"
            - name: WOODPECKER_DATABASE_DATASOURCE
              value: "postgres://${WOODPECKER_DB_USER}:$(WOODPECKER_DATABASE_PASSWORD)@${WOODPECKER_DB_HOST}:${WOODPECKER_DB_PORT}/${WOODPECKER_DB_NAME}?sslmode=disable"
            - name: WOODPECKER_DATABASE_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: infra-secrets
                  key: WOODPECKER_DB_PASSWORD
            - name: WOODPECKER_GITEA
              value: "true"
            - name: WOODPECKER_GITEA_URL
              value: "https://${GITEA_DOMAIN}"
            - name: WOODPECKER_GITEA_CLIENT
              valueFrom:
                secretKeyRef:
                  name: infra-secrets
                  key: WOODPECKER_GITEA_CLIENT
            - name: WOODPECKER_GITEA_SECRET
              valueFrom:
                secretKeyRef:
                  name: infra-secrets
                  key: WOODPECKER_GITEA_SECRET
            - name: WOODPECKER_AGENT_SECRET
              valueFrom:
                secretKeyRef:
                  name: infra-secrets
                  key: WOODPECKER_AGENT_SECRET
            - name: WOODPECKER_VOLUME
              value: "/var/lib/woodpecker"
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop: [ALL]
            seccompProfile:
              type: RuntimeDefault
          volumeMounts:
            - name: data
              mountPath: /var/lib/woodpecker
          resources:
            requests:
              memory: "128Mi"
              cpu: "100m"
            limits:
              memory: "512Mi"
              cpu: "500m"
          readinessProbe:
            httpGet:
              path: /healthz
              port: 8000
            initialDelaySeconds: 10
            periodSeconds: 5
          livenessProbe:
            httpGet:
              path: /healthz
              port: 8000
            initialDelaySeconds: 30
            periodSeconds: 15
          startupProbe:
            httpGet:
              path: /healthz
              port: 8000
            initialDelaySeconds: 5
            periodSeconds: 5
            failureThreshold: 30
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: woodpecker-data
---
# ── Agent RBAC (ClusterRole) ────────────────────────────────
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: woodpecker-agent
rules:
  - apiGroups: [""]
    resources: ["pods", "pods/log", "secrets", "services", "persistentvolumeclaims"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: ["batch"]
    resources: ["jobs"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: woodpecker-agent
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: woodpecker-agent
subjects:
  - kind: ServiceAccount
    name: woodpecker-agent
    namespace: infra
---
# ── Agent ServiceAccount ─────────────────────────────────────
apiVersion: v1
kind: ServiceAccount
metadata:
  name: woodpecker-agent
  namespace: infra
---
# ── Agent Deployment ────────────────────────────────────────
apiVersion: apps/v1
kind: Deployment
metadata:
  name: woodpecker-agent
  namespace: infra
spec:
  replicas: 1
  selector:
    matchLabels:
      app: woodpecker-agent
  template:
    metadata:
      labels:
        app: woodpecker-agent
    spec:
      serviceAccountName: woodpecker-agent
      enableServiceLinks: false
      containers:
        - name: woodpecker-agent
          image: woodpeckerci/woodpecker-agent:v${WOODPECKER_VERSION}
          ports:
            - containerPort: 9000
              name: grpc
          env:
            - name: WOODPECKER_SERVER
              valueFrom:
                configMapKeyRef:
                  name: woodpecker-agent-config
                  key: WOODPECKER_SERVER
            - name: WOODPECKER_AGENT_SECRET
              valueFrom:
                secretKeyRef:
                  name: infra-secrets
                  key: WOODPECKER_AGENT_SECRET
            - name: WOODPECKER_BACKEND
              valueFrom:
                configMapKeyRef:
                  name: woodpecker-agent-config
                  key: WOODPECKER_BACKEND
            - name: WOODPECKER_BACKEND_K8S_NAMESPACE
              valueFrom:
                configMapKeyRef:
                  name: woodpecker-agent-config
                  key: WOODPECKER_BACKEND_K8S_NAMESPACE
            - name: WOODPECKER_BACKEND_K8S_STORAGE_CLASS
              valueFrom:
                configMapKeyRef:
                  name: woodpecker-agent-config
                  key: WOODPECKER_BACKEND_K8S_STORAGE_CLASS
            - name: WOODPECKER_BACKEND_K8S_STORAGE_RWX
              valueFrom:
                configMapKeyRef:
                  name: woodpecker-agent-config
                  key: WOODPECKER_BACKEND_K8S_STORAGE_RWX
            - name: WOODPECKER_BACKEND_K8S_POD_LABELS
              valueFrom:
                configMapKeyRef:
                  name: woodpecker-agent-config
                  key: WOODPECKER_BACKEND_K8S_POD_LABELS
            - name: WOODPECKER_BACKEND_K8S_POD_ANNOTATIONS
              valueFrom:
                configMapKeyRef:
                  name: woodpecker-agent-config
                  key: WOODPECKER_BACKEND_K8S_POD_ANNOTATIONS
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop: [ALL]
            seccompProfile:
              type: RuntimeDefault
          resources:
            requests:
              memory: "128Mi"
              cpu: "100m"
            limits:
              memory: "512Mi"
              cpu: "500m"
```

---

### Task 5: Register Gitea + Woodpecker in root Kustomization

**Files:**
- Modify: `DEVOPS/kubernetes/infra/kustomization.yaml`

- [ ] **Step 1: Add gitea and woodpecker to resources list**

Add these two lines to the `resources:` array in `kubernetes/infra/kustomization.yaml`, after `excalidraw`:

```yaml
  - gitea
  - woodpecker
```

The file should look like:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: infra
resources:
  - base
  - postgres
  - mysql
  - nats-expose
  - redis
  - victoriametrics
  - loki
  - mailpit
  - mongo-ui
  - tempo
  - pyroscope
  - grafana
  - alloy
  - cloudflared
  - cloudbeaver
  - emqx
  - excalidraw
  - gitea
  - woodpecker
  - ingress
  - networkpolicy
```

- [ ] **Step 2: Dry-run validate entire kustomization**

Run: `kubectl kustomize kubernetes/infra/ 2>&1 | head -5`
Expected: YAML output begins, no error.

---

### Task 6: Add Gitea + Woodpecker to Ingress

**Files:**
- Modify: `DEVOPS/kubernetes/infra/ingress/ingress.yaml`

- [ ] **Step 1: Add hostnames to TLS section**

Add `- ${GITEA_DOMAIN}` and `- ${WOODPECKER_SERVER_HOST}` to the `tls.hosts` array, after the existing hosts:

```yaml
        - ${GITEA_DOMAIN}
        - ${WOODPECKER_SERVER_HOST}
```

- [ ] **Step 2: Add routing rules at end of `rules:` array**

Add two new rules before the closing of the `rules:` array:

```yaml
    - host: ${GITEA_DOMAIN}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: gitea
                port:
                  number: 3000
    - host: ${WOODPECKER_SERVER_HOST}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: woodpecker-server
                port:
                  number: 8000
```

- [ ] **Step 3: Validate ingress YAML**

Run: `kubectl kustomize kubernetes/infra/ingress/ 2>&1`
Expected: Ingress manifest output with new hosts, no error.

---

### Task 7: Sync `.env.example`

**Files:**
- Modify: `DEVOPS/.env.example`

- [ ] **Step 1: Copy Gitea and Woodpecker sections from `.env` to `.env.example`**

Copy the Gitea and Woodpecker sections verbatim from `.env` to `.env.example` (same sections, same values except leave OAuth2 fields empty).

---

### Task 8: Create databases on PostgreSQL

**Files:** None — manual operation on existing postgres-0

- [ ] **Step 1: Create `gitea` database**

Run:
```bash
kubectl exec -n infra postgres-0 -- psql -U postgres -c "CREATE DATABASE gitea;"
```
Expected: `CREATE DATABASE`

- [ ] **Step 2: Create `woodpecker` database**

Run:
```bash
kubectl exec -n infra postgres-0 -- psql -U postgres -c "CREATE DATABASE woodpecker;"
```
Expected: `CREATE DATABASE`

- [ ] **Step 3: Verify databases exist**

Run:
```bash
kubectl exec -n infra postgres-0 -- psql -U postgres -c "\l" | grep -E "gitea|woodpecker"
```
Expected: Both databases listed.

---

### Task 9: Apply and verify Gitea

- [ ] **Step 1: Apply Gitea manifests**

Run:
```bash
kubectl apply -k kubernetes/infra/gitea/
```
Expected:
```
persistentvolumeclaim/gitea-data created
service/gitea created
configmap/gitea-config created
deployment.apps/gitea created
```

- [ ] **Step 2: Wait for Gitea pod ready**

Run:
```bash
kubectl wait -n infra --for=condition=ready pod -l app=gitea --timeout=120s
```
Expected: `pod/gitea-xxx condition met`

- [ ] **Step 3: Verify Gitea accessible internally**

Run:
```bash
kubectl exec -n infra deploy/gitea -- wget -qO- http://localhost:3000/ | head -1
```
Expected: HTML containing `<title>Gitea</title>` or similar

- [ ] **Step 4: Verify ingress route resolves**

Check ingress picks up new host:
```bash
kubectl get ingress -n infra infra-ingress -o yaml | grep -A1 git.faisalaffan.com
```
Expected: Host line found.

---

### Task 10: Apply and verify Woodpecker

- [ ] **Step 1: Apply Woodpecker manifests (server + agent)**

Run:
```bash
kubectl apply -k kubernetes/infra/woodpecker/
```
Expected: Resources created (PVC, services, configmaps, deployments, RBAC).

- [ ] **Step 2: Wait for Woodpecker server pod ready**

Run:
```bash
kubectl wait -n infra --for=condition=ready pod -l app=woodpecker-server --timeout=120s
```
Expected: `pod/woodpecker-server-xxx condition met`

- [ ] **Step 3: Verify Woodpecker server accessible internally**

Run:
```bash
kubectl exec -n infra deploy/woodpecker-server -- wget -qO- http://localhost:8000/healthz
```
Expected: `{"status":"ok"}` or similar health response

- [ ] **Step 4: Wait for Woodpecker agent pod ready**

Run:
```bash
kubectl wait -n infra --for=condition=ready pod -l app=woodpecker-agent --timeout=120s
```
Expected: `pod/woodpecker-agent-xxx condition met`

---

### Task 11: Post-deployment — OAuth2 wiring

Manual steps after both services are running.

- [ ] **Step 1: Access Gitea web UI at https://git.faisalaffan.com**

Verify Gitea is reachable through Cloudflare Tunnel. First-time setup auto-creates admin user from env vars.

- [ ] **Step 2: Create OAuth2 application in Gitea**

In Gitea UI: Settings → Applications → Create a new OAuth2 Application:
- Name: `Woodpecker CI`
- Redirect URI: `https://ci.faisalaffan.com/authorize`

Copy the generated **Client ID** and **Client Secret**.

- [ ] **Step 3: Update `.env` with OAuth2 values**

```bash
WOODPECKER_GITEA_CLIENT=<paste-client-id>
WOODPECKER_GITEA_SECRET=<paste-client-secret>
```

- [ ] **Step 4: Re-apply base secrets and restart Woodpecker**

Run:
```bash
# Re-create infra-secrets with new OAuth2 values
kubectl delete secret -n infra infra-secrets
kubectl apply -k kubernetes/infra/base/
# Restart woodpecker server
kubectl rollout restart -n infra deploy/woodpecker-server
kubectl rollout status -n infra deploy/woodpecker-server --timeout=120s
```

- [ ] **Step 5: Verify Woodpecker login via Gitea**

Open https://ci.faisalaffan.com — should redirect to Gitea login. After login, Woodpecker dashboard should show.

- [ ] **Step 6: Verify agent connected**

In Woodpecker UI: Settings → Agents — agent should show as connected.

---

### Task 12: Final verification

- [ ] **Step 1: Verify all pods running**

Run:
```bash
kubectl get pods -n infra -l 'app in (gitea,woodpecker-server,woodpecker-agent)'
```
Expected: 3 pods all `Running`.

- [ ] **Step 2: Verify PVCs bound**

Run:
```bash
kubectl get pvc -n infra gitea-data woodpecker-data
```
Expected: Both `Bound`.

- [ ] **Step 3: Verify ingress TLS**

```bash
kubectl get ingress -n infra infra-ingress -o yaml | grep -E "git\.|ci\." | head -4
```
Expected: Both hosts listed.

---

### Commit Plan

After each task chunk, commit separately:

```bash
git add .env .env.example
git commit -m "feat(gitea): add Gitea and Woodpecker CI env vars"

git add kubernetes/infra/base/secrets-template.yaml
git commit -m "feat(gitea): add Gitea/Woodpecker secrets to infra-secrets template"

git add kubernetes/infra/gitea/
git commit -m "feat(gitea): add Gitea kustomize manifests"

git add kubernetes/infra/woodpecker/
git commit -m "feat(woodpecker): add Woodpecker CI server + agent manifests"

git add kubernetes/infra/kustomization.yaml kubernetes/infra/ingress/ingress.yaml
git commit -m "feat(gitea): register Gitea + Woodpecker in kustomization and ingress"
```
