# Cross-Batch Admission Verdict Schema

**Status**: Current architecture. Version 5 (`orchestrate-batch-admit-v5`) — see "Version History"
at the bottom for what changed from v1 to v2, v2 to v3, v3 to v4, and v4 to v5, and why each bump
was a version, not an additive field, and for the self-modification tie-breaker/`--phase-map`
change (still v5) that follows the same history for the opposite reason — why it deliberately did
NOT bump the version.

**File location**: n/a — this is a stdout stream contract, not a file. The script emits NDJSON
directly; nothing is written to disk.
**Written by**: `.claude/scripts/orchestrate-batch-admit.sh`
**Read by**: `skills/skill-orchestrate/SKILL.md` Stage MT-3 step 4.5 (per-cycle eligibility gate — the sole
EXECUTING admission gate on the MT dispatch path, covering both effort modes now that the
formerly-separate hard-mode engine's own transcribed copy of this contract has been deleted along
with that file — see "Version History" below),
`scripts/orchestrate-cycle-plan.sh` (both its live dispatch path and its `--dry-run` mode — one
call, one schema, never a forked copy; this script absorbed and retired the former standalone
`orchestrate-dry-run-report.sh`), and `scripts/orchestrate-predispatch-review.sh` (Classes C and D —
a report composer in the same relationship to this schema as the dry-run reporter above: it
re-presents `defer_reason == "self_modifying"` and `defer_reason == "file_scope_collision" &&
collision_scope == "cross_batch"` verdicts, adding a declaration-coarseness diagnosis and a
suggested serializing edge respectively, never re-deriving the collision algorithm itself)

**See Also**: `context/patterns/file-footprint-overlap.md` (the canonical overlap predicate this
script transcribes and never restates), `context/patterns/batch-orchestration-guardrails.md`
("Self-Modification Hazard: The Fourth Admission Dimension" — the rationale behind the
critical-path list and the two-test inclusion/exclusion criteria), `handoff-schema.md` (the
sibling orchestrator-facing schema document this page is modelled on),
`context/reference/orchestrator-critical-paths.json` (the declared critical-path list and
`scope_roots` this script loads and expands)

## Invocation Contract

```
orchestrate-batch-admit.sh [--invocation-count <N>] [--session-id <id>] [--phase-map <task:group[,task:group...]>] <task_number> [<task_number> ...]
```

Positional arguments are the candidate task numbers — the caller's already-computed
`validated_tasks`/`task_numbers`/`eligible_tasks` for this call. Output is NDJSON on stdout:
exactly one compact JSON object per candidate argument, one per line, in input order. There is no
other output mode.

**Two independent orderings (do not conflate them)**: verdicts are DECIDED by folding candidates
in ASCENDING `project_number` order — a greedy walk that threads a running admitted-set forward,
so a candidate's own `in_batch` collision test can consult whether an already-folded,
lower-numbered peer was itself decided `admit` (see the `in_batch` bullet under
"Deferral-Direction Rule and Caller Guidance" below). Verdicts are EMITTED in the original
caller-argument order — the positional order above — regardless of decision order; an invocation
with arguments out of ascending order (e.g. `D C A B`) still decides `A` before `B` before `C`
before `D` internally, but prints `D`'s verdict first. Identical input always produces an
identical admitted set (the fold is a pure function of `specs/state.json` plus the candidate
list), so determinism is preserved across both orderings independently.

**`--invocation-count <N>`**: the number of candidates being CO-DISPATCHED IN THE SAME wave/cycle
as the positional `<task_number>` arguments — not the whole invocation's total candidate count.
Defaults to the number of positional `<task_number>` arguments when omitted (backward-compatible:
correct for any caller that already passes its own co-dispatch set in one call). A caller that
passes a wave/cycle SUBSET (`wave_tasks`, `eligible_tasks`) MUST pass that subset's own size here
— see "Why `--invocation-count` Exists" below for why a whole-invocation count is wrong as of v3.

**`--session-id <id>` (NEW in v4)**: the CALLER's own session id, the same id registered via
`task-lock.sh session-register`. Activates the session-registry contention input (the third
bounded input, alongside held locks — consumed only by `task-lock.sh acquire` — and non-terminal
`state.json` tasks) with self-exclusion against this id. Optional; when OMITTED, the session input
is SKIPPED entirely and one loud line goes to stderr — see "Degradation (D6)" below for the full
contract and why omitting it is never a silent no-op.

**`--phase-map <task:group[,task:group...]>` (NEW, tie-breaker/phase-aware convergence)**:
OPTIONAL. Maps a subset of the candidate `<task_number>` arguments to the dispatch phase group
each would run under this cycle (`research`, `plan`, `implement` — the same vocabulary
`scripts/orchestrate-triage-classify.sh` already emits). A self-modifying candidate mapped to
`research` or `plan` is admitted unconditionally — the self-modification defer branch never fires
for it, regardless of `--invocation-count` and regardless of the tie-breaker below — because a
research or plan dispatch touches only that task's own `reports/`/`plans/` subdirectory, never
orchestrator machinery. `self_modifying: true` still appears on the verdict; only `decision`
changes. A candidate absent from the map, or mapped to any other group (including `implement`),
is unaffected. Omitting `--phase-map` entirely preserves the prior (pre-tie-breaker) shape exactly
for every candidate that is not the cycle's designated self-modifying candidate — see the
tie-breaker paragraph immediately below. A malformed value (not matching
`task:group[,task:group...]` with integer tasks and alphabetic/underscore group names) is a usage
error (exit 2), same posture as `--invocation-count`.

**Self-modification tie-breaker (NEW)**: among the candidates in this cycle, the LOWEST task
number whose own `file_scope` matches a declared critical path is the DESIGNATED self-modifying
candidate for the cycle — the same ascending-`project_number`-first-match determinism convention
the `in_batch` collision-deferral direction already uses. The designated candidate is never
deferred by the self-modification branch, regardless of `--invocation-count`; every OTHER
self-modifying candidate this cycle still defers when `--invocation-count` > 1, exactly as
before. This converges N co-dispatched self-modifying candidates into a deterministic per-cycle
sequence (lowest number first, then re-evaluated next cycle as the prior designated candidate
leaves `eligible_tasks`) instead of every one of them deferring forever because none is ever
alone — the deadlock this closes. This is a genuine behavior change from pre-tie-breaker verdicts
(the previously-lowest-numbered candidate among 2+ co-dispatched self-modifying candidates now
`admit`s instead of `defer`s), but it introduces **no new field and no new verdict shape** — the
designated candidate's `admit` verdict is byte-for-byte the same shape as the pre-existing
"solo admit" case (`self_modifying: true`, no collision fields), and a deferred candidate's
verdict keeps the same `defer_reason: "self_modifying"` shape with only the `reason` string's
wording updated to name the designated candidate and frame the defer as a one-cycle ordering
constraint rather than an instruction to isolate the dispatch. Because no consumer branches on
the CONTENTS of `reason` (see the Field Definitions table: "Never the sole carrier of any fact
already available as a structured field above") and no field was added or removed, this is
**not** a schema version bump — see the `v5 to v6` non-bump note at the end of "Version History"
below for the full non-bump rationale, which is a different class of change than every prior
bump in this document's history.

**Exit codes**:
- `0`: verdicts were emitted successfully, regardless of how many are `defer`. Verdicts are
  data, not errors — this script never exits non-zero merely because a candidate was deferred.
- `2`: usage error (zero positional arguments, a non-integer positional argument, a non-integer
  `--invocation-count` value, or a malformed `--phase-map` value) or unavailable state (`jq`
  missing, or `specs/state.json` missing/unparseable). Nothing is printed on stdout in either
  case; a single loud line naming the reason goes to stderr.

There is no `1` exit code and no `fail` decision value — a candidate this script cannot resolve
(unknown task number, terminal status, empty/null `file_scope`) is admitted, not failed. Only a
usage error or unavailable state aborts the whole invocation before any verdict is printed.

## Complete JSON Schema

Every emitted line matches one of the three shapes below. Key order is stable — always as listed,
never reordered per verdict. `self_modifying` is present on **every** verdict, including plain
`admit` verdicts — this is the one field that never depends on which branch produced the verdict.

**Self-modifying defer** (self-modification hazard, candidate is co-dispatched this wave/cycle
alongside another candidate):

```json
{"$schema":"orchestrate-batch-admit-v5","task_number":460,"decision":"defer","self_modifying":true,"defer_reason":"self_modifying","critical_path":"agent-system/extensions/core/scripts/orchestrate-batch-admit.sh","critical_label":"admission predicate","reason":"candidate #460 file_scope names orchestrator-critical path \"agent-system/extensions/core/scripts/orchestrate-batch-admit.sh\" (admission predicate); deferred this wave/cycle in favor of designated self-modifying candidate #205 (lowest task number among the self-modifying candidates in this cycle) -- this is an ORDERING CONSTRAINT, not an exclusion: candidate #460 resolves in a later cycle, in sequence, once #205 clears, or pass --allow-self-modifying to override"}
```

**File-scope collision defer** (unchanged algorithm from v1, plus `corroborated_by` (NEW in v4);
as of v5 a `cross_batch` collision only reaches this shape when the colliding task carries
execution evidence — see "Deferral-Direction Rule and Caller Guidance" below):

```json
{"$schema":"orchestrate-batch-admit-v5","task_number":"{N}","decision":"defer","self_modifying":false,"defer_reason":"file_scope_collision","colliding_task_number":"{M}","colliding_task_status":"implementing","overlapping_path":"agent-system/extensions/core/scripts/orchestrate-batch-admit.sh","collision_scope":"cross_batch","corroborated_by":["non_terminal_status"],"reason":"file_scope overlap with non-terminal task #{M} (not in this batch) at agent-system/extensions/core/scripts/orchestrate-batch-admit.sh; no dependencies[] edge between them"}
```

**Session-active defer** (NEW in v4 — reached only when the collision scan above found no hit; a
live registered session's own unioned `file_scope` overlaps the candidate's):

```json
{"$schema":"orchestrate-batch-admit-v5","task_number":"{N}","decision":"defer","self_modifying":false,"defer_reason":"session_active","session_id":"sess_1736700000_a1b2c3","colliding_task_number":"{M}","overlapping_path":"agent-system/extensions/core/scripts/task-lock.sh","session_liveness_reason":"pid-alive","reason":"session sess_1736700000_a1b2c3 (liveness: pid-alive) covers non-terminal task #{M} whose registered file_scope overlaps this candidate at agent-system/extensions/core/scripts/task-lock.sh"}
```

**Admit** (carries only `$schema`, `task_number`, `decision`, `self_modifying` — nothing else,
whether `self_modifying` is `true` (a self-modifying candidate admitted solo, co-dispatch count
== 1), `false` (an ordinary candidate), or `null` (degraded — see below); may additionally carry
`idle_overlap_advisory`, NEW in v5 — see the dedicated example below):

```json
{"$schema":"orchestrate-batch-admit-v5","task_number":905,"decision":"admit","self_modifying":false}
```

**Admit with idle cross-batch advisory** (NEW in v5 — the collision scan found a `cross_batch`
overlap against a task with NO execution evidence, so the candidate is admitted rather than
deferred, and the suppressed overlap is surfaced loudly rather than silently):

```json
{"$schema":"orchestrate-batch-admit-v5","task_number":"{N}","decision":"admit","self_modifying":false,"idle_overlap_advisory":{"colliding_task_number":"{M}","colliding_task_status":"not_started","overlapping_path":"agent-system/extensions/core/scripts/orchestrate-batch-admit.sh","collision_scope":"cross_batch","reason":"file_scope overlap with IDLE (not in-flight) task #{M} (status \"not_started\", not in this batch) at agent-system/extensions/core/scripts/orchestrate-batch-admit.sh; admitted because no execution evidence exists — add a dependencies[] edge if ordering between them matters"}}
```

## Field Definitions

| Field | Type | Presence | Meaning |
|-------|------|----------|---------|
| `$schema` | string | always | Literal `"orchestrate-batch-admit-v5"`. Pinned; never changes across an invocation. |
| `task_number` | int | always | The candidate task number, echoed back from the corresponding CLI argument. |
| `decision` | string | always | `"admit"` or `"defer"` — never `"fail"`. |
| `self_modifying` | bool \| null | always | `true` when the candidate's own `file_scope` names a declared orchestrator-critical path; `false` when it does not; `null` when the critical-path data file is missing or unparseable (degraded — the check could not run, never silently reported as `false`). |
| `defer_reason` | string | defer only | REQUIRED on every `defer` verdict (since v2). Exactly one of `"self_modifying"`, `"file_scope_collision"`, or (NEW in v4) `"session_active"` — the discriminator that determines which of the field groups below is present, and which operator remedy applies (a `self_modifying` defer has a consumer-side `--allow-self-modifying` override; `file_scope_collision` and `session_active` have none). |
| `critical_path` | string | `defer_reason == "self_modifying"` only | The matched declared critical path, after `scope_roots` expansion (may be a source-store path or a deploy-tree path, whichever the candidate's `file_scope` actually named). |
| `critical_label` | string | `defer_reason == "self_modifying"` only | The matched entry's short label, from `orchestrator-critical-paths.json`. |
| `colliding_task_number` | int | `defer_reason == "file_scope_collision"` (the other task's `project_number`) OR `defer_reason == "session_active"` (NEW in v4 — the lowest non-excluded task number the contending session covers, per D4) | See per-branch meaning in this cell. |
| `colliding_task_status` | string | `defer_reason == "file_scope_collision"` only | The other task's `status` string, verbatim from `specs/state.json`. Not present on a `session_active` verdict — the session registry carries no `status` field of its own. |
| `overlapping_path` | string | `defer_reason == "file_scope_collision"` (first overlapping path, from the COLLIDING task's declared `file_scope`) OR `defer_reason == "session_active"` (NEW in v4 — first overlapping path, from the contending session's own precomputed `file_scope`) | Matches `task-lock.sh`'s `scopes_overlap()` convention of returning the first match, not an exhaustive list, in both branches. |
| `collision_scope` | string | `defer_reason == "file_scope_collision"` only | `"in_batch"` (the colliding task is itself one of this invocation's candidate arguments) or `"cross_batch"` (it is not). Not present on `session_active` — the session-registry input has no in-batch/cross-batch distinction of its own (a session's covered task numbers are compared against D4's edge/liveness/self exclusions, not against invocation membership). |
| `corroborated_by` | array of strings | `defer_reason == "file_scope_collision"` only (NEW in v4) | Always contains `"non_terminal_status"` (the state.json signal that produced this verdict); additionally contains `"session_registry"` when a live, non-caller session independently covers the SAME colliding task number — evidentiary corroboration, not a second detection path. |
| `session_id` | string | `defer_reason == "session_active"` only (NEW in v4) | The contending session's own `session_id`. |
| `session_liveness_reason` | string | `defer_reason == "session_active"` only (NEW in v4) | One of `session_liveness()`'s six reasons (`task-lock.sh`) — always one of `pid-alive` / `dead-pid-within-grace` / `corrupt` / `undeterminable` here, since `dead-pid`/`stale-heartbeat` sessions are excluded by D4 before this verdict can fire. |
| `reason` | string | defer only | Machine-templated human-readable summary. Never the sole carrier of any fact already available as a structured field above. |
| `idle_overlap_advisory` | object | present on any post-scan verdict (`admit`, `session_active` defer, or `file_scope_collision` defer) when a suppressed idle cross-batch overlap exists; absent otherwise, and absent on all pre-scan branches (the three early-exit admits and both `self_modifying` branches) (NEW in v5) | Nested object surfacing a `cross_batch` overlap the collision scan found against a task carrying NO execution evidence (status not in `{researching, planning, implementing}`) and therefore did not block on. Nested keys: `colliding_task_number` (int), `colliding_task_status` (string, verbatim from `specs/state.json`), `overlapping_path` (string, first overlapping path), `collision_scope` (string, always `"cross_batch"` — `idle_overlap_advisory` is derived only from the `cross_batch`-scoped entries surviving the comparison scan; an `in_batch` overlap either IS the blocking `$hit` or is excluded from the scan entirely per the admitted-set-only narrowing below, and is never separately classified as idle), and `reason` (string, machine-templated, names the `dependencies[]`-edge remedy). First-match, ascending `project_number` — same determinism convention as the collision scan itself. |

## Precedence: Self-Modification, Then Collision, Then Session-Registry

The self-modification check runs FIRST and, when it fires (`self_modifying == true`),
SHORT-CIRCUITS both the collision scan AND the session-registry pass entirely — a self-modifying
candidate never also carries collision or session fields, regardless of whether it is deferred
(co-dispatch count > 1) or admitted solo (co-dispatch count == 1). Rationale, unchanged since v3:
self-mod is a pure single-candidate predicate (tests the candidate's own `file_scope` against a
static list) that is cheaper to evaluate than the collision scan's set comparison against every
other non-terminal task, and first-match determinism matches this script's existing "first hit
wins, no exhaustive collection" convention used elsewhere.

**NEW in v4**: when self-modification does not short-circuit, the file-scope collision scan runs
SECOND and, only when IT finds no hit, the session-registry pass runs THIRD
(`defer_reason == "session_active"`). This ordering is the load-bearing non-regression property
the v4 convergence plan asserts: every input that produced a `defer` verdict before v4 produces
the IDENTICAL defer verdict after v4, modulo the `$schema` string and the added `corroborated_by`
field — the new `session_active` flavor fires strictly where the pre-v4 predicate emitted `admit`.
The isolated-temp-root suite `scripts/test-conflict-predicate.sh` pins this invariant directly.

**A1 — dependency-edge exemption asymmetry, explained not remedied**: the collision dimension
exempts any `dependencies[]`-edge-connected task from its comparison set; the self-modification
dimension applies no equivalent exemption. This is deliberate: once `--invocation-count` is
same-cycle-scoped, an edge-connected pair can never share that count in the first place (the
calling skill's own eligibility rule guarantees a successor is never eligible in the same cycle as
its predecessor), so an explicit exemption in the self-mod branch would be unreachable dead code.
See `context/patterns/batch-orchestration-guardrails.md`'s "The Same-Cycle Narrowing and Its
Hazard Accounting" subsection for the full argument.

**The session-registry dimension's exemption rule is DIFFERENT from both of the above, not a
third instance of the same asymmetry (re-examined for v4, per D4 in the originating plan)**: it
DOES apply a dependency-edge exemption, but at a FINER grain than the collision dimension's
whole-task exemption — PER COVERED TASK NUMBER, not per session. A session entry is excluded from
contending against a candidate iff EVERY task number in its `task_numbers` array is either the
candidate itself or edge-connected to it; if the session covers even one task number that is
neither, the session contends (using the LOWEST such surviving number as `colliding_task_number`).
This is deliberately more conservative than a whole-session exemption would be: a session covering
`{edge-connected task, unrelated task}` is doing live work on the unrelated task that no
`dependencies[]` edge serializes, and the session's `file_scope` is a precomputed UNION that
cannot be attributed back to individual covered task numbers — so a whole-session exemption based
on ANY covered edge-connection would silently hide genuine contention on the unrelated task. The
self-modification dimension's "no exemption at all" and the collision dimension's "whole-task
exemption" are each correct for what they compare (a static list; another task's own single
declared scope, respectively) — the session dimension's finer per-number rule is correct for what
IT compares (a union across potentially many covered tasks), not a departure from either existing
precedent for its own sake.

## Deferral-Direction Rule and Caller Guidance

- **`defer_reason == "self_modifying"`**: the candidate's own `file_scope` names a declared
  orchestrator-critical path AND it is co-dispatched this wave/cycle alongside another candidate
  (`--invocation-count` > 1). The candidate is deferred out of the CURRENT wave/cycle — converging
  the same way an `in_batch` `file_scope_collision` defer already does — not excluded from the
  whole invocation. If the co-dispatch count is exactly one, the SAME hazardous candidate is
  instead `admit`ted with `self_modifying: true` still present (solo is still the desired outcome
  for orchestrator-critical work). The consumer (`skills/skill-orchestrate/SKILL.md` Stage MT-3
  step 4.5, covering both effort modes) may bypass acting on this verdict when
  `--allow-self-modifying` is active for the invocation — see "Why This Check Is Blocking, Not
  Advisory" below for the override's exact boundary.
- **`defer_reason == "file_scope_collision"`, `collision_scope == "in_batch"`** (NARROWED, still
  v5, no version bump — see "Version History" below): the colliding task is itself one of this
  invocation's candidate arguments, AND — as of this narrowing — that colliding task is ITSELF
  decided `admit` this cycle. A lower-numbered in-batch peer that is itself deferring (for any
  `defer_reason`) poses no concurrent-write hazard, since it never actually dispatches this
  cycle, and no longer blocks a higher-numbered candidate merely by appearing earlier in the
  invocation's argument list. This resolves by ordinary same-run deferral — the candidate is
  deferred to the next wave/cycle, same as the pre-existing invocation-scoped check already did.
  No special handling is required beyond what callers already implement for a same-batch
  collision.

  **Second consumer (recorded, not a schema change)**: `collision_scope == "in_batch"` now has a
  SECOND consumer beyond `skill-orchestrate/SKILL.md` Stage MT-3 step 4.5's multi-cycle
  re-sequencing loop — `commands/research.md`'s, `commands/plan.md`'s, and
  `commands/implement.md`'s Step 2.5/Step 3.5 plain-multi-task two-pass structure (see
  `context/patterns/task-lock.md`'s "Four-Tier Conflict Response" section, Tier 1, and
  `context/patterns/multi-task-operations.md`'s "5a. Batch Admission Pre-Check and Bounded Second
  Pass" section). The two consumers' caller-side handling of the SAME `in_batch` value differs
  materially: `skill-orchestrate`'s loop can retry the identical verdict across MANY cycles as
  tasks progress toward completion, while the plain-multi-task consumer is bounded to EXACTLY ONE
  extra pass before falling through to a `"deferred after second pass"` skip. The verdict schema
  itself is unchanged by this — `collision_scope`'s two values (`in_batch`/`cross_batch`) and
  their meaning are exactly as documented above — but a future change to this field's semantics
  (e.g. adding a third `collision_scope` value, or changing what `in_batch` means) now has a
  WIDER blast radius than before: it must be re-verified against both consumers, not just
  `skill-orchestrate`'s.
- **`defer_reason == "file_scope_collision"`, `collision_scope == "cross_batch"`** (NARROWED in
  v5): the colliding task is NOT one of this invocation's candidate arguments, AND it carries
  execution evidence — status in `{researching, planning, implementing}` (case-insensitive).
  Through v4 this defer fired unconditionally for any non-terminal cross-batch collision,
  regardless of the colliding task's status; as of v5 it fires only when the colliding task is
  actually in flight. This means the requested candidate is excluded from this invocation's
  admitted set and the colliding task is surfaced for human batch-composition judgment. This is
  explicitly **not** a correctness verdict on the candidate task, and explicitly **not** an
  instruction to fold the in-flight out-of-batch task into the run; a human resolves batch
  composition. When the colliding cross-batch task instead carries NO execution evidence, this
  script no longer defers at all — it admits the candidate with an `idle_overlap_advisory` (see
  the Field Definitions table above and the dedicated example verdict) rather than blocking
  permanently on a task that will never itself advance to resolve the collision.
- **`defer_reason == "session_active"`** (NEW in v4, reached only when the collision scan above
  found no hit): a live registered session's own unioned `file_scope` overlaps the candidate's,
  and the session is not excluded by D4's three exclusions (self-session-id, liveness,
  per-covered-task-number dependency edge — see the A1 discussion above). The candidate is
  deferred out of the CURRENT wave/cycle, converging the same way an `in_batch` collision defer
  already does — not a permanent whole-invocation exclusion. Requires the caller to have supplied
  `--session-id`; without it, this dimension is SKIPPED entirely via D6 degradation (below), never
  silently treated as "no contention found".

All four defer-verdict shapes above share the defer-not-fail invariant: a `defer` verdict never
marks the candidate task failed, and this script never writes to `specs/state.json` — it is a
pure, read-only predicate that only prints.

**Consumer requirement (since v2, unchanged by v3, extended by v4)**: any consumer that branches
on a `defer` verdict MUST check `defer_reason` before falling back to `collision_scope`-only
logic. A pre-v2 consumer that assumed every `defer` was a `file_scope_collision` and branched on
`collision_scope` alone would misread a `self_modifying` defer as an ordinary
`in_batch`/`cross_batch` collision (both carry a `reason` string, so the mistake would not
immediately surface as an error). A v2-aware consumer that still treats a `self_modifying` defer
as a permanent whole-invocation exclusion under v3 has a DIFFERENT, narrower mismatch — see
"Version History" below for the v3 entry's full account of why this required a schema version
bump rather than an additive field. **NEW in v4**: a consumer that branches on `defer_reason`
with an exhaustive `if self_modifying / else (assume file_scope_collision)` shape — rather than a
THIRD explicit branch or a safe default for an unrecognized value — will silently mis-bucket a
`session_active` verdict as a `file_scope_collision` and read undefined/absent fields
(`collision_scope`, `colliding_task_status`) from it. This was caught empirically during this
convergence: see `scripts/orchestrate-dry-run-report.sh`'s fix, recorded in the v4 consumer table
below.

## Why `--invocation-count` Exists

The sole live caller (`skills/skill-orchestrate/SKILL.md` Stage MT-3 step 4.5, the sole EXECUTING gate) dispatches in
wave/cycle-sized SUBSETS of the invocation's full candidate set — `wave_tasks` and
`eligible_tasks` respectively. As of v3, `--invocation-count` is evaluated against that SAME
subset — this cycle's actual co-dispatch count, not the whole invocation's full candidate count.
The v2 argument for whole-invocation scope ("the whole point is to keep orchestrator-critical
work from running alongside ANY sibling, not merely a same-wave one") is the exact claim v3
reverses: a `dependencies[]`-edge-connected pair can never co-occupy a wave/cycle in the first
place (the calling skill's own eligibility rule guarantees a successor is never eligible until
its predecessor terminates), so a whole-invocation count fires against pairs that never actually
co-occur in a dispatch batch. That was a pure false positive, not a safety margin.
`--invocation-count` still makes the co-dispatch count an explicit, required-by-convention input
rather than something this script would otherwise have to (incorrectly) infer from `argc`. Both
live call sites now pass `--invocation-count` set to the CURRENT wave/cycle's own size
(`${#wave_tasks[@]}` / `${#eligible_tasks[@]}`), never the whole invocation's full candidate
count.

Retained flag name (unchanged from v1/v2): `--invocation-count` keeps its original name even
though its documented semantics narrowed, because `scripts/orchestrate-dry-run-report.sh` and
`scripts/orchestrate-predispatch-review.sh` pass this flag by name; renaming it would make an
unrecognized flag fall through those callers' argument scans into positional validation, aborting
with exit 2. A `--codispatch-count` alias was considered and rejected as extra surface on
orchestrator-critical machinery for a naming-clarity improvement only.

**Convergence requirement on the SKILL.md caller — CHANGED IN v3**: under v2, because Stage MT-3
re-evaluates `eligible_tasks` every cycle, a `self_modifying` defer verdict had to be recorded in
an invocation-scoped EXCLUSION set (`deferred_self_modifying` in `mt_state_file`) that was
excluded from `eligible_tasks` on every subsequent cycle, or the same candidate would re-qualify
as eligible on the very next cycle and the check would re-fire forever. As of v3, the convergence
mechanism is different: `deferred_self_modifying` is now an APPEND-ONLY OBSERVATION LOG, not an
exclusion set, and the defer clears on its own once the co-dispatched sibling that caused it
leaves `eligible_tasks` by terminating or failing (a task no longer leaves `eligible_tasks`
merely by transitioning to an in-flight status — `researching`/`planning` — now that eligibility
is no longer status-gated; see `skills/skill-orchestrate/SKILL.md` Stage MT-3 step 3) — the loop's
existing per-cycle re-evaluation of `eligible_tasks` from current state already guarantees this,
the same convergence `file_scope_collision` already relies on. **Second, independent, per-cycle
exit condition, added by the designated-candidate tie-breaker and depending on no status
transition at all** (see the "Self-modification tie-breaker and `--phase-map`" paragraph under
"Invocation Contract" above): the tie-breaker admits exactly one self-modifying candidate — the
lowest task number — on EVERY cycle regardless of co-dispatch count, so N self-modifying
candidates converge to full dispatch in at most N cycles by construction; this is materially
stronger than the status-transition argument above and is what actually bounds the
multiple-self-modifying case. A bounded `consecutive_no_dispatch_cycles` counter backs the narrow
non-convergence mode still possible when NEITHER exit condition converges in time (e.g. a
tie-breaker defect), breaking the loop with `partial` status rather than silently spinning to
`MAX_CYCLES_MT`. The recurring-cycle shape is unique to the SKILL.md multi-task loop.

## Why This Check Is Evidence-Gated Between Blocking and Advisory

**Retitled in v5** (was "Why This Check Is Blocking, Not Advisory" — that title, and the
paragraph beneath it, asserted blanket blocking for the `cross_batch` case while simultaneously
conceding the colliding task "is not running", which is a self-contradiction. See the v5 Version
History entry below for the correction).

The imported criterion for the blocking-vs-advisory decision is: computable from on-disk state
alone, and the harm of skipping it is silent and hard to detect later. Three cases this script
implements satisfy that criterion and stay BLOCKING:

- An `in_batch` `file_scope` collision requires nothing but a read of `specs/state.json`, and if
  skipped, two sessions can concurrently edit the same files with no lock contention and no
  visible symptom until a merge conflict or a silently overwritten edit turns up much later.
- A `cross_batch` `file_scope` collision against a task carrying execution evidence (status in
  `{researching, planning, implementing}`) satisfies the same profile: that task IS actively
  running, so the concurrent-write hazard is real, not hypothetical.
- A self-modifying candidate's hazard requires nothing but a read of the candidate's own
  `file_scope` against a declared list, and if skipped, an unverifiable orchestrator-machinery
  fix can be bundled into a multi-task batch commit with no visible symptom until a later defect
  is traced back to it. This dimension is unaffected by the v5 narrowing below and keeps its own
  unconditional blocking profile regardless of any other task's status.

One case does NOT satisfy the criterion and is ADVISORY (**NEW in v5**): a `cross_batch`
`file_scope` collision against a task with NO execution evidence (`not_started`, `blocked`,
`partial`, `pr_ready`, or any other idle non-terminal status). There is no second session to
concurrently edit anything — the colliding task simply is not running — so nothing is lost by not
blocking on it today. The only real residual concern is ORDERING (should the candidate wait until
the idle task eventually runs?), and ordering is exactly what `dependencies[]` exists to express;
it is not a concurrent-write hazard and does not belong behind a defer that can never self-clear
until the idle task changes status on its own initiative. This case admits, and surfaces the
suppressed overlap loudly via `idle_overlap_advisory` (see the Field Definitions table above)
rather than silently dropping it.

A future maintainer who is tempted to relax the `in_batch` check, the in-flight `cross_batch`
check, or the self-modifying check to advisory after reading general literature on false
positives from coarse directory-prefix scope declarations should re-derive the criterion above
first: the false-positive cost for all three of those is a deferred task, not silent data loss,
and the two are not comparable. Those three checks stay blocking. This narrowing is
evidence-gating — does the colliding task carry proof of being in flight? — not batch-size-gating;
the comparison set and its size are unchanged, and the check runs identically at any batch size.
See `context/patterns/batch-orchestration-guardrails.md`'s "Batch-Size Scaling: Scope of
Deferral, Not Existence of the Check" section for the batch-size argument this is distinct from.

**The `--allow-self-modifying` override does not change this.** The check remains fully blocking;
this script always computes and emits the honest `self_modifying`/`defer_reason` verdict
regardless of the flag, and `--allow-self-modifying` is NEVER passed to
`orchestrate-batch-admit.sh`. The override is a CONSUMER decision, made at
`skills/skill-orchestrate/SKILL.md` Stage MT-3 step 4.5 (covering both effort modes), to not ACT
on an emitted `self_modifying` defer verdict — dispatching the
candidate this cycle anyway, with a loud bypass notice logged regardless of whether the gate
would otherwise have fired. It is never a change to this script's own output schema or blocking
behavior, and it defaults off (`"false"`), per-invocation only.

## Why `collision_scope`, Never `severity`

`severity` already carries two incompatible vocabularies in this codebase: `hard|soft` for
handoff blockers (see `handoff-schema.md`), and `critical|high|medium|low` for error/review
issues. Reusing that name here for a third, unrelated vocabulary (`in_batch|cross_batch`) would
collide with both existing meanings. `collision_scope` is a distinct field name for a distinct
concept — which side of the invocation boundary the colliding task falls on — and is not a
severity ranking at all. `defer_reason` is likewise a distinct field from both: it discriminates
which HAZARD DIMENSION fired, not which side of a boundary a collision falls on.

## Accepted False-Positive Profile

This script transcribes, and never restates or forks, the directory-prefix overlap predicate
defined once in `context/patterns/file-footprint-overlap.md`. That predicate is directory-prefix
matching only: a task declaring a whole directory as its `file_scope` will defer against
anything beneath it, with no glob/regex matching and no content-hash refinement. This cost is
accepted rather than engineered around — see that document's Non-Goals section for the full
rationale. `orchestrate-batch-admit.sh` is that document's fourth named consumer, alongside the
task-level, phase-level, and lock-acquisition-level callers already listed there. The
self-modification check is a FURTHER APPLICATION of the same predicate (candidate `file_scope`
vs. a static declared list, rather than vs. another task's `file_scope`) and inherits the same
false-positive profile — a candidate declaring a whole directory that happens to contain a
critical file will be flagged, with no finer-grained disambiguation.

## Degradation (D5): Visible, Never Silent

A missing, unreadable, or unparseable `orchestrator-critical-paths.json` does NOT disable the
self-modification check silently and does NOT abort the invocation. Instead:

- `self_modifying` is `null` on EVERY verdict for that invocation (never silently `false`, which
  would be indistinguishable from "checked and found non-hazardous").
- One loud `WARNING:` line goes to stderr naming the missing/unparseable file.
- The collision scan still runs unaffected — a degraded self-modification check does not
  degrade the rest of admission.
- `orchestrate-cycle-plan.sh` (live and `--dry-run` alike) relays this exact stderr `WARNING:`
  line unchanged, so a human reading either surface sees the degradation directly rather than
  inferring it from an absent exclusion.

## Degradation (D6, NEW in v4): `--session-id` Omitted, Visible, Never Silent

`--session-id` is OPTIONAL, not required — but omitting it is a deliberate, visibly-announced
degradation of the session-registry input, never a silent no-op:

- When omitted, `task-lock.sh session-list` is never invoked; the session array passed into the
  jq program is empty, so `session_contention()` can never fire and no `session_active` verdict
  is ever emitted for that invocation.
- One loud `WARNING:` line goes to stderr naming the skip and its consequence.
- The self-modification check and the collision scan both still run unaffected.
- **This prevents a fatal self-block, not merely an incomplete check.** Every caller in this
  repo wires this script's call IMMEDIATELY AFTER `task-lock.sh session-register`, so by the time
  this script runs, a session covering the entire candidate set — with their unioned `file_scope`
  — is ALREADY on disk. Without knowing its own session id, the script would see that
  just-registered session as foreign and defer every candidate in the batch against itself,
  deadlocking the whole invocation. Skipping the session input when identity is unknown is
  therefore the ONLY correct default; treating one's own session as foreign is a guaranteed
  deadlock, and silently including an unverified id would be worse than visibly skipping it.
  Every call site this repository wires (see the v4 consumer table below) passes `--session-id`.

## Version History

**v1** (original): `$schema`, `task_number`, `decision`, and the four `collision_scope`-defer
fields (`colliding_task_number`, `colliding_task_status`, `overlapping_path`, `collision_scope`)
plus `reason`. Every `defer` verdict was, by construction, a file-scope collision — there was
only one kind of defer, so no discriminator field existed.

**v2**: adds `self_modifying` (present on every verdict) and the self-modification
hazard dimension (`defer_reason`, `critical_path`, `critical_label` on a self-modifying defer;
`defer_reason` also added to the pre-existing collision defer, now valued
`"file_scope_collision"`). This was a VERSION BUMP, not an additive-field change, because a v1
consumer's `defer` handling assumed every defer was a collision and branched on
`collision_scope` alone; an unrecognized second defer flavor routed through that pre-v2 default
branch would be misread as an ordinary in-batch collision (a "retry next wave" outcome) rather
than the invocation-scoped exclusion it actually is — and since the self-modifying candidate's
own eligibility does not change on its own, that misread produces a non-converging retry loop,
never a merely incorrect one-off classification. All in-repo consumers (`skills/skill-orchestrate/SKILL.md`
Stage MT-3 step 4.5 and `scripts/orchestrate-dry-run-report.sh` Step 4) were updated to the v2 discriminator in the same
change that introduced it — there is no transitional period where v1 and v2 consumers coexist
against a v2 script.

**v3**: narrows the SEMANTIC of a `self_modifying` defer from a permanent
whole-invocation exclusion to a converging same-cycle defer (the `$schema` string, field set, and
key order are otherwise unchanged from v2 — no field was added or removed). This was a VERSION
BUMP rather than an additive-field change, for the same class of reason the v1-to-v2 bump was: a
v2-aware consumer still applying v2's permanent-exclusion handling to a v3 `self_modifying`
verdict would over-defer a task the v3 script expects to be retried next cycle once its
co-dispatched sibling clears — silently reintroducing a form of the original
whole-invocation-exclusion behavior the narrowing was meant to remove, via a stale consumer rather
than a script defect. `--invocation-count`'s documented contract also narrowed in the same
change (whole-invocation count to same-cycle co-dispatch count), and a new consumer-side
`--allow-self-modifying` override was added — never passed to this script, so it does not appear
in this schema.

Every in-repo consumer's status as of v3:

| Consumer | Status |
|---|---|
| `skills/skill-orchestrate/SKILL.md` Stage MT-3 step 4.5 | Updated — the sole EXECUTING gate |
| The former standalone hard-mode orchestrator's own `## Multi-Task Mode` transcription (file since deleted; the contract now lives solely in `skill-orchestrate/SKILL.md` above) | Updated at the time — explicit transcription added, closing a prior zero-reference gap |
| `scripts/orchestrate-dry-run-report.sh` Step 4 | Verified v3-compatible, NOT edited (outside this change's declared file scope) — pins no `$schema` string literal and already branches on `defer_reason` |
| `scripts/orchestrate-predispatch-review.sh` Classes C and D | Verified v3-compatible, NOT edited (outside this change's declared file scope) — pins no `$schema` string literal and already branches on `defer_reason` |

**Declared residual for the two verified-not-edited consumers**: both call this script once with
their whole candidate set rather than a same-cycle co-dispatch subset, so under the narrowed v3
semantics their existing exclusion-scope PROSE (describing a `self_modifying` defer as
whole-invocation) now over-states the live consequence. This is a recorded follow-up, not a
silent gap — see `context/patterns/batch-orchestration-guardrails.md`'s "Scope Limitation and
Residual Risk" section for the broader scope-boundary reasoning this residual sits alongside.

**v3 to v4**: converges the twice-transcribed overlap predicate into ONE shared
implementation (`scripts/lib/file-scope-overlap.sh`), and adds the session registry as a THIRD
bounded contention input, alongside held locks (unchanged — `task-lock.sh acquire` only) and
non-terminal `state.json` tasks (this script's pre-existing collision scan). Two additive changes
to the verdict shape: a NEW `defer_reason: "session_active"` (fields `session_id`,
`colliding_task_number`, `overlapping_path`, `session_liveness_reason`), reached only when the
collision scan finds no hit; and a NEW `corroborated_by` array on the existing
`file_scope_collision` verdict. This was a VERSION BUMP, not an additive-field change, for the
SAME class of reason the v1-to-v2 bump was: a v3-aware consumer that assumes `defer_reason` is a
CLOSED two-value set (`self_modifying` | `file_scope_collision`) and branches with an exhaustive
`if/else` rather than a third explicit case will mis-bucket a `session_active` verdict as a
`file_scope_collision` and read absent fields (`collision_scope`, `colliding_task_status`) from
it — exactly the `scripts/orchestrate-dry-run-report.sh` defect this convergence found and fixed
empirically (see the consumer table below), not merely a hypothetical risk. The non-regression
invariant (see "Precedence" above) is the property that makes this bump SAFE for the existing two
defer flavors specifically: every `defer` verdict a pre-v4 script produced is byte-for-byte
identical post-v4, modulo `$schema` and the added `corroborated_by` — so a v3-aware consumer that
DOES branch correctly on `defer_reason` (checking for an unrecognized value rather than assuming
exhaustiveness) needs no changes at all for its existing two branches to keep working; only the
NEW `session_active` branch is required to see the new input at all. `--session-id` was added as
an optional flag (D6); omitting it is a visible, per-invocation degradation, never a schema
change.

Every in-repo consumer's status as of v4:

| Consumer | Status |
|---|---|
| `skills/skill-orchestrate/SKILL.md` Stage MT-3 step 4.5 | Updated — the sole EXECUTING gate; gained `--session-id "$session_id"` AND a new explicit `session_active` defer_reason branch (append to `defer_ledger`, distinct warning) — without the latter, this consumer would have shared `orchestrate-dry-run-report.sh`'s mis-bucketing defect on the one path that actually ACTS on verdicts, not just reports them |
| The former standalone hard-mode orchestrator's own `## Multi-Task Mode` transcription (file since deleted; see the v3 row above) | Updated at the time — per this file's own explicit CO-MAINTENANCE requirement with the base skill's Stage MT-3 step 4.5, gained the same `--session-id "$session_id"` forwarding and `session_active` defer_reason branch |
| `scripts/orchestrate-dry-run-report.sh` Step 4 | Fixed (this convergence found a REAL bug, not a clean pass): the pre-v4 code checked `self_modifying` explicitly, then fell through UNCONDITIONALLY into `file_scope_collision` field reads — a `session_active` verdict would have been mis-bucketed as an in-batch wave-deferral Note instead of the Excluded entry it actually is. Added an explicit `session_active` branch, `--session-id` passthrough (forwarded to both its own `orchestrate-batch-admit.sh` call and its `orchestrate-predispatch-review.sh` subprocess call), and `corroborated_by` rendering |
| `scripts/orchestrate-predispatch-review.sh` Classes C and D | Extended, not merely re-verified: pinned no `$schema` literal and was already safe (its `select()`-based Class C/D filters simply do not match an unrecognized `defer_reason`, so a `session_active` verdict was inert rather than mis-bucketed). Gained a new Class E section re-presenting `session_active` verdicts, `corroborated_by` rendering on Class D, and an optional `--session-id` passthrough (forwarded only when the CALLER explicitly supplies it — this script's own pre-existing `--session-id` flag has an unrelated auto-generated-fallback purpose for `--repair`'s mutex attribution, and that fallback is deliberately never forwarded) |
| `scripts/orchestrate-triage-classify.sh` | Confirmed OUT OF SCOPE: re-checked during this convergence and confirmed it never subprocess-calls `orchestrate-batch-admit.sh` — it only names the script in a comment and has its own independent `orchestrate-triage-v1` schema |

No declared residual for v4: every listed consumer that consumes verdicts was either updated or
confirmed already-safe in this convergence pass, including the hard-mode transcription (updated
per its own co-maintenance requirement, not merely re-verified).

**v4 to v5** (current): narrows the `cross_batch` disjunct of the collision scan's `$hit`
selection to require execution evidence (status in `{researching, planning, implementing}`,
case-insensitive) on the colliding task. Through v4, ANY non-terminal cross-batch collision
deferred unconditionally, regardless of the colliding task's status — a broad-scope `not_started`
task could become a permanent, never-self-clearing blocker on every candidate that overlapped it,
since an idle task never advances on its own to resolve the collision. As of v5, a `cross_batch`
collision against a provably idle task (no execution evidence) no longer defers: it admits, and
the suppressed overlap is surfaced via a NEW `idle_overlap_advisory` field (present on any
post-scan verdict — the plain `admit`, the `session_active` defer, or the `file_scope_collision`
defer — wherever an idle cross_batch overlap was found and suppressed; see the Field Definitions
table above). `in_batch` collision behavior is completely unaffected by THIS bump — it stays
blocking and bit-for-bit identical, since every `in_batch` candidate is, by construction,
imminently dispatched regardless of the colliding task's status. (This "imminently dispatched"
premise was itself narrowed by a LATER, still-v5, no-version-bump change — an `in_batch` peer that
is itself deferring is not imminently dispatched after all — see the "admitted-set-only in-batch
narrowing" Version History entry below for the full account; that later change does not revise
this entry's own v4-to-v5 scope, which remains accurate as stated for the narrowing this entry
describes.)

This was a VERSION BUMP, not an additive-field change, for a DIFFERENT class of reason than the
v1-to-v2 or v3-to-v4 bumps (those were about a NEW defer flavor being mis-bucketed by a closed
`if/else`; this one is about an EXISTING defer flavor silently disappearing for a subset of its
former inputs): a v4-aware consumer branching on `decision` alone will read a `cross_batch`
idle-overlap `admit` as an unqualified all-clear and will not know to look for
`idle_overlap_advisory`, silently losing the very signal this narrowing exists to make loud; and a
v4-aware consumer's `defer_reason == "file_scope_collision"` handling simply never sees the idle
`cross_batch` case at all post-v5, where it previously always did. Both are silent behavior
changes from a stale consumer's point of view, not merely an unrecognized new field to ignore
safely — the same bar every prior bump in this history applied.

**Accepted discriminator change beyond the headline narrowing**: when a candidate overlaps both a
lower-numbered idle `cross_batch` task and a higher-scanned `in_batch` task, the pre-v5 predicate
emitted the `cross_batch` defer (first in ascending `project_number` order); the v5 predicate
emits the `in_batch` defer instead, because the idle `cross_batch` member is no longer eligible
for `$hit` at all. The decision is `defer` either way — only which collision the verdict names
changes. This is accepted as correct and intended, not a regression: the candidate must still wait
either way, and `in_batch` is the discriminator that actually causes the wait, so naming it is
more accurate, not less.

**Consumers updated by this bump — none**: no `defer_reason`-branching consumer
(`scripts/orchestrate-dry-run-report.sh`, `scripts/orchestrate-predispatch-review.sh`,
`skills/skill-orchestrate/SKILL.md` Stage MT-3 step 4.5, covering both effort modes) is updated by
this change — that consumer-side work is a separate, later
change with its own declared file scope. **Declared residual for v5**: every listed consumer above
still reads `idle_overlap_advisory` as an unrecognized field it silently ignores (never an error),
which is safe but incomplete — none of them yet surfaces the advisory to a human or a report. This
is a recorded, intentional residual, not a silent gap.

**Self-modification tie-breaker and `--phase-map` — NOT a version bump (schema stays v5)**: adds
the designated-candidate tie-breaker and the optional `--phase-map` argument (see "Invocation
Contract" above for both). This is a DIFFERENT class of change from every prior bump in this
history, and deliberately does not bump `$schema`: every prior bump (v1-v2, v3-v4, v4-v5) was
about a stale consumer either mis-bucketing an unrecognized NEW verdict shape into an existing
`if/else` branch, or silently losing a signal carried on a NEW field it does not know to look
for. This change adds neither. It reassigns which of the two ALREADY-EXISTING self-modifying
verdict shapes (the plain `admit` with `self_modifying: true`, or the `defer` with
`defer_reason: "self_modifying"`) a given candidate lands in, using criteria a consumer never
needs to inspect — the consumer already branches on `decision` and `defer_reason`, not on which
candidate produced which shape or why. The only content-level change is the human-readable
`reason` string's wording on a tie-breaker `defer`, and `reason` is documented above as "Never
the sole carrier of any fact already available as a structured field" — no consumer parses it
structurally. A consumer that omits `--phase-map` and never passes `--invocation-count` in a way
that changes its own co-dispatch semantics sees a real behavior change (the previously-lowest
self-modifying candidate among 2+ co-dispatched ones now admits instead of defers) but no
verdict-shape surprise: every field it already reads is present with its already-documented
type and meaning. Every in-repo consumer's status: unaffected by the tie-breaker itself (no
consumer code needs to change to remain correct); the SKILL.md consumers additionally gain
`--phase-map` wiring and updated warning/diagnostic text as a separate, later change with its
own declared file scope (see `context/patterns/batch-orchestration-guardrails.md`'s gate
catalogue for the resulting classification of `self_modifying` as an ordering constraint).

**Admitted-set-only in-batch narrowing — NOT a version bump (schema stays v5)**: converts the
top-level candidate generator into a `reduce` that folds candidates in ASCENDING `project_number`
order, threading a running admitted-set lookup that narrows the `in_batch` disjunct of the
collision scan's overlap predicate. Before this change, an `in_batch` collision blocked a
candidate against ANY lower-numbered peer that merely appeared in the invocation's argument list,
regardless of that peer's own verdict — including a peer that was itself deferring (for
`file_scope_collision`, `self_modifying`, or `session_active`) and therefore never actually
dispatching this cycle. As of this narrowing, an `in_batch` collision blocks the candidate only
when the lower-numbered peer is ITSELF decided `admit` this cycle; a deferring peer poses no
concurrent-write hazard and no longer blocks a higher-numbered candidate merely by sharing
project_number ordering and file_scope overlap. This is the SAME class of change as the
self-modification tie-breaker entry immediately above, and deliberately does not bump `$schema`
for the identical reason: it adds no new field and no new verdict shape. It reassigns which of
the two ALREADY-EXISTING `file_scope_collision`-adjacent shapes (`admit`, or `defer` with
`defer_reason: "file_scope_collision"` and `collision_scope: "in_batch"`) a given in-batch
candidate lands in, using an internal criterion (a lower-numbered peer's own already-folded
decision) that no consumer inspects — every consumer already branches on `decision` and
`defer_reason`/`collision_scope` only, never on why a lower-numbered peer was or was not admitted.
Decision computation order (ascending `project_number`) and NDJSON emission order (original
caller-argument order) are two independent orderings, both preserved — see the "Two independent
orderings" paragraph under "Invocation Contract" above. `cross_batch`, `session_active`,
`idle_overlap_advisory`, and the self-modification branch (including the tie-breaker and
`--phase-map` exemption above) are unaffected: only the `in_batch` disjunct of the collision
predicate changed. Every in-repo consumer's status: unaffected (no consumer code needs to change
to remain correct — this purely reduces the frequency of a `defer` verdict a consumer already
knows how to handle, it never introduces a verdict shape a consumer has not seen before).
