# Kubernetes plugin for drone.io (for ARM/raspberry pi architecture)

A basic plugin that allows you to update the container for a Kubernetes deployment,
on an agent using an arm CPU.

## Usage

Each plugin usage requires the kubernetes_server, kubernetes_cert, and kubernetes_token to be provided. Details on how to get (and potentially set) those values can be found at the bottom of this guide.

### Examples

This pipeline will update the `my-deployment` deployment with the image tagged `DRONE_COMMIT_SHA:0:8`

```yaml
kind: pipeline
name: kubernetes-deploy

steps:
  - name: deploy
    image: matthewoden/drone-kubernetes-arm
    settings:
      - kubernetes_server: ${KUBERNETES_SERVER}
      - kubernetes_cert: ${KUBERNETES_CERT}
      - kubernetes_token: ${KUBERNETES_TOKEN}
      - deployment: my-deployment
      - repo: myorg/myrepo
      - container: my-container
      - tag: ${DRONE_COMMIT_SHA:0:8}
```

Deploying containers across several deployments, eg in a scheduler-worker setup.
Make sure your container `name` in your manifest is the same for each pod.

```yaml
kind: pipeline
name: kubernetes-deploy

steps:
  - name: deploy
    image: matthewoden/drone-kubernetes-arm
    settings:
      - kubernetes_server: ${KUBERNETES_SERVER}
      - kubernetes_cert: ${KUBERNETES_CERT}
      - kubernetes_token: ${KUBERNETES_TOKEN}
      - deployment: [server-deploy, worker-deploy]
      - repo: myorg/myrepo
      - container: my-container
      - tag: mytag
```

Deploying multiple containers within the same deployment.

```yaml
kind: pipeline
name: kubernetes-deploy

steps:
  - name: deploy
    image: matthewoden/drone-kubernetes-arm
    settings:
      - kubernetes_server: ${KUBERNETES_SERVER}
      - kubernetes_cert: ${KUBERNETES_CERT}
      - kubernetes_token: ${KUBERNETES_TOKEN}
      - deployment: my-deployment
      - repo: myorg/myrepo
      - container: [container1, container2]
      - tag: mytag
```

**NOTE**: Combining multi container deployments across multiple deployments is not recommended

This more complex example demonstrates how to deploy to several environments based on the branch, in a `app` namespace

```yaml
kind: pipeline
name: kubernetes-deploy

steps:
  - name: deploy-staging
    image: matthewoden/drone-kubernetes-arm
    settings:
      - kubernetes_server: ${KUBERNETES_SERVER_STAGING}
      - kubernetes_cert: ${KUBERNETES_CERT_STAGING}
      - kubernetes_token: ${KUBERNETES_TOKEN_STAGING}
      - deployment: my-deployment
      - repo: myorg/myrepo
      - container: my-container
      - namespace: app
      - tag: mytag
    when:
      branch: [staging]

  - name: deploy-prod
    image: matthewoden/drone-kubernetes-arm
    settings:
      - kubernetes_server: ${KUBERNETES_SERVER_PROD}
      - kubernetes_token: ${KUBERNETES_TOKEN_PROD}
      - deployment: my-deployment
      - repo: myorg/myrepo
      - container: my-container
      - namespace: app
      - tag: mytag
    when:
      - branch: [master]
```

## Required fields

Each use of the plugin should provide a kubernetes server, cert, token and secret.

You can add these as env variables to your `drone.yaml`, or as secrets via the CLI:

```bash
    drone secret add
      --respository your-user/your-repo
      --name KUBERNETES_SERVER
      --data https://mykubernetesapiserver

    drone secret add
      --repository your-user/your-repo \
      --name KUBERNETES_CERT \
      --data <base64 encoded CA.crt>

    drone secret add
      --repository your-user/your-repo \
      --name KUBERNETES_TOKEN
      --data eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJrdWJ...
```

When using TLS Verification, ensure Server Certificate used by kubernetes API server
is signed for your SERVER url (this could be a reason for failures if you
use aliases for your kubernetes cluster)

## How to get a token

## Default Service Account

I recommend creating a deployment service account with RBAC (further below)

1. After deployment, inspect your pod for the name of your (k8s) secret with **token** and **ca.crt**

```bash
kubectl describe [ your pod name ] | grep SecretName | grep token
```

2. Get data from your (k8s) secret

```bash
kubectl get secret [ your default secret name ] -o yaml | egrep 'ca.crt:|token:'
```

3. Copy-paste contents of ca.crt into your drone's **KUBERNETES_CERT** secret
4. Decode base64 encoded token

```bash
echo [ your k8s base64 encoded token ] | base64 -d && echo''
```

5. Copy-paste decoded token into your drone's **KUBERNETES_TOKEN** secret

### RBAC

When using a version of kubernetes with RBAC (role-based access control)
enabled, you will not be able to use the default service account, since it does
not have access to update deployments. Instead, you will need to create a
custom service account with the appropriate permissions (`Role` and
`RoleBinding`, or `ClusterRole` and `ClusterRoleBinding` if you need access
across namespaces using the same service account).

As an example (for the `web` namespace):

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: drone-deploy
  namespace: web

---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: Role
metadata:
  name: drone-deploy
  namespace: web
rules:
  - apiGroups: ["extensions"]
    resources: ["deployments"]
    verbs: ["get", "list", "patch", "update"]

---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: RoleBinding
metadata:
  name: drone-deploy
  namespace: web
subjects:
  - kind: ServiceAccount
    name: drone-deploy
    namespace: web
roleRef:
  kind: Role
  name: drone-deploy
  apiGroup: rbac.authorization.k8s.io
```

Once the service account is created, you can extract the `ca.cert` and `token`
parameters as mentioned for the default service account above:

```
kubectl -n web get secrets
# Substitute XXXXX below with the correct one from the above command
kubectl -n web get secret/drone-deploy-token-XXXXX -o yaml | egrep 'ca.crt:|token:'
```

### Special thanks

Inspired by [drone-helm](https://github.com/ipedrazas/drone-helm).
