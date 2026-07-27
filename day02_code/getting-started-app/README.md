# Getting started

This repository is a sample application for users following the getting started guide at https://docs.docker.com/get-started/.

The application is based on the application from the getting started tutorial at https://github.com/docker/getting-started

## Dockerize this project (simple container)

This app can be packaged as a single Node.js container and run locally.

### Prerequisites

- Docker Desktop (or Docker Engine) installed and running

### 1. Build the image

From the project root (same folder as `Dockerfile`):

```bash
docker build -t day02-todo .
```

### 2. Run the container

```bash
docker run --rm -p 3000:3000 day02-todo
```

Then open:

- http://localhost:3000

### 3. Stop the container

Use `Ctrl + C` in the terminal where the container is running.

## Common mistakes and corrections from this project

These are the exact issues we hit while dockerizing this app.

### Mistake 1: Invalid exposed port

- Problem: `EXPOSE 300026`
- Why it fails: Docker only accepts valid container ports in the range 1-65535.
- Correction: `EXPOSE 3000`
- How we verified: App code listens on port 3000, so exposed port should match.

### Mistake 2: Using Yarn when Yarn is not installed in the base image

- Problem: `RUN yarn install --production`
- Error: `/bin/sh: yarn: not found`
- Why it fails: The selected Node image did not include Yarn.
- Correction: Use npm with lockfile-based install:

```dockerfile
COPY package*.json ./
RUN npm ci --omit=dev
COPY . .
```

### Mistake 3: Copying everything before dependency install

- Problem: `COPY . .` before installing dependencies.
- Why it is not ideal: Any source code change invalidates dependency cache layers, causing slower rebuilds.
- Correction: Copy only `package*.json` first, install dependencies, then copy the rest of the app.

## Final Dockerfile used

```dockerfile
FROM node:26-alpine3.23
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev
COPY . .
CMD ["node", "src/index.js"]
EXPOSE 3000
```