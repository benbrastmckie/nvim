# Implementation Summary: Enforce the State-Write Convention Over the Python Channel

- **Task**: Extend the state-writer boundary lint to the Python/ad hoc JSON re-serialization channel
- **Status**: [COMPLETED]
- **Started**: 2026-11-06
- **Completed**: 2026-11-06
- **Effort**: ~6 hours
- **Dependencies**: None
- **Artifacts**: plans/01_python-state-write-enforcement.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Closed the mechanical enforcement gap on the Python/interpreter re-serialization channel for
`specs/state.json` writes. The existing lint (gate 12) could only see a hand-rolled
`jq ... > tmp && mv` sequence; a Python `json.load`/`json.dump` in-place write through an
already-open file object carried no `mv` and no shell redirect, so it was invisible to the
lint's regex. All six plan phases completed: a shared detection library, lint-side test
coverage for every named shape and control, an executed corruption-reproduction fixture, a
companion write-time Bash hook (for the shape a content lint provably cannot see), hook
registration plus a prose pointer, and a final redeploy with scoped gate verification.

## What Changed

- `agent-system/extensions/core/scripts/lib/state-writer-boundary-patterns-lib.sh` — new shared
  predicate library: the candidate limb (`open\([^)]*state\.json`) and a write-mode classifier
  accepting `w`, `a`, `r+`, `w+`, `a+`, `x` as write-capable (rejecting bare/no-mode and plain
  `r`), consumed by both the lint and the new hook.
- `agent-system/extensions/core/scripts/lint/lint-state-writer-boundary.sh` — sourced the new
  library, appended its candidate limb to `CANDIDATE_PATTERN`, added a `classify_line` branch
  delegating to the library, extended the remedy `Fix:` message, added an `EXCLUDED_FILES`
  entry for the new library and for the new hook test, and updated the `KNOWN LIMITATION`/
  `DETECTION MODEL` header paragraphs to name the Python channel.
- `agent-system/extensions/core/scripts/tests/test-lint-state-writer-boundary.sh` — 20 new
  cases: every named flagged shape (default-`ensure_ascii`, explicit `ensure_ascii=False`, the
  two-line `with open()` idiom, archive and vault-root targets), the no-mode/`'r'` controls with
  asserted `EXEMPT` reason text, a real-literature-extension-writer control (enumerated via
  `git grep`, 10 tracked files, not the 3 the Scope Hypothesis assumed), and the executed
  corruption-reproduction fixture (a default-`ensure_ascii` round-trip producing a whole-file
  diff vs. a `jq --arg` transform leaving untouched rows byte-identical).
- `agent-system/extensions/core/hooks/validate-no-python-state-write.sh` — new `PreToolUse` Bash
  hook: scans `tool_input.command` line-by-line against the shared library's predicate, blocks
  via `exit 2` + stderr naming `state-write.sh`, fails OPEN on a missing/unsourceable library.
- `agent-system/extensions/core/scripts/tests/test-validate-no-python-state-write.sh` — new
  both-polarity suite (11 cases): 5 positive (live/archive/vault-root/with-open-idiom/
  ensure_ascii=False), 5 negative (read-only variants, a real `state-write.sh` call, an
  unrelated command, an unrelated JSON target), plus the fail-open pin.
- `agent-system/extensions/core/merge-sources/settings-hooks.json` — registered the new hook in
  the existing `Bash` `PreToolUse` array as a blocking guard (no suppression wrapper).
- `agent-system/extensions/core/context/patterns/task-lock.md` — one pointer sentence in the
  State-Write Convention section naming both mechanical enforcers (gate 12 and the new hook).
- `agent-system/extensions/core/manifest.json` — `provides.scripts`/`provides.hooks` entries for
  all three new files.
- Regenerated `.claude/` deploy tree (two redeploys; the second after an exec-bit fix).

## Decisions

- Keyed detection on a write-capable `open()` call rather than a bare `json.dump`/`json.dumps`
  token, per the research measurement: this produces zero new candidate matches in the live
  tree beyond the library and lint themselves, where a bare-token approach would false-positive
  on every legitimate JSON writer (including the literature extension's).
- Mode-based detection fires regardless of `ensure_ascii`, since an `ensure_ascii=False` write is
  still an unsynchronized, non-mutex-guarded read-modify-write that bypasses `state-write.sh`'s
  staging and validation — fixing only the escaping half would leave the interleaving/lost-update
  half of the hazard unaddressed.
- `r+` counts as write-capable: the in-place rewrite idiom (`open(path, "r+")` -> `json.load` ->
  `seek(0)` -> `json.dump`) backs both read and write through one `open()` call.
- The write-time hook was judged warranted (not just the content lint), per the dispatch's own
  reasoning: the originating incident was a live Bash-tool `python3` invocation that never
  landed as a file under the scanned tree, so a content lint alone is evidenced-insufficient
  against the exact shape that raised this work.
- The hook blocks via `exit 2` + stderr (never `permissionDecision: deny`) and fails OPEN on a
  missing library — the opposite polarity from the lint (a deploy gate, which fails LOUD on the
  same condition), since a silently-skipped lint would ship unenforced while a failed-open hook
  only narrows one call's coverage.

## Plan Deviations

- **Real literature-extension-writer control case** (Phase 2): altered from the Scope
  Hypothesis's assumed 3 real writer scripts to a 10-file `git grep` enumeration. A plain
  recursive `grep` over the directory nondeterministically swept in the extension's own
  gitignored, environment-local venv's vendored third-party packages (pymupdf, networkx,
  onnxruntime, ...); `git grep` (tracked files only) gives a deterministic, correct file set.
- **Complementary `--argjson`-style transform** (Phase 3): implemented via `jq --arg` rather
  than `--argjson`, since the appended `file_scope` value is a plain string, not a JSON-typed
  value — same `state-write.sh` bindings mechanism, correct flag for this value's type.
- **Full gate battery** (Phase 6, tasks 3/5): deferred to the batch stage per this dispatch's
  own Batch Gate Deferral directive (this task is one of several `implement`-phase dispatches in
  one multi-task `/orchestrate` batch invocation). Ran the scoped `verify-deploy.sh
  --only-gate 12` (PASS) and `run-all.sh --only
  test-lint-state-writer-boundary.sh,test-validate-no-python-state-write.sh` (2 passed, 0 failed)
  instead of the plan's literally-worded full-battery commands.

## Verification

- Build: N/A (shell scripts, no compiled build step)
- Tests: `test-lint-state-writer-boundary.sh` 28/28 PASS; `test-validate-no-python-state-write.sh`
  11/11 PASS; both confirmed against the redeployed `.claude/` tree, not just the source store.
- Negative control: temporarily reverted Phase 1's `classify_line` branch and confirmed the new
  lint cases FAIL (exit 0 instead of 1) without it, then restored and reconfirmed green —
  proving the cases exercise the new code rather than passing vacuously.
- `lint-shellcheck.sh`, `lint-hook-registration-paths.sh`, `lint-test-harness-adoption.sh`,
  `check-task-references.sh`, `check-record-versioning.sh` all clean on every new/edited file.
- Gate 12 measured runtime: 3.610s, then 4.985s after the exec-bit-fix redeploy — both well
  within the registry's declared 30s timeout (consistent with the research's pre-change 4.8s
  baseline).
- Files verified: Yes — all new files present under the deployed `.claude/` tree, hook
  registration confirmed in deployed `settings.json`.

## Impacts

- An agent reaching for a Python `json.dump`/`json.load` in-place rewrite of `specs/state.json`
  (or its archive/vault-root counterparts) is now caught two ways: mechanically at lint time
  (gate 12, for any shape landing in a tracked `.md`/`.sh` file) and at write time (the new hook,
  for a live Bash-tool `python3` invocation that never lands as a file — the exact shape that
  raised this work and that the lint alone could not have stopped).
- No existing jq-channel detection behavior changed: Cases 1-6 of the pre-existing lint suite
  pass unmodified, confirming the jq-shaped `CANDIDATE_PATTERN` limbs and `classify_line`
  branches are byte-identical to before this work.
- The three literature-extension Python JSON writers research originally named (plus 7 more
  found by the corrected enumeration) remain unflagged by content, with no allowlist marker
  needed — they simply never match the new predicate's `state.json`-in-`open()` substring test.

## Follow-ups

- The full, unscoped gate battery and shell-suite run are deferred to this `/orchestrate`
  batch's single end-of-invocation pass (per the Batch Gate Deferral directive); that pass's
  triage against the dispatch's known-unrelated list (gate 3, gate 20, three gate 8 suites) is
  not independently repeated here.
- A new `scripts/tests/*.sh` suite file created via a file-write tool does not inherit an
  executable bit automatically; a future similar addition should set it explicitly in the source
  store before its first deploy, or `run-all.sh` will SKIP it silently-but-loudly rather than
  running it. (Caught and fixed in Phase 6 for this task's own new file; recorded here as a
  general caution for future similar work, not a current defect.)

## References

- Plan: `specs/419_enforce_state_write_convention_python_channel/plans/01_python-state-write-enforcement.md`
- Research report: `specs/419_enforce_state_write_convention_python_channel/reports/01_python-state-write-lint-extension.md`
- Dispatch file: `specs/419_enforce_state_write_convention_python_channel/.dispatch/19.md`
