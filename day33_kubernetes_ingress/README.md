# Kubernetes Ingress on the GCP clusters

This example runs a small Flask app behind a Kubernetes `Service` and an
NGINX `Ingress`. An Ingress resource only defines HTTP routing; every cluster
you want to serve traffic from must also have an Ingress controller installed
and reachable.

## Prerequisites

- `kubectl` is connected to the intended cluster. In a multi-cluster setup,
  check `kubectl config current-context` and select the target with
  `kubectl config use-context <context-name>`. For GKE clusters whose
  credentials are not configured yet, use
  `gcloud container clusters get-credentials <cluster-name> --location <region-or-zone> --project <project-id>`.
- An NGINX Ingress controller is running in that cluster and provides the
  `nginx` IngressClass. Controller installation and external exposure depend
  on how the GCP cluster was provisioned.
- The image name in `Flask/k8s/deployment.yaml` points to an image available
  to the cluster.

An Ingress is cluster-scoped routing configuration, not a multi-cluster
router. To serve this app from more than one cluster, configure credentials
for each cluster and repeat the deployment there. Each cluster needs its own
controller and reachable entry point.

## Build and deploy

From this directory, build and push the Flask image to a registry accessible
to your cluster:

```bash
docker build -t <registry>/<username>/hello-world:v1 ./Flask
docker push <registry>/<username>/hello-world:v1
```

Update the `image` value in
[`Flask/k8s/deployment.yaml`](./Flask/k8s/deployment.yaml) to that image. Then
confirm the selected cluster and apply the Deployment, Service, and Ingress:

```bash
kubectl config current-context
kubectl get nodes
kubectl apply -f Flask/k8s/deployment.yaml
kubectl apply -f Flask/k8s/service.yaml
kubectl apply -f Flask/k8s/ingress.yaml
kubectl rollout status deployment/hello-world
```

The Ingress routes HTTP requests for `example.com` at `/` to the `hello-world`
Service on port 80. Change the `host` in
[`Flask/k8s/ingress.yaml`](./Flask/k8s/ingress.yaml) if you want to use a
different hostname.

## Test the route

First verify the app and Ingress resources:

```bash
kubectl get pods,svc,ingress
kubectl get ingressclass nginx
```

For a quick test from your workstation, port-forward the NGINX controller
(leave this running in one terminal):

```bash
kubectl port-forward -n ingress-nginx service/ingress-nginx-controller 8080:80
```

In another terminal, send a request with the hostname configured in the
Ingress. In PowerShell, use `curl.exe` to avoid the `curl` alias:

```powershell
curl.exe -H "Host: example.com" http://127.0.0.1:8080/
```

The expected response is `Hello, World!`. For an end-to-end external test,
point the hostname at the controller's reachable GCP address (or send the
matching `Host` header to that address), allow the required GCP firewall
traffic, and request `http://<hostname>/`. A `kubectl get ingress` address
may be blank when the controller is not exposed through a load balancer.

Repeat the context selection, deployment, and test for each cluster you want
to verify. Use a distinct hostname per cluster, or direct each test to that
cluster's controller address.

## Troubleshooting and cleanup

```bash
kubectl describe ingress hello-world
kubectl get pods -n ingress-nginx
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller
```

If the controller uses a different namespace or workload name, adjust the
controller commands accordingly. Remove the example from the current cluster
with:

```bash
kubectl delete -f Flask/k8s
```
