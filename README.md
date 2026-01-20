# argo-ci-charts

A collection of Helm charts for using Argo Workflows and Argo Events as a continuous integration (CI) engine. These charts enable you to run your build pipelines natively in Kubernetes, leveraging the power of the Argo ecosystem for event-driven workflow automation.

**Registry:** [Docker Hub - anisimovdk](https://hub.docker.com/repositories/anisimovdk)

## Table of Contents

- [argo-ci-charts](#argo-ci-charts)
  - [Table of Contents](#table-of-contents)
  - [Layout](#layout)
  - [Getting started](#getting-started)
    - [Building and Publishing](#building-and-publishing)
    - [Working with Individual Charts](#working-with-individual-charts)
    - [Manual Chart Creation](#manual-chart-creation)
  - [Installing Charts](#installing-charts)
  - [Conventions](#conventions)
  - [License](#license)

## Layout

- `charts/` - individual Helm charts (one chart per subfolder)
- `docs/` - documentation and release notes

## Getting started

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
   make push REPOSITORY=your-dockerhub-username
   ```

### Working with Individual Charts

Build and push a specific chart:

```bash
make push-argo-ci-rbac REPOSITORY=your-dockerhub-username
```

### Manual Chart Creation

1. Create a new chart:

   ```bash
   helm create charts/<chart-name>
   ```

2. Lint a chart:

   ```bash
   helm lint charts/<chart-name>
   ```

3. Package a chart:

   ```bash
   helm package charts/<chart-name> -d dist/
   ```

## Installing Charts

Install from OCI registry:

```bash
helm install my-release oci://docker.io/your-username/argo-ci-rbac --version 0.1.0
```

## Conventions

- Chart folder name matches `Chart.yaml` name.
- Use semantic versioning for `version` and `appVersion`.
- Keep values defaults minimal and documented.

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.
