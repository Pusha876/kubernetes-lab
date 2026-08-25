# Day 24 - ClusterRole & ClusterRoleBinding

This exercise walks through creating a real Kubernetes user (via client certificates), then granting that user permissions using both namespaced (`Role`/`RoleBinding`) and cluster-scoped (`ClusterRole`/`ClusterRoleBinding`) RBAC objects.

## 1. Create a user

Kubernetes has no built-in `User` object. Users are authenticated externally — the simplest approach for a kind/self-managed cluster is a client certificate signed by the cluster CA.

### Generate a private key and CSR

```bash
openssl genrsa -out jamie.key 2048

# On Git Bash / MINGW64, prefix with MSYS_NO_PATHCONV=1 to stop path-mangling of the -subj value
MSYS_NO_PATHCONV=1 openssl req -new -key jamie.key -out jamie.csr -subj "/CN=jamie/O=dev-team"
```

- `CN` (Common Name) becomes the Kubernetes username.
- `O` (Organization) becomes the group, useful for group-based RBAC bindings.

### Submit a CertificateSigningRequest to the cluster

The `request` field must contain the base64-encoded CSR content. This only works when run directly in a shell (so `$(...)` is expanded before hitting the API) — see [csr_cluster.yaml](csr_cluster.yaml) for reference, or inline it directly:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: jamie
spec:
  request: $(cat jamie.csr | base64 | tr -d '\n')
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 31536000
  usages:
  - client auth
EOF
```

### Approve the CSR and extract the signed certificate

```bash
kubectl certificate approve jamie
kubectl get csr jamie -o jsonpath='{.status.certificate}' | base64 -d > jamie.crt
```

### Add the user and a context to kubeconfig

```bash
kubectl config set-credentials jamie \
  --client-key=jamie.key \
  --client-certificate=jamie.crt \
  --embed-certs=true

kubectl config set-context jamie-context \
  --cluster=<cluster-name> \
  --user=jamie
```

At this point `jamie` can authenticate but has zero permissions (every request returns `Forbidden`) until RBAC objects are bound.

## 2. Role & RoleBinding (namespace-scoped)

A `Role` grants permissions within a single namespace. See [role.yaml](role.yaml):

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: default
  name: pod-reader
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "watch", "list"]
```

Bind it to `jamie` with a `RoleBinding` — see [binding.yaml](binding.yaml):

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-pods
  namespace: default
subjects:
- kind: User
  name: jamie
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

Apply as an admin context, then test as `jamie`:

```bash
kubectl config use-context <admin-context>
kubectl apply -f role.yaml
kubectl apply -f binding.yaml

kubectl config use-context jamie-context
kubectl get pods       # works, default namespace only
kubectl get pods -n kube-system   # forbidden - Role/RoleBinding are namespace-scoped
```

## 3. ClusterRole & ClusterRoleBinding (cluster-scoped)

Cluster-scoped resources (e.g. `nodes`, `namespaces`, `persistentvolumes`) or permissions spanning all namespaces require a `ClusterRole` bound with a `ClusterRoleBinding`.

[clusterrole.yaml](clusterrole.yaml):

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: node-reader
rules:
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["get", "watch", "list"]
```

[clusterrolebinding.yaml](clusterrolebinding.yaml):

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: read-nodes
subjects:
- kind: User
  name: jamie
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: node-reader
  apiGroup: rbac.authorization.k8s.io
```

Apply and test:

```bash
kubectl config use-context <admin-context>
kubectl apply -f clusterrole.yaml
kubectl apply -f clusterrolebinding.yaml

kubectl config use-context jamie-context
kubectl get nodes   # now works
```

## 4. Useful checks

```bash
# Which user/context am I using?
kubectl config current-context
kubectl auth whoami        # newer kubectl versions

# What can I do?
kubectl auth can-i --list
kubectl auth can-i get pods -n default
kubectl auth can-i get nodes
```

## Role vs ClusterRole quick reference

| | Scope | Binding object | Example resources |
|---|---|---|---|
| `Role` | Single namespace | `RoleBinding` | pods, configmaps, secrets (in-namespace) |
| `ClusterRole` | Whole cluster (or reusable across namespaces via `RoleBinding`) | `ClusterRoleBinding` (cluster-wide) or `RoleBinding` (namespace-scoped use of a ClusterRole) | nodes, namespaces, persistentvolumes, non-resource URLs |

## Common gotchas

- **Git Bash mangles `-subj` paths**: prefix commands with `MSYS_NO_PATHCONV=1` or use `//CN=...` (double leading slash).
- **`$(...)` in a YAML file is not expanded** — shell substitution only works when typed directly in a terminal command/heredoc, not when saved literally inside a `.yaml` file.
- **Stale kubeconfig server URLs**: if a kind cluster is deleted/recreated, its exposed port (and CA) changes — verify with `docker ps` and `kind get clusters` before debugging "connection refused" errors.
- **Forbidden on cluster-scoped resources** (e.g. `nodes`) despite having a working `Role`/`RoleBinding`: namespaced Roles never grant access to cluster-scoped resources — you need a `ClusterRole` + `ClusterRoleBinding`.
