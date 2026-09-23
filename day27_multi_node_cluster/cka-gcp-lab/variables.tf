variable "project_id" {
  description = "Google Cloud project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-east1"
}

variable "zone" {
  description = "GCP zone"
  type        = string
  default     = "us-east1-b"
}

variable "ssh_source_ranges" {
  description = "CIDR ranges allowed to SSH to the lab"
  type        = list(string)
}

variable "node_image_family" {
  description = "Custom image family with k8s prereqs (containerd, kubeadm, kubelet, kubectl, cni-plugins) baked in"
  type        = string
  default     = "cka-node"
}