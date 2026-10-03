# Shell Strict-Mode Convention (core)

Every shell script under `agent-system/extensions/**` falls into exactly one of three strict-mode
classes. This doc states the admission test for each class and records the live classification of
every script that does not already carry `set -euo pipefail`, so a migration only ever flips a
script that has been shown safe rather than guessed safe.

**Default for new scripts**: a new script defaults to Class A (`set -euo pipefail`) unless it can
justify Class B or Class C against the admission tests below. Silence is not a justification —
every non-Class-A script needs a recorded reason.

## The three classes

### Class A — migrate to `set -euo pipefail`

Ordinary scripts with no counter idiom and no documented non-`-e` dependency. A command whose
failure is expected to be tolerated is explicitly guarded (`if`, `&&`, `||`, `while`); nothing in
the script relies on falling through past an unguarded nonzero exit.

### Class B — deliberately `set -uo pipefail`, do not migrate

Counter-idiom harnesses whose correctness *requires* continuing past a failure to produce an
accurate summary, or scripts whose own documented purpose is "keep going and report everything
that's wrong." Adding `-e` to a Class B script would silently truncate its output at the first
failure — a report showing partial results with no indication anything was cut short.

**Admission test**: the script accumulates a `PASSED`/`FAILED` (or equivalent) counter across
multiple independent checks/cases and reports a summary at the end, OR its header explicitly
documents "don't exit on error, report everything" as the design intent.

### Class C — deliberately no `set` line, do not migrate

Scripts that are **sourced** (never executed directly) into a caller's shell. Per
`scripts/lib/manifest-routing-lib.sh`'s and `scripts/lib/common.sh`'s own contract, sourcing must
never change the calling shell's error-handling behavior — so these files set no shell options at
all, regardless of how disciplined their own internal control flow is.

**Admission test**: the script's own header/usage comment says "source this file" (or it is
invoked exclusively via `. "$path"` / `source "$path"` at every call site found live), and it is
never invoked as `bash script.sh` or `./script.sh` in its own right.

## Classification of the `set -uo pipefail` population

Re-derive live with `grep -rl '^set -uo pipefail' --include="*.sh" agent-system/extensions/`.

### Class B — test suites (naming-convention admission, `shell-script-testing.md`)

Every `scripts/tests/test-*.sh` and flat `scripts/test-*.sh` file uses the `PASSED`/`FAILED` +
`pass()`/`fail()`/`info()` idiom mandated by `shell-script-testing.md`'s helper-naming convention.
`-e` would abort a suite at its first failing case instead of reporting the full count:

`test-conflict-predicate.sh`, `test-four-tier-conflict.sh`, `test-session-registry.sh`,
`test-session-runtime-files.sh`, `test-state-write-concurrency.sh`,
`test-state-write-regen-timing.sh`, `test-task-lock-reap.sh`, `tests/test-census-count.sh`,
`tests/test-claude-refresh-matcher.sh`, `tests/test-common-lib.sh`,
`tests/test-corroborate-phase-counts.sh`, `tests/test-deploy-propagation.sh`,
`tests/test-errors-append.sh`, `tests/test-git-commit-scoped.sh`,
`tests/test-handoff-reader-parity.sh`, `tests/test-index-entries-schema.sh`,
`tests/test-lint-agent-contracts.sh`, `tests/test-loop-guard-staleness.sh`,
`tests/test-orchestrate-triage-classify.sh`, `tests/test-phase-heading-patterns.sh`,
`tests/test-reconcile-handoff-status.sh`, `tests/test-resume-scan-nonconformance.sh`,
`tests/test-routing-resolution.sh`, `tests/test-validate-handoff.sh`,
`tests/test-validate-no-task-references.sh` (all `core/scripts/`), and
`literature/scripts/tests/test-literature-convert.sh`.

### Class B — harness/report scripts (counter or "report everything" admission)

- `scripts/tests/run-all.sh` — the suite runner itself; per its own design (recorded when it was
  written), it must not abort on the first failing suite or it cannot print a `N passed, M
  failed` summary.
- `scripts/verify-deploy.sh` — accumulates a gate-by-gate PASS/FAIL report across 8 gates; the
  same summary-truncation hazard applies.
- `scripts/check-extension-docs.sh`, `scripts/check-runtime-file-tracking.sh`,
  `scripts/check-task-references.sh` — each walks a population of files/extensions and reports
  every finding, not just the first.
- `scripts/lint/lint-routing-wiring.sh` — same report-everything shape as the `check-*.sh` family.

### Class A candidates — ordinary scripts (individually audited)

No counter idiom, no "report everything" header. `-e`-hostile constructs checked for each: bare
non-`if`-guarded command chains, functions whose nonzero return is a meaningful signal, and
`grep`/`jq` calls whose empty/no-match result is a normal outcome. None found unguarded in the
scripts below — every conditional read is already inside `if`/`||`/`&&`, or reads via
`2>/dev/null || true` / `2>/dev/null || echo <default>`.

**Phase 6 batch (highest-risk state mutators — migrated in that phase, not here)**:
`scripts/state-write.sh`, `scripts/task-lock.sh`, `scripts/git-commit-scoped.sh`,
`scripts/orchestrate-batch-admit.sh`, `scripts/orchestrate-predispatch-review.sh`.

**Phase 7 remainder (core)**:
- `scripts/census-count.sh`, `scripts/claude-refresh.sh`, `scripts/deploy-headless.sh`,
  `scripts/generate-context-line-counts.sh`, `scripts/git-snapshot.sh`,
  `scripts/lifecycle-notify.sh`, `scripts/orchestrate-dry-run-report.sh`,
  `scripts/orchestrate-recover-outcome.sh`, `scripts/orchestrate-triage-classify.sh`,
  `scripts/reap-session-runtime-files.sh`, `scripts/reconcile-artifacts.sh` — ordinary scripts,
  no load-bearing exit-code contract with an external caller beyond "0 succeeded, nonzero
  failed", which `-e` preserves.
- `hooks/claude-stop-notify.sh`, `hooks/memory-nudge.sh`, `hooks/tts-notify.sh`,
  `hooks/events-log-artifact.sh`, `hooks/events-log-lifecycle.sh` — notification/event-logging
  hooks, already heavily `|| true`-guarded (fail-open by construction); low risk.

**Phase 7 remainder — EXTRA CARE (PreToolUse/PostToolUse gates with a load-bearing exit code)**:
these are Class A (no counter idiom, so the plain admission test passes), but per this doc's own
"hooks under `core/hooks/`" caution and Phase 7's task list, each needs its own `-e`-hostility
walk immediately before the flip, not just at classification time, because `exit 2` here means
"deny the tool call" and an accidental fail-closed (or fail-open) flip is a behavior change, not
just a style change:
- `hooks/guard-destructive-git.sh` — `exit 2` denies a destructive git command; already
  documented to never set `MATCHED`/`REASON` on its own early-exit paths.
- `hooks/validate-no-task-references.sh` — `exit 2` denies a citation violation; **documented to
  fail OPEN (exit 0, stderr warning) if its own pattern library cannot be sourced** — `-e` must
  not convert that fail-open path into a fail-closed abort.
- `hooks/validate-handoff-location.sh`, `hooks/validate-meta-write.sh`,
  `hooks/validate-plan-write.sh` — same `exit 2`-denies shape as the two above.
- `email/hooks/mail-guard.sh` — the wrapper-only email-mutation allowlist gate; same
  exit-code-is-a-decision shape as the core PreToolUse hooks above.

If any of the above resists a clean `-e`-hostility audit when Phase 7 actually attempts it, Phase
7 reclassifies it Class B in this doc with the observed evidence, per that phase's own task list
— this doc is not re-litigated retroactively for a reclassification that hasn't happened yet.

### Class A candidates — non-core extensions (classified for completeness; migration out of scope)

Phases 6-8's `Files to modify` lists are core-only. These are classified here so the tree-wide
population in `verify-deploy.sh`'s eventual scope is fully accounted for, but migrating them is
left as a residual for a future task, not this plan's Phase 6/7:

`lean/scripts/lean-sorry-census.sh`, `literature/scripts/literature-briefing-invoke.sh`,
`literature/scripts/literature-convert.sh`, `literature/scripts/literature-pyenv-provision.sh`,
`memory/scripts/bootstrap-harvest.sh`, `memory/scripts/bootstrap-harvest-attribution.sh`,
`memory/scripts/bootstrap-harvest-history.sh`, `memory/scripts/bootstrap-harvest-transcripts.sh`.

## Classification of the no-`set`-line population

Re-derive live: files under `agent-system/extensions/**/*.sh` with no `^set -` line at all.

### Class C — sourced-only libraries and helpers

Per each file's own header ("Sourced (never executed) by...", "Usage: source this file..."), and
confirmed by grep of every call site found live — none invoke the file via `bash`/`./`:

- `scripts/lib/common.sh`, `scripts/lib/file-scope-overlap.sh`,
  `scripts/lib/manifest-routing-lib.sh`, `scripts/lib/phase-heading-patterns.sh`,
  `scripts/lib/task-reference-patterns.sh` — the library convention this doc's own admission test
  is modeled on.
- `scripts/command-gate-in.sh`, `scripts/command-route-agent.sh`,
  `scripts/deploy-root-guard.sh`, `scripts/parse-command-args.sh`, `scripts/skill-base.sh` —
  sourced into a command/skill's own shell; `common.sh`'s header already documents
  `command-gate-in.sh` and `skill-base.sh` as confirmed-unchanged by sourcing (see that file's
  `$-`/`set -o` note).
- `hooks/wezterm-utils.sh` — "source this file in WezTerm hooks to get shared TTY discovery."

**Note on `deploy-root-guard.sh`'s callers**: several `scripts/*.sh` files source it via
`. "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1` — the `|| exit 1` is `-e`-safe by construction
(a command whose failure is tested by `||` never trips the `-e` trap), so a Class A flip on any of
those *callers* does not disturb this guard pattern. This was flagged as a risk during planning
and is recorded here as confirmed-safe rather than re-litigated in Phase 6/7.

### Class B — report-everything / no-set-line by design

- `scripts/validate-wiring.sh` — header states explicitly: "Don't exit on error - we want to
  report all issues." Same report-everything shape as the `check-*.sh` family above, just missing
  the `set -uo pipefail` line the others carry. Do not add `-e`; adding the missing
  `set -uo pipefail` line (to make its shell-option posture explicit rather than merely absent)
  is a reasonable opportunistic improvement for a future pass, not required by this phase.
- `literature/scripts/test-lit-pipeline.sh` — a broad pipeline test suite (see
  `shell-script-testing.md`'s location-rule distinction between narrow and pipeline suites); its
  counter/report shape is the same Class B rationale as the core test suites even though it is
  currently missing an explicit `set -uo pipefail` line. Same opportunistic-improvement note as
  `validate-wiring.sh` applies.

### Class A candidates — ordinary hooks (no sourcing contract, no counter idiom)

- `hooks/log-session.sh`, `hooks/post-command.sh` — trivial SessionStart/Stop loggers, unconditional
  `exit 0` at the end, no unguarded command whose failure matters.
- `hooks/subagent-postflight.sh` — every command whose exit status is a meaningful signal is
  already tested by `if`/`if !`; the `check_loop_guard` function's `return 1` "allow stop" signal
  is always called as `if ! check_loop_guard`, which is `-e`-exempt. Same EXTRA CARE caveat as the
  other hook gates above applies at actual-flip time, since its `{"decision": "block", ...}` /
  `{}` output is load-bearing for the Claude Code hook framework.
- `hooks/validate-state-sync.sh` — linear `if`-guarded checks ending in explicit `exit 0`/`exit 1`;
  same EXTRA CARE caveat (PostToolUse, though its own exit codes are advisory-only per its
  `additionalContext` shape rather than a block/allow decision).

## Confirmed-safe patterns (do not re-litigate)

- **`|| exit 1` after a source line** (`deploy-root-guard.sh` callers): `-e`-safe by construction;
  see the Class C note above.
- **`update-task-status.sh`**: already carries `set -euo pipefail` prior to this plan; excluded
  from both populations and from Phase 6/7's candidate lists.
- **`scripts/lib/*.sh` sourcing does not change caller shell-option state**: proven by
  `tests/test-common-lib.sh`'s `$-`/`set -o` before/after assertions (see Phase 2/3's summary).

## Related

- `context/standards/shell-script-testing.md` — owns the Class B test-suite helper-naming and
  counter-idiom rationale in full; this doc cross-references it rather than restating it.
- `scripts/lib/common.sh` — the Class C contract this doc's admission test is modeled on; its own
  header states the "sourcing must never change caller shell-option state" rule directly.
