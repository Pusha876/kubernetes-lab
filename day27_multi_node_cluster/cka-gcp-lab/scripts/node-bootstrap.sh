#!/usr/bin/env bash
set -euo pipefail

# Wipe any kubeadm/cluster state baked into the golden image so redeployed
# nodes always boot clean and ready for a fresh `kubeadm init` / `kubeadm join`.
if [ -f /etc/kubernetes/admin.conf ] || [ -f /etc/kubernetes/kubelet.conf ]; then
  kubeadm reset -f --cri-socket unix:///var/run/containerd/containerd.sock || true
  rm -rf /etc/kubernetes /var/lib/etcd
  rm -rf /home/*/.kube /root/.kube
fi
