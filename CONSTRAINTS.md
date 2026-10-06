# Constraints

Last reviewed: 2026-10-07 by @duypon2601

The quality bar for this repository. Agents read this before writing code.

## Mode: warn

Decided 2026-10-07: a failing check does not stop the task. The agent reports the failure
(which check, where, the output) in its hand-back and carries on; the user decides what to do.
"Carry on" never means making the check pass by weakening it — see the floor.

## Floor (always applies, no tooling needed)

- No new suppression comments: `# shellcheck disable`, `# noqa`, `# type: ignore`,
  `gitleaks:allow`. Today there is one, `auto.sh:121` (SC1091, sourcing the optional `.autowf.env`).
- No unimplemented stubs: `raise NotImplementedError`, `pass` or `:` standing in for logic,
  `|| true` added to hide a failing command.
- No skipped, deleted or weakened tests (`pytest.mark.skip`/`xfail`, removed fixtures or
  cases, assertions stripped) without the reason in the commit message.
- No secrets in source. `NTFY_TOPIC` and agent credentials stay out of the repo.
- This file is not weakened to make a change pass. Changing it is its own commit.

Checked at review by reading `git diff` for the moves above (`/constraints guard`).

## Enforced with numbers

| Dimension | Rule | Why | Checked by | Runs at |
|-----------|------|-----|-----------|---------|
| Syntax | `auto.sh` parses | A syntax error breaks every project using `autowf` | `bash -n auto.sh` | every edit |
| Lint (bash) | Zero shellcheck findings at severity `error` | Errors are real bugs; it is zero today, so any is new | `shellcheck -S error auto.sh tests/diagnose_test.sh tests/watch_test.sh` | every edit |
| Secrets | Zero findings | One leaked token is enough | `gitleaks dir --redact --no-banner .` (tree), `gitleaks git --redact --no-banner .` (history) | every edit / before push |
| Tests | All pass | The only proof of pipeline behaviour | `bash tests/diagnose_test.sh && bash tests/watch_test.sh && .venv/bin/python -m pytest -q` | task end |
| Time | `make check-task` under 90 s | Slower checks stop being run; today it takes about 10 s | `time make check-task` | task end |

Shortcuts: `make check-fast` (every edit), `make check-task` (task end), `make check-full`
(before review or push). The Makefile mirrors this table; if they differ, this file wins.

shellcheck and gitleaks are the outside opinions here: neither can be satisfied by the agent
writing a test that agrees with its own code. Always pass `--redact` to gitleaks so a matched
secret never lands in a transcript or log.

## Measured, not yet enforced

Values on 2026-10-07. Update a number when it improves; a move in the wrong direction is a
finding to report.

| Metric | Today | Direction | Measured by |
|--------|-------|-----------|-------------|
| shellcheck warnings | 5 (all SC2034 in `tests/*.sh`: variables read by functions sourced from `auto.sh`) | must not grow | `make check-full` |
| shellcheck notes (info + style) | 24 | must not grow | `make check-full` |
| Pipeline regression cases | 15 + 10 | must not fall | the two `tests/*.sh` scripts |
| pytest tests | 120 | must not fall | `.venv/bin/python -m pytest -q` |

## Not applicable

- Coverage: the product is bash, which has no usable line-coverage tool; `todo/` is a fixture.
- Dependency scanning: no runtime dependencies.
- Performance budgets, accessibility: a CLI has no URL to measure.

## Exceptions

| ID | Rule | Path | Reason | Owner | Expires |
|----|------|------|--------|-------|---------|
| — | none | | | | |

New exceptions need an owner and an expiry at most 90 days out.
