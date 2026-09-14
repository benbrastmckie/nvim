# Implementation Summary: Task #156

- **Task**: 156 - Surface a Comparator doctor mode and document what a green result does and does not certify
- **Status**: [COMPLETED]
- **Started**: 2026-09-07T00:00:00Z
- **Completed**: 2026-09-07T01:15:00Z
- **Effort**: ~1.25 hours
- **Dependencies**: 155 (completed — `lean-comparator-run.sh`, advisory `--compare` gate, `comparator-integration.md`)
- **Artifacts**: plans/01_comparator-doctor-trust-boundary.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Added a `doctor` mode to `/lean` (implemented inline in `skill-lean-version/SKILL.md` and
mirrored in `commands/lean.md`) that probes for the four Comparator binaries and checks the C3
version-coupling constraint — that `lean4export` was built against the *target project's*
toolchain, not Comparator's own — via a bounded 5-level directory walk-up for a sibling
`lean-toolchain` file. Wrote `context/project/lean4/tools/comparator-guide.md`, the operator-facing
trust-model document stating plainly what a green Comparator result does and does not certify,
quoting the upstream README verbatim throughout. Added an advisory-only policy note to
`proof-debt-policy.md` and registered the new file across the extension's declared surface
(`index-entries.json`, `EXTENSION.md`, `README.md`) so `check-extension-docs.sh` stays green.

## What Changed

- `agent-system/extensions/lean/context/project/lean4/tools/comparator-guide.md` — new file. The
  trust-model document: what a green result certifies (three upstream-quoted properties), what it
  does NOT certify (Challenge correctness, definition-hole solutions with the RiemannHypothesis
  gaming example, conditional guarantee), the six upstream assumptions (2 and 4 flagged as live
  concerns), the TCB statement, version coupling (C3), current gate strength, and a pointer to
  `comparator-integration.md`.
- `agent-system/extensions/lean/context/project/lean4/README.md` — added a `Key Files` bullet
  linking the new guide.
- `agent-system/extensions/lean/skills/skill-lean-version/SKILL.md` — added `doctor` to the mode
  parser and router, and a new `## Doctor Mode` section implementing `resolve_binary()` (reusing
  `lean-comparator-run.sh`'s exact four env-var names), `find_lean_toolchain_upward()` (bounded
  5-level walk-up), `check_lean4export_version()` (four-valued verdict: `matched` / `mismatched`
  / `UNKNOWN (cannot verify)` / not-applicable), and the doctor report driver.
- `agent-system/extensions/lean/commands/lean.md` — mirrored the doctor mode: modes table,
  `argument-hint`, STEP 1/STEP 2 entries, new `STEP 3D: Doctor Mode` (byte-identical bash block to
  the skill's), an `Examples` entry, and a `Doctor Output` example showing all three named
  acceptance states.
- `agent-system/extensions/lean/context/project/lean4/standards/proof-debt-policy.md` — new
  `### What Comparator Adds (Advisory Today)` subsection under `## Completion Gates`, enumerating
  the five actual Final Verification Stage mechanisms (sorry census, vacuous-definition grep,
  axiom grep, plan-compliance grep, unsandboxed `lake build`), the specific hole each has, what
  Comparator's checks would close, and an explicit statement that `--compare` is advisory only
  today and the existing checks remain the operative zero-debt gate.
- `agent-system/extensions/lean/index-entries.json` — new entry for
  `project/lean4/tools/comparator-guide.md` (following the `comparator-integration.md` entry as
  the model); `line_count` populated via `generate-context-line-counts.sh --write` (also
  corrected `line_count` for the `README.md` and `proof-debt-policy.md` entries, which had drifted
  from earlier edits in this round).
- `agent-system/extensions/lean/EXTENSION.md` — added the `doctor` mode row to the Commands table
  and the guide to Context Pointers.
- `agent-system/extensions/lean/README.md` — updated the `/lean` command row and the `### /lean`
  section to name the `doctor` mode.
- `agent-system/extensions/lean/manifest.json` — unchanged. Confirmed no new `provides` entry is
  needed: `comparator-guide.md` falls under the existing `"project/lean4"` context directory
  entry, and no new script/skill/command file was introduced (the Phase 3 contingency to extract a
  standalone script was not triggered).

## Decisions

- No new script for the doctor mode — implemented inline in `SKILL.md`/`lean.md`, matching
  check/upgrade/rollback and the plan's file scope.
- The C3 version-match check uses a bounded directory walk-up for a sibling `lean-toolchain` file,
  not binary introspection (confirmed unworkable against real binaries during research).
- `UNKNOWN (cannot verify)` is treated as a distinct, unmistakable fourth outcome — never rendered
  with OK/pass/green wording — in both the doctor's own output and `comparator-guide.md`.

## Plan Deviations

- **Task 3.6** (contingency to extract a standalone `lean-comparator-doctor.sh` script) skipped:
  the inline doctor block, extracted verbatim to a scratch file and run via `env -i ... bash`
  against four constructed fixtures, demonstrated all four states cleanly on the first attempt —
  the contingency condition (demonstration proving awkward from the inline block) never arose.
- **Task 4.1** (proof-debt-policy subsection) altered: the plan's Scope Hypothesis asserted the
  current gate consists of exactly three greps plus a build; re-reading
  `lean-implementation-agent.md`'s Final Verification Stage showed a fifth mechanism — a
  plan-compliance spot-check grep — which was included (with its own documented hole) per the
  plan's own instruction to enumerate whatever is actually there.

## Verification

- Build: N/A (no Lean/lake build involved; this is a meta/documentation task)
- Tests: N/A (no automated test suite for markdown/skill-file changes; verification was direct
  execution — see below)
- Files verified: Yes

Verification performed directly:
- `bash -n` over both extracted doctor bash blocks (SKILL.md and commands/lean.md): clean, and the
  two blocks are byte-identical (91 lines each, `diff` empty) — no drift between skill and
  command.
- The four `COMPARATOR_*` env-var names in the doctor blocks match `lean-comparator-run.sh`'s
  `resolve_binary()` call sites exactly.
- `grep -n 'UNKNOWN (cannot verify)'` finds the literal label in both files; `grep -niE
  'unknown.*(ok|pass|green)'` finds nothing in either.
- `bash agent-system/extensions/core/scripts/check-extension-docs.sh` (deployed copy):
  `lean PASS`, and `PASS: all extensions OK` overall.
- `jq empty` on `index-entries.json` and `manifest.json`: both parse cleanly; the new entry's
  `line_count` (110) matches `wc -l` on `comparator-guide.md`.
- `grep -nE '\btasks? [0-9]+\b|\(task [0-9]+\)'` across all nine touched extension files: no
  matches.
- `git status --short` after all five phase commits: changes confined to
  `agent-system/extensions/lean/**` and `specs/156_document_comparator_trust_boundary/**` (plus
  pre-existing, unrelated dirty files from concurrent sessions/tasks); nothing under `.claude/**`.

### Doctor state demonstrations (real execution against constructed fixtures, session scratchpad only — no fixture files entered the repository)

**State A — all present, `lean4export` version matched:**
```
Comparator Environment Doctor
==============================

comparator: present (<fixture>/bin/comparator) [override: COMPARATOR_BIN]
landrun: present (<fixture>/bin/landrun) [override: COMPARATOR_LANDRUN]
lean4export: present (<fixture>/stateA/.lake/build/bin/lean4export) [override: COMPARATOR_LEAN4EXPORT]
nanoda_bin: not found [override: COMPARATOR_NANODA] (optional)

lean4export version check (C3):
  matched
    lean4export toolchain (<fixture>/stateA/lean-toolchain): leanprover/lean4:v4.27.0-rc1
    target project toolchain (lean-toolchain): leanprover/lean4:v4.27.0-rc1
```

**State B — a binary missing (`lean4export`):**
```
Comparator Environment Doctor
==============================

comparator: present (<fixture>/bin/comparator) [override: COMPARATOR_BIN]
landrun: present (<fixture>/bin/landrun) [override: COMPARATOR_LANDRUN]
lean4export: MISSING [override: COMPARATOR_LEAN4EXPORT]
nanoda_bin: not found [override: COMPARATOR_NANODA] (optional)

lean4export version check (C3):
  not applicable — lean4export is absent
```

**State C — present but mismatched (the state that matters):**
```
Comparator Environment Doctor
==============================

comparator: present (<fixture>/bin/comparator) [override: COMPARATOR_BIN]
landrun: present (<fixture>/bin/landrun) [override: COMPARATOR_LANDRUN]
lean4export: present (<fixture>/stateC/.lake/build/bin/lean4export) [override: COMPARATOR_LEAN4EXPORT]
nanoda_bin: not found [override: COMPARATOR_NANODA] (optional)

lean4export version check (C3):
  mismatched
    lean4export toolchain (<fixture>/stateC/lean-toolchain): leanprover/lean4:v4.34.0-rc2
    target project toolchain (lean-toolchain): leanprover/lean4:v4.27.0-rc1
    remedy: confirm manually that lean4export at <fixture>/stateC/.lake/build/bin/lean4export was built against leanprover/lean4:v4.27.0-rc1, or install a matching lean4export and set COMPARATOR_LEAN4EXPORT
```

**State D — walk-up finds nothing (`UNKNOWN (cannot verify)`):**
```
Comparator Environment Doctor
==============================

comparator: present (<fixture>/bin/comparator) [override: COMPARATOR_BIN]
landrun: present (<fixture>/bin/landrun) [override: COMPARATOR_LANDRUN]
lean4export: present (<fixture>/stateD/no_toolchain_here/deep/bin/lean4export) [override: COMPARATOR_LEAN4EXPORT]
nanoda_bin: not found [override: COMPARATOR_NANODA] (optional)

lean4export version check (C3):
  UNKNOWN (cannot verify)
    reason: no lean-toolchain found within 5 parent directories of <fixture>/stateD/no_toolchain_here/deep/bin/lean4export
    remedy: confirm manually that lean4export at <fixture>/stateD/no_toolchain_here/deep/bin/lean4export was built against the target project's toolchain
```
(`<fixture>` paths were absolute session-scratchpad paths at execution time; a `grep -niE
'unknown.*(ok|pass|green)'` against the State D transcript found nothing.)

## Impacts

- Operators (and future maintainers) now have a single command, `/lean doctor`, to check whether
  the Comparator environment is usable before invoking `lean-comparator-run.sh --compare`, and a
  single document, `comparator-guide.md`, explaining exactly what a green result means and does
  not mean.
- `proof-debt-policy.md` now names Comparator's relationship to the zero-debt gate explicitly,
  closing a documentation gap without changing runtime enforcement — `--compare` remains advisory.
- No agent, skill routing, task type, or gate-strength behavior changed; this task is purely
  additive documentation and a reporting-only command mode.

## Follow-ups

- None. Promotion of `--compare` to a hard completion gate remains a separate, later,
  evidence-based decision, explicitly out of scope here per the plan's Non-Goals.

## References

- `specs/156_document_comparator_trust_boundary/plans/01_comparator-doctor-trust-boundary.md`
- `specs/156_document_comparator_trust_boundary/reports/01_comparator-doctor-trust-boundary.md`
- `agent-system/extensions/lean/context/project/lean4/tools/comparator-guide.md`
- `agent-system/extensions/lean/context/project/lean4/domain/comparator-integration.md`
- `agent-system/extensions/lean/scripts/lean-comparator-run.sh`
