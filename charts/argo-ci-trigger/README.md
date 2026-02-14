# argo-ci-trigger

A Helm chart for deploying Argo Events GitHub webhook triggers for CI pipelines.

## Table of Contents

- [Description](#description)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Configuration](#configuration)
  - [Required Parameters](#required-parameters)
  - [Global Configuration](#global-configuration)
  - [Ingress Configuration](#ingress-configuration)
  - [EventSource Configuration](#eventsource-configuration)
    - [API Token Configuration (Required)](#api-token-configuration-required)
  - [Sensor Configuration](#sensor-configuration)
  - [ExternalSecrets Configuration](#externalsecrets-configuration)
  - [WorkflowTemplate Configuration](#workflowtemplate-configuration)
- [Resource Naming](#resource-naming)
- [Usage Examples](#usage-examples)
- [GitHub Webhook Configuration](#github-webhook-configuration)
- [GitHub Webhook Payload Reference](#github-webhook-payload-reference)
- [Troubleshooting](#troubleshooting)
- [Advanced Configuration](#advanced-configuration)
- [Additional Resources](#additional-resources)
- [Contributing](#contributing)
- [License](#license)

## Description

This chart creates a complete GitHub webhook-based CI pipeline using Argo Events and Argo Workflows:

- **EventSource**: Listens for GitHub webhook events (push, pull_request, etc.)
- **Sensor**: Triggers Argo Workflows based on GitHub events
- **WorkflowTemplate**: Defines your CI pipeline steps (build, test, release, etc.)
- **Service**: ClusterIP service for the EventSource (automatically created)
- **Ingress**: Exposes the webhook endpoint to receive GitHub webhooks (recommended)
- **Secrets** (optional): GitHub webhook secret and API token for authentication
- **ExternalSecrets** (optional): Sync secrets from external stores (Doppler, AWS Secrets Manager, Vault, etc.)

All resource names are automatically derived from the Helm release name ensuring consistent naming and avoiding conflicts.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- [Argo Events](https://argoproj.github.io/argo-events/) installed and configured
- [Argo Workflows](https://argoproj.github.io/argo-workflows/) installed and configured
- The [argo-ci](../argo-ci/) chart must be installed first (provides ServiceAccount, RBAC, and EventBus)

## Installation

### From OCI Registry (Recommended)

Install the latest version from Docker Hub:

```bash
helm install my-app oci://docker.io/anisimovdk/argo-ci-trigger --version 0.1.0 \
  --set host=ci.example.com \
  --set eventSource.github.repository=myorg/myrepo
```

### From Local Source

```bash
helm install my-app ./charts/argo-ci-trigger \
  --set host=ci.example.com \
  --set eventSource.github.repository=myorg/myrepo
```

**Important Notes:**
- The `host` parameter is **required** when ingress is enabled (default). It's used for both the Ingress host and the EventSource webhook URL.
- The `eventSource.github.repository` parameter is **required** and must be in the format `owner/repo-name`.
- A GitHub API token with `admin:repo_hook` permissions is **required** for automatic webhook management. You must provide it via one of three methods: `eventSource.github.apiToken` (chart-managed secret), `externalSecrets.api-token` (external secret store), or by manually creating a secret and referencing it. See [API Token Configuration](#api-token-configuration-required) for details.
- Ensure the [argo-ci](../argo-ci/) chart is installed first to provide the necessary ServiceAccount and EventBus.

## Configuration

### Required Parameters

| Parameter | Description | Default | Required |
| --------- | ----------- | ------- | -------- |
| `host` | Webhook URL hostname for GitHub webhooks and Ingress host | `""` | Yes (when ingress is enabled) |
| `eventSource.github.repository` | GitHub repository in format `owner/repo-name` | `""` | Yes |
| GitHub API Token | GitHub API token with `admin:repo_hook` permissions for automatic webhook management (must be provided via one of three methods - see [API Token Configuration](#api-token-configuration-required)) | N/A | Yes |

### Global Configuration

| Parameter | Description | Default |
| --------- | ----------- | ------- |
| `nameOverride` | Override chart name | `""` |
| `fullnameOverride` | Override full resource name | `""` |
| `eventBusName` | EventBus name for EventSource and Sensor (must match the EventBus resource in your namespace) | `argo-ci-eventbus` |

### Ingress Configuration

| Parameter | Description | Default |
| --------- | ----------- | ------- |
| `ingress.enabled` | Enable Ingress for the EventSource webhook | `true` |
| `ingress.className` | Ingress class name | `""` |
| `ingress.annotations` | Ingress annotations | `{}` |
| `ingress.tls.enabled` | Enable TLS for Ingress | `true` |
| `ingress.tls.secretName` | Name of the TLS secret | `""` |

### EventSource Configuration

| Parameter | Description | Default |
| --------- | ----------- | ------- |
| `eventSource.github.events` | List of GitHub events to listen for (e.g., push, pull_request, release) | `["push"]` |
| `eventSource.github.contentType` | Content type for webhook payload | `json` |
| `eventSource.github.filter.expression` | Filter expression to restrict which events trigger workflows (uses expr language) | `body.ref == 'refs/heads/master'` |
| `eventSource.github.webhookSecret.create` | Create webhook secret with the chart | `false` |
| `eventSource.github.webhookSecret.name` | Name of the webhook secret | `github-webhook-secret` |
| `eventSource.github.webhookSecret.key` | Key within the secret | `token` |
| `eventSource.github.webhookSecret.value` | Secret value (auto-generated if empty when create: true) | `""` |
| `eventSource.github.apiToken.create` | Create API token secret with the chart | `false` |
| `eventSource.github.apiToken.name` | Name of the API token secret (required if not using create or externalSecrets) | `github-api-token` |
| `eventSource.github.apiToken.key` | Key within the secret | `token` |
| `eventSource.github.apiToken.value` | API token value (required if create: true; see [API Token Configuration](#api-token-configuration-required) for all options) | `""` |

**Filter Expression Examples:**

```yaml
# Only trigger on pushes to master branch
filter:
  expression: "body.ref == 'refs/heads/master'"

# Trigger on pushes to master or develop
filter:
  expression: "body.ref in ['refs/heads/master', 'refs/heads/develop']"

# Only trigger on pull requests to main branch
filter:
  expression: "body.pull_request.base.ref == 'main'"

# Trigger when commit message contains [deploy]
filter:
  expression: "body.head_commit.message contains '[deploy]'"
```

#### API Token Configuration (Required)

A GitHub API token with `admin:repo_hook` permissions is **required** for Argo Events to automatically manage webhooks in your repository. You must provide this token using one of three methods:

##### Option 1: Chart-Managed Secret

Let the chart create and manage the secret for you:

```yaml
eventSource:
  github:
    repository: myorg/myrepo
    apiToken:
      create: true
      value: "ghp_YourGitHubPersonalAccessToken"
```

The chart will create a Kubernetes Secret named `<release-name>-api-token` with your token.

##### Option 2: External Secret (Recommended for Production)

Use External Secrets Operator to sync the token from an external secret store (Doppler, AWS Secrets Manager, Vault, etc.):

```yaml
externalSecrets:
  secretStore:
    kind: ClusterSecretStore
    name: doppler
  api-token:
    create: true
    data:
      token:
        key: GITHUB_API_TOKEN  # Key in your external secret store
```

The ExternalSecret will sync the token and create a Kubernetes Secret named `<release-name>-api-token`.

##### Option 3: Manual Secret Creation

Create the secret manually and reference it in your values:

```bash
# Create the secret manually
kubectl create secret generic my-github-token \
  --from-literal=token="ghp_YourGitHubPersonalAccessToken"
```

Then reference it in your values:

```yaml
eventSource:
  github:
    repository: myorg/myrepo
    apiToken:
      create: false
      name: my-github-token  # Name of your manually created secret
      key: token             # Key within the secret
```

**Creating a GitHub Personal Access Token:**

1. Go to GitHub **Settings → Developer settings → Personal access tokens → Tokens (classic)**
2. Click **Generate new token (classic)**
3. Give it a descriptive name (e.g., "Argo CI Webhook")
4. Select the `admin:repo_hook` permission (required for webhook management)
5. Optionally add `repo` scope if you need access to private repositories
6. Click **Generate token** and copy the token immediately (you won't see it again)
7. Use this token in one of the three methods above

### Sensor Configuration

The Sensor defines how GitHub webhook events are mapped to Workflow parameters.

| Parameter | Description | Default |
| --------- | ----------- | ------- |
| `sensor.workflowArguments` | List of workflow parameter names | `[{name: repo_url}, {name: revision}]` |
| `sensor.parameterMapping` | Maps webhook payload fields to workflow parameters | See values.yaml |

**Default Parameter Mapping:**

The default configuration maps GitHub webhook data to workflow parameters:

- `repo_url` ← `body.repository.clone_url` (Repository clone URL)
- `revision` ← `body.after` (Commit SHA for push events)

**Custom Parameter Mapping Example:**

```yaml
sensor:
  workflowArguments:
    - name: repo_url
    - name: revision
    - name: branch
    - name: author
  
  parameterMapping:
    - src:
        dependencyName: dep
        dataKey: body.repository.clone_url
      dest: spec.arguments.parameters.0.value
    - src:
        dependencyName: dep
        dataKey: body.after
      dest: spec.arguments.parameters.1.value
    - src:
        dependencyName: dep
        dataKey: body.ref
      dest: spec.arguments.parameters.2.value
    - src:
        dependencyName: dep
        dataKey: body.pusher.name
      dest: spec.arguments.parameters.3.value
```

### ExternalSecrets Configuration

This chart supports External Secrets Operator to sync secrets from external stores like Doppler, AWS Secrets Manager, etc.

#### ExternalSecret Naming

All ExternalSecret names are automatically prefixed with the release name for consistent resource naming. The pattern is: `<release-name>-<secret-key>`

**Examples:**

| Release Name | Secret Key | Actual Secret Name |
|--------------|------------|--------------------|
| `myapp` | `webhook-secret` | `myapp-webhook-secret` |
| `myapp` | `api-token` | `myapp-api-token` |
| `myapp` | `db-credentials` | `myapp-db-credentials` |
| `production-api` | `oauth-tokens` | `production-api-oauth-tokens` |

This ensures that multiple releases can coexist in the same namespace without secret name conflicts. The generated Kubernetes Secret uses the same name as the ExternalSecret.

#### Configuration Parameters

| Parameter | Description | Default |
| --------- | ----------- | ------- |
| `externalSecrets.secretStore.kind` | Default SecretStore kind | `ClusterSecretStore` |
| `externalSecrets.secretStore.name` | Default SecretStore name | `doppler` |
| `externalSecrets.webhook-secret.create` | Create ExternalSecret for GitHub webhook | `false` |
| `externalSecrets.webhook-secret.secretStoreRef.kind` | Override default store kind | `""` |
| `externalSecrets.webhook-secret.secretStoreRef.name` | Override default store name | `""` |
| `externalSecrets.webhook-secret.refreshInterval` | How often to refresh the secret | `60m` |
| `externalSecrets.webhook-secret.data` | Data mapping from external store | See values.yaml |
| `externalSecrets.api-token.create` | Create ExternalSecret for GitHub API token | `false` |
| `externalSecrets.api-token.secretStoreRef.kind` | Override default store kind | `""` |
| `externalSecrets.api-token.secretStoreRef.name` | Override default store name | `""` |
| `externalSecrets.api-token.refreshInterval` | How often to refresh the secret | `60m` |
| `externalSecrets.api-token.data` | Data mapping from external store | See values.yaml |

### WorkflowTemplate Configuration

| Parameter | Description | Default |
| --------- | ----------- | ------- |
| `workflowTemplate` | Full WorkflowTemplate spec (entrypoint, arguments, templates) | See values.yaml |
| `workflowTemplate.serviceAccountName` | Service account for workflow execution | `argo-events-sa` |
| `buildTemplates` | Additional build/release templates merged into workflowTemplate.templates | See values.yaml |

**Secret Name Templating:**

When referencing secrets in your WorkflowTemplate (e.g., in `secretKeyRef.name`), use the ExternalSecret key name directly. The chart automatically replaces it with the templated name `<release-name>-<key>`.

**Example:**

```yaml
workflowTemplate:
  templates:
    - name: release
      container:
        env:
          - name: GITHUB_TOKEN
            valueFrom:
              secretKeyRef:
                name: api-token  # Automatically becomes: myapp-api-token
                key: token
```

### Other Configuration

## Resource Naming

The chart automatically generates resource names based on your Helm release name to ensure consistency and avoid conflicts.

### Auto-Generated Names

| Resource | Name Pattern | Example (release: `myapp`) |
| -------- | ------------ | -------------------------- |
| EventSource | `<release-name>` | `myapp` |
| Sensor | `<release-name>` | `myapp` |
| Service | `<release-name>-eventsource-svc` | `myapp-eventsource-svc` |
| Ingress | `<release-name>` | `myapp` |
| WorkflowTemplate | `<release-name>` | `myapp` |
| Workflow generateName | `<release-name>-build-` | `myapp-build-abc123` |
| ExternalSecret | `<release-name>-<secret-key>` | `myapp-webhook-secret` |
| Predefined Secret | `<release-name>-<secret-type>` | `myapp-webhook-secret` |

### Fixed/Hardcoded Values

These values are hardcoded in the chart templates:

| Setting | Value | Description |
| ------- | ----- | ----------- |
| Webhook endpoint | `/<owner>/<repo-name>` | Derived from `eventSource.github.repository` |
| Webhook port | `12000` | Service and EventSource port |
| Webhook method | `POST` | HTTP method for webhook |
| Sensor service account | `argo-events-sa` | From argo-ci chart |
| Workflow operation | `submit` | Sensor workflow operation |

## Usage Examples

### Basic Setup

Minimal configuration for a simple CI pipeline:

```bash
helm install my-app oci://docker.io/anisimovdk/argo-ci-trigger --version 0.1.0 \
  --set host=ci.example.com \
  --set eventSource.github.repository=myorg/myrepo
```

### With Event Filter

Only trigger on pushes to specific branches:

```bash
helm install my-app oci://docker.io/anisimovdk/argo-ci-trigger --version 0.1.0 \
  --set host=ci.example.com \
  --set eventSource.github.repository=myorg/myrepo \
  --set eventSource.github.filter.expression="body.ref in ['refs/heads/main', 'refs/heads/develop']"
```

### With Multiple Events

Listen for push, pull_request, and release events:

```bash
helm install my-app oci://docker.io/anisimovdk/argo-ci-trigger --version 0.1.0 \
  --set host=ci.example.com \
  --set eventSource.github.repository=myorg/myrepo \
  --set eventSource.github.events[0]=push \
  --set eventSource.github.events[1]=pull_request \
  --set eventSource.github.events[2]=release
```

### With Webhook Secret

Create a webhook secret for GitHub authentication:

```bash
helm install my-app oci://docker.io/anisimovdk/argo-ci-trigger --version 0.1.0 \
  --set host=ci.example.com \
  --set eventSource.github.repository=myorg/myrepo \
  --set eventSource.github.webhookSecret.create=true \
  --set eventSource.github.webhookSecret.value=my-secret-value
```

### With ExternalSecrets (Doppler)

Use External Secrets Operator to sync secrets from Doppler:

```bash
helm install my-app oci://docker.io/anisimovdk/argo-ci-trigger --version 0.1.0 \
  --set host=ci.example.com \
  --set eventSource.github.repository=myorg/myrepo \
  --set externalSecrets.secretStore.name=doppler \
  --set externalSecrets.webhook-secret.create=true \
  --set externalSecrets.api-token.create=true
```

This creates:
- ExternalSecret: `my-app-webhook-secret` → Kubernetes Secret: `my-app-webhook-secret`
- ExternalSecret: `my-app-api-token` → Kubernetes Secret: `my-app-api-token`

### Advanced: Custom Values File

Create a comprehensive configuration file (`my-values.yaml`):

```yaml
# Required configuration
host: "ci.example.com"

# EventSource configuration
eventSource:
  github:
    repository: "myorg/myrepo"
    events:
      - push
      - pull_request
    filter:
      expression: "body.ref in ['refs/heads/main', 'refs/heads/develop']"
    webhookSecret:
      create: true
      value: "my-webhook-secret"

# Ingress configuration
ingress:
  enabled: true
  className: "nginx"
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
  tls:
    enabled: true
    secretName: "ci-tls-cert"

# ExternalSecrets configuration
externalSecrets:
  secretStore:
    kind: ClusterSecretStore
    name: doppler

  api-token:
    create: true
    data:
      token:
        key: GITHUB_API_TOKEN

# WorkflowTemplate configuration
workflowTemplate:
  serviceAccountName: argo-events-sa
  entrypoint: main
  arguments:
    parameters:
      - name: repo_url
      - name: revision

  templates:
    - name: main
      dag:
        tasks:
          - name: clone
            template: git-clone
          - name: build
            depends: "clone"
            template: go-build
            arguments:
              artifacts:
                - name: source
                  from: "{{tasks.clone.outputs.artifacts.source}}"

buildTemplates:
  - name: git-clone
    container:
      image: alpine/git:latest
      command: [sh, -c]
      args:
        - |
          mkdir -p /src
          cd /src
          git clone {{workflow.parameters.repo_url}} .
          git checkout {{workflow.parameters.revision}}
    outputs:
      artifacts:
        - name: source
          path: /src

  - name: go-build
    inputs:
      artifacts:
        - name: source
          path: /src
    container:
      image: golang:1.21-alpine
      workingDir: /src
      command: [sh, -c]
      args: ["go build -o my-app main.go"]
```

Install with the custom values:

```bash
helm install my-app oci://docker.io/anisimovdk/argo-ci-trigger --version 0.1.0 \
  -f my-values.yaml
```

## GitHub Webhook Configuration

After deploying the chart, GitHub webhooks are automatically created and managed by Argo Events using your configured API token.

### Webhook URL Format

The webhook endpoint is automatically constructed as:

```
https://<host>/<owner>/<repo-name>
```

**Example:** If `host=ci.example.com` and `repository=myorg/myrepo`:
```
https://ci.example.com/myorg/myrepo
```

### Setup Steps

#### Automatic Webhook Creation

**Important:** A GitHub API token with `admin:repo_hook` permissions is **required** for automatic webhook management. See [API Token Configuration](#api-token-configuration-required) for setup instructions.

After installation with a properly configured API token:

1. Navigate to your GitHub repository
2. Go to **Settings → Webhooks**
3. You should see the webhook automatically created by Argo Events with the correct URL and configured events
4. If you don't see the webhook, check the EventSource logs for errors:

   ```bash
   kubectl logs -l eventsource-name=<release-name> -f
   ```

### Verify Webhook

After creating the webhook, GitHub will send a ping event:

1. Check the **Recent Deliveries** tab in GitHub webhook settings
2. You should see a successful ping delivery (green checkmark)
3. Check your EventSource logs:

   ```bash
   kubectl logs -l eventsource-name=<release-name> -f
   ```

### Testing

Trigger a test event (e.g., push a commit) and verify:

```bash
# Check if workflow was triggered
kubectl get workflows -l workflows.argoproj.io/workflow-template=<release-name>

# Watch workflow execution
kubectl logs -l workflows.argoproj.io/workflow-template=<release-name> -f
```

## GitHub Webhook Payload Reference

### Default Workflow Parameters

The chart's default configuration passes these parameters to workflows:

| Parameter | Webhook Path | Description | Example |
| --------- | ------------ | ----------- | ------- |
| `repo_url` | `body.repository.clone_url` | Repository clone URL | `https://github.com/myorg/myrepo.git` |
| `revision` | `body.after` | Commit SHA (for push events) | `abc123def456...` |

### Additional Available Data

You can access these fields from the GitHub webhook payload for custom parameter mappings:

#### Repository Information
| Webhook Path | Description | Example |
| ------------ | ----------- | ------- |
| `body.repository.name` | Repository name | `myrepo` |
| `body.repository.full_name` | Full repository name | `myorg/myrepo` |
| `body.repository.owner.login` | Repository owner | `myorg` |
| `body.repository.html_url` | Repository web URL | `https://github.com/myorg/myrepo` |

#### Commit Information (Push Events)
| Webhook Path | Description | Example |
| ------------ | ----------- | ------- |
| `body.ref` | Git reference | `refs/heads/main` |
| `body.before` | Previous commit SHA | `xyz789...` |
| `body.after` | New commit SHA | `abc123...` |
| `body.head_commit.message` | Commit message | `Fix bug in build script` |
| `body.head_commit.author.name` | Commit author name | `John Doe` |
| `body.head_commit.author.email` | Commit author email | `john@example.com` |
| `body.pusher.name` | Pusher name | `johndoe` |

#### Pull Request Information
| Webhook Path | Description | Example |
| ------------ | ----------- | ------- |
| `body.pull_request.number` | PR number | `42` |
| `body.pull_request.title` | PR title | `Add new feature` |
| `body.pull_request.head.ref` | Source branch | `feature-branch` |
| `body.pull_request.base.ref` | Target branch | `main` |
| `body.pull_request.head.sha` | Source commit SHA | `abc123...` |

### Usage in Parameter Mapping

Example of using custom webhook data:

```yaml
sensor:
  workflowArguments:
    - name: repo_url
    - name: revision
    - name: branch_name
    - name: commit_message

  parameterMapping:
    - src:
        dependencyName: dep
        dataKey: body.repository.clone_url
      dest: spec.arguments.parameters.0.value
    - src:
        dependencyName: dep
        dataKey: body.after
      dest: spec.arguments.parameters.1.value
    - src:
        dependencyName: dep
        dataKey: body.ref
      dest: spec.arguments.parameters.2.value
    - src:
        dependencyName: dep
        dataKey: body.head_commit.message
      dest: spec.arguments.parameters.3.value
```

## Troubleshooting

### Quick Diagnostics

Check the status of all resources created by the chart:

```bash
# Replace <release-name> with your Helm release name
export RELEASE=my-app

# Check all resources
kubectl get eventsource $RELEASE
kubectl get sensor $RELEASE
kubectl get workflowtemplate $RELEASE
kubectl get ingress $RELEASE
kubectl get service ${RELEASE}-eventsource-svc
kubectl get externalsecret  # Lists all ExternalSecrets
```

### Common Issues and Solutions

#### Webhook Not Triggering Workflows

**Symptoms:** GitHub webhook shows successful delivery, but no workflow is created.

**Diagnosis:**

```bash
# Check EventSource status and logs
kubectl describe eventsource <release-name>
kubectl logs -l eventsource-name=<release-name> -f

# Check Sensor status and logs
kubectl describe sensor <release-name>
kubectl logs -l sensor-name=<release-name> -f
```

**Common Causes:**

- **Filter expression mismatch**: The event doesn't match your filter

  ```bash
  # Check your filter in values
  helm get values <release-name> | grep -A2 filter
  ```

- **EventBus not running**: Ensure the EventBus is healthy

  ```bash
  kubectl get eventbus
  kubectl describe eventbus argo-ci-eventbus
  ```

- **Sensor permissions**: Verify ServiceAccount has proper RBAC

  ```bash
  kubectl get rolebinding | grep argo-events
  ```

#### Ingress Not Accessible

**Symptoms:** GitHub webhook fails with connection timeout or SSL errors.

**Diagnosis:**

```bash
# Check Ingress configuration
kubectl describe ingress <release-name>
kubectl get ingress <release-name> -o yaml

# Test internally
kubectl port-forward svc/<release-name>-eventsource-svc 12000:12000
curl -X POST http://localhost:12000/<owner>/<repo> -d '{}'
```

**Common Causes:**

- **DNS not configured**: Ensure your `host` resolves to the Ingress controller

  ```bash
  nslookup ci.example.com
  ```

- **TLS certificate issues**: Check certificate validity

  ```bash
  kubectl get secret <tls-secret-name> -o yaml
  openssl x509 -in <(kubectl get secret <tls-secret-name> -o jsonpath='{.data.tls\.crt}' | base64 -d) -text -noout
  ```

- **Ingress controller not running**:

  ```bash
  kubectl get pods -n ingress-nginx  # Or your ingress namespace
  ```

#### Webhook Secret Mismatch

**Symptoms:** GitHub webhook shows "X-Hub-Signature validation failed".

**Diagnosis:**

```bash
# Check the secret value
kubectl get secret <release-name>-webhook-secret -o jsonpath='{.data.token}' | base64 -d

# Verify it matches GitHub webhook secret
```

**Solution:**

- Ensure the secret in GitHub webhook settings matches the Kubernetes secret
- If using ExternalSecrets, verify the remote key value

#### Reconcile Github Webhook

```bash
kubectl annotate eventsource <release-name> reconcile-at=$(date +%s) --overwrite -n <namespace>
```

#### Workflow Fails to Start

**Symptoms:** Sensor triggers but workflow fails immediately or doesn't start.

**Diagnosis:**

```bash
# Check workflow events
kubectl get events --sort-by='.lastTimestamp' | grep workflow

# Check workflow status
kubectl get workflows -l workflows.argoproj.io/workflow-template=<release-name>
kubectl describe workflow <workflow-name>
```

**Common Causes:**

- **ServiceAccount lacks permissions**: Missing workflow RBAC

  ```bash
  kubectl get role | grep argo-events
  kubectl describe role argo-events-role
  ```

- **Invalid WorkflowTemplate**: Syntax errors in template

  ```bash
  kubectl get workflowtemplate <release-name> -o yaml
  ```

- **Missing container images**: Images not available

  ```bash
  kubectl describe pod <workflow-pod-name>
  ```

### View Logs

```bash
# EventSource controller logs (if issues creating EventSource)
kubectl logs deploy/eventsource-controller -f

# Sensor controller logs (if issues creating Sensor)
kubectl logs deploy/sensor-controller -f

# EventSource application logs (webhook reception)
kubectl logs -l eventsource-name=<release-name> -f

# Sensor application logs (workflow triggering)
kubectl logs -l sensor-name=<release-name> -f

# Workflow logs
kubectl logs -l workflows.argoproj.io/workflow-template=<release-name> -f
```

### Manual Webhook Testing

Test the webhook endpoint without GitHub:

#### Using Port Forward

```bash
# Forward the EventSource service
kubectl port-forward svc/<release-name>-eventsource-svc 12000:12000

# Send a test payload
curl -X POST http://localhost:12000/myorg/myrepo \
  -H "Content-Type: application/json" \
  -d '{
    "ref": "refs/heads/master",
    "repository": {
      "clone_url": "https://github.com/myorg/myrepo.git",
      "name": "myrepo"
    },
    "after": "abc123def456",
    "head_commit": {
      "message": "Test commit"
    }
  }'
```

#### Using Ingress

```bash
curl -X POST https://ci.example.com/myorg/myrepo \
  -H "Content-Type: application/json" \
  -d '{
    "ref": "refs/heads/master",
    "repository": {
      "clone_url": "https://github.com/myorg/myrepo.git",
      "name": "myrepo"
    },
    "after": "abc123def456"
  }'
```

### Verify Resource Creation

Check that all expected resources were created:

```bash
# List all resources with release label
kubectl get all -l app.kubernetes.io/instance=<release-name>

# Check Helm release status
helm status <release-name>
helm get values <release-name>
```

## Advanced Configuration

### Using Multiple ExternalSecrets

You can define additional ExternalSecrets for custom use cases:

```yaml
externalSecrets:
  secretStore:
    kind: ClusterSecretStore
    name: doppler

  # Standard webhook secret
  webhook-secret:
    create: true
    data:
      token:
        key: GITHUB_WEBHOOK_SECRET

  # Standard API token
  api-token:
    create: true
    data:
      token:
        key: GITHUB_API_TOKEN

  # Custom: Database credentials
  db-credentials:
    create: true
    secretStoreRef:
      kind: SecretStore
      name: vault
    refreshInterval: 30m
    data:
      username:
        key: DATABASE_USERNAME
      password:
        key: DATABASE_PASSWORD

  # Custom: Docker registry credentials
  docker-registry:
    create: true
    data:
      .dockerconfigjson:
        key: DOCKER_CONFIG_JSON
    target:
      template:
        type: kubernetes.io/dockerconfigjson
```

Each ExternalSecret will create a Kubernetes Secret with the name pattern: `<release-name>-<secret-key>`.

## Additional Resources

- [Argo Events Documentation](https://argoproj.github.io/argo-events/)
- [Argo Workflows Documentation](https://argoproj.github.io/argo-workflows/)
- [External Secrets Operator Documentation](https://external-secrets.io/)
- [GitHub Webhooks Documentation](https://docs.github.com/en/developers/webhooks-and-events/webhooks)
- [Chart Repository](https://github.com/anisimovdk/argo-ci-charts)

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests to the [GitHub repository](https://github.com/anisimovdk/argo-ci-charts).

## License

This chart is available under the same license as the [argo-ci-charts repository](https://github.com/anisimovdk/argo-ci-charts).
