---
name: land
description: >-
  Land the change the user just made in this project: verify the checks the
  tests workflow runs, commit, push to origin/main, confirm the commit is on
  the remote, and report the outcome. This is the workflow behind the Land
  Changes button and the only supported way to land here. Use it only when the
  user has asked to land, merge, or push their changes, never for review,
  preparation, running checks on their own, or a question about the process.
disable-model-invocation: true
metadata:
  delta-action: land
---

# Land changes in ddev-assistant-ollama

The request that invoked this skill is the authorization to land. Do not ask
again whether to merge, and do not stop to confirm intent.

Landing here means: the change is committed on `main` and the commit is
verified present on `origin/main`. A commit, a push that was not confirmed, or
a passing local run is not landing.

## Scope

This repository has one branch and no pull requests: its history is three
direct commits on `main`, and `.github/PULL_REQUEST_TEMPLATE.md` is unmodified
template boilerplate. So:

- Land onto `main`, which is what the worktree is already on.
- Push to `origin` (`git@github.com:brookemahoney/ddev-assistant-ollama.git`,
  SSH verified reachable). Never push to the `local` remote; that is the user's
  primary checkout.
- Do not open a pull request, and do not create a tag or a release. There is no
  release workflow in `.github/` and no tag exists on the remote, so releasing
  is a separate manual step the user performs. If the change needs a release
  to take effect for users of the add-on, say so in the report and stop there.
- Never force-push, never `reset --hard`, and never discard work that is not
  part of the change being landed.

If `HEAD` is not `main`, stop and ask: this repository has no feature-branch
practice to fall back on.

## Step 1: Preflight

```bash
git fetch origin
git --no-pager status --short
git rev-list --left-right --count origin/main...HEAD
git --no-pager log --oneline -1 origin/main
```

- `origin/main...HEAD` must read `0	0` after any commit you are about to make,
  or `0	<n>` before it. Anything in the left column means the remote moved:
  rebase onto `origin/main` (Step 4) and re-run the checks.
- Read every path in `git status --short`. If it contains changes that are not
  part of the change being landed, stop and ask which ones belong. Do not
  `git add -A` over unrelated work.
- If the worktree is already clean, the change may already be committed. Land
  what is there rather than looking for more.

## Step 2: Run the required checks

The required check is the bats suite, which is exactly what CI runs:
`.github/workflows/tests.yml` invokes `ddev/github-action-add-on-test@v2`, and
`tests/test.bats` is the suite that action executes.

```bash
bats ./tests/test.bats --filter-tags '!release'
```

The `!release` filter is required, not optional: the `@release` test installs
the add-on from a published GitHub release, and no release or tag exists on the
remote, so that test cannot pass. CI runs it only after a release is cut.

Prerequisites for that command, because the repository does not vendor them:

- `bats` itself: `brew install bats-core` if `command -v bats` is empty.
- The libraries `setup()` in `tests/test.bats` loads (`bats-support`,
  `bats-assert`, `bats-file`) must be on `BATS_LIB_PATH`. It checks
  `$(brew --prefix)/lib` and `${DIR}/test_env/bats_libs`, neither of which
  exists on this machine. Fetch them once, outside the repository:

  ```bash
  mkdir -p ~/tmp/bats_libs
  git clone --depth 1 https://github.com/bats-core/bats-support ~/tmp/bats_libs/bats-support
  git clone --depth 1 https://github.com/bats-core/bats-assert ~/tmp/bats_libs/bats-assert
  git clone --depth 1 https://github.com/bats-core/bats-file ~/tmp/bats_libs/bats-file
  BATS_LIB_PATH="$HOME/tmp/bats_libs:$(brew --prefix)/lib" bats ./tests/test.bats --filter-tags '!release'
  ```

- The suite needs DDEV and Docker, and it builds the web image, so the first
  run after a Dockerfile change is slow. Let it finish; do not shorten it.

Also run, when the change touches a shell script:

```bash
shellcheck web-build/ddev-ollama-start
```

Scale the checks to the change. A change that only edits `README.md` does not
need the image build, but still needs:

```bash
git --no-pager diff --check
```

Any failing, unrun, or inconclusive check is a blocker. Report it and stop; do
not push and do not describe it as landed. Verification must cover the change
being landed, not an earlier commit that happened to pass.

## Step 3: Commit

Stage only the paths belonging to this change, then commit with a subject that
states what changed. Use a conventional-commit prefix (`feat:`, `fix:`,
`docs:`, `chore:`, `test:`): the existing subjects on `main` are plain
sentences, so this is a convention rather than enforced policy, but it makes
the type of change visible in `git log`. Keep the body to what a reviewer
would need: the behavior, and anything non-obvious about why.

Commits here are unsigned and there is no gpg on this machine, so do not add a
`-S` flag or a `Signed-off-by` trailer.

## Step 4: Push

```bash
git push origin main
```

If the push is rejected as non-fast-forward, the remote moved after Step 1:

```bash
git fetch origin && git rebase origin/main
```

then re-run Step 2 in full, because rebasing changes the commit being landed,
and push again. If the rebase conflicts, go to "Conflicts" below.

## Step 5: Confirm

```bash
git ls-remote --heads origin main
git --no-pager status --short
git rev-list --left-right --count origin/main...HEAD
```

`ls-remote` must show the short SHA you just committed, and the worktree must
be clean with `0	0` against `origin/main`. Only then is the change landed.
If the SHA is not there, the change is not landed; say so plainly.

## Conflicts

The user has chosen to resolve conflicts themselves. On any conflict during a
rebase, merge, or a rejected push:

- Leave the tree as it is, in whatever state git left it, and do not resolve,
  abort, or skip.
- Report which files conflict, what landed on `origin/main` in the meantime,
  and the resolutions you would consider, as questions in the conversation.
- Report the attempt as a failure with `status: "failure"`, title `Merge
  conflicts`, and let the user decide. The change has not landed.

## CI status

Pushing to `main` triggers `tests` in `.github/workflows/tests.yml`, across
ubuntu-latest and ubuntu-24.04-arm with DDEV stable and HEAD.

There is no `gh` and no `GITHUB_TOKEN`/`GH_TOKEN` in this environment, so
remote check status cannot be read from the terminal. Do not report that CI
passed on the strength of a local run. Say the workflow is running on the
commit. If `gh` is ever installed and authenticated, use
`gh run list --commit <sha>` and `gh run watch` to confirm, and include the run
URL only if you have actually read it.

## Report the outcome

When running in a subthread, as the Land Changes button does, report with
`report_subthread_status`. Otherwise reply in this conversation. Either way,
keep `title` to a few sentence-case words and `description` to one short line,
and keep questions in the conversation rather than in the status event.

| Outcome | `status` | `title` | `description` |
| --- | --- | --- | --- |
| Verified landing | `success` | `Landed on main` | `[abc1234](https://github.com/brookemahoney/ddev-assistant-ollama/commit/abc1234). Tests passed locally; the workflow is running. No release cut.` |
| Checks failed | `failure` | `Blocked by tests` | `[abc1234](https://github.com/brookemahoney/ddev-assistant-ollama/commit/abc1234) not landed: the bats suite failed.` |
| Push rejected | `failure` | `Push blocked` | `[abc1234](https://github.com/brookemahoney/ddev-assistant-ollama/commit/abc1234) passed locally; push to origin/main was rejected.` |
| Conflict | `failure` | `Merge conflicts` | `[abc1234](https://github.com/brookemahoney/ddev-assistant-ollama/commit/abc1234) conflicts with main. Waiting for your call.` |

Substitute the real short SHA. Include a CI run link only when you have read
the run. Report the release status as its own clause, since landing does not
cut one.

A failure is not terminal: if a later attempt after the user resolves the
blocker succeeds, verify again and report the new outcome.
