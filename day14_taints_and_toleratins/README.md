# Kubernetes Scheduling Guide: Taints, Tolerations, Labels, and Selectors

This guide explains what each concept does, when to use it, and the commands you can run during setup and troubleshooting.

## 1) Labels

Labels are key/value metadata attached to Kubernetes objects (nodes, pods, deployments, etc.).

Use labels to:

- Organize resources (environment, tier, team)
- Select targets for scheduling and services
- Filter resources quickly

Examples:

```bash
# Show labels on nodes
kubectl get nodes --show-labels

# Add label to a node
kubectl label node cka-cluster3-worker gpu=false

# Update an existing label (overwrite)
kubectl label node cka-cluster3-worker gpu=true --overwrite

# Remove a label
kubectl label node cka-cluster3-worker gpu-
```

## 2) Selectors (nodeSelector and label selectors)

Selectors match resources by label.

Use selectors when you need workloads to run only on specific nodes or to query matching resources.

### Pod-level nodeSelector example

```yaml
apiVersion: v1
kind: Pod
metadata:
	name: nginx-new
spec:
	nodeSelector:
		gpu: "false"
	containers:
	- name: nginx-new
		image: nginx
```

Important: The selected label must exist on at least one schedulable node.

### CLI selector examples

```bash
# List pods with a label
kubectl get pods -l app=nginx

# List nodes that match a label
kubectl get nodes -l gpu=false
```

## 3) Taints

Taints are applied to nodes to repel pods.

Think: "Do not schedule here unless pod explicitly tolerates this taint."

Use taints when:

- Reserving nodes for special workloads (GPU, infra, sensitive jobs)
- Preventing general workloads from using specific nodes

Examples:

```bash
# Add taint: only tolerant pods can schedule on this node
kubectl taint nodes cka-cluster3-worker2 gpu=true:NoSchedule

# View taints
kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints

# Remove taint
kubectl taint nodes cka-cluster3-worker2 gpu=true:NoSchedule-
```

Common taint effects:

- `NoSchedule`: new non-tolerating pods are not scheduled there
- `PreferNoSchedule`: soft avoid
- `NoExecute`: evicts running non-tolerating pods and blocks new ones

## 4) Tolerations

Tolerations are set on pods and allow (but do not force) scheduling onto tainted nodes.

Use tolerations when workloads are allowed to run on restricted nodes.

Example (pod can run on nodes tainted with `gpu=true:NoSchedule`):

```yaml
apiVersion: v1
kind: Pod
metadata:
	name: nginx-gpu
spec:
	tolerations:
	- key: "gpu"
		operator: "Equal"
		value: "true"
		effect: "NoSchedule"
	containers:
	- name: nginx
		image: nginx
```

Best practice: combine `tolerations` + `nodeSelector` when you want both permission and placement control.

## 5) When to Use What

- Use labels: categorize and identify resources.
- Use selectors: choose resources by labels (including node placement).
- Use taints: block general scheduling on a node.
- Use tolerations: allow specific pods onto tainted nodes.

Decision rule:

- "I want pod only on node type X" -> add label + nodeSelector.
- "I want to protect node X from regular pods" -> add taint.
- "I want only approved pods on tainted node X" -> add toleration (and usually nodeSelector).

## 6) End-to-End Example

Goal: run pod only on worker2 and keep other pods away.

1. Label node:

```bash
kubectl label node cka-cluster3-worker2 gpu=true --overwrite
```

2. Taint node:

```bash
kubectl taint nodes cka-cluster3-worker2 gpu=true:NoSchedule --overwrite
```

3. Create pod with both selector and toleration:

```yaml
apiVersion: v1
kind: Pod
metadata:
	name: nginx-new
spec:
	nodeSelector:
		gpu: "true"
	tolerations:
	- key: "gpu"
		operator: "Equal"
		value: "true"
		effect: "NoSchedule"
	containers:
	- name: nginx-new
		image: nginx
```

4. Apply and verify:

```bash
kubectl apply -f newnginx.yaml
kubectl get pod nginx-new -o wide
kubectl describe pod nginx-new | sed -n '/Events/,$p'
```

## 7) Troubleshooting Checklist

If pod is `Pending`:

```bash
kubectl describe pod <pod-name>
kubectl get nodes --show-labels
kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints
kubectl get events -A --sort-by=.lastTimestamp | tail -n 50
```

Typical errors and fixes:

- `didn't match Pod's node affinity/selector` -> fix/add matching node label or selector.
- `had untolerated taint(s)` -> add toleration or remove taint.
- `Node: <none>` in describe -> scheduling constraints are blocking placement.
