---
name: to-autowf-plan
description: Turn a spec, plan or the current conversation into a PLAN.md that autowf can run, split into tracer-bullet tasks small enough for one coding-agent run.
disable-model-invocation: true
argument-hint: "Path to a spec (e.g. .scratch/<feature>/spec.md), or nothing to use the conversation"
---

# To autowf plan

Write `PLAN.md` for autowf: the reviewer only sees the overview plus one task, and the coding agent (agy) sees the same excerpt. Every decision the agent needs must already be in the plan, or the reviewer stops the run with a `plan-gap`.

Adapted from Matt Pocock's `to-tickets` (see `skills/README.md`). Same slicing rules, but the output is one `PLAN.md`, not tracker tickets.

## Process

### 1. Gather context

- Use the conversation, or read the spec the user passes (often `.scratch/<feature>/spec.md` from `/to-spec`).
- Read `GLOSSARY.md` (or `GLOSSARY-MAP.md`) and the ADRs in `docs/adr/` that touch this area, if they exist. Use the glossary's terms in task titles and criteria.
- Read `CONSTRAINTS.md`, `CLAUDE.md` or `AGENTS.md` if present: tasks must not ask for anything they forbid.
- If `PLAN.md` already exists, read it and `git log --oneline -- PLAN.md`. Changing its `## Task N` headings starts a new plan, so committed tasks will no longer be skipped. Tell the user before replacing it.

### 2. Find the test command

Pick ONE command that runs the whole test suite with compact output (`pytest -q`, `vitest --reporter=dot`, `go test ./...`). The agent reads its output on every try. If the project has no tests yet, Task 1 sets them up.

### 3. Draft tracer-bullet tasks

<vertical-slice-rules>

- Each task cuts a narrow but COMPLETE path through every layer it needs (schema, logic, API, UI, tests): vertical, not one layer at a time.
- A finished task is verifiable on its own by `TEST_CMD`.
- Each task fits one agy run: few files, one concern. The agent's token cost grows with every file it reads.
- Prefactoring comes first: "make the change easy, then make the easy change".
- A wide refactor (one mechanical change across many call sites) is sequenced expand, migrate in batches, contract, each its own task, keeping tests green after every task.

</vertical-slice-rules>

autowf runs tasks strictly in order 1, 2, 3…, so order them so every task's blockers come earlier.

For each task, decide everything the agent would otherwise guess: names, file paths, data formats, error messages, exit codes, edge-case behaviour. If you cannot decide one, ask the user now instead of leaving it open.

### 4. Quiz the user

Show the tasks as a numbered list: title, what it delivers end to end, which earlier tasks it needs. Ask:

- Is the granularity right (too coarse / too fine)?
- Is anything left for the agent to guess?
- Should any task be merged or split?

Iterate until the user approves.

### 5. Write PLAN.md

Use the template below. Write in the language the user works in; keep code identifiers as they are.

<plan-template>

# PLAN.md: <project or feature name>

TEST_CMD: <one command that runs the full suite with compact output>

## Overview

<Stack, how to run, conventions every task follows. Put shared decisions here (data formats, error handling, exit codes, directory layout), since every task excerpt includes this section. Link the spec and ADRs by path.>

---

## Task 1: <short title>

**Delivers:** <the end-to-end behaviour this task makes work>

**Files:** <files to create or modify>

**Acceptance criteria (checked by tests):**

- [ ] <criterion>
- [ ] <criterion>

## Task 2: <short title>

...

</plan-template>

Format rules autowf enforces (`load_plan` in `auto.sh`):

- Exactly one line starting with `TEST_CMD: `.
- Task headings are `## Task N: <title>`, N starting at 1 with no gaps.
- Nothing before `## Task 1` except the overview: the overview is sent with every task.

### 6. Commit and hand off

autowf refuses to start on a dirty repo, so commit the plan (and any spec, glossary or ADR files written on the way) once the user approves: `git add PLAN.md <other files> && git commit -m "PLAN.md"`.

Then tell the user to run `autowf` in their own terminal. Never run the pipeline yourself: it is long-running.
