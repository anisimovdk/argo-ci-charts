# argo-ci-charts

A collection of Helm charts for using Argo Workflows and Argo Events as a continuous integration (CI) engine. These charts enable you to run your build pipelines natively in Kubernetes, leveraging the power of the Argo ecosystem for event-driven workflow automation.

**Registry:** [Docker Hub - anisimovdk](https://hub.docker.com/repositories/anisimovdk)

**Table of Contents**:

- [argo-ci-charts](#argo-ci-charts)
  - [Charts](#charts)
    - [argo-ci](#argo-ci)
    - [argo-ci-trigger](#argo-ci-trigger)
  - [Prerequisites](#prerequisites)
  - [Quick Start](#quick-start)
  - [Layout](#layout)
  - [Installing Charts](#installing-charts)
  - [Development](#development)
    - [Building and Publishing](#building-and-publishing)
  - [Conventions](#conventions)
  - [License](#license)

## Charts

### [argo-ci](charts/argo-ci/README.md)

Provides RBAC resources and EventBus configuration to enable Argo Events to manage Argo Workflows.

**Includes:**

- ServiceAccount for Argo Events components
- Role with workflow management permissions
- RoleBinding to connect service account and role
- EventBus for Argo Events communication (optional)

**Use this chart to:** Set up the foundational permissions and infrastructure for Argo Events to trigger and manage workflows.

### [argo-ci-trigger](charts/argo-ci-trigger/README.md)

Deploys GitHub webhook listeners and CI workflow templates using Argo Events.

**Includes:**

- EventSource for GitHub webhooks
- Sensor to trigger workflows on GitHub events
- WorkflowTemplate defining CI pipelines
- Ingress for webhook endpoint exposure
- Secret management (native or External Secrets Operator)

**Use this chart to:** Configure automated CI pipelines triggered by GitHub events (push, pull request, etc.).

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- [Argo Events](https://argoproj.github.io/argo-events/) installed and configured
- [Argo Workflows](https://argoproj.github.io/argo-workflows/) installed and configured

**Note:** The `argo-ci-trigger` chart requires the `argo-ci` chart to be installed first, as it depends on the ServiceAccount and EventBus created by `argo-ci`.

## Quick Start

1. Install the base RBAC and EventBus:

   ```bash
   helm install argo-ci oci://docker.io/anisimovdk/argo-ci --version 0.1.0
   ```

2. Install a GitHub webhook trigger:

   ```bash
   helm install my-app-ci oci://docker.io/anisimovdk/argo-ci-trigger --version 0.1.1 \
     --set host=ci.example.com \
     --set eventSource.github.repository=myorg/myrepo
   ```

3. Configure your GitHub repository webhook to point to `https://ci.example.com/push`

## Layout

- [charts/](charts/) - Individual Helm charts (one chart per subfolder)
- [argo-ci.yaml](argo-ci.yaml) - Helm values file for deploying this repository's CI pipeline using the argo-ci-trigger chart

**Note:** The `argo-ci.yaml` file demonstrates how this repository uses its own argo-ci-trigger chart for building, packaging, and publishing charts (self-hosting). It serves as a real-world example of advanced configuration including custom workflows, ExternalSecrets, and multi-step DAG pipelines.

## Installing Charts

Install from OCI registry (Docker Hub):

```bash
# Install argo-ci (RBAC and EventBus)
helm install argo-ci oci://docker.io/anisimovdk/argo-ci --version 0.1.0

# Install argo-ci-trigger (GitHub webhooks)
helm install my-app-ci oci://docker.io/anisimovdk/argo-ci-trigger --version 0.1.1 \
  --set host=ci.example.com \
  --set eventSource.github.repository=myorg/myrepo
```

Install from local source:

```bash
# Install argo-ci
helm install argo-ci ./charts/argo-ci

# Install argo-ci-trigger
helm install my-app-ci ./charts/argo-ci-trigger \
  --set host=ci.example.com \
  --set eventSource.github.repository=myorg/myrepo
```

For detailed configuration options, see the individual chart READMEs:

- [argo-ci configuration](charts/argo-ci/README.md)
- [argo-ci-trigger configuration](charts/argo-ci-trigger/README.md)

## Development

### Building and Publishing

1. Lint all charts:

   ```bash
   make lint
   ```

2. Build (package) all charts:

   ```bash
   make build
   ```

3. Login to Docker Hub:

   ```bash
   export DOCKER_USERNAME=your-username
   export DOCKER_PASSWORD=your-password
   make login
   ```

4. Push all charts to Docker Hub:

   ```bash
   make push
   ```

## Conventions

- Chart folder name matches `Chart.yaml` name.
- Use semantic versioning for `version` and `appVersion`.
- Keep values defaults minimal and documented.

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.
