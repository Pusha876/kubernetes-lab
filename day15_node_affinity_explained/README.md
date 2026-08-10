# Node and Pod Affinity in Kubernetes

Affinity lets you influence where Pods get scheduled.

- **Node affinity**: choose nodes by node labels.
- **Pod affinity**: place a Pod near other Pods.
- **Pod anti-affinity**: keep a Pod away from other Pods.

Think of it as smarter scheduling rules compared to a basic `nodeSelector`.

## Why Affinity Matters

You use affinity to:

- Keep workloads close for low latency.
- Separate workloads for high availability.
- Place workloads on nodes with specific hardware (SSD, GPU, zone).
- Prefer a location without making it a hard requirement.

## Scheduling Rule Types

Kubernetes supports two important rule strengths:

1. **requiredDuringSchedulingIgnoredDuringExecution**
	 - Hard rule.
	 - Pod is scheduled only if rule matches.
	 - If no node matches, Pod stays `Pending`.

2. **preferredDuringSchedulingIgnoredDuringExecution**
	 - Soft rule.
	 - Scheduler tries to match this preference.
	 - If no preferred node is available, Pod can still run elsewhere.

`IgnoredDuringExecution` means if labels change later, Kubernetes usually does not evict already-running Pods because of this affinity rule alone.

## Node Affinity

Node affinity selects nodes using node labels.

### Hard Requirement Example

This matches [affinity.yaml](affinity.yaml):

```yaml
apiVersion: v1
kind: Pod
metadata:
	name: redis-3
spec:
	containers:
	- name: redis
		image: redis
	affinity:
		nodeAffinity:
			requiredDuringSchedulingIgnoredDuringExecution:
				nodeSelectorTerms:
				- matchExpressions:
					- key: disktype
						operator: Exists
```

Meaning: schedule only on nodes that have the `disktype` label (any value).

### Soft Preference Example

This matches [affinity2.yaml](affinity2.yaml):

```yaml
apiVersion: v1
kind: Pod
metadata:
	name: redis-new
spec:
	containers:
	- name: redis
		image: redis
	affinity:
		nodeAffinity:
			preferredDuringSchedulingIgnoredDuringExecution:
			- weight: 1
				preference:
					matchExpressions:
					- key: disktype
						operator: In
						values:
						- hdd
```

Meaning: scheduler prefers nodes labeled `disktype=hdd`, but can choose another node if needed.

## Common Operators

In `matchExpressions`, operators include:

- `In`
- `NotIn`
- `Exists`
- `DoesNotExist`
- `Gt`
- `Lt`

Example label logic:

- `key: env`, `operator: In`, `values: [prod]`
- `key: gpu`, `operator: Exists`

## Pod Affinity Example

Use this when you want a Pod to run close to another Pod (same zone or node domain).

```yaml
apiVersion: v1
kind: Pod
metadata:
	name: api-pod
	labels:
		app: api
spec:
	containers:
	- name: api
		image: nginx
	affinity:
		podAffinity:
			requiredDuringSchedulingIgnoredDuringExecution:
			- labelSelector:
					matchExpressions:
					- key: app
						operator: In
						values:
						- cache
				topologyKey: topology.kubernetes.io/zone
```

Meaning: this Pod must be scheduled in a zone where at least one Pod with `app=cache` already exists.

## Pod Anti-Affinity Example

Use this to spread replicas and avoid single-node failure impact.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
	name: web
spec:
	replicas: 3
	selector:
		matchLabels:
			app: web
	template:
		metadata:
			labels:
				app: web
		spec:
			containers:
			- name: web
				image: nginx
			affinity:
				podAntiAffinity:
					requiredDuringSchedulingIgnoredDuringExecution:
					- labelSelector:
							matchExpressions:
							- key: app
								operator: In
								values:
								- web
						topologyKey: kubernetes.io/hostname
```

Meaning: scheduler tries to place `web` Pods on different nodes.

## Quick Lab Commands

1. Label a node:

```bash
kubectl label nodes <node-name> disktype=hdd
```

2. Create Pods:

```bash
kubectl apply -f affinity.yaml
kubectl apply -f affinity2.yaml
```

3. Check scheduling result:

```bash
kubectl get pods -o wide
kubectl describe pod redis-3
kubectl describe pod redis-new
```

4. If a Pod is pending, inspect events at the end of `describe` output.

## Affinity vs nodeSelector

- `nodeSelector` is simple exact-match logic.
- `nodeAffinity` is more expressive with operators and soft/hard constraints.

If your placement logic is basic, `nodeSelector` is fine. For production-grade scheduling intent, prefer affinity.
