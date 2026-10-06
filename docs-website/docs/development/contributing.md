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

The repository's `sync-fork.sh` script merges upstream changes while preserving
the fork's commits and their original IDs. This fork uses these remote names:

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
   Untracked and ignored files can stay; the script stops if a merge would
   overwrite them.
2. Run from the repository root:

   ```bash
   ./sync-fork.sh
   ```

   This fetches `origin` and `fork` without pruning local tags, fast-forwards
   from `fork/master` when possible, then merges `origin/master`. It runs the
   deployment command tests and validates the all-in-one Compose configuration
   before creating a merge commit. Repeated runs do not create empty commits.
3. Review and test any application changes. To also publish local `master` to
   `fork/master`, run:

   ```bash
   ./sync-fork.sh --push
   ```

The default command updates local `master` only. `--push` uses a normal push
to `fork`; the script never force-pushes, rebases, or pushes to `origin`.
It operates directly on `master`, so the older `sync-fork-master` helper branch
is not needed or updated. The deployment checks do not replace application
tests for changes to game logic or other server code.

The final output shows how many commits local `master` is ahead of and behind
upstream. The second number must be `0`. The first includes fork-specific
commits and merge commits.

### Resolve a stopped sync

If a merge conflicts, the script stops without committing or pushing. Use
`git status` to find the conflicted files. Resolve them while keeping the
required changes from both branches, then stage only the resolved files.
Run the same checks before committing:

```bash
bash deploy/test-ctl.sh
docker compose --env-file deploy/all-in-one/.env.example \
  -f deploy/all-in-one/docker-compose.yml config --quiet
```

If both checks pass, run any additional tests required by your resolutions,
then finish the merge and resume synchronization:

```bash
git commit -m "chore(sync): merge upstream master"
./sync-fork.sh --push
```

If a check fails, fix the problem and rerun the checks before committing.
To cancel a pending merge, use `git merge --abort`. A completed fast-forward
from `fork/master` stays in local history.

If local `master` and `fork/master` have both gained separate commits, the
script stops at the fast-forward check. Merge `fork/master` manually with
`git merge --no-ff --no-commit fork/master`, resolve and test as described
above, commit, then rerun the script. A rejected push also leaves local commits
intact; resolve the remote change or access problem before retrying.

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
