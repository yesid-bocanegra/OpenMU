---
title: Contributing
sidebar_position: 4
description: How to contribute code, documentation and other things to OpenMU.
---

# Contributing

Contributions are welcome if they meet the following criteria:

* Language is english.
* Code should be StyleCop compliant — this project uses the
  [StyleCop.Analyzers](https://www.nuget.org/packages/StyleCop.Analyzers/) for
  VS2022, so you should see issues directly as warnings.
* Coding style (naming, etc.) and quality should fit the current state.
* No code copied or converted from the well-known decompiled source of the
  original server.

If you want to contribute, please create a new issue for the feature or bug (if
the issue doesn't exist yet), so we can see who is working on something and can
discuss possible solutions. If it's a small thing, you can also just send a pull
request without adding an issue.

## How to contribute code

1. Fork this project from the original
   [MUnique OpenMU project](https://github.com/MUnique/OpenMU).
2. Create a feature branch from the master branch.
3. Commit your changes to your feature branch.
4. Please test your changes — **don't send AI generated code without testing it
   yourself**.
5. Submit a pull request to the original master branch.
6. Wait for the code review and merge. 🙂

## Synchronize this fork with upstream

The repository's `sync-fork.sh` script rebases the fork's commits onto upstream.
This keeps upstream history intact and replays only fork-specific commits,
without adding sync merge commits. Replayed commits receive new IDs. This fork
uses these remote names:

| Remote | Repository | Purpose |
| --- | --- | --- |
| `origin` | `https://github.com/MUnique/OpenMU.git` | Fetch upstream changes |
| `fork` | `git@github.com:yesid-bocanegra/OpenMU.git` | Fetch and push this fork |

Check your remotes with `git remote -v` before using the script. Other clones
often use `origin` for their own fork, so their remote names must be adjusted
first. The script requires Bash, Git, Docker Compose, and a configured Git
commit identity. Its checks do not start containers.

### Run the script

1. Commit or stash changes to tracked files, then switch to `master`.
   Untracked and ignored files can stay; the script stops if incoming files would
   overwrite them.
2. Run from the repository root:

   ```bash
   ./sync-fork.sh
   ```

   This fetches `origin` and `fork` without pruning local tags, fast-forwards
   from `fork/master` when its published tip changes, then rebases onto
   `origin/master`. It runs the deployment command tests and validates the
   all-in-one Compose configuration before any push. Repeated runs without
   new commits leave history unchanged.
3. Review and test any application changes. To also publish local `master` to
   `fork/master`, run:

   ```bash
   ./sync-fork.sh --push
   ```

The default command updates local `master` only. **`--push` rewrites
`fork/master`**, using `--force-with-lease` with the exact fork tip fetched at the
start. If another push changes that tip, publishing fails without overwriting
it. Coordinate history rewrites with anyone using this fork. The script never
pushes to `origin` or updates other local branches.

The script records incorporated fork history in
`refs/sync-fork/published-master`, so a local rebase can be rerun before pushing.
The older `sync-fork-master` helper branch is not needed or updated. The
deployment checks do not replace application tests for upstream changes.

The final output shows how many commits local `master` is ahead of and behind
upstream. The second number must be `0`. The first counts fork-specific commits.
Inspect the fork's actual file differences with `git diff origin/master HEAD`.
A rebase cleans up history; it does not remove intentional fork changes.

### Resolve a stopped sync

The first rebase of the old merge-based history can expose conflicts that were
resolved in earlier sync merges. Review those resolutions carefully because
rebase drops the merge commits themselves. Use `git reflog master` to find the
previous branch tip if needed.

If a rebase conflicts, the script stops without pushing. Use `git status` to
find the conflicted files. Resolve them while keeping the required changes from
upstream and the fork, then stage only the resolved files. Continue with
`git rebase --continue`, repeating as needed. To cancel, use `git rebase --abort`.
A completed fast-forward from `fork/master` stays in local history.

After the rebase completes, run the deployment checks and any additional tests
required by your resolutions:

```bash
bash deploy/test-ctl.sh
docker compose --env-file deploy/all-in-one/.env.example \
  -f deploy/all-in-one/docker-compose.yml config --quiet
```

If the checks pass, resume synchronization:

```bash
./sync-fork.sh --push
```

If a check fails, fix the problem and rerun the checks before pushing.

If `fork/master` has changed and cannot fast-forward local `master`, the script
stops. Inspect both histories and incorporate the new remote work before
retrying. A rejected push leaves local commits intact.

## Contributions from non-developers

Contributions from non-developers are welcome as well. You can

* test the server and submit issues or suggestions,
* contribute packet descriptions,
* write documentation about the concepts and mechanics of the game itself.

Please use markdown files/syntax for this purpose.

## Contributing to this documentation

The site you are reading lives in the
[`docs-website/`](https://github.com/MUnique/OpenMU/tree/master/docs-website)
folder of the repository. Every page has an *Edit this page* link at the bottom
which takes you straight to the right file.

To run the site locally:

```bash
cd docs-website
npm install
npm start
```

Please keep the existing style: line width around 80 characters, one sentence per
idea, and a link instead of a copy when the information already exists somewhere
else.

## Questions

If you have questions, don't hesitate to ask in our
[Discord channel](https://discord.gg/2u5Agkd) or by submitting an issue.
