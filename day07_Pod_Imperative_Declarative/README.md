# day07 Pod Imperative vs Declarative

This folder focuses on creating and managing Pods with `kubectl` using both:

- Imperative commands (quick, command-line driven)
- Declarative manifests (YAML files you apply)

## kubectl Command Cheat Sheet

Use these commands frequently while working on Pod tasks:

| Command | What it does | Common use in this folder |
| --- | --- | --- |
| `kubectl run <name> --image=<image>` | Creates a Pod imperatively | Fast Pod creation for Task 1 |
| `kubectl get pods` | Lists pods and status | Verify Pod creation and health |
| `kubectl get pods -o wide` | Lists pods with node/IP details | Deeper verification |
| `kubectl describe pod <name>` | Shows detailed Pod events/state | Troubleshooting image/start errors |
| `kubectl logs <name>` | Shows container logs | Runtime debugging |
| `kubectl delete pod <name>` | Deletes a Pod | Cleanup/reset between tasks |
| `kubectl run <name> --image=<image> --dry-run=client -o yaml` | Generates Pod YAML without creating it | Starting point for Task 2 manifests |
| `kubectl apply -f <file>.yaml` | Creates/updates resources from YAML | Declarative workflow for Tasks 2 and 3 |
| `kubectl create -f <file>.yaml` | Creates resource from YAML only if not existing | One-time declarative create |
| `kubectl explain pod` | Shows Pod schema help | Validate manifest fields |

## Task-Based Usage

### Task 1: Create nginx Pod Imperatively

Goal: Create a Pod named `nginx` with image `nginx`.

Command:

```bash
kubectl run nginx --image=nginx
kubectl get pods
```

How this is used:

- `kubectl run` is the imperative way to create the Pod immediately.
- `kubectl get pods` confirms the Pod exists and reaches `Running`.

Expected output (example):

```text
NAME    READY   STATUS    RESTARTS   AGE
nginx   1/1     Running   0          10s
```

### Task 2: Generate YAML, Rename, and Create New Pod

Goal:

1. Generate YAML from Task 1 Pod setup
2. Change Pod name to `nginx-new`
3. Create the new Pod from YAML

Commands:

```bash
kubectl run nginx --image=nginx --dry-run=client -o yaml > nginx.yaml
```

Edit `nginx.yaml` and update:

```yaml
metadata:
  name: nginx-new
```

Then apply:

```bash
kubectl apply -f nginx.yaml
kubectl get pods
```

How this is used:

- `--dry-run=client -o yaml` bridges imperative to declarative by generating a manifest template.
- `kubectl apply -f` uses declarative style to create/manage resources from file state.

Expected output (example):

```text
pod/nginx-new created

NAME        READY   STATUS    RESTARTS   AGE
nginx       1/1     Running   0          2m
nginx-new   1/1     Running   0          8s
```

### Task 3: Apply Broken YAML and Troubleshoot

Provided YAML (has error: image `rediss`):

```yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    app: test
  name: redis
spec:
  containers:
  - image: rediss
    name: redis
```

Suggested troubleshooting flow:

```bash
kubectl apply -f redis.yaml
kubectl get pods
kubectl describe pod redis
```

Typical error you will observe:

- Pod status: `ErrImagePull` / `ImagePullBackOff`
- Event message similar to: `Failed to pull image "rediss": ... not found`

Fix:

1. Update image from `rediss` to `redis` in YAML.
2. Re-apply manifest.

```bash
kubectl apply -f redis.yaml
kubectl get pods
```

Expected output before fix (example):

```text
NAME    READY   STATUS             RESTARTS   AGE
redis   0/1     ImagePullBackOff   0          25s
```

Expected output after fix (example):

```text
pod/redis configured

NAME    READY   STATUS    RESTARTS   AGE
redis   1/1     Running   0          20s
```

## Imperative vs Declarative (Project-Specific Definition)

### Imperative in this folder

Imperative means telling Kubernetes exactly what command to run right now.

- Example: `kubectl run nginx --image=nginx`
- Best for: quick tests, learning, and fast one-off Pod creation.

### Declarative in this folder

Declarative means defining the desired Pod state in YAML and applying that file.

- Example: `kubectl apply -f nginx.yaml`
- Best for: repeatable setups, version control, and team collaboration.

### Practical rule for this repo

- Start imperative to understand resources quickly.
- Move to declarative YAML for reproducible and maintainable Kubernetes workflows.