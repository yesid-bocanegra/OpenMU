#!/usr/bin/env bash
set -euo pipefail

# Git can overwrite ignored files when checking out incoming commits.
check_incoming_paths() {
  local incoming path
  git rev-parse --verify "$1^{commit}" >/dev/null
  while IFS= read -r -d '' incoming; do
    path=$incoming
    while :; do
      if [[ -L "$path" || ( -e "$path" && ( "$path" == "$incoming" || ! -d "$path" ) ) ]]; then
        printf 'Move the local file or directory before syncing: %s\n' "$path" >&2
        return 1
      fi
      [[ "$path" == */* ]] || break
      path=${path%/*}
    done
  done < <(git diff --no-renames --diff-filter=A --name-only -z HEAD "$1" --)
}

# Parse the whole function before Git can replace this script on disk.
main() {
  case "${1:-}" in
    --help|-h)
      printf 'Usage: ./sync-fork.sh [--push]\nRebase fork commits onto origin/master; --push updates fork/master with an explicit lease.\n'
      return
      ;;
    ''|--push) ;;
    *) printf 'Usage: ./sync-fork.sh [--push]\n' >&2; return 2 ;;
  esac
  if [[ $# -gt 1 ]]; then
    printf 'Usage: ./sync-fork.sh [--push]\n' >&2
    return 2
  fi

  cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
  # ponytail: fixed origin/fork master workflow; add arguments if another layout is needed.
  if [[ "$(git branch --show-current)" != master ]]; then
    printf 'Switch to master before syncing.\n' >&2
    return 1
  fi
  local operation
  for operation in MERGE_HEAD CHERRY_PICK_HEAD REVERT_HEAD rebase-merge rebase-apply sequencer; do
    if [[ -e "$(git rev-parse --git-path "$operation")" ]]; then
      printf 'Finish or abort the pending Git operation before syncing.\n' >&2
      return 1
    fi
  done
  if ! git diff --quiet || ! git diff --cached --quiet; then
    printf 'Commit or stash tracked changes before syncing. Untracked files can stay.\n' >&2
    return 1
  fi
  git remote get-url origin >/dev/null
  git remote get-url fork >/dev/null
  docker compose version >/dev/null

  git fetch --no-prune-tags origin
  git fetch --no-prune-tags fork
  local fork_tip previous_fork
  fork_tip=$(git rev-parse fork/master)
  previous_fork=$(git rev-parse --quiet --verify refs/sync-fork/published-master || true)
  # Remember incorporated fork history so an unpushed rebase can be run again.
  if [[ "$fork_tip" != "$previous_fork" ]]; then
    check_incoming_paths fork/master
    if ! git merge --no-overwrite-ignore --ff-only fork/master; then
      printf 'Cannot fast-forward from fork/master. Inspect the remote changes before retrying.\n' >&2
      return 1
    fi
    git update-ref refs/sync-fork/published-master "$fork_tip"
  fi
  check_incoming_paths origin/master
  if ! git rebase --no-fork-point --no-rebase-merges --no-update-refs --no-autostash origin/master; then
    printf 'Rebase stopped. Inspect git status, resolve and stage conflicts, then run git rebase --continue; or git rebase --abort.\n' >&2
    return 1
  fi
  if ! bash deploy/test-ctl.sh || ! docker compose \
    --env-file deploy/all-in-one/.env.example \
    -f deploy/all-in-one/docker-compose.yml config --quiet; then
    printf 'Deployment checks failed. Fix and rerun checks before pushing.\n' >&2
    return 1
  fi
  git merge-base --is-ancestor origin/master HEAD
  if [[ "${1:-}" == --push ]]; then
    git push --force-with-lease="refs/heads/master:$fork_tip" fork HEAD:refs/heads/master
  fi
  printf 'Local master contains upstream plus rebased fork commits. Ahead/behind upstream:\n'
  git rev-list --left-right --count HEAD...origin/master
}

main "$@"
