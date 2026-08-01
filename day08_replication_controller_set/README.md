# Day 08 - Replication Controllers and Pods

This note captures useful commands for inspecting a live Pod object and identifying which controller created it.

## Inspect a Pod's live object

Show the full Pod manifest as stored in the cluster:

```bash
kubectl get pod <pod-name> -n <namespace> -o yaml
```

Example:

```bash
kubectl get pod nginx-bwtm2 -n default -o yaml
```

## Inspect a Pod in human-readable form

Show a detailed summary of the Pod, including events, labels, and owner references:

```bash
kubectl describe pod <pod-name> -n <namespace>
```

Example:

```bash
kubectl describe pod nginx-bwtm2 -n default
```

## Find the controller that created the Pod

Check the owner reference on the Pod:

```bash
kubectl get pod <pod-name> -n <namespace> -o jsonpath='{.metadata.ownerReferences[*].kind}{" "}{.metadata.ownerReferences[*].name}{"\n"}'
```

Example:

```bash
kubectl get pod nginx-bwtm2 -n default -o jsonpath='{.metadata.ownerReferences[*].kind}{" "}{.metadata.ownerReferences[*].name}{"\n"}'
```

## Inspect the controller object

If the Pod is controlled by a Deployment, ReplicaSet, Job, or similar object, inspect that object directly:

```bash
kubectl get deployment <deployment-name> -n <namespace> -o yaml
kubectl get rs <replicaset-name> -n <namespace> -o yaml
```

## Useful output to look for

When inspecting a Pod, check for:

- `Controlled By:` in `kubectl describe`
- `ownerReferences` in the YAML output
- `Labels:` and `Annotations:`
- Container status and events
