#To generate a key file
openssl genrsa -out adam.key 2048
#To generate a csr file
openssl req -new -key adam.key -out adam.csr -subj "/CN=adam"
# Kubernetes Certificate Signing Requests

This guide creates a client certificate request for a user named `adam`, submits it to Kubernetes, approves or denies it, and gives the signed certificate to the user.

## Prerequisites

- `kubectl` is configured for a reachable Kubernetes cluster.
- You have permission to create and approve `CertificateSigningRequest` resources.
- `openssl` is installed.

Check that the cluster is available before continuing:

```bash
kubectl cluster-info
```

## 1. Create the user's private key

Create the key locally and protect it. It is the user's secret and must not be committed to source control or sent to the cluster.

```bash
openssl genrsa -out adam.key 2048
```

## 2. Create a certificate signing request

```bash
MSYS_NO_PATHCONV=1 openssl req -new -key adam.key -out adam.csr -subj "/CN=adam"
```

`MSYS_NO_PATHCONV=1` is needed in Git Bash on Windows so Git Bash does not convert `/CN=adam` into a Windows path. It is not normally required on Linux, macOS, or PowerShell.

Confirm the subject in the request:

```bash
openssl req -in adam.csr -noout -subject
```

## 3. Encode the request and create the Kubernetes resource

Encode the CSR into one base64 line:

```bash
cat adam.csr | base64 | tr -d "\n"
```

Copy the output into `spec.request` in `csr.yaml`. The complete manifest should have this structure:

```yaml
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
	name: adam
spec:
	request: <base64-encoded-content-of-adam.csr>
	signerName: kubernetes.io/kube-apiserver-client
	expirationSeconds: 86400
	usages:
		- client auth
```

Optionally validate the manifest locally:

```bash
kubectl apply --dry-run=client --validate=false -f csr.yaml
```

Submit the request:

```bash
kubectl apply -f csr.yaml
kubectl get csr
```

## 4. Approve or deny the request

An authorized cluster administrator reviews the request before approving it:

```bash
kubectl describe csr adam
kubectl certificate approve adam
```

To deny a request instead, run:

```bash
kubectl certificate deny adam
```

Check its status:

```bash
kubectl get csr adam
```

After approval, wait until the `CONDITION` column includes `Approved,Issued`.

## 5. Give the signed certificate to the user

Extract the issued certificate from the approved CSR:

```bash
kubectl get csr adam -o jsonpath='{.status.certificate}' | base64 --decode > adam.crt
```

Verify it:

```bash
openssl x509 -in adam.crt -noout -subject -issuer -dates
```

Share `adam.crt` with the user through an approved secure channel. The user must retain `adam.key`; do not send the private key to Kubernetes, commit it to Git, or share it unnecessarily.

The user can authenticate with the certificate and their private key by configuring a kubeconfig file that points to the cluster, `adam.crt`, and `adam.key`.