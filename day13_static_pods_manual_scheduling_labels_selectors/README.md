# Cleanup Process (Required for Every Project)

This section captures the exact steps we used to stop and delete nginx workloads that were being recreated by Kubernetes controllers.

Use this as a standard cleanup checklist at the end of every project.

## Why pods kept coming back

Deleting Pods directly is not enough when a controller (Deployment, ReplicaSet, ReplicationController, StatefulSet, or DaemonSet) still exists.

Kubernetes immediately recreates Pods to match the controller's desired state.

## Standard Cleanup Steps

### 1. Find all nginx controllers in the default namespace

```bash
kubectl get deploy,rs,rc,ds,sts,job,cronjob -n default | findstr nginx
```

### 2. Scale scalable nginx controllers to 0 replicas

```bash
for kind in deploy rs rc sts; do
	kubectl get $kind -n default --no-headers 2>/dev/null | awk '/nginx/ {print $1}' | xargs -r -I {} kubectl scale $kind/{} -n default --replicas=0
done
```

### 3. Handle DaemonSets separately (they do not use replicas)

```bash
kubectl get ds -n default | findstr nginx
```

If any nginx DaemonSet exists, delete it:

```bash
kubectl delete ds <daemonset-name> -n default
```

### 4. Delete remaining nginx Pods

```bash
kubectl get pods -n default --no-headers | awk '/nginx/ {print $1}' | xargs -r kubectl delete pod -n default
```

### 5. Verify cleanup is complete

```bash
kubectl get pods,deploy,rs,rc,ds,sts,job,cronjob -n default | findstr nginx
```

If this returns no nginx resources, cleanup is complete.

## Optional: Delete nginx ReplicaSets after scaling

```bash
kubectl get rs -n default --no-headers | awk '/nginx/ {print $1}' | xargs -r -I {} kubectl delete rs/{} -n default
```

## Troubleshooting

- If Pods reappear, another parent controller still exists.
- Check owner references to find the true parent:

```bash
kubectl get pod <pod-name> -n default -o jsonpath='{.metadata.ownerReferences[*].kind}{"/"}{.metadata.ownerReferences[*].name}{"\n"}'
```

## Important Note

Always include this cleanup flow in every project teardown to avoid leftover workloads and unexpected resource usage.


----
### Control-Plane Static Pod Manifest Check (Critical)

If new Pods are stuck in `Pending` and show no associated node in `kubectl describe pod`, verify the control-plane static pod manifest directory and required files.

Use the correct path:

```bash
cd /etc/kubernetes/manifests/
ls -lrt
```

Note: `/etc/kubenetes/manifests/` is a typo and does not exist.

This folder on the control-plane node should contain at least:

- `etcd.yaml`
- `kube-apiserver.yaml`
- `kube-controller-manager.yaml`
- `kube-scheduler.yaml`

If any of these files are missing, the cluster control plane may be incomplete and scheduling can fail, causing new Pods to remain in `Pending` without a node assignment.

## Quick Health Check (Run During Troubleshooting)

Use this checklist whenever workloads are not scheduling or cluster behavior looks unstable.

### 1. Confirm nodes are Ready

```bash
kubectl get nodes -o wide
```

### 2. Confirm core control-plane/system Pods are healthy

```bash
kubectl get pods -n kube-system -o wide
kubectl get pods -n kube-system | findstr "etcd kube-apiserver kube-controller-manager kube-scheduler coredns"
```

### 3. Check recent warnings/errors across all namespaces

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

### 4. Validate scheduling symptoms for a Pending Pod

```bash
kubectl describe pod <pod-name> -n <namespace>
```

Look for:

- `Node: <none>`
- `Events` showing scheduling failures

### 5. Re-check control-plane static manifests (on control-plane node)

```bash
cd /etc/kubernetes/manifests/
ls -lrt
```

Expected files:

- `etcd.yaml`
- `kube-apiserver.yaml`
- `kube-controller-manager.yaml`
- `kube-scheduler.yaml`

### 6. Validate post-fix status

```bash
kubectl get pods -A -o wide
kubectl get events -A --sort-by=.lastTimestamp
```

If Pending Pods now have assigned nodes and no new scheduler/control-plane errors appear, the cluster is healthy.
