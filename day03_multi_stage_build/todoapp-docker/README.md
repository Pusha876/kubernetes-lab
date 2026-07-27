# A sample todo app in react

## Multi-stage Docker build

This project uses a multi-stage Dockerfile to create a smaller production image.

### Dockerfile stages

1. `installer` stage (`node:18-alpine`)
- Installs npm dependencies
- Builds the React app using `npm run build`

2. `deployer` stage (`nginx:latest`)
- Copies only the built static files from `/app/build`
- Serves them with Nginx from `/usr/share/nginx/html`

This keeps development dependencies and Node build tooling out of the final runtime image.

## Build and run

### 1. Build the image

Run from this folder (where the Dockerfile exists):

```bash
docker build -t todoapp-multistage .
```

### 2. Run the container

```bash
docker run --rm -p 3000:80 todoapp-multistage
```

Why `3000:80`?
- Nginx inside the container listens on port 80.
- Port 3000 is your local machine port.

### 3. Open the app

- http://localhost:3000

### 4. Stop the container

- Press `Ctrl + C` in the terminal running the container.

## Useful verification commands

### Check built images

```bash
docker images
```

### List running containers

```bash
docker ps
```

### View container logs

```bash
docker logs <container_id>
```

## Things to look out for

1. Running the wrong port mapping
- If you map `3000:3000`, the app will not load because Nginx serves on `80`.
- Use `-p 3000:80`.

2. Copy path mismatch in multi-stage copy
- Final stage must copy from the React build output path:
- `COPY --from=installer /app/build /usr/share/nginx/html`

3. Building from the wrong folder
- Make sure you run `docker build` in the folder that contains this Dockerfile.
