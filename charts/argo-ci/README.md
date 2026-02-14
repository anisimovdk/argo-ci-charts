# argo-ci

Helm chart providing RBAC resources and EventBus to allow Argo Events to manage Argo Workflows.

## Overview

This chart creates:

- **ServiceAccount**: `argo-events-sa` for Argo Events components
- **Role**: `argo-events-role` with permissions to create and manage Workflows
- **RoleBinding**: `argo-events-binding` to bind the Role to the ServiceAccount
- **EventBus**: `argo-ci-eventbus` EventBus for Argo Events communication (optional)

## Installation

```bash
helm install argo-ci ./charts/argo-ci
```

## Configuration

| Parameter                         | Description                          | Default               |
| --------------------------------- | ------------------------------------ | --------------------- |
| `serviceAccount.name`             | Name of the ServiceAccount           | `argo-events-sa`      |
| `serviceAccount.annotations`      | Annotations for the ServiceAccount   | `{}`                  |
| `serviceAccount.labels`           | Labels for the ServiceAccount        | `{}`                  |
| `role.name`                       | Name of the Role                     | `argo-events-role`    |
| `role.annotations`                | Annotations for the Role             | `{}`                  |
| `role.labels`                     | Labels for the Role                  | `{}`                  |
| `role.rules`                      | RBAC rules for the Role              | See values.yaml       |
| `roleBinding.name`                | Name of the RoleBinding              | `argo-events-binding` |
| `roleBinding.annotations`         | Annotations for the RoleBinding      | `{}`                  |
| `roleBinding.labels`              | Labels for the RoleBinding           | `{}`                  |
| `eventBus.enabled`                | Enable EventBus creation             | `true`                |
| `eventBus.name`                   | Name of the EventBus                 | `argo-ci-eventbus`    |
| `eventBus.annotations`            | Annotations for the EventBus         | `{}`                  |
| `eventBus.labels`                 | Labels for the EventBus              | `{}`                  |
| `eventBus.nats.native.replicas`   | Number of NATS replicas              | `3`                   |
| `eventBus.nats.native.auth`       | NATS authentication strategy         | `token`               |
| `namespaceOverride`               | Override release namespace           | `""`                  |

## Usage

After installing, configure your Argo Events EventSource or Sensor to use the ServiceAccount:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: my-sensor
spec:
  serviceAccountName: argo-events-sa
  # ... rest of sensor config
```

## Customization

To add additional permissions:

```yaml
role:
  rules:
    - apiGroups: ["argoproj.io"]
      resources: ["workflows", "workflowtemplates"]
      verbs: ["create", "get", "list", "watch", "update", "patch"]
    - apiGroups: [""]
      resources: ["configmaps"]
      verbs: ["get", "list"]
```
