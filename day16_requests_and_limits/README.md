# CKA Critical Q&A: Requests and Limits

This guide is a fast revision set for CKA on **resource requests and limits**, using the same workflow we just executed in this folder.

---

## 1) What are requests and limits in Kubernetes?

**Question:** What is the difference between `requests` and `limits` for CPU and memory?

**Answer:**
- `requests`: minimum resources guaranteed for a container. Scheduler uses this value to place Pods.
- `limits`: maximum resources a container can use.

Key behavior:
- CPU limit is throttled when exceeded.
- Memory limit can cause OOM kill if exceeded.

---

## 2) Why do requests matter for scheduling?

**Question:** Which value does the scheduler use to decide where a Pod can run?

**Answer:**
- Scheduler uses **requests**, not limits.
- If a node cannot satisfy requested CPU/memory, Pod stays `Pending`.

Quick check command:

```bash
kubectl describe pod <pod-name>
```

Look for events like `0/3 nodes are available: Insufficient cpu`.

---

## 3) How do you set requests and limits in a Pod spec?

**Question:** Where do you define CPU and memory requests/limits?

**Answer:**
Define under container resources:

```yaml
resources:
	requests:
		cpu: "100m"
		memory: "128Mi"
	limits:
		cpu: "250m"
		memory: "256Mi"
```

`m` means millicores (`1000m = 1 CPU`).

---

## 4) How do you measure real CPU/memory usage in-cluster?

**Question:** Which command shows live node/pod usage?

**Answer:**
- `kubectl top nodes`
- `kubectl top pods -A`

These require **metrics-server**.

---

## 5) How did we install metrics-server in this lab?

**Question:** What command did we use in this folder?

**Answer:**

```bash
kubectl apply -f metrics-server.yaml --validate=false
```

Why `--validate=false`?
- We hit a transient OpenAPI TLS handshake timeout during client validation.
- Disabling validation allowed manifest apply to proceed successfully.

---

## 6) How do you verify metrics-server is healthy?

**Question:** What are the fastest exam-safe verification steps?

**Answer:**

```bash
kubectl -n kube-system get deploy,po,svc | grep metrics-server
kubectl get apiservice v1beta1.metrics.k8s.io -o wide
kubectl top nodes
```

Expected signs:
- `metrics-server` Pod is `Running`.
- APIService `v1beta1.metrics.k8s.io` is `Available=True`.
- `kubectl top` returns CPU/memory values.

---

## 7) CKA troubleshooting: apply fails with TLS handshake timeout

**Question:** You run `kubectl apply -f metrics-server.yaml` and get:

`failed to download openapi ... TLS handshake timeout`

What do you do?

**Answer:**
1. Confirm cluster connectivity:

```bash
kubectl cluster-info
```

2. Re-run with validation disabled:

```bash
kubectl apply -f metrics-server.yaml --validate=false
```

3. Verify API service and metrics:

```bash
kubectl get apiservice v1beta1.metrics.k8s.io -o wide
kubectl top nodes
```

---

## 8) Common CKA quick questions

**Q:** Can a Pod use more CPU than its request?  
**A:** Yes, up to its CPU limit (or unlimited if no limit set).

**Q:** Can a Pod use more memory than its limit?  
**A:** No. It may be terminated (OOMKilled).

**Q:** What happens if no requests/limits are set?  
**A:** Pod may run as BestEffort QoS (unless defaults are applied by LimitRange).

**Q:** What command shows why a Pod is Pending?  
**A:** `kubectl describe pod <pod-name>` (check Events).

---

## 9) Exam-speed command block

```bash
# Apply metrics server
kubectl apply -f metrics-server.yaml --validate=false

# Verify control plane metrics API
kubectl get apiservice v1beta1.metrics.k8s.io -o wide

# Verify node and pod usage
kubectl top nodes
kubectl top pods -A

# Investigate scheduling/resource issues
kubectl describe pod <pod-name>
kubectl get events --sort-by=.metadata.creationTimestamp
```

---

## 10) Remember for CKA

- Use **requests** for guaranteed scheduling.
- Use **limits** to cap usage and protect node stability.
- If `top` is unavailable, first fix **metrics-server**.
- If apply validation fails due to OpenAPI timeout, use `--validate=false` and continue.
