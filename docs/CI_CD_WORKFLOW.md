# 🚀 Woodpecker CI/CD & Multi-Environment Workflow Guide

This document outlines the standard CI/CD pipeline pattern for business applications (`ewallet`, `wasteco`, `resolva`) deploying to the dual-environment K3s cluster.

---

## 🌿 1. Branching Strategy

| Branch | Target Environment | Target Namespace | Ingress Domain Pattern | Vault Secret Path | Database |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **`dev`** | **Development** | `<app>-dev` | `*-dev.faisalaffan.com` | `secret/data/<app>/dev` | `<app>_dev` |
| **`main`** | **Production** | `<app>` | `*.faisalaffan.com` | `secret/data/<app>/prod` | `<app>` / `<app>_prod` |

---

## 🛠️ 2. Standard `.woodpecker.yaml` Pipeline Template

Place this file in the root of your application repository (e.g. `reconciliation-frontend`, `reconciliation-backend`, `ewallet`, `wasteco`):

```yaml
when:
  - event: [push, tag]

steps:
  # -------------------------------------------------------------
  # Step 1: Build and Push Docker Image to Private Registry
  # -------------------------------------------------------------
  - name: publish-dev
    image: plugins/docker
    settings:
      registry: registry.faisalaffan.com
      repo: registry.faisalaffan.com/apps/${CI_REPO_NAME}
      tags:
        - ${CI_COMMIT_BRANCH}
        - dev-${CI_COMMIT_SHA:0:8}
      username:
        from_secret: REGISTRY_USER
      password:
        from_secret: REGISTRY_PASSWORD
      insecure: false
    when:
      branch: dev

  - name: publish-prod
    image: plugins/docker
    settings:
      registry: registry.faisalaffan.com
      repo: registry.faisalaffan.com/apps/${CI_REPO_NAME}
      tags:
        - latest
        - ${CI_COMMIT_SHA:0:8}
      username:
        from_secret: REGISTRY_USER
      password:
        from_secret: REGISTRY_PASSWORD
      insecure: false
    when:
      branch: main

  # -------------------------------------------------------------
  # Step 2: Deploy to Kubernetes Cluster via Woodpecker Agent
  # -------------------------------------------------------------
  - name: deploy-dev
    image: bitnami/kubectl:latest
    commands:
      # Apply manifests and update image to newly built tag
      - kubectl apply -f kubernetes/ -n ${CI_REPO_NAME}-dev
      - kubectl set image deployment/${CI_REPO_NAME} ${CI_REPO_NAME}=registry.faisalaffan.com/apps/${CI_REPO_NAME}:dev-${CI_COMMIT_SHA:0:8} -n ${CI_REPO_NAME}-dev
      - kubectl rollout status deployment/${CI_REPO_NAME} -n ${CI_REPO_NAME}-dev --timeout=120s
    when:
      branch: dev

  - name: deploy-prod
    image: bitnami/kubectl:latest
    commands:
      # Apply manifests and update image to newly built tag
      - kubectl apply -f kubernetes/ -n ${CI_REPO_NAME}
      - kubectl set image deployment/${CI_REPO_NAME} ${CI_REPO_NAME}=registry.faisalaffan.com/apps/${CI_REPO_NAME}:${CI_COMMIT_SHA:0:8} -n ${CI_REPO_NAME}
      - kubectl rollout status deployment/${CI_REPO_NAME} -n ${CI_REPO_NAME} --timeout=180s
    when:
      branch: main
```

---

## 🔐 3. Vault Secret Injection Template

For applications retrieving environment secrets from HashiCorp Vault, use the Vault Agent annotations in your Deployment `spec.template.metadata.annotations`:

### For Development (`dev`):
```yaml
spec:
  template:
    metadata:
      annotations:
        vault.hashicorp.com/agent-inject: "true"
        vault.hashicorp.com/role: "resolva-dev-role" # or ewallet-dev-role, wasteco-dev-role
        vault.hashicorp.com/agent-inject-secret-.env: "secret/data/resolva/dev"
        vault.hashicorp.com/agent-inject-template-.env: |
          {{- with secret "secret/data/resolva/dev" -}}
          {{- range $key, $value := .Data.data }}
          {{ $key }}={{ $value }}
          {{- end }}
          {{- end -}}
```

### For Production (`main`):
```yaml
spec:
  template:
    metadata:
      annotations:
        vault.hashicorp.com/agent-inject: "true"
        vault.hashicorp.com/role: "resolva-prod-role" # or ewallet-prod-role, wasteco-prod-role
        vault.hashicorp.com/agent-inject-secret-.env: "secret/data/resolva/prod"
        vault.hashicorp.com/agent-inject-template-.env: |
          {{- with secret "secret/data/resolva/prod" -}}
          {{- range $key, $value := .Data.data }}
          {{ $key }}={{ $value }}
          {{- end }}
          {{- end -}}
```

---

## 📊 4. Namespace Resource Quotas & Limits

All pods in Dev and Prod are automatically guarded by `LimitRange` and `ResourceQuota`:

- **Development Quota**: Max 10 pods, 500m / 1 CPU, 512Mi / 1Gi RAM.
  - *Default container limits*: 100m CPU / 128Mi RAM request, 250m CPU / 256Mi RAM limit.
- **Production Quota**: Max 25 pods, 2 CPU / 4 CPU, 2Gi / 4Gi RAM.
  - *Default container limits*: 200m CPU / 256Mi RAM request, 1.0 CPU / 1Gi RAM limit.
