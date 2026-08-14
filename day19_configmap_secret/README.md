# ConfigMaps and Secrets

ConfigMaps store non-sensitive application configuration. Secrets store sensitive values such as passwords, tokens, and certificates. Both resources let a pod receive configuration without baking it into the container image.

> A Secret is base64-encoded in its YAML, not encrypted merely because it is base64. Protect Secret manifests, restrict access with RBAC, and enable encryption at rest for the cluster where appropriate.

## ConfigMaps

The repository includes [cm.yaml](cm.yaml), which creates an `app-cm` ConfigMap, and [pod.yaml](pod.yaml), which reads `first_name` from that ConfigMap.

### Imperative creation

Create a ConfigMap from literal key/value pairs:

```bash
kubectl create configmap app-cm \
	--from-literal=first_name=john \
	--from-literal=lastname=gillon
```

Generate the equivalent declarative YAML without creating it yet:

```bash
kubectl create configmap app-cm \
	--from-literal=first_name=john \
	--from-literal=lastname=gillon \
	--dry-run=client -o yaml > cm.yaml
```

Create from files instead when configuration is maintained outside the command line:

```bash
kubectl create configmap app-settings --from-file=application.properties
kubectl create configmap web-content --from-file=./config/
```

### Declarative creation

Define the desired resource in YAML, then apply it:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
	name: app-cm
data:
	first_name: john
	lastname: gillon
```

```bash
kubectl apply -f cm.yaml
```

Use declarative manifests for configuration that should be version-controlled and reproducible. Imperative commands are convenient for exploration, quick tests, and generating a starting manifest.

### Provide ConfigMap values to a pod

Create the ConfigMap before creating the pod:

```bash
kubectl apply -f cm.yaml
kubectl apply -f pod.yaml
```

Use one ConfigMap key as an environment variable, as in [pod.yaml](pod.yaml):

```yaml
env:
	- name: FIRSTNAME
		valueFrom:
			configMapKeyRef:
				name: app-cm
				key: first_name
```

Import every key as an environment variable:

```yaml
envFrom:
	- configMapRef:
			name: app-cm
```

Mount all ConfigMap keys as files in a directory:

```yaml
containers:
	- name: app
		image: nginx:1.27
		volumeMounts:
			- name: app-config
				mountPath: /etc/app-config
				readOnly: true
volumes:
	- name: app-config
		configMap:
			name: app-cm
```

For mounted ConfigMaps, Kubernetes can update the files after the ConfigMap changes. Environment variables do not update in a running container; restart or redeploy the pod to use new values.

## Secrets

Secrets use the same pod-consumption patterns as ConfigMaps, but should hold sensitive data. Do not commit real production values to Git.

### Imperative creation

Create an opaque Secret from literals:

```bash
kubectl create secret generic app-secret \
	--from-literal=username=jamie \
	--from-literal=password='change-me'
```

Create a TLS Secret from an existing certificate and private key:

```bash
kubectl create secret tls website-tls \
	--cert=tls.crt \
	--key=tls.key
```

Generate a Secret manifest for review or controlled deployment:

```bash
kubectl create secret generic app-secret \
	--from-literal=username=jamie \
	--from-literal=password='change-me' \
	--dry-run=client -o yaml > secret.yaml
```

### Declarative creation

`stringData` accepts ordinary strings and is convenient for authored YAML. Kubernetes converts it to `data` when the Secret is stored.

```yaml
apiVersion: v1
kind: Secret
metadata:
	name: app-secret
type: Opaque
stringData:
	username: jamie
	password: change-me
```

Apply the manifest:

```bash
kubectl apply -f secret.yaml
```

For `data`, values must be base64-encoded. On Git Bash, for example:

```bash
printf %s 'change-me' | base64
```

```yaml
data:
	password: Y2hhbmdlLW1l
```

### Provide Secret values to a pod

Read one Secret key into an environment variable:

```yaml
env:
	- name: APP_PASSWORD
		valueFrom:
			secretKeyRef:
				name: app-secret
				key: password
```

Import all keys as environment variables:

```yaml
envFrom:
	- secretRef:
			name: app-secret
```

Mount Secret keys as files:

```yaml
containers:
	- name: app
		image: nginx:1.27
		volumeMounts:
			- name: credentials
				mountPath: /var/run/credentials
				readOnly: true
volumes:
	- name: credentials
		secret:
			secretName: app-secret
```

## Verify and clean up

```bash
kubectl get configmap app-cm -o yaml
kubectl get secret app-secret
kubectl describe pod myapp-container-pod
kubectl exec myapp-container-pod -- printenv FIRSTNAME
```

Delete the sample resources when finished:

```bash
kubectl delete -f pod.yaml
kubectl delete -f cm.yaml
kubectl delete secret app-secret
```
