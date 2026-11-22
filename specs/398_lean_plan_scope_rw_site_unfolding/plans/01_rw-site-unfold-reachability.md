# Implementation Plan: Task #398

- **Task**: 398 - lean_plan_scope_rw_site_unfolding
- **Status**: [IMPLEMENTING]
- **Effort**: 1.5 hours
- **Dependencies**: 397 (ordering constraint on `agent-system/extensions/lean/index-entries.json` only; no content coupling)
- **Research Inputs**: specs/398_lean_plan_scope_rw_site_unfolding/reports/01_rw_site_unfolding_reachability.md
- **Artifacts**: plans/01_rw-site-unfold-reachability.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The rw-site definitional-unfold caveat is already present in
`agent-system/extensions/lean/context/project/lean4/patterns/dependency-tracing.md` in generic
form (section `## Grep-Based Blast Radius: Cover Unfold Spellings, Not Just Importers`), landed
independently by a cross-repository conclusion-stage dispatch. What remains undone is (1) the
concrete worked example and the enumerated, runnable multi-spelling grep probe that the dispatch
record calls "the actual working recipe", and (2) the reachability leg: that file's index entry
carries no `plan-authoring` keyword, so the only mechanism by which the core planner ever reads
`project/**` content (`planner-agent.md` Stage 4 item 13) does not select it. The plan extends
the existing section in place, resyncs the entry's coupled `line_count`, adds the one keyword
that makes the file reachable at plan time, then redeploys and verifies.

### Research Integration

The research report settles the dispatch's stated open question by reading, and the plan adopts
its conclusions without re-litigating them:

- Plan-time discovery of `project/**` content runs through exactly one mechanism:
  `planner-agent.md` Stage 4 item 13, gated on `load_when.task_types[]` matching the dispatch's
  `task_type` **AND** `keywords[]`/`topics[]` containing the literal `plan-authoring`. The
  `task_types` axis alone is necessary but not sufficient; `load_when.agents[]` plays no part.
- Remedy (a) (naming `planner-agent` in `load_when.agents[]`) is mechanically prohibited, not a
  judgment call — `planner-agent.md` carries an explicit MUST NOT and
  `context-discovery.md`'s "Cross-Domain-Shared-Agent Hazard in `agents[]`" names this exact
  scenario.
- The adopted remedy is a narrower realization of candidate (c): tag the file's **own** index
  entry with `plan-authoring`, so the existing query resolves it. No second file, no pointer, no
  change to the core planner's contract, nothing outside the declared file scope.

### Carried-Figure Re-Validation

Checked against live state before planning, per the dispatch's Premise Re-Validation block. Each
result is stated explicitly, including the confirmations:

| Carried claim | Result |
|---|---|
| `SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/lean/**` | **CONFIRMED unchanged.** `.claude-extensions.json` -> `.extensions.lean.source_dir` resolves to `/home/benjamin/.config/nvim/agent-system/extensions/lean`. |
| `complete repair set (3 sites in 2 files)` and `ALL TWELVE definitional-unfold spellings` | **NOT INDEPENDENTLY VERIFIABLE on this machine.** The originating issue log (`~/Projects/BimodalLogic/specs/716_sliced_certificate_liveat_nontermination/`) is absent — re-confirmed by direct `ls`, matching the research report. These figures are carried as reported provenance, never as measurements this repository can check. Consequence for the edit: see Phase 1's reconstruction-labelling requirement. |
| `load_when`'s allowed keys are `agents`, `commands`, `task_types`, `always`, enforced by `check-extension-docs.sh` Rule T | **CONFIRMED unchanged.** The script's Rule T loop carries the literal case arm `agents\|commands\|task_types\|always` and reports any other key as forbidden. |
| Dispatch appendix: "`index-entries.json` leg was NOT updated" | **CONFIRMED, but the gap is the keyword, not the count.** The entry's `line_count: 242` matches `wc -l` (242) today — an unrelated later sync commit repaired the drift the content landing introduced. The live gap is the missing `plan-authoring` keyword. |
| Dispatch body: "MEASURED: the file contains no occurrence of `rw`, `unfold`, `whnf` or `heartbeat`" | **NOW STALE — this figure is no longer true.** 12 lines in the live file match that pattern set; the `## Grep-Based Blast Radius` section supplies them. The dispatch's own appended "ALREADY LANDED" note anticipates this. |
| Dispatch appendix: `load_when.agents = ["lean-implementation-agent"]`, `load_when.task_types = ["lean4"]` for this entry | **CONFIRMED unchanged**, live. |
| Dispatch appendix: "Across all 41 entries ... NOT ONE names a planner agent" | **Still true in substance; the count has moved.** The report re-measured 45 `agents[]`-bearing entries; the only values anywhere are `lean-research-agent` and `lean-implementation-agent`. |

Additionally measured for this dispatch: this plan dispatch's own `task_type` is `meta`, and the
Stage 4 item 13 query (`project/**` entry with `task_types[]` containing `meta` AND a
`plan-authoring` keyword/topic) returns **zero hits** against the deployed
`.claude/context/index.json`. Zero hits is the documented normal case, not an error.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch context and no `roadmap_flag` is set; no roadmap
consultation performed and no roadmap phases added.

## Goals & Non-Goals

**Goals**:
- Land the concrete rw-site worked example and an enumerated, runnable multi-spelling grep probe
  inside the existing `## Grep-Based Blast Radius: Cover Unfold Spellings, Not Just Importers`
  section of `dependency-tracing.md`.
- Keep every section heading and probe count in that file internally consistent after the edit —
  in particular, leave `## Four Probe Shapes` and its four `### Shape N` children untouched.
- Make `dependency-tracing.md` reachable at plan time by adding the `plan-authoring` keyword to
  its own index entry, the narrowest remedy the measured mechanism admits.
- Keep the entry's coupled `line_count` accurate in the same phase that moves it.
- Redeploy so the deployed `.claude/context/index.json` carries the new keyword, and verify the
  Stage 4 item 13 query actually selects the file for a `lean4` plan dispatch.

**Non-Goals**:
- No change to the mechanics, code, or count of the four existing probe shapes. The new material
  is a sibling of that section, never a fifth shape.
- No change to `planner-agent.md` or to any core planner contract. No loosening of Stage 4 item
  13's `plan-authoring` co-requirement (candidate remedy (b)) — recorded as a follow-up below.
- No edit to `plan-authoring-gate-collisions.md`. It is the only other file carrying the
  `plan-authoring` tag and it is a concurrent sibling task's declared territory this cycle.
- No `planner-agent` entry in any `load_when.agents[]` array.
- No heartbeat-limit or build-timeout policy change.
- No hand-authored write anywhere under `.claude/**`; that tree is a disposable deploy artifact
  regenerated from the source store.

## Decisions

Recorded here as the durable record the dispatch's "WHAT IS OWED" clause requires. The research
report's candidate-remedy table is the companion record; no file under `agent-system/**` records
any of this, both because it would be out of declared scope and because task-management
provenance does not belong in a deliverable.

| Candidate remedy | Disposition | Reason |
|---|---|---|
| (a) Add the planning agent to `load_when.agents` | **Rejected** | Mechanically prohibited in two places: `planner-agent.md`'s own MUST NOT under Stage 4 item 13, and `context-discovery.md`'s Cross-Domain-Shared-Agent Hazard section. A shared agent named in a domain entry's `agents[]` pulls that domain's content into every other domain's plan dispatch. |
| (b) Rely on the `task_types` axis and fix what stops the planner querying it | **Out of scope, recorded as a follow-up** | Measured: `task_types` is not what gates the planner's read — the `plan-authoring` keyword co-requirement is. Removing or loosening that co-requirement changes the core planner's own shared, cross-domain query. The dispatch's NOT IN SCOPE clause reserves exactly this as a larger piece of work. |
| (c) Short plan-time pointer wherever the planner demonstrably reads | **Adopted, in a narrower realization** | Literally executed, (c) means a cross-reference inside `plan-authoring-gate-collisions.md` — a concurrent sibling's live territory this cycle. Tagging `dependency-tracing.md`'s own entry reaches the identical query with no second file and no collision. |
| (d) Conclude the planner already reaches it | **Rejected** | Measured false: the entry's `keywords[]` carries no `plan-authoring` tag, so Stage 4 item 13's query does not select it today. |

**Follow-ups to record, not to absorb here**:
- Candidate (b): whether Stage 4 item 13's `plan-authoring` co-requirement should be loosened, or
  plan-stage context discovery restructured for all extensions. Larger than this record.
- If `dependency-tracing.md` later grows past a comfortable plan-time read budget, the cheaper
  alternative is a one-line cross-reference inside `plan-authoring-gate-collisions.md` instead of
  loading this file in full — which needs coordination with that file's owning task and must not
  be taken opportunistically from here. Budget is not a concern today.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| New material folded into `## Four Probe Shapes`, leaving a "Four" heading with five children — the dispatch names this the obvious way to get it wrong | M | L | Phase 1 edits strictly inside the existing `## Grep-Based Blast Radius...` section; its verification greps the heading and the four `### Shape N` lines to confirm they are byte-identical. |
| A reconstructed spelling enumeration presented as a verbatim transcription of an unreachable source | M | M if unflagged | Phase 1 requires an inline label stating the enumeration is reconstructed from Lean 4's own unfold-triggering syntax forms, not transcribed. |
| A count asserted in prose disagreeing with the list it introduces | L | M | Phase 1's verification counts the enumerated items mechanically and compares against the number the prose states. |
| `generate-context-line-counts.sh --write` rewriting sibling entries' `line_count` values (concurrent siblings are editing other indexed lean context files this cycle), then an unscoped `git add` committing their hunks | M | M | Phase 1 resyncs **only** this one entry's `line_count` with a targeted `Edit`, never the sweep. If the sweep is run anyway (it also runs inside deploy), review `git diff -- index-entries.json` and commit only this entry's hunks; a foreign hunk is reported, never absorbed. |
| Whole-file `jq` round-trip on `index-entries.json` reflowing unrelated records | M | L | Both index edits use the `Edit` tool with a unique `old_string`. `jq` is read-only here. |
| Record-versioning or task-number language leaking into the source-store markdown edit | M | L | Phase 1 states the current design only — no "previously", "no longer", "the earlier list", and no task numbers. Gate 4 (task-reference lint) covers the latter mechanically. |
| Deploy regenerating the whole tree concurrently with a sibling's own deploy | M | L | Phase 3 declares the whole-tree claim via the reserved sentinel; `deploy-headless.sh` carries its own `specs/.deploy-lock` mutex. A foreign in-flight build is reported, not worked around. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 1, 2 |

Phases within the same wave can execute in parallel. Phases 1 and 2 both write
`index-entries.json` and are deliberately serialized rather than parallelized.

### Phase 1: Land the Worked Example and the Enumerated Unfold-Spelling Probe [IN PROGRESS]

**Goal**: The `## Grep-Based Blast Radius: Cover Unfold Spellings, Not Just Importers` section
carries the concrete worked example and a runnable, enumerated multi-spelling grep probe, and the
index entry's coupled `line_count` matches the file's new length.

**Tasks**:
- [x] Re-read `agent-system/extensions/lean/context/project/lean4/patterns/dependency-tracing.md`
      in full immediately before editing (a sibling may have touched it; the territory block
      requires the re-read). *(completed)*
- [x] Extend the existing `## Grep-Based Blast Radius...` section in place with the concrete
      worked example: a fixture file carrying an `rw [<def>]` of the changed definition while not
      being a direct dependent of the defining module; the definitional switch unfolding to a
      different fixed-point representative; the induction lemma unifying through that
      representative into a whnf/kernel heartbeat timeout at the 200000-heartbeat limit; and the
      complete repair set's shape (3 sites across 2 files). Name the originating run as a Lean 4
      orchestration run in a separate repository — never a task number, never a `specs/**` path.
      *(completed)*
- [x] Replace that section's free-text spelling description with an enumerated, runnable probe:
      an explicit spelling list plus a short shell loop grepping the whole repository for each,
      in the same give-runnable-code style the four probe shapes already use. Candidate
      enumeration (the implementer may refine the members, but see the count obligation below):
      `rw [name]`, `rw [← name]`, `rw [name] at h`, `simp [name]`, `simp only [name]`,
      `dsimp [name]`, `unfold name`, `unfold_let name`, `delta name`, `show _ from name`, a
      `@[simp]`-triggered unfold of `name`, and a `@[reducible]`-triggered unfold of `name`.
      *(completed: used the twelve-item candidate list verbatim as the shell array)*
- [x] Label the enumeration inline as **reconstructed** from Lean 4's own unfold-triggering
      syntax forms rather than transcribed from the originating run's issue log, which is not
      reachable from this repository. Do not present it as a verbatim list. *(completed)*
- [x] Make the prose's stated count and the enumeration's actual length agree. If the refined
      list is not twelve items, the prose says the number the list actually has — a number
      asserted in prose that disagrees with its own list is the defect this task exists to avoid
      reproducing. *(completed: prose says "twelve forms", array has 12 entries — verified
      mechanically)*
- [x] Confirm `## Four Probe Shapes` and its four `### Shape N:` headings are byte-identical to
      their pre-edit state, and that the new material sits in the sibling section rather than
      under that heading. *(completed: grep counts unchanged at 1 and 4 respectively)*
- [x] Re-read the live `wc -l` of the edited file, then update **only** the
      `project/lean4/patterns/dependency-tracing.md` entry's `line_count` in
      `agent-system/extensions/lean/index-entries.json` with an `Edit` whose `old_string` spans
      the entry's `"path"` and `"line_count"` lines together (that pair is unique; a bare
      `"line_count": 242` is not). *(completed: 242 -> 286)*
- [ ] Review `git status --short` and `git diff --staged`, stage the two files by explicit name,
      and commit. If `index-entries.json` carries a hunk for any other entry, stop and report it
      rather than committing it.

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: the enumeration is hypothesized to land as twelve concrete spellings (the
dispatch's carried figure, which this repository cannot verify — see Carried-Figure
Re-Validation). Confirm at implementation time by counting the list the edit actually writes and
matching the prose's stated number to that count; do not assume twelve.

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh
agent-system/extensions/lean/context/project/lean4/patterns/dependency-tracing.md
agent-system/extensions/lean/index-entries.json` covers this phase's whole touched set, selecting
`test-index-entries-schema.sh`, `test-context-reachability.sh`, `test-deploy-orphans.sh`,
`test-install-uninstall-extension.sh`, `test-manifest-scripts-sync.sh` and
`test-roadmap-command-registration.sh` (run once over both paths; the markdown path alone maps to
no suite, so the real suite names are the honest claim, not the sentinel).

**Files to modify**:
- `agent-system/extensions/lean/context/project/lean4/patterns/dependency-tracing.md` - extend
  the existing `## Grep-Based Blast Radius...` section with the worked example and the enumerated
  runnable probe; no other section touched
- `agent-system/extensions/lean/index-entries.json` - resync this one entry's `line_count` to the
  file's new length (the coupled generated surface this phase's edit moves)

**Verification**:
- `grep -c '^## Four Probe Shapes$'` returns 1 and `grep -c '^### Shape '` returns 4, unchanged.
- The enumerated list's item count equals the number the surrounding prose states.
- The reconstruction label is present in the section.
- `jq -r '.entries[] | select(.path | test("dependency-tracing")) | .line_count'` on the source
  index equals `wc -l` of the edited file.
- `bash agent-system/extensions/core/scripts/verify-touched.sh <the two paths above>` is green.
- `git diff --staged --name-only` lists exactly the two declared files.

---

### Phase 2: Make the File Reachable at Plan Time [NOT STARTED]

**Goal**: `dependency-tracing.md`'s index entry carries the `plan-authoring` keyword, so
`planner-agent.md` Stage 4 item 13's query selects it for every `lean4` plan dispatch — with no
change to the core planner and no `planner-agent` entry in any `load_when.agents[]`.

**Tasks**:
- [ ] Re-read the `project/lean4/patterns/dependency-tracing.md` entry in
      `agent-system/extensions/lean/index-entries.json` immediately beforehand.
- [ ] Add `"plan-authoring"` to that entry's `keywords[]` array with an `Edit` anchored on a
      unique `old_string` inside this entry's own keyword block (e.g. the
      `"reverse-dependency"` / `"retirement"` pair). Do not pipe the file through `jq`.
- [ ] Leave `load_when` untouched: `agents` stays `["lean-implementation-agent"]`, `task_types`
      stays `["lean4"]`. Adding `planner-agent` here is prohibited and is not an alternative.
- [ ] Optionally refresh the entry's `summary` only if the added keyword makes it inaccurate; the
      current summary is accurate, so the default is to leave it alone.
- [ ] Confirm the file still parses: `jq empty agent-system/extensions/lean/index-entries.json`.
- [ ] Stage `index-entries.json` by explicit name and commit, after confirming the diff contains
      only this entry's keyword hunk.

**Timing**: 0.25 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh
agent-system/extensions/lean/index-entries.json` covers this phase's single touched path,
selecting `test-index-entries-schema.sh`, `test-context-reachability.sh`,
`test-deploy-orphans.sh`, `test-install-uninstall-extension.sh`,
`test-manifest-scripts-sync.sh` and `test-roadmap-command-registration.sh`.

**Files to modify**:
- `agent-system/extensions/lean/index-entries.json` - add `"plan-authoring"` to the keywords
  array of the entry for the dependency-tracing pattern file

**Verification**:
- `jq -r '.entries[] | select(.path | test("dependency-tracing")) | .keywords | index("plan-authoring")'`
  returns a non-null index.
- `jq -r '.entries[] | select(.path | test("dependency-tracing")) | .load_when'` is unchanged
  (`agents: ["lean-implementation-agent"]`, `task_types: ["lean4"]`).
- `jq -r '[.entries[].load_when.agents // []] | flatten | index("planner-agent")'` returns
  `null` across the whole file.
- `bash agent-system/extensions/core/scripts/verify-touched.sh agent-system/extensions/lean/index-entries.json`
  is green.
- `git diff --staged --name-only` lists only `agent-system/extensions/lean/index-entries.json`.

---

### Phase 3: Redeploy and Confirm Plan-Time Reachability End to End [NOT STARTED]

**Goal**: The deployed tree carries the new content and the new keyword, the entry's `line_count`
is accurate in the source store after deploy's own regeneration sweep, and the Stage 4 item 13
query demonstrably selects `dependency-tracing.md` for a `lean4` plan dispatch.

**Tasks**:
- [ ] Confirm no foreign build or deploy is in flight (`git log` to confirm recent commits are
      this task's own; report rather than proceed if a foreign commit or foreign uncommitted
      modification is present).
- [ ] Run `bash .claude/scripts/deploy-headless.sh` to regenerate the deployed tree. Capture its
      `line_count auto-repair` report line: deploy runs
      `generate-context-line-counts.sh --write` across every extension's source index, so it may
      also correct entries belonging to concurrent siblings' files.
- [ ] Inspect `git diff -- agent-system/extensions/lean/index-entries.json` after the deploy. If
      the sweep corrected only this task's own entry (expected, since Phase 1 already resynced
      it, so the likely outcome is no diff at all), commit nothing further. If it corrected a
      sibling's entry, leave that hunk uncommitted and report it — it is that sibling's to carry.
- [ ] Confirm the deployed index carries the keyword:
      `jq -r '.entries[] | select(.path | test("dependency-tracing")) | .keywords' .claude/context/index.json`.
- [ ] Reproduce Stage 4 item 13's query against the deployed index for `task_type` `lean4` and
      confirm `project/lean4/patterns/dependency-tracing.md` is now among the hits:
      `jq -r '.entries[] | select(.path | startswith("project/")) | select(((.load_when.task_types // []) | index("lean4")) and (((.keywords // []) + (.topics // [])) | index("plan-authoring"))) | .path' .claude/context/index.json`.
- [ ] Confirm the deployed copy of `dependency-tracing.md` matches the source-store copy
      (`diff` the two) and carries the new section content.
- [ ] Run the scoped touched-path check over this task's own touched paths and record the result.
- [ ] Record in the phase's verification notes that the complete gate set is deferred to the
      orchestration close rather than independently run in this dispatch.

**Timing**: 0.5 hours

**Depends on**: 1, 2

**Verification Tier**: full

**Files to modify**:
- `__WHOLE_TREE__` - this phase invokes `deploy-headless.sh`, which regenerates the entire
  deployed tree; the reserved sentinel declares that implicit whole-tree scope claim
- `agent-system/extensions/lean/index-entries.json` - only if deploy's own `line_count`
  regeneration sweep corrects this task's own entry

**Verification**:
- `deploy-headless.sh` exits 0 and its `line_count auto-repair` report line is captured.
- The deployed `.claude/context/index.json` entry for
  `project/lean4/patterns/dependency-tracing.md` contains `plan-authoring` in `keywords[]`.
- The Stage 4 item 13 query above, run for `task_type` `lean4` against the deployed index,
  includes `project/lean4/patterns/dependency-tracing.md`.
- `diff .claude/context/project/lean4/patterns/dependency-tracing.md agent-system/extensions/lean/context/project/lean4/patterns/dependency-tracing.md`
  is empty.
- In-dispatch obligation under `/orchestrate`: `bash agent-system/extensions/core/scripts/verify-touched.sh
  agent-system/extensions/lean/context/project/lean4/patterns/dependency-tracing.md
  agent-system/extensions/lean/index-entries.json` is green, **plus** an explicit statement that
  the complete gate set (`verify-deploy.sh`) is deferred to the orchestration close's
  once-per-invocation batch gate stage, not independently run here. If this task is run
  standalone with no orchestration close to defer to, run
  `bash .claude/scripts/verify-deploy.sh` in full instead.

---

## Testing & Validation

- [ ] `## Four Probe Shapes` heading and its four `### Shape N:` children are unchanged.
- [ ] The new material lives in the `## Grep-Based Blast Radius...` section, not as a fifth probe
      shape.
- [ ] The spelling enumeration's length equals the count the prose states, and is labelled a
      reconstruction.
- [ ] The worked example names no task number and no `specs/**` path, and uses no
      record-versioning phrasing.
- [ ] Source `index-entries.json` `line_count` for the entry equals `wc -l` of the file.
- [ ] Source and deployed `index-entries.json`/`index.json` both carry `plan-authoring` on the
      entry; `load_when` is unchanged and no `load_when.agents[]` anywhere names `planner-agent`.
- [ ] The Stage 4 item 13 query selects the file for `task_type` `lean4` against the deployed
      index.
- [ ] Every commit stages only this task's own explicitly named files.

## Artifacts & Outputs

- `agent-system/extensions/lean/context/project/lean4/patterns/dependency-tracing.md` — extended
  `## Grep-Based Blast Radius...` section with worked example and enumerated runnable probe.
- `agent-system/extensions/lean/index-entries.json` — `plan-authoring` keyword added and
  `line_count` resynced on the `dependency-tracing.md` entry.
- Regenerated deployed tree (`.claude/**`), a disposable artifact, not a committed deliverable.
- This plan's Decisions section as the durable record of the adopted and rejected remedies and
  the two recorded follow-ups.

## Rollback/Contingency

Both source-store edits are additive and confined to two files, each landed in its own commit, so
a revert of this task's commits restores the prior state exactly. If a revert is genuinely needed
rather than a forward fix, snapshot first with
`bash .claude/scripts/git-snapshot.sh 398` before any destructive git operation. For an ordinary
defensive checkpoint mid-phase (not a rollback), use
`bash .claude/scripts/git-snapshot.sh 398 --no-revert`. After any revert of the source store,
re-run `bash .claude/scripts/deploy-headless.sh` so the deployed tree stops carrying the reverted
content. If the deploy itself fails, the source store remains the truth and the deployed tree can
be regenerated at any time; no manual repair under `.claude/**` is ever the fix.
