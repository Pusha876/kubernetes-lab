# Day 09 - Kubernetes Services (NodePort)

This note captures the exact NodePort flow we practiced, including fixes and validation steps.

## Prerequisite (kind cluster port mapping)

For local access from host to NodePort on kind, map the host port in `kind.yaml`:

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
	extraPortMappings:
	- containerPort: 30007
		hostPort: 30007
- role: worker
- role: worker
```

If you change this file, recreate the cluster for the mapping to take effect.

## 1) Deploy nginx workload

```bash
kubectl apply -f rc-deploy.yaml
```

Important: `kubectl apply` must use `-f`.

## 2) Create NodePort service

```bash
kubectl apply -f nodeport.yaml
```

Working service configuration used in this lab:

```yaml
apiVersion: v1
kind: Service
metadata:
	name: nodeport-svc
	labels:
		env: demo
spec:
	type: NodePort
	selector:
		env: demo
	ports:
		- protocol: TCP
			port: 80
			targetPort: 80
			nodePort: 30007
```

## 3) Verify objects

```bash
kubectl get pods --show-labels
kubectl get svc nodeport-svc -o wide
kubectl get endpoints nodeport-svc -o wide
```

Expected:
- Pods are `Running`
- Service shows `80:30007/TCP`
- Endpoints list pod IPs with `:80`

## 4) Test service

From host:

```bash
curl http://localhost:30007
```

Should return nginx welcome HTML.

If host curl fails, test from inside cluster:

```bash
kubectl run tmp-curl --image=curlimages/curl:8.10.1 --restart=Never --rm -i --command -- curl -I http://nodeport-svc
```

If this returns `HTTP/1.1 200 OK`, service routing is correct and host access issue is usually port mapping/network.

## 5) Troubleshooting we fixed

### Problem A: apply command error

Error:

```text
error: Unexpected args: [rc-deploy.yaml]
```

Fix:

```bash
kubectl apply -f rc-deploy.yaml
```

### Problem B: Empty reply from server

Root causes we corrected:
- Service selector had extra label `app: nodeport-app` that pods did not have.
- Service `targetPort` was `8080`, but nginx listens on `80`.

Fix summary:
- Keep selector as `env: demo`
- Set `targetPort: 80`

## Alias setup for kubectl

### Temporary alias (current shell only)

```bash
alias k='kubectl'
```

Use it:

```bash
k get pods
k get svc
```

### Persistent alias (Git Bash)

Add to `~/.bashrc`:

```bash
echo "alias k='kubectl'" >> ~/.bashrc
source ~/.bashrc
```

Verify:

```bash
alias | grep "alias k="
```

Optional helpful aliases:

```bash
echo "alias kgp='kubectl get pods'" >> ~/.bashrc
echo "alias kgs='kubectl get svc'" >> ~/.bashrc
source ~/.bashrc
```

## 6) Create a ClusterIP service

`ClusterIP` is the default service type and is reachable only inside the cluster.

Create using an imperative command:

```bash
# Create a service for a replicated nginx, which serves on port 80 and connects to the containers on port 8000
kubectl expose rc nginx --port=80 --target-port=8000
```

Optional explicit type form:

```bash
kubectl expose rc nginx --port=80 --target-port=8000 --type=ClusterIP
```

Verify:

```bash
kubectl get svc nginx
kubectl describe svc nginx
kubectl explain service.spec.type
kubectl explain service.spec.clusterIP
```

Test from inside cluster:

```bash
kubectl run tmp-curl --image=curlimages/curl:8.10.1 --restart=Never --rm -i --command -- curl -I http://nginx
```

## 7) Create a LoadBalancer service

`LoadBalancer` is used to expose a service externally through cloud provider integration.

Create with imperative command:

```bash
kubectl expose deploy nginx-deploy --port=80 --target-port=80 --type=LoadBalancer --name=nginx-lb
```

Equivalent YAML:

```yaml
apiVersion: v1
kind: Service
metadata:
	name: nginx-lb
spec:
	type: LoadBalancer
	selector:
		env: demo
	ports:
		- port: 80
			targetPort: 80
```

Verify:

```bash
kubectl get svc nginx-lb -o wide
kubectl describe svc nginx-lb
```

Note for local clusters (`kind`, `minikube`, `docker-desktop`):
- `EXTERNAL-IP` may stay `<pending>` unless you install a local load balancer solution.
- For local practice, `NodePort` is usually the easiest external access method.
