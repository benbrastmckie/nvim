# Implementation Plan: Task #391

- **Task**: 391 - Agent system task siting and target root
- **Status**: [IMPLEMENTING]
- **Effort**: 5.75 hours
- **Dependencies**: 372, 373 (ordering only — both declare `conclusion-stage.md` in their own
  file_scope; this record's substance does not wait on their conclusions)
- **Research Inputs**: specs/391_agent_system_task_siting_and_target_root/reports/01_task-siting-and-target-root.md
- **Artifacts**: plans/01_target-root-and-siting-remedy.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Close the authoring hole that let the orchestrate conclusion stage's channel (b) file
agent-system task records into whatever repository `/orchestrate` happened to be running in, and
settle the adjacent `file_scope` convention question in writing. The research phase narrowed the
fault precisely: exactly three call sites dispatch `meta-builder-agent` directly, two already
resolve and thread `target_root`, and only `context/contracts/conclusion-stage.md` Step 4b does
not. The remedy mix is therefore (a) teach Step 4b to resolve and pass the field, plus a revised
(b) that strengthens the agent's already-present fallback into a loud refusal rather than adding
a resolution step it already has, plus (c) a standing siting rule kept deliberately distinct from
the existing `specs/**` artifact-location exemption. All edits land in the source store under
`agent-system/extensions/core/**` and are followed by a redeploy.

### Research Integration

Four research findings shape this plan directly:

1. **The enumeration is complete at three dispatchers.** `skills/skill-meta/SKILL.md` and
   `context/patterns/telemetry-meta-submode.md` both resolve `target_root`; only
   `context/contracts/conclusion-stage.md` Step 4b does not. This is why Phase 1 is narrow and
   why no fourth dispatcher phase exists.
2. **The dispatch's "remedy (b) means ADDING a resolution step" premise is stale.**
   `agents/meta-builder-agent.md` Stage 1 already resolves
   `TARGET_ROOT="${CLAUDE_AGENT_GLOBAL_ROOT:-$HOME/.config/nvim}"` and already forbids CWD as the
   fallback. Phase 2 therefore changes only the absent-key branch's *action* — silent best-guess
   to loud stop — and preserves the formula and the explicit-value-wins precedence verbatim.
3. **`skill-meta`'s acknowledged "carried by the prompt today" gap is discharged**, not still
   open. Phase 3 rewrites that text to describe the current mechanism.
4. **The dual-path `file_scope` convention is legitimate**, because a source-store edit's mandated
   redeploy genuinely rewrites the deployed mirror. Phase 5 records the verdict and its
   owning-repo-vs-deploy-only-repo asymmetry; no new field or marker is added.

### Premise Re-Validation (Carried-Figure Discipline)

The dispatch flagged four trigger-class lines. Each was checked against the research report and
against live disk state in this planning pass. Results stated explicitly, including where the
check only confirms the description unchanged:

| Dispatch line | Claim | Verdict |
|---|---|---|
| 1 | `agent-system/extensions/core/**` is the edit target, never a deployed `.claude/**` tree | **CONFIRMED unchanged.** All seven candidate target files exist under `agent-system/extensions/core/`; the parallel `.claude/**` copies are deploy output. |
| 25 | Step 4b never resolves `target_root`, "so the agent defaults to the session's working directory" | **SPLIT.** First half CONFIRMED live: `grep -n "target_root\|mode_target\|GLOBAL_ROOT" context/contracts/conclusion-stage.md` returns zero hits. Second half **STALE as a description of the agent file**: `agents/meta-builder-agent.md` lines 146-149 carry a defensive fallback that resolves `GLOBAL_ROOT` and states "CWD must never be the fallback". The CWD outcome is real as an *observed* 2026-11-05 execution result, but it is a compliance lapse against written contract text, not the contract's specified behavior. This is what reshapes remedy (b) from "add" to "strengthen". |
| 165 | "skill-meta always [passes target_root] explicitly, including in `--local` mode" | **CONFIRMED live.** `skills/skill-meta/SKILL.md` lines 78-85 resolve `target_root` on both branches (`git rev-parse --show-toplevel` in local mode, `$GLOBAL_ROOT` otherwise); line 136 carries it in the delegation context. The refusal in Phase 2 therefore cannot fire for this caller in either mode. |
| 176 | The backlog audit's untrustworthy verdicts are part of why a misfiled record reaches creation | **CONFIRMED as context only, and deliberately not acted on.** Owned by a separate open record (`fix_backlog_audit_semantic_scorer`). Not absorbed here, per the dispatch's explicit instruction. |

One further independent check beyond the flagged lines: the three-dispatcher enumeration was
re-run in this planning pass with a differently-shaped sweep (every file matching
`meta-builder-agent` that also matches `dispatch|subagent_type`, then inspecting the six
plausible non-listed candidates — `orchestration-core.md`, `meta-guide.md`, `meta-interview.md`,
`backlog-reconciliation.md`, `skill-telemetry/SKILL.md`, `validation.md`). None is an independent
dispatch site: they are routing tables, delegation-chain prose, or workflows consumed by
`skill-meta`. The enumeration holds.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch's delegation context and no `roadmap_flag` is
set, so no roadmap consultation was performed and no roadmap phases are included.

## Goals & Non-Goals

**Goals**:

- Channel (b)'s dispatch path can no longer file an agent-system record into an arbitrary
  repository.
- Every direct dispatcher of `meta-builder-agent` is enumerated in writing, and each is either
  fixed or recorded as already correct.
- An absent `target_root` becomes a visible refusal at dispatch time rather than a silent
  mis-filing discovered later by hand.
- `skill-meta`'s stale self-acknowledgment is replaced with text describing the current mechanism.
- A standing siting rule exists for a task whose own edit target is the source store, written so
  it cannot be read as revoking the `specs/**` artifact-location exemption.
- The dual-path `file_scope` convention is settled in writing in the field's authoritative schema
  reference.
- The reasoning for the remedy shape adopted — and for what was rejected — is recorded.

**Non-Goals**:

- No change to the conclusion stage's three-channel derivation contract, its per-channel approval
  gates, or its approval-ledger mechanics beyond what `target_root` resolution forces.
- No repair of the six already-mis-sited records' own `file_scope` data (sibling migration
  record).
- No new migration tooling, and no blocking hook for task siting (explicitly accepted as
  documentation-and-contract enforcement only, consistent with the existing edit-target rule's own
  recorded posture).
- No change to `/meta`'s `--local` semantics.
- No absorption of the backlog-audit semantic-scorer defect.
- No edit to `commands/meta.md` (see Decisions below).

## Decisions

Two plan-time scope decisions the research phase explicitly deferred here:

- **`context/standards/postflight-tool-restrictions.md` — ACCEPT into scope.** Its Conclusion
  Stage "Allowed Tool Surface" `Bash` row (line 149) enumerates named scripts only. Remedy (a)
  introduces a shell variable resolution at that stage which no enumerated entry covers, leaving
  two contracts in apparent tension. A one-line addition in that table's own enumeration style
  removes the ambiguity, and it is cheap enough to land in the same phase as the change that
  creates the need.
- **`commands/meta.md` — REJECT from scope.** It is not a dispatcher, its Target Resolution
  section already documents the pattern correctly, and the measured defect does not touch it.
  The optional cross-reference the research floated is editorial only and would widen `file_scope`
  for no mechanical gain. Recorded as considered and declined rather than silently dropped.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Record-versioning language leaks into the deliverables. The research report's own framing ("already discharged", "a gap that has not existed since July", "now stale") is exactly what `no-record-versioning-in-deliverables.md` forbids, and `agent-system/**` is NOT exempt — only `specs/**` is. | H | H | Phases 2, 3 and 5 state the CURRENT design only, with no "no longer"/"previously"/"used to"/"supersedes" framing. `check-record-versioning.sh` is run on each edited path as that phase's own verification, not deferred to Phase 6. |
| Task-number citations leak in. The discharge text is naturally phrased as "the follow-up task that made this durable". | H | M | Describe the discharge by what the mechanism now *is*, never by which record changed it. `check-task-references.sh` run per-path per-phase. |
| Phase 2's refusal lands (and deploys) before Phase 1, breaking channel (b) outright instead of mis-filing. | M | M | A real ordering constraint, not bookkeeping: Phase 2 `Depends on: 1`. Refusing is strictly better than mis-filing, but channel (b) should be correct before the backstop tightens. |
| The new standing rule is read as revoking the `specs/**` exemption, making ordinary artifact authoring look illegal. | H | M | Phase 4 adds a *separately labeled* subsection, never folded into the existing `.claude/**`-scoped "Path Pattern", and states the artifact-location-vs-creation-site distinction in the rule text itself. The existing Exceptions bullet is left byte-for-byte unchanged. |
| Whole-tree collision with a concurrent sibling. Sibling record 507 is implementing this same cycle with `__WHOLE_TREE__` in its own file_scope, so both records regenerate the entire deployed tree. | M | H | Phase 6 declares `__WHOLE_TREE__` so the admission gate serializes rather than races. Per the dispatch's concurrency note: re-read every file immediately before editing, stage only this record's own hunks with an explicit file list, never `git-snapshot.sh` in reverting mode, and STOP and report a foreign commit or foreign uncommitted modification after checking `git log` to confirm it is not this record's own work. |
| The refusal blocks a legitimate future caller that omits `target_root` for some unenvisioned reason. | L | L | No such caller exists; all three dispatchers are accounted for and two already pass the field. The refusal message names the calling convention so the fix is immediate rather than mysterious. |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 4 | -- |
| 2 | 2, 5 | 1 (for 2); 4 (for 5) |
| 3 | 3 | 2 |
| 4 | 6 | 1, 2, 3, 4, 5 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Resolve and thread target_root in conclusion stage Step 4b [COMPLETED]

**Goal**: Remedy (a). Channel (b)'s dispatch carries a resolved `target_root` and
`mode_target`, so it can no longer inherit the session's working directory.

**Tasks**:

- [x] Re-read `context/contracts/conclusion-stage.md` Step 4b (currently lines 284-309) and
      `skills/skill-meta/SKILL.md` Section 1 (lines 60-85) immediately before editing. *(completed)*
- [x] Add a `target_root` resolution block to Step 4b immediately before the dispatch, mirroring
      `skill-meta` Section 1's formula verbatim: `GLOBAL_ROOT="${CLAUDE_AGENT_GLOBAL_ROOT:-$HOME/.config/nvim}"`.
      Resolve always-global with no `--local` branch, and state in one sentence why channel (b)
      has no local analogue: filing a channel-(b) record into whichever deploy-only repo
      `/orchestrate` happens to be running in is the defect being closed, so local mode is never
      the right choice at this call site. *(completed)*
- [x] Add `"target_root"` and `"mode_target": "global"` to the dispatch body's described fields. *(completed)*
- [x] Add the path-qualification imperative to the dispatch body, mirroring `skill-meta`
      Section 4's wording (lines 168-173), so the three dispatch sites read as one maintained
      pattern rather than three independent re-derivations. *(completed)*
- [x] Add a one-line entry to `context/standards/postflight-tool-restrictions.md`'s Conclusion
      Stage `Bash` row (line 149) covering the `GLOBAL_ROOT` resolution, in that table's existing
      enumeration style. *(completed)*
- [x] Confirm no task-number citation and no record-versioning phrasing was introduced. *(completed: check-task-references.sh and check-record-versioning.sh both exit 0 on both edited paths)*

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `run-all.sh --only test-orchestrate-conclusion-aggregate` covers the
conclusion stage's gate scripting that this step's text invokes, and `check-task-references.sh`
plus `check-record-versioning.sh` scoped to the two edited paths cover the authoring-shape
obligations; no cross-cutting surface outside the conclusion stage is touched.

**Scope Hypothesis**: This phase assumes Step 4b is the ONLY dispatcher needing the fix, i.e.
exactly three direct dispatchers exist. Confirm at implement time by re-running both sweeps:
`grep -rl "meta-builder-agent" --include="*.md" .` under `agent-system/extensions/core/`,
intersected with a `dispatch|subagent_type` filter, then reading each hit. If a fourth genuine
dispatch site appears, fix it in this same phase and record it rather than deferring.

**Files to modify**:

- `agent-system/extensions/core/context/contracts/conclusion-stage.md` - Step 4b gains a
  `target_root`/`mode_target` resolution, the two dispatch-body fields, and the
  path-qualification imperative.
- `agent-system/extensions/core/context/standards/postflight-tool-restrictions.md` - Conclusion
  Stage `Bash` row gains the `GLOBAL_ROOT` resolution entry.

**Verification**:

- `grep -n "target_root\|mode_target\|GLOBAL_ROOT" context/contracts/conclusion-stage.md` returns
  hits inside Step 4b (it currently returns none).
- The resolution formula is byte-identical to `skill-meta/SKILL.md` line 60's.
- `bash .claude/scripts/tests/run-all.sh --only test-orchestrate-conclusion-aggregate` passes.
- `bash .claude/scripts/check-task-references.sh agent-system/extensions/core/context/` exits 0.
- `bash .claude/scripts/check-record-versioning.sh agent-system/extensions/core/context/` exits 0.

---

### Phase 2: Convert the agent's silent target_root fallback to a loud refusal [COMPLETED]

**Goal**: Remedy (b), in its revised form. An absent `target_root` stops the run visibly instead
of producing a best-guess that files records somewhere unintended.

**Tasks**:

- [x] Re-read `agents/meta-builder-agent.md` Stage 1 (currently lines 141-167) immediately before
      editing. *(completed)*
- [x] Replace the absent-key branch's action (currently "resolve ... and note the fallback was
      used in the run log") with an explicit refusal: stop before any Write/Edit, write
      `.return-meta.json` with `status: "blocked"`, name the missing field and the calling
      convention the other dispatchers follow, and create nothing. *(completed)*
- [x] Preserve unchanged: the `GLOBAL_ROOT`-versus-CWD distinction, the explicit-value-always-wins
      precedence, and the whole Path Qualification Convention block. Only the absent-key branch's
      action changes. *(completed)*
- [x] State the precedence explicitly in the edited text: an explicitly passed `target_root`
      (global or local) is always used as given, so the refusal fires only on true absence of the
      key and never on a present-but-local value. `--local` semantics are untouched. *(completed)*
- [x] Write the new text as a statement of the current contract, with no narration of what the
      branch used to do. *(completed)*

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: `run-all.sh --only test-return-meta-status-vocabulary` covers the
`status: "blocked"` value this refusal introduces into an agent return path, which is the one
mechanically checkable consequence of the edit; the surrounding change is contract prose covered
by the two authoring-shape lints.

**Files to modify**:

- `agent-system/extensions/core/agents/meta-builder-agent.md` - Stage 1's absent-`target_root`
  branch becomes a refusal writing `status: "blocked"`.

**Verification**:

- The phrase directing a run-log note on fallback use is gone; a `status: "blocked"` refusal is
  present in its place.
- `grep -n "CWD must never be the fallback" agents/meta-builder-agent.md` still returns a hit —
  the CWD prohibition survived the edit.
- The explicit-value precedence sentence is present and names both global and local.
- `bash .claude/scripts/tests/run-all.sh --only test-return-meta-status-vocabulary` passes.
- `bash .claude/scripts/check-record-versioning.sh agent-system/extensions/core/agents/meta-builder-agent.md` exits 0.

---

### Phase 3: Discharge skill-meta's stale path-qualification acknowledgment [NOT STARTED]

**Goal**: `skill-meta/SKILL.md` describes the mechanism that exists rather than pointing at a
follow-up as though it were still owed.

**Tasks**:

- [ ] Re-read `skills/skill-meta/SKILL.md` lines 168-175 immediately before editing.
- [ ] Rewrite the closing sentence (lines 174-175) to state that the agent definition enforces its
      own `target_root` requirement independently — refusing when the key is absent, per Phase 2 —
      so the prompt's path-qualification imperative is defense-in-depth rather than the sole
      mechanism.
- [ ] Keep the REQUIRED path-qualification imperative itself and its example wording intact; only
      the trailing durability-gap sentence changes.
- [ ] Write it with no task-number citation and no draft-history framing: describe what the
      mechanism now is, not that a gap was closed or by which record.

**Timing**: 0.5 hours

**Depends on**: 2

**Verification Tier**: prose

**Tier Justification**: A single-sentence prose replacement in a skill body with no scripted
behavior and no consumer that parses it; `check-task-references.sh` and
`check-record-versioning.sh` on that one path are the only applicable mechanical checks, and both
are run below.

**Files to modify**:

- `agent-system/extensions/core/skills/skill-meta/SKILL.md` - trailing sentence of the
  path-qualification imperative block restated as current mechanism.

**Verification**:

- `grep -n "carried by the prompt today" skills/skill-meta/SKILL.md` returns no hits.
- `grep -n "REQUIRED path-qualification imperative" skills/skill-meta/SKILL.md` still returns a
  hit — the imperative itself survived.
- The replacement text describes the agent's own enforcement and matches what Phase 2 actually
  wrote (read both and confirm they agree).
- `bash .claude/scripts/check-task-references.sh agent-system/extensions/core/skills/skill-meta/SKILL.md` exits 0.
- `bash .claude/scripts/check-record-versioning.sh agent-system/extensions/core/skills/skill-meta/SKILL.md` exits 0.

---

### Phase 4: Add the standing task-siting rule [NOT STARTED]

**Goal**: Remedy (c). A documented standing rule that a task whose own edit target is the source
store must be created in the repository that owns that source store — kept clearly distinct from
the `specs/**` artifact-location exemption.

**Tasks**:

- [ ] Re-read `rules/source-store-deploy-boundary.md` (29 lines, full file) and
      `context/standards/source-store-deploy-boundary-narrative.md` Exceptions (lines 52-57) and
      Known limitation (lines 70-76) immediately before editing.
- [ ] Add a new, separately titled subsection to `rules/source-store-deploy-boundary.md` — NOT
      folded into the existing "Path Pattern", which is scoped to `.claude/**` writes — stating
      the siting principle: a task whose declared edit target is a source-store path must be
      created in the repository whose local filesystem contains that `source_dir`, resolvable via
      `.claude-extensions.json`, never in a deploy-only repo where the path does not exist on disk.
- [ ] In that same subsection, state the distinction explicitly: a task's own artifacts (reports,
      plans, summaries) may legitimately live in whatever repository the run happens from — that
      is a separate matter from where the task record itself is filed when its edit target is the
      source store.
- [ ] Leave the narrative's existing `specs/**` Exceptions bullet byte-for-byte unchanged.
- [ ] Add the matching narrative detail to
      `context/standards/source-store-deploy-boundary-narrative.md`, anchored at the Known
      limitation paragraph, which already names this exact gap ("not a backstop for target-root
      correctness").
- [ ] State plainly in the narrative that this rule's enforcement is documentary and
      agent-contract reinforcement only — no blocking hook — consistent with the adjacent
      edit-target rule's own recorded posture.
- [ ] Respect the rule file's eager-loading comment: keep the addition short, and do not add a
      `paths:` frontmatter glob.

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `rules/source-store-deploy-boundary.md` is deliberately eager-loaded
(its own header comment records that decision), so added text there consumes ambient context
budget in every session — `validate-context-budgets.sh` is the specific covering check, alongside
`test-context-reachability` for the new rule-to-narrative cross-reference.

**Files to modify**:

- `agent-system/extensions/core/rules/source-store-deploy-boundary.md` - new separately titled
  siting subsection with the artifact-location distinction.
- `agent-system/extensions/core/context/standards/source-store-deploy-boundary-narrative.md` -
  matching narrative detail at the Known limitation anchor, plus the documentary-enforcement note.

**Verification**:

- The new subsection has its own heading and is not nested under "Path Pattern".
- `grep -n "Writes under \`specs/\*\*\`" context/standards/source-store-deploy-boundary-narrative.md`
  returns the original exemption bullet, textually unchanged.
- The rule text names `.claude-extensions.json`/`source_dir` as the resolution mechanism, matching
  the existing "Correct Edit Target" section's procedure.
- No `paths:` frontmatter was added to the rule file.
- `bash .claude/scripts/validate-context-budgets.sh` passes.
- `bash .claude/scripts/tests/run-all.sh --only test-context-reachability` passes.
- `bash .claude/scripts/check-record-versioning.sh agent-system/extensions/core/rules/source-store-deploy-boundary.md` exits 0.

---

### Phase 5: Record the file_scope deploy-path convention verdict [NOT STARTED]

**Goal**: Settle the dual-path `file_scope` question in writing, in the field's authoritative
schema reference, so the next author is not choosing between two undocumented conventions.

**Tasks**:

- [ ] Re-read `context/reference/state-management-schema.md`'s "File Scope Field" section
      (lines 375-410) immediately before editing.
- [ ] Add a subsection recording the verdict: declaring both a source-store path and its deployed
      `.claude/**` mirror is a true statement about what the task's execution touches, because the
      mandated redeploy genuinely rewrites the mirror. It is not an overload of the field's
      "expects to create or modify" contract.
- [ ] State the asymmetry explicitly: the repository that owns the source store may declare the
      source path alone (its own `.claude/**` is disposable and regenerated wholesale, so a
      mirror-versus-mirror collision there carries no information); a deploy-only repository
      should declare both, because its overlap gate can only see what physically exists on disk.
- [ ] Record that no second field and no per-entry marker is added, and why: the two readings
      ("edit target" and "declared collision surface") are never in tension, since both paths are
      genuinely touched. Note the revisit condition — a future consumer that actually needs the
      distinction.
- [ ] Note that the standing rule from Phase 4 is expected to make the deploy-only-repo case
      exceptional going forward rather than dissolve the question, so the written answer is still
      owed for deliberate local runs from a deploy-only repo.
- [ ] Cross-reference the Phase 4 rule subsection by section heading, not by task number.
- [ ] Keep the existing "Generated-surface entries are ordinary, not provenance-tagged" paragraph
      intact — it makes the adjacent point that the schema has no per-entry provenance field, which
      this verdict relies on rather than contradicts.

**Timing**: 1 hour

**Depends on**: 4

**Verification Tier**: prose

**Tier Justification**: A documentation addition to a schema reference with no parser or script
reading the added prose; `test-context-reachability` covers that the new cross-reference to the
Phase 4 subsection resolves, and the two authoring-shape lints cover the rest.

**Files to modify**:

- `agent-system/extensions/core/context/reference/state-management-schema.md` - "File Scope
  Field" section gains the deploy-path convention verdict and its asymmetry.

**Verification**:

- The verdict subsection exists under "File Scope Field" and states both the legitimacy ruling and
  the owning-repo-vs-deploy-only-repo asymmetry.
- The cross-reference to Phase 4's new rule subsection names a section heading that actually
  exists in the file Phase 4 edited (read it and confirm).
- `grep -n "Generated-surface entries are ordinary" context/reference/state-management-schema.md`
  still returns a hit.
- `bash .claude/scripts/tests/run-all.sh --only test-context-reachability` passes.
- `bash .claude/scripts/check-task-references.sh agent-system/extensions/core/context/reference/state-management-schema.md` exits 0.
- `bash .claude/scripts/check-record-versioning.sh agent-system/extensions/core/context/reference/state-management-schema.md` exits 0.

---

### Phase 6: Redeploy and verify the full gate set [NOT STARTED]

**Goal**: Propagate every source-store edit into the deployed tree and confirm the complete gate
set is green across all six edited files.

**Tasks**:

- [ ] Confirm Phases 1-5 are all complete and committed before redeploying.
- [ ] Check for concurrent sibling activity first: a foreign commit or foreign uncommitted
      modification in the deployed tree is possibly sibling record 507's in-flight whole-tree work,
      not this record's regression. Check `git log` to confirm the work is not this record's own,
      then STOP and report rather than proceeding or dismissing it.
- [ ] Run the redeploy: `bash .claude/scripts/deploy-headless.sh`, and require
      `RESULT=landed_verify_clean`.
- [ ] Run the full verification battery (not a narrowed selection) and resolve any failure.
- [ ] Confirm the deployed `.claude/**` copies of all six edited files match their source-store
      originals.
- [ ] Re-read the "WHAT IS OWED" list in the task description and confirm each of its five items is
      discharged by a specific landed edit; record any that is not.

**Timing**: 0.75 hours

**Depends on**: 1, 2, 3, 4, 5

**Verification Tier**: full

**Files to modify**:

- `__WHOLE_TREE__` - the redeploy regenerates the entire deployed tree.

**Verification**:

- `bash .claude/scripts/deploy-headless.sh` reports `RESULT=landed_verify_clean`.
- `bash .claude/scripts/verify-deploy.sh` passes with no gate narrowing.
- `bash .claude/scripts/tests/run-all.sh` passes with no `--only` narrowing (known-failures file
  respected).
- `bash .claude/scripts/check-task-references.sh` exits 0 repo-wide.
- `bash .claude/scripts/check-record-versioning.sh` exits 0 repo-wide.
- `bash .claude/scripts/validate-wiring.sh` and `bash .claude/scripts/validate-context-index.sh`
  both pass.
- `diff` of each edited source-store file against its deployed `.claude/**` counterpart shows the
  edit propagated.

---

## Testing & Validation

- [ ] `context/contracts/conclusion-stage.md` Step 4b resolves `target_root` and passes it plus
      `mode_target` in the dispatch body.
- [ ] The resolution formula at that site is byte-identical to the two already-correct dispatchers'.
- [ ] All three direct dispatchers are enumerated in the artifacts, each marked fixed or
      already-correct; the enumeration was re-confirmed with two differently-shaped sweeps at
      implement time.
- [ ] `agents/meta-builder-agent.md` refuses with `status: "blocked"` on an absent `target_root`
      and creates nothing; the CWD prohibition and the explicit-value precedence survive unchanged.
- [ ] `--local` semantics are demonstrably unaffected: the refusal fires only on key absence.
- [ ] `skills/skill-meta/SKILL.md` no longer points at an owed follow-up for path qualification.
- [ ] The standing siting rule exists as its own subsection and the `specs/**` exemption bullet is
      textually unchanged.
- [ ] The `file_scope` verdict, its asymmetry, and the no-new-field decision are recorded in the
      field's authoritative schema reference.
- [ ] No file under `agent-system/**` carries a task-number citation or record-versioning language.
- [ ] Redeploy reports `RESULT=landed_verify_clean` and the full gate set is green.

## Artifacts & Outputs

- Six modified source-store files under `agent-system/extensions/core/`:
  `context/contracts/conclusion-stage.md`, `context/standards/postflight-tool-restrictions.md`,
  `agents/meta-builder-agent.md`, `skills/skill-meta/SKILL.md`,
  `rules/source-store-deploy-boundary.md`,
  `context/standards/source-store-deploy-boundary-narrative.md`,
  `context/reference/state-management-schema.md`.
- A regenerated deployed `.claude/**` tree.
- An implementation summary recording the adopted remedy mix, the rejection reasoning for
  `commands/meta.md` and for the literal "add a resolution step" reading of remedy (b), and the
  dispatcher enumeration result.

## Rollback/Contingency

Each phase is a self-contained documentation or contract edit committed separately, so reverting
is per-phase via `git revert` of that phase's commit followed by a redeploy. Before any
intentional rollback that would otherwise be blocked, take a snapshot with
`bash .claude/scripts/git-snapshot.sh 391` first; for an ordinary defensive checkpoint before
risky work, use `--no-revert`, and never the reverting default while a sibling record is live in
this tree.

The highest-risk single change is Phase 2's refusal, because it converts a previously
best-effort path into a hard stop. If a legitimate caller is discovered to depend on the absent-key
branch, the contingency is to downgrade that branch from refusal to a resolution that additionally
writes a named, fixed-location warning field — preserving auditability without blocking — rather
than restoring a silent fallback.
