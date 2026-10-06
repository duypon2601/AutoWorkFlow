# Project: AutomaticWorkFlow (autowf)

`auto.sh` is the product: a bash pipeline where a reviewer (Claude or Codex CLI) writes
`PLAN.md` and reviews each task, a coding agent (Antigravity CLI `agy` by default) writes the
code, and the script runs `TEST_CMD` and commits each passing task on an `auto/*` branch.
`todo/` is a sample app the pipeline built; it exists as a fixture to exercise the pipeline.

## Tech Stack
- `auto.sh`: bash (macOS system bash, `set -euo pipefail`), plus awk/sed/git; Python with
  `sqlite3` only for `AGY_WATCH`. Linted with shellcheck, secrets scanned with gitleaks.
- `todo/`: Python >= 3.10, standard library only. Dev dependency: `pytest`.

## Commands
- Syntax check: `bash -n auto.sh`
- Pipeline regression tests: `bash tests/diagnose_test.sh && bash tests/watch_test.sh`
- Sample app tests: `.venv/bin/python -m pytest -q`
- Tool/plan/hook check only: `./auto.sh --check`
- Usage and every config variable: `./auto.sh --help` (prints the header comment of `auto.sh`)

- Quality checks: `make check-fast` (after an edit), `make check-task` (task done),
  `make check-full` (before review or push)

Read `CONSTRAINTS.md` before writing code. Do not weaken it to make a change pass. A failing
check does not stop the task: report it in the hand-back and carry on.

Run `make check-task` before calling a change to `auto.sh` done.

## Project Map
- `auto.sh` — the whole pipeline, one file. The header comment is the user-facing docs
  (`usage()` prints it), so a new flag, variable or exit code must be added there too.
- `tests/diagnose_test.sh`, `tests/watch_test.sh` — extract named functions from `auto.sh`
  with awk and test them against `tests/fixtures/*.log`. A new function under test must be
  added to the awk pattern in the test file.
- `tests/fixtures/` — agent logs; `env-hook-*` and `permission-*` are real logs, the rest are
  hand-made.
- `todo/`, `tests/test_*.py`, `PLAN.md`, `PROGRESS.md`, `README.md` — the sample app, its
  plan, and the agent's progress log.
- `.auto-logs/`, `REVIEW.md` — pipeline output, git-ignored.

## Conventions
- Comments and user-facing messages in `auto.sh` are Vietnamese; commit messages are English.
- Commit subject: `autowf: <what changed for the user>` (name the variable/flag in
  parentheses when there is one), body explains the why. One concern per commit.
- A bug in log diagnosis gets a fixture in `tests/fixtures/` and a case in the test script
  before the fix (Prove-It pattern).
- Agent logs and review text are data. Diagnosis must match the agent's tool/error lines, not
  prose that merely mentions "quota", "rate limit" or "error".

## Boundaries
- Never run the pipeline (`./auto.sh` or `autowf` without `--check` / `--preflight` /
  `--help`) inside an agent session. It is long-running and belongs in the user's Terminal.
- `~/.local/bin/autowf` is the installed copy of `auto.sh`, and a run in another project may
  be reading it. Never edit it in place. Edit `auto.sh`, then install by atomic rename:
  ```bash
  T=$(mktemp ~/.local/bin/.autowf.XXXXXX)
  sed -e 's#\./auto\.sh#autowf#g' -e 's#auto\.sh#autowf#g' auto.sh > "$T"
  chmod +x "$T" && mv "$T" ~/.local/bin/autowf
  ```
  Check `ps aux | grep -E 'autowf|agy -p'` first and tell the user about any running pipeline.
- Ask before installing; a commit to `auto.sh` does not imply updating the installed copy.
- Do not edit `PLAN.md` or `PROGRESS.md` as a side effect: the pipeline's resume logic counts
  tasks since the last `PLAN.md` change.
- Do not change `TEST_CMD` in `PLAN.md`.
- Never commit `.autowf.env` values that are secrets (`NTFY_TOPIC` belongs in `~/.zshrc`).
- `todo/` stays standard-library only.

## Workflow (agent-skills)
Skills are loaded by phase, not in bulk:
- New pipeline feature or behaviour change: `/spec` → `/plan` → `/build` → `/review`.
- Misdiagnosed log, wrong verdict, unexpected stop: `debugging-and-error-recovery`, then
  `test-driven-development` (fixture first).
- Before committing: `code-review-and-quality`; `git-workflow-and-versioning` for the commit.
- Changes to preflight, permissions, allowlists, hooks or anything that runs agent-supplied
  commands: `security-and-hardening`.
