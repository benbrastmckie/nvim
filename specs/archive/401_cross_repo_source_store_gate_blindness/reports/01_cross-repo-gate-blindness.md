# Research Report: Task 401

**Task**: 401 - Cross-repo source store gate blindness
**Started**: 2026-11-05T22:49:00-08:00
**Completed**: 2026-11-05T23:40:00-08:00
**Effort**: Research only (evidence verification + escalation framing; no mechanism design)
**Dependencies**: Task 387 (whole_tree_regeneration_scope_claim) — verified COMPLETED, no blocker
**Sources/Inputs**:
- Git history of this repository (commits f49576632, 4311617a2, 9a43026d2, aac4a8c6a, 2e0a82a53, and the task-275 archival diff)
- `specs/state.json` (tasks 398, 399, 390, 391 live descriptions)
- Archived task-275 artifacts recovered via `git show aac4a8c6a^:specs/275_.../...`
- `agent-system/extensions/core/context/patterns/file-footprint-overlap.md` (current Non-Goals section)
- `agent-system/extensions/core/scripts/orchestrate-predispatch-review.sh` (header comments + `STATE_FILE` resolution)
- `agent-system/extensions/lean/index-entries.json` and the five files it indexes (measured line counts)
- `~/.config/nvim/.claude-extensions.json` (`source_dir` resolution for core/lean)
**Artifacts**: `specs/401_cross_repo_source_store_gate_blindness/reports/01_cross-repo-gate-blindness.md` (this report)
**Standards**: report-format.md, subagent-return.md, user-decision-contract.md

## Executive Summary

- The counterexample the dispatch names is verified in full: commits f49576632 and 4311617a2 exist
  exactly as described; tasks 398 and 399 cite the identical four issue-log entry ids, with
  file_scope overlapping f49576632's edits exactly as claimed.
- `orchestrate-predispatch-review.sh` reads **only** `$PROJECT_ROOT/specs/state.json` (one repo's
  state file, resolved via `common_repo_root`), and `file-footprint-overlap.md` defines the overlap
  predicate with no cross-repo concept anywhere in it. The blindness is architectural, not a bug in
  either file — confirmed by reading both rather than inferring it.
- Task 275's "SCOPE — RULED: PER-REPO" paragraph is no longer `[RESEARCHING]` — it reached
  `[COMPLETED]` on 2026-11-04/05, in parallel with this escalation. Its archived plan and summary
  (recovered from git history) explicitly consulted this task and declined to amend the ruling,
  implementing the per-repo queue as written and deferring the actual decision here. **The
  escalation is still live**, but any eventual amendment note can no longer land in task 275's own
  record (its files were deleted on archival) — it has to land in the durable artifact that now
  carries the ruling's substance, `task-lock.md`'s Orchestration-Queue CLI section.
- Two of the dispatch's "what remains outstanding" premises are now stale: the
  `index-entries.json` leg that 398 and 399 believe they still owe was silently repaired by a
  **third**, same-repo, record-less channel (a) dispatch (commit 9a43026d2, 2026-10-16) three days
  after the original incident — again invisible to any gate, again inside 398/399's own declared
  territory while both sat `[NOT STARTED]`. This is additional, independent corroboration of the
  same blind spot, not a duplicate of the cross-repo incident.
- This record routes the scope question to the user rather than deciding it (see `user_decision`
  in `.return-meta.json`). No mechanism is designed here, per the dispatch's explicit instruction.

## Context & Scope

This is a research-phase dispatch whose primary deliverable is an adjudicated decision, not a
mechanism (per the dispatch's own framing). The work here is: (1) verify the measured counterexample
with independent evidence, (2) confirm the current state of task 275's ruling and whether it has
already foreclosed the question, (3) confirm the gate's actual blindness mechanically rather than by
assertion, and (4) frame the owner's decision as a `user_decision` so the orchestrator relays it at
the next natural stopping point — never deciding the per-repo-vs-cross-repo policy question myself.

No source-store file was edited in this dispatch. The conditional file_scope items
(`scripts/lib/file-scope-overlap.sh`, `skills/skill-orchestrate/SKILL.md`, `scripts/task-lock.sh`,
`scripts/orchestrate-batch-admit.sh`) were correctly left untouched — they apply only if the
escalation's answer requires a mechanism, which is not yet known.

## Findings

### The counterexample, independently re-verified

- `git cat-file -e f49576632` and `git cat-file -e 4311617a2` both resolve; `git log --oneline`
  shows their exact subjects: "lean: record four Lean 4 measurement and syntax gotchas" and "meta:
  note the landed gotcha records against their source-store commit", matching the dispatch verbatim.
- Task 398's live description cites `iss_1791921588196_IcZKne` and declares file_scope including
  `context/project/lean4/patterns/dependency-tracing.md`. Task 399's live description cites
  `iss_1791886589088_do8mDR`, `iss_1791914943297_AoBxvm`, `iss_1791928136829_T0iDVg` and declares
  file_scope including `context/project/lean4/domain/lean4-syntax.md`. Both already carry an
  "ALREADY LANDED IN THE SOURCE STORE" appendix (dated 2026-10-13) naming f49576632 and
  4311617a2 — the annotation the dispatch describes is present and accurate.
- Both tasks remain `[NOT STARTED]` in `specs/state.json` today (2026-11-05), unchanged since the
  incident.

### The gate's blindness is structural, confirmed by reading the code, not inferred

- `agent-system/extensions/core/scripts/orchestrate-predispatch-review.sh` header (line 5): "reads
  `specs/state.json` directly — the only place raw, unfiltered `dependencies[]`..."; line 169:
  `STATE_FILE="$PROJECT_ROOT/specs/state.json"`, with `PROJECT_ROOT` resolved via
  `common_repo_root` — i.e. exactly one repository's state file, every time.
- `agent-system/extensions/core/context/patterns/file-footprint-overlap.md`'s `## Non-Goals`
  section (lines 263+) enumerates four things the overlap predicate deliberately does not do (no
  glob matching outside Containment, no filesystem validation, no opinion on scan scope) — it names
  four distinct same-repo scan-scope shapes (task/phase-level, lock-acquisition-level,
  batch-admission-level, session-registry-level) but has no fifth entry addressing cross-repository
  scope at all. The gap named in the dispatch is real and is exactly where a future author would
  look.
- Together these confirm the dispatch's claim without needing to trust it: every consumer of the
  overlap predicate is wired to one repository's `specs/state.json`, and the predicate's own
  contract document has nothing to say about a second repository sharing the same source-store file
  tree.

### Task 275's ruling has reached a terminal state, but the escalation remains live

- `specs/state.json` and `specs/CHANGE_LOG.md` confirm task 275 (`per_repo_orchestration_queue`)
  is `[COMPLETED]`, archived in commit `aac4a8c6a` ("todo: archive 44 completed tasks") on
  2026-11-05, immediately preceding this dispatch.
- Recovering task 275's description from the pre-archival state (`git show aac4a8c6a^:specs/state.json`)
  confirms the "SCOPE — RULED: PER-REPO" paragraph quoted in the 401 dispatch verbatim:

  > "SCOPE -- RULED: PER-REPO. One queue per repository, living beside the existing session
  > registry. No cross-repo global queue and no global-ready schema requirement: file_scope
  > conflicts are inherently per-repo, so a global queue would carry no information the per-repo
  > one lacks."

  The same recovered description also carries a "CROSS-REPO COUNTEREXAMPLE TO THE PER-REPO SCOPE
  RULING — ESCALATION PENDING (2026-10-13)" section appended after the original ruling, explicitly
  naming task 401 and instructing: "Consult it before concluding this record's research, and if the
  ruling is amended, the amendment belongs in this record as a dated amendment note."
- Task 275's archived **plan** (`plans/01_per-repo-orchestration-queue.md`, recovered via
  `git show aac4a8c6a^:...`) contains a "### Cross-Repo Counterexample — Not Re-Opened Here"
  section: "...this plan implements the per-repo ruling as written and adds no cross-repo
  mechanism. If the ruling is amended, the amendment belongs in the task record as a dated note..."
- Task 275's archived **summary** states: "A measured cross-repo counterexample to the per-repo
  scope ruling remains tracked in a separate record that owns running the scope question to an
  owner decision; no amendment was made here."
- **Consequence**: task 275 reached `[COMPLETED]` without the escalation ever being answered, and
  its files are now deleted from the live tree (only the CHANGE_LOG.md digest survives). The
  question this record exists to run to an answer is still genuinely open — 275 did not pre-empt
  it — but the place named in 275's own text for an eventual amendment note ("the task record") no
  longer exists as an editable artifact. The durable artifact that now carries the ruling's
  substance is `agent-system/extensions/core/context/patterns/task-lock.md`'s Orchestration-Queue
  CLI section (added by 275's implementation) — that is where a future amendment note belongs, not
  a resurrected task-275 file.

### Two "what remains outstanding" premises in 398/399 are now stale

- Both tasks' descriptions (dated 2026-10-13) state the `agent-system/extensions/lean/index-entries.json`
  leg "was NOT updated" and (for 399) that README.md's recorded `line_count` is stale (31 vs.
  actual 32). Measured today: **false**. `git log -p -- agent-system/extensions/lean/index-entries.json`
  shows a third dispatch, commit `9a43026d2` ("orchestrate conclusion: channel (a) direct fixes",
  2026-10-16), silently repaired this — `README.md` now reads 32 lines and `index-entries.json`
  records `line_count: 32` for it; independently re-measured `wc -l` against all five files touched
  by f49576632 (`dependency-tracing.md`, `lean4-syntax.md`, `tactic-patterns.md`, `README.md`,
  `measurement-harness-strictness.md`) and all five now match their recorded `line_count` exactly.
  The `measurement-harness-strictness.md` index entry is complete (`load_when`, `domain`,
  `subdomain`, `summary`, `keywords` all present).
- This is **not** a repeat of the cross-repo incident — commit 9a43026d2 is a same-repo
  conclusion-stage channel (a) dispatch (it also touched
  `agent-system/extensions/core/config/orchestrator-context-budget.json` and
  `agent-system/extensions/core/rules/git-workflow.md`, both core-extension files unrelated to
  BimodalLogic). It is, however, a **third independent instance** of the identical blind-spot
  shape named in the dispatch's "harder half": a dispatch with no task record of its own, editing
  territory two `[NOT STARTED]` task records (398, 399) believe they still own, invisible to any
  gate because neither gate nor dependency graph is keyed on anything such a dispatch carries.
  This strengthens rather than weakens the case for the escalation: the record-less channel is not
  a one-off, it is a recurring pattern that has now independently duplicated or pre-empted the same
  two task records' work at least three separate times (the original four-note landing, this
  index-entries.json repair, and — per 398's own appendix — the dependency-tracing.md section
  itself).
- **Out of scope for this record** (per the dispatch's "NOT IN SCOPE" section): repairing 398's or
  399's data, or correcting their descriptions. Noted here as evidence only; 398 and 399's own
  researchers should re-verify this when those tasks are picked up, since their "what remains
  outstanding" sections currently understate how much is already done.

### Delimitation from adjacent records — confirmed, not assumed

- Tasks 390 and 391 are both `[NOT STARTED]` in `specs/state.json`. Task 390's live description
  confirms it is the seven-record BimodalLogic→here migration manifest the 401 dispatch describes
  (explicit "SOURCE STORE IS THE EDIT TARGET... Move seven task records out of
  ~/Projects/BimodalLogic/specs/..." framing, with per-item citations matching the dispatch's
  description of 390's content). `~/Projects/BimodalLogic` exists and is reachable from this
  machine, but re-verifying the specific drifting counts (BimodalLogic #768's current title/length,
  #772/#774/#778/#783) is explicitly task 390's own job, not 401's — the dispatch's "NOT IN SCOPE"
  section excludes migration from this record, and 390's description already instructs its own
  future reader to re-verify rather than trust the recorded counts. Not re-derived here to stay
  inside this record's scope.
- Nothing in 390's or 391's current text overlaps 401's thesis (siting/migration vs. two
  correctly-sited actors colliding) — the delimitation in the dispatch holds on inspection.

## Decisions

- No cross-repo gate, global queue, or global-ready schema was designed in this dispatch, per the
  dispatch's explicit instruction to route the scope question rather than decide it.
- No file under `agent-system/**` was edited in this research phase. The Non-Goals addition to
  `file-footprint-overlap.md` is deferred to the plan phase, once the owner's answer is known (see
  Recommendations below for the two candidate text blocks to choose between).
- The amendment note for task 275's ruling, if the owner amends it, is directed at
  `task-lock.md`'s Orchestration-Queue CLI section rather than at task 275's own (now-deleted)
  record — a routing decision made here because 275's archival makes its originally-named target
  unreachable, not a decision about the ruling's substance itself.
- `user_decision` is set on `.return-meta.json` (see below) with `blocking: false`: this is a
  forward-looking policy question, fully reversible (a documentation choice, not a destructive or
  costly action), so the loop proceeds on the recommended option and the question surfaces for the
  user's review at the next natural stopping point rather than halting here.

## Recommendations

1. **Plan phase**: once the owner's answer lands, add a fifth bullet to
   `file-footprint-overlap.md`'s `## Non-Goals` section stating the cross-repo limitation. Two
   candidate texts, one per possible answer:
   - If the per-repo ruling stands: "No cross-repository scope: when two repositories' task spaces
     file work against one shared source store (see `rules/source-store-deploy-boundary.md`), this
     predicate and every consumer wired to it see only the invoking repository's own
     `specs/state.json` — a correctly-sited actor in each repository can claim the same
     source-store file with no edge and no overlap finding anywhere. Accepted risk, detected
     manually; see [the durable record of this ruling] for the adjudication."
   - If the ruling is amended toward some cross-repo mechanism: state what the mechanism covers and,
     explicitly, what it does **not** cover — specifically, a channel (a) conclusion-stage dispatch
     that writes to shared source-store territory with no task record of its own in either repo
     (the case this record's evidence shows recurring at least three times). A mechanism keyed on
     task records or `dependencies[]` cannot see that case by construction; say so rather than
     implying coverage it does not have.
2. **Plan phase**: direct the eventual amendment note (if any) at `task-lock.md`'s
   Orchestration-Queue CLI section, not at a resurrected task-275 file — see Findings above for why.
3. **Follow-up, not this record**: 398 and 399 should re-verify their "what remains outstanding"
   sections before being planned — the index-entries.json leg they believe is owed is already done.
4. **Follow-up, not this record**: the recurring record-less channel (a) pattern (three instances
   now measured against the same two-task territory) may itself warrant a separate record if the
   owner's answer to this escalation does not already address it — but that record, like a
   cross-repo mechanism, should wait on this escalation's answer rather than being proposed
   unilaterally here.

## Risks & Mitigations

- **Risk**: the owner's answer arrives after further channel (a) activity lands in the same
  territory, compounding the duplication this record already measured three times over.
  **Mitigation**: none available at research time beyond surfacing the question promptly — this
  record is already doing that via the non-blocking `user_decision`.
- **Risk**: a future reader treats task 275's `[COMPLETED]` status as having settled the cross-repo
  question by default (since it shipped the per-repo queue without amendment). **Mitigation**:
  this report and the `user_decision` payload state explicitly that 275 deferred rather than
  settled the question — the ruling's text was implemented as-is, not re-examined.

## Context Extension Recommendations

- **Topic**: cross-repository source-store coordination.
- **Gap**: no context file anywhere in `agent-system/extensions/core/context/` currently documents
  that multiple repositories can share one source store (only
  `rules/source-store-deploy-boundary.md` documents the deploy-target relationship itself, from a
  single repository's perspective).
- **Recommendation**: whichever way the escalation resolves, the chosen Non-Goals text (see
  Recommendations §1) is the right place to record this — no new standalone context file is
  warranted for a single documented limitation.

## Appendix

- Verified commits: `f49576632`, `4311617a2`, `9a43026d2`, `aac4a8c6a`, `2e0a82a53`.
- Issue-log entries verified present in task 398/399 descriptions: `iss_1791886589088_do8mDR`,
  `iss_1791914943297_AoBxvm`, `iss_1791928136829_T0iDVg`, `iss_1791921588196_IcZKne`.
- `agent-system/extensions/lean/index-entries.json` line_count cross-check (measured 2026-11-05):
  `dependency-tracing.md` 229/229, `lean4-syntax.md` 153/153, `tactic-patterns.md` 159/159,
  `README.md` 32/32, `measurement-harness-strictness.md` 50/50 (recorded/actual, all consistent).
- Commands used: `git log`, `git show <rev>:<path>`, `git cat-file -e`, `jq`, `wc -l`, `grep -n`.
