# Research Report: Task #395

**Task**: 395 - Surface failed per-cycle scoped commit into the DISPATCHED TASK's own status
**Started**: 2026-10-16
**Completed**: 2026-10-16
**Effort**: medium
**Dependencies**: None (verified against the live, contended `orchestrate-cycle-postflight.sh`;
six-plus sibling tasks are concurrently editing this file per the dispatch's Territory block)
**Sources/Inputs**:
- Codebase: `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` (source-store
  copy; verified byte-identical to the deployed `.claude/scripts/` copy at research time)
- `agent-system/extensions/core/scripts/skill-base.sh` (`skill_postflight_update`,
  `skill_preflight_update`)
- `agent-system/extensions/core/scripts/update-task-status.sh` (`map_status`, write guards)
- `agent-system/extensions/core/scripts/lib/status-vocabulary.sh` (monotonic-max clamp primitive)
- `agent-system/extensions/core/scripts/orchestrate-triage-classify.sh` (next-cycle routing of a
  `partial` status)
- `agent-system/extensions/core/context/standards/git-staging-scope.md` (git-commit-scoped.sh
  exit-code table, V2/V3/V5/V6/V8/V9 semantics)
- `agent-system/extensions/core/context/standards/status-markers.md`
- `agent-system/extensions/core/docs/architecture/handoff-schema.md`
**Artifacts**:
- This report: `specs/395_surface_failed_per_cycle_commit_into_task_status/reports/01_commit-failure-status-surfacing.md`
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The gap is real and precisely as scoped: `orchestrate-cycle-postflight.sh`'s WORK (f) writes
  `state.json` status to `completed` (for an `implemented` dispatch with the completion-claim
  gate passed) hundreds of lines before WORK (i) attempts this cycle's scoped commit; a loud
  commit failure there today produces an `ERROR` line, an `issue-record.sh` entry, and the
  emitted JSON's `note` field — but `state.json` is left at `completed` even though the task's
  own deliverable changes may be sitting uncommitted on disk.
- The "monotonic-max machinery... prevents a later demotion by construction" reasoning recorded
  by task 304 does **not** hold as a mechanical fact once re-checked against the current code:
  the clamp is opt-in (`status_clamp_mode == "monotonic-max"`, itself only set when
  `force_invoked == "true"`), `update-task-status.sh` has no terminal-state guard on `postflight`
  writes (only `skill_preflight_update` blocks terminal states, and only for `preflight` calls),
  and even if the clamp *were* applied to a demotion write, `partial` is deliberately **unranked**
  in `STATUS_VOCABULARY_LIFECYCLE_RANK` (`scripts/lib/status-vocabulary.sh`), so
  `status_vocabulary_would_regress(completed, partial)` returns false (no regression — the clamp
  would not fire). The real reason this was deferred is that a demotion write did not exist yet,
  not that one is structurally impossible. This is a correction to task 304's recorded reasoning,
  not a formal claim refutation (no `claim_invalidations` entry is warranted — see below).
- `git-commit-scoped.sh` exit code `6` (V9) is **not** a genuine commit-landing failure: per
  `context/standards/git-staging-scope.md`'s own table, exit 6 means "a commit WAS created... and
  one or more positive pathspecs were dropped as out-of-repository... the valid paths already
  committed successfully." WORK (i)'s current `2|3|4|5|6)` case arm groups it with the genuine
  non-landing codes (2/3/4/5) for the ERROR/issue-record treatment. A status demotion must not
  reuse that same grouping verbatim — demoting `completed` to `partial` for an exit-6 cycle would
  punish a task whose own content landed fine.
- The architecture already has the exact hook needed: `persisted_status` (the final emitted
  JSON's field) is read **fresh from `state.json` at emit time**, hundreds of lines after WORK
  (i), and is documented as legitimately diverging from `status` (the dispatch's self-report) "by
  design." A WORK (i) demotion write to `state.json` requires **no** change to the
  `persisted_status` read-back logic — it already reflects whatever WORK (i) leaves on disk.
- Recommendation: **Option (b)**, a narrowly-scoped corrective write inside WORK (i)'s existing
  `2|3|4|5)` branch (excluding 6), gated to fire only when this cycle's WORK (f) write actually
  landed `completed` for an `implement`-phase dispatch. Option (a) (reordering) is mechanically
  much larger than it first appears — it would require splitting the single per-cycle commit into
  two (task files first, then state.json/TODO.md), which conflicts with this codebase's "one
  commit per cycle" convention used elsewhere (git-workflow.md, dispatch-metrics.sh's per-commit
  accounting) and is correctly characterized by task 304 as "a larger design change."

## Context & Scope

Task 304 added `git-commit-scoped.sh`'s exit-code branch at WORK (i) (the per-task scoped commit
call site in `orchestrate-cycle-postflight.sh`), an attributable `ERROR` on stderr, an
`issue-record.sh` entry, and a `note` field on the emitted verdict JSON — but explicitly left
`verdict`, `halt`, `infra_exempt_cycle`, and every `state.json` status write untouched, recording
the reason as a hard constraint it deliberately scoped out. Task 395 asks this research to
re-verify that reasoning against the current (contended, frequently-edited) file structure and
recommend a path to actually close the gap: a genuinely failed per-cycle commit for an
`implement`-phase dispatch must leave the task at `[PARTIAL]`, never `[COMPLETED]`.

This research re-read the live file end to end (WORK (a) through WORK (n), ~2288 lines),
traced the status-write call graph (`orchestrate-cycle-postflight.sh` -> `skill-base.sh`'s
`skill_postflight_update` -> `update-task-status.sh`), traced the monotonic-max clamp primitive
(`scripts/lib/status-vocabulary.sh`), traced how a `partial` status is consumed one cycle later
(`orchestrate-triage-classify.sh`), and checked the precise semantics of each
`git-commit-scoped.sh` exit code against its own documented contract
(`context/standards/git-staging-scope.md`).

## Findings

### Codebase Patterns

**WORK (f) status transition (current ~line 1144-1517).** For `dispatch_status == "implemented"`,
`skill_gate_completion_claim` is evaluated; on pass, and when neither
`deploy_pending_refusal` nor `derived_staleness_refusal` is set, `skill_postflight_update
"$task_number" "implement" "$session_id" "$dispatch_status" ... "$clamp_mode"` is called
(~line 1323), which calls `update-task-status.sh postflight "$task_number" "implement"
"$session_id"` and writes `state.json` status to `completed` (`map_status`'s
`postflight:implement` arm). `clamp_mode` is `"monotonic-max"` only when `force_invoked ==
"true"` (an explicit `/orchestrate --implement` forcing flag), empty otherwise — i.e. on an
*ordinary* (non-forced) cycle, the monotonic-max clamp is never even consulted for this write.

**WORK (i) per-task scoped commit (current ~line 1832-1965).** Runs `git-commit-scoped.sh`,
captures `commit_rc`, and classifies it:
- `0`: clean commit, no action.
- `1`: "nothing to commit" — benign, non-blocking by design (unchanged).
- `2|3|4|5|6`: a named `ERROR` to stderr, an `issue-record.sh` entry (class "orchestration
  defect", severity `costly`), and `commit_attribution_note` populated for the emitted JSON's
  `note` field. **No status write, no `verdict`/`halt`/`infra_exempt_cycle` change** — the block's
  own comment states this is deliberate and names it a residual follow-up.
- unrecognized future code: same ERROR treatment as 2-6, no issue-record call.

**The monotonic-max clamp is opt-in and would not block a demotion anyway.**
`skill_postflight_update`'s 7th positional argument `status_clamp_mode` defaults to empty;
clamp logic only runs when it equals `"monotonic-max"` (`skill-base.sh` ~line 972). The clamp
calls `status_vocabulary_would_regress "$_clamp_current_status" "$status"`
(`scripts/lib/status-vocabulary.sh`), which only returns true (regression, write skipped) when
**both** the current and target status are members of `STATUS_VOCABULARY_LIFECYCLE_RANK`. That
rank table contains exactly 8 of the 13 enum values (`not_started` through `completed`);
`partial`, `blocked`, `abandoned`, `expanded`, and `hold` are all deliberately *unranked* — the
file's own header comment states "`blocked`, `partial`, `abandoned`, and `expanded` are
deliberately OMITTED." `status_vocabulary_would_regress`'s own doc states it "Returns 1 (no
regression...) in every other case, including when either side is unranked." So
`status_vocabulary_would_regress(completed, partial)` is **false** — even a clamp-protected write
to `partial` is never blocked by this mechanism. Separately, `update-task-status.sh` itself has
*no* terminal-state check at all on `postflight` writes (`map_status`'s
`postflight:partial`/`postflight:blocked` arms are unconditional); the only terminal-state guard
in the codebase lives in `skill_preflight_update` (skill-base.sh ~line 382), gating the *start* of
a fresh dispatch against a terminal task, which is an unrelated call path.

**Existing, already-exercised precedent for exactly this call shape.** WORK (f)'s own `partial)`
dispatch-status arm (current ~line 1397-1416) already calls `skill_postflight_update
"$task_number" "implement" "$session_id" "partial" "" "$TASK_DIR" "$clamp_mode"` when a handoff
carries a non-empty `blockers[]`. Inside `skill_postflight_update`, `$status == "partial"` falls
through the main `researched|planned|implemented)` arm into skill-base.sh's dedicated `partial)`
case (~line 1038-1047), which calls `update-task-status.sh postflight "$task_number" partial
"$session_id"` — note the literal `partial` token, independent of the `$operation` ("implement")
argument. That comment explicitly states: "Caller gates this arm on a non-empty handoff
blockers[] -- see orchestrate-cycle-postflight.sh's `partial)` arm." This is the exact mechanism
task 395 needs, already proven in production for the *agent-reported* partial case; the new work
is reusing it for a *postflight-synthesized* partial case.

**`persisted_status` already decouples the emitted JSON from the in-flight write decision.**
Current ~line 2181-2194, positioned after WORK (i), WORK (j)/(k)/(m)/(n): `persisted_status=$(jq
-r ... .status ... "$STATE_FILE")` — read fresh from `state.json` at the very end of the script,
independent of whether *this* cycle performed a transition. The script's own header comment (line
199-210) documents: "`status` = the dispatch's own self-reported outcome... may legitimately
differ from `persisted_status` by design." A WORK (i) demotion write therefore requires **no**
separate wiring to correct the emitted JSON — `persisted_status` already reflects it for free.

**`verdict` resolution precedent for "self-report says completed but it didn't land."**
Current ~line 1639-1652: for `dispatch_status == "implemented"`, `verdict` is `"ok"` only when
`implemented_gate_passed == true` **and** `deploy_pending_refusal != true` **and**
`derived_staleness_refusal != true`; otherwise `verdict = "defer"` ("in-flight, retry the SAME
phase next cycle"). These two existing refusal flags are both detected and consulted **before**
WORK (f)'s write — i.e. they prevent the `completed` write from ever landing in the first place.
A commit-landing failure is structurally different: it is discovered **after** the write already
landed, so closing this gap requires an actual demotion (undo), not merely skipping a write
that hasn't happened yet. This is the concrete reason task 304 characterized full closure as
"requiring either reordering WORK (f)/(i) or a sanctioned write out of a terminal `completed`
state" — both options are genuinely necessary; there is no third way to avoid the asymmetry.

**Exit-code semantics are NOT uniform across 2/3/4/5/6.** From
`context/standards/git-staging-scope.md`'s exit-code table:
| Code | Meaning | Did the task's own content land? |
|------|---------|-----------------------------------|
| 2 | V3/usage/add-failure | No — no commit created. |
| 3 | V5 contended-path refusal | No — refused before any `git add`. |
| 4 | V6 all-dropped-and-nothing-committed | No — no commit created. |
| 5 | V8 post-commit integrity mismatch | **Ambiguous/partial** — a commit exists, but a named intended pathspec did not land in HEAD. |
| 6 | V9 out-of-repository drop | **Yes** — "the valid paths already committed successfully"; only a stray, invalid pathspec was dropped. Documented as "Observability, not a refusal." |

WORK (i)'s current `2|3|4|5|6)` grouping treats exit 6 identically to the four genuine failures
for the ERROR/issue-record treatment. That grouping is arguably already slightly loose for the
*existing* non-status-changing behavior, but it becomes actively harmful if reused verbatim as
the trigger set for a **status demotion**: a task whose commit succeeded (6) would be wrongly
knocked back to `[PARTIAL]`.

**What a `partial` demotion must additionally populate for correct next-cycle routing.**
`orchestrate-triage-classify.sh` (current ~line 48-89) reads, for every `status == "partial"`
candidate, that task's own `.orchestrator-handoff.json` `blockers[]` and `continuation_path`:
- `partial` + continuation pointer -> routes to `implement` (re-dispatch).
- `partial` + non-empty `blockers[]`, no continuation -> routes to `needs_human`.
- `partial` + neither -> routes to `implement` (re-dispatch) — this is the documented
  "ordinary in-progress partial... routes to implement" default.

A bare `state.json` demotion to `partial` with **no corresponding handoff correction** would hit
the third row: the next `/orchestrate` cycle would re-dispatch a full `implement` phase for a task
whose plan file already shows every phase `[COMPLETED]` — wasted work at best, confusing
re-entry at worst. The demotion must therefore also leave a `blockers[]` entry (and no
`continuation_path`) in `.orchestrator-handoff.json` describing the commit failure, so the next
cycle lands on the `needs_human` row instead — the correct outcome for "the work is done, the
commit mechanism needs a human or a retry, not a redo." `.orchestrator-handoff.json` is git-
tracked, already inside WORK (i)'s own `stage_paths` (via `"${TASK_DIR}/"`), and persists on disk
indefinitely between dispatches (nothing in this script deletes or archives the per-task handoff
after reading it) — it is the correct, already-wired artifact to amend in place.

### External Resources

No external (web) research was needed — this is an internal orchestration-engine question fully
resolved by reading the live codebase and its own context documentation.

## Recommendations

**Adopt Option (b): a narrowly-scoped corrective write inside WORK (i), not Option (a)
reordering.**

1. **Scope the trigger precisely.** Fire the new logic only when, in *this* cycle: (i)
   `dispatch_status == "implemented"`, (ii) `implemented_gate_passed == "true"`, (iii)
   `deploy_pending_refusal != "true"`, (iv) `derived_staleness_refusal != "true"` — i.e. exactly
   the condition under which WORK (f) already wrote `state.json` status to `completed` this
   cycle (mirrors `verdict == "ok"` for the implement case). Do not extend this to
   `researched`/`planned` dispatch outcomes: those statuses are non-terminal under
   `state-management.md`'s permissive model, so a later cycle can already naturally retry/recover
   them without a demotion; only `completed` is the terminal state the task's HARD CONSTRAINT
   language is actually about.

2. **Narrow the exit-code trigger set to `{2,3,4,5}`, excluding `6`.** Exit 6 (V9) is documented
   as "the valid paths already committed successfully" — it must keep today's ERROR/issue-record
   treatment (something worth a human's attention: an out-of-repo pathspec was silently dropped)
   but must **not** demote a task whose actual commit landed. Flag this precisely in the
   implementation plan as a deliberate narrowing of the dispatch's literal "2/3/4/5/6" framing,
   with the table above as the cited justification; if the plan author disagrees and wants
   6 included for simplicity/uniformity with the existing issue-record grouping, that is a
   reasonable alternative to weigh, but it should be a stated decision, not an accidental carry-
   over.

3. **Reuse the exact `partial)`-arm call shape already proven in this file**: call
   `skill_postflight_update "$task_number" "implement" "$session_id" "partial" "" "$TASK_DIR"
   ""` (clamp_mode intentionally empty — not `"monotonic-max"`; Finding above shows it would be a
   no-op for an unranked target anyway, so there is no need to reason about it further at the
   call site, but passing it anyway would be misleading since `partial` is not a forced-dispatch
   concept here).

4. **Amend `.orchestrator-handoff.json` in place** (jq-based partial update, not a wholesale
   rewrite — preserve `phases_completed`/`phases_total`/etc.) to append a `blockers[]` entry
   built from `commit_attribution_note`, and to clear/omit `continuation_path` if present, so
   `orchestrate-triage-classify.sh`'s "partial + blockers, no continuation -> needs_human" row is
   the one reached on the next cycle, not the redispatch-to-implement default row. Re-check
   `docs/architecture/handoff-schema.md`'s "Readers MUST check freshness" contract
   (dispatch_start_ts / dispatch_seq gates) during implementation to confirm this in-place
   amendment does not accidentally make the handoff look stale to some other reader that still
   expects it to carry the original dispatch's own freshness markers.

5. **Flip `verdict` from `"ok"` to `"defer"`** for this corrected cycle, mirroring the existing
   `deploy_pending_refusal`/`derived_staleness_refusal` precedent's established meaning of
   `"defer"` ("in-flight, retry the SAME phase next cycle"). This requires relaxing WORK (i)'s own
   current comment ("do NOT change verdict, halt, infra_exempt_cycle... here") — update that
   comment to document the new, narrowly-scoped carve-out rather than leaving it stale and
   contradicted by the new code.

6. **Leave `skill_orchestrate_propagate_completion`'s already-fired side effects alone** (roadmap
   item propagation, `completion_summary`). The underlying work genuinely happened; only the
   task's own commit/status bookkeeping is being corrected. State this as a deliberate, recorded
   decision in the plan rather than silently leaving it unaddressed, in case a future reader
   wonders why a "demoted" task still shows a completion summary.

7. **Update `context/standards/status-markers.md`'s `[COMPLETED]` row** ("No further
   transitions") to document this one sanctioned, narrow exception, and cross-reference
   `git-staging-scope.md`'s exit-code table from the new WORK (i) code comment.

**Why not Option (a) (reorder WORK (f) and WORK (i)).** WORK (i)'s single `git-commit-scoped.sh`
call commits the task's own `modified_files` **together with** `state.json`/`TODO.md` (and the
plan file, for implement) in one atomic commit — this is the existing "one commit per cycle"
contract (`git-workflow.md`; `dispatch-metrics.sh`'s per-commit accounting). Knowing the commit's
outcome *before* the status write requires either (i) committing the task's own files in a
*separate*, earlier commit, then committing `state.json`/`TODO.md` in a second commit once the
status write happens — splitting one commit into two for every cycle, a change with much broader
blast radius than the demotion logic above — or (ii) a dry-run/pre-check version of
`git-commit-scoped.sh` that predicts success without actually committing, which cannot
meaningfully predict `V5` contention or `V8` integrity-mismatch failures without actually
attempting the commit. Task 304's framing of option (a) as "a larger design change belonging to
other work on these files" is confirmed correct by this re-read; option (b) is the proportionate,
narrowly-scoped fix this task's SCOPE calls for.

## Decisions

- Recommend Option (b) over Option (a): a corrective `state.json`/`.orchestrator-handoff.json`
  demotion inside WORK (i), not a reordering of WORK (f)/(i) into two commits per cycle.
- Recommend narrowing the demotion-triggering exit-code set to `{2,3,4,5}` (excluding 6), citing
  `git-staging-scope.md`'s own V9 semantics ("the valid paths already committed successfully") as
  the reason 6 must keep its existing non-demoting ERROR/issue-record treatment only.
- Recommend scoping the new logic strictly to the `implement`-phase/`completed` case (not
  `researched`/`planned`), matching the task's own HARD CONSTRAINT framing and the fact that only
  `completed` is a terminal state under the permissive transition model.
- Recommend reusing the proven `skill_postflight_update "$task_number" "implement" "$session_id"
  "partial" "" "$TASK_DIR" ""` call shape already exercised by WORK (f)'s own `partial)` arm,
  rather than inventing a new call pattern.
- Recommend pairing the `state.json` demotion with an in-place `.orchestrator-handoff.json`
  `blockers[]` amendment (clearing any `continuation_path`), so `orchestrate-triage-classify.sh`
  routes the corrected task to `needs_human` on the next cycle rather than wastefully
  re-dispatching a redundant `implement` phase.
- No `claim_invalidations` entry is warranted: task 304's "monotonic-max... prevents a later
  demotion by construction" framing is corrected above, but this is a researcher's re-reading of
  unchanged library code against a now-clearer question, not a machine-checked refutation of a
  declaration or an explicit supersession event.

## Risks & Mitigations

- **Risk**: the new demotion write races a concurrent reader of `state.json`/the handoff file
  (this task's own territory note flags six-plus sibling tasks contending on this exact file).
  **Mitigation**: `update-task-status.sh` already serializes through `state-write.sh`'s mutex;
  the new call is just another ordinary postflight write through that same serialized path, no
  new concurrency primitive needed.
- **Risk**: scope creep — attempting to also "undo" `skill_orchestrate_propagate_completion`'s
  roadmap/summary side effects. **Mitigation**: explicitly declared out of scope in Recommendation
  6 above; the underlying work is real, only the commit/status bookkeeping is being corrected.
- **Risk**: a future reader assumes exit 6 belongs in the demotion set because the dispatch text
  literally lists "2/3/4/5/6." **Mitigation**: the exit-code table and V9's own documented
  semantics are cited explicitly in Findings/Recommendations above so the planning phase makes
  this choice deliberately, with the evidence in hand, rather than defaulting to the literal
  dispatch wording without re-checking it.
- **Risk**: the handoff amendment conflicts with the "Readers MUST check freshness" contract in
  `handoff-schema.md`, causing some other reader to treat the corrected handoff as stale or vice
  versa. **Mitigation**: flagged explicitly in Recommendation 4 as something the implementation
  phase must re-verify against that contract's exact freshness predicate before committing to the
  in-place amendment approach.

## Context Extension Recommendations

- **Topic**: sanctioned terminal-state status demotions.
  **Gap**: `context/standards/status-markers.md`'s `[COMPLETED]` row currently states "No further
  transitions" with no carve-out language, and `git-staging-scope.md`'s exit-code table is not
  cross-referenced from any status-transition document.
  **Recommendation**: once this task's implementation lands, update `status-markers.md` to
  document the one sanctioned exception (terminal `completed` -> `partial` on a demonstrated
  per-cycle commit failure for that same dispatch window) and link both directions between
  `status-markers.md` and `git-staging-scope.md`'s exit-code table.

## Appendix

- Searches performed: `grep -n "WORK ("` across `orchestrate-cycle-postflight.sh`; full reads of
  WORK (f) (~1144-1517) and WORK (i) (~1832-1965); `grep -n "monotonic"` across
  `skill-base.sh`/`orchestrate-cycle-plan.sh`; full read of `scripts/lib/status-vocabulary.sh`;
  `grep -n "terminal\|COMPLETED"` across `update-task-status.sh`; full read of `map_status()` and
  the idempotency/write-guard sections of `update-task-status.sh`; `grep -n "needs_human\|
  partial\|blockers"` across `orchestrate-triage-classify.sh`; `grep -n "orchestrator-handoff.json"`
  across every script in `agent-system/extensions/core/scripts/`; read of
  `docs/architecture/handoff-schema.md`'s header and path-resolution contract; read of the exit-
  code table and V3/V5/V6/V8/V9 sections of `context/standards/git-staging-scope.md`; read of the
  `verdict` resolution block (~1625-1671) and the `persisted_status` block (~2181-2194); read of
  `skill_postflight_update`'s full body (skill-base.sh ~880-1090) including its `partial)` and
  `needs_research)` case arms.
- Both `.claude/scripts/orchestrate-cycle-postflight.sh` and
  `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` were diffed and confirmed
  byte-identical at research time (deploy is current); the source-store copy under
  `agent-system/extensions/core/` is the one any implementation phase must edit, per
  `.claude/rules/source-store-deploy-boundary.md`.
