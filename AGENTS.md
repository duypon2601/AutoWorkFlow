# AutomaticWorkFlow (autowf)

`auto.sh` is the product (a bash pipeline: a reviewer plans and reviews, a coding agent writes
code, the script tests and commits). `todo/` is a sample app used as a fixture.

## Commands
- After an edit: `make check-fast`
- Task done: `make check-task` (syntax, shellcheck, gitleaks, all three test suites)
- Usage and config variables: `./auto.sh --help`

## Boundaries
- Never run the pipeline (`./auto.sh` or `autowf` without `--check` / `--preflight` /
  `--help`) inside an agent session.
- Never edit `~/.local/bin/autowf`; it is installed from `auto.sh` by the user's procedure in
  `CLAUDE.md`.
- Do not edit `PLAN.md` or `PROGRESS.md` as a side effect, and do not change `TEST_CMD`.
- Read `CONSTRAINTS.md` before writing code. Do not weaken it to make a change pass.

`CLAUDE.md` has the project map and conventions; read it when changing `auto.sh`.
