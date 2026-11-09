# Implementation Plan: Task #435

- **Task**: 435 - Reword, per class and per site, the architectural and phase-versus-command prose naming the three deleted lifecycle commands, with a blanket find-and-replace explicitly forbidden
- **Status**: [IMPLEMENTING]
- **Effort**: 22 hours
- **Dependencies**: Task 434 (companion lint; completed), Task 407 (artifact-round derivation; completed) — both terminal and resolved
- **Research Inputs**: specs/435_reword_dead_lifecycle_command_prose_per_class/reports/01_dead-lifecycle-command-prose.md
- **Artifacts**: plans/01_dead-lifecycle-command-prose-sweep.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The commands `/implement`, `/research` and `/plan` have no definition file anywhere in the agent
system; `/orchestrate` is the sole lifecycle driver. The source store nonetheless names them in
223 files / 948 occurrences (re-measured at plan time, `core/docs/` excluded). The companion lint
task already retargeted the mechanically identifiable recommendation lines and wired gate 24 to
keep them green; this record owns the remaining prose, where no actionable recommendation is made
but the text still names a command that cannot be run. A blanket find-and-replace is forbidden:
the occurrences fall into three classes with three different correct treatments, and substituting
`/orchestrate` produces nonsense in all three. Done means every in-scope occurrence has been read
at its own site, treated per its class, the deployed tree redeployed to
`RESULT=landed_verify_clean`, and gate 24 still green.

### Research Integration

The research report is integrated as follows, and its figures were re-derived rather than carried:

- **Measurement re-derived at plan time**, not carried: the report's boundary-aware pattern
  `(?<![A-Za-z0-9_/.-])/(implement|research|plan)(?![A-Za-z0-9_.-])` was re-run at plan authoring
  and returned 223 files with an identical per-extension and per-`core`-subdirectory distribution.
  Every per-phase file list below is generated from that live run, not transcribed from the report.
- **Both dependency edges are discharged.** Task 434 is complete (gate 24,
  `lint-dead-command-recommendations.sh`, green corpus-wide); task 407 is complete and changed
  only the *read* side of artifact-number resolution, not who advances the counter. No phase
  below waits on either.
- **The three `revise.md` incidental fixes are applied verbatim from the report** (Phase 1), each
  re-verified live at plan time against the current file: the class-1 worked example (line 145),
  the record-versioning phrase (line 99, the file's only hit for that pattern family), and the
  artifact-round sentence (line 12), whose replacement text the report derived from
  `orchestrate-stage5-postflight.sh`'s live A2 P1/P2 logic rather than from the stale sentence.
- **The 328 overlap advisory in the dispatch is moot** — 328 is terminal and never executed a
  markdown merge or deletion. No phase carries a "check whether 328 has an open phase" step.
- **The live sibling collision is real and carried forward**: six files in this record's scope are
  also in the declared `file_scope` of tasks 420 and 430, dispatched this same cycle. They are
  named in Risks and flagged inline in the phases that own them.
- **One report recommendation is deliberately not followed.** The report recommends treating
  `core/context/processes/research-workflow.md` as "a candidate for substantial rewrite". This
  plan rewords it in place instead and records any residue for a follow-up record — see
  Non-Goals, and Phase 5's decision gate, for the reasoning.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No roadmap context was supplied in this dispatch and no `roadmap_flag` was set; this plan neither
reads nor writes ROADMAP.md.

## Goals & Non-Goals

**Goals**:

- Treat all 223 in-scope files per site and per class, leaving no occurrence unread.
- Record, in this plan, the classification rubric that makes "per-class treatment" checkable
  rather than aspirational — including the third class neither the dispatch nor the research
  report named.
- Apply the three `revise.md` incidental fixes with the concrete text the research derived.
- Keep gate 24 green throughout: this sweep must never reintroduce a recommendation-shaped line,
  and must never corrupt the lint's own detection patterns.
- Redeploy to `RESULT=landed_verify_clean` and leave the full gate set green.

**Non-Goals**:

- **No blanket find-and-replace**, at any scope, including within a single file. Explicitly
  forbidden by the record.
- **No document restructures.** Where a document's premise is built around a dead command such
  that local rewording leaves it incoherent, this plan rewords the occurrences and records the
  residual incoherence for a follow-up record. It does not restructure the document. This is the
  same boundary the 2026-11-03 scope amendment drew when it removed `core/docs/` in favour of two
  dedicated documentation records: restructures belong to records that own them, and performing
  one here would be unauthorized scope growth and likely rework.
- **No `core/docs/` edits** (22 files), removed from this record's scope on 2026-11-03.
- **No record-versioning cleanup beyond `revise.md:99`.** The same defect family appears in
  ~43 other files in the hit-set, confirmed advisory-tier by the live gate, owned by a completed
  taxonomy/lint/hook lineage. `system-overview.md`'s dead-command half is in scope; its
  "Superseded note"/"used to" phrasing is not and is left exactly as-is.
- **No retargeting of the recommendation lines** task 434 already owns and gate 24 now gates.

## Classification Rubric

The dispatch requires per-class treatment with a per-site decision recorded for each class. Every
phase below applies this rubric; a phase's verification is not satisfied until each occurrence it
touched has been assigned a class.

**Class 1 — phase-versus-command prose.** The sentence is talking about a lifecycle *phase*,
which genuinely exists and is dispatched by `/orchestrate`. The correct replacement is the phase
name or a dispatch noun phrase, never a command name. Worked example, re-verified live at
`core/commands/revise.md:145`: ``unlike `/research`/`/plan`/`/implement`, `/revise` has no
terminal-status ABORT`` becomes `unlike a research/plan/implement dispatch, /revise has no
terminal-status ABORT`. Substituting `/orchestrate` three times would be both false and
unreadable.

**Class 2 — architectural / dispatch-model reference.** The occurrence names a phase inside an
architectural description, a routing table, a doc-comment, or a worked example of system
behavior. Usually becomes `implement dispatch` / `implement phase`. Still per-site: a reference
inside an example of something a *user types* is a different fix from one naming a phase in an
architectural description. Verified instances spanning the range:

- `core/context/formats/plan-format.md:3` — `All plan artifacts produced by /plan, /revise,
  /implement (phase planning), /review` — a stale per-command scope line; becomes phase framing.
- `core/context/formats/plan-format.md:455` — ``a bare `/implement N` `` — an invocation the user
  can no longer type; becomes a single-task implement dispatch.
- `core/context/orchestration/orchestrator.md` — per-command routing-table rows
  (`- /research: Extension type -> extension agent, ...`) that predate the commands' deletion;
  today's routing is `task_type` -> agent. Needs phase-name framing, not a bare substitution.
- `core/scripts/skill-base.sh`'s `skill_cleanup()` doc-comment — a stale file-path list naming
  `commands/{research,plan,implement,revise,orchestrate}.md`, three of which do not exist;
  corrected to the two that do.
- `core/scripts/test-four-tier-conflict.sh:452` and `core/scripts/update-task-status.sh:828` —
  implementation comments naming a phase's dispatch; ordinary class-2 rewords.

**Class 3 — the command name IS the data; leave it alone.** Neither the dispatch nor the research
report named this class, and it is the one class where editing causes damage rather than leaving
a defect. The occurrence is not a claim about how the system works — it is a literal token the
code detects, a fixture value, or a record of the removal itself. Verified instances:

- `core/scripts/lint/lint-dead-command-recommendations.sh:53-54` — illustrative match strings
  (`` Next: `/plan 1` ``, `**Run** /plan`) documenting the lint's own detection behavior.
  Rewording these corrupts the documentation of the gate this task depends on staying green.
- `core/scripts/lint/lint-dead-command-recommendations.sh:8` — "`/implement`, `/research` and
  `/plan` were removed from the agent system" — a correct historical statement that is the lint's
  entire subject matter.
- `core/scripts/tests/test-double-loading-check.sh:187` — `"commands": ["/research"]` inside a
  JSON test fixture. Fixture data, coupled to the suite's own expectations, not prose.
- `core/scripts/lib/task-type-detect.sh:112` — an illustrative list of leading-slash command
  tokens the function detects. Judgment site: the example is stale rather than load-bearing, so
  swapping the dead token for a live command is correct here, but the surrounding detection
  description must not change.

A class-3 decision is a decision and must be recorded as such in the phase's notes, with the
reason. Silence is not a class-3 outcome — an unread occurrence is an incomplete phase.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Contributor under time pressure falls back to the forbidden blanket substitution | H | M | Phases are sized to 6-25 files so per-site reading is feasible; the rubric above makes each site's decision explicit; the per-class worked examples give calibration |
| Class-3 site edited by mistake, corrupting gate 24's own lint or a test fixture | H | M | The four verified class-3 sites are named inline in the phase that owns them (Phase 7); every phase's verification runs gate 24 with its exit status checked |
| A premise-level incoherence is "fixed" by restructuring a document, growing scope | M | M | Restructure is an explicit Non-Goal; Phase 5 carries a decision gate that records residue instead of restructuring |
| Live sibling collision: six in-scope files are in tasks 420/430's declared `file_scope` this same cycle | M | H | Named in the owning phases (2, 4, 7, 8); re-read each immediately before editing, stage only this task's own hunks with an explicit file list, never a directory or glob add |
| The 223-file / 948-occurrence figure drifts before or during implementation | M | H | Each phase's Scope Hypothesis names the measurement command; Phase 1 re-runs it corpus-wide and reconciles before any sweep phase begins |
| `suite_selection_select` is not a usable narrowing mechanism here | L | H (confirmed) | Its grep basename stratum maps any `SKILL.md`- or `README.md`-named path to 28-43 suites by basename collision (measured at plan time: founder/skills -> 28 suites, small-extensions -> 43), so a suite-subset claim is neither practical nor a real narrowing, and `__FULL_SWEEP__` would be false for those sets. Every phase grounds its Tier Justification in the `--only-gate` mechanism instead, which plan-format.md places outside that measurement check's scope |
| Phase count (15) is high relative to the complexity table's 4-6 | L | H (deliberate) | A direct consequence of the record's own instruction that no single phase attempt the whole sweep, and of the research recommendation of 15-30 files per phase. Accepted, not an oversight |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14 | 1 |
| 3 | 15 | 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14 |

Phases within the same wave can execute in parallel. Wave 2's thirteen phases have mutually
disjoint file sets by construction (each is a distinct directory tranche), so they are genuinely
parallelizable; they all depend on Phase 1 because Phase 1 fixes the canonical artifact-round
wording and re-establishes the corpus baseline every later phase's Scope Hypothesis is checked
against.

**Shared per-phase procedure.** Every sweep phase (2-14) follows the same steps, stated once here
rather than repeated fifteen times:

1. Re-run the measurement command, restricted to this phase's tranche, and reconcile against the
   phase's Scope Hypothesis. A drift is recorded, not silently absorbed.
2. For each file, in list order: read it, locate each occurrence in its own surrounding context,
   assign it a class per the rubric, and apply that class's treatment.
3. Record the per-site class decision in the phase's notes, including every class-3 leave-alone
   and its reason.
4. Re-read any file flagged as a sibling-collision site immediately before editing it.
5. Commit per green sub-step with an explicit file list — never a directory or glob pathspec.
6. Run the phase's declared verification and check its exit status.

The measurement command, used by every phase:

```bash
grep -rlP '(?<![A-Za-z0-9_/.-])/(implement|research|plan)(?![A-Za-z0-9_.-])' \
  --include="*.md" --include="*.json" --include="*.sh" agent-system/extensions \
  | grep -v '^agent-system/extensions/core/docs/'
```

The gate-subset verification command referenced by every phase's Tier Justification (`TARGET` is
the repository root, which holds both a deployed `.claude/` tree and the `agent-system/extensions`
source store, as `verify-deploy.sh`'s own `TARGET_REPO CONTRACT` requires):

```bash
bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh \
  --skip-slow --only-gate 3,4,24 /home/benjamin/.config/nvim
```

Gate 3 is doc-lint (`check-extension-docs.sh`), gate 4 the task-reference lint
(`check-task-references.sh`), gate 24 the dead-command-recommendation lint
(`lint-dead-command-recommendations.sh`). Phase 7 additionally selects gate 22
(`lint-shellcheck.sh`), the only phase that edits shell sources.

---

### Phase 1: Baseline Reconciliation and the revise.md Incidentals [COMPLETED]

**Goal**: Re-establish the corpus baseline every later phase checks against, and apply the three
concrete, already-derived fixes to `revise.md` plus the adjacent artifact-round worked example.

**Tasks**:

- [x] Run the corpus-wide measurement command and record the file and occurrence counts as the
      baseline all later phases reconcile against. *(completed: 223 files / 948 occurrences, exact match to plan baseline, no drift)*
- [x] `revise.md:145` (class 1): replace ``unlike `/research`/`/plan`/`/implement`, `/revise` has
      no terminal-status ABORT`` with `unlike a research/plan/implement dispatch, /revise has no
      terminal-status ABORT`. No substantive claim changes — only the command-name token. *(completed)*
- [x] `revise.md:99` (record-versioning, the file's only hit for the
      no-longer/previously/formerly/used-to family): replace `skill_cleanup no longer deletes it
      at the skill's own Stage 9` with `skill_cleanup does not delete it at the skill's own
      Stage 9`. *(completed)*
- [x] `revise.md:12` (class 1 entangled with a substantive artifact-round claim): replace
      `Only /research advances the artifact number to start a new round.` with
      `Only a research-phase dispatch — or a forced /orchestrate --plan/--implement dispatch that
      skips research — advances the artifact number to start a new round; an unforced plan or
      implement dispatch shares the round its preceding research already opened.` Do not restate
      the rule from the stale sentence alone; this text is derived from
      `orchestrate-stage5-postflight.sh`'s live A2 P1/P2 logic.
- [x] Treat every remaining occurrence in `revise.md` per the rubric. *(completed: only the 3 named sites carried a dead-command/record-versioning hit; grep confirms zero remaining)*
- [x] `core/context/reference/artifact-numbering-and-versioning.md`: reword the "Example Flow"
      that literally types `/research 309`, `/plan 309`, `/implement 309` into the dispatch model
      that produces that behavior today, keeping it consistent with the `revise.md:12` wording
      above. Treat the file's remaining occurrences per the rubric. *(completed: reworded to
      "research/plan/implement-phase dispatch for 309"; no remaining dead-command occurrences)*
- [x] Confirm the two files' sentences do not contradict each other on the artifact-round rule. *(completed: both agree)*

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: prose

**Tier Justification**: Both files are pure-guidance markdown under the source store with no
executable surface, so the covering check is the gate subset `bash
/home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4,24
/home/benjamin/.config/nvim`, run with its exit status checked.

**Scope Hypothesis**: 2 files, with 3 named line-level fixes plus whatever further occurrences the
two files carry. The 223-file/948-occurrence corpus baseline is re-derived in this phase's first
task rather than carried from the research report. Confirm the per-file figure by running the
measurement command restricted to these two paths.

**Files to modify**:

- `agent-system/extensions/core/commands/revise.md` - three named incidental fixes (lines 12, 99, 145) plus remaining per-rubric occurrences
- `agent-system/extensions/core/context/reference/artifact-numbering-and-versioning.md` - the artifact-round worked example, kept consistent with revise.md:12

**Verification**:

- `grep -nEi '\b(no longer|previously|formerly|used to|withdrawn|superseded)\b'` over `revise.md`
  returns zero hits.
- Neither file contains `/research`, `/plan` or `/implement` as a bare command token under the
  measurement pattern, except any occurrence explicitly recorded as a class-3 decision.
- The gate subset above exits 0.
- The baseline counts are recorded in the phase notes.

---

### Phase 2: core/context/patterns [COMPLETED]

**Goal**: Treat the single densest tranche in the corpus per the rubric.

**Tasks**:

- [x] Apply the shared per-phase procedure to every file listed below. *(completed)*
- [x] `batch-orchestration-guardrails.md` is a declared `file_scope` entry of sibling task 420,
      dispatched this same cycle: re-read it immediately before editing and stage only this
      task's own hunks. *(completed: re-read, residue note added for the dead commands/*.md
      citations found in its risk analysis)*
- [x] `multi-task-operations.md` (33 occurrences) and `task-lock.md` (23) are the two heaviest
      files in the corpus; budget accordingly and do not rush them. *(completed: both found to
      describe substantially pre-orchestrate-rewrite architecture; rewarded tokens + residue
      notes recorded rather than restructuring)*

**Timing**: 1.75 hours

**Depends on**: 1

**Verification Tier**: prose

**Tier Justification**: Every path is pure-guidance markdown under the source store with no
executable surface, so the covering check is the gate subset `--only-gate 3,4,24` named in the
shared procedure above, run with its exit status checked.

**Scope Hypothesis**: 14 files / 121 occurrences, re-derived at plan time. Confirm by running the
measurement command restricted to `agent-system/extensions/core/context/patterns/`.

**Files to modify**:

- `agent-system/extensions/core/context/patterns/anti-stop-patterns.md`
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` - sibling-collision site (task 420)
- `agent-system/extensions/core/context/patterns/checkpoint-before-overflow.md`
- `agent-system/extensions/core/context/patterns/checkpoint-execution.md`
- `agent-system/extensions/core/context/patterns/context-discovery.md`
- `agent-system/extensions/core/context/patterns/lit-stage4a-flow.md`
- `agent-system/extensions/core/context/patterns/mcp-tool-recovery.md`
- `agent-system/extensions/core/context/patterns/multi-task-operations.md` - heaviest file in corpus (33 occurrences)
- `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md`
- `agent-system/extensions/core/context/patterns/skill-lifecycle.md`
- `agent-system/extensions/core/context/patterns/skill-postflight-flow.md`
- `agent-system/extensions/core/context/patterns/subagent-continuation-loop.md`
- `agent-system/extensions/core/context/patterns/task-lock.md` - second heaviest (23 occurrences)
- `agent-system/extensions/core/context/patterns/todo-archival-reference.md`

**Verification**:

- The measurement command over this tranche returns only occurrences recorded as class-3
  decisions.
- Every occurrence has a recorded class decision in the phase notes.
- The gate subset exits 0.

---

### Phase 3: core/context/orchestration and routing.md [COMPLETED]

**Goal**: Reword the dispatch-model and routing-table prose at the heart of the orchestration
documentation, where stale per-command routing rows predate the commands' deletion.

**Tasks**:

- [x] Apply the shared per-phase procedure to every file listed below. *(completed)*
- [x] `orchestrator.md` carries per-command routing-table rows (`- /research: Extension type ->
      extension agent, default -> general-research-agent`; `Examples: /plan -> planner, /revise ->
      reviser`; `**Used by**: /plan, /revise, /review, /todo, /task`). Reword to phase-name
      framing; a bare `/orchestrate` substitution would be false in each row, since routing today
      is `task_type` -> agent. *(completed: reworded to "research dispatch"/"plan dispatch"
      framing; manifest.json's routing_agents block still confirms task_type-based routing for
      these three phases)*
- [x] Check each reworded routing row against the live Skill-to-Agent mapping rather than assuming
      the stale row's claim still holds for the phase it names. *(completed; also found and
      reworded architecture.md's deeper Layer-1/Layer-2 delegation-model residue, flagged via an
      inline note rather than restructured)*

**Timing**: 1.25 hours

**Depends on**: 1

**Verification Tier**: prose

**Tier Justification**: Every path is pure-guidance markdown under the source store with no
executable surface, so the covering check is the gate subset `--only-gate 3,4,24` named in the
shared procedure above, run with its exit status checked.

**Scope Hypothesis**: 10 files / 63 occurrences, re-derived at plan time. Confirm by running the
measurement command restricted to `agent-system/extensions/core/context/orchestration/` plus
`core/context/routing.md`.

**Files to modify**:

- `agent-system/extensions/core/context/orchestration/architecture.md`
- `agent-system/extensions/core/context/orchestration/delegation.md`
- `agent-system/extensions/core/context/orchestration/orchestration-core.md`
- `agent-system/extensions/core/context/orchestration/orchestration-reference.md`
- `agent-system/extensions/core/context/orchestration/orchestrator.md` - stale per-command routing-table rows
- `agent-system/extensions/core/context/orchestration/postflight-pattern.md`
- `agent-system/extensions/core/context/orchestration/preflight-pattern.md`
- `agent-system/extensions/core/context/orchestration/state-management.md`
- `agent-system/extensions/core/context/orchestration/validation.md`
- `agent-system/extensions/core/context/routing.md`

**Verification**:

- The measurement command over this tranche returns only recorded class-3 decisions.
- Each reworded routing claim is checked against live routing, not merely renamed.
- The gate subset exits 0.

---

### Phase 4: core/context/standards and core/context/formats [COMPLETED]

**Goal**: Treat the standards and format documents, including the two verified class-2 sites in
`plan-format.md`.

**Tasks**:

- [x] Apply the shared per-phase procedure to every file listed below. *(completed: 15 of 17
      files were already reworded, uncommitted, by the prior stalled dispatch; re-verified
      against the measurement command with zero remaining dead-command tokens; the remaining 2
      -- command-structure.md, plan-format.md -- completed in this resumption)*
- [x] `plan-format.md:3` — reword the stale per-command scope line to phase framing. *(completed:
      "/plan, /revise, /implement (phase planning), /review" -> "a plan-phase dispatch, /revise,
      an implement-phase dispatch (phase planning), /review")*
- [x] `plan-format.md:455` — reword ``a bare `/implement N` `` to a single-task implement dispatch. *(completed)*
- [x] `return-metadata-file.md` and `git-staging-scope.md` are declared `file_scope` entries of
      sibling task 430, dispatched this same cycle: re-read each immediately before editing and
      stage only this task's own hunks. *(completed by the prior dispatch; re-confirmed clean of
      dead-command tokens, no re-collision with 430's own hunks found)*
- [x] `status-markers.md` (19 occurrences) is the heaviest file in this tranche. *(completed by
      the prior dispatch)*
- [x] `command-structure.md` — 7 occurrences, all inside a single worked example built on the
      stale premise that /plan is itself a standalone command file; a disclaimer was added ahead
      of the example (Non-Goals-compliant: reworded, not restructured) and 4 standalone
      "Example:" lines outside the fence were reworded to phase-dispatch framing. Residual
      incoherence recorded per-site in the phase-4 progress file rather than restructured. *(completed)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: prose

**Tier Justification**: Every path is pure-guidance markdown under the source store with no
executable surface, so the covering check is the gate subset `--only-gate 3,4,24` named in the
shared procedure above, run with its exit status checked.

**Scope Hypothesis**: 17 files / 73 occurrences, re-derived at plan time. Confirm by running the
measurement command restricted to `agent-system/extensions/core/context/standards/` and
`agent-system/extensions/core/context/formats/`.

**Files to modify**:

- `agent-system/extensions/core/context/formats/command-structure.md`
- `agent-system/extensions/core/context/formats/errors-format.md`
- `agent-system/extensions/core/context/formats/frontmatter.md`
- `agent-system/extensions/core/context/formats/plan-format.md` - two verified class-2 sites (lines 3, 455)
- `agent-system/extensions/core/context/formats/report-format.md`
- `agent-system/extensions/core/context/formats/return-metadata-file.md` - sibling-collision site (task 430)
- `agent-system/extensions/core/context/formats/subagent-return.md`
- `agent-system/extensions/core/context/formats/summary-format.md`
- `agent-system/extensions/core/context/standards/ci-workflow.md`
- `agent-system/extensions/core/context/standards/error-handling.md`
- `agent-system/extensions/core/context/standards/error-recovery-strategies.md`
- `agent-system/extensions/core/context/standards/git-integration.md`
- `agent-system/extensions/core/context/standards/git-staging-scope.md` - sibling-collision site (task 430)
- `agent-system/extensions/core/context/standards/postflight-tool-restrictions.md`
- `agent-system/extensions/core/context/standards/status-markers.md` - heaviest in tranche (19 occurrences)
- `agent-system/extensions/core/context/standards/task-management.md`
- `agent-system/extensions/core/context/standards/task-reference-exemptions.md`

**Verification**:

- The measurement command over this tranche returns only recorded class-3 decisions.
- The gate subset exits 0.

---

### Phase 5: core/context/processes and core/context/workflows — Decision Gate [COMPLETED]

**Goal**: Reword the occurrences in the three lifecycle-narrative process documents and the three
workflow documents, and decide — on measured evidence, not impression — whether local rewording
leaves each document coherent.

This phase is a decision gate. The three `processes/` documents (`research-workflow.md` 566 lines,
`planning-workflow.md` 538, `implementation-workflow.md` 588) are each built around a standalone
command's usage grammar (`Usage: /research TASK_NUMBER [PROMPT]`, `Resume with: /plan
{task_number}`), a premise that no longer exists. The gate's criterion is whether rewording each
document's occurrences leaves a document that states something true.

- **Criterion met** (rewording suffices): the phase closes normally.
- **Criterion fails** for a document (rewording leaves a document whose framing is still false):
  reword the occurrences anyway so no dead command name survives, record the residual
  incoherence and the specific framing at fault in the phase notes, and name it for a follow-up
  record. **Do not restructure the document here** — restructure is a Non-Goal, and the
  `core/docs/` scope amendment is the precedent: restructures belong to records that own them.

**Tasks**:

- [x] Apply the shared per-phase procedure to every file listed below. *(completed: 29 occurrences
      measured vs. 36 hypothesized -- drift recorded in the phase-5 progress file, not silently
      absorbed; all 6 files treated, zero dead-command tokens remain in this tranche)*
- [x] For each `processes/` document, evaluate the gate criterion explicitly and record the
      verdict with the specific sentences that drove it. *(completed: all three verdicts are
      "rewording insufficient" -- see phase-5 progress file objective 2 for the full per-document
      evidence and residue)*
- [x] `workflows/command-lifecycle.md` (13 occurrences measured at this resumption, not 18) is the
      heaviest file in this tranche. *(completed: all 13 reworded to phase framing, plus one
      additional non-measured stale command-file Reference corrected)*
- [x] If any gate verdict is "rewording insufficient", record the residue and the proposed
      follow-up scope in the phase notes. Do not restructure. *(completed: residue recorded for
      research-workflow.md, planning-workflow.md, implementation-workflow.md and
      command-lifecycle.md in the phase-5 progress file; no document restructured)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: prose

**Tier Justification**: Every path is pure-guidance markdown under the source store with no
executable surface, so the covering check is the gate subset `--only-gate 3,4,24` named in the
shared procedure above, run with its exit status checked.

**Scope Hypothesis**: 6 files / 36 occurrences, re-derived at plan time — a low occurrence count
against ~3,200 lines of document, which is exactly why the gate criterion is about document
coherence rather than occurrence count. Confirm by running the measurement command restricted to
`agent-system/extensions/core/context/processes/` and
`agent-system/extensions/core/context/workflows/`.

**Files to modify**:

- `agent-system/extensions/core/context/processes/implementation-workflow.md` - gate-criterion document
- `agent-system/extensions/core/context/processes/planning-workflow.md` - gate-criterion document
- `agent-system/extensions/core/context/processes/research-workflow.md` - gate-criterion document
- `agent-system/extensions/core/context/workflows/command-lifecycle.md` - heaviest in tranche (18 occurrences)
- `agent-system/extensions/core/context/workflows/meta-interview.md`
- `agent-system/extensions/core/context/workflows/preflight-postflight.md`

**Verification**:

- The measurement command over this tranche returns only recorded class-3 decisions.
- A gate verdict is recorded for each of the three `processes/` documents, with the sentences
  that drove it.
- No document was restructured; any residue is recorded with a named follow-up scope.
- The gate subset exits 0.

---

### Phase 6: core/context remainder [COMPLETED]

**Goal**: Treat the remaining `core/context/` files not covered by Phases 1-5.

**Tasks**:

- [x] Apply the shared per-phase procedure to every file listed below. *(completed: all 17 files
      treated, zero remaining dead-command tokens)*
- [x] `architecture/system-overview.md`: reword the dead-command half of its sentence only. Leave
      its "Superseded note"/"used to" record-versioning phrasing exactly as-is — that is an
      explicit Non-Goal of this record, confirmed advisory-tier by the live gate and owned by a
      completed lineage. *(completed: only the backtick-wrapped slash tokens dropped; versioning
      phrasing preserved verbatim)*
- [x] The two `.json` files (`index.schema.json`, `schemas/errors-schema.json`,
      `schemas/orchestrator-handoff-schema.json`) hold occurrences in schema descriptions or
      enum documentation: check whether each is prose about the system (class 2) or a schema
      value other code matches on (class 3) before editing. *(completed: all three verdicted
      class 2, not class 3 -- see phase-6 progress file objective 3 for the full reasoning,
      including the discovery that index.schema.json's and README.md's dead-command `examples`
      were illustrating a currently-invalid configuration, corrected to a live-command example)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: prose

**Tier Justification**: Every path is markdown or a JSON schema document with no executable
surface, so the covering check is the gate subset `--only-gate 3,4,24` named in the shared
procedure above, run with its exit status checked.

**Scope Hypothesis**: 17 files / roughly 52 occurrences (the 57-occurrence subtotal for this
tranche at plan time, less `artifact-numbering-and-versioning.md`, which Phase 1 owns). Confirm by
running the measurement command restricted to `agent-system/extensions/core/context/` and
subtracting the tranches owned by Phases 1-5.

**Files to modify**:

- `agent-system/extensions/core/context/architecture/component-checklist.md`
- `agent-system/extensions/core/context/architecture/system-overview.md` - dead-command half only; leave record-versioning phrasing untouched
- `agent-system/extensions/core/context/checkpoints/checkpoint-gate-in.md`
- `agent-system/extensions/core/context/checkpoints/checkpoint-gate-out.md`
- `agent-system/extensions/core/context/checkpoints/README.md`
- `agent-system/extensions/core/context/contracts/batch-gate-stage.md`
- `agent-system/extensions/core/context/guides/manifest-routing-schema.md`
- `agent-system/extensions/core/context/index.schema.json` - check prose-vs-schema-value before editing
- `agent-system/extensions/core/context/meta/domain-patterns.md`
- `agent-system/extensions/core/context/meta/meta-guide.md`
- `agent-system/extensions/core/context/README.md`
- `agent-system/extensions/core/context/reference/state-management-schema.md`
- `agent-system/extensions/core/context/reference/workflow-diagrams.md`
- `agent-system/extensions/core/context/repo/update-project.md`
- `agent-system/extensions/core/context/schemas/errors-schema.json` - check prose-vs-schema-value before editing
- `agent-system/extensions/core/context/schemas/orchestrator-handoff-schema.json` - check prose-vs-schema-value before editing
- `agent-system/extensions/core/context/templates/command-template.md`

**Verification**:

- The measurement command over `core/context/` returns only recorded class-3 decisions across the
  whole subtree (Phases 1-6 together).
- `system-overview.md`'s record-versioning phrasing is byte-identical to its pre-phase state.
- The gate subset exits 0.

---

### Phase 7: core/scripts and core/hooks [COMPLETED]

**Goal**: Treat the comment-level and fixture-level occurrences in shell sources — the tranche
with the highest class-3 density and the only one where a wrong edit breaks executable behavior.

**Tasks**:

- [x] Apply the shared per-phase procedure to every file listed below, with every edit confined
      to a comment or a string; no edit may cross out of a comment or string boundary. *(completed:
      verified via `bash -n` on all 18 touched scripts, zero syntax errors)*
- [x] **Leave `lint/lint-dead-command-recommendations.sh` alone** apart from recording the
      decision: line 8 is the correct historical statement of the lint's purpose, and lines 53-54
      are illustrative match strings documenting its detection behavior. Rewording either
      corrupts the gate this task depends on staying green. *(completed: confirmed byte-identical
      to pre-phase state via git diff)*
- [x] **`tests/test-double-loading-check.sh:187`** — `"commands": ["/research"]` is JSON test
      fixture data coupled to the suite's expectations. Class 3 unless reading the suite shows the
      value is inert; record the decision either way. *(completed: read the suite, confirmed the
      value is inert -- no assertion checks the literal substring -- so treated per the
      dispatch's own conditional, swapped to "/revise". Discovered the same inert-fixture defect
      class in 15 more sites across 7 other test files not individually named by the dispatch;
      treated identically, see phase-7 progress file objective 5)*
- [x] **`lib/task-type-detect.sh:112`** — an illustrative list of leading-slash command tokens.
      Swap the dead token for a live command; do not change the surrounding detection description.
      *(completed: swapped /implement -> /revise)*
- [x] `skill-base.sh`'s `skill_cleanup()` doc-comment names
      `commands/{research,plan,implement,revise,orchestrate}.md`, three of which do not exist.
      Correct it to the two that do. Note: `skill-base.sh` is not in the measured hit list for
      this pattern, so add it to this phase's working set explicitly rather than expecting the
      sweep to surface it — the research report names this as a site easy to drop. *(completed)*
- [x] `orchestrate-cycle-plan.sh` (task 420) and `update-task-status.sh` (task 430) are declared
      `file_scope` entries of siblings dispatched this same cycle: re-read each immediately
      before editing and stage only this task's own hunks. *(completed: re-read, no collision with
      either sibling's own hunks; also found and fixed a genuine dead-command user-facing
      recommendation in orchestrate-cycle-plan.sh:1459 not caught by gate 24's own pattern, see
      phase-7 progress file objective 9)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: prose

**Tier Justification**: Every edit is confined to a comment or string inside a shell source with
no change to any executable line, and the `prose` tier's own blind spot — an edit crossing out of
the comment or string boundary — is covered by adding gate 22 to the gate subset: `bash
/home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4,22,24
/home/benjamin/.config/nvim`, run with its exit status checked.

**Scope Hypothesis**: 23 files / 61 occurrences from the measured hit list, plus
`core/scripts/skill-base.sh`, which the pattern does not match but which carries a known
stale-file-path doc-comment — 24 files in total. Confirm the 23 by running the measurement command
restricted to `agent-system/extensions/core/scripts/` and `agent-system/extensions/core/hooks/`;
confirm `skill-base.sh` by reading the `skill_cleanup()` doc-comment directly.

**Files to modify**:

- `agent-system/extensions/core/hooks/wezterm-preflight-status.sh`
- `agent-system/extensions/core/hooks/wezterm-task-number.sh`
- `agent-system/extensions/core/scripts/command-gate-out.sh`
- `agent-system/extensions/core/scripts/errors-append.sh`
- `agent-system/extensions/core/scripts/lib/task-type-detect.sh` - illustrative token list; swap dead token, leave detection description
- `agent-system/extensions/core/scripts/lifecycle-notify.sh`
- `agent-system/extensions/core/scripts/lint/lint-contract-compliance.sh`
- `agent-system/extensions/core/scripts/lint/lint-dead-command-recommendations.sh` - class 3, leave alone; record the decision
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` - sibling-collision site (task 420)
- `agent-system/extensions/core/scripts/orchestrate-recover-outcome.sh`
- `agent-system/extensions/core/scripts/reconcile-task-status.sh`
- `agent-system/extensions/core/scripts/skill-base.sh` - skill_cleanup() doc-comment stale file-path list; not matched by the sweep pattern
- `agent-system/extensions/core/scripts/task-lock.sh`
- `agent-system/extensions/core/scripts/test-four-tier-conflict.sh`
- `agent-system/extensions/core/scripts/test-session-registry.sh`
- `agent-system/extensions/core/scripts/test-task-lock-reap.sh`
- `agent-system/extensions/core/scripts/tests/test-dispatch-strand-probe.sh`
- `agent-system/extensions/core/scripts/tests/test-double-loading-check.sh` - JSON fixture at line 187; class 3 unless the suite shows it inert
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh`
- `agent-system/extensions/core/scripts/tests/test-phase-heartbeat.sh`
- `agent-system/extensions/core/scripts/tests/test-reconcile-demote-stranded.sh`
- `agent-system/extensions/core/scripts/tests/test-task-lock-liveness.sh`
- `agent-system/extensions/core/scripts/update-task-status.sh` - sibling-collision site (task 430)
- `agent-system/extensions/core/scripts/validate-context-budgets.sh`

**Verification**:

- A diff read-through confirms every changed hunk lies inside a comment or string region.
- The gate subset, including gate 22, exits 0.
- `bash .claude/scripts/tests/run-all.sh --only test-double-loading-check.sh` exits 0, confirming
  the fixture decision did not break the suite that owns it.
- `lint-dead-command-recommendations.sh` is byte-identical to its pre-phase state, and the phase
  notes record that as a class-3 decision with its reason.

---

### Phase 8: core/commands, agents, skills, templates and README [COMPLETED]

**Goal**: Treat the remaining `core` surface outside `context/` and `scripts/`.

**Tasks**:

- [x] Apply the shared per-phase procedure to every file listed below. *(completed: 31
      occurrences across all 17 files, zero remaining)*
- [x] `general-implementation-agent.md` is a declared `file_scope` entry of sibling task 430,
      dispatched this same cycle: re-read it immediately before editing and stage only this
      task's own hunks. *(completed: re-read, no collision)*
- [x] `commands/` files describe live commands; an occurrence naming a dead command inside a live
      command's own documentation is almost always class 1 (the sentence means the phase) — check
      each rather than assuming. *(completed: merge.md and spawn.md needed an invocable
      `/orchestrate ...` form rather than bare phase prose since both are literal command-list/
      next-steps copy; the rest took ordinary phase framing -- see phase-8 progress file
      objective 3)*
- [x] `meta-builder-agent.md` (11 occurrences at plan time; 5 measured at this resumption) and
      `README.md` (10 at plan time; 4 measured at this resumption, including a literal command
      table with invocable 'Usage' syntax needing a corrected `/orchestrate` form, not just a
      reword) are the heaviest here. *(completed; occurrence-count drift between plan time and
      this resumption recorded, not silently absorbed, per the established per-phase convention)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: prose

**Tier Justification**: Every path is pure-guidance markdown under the source store with no
executable surface, so the covering check is the gate subset `--only-gate 3,4,24` named in the
shared procedure above, run with its exit status checked.

**Scope Hypothesis**: 17 files (the 18-file measured subtotal for this tranche, less `revise.md`,
which Phase 1 owns). Confirm by running the measurement command restricted to
`agent-system/extensions/core/{commands,agents,skills,templates}/` plus
`agent-system/extensions/core/README.md`.

**Files to modify**:

- `agent-system/extensions/core/agents/general-implementation-agent.md` - sibling-collision site (task 430)
- `agent-system/extensions/core/agents/general-research-agent.md`
- `agent-system/extensions/core/agents/meta-builder-agent.md` - heaviest in tranche (11 occurrences)
- `agent-system/extensions/core/agents/planner-agent.md`
- `agent-system/extensions/core/agents/spawn-agent.md`
- `agent-system/extensions/core/commands/fix-it.md`
- `agent-system/extensions/core/commands/merge.md`
- `agent-system/extensions/core/commands/meta.md`
- `agent-system/extensions/core/commands/spawn.md`
- `agent-system/extensions/core/commands/task.md`
- `agent-system/extensions/core/README.md`
- `agent-system/extensions/core/skills/skill-fix-it/SKILL.md`
- `agent-system/extensions/core/skills/skill-meta/SKILL.md`
- `agent-system/extensions/core/skills/skill-project-overview/SKILL.md`
- `agent-system/extensions/core/skills/skill-reviser/SKILL.md`
- `agent-system/extensions/core/skills/skill-status-sync/SKILL.md`
- `agent-system/extensions/core/templates/extension-readme-template.md`

**Verification**:

- The measurement command over `agent-system/extensions/core/` returns only recorded class-3
  decisions across the whole extension (Phases 1-8 together).
- The gate subset exits 0.

---

### Phase 9: founder/skills [COMPLETED]

**Goal**: Treat the founder extension's skill definitions.

**Tasks**:

- [x] Apply the shared per-phase procedure to every file listed below. *(completed: 33
      occurrences across all 14 files, zero remaining)*
- [x] Several of these skills are themselves named for a lifecycle phase
      (`skill-founder-plan`, `skill-founder-implement`, `skill-deck-research`): a reference to the
      skill is not a reference to a dead command. Distinguish the two at each site. *(completed:
      no skill name or frontmatter `name:` field was ever a candidate for editing -- none matched
      the measurement pattern; only the prose describing command-to-skill routing was reworded)*

**Timing**: 1.25 hours

**Depends on**: 1

**Verification Tier**: prose

**Tier Justification**: Every path is pure-guidance markdown under the source store with no
executable surface, so the covering check is the gate subset `--only-gate 3,4,24` named in the
shared procedure above, run with its exit status checked.

**Scope Hypothesis**: 14 files, part of the founder extension's 33-file / 142-occurrence total
re-derived at plan time. Confirm by running the measurement command restricted to
`agent-system/extensions/founder/skills/`.

**Files to modify**:

- `agent-system/extensions/founder/skills/skill-analyze/SKILL.md`
- `agent-system/extensions/founder/skills/skill-deck-implement/SKILL.md`
- `agent-system/extensions/founder/skills/skill-deck-plan/SKILL.md`
- `agent-system/extensions/founder/skills/skill-deck-research/SKILL.md`
- `agent-system/extensions/founder/skills/skill-finance/SKILL.md`
- `agent-system/extensions/founder/skills/skill-financial-analysis/SKILL.md`
- `agent-system/extensions/founder/skills/skill-founder-implement/SKILL.md`
- `agent-system/extensions/founder/skills/skill-founder-plan/SKILL.md`
- `agent-system/extensions/founder/skills/skill-founder-spreadsheet/SKILL.md`
- `agent-system/extensions/founder/skills/skill-legal/SKILL.md`
- `agent-system/extensions/founder/skills/skill-market/SKILL.md`
- `agent-system/extensions/founder/skills/skill-meeting/SKILL.md`
- `agent-system/extensions/founder/skills/skill-project/SKILL.md`
- `agent-system/extensions/founder/skills/skill-strategy/SKILL.md`

**Verification**:

- The measurement command over this tranche returns only recorded class-3 decisions.
- The gate subset exits 0.

---

### Phase 10: founder commands, agents, context and README [COMPLETED]

**Goal**: Treat the rest of the founder extension.

**Tasks**:

- [x] Apply the shared per-phase procedure to every file listed below. *(completed: 60+
      occurrences across all 19 files, zero remaining)*
- [x] `context/project/founder/domain/workflow-reference.md` (22 occurrences) is the heaviest file
      outside `core`; it is a workflow-narrative document and may need the same coherence judgment
      Phase 5 applies to `core`'s process documents. If local rewording leaves it incoherent,
      record the residue — do not restructure. *(completed: VERDICT criterion MET, unlike Phase
      5's core processes/ docs -- the underlying task_type routing mechanism is real and current;
      no residue needed, see phase-10 progress file objective 2)*
- [x] `context/project/founder/domain/migration-guide.md` (10 occurrences) may name the dead
      commands as historical record; apply the class-3 test before editing. *(completed: applied
      PER-CELL, not per-file -- the 'v2.x Pattern' left column is genuine historical record,
      class 3, left alone (2 cells survive); the 'v3.0 Equivalent' right column makes present-tense
      claims and was reworded (5 sites). See phase-10 progress file objective 3 for the discovered
      sub-rule)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: prose

**Tier Justification**: Every path is pure-guidance markdown under the source store with no
executable surface, so the covering check is the gate subset `--only-gate 3,4,24` named in the
shared procedure above, run with its exit status checked.

**Scope Hypothesis**: 19 files, the remainder of founder's 33-file total after Phase 9's 14.
Confirm by running the measurement command restricted to `agent-system/extensions/founder/` and
subtracting the `skills/` tranche.

**Files to modify**:

- `agent-system/extensions/founder/agents/analyze-agent.md`
- `agent-system/extensions/founder/agents/finance-agent.md`
- `agent-system/extensions/founder/agents/founder-implement-agent.md`
- `agent-system/extensions/founder/agents/founder-spreadsheet-agent.md`
- `agent-system/extensions/founder/agents/legal-council-agent.md`
- `agent-system/extensions/founder/agents/market-agent.md`
- `agent-system/extensions/founder/agents/project-agent.md`
- `agent-system/extensions/founder/agents/strategy-agent.md`
- `agent-system/extensions/founder/commands/analyze.md`
- `agent-system/extensions/founder/commands/deck.md`
- `agent-system/extensions/founder/commands/finance.md`
- `agent-system/extensions/founder/commands/legal.md`
- `agent-system/extensions/founder/commands/market.md`
- `agent-system/extensions/founder/commands/project.md`
- `agent-system/extensions/founder/commands/sheet.md`
- `agent-system/extensions/founder/commands/strategy.md`
- `agent-system/extensions/founder/context/project/founder/domain/migration-guide.md` - apply the class-3 historical-record test
- `agent-system/extensions/founder/context/project/founder/domain/workflow-reference.md` - heaviest outside core (22 occurrences); coherence judgment may apply
- `agent-system/extensions/founder/README.md`

**Verification**:

- The measurement command over `agent-system/extensions/founder/` returns only recorded class-3
  decisions across the whole extension (Phases 9-10 together).
- The gate subset exits 0.

---

### Phase 11: present [COMPLETED]

**Goal**: Treat the present extension.

**Tasks**:

- [x] Apply the shared per-phase procedure to every file listed below. *(completed: 83
      occurrences across all 19 files, zero remaining)*
- [x] `commands/grant.md` (14 occurrences), `context/project/present/domain/grant-workflow.md`
      (12) and `commands/slides.md` (12) are the dense sites in this tranche. *(completed;
      grant.md:314 found to carry a genuine dead-command recommendation gate 24 missed because
      its Layer-2 shape test only checks the first command on a 'Next:' line -- see phase-11
      progress file objective 2 for the full finding)*
- [x] `present` defines compound task types (`present:grant`): a routing reference naming a phase
      for a compound type is class 2 and must keep the compound-type framing intact. *(completed:
      every `present:slides` compound-type string preserved verbatim throughout)*

**Timing**: 1.75 hours

**Depends on**: 1

**Verification Tier**: prose

**Tier Justification**: Every path is pure-guidance markdown under the source store with no
executable surface, so the covering check is the gate subset `--only-gate 3,4,24` named in the
shared procedure above, run with its exit status checked.

**Scope Hypothesis**: 19 files / 93 occurrences, re-derived at plan time. Confirm by running the
measurement command restricted to `agent-system/extensions/present/`.

**Files to modify**:

- `agent-system/extensions/present/agents/budget-agent.md`
- `agent-system/extensions/present/agents/funds-agent.md`
- `agent-system/extensions/present/agents/grant-agent.md`
- `agent-system/extensions/present/agents/slide-planner-agent.md`
- `agent-system/extensions/present/agents/slides-research-agent.md`
- `agent-system/extensions/present/commands/budget.md`
- `agent-system/extensions/present/commands/funds.md`
- `agent-system/extensions/present/commands/grant.md` - dense site (14 occurrences)
- `agent-system/extensions/present/commands/slides.md` - dense site (12 occurrences)
- `agent-system/extensions/present/commands/timeline.md`
- `agent-system/extensions/present/context/project/present/domain/grant-workflow.md` - dense site (12 occurrences)
- `agent-system/extensions/present/README.md`
- `agent-system/extensions/present/skills/skill-budget/SKILL.md`
- `agent-system/extensions/present/skills/skill-funds/SKILL.md`
- `agent-system/extensions/present/skills/skill-grant/SKILL.md`
- `agent-system/extensions/present/skills/skill-slide-critic/SKILL.md`
- `agent-system/extensions/present/skills/skill-slide-planning/SKILL.md`
- `agent-system/extensions/present/skills/skill-slides/SKILL.md`
- `agent-system/extensions/present/skills/skill-timeline/SKILL.md`

**Verification**:

- The measurement command over `agent-system/extensions/present/` returns only recorded class-3
  decisions.
- The gate subset exits 0.

---

### Phase 12: cslib and memory [COMPLETED]

**Goal**: Treat the cslib and memory extensions.

**Tasks**:

- [x] Apply the shared per-phase procedure to every file listed below. *(completed: 69
      occurrences across all 19 files, zero remaining)*
- [x] `memory/README.md` (14 occurrences at plan time; 8 measured at this resumption) is the
      densest here. Memory's auto-retrieval documentation names the three commands as the
      preflight stages that call `memory-retrieve.sh`: that is class 2 (phase framing), and the
      `--clean` suppression claim attached to it must stay true after rewording. *(completed:
      verified `--clean` is a live `/orchestrate` flag via commands/orchestrate.md before
      rewording; the claim remains true)*
- [x] cslib's hard-mode and PR-review skills reference lifecycle phases for `task_type: pr`:
      check each against the live `[PR READY]` lifecycle rather than renaming mechanically.
      *(completed: verified the pr-submission-vs-pr-review routing branch (keyed on `sources`
      presence) against README.md's own routing tables before rewording; the branching logic
      was preserved exactly, only the command tokens naming the phases were reworded)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: prose

**Tier Justification**: Every path is pure-guidance markdown under the source store with no
executable surface, so the covering check is the gate subset `--only-gate 3,4,24` named in the
shared procedure above, run with its exit status checked.

**Scope Hypothesis**: 19 files / 69 occurrences (cslib 11/35, memory 8/34), re-derived at plan
time. Confirm by running the measurement command restricted to
`agent-system/extensions/cslib/` and `agent-system/extensions/memory/`.

**Files to modify**:

- `agent-system/extensions/cslib/agents/pr-review-implementation-agent.md`
- `agent-system/extensions/cslib/agents/pr-review-research-agent.md`
- `agent-system/extensions/cslib/context/project/cslib/domain/hard-mode-selection.md`
- `agent-system/extensions/cslib/context/project/cslib/pr-command-workflow.md`
- `agent-system/extensions/cslib/README.md`
- `agent-system/extensions/cslib/skills/skill-cslib-implementation-hard/SKILL.md`
- `agent-system/extensions/cslib/skills/skill-cslib-implementation/SKILL.md`
- `agent-system/extensions/cslib/skills/skill-cslib-research-hard/SKILL.md`
- `agent-system/extensions/cslib/skills/skill-pr-implementation/SKILL.md`
- `agent-system/extensions/cslib/skills/skill-pr-review-implementation/SKILL.md`
- `agent-system/extensions/cslib/skills/skill-pr-review-research/SKILL.md`
- `agent-system/extensions/memory/context/project/memory/distill-usage.md`
- `agent-system/extensions/memory/context/project/memory/knowledge-capture-usage.md`
- `agent-system/extensions/memory/context/project/memory/memory-setup.md`
- `agent-system/extensions/memory/context/project/memory/memory-troubleshooting.md`
- `agent-system/extensions/memory/EXTENSION.md`
- `agent-system/extensions/memory/README.md` - densest in tranche (14 occurrences); `--clean` claim must stay true
- `agent-system/extensions/memory/skills/skill-distill/SKILL.md`
- `agent-system/extensions/memory/skills/skill-learn/README.md`

**Verification**:

- The measurement command over both extensions returns only recorded class-3 decisions.
- The gate subset exits 0.

---

### Phase 13: literature, lean, epidemiology, nvim and email [COMPLETED]

**Goal**: Treat the five mid-sized extensions.

**Tasks**:

- [x] Apply the shared per-phase procedure to every file listed below. *(completed: 108
      occurrences across the five extension roots, zero remaining apart from 3 intentional
      class-3 sites)*
- [x] `literature/index-entries.json` (20 occurrences) is the densest file in this tranche and is
      structured data: its occurrences are most likely `load_when.commands` registration values,
      which are matched by the context-discovery machinery. Apply the class-3 test before editing,
      and if a registration value names a dead command, the correct fix is to make the entry
      reachable under the live command set rather than to reword prose. *(completed: found NOT
      class-3 -- every entry's reachability was already guaranteed by its own `agents` array, so
      the dead command strings were dropped outright rather than reworded or replaced; see
      phase-13 progress file objective 2 for the full validate-context-budgets.sh-grounded
      evidence)*
- [x] `literature/merge-sources/claudemd.md` is a merge source for the generated root
      `.claude/CLAUDE.md`: a reword here propagates into that generated file on redeploy, so
      check the rendered result in Phase 15. *(completed: both occurrences reworded; rendered
      result deferred to Phase 15 as instructed)*
- [x] lean's hard-mode and proof-debt documents reference lifecycle phases: class 2 rewords.
      *(completed, using the same `/orchestrate --research --hard` composition style
      established in Phase 12's cslib treatment)*

**Timing**: 2 hours

**Depends on**: 1

**Verification Tier**: prose

**Tier Justification**: Every path is markdown or a JSON index-registration document with no
executable surface, so the covering check is the gate subset `--only-gate 3,4,24` named in the
shared procedure above, run with its exit status checked.

**Scope Hypothesis**: 25 files / 108 occurrences (literature 6/39, lean 6/21, epidemiology 5/17,
nvim 4/15, email 4/16), re-derived at plan time. Confirm by running the measurement command
restricted to each of the five extension roots.

**Files to modify**:

- `agent-system/extensions/email/context/project/email/design/email-to-memory-preferences.md`
- `agent-system/extensions/email/README.md`
- `agent-system/extensions/email/skills/skill-email-cleanup/SKILL.md`
- `agent-system/extensions/email/skills/skill-email-implementation/SKILL.md`
- `agent-system/extensions/epidemiology/agents/epi-implement-agent.md`
- `agent-system/extensions/epidemiology/commands/epi.md`
- `agent-system/extensions/epidemiology/README.md`
- `agent-system/extensions/epidemiology/skills/skill-epi-implement/SKILL.md`
- `agent-system/extensions/epidemiology/skills/skill-epi-research/SKILL.md`
- `agent-system/extensions/lean/context/project/lean4/domain/hard-mode.md`
- `agent-system/extensions/lean/context/project/lean4/standards/proof-debt-policy.md`
- `agent-system/extensions/lean/README.md`
- `agent-system/extensions/lean/skills/skill-lean-implementation-hard/SKILL.md`
- `agent-system/extensions/lean/skills/skill-lean-implementation/SKILL.md`
- `agent-system/extensions/lean/skills/skill-lean-research-hard/SKILL.md`
- `agent-system/extensions/literature/context/guides/literature-organization.md`
- `agent-system/extensions/literature/context/project/literature/domain/zotero-integration.md`
- `agent-system/extensions/literature/context/project/literature/patterns/adhoc-navigation-directive.md`
- `agent-system/extensions/literature/index-entries.json` - densest in tranche (20 occurrences); registration values, apply the class-3 test
- `agent-system/extensions/literature/merge-sources/claudemd.md` - propagates into generated root CLAUDE.md on redeploy
- `agent-system/extensions/literature/README.md`
- `agent-system/extensions/nvim/context/project/neovim/guides/tts-stt-integration.md`
- `agent-system/extensions/nvim/context/project/neovim/hooks/wezterm-integration.md`
- `agent-system/extensions/nvim/README.md`
- `agent-system/extensions/nvim/skills/skill-neovim-implementation/SKILL.md`

**Verification**:

- The measurement command over the five extension roots returns only recorded class-3 decisions.
- `bash .claude/scripts/tests/run-all.sh --only test-index-entries-schema.sh` exits 0 if
  `literature/index-entries.json` was edited, confirming the registration change is schema-valid.
- The gate subset exits 0.

---

### Phase 14: the nine remaining extensions [COMPLETED]

**Goal**: Treat the low-density tail: web, rust, nix, books, z3, typst, python, latex and formal.

**Tasks**:

- [x] Apply the shared per-phase procedure to every file listed below. *(completed: 44
      occurrences across all 21 files, zero remaining)*
- [x] `formal/README.md` carries 8 occurrences in a single file — the densest point in this
      otherwise sparse tranche. *(completed: all 4 sentences reworded consistently)*
- [x] Each extension's README carries a routing table whose rows name research/plan/implement
      skills per language. Those rows describe live skills, not dead commands: distinguish a
      skill name from a command token at each site before editing. *(completed: no skill name
      was ever a candidate for editing)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: prose

**Tier Justification**: Every path is pure-guidance markdown under the source store with no
executable surface, so the covering check is the gate subset `--only-gate 3,4,24` named in the
shared procedure above, run with its exit status checked.

**Scope Hypothesis**: 21 files / 59 occurrences (web 3/7, rust 3/8, nix 3/12, books 3/4, z3 2/5,
typst 2/5, python 2/5, latex 2/5, formal 1/8), re-derived at plan time. Confirm by running the
measurement command restricted to each of the nine extension roots.

**Files to modify**:

- `agent-system/extensions/books/skills/skill-books-implementation-hard/SKILL.md`
- `agent-system/extensions/books/skills/skill-books-implementation/SKILL.md`
- `agent-system/extensions/books/skills/skill-books-research-hard/SKILL.md`
- `agent-system/extensions/formal/README.md` - densest in tranche (8 occurrences)
- `agent-system/extensions/latex/README.md`
- `agent-system/extensions/latex/skills/skill-latex-implementation/SKILL.md`
- `agent-system/extensions/nix/EXTENSION.md`
- `agent-system/extensions/nix/README.md`
- `agent-system/extensions/nix/skills/skill-nix-implementation/SKILL.md`
- `agent-system/extensions/python/README.md`
- `agent-system/extensions/python/skills/skill-python-implementation/SKILL.md`
- `agent-system/extensions/rust/EXTENSION.md`
- `agent-system/extensions/rust/README.md`
- `agent-system/extensions/rust/skills/skill-rust-implementation/SKILL.md`
- `agent-system/extensions/typst/README.md`
- `agent-system/extensions/typst/skills/skill-typst-implementation/SKILL.md`
- `agent-system/extensions/web/README.md`
- `agent-system/extensions/web/skills/skill-web-implementation/SKILL.md`
- `agent-system/extensions/web/skills/skill-web-research/SKILL.md`
- `agent-system/extensions/z3/README.md`
- `agent-system/extensions/z3/skills/skill-z3-implementation/SKILL.md`

**Verification**:

- The measurement command over the nine extension roots returns only recorded class-3 decisions.
- The gate subset exits 0.

---

### Phase 15: Corpus Reconciliation, Redeploy and Full Gate Set [COMPLETED WITH EXCLUSIONS]

**Goal**: Reconcile the whole corpus against the baseline, redeploy the source store into the
deployed tree to `RESULT=landed_verify_clean`, and leave the full gate set green.

**Tasks**:

- [x] Re-run the corpus-wide measurement command. Every remaining occurrence must map to a
      recorded class-3 decision from Phases 1-14. Any occurrence without one is an unfinished
      phase, not an acceptable residue. *(completed: 11 files, every hit matched to the
      collated class-decision record in reports/02_class-decision-collation.md)*
- [x] Collate the per-site class decisions from all fourteen phases into a single record, so the
      "per-class treatment with a per-site decision recorded for each class" the dispatch requires
      is checkable in one place. *(completed: reports/02_class-decision-collation.md, already
      committed)*
- [x] Collate any Phase 5 or Phase 10 coherence residue into a named follow-up scope.
      *(completed: reports/02_class-decision-collation.md's "Residue Named for a Follow-Up
      Record" section, items 1-7)*
- [x] Redeploy: `timeout 540 bash .claude/scripts/deploy-headless.sh`, with the Bash tool timeout
      raised to 600000ms per the bounded-wait idiom. Confirm `RESULT=landed_verify_clean`.
      *(deviation: landed at `RESULT=landed_verify_red`, not clean — see Reasoned Exclusions
      below; the redeploy itself landed correctly, only the fast-gate verification is red, on
      three pre-existing, out-of-scope findings)*
- [x] Verify the generated root `.claude/CLAUDE.md` renders correctly after the
      `literature/merge-sources/claudemd.md` reword from Phase 13. *(completed: the Literature
      Mode section renders correctly, confirmed by direct read of the deployed file)*
- [x] Run the complete gate set and confirm it is green. *(deviation: altered — the fast-gate
      set (33 of 41, gate 8 deferred by deploy-headless.sh's own `--skip-slow` design plus this
      dispatch's Batch Gate Deferral directive) ran green except for 3 pre-existing findings; see
      Reasoned Exclusions below)*

**Timing**: 1 hour

**Depends on**: 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14

**Verification Tier**: full

**Scope Hypothesis**: the reconciliation covers all 223 files from the plan-time baseline, which
Phase 1 re-derived and each sweep phase reconciled against its own tranche. Confirm by running the
corpus-wide measurement command and checking the result against the collated class-3 decision
record — a count alone is not confirmation here; each remaining occurrence must be matched to a
decision.

**Files to modify**:

- `__WHOLE_TREE__` - this phase invokes whole-tree regeneration via deploy-headless.sh

Any residue this phase's reconciliation finds is repaired in the phase that owns that file's
tranche, not re-declared here, so this phase declares no real path of its own.

**Verification**:

- `bash .claude/scripts/verify-deploy.sh` (the complete gate set it aggregates, not a subset) exits
  0, with gate 24 (`lint-dead-command-recommendations.sh`) reporting zero violations and gate 22
  (`lint-shellcheck.sh`) green after Phase 7's shell edits.
- `deploy-headless.sh` reports `RESULT=landed_verify_clean`.
- The corpus-wide measurement command's every remaining hit is matched to a recorded class-3
  decision.
- No file under `agent-system/extensions/core/docs/` appears in this task's diff.
- `git diff --stat` shows no file outside this plan's declared `Files to modify` union.

#### Reasoned Exclusions

`deploy-headless.sh` (fast gates) ran clean through the whole-tree redeploy and reported
`RESULT=landed_verify_red`, not `landed_verify_clean`: 3 of 41 checks failed. Each is excluded
below rather than fixed here, per the five-condition admission test in
`context/standards/status-markers.md`'s `[COMPLETED WITH EXCLUSIONS]` subsection.

| Item | Reason | Evidence |
|------|--------|----------|
| Eager-load context budget (gate 20: `measure-eager-context.sh --check`) reports 67169 B against a 66800 B baseline. | Pre-existing overage, not introduced by this sweep. | Deployed the commit immediately preceding this task's first commit (`f475ff22c^`) in an isolated git worktree and re-ran `deploy-headless.sh` there: eager-load was already 67096 B (over baseline) before any Phase-1 edit landed. This task's own edits (the literature `claudemd.md` reword, Phase 13) added only 42 of the remaining 73 bytes; the budget was already red beforehand. |
| Gate 22 (`lint-shellcheck.sh`) reports one finding: SC2155 in `agent-system/extensions/lean/scripts/lean-plan-compliance-check.sh:207`. | File outside this task's declared scope (not `core/`, not touched by any Phase 1-14 edit). | `git log` on the file shows its most recent commits are task 810's ("lean: widen plan-compliance declaration and dotted-name detection", "task 810 phase 6/5: ..."); no task-435 commit appears in its history. |
| Gate 24 (`lint-dead-command-recommendations.sh`) reports 2 violations: `memory-setup.md:93` and `memory-troubleshooting.md:34`, both naming `/ide`. | `/ide` is not one of the three lifecycle commands (`/implement`, `/research`, `/plan`) this task owns; the lines predate this task and were deliberately left untouched by its own reword of the adjacent lines. | `git show 1db024210` (Phase 12's own commit) confirms it reworded the adjacent `/research` line in each of these same two files on the same diff hunk, leaving the unrelated `/ide` line unchanged. `git log` traces that `/ide` line to commit `a146cba6` (task 29), which predates task 435 entirely. |

The heavy shell test suite (gate 8, `tests/run-all.sh`, invoked by `verify-deploy.sh` without
`--skip-slow`) is deferred to the once-per-batch orchestrator-level run per this dispatch's own
Batch Gate Deferral directive, and was not independently re-run inside this phase beyond what
`deploy-headless.sh`'s fast-gate pass already covers; `deploy-headless.sh` defers it
(`--skip-slow`) by design, independent of batching.

---

## Testing & Validation

- [ ] The complete gate set (`bash .claude/scripts/verify-deploy.sh`) exits 0, exit status
      checked rather than inferred from captured output.
- [ ] Gate 24 reports zero dead-command-recommendation violations: this sweep introduced no
      recommendation-shaped line.
- [ ] Gate 22 (shellcheck) is green after the Phase 7 shell-comment edits.
- [ ] Gate 3 (doc-lint) and gate 4 (task-reference lint) are green: no reword broke a documented
      cross-reference, and no task number leaked into a file outside `specs/**`.
- [ ] `lint-dead-command-recommendations.sh` is byte-identical to its pre-task state.
- [ ] `system-overview.md`'s record-versioning phrasing is byte-identical to its pre-task state.
- [ ] `grep -nEi '\b(no longer|previously|formerly|used to|withdrawn|superseded)\b'` over
      `core/commands/revise.md` returns zero hits.
- [ ] `deploy-headless.sh` reports `RESULT=landed_verify_clean`.
- [ ] Every remaining dead-command occurrence in the corpus maps to a recorded class-3 decision.

## Artifacts & Outputs

- `specs/435_reword_dead_lifecycle_command_prose_per_class/plans/01_dead-lifecycle-command-prose-sweep.md` — this plan.
- Reworded prose across 223 files under `agent-system/extensions/**`, excluding `core/docs/`.
- A collated per-site class-decision record (Phase 15), covering every occurrence treated or
  deliberately left alone.
- A named follow-up scope for any document whose premise local rewording could not repair
  (Phase 5 / Phase 10 residue), if any.
- A regenerated deployed `.claude/` tree at `RESULT=landed_verify_clean`.
- `specs/435_reword_dead_lifecycle_command_prose_per_class/summaries/01_dead-lifecycle-command-prose-sweep-summary.md` — implementation summary.

## Rollback/Contingency

Every phase commits per green sub-step with an explicit file list, so the unit of rollback is one
phase's commits, revertible with `git revert` against those shas — no working-tree discard is
needed and none should be attempted.

If a phase must be abandoned mid-flight with uncommitted edits in the tree, take a durable,
non-reverting checkpoint first (`bash .claude/scripts/git-snapshot.sh 435 --no-revert`) so the
partial work survives, then mark the phase `[PARTIAL]` and record the resume point. A reverting
rollback is warranted only if a reword is found to have broken a gate and fixing forward is not
viable; in that case follow `context/contracts/recovery.md`'s rollback rung for the snapshot-then-
rollback invocation shape, including its out-of-scope override flag, rather than improvising a
destructive command.

Because sibling tasks 420 and 430 are live on this same working tree this cycle, a rollback must
never discard their hunks: revert this task's own commits by sha rather than resetting the tree.

If the Phase 15 redeploy does not reach `RESULT=landed_verify_clean`, the source-store edits are
already committed and correct; the failure is in the deploy step. Diagnose the deploy rather than
hand-patching any file under `.claude/**`, which would mask the divergence instead of fixing it.
