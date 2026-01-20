# argo-ci-trigger

A Helm chart for deploying Argo Events GitHub webhook triggers for CI/CD pipelines.

## Description

This chart creates:
- **EventSource**: Listens for GitHub webhook events
- **Sensor**: Triggers Argo Workflows on events
- **WorkflowTemplate**: Defines the CI/CD pipeline (build & release)
- **Ingress**: Exposes the webhook endpoint (recommended)
- **Secrets** (optional): GitHub webhook secret and API token
- **ExternalSecrets** (optional): Sync secrets from external secret stores (Doppler, AWS Secrets Manager, etc.)

All resource names are derived from the Helm release name for consistent naming.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- Argo Events installed and configured
- Argo Workflows installed and configured

## Installation

### Basic Installation

```bash
helm install my-app ./charts/argo-ci-trigger \
  --set host=ci.example.com \
  --set eventSource.github.repository=myorg/myrepo
```

**Note:** The `host` parameter is required when ingress is enabled. It's used for both the Ingress host and EventSource webhook URL.

## Configuration

### Required Configuration

| Parameter | Description | Default | Required |
| --------- | ----------- | ------- | -------- |
| `host` | Webhook URL hostname for GitHub webhooks and ingress host | `""` | Yes (when ingress is enabled) |
| `eventSource.github.repository` | GitHub repository (format: `owner/repo-name`) | `""` | Yes |

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
| `eventSource.github.events` | GitHub events to listen for | `["push", "pull_request"]` |
| `eventSource.github.webhookSecret.create` | Create webhook secret with the chart | `false` |
| `eventSource.github.webhookSecret.name` | Name of the webhook secret | `github-webhook-secret` |
| `eventSource.github.webhookSecret.key` | Key within the secret | `token` |
| `eventSource.github.webhookSecret.value` | Secret value (auto-generated if empty) | `""` |
| `eventSource.github.apiToken.create` | Create API token secret with the chart | `false` |
| `eventSource.github.apiToken.name` | Name of the API token secret | `github-api-token` |
| `eventSource.github.apiToken.key` | Key within the secret | `token` |
| `eventSource.github.apiToken.value` | API token value (required if create: true) | `""` |

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
| `workflowTemplate` | Full WorkflowTemplate spec | See values.yaml |
| `buildTemplates` | Build templates merged into workflowTemplate.templates | See values.yaml |

### Other Configuration

| Parameter | Description | Default |
| --------- | ----------- | ------- |
| `nameOverride` | Override chart name | `""` |
| `fullnameOverride` | Override full resource name | `""` |

## Templated Values

The following are automatically derived from the Helm release name:

- EventSource name: `<release-name>`
- Sensor name: `<release-name>`
- WorkflowTemplate name: `<release-name>`
- Workflow generateName: `<release-name>-build-` (e.g., `myapp-build-`)
- ExternalSecret names: `<release-name>-<secret-key>` (e.g., `myapp-github-webhook-secret`)
- Predefined Secret names: `<release-name>-webhook-secret`, `<release-name>-api-token`
- Webhook endpoint: `/<owner>/<repo-name>`

Hardcoded values:

- Webhook port: `12000`
- Webhook method: `POST`
- Sensor service account: `argo-events-sa`
- Workflow operation: `submit`

## Examples

### Quick Start

```bash
helm install my-app ./charts/argo-ci-trigger \
  --set host=ci.example.com \
  --set eventSource.github.repository=myorg/myrepo
```

### With Webhook Secret

```bash
helm install my-app ./charts/argo-ci-trigger \
  --set host=ci.example.com \
  --set eventSource.github.repository=myorg/myrepo \
  --set eventSource.github.webhookSecret.create=true \
  --set eventSource.github.webhookSecret.value=my-secret-value
```

### With ExternalSecrets

```bash
helm install my-app ./charts/argo-ci-trigger \
  --set host=ci.example.com \
  --set eventSource.github.repository=myorg/myrepo \
  --set externalSecrets.secretStore.name=doppler \
  --set externalSecrets.webhook-secret.create=true \
  --set externalSecrets.api-token.create=true
```

This creates:
- ExternalSecret: `my-app-webhook-secret` → Secret: `my-app-webhook-secret`
- ExternalSecret: `my-app-api-token` → Secret: `my-app-api-token`

### With Custom ExternalSecret

Create a custom values file (`my-values.yaml`):

```yaml
host: "ci.example.com"

eventSource:
  github:
    repository: "myorg/myrepo"

externalSecrets:
  secretStore:
    kind: ClusterSecretStore
    name: doppler
  
  webhook-secret:
    create: true
    data:
      token:
        key: GITHUB_WEBHOOK_SECRET
  
  # Custom secret for database credentials
  db-credentials:
    create: true
    secretStoreRef:
      kind: SecretStore
      name: vault
    refreshInterval: 30m
    data:
      DB_PASSWORD:
        key: DATABASE_PASSWORD
      DB_USERNAME:
        key: DATABASE_USERNAME
    target:
      creationPolicy: Owner
      deletionPolicy: Retain
      template:
        type: Opaque
```

Install the chart:

```bash
helm install my-app ./charts/argo-ci-trigger -f my-values.yaml
```

Verify the created secrets:

```bash
# Check ExternalSecrets
kubectl get externalsecret
# Output:
# NAME                      STORE    REFRESH INTERVAL   STATUS
# my-app-webhook-secret     doppler  60m                SecretSynced
# my-app-db-credentials     vault    30m                SecretSynced

# Check generated Secrets
kubectl get secret my-app-webhook-secret
kubectl get secret my-app-db-credentials
```

### With Ingress and TLS

```bash
helm install my-app ./charts/argo-ci-trigger \
  --set host=ci.example.com \
  --set eventSource.github.repository=myorg/myrepo \
  --set ingress.enabled=true \
  --set ingress.tls.enabled=true \
  --set ingress.tls.secretName=ci-tls-cert \
  --set ingress.className=nginx
```

### Multiple Events

```bash
helm install my-app ./charts/argo-ci-trigger \
  --set host=ci.example.com \
  --set eventSource.github.repository=myorg/myrepo \
  --set eventSource.github.events[0]=push \
  --set eventSource.github.events[1]=pull_request \
  --set eventSource.github.events[2]=release
```

### With Custom values.yaml

Create a custom `my-values.yaml`:

```yaml
host: "ci.example.com"

ingress:
  enabled: true
  className: "nginx"
  tls:
    enabled: true
    secretName: "ci-tls-cert"

eventSource:
  github:
    repository: "myorg/myrepo"
    events:
      - push
      - pull_request
    webhookSecret:
      create: true
      value: "my-webhook-secret"

externalSecrets:
  secretStore:
    kind: ClusterSecretStore
    name: doppler
  api-token:
    create: true
    data:
      token:
        key: GITHUB_API_TOKEN

workflowTemplate:
  entrypoint: main
  arguments:
    parameters:
      - name: repo_url
      - name: revision
  templates:
    - name: main
      dag:
        tasks:
          - name: build
            template: go-build
          - name: release
            depends: "build"
            template: github-release
            arguments:
              artifacts:
                - name: binary
                  from: "{{tasks.build.outputs.artifacts.binary}}"

buildTemplates:
  - name: go-build
    inputs:
      artifacts:
        - name: code
          path: /src
          git:
            repo: "{{workflow.parameters.repo_url}}"
            revision: "{{workflow.parameters.revision}}"
    container:
      image: golang:1.21-alpine
      workingDir: /src
      command: [sh, -c]
      args: ["go build -o my-app main.go"]
    outputs:
      artifacts:
        - name: binary
          path: /src/my-app

  - name: github-release
    inputs:
      artifacts:
        - name: binary
          path: /dist/my-app
    container:
      image: alpine:latest
      env:
        - name: GITHUB_TOKEN
          valueFrom:
            secretKeyRef:
              name: github-creds
              key: token
      command: [sh, -c]
      args:
        - |
          apk add --no-cache github-cli
          gh release create "v-{{workflow.parameters.revision}}" /dist/my-app \
             --repo myorg/myrepo \
             --title "Build {{workflow.parameters.revision}}" \
             --notes "Automated release from Argo Workflows"
```

Then install:

```bash
helm install my-app ./charts/argo-ci-trigger -f my-values.yaml
```

## GitHub Webhook Setup

After installing the chart, you need to configure GitHub to send webhooks to your EventSource.

### Using Ingress (Recommended)

If ingress is enabled (default), GitHub will send webhooks to:

```
https://<host>/<owner>/<repo-name>
```

For example, if `host=ci.example.com` and `repository=myorg/myrepo`:

```
https://ci.example.com/myorg/myrepo
```

Configure in GitHub:

1. Go to your repository **Settings → Webhooks → Add webhook**
2. **Payload URL**: `https://<host>/<owner>/<repo-name>`
3. **Content type**: `application/json`
4. **Secret**: Your webhook secret (if configured)
5. **Events**: Select the events you configured (e.g., push, pull_request)
6. **Active**: Check this box

### Without Ingress

If you're not using ingress, you'll need to expose the EventSource service:

**Option 1: Port forwarding (for testing)**

```bash
kubectl port-forward svc/<eventsource-service> 12000:12000
```

Then use `http://localhost:12000/<owner>/<repo-name>` in GitHub webhook configuration.

**Option 2: LoadBalancer service**

Modify the EventSource service type to LoadBalancer and use the external IP.

**Option 3: NodePort**

Use a NodePort service and access via `http://<node-ip>:<node-port>/<owner>/<repo-name>`.

## Available GitHub Webhook Data

The workflow receives these parameters from GitHub webhook payload:

| Parameter | Source | Description |
| --------- | ------ | ----------- |
| `repo_url` | `{{ .Input.body.repository.clone_url }}` | Repository clone URL |
| `revision` | `{{ .Input.body.after }}` | Commit SHA (for push events) |

Additional data available in webhook payload (accessible via dataTemplate):

| Path | Description |
| ---- | ----------- |
| `{{ .Input.body.ref }}` | Git reference (e.g., refs/heads/main) |
| `{{ .Input.body.repository.name }}` | Repository name |
| `{{ .Input.body.repository.owner.login }}` | Repository owner |
| `{{ .Input.body.pusher.name }}` | Name of the person who pushed |
| `{{ .Input.body.head_commit.message }}` | Commit message |

## Troubleshooting

### Check Resource Status

```bash
# Replace <release-name> with your Helm release name
kubectl get eventsource <release-name>
kubectl get sensor <release-name>
kubectl get workflowtemplate <release-name>
kubectl get ingress <release-name>
```

### View EventSource Logs

```bash
# EventSource controller logs
kubectl logs -n argo-events deploy/eventsource-controller
```

### View Sensor Logs

```bash
# Sensor logs
kubectl logs -l sensor-name=<release-name> -f
```

### Verify Ingress Configuration

```bash
# Check ingress details
kubectl describe ingress <release-name>

# Get ingress URL
kubectl get ingress <release-name> -o jsonpath='{.spec.rules[0].host}'
```

### Test Webhook Manually

#### Using Port Forward

```bash
kubectl port-forward svc/<eventsource-service> 12000:12000

curl -X POST http://localhost:12000/myorg/myrepo \
  -H "Content-Type: application/json" \
  -d '{
    "repository": {
      "clone_url": "https://github.com/myorg/myrepo.git",
      "name": "myrepo"
    },
    "after": "abc123"
  }'
```

#### Using Ingress

```bash
curl -X POST https://ci.example.com/myorg/myrepo \
  -H "Content-Type: application/json" \
  -d '{
    "repository": {
      "clone_url": "https://github.com/myorg/myrepo.git",
      "name": "myrepo"
    },
    "after": "abc123"
  }'
```

### Check Triggered Workflows

```bash
# List workflows triggered by the sensor
kubectl get workflows -l workflows.argoproj.io/workflow-template=<release-name>

# View workflow logs
kubectl logs -l workflows.argoproj.io/workflow-template=<release-name> -f
```

### Common Issues

**Webhook not triggering workflows:**

- Verify ingress is accessible from the internet
- Check EventSource and Sensor logs for errors
- Ensure GitHub webhook secret matches the configured secret
- Verify the webhook URL in GitHub matches the ingress host

**TLS certificate errors:**

- Ensure `ingress.tls.secretName` references a valid TLS secret
- Check that your certificate is not expired
- Verify the certificate matches the configured host

**ExternalSecrets not syncing:**

- Verify the SecretStore is configured correctly
- Check ExternalSecret controller logs
- Ensure the remote keys exist in your external secret store

## License

This chart is available under the same license as the repository.
