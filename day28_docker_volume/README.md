# Docker Volume Example

The application image uses Node.js 20 and installs production dependencies from
the existing npm lockfile:

```dockerfile
FROM node:20-alpine
RUN npm ci --omit=dev
```

Node.js 20 is required by the resolved dependencies, and `npm ci --omit=dev`
provides a reproducible production-only install from `package-lock.json`.
