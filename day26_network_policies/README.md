# Day 26: Network Policies

## Manifests

- Application workloads and Services: [Task/manifest.yaml](Task/manifest.yaml)
- Database ingress policy: [Task/networkpolicy.yaml](Task/networkpolicy.yaml)

> Note: the current application manifest defines standalone `Pod` resources and Services of the default `ClusterIP` type. Convert the workloads to `Deployment` resources and set `spec.type: NodePort` on each Service when those are required by the exercise.

## 1. Install Calico

The Kind configuration disables Kind's default CNI, so install Calico before creating workload pods.

```bash
kind create cluster --name cka-new --image kindest/node:v1.35.0 --config kind_new.yaml
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.32.1/manifests/tigera-operator.yaml
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.32.1/manifests/custom-resources.yaml
kubectl get pods -n tigera-operator -w
```

Verify that Calico is available on every node:

```bash
kubectl get nodes
kubectl get daemonset -n calico-system calico-node
kubectl get pods -n calico-system -o wide
```

Troubleshooting:

- If nodes remain `NotReady`, confirm that all `calico-node` pods are `Running` with `kubectl get pods -n calico-system -o wide`.
- If the Tigera operator is restarting, inspect it with `kubectl logs -n tigera-operator deployment/tigera-operator --previous`.
- If `kubectl` reports a TLS handshake timeout or `EOF`, restart Docker Desktop and verify the cluster API with `kubectl get --raw='/readyz?verbose' --request-timeout=20s`.
- Do not apply both `calico.yaml` and the Tigera operator manifests. Use one Calico installation method only.

## 2. Create Frontend, Backend, and Database Workloads

The exercise uses one frontend NGINX workload, one backend NGINX workload, and one MySQL database workload. Their required labels are important because the Services and NetworkPolicy select pods by label.

```bash
kubectl apply -f Task/manifest.yaml
kubectl get pods -o wide
kubectl get pods --show-labels
```

Expected labels:

- `frontend`: `role=frontend`
- `backend`: `role=backend`
- `mysql`: `name=mysql`

Troubleshooting:

- For `ContainerCreating`, inspect the pod events: `kubectl describe pod <pod-name>`.
- For `ErrImagePull` or `ImagePullBackOff`, make sure Docker Desktop has Internet access and retry after the image pull succeeds.
- For `Pending`, inspect scheduling events with `kubectl get events --sort-by=.lastTimestamp` and confirm nodes are `Ready`.
- For MySQL failures, view logs with `kubectl logs mysql` and confirm `MYSQL_ROOT_PASSWORD` is set.

## 3. Expose Services as NodePorts

Create one Service per application using the matching workload name:

```bash
kubectl expose deployment frontend --name=frontend --type=NodePort --port=80 --target-port=80
kubectl expose deployment backend --name=backend --type=NodePort --port=80 --target-port=80
kubectl expose deployment db --name=db --type=NodePort --port=3306 --target-port=3306
kubectl get services
```

For the current standalone-Pod manifest, make the same Service changes in `Task/manifest.yaml`: add `type: NodePort` under each Service `spec`. Kubernetes will assign a NodePort unless a valid `nodePort` is specified.

Troubleshooting:

- If `kubectl expose deployment` returns `NotFound`, the workload is a standalone Pod. Update the Service manifest directly or convert the Pod into a Deployment first.
- If a Service has no endpoints, compare its selector with pod labels: `kubectl get endpoints <service-name>` and `kubectl get pods --show-labels`.
- On Kind, a NodePort is reachable only when the cluster configuration maps that port to the host. The provided configuration maps host port `30001` to node port `30001`.

## 4. Test Connectivity

Run DNS and HTTP checks from the frontend pod to the backend Service:

```bash
kubectl exec frontend -- getent hosts backend
kubectl exec frontend -- wget -qO- http://backend
```

Test database access from the backend pod before applying the NetworkPolicy:

```bash
kubectl exec backend -- getent hosts db
kubectl exec backend -- sh -c 'nc -zvw 5 db 3306'
```

Troubleshooting:

- If name lookup fails, verify CoreDNS with `kubectl get pods -n kube-system -l k8s-app=kube-dns`.
- If the Service name resolves but the connection fails, inspect its endpoints with `kubectl get endpoints backend db`.
- If `nc` or `wget` is not in the container image, start a temporary test pod: `kubectl run netcheck --rm -it --restart=Never --image=busybox:1.36 -- sh`.

## 5. Restrict Database Access with a NetworkPolicy

Apply the policy in [Task/networkpolicy.yaml](Task/networkpolicy.yaml). It selects MySQL with `name: mysql` and permits ingress only from pods labeled `role: backend` on TCP port `3306`.

```bash
kubectl apply -f Task/networkpolicy.yaml
kubectl get networkpolicy
kubectl describe networkpolicy db-test
```

Troubleshooting:

- If the policy has no effect, confirm Calico is running; NetworkPolicy enforcement requires a network plugin that supports it.
- If backend is blocked, compare labels precisely using `kubectl get pod backend mysql --show-labels`.
- If access from frontend still succeeds, verify that the policy targets the MySQL pod with `kubectl describe networkpolicy db-test`.

## 6. Verify Backend-Only Database Access

The policy is attached by selecting the database workload, not by being assigned to the backend workload. Its `from` rule permits the backend label and denies all other ingress to the selected MySQL pod on port `3306`.

```bash
kubectl exec backend -- sh -c 'nc -zvw 5 db 3306'
kubectl exec frontend -- sh -c 'nc -zvw 5 db 3306'
```

The backend test should succeed. The frontend test should time out or fail after the NetworkPolicy is applied.

Troubleshooting:

- Run the tests only after all relevant pods report `Running` and `Ready`.
- If the test results are reversed, inspect the policy selector and labels with `kubectl get networkpolicy db-test -o yaml` and `kubectl get pods --show-labels`.
- Delete the policy temporarily only for diagnosis: `kubectl delete -f Task/networkpolicy.yaml`. Reapply it with `kubectl apply -f Task/networkpolicy.yaml` when testing is complete.
kubectl get networkpolicy
```

The `db-test` policy selects the MySQL pod with `name: mysql` and allows ingress only from pods labeled `role: backend` on TCP port `3306`.
