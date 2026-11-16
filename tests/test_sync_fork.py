"""Exercise the sync script with local Git remotes and a Docker stub."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "sync-fork.sh"


class SyncForkTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="openmu-sync-test-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.repo = self.root / "repo"
        self.upstream = self.root / "upstream"
        self.origin = self.root / "origin.git"
        self.fork = self.root / "fork.git"
        self.env = {key: value for key, value in os.environ.items() if not key.startswith("GIT_")}
        self.env.update(
            GIT_CONFIG_GLOBAL=os.devnull,
            GIT_CONFIG_NOSYSTEM="1",
            GIT_AUTHOR_NAME="Sync test",
            GIT_AUTHOR_EMAIL="sync-test@example.invalid",
            GIT_COMMITTER_NAME="Sync test",
            GIT_COMMITTER_EMAIL="sync-test@example.invalid",
            GIT_EDITOR="true",
        )
        binary = self.root / "bin"
        binary.mkdir()
        docker = binary / "docker"
        docker.write_text(
            '#!/usr/bin/env bash\nset -eu\n'
            'if [[ "$*" == *"config --quiet" && -n "${SYNC_RACE_TIP:-}" ]]; then\n'
            '  git --git-dir="$SYNC_RACE_FORK" update-ref refs/heads/master "$SYNC_RACE_TIP"\n'
            '  git fetch --quiet fork\n'
            'fi\n'
        )
        docker.chmod(0o755)
        self.env["PATH"] = str(binary) + os.pathsep + self.env["PATH"]
        self.git(self.root, "init", "--bare", "-b", "master", str(self.origin))
        self.git(self.root, "init", "--bare", "-b", "master", str(self.fork))
        self.git(self.root, "init", "-b", "master", str(self.upstream))
        self.write(self.upstream, "src/server.cs", "upstream base\n")
        self.write(self.upstream, "shared.conf", "value=base\n")
        self.write(self.upstream, ".gitignore", "*.local\n")
        self.write(self.upstream, "deploy/test-ctl.sh", 'exit "${DEPLOY_CHECK_EXIT:-0}"\n')
        self.commit(self.upstream, "upstream base")
        self.git(self.upstream, "remote", "add", "origin", str(self.origin))
        self.git(self.upstream, "push", "origin", "master")
        self.git(self.root, "clone", str(self.origin), str(self.repo))
        self.git(self.repo, "remote", "add", "fork", str(self.fork))
        shutil.copy2(SCRIPT, self.repo / "sync-fork.sh")
        self.commit(self.repo, "fork sync script")
        self.write(self.repo, "shared.conf", "value=fork\n")
        self.commit(self.repo, "fork settings")
        self.write(self.upstream, "src/server.cs", "upstream update\n")
        self.commit(self.upstream, "upstream update")
        self.git(self.upstream, "push", "origin", "master")
        self.git(self.repo, "fetch", "origin")
        self.git(self.repo, "merge", "--no-ff", "-m", "old sync merge", "origin/master")
        self.git(self.repo, "push", "fork", "master")
        self.write(self.upstream, "src/server.cs", "latest upstream\n")
        for path in ("incoming", "secret.local", "new-dir/child"):
            self.write(self.upstream, path, "upstream file\n")
            self.git(self.upstream, "add", "--force", path)
        self.commit(self.upstream, "latest upstream")
        self.git(self.upstream, "push", "origin", "master")
        self.original = self.git(self.repo, "rev-parse", "HEAD")
        self.published = self.git(self.fork, "rev-parse", "master")

    def git(self, repo, *args):
        result = subprocess.run(
            ["git", "-C", str(repo), *args], env=self.env, text=True,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return result.stdout.strip()

    def write(self, repo, path, contents):
        target = repo / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(contents)

    def commit(self, repo, message):
        self.git(repo, "add", ".")
        self.git(repo, "commit", "-m", message)

    def sync(self, *args, success=True):
        result = subprocess.run(
            ["bash", "sync-fork.sh", *args], cwd=self.repo, env=self.env,
            text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        )
        self.assertEqual(result.returncode == 0, success, result.stdout)
        return result.stdout

    def remote_work(self):
        other = self.root / "other"
        self.git(self.root, "clone", str(self.fork), str(other))
        self.write(other, "remote-work", "preserve remote work\n")
        self.commit(other, "remote work")
        return other

    def assert_rebased(self, count=2):
        self.assertEqual(self.git(self.repo, "rev-list", "--count", "origin/master..HEAD"), str(count))
        self.assertEqual(self.git(self.repo, "rev-list", "--merges", "origin/master..HEAD"), "")
        self.git(self.repo, "merge-base", "--is-ancestor", "origin/master", "HEAD")
        self.git(self.repo, "diff", "--exit-code", "origin/master", "HEAD", "--", "src")
        self.assertEqual((self.repo / "shared.conf").read_text(), "value=fork\n")

    def test_rebase_preserves_fork_commits_and_is_repeatable(self):
        self.git(self.repo, "config", "rebase.updateRefs", "true")
        self.git(self.repo, "config", "rebase.rebaseMerges", "true")
        self.git(self.repo, "config", "fetch.prune", "true")
        self.git(self.repo, "config", "fetch.pruneTags", "true")
        self.git(self.repo, "branch", "other-work")
        self.git(self.repo, "tag", "keep-local")
        self.sync()
        self.assert_rebased()
        rebased = self.git(self.repo, "rev-parse", "HEAD")
        self.assertEqual(self.git(self.fork, "rev-parse", "master"), self.published)
        self.assertEqual(self.git(self.repo, "rev-parse", "other-work"), self.original)
        self.assertEqual(self.git(self.repo, "rev-parse", "keep-local"), self.original)
        self.sync()
        self.assertEqual(self.git(self.repo, "rev-parse", "HEAD"), rebased)
        self.sync("--push")
        self.assertEqual(self.git(self.fork, "rev-parse", "master"), rebased)
        self.sync("--push")
        self.assertEqual(self.git(self.repo, "rev-parse", "HEAD"), rebased)
        self.write(self.upstream, "src/server.cs", "another upstream update\n")
        self.commit(self.upstream, "another upstream update")
        self.git(self.upstream, "push", "origin", "master")
        self.sync("--push")
        self.assert_rebased()

    def test_local_files_are_preserved(self):
        for path in ("incoming", "secret.local", "new-dir"):
            with self.subTest(path=path):
                target = self.repo / path
                target.write_text("local data\n")
                self.assertIn("Move the local file or directory", self.sync(success=False))
                self.assertEqual(target.read_text(), "local data\n")
                self.assertEqual(self.git(self.repo, "rev-parse", "HEAD"), self.original)
                target.unlink()
        self.write(self.repo, "unrelated.local", "keep ignored file\n")
        self.write(self.repo, "unrelated", "keep untracked file\n")
        self.sync()
        self.assertEqual((self.repo / "unrelated.local").read_text(), "keep ignored file\n")
        self.assertEqual((self.repo / "unrelated").read_text(), "keep untracked file\n")

    def test_dirty_tracked_files_are_preserved(self):
        self.write(self.repo, "shared.conf", "uncommitted\n")
        self.assertIn("Commit or stash", self.sync(success=False))
        self.assertEqual((self.repo / "shared.conf").read_text(), "uncommitted\n")
        self.assertEqual(self.git(self.repo, "rev-parse", "HEAD"), self.original)

    def test_pending_operation_is_rejected(self):
        self.write(self.repo, ".git/MERGE_HEAD", self.original + "\n")
        self.assertIn("pending Git operation", self.sync(success=False))
        self.assertEqual(self.git(self.repo, "rev-parse", "HEAD"), self.original)

    def test_remote_fast_forward_is_preserved(self):
        other = self.remote_work()
        self.git(other, "push", "origin", "master")
        self.sync("--push")
        self.assert_rebased(count=3)
        self.assertEqual((self.repo / "remote-work").read_text(), "preserve remote work\n")

    def test_diverged_remote_is_not_overwritten(self):
        other = self.remote_work()
        self.git(other, "push", "origin", "master")
        published = self.git(self.fork, "rev-parse", "master")
        self.write(self.repo, "local-work", "local work\n")
        self.commit(self.repo, "local work")
        local = self.git(self.repo, "rev-parse", "HEAD")
        self.assertIn("Cannot fast-forward", self.sync("--push", success=False))
        self.assertEqual(self.git(self.repo, "rev-parse", "HEAD"), local)
        self.assertEqual(self.git(self.fork, "rev-parse", "master"), published)

    def test_concurrent_push_is_not_overwritten_even_after_background_fetch(self):
        other = self.remote_work()
        self.git(other, "push", "origin", "HEAD:refs/heads/racing")
        tip = self.git(other, "rev-parse", "HEAD")
        self.env.update(SYNC_RACE_TIP=tip, SYNC_RACE_FORK=str(self.fork))
        self.assertIn("stale info", self.sync("--push", success=False))
        self.assertEqual(self.git(self.fork, "rev-parse", "master"), tip)
        self.assert_rebased()

    def test_failed_checks_prevent_push_and_allow_retry(self):
        self.env["DEPLOY_CHECK_EXIT"] = "1"
        self.assertIn("Deployment checks failed", self.sync("--push", success=False))
        self.assertEqual(self.git(self.fork, "rev-parse", "master"), self.published)
        self.assert_rebased()
        del self.env["DEPLOY_CHECK_EXIT"]
        self.sync("--push")
        self.assertEqual(self.git(self.fork, "rev-parse", "master"), self.git(self.repo, "rev-parse", "HEAD"))

    def test_conflict_can_be_aborted_or_resolved(self):
        self.write(self.upstream, "shared.conf", "value=upstream\n")
        self.commit(self.upstream, "conflicting upstream change")
        self.git(self.upstream, "push", "origin", "master")
        self.assertIn("Rebase stopped", self.sync("--push", success=False))
        self.assertEqual(self.git(self.fork, "rev-parse", "master"), self.published)
        self.git(self.repo, "rebase", "--abort")
        self.assertEqual(self.git(self.repo, "rev-parse", "HEAD"), self.original)
        self.sync(success=False)
        self.write(self.repo, "shared.conf", "value=fork\n")
        self.git(self.repo, "add", "shared.conf")
        self.git(self.repo, "rebase", "--continue")
        self.sync("--push")
        self.assert_rebased()


if __name__ == "__main__":
    unittest.main()
