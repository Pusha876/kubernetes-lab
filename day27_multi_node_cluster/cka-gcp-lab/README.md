## Multi-Node Kubernetes Cluster

Before Terraform can create resources on Google Cloud Platform (GCP), the required GCP APIs must be enabled. Terraform creates the following infrastructure for this lab:

- VPC
- Subnet
- Firewall rules
- VM instances

This project sets up a multi-node Kubernetes cluster using `kubeadm`.

## Setup Workflow

### 1. Enable the GCP project API

Enable the Google Cloud APIs required by the lab in the target GCP project before running Terraform.

### 2. Create the Terraform workstation

The Terraform workstation is organized as a small working directory containing the configuration files for the lab:

```text
cka-gcp-lab/
├── firewall.tf
├── instances.tf
├── network.tf
├── outputs.tf
├── provider.tf
├── variables.tf
└── terraform.tfvars        # local values; not committed
```

Terraform loads all `.tf` files in this directory as one configuration. The `terraform.tfvars` file supplies local values such as the GCP project ID, region, zone, and allowed SSH source ranges.

### 3. Authenticate Terraform to Google Cloud

Authenticate the Google Cloud CLI and create Application Default Credentials so the Terraform Google provider can access the project:

```bash
gcloud auth login
gcloud auth application-default login
```

Terraform uses these credentials through the Google provider defined in `provider.tf`. Confirm that the authenticated account has permission to create the required VPC, firewall, and Compute Engine resources.

### 4. Connect to the VMs with SSH

The VMs have ephemeral external IP addresses. List the current addresses before connecting:

```bash
gcloud compute instances list \
	--project cka-kubernetes-lab-508720 \
	--format="table(name,zone,status,networkInterfaces[0].accessConfigs[0].natIP)"
```

For direct SSH, the public IP address of the local network must be included in `ssh_source_ranges` in `terraform.tfvars`. Use `/32` for one public IPv4 address, then apply the change:

```hcl
ssh_source_ranges = [
	"YOUR_CURRENT_PUBLIC_IP/32"
]
```

```bash
terraform apply
gcloud compute ssh cka-master \
	--zone us-east1-b \
	--project cka-kubernetes-lab-508720
```

#### SSH troubleshooting by local network

The allowed source address depends on where the SSH client is connected:

| Local network | What to check |
| --- | --- |
| Home network | Check the current public IP and update `ssh_source_ranges` if the ISP address changed. |
| Office or school network | The network may block outbound TCP port 22. Test with `Test-NetConnection VM_EXTERNAL_IP -Port 22` on Windows or `nc -vz VM_EXTERNAL_IP 22` on Linux/macOS. |
| VPN | The VM may see the VPN gateway's public IP rather than the local ISP address. Add the observed public IP, or disconnect the VPN for testing. |
| Mobile hotspot | The carrier address may change frequently or use carrier-grade NAT. Refresh the public IP allowlist after reconnecting. |

If port 22 is blocked by the local network, use Identity-Aware Proxy (IAP), which tunnels SSH over HTTPS. Allow the IAP TCP range in the SSH firewall rule:

```hcl
ssh_source_ranges = [
	"YOUR_CURRENT_PUBLIC_IP/32",
	"35.235.240.0/20"
]
```

Apply the firewall change and connect through IAP:

```bash
terraform apply
gcloud compute ssh cka-master \
	--zone us-east1-b \
	--project cka-kubernetes-lab-508720 \
	--tunnel-through-iap
```

The user connecting through IAP needs permission to use IAP tunneling, such as `roles/iap.tunnelResourceAccessor`, and permission to access the VM. If direct SSH times out but HTTPS works and the same timeout occurs for every VM, IAP is usually the appropriate connection method.

### 5. Initialize the control plane

Run on `cka-master`, as root (`kubeadm` fails preflight checks under a non-root user, so use `sudo`):

```bash
sudo kubeadm init --pod-network-cidr=192.168.0.0/16
```

Set up `kubectl` access for the current user:

```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

Install a pod network add-on so nodes reach `Ready` (Calico, matching the CIDR above):

```bash
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.32.1/manifests/tigera-operator.yaml
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.32.1/manifests/custom-resources.yaml
```

### 6. Join the worker nodes to the control plane

Run these steps after `kubeadm init` has completed on `cka-master`. First, generate a fresh join command on the control plane:

```bash
# Run on cka-master
sudo kubeadm token create --print-join-command
```

Copy the complete command that is printed. It already contains the control plane's current internal IP, since `kubeadm token create --print-join-command` reads it live from the cluster.

The master's internal IP changes on every Terraform redeploy — do not assume it stays `10.10.0.2`. To look it up separately (e.g., for the reachability check below), use:

```bash
terraform output master_internal_ip
# or
gcloud compute instances describe cka-master \
	--zone us-east1-b \
	--project cka-kubernetes-lab-508720 \
	--format="get(networkInterfaces[0].networkIP)"
```

On each worker, verify that the Kubernetes API server is reachable, substituting the current master internal IP:

```bash
# Run on cka-worker-1 and repeat on cka-worker-2
nc -vz <master_internal_ip> 6443
```

If the worker was previously initialized or a join attempt failed, reset its old state first:

```bash
# Run on the worker being joined
sudo kubeadm reset -f
sudo rm -rf /etc/cni/net.d/* /var/lib/cni/*
sudo systemctl restart containerd
```

Run the generated command as root on `cka-worker-1`, then repeat the same process for `cka-worker-2`. Use the exact command printed by `kubeadm token create --print-join-command` — the IP, token, and hash below are illustrative only and will differ on every redeploy:

```bash
# Run on each worker, using the command generated on cka-master
sudo kubeadm join <master_internal_ip>:6443 \
	--token <token> \
	--discovery-token-ca-cert-hash sha256:<hash>
```

Do not run `kubeadm token create` on a worker. It requires the control-plane kubeconfig and must be run on `cka-master`. Do not use `--ignore-preflight-errors` to bypass existing kubelet or CA files; reset the worker when those files indicate stale cluster state.

Verify the cluster from the control plane:

```bash
# Run on cka-master
kubectl get nodes -o wide
```

### 7. (Optional) Copy admin.conf to the worker nodes for kubectl access

Worker nodes don't need `kubectl` configured at all — only `cka-master` runs the API server, and `kubeadm join` alone is enough for a worker to function. Only do this if you want `kubectl` to work directly from a worker for convenience.

Do **not** use `/etc/kubernetes/kubelet.conf` for this. It embeds paths to the kubelet's own client cert/key (`/var/lib/kubelet/pki/kubelet-client-current.pem`), which is root-only (`0600`) and scoped to the restrictive `system:node:<name>` identity — `kubectl` will fail with permission or authorization errors. Use `/etc/kubernetes/admin.conf` from the control plane instead.

On `cka-master`, print the admin kubeconfig:

```bash
sudo cat /etc/kubernetes/admin.conf
```

Copy the entire output (from `apiVersion` through the final `users:` block).

On the worker node, make sure `~/.kube` is a directory, not a leftover file from an earlier mistake:

```bash
ls -la $HOME/.kube
# if it shows as a regular file (starts with "-"), remove it first:
rm -f $HOME/.kube
mkdir -p $HOME/.kube
```

Paste the copied content into a new config file:

```bash
vim $HOME/.kube/config
# paste, then save with Ctrl+O, Enter, and exit with Ctrl+X
```

Confirm it uses embedded credential data, not file paths to the kubelet's cert:

```bash
grep -A2 "client-certificate\|client-key" $HOME/.kube/config
# expect: client-certificate-data / client-key-data (base64 blobs)
```

Lock down permissions and verify:

```bash
chmod 600 $HOME/.kube/config
kubectl get nodes
```

If SSH between nodes only allows key-based auth (no password), `scp`-ing `admin.conf` directly will fail with `Permission denied (publickey)`. The manual copy/paste above avoids that entirely; set up SSH keys between nodes separately if you want to automate this step later.

### 8. Upgrade the cluster (fixing a version mismatch)

Symptom: `tigera-operator` is in `CrashLoopBackOff` and its previous logs (`kubectl logs -n tigera-operator <pod> --previous`) show the API server rejecting a Calico CRD:

```text
failed to create CustomResourceDefinition clusternetworkpolicies.policy.networking.k8s.io ... undeclared reference to 'isCIDR'
```

Cause: the Tigera operator installs CRDs that use CEL functions the API server doesn't have. Here the operator was `v1.42.3` and the API server was `v1.29.15`. Calico 3.30 is tested with Kubernetes 1.31-1.35, so upgrade the cluster with `kubeadm`.

Rules:

- Upgrade **one minor version at a time** (1.29 → 1.30 → 1.31 → ...). Skipping minors is unsupported.
- Order: control plane first, then each worker one at a time.
- Do **not** run `kubeadm reset` or delete CNI config for an upgrade; that tears the cluster down.
- Repeat the whole procedure for every hop. The examples below use 1.30; change the minor each time.
- Back up the VMs/etcd first. A single control-plane node has a brief API outage during the upgrade.

#### 8.1 Point apt at the target minor (every node)

Edit the existing source instead of adding a duplicate, then find the exact patch version (the examples use `1.30.14`; use what `apt-cache` shows):

```bash
sudo sed -i 's#/core:/stable:/v1\.[0-9]*/#/core:/stable:/v1.30/#' /etc/apt/sources.list.d/kubernetes.list
cat /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
apt-cache madison kubeadm | head
```

`1.30.Z-*` is a placeholder and fails with `Version '1.30.Z-*' was not found`. Use the real patch.

#### 8.2 Upgrade the control plane (`cka-master`)

Upgrade `kubeadm` first, then apply the upgrade, **then** upgrade `kubelet` and `kubectl`:

```bash
sudo apt-mark unhold kubeadm
sudo apt-get install -y kubeadm='1.30.14-*'
sudo apt-mark hold kubeadm
kubeadm version -o short

sudo kubeadm upgrade plan
sudo kubeadm upgrade apply v1.30.14
```

If `upgrade plan`/`apply` fails with `[ERROR CreateJob]: Job "upgrade-health-check-..." did not complete in 15s`, the health-check pod can't start because pod networking (Calico) is broken. In this lab that is the known problem, so bypass only that check:

```bash
sudo kubeadm upgrade apply v1.30.14 --ignore-preflight-errors=CreateJob
```

Then upgrade the kubelet and kubectl:

```bash
sudo apt-mark unhold kubelet kubectl
sudo apt-get install -y kubelet='1.30.14-*' kubectl='1.30.14-*'
sudo apt-mark hold kubelet kubectl
sudo systemctl daemon-reload
sudo systemctl restart kubelet
```

Verify the control plane version:

```bash
kubectl get nodes
kubectl get pod -n kube-system -l component=kube-apiserver -o jsonpath='{.items[*].spec.containers[0].image}{"\n"}'
```

Notes from the lab:

- A drain of the master hung on `coredns` because the CNI was broken. It isn't required for a lab control plane; if used, add `--timeout=120s`.
- After the upgrade, `kubectl` returned `Forbidden` (`User "kubernetes-admin" cannot list resource "nodes"`) because `~/.kube/config` was a stale copy of `admin.conf`. Refresh it:

  ```bash
  sudo cp /etc/kubernetes/admin.conf ~/.kube/config
  sudo chown $(id -u):$(id -g) ~/.kube/config
  ```

- Clean up leftover health-check jobs if any: `kubectl get jobs -n kube-system`, then delete each `upgrade-health-check-*` job.
- A "Pending kernel upgrade" notice from apt can wait; reboot once the cluster is stable.

#### 8.3 Upgrade each worker (`cka-worker-1`, then `cka-worker-2`)

Do one worker completely before starting the next. Drain from a node with working `kubectl`:

```bash
kubectl drain cka-worker-1.us-east1-b.c.cka-kubernetes-lab-508720.internal \
	--ignore-daemonsets --delete-emptydir-data --timeout=120s
```

With a broken CNI the drain can time out on `coredns` and leftover `upgrade-health-check-*` pods. The node stays cordoned and it is safe to continue.

On the worker, point apt at the target minor (step 8.1), then:

```bash
sudo apt-mark unhold kubeadm
sudo apt-get install -y kubeadm='1.30.14-*'
sudo apt-mark hold kubeadm
sudo kubeadm upgrade node

sudo apt-mark unhold kubelet kubectl
sudo apt-get install -y kubelet='1.30.14-*' kubectl='1.30.14-*'
sudo apt-mark hold kubelet kubectl
sudo systemctl daemon-reload
sudo systemctl restart kubelet
```

Back on a node with `kubectl`, uncordon and verify:

```bash
kubectl uncordon cka-worker-1.us-east1-b.c.cka-kubernetes-lab-508720.internal
kubectl get nodes
```

Repeat for `cka-worker-2.us-east1-b.c.cka-kubernetes-lab-508720.internal`.

#### 8.4 Move to the next minor and verify Calico

Do not start the next hop until all three nodes are `Ready` and on the same version. Repeat 8.1-8.3 for 1.31, 1.32, and so on up to the target (1.35 for Calico 3.30). Once the API server supports the operator's CRDs (1.31 or later), confirm it recovers:

```bash
kubectl get nodes
kubectl get pods -A
kubectl get tigerastatus
kubectl logs -n tigera-operator deploy/tigera-operator --tail=100
```

If the operator still crashes, read the new error rather than resetting the cluster.

## Kubernetes Control-Plane Firewall Rules

When creating the Kubernetes control plane with `kubeadm`, the following TCP ports must be available to the control-plane components. The `kubernetes_control_plane` firewall rule allows these ports from the cluster subnet and targets instances tagged `cka-master`.

| Port | Purpose |
| --- | --- |
| 6443 | Kubernetes API server |
| 2379-2380 | etcd |
| 10250 | kubelet |
| 10257 | kube-controller-manager |
| 10259 | kube-scheduler |
