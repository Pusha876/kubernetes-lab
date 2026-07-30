# Day 10 - Kubernetes Namespaces

Namespaces let you divide a cluster into logical partitions. We used them to keep resources separated by environment, domain, or resource type.

## Why use namespaces?

- Provide isolation of resources inside the same cluster
- Help avoid accidental deletion or modification of unrelated resources
- Separate workloads by resource type, environment, team, or domain
- Make it easier to organize and manage Kubernetes objects

## Create a namespace

Create one imperatively:

```bash
kubectl create namespace demo
```

Verify it exists:

```bash
kubectl get namespaces
```

Or create it with YAML:

```yaml
apiVersion: v1
kind: Namespace
metadata:
	name: demo
```

Apply the file with:

```bash
kubectl apply -f namespace.yaml
```

## Use a namespace for resources

Create a resource directly in a namespace:

```bash
kubectl apply -f pod.yaml -n demo
```

List resources in that namespace:

```bash
kubectl get pods -n demo
kubectl get svc -n demo
```

You can also make a namespace the default for the current context:

```bash
kubectl config set-context --current --namespace=demo
```

## DNS and service access

Pods and services in the same namespace can usually reach each other by the service name alone.

Example:

```bash
curl http://my-service
```

If the service is in another namespace, use the full DNS name:

```bash
curl http://my-service.other-namespace
```

For a fully qualified service name, Kubernetes DNS follows this pattern:

```text
service-name.namespace.svc.cluster.local
```

## Useful commands

```bash
kubectl get all -n demo
kubectl describe namespace demo
kubectl delete namespace demo
```

## Notes

- Resources in one namespace are isolated from resources in another namespace by default.
- A namespace is a good boundary for development, staging, and production workloads.
- Shared cluster-level resources like nodes are not isolated by namespaces.
