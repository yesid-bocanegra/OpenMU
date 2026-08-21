# Deployment Control Script Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add one tested shell command for pulling, building, and operating supported OpenMU Compose deployments, with all-in-one endpoint configuration loaded from `.env`.

**Architecture:** `deploy/ctl` validates two positional arguments, selects explicit Compose files, and delegates to Docker. `deploy/test-ctl.sh` injects a fake `docker` command and verifies emitted invocations without requiring Docker.

**Tech Stack:** POSIX shell utilities, Bash, Docker CLI, Docker Compose plugin.

---

### Task 1: Command Contract Tests

**Files:**
- Create: `deploy/test-ctl.sh`

- [ ] Write fake-Docker tests for usage, `aio deploy`, `aio rebuild`, `traefik deploy`, safe `down`, `.env` loading, and validation failures.
- [ ] Run `bash deploy/test-ctl.sh` and confirm failure because `deploy/ctl` does not exist.

### Task 2: Deployment Controller

**Files:**
- Create: `deploy/ctl`

- [ ] Add strict Bash execution and usage validation.
- [ ] Select explicit Compose directory and files for `aio` or `traefik`.
- [ ] Add Docker and Compose prerequisite checks.
- [ ] Require and load `deploy/all-in-one/.env` for all-in-one Compose actions.
- [ ] Add Traefik `.env` and `proxy` network checks for start actions.
- [ ] Map `pull`, `build`, `deploy`, `rebuild`, `restart`, `down`, `logs`, and `status` to minimal Docker commands.
- [ ] Run `bash deploy/test-ctl.sh` and confirm all assertions pass.

### Task 3: All-in-one Endpoint Configuration

**Files:**
- Create: `deploy/all-in-one/.env.example`
- Create: `deploy/all-in-one/.gitignore`
- Modify: `deploy/all-in-one/docker-compose.yml`

- [ ] Require `HTTP_PORT` for the nginx host port.
- [ ] Pass required `RESOLVE_IP` to OpenMU.
- [ ] Document the `.env` setup and keep the local file untracked.

### Task 4: Verification

**Files:**
- Verify: `deploy/ctl`
- Verify: `deploy/test-ctl.sh`

- [ ] Run `bash -n deploy/ctl deploy/test-ctl.sh`.
- [ ] Run `bash deploy/test-ctl.sh`.
- [ ] Run `git diff --check`.
- [ ] Review diff against design safety requirements.
