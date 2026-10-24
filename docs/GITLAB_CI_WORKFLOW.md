# 🦊 GitLab CI/CD & Local Registry Workflow Guide

This document outlines the standard **GitLab CI/CD** pipeline pattern for applications deploying to this K3s cluster using the **in-cluster Docker Registry (`docker-registry.infra.svc.cluster.local:5000`)** and **BuildKit Rootless**.

---

## 🏗️ Architecture & High-Speed Build Workflow

```
[GitLab CI Pipeline]
       │
       ▼ (spawns pod on K3s)
[BuildKit Rootless Container]
       │
       ├── Reads Dockerfile & source
       ├── Imports build cache from local registry
       ├── Builds image layers
       └── Pushes image + cache to:
           docker-registry.infra.svc.cluster.local:5000/<app>:<tag>
       │
       ▼ (kubectl rollout)
[K3s containerd]
       │
       └── Pulls http://docker-registry.infra.svc.cluster.local:5000/<app>:<tag> (Zero WAN traffic)
```

---

## 📄 Standard `.gitlab-ci.yml` Template

Place this file in the root of your application repository:

```yaml
stages:
  - test
  - build
  - deploy

variables:
  # Host Node Direct IP Registry (Works for both BuildKit push & K3s containerd pull)
  INTERNAL_REGISTRY: "139.0.15.90:5000"
  IMAGE_NAME: "$INTERNAL_REGISTRY/apps/$CI_PROJECT_NAME"
  IMAGE_TAG: "$IMAGE_NAME:$CI_COMMIT_SHORT_SHA"
  IMAGE_LATEST: "$IMAGE_NAME:latest"
  CACHE_TAG: "$IMAGE_NAME:buildcache"

default:
  tags:
    - k3s
    - devops
    - linux

# -------------------------------------------------------------
# 1. Test Stage
# -------------------------------------------------------------
unit-tests:
  stage: test
  image: golang:1.24-alpine # Ganti sesuai runtime aplikasi (Node/Go/Python)
  script:
    - echo "Running tests..."
  rules:
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
    - if: '$CI_COMMIT_BRANCH == "main" || $CI_COMMIT_BRANCH == "dev"'

# -------------------------------------------------------------
# 2. Build Stage (BuildKit Rootless - Zero DNS Issue)
# -------------------------------------------------------------
build-and-push:
  stage: build
  image:
    name: moby/buildkit:rootless
    entrypoint: [""]
  variables:
    BUILDKITD_FLAGS: "--oci-worker-no-process-sandbox"
  before_script:
    - mkdir -p ~/.config/buildkit
    - |
      cat <<EOF > ~/.config/buildkit/buildkitd.toml
      [registry."${INTERNAL_REGISTRY}"]
        http = true
        insecure = true
      EOF
  script:
    - echo "Building and pushing image to ${IMAGE_TAG}..."
    - |
      buildctl-daemonless.sh build \
        --frontend=dockerfile.v0 \
        --local context=. \
        --local dockerfile=. \
        --output type=image,name=${IMAGE_TAG},push=true,registry.insecure=true \
        --export-cache type=registry,ref=${CACHE_TAG},mode=max,registry.insecure=true \
        --import-cache type=registry,ref=${CACHE_TAG}
  rules:
    - if: '$CI_COMMIT_BRANCH == "main" || $CI_COMMIT_BRANCH == "dev"'

# -------------------------------------------------------------
# 3. Deploy Stages
# -------------------------------------------------------------
deploy-dev:
  stage: deploy
  image: bitnami/kubectl:latest
  script:
    - echo "Deploying to Development (${CI_PROJECT_NAME}-dev)..."
    - kubectl set image deployment/${CI_PROJECT_NAME} ${CI_PROJECT_NAME}=${IMAGE_TAG} -n ${CI_PROJECT_NAME}-dev
    - kubectl rollout status deployment/${CI_PROJECT_NAME} -n ${CI_PROJECT_NAME}-dev --timeout=180s
  environment:
    name: development
    url: https://${CI_PROJECT_NAME}-dev.faisalaffan.com
  rules:
    - if: '$CI_COMMIT_BRANCH == "dev"'

deploy-prod:
  stage: deploy
  image: bitnami/kubectl:latest
  script:
    - echo "Deploying to Production (${CI_PROJECT_NAME})..."
    - kubectl set image deployment/${CI_PROJECT_NAME} ${CI_PROJECT_NAME}=${IMAGE_TAG} -n ${CI_PROJECT_NAME}
    - kubectl rollout status deployment/${CI_PROJECT_NAME} -n ${CI_PROJECT_NAME} --timeout=180s
  environment:
    name: production
    url: https://${CI_PROJECT_NAME}.faisalaffan.com
  rules:
    - if: '$CI_COMMIT_BRANCH == "main"'
      when: manual # Manual gate for production deploy
```

---

## ⚡ Key Benefits of This Setup
1. **Zero Bandwidth Overhead**: Image push & pull terjadi di level internal network cluster K3s (`docker-registry.infra.svc.cluster.local:5000`).
2. **BuildKit Layer Caching**: `--export-cache` disimpan di local registry tanpa hambatan upload speed, membuat build berikutnya selesai dalam hitungan detik.
3. **No Root / Privileged Requirement**: Menggunakan `moby/buildkit:rootless` sehingga Runner tidak memerlukan izin root/privileged pada host.
4. **Automated Weekly Maintenance**: Registry image layers lama yang tidak terpakai dibersihkan otomatis oleh CronJob `docker-registry-gc`.
