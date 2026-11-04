# Implementation Plan: Task #312

- **Task**: 312 - Backlog reconciliation as a required task-creation component: compare every proposed task against the open backlog before it is written
- **Status**: [IMPLEMENTING]
- **Effort**: 15 hours
- **Dependencies**: 165 (completed), 282 (completed), 300 (completed), 344 (completed) — all cleared
- **Research Inputs**: specs/312_backlog_reconciliation_required_at_task_creation/reports/01_backlog-reconciliation-task-creation.md
- **Artifacts**: plans/01_backlog-reconciliation-task-creation.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Build a two-layer backlog-reconciliation mechanism for task creation: a single shared matcher
script that compares a proposal against the union of open and closed records and emits a
structured verdict, plus enforcement that refuses a `specs/state.json` task-creation write
carrying no recorded verdict. The research phase ruled that the dispatch's option (a) — a
`Write|Edit`-matched PreToolUse hook — cannot observe most task-creation writes at all, because
those writes happen through Bash-invoked `jq`/`state-write.sh` calls; so enforcement is anchored
inside `scripts/state-write.sh` (the real single writer) with a narrow `Bash`-matcher hook as a
structural backstop against bypass. Verdict acquisition stays per-surface at the *skill* layer,
where `AskUserQuestion` is reachable, and ambiguous verdicts render into Component 7's existing
confirmation table rather than a newly invented interactive gate.

### Research Integration

Four research findings shape the phasing directly:

1. **Option (a) as literally stated would be a no-op hook.** `root-files/settings.json`'s
   `Write|Edit` PreToolUse slot holds content scanners; `specs/state.json` is mutated via Bash
   (`state-write.sh` or raw `jq`), which that matcher never sees. Enforcement therefore lives in
   `state-write.sh`'s existing `acquire -> stage -> transform -> validate -> mv -> release`
   pipeline, extending the same technique its `--allocate-into` recording assertion already uses
   (diff the pre/post-transform `active_projects` number set; refuse when a new entry lacks
   evidence).
2. **Not every surface routes through `state-write.sh`.** Verified by `grep -c state-write`:
   `commands/task.md` (5), `commands/review.md` (6), `skills/skill-spawn/SKILL.md` (5) do;
   `agents/meta-builder-agent.md` (0), `skills/skill-fix-it/SKILL.md` (0),
   `skills/skill-meta/SKILL.md` (0), `commands/errors.md` (0) do not. Migration of the two actual
   raw writers is therefore an early, independent phase — enforcement cannot reach `/meta` (the
   surface responsible for the motivating incident) until it lands.
3. **The semantic pass has nothing to reuse.** No similarity utility exists anywhere in
   `scripts/`. The design is a cheap, recall-biased keyword/token-overlap *shortlist* computed
   mechanically, with the duplicate/subset/superset/covered-by-closed disposition rendered by the
   calling LLM surface against the shortlisted candidates' full text. The script never decides
   semantic equivalence.
4. **Existing libraries cover both reads.** `scripts/lib/file-scope-overlap.sh` exports
   `scopes_overlap()` and `FILE_SCOPE_OVERLAP_JQ_DEFS`; `scripts/lib/project-number-inuse.sh`
   already unions `specs/state.json`'s `active_projects` with `specs/archive/state.json`'s
   `completed_projects`/`archived_projects`/`abandoned_projects` and handles that archive's real
   cross-array duplicate numbers. The new matcher sources both rather than re-deriving either.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the dispatch context; no roadmap phases are included.

## Goals & Non-Goals

**Goals**:
- A new REQUIRED component in `multi-task-creation-standard.md`, sequenced as 4b (after the
  existing 4a, before Component 7), specifying inputs, the two passes, the verdict vocabulary and
  the non-silence obligation; compliance table carries it as a new column, honestly marked.
- One shared matcher script, serving two call shapes: creation-time single-attempt, and
  proposal-time over a set of proposals that carry no allocated number and no task directory.
- A semantic/intent pass that catches the 310-vs-272 class (near-identical goal, one shared path),
  with its false-negative posture stated explicitly.
- Enforcement that a creation surface cannot silently skip, anchored where the write actually
  happens.
- Verdict vocabulary that distinguishes OPEN from CLOSED matches and cites a closed record by
  `project_name` + discharging artifact path, never a bare archived number.
- The 309/310/311 incident reproducible as a regression fixture yielding the three correct
  verdicts, plus the extended closed-record acceptance cases.

**Non-Goals**:
- Reworking the overlap predicate in `lib/file-scope-overlap.sh` or
  `context/patterns/file-footprint-overlap.md`. It is sound and deliberately scope-agnostic.
- Reworking the admission-time three/five-input model in `batch-orchestration-guardrails.md`.
  This is creation time; admission time is a different scan scope that already works.
- Auto-abandoning, auto-merging or auto-rewriting any existing task. Every verdict beyond an
  auto-added dependency edge is surfaced for a human ruling.
- Any semantic-embedding comparator. A second divergent matcher is the failure this task exists
  to prevent, reproduced inside the deduplication machinery.
- Building `/review`'s and `/errors`' missing Component 4a in-batch check. Those remain honestly
  marked gaps; this task does not retrofit the old requirement while adding a new one.

## Decisions Settled at Planning Time

**D1 — The script's name is `scripts/audit-task-proposals.sh`.** The inherited
`audit-open-tasks.sh` contradicts the widened contract (it compares against closed records too,
and it operates on *proposals*, not on open tasks). The `audit-` prefix is kept — there is
existing precedent (`scripts/audit-deletion-references.sh`) and it preserves continuity with the
record's own description — while `task-proposals` names what is actually audited and is plural
for the set call shape. The file is created under this name; nothing is created then renamed.
The declared `file_scope` entry `agent-system/extensions/core/scripts/audit-open-tasks.sh` is
superseded and must not be created.

**D2 — Verdict vocabulary (fixed, closed enum).** Open-side verdicts are actionable on the task
graph; closed-side verdicts are actionable on evidence; the two never collapse into one token.

| Verdict | Side | Carries | Operator action |
|---------|------|---------|-----------------|
| `genuinely-new` | — | nothing | create as proposed |
| `duplicate-of-open` | open | `project_number`, `project_name` | fold the proposal into the existing record |
| `subset-of-open` | open | `project_number`, `project_name`, `shared_paths` | narrow the existing record, order it behind |
| `superset-of-open` | open | `project_number`, `project_name`, `shared_paths` | widen the proposal or narrow it to the delta |
| `overlaps-open` | open | `project_number`, `project_name`, `shared_paths` | add a serializing dependency edge |
| `narrow-open` | open | `project_number`, `project_name`, `shared_paths` | narrow the proposal's own `file_scope` |
| `covered-by-closed` | closed | `project_name`, `discharging_artifact`, `project_number` (convenience only) | cite the artifact; drop, or state what is genuinely new relative to what landed |
| `scope-blind` | open or closed | `project_number`, `project_name` | the mechanical pass could not see this record (it declares no `file_scope`); judge it on the semantic shortlist alone |

`scope-blind` is the loud degradation the dependency on #165 exists to enable: a record with no
`file_scope` is invisible to the mechanical pass, and that invisibility is reported rather than
silently treated as non-overlap.

**D3 — A closed match never suppresses a proposal.** `covered-by-closed` is rendered alongside
the discharging artifact and the ruling is made by a human. The script has no suppression path at
all, because a suppression is unfalsifiable from the proposal side.

**D4 — This record owns the shared matcher for both call shapes.** The proposal-time shape task
421 needs is served here, not deferred: `--proposals-file FILE` / stdin accepts an array of
proposals with no `project_number` and no task directory, and the script is callable with the
enforcement hook nowhere in the path. 421 calls it the same way a creation surface does, earlier
and over a set. No second matcher is to be grown.

**D5 — The semantic pass's false-negative posture, stated explicitly.** A recall-biased
token-overlap shortlist over `title + description` is tuned toward over-inclusion. A false
positive costs a human one line's dismissal in the confirmation table; a false negative
reproduces the 310-vs-272 failure exactly. The script emits candidates, never a semantic verdict;
the final disposition is rendered by the calling surface (itself an LLM) reading the shortlisted
candidates' full text. A purely mechanical run of this script therefore cannot be claimed to
*decide* duplication — only to shortlist for it, and that limit is written into the script header
and the standard's Component 4b.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Migrating `meta-builder-agent.md`/`skill-fix-it` to `state-write.sh` is unscoped work discovered by research, not named in the record | M | H | Phased explicitly (Phase 2) and its paths added to `file_scope` in Phase 1, not silently assumed |
| The `Bash`-matcher backstop is a command-text scanner with real false-negative surface (an obfuscated `jq` evades it) | M | M | It is a backstop only; the primary gate inside `state-write.sh` has full pre/post-transform JSON visibility and is evadable only by bypassing `state-write.sh` entirely — which is exactly what the backstop catches |
| A lenient token-overlap threshold floods the confirmation table on short/generic titles | M | H | Accepted per D5; cheaper than a missed duplicate, and the non-goals forbid auto-suppression. Threshold is a single named constant with its tuning rationale inline |
| `state-write.sh` is called by 7+ sites; a new required flag would break every one | H | M | The gate fires ONLY when the transform introduces a new `active_projects` `project_number`. Every non-creating call is byte-for-byte unaffected; asserted by test |
| `meta-builder-agent.md`'s own write instruction is internally contradictory ("Edit tool target" at one line, "pass `--arg` to the jq call" a few lines later) | M | H | Phase 2 resolves the ambiguity by replacing both with one `state-write.sh` call, rather than picking one of the two |
| `commands/errors.md` has no `active_projects` write at all (verified: zero `next_project_number`/`active_projects` write sites) — its creation path is elsewhere | L | M | Phase 8 carries a Scope Hypothesis to locate its actual creation path before wiring; it is not assumed to need a migration |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1 |
| 3 | 4, 5, 6 | 3 (and 2, for phase 5) |
| 4 | 7, 8 | 5, 6 |
| 5 | 9 | 4, 7, 8 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Declare scope and settle the contract document [COMPLETED]

**Goal**: The verdict vocabulary, the two-pass model and the open/closed distinction exist in one
canonical document before any code is written, and this record's `file_scope` names every path
the later phases touch.

**Tasks**:
- [x] Extend `file_scope` with the paths research proposed plus D1's renamed script, via the
      implement-phase preflight transition's `--file-scope-add=<json-array>` flag (the array:
      `scripts/audit-task-proposals.sh`, `scripts/tests/test-audit-task-proposals.sh`,
      `scripts/state-write.sh`, `scripts/lib/file-scope-overlap.sh` (read-only source),
      `scripts/lib/project-number-inuse.sh` (read-only source), `manifest.json`,
      `root-files/settings.json`, `context/patterns/backlog-reconciliation.md`,
      `index-entries.json`, `agents/meta-builder-agent.md`, `skills/skill-meta/SKILL.md`,
      `skills/skill-fix-it/SKILL.md`, `skills/skill-spawn/SKILL.md`, `commands/task.md`,
      `commands/review.md`, `commands/errors.md`, each prefixed
      `agent-system/extensions/core/`). If the implement preflight has already run, apply the
      same addition through a `state-write.sh` call on this record's `file_scope` array.
      *(completed: preflight had already run (status was "implementing"), so applied via a
      `.claude/scripts/state-write.sh` call that dropped the superseded `audit-open-tasks.sh`
      entry and added the two `lib/` read-only sources; the other named paths were already
      present in `file_scope` from the plan phase)*
- [x] Create `context/patterns/backlog-reconciliation.md` mirroring
      `context/patterns/file-footprint-overlap.md`'s structure: Rule, Inputs, The Two Passes,
      Verdict Vocabulary, Consumers, Non-Goals. *(completed)*
- [x] Transcribe D2's verdict table and D5's false-negative posture into it as the single
      canonical copy — every later consumer references this document by path rather than
      restating the vocabulary. *(completed)*
- [x] Write the Non-Goals section explicitly: no suppression, no auto-mutation of an existing
      record, no semantic-embedding comparator, no opinion on the admission-time scan scope.
      *(completed)*
- [x] Record D1's name ruling and its reasoning in the document, so the superseded
      `audit-open-tasks.sh` name cannot be re-derived later. *(completed: "Naming Note (D1)"
      section)*
- [x] Add the document to `index-entries.json` under the `orchestrator` subdomain (research
      confirmed no backlog-reconciliation/dedup/audit entry exists there). *(deviation: altered —
      no `orchestrator` subdomain exists in index-entries.json; used subdomain `patterns` per the
      directory-matching convention every other entry follows, with `topics: ["orchestration"]`
      carrying the intended tag — see progress file deviation 1.6)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `scripts/validate-context-index.sh` plus
`scripts/tests/test-context-reachability.sh` cover a new context document and its index entry
completely; no script, hook, or registration surface is touched in this phase.

**Files to modify**:
- `agent-system/extensions/core/context/patterns/backlog-reconciliation.md` - new canonical
  contract document (vocabulary, two passes, open/closed distinction, consumers, non-goals)
- `agent-system/extensions/core/index-entries.json` - index the new document under `orchestrator`
- `specs/state.json` - this record's `file_scope` extended (via the sanctioned flag/writer, not a
  hand edit)

**Verification**:
- `bash .claude/scripts/validate-context-index.sh` passes with the new entry present
- `bash agent-system/extensions/core/scripts/tests/test-context-reachability.sh` passes
- `jq '.active_projects[] | select(.project_number==312) | .file_scope | length' specs/state.json`
  returns the extended count, and the array contains no `audit-open-tasks.sh` entry

---

### Phase 2: Migrate the two raw `state.json` writers onto `state-write.sh` [COMPLETED]

**Goal**: Every surface that creates an `active_projects` entry writes it through the one
mutex-guarded writer, so Phase 5's gate can observe the write at all.

**Tasks**:
- [x] Replace `agents/meta-builder-agent.md`'s task-creation write (the block whose comment reads
      "Update state.json (include dependencies array) — Edit tool target" and the later,
      contradicting note "Pass `--arg title` ... to the jq call") with one documented
      `state-write.sh` invocation using `--allocate-into` plus `--arg`/`--argjson` bindings,
      removing both of the contradictory instructions rather than choosing between them.
      *(completed: also converted the upfront `base_num + position` number precompute to
      incremental per-task allocation, since a precomputed map is incompatible with
      `--allocate-into`'s derive-at-write-time contract — recorded as a deviation below)*
- [x] Replace `skills/skill-fix-it/SKILL.md` Step 9.1's `current=$(cat specs/state.json)` plus
      two-step `jq`/`--slurpfile` pattern with the same `state-write.sh` shape. *(completed: same
      incremental-allocation treatment applied to `next_num`/`learn_it_task_num`)*
- [x] Keep each surface's existing `manage-topics.sh` and `generate-todo.sh` follow-up calls
      unchanged — this phase changes only where the `active_projects` mutation happens.
      *(completed — unchanged)*
- [x] Confirm the migrated call shapes satisfy `--allocate-into`'s existing recording assertion
      (the filter must record the allocated number into `active_projects`, or the write is
      refused with exit 3). *(completed: verified live against a scratchpad-copied state.json
      with `--state-file`, exit 0, entry recorded correctly)*
- [x] Remove `skill-fix-it`'s "state.json/TODO.md failures: Try two-step jq pattern" error-handling
      advice, which instructs the exact bypass this phase removes. *(completed)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `scripts/lint/lint-state-writer-boundary.sh` plus
`scripts/tests/test-lint-state-writer-boundary.sh` are the dedicated gate for exactly this
write-shape change, and both edited files are prose with no registration or deploy surface.

**Files to modify**:
- `agent-system/extensions/core/agents/meta-builder-agent.md` - route task creation through
  `state-write.sh`; resolve the Edit-tool-vs-jq contradiction
- `agent-system/extensions/core/skills/skill-fix-it/SKILL.md` - same migration for Step 9.1;
  drop the two-step-jq fallback advice

**Verification**:
- `grep -c state-write agent-system/extensions/core/agents/meta-builder-agent.md` and the same
  for `skills/skill-fix-it/SKILL.md` both return non-zero (both were 0 before this phase)
- `bash agent-system/extensions/core/scripts/lint/lint-state-writer-boundary.sh` passes
- `bash agent-system/extensions/core/scripts/tests/test-lint-state-writer-boundary.sh` passes
- No `cat specs/state.json`-into-`jq`-into-`mv` sequence remains in either file

---

### Phase 3: Implement `scripts/audit-task-proposals.sh` [COMPLETED]

**Goal**: One shared matcher that takes proposals and emits structured verdicts over the union of
open and closed records, serving both the creation-time and the proposal-time call shapes.

**Tasks**:
- [x] Create the script with two input modes: single-proposal flags (`--title`, `--description`,
      `--file-scope <json-array>`) and set mode (`--proposals-file FILE`, or the same JSON on
      stdin). Set mode must accept proposals with no `project_number` and no task directory (D4).
      *(completed: verified single-mode and set-mode produce byte-identical output for the same
      proposal)*
- [x] Build the backlog corpus by unioning four sources: `specs/state.json`'s non-terminal
      `active_projects` (open), `specs/state.json`'s `status: "completed"` entries (closed, not
      yet archived), and `specs/archive/state.json`'s `completed_projects`/`archived_projects`/
      `abandoned_projects` (closed). Reuse `lib/project-number-inuse.sh`'s archive-doc loading
      and duplicate-tolerant set shape rather than re-deriving either. *(completed: archive-doc
      loading mirrors that library's tolerance for a missing archive file; the full-record
      corpus construction is this script's own, since project-number-inuse.sh exports only
      number SETS, not full records)*
- [x] Mechanical pass: source `lib/file-scope-overlap.sh` and call `scopes_overlap()` (or splice
      `FILE_SCOPE_OVERLAP_JQ_DEFS` into a single `jq` program, following
      `orchestrate-batch-admit.sh`'s precedent) for each proposal against each corpus record.
      Classify the result as exact / subset / superset / partial-overlap to select among
      `duplicate-of-open`, `subset-of-open`, `superset-of-open`, `overlaps-open`, `narrow-open`.
      Do not modify the predicate. *(completed with one deviation: the mechanical pass alone
      emits exact/subset/superset/overlap -> duplicate-of-open/subset-of-open/superset-of-open/
      overlaps-open. It never independently emits `narrow-open` -- that verdict's action
      ("narrow the proposal's own file_scope") is not mechanically distinguishable from
      `overlaps-open`'s ("add a serializing edge") by containment alone; both are live vocabulary
      values a calling surface or human may still apply, but this script's own classifier does
      not choose between them. Verified live: a STRONG mechanical signal (exact/subset/superset)
      always outranks the semantic pass; a WEAK one (overlap, one shared path among many) is
      overridden by a strong semantic score into `duplicate-of-open` -- this combination-order
      fix (semantic checked before the weak overlap branch, not after) was necessary to satisfy
      the near-duplicate-with-one-shared-path acceptance shape; see progress file deviation 3.3*
- [x] Emit `scope-blind` for every corpus record that declares no `file_scope`, rather than
      treating its absence as non-overlap. *(completed: verified unconditional per the exact
      wording -- noted as a real output-volume trade-off in the script's own header, since most
      of this repo's live backlog currently declares no file_scope)*
- [x] Semantic pass: compute a recall-biased token-overlap shortlist over
      `title + description`, with the threshold as a single named constant carrying its tuning
      rationale inline. Stopword-strip and lowercase; no stemming, no embeddings. *(completed:
      SEMANTIC_THRESHOLD=0.4, token-overlap ratio over the smaller side's token count)*
- [x] Mark closed-side matches `covered-by-closed`, carrying `project_name` and the discharging
      artifact's path resolved from the record's `artifacts` array; include `project_number` only
      as a labelled convenience field. Never emit a bare archived number as the identifier.
      *(completed: verified against both a live-completed record and an archived record)*
- [x] Output one JSON object per proposal: the proposal's identity, a `verdicts` array, a `passes`
      object recording that each pass ran, and a `degradations` array. Exit 0 whenever the audit
      ran (a match is a verdict, not a failure), 1 on usage error, 2 when a required state file
      cannot be read (fail loudly, never an empty-corpus silent pass). *(completed: verified all
      three exit codes live)*
- [x] Write the header to state D5's false-negative posture and the no-suppression rule, and to
      reference `context/patterns/backlog-reconciliation.md` as the vocabulary's canonical home.
      *(completed)*
- [x] Register the script in `manifest.json`'s `provides.scripts` array. *(completed)*

**Timing**: 2 hours

**Depends on**: 1

**Verification Tier**: interface

**Tier Justification**: adding the script to `manifest.json`'s `provides.scripts` is a deploy
wiring surface that `scripts/validate-wiring.sh` and `verify-deploy.sh` check and no local
script-level suite covers.

**Scope Hypothesis**: the four-source corpus union is asserted here from the research report's
structural read of `specs/archive/state.json` (three arrays) and the dispatch's measured 380 + 35
counts. Confirm at implementation time with `jq` against both files that all four sources are
non-empty and that `status: "completed"` entries genuinely remain in the live file; if the live
file carries none at that moment, the fourth source still must be implemented and tested against
a fixture, not dropped.

**Files to modify**:
- `agent-system/extensions/core/scripts/audit-task-proposals.sh` - new shared matcher (D1's name)
- `agent-system/extensions/core/manifest.json` - add the script to `provides.scripts`

**Verification**:
- `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh` passes on the new script
- `--proposals-file` mode accepts a proposal with no `project_number` and no task directory and
  emits a verdict (D4's call shape works standalone)
- Single-proposal mode and set mode produce the same verdict for the same proposal
- An unreadable `specs/state.json` exits 2, never 0 with an empty verdict array
- `grep -c audit-task-proposals agent-system/extensions/core/manifest.json` returns non-zero
- `bash agent-system/extensions/core/scripts/validate-wiring.sh` passes -- **deferred to Phase 9**:
  this script unconditionally sources `deploy-root-guard.sh` with no `REPO_ROOT` override
  carve-out (unlike this script's own `audit-task-proposals.sh`, which does support one), so it
  can only run meaningfully against the DEPLOYED tree; the new script does not exist there until
  Phase 9's deploy step. Phase 3's registration (manifest grep, above) is verified now; the
  deploy-wiring check itself is verified at Phase 9 per the Batch Gate Deferral / full-gate-sweep
  design already in this plan's Phase 9.

---

### Phase 4: Regression fixture suite [COMPLETED]

**Goal**: The acceptance criteria are executable: the 309/310/311 incident and both closed-record
cases are fixtures that assert exact verdicts.

**Tasks**:
- [x] Create `scripts/tests/test-audit-task-proposals.sh` with hermetic fixture state files (a
      temp `state.json` and `archive/state.json` built by the test, never the live repo files).
      *(completed)*
- [x] Fixture A — the motivating incident: reconstruct the three proposals and the backlog as it
      stood, asserting `subset-of-open` naming 302, `duplicate-of-open` naming 272, and
      `genuinely-new` for the third. The 272 case must be caught by the semantic shortlist with
      exactly ONE shared path, proving the mechanical pass alone is insufficient. *(completed:
      uses analog project numbers 302/272 with reconstructed titles/descriptions/scopes matching
      the dispatch's own description of the incident; 310-analog's mechanical_class asserted
      "overlap" with exactly 1 shared path, proving the mechanical pass alone was insufficient)*
- [x] Fixture B — closed record in the archive: assert `covered-by-closed` carrying the record's
      `project_name` and the discharging artifact's path. *(completed)*
- [x] Fixture C — closed record still resident in the live state file with `status: "completed"`:
      assert the same verdict shape, proving the union is real and not archive-only. *(completed)*
- [x] Fixture D — a corpus record with no `file_scope`: assert `scope-blind` is emitted and the
      record is not silently classified as non-overlapping. *(completed)*
- [x] Fixture E — no-suppression: assert the script's output for a `covered-by-closed` match still
      contains the proposal, and that no exit code or flag causes a proposal to be dropped.
      *(completed)*
- [x] Assert no verdict identifies a closed record by bare number alone (every closed verdict
      carries `project_name` and `discharging_artifact`). *(completed)*
- [x] Register the suite in `manifest.json`'s `provides.scripts`. *(completed)*

**Timing**: 2 hours

**Depends on**: 3

**Verification Tier**: interface

**Tier Justification**: the new suite's `manifest.json` registration is a deploy wiring surface
checked only by `scripts/validate-wiring.sh`/`verify-deploy.sh`; running the suite itself does
not cover whether it was registered.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-audit-task-proposals.sh` - new fixture suite
- `agent-system/extensions/core/manifest.json` - add the suite to `provides.scripts`

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-audit-task-proposals.sh`
  passes with all five fixtures green *(verified: 17/17 individual assertions pass, 1 suite
  pass via run-all.sh --only)*
- The suite touches no file under `specs/` (assert by running it and checking
  `git status --porcelain specs/` is unchanged) *(verified: before/after snapshot comparison
  inside the suite itself, passes)*
- `bash agent-system/extensions/core/scripts/validate-wiring.sh` passes -- **deferred to Phase 9**
  (same `REPO_ROOT`-override limitation as Phase 3's identical deferral)

---

### Phase 5: Audit-evidence gate inside `state-write.sh` [COMPLETED]

**Goal**: A `specs/state.json` write that introduces a new `active_projects` entry without a
recorded audit verdict is refused, at the one place that can see the mutation.

**Tasks**:
- [x] Add `--audit-verdict FILE` (a JSON verdict document as emitted by
      `audit-task-proposals.sh`) and `--audit-override REASON` (an explicit, recorded human
      override) to the argument parser, following the existing `--arg`/`--allocate-into`
      validation conventions. *(completed)*
- [x] Capture the pre-transform `active_projects[].project_number` set inside the mutex, before
      the jq transform, alongside the existing `--allocate-into` prefix work. *(completed)*
- [x] After the transform and still inside the mutex, diff the post-transform number set against
      the pre-transform set. For every newly appearing entry, require either a verdict record in
      `--audit-verdict` whose proposal matches that entry, or an `--audit-override` reason.
      *(completed: match contract is `.proposal.id == new entry's project_name` -- documented in
      the script header as a new convention this phase introduces, since the real
      `project_number` is rarely known at audit time, before `--allocate-into` runs)*
- [x] Refuse with the new **exit 5** (0-4 are taken: success, usage, mutex, transform/assertion,
      empty-validation) and leave the target file untouched, naming the offending
      `project_number` and the remedy in the stderr message. *(completed)*
- [x] Record the verdict (or the override reason) into the new entry so the decision is durable
      and auditable after the fact, not merely checked in flight. *(completed:
      `.audit_verdict`/`.audit_override` fields)*
- [x] Make the gate fire ONLY when a new `active_projects` number appears: every status update,
      artifact link, `file_scope` edit and archive write is byte-for-byte unaffected. *(completed
      and verified: gated on `IS_DEFAULT_TARGET && !INIT_MODE`, confirmed via the existing
      `test-state-write-concurrency.sh`/`large-payload`/`regen-timing`/`spill-names` suites plus
      a live status-only-update check, all unaffected)*
- [x] Extend the script header's Exit codes block and Usage line with exit 5 and both new flags.
      *(completed)*
- [x] Add the gate's cases to the existing `state-write.sh` coverage: new-entry-without-verdict
      refused with exit 5; new-entry-with-verdict accepted; new-entry-with-override accepted and
      the reason recorded; a non-creating write unaffected; `--dry-run` applying the identical
      assertion (mirroring how the recording assertion already behaves on that path). *(completed:
      verified live against a full fake-repo skeleton under scratch, since this gate only fires
      against the DEFAULT target and `--state-file` override cannot exercise it. Found and fixed
      two real bugs during verification: (1) `$newnums | index(.project_number)` indexed the
      wrong `.` inside `map()`, fixed to bind `.project_number as $pn` first; (2)
      `$by_id[.project_name]` raised "Cannot index object with null" for an entry with no
      `project_name`, fixed with `(.project_name // "")`. Also found and fixed a REGRESSION this
      phase introduced in three pre-existing suites (`test-state-write-concurrency.sh`,
      `test-state-write-large-payload.sh`, `test-force-phases.sh`) whose own fixtures create
      `active_projects` entries without audit evidence -- added `--audit-override` to each
      fixture-setup call; all three (plus `test-state-write-regen-timing.sh` and
      `test-state-write-spill-names.sh`, unaffected) now pass. A full `run-all.sh` sweep surfaced
      5 additional failing suites with no connection to this gate (confirmed: zero mentions of
      "audit-evidence" in any of their output) -- recorded as a non-fatal issue (scope excursion,
      likely a concurrent sibling task's in-flight changes) rather than investigated further,
      since they are outside this task's file_scope)*

**Timing**: 2 hours

**Depends on**: 2, 3

**Verification Tier**: local

**Tier Justification**: the gate is internal to one already-registered script, and the
`state-write.sh` cases added in this phase plus
`scripts/tests/test-lint-state-writer-boundary.sh` cover both the new refusal and the
no-regression-for-existing-callers claim.

**Scope Hypothesis**: exit codes 0-4 are asserted taken and 5 free, from this script's own
header's Exit codes block. Confirm with `grep -n 'exit 5' scripts/state-write.sh` returning
nothing before claiming 5; if taken, use the next free code and update the header accordingly.

**Files to modify**:
- `agent-system/extensions/core/scripts/state-write.sh` - new flags, pre/post-transform
  new-entry diff, exit 5 refusal, verdict recording, header updates

**Verification**:
- A `state-write.sh` call adding a new `active_projects` entry with no `--audit-verdict` exits 5
  and leaves the target file byte-identical *(verified live)*
- The same call with a matching `--audit-verdict` succeeds and the verdict is present in the
  written entry *(verified live)*
- The same call with `--audit-override` succeeds and the reason is present in the written entry
  *(verified live)*
- A status-only update, an artifact link, and an archive write each still succeed with no new
  flags (no regression for the 7+ existing call sites) *(verified: status-only update live, plus
  all four `test-state-write-*.sh` suites green, plus the pre-existing archive/`--state-file`
  case 5 in `test-state-write-concurrency.sh`)*
- `--dry-run` refuses the no-verdict case identically, applying no write *(verified live)*
- `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh` passes *(verified)*

---

### Phase 6: Component 4b in the creation standard [NOT STARTED]

**Goal**: The standard REQUIRES backlog reconciliation, and its compliance table honestly reports
each surface's state against the new requirement.

**Tasks**:
- [ ] Insert `### 4b. Backlog Reconciliation (Required)` after the existing 4a and before
      Component 5, with no renumbering of later components.
- [ ] Specify its inputs (the four-source open ∪ closed union), its two passes (mechanical
      footprint via the shared predicate; semantic shortlist), its verdict vocabulary (reference
      `context/patterns/backlog-reconciliation.md` by path — do not restate the table), and its
      non-silence obligation.
- [ ] State the non-silence obligation concretely: every verdict other than `genuinely-new` and
      an auto-handled `overlaps-open` edge MUST appear in the Component 7 confirmation summary,
      and no surface may suppress one.
- [ ] Extend Component 7's summary table format with a **Backlog Check** column and a worked
      example row per verdict class, reusing Component 7's existing Foreground Requirement rather
      than inventing a new interactive gate (per task 300's measured rehome finding).
- [ ] Add a **Backlog Reconciliation (4b)** column to the Current Compliance Status table, marked
      honestly per surface — including "No" for `/review` and `/errors`, which do not satisfy even
      the existing 4a check, so the new requirement does not silently inherit a false "Yes".
- [ ] Add the new component to the Implementation Checklist's Required Components list.
- [ ] Add the closed-record durable-anchor rule: a closed match is cited by `project_name` plus
      the discharging artifact's path, never a bare archived number, for the same reason
      `rules/no-task-references-in-deliverables.md` gives.

**Timing**: 1.5 hours

**Depends on**: 1, 3

**Verification Tier**: prose

**Tier Justification**: this phase edits one standards document under `docs/` with no code, no
registration, and no index entry; `scripts/check-extension-docs.sh` is the only applicable check
and it covers the whole edit.

**Files to modify**:
- `agent-system/extensions/core/docs/reference/standards/multi-task-creation-standard.md` -
  Component 4b, Component 7 column, compliance table column, checklist entry

**Verification**:
- `grep -n '### 4b' docs/reference/standards/multi-task-creation-standard.md` finds the component
  between 4a and Component 5
- The Current Compliance Status table has the new column with a value for every listed surface and
  no blank cells
- The document references `context/patterns/backlog-reconciliation.md` rather than restating the
  verdict table (assert the table appears exactly once across the two files)
- `bash agent-system/extensions/core/scripts/check-extension-docs.sh` passes

---

### Phase 7: Structural backstop hook and registration [NOT STARTED]

**Goal**: A surface that bypasses `state-write.sh` to mutate `active_projects` is refused, so
Phase 5's gate cannot be sidestepped by reverting to a raw `jq` write.

**Tasks**:
- [ ] Create `hooks/validate-task-creation-audit.sh` following the `Bash`-matcher command-text
      family (`guard-destructive-git.sh`, `guard-git-push.sh`), not the `Write|Edit` content-scanner
      family. Its job is narrow and structural: detect a Bash command mutating `specs/state.json`'s
      `active_projects` outside `state-write.sh`, and refuse it with `exit 2` plus a remediation
      banner naming `state-write.sh` and the audit flags.
- [ ] Do not re-implement the audit-verdict check in the hook. Phase 5's gate owns it; the hook
      only forces the write through the place that performs it.
- [ ] State the hook's own false-negative surface in its header (a variable-indirected or
      sufficiently obfuscated `jq` invocation evades command-text matching), and that it is a
      backstop, never the primary gate.
- [ ] Register the hook bare on the `Bash` PreToolUse matcher in `root-files/settings.json`,
      following the `exit 2`-surviving registration pattern (per the dependency on #282) that the
      two existing `Bash`-family guards already use.
- [ ] Add the hook to `manifest.json`'s `provides.hooks` array.
- [ ] Add a test suite asserting: a raw-`jq` `active_projects` write is refused with exit 2; a
      `state-write.sh` call is allowed; a read-only `jq` query against `state.json` is allowed; a
      write to an unrelated file is allowed. Register the suite in `provides.scripts`.

**Timing**: 1.5 hours

**Depends on**: 5

**Verification Tier**: interface

**Tier Justification**: hook registration spans `root-files/settings.json` and `manifest.json`,
the cross-cutting surface `scripts/lint/lint-hook-registration-paths.sh`,
`scripts/validate-wiring.sh` and `scripts/check-runtime-file-tracking.sh` check and no
script-local suite covers.

**Files to modify**:
- `agent-system/extensions/core/hooks/validate-task-creation-audit.sh` - new structural backstop
- `agent-system/extensions/core/root-files/settings.json` - register bare on the `Bash` matcher
- `agent-system/extensions/core/manifest.json` - `provides.hooks` + the new test suite in
  `provides.scripts`
- `agent-system/extensions/core/scripts/tests/test-validate-task-creation-audit.sh` - new suite

**Verification**:
- `jq '.hooks.PreToolUse[] | select(.matcher=="Bash")' root-files/settings.json` shows the new
  hook registered alongside `guard-destructive-git.sh`
- `bash agent-system/extensions/core/scripts/lint/lint-hook-registration-paths.sh` passes
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-validate-task-creation-audit.sh`
  passes
- `bash agent-system/extensions/core/scripts/validate-wiring.sh` and
  `bash agent-system/extensions/core/scripts/check-runtime-file-tracking.sh` pass
- The hook allows a read-only `jq` query against `state.json` (no false positive on reads)

---

### Phase 8: Wire the audit call into every creation surface [NOT STARTED]

**Goal**: Each creation surface obtains a verdict before confirmation, at the skill layer where
the human ruling is reachable, and passes the verdict to the write.

**Tasks**:
- [ ] `skills/skill-meta/SKILL.md`: call `audit-task-proposals.sh` in Stage 2.5 (Pre-Confirmation,
      foreground) over the whole proposal set, render non-`genuinely-new` verdicts into the
      Component 7 confirmation table's Backlog Check column, and pass the resulting verdict
      document to `meta-builder-agent` alongside `mode=confirmed`. The agent performs no
      interactive prompt — this is task 300's measured rehome pattern, which the standard already
      states as the Foreground Requirement.
- [ ] `agents/meta-builder-agent.md`: consume the verdict document passed in and forward it to the
      Phase 2 `state-write.sh` call's `--audit-verdict` flag. Add no `AskUserQuestion` call.
- [ ] `commands/task.md`: call the audit in Create Task Mode and Expand Mode before confirmation;
      pass the verdict to the existing `state-write.sh` invocation.
- [ ] `skills/skill-fix-it/SKILL.md`: call the audit before Step 9's confirmation; pass the
      verdict to the Phase 2 `state-write.sh` call.
- [ ] `skills/skill-spawn/SKILL.md`: call the audit on the proposed follow-up task; pass the
      verdict to its existing `state-write.sh` invocation.
- [ ] `commands/review.md`: call the audit on each proposed task before confirmation; pass the
      verdict to its existing `state-write.sh` invocation.
- [ ] `commands/errors.md`: call the audit before task entries are drafted; render the verdicts
      non-interactively (this surface is intentionally non-interactive) and pass them through to
      whatever performs its write.
- [ ] In each surface, state that a verdict is never suppressed and that no surface auto-abandons,
      auto-merges or auto-rewrites an existing record — only an `overlaps-open` edge is
      auto-applied, and it is annotated in the confirmation summary exactly as 4a's auto-added
      edges already are.

**Timing**: 2 hours

**Depends on**: 3, 5, 6

**Verification Tier**: local

**Tier Justification**: all seven edited files are prose instruction documents with no
registration surface, and `scripts/validate-wiring.sh` plus
`scripts/check-consumer-freshness.sh` cover the per-surface call-site wiring claim.

**Scope Hypothesis**: this phase asserts seven wiring sites and that `commands/errors.md` needs
only an audit call, not a `state-write.sh` migration — grounded in the verified finding that it
contains no `next_project_number`/`active_projects` write site at all (one read-only `jq` query
only). Confirm at implementation time where `/errors` actually creates its fix task (it may
delegate to `/task` or to a script, in which case that delegate is already covered and the wiring
site is the hand-off, not a new write); if it turns out to carry its own raw write, add it to
Phase 2's migration set rather than wiring an audit call onto a bypassing write.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-meta/SKILL.md` - Stage 2.5 audit call + table column
- `agent-system/extensions/core/agents/meta-builder-agent.md` - consume and forward the verdict
- `agent-system/extensions/core/commands/task.md` - audit call in both creation modes
- `agent-system/extensions/core/skills/skill-fix-it/SKILL.md` - audit call before Step 9
- `agent-system/extensions/core/skills/skill-spawn/SKILL.md` - audit call on the follow-up task
- `agent-system/extensions/core/commands/review.md` - audit call per proposed task
- `agent-system/extensions/core/commands/errors.md` - non-interactive audit call

**Verification**:
- `grep -lc audit-task-proposals` finds a call site in all seven files
- No file gained an `AskUserQuestion` call inside an agent (assert
  `grep -c AskUserQuestion agents/meta-builder-agent.md` is unchanged from its pre-phase value)
- `bash agent-system/extensions/core/scripts/validate-wiring.sh` passes
- `bash agent-system/extensions/core/scripts/check-consumer-freshness.sh` passes
- The compliance table's new column (Phase 6) now reads consistently with what each surface
  actually does

---

### Phase 9: Deploy, acceptance, and full gate sweep [NOT STARTED]

**Goal**: The mechanism is live in the deploy tree, the acceptance criteria pass end to end
against the real repository state, and the complete gate set is green.

**Tasks**:
- [ ] Deploy the source store to `.claude/` so the new script, hook, registration and documents
      are present in the deploy tree.
- [ ] Run the end-to-end acceptance check from the dispatch: a creation attempt that duplicates,
      subsumes or is subsumed by an open record cannot complete without the verdict being
      surfaced. Exercise it through at least one real surface, not only the fixture suite.
- [ ] Run the extended closed-record acceptance check against the live repository: one archived
      record and one still-live `completed` record each yield `covered-by-closed` naming
      `project_name` and the discharging artifact.
- [ ] Confirm the backstop refuses a raw-`jq` `active_projects` write in the deployed tree
      (registration survived deploy, `exit 2` survives bare registration).
- [ ] Run the complete gate set: `scripts/tests/run-all.sh` (unfiltered — a `--only` subset is
      explicitly not evidence for this phase), `scripts/validate-state.sh`,
      `scripts/validate-wiring.sh`, `scripts/validate-context-index.sh`,
      `scripts/verify-deploy.sh` (all gates, no `--only-gate`), `scripts/lint/lint-shellcheck.sh`,
      `scripts/lint/lint-state-writer-boundary.sh`,
      `scripts/lint/lint-hook-registration-paths.sh`, `scripts/check-extension-docs.sh`,
      `scripts/check-runtime-file-tracking.sh`, `scripts/check-task-references.sh`,
      `scripts/check-record-versioning.sh`.
- [ ] Confirm no `.claude/**` path was hand-authored at any point in this task (every edit landed
      in `agent-system/extensions/core/` and reached `.claude/` only by deploy).

**Timing**: 1 hour

**Depends on**: 4, 7, 8

**Verification Tier**: full

**Files to modify**:
- None (deploy and verification only; the deploy tree is generated, never hand-edited)

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` passes unfiltered with no NEW
  failures against `known-failures.txt`
- `bash agent-system/extensions/core/scripts/verify-deploy.sh` passes with all gates, no
  `--only-gate` narrowing
- Every lint and validator listed above exits 0
- Both acceptance fixtures (open-backlog and closed-record) pass against live repository state,
  not only against hermetic fixtures
- `git status --porcelain .claude/` shows only deploy-generated changes

---

## Testing & Validation

- [ ] Fixture A reproduces the motivating incident and yields exactly `subset-of-open` (302),
      `duplicate-of-open` (272), `genuinely-new`
- [ ] The 272 duplicate is caught by the semantic pass with exactly ONE shared file path, proving
      the mechanical pass alone is insufficient
- [ ] Fixtures B and C both yield `covered-by-closed` carrying `project_name` and the discharging
      artifact's path — one from `specs/archive/state.json`, one from a live `completed` entry
- [ ] No verdict anywhere identifies a closed record by bare number alone
- [ ] Fixture D yields `scope-blind` for a record with no `file_scope` (loud degradation, not
      silent non-overlap)
- [ ] Fixture E proves no code path suppresses a proposal
- [ ] `--proposals-file`/stdin mode works for proposals with no allocated number and no task
      directory, with the enforcement hook nowhere in the path (task 421's call shape)
- [ ] A new-`active_projects`-entry write without a verdict is refused (exit 5), with the target
      file untouched
- [ ] Every existing non-creating `state-write.sh` call site still succeeds unchanged
- [ ] The backstop hook refuses a raw-`jq` `active_projects` write and allows a read-only query
- [ ] Full unfiltered `run-all.sh` and all-gates `verify-deploy.sh` green

## Artifacts & Outputs

- `agent-system/extensions/core/context/patterns/backlog-reconciliation.md` (new)
- `agent-system/extensions/core/scripts/audit-task-proposals.sh` (new)
- `agent-system/extensions/core/scripts/tests/test-audit-task-proposals.sh` (new)
- `agent-system/extensions/core/hooks/validate-task-creation-audit.sh` (new)
- `agent-system/extensions/core/scripts/tests/test-validate-task-creation-audit.sh` (new)
- Modified: `scripts/state-write.sh`, `docs/reference/standards/multi-task-creation-standard.md`,
  `manifest.json`, `root-files/settings.json`, `index-entries.json`,
  `agents/meta-builder-agent.md`, `skills/skill-meta/SKILL.md`, `skills/skill-fix-it/SKILL.md`,
  `skills/skill-spawn/SKILL.md`, `commands/task.md`, `commands/review.md`, `commands/errors.md`
- A completion summary at `specs/312_backlog_reconciliation_required_at_task_creation/summaries/01_backlog-reconciliation-task-creation-summary.md`

## Rollback/Contingency

Each phase commits independently, so rollback is per-phase `git revert` of that phase's commit.
Two phases need specific care:

- **Phase 5 (the `state-write.sh` gate)** is the only change that can refuse a write every other
  surface depends on. If it misfires, the immediate mitigation is `--audit-override` (which is
  part of the design, not an escape hatch), and the rollback is reverting that one commit — the
  rest of the mechanism (matcher, documents, migrations) remains useful and harmless without it.
- **Phase 7 (the backstop hook)** can block legitimate Bash activity if its command-text match is
  too broad. Rollback is removing its `root-files/settings.json` registration and redeploying;
  the hook file itself is inert unless registered.

Phase 2's migration is the one change that is harder to revert cleanly, because Phase 5 and
Phase 8 both assume it. If Phase 2 must be rolled back, Phases 5 and 8 roll back with it.

Before any phase that edits `scripts/state-write.sh` or `root-files/settings.json`, take a
non-reverting defensive checkpoint:
`bash .claude/scripts/git-snapshot.sh 312 --no-revert`.
