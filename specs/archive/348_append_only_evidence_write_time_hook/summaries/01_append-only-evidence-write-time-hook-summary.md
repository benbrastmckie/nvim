# Implementation Summary: Task #348

- **Task**: 348 - Write-time PreToolUse Write|Edit hook enforcing append-only evidence files, the books extension first hook and its registration path
- **Status**: [COMPLETED]
- **Started**: 2026-10-06T00:00:00Z
- **Completed**: 2026-10-06T02:40:00Z
- **Effort**: ~2.75 hours
- **Dependencies**: None
- **Artifacts**: plans/01_append-only-evidence-write-time-hook.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Added the books extension's first hook: `validate-evidence-append-only.sh`, a PreToolUse
`Write|Edit` guard that refuses any write which alters or deletes a line already present in
`books/book-convention-evidence/NN-*.md`, while permitting a pure append, a new `NN-*.md`,
`README.md`, and every out-of-scope path. Built its forgery-probed fixture suite (29 assertions,
0 failed), wired the extension's manifest and a new bare settings fragment, and verified a real
deploy into the live consumer repository (`/home/benjamin/Projects/Logos/Verification`): the hook
file landed executable, its registration joined the existing `Write|Edit` matcher block bare (not
a second block), survived a second deploy unchanged (idempotent), and fired correctly against a
real committed evidence file (refusing a modification, allowing an append) without ever writing
to that file.

## What Changed

- `agent-system/extensions/books/hooks/validate-evidence-append-only.sh` — new file: the hook.
  Scope match on `books/book-convention-evidence/NN-*.md` (README.md and out-of-scope paths
  excluded before any subprocess runs); byte-string-only prefix/suffix predicate (never
  line-oriented, to catch the measured incident's buried-in-a-long-line shape); a FLOOR
  (HEAD content) / DISK (on-disk content) / TAIL (DISK minus FLOOR) split implementing Ruling 2
  (the uncommitted tail is freely editable, including in-place corrections, while the committed
  floor is immutable); two separately guarded fail-open cases (jq presence, payload JSON
  usability); and a three-fact rejection message naming the companion gate.
- `agent-system/extensions/books/scripts/tests/test-validate-evidence-append-only.sh` — new file:
  29-assertion fixture suite (11 behavioral cases, 3 forgery probes with a stub-applied check
  each, 2 fail-open cases, 2 buried-long-line cases, plus the 5 message-content assertions for
  Case 2). Drives the real hook as a subprocess; never sources it or reimplements its predicate.
- `agent-system/extensions/books/settings-hooks.json` — new file: the bare `PreToolUse`
  `Write|Edit` registration, matcher byte-identical to core's own block.
- `agent-system/extensions/books/manifest.json` — `provides.hooks` populated, the test entry
  appended to `provides.scripts`, and a new `merge_targets.settings` block (target
  `.claude/settings.json`, not `settings.local.json`) with a `_comment` recording Ruling 1.
- A redeployed `.claude/` tree in `/home/benjamin/Projects/Logos/Verification` carrying the hook
  and its registration (verified, not merely asserted — see Verification below).

## Decisions

- **Ruling 1** (registration target): `.claude/settings.json`, bare. `settings.local.json` is
  gitignored in the consumer repo and invisible to `verify-deploy.sh`'s registration gate; a
  guard over a tracked, shared archival record belongs in the tracked file, per the same test
  core's own `merge_targets.settings` comment applies to its WezTerm hooks.
- **Ruling 2** (trailing-uncommitted-entry): only lines present in `git show HEAD:<path>` are
  immutable; the uncommitted tail may be edited freely, including a genuine in-place correction
  (not merely an append). Implemented as two independent Edit-allow patterns — (a) a pure append
  relative to the current on-disk content, (b) a free edit whose `old_string` is a suffix of the
  tail alone (which by construction can never reach back into the floor) — because the dispatch's
  literally-suggested single-pattern shape (`old_string` suffix of the HEAD baseline) was found,
  during fixture authoring, to incorrectly refuse a legitimate in-place typo-fix in the
  uncommitted tail (that text never appears in the HEAD baseline at all). Fallback when the HEAD
  lookup is unavailable: floor and disk collapse to the same value, a strictly stricter prefix
  test, not fail-open.
- **Ruling 3** (fail-open guards): two separately guarded internal-error classes over the hook's
  one real dependency (`jq` presence; payload JSON usability), since the hook sources no shared
  library — creating one solely to manufacture a sourcing-failure mode would add a file outside
  the locked `file_scope` for no functional benefit.
- Fragment named `settings-hooks.json` at the extension root (not `settings-fragment.json` under
  a `merge-sources/` subdirectory), per the task's locked `file_scope`.

## Plan Deviations

- **Phase 1** (hook predicate): the Edit branch's design was revised during Phase 2's fixture
  authoring from the dispatch's literal suggested shape to the FLOOR/DISK/TAIL split described
  above under Ruling 2. The file edited (Phase 1's own deliverable) is unchanged in location and
  purpose; only its internal predicate logic was corrected before any fixture locked in behavior
  that would have been wrong. Re-verified with the full fixture suite (including the specific
  Ruling 2 ALLOW and its refusal companion) and shellcheck after the revision.
- No other deviations; all phases executed in full per plan, including the fail-open fixture
  redesign noted in Phase 3's progress file (a coreutils-only PATH rather than a fully blanked
  one, since blanking PATH entirely breaks the hook's own location-resolution coreutils calls
  before guard 1 ever runs — an implementation-detail correction, not a scope change).

## Verification

- Build: N/A (shell scripts + JSON manifests).
- Tests: `bash agent-system/extensions/books/scripts/tests/test-validate-evidence-append-only.sh`
  — 29 passed, 0 failed. `shellcheck` clean on both new shell files. `jq -e .` clean on both new
  JSON files. No task-number citation in any touched file under `agent-system/**`.
- Deploy verification (live, not asserted): hook file present and executable in the consumer
  repo; registration command bare (no `2>/dev/null || echo '{}'`); exactly one `Write|Edit` block
  containing both `validate-no-task-references.sh` and the new hook; hook-object count unchanged
  across a second deploy (idempotent); the deployed hook, driven with a real PreToolUse payload
  against a real committed evidence file, refused a modification (exit 2, three-fact message) and
  allowed an append (exit 0), with the real file's `git status` empty both before and after (never
  written to by the verification itself); `books/book-convention-evidence/` clean in `git status`
  afterward; `books/scripts/check-evidence-append-only.sh` reports 0 blocking findings.
- Files verified: Yes.

## Impacts

- Any future Write or Edit to a committed line in `books/book-convention-evidence/NN-*.md`, in
  any repository where the books extension is deployed, is now refused at write time rather than
  only discoverable later at commit time (when the only remedy is a history rewrite).
- `books/manifest.json` and `books/settings-hooks.json` are new durable deploy-wiring surfaces for
  the extension's future hooks, following the pattern this task established (bare registration,
  `.claude/settings.json` target, exact-matcher-string discipline).

## Follow-ups

- `verify-deploy.sh`'s registration gate checks only three hardcoded core event:script pairs, so
  this hook's registration is not regression-protected by deploy tooling. A generic "every
  `provides.hooks` entry is registered somewhere" check is a separate concern, deliberately out
  of scope here (recorded in the hook's own header, not re-derived or fixed by this task).
- Observed, unrelated: the consumer repository
  (`/home/benjamin/Projects/Logos/Verification`) carries substantial pre-existing uncommitted
  work from what appears to be a concurrently or recently active session (task-226 artifacts,
  `specs/books-evidence/.runs.lock` and `.observations.lock` untracked, a cosmetic
  `.claude/settings.json` key-reordering diff), and `verify-deploy.sh`'s runtime-file-tracking
  gate (gate 14) fails there for an unrelated reason (those two lock files not gitignored).
  Confirmed pre-existing (present before this task's deploy ran) and unrelated to this task's
  hook or registration; recorded here and in `issues.jsonl` per the Observation Duty, not treated
  as a blocker for this task's own acceptance criteria.

## References

- Plan: `specs/348_append_only_evidence_write_time_hook/plans/01_append-only-evidence-write-time-hook.md`
- Research: `specs/348_append_only_evidence_write_time_hook/reports/01_append-only-evidence-write-time-guard.md`
- Hook: `agent-system/extensions/books/hooks/validate-evidence-append-only.sh`
- Fixture suite: `agent-system/extensions/books/scripts/tests/test-validate-evidence-append-only.sh`
- Companion commit-time gate (input, not modified): `books/scripts/check-evidence-append-only.sh`
  (consumer repository)
