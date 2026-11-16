#!/usr/bin/env bash
set -euo pipefail

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp_dir=$(mktemp -d)
test_root="$tmp_dir/repo"
ctl="$test_root/deploy/ctl"
aio_env_file="$test_root/deploy/all-in-one/.env"
traefik_env_file="$test_root/deploy/all-in-one-traefik/.env"
trap 'rm -rf "$tmp_dir"' EXIT

mkdir -p "$tmp_dir/bin" "$test_root/deploy/all-in-one" "$test_root/deploy/all-in-one-traefik"
cp "$root_dir/deploy/ctl" "$ctl"
cat >"$tmp_dir/bin/docker" <<'DOCKER'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$DOCKER_LOG"

if [[ "$*" == "compose version" ]]; then
  exit 0
fi

if [[ "$*" == "network inspect proxy" ]]; then
  exit "${PROXY_NETWORK_EXIT:-0}"
fi
DOCKER
chmod +x "$tmp_dir/bin/docker"

export PATH="$tmp_dir/bin:$PATH"
export DOCKER_LOG="$tmp_dir/docker.log"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_log_line() {
  local expected=$1
  grep -Fx -- "$expected" "$DOCKER_LOG" >/dev/null || fail "missing command: $expected"
}

run_ctl() {
  : >"$DOCKER_LOG"
  "$ctl" "$@"
}

usage_output="$tmp_dir/usage.txt"
if "$ctl" >"$usage_output" 2>&1; then
  fail "missing arguments succeeded"
fi
grep -F "deploy    Pull images, then create or start containers" "$usage_output" >/dev/null || fail "usage lacks deploy details"
grep -F "rebuild   Build local OpenMU image, then create or start containers" "$usage_output" >/dev/null || fail "usage lacks rebuild details"
grep -F "down      Stop and remove containers; preserve named volumes" "$usage_output" >/dev/null || fail "usage lacks down safety details"

aio_env_output="$tmp_dir/aio-env.txt"
if "$ctl" aio status >"$aio_env_output" 2>&1; then
  fail "aio status succeeded without .env"
fi
grep -F "Missing $test_root/deploy/all-in-one/.env" "$aio_env_output" >/dev/null || fail "aio missing .env error is unclear"

cat >"$aio_env_file" <<'ENV'
RESOLVE_IP=192.168.1.217
HTTP_PORT=8080
ENV

run_ctl aio deploy
assert_log_line "compose version"
assert_log_line "compose --env-file .env -f docker-compose.yml pull"
assert_log_line "compose --env-file .env -f docker-compose.yml up -d --no-build --remove-orphans"
if grep -F "docker-compose.prod.yml" "$DOCKER_LOG" >/dev/null; then
  fail "aio deploy includes HTTPS production overlay"
fi

run_ctl aio rebuild
assert_log_line "build -t munique/openmu -f $test_root/src/Startup/Dockerfile $test_root/src"
assert_log_line "compose --env-file .env -f docker-compose.yml up -d --no-build --remove-orphans"

touch "$traefik_env_file"

run_ctl traefik deploy
assert_log_line "network inspect proxy"
assert_log_line "compose -f docker-compose.prod.yml pull"
assert_log_line "compose -f docker-compose.prod.yml up -d --no-build --remove-orphans"

run_ctl aio down
assert_log_line "compose --env-file .env -f docker-compose.yml down --remove-orphans"
if grep -Eq -- '(^| )-v( |$)' "$DOCKER_LOG"; then
  fail "down deletes volumes"
fi

if run_ctl unsupported status >/dev/null 2>&1; then
  fail "unsupported deployment succeeded"
fi

if run_ctl aio unsupported >/dev/null 2>&1; then
  fail "unsupported action succeeded"
fi

grep -F '${HTTP_PORT:?Set HTTP_PORT in .env}:80' "$root_dir/deploy/all-in-one/docker-compose.yml" >/dev/null || fail "aio HTTP port does not require .env"
grep -F 'RESOLVE_IP: ${RESOLVE_IP:?Set RESOLVE_IP in .env}' "$root_dir/deploy/all-in-one/docker-compose.yml" >/dev/null || fail "aio advertised IP does not require .env"
grep -Fx 'RESOLVE_IP=local' "$root_dir/deploy/all-in-one/.env.example" >/dev/null || fail "aio .env example lacks advertised IP"
grep -Fx 'HTTP_PORT=8080' "$root_dir/deploy/all-in-one/.env.example" >/dev/null || fail "aio .env example lacks HTTP port"

printf 'PASS: deploy/ctl command contract\n'
