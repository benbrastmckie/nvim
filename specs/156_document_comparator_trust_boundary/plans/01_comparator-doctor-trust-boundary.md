# Implementation Plan: Task #156

- **Task**: 156 - Surface a Comparator doctor mode and document what a green result does and does not certify
- **Status**: [IMPLEMENTING]
- **Effort**: 4.5 hours
- **Dependencies**: 155 (completed — `lean-comparator-run.sh`, advisory `--compare` gate, `comparator-integration.md`)
- **Research Inputs**: specs/156_document_comparator_trust_boundary/reports/01_comparator-doctor-trust-boundary.md
- **Artifacts**: plans/01_comparator-doctor-trust-boundary.md (this file)
- **Standards**:
  - .claude/context/formats/plan-format.md
  - .claude/context/standards/status-markers.md
  - .claude/rules/artifact-formats.md
  - .claude/rules/state-management.md
  - .claude/rules/source-store-deploy-boundary.md
  - .claude/rules/no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Two deliverables, both operator-facing and both living in the lean extension's source store: a
`doctor` mode on `/lean` that probes for the four Comparator binaries and checks the C3
version-coupling constraint (`lean4export` built against the *target project's* toolchain, not
Comparator's own), and `context/project/lean4/tools/comparator-guide.md`, the trust-model
document that states without overclaiming what a green Comparator result does and does not
certify. A policy note in `proof-debt-policy.md` records what Comparator adds while making
unmistakable that the greps remain the operative zero-debt gate today, and the extension surface
(EXTENSION.md, README.md, manifest.json, index-entries.json) is updated so a fresh deploy passes
`check-extension-docs.sh`. Definition of done: the doctor demonstrably distinguishes the three
named states (all-present-and-matched, binary-missing, present-but-mismatched), the guide carries
an explicit "what this does NOT certify" section, and doc-lint is green.

### Research Integration

The research report settles three questions this plan builds on directly:

1. **The C3 version check cannot use binary introspection.** `lean4export` has no
   `--version`/`--help` flag (confirmed upstream), and the real `comparator` binary now installed
   on this host statically links the Lean runtime with no elan-toolchain path visible to `ldd`
   (confirmed live). The one technique that survives is a **bounded (5-level) directory walk-up
   from the resolved binary's realpath looking for a sibling `lean-toolchain` file**, diffed
   against the target project's own `lean-toolchain`. A fourth outcome — no `lean-toolchain`
   discoverable within the bound — MUST be reported as `UNKNOWN (cannot verify)`, never as a pass.
2. **No new script.** The doctor is inline bash inside `skill-lean-version/SKILL.md` as a fourth
   arm of its existing `case "$mode"` dispatch, mirrored in `commands/lean.md` as `STEP 3D`,
   consistent with how `check`/`upgrade`/`rollback` are already built and with the task's declared
   `file_scope` (nine files, none a new script).
3. **Binary resolution has a reusable pattern.** `lean-comparator-run.sh`'s `resolve_binary()`
   already uses the four env-var names `COMPARATOR_BIN`, `COMPARATOR_LANDRUN`,
   `COMPARATOR_LEAN4EXPORT`, `COMPARATOR_NANODA`. The doctor reuses those exact names.

The report also supplies the upstream README's six assumptions, the certification wording, the
definition-hole caveat, the TCB sentence, and the version-coupling sentence — all fetched
verbatim this round, so the guide can quote rather than paraphrase.

### Prior Plan Reference

No prior plan. `plans/` was empty at dispatch time; this is round 1.

### Roadmap Alignment

No ROADMAP.md found at `specs/ROADMAP.md`. No roadmap phases added.

## Goals & Non-Goals

**Goals**:
- A `/lean doctor` mode that reports, per binary, presence + resolved path + the override env var
  checked, and for `lean4export` a four-valued version verdict (`matched` / `mismatched` /
  `UNKNOWN (cannot verify)` / not-applicable-because-absent).
- Demonstrate — not assert — the three acceptance states, especially present-but-mismatched.
- `comparator-guide.md`: an operator-facing trust-model document whose structural centerpiece is
  "what this does NOT certify", quoting upstream verbatim.
- A `proof-debt-policy.md` addition that cannot be misread as claiming a hard Comparator gate
  exists.
- A fresh deploy passing `check-extension-docs.sh` (Rules R and T) with the new entries.

**Non-Goals**:
- Changing the gate strength. `--compare` stays advisory; promotion to a hard gate is a separate,
  later, evidence-based decision and must not be pre-empted anywhere in these deliverables.
- Re-litigating or re-documenting the clean-room worktree design, verdict vocabulary, or
  `--compare` threading — those live in `comparator-integration.md`; the guide cross-references
  rather than duplicates them.
- Any new script, skill, agent, task type, or routing change.
- Installing or provisioning `lean4export` / `nanoda_bin`; the doctor reports on the environment,
  it does not fix it.
- Any edit under `.claude/**` (deploy artifact) — all edits target
  `agent-system/extensions/lean/**`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `UNKNOWN (cannot verify)` gets read as a pass by an operator or a future maintainer | H | M | Use the literal label `UNKNOWN (cannot verify)` in doctor output; never the words OK/pass/green for it. Say so explicitly in `comparator-guide.md` too. |
| `comparator-guide.md` overclaims what a green result means | H | M | Quote the upstream README verbatim for the three certified properties, the six assumptions, the definition-hole caveat, and the TCB sentence. No paraphrase of any of those five items. |
| `line_count` in `index-entries.json` drifts from the file | M | H | Never hand-type it. Run `generate-context-line-counts.sh --write` as the final edit of the last phase, after every other file is frozen; then run `check-extension-docs.sh`. |
| Policy update reads as though the hard gate already exists | H | M | Phrase the addition as "advisory today; the greps remain the operative gate", and have the phase's verification re-read the whole added subsection cold for that misreading. |
| Task-number references leak into deliverables (all nine files live outside `specs/`) | M | L | Final grep across the changed file set before the last commit; `comparator-integration.md` already models the correct citation style (files and upstream URLs, never task numbers). |
| Inline-in-SKILL.md doctor logic proves awkward to demonstrate or regression-test | M | L | Contingency (Phase 3): if demonstration cannot be driven from the inline block, extract the version-match helper to `scripts/lean-comparator-doctor.sh` and add it to `manifest.json`'s `provides.scripts` — a deliberate, recorded deviation from the research decision, not a silent one. |
| Edits land in `.claude/**` instead of the source store | H | L | Binding source-store rule; every phase's file list names `agent-system/extensions/lean/**` paths only. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3, 4 | 2 (phase 3), 1 (phase 4) |
| 3 | 5 | 1, 2, 3, 4 |

Phases within the same wave can execute in parallel. Phase 5 is deliberately last because its
`line_count` registration is only correct once every other file is frozen.

---

### Phase 1: Trust-model document (comparator-guide.md) [COMPLETED]

**Goal**: Write the operator-facing document that states plainly what a green Comparator result
does and does not certify, and link it from the lean4 context index. This is the important half
of the task.

**Tasks**:
- [x] Create `context/project/lean4/tools/comparator-guide.md` with this section order:
  1. What Comparator is, in two or three sentences, and when an operator would reach for it.
  2. **What a green result certifies** — the three upstream properties, quoted verbatim: the
     named theorems "Prove the same statement as provided in `Challenge`", "Use no more axioms
     than listed in `permitted_axioms`", "Be accepted by the Lean kernel."
  3. **What this does NOT certify** (the structural centerpiece): that the Challenge asked the
     right question; definition-hole solutions — quote upstream's "all definition hole solutions
     **must** always be checked with an additional (potentially human) verifier" and give the
     RiemannHypothesis gaming example; and that the guarantee is conditional, not absolute.
  4. **The six assumptions**, quoted verbatim from the upstream README (trusted imports; no prior
     compilation; binaries in PATH; landrun correctness; kernel correctness; unprivileged user),
     with assumptions 2 and 4 explicitly flagged as the two live concerns here — 2 because the
     implementation agent compiles continuously (mitigated only by the clean-room worktree), 4
     because landrun's correctness on this host is not independently verifiable by this system.
  5. **Trusted computing base**, quoting upstream: "The Trusted Code Base of Landrun naturally
     includes the operating system and hardware it is running on, plus its sandboxing mechanism."
  6. **Version coupling (C3)** in one short paragraph, quoting upstream's "lean4export, at a
     version that is compatible with whatever Lean version your project is targeting, present in
     `PATH`", and pointing at the `doctor` mode as the way to check it.
  7. **Current gate strength**: `--compare` is advisory only today; a rejection is recorded and
     surfaced but does not fail verification, downgrade status, or block completion.
  8. A short cross-reference to `domain/comparator-integration.md` for implementation detail
     (clean-room worktree, verdict vocabulary, runner flags) — pointer only, no duplication.
- [x] State explicitly, in the section describing the doctor's version verdict, that
      `UNKNOWN (cannot verify)` is not a pass.
- [x] Add one bullet under `## Key Files` in `context/project/lean4/README.md` linking
      `tools/comparator-guide.md` with a one-line description.
- [x] Verify no task-number references anywhere in either file.

**Timing**: 1.25 hours

**Depends on**: none

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: The plan asserts the guide needs exactly the eight sections above and that
all five verbatim upstream quotations (three certified properties, six assumptions,
definition-hole caveat, TCB sentence, version-coupling sentence) are reproduced accurately in
the research report's "External Resources" section. Confirm at implementation time by reading
that section of `reports/01_comparator-doctor-trust-boundary.md` and copying the quoted strings
from it verbatim; if any quotation there looks paraphrased rather than quoted, re-fetch
`https://raw.githubusercontent.com/leanprover/comparator/master/README.md` before writing it into
the guide.

**Files to modify**:
- `agent-system/extensions/lean/context/project/lean4/tools/comparator-guide.md` - new file, the
  trust-model document
- `agent-system/extensions/lean/context/project/lean4/README.md` - one bullet under `## Key Files`

**Verification**:
- The guide contains a section whose heading names what is NOT certified, and that section names
  both the definition-hole caveat and the previously-compiled-Solution assumption (acceptance
  criterion 2).
- Every one of the five upstream items appears as a quotation, not a paraphrase.
- `grep -nE '\btasks? [0-9]+\b|\(task [0-9]+\)' <both files>` returns nothing.
- Read the "current gate strength" section cold and confirm it cannot be read as describing a
  hard gate.

---

### Phase 2: Doctor mode in skill-lean-version and commands/lean.md [COMPLETED]

**Goal**: Add `doctor` as a fourth mode to the Lean version skill and mirror it in the `/lean`
command, probing the four Comparator binaries and checking the C3 version match.

**Tasks**:
- [x] `skills/skill-lean-version/SKILL.md`: add `doctor` to the Step 1 argument parser's
      `case "$arg"` mode list and to the Step 3 route-by-mode list; add a new mode step
      implementing the probe.
- [x] Implement binary resolution reusing the four env-var names from
      `scripts/lean-comparator-run.sh`'s `resolve_binary()`: `COMPARATOR_BIN` (comparator),
      `COMPARATOR_LANDRUN` (landrun), `COMPARATOR_LEAN4EXPORT` (lean4export), `COMPARATOR_NANODA`
      (nanoda_bin, optional). Each: override var first, then `command -v`.
- [x] For each binary report: name, present yes/no, resolved path (`readlink -f`) when present,
      and the override env var an operator may set.
- [x] Implement the C3 version check for `lean4export` only: `readlink -f` the resolved binary,
      walk up at most 5 parent directories looking for a `lean-toolchain` file, compare its
      trimmed content against the target project's own `lean-toolchain`. Emit exactly one of four
      labels: `matched`, `mismatched`, `UNKNOWN (cannot verify)`, or a not-applicable note when
      `lean4export` is absent. Never emit OK/pass/green for the unknown case.
- [x] On `mismatched` and on `UNKNOWN`, print the two toolchain strings (or the missing-file
      reason) plus the actionable remedy, e.g. "confirm manually that lean4export at `<path>` was
      built against `<target-toolchain>`".
- [x] Handle the target project having no `lean-toolchain` at all (report it; do not crash).
- [x] `commands/lean.md`: add `doctor` to the `## Modes` table, to STEP 1's mode-parsing comment,
      and to STEP 2's routing list; add `### STEP 3D: Doctor Mode` mirroring the skill's steps;
      add a `### Doctor Output` example under `## Output Examples` showing all three states.
- [x] Update the `argument-hint` frontmatter in `commands/lean.md` to include `doctor`.
- [x] Verify no task-number references in either file.

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: The plan asserts (a) exactly four binaries with exactly the four env-var
names above, (b) that `skill-lean-version`'s existing `allowed-tools` (`Bash, Read, Write, Edit,
AskUserQuestion`) already covers the probe with no frontmatter change needed, and (c) that a
5-level walk-up bound is sufficient for the realistic
`<checkout>/.lake/build/bin/lean4export` install layout. Confirm at implementation time by
re-reading `resolve_binary()` in `scripts/lean-comparator-run.sh` for the exact var names, by
re-reading the SKILL.md frontmatter, and by counting the actual directory levels between
`.lake/build/bin/lean4export` and the checkout root (4) before accepting 5 as the bound. Adjust
and record any deviation rather than silently keeping the asserted numbers.

**Files to modify**:
- `agent-system/extensions/lean/skills/skill-lean-version/SKILL.md` - new `doctor` mode arm,
  parser and router entries
- `agent-system/extensions/lean/commands/lean.md` - modes table, argument-hint, STEP 1/STEP 2
  entries, new STEP 3D, doctor output example

**Verification**:
- `bash -n` over the doctor bash block extracted to a scratch file: parses clean.
- The four env-var names in the new block are byte-identical to those in
  `scripts/lean-comparator-run.sh` (`diff` the extracted name list).
- `commands/lean.md` and `SKILL.md` agree on the mode name, the four binaries, and the four
  verdict labels (no drift between command and skill).
- `grep -n 'UNKNOWN (cannot verify)'` finds the literal label in both files; `grep -niE
  'unknown.*(ok|pass|green)'` finds nothing.
- No task-number references in either file.

---

### Phase 3: Demonstrate the three doctor states [COMPLETED]

**Goal**: Prove, with real execution against constructed fixtures, that the doctor reports
correctly in all three acceptance states — most importantly present-but-mismatched.

**Tasks**:
- [x] Extract the Phase 2 doctor bash block to a scratch file under the session scratchpad (not
      into the repo) so it can be run directly.
- [x] **State A (all present, versions matched)**: build a fixture tree with a stub executable at
      `<fixture>/.lake/build/bin/lean4export` and `<fixture>/lean-toolchain` whose content equals
      the target project's `lean-toolchain`; set `COMPARATOR_LEAN4EXPORT` to the stub (and the
      other three override vars to stubs or real binaries). Run; confirm `matched`.
- [x] **State B (a binary missing)**: unset the override var for one binary and ensure it is not
      on `PATH`; run; confirm the missing-binary report and that no version verdict is claimed
      for an absent `lean4export`.
- [x] **State C (present but mismatched)** — the state that matters: same fixture layout as A but
      with `<fixture>/lean-toolchain` holding a different toolchain string; run; confirm
      `mismatched` and that both toolchain strings are printed.
- [x] **State D (walk-up finds nothing)**: point `COMPARATOR_LEAN4EXPORT` at a stub with no
      `lean-toolchain` within 5 levels; run; confirm `UNKNOWN (cannot verify)` and that the output
      contains no OK/pass/green wording for that line.
- [x] Capture the four transcripts verbatim for the implementation summary.
- [ ] If the inline block cannot be driven this way, apply the recorded contingency: extract the
      version-match helper to `agent-system/extensions/lean/scripts/lean-comparator-doctor.sh`,
      register it in `manifest.json`'s `provides.scripts`, and note the deviation in the summary
      and in Phase 5's file list. *(deviation: skipped — inline block demonstrated cleanly against all four fixture states; contingency not triggered)*

**Timing**: 0.75 hours

**Depends on**: 2

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: The plan asserts four demonstrable states (three named in the acceptance
criteria plus the walk-up-found-nothing outcome) and that all four are constructible with stub
files alone, requiring no real `lean4export` binary. Confirm by actually running each fixture and
capturing its transcript; a state that cannot be produced is a finding to record, not to skip.

**Files to modify**:
- No repository files under normal execution — fixtures live in the session scratchpad. Under the
  contingency only: `agent-system/extensions/lean/scripts/lean-comparator-doctor.sh` (new) and
  `agent-system/extensions/lean/manifest.json`.

**Verification**:
- Four transcripts exist, one per state, each showing the expected label.
- The State C transcript shows both the fixture toolchain string and the project toolchain string.
- The State D transcript contains `UNKNOWN (cannot verify)` and no OK/pass/green for that line.
- Fixtures were created outside the repository (`git status --short` shows no stray fixture files).

---

### Phase 4: Proof-debt policy update [COMPLETED]

**Goal**: Record in `proof-debt-policy.md` what Comparator adds to the zero-debt story, while
making unmistakable that the greps remain the operative gate today.

**Tasks**:
- [x] Add a subsection under `## Completion Gates` (after
      `### Zero-Debt Completion Requirement (MANDATORY)`) covering: what the current gate is
      (sorry census, `^axiom ` grep, single-line vacuous-definition grep, unsandboxed
      `lake build`); the specific hole each has; what Comparator's statement-identity, transitive
      axiom, and kernel-replay checks would close. *(deviation: altered — enumerated five actual Final Verification Stage mechanisms, including the plan-compliance grep, rather than the plan's asserted three-greps-plus-build count)*
- [x] State in the same subsection, unambiguously, that `--compare` is **advisory only** today:
      a rejection is recorded and surfaced but does not set `verification_passed` false, does not
      downgrade status to partial, and does not block completion — and that the greps therefore
      remain the operative zero-debt gate.
- [x] State that promotion to a hard gate is a separate, later, evidence-based decision, in the
      future/conditional voice.
- [x] Cross-reference `tools/comparator-guide.md` (trust model) and
      `domain/comparator-integration.md` (design record). Do not restate their content.
- [x] Verify no task-number references.

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: The plan asserts the current gate consists of exactly the three greps plus
an unsandboxed `lake build`. Confirm at implementation time by re-reading the Final Verification
Stage of `agents/lean-implementation-agent.md` and the existing
`### Zero-Debt Completion Requirement (MANDATORY)` subsection, and enumerate whatever is actually
there rather than the asserted list.

**Files to modify**:
- `agent-system/extensions/lean/context/project/lean4/standards/proof-debt-policy.md` - new
  subsection under `## Completion Gates`

**Verification**:
- Read the new subsection cold: no sentence describes a Comparator gate as currently enforcing
  anything.
- The words "advisory" and "operative" (or equivalent unambiguous phrasing) both appear, applied
  to `--compare` and to the greps respectively.
- Both cross-referenced files exist at the paths cited.
- No task-number references.

---

### Phase 5: Extension surface and doc-lint [NOT STARTED]

**Goal**: Register the new context file and the new command mode across the extension's declared
surface so a fresh deploy passes `check-extension-docs.sh`.

**Tasks**:
- [ ] `index-entries.json`: add an entry for `project/lean4/tools/comparator-guide.md` following
      the `comparator-integration.md` entry as the model — `domain: "project"`,
      `subdomain: "lean"`, a one-line `summary`, `keywords`, and
      `load_when: {agents: ["lean-implementation-agent", "lean-research-agent"], task_types:
      ["lean4"]}`. Include no `description` or `tags` keys (Rule T).
- [ ] Run `bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --write` to
      populate `line_count` — do not hand-type it (Rule R).
- [ ] `EXTENSION.md`: add the `doctor` mode to the `### Commands` table's `/lean` row (or add a
      modes note), and add `.claude/context/project/lean4/tools/comparator-guide.md` to
      `### Context Pointers`.
- [ ] `README.md`: update the `/lean` command row and the `### /lean` section to name the
      `doctor` mode; add the guide to the file-tree/context listing if that listing enumerates
      context files.
- [ ] `manifest.json`: confirm whether any `provides` array needs a new entry. Under the base
      design no new file is added to `commands`/`skills`/`scripts` (the guide is covered by the
      existing `"context": ["project/lean4", "contracts"]` directory entry); under the Phase 3
      contingency, add the doctor script to `provides.scripts`.
- [ ] Run `bash agent-system/extensions/core/scripts/check-extension-docs.sh` and drive it to
      zero findings for the lean extension.
- [ ] Final sweep: `grep -nE '\btasks? [0-9]+\b|\(task [0-9]+\)'` across all files changed by this
      task; expect no matches.

**Timing**: 0.75 hours

**Depends on**: 1, 2, 3, 4

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: The plan asserts that `manifest.json` needs no new `provides` entry because
the guide falls under the existing `project/lean4` context directory entry, and that exactly five
files are touched in this phase. Confirm by reading `manifest.json`'s `provides.context` array
and by running `check-extension-docs.sh` — a Rule finding naming an unregistered file falsifies
the hypothesis and the manifest must then be updated.

**Files to modify**:
- `agent-system/extensions/lean/index-entries.json` - new entry + generated `line_count`
- `agent-system/extensions/lean/EXTENSION.md` - commands table, context pointers
- `agent-system/extensions/lean/README.md` - `/lean` command row and section
- `agent-system/extensions/lean/manifest.json` - only if a `provides` entry is genuinely required
- (contingency only) `agent-system/extensions/lean/scripts/lean-comparator-doctor.sh`

**Verification**:
- `bash agent-system/extensions/core/scripts/check-extension-docs.sh` reports zero findings for
  the lean extension (acceptance criterion 3), Rules R and T included.
- `jq` over `index-entries.json` parses cleanly and the new entry's `line_count` equals
  `wc -l < agent-system/extensions/lean/context/project/lean4/tools/comparator-guide.md`.
- The `doctor` mode name appears in `commands/lean.md`, `SKILL.md`, `EXTENSION.md`, and
  `README.md` with no spelling drift.
- Task-number sweep across the full changed-file set returns nothing (acceptance criterion 4).

---

## Testing & Validation

- [ ] Doctor State A (all present, matched) demonstrated with a transcript.
- [ ] Doctor State B (binary missing) demonstrated with a transcript.
- [ ] Doctor State C (present but `lean4export` mismatched) demonstrated with a transcript — the
      acceptance criterion that must not be assumed.
- [ ] Doctor State D (`UNKNOWN (cannot verify)`) demonstrated, with no pass-flavored wording.
- [ ] `comparator-guide.md` has an explicit "what this does NOT certify" section naming the
      definition-hole caveat and the previously-compiled-Solution assumption.
- [ ] `bash agent-system/extensions/core/scripts/check-extension-docs.sh` — zero findings.
- [ ] `bash -n` clean over the extracted doctor bash block.
- [ ] No task-number references in any changed file (all live outside `specs/`).
- [ ] `git status --short` shows changes only under `agent-system/extensions/lean/**` and
      `specs/156_*/**` — nothing under `.claude/**`.

## Artifacts & Outputs

- `agent-system/extensions/lean/context/project/lean4/tools/comparator-guide.md` (new)
- `agent-system/extensions/lean/skills/skill-lean-version/SKILL.md` (doctor mode)
- `agent-system/extensions/lean/commands/lean.md` (doctor mode, STEP 3D, output example)
- `agent-system/extensions/lean/context/project/lean4/standards/proof-debt-policy.md` (policy note)
- `agent-system/extensions/lean/context/project/lean4/README.md` (index link)
- `agent-system/extensions/lean/EXTENSION.md`, `README.md`, `index-entries.json`,
  `manifest.json` (extension surface)
- `specs/156_document_comparator_trust_boundary/summaries/01_*-summary.md` including the four
  doctor-state transcripts

## Rollback/Contingency

All changes are additive edits to markdown and JSON in the extension source store; none change
runtime behavior of any existing mode, agent, or gate. Revert is per-phase: each phase commits
independently, so `git revert <phase-sha>` undoes any single phase. Reverting Phase 5 alone would
leave `comparator-guide.md` unregistered and fail doc-lint, so Phase 5 must be reverted together
with Phase 1 (or the index entry removed by hand). If the doctor mode proves unworkable inline,
Phases 1 and 4 still stand alone as complete deliverables — the trust-model document is the
independently valuable half.
