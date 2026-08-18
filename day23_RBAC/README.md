# Role-Based Access Control (RBAC)

This lesson assigns the authenticated Kubernetes user `adam` permission to read Pods in the `default` namespace.

The exercise demonstrates the complete separation between authentication and authorization:

1. A client certificate authenticates `adam` to the Kubernetes API server.
2. A `Role` describes which actions are allowed.
3. A `RoleBinding` assigns that Role to the user `adam`.
4. `kubectl auth can-i` verifies the resulting access decisions.

## Files In This Folder

- [role.yaml](role.yaml): creates the namespace-scoped `pod-reader` Role.
- [binding.yaml](binding.yaml): binds `pod-reader` to the user `adam` in the `default` namespace.
- [adam.key](adam.key): private key used by `adam`. Treat this file as a secret.
- [adam.csr](adam.csr): certificate signing request generated for `CN=adam`.
- [adam.crt](adam.crt): signed client certificate issued for `adam`.
- [csr.yaml](csr.yaml): CertificateSigningRequest manifest used to issue the renewed certificate.
- [cert-public-key.pem](cert-public-key.pem) and [key-public-key.pem](key-public-key.pem): public-key comparison artifacts used to verify that the certificate and private key match.

The certificate files are copied from [day21_manage_tls_certificates](../day21_manage_tls_certificates/) so the authentication and RBAC exercises can be reviewed together. These are learning artifacts, not production credentials. Do not commit real private keys, tokens, or kubeconfig files to a shared repository.

## Prerequisites

- `kubectl` is installed and configured.
- You have an administrator context that can create and approve CertificateSigningRequest resources and apply RBAC objects.
- `openssl` is installed.
- The cluster is reachable.

Check the available contexts and cluster connection:

```bash
kubectl config get-contexts
kubectl cluster-info
```

## 1. Understand The RBAC Manifests

The Role in [role.yaml](role.yaml) grants these permissions in the `default` namespace:

```yaml
resources: ["pods"]
verbs: ["get", "watch", "list"]
```

It does not grant permission to create, update, or delete Pods, and it does not apply to other namespaces.

The RoleBinding in [binding.yaml](binding.yaml) connects the Role to this authenticated identity:

```yaml
subjects:
- kind: User
	name: adam
```

The `name` must match the username presented by the certificate. In this exercise, the certificate subject is `CN=adam`, so Kubernetes authenticates the user as `adam`.

## 2. Verify The Certificate Files

Before configuring `kubectl`, verify the file types and certificate identity:

```bash
head -n 1 adam.key adam.csr adam.crt
openssl req -in adam.csr -noout -subject
openssl x509 -in adam.crt -noout -subject -issuer -dates
```

Expected PEM headers are:

```text
adam.key: -----BEGIN PRIVATE KEY-----
adam.csr: -----BEGIN CERTIFICATE REQUEST-----
adam.crt: -----BEGIN CERTIFICATE-----
```

The CSR is only a request and cannot be used as a client certificate. The `.crt` file must contain the signed certificate returned in the Kubernetes CSR status.

Verify that the certificate was issued from the same key used to create the CSR:

```bash
openssl x509 -in adam.crt -pubkey -noout > cert-public-key.pem
openssl pkey -in adam.key -pubout > key-public-key.pem
diff -u cert-public-key.pem key-public-key.pem
```

No output from `diff` means the public keys match.

## 3. Configure The `adam` Kubeconfig User

Use an administrator context while creating or approving the certificate. The exact context name depends on the cluster:

```bash
kubectl config get-contexts
kubectl config use-context kind-cka-cluster3
```

Configure `adam` with the matching key and certificate. `--embed-certs=true` stores the certificate data in kubeconfig, avoiding fragile relative file paths:

```bash
kubectl config set-credentials adam \
	--client-key="$PWD/adam.key" \
	--client-certificate="$PWD/adam.crt" \
	--embed-certs=true
```

Create or select a context that uses the `adam` user and the cluster:

```bash
kubectl config set-context adam \
	--cluster=kind-cka-cluster3 \
	--user=adam \
	--namespace=default
kubectl config use-context adam
```

Confirm the authenticated identity:

```bash
kubectl auth whoami
```

Expected username:

```text
adam
```

## 4. Apply The RBAC Assignment

Switch back to the administrator context before applying the RBAC resources:

```bash
kubectl config use-context kind-cka-cluster3
kubectl apply -f role.yaml
kubectl apply -f binding.yaml
```

Inspect the resources:

```bash
kubectl get role pod-reader -n default
kubectl get rolebinding read-pods -n default
kubectl describe role pod-reader -n default
kubectl describe rolebinding read-pods -n default
```

## 5. Test `adam` Access

Switch to the `adam` context and test the permissions:

```bash
kubectl config use-context adam
kubectl auth whoami
kubectl auth can-i get pods -n default
kubectl auth can-i list pods -n default
kubectl auth can-i watch pods -n default
kubectl auth can-i delete pods -n default
kubectl auth can-i list pods -n kube-system
```

Expected results:

| Request | Expected result | Reason |
| --- | --- | --- |
| `get pods -n default` | `yes` | Granted by `pod-reader` |
| `list pods -n default` | `yes` | Granted by `pod-reader` |
| `watch pods -n default` | `yes` | Granted by `pod-reader` |
| `delete pods -n default` | `no` | `delete` is not granted |
| `list pods -n kube-system` | `no` | The Role is namespace-scoped |

You can also list all permissions visible to the current identity:

```bash
kubectl auth can-i --list
```

## Expired Certificates And Renewal

Client certificates have an expiration time. An expired certificate fails during authentication, before RBAC is evaluated. The error may appear as `Unauthorized`, even when the RoleBinding is correct.

Inspect the validity period:

```bash
openssl x509 -in adam.crt -noout -subject -issuer -dates
```

For example, a certificate with an `notAfter` date before the current date is expired. Renew it from an administrator context.

### Generate a new key and CSR

Generating a new key avoids accidentally pairing a renewed certificate with an old private key:

```bash
openssl genrsa -out adam.key 2048

MSYS_NO_PATHCONV=1 openssl req \
	-new \
	-key adam.key \
	-out adam.csr \
	-subj "/CN=adam"
```

`MSYS_NO_PATHCONV=1` prevents Git Bash on Windows from converting `/CN=adam` into a filesystem path.

### Encode and submit the CSR

The Kubernetes `spec.request` field must contain one base64-encoded line. It must not contain the PEM header or the literal placeholder text:

```bash
base64 adam.csr | tr -d '\r\n'
```

Copy that output into `spec.request` in [csr.yaml](csr.yaml). The manifest should use a unique name, such as `adam-renewal`, and include:

```yaml
metadata:
	name: adam-renewal
spec:
	request: <one-line-base64-encoded-csr>
	signerName: kubernetes.io/kube-apiserver-client
	expirationSeconds: 31536000
	usages:
		- client auth
```

Validate and submit it as an administrator:

```bash
kubectl apply --dry-run=client -f csr.yaml
kubectl apply -f csr.yaml
kubectl get csr adam-renewal
kubectl certificate approve adam-renewal
kubectl get csr adam-renewal
```

Wait until the condition includes `Approved,Issued`, then extract the signed certificate:

```bash
kubectl get csr adam-renewal \
	-o jsonpath='{.status.certificate}' |
	base64 --decode \
	> adam.crt
```

Verify the renewed certificate and key before updating kubeconfig:

```bash
openssl x509 -in adam.crt -noout -subject -issuer -dates
openssl x509 -in adam.crt -pubkey -noout > cert-public-key.pem
openssl pkey -in adam.key -pubout > key-public-key.pem
diff -u cert-public-key.pem key-public-key.pem
```

Update the embedded kubeconfig credentials and retry authentication:

```bash
kubectl config set-credentials adam \
	--client-key="$PWD/adam.key" \
	--client-certificate="$PWD/adam.crt" \
	--embed-certs=true
kubectl config use-context adam
kubectl auth whoami
```

Common certificate errors:

- `failed to find "CERTIFICATE" PEM block`: the configured `.crt` contains a CSR (`CERTIFICATE REQUEST`) instead of a signed certificate.
- `private key does not match public key`: the certificate was issued from a different private key. Generate a new key and issue a new certificate as a pair.
- `Unauthorized`: the certificate may be expired, invalid, signed by an untrusted CA, or not accepted by the API server. Check `openssl x509 ... -dates` and the certificate subject.
- `illegal base64 data at input byte 0`: `spec.request` contains a PEM block or placeholder text instead of base64-encoded CSR content.
- `NotFound` for `adam-renewal`: the CSR creation failed or the manifest uses a different `metadata.name`. Check the `apply` output and `kubectl get csr`.

## Cleanup

Remove the RBAC resources from the practice cluster when finished:

```bash
kubectl config use-context kind-cka-cluster3
kubectl delete -f binding.yaml
kubectl delete -f role.yaml
kubectl delete csr adam-renewal --ignore-not-found
```

Keep private key files out of source control. For a real cluster, use an approved secret-management and identity-management process instead of sharing these learning artifacts.
