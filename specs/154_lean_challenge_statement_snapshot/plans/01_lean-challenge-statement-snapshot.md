# Implementation Plan: Task #154

- **Task**: 154 - Make lean plans carry exact theorem statements and emit an immutable trusted Challenge snapshot
- **Status**: [IMPLEMENTING]
- **Effort**: 12.75 hours
- **Dependencies**: None (wave 1 of the Comparator integration group; downstream compare-step tasks consume this task's manifest schema)
- **Research Inputs**: specs/154_lean_challenge_statement_snapshot/reports/01_lean-challenge-statement-snapshot.md
- **Artifacts**: plans/01_lean-challenge-statement-snapshot.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Establish the trusted Challenge that constraint C1 says does not exist today: a recorded, exact
theorem *statement* (not just an identifier) fixed before the implementation agent runs, plus a
snapshot tool that turns it into a Challenge module `lean-comparator-run.sh` accepts. The route
is R1 (plan-declared statements) with R2 (git-baseline extraction) demoted to a loudly-degraded
legacy fallback, because R2 structurally cannot serve a greenfield theorem. Immutability is
obtained from git content-addressing — the Challenge is committed into the target project's own
history and callers are pinned to the resulting SHA — backed by a process-level status gate that
refuses regeneration once the task has moved past `planned`. Definition of done: the snapshot
script produces a Comparator-acceptable Challenge on a real Lean project, a weakened statement is
mechanically flagged while an honest one is not, and the immutability refusal is demonstrated
rather than asserted.

### Research Integration

The research report settles four questions this plan builds on directly, and this plan does not
relitigate them:

- **R1 over R2**, with R2 kept only as an explicitly-logged fallback for plans authored before
  this feature. Reasoning is reproduced in the Phase 1 decision record.
- **A new additive plan section `## Lean Challenge Statements`**, gated on lean/lean4 task type,
  rather than amending the shared `- **Goals**:` bullet block — `## Planned Strategic Sorries` is
  the in-file precedent for a conditionally-present section, so the shape is not novel and
  non-lean plans are provably untouched.
- **`lean-comparator-run.sh` never synthesises `.lean` content.** It does `git worktree add
  --detach $WORKDIR $COMMIT_REF` and expects both `--challenge-module` and `--solution-module` to
  already exist in that commit's tree. A Challenge therefore has to be real, committed Lean
  source in the target project's repository, not a specs-side artifact copied in at check time.
  This is what makes git the immutability mechanism.
- **`plan-compliance.md` should gain a statement-fidelity notion.** Today it makes the plan's
  *decomposition* the contract and is silent on whether a declaration's *signature* is part of it,
  so a same-named weaker restatement violates nothing in the rule as written.

The report also records that **no genuine Lean proof-task plan exists anywhere in this
repository's `specs/` tree** — every `task_type: lean` plan found is a meta task about Lean
tooling. There is consequently no live in-repo example to validate the new section against, which
is why Phase 8 targets a real external Lean project (`~/Projects/BimodalLogic` and
`~/Projects/cslib`, both confirmed present with tracked `.lean` sources, git history, and
`leanprover/lean4:v4.33.0-rc1`) instead of a synthetic fixture.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:

- Decide R1 vs R2 **in writing**, with the greenfield case R2 cannot serve stated explicitly, in
  a durable design record under the lean extension's context tree.
- Add `## Lean Challenge Statements` to `context/formats/plan-format.md` as a new, additively
  gated section carrying literal ```` ```lean ````-fenced signatures with `sorry` bodies.
- Deliver `agent-system/extensions/lean/scripts/lean-challenge-snapshot.sh`: given a task number
  and a project root, it writes a Challenge module plus the `theorem_names` list that
  `lean-comparator-run.sh` consumes, commits it, and records a manifest pinning the commit SHA.
- Give the script a Comparator-independent `--check` drift mode, so statement fidelity is
  enforceable today by normalised text comparison whether or not the Comparator binaries are ever
  provisioned. This is the task's stated independent value.
- Make regeneration-after-implementation a loud, gated refusal, and demonstrate that even a
  bypassed refusal cannot retroactively change what an already-recorded SHA points to.
- Add a Statement Fidelity subsection to `rules/plan-compliance.md` naming statement weakening as
  a forbidden pattern.

**Non-Goals**:

- **Wiring the snapshot or any drift verdict into a completion gate.** Consistent with the
  operator's already-made ADVISORY FIRST decision, nothing produced here may set
  `verification_passed` false, downgrade a status to partial, or block completion. The script is
  a standalone CLI, as `lean-comparator-run.sh` already is.
- **Synthesising a `Solution.lean` module or invoking `lean-comparator-run.sh --compare`.** That
  is the downstream compare-step task's concern; this plan only fixes the manifest interface it
  will read.
- **Provisioning the missing binaries** (`landrun`, `lean4export`, `nanoda_bin`, `comparator`).
  All four are absent on this host; every acceptance criterion below is deliberately reachable
  without them.
- Amending `- **Goals**:` bullet semantics, or changing anything about how non-lean plans are
  shaped or validated.
- Resolving C3 (lean4export version coupling) or C4 (cost) — both belong to the run-side tooling.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A planner writes a `## Lean Challenge Statements` block whose identifiers drift from the `- **Goals**:` identifier list, yielding a Challenge that does not match what compliance checking expects | H | M | Phase 2 makes identifier-set disagreement a **hard `config_error` failure** naming the specific offending identifiers — never a silent union, intersection, or warning. Decided here so the implementer does not have to re-decide it. |
| The R2 fallback's declaration-boundary extraction mis-parses (multi-line signatures, `@[...]` attributes, `noncomputable`/`private`/`protected` modifiers) and silently produces a *wrong* Challenge | H | M | Treat every R2 extraction ambiguity as a hard error, not a best-effort parse; R2 is a fallback, so it need only handle declaration shapes this codebase's own `lean4-style-guide.md` conventions produce. A silently mis-extracted Challenge is strictly worse than a refusal. |
| The acceptance demonstration commits a `Challenge.lean` into the operator's live `~/Projects/*` repository | M | M | Phase 8 runs against a throwaway `git clone --no-hardlinks` of the real project into a scratch dir. Real sources, real toolchain, real git history — zero mutation of the operator's working repos. |
| `--force` becomes a normalised convenience for bypassing the status gate | M | M | The `--force` path prints an incident-shaped warning naming the task, its current status, and the fact that any previously recorded manifest SHA is now stale for callers still holding it. Phase 4 asserts the warning text in a test, so it cannot be quietly softened later. |
| Adding a section to `plan-format.md` perturbs a format every task type consumes | H | L | The section is additive and documented as present only for lean/lean4 plans; Phase 1 verifies by running the artifact validator over existing non-lean plans before and after and asserting no diff in outcome. |
| Editing `.claude/**` instead of the source store, wiping the work on the next deploy | H | M | Binding source-store rule: every edit lands in `agent-system/extensions/{core,lean}/**`. Phase 1 and every later phase state the source path explicitly; the advisory PostToolUse hook is a reminder, not the guarantee. |
| A demonstration that only shows drift being caught, proving nothing about false positives | M | M | Acceptance requires **both** directions: the weakened statement flagged AND an honest implementation not flagged. Phase 8 runs both and records both transcripts. |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 7 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |
| 5 | 5 | 4 |
| 6 | 6 | 5 |
| 7 | 8 | 6, 7 |

Phases within the same wave can execute in parallel. Phases 2 and 7 touch disjoint files
(`lean/scripts/**` vs `lean/rules/plan-compliance.md`) and are safe to run concurrently.

---

### Phase 1: Decision record and the `## Lean Challenge Statements` plan section [COMPLETED]

**Goal**: Fix the contract everything else consumes — the written R1-vs-R2 decision, the new plan
section's exact shape, and the manifest schema — before any script exists to consume it.

**Tasks**:

- [x] Create `agent-system/extensions/lean/context/project/lean4/domain/challenge-snapshot.md` as *(completed)*
      the design record. It must contain, at minimum:
  - The **R1-vs-R2 decision in writing**, with the comparison table from the research report
    (greenfield case, cost to shared format, fidelity to planner intent, mechanism complexity,
    import-context reconstruction) and the explicit statement that R2 cannot serve a greenfield
    theorem — the case this task exists to close — and is therefore a logged fallback only.
  - **Where the Challenge is stored** (committed `.lean` source inside the target project's own
    git history) and **what stops regeneration from post-hoc sources** (the status-gate refusal at
    process level; SHA pinning plus a recorded content hash at mechanism level).
  - The **manifest schema** the downstream compare step will read, verbatim:
    `{schema_version, task_number, plan_path, project_root, challenge_module, challenge_path,
    theorem_names, route, commit, content_sha256, created_at}` where `route` is
    `"plan-declared"` or `"git-baseline"`.
  - The **exit-code vocabulary**, deliberately aligned with `lean-comparator-run.sh`'s own codes
    where the meanings correspond: `0` ok, `64` usage error, `65` statement drift (mirrors
    Comparator's `statement_mismatch`), `71` config error (mirrors Comparator's `config_error`,
    used for identifier-set mismatch and for a name resolvable by neither route), `73` snapshot
    refused. Document the alignment as intentional.
  - A restatement of the ADVISORY FIRST gate-strength decision, in the same binding language
    `comparator-integration.md` already uses.
- [x] Add `## Lean Challenge Statements` to *(completed)*
      `agent-system/extensions/core/context/formats/plan-format.md`: one or more ```` ```lean ````
      fenced blocks that concatenate in order to form the Challenge module body; bodies are
      `sorry`; present only when the plan's task type is `lean`/`lean4`. Document the gating
      explicitly, mirroring how `## Planned Strategic Sorries` documents its own
      `plan_metadata.skeleton` gate, and add it to the numbered `## Structure` list in the same
      conditional style.
- [x] State in the new section that the identifiers declared there MUST equal the identifier set *(completed)*
      under `- **Goals**:`, and that disagreement is a hard error at snapshot time (settling the
      research report's flagged phase-1 decision point).
- [x] Register the design record in `agent-system/extensions/lean/index-entries.json` following *(completed)*
      the `comparator-integration.md` entry's shape (`load_when.agents`:
      `lean-implementation-agent`, `lean-research-agent`; `load_when.task_types`: `lean4`;
      summary; keywords).
- [x] Use durable anchors only — the design record is a deliverable outside `specs/**`, so it *(completed)*
      MUST NOT cite task numbers; refer to "the Comparator compare step" and to file names.

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts exactly three edited/created files
(`challenge-snapshot.md`, `plan-format.md`, `index-entries.json`). Confirm at implementation time
with `git status --short` before committing; if a fourth file proves necessary (e.g. a core
`index.json` counterpart), record why rather than silently widening.

**Files to modify**:

- `agent-system/extensions/lean/context/project/lean4/domain/challenge-snapshot.md` - new design
  record (R1/R2 decision, storage, immutability, manifest schema, exit codes)
- `agent-system/extensions/core/context/formats/plan-format.md` - new additive
  `## Lean Challenge Statements` section plus its `## Structure` list entry
- `agent-system/extensions/lean/index-entries.json` - context index entry for the new record

**Verification**:

- `python3 -c "import json;json.load(open('agent-system/extensions/lean/index-entries.json'))"`
  parses clean.
- `bash agent-system/extensions/core/scripts/check-extension-docs.sh` (and
  `check-consumer-freshness.sh` if it covers `plan-format.md`) reports no new findings.
- Run `scripts/validate-artifact.sh` over two existing **non-lean** plans before and after the
  `plan-format.md` edit and confirm identical outcomes — the additive-only claim is demonstrated,
  not asserted.
- `grep -n "task [0-9]" agent-system/extensions/lean/context/project/lean4/domain/challenge-snapshot.md`
  returns nothing.

---

### Phase 2: Snapshot script CLI and R1 extraction (assemble-only, no writes) [COMPLETED]

**Goal**: A runnable `lean-challenge-snapshot.sh` that resolves a task's plan, extracts the
plan-declared statements and the goal identifiers, cross-validates them, and prints the assembled
Challenge module to stdout — with no filesystem or git side effects yet.

**Tasks**:

- [x] Create `agent-system/extensions/lean/scripts/lean-challenge-snapshot.sh` with the header *(completed)*
      comment convention `lean-comparator-run.sh` uses: purpose, usage, required/optional args,
      env-var seams, exit-code table, and an explicit ADVISORY-ONLY gate-strength paragraph.
- [x] CLI: *(completed)*
      `lean-challenge-snapshot.sh <task_number> <project_root> [--commit REF]
      [--challenge-module NAME] [--force] [--dry-run] [--json]`, plus the `--check` mode added in
      Phase 5. Default `--challenge-module` is `Challenge`, matching the fixtures.
- [x] Resolve the plan file exactly as `lean-implementation-agent.md` already does *(completed)*
      (`specs/{padded}_{slug}/plans/*.md`, `sort -V | tail -1`) — reuse, do not reinvent.
- [x] Extract goal identifiers with the existing backtick regex, reused **verbatim**: *(completed)*
      `sed -n '/^\*\*Goals\*\*:/,/^\*\*[^G]/p' "$plan_file" | grep -oP '`[a-zA-Z_][a-zA-Z0-9_'"'"']*`'`.
      This is `theorem_names`.
- [x] Extract every ```` ```lean ```` fenced block under `## Lean Challenge Statements` and *(completed)*
      concatenate in document order as the Challenge module body. Force every declaration body to
      `sorry` regardless of what the block contains — a Challenge pins statements only and must
      never carry a real proof.
- [x] Cross-validate: the identifier set declared in the section must equal the `- **Goals**:` *(completed)*
      set. On disagreement exit `71` naming the specific identifiers on each side.
- [x] `--dry-run` prints the assembled module and the resolved `theorem_names` to stdout and *(completed)*
      exits 0 without touching anything.
- [x] Set the standard bash preamble used by the sibling scripts (`set -uo pipefail`, *(completed)*
      `SCRIPT_DIR` resolution) and make usage errors exit `64`.

**Timing**: 2 hours

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase assumes the five exit codes fixed in Phase 1 are sufficient for
the whole script. Confirm at implementation time by walking every `exit` site added here and in
Phases 3-5; if a sixth code is genuinely needed, amend the Phase 1 design record in the same
commit rather than introducing an undocumented code.

**Files to modify**:

- `agent-system/extensions/lean/scripts/lean-challenge-snapshot.sh` - new script (CLI, plan
  resolution, R1 extraction, identifier cross-validation, `--dry-run`)

**Verification**:

- `bash -n` clean; `shellcheck` (if available) reports no errors.
- Hand-built temporary plan fixture with a `## Lean Challenge Statements` block: `--dry-run`
  emits the expected module body and `theorem_names`.
- Deliberately mismatched fixture (a name in the section absent from `- **Goals**:`) exits `71`
  and the message names the offending identifier.
- A plan with a non-`sorry` body in the fenced block still yields `sorry` in the assembled output.

---

### Phase 3: R2 git-baseline fallback [NOT STARTED]

**Goal**: Legacy lean plans with no `## Lean Challenge Statements` section still yield a
Challenge when — and only when — every named identifier already exists as a declaration at the
plan's approval commit; anything else fails loudly.

**Tasks**:

- [ ] When the R1 section is absent, log a prominent degradation notice naming the plan file and
      the reason (pre-feature plan), then enter the fallback. The notice must be unmissable in
      normal output, never a debug-only line.
- [ ] Resolve the plan's approval commit as `git log -1 --format=%H -- <plan_path>`.
- [ ] For each identifier in `theorem_names`, locate its declaration in the target project's tree
      at that commit (`git show <commit>:<path>`), extract the declaration header up to the
      body-introducing `:=` / `by`, and emit it with a `sorry` body.
- [ ] Lift the source file's own `import` lines into the assembled module so the extracted
      signature can type-check standalone.
- [ ] Any identifier resolvable by neither R1 nor R2 is a hard `71` failure naming the specific
      missing identifier. Never emit a partial Challenge — Comparator would silently accept it as
      "no theorem named here to check", which is the exact failure this task exists to prevent.
- [ ] Treat extraction ambiguity (unbalanced construct, unrecognised declaration shape, more than
      one declaration matching the name) as a hard error rather than a best-effort guess.
- [ ] Record `route` (`"plan-declared"` vs `"git-baseline"`) for the manifest Phase 4 writes.

**Timing**: 1.5 hours

**Depends on**: 2

**Verification Tier**: local

**Commit Mode**: per-substep

**Files to modify**:

- `agent-system/extensions/lean/scripts/lean-challenge-snapshot.sh` - R2 fallback path,
  degradation logging, hard-fail behaviour

**Verification**:

- Scratch git repo with a `.lean` file containing a `sorry`ed theorem and a plan with no
  Challenge section: fallback produces the expected signature with a `sorry` body and prints the
  degradation notice.
- Greenfield case (identifier named in `- **Goals**:` but present in neither the section nor the
  tree): exits `71` naming that identifier; **no** Challenge file content is emitted.
- Attribute-decorated and multi-line-signature declarations either extract correctly or fail
  loudly — verified by asserting the outcome, never by reading the source.

---

### Phase 4: Commit, manifest, and the immutability status gate [NOT STARTED]

**Goal**: Turn an assembled Challenge into a durable, SHA-pinned artifact, and make regeneration
after implementation has started a loud refusal.

**Tasks**:

- [ ] Write the assembled module to `<project_root>/<challenge_module>.lean`, `git add` it, and
      commit it as an isolated commit with message
      `task {N}: snapshot lean challenge statements` (the existing task-scoped git convention;
      task numbers are permitted in commit messages).
- [ ] Compute `content_sha256` of the assembled module before committing — a second, independent
      immutability witness that does not require the project repo to be reachable later.
- [ ] Write `specs/{NNN}_{SLUG}/challenge/manifest.json` with the Phase 1 schema, including the
      resulting commit SHA.
- [ ] **Status gate**: read the task's status from `specs/state.json`. If it is anything past
      `planned` (`implementing`, `pr_ready`, `completed`, ...), refuse with exit `73` and a
      message naming the task, its current status, and that the Challenge must predate
      implementation to certify anything.
- [ ] Refuse (exit `73`) to overwrite an existing manifest even at `planned`, unless `--force`.
- [ ] `--force` past `planned` proceeds but prints an incident-shaped warning naming the task, its
      status, and the fact that any previously recorded manifest SHA is now stale for callers
      still holding it. Never a silent success.
- [ ] Emit the verdict record in the sibling script's style: key/value lines by default, one JSON
      object under `--json`.

**Timing**: 1.5 hours

**Depends on**: 3

**Verification Tier**: local

**Commit Mode**: per-substep

**Files to modify**:

- `agent-system/extensions/lean/scripts/lean-challenge-snapshot.sh` - commit path, manifest write,
  status gate, `--force` warning, verdict output

**Verification**:

- Scratch repo + scratch specs dir at status `planned`: script commits the Challenge, manifest
  records a SHA, and `git show <SHA>:<Challenge>` returns exactly the assembled bytes.
- Flip the scratch status to `implementing` and re-run: exit `73`, refusal message names task and
  status, working tree unchanged.
- Re-run with `--force` at `implementing`: succeeds, and the incident warning text is asserted.
- After a `--force` overwrite, `git show <original SHA>` still returns the original content —
  the SHA pin survives the bypass.

---

### Phase 5: `--check` statement-drift mode [NOT STARTED]

**Goal**: Deliver the Comparator-independent fidelity check — the task's stated independent value
— so statement weakening is detectable today with no Comparator binaries present.

**Tasks**:

- [ ] Add `--check` mode: read the manifest, retrieve the recorded Challenge at its pinned commit
      via `git show <commit>:<challenge_path>`, and compare each named theorem's signature against
      the same-named declaration in the project's current working tree.
- [ ] Normalise before comparing — collapse whitespace and line breaks, strip comments, ignore
      binder-name-only differences where they are unambiguous — so cosmetic reformatting is not
      reported as drift. Document precisely what normalisation does and does not absorb; anything
      it cannot decide is reported as drift, never silently passed.
- [ ] Exit `65` on drift with a per-identifier diff showing recorded vs current; exit `0` when
      every named statement matches; exit `71` when a named identifier is absent from the current
      tree (an authoring error, not a security finding — matching `lean-comparator-run.sh`'s own
      distinction).
- [ ] `--check` is read-only: it must not write, commit, or mutate anything, including the
      manifest.
- [ ] State in the `--check` output header that the verdict is **advisory** and must not be used
      to fail a task.

**Timing**: 1.5 hours

**Depends on**: 4

**Verification Tier**: local

**Commit Mode**: per-substep

**Files to modify**:

- `agent-system/extensions/lean/scripts/lean-challenge-snapshot.sh` - `--check` mode, normalising
  comparator, per-identifier diff output

**Verification**:

- Honest case: implementation proves the recorded statement -> exit `0`, no drift reported.
- Weakened case: an added hypothesis on one theorem -> exit `65`, diff names that theorem only.
- Cosmetic case: reformatted-but-equivalent signature -> exit `0` (no false positive).
- Missing case: identifier deleted from the tree -> exit `71`, distinguishable from `65`.
- `git status --porcelain` is unchanged across a `--check` run.

---

### Phase 6: Regression suite, fixtures, and manifest registration [NOT STARTED]

**Goal**: Lock every behaviour above behind an executable suite in the house style, and register
the new files so they actually deploy.

**Tasks**:

- [ ] Create `agent-system/extensions/lean/scripts/tests/test-lean-challenge-snapshot.sh`
      following the established convention (`pass()/fail()/info()/skip()` helpers, PASSED/FAILED/
      SKIPPED counters, `mktemp -d` workdir with `trap EXIT` cleanup, exit 0 all-pass / 1 any-fail),
      with a header comment enumerating the regression concerns it covers.
- [ ] Cases: R1 extraction; identifier-set mismatch -> `71`; R2 fallback success plus its
      degradation notice; greenfield unresolvable -> `71`; commit+manifest+SHA round-trip; status
      gate refusal -> `73`; `--force` incident warning text; `--check` drift -> `65`; `--check`
      honest -> `0`; `--check` cosmetic-only -> `0`; `--check` missing identifier -> `71`.
- [ ] Carry the **anti-vacuous-test guard** the sibling suites use: assert that a naive
      "exit code non-zero means bad" classifier cannot distinguish the `65` drift case from the
      `71` config-error case, proving the exit-code vocabulary is doing real work.
- [ ] Add fixtures under `tests/fixtures/challenge/`: a plan with an R1 section, a legacy plan
      without one, a mismatched-identifier plan, and honest/weakened/cosmetic Solution variants.
- [ ] Register the script, the test, and every fixture file in
      `agent-system/extensions/lean/manifest.json` under `provides.scripts`, matching the
      `lean-comparator-run.sh` registration pattern exactly.

**Timing**: 2 hours

**Depends on**: 5

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts eleven test cases and six fixture files. Both counts are
hypotheses — confirm at implementation time by running the suite and reading its own case report;
adding cases is fine, dropping one requires a stated reason in the phase record.

**Files to modify**:

- `agent-system/extensions/lean/scripts/tests/test-lean-challenge-snapshot.sh` - new suite
- `agent-system/extensions/lean/scripts/tests/fixtures/challenge/**` - new fixtures
- `agent-system/extensions/lean/manifest.json` - `provides.scripts` registration

**Verification**:

- `bash agent-system/extensions/lean/scripts/tests/test-lean-challenge-snapshot.sh` exits 0 with
  every case reported PASS or explicitly SKIP (never a silent pass).
- Existing `test-lean-comparator-run.sh` and `test-lean-sorry-census.sh` still pass — no
  regression in the sibling suites.
- `python3 -c "import json;json.load(open('agent-system/extensions/lean/manifest.json'))"` parses;
  every newly registered path exists on disk.
- `bash agent-system/extensions/core/scripts/check-deploy-freshness.sh` reports no new findings.

---

### Phase 7: Statement Fidelity clause in `plan-compliance.md` [NOT STARTED]

**Goal**: Make a declaration's *signature*, not just its name and the plan's decomposition, part
of the contract the rule enforces.

**Tasks**:

- [ ] Add a `## Statement Fidelity` subsection to
      `agent-system/extensions/lean/rules/plan-compliance.md` stating that when a plan carries a
      `## Lean Challenge Statements` section, the named declarations' **signatures** are part of
      the contract — not only their identifiers.
- [ ] Add to the existing `## Forbidden Patterns` list: *"Weakening a recorded Challenge statement
      — adding a hypothesis, specialising a quantifier, or restating a strictly weaker claim under
      the same name."*
- [ ] Cross-reference the rule's existing escalate-rather-than-substitute behaviour (mark the
      phase `[BLOCKED]` and raise it) so a genuinely wrong recorded statement has a sanctioned
      route that is not "quietly change it".
- [ ] Point at `lean-challenge-snapshot.sh --check` as the cheap mechanical check available
      independently of Comparator, and state plainly that its verdict is advisory.
- [ ] No task-number citations — this file is a deliverable outside `specs/**`.

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: prose

**Commit Mode**: per-substep

**Files to modify**:

- `agent-system/extensions/lean/rules/plan-compliance.md` - new `## Statement Fidelity`
  subsection, one new Forbidden Patterns bullet, cross-references

**Verification**:

- Diff read-through confirms every changed hunk is markdown prose; the YAML `paths:` frontmatter
  is untouched.
- `bash agent-system/extensions/core/scripts/check-task-references.sh` (or a scoped
  `grep -nE 'task [0-9]+'` on the file) returns nothing.
- Every cross-referenced file and section heading named in the new text actually exists.

---

### Phase 8: Acceptance demonstration on a real Lean project [NOT STARTED]

**Goal**: Discharge the dispatch's four acceptance criteria with recorded evidence rather than
assertions.

**Tasks**:

- [ ] `git clone --no-hardlinks ~/Projects/cslib` (or `~/Projects/BimodalLogic`) into a scratch
      directory. All demonstration commits land in the clone; the operator's live repositories are
      never mutated.
- [ ] Build a realistic scratch task directory and `state.json` entry at status `planned`, with a
      plan carrying a `## Lean Challenge Statements` block naming two or three real theorems from
      the chosen project.
- [ ] **Criterion: Comparator-acceptable Challenge.** Run the snapshot, then show the emitted
      module and `theorem_names` satisfy `lean-comparator-run.sh`'s input contract — same module
      shape as the existing `tests/fixtures/comparator/*/Challenge.lean` fixtures, resolvable as a
      `lean_lib` target, `--commit` retrievable. Where the run itself cannot proceed because
      `comparator`/`landrun`/`lean4export` are absent on this host, record an explicit SKIP naming
      the deferred criterion — never a silent pass.
- [ ] **Criterion: drift detected, both directions.** Weaken one theorem statement in the clone's
      working tree; `--check` exits `65` naming that theorem. Restore an honest implementation of
      the same statement; `--check` exits `0`. Record both transcripts.
- [ ] **Criterion: immutability demonstrated.** Advance the scratch task to `implementing`, re-run
      the snapshot, capture the `73` refusal. Then `--force` (or hand-commit a different
      `Challenge.lean`) and show `git show <original SHA>:<Challenge>` still returns the original
      bytes and the recorded `content_sha256` still matches them.
- [ ] Fold the transcripts and the SKIP record into the Phase 1 design record's own
      "Demonstrated behaviour" section (durable, outside `specs/**`, no task numbers) and into the
      task summary.
- [ ] Remove the scratch clone; confirm `~/Projects/*` are untouched (`git status` clean, no new
      commits).

**Timing**: 2 hours

**Depends on**: 6, 7

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase assumes one cloned project and two or three named theorems
suffice to exercise every acceptance criterion. Confirm at implementation time; if the chosen
project's declarations turn out unsuitable (e.g. every candidate theorem has a multi-line
signature the extractor rejects), switch to the other confirmed project and record why.

**Files to modify**:

- `agent-system/extensions/lean/context/project/lean4/domain/challenge-snapshot.md` - add the
  "Demonstrated behaviour" evidence section
- (scratch clone and scratch specs fixtures are temporary; nothing else in the repository changes)

**Verification**:

- Full repository gate set passes: both lean test suites, the artifact validator, deploy-freshness
  and extension-docs checks, and the task-reference lint.
- All four acceptance criteria are individually addressed with a transcript or an explicit,
  named SKIP.
- `cd ~/Projects/cslib && git status --porcelain` (and the same for BimodalLogic) is unchanged
  from before the phase.

---

## Testing & Validation

- [ ] `bash agent-system/extensions/lean/scripts/tests/test-lean-challenge-snapshot.sh` exits 0,
      with every case PASS or explicitly SKIP.
- [ ] Sibling suites `test-lean-comparator-run.sh` and `test-lean-sorry-census.sh` still pass.
- [ ] Anti-vacuous guard passes: a naive exit-code-only classifier provably disagrees with this
      script's `65`-vs-`71` classification.
- [ ] The artifact validator's outcome on existing non-lean plans is identical before and after
      the `plan-format.md` edit.
- [ ] Every path registered in `lean/manifest.json` exists; `check-deploy-freshness.sh` clean.
- [ ] No `.claude/**` file is modified by any phase (`git status --short` review before each
      commit).
- [ ] No task-number citation appears in any deliverable outside `specs/**`.
- [ ] Both operator Lean projects are unmodified after Phase 8.

## Artifacts & Outputs

- `agent-system/extensions/lean/scripts/lean-challenge-snapshot.sh` — the snapshot/check tool
- `agent-system/extensions/lean/scripts/tests/test-lean-challenge-snapshot.sh` — regression suite
- `agent-system/extensions/lean/scripts/tests/fixtures/challenge/**` — plan and solution fixtures
- `agent-system/extensions/lean/context/project/lean4/domain/challenge-snapshot.md` — design
  record: R1-vs-R2 decision, storage and immutability, manifest schema, exit codes, demonstrated
  behaviour
- `agent-system/extensions/core/context/formats/plan-format.md` — new `## Lean Challenge
  Statements` section
- `agent-system/extensions/lean/rules/plan-compliance.md` — `## Statement Fidelity` subsection
- `agent-system/extensions/lean/manifest.json`, `index-entries.json` — registration
- `specs/154_lean_challenge_statement_snapshot/summaries/01_*-summary.md` — execution summary

## Rollback/Contingency

Every phase is an isolated commit on the task branch, so `git revert` of a phase's commit undoes
it cleanly. The change set is strictly additive: the new script, its tests and fixtures, and one
new context file are pure additions; the three edited files (`plan-format.md`,
`plan-compliance.md`, `manifest.json`/`index-entries.json`) gain sections or entries and remove
nothing, so a partial rollback leaves the system in its pre-task state rather than a broken
intermediate. Nothing produced here is wired into a gate, so an abandoned or reverted task cannot
block any other task's completion. If Phase 8's demonstration fails on both candidate projects,
the correct outcome is `[BLOCKED]` with the failure recorded — not a weakened acceptance
criterion.
