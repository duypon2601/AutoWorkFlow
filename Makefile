# Quality checks. CONSTRAINTS.md is the source of truth; these targets mirror its commands.
SH := auto.sh tests/diagnose_test.sh tests/watch_test.sh

.PHONY: check-fast check-task check-full

# After an edit: seconds.
check-fast:
	bash -n auto.sh
	shellcheck -S error $(SH)
	gitleaks dir --redact --no-banner .

# When a task looks done.
check-task: check-fast
	bash tests/diagnose_test.sh
	bash tests/watch_test.sh
	.venv/bin/python -m pytest -q

# Before review / push.
check-full: check-task
	gitleaks git --redact --no-banner .
	@echo "shellcheck warnings: $$(shellcheck -f gcc $(SH) | grep -c ': warning:')  notes: $$(shellcheck -f gcc $(SH) | grep -c ': note:')"
