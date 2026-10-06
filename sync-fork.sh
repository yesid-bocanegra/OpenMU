#!/usr/bin/env bash
set -euo pipefail

# Git's merge strategy can overwrite ignored files despite --no-overwrite-ignore.
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

# Parse the whole function before a merge can replace this script on disk.
main() {
  case "${1:-}" in
    --help|-h)
      printf 'Usage: ./sync-fork.sh [--push]\nMerge origin/master into local master; --push also updates fork/master.\n'
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
  check_incoming_paths fork/master
  if ! git merge --no-overwrite-ignore --ff-only fork/master; then
    printf 'Cannot fast-forward from fork/master. Inspect git status and the Git error before retrying.\n' >&2
    return 1
  fi
  check_incoming_paths origin/master
  if ! git merge --no-overwrite-ignore --no-ff --no-commit origin/master; then
    printf 'Upstream merge stopped. Inspect git status. Resolve blocking files or finish the merge after checks.\n' >&2
    return 1
  fi
  if ! bash deploy/test-ctl.sh || ! docker compose \
    --env-file deploy/all-in-one/.env.example \
    -f deploy/all-in-one/docker-compose.yml config --quiet; then
    printf 'Deployment checks failed. Fix and rerun checks before committing any pending merge.\n' >&2
    return 1
  fi
  if git rev-parse --quiet --verify MERGE_HEAD >/dev/null; then
    git commit -m 'chore(sync): merge upstream master'
  fi
  git merge-base --is-ancestor origin/master HEAD
  git merge-base --is-ancestor fork/master HEAD
  if [[ "${1:-}" == --push ]]; then
    git push fork HEAD:refs/heads/master
  fi
  printf 'Local master includes upstream and fork history. Ahead/behind upstream:\n'
  git rev-list --left-right --count HEAD...origin/master
}

main "$@"
