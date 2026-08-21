# Deployment Control Script Design

## Goal

Add one `deploy/ctl` shell script for routine deployment operations and local OpenMU image rebuilds across supported `aio` and `traefik` deployments. Load the all-in-one advertised server IP and Web UI host port from its `.env` file.

## Interface

```bash
./deploy/ctl <deployment> <action>
```

Deployments:

- `aio`: Compose files in `deploy/all-in-one`.
- `traefik`: production Compose file in `deploy/all-in-one-traefik`.

Actions:

- `pull`: pull configured images.
- `build`: build local OpenMU image from `src/Startup/Dockerfile`.
- `deploy`: pull images, then recreate services in detached mode.
- `rebuild`: build local OpenMU image, then recreate services without pulling OpenMU.
- `restart`: restart existing services.
- `down`: stop and remove containers and networks created by Compose, preserving named volumes.
- `logs`: follow service logs.
- `status`: show Compose service status.

Invalid or missing arguments print usage and exit nonzero.

## Compose Selection

`aio` commands run from `deploy/all-in-one` with explicit Compose files so `docker-compose.override.yml` cannot silently enable its development build:

```bash
docker compose --env-file .env -f docker-compose.yml ...
```

`traefik` commands run from `deploy/all-in-one-traefik`:

```bash
docker compose -f docker-compose.prod.yml ...
```

## Local Image Build

Both deployments reference `munique/openmu`. Local builds use repository source directly and replace that tag:

```bash
docker build -t munique/openmu -f src/Startup/Dockerfile src
```

`rebuild` runs this build before `docker compose up -d --no-build --remove-orphans`. Database volumes remain untouched.

## All-in-one Configuration

`deploy/all-in-one/.env` defines `RESOLVE_IP` and `HTTP_PORT`. Compose passes `RESOLVE_IP` to OpenMU and publishes nginx on `HTTP_PORT`. Both values are required; `.env.example` provides the local defaults. The real `.env` remains untracked.

## Validation

Before action execution, script verifies:

- `docker` command exists.
- Docker Compose plugin responds.
- Deployment and action are supported.
- `deploy/all-in-one/.env` exists for all-in-one Compose actions.
- `traefik` external `proxy` network exists for actions that start services.
- `deploy/all-in-one-traefik/.env` exists for Traefik deployment actions.

Errors identify missing prerequisite and return nonzero. Script never creates production configuration implicitly.

## Safety

- No `docker compose down -v` support.
- No automatic image pruning.
- No Git operations.
- No distributed deployment support because repository marks it broken and unsupported.
- Commands fail immediately on errors.

## Verification

Add `deploy/test-ctl.sh`, using temporary fake `docker` executable to assert command construction, `.env` loading and validation failures, and absence of volume deletion. Test uses POSIX shell tools only and does not contact Docker.
