# Docker Volume Example

The application image uses Node.js 20 and installs production dependencies from
the existing npm lockfile:

```dockerfile
FROM node:20-alpine
RUN npm ci --omit=dev
```

Node.js 20 is required by the resolved dependencies, and `npm ci --omit=dev`
provides a reproducible production-only install from `package-lock.json`.

## Docker Volume Storage

To list all volumes:

```bash
docker volume ls
```

-
-
-
-

Docker Desktop stores Linux container data inside its WSL virtual disk, commonly under:

```text
%LOCALAPPDATA%\Docker\wsl\disk\
```

-
-
-
-

Those files are inside a `.vhdx` disk and should not be edited directly.

## Accessing Container Folders

The `todo` container mounts the `data_vol` volume at `/app`.

To view the folder from inside the container:

```bash
docker exec -it todo sh
ls -la /app
```

To copy a folder from the container to the local project directory:

```bash
docker cp todo:/app/<folder-name> ./<folder-name>
```

To inspect the named volume through a temporary container:

```bash
docker run --rm -it -v data_vol:/data alpine sh
ls -la /data
```

For direct access from the local machine, use a bind mount instead of a named volume:

```bash
docker run -v "$PWD/data:/app" ...
```
