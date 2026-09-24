```text
				         GCP VPC
			           10.10.0.0/24
				            │
	       ┌────────────────┼────────────────┐
	       │                │                │
	       ▼                ▼                ▼
     ┌───────────┐    ┌───────────┐    ┌───────────┐
     │   MASTER  │    │  WORKER 1 │    │  WORKER 2 │
     │           │    │           │    │           │
     │ API       │    │ kubelet   │    │ kubelet   │
     │ etcd      │    │ containerd│    │ containerd│
     │ scheduler │    │ Calico    │    │ Calico    │
     │ controller│    │           │    │           │
     │ kubelet   │    │           │    │           │
     │ containerd│    │           │    │           │
     │ Calico    │    │           │    │           │
     └───────────┘    └───────────┘    └───────────┘
	       │                │                │
	       └────────────────┼────────────────┘
				            │
			           Pod Network
			          192.168.0.0/16
```
