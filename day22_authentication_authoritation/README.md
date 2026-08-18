# Authentication and Authorization

Authentication and authorization are separate steps in every request to the Kubernetes API server:

- **Authentication** verifies who is making the request. Kubernetes can use client certificates, bearer tokens, service-account tokens, OIDC, and other mechanisms.
- **Authorization** decides whether the authenticated identity may perform the requested action on a resource.

This lesson uses a kubeconfig file to show how `kubectl` selects a cluster, user, namespace, and credentials. The file is an example only; its server addresses and credential paths are placeholders.

## Files In This Folder

- [kubeconfig.yml](kubeconfig.yml): example kubeconfig containing clusters, users, contexts, and a current-context setting.

The certificate signing request workflow used to create a client certificate is in [day21_manage_tls_certificates](../day21_manage_tls_certificates/). A client certificate proves the user's identity, but it does not by itself grant access to Kubernetes resources. The certificate identity must also be allowed by the cluster's authorization configuration, commonly through RBAC.

## Prerequisites

- `kubectl` is installed.
- You have access to a Kubernetes cluster and a kubeconfig for that cluster.
- You understand that private keys, tokens, passwords, and real kubeconfig files must not be committed to Git.

Check the client and cluster connection:

```bash
kubectl version --client
kubectl cluster-info
```

## Authentication With Kubeconfig

By default, `kubectl` reads the current user's kubeconfig from `$HOME/.kube/config`. Select another file explicitly with `--kubeconfig`:

```bash
kubectl get pods --kubeconfig ./kubeconfig.yml
```

The example file contains fake server addresses and credential file names, so it will not connect until you replace those values with credentials for a real cluster. Do not use `insecure-skip-tls-verify: true` for a real cluster; configure the cluster's CA certificate instead.

### Kubeconfig Structure

A kubeconfig is organized into three reusable sections:

- `clusters`: API server addresses and TLS settings.
- `users`: authentication credentials, such as a client certificate and key or a credential plugin.
- `contexts`: a convenient combination of a cluster, user, and optional namespace.

Inspect the contexts in the active configuration:

```bash
kubectl config get-contexts
kubectl config current-context
```

Switch context and verify the selected namespace:

```bash
kubectl config use-context dev-frontend
kubectl config view --minify
kubectl get pods
```

Use a namespace-specific context without adding `-n` to every command:

```bash
kubectl config set-context dev-frontend --namespace=frontend
```

When working with multiple files, set `KUBECONFIG` temporarily. On Git Bash:

```bash
export KUBECONFIG="$PWD/kubeconfig.yml"
kubectl config get-contexts
```

On PowerShell:

```powershell
$env:KUBECONFIG = "$PWD\kubeconfig.yml"
kubectl config get-contexts
```

## Authorization With RBAC

Kubernetes authorization evaluates the authenticated user or group against the requested verb, resource, namespace, and API group. RBAC is the standard authorization mechanism.

The main RBAC objects are:

- `Role`: permissions within one namespace.
- `ClusterRole`: permissions that can apply across the cluster or be bound to a namespace.
- `RoleBinding`: grants a `Role` or `ClusterRole` to users, groups, or service accounts in one namespace.
- `ClusterRoleBinding`: grants a `ClusterRole` across the cluster.

RBAC permissions are additive. A role grants specific verbs such as `get`, `list`, `create`, or `delete`; there is no default deny rule inside a Role. Grant the smallest set of permissions needed for the task.

Check what the current identity can do:

```bash
kubectl auth can-i get pods
kubectl auth can-i create deployments -n frontend
kubectl auth can-i --list
```

An administrator can test a particular user or service account:

```bash
kubectl auth can-i get pods --as=adam -n frontend
kubectl auth can-i list secrets --as=system:serviceaccount:frontend:app -n frontend
```

The `--as` option requires impersonation permission. It does not change the identity of the current kubeconfig user.

## Authorization Modes

The API server can be configured with one or more authorization modes. Common modes include:

- **Node**: authorizes kubelet requests from nodes.
- **RBAC**: evaluates Role and ClusterRole bindings.
- **Webhook**: delegates authorization decisions to an external service.
- **ABAC**: uses attribute-based policy files and is generally avoided for new clusters.

The exact mode and order are cluster configuration decisions made by the administrator. `kubectl auth can-i` is the practical way for a user to test the resulting decision.

## Security Notes

- Authentication is not authorization: a valid certificate or token only identifies the caller.
- Treat client keys, tokens, passwords, and kubeconfig files as secrets.
- Avoid putting passwords directly in kubeconfig; use an external credential plugin or an identity provider where possible.
- Verify the API server certificate and prefer a trusted `certificate-authority` over `insecure-skip-tls-verify`.
- Avoid cluster-admin access for normal users and workloads.
- Review access with `kubectl auth can-i --list` and remove unused credentials or bindings.

## Suggested Practice

1. Inspect [kubeconfig.yml](kubeconfig.yml) and identify its clusters, users, contexts, and empty `current-context`.
2. Replace the placeholder values in a local copy with valid cluster details, then select a context.
3. Use `kubectl auth can-i` to compare permissions in different namespaces.
4. Follow the certificate workflow in [day21_manage_tls_certificates](../day21_manage_tls_certificates/) to see how a client certificate is requested and issued.
5. Create a namespace-scoped Role and RoleBinding in a practice cluster, then verify both allowed and denied actions.

This folder contains examples and does not create cluster resources by itself, so there is nothing to clean up unless you create additional test RBAC objects while practicing.