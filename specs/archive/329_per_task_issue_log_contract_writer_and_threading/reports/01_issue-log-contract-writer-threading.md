# Research Report: Task #329

**Task**: 329 - Per-task issue log: contract, writer and dispatch threading
**Started**: 2026-10-03T23:21:00Z
**Completed**: 2026-10-03T23:30:00Z
**Effort**: medium
**Dependencies**: Task 285 (completed), Task 326 (completed) — both file-footprint serializations only, both already landed
**Sources/Inputs**: Codebase read (scripts/, context/contracts/, context/formats/, docs/architecture/), state.json/TODO.md dependency check, grep-corroboration of dead-field claims
**Artifacts**: - specs/329_per_task_issue_log_contract_writer_and_threading/reports/01_issue-log-contract-writer-threading.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- `scripts/system-defect-record.sh` + `scripts/events-append.sh` give two append-one-validated-
  JSONL-line precedents; `scripts/orchestrate-record-decision.sh` gives a third precedent for a
  **per-task** file (`.decisions.json`) resolved from a bare task number via
  `scripts/lib/task-lookup-lib.sh`. `issue-record.sh` should combine the JSONL append mechanics
  of the first two (flock + O_APPEND, one `jq -c -n` line, lazy file creation) with the per-task
  targeting of the third — but target the file directly via an absolute `--task-dir`, since every
  known caller (dispatched agents via the dispatch file's `task_dir`, and
  `orchestrate-cycle-postflight.sh`'s `$TASK_DIR`) already holds that path and a state.json lookup
  round-trip would be pure overhead.
- The single threading point is real and precisely located: `orchestrate-build-dispatch.sh`'s
  unconditional per-dispatch section emitter (lines 420-578 of the deployed/current copy — the
  dispatch's "measured ~417-558" is now stale by ~20 lines, almost certainly from tasks 285/326
  landing; **re-measure again before editing**, as the dispatch itself warns). A new `## Issue
  Log` section fits right after `## Handoff` (currently lines 499-503), before the conditional
  `## Territory` block, since it is unconditional across every phase (research/plan/implement)
  exactly like `## Handoff` itself.
- `context/contracts/phase-closure.md` is explicitly documented as **loaded in both modes** via
  an explicit `@`-bullet in `agents/general-implementation-agent.md` — it is the correct second
  injection site for implementation agents. `context/contracts/wrap-up.md` is **hard-mode-only**
  (loaded exclusively via `skill-orchestrate`'s hard-mode contract injection) — adding the
  recording instruction there reaches only hard-mode implement dispatches, not standard-mode or
  research/plan dispatches. The dispatch's phrase "every implementation and research agent" is
  therefore satisfied by the `orchestrate-build-dispatch.sh` section alone; `wrap-up.md` and
  `phase-closure.md` add reinforcement at the specific moment (during-phase, pre-termination)
  that a hard-mode/implementation agent is most likely to reconstruct-at-the-end instead of
  recording-as-it-happens.
- The dead `reflection` field claim is **independently corroborated** by this research (not just
  asserted by the dispatch): `grep` across `skill-base.sh`, `update-task-status.sh`,
  `orchestrate-cycle-postflight.sh`, and `state-write.sh` finds zero writers of `.reflection`;
  the only writer is `scripts/orchestrator-postflight.sh`, and `skill-base.sh:991` itself already
  documents in-repo that "`orchestrator-postflight.sh` itself has no live callers." The
  `context/reference/state-management-schema.md` prose describing a live "Skill postflight reads
  `reflection`... and writes it" producer is aspirational/stale, not a description of working code.
- The orchestrator-side call sites named in the dispatch are real but their locations need two
  corrections: (1) the "blocked dispatch, off-schema return, recovery... and defer" sites are all
  in `orchestrate-cycle-postflight.sh`, but spread across ~lines 676-860 (recovery/RECOVERY_DECLINED),
  ~1108-1125 (partial-with-blockers / failed / blocked), ~1168-1189 (off-schema catch-all), and
  ~1290-1320 (verdict="defer" resolution) — not one contiguous "~1048-1125" block; (2)
  "loop-guard exhaustion" is not in `orchestrate-cycle-postflight.sh` at all — it is the
  `MAX_CYCLES`/`MAX_INFRA_FAILURES` budget-exhaustion block in `orchestrate-cycle-plan.sh`
  (~lines 1569-1584).

## Context & Scope

Researched the writer-script precedent, the dispatch-threading mechanism, the six existing
issue-surfaces named in the dispatch, and the live/dead status of the `reflection` field, in
order to hand the planner concrete file:line anchors and a recommended verdict for each of the
six relation decisions the dispatch requires to be recorded. Scope is per the dispatch's CAPTURE
ONLY boundary: no mid-run surfacing, no gates, no status changes — this research is exclusively
about where to write one validated entry and where to tell agents/orchestrator code to call that
writer.

## Findings

### Codebase Patterns

**Three existing append-one-validated-entry precedents, not one:**

1. `agent-system/extensions/core/scripts/system-defect-record.sh` (the dispatch's named model).
   Validates a **closed** enum (`--defect-class`), requires Signal-B attribution resolution to
   `agent-system/extensions/**`, runs a recursion guard and a dedup rule, then delegates the
   actual write to `events-append.sh`. This is the right shape for *argument validation style and
   non-fatal-call-site convention*, but it writes to the **global** `specs/events.jsonl`, not a
   per-task file — not directly reusable for the write-target mechanics.
2. `agent-system/extensions/core/scripts/events-append.sh`. The actual JSONL-append primitive:
   builds one line with `jq -c -n` (never string concatenation), then
   `(flock -x 200; printf '%s\n' "$line" >> "$EVENTS_FILE") 200> "$LOCK_FILE"`. This flock+O_APPEND
   idiom is exactly the mechanics `issue-record.sh` needs, pointed at a per-task
   `issues.jsonl`/`.issues.lock` pair instead of the global files.
3. `agent-system/extensions/core/scripts/orchestrate-record-decision.sh` (the task-285 writer for
   `.decisions.json`, already landed). This is the closest **per-task-file** precedent: it
   resolves `TASK_DIR` from a bare `--task N` via `task_lookup_entry`/`task_lookup_dir`
   (`scripts/lib/task-lookup-lib.sh`), uses a dedicated per-task lock file
   (`$TASK_DIR/.decisions.lock`), and documents explicitly that task-directory resolution is
   **not** done via `task-lock.sh` (a different, unrelated mutex). Its write mechanics
   (read-merge-validate-mv under `flock`) suit a JSON **array** document, not a JSONL file —
   `issue-record.sh` wants `events-append.sh`'s simpler append-only-line mechanics instead, but
   should borrow this script's **task-dir-resolution** discipline for any call site that only has
   a bare task number.

   **Design implication for the planner**: every currently-named caller already holds an
   absolute task directory path directly (a dispatched agent reads `task_dir` straight off its
   dispatch file's `## Handoff` section; `orchestrate-cycle-postflight.sh` already carries
   `$TASK_DIR` as a script-local variable). Requiring `--task-dir PATH` as the primary/required
   argument (mirroring `wrap-up.md`'s own "absolute path, never a bare filename" lesson for
   `.orchestrator-handoff.json`) avoids a state.json round-trip entirely for every known caller.
   An optional `--task N` could still be accepted as a provenance-only field recorded *into* the
   entry (not used for path resolution) if the planner wants it for cross-task search later.

**Shell strict-mode classification** (`context/standards/shell-strict-mode.md`): `issue-record.sh`
is an ordinary script with no counter idiom — Class A, `set -euo pipefail`, matching
`system-defect-record.sh` and `events-append.sh`. `scripts/tests/test-issue-record.sh` is a test
suite — Class B, `set -uo pipefail` (no `-e`), using the mandated `pass()`/`fail()`/`info()` +
PASSED/FAILED-counter idiom documented in `shell-script-testing.md`, matching every other
`scripts/tests/test-*.sh` file (e.g. `tests/test-orchestrate-record-decision.sh`, which is the
closest sibling test to model the new one on).

### Threading Point — `orchestrate-build-dispatch.sh`

Confirmed single-point structure (current file is 581 lines, not ~558 — re-measure before
editing, both because the dispatch already warns to and because this research's own read is
already slightly stale against a live file):

- Lines 420-578: one `{ ... } > "$dispatch_file"` block that emits every section of the per-
  dispatch prompt, unconditionally for every phase.
- `## Identity` (427-443), `## Description` (444-451), `## Artifact Round` (452-457),
  phase-conditional `## Research Artifact`/`## Plan`/`## Continuation`/`## Phase Mission`
  (458-498), `## Handoff` (499-503, **unconditional**), conditional `## Territory` (504-526),
  conditional memory/lit/effort/hard-contracts/deploy-freshness/lean-readiness blocks (527-550),
  conditional `## Prior Decisions` (551-560), unconditional `## Wait Discipline` (561-570),
  unconditional `## User-Decision Contract` (571-577).

A new `## Issue Log` section belongs **immediately after `## Handoff`** (i.e., inserted between
current lines 503 and 504): it is unconditional like `## Handoff` and `## Wait Discipline`, it
needs no per-phase branching, and placing it next to `## Handoff` keeps "where things live"
(`task_dir`, `handoff_path`, and now the issue-log path/call convention) co-located. It should
state: the resolved `--task-dir "${TASK_DIR_ABS}"` the agent should pass, the non-fatal call
convention (mirroring `system-defect-record.sh`'s own documented convention:
`bash .../issue-record.sh ... >/dev/null 2>&1 || echo "Note: ... (non-fatal)" >&2`), the
`kind: issue|win` + seed-class-enum one-liner, and a pointer to
`context/formats/issue-log.md` for the full schema — never inlining the full schema in the
dispatch file itself (consistent with every other pointer-not-copy section in this file, e.g. the
Territory section's pointer to `context/contracts/territory.md`).

### Threading Point — Shared Contracts

- `context/contracts/phase-closure.md` (175 lines): **loaded in both modes**, via an explicit
  `@`-bullet in `agents/general-implementation-agent.md`'s Context References (its own header
  says so explicitly, with a "Correction (re-verified by grep, this task)" note showing this file
  already practices exactly the re-verification discipline task 329 should apply). This is the
  correct second injection site — add a short paragraph (near "Marker/commit synchrony is
  bidirectional" or as its own small section) instructing: call `issue-record.sh` as soon as a
  deviation, blocker, workaround, or an unusually smooth win is observed mid-phase, rather than
  reconstructing it from memory at the final `.return-meta.json`/handoff write.
- `context/contracts/wrap-up.md` (231 lines): **`--hard`-only** per its own header ("loaded
  exclusively via `skill-orchestrate`'s hard-mode contract injection... STANDARD mode never loads
  this file"). Adding the same instruction here reinforces it specifically for hard-mode
  implement dispatches at the point they write blockers/sorry_inventory — a natural place to also
  remind the agent that a `blockers[]` entry it is about to write should ALSO be recorded via
  `issue-record.sh` (see Decisions below — this is the MIRROR point for `blockers`/`dead_ends`).

Research/plan-phase agents (base mode) load neither contract file — their only path to the
Issue Log instruction is the `orchestrate-build-dispatch.sh` section above. This matches the
dispatch's own framing ("reaches EVERY dispatched agent without editing any of the 78 agent
definition files") and confirms no third injection site is needed to satisfy "every
implementation and research agent."

### Orchestrator-Side Call Sites — `orchestrate-cycle-postflight.sh` (1646 lines total)

The dispatch's "~1048-1125" estimate undershoots: the actual completion-arm structure (re-measured
this session) is:

- **`implemented)` case** (~963-1096): the `skill_gate_completion_claim` branch; its `else`
  (gate-refused) arm at ~1096-1106 already calls
  `skill_orchestrate_append_detected_defect ... META_MISSING_AFTER_NARRATION` for one specific
  sub-case (phases_total==0 and markers unverified) — a natural MIRROR call site for an
  `issue-record.sh` call (kind=issue, class could use "orchestration defect" or "design-record
  defect or ambiguity" depending on root cause).
- **`partial)` case** (~1108-1122): blocker-gated — only the `partial_blocker_count -gt 0` branch
  changes state; this is the strongest candidate for an issue-record call (kind=issue,
  class="plan scope-hypothesis wrong" or similar, `resolution="open"`), since it is exactly the
  "some phases completed, one is externally blocked" case `wrap-up.md` documents.
- **`failed|blocked)` case** (~1123-1125): "recognized exception outcome. No state.json
  transition... remains at its current in-flight status" — today leaves **only** the commit
  subject line per the dispatch's own WHY section; this is the clearest "destroyed on overwrite"
  case to fix.
- **RECOVERY_DECLINED block** (~788-860, inside WORK (b) "return-meta recovery"): already calls
  `system_defect-record.sh --defect-class RECOVERY_DECLINED` at ~826-838. A same-site
  `issue-record.sh` call is the MIRROR point for "recovery" named in the dispatch.
- **OFF_SCHEMA_STATUS catch-all** (~1168-1189, the `*)` arm of the dispatch_status case): already
  calls `system-defect-record.sh --defect-class OFF_SCHEMA_STATUS`. Same-site MIRROR point for
  "off-schema return."
- **`verdict="defer"` resolution** (~1290-1320): three distinct sub-paths set `verdict="defer"` —
  implemented-but-gate-failed-or-deploy-pending (~1300-1303), `partial)` (1306), and
  `infra_exempt_cycle` (1317). "Defer" per se is a routing signal, not necessarily an issue (most
  defers are healthy in-flight continuations) — recommend recording only the
  deploy-pending-refusal sub-path (an actual anomaly: the status write itself did not land) as
  kind=issue, and treating the ordinary partial/infra-exempt defers as out of scope for recording
  (they would otherwise flood the log with non-anomalous routine continuations, which cuts against
  the dispatch's own "capture only... resist the pull to add a mid-run summary" spirit applied to
  volume rather than timing).
- **Loop-guard exhaustion is NOT in this file.** It is the `MAX_CYCLES`/`MAX_INFRA_FAILURES`
  per-task budget-exhaustion block in `orchestrate-cycle-plan.sh` (~1569-1584, inside the
  eligibility-filtering loop) — a clean kind=issue candidate (class="cost-forced exclusion or
  substituted verification" fits well: "every remaining task has reached its own per-task
  work-cycle budget for this run").

All of these sites already have `$task_number`, `$session_id`, and either `$TASK_DIR` or an
equivalent resolvable path in scope — the orchestrator-side calls can pass `--task-dir "$TASK_DIR"`
directly, with no task-lookup round-trip needed there either.

### The Six Existing Surfaces — Relation Evidence

| Surface | Evidence found | 
|---|---|
| `.return-meta.json` `errors[]` | `context/formats/return-metadata-file.md:597-609` — optional array, four required fields (`type`, `message`, `recoverable`, `recommendation`), **"Include if: status is partial, failed, or blocked"** only. Confirmed overwritten every dispatch (no append semantics documented or implemented anywhere in this field's section). |
| `progress/phase-N-progress.json` | `context/formats/progress-file.md` has **no `deviations[]` field** — the dispatch's phrasing is imprecise here. The actual field is `approaches_tried[]` (`{approach, result, reason}`, optional, "Prevents successor teammates from retrying approaches that already failed" — purpose-overlapping with issue-log's `resolution`/`what_happened`). `summary-format.md`'s "Plan Deviations" is free prose in the *summary* artifact, not a progress-file JSON field. |
| Handoff `blockers`/`dead_ends` | `docs/architecture/handoff-schema.md:227-250` (`blockers`, required array, canonical `{phase, target, verbatim_goal, what_was_tried, why_it_failed}` shape) and `:273-275` (`dead_ends`, optional, "Approaches tried but failed... prevent repetition"). Both live in `.orchestrator-handoff.json`, which — per the dispatch's own WHY section and this file's own Wrap-Up Contract — is **overwritten on every dispatch**. |
| `system_defect` events | `scripts/system-defect-record.sh` — closed 16-class enum, Signal-B attribution REQUIRED (must resolve to `agent-system/extensions/**`), recursion-guarded, deduplicated against non-terminal linked tasks. This is strictly about **agent-system's own mechanically-detected schema defects**, a different population and audience from issue-log's human/task-execution-friction taxonomy (design-record defects, gate collisions, resource/OOM, etc.) — though the two populations overlap exactly at the sites above (RECOVERY_DECLINED, OFF_SCHEMA_STATUS) where both a system defect AND a project-issue are simultaneously true. |
| `reflection` | **Confirmed dead by two independent methods this session**: (1) `grep -rn "reflection" scripts/skill-base.sh scripts/update-task-status.sh scripts/orchestrate-cycle-postflight.sh scripts/state-write.sh` returns zero hits — none of the scripts that actually run in the live postflight path ever touch this field; (2) the only writer, `scripts/orchestrator-postflight.sh` (Stage 7d, ~lines 428-443), is itself already documented as dead in-repo: `scripts/skill-base.sh:991` states verbatim "orchestrator-postflight.sh itself has no live callers." `context/reference/state-management-schema.md`'s own "Sparsity note" (~line 307) independently confirms zero occurrences in `specs/state.json` or `specs/archive/state.json`. |

### Dependency / Overlap Status (re-checked this session)

- Task 285 (`.decisions.json` writer + postflight touch): **status=completed**. Its line-range
  edits to `orchestrate-cycle-postflight.sh` are already baked into the file this research read —
  no further waiting needed.
- Task 326 (`--gate` flag at implement dispatch, touches `orchestrate-build-dispatch.sh`):
  **status=completed**. Already baked into the 581-line file this research measured — this is
  almost certainly why the dispatch's "~417-558" estimate is already ~20 lines stale.
- Task 299 (concurrent plan-revision detection, also edits `orchestrate-build-dispatch.sh`):
  **status=not_started**. No current conflict; still re-measure at implementation time per the
  dispatch's own instruction, since 299 could land first in a different cycle.
- Task 273 (three-channel conclusion stage, downstream consumer of these logs):
  **status=not_started**.

## Decisions

Recommended verdicts for the six required relation decisions (to be encoded verbatim into
`context/formats/issue-log.md` at implementation time — research can recommend but the dispatch
treats this as a decision the implementing pass must record, not one pre-baked into agent code):

1. **`.return-meta.json` `errors[]` → MIRROR.** Keep `errors[]` exactly as-is (it is read
   structurally by postflight/triage logic and must stay a per-dispatch, overwritten, bounded
   field). At every call site that already builds an `errors[]` entry, also call `issue-record.sh`
   with the same `message`/`recommendation` content (kind="issue"). This is what makes the
   acceptance criterion "a recorded entry survives a subsequent dispatch's overwrite of
   `.return-meta.json`" true without touching the existing field's semantics or its consumers.
2. **`progress/phase-N-progress.json` `approaches_tried[]` → MIRROR**, same rationale: it remains
   the within-phase, same-dispatch-successor-facing memory ("don't retry this"); `issue-record.sh`
   additionally captures it durably at the task level with the richer taxonomy (class, severity,
   cost) `approaches_tried` doesn't carry.
3. **Handoff `blockers[]`/`dead_ends` → MIRROR.** Both already have the richest structured shape
   of the six surfaces (`wrap-up.md`'s `blockers[]` canonical fields map almost 1:1 onto
   `what_happened`/`evidence_path`/`resolution`). Keep writing the handoff fields (the live
   routing signal the orchestrator consumes this cycle); additionally call `issue-record.sh` at
   the same write site so the content survives the handoff's own next-dispatch overwrite.
4. **`system_defect` events → LEAVE (independent), with call-site MIRROR only where both already
   fire.** The two logs serve different audiences (agent-system meta-defects vs. task-execution
   friction) and different enums (closed 16-class vs. open/extensible 15-class-seeded). Do not
   merge or subsume either into the other. At the two sites that already call
   `system-defect-record.sh` (RECOVERY_DECLINED, OFF_SCHEMA_STATUS), add an adjacent
   `issue-record.sh` call — both logs end up with an entry for the same event, each in its own
   vocabulary, which is the intended overlap, not a defect.
5. **`reflection` → RETIRE.** It is dead (corroborated above by two independent methods, not just
   asserted). Per the dispatch's own instruction, retire it in the same pass: remove it from
   `KNOWN_ENTRY_FIELDS` in `scripts/validate-state.sh` (currently line 505, in the array literal
   spanning lines 503-507), remove the Stage 6b/7d reflection logic from
   `scripts/orchestrator-postflight.sh` (lines ~204, 219, 269-277, 412, 428-443), and remove or
   mark-historical the "Reflection Field" subsection of
   `context/reference/state-management-schema.md` (~lines 287-307) and the `reflection` row in its
   field table (~line 231). `kind="win"` entries in `issues.jsonl` become the live replacement for
   the positive-signal half of `reflection` (`what_worked`/`successes`); the negative half
   (`what_was_hard`/`what_was_missed`) is exactly `kind="issue"`.
6. **New field placement**: `issues.jsonl` is additive to, not a replacement for, any of the five
   surfaces above — all five keep their current writers unchanged (MIRROR, not SUBSUME) except
   `reflection` (RETIRE, since it has no live writer to preserve).

## Recommendations

1. Build `issue-record.sh` on `events-append.sh`'s flock+O_APPEND JSONL mechanics (not
   `orchestrate-record-decision.sh`'s read-merge-mv array mechanics — `issues.jsonl` is append-only
   by name and by the dispatch's own "survives... overwrite" framing, so one-line-per-call is the
   right shape), borrowing `system-defect-record.sh`'s argument-parsing/validation style and
   non-fatal call-site convention verbatim.
2. Require `--task-dir PATH` (absolute) as the write target, not a bare `--task N` requiring
   state.json resolution — every known caller already holds the absolute path. Target file:
   `${TASK_DIR}/issues.jsonl`; lock file: `${TASK_DIR}/.issues.lock` (mirroring
   `.decisions.lock`'s per-task, not-shared-with-`task-lock.sh`, convention).
3. Validate `kind` (closed: `issue|win`) and `what_happened` (required, non-empty) at minimum
   before any write, mirroring `events-append.sh`'s required-argument checks; accept-with-stderr-
   warning for an unrecognized `class` value (never refuse) per the dispatch's EXTENSIBLE
   requirement — this is the one deliberate divergence from `system-defect-record.sh`'s
   closed-enum-refuses-loudly posture, and should be called out explicitly in the script's header
   comment so a future reader does not "fix" it into a closed enum by analogy.
4. Insert the `## Issue Log` dispatch section immediately after `## Handoff` in
   `orchestrate-build-dispatch.sh` (current lines 499-503), re-measuring exact line numbers
   immediately before editing (both tasks 285 and 326 already shifted this file since the
   dispatch's own estimate was written).
5. Add the recording-as-you-go instruction to `context/contracts/phase-closure.md` (reaches both
   modes) and `context/contracts/wrap-up.md` (reinforces hard-mode's blockers/sorry_inventory
   write moment) — no third injection site is needed; research/plan-phase and base-mode agents
   are already reached by the dispatch-file section alone.
6. At implementation time, re-measure `orchestrate-cycle-postflight.sh`'s five actual sub-sites
   (RECOVERY_DECLINED ~788-860, OFF_SCHEMA_STATUS ~1168-1189, `partial` blocker-gated ~1108-1122,
   `failed|blocked` ~1123-1125, deploy-pending-refusal defer sub-path ~1300-1303) individually,
   rather than treating them as one contiguous range — and separately locate and edit
   `orchestrate-cycle-plan.sh`'s MAX_CYCLES/MAX_INFRA_FAILURES block (~1569-1584) for the
   loop-guard-exhaustion site the dispatch names, which is not in the postflight script at all.
7. Retire `reflection` in the same implementation pass per Decision 5 above, rather than leaving
   it dead beside a newly-live `issues.jsonl`.

## Risks & Mitigations

- **Risk**: `orchestrate-build-dispatch.sh` and `orchestrate-cycle-postflight.sh`/
  `orchestrate-cycle-plan.sh` line numbers will have moved again by the time an implementer reads
  this report (tasks 285/326 already shifted them once between the dispatch's estimate and this
  research). **Mitigation**: every line number in this report is stated as approximate
  ("~") and the Recommendations section explicitly repeats the re-measure instruction per site,
  not just once globally.
- **Risk**: adding an `issue-record.sh` call at every MIRROR site inflates dispatch/postflight
  script complexity and risks becoming another silently-stale dead feature (like `reflection`)
  if a future script edit forgets to keep the call site in sync with its sibling field write.
  **Mitigation**: co-locate each `issue-record.sh` call immediately adjacent to the sibling
  write it mirrors (same `if`/case arm), not in a separate pass — the two writes should be visibly
  paired in the diff a future editor reads.
- **Risk**: the open/extensible `class` field could silently drift into an unbounded tag soup if
  nothing ever looks at what unknown classes accumulate. **Mitigation**: out of scope for this
  task (CAPTURE ONLY), but worth flagging for task 273's conclusion-stage design: it should
  surface a tally of classes outside the 15-class seed as part of its own synthesis, which doubles
  as the feedback loop that eventually promotes a recurring unknown class into the documented seed
  enum.

## Context Extension Recommendations

- **Topic**: machine-checkable schema for `issues.jsonl` entries.
- **Gap**: every other per-line JSONL format in this codebase (`events.jsonl`,
  `.orchestrator-handoff.json`) pairs its prose contract with a `context/schemas/*-schema.json`
  file (`events-schema.json`, `orchestrator-handoff-schema.json`). The dispatch's deliverable list
  only names `context/formats/issue-log.md` (prose) — no `issue-log-schema.json` is required by
  this task's acceptance criteria, but omitting one breaks the established prose+schema pairing
  convention.
- **Recommendation**: not required for this task's acceptance bar; flag as a natural, low-cost
  follow-up (`context/schemas/issue-log-schema.json`) either in the same implementation pass if
  budget allows, or as a short note in the format doc itself acknowledging the omission.

## Appendix

- Search queries / commands used: `jq` queries against `specs/state.json` for tasks 285/326/299/273
  status; `grep -rn` sweeps for `reflection`, `dead_ends`, `deviations`/`approaches_tried`,
  `orchestrator-postflight.sh` callers, `## Identity`/`Handoff`/`Territory` section markers in
  `orchestrate-build-dispatch.sh`, and `exhaust`/`MAX_CYCLES` in the cycle-plan/cycle-postflight
  scripts.
- Key files read in full or in substantial part: `scripts/system-defect-record.sh`,
  `scripts/events-append.sh`, `scripts/orchestrate-record-decision.sh`,
  `scripts/orchestrate-build-dispatch.sh` (lines 410-581), `scripts/orchestrate-cycle-postflight.sh`
  (lines 1000-1320, plus targeted greps), `scripts/orchestrate-cycle-plan.sh` (lines 1560-1620),
  `context/contracts/wrap-up.md` (full), `context/contracts/phase-closure.md` (full),
  `context/formats/progress-file.md` (lines 1-170), `context/formats/return-metadata-file.md`
  (lines 590-629), `docs/architecture/handoff-schema.md` (lines 227-300), `scripts/validate-state.sh`
  (lines 495-515), `context/reference/state-management-schema.md` (lines 280-310),
  `context/standards/shell-strict-mode.md` (lines 1-60).
