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

## Kubernetes Control-Plane Firewall Rules

When creating the Kubernetes control plane with `kubeadm`, the following TCP ports must be available to the control-plane components. The `kubernetes_control_plane` firewall rule allows these ports from the cluster subnet and targets instances tagged `cka-master`.

| Port | Purpose |
| --- | --- |
| 6443 | Kubernetes API server |
| 2379-2380 | etcd |
| 10250 | kubelet |
| 10257 | kube-controller-manager |
| 10259 | kube-scheduler |
