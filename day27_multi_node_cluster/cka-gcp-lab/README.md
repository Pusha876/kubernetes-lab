## Multi-Node Kubernetes Cluster

Before Terraform can create resources on Google Cloud Platform (GCP), the required GCP APIs must be enabled. Terraform creates the following infrastructure for this lab:

- VPC
- Subnet
- Firewall rules
- VM instances

This project sets up a multi-node Kubernetes cluster using `kubeadm`.
