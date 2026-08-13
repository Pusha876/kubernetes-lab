# Health Probes

Health probes let Kubernetes decide whether a container is alive, ready to serve traffic, or still starting up. They are one of the main tools for keeping Pods healthy without manual intervention.

## Probe Types

- Liveness probe: checks whether the container is still running correctly. If it fails too many times, Kubernetes restarts the container.
- Readiness probe: checks whether the container is ready to receive traffic. If it fails, the Pod stays out of Service endpoints.
- Startup probe: checks whether a slow-starting container has finished booting. While it is failing, liveness checks are paused.

## Examples In This Folder

### Exec Liveness Probe

File: `liveness-command.yaml`

This Pod uses a file check as a liveness probe.

- The container creates `/tmp/healthy` when it starts.
- After 30 seconds, the file is removed.
- The liveness probe runs `cat /tmp/healthy` every 5 seconds.
- Once the file disappears, the probe fails and the container is restarted.

Example command:

```bash
kubectl apply -f liveness-command.yaml
kubectl get pods -w
```

### HTTP Liveness And Readiness Probe

File: `liveness-http.yaml`

This Pod uses the `agnhost` sample image and checks the `/healthz` endpoint on port 8080.

- The liveness probe starts after 3 seconds and runs every 3 seconds.
- The readiness probe starts later, after 15 seconds, and runs every 10 seconds.
- If `/healthz` returns a failure, Kubernetes marks the container unready or restarts it depending on the probe type.

Example command:

```bash
kubectl apply -f liveness-http.yaml
kubectl describe pod hello
```

### TCP Liveness Probe

File: `liveness-tcp.yaml`

This Pod uses a TCP socket check.

- The container exposes port 8080.
- The liveness probe checks port 3000.
- Because the probe is pointed at a different port, it will fail unless something is listening there.

Example command:

```bash
kubectl apply -f liveness-tcp.yaml
kubectl describe pod tcp-pod
```

## What To Look For

When a probe fails, check the Pod events:

```bash
kubectl describe pod <pod-name>
```

Common symptoms:

- `Ready 0/1`: the container is running, but the readiness probe is failing.
- `CrashLoopBackOff`: the container is repeatedly restarting, often because the liveness probe fails.
- `ImagePullBackOff`: Kubernetes cannot pull the container image, so the Pod never starts.

## Suggested Practice

Try each manifest one at a time, then watch how the status changes over time. The goal is to see the difference between a Pod that is running, a Pod that is ready, and a Pod that is being restarted because its liveness check fails.
