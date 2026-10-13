## Save GCP cluster disks with snapshots

Google Compute Engine boot disks are persistent disks, but the disks in this
lab are configured to be deleted when their VM is destroyed. Create snapshots
before changing Terraform, recreating the VMs, or making other risky changes.

The commands below use the lab project and zone. Change them if your cluster
uses different values:

```bash
export PROJECT_ID=cka-kubernetes-lab-508720
export ZONE=us-east1-b
```

### 1. Stop the cluster before taking snapshots

Stopping the VMs gives the snapshots a consistent view of the Kubernetes
control-plane and worker files:

```bash
gcloud compute instances stop cka-master cka-worker-1 cka-worker-2 \
  --zone="$ZONE" \
  --project="$PROJECT_ID"
```

### 2. Find the attached persistent-disk names

Do not assume that a disk name is identical to its VM name. List the disks
attached to each VM:

```bash
for INSTANCE in cka-master cka-worker-1 cka-worker-2; do
  echo "=== $INSTANCE ==="
  gcloud compute instances describe "$INSTANCE" \
    --zone="$ZONE" \
    --project="$PROJECT_ID" \
    --format="table(disks[].deviceName,disks[].source.basename())"
done
```

### 3. Create a snapshot for each boot disk

Replace the disk names below with the names returned by the previous command.
Snapshot names must be unique within the project:

```bash
gcloud compute disks snapshot <master-disk-name> \
  --snapshot-names=cka-master-$(date +%Y%m%d-%H%M%S) \
  --zone="$ZONE" \
  --project="$PROJECT_ID"

gcloud compute disks snapshot <worker-1-disk-name> \
  --snapshot-names=cka-worker-1-$(date +%Y%m%d-%H%M%S) \
  --zone="$ZONE" \
  --project="$PROJECT_ID"

gcloud compute disks snapshot <worker-2-disk-name> \
  --snapshot-names=cka-worker-2-$(date +%Y%m%d-%H%M%S) \
  --zone="$ZONE" \
  --project="$PROJECT_ID"
```

Confirm that the snapshots completed:

```bash
gcloud compute snapshots list \
  --project="$PROJECT_ID" \
  --filter="name~'^cka-(master|worker-1|worker-2)-'" \
  --format="table(name,status,creationTimestamp)"
```

### 4. Start the cluster again

```bash
gcloud compute instances start cka-master cka-worker-1 cka-worker-2 \
  --zone="$ZONE" \
  --project="$PROJECT_ID"
```

After the VMs start, connect to `cka-master` and verify the cluster:

```bash
gcloud compute ssh cka-master \
  --zone="$ZONE" \
  --project="$PROJECT_ID"

kubectl get nodes -o wide
kubectl get pods -A
```

Snapshots are backups, not live disks. If a VM is recreated, restore a
snapshot to a new persistent disk and attach it to the replacement VM, or
restore the cluster from an etcd backup. Keep at least one snapshot from
before each Terraform rebuild and delete old snapshots only after confirming
that a newer backup is usable.

## Deploy NGINX on both worker nodes

### Install Calico networking first

Pods cannot start until the cluster has a working CNI. This cluster runs
Kubernetes `v1.30`, so use Calico `v3.29`, which supports that Kubernetes
minor release. Do not install Calico `v3.30` or newer until Kubernetes is
upgraded: Calico `v3.30` is tested with Kubernetes `v1.31` through `v1.35`.

```bash
curl -LO https://raw.githubusercontent.com/projectcalico/calico/v3.29.7/manifests/calico.yaml
kubectl apply -f calico.yaml
kubectl get pods -n calico-system -w
```

Do not create the `calico-system` namespace manually. Continue only when
Calico pods are `Running` and CoreDNS can start:

```bash
kubectl get pods -n calico-system
kubectl get pods -n kube-system
```

Label the worker nodes so that the workload does not run on `cka-master`.
Use the exact node names returned by `kubectl get nodes`.

```bash
kubectl get nodes -o wide

kubectl label node <worker-1-node-name> workload=nginx
kubectl label node <worker-2-node-name> workload=nginx
```

Create `nginx-workers.yaml`:

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: nginx-workers
  namespace: default
spec:
  selector:
    matchLabels:
      app: nginx-workers
  template:
    metadata:
      labels:
        app: nginx-workers
    spec:
      nodeSelector:
        workload: nginx
      containers:
        - name: nginx
          image: nginx:1.27
          ports:
            - name: http
              containerPort: 80
              protocol: TCP
          readinessProbe:
            httpGet:
              path: /
              port: 80
            initialDelaySeconds: 3
            periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-workers
  namespace: default
spec:
  selector:
    app: nginx-workers
  type: NodePort
  ports:
    - name: http
      port: 80
      targetPort: 80
      nodePort: 30080
      protocol: TCP
```

Apply the workload:

```bash
kubectl apply -f nginx-workers.yaml
kubectl rollout status daemonset/nginx-workers
kubectl get pods -l app=nginx-workers -o wide
kubectl get service nginx-workers
```

The `DaemonSet` creates one NGINX pod on each labeled worker. The Service
listens on port 80 inside the cluster and exposes it as NodePort `30080` on
each node. Test it from a machine that can reach the worker network:

```bash
curl http://<worker-1-ip>:30080
curl http://<worker-2-ip>:30080
```

If the requests must be reachable from the public internet, allow TCP port
`30080` in the GCP firewall for the worker instances. A NodePort does not
make the service publicly reachable by itself. For a public service on
standard port 80, use a Kubernetes `LoadBalancer` Service or an external
HTTP load balancer instead of exposing port 80 directly on the VM host.

Clean up the example with:

```bash
kubectl delete -f nginx-workers.yaml
kubectl label node <worker-1-node-name> workload-
kubectl label node <worker-2-node-name> workload-
```