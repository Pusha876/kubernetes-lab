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

## Kubernetes Control-Plane Firewall Rules

When creating the Kubernetes control plane with `kubeadm`, the following TCP ports must be available to the control-plane components. The `kubernetes_control_plane` firewall rule allows these ports from the cluster subnet and targets instances tagged `cka-master`.

| Port | Purpose |
| --- | --- |
| 6443 | Kubernetes API server |
| 2379-2380 | etcd |
| 10250 | kubelet |
| 10257 | kube-controller-manager |
| 10259 | kube-scheduler |
