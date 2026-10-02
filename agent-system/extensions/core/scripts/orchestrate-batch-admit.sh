#!/usr/bin/env bash
# orchestrate-batch-admit.sh — Cross-batch file_scope admission predicate for /orchestrate.
#
# Purpose: the three existing file_scope overlap checks (task-creation-time pairwise
# comparison, phase-level parallel-dispatch comparison, and task-lock.sh's currently-held-lock
# comparison) each scope their comparison to a fixed, already-collected set — a creation batch,
# a task's phase list, or the locks presently held. None of them compares a candidate task
# against every OTHER non-terminal task sitting idle in specs/state.json outside the current
# invocation's batch and outside any held lock. This script closes that gap: it is a read-only,
# blocking (defer-not-fail) predicate that, for each candidate task number, checks its declared
# file_scope against every non-terminal task in specs/state.json — not just the tasks in this
# invocation, and not just the tasks currently holding a lock.
#
# A FOURTH, orthogonal dimension is layered on top of the cross-batch collision check above: the
# self-modification hazard check. Before the collision scan runs at all, this script tests
# whether the candidate's OWN file_scope names a file on a fixed, declared list of
# orchestrator-critical paths (context/reference/orchestrator-critical-paths.json). If it does,
# and this invocation carries more than one CO-DISPATCHED candidate (see the `--invocation-count`
# contract below), the candidate is deferred out of the CURRENT wave/cycle — converging the same
# way a `file_scope_collision` defer already does — so orchestrator-machinery work never actually
# runs concurrently with another candidate. See context/patterns/batch-orchestration-guardrails.md's
# "Self-Modification Hazard: The Fourth Admission Dimension" section for the two-test rationale
# (reachability + decision-relevance) behind the declared list, and
# docs/architecture/batch-admit-schema.md for the full verdict schema this check adds.
#
# Canonical predicate: this script SPLICES, and never restates or forks, the directory-prefix
# overlap algorithm defined once in context/patterns/file-footprint-overlap.md and implemented
# once in scripts/lib/file-scope-overlap.sh ($FILE_SCOPE_OVERLAP_JQ_DEFS -- norm,
# scopes_overlap_first, self_mod_match, edge_connected_nums, session_contention). See that
# document for the normalization rule
# (rtrimstr("/")) and the three-way overlap test (exact match, or either path a directory-prefix
# ancestor of the other). This script is that document's fourth named consumer, alongside the
# task-level, phase-level, and lock-acquisition-level callers already listed there. It mirrors
# scripts/task-lock.sh's scopes_overlap() exactly because both splice the SAME shared defs, not
# because the two are independently kept in sync. The self-modification check above is a FURTHER
# APPLICATION of the same predicate — the candidate's own file_scope compared against a static
# declared list rather than against another task's file_scope — not a new matching rule.
#
# Usage:
#   orchestrate-batch-admit.sh [--invocation-count <N>] [--session-id <id>] [--phase-map <map>] <task_number> [<task_number> ...]
#
# `--session-id <id>` (D6): the CALLER's own session id (the same id registered via
# `task-lock.sh session-register`). When supplied, this script's session-registry contention
# input (the third bounded input, alongside held locks (consumed only by task-lock.sh acquire)
# and non-terminal state.json tasks) is active, with self-exclusion against this id. When
# OMITTED, the session input is SKIPPED entirely and one loud line goes to stderr naming the
# skip and its consequence -- this prevents a fatal self-block: Gap C wires this script's call
# immediately AFTER `session-register`, so a session covering the entire candidate set is already
# on disk by the time this script runs; without knowing its own session id it would see that
# session as foreign and defer every candidate against itself. Every call site this repo wires
# passes `--session-id`; see context/patterns/batch-orchestration-guardrails.md for the full
# degradation contract.
#
# `--invocation-count <N>` (D3): the number of candidates being CO-DISPATCHED IN THE SAME
# wave/cycle as the positional <task_number> arguments — not the whole invocation's total
# candidate count. Callers that pass a wave/cycle subset (wave_tasks, eligible_tasks) MUST pass
# that subset's own size here, not the invocation's full validated-candidate count, or the
# self-modification defer trigger over-fires against candidates that never actually co-occur in a
# dispatch batch (see the file-top paragraph above and the Precedence (D4) block below for why a
# whole-invocation count is wrong). Defaults to the number of positional <task_number> arguments
# when omitted (backward-compatible: correct for any caller that already passes its own
# co-dispatch set in one call). A non-integer value is a usage error, same as a non-integer
# task_number.
#
# Flag name retained (not renamed): `--invocation-count` keeps its original name even though its
# documented semantics narrowed from "whole invocation" to "same-cycle co-dispatch count", because
# two out-of-scope callers — scripts/orchestrate-cycle-plan.sh (both its live and --dry-run
# paths) and scripts/orchestrate-predispatch-review.sh — pass this flag BY NAME. Renaming it
# would make an unrecognized `--invocation-count` fall through those callers' argument scans into positional
# validation, aborting with exit 2. A `--codispatch-count` alias was considered and rejected: it
# would add a second flag name to orchestrator-critical machinery for a naming-clarity improvement
# only, with no behavioral benefit over documenting the narrowed meaning under the existing name.
#
# `--phase-map <task:group[,task:group...]>` (D-phase, NEW): OPTIONAL. Maps a subset of the
# positional <task_number> candidates to the dispatch phase group they would run under this
# cycle (e.g. "research", "plan", "implement") -- the same group vocabulary
# scripts/orchestrate-triage-classify.sh already emits. When a candidate named in the map is
# self-modifying AND its mapped group is "research" or "plan", the self-modification defer branch
# is skipped UNCONDITIONALLY for that candidate (regardless of --invocation-count and regardless
# of the tie-breaker below) -- a research or plan dispatch touches only the task's own reports/ or
# plans/ subdirectory plus its own .return-meta.json/.orchestrator-handoff.json, never
# orchestrator machinery, so gating it on the task's IMPLEMENTATION footprint is a pure false
# positive. `self_modifying: true` still appears on the verdict (the hazard stays visible even
# when not deferred, same "solo admit" convention already used below). A candidate ABSENT from
# the map, or mapped to any other group (including "implement"), is unaffected and falls through
# to the ordinary self-mod branch. Omitting `--phase-map` entirely preserves today's behavior
# exactly -- no candidate is phase-exempted, byte-for-byte identical to a pre-D-phase invocation.
# Malformed values (anything not matching `task:group[,task:group...]` with integer tasks and
# alphabetic-or-underscore group names) are a usage error (exit 2), same posture as
# `--invocation-count`.
#
# Self-modification tie-breaker (D-tiebreak, NEW): among THIS cycle's candidates, the LOWEST
# task number whose own file_scope matches a declared critical path is the DESIGNATED
# self-modifying candidate -- the same ascending-project_number-first-match determinism
# convention the `in_batch` deferral direction already uses (see "Determinism" below) and the
# same first-match convention the self-modification check itself already used for selecting
# WHICH critical-path entry matched. The designated candidate is never deferred by the
# self-modification branch, regardless of `--invocation-count`; every OTHER self-modifying
# candidate this cycle still defers when `--invocation-count` > 1, exactly as before. This
# converges N co-dispatched self-modifying candidates into a deterministic per-cycle sequence
# (lowest number first, then re-evaluated next cycle) instead of every one of them deferring
# forever because none is ever alone -- the prior deadlock this fixes. The verdict's `reason`
# string on a tie-breaker defer names the designated candidate and states this is a one-cycle
# ordering constraint that resolves once the designated candidate clears -- never an operator
# instruction to isolate the dispatch by itself.
#
# Output: NDJSON on stdout, one compact JSON object per candidate, in input order. Verdict
# schema (pinned as "orchestrate-batch-admit-v6"; field order is stable):
#
#   $schema                 string   Literal "orchestrate-batch-admit-v6".
#   task_number              int     The candidate task number, echoed back.
#   decision                 string  "admit" or "defer". Never "fail" — a candidate this script
#                                     cannot resolve (unknown task, terminal status, empty/null
#                                     file_scope) is admitted, not failed; only a usage error or
#                                     unavailable state.json aborts the whole invocation (exit 2,
#                                     no verdicts at all).
#   self_modifying            bool|null  Present on EVERY verdict, including "admit". `true` when
#                                     the candidate's own file_scope names a declared
#                                     orchestrator-critical path; `false` when it does not;
#                                     `null` when the critical-path data file is missing or
#                                     unparseable (degraded — see below). A solo admitted run of
#                                     a self-modifying candidate still carries `true` here, so
#                                     the hazard stays visible even when it is not deferred.
#   defer_reason              string  Present only when decision == "defer". Exactly one of
#                                     "self_modifying", "file_scope_collision", "session_active"
#                                     (NEW in v4), or "absent_file_scope" (NEW in v6) — REQUIRED
#                                     discriminator. Existing consumers MUST branch on this field
#                                     before falling into any pre-v2 default handling. Every defer
#                                     reason is wave/cycle-scoped (none is a whole-invocation
#                                     exclusion); the discriminator exists to name the HAZARD
#                                     behind the defer and select the operator remedy
#                                     (self_modifying's remedy is the `--allow-self-modifying`
#                                     override; file_scope_collision, session_active, and
#                                     absent_file_scope have none — see
#                                     docs/architecture/batch-admit-schema.md).
#   critical_path              string Present only when defer_reason == "self_modifying". The
#                                     matched declared critical path (post scope-root expansion).
#   critical_label              string Present only when defer_reason == "self_modifying". The
#                                     matched entry's short label, from the critical-paths data
#                                     file.
#   colliding_task_number     int    Present when defer_reason == "file_scope_collision" (the
#                                     other task's project_number, from state.json) OR
#                                     defer_reason == "session_active" (the lowest non-excluded
#                                     task number the contending session covers, per D4).
#   colliding_task_status     string Present only when defer_reason == "file_scope_collision".
#                                     The other task's status string, verbatim from state.json.
#   overlapping_path          string Present when defer_reason == "file_scope_collision" (the
#                                     first overlapping path, taken from the COLLIDING task's
#                                     declared file_scope) OR defer_reason == "session_active"
#                                     (the first overlapping path from the contending session's
#                                     own precomputed file_scope) — first match, not an
#                                     exhaustive list, matching scopes_overlap()'s convention in
#                                     task-lock.sh.
#   collision_scope            string Present only when defer_reason == "file_scope_collision".
#                                     "in_batch" (the colliding task is itself one of this
#                                     invocation's candidate arguments) or "cross_batch" (it is
#                                     not).
#   corroborated_by      array[string]  Present only when defer_reason == "file_scope_collision"
#                                     (NEW in v4). Always contains "non_terminal_status" (the
#                                     state.json signal that produced this verdict); additionally
#                                     contains "session_registry" when a live, non-caller session
#                                     independently covers the SAME colliding task number —
#                                     evidentiary corroboration, not a second detection path.
#   session_id                string Present only when defer_reason == "session_active" (NEW in
#                                     v4). The contending session's own session_id.
#   session_liveness_reason   string Present only when defer_reason == "session_active" (NEW in
#                                     v4). One of session_liveness()'s six reasons (task-lock.sh)
#                                     — always one of pid-alive / dead-pid-within-grace / corrupt /
#                                     undeterminable here, since dead-pid/stale-heartbeat sessions
#                                     are excluded by D4 before this verdict can fire.
#   designated_absent_candidate int   Present only when defer_reason == "absent_file_scope" (NEW
#                                     in v6). The lowest task number among this cycle's
#                                     absent-scope candidates — the peer that admits this cycle in
#                                     this candidate's place. Deliberately NO
#                                     colliding_task_number/colliding_task_status/overlapping_path/
#                                     collision_scope/corroborated_by on this defer: there is no
#                                     colliding task and no overlapping path (this is MISSING
#                                     information, not a detected conflict), so this value is its
#                                     own field rather than overloading file_scope_collision's
#                                     shape with fields that would all be present-but-empty.
#   reason                    string Present only when decision == "defer". Machine-templated
#                                     human-readable summary; never the sole carrier of any fact
#                                     already present as a structured field above.
#   idle_overlap_advisory     object Present on ANY post-scan verdict (the plain "admit", the
#                                     "session_active" defer, or the "file_scope_collision" defer)
#                                     (NEW in v5) whenever the collision scan found a cross_batch
#                                     overlap against a task with NO execution evidence (status not
#                                     in {researching, planning, implementing}) that this script
#                                     suppressed from blocking. Absent when no such idle overlap
#                                     exists, and structurally absent on the three early-exit admit
#                                     branches (unknown task / terminal status / empty file_scope)
#                                     and both self_modifying branches, none of which reach the
#                                     collision scan. Nested keys (first-match, ascending
#                                     project_number, same convention as the collision scan itself):
#                                     colliding_task_number (int), colliding_task_status (string,
#                                     verbatim from state.json), overlapping_path (string, first
#                                     overlapping path), collision_scope (string, always
#                                     "cross_batch" here — an idle in_batch overlap cannot occur,
#                                     see the narrowed deferral-direction rule below), and reason
#                                     (string, machine-templated, names the remedy: add a
#                                     dependencies[] edge if ordering between the two tasks
#                                     matters). See docs/architecture/batch-admit-schema.md for the
#                                     full field table and an example verdict.
#   absent_scope_advisory      object Present on EVERY verdict the absent-scope early-exit branch
#                                     produces (NEW), i.e. whenever a candidate's own file_scope
#                                     is absent (missing key, literal null, or empty array).
#                                     Carried regardless of decision — this field is purely
#                                     informational; see "Admission Posture for an ABSENT
#                                     file_scope" below for the full blocking-vs-advisory ruling
#                                     by scope kind. Absent on every other branch (unknown task,
#                                     terminal status, self-modifying, non-empty file_scope).
#                                     Nested keys: scope_state (string, one of "missing_key" |
#                                     "null_value" | "empty_array" — reuses
#                                     validate-state.sh Check 10's own vocabulary verbatim, never a
#                                     fourth spelling), codispatch_count (int, this invocation's
#                                     --invocation-count value), and reason (string,
#                                     machine-templated, names the remedy: declare a file_scope, or
#                                     run plan-file-scope-harvest.sh / backfill-file-scope.sh once a
#                                     plan exists).
#
# Admission Posture for an ABSENT file_scope (ruling, measured 2026-09-29; this is a decision
# record, not a defect description — read alongside the defer_reason field above): an undeclared
# file_scope is NOT treated identically in every comparison direction. The posture is SPLIT by
# scope kind, decided by measurement rather than preference:
#
#   - cross_batch (the comparison task is NOT one of this invocation's candidate arguments):
#     ADVISORY ONLY, via the additive absent_scope_advisory field above — NEVER blocks admission
#     on absence alone. THE TRADEOFF (stated explicitly, per this codebase's own advisory-first
#     precedent — see plan-format.md's Verification Tier rollout): treating absence as a defer
#     reason closes the silent-passage hole this check exists to close, but risks blocking
#     legitimate work on legacy tasks that predate any file_scope discipline. The softer posture
#     is chosen here because that risk is NOT yet mitigated at the coverage level this script's
#     other blocking checks require (computable-from-on-disk-state AND low false-positive cost —
#     see "Why This Check Is Evidence-Gated..." below): a live coverage measurement
#     (`validate-state.sh --strict` Check 10's own missing_key/null_value finding count against
#     non-terminal, plan-bearing tasks, re-derivable with that same command) found the backfill
#     mitigation this ruling was gated behind has NOT landed uniformly across the repositories
#     this system deploys into, measured 2026-09-29: this repository 27/28 (96%), a second
#     deployment repository 32/33 (97%), but the THIRD deployment repository where the
#     motivating harm was observed live only 18/43 (42%) covered, with 24 of the 25 gaps being
#     plan-less tasks that backfill-file-scope.sh correctly, by design, leaves absent. Tightening
#     cross-batch absence to blocking today would silently stall legitimate legacy work in
#     exactly the repository the motivating harm came from.
#
#     PROMOTION CRITERION (recorded now; NOT performed by this version — mirrors
#     plan-format.md's Verification Tier rollout wording, "this task does NOT perform the
#     promotion"): promote cross-batch absence from absent_scope_advisory to a blocking
#     defer_reason (the same "absent_file_scope" value the in_batch case below already uses) once
#     `bash .claude/scripts/validate-state.sh --strict` reports ZERO Check 10
#     missing_key/null_value findings across every repository this system deploys into.
#     Re-derive that coverage measurement before ever flipping this ruling — do not promote on
#     elapsed time or on a single repository's local coverage alone.
#
#   - in_batch (the comparison task IS one of this invocation's candidate arguments): BLOCKING,
#     via the "absent_file_scope" defer_reason (see the defer_reason field above and the
#     Deferral-Direction Rule below for its full payload and override semantics). In-batch
#     absence is EXEMPT from the coverage reasoning above entirely: it only ever concerns
#     candidates being CO-DISPATCHED THIS CYCLE, so legacy-backlog coverage elsewhere in
#     specs/state.json is irrelevant to it. The cost/benefit is also inverted from the
#     cross-batch case: the cost of wrongly serializing an in-batch absent-scope candidate is one
#     extra cycle (identical in shape to this script's existing self_modifying tie-breaker cost),
#     while the cost of wrongly admitting all of them was, measured live, concurrent edits to a
#     shared orchestrator-critical gate script plus concurrent certificate-regenerating gate runs
#     across eight co-dispatched candidates with zero collision-guard coverage — the guard was
#     never consulted, not merely wrong, because an absent scope gave it nothing to compare. See
#     context/patterns/batch-orchestration-guardrails.md's absent-scope posture subsection for
#     the full incident narrative behind both halves of this ruling.
#
# Precedence (D4): self-modification runs FIRST and SHORT-CIRCUITS the rest — a self-modifying
# candidate never runs the collision scan or the session pass, regardless of whether it is
# deferred (co-dispatch count > 1) or admitted solo (co-dispatch count == 1). Rationale,
# unchanged since v3: self-mod is a pure single-candidate predicate (tests the candidate's own
# file_scope against a static list) that is cheaper to evaluate than the collision scan's set
# comparison against every other non-terminal task, and first-match determinism matches this
# script's existing "first hit wins, no exhaustive collection" convention. NEW in v4: when
# self-modification does not short-circuit, the state.json collision scan
# (`file_scope_collision`) runs SECOND and, only when IT finds no hit, the session-registry pass
# (`session_active`) runs THIRD. This ordering is the load-bearing non-regression invariant this
# convergence's plan calls out explicitly: every input that produced a `defer` verdict before v4
# produces the IDENTICAL defer verdict after v4, modulo the `$schema` string and the added
# `corroborated_by` field — the new `session_active` flavor fires strictly where the pre-v4
# predicate emitted `admit`.
#
# NEW in v6: the absent-scope branch (empty/null/missing file_scope) resolves BEFORE the
# self-modification check — it already did, structurally, since an empty file_scope can match no
# critical path — so `absent_file_scope` and `self_modifying` are MUTUALLY EXCLUSIVE BY
# CONSTRUCTION: no verdict ever carries both a `defer_reason: "absent_file_scope"` and
# `self_modifying: true`, and no candidate reaching the `absent_file_scope` branch ever also runs
# the collision scan or the session-registry pass this cycle (the absent-scope branch's own
# `if`/`elif`/`else` fully resolves the verdict without falling through to any of them). Stated
# explicitly here rather than left to be inferred from branch order alone.
#
# Held-lock scan rejection (recorded, not the file's pre-existing D5 above — this convergence's
# OWN separate decision not to add a fourth contention input): `orchestrate-batch-admit.sh` does
# NOT gain a held-lock scan. Held locks supply no `file_scope` of their own (`holder.json`
# carries none — task-lock.sh's own overlap check always re-fetches the other side's scope from
# state.json), so a held-lock scan here could produce no detection the state.json/session-registry
# inputs do not already produce, at the cost of a repo-wide filesystem walk of every `.lock/`
# directory — directly contradicting this script's own "no repo-wide filesystem walk of any
# kind" invariant. Held locks stay a task-lock.sh-acquire-only input.
#
# A1 (dependency-edge exemption asymmetry) — explained, not remedied: the collision dimension
# excludes from its comparison set any task connected to the candidate by a dependencies[] edge in
# EITHER direction (see the "Comparison set for the collision scan" paragraph below). The
# self-modification dimension applies no equivalent exemption, and this is deliberate, not an
# oversight. Once `--invocation-count` is same-cycle-scoped (D3 above), an edge-connected pair can
# NEVER share that count in the first place — Stage MT-3 step 3's eligibility rule in
# skills/skill-orchestrate/SKILL.md makes it structurally impossible for a `dependencies[]`-edge
# predecessor/successor pair to occupy the same `eligible_tasks` batch, because the successor is
# never eligible until the predecessor leaves the non-terminal set. An explicit dependency-edge
# exemption in the self-mod branch would therefore be unreachable dead code: the condition it
# would guard against (an edge-connected pair sharing a co-dispatch count) cannot occur. The
# asymmetry between the two dimensions is real but load-bearing only on the collision side, whose
# comparison set spans every non-terminal task in state — including ones far outside the current
# wave/cycle — where an edge-connected pair CAN and does otherwise collide.
#
# Degradation (D5): a missing, unreadable, or unparseable critical-path data file does NOT exit
# non-zero and does NOT disable the rest of admission — it sets self_modifying: null on every
# verdict, prints one loud line to stderr, and falls through to the ordinary collision scan
# unaffected. Silent disablement (returning false as if no candidate were ever self-modifying) is
# the one behavior this script must never produce for a degraded data file.
#
# Degenerate candidates (self_modifying still computed per the rule above; decision resolves to a
# plain "admit" verdict with no collision fields in the FIRST two cases below, exactly as in v1
# — the THIRD case gained its own blocking posture in v6, see "Admission Posture for an ABSENT
# file_scope" above):
#   - task_number absent from active_projects (unknown task) — self_modifying: false (no
#     file_scope to test) unless degraded, then null.
#   - task_number's status is terminal (completed, abandoned, expanded — case-insensitive) — the
#     candidate's own file_scope is still tested against the critical-path list (so a terminal
#     candidate that WOULD be self-modifying is still visible in the verdict), but a terminal
#     candidate is never deferred by this script — it will not be dispatched regardless.
#   - task_number's file_scope is null, missing, or an empty array — self_modifying: false
#     (trivially no scope to match) unless degraded, then null; decision is "admit" carrying
#     absent_scope_advisory for a cross_batch comparison, or (NEW in v6) "defer" with
#     defer_reason "absent_file_scope" for an in_batch comparison when this candidate is not this
#     cycle's designated absent-scope candidate and is not phase-exempt — see the ruling above.
#
# Comparison set for the collision scan (per candidate, only reached when self_modifying is not
# true): every entry in active_projects whose status is NOT one of {completed, abandoned,
# expanded} (case-insensitive, so "PR READY" / "Completed" etc. are all handled), excluding the
# candidate itself, per rules/state-management.md's terminal-state list (Terminal states:
# [COMPLETED], [ABANDONED], [EXPANDED]) — every other status (not_started, researching,
# researched, planning, planned, implementing, partial, pr_ready/"PR READY", blocked) is
# compared. Any task connected to the candidate by a dependencies[] edge in EITHER direction
# (candidate depends on it, or it depends on candidate) is excluded from the comparison set
# entirely — an explicit dependency edge already serializes that pair.
#
# Deferral-direction rule for file_scope_collision (this is the load-bearing semantic, read
# carefully):
#   - in_batch (the colliding task is itself one of this invocation's <task_number> arguments):
#     the candidate defers ONLY against a task with a LOWER project_number that is ITSELF admitted
#     this cycle (NARROWED, still v5, no version bump -- see docs/architecture/batch-admit-schema.md's
#     Version History for the full record). A higher-numbered in-batch task defers instead only
#     when the lower-numbered peer actually admits; when the lower-numbered peer itself defers (for
#     any reason -- file_scope_collision, self_modifying, or session_active), it poses no
#     concurrent-write hazard (it never dispatches this cycle) and no longer blocks a
#     higher-numbered peer merely by sharing project_number ordering and file_scope overlap.
#   - cross_batch (the colliding task is NOT one of this invocation's arguments): the candidate
#     defers ONLY while the colliding task carries execution evidence — status in
#     {researching, planning, implementing} (case-insensitive; NARROWED in v5, was
#     "unconditionally, regardless of project_number ordering" through v4). An out-of-batch task
#     cannot itself be deferred by an invocation it is not part of, so there is still no symmetric
#     "the other one defers instead" outcome available — but a cross_batch task that is provably
#     IDLE (no execution evidence: not_started, blocked, partial, pr_ready, or any other
#     non-in-flight non-terminal status) is no longer able to permanently block a candidate merely
#     by sitting in state.json. An idle cross_batch overlap now ADMITS instead, carrying a loud
#     idle_overlap_advisory (see the field list above) rather than silently vanishing. This is
#     evidence-gating, not batch-size-gating: the check still runs the full comparison set at any
#     batch size, and an idle overlap discovered in a batch of one behaves identically to one
#     discovered in a batch of fifty.
#
# Deferral rule for absent_file_scope (NEW in v6 — a DIFFERENT kind of fact from
# file_scope_collision above, read carefully): an absent file_scope has NO colliding task and NO
# overlapping path to name — this is MISSING information, not a detected conflict — so it does
# not reuse file_scope_collision's payload shape (which would leave colliding_task_number,
# colliding_task_status, overlapping_path, collision_scope, and corroborated_by all
# present-but-empty, violating this schema's "present only when..." discipline). It is its own
# defer_reason with its own payload field, designated_absent_candidate (see the field list
# above):
#   - in_batch (co-dispatched this wave/cycle, `--invocation-count` > 1): the candidate defers
#     UNLESS it is this cycle's designated absent-scope candidate (the lowest task number among
#     this cycle's absent-scope candidates — the SAME ascending-first-match tie-breaker
#     convention `self_modifying` already uses) OR it is phase-exempt (mapped via --phase-map to
#     "research" or "plan" — a research/plan dispatch touches only the task's own reports/ or
#     plans/ subdirectory, never orchestrator machinery, so its IMPLEMENTATION footprint being
#     undeclared is a pure false positive, identical rationale to the self-mod branch's own
#     phase-aware gate). This is a one-cycle ORDERING CONSTRAINT, not an exclusion: the deferred
#     candidate resolves in a later cycle once the designated candidate clears (dispatches,
#     completes, or otherwise leaves this cycle's candidate set) — self-clearing, same as every
#     other defer_reason this script emits.
#   - cross_batch (not co-dispatched this cycle, or `--invocation-count` == 1): NEVER defers —
#     see "Admission Posture for an ABSENT file_scope" above for the full advisory-only ruling and
#     its recorded promotion criterion.
#   - Override semantics: NO override flag exists for absent_file_scope, unlike self_modifying's
#     consumer-side `--allow-self-modifying`. This is deliberate, not an oversight: the defer
#     self-clears next cycle via the same tie-breaker convergence self_modifying already relies
#     on, and the real remedy — declare a file_scope — is a one-line state.json edit available to
#     any operator immediately, so no bypass flag is needed to unblock a legitimately urgent
#     dispatch. absent_file_scope sits alongside file_scope_collision and session_active in this
#     respect (neither of those has an override flag either), not alongside self_modifying.
#
# Determinism: among the surviving comparison set (terminal-excluded, edge-excluded, and — for
# in_batch pairs only — direction-filtered), tasks are visited in ASCENDING project_number order;
# the FIRST task with an overlapping file_scope wins and its verdict is emitted. No exhaustive
# collection of all collisions is attempted or reported. The self-modification check is likewise
# first-match: the FIRST critical-path entry (in the data file's declared order, expanded across
# scope_roots) that overlaps any of the candidate's own file_scope entries wins.
#
# Admitted-set-only in_batch narrowing (candidate-level ordering, distinct from the
# within-comparison-set ordering above): candidates are folded in ASCENDING project_number order
# into a running admitted-set lookup, and an in_batch collision blocks a candidate only when the
# lower-numbered peer's OWN verdict, already decided by the time this candidate is folded, is
# itself "admit" -- not merely that the peer appears somewhere in this invocation's argument
# list. NDJSON is still emitted in the original caller-argument order regardless of this
# decision-computation order; see docs/architecture/batch-admit-schema.md for the full narrative.
#
# Why this check is evidence-gated between blocking and advisory (REWRITTEN in v5 — the pre-v5
# text asserted blanket blocking for the cross_batch case and is gone; it self-contradicted by
# arguing concurrent-write harm from a task it simultaneously conceded "is not running"): the
# criterion imported for the blocking-vs-advisory decision is "computable from on-disk state
# alone, and the harm of skipping it is silent and hard to detect later." An in_batch collision,
# and a cross_batch collision against a task carrying execution evidence (status in
# {researching, planning, implementing}), both satisfy that criterion in full — both are
# computable from a read of specs/state.json, and if skipped, two sessions can concurrently edit
# the same files with no lock contention and no visible symptom until a merge conflict or a
# silently overwritten edit turns up much later. Those stay BLOCKING. A cross_batch collision
# against a task with NO execution evidence satisfies neither half: there is no second session
# to concurrently edit anything — the colliding task simply is not running, and nothing is lost by
# not blocking on it today. The only real residual concern is ORDERING (should the candidate wait
# until the idle task eventually runs?), and ordering is exactly what dependencies[] exists to
# express; it is not a concurrent-write hazard and does not belong behind a defer that can never
# self-clear until the idle task changes status on its own. That case is ADVISORY: it admits, and
# surfaces the suppressed overlap loudly via idle_overlap_advisory (see the field list above)
# rather than silently. The self-modifying check is unaffected by this narrowing and keeps its own
# unconditional blocking profile: it is computable from the candidate's own on-disk file_scope
# alone, and the harm of skipping it — an unverifiable orchestrator-machinery fix bundled into a
# multi-task batch commit — is silent and hard to attribute later, regardless of what any other
# task's status is. A later maintainer who reads the general literature on false positives from
# coarse directory-prefix scope declarations and is tempted to relax either the in_batch check, the
# in-flight cross_batch check, or the self-modifying check to advisory should re-derive the
# criterion above first — the false-positive cost for all three of those is a deferred task, not
# silent data loss, so the two are not comparable and the advisory relaxation is not warranted by
# that literature alone. This narrowing is evidence-gating (does the colliding task carry proof of
# being in flight?), not batch-size-gating (how many candidates are in this invocation?) — the
# comparison set and its size are unchanged; only the disposition of a provably idle cross_batch
# member changed.
#
# Exit codes:
#   0 - verdicts were emitted successfully on stdout, REGARDLESS of how many are "defer".
#       Verdicts are data, not errors: this script never exits non-zero merely because a
#       candidate was deferred, and it never writes to state.json (pure predicate, read-only).
#   2 - usage error (zero <task_number> arguments, any argument that is not a non-negative
#       integer, or a non-integer --invocation-count value), or state unavailable (jq missing, or
#       STATE_FILE missing/unparseable). Nothing is printed on stdout in either case; a single
#       loud line naming the reason goes to stderr.
#
# Output-channel discipline — AUDITED CLEAN, no change needed (audited alongside the fd-3
# structural fix in orchestrate-cycle-plan.sh/orchestrate-cycle-postflight.sh): this script
# already emits exactly once at the end (`printf '%s\n' "$verdicts"`), and every diagnostic
# above that point is already `>&2`. There is no per-call-site stopgap to remove and no
# entry-point redirect needed here. Do not re-open this question without new evidence.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
PROJECT_ROOT="$(common_repo_root "$SCRIPT_DIR" 2)"
. "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1
# Fail CLOSED (never fall back to an inline copy or skip the check) if the shared overlap-
# predicate lib is unsourceable. Deployed path: .claude/scripts/lib/file-scope-overlap.sh;
# source-store path: agent-system/extensions/core/scripts/lib/file-scope-overlap.sh. A missing
# copy at the deployed path most likely just means this repo's .claude/ predates this file's
# addition to the core manifest and has not been regenerated since -- the historical defect class
# where a subdirectory-declared scripts/hooks entry was silently dropped even on a resync (the
# retired glob+allow-list sync engine's top-path-segment allow-list bug) is fixed: the deploy tree
# is now driven by a single manifest-driven engine that addresses every declared entry by its
# manifest path. Remedy: regenerate via the picker's [Reload All]/[Regenerate] entries or
# bash .claude/scripts/deploy-headless.sh so the file reaches .claude/scripts/lib/.
if ! . "${SCRIPT_DIR}/lib/file-scope-overlap.sh" 2>/dev/null; then
  echo "ERROR: orchestrate-batch-admit.sh: could not source ${SCRIPT_DIR}/lib/file-scope-overlap.sh." >&2
  echo "  Source-store copy: agent-system/extensions/core/scripts/lib/file-scope-overlap.sh" >&2
  echo "  Remedy: regenerate via the picker's [Reload All]/[Regenerate] entries, or bash .claude/scripts/deploy-headless.sh." >&2
  echo "  Failing CLOSED: no fallback overlap check will run; batch admission is blocked." >&2
  exit 2
fi
STATE_FILE="$PROJECT_ROOT/specs/state.json"
CRITICAL_PATHS_FILE="$SCRIPT_DIR/../context/reference/orchestrator-critical-paths.json"

# --- argument parsing: --invocation-count <N> (D3) and --session-id <id> (D6) ahead of
# positional task_number validation ---
invocation_count_arg=""
session_id_arg=""
phase_map_arg=""
task_args=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --invocation-count)
      invocation_count_arg="${2:-}"
      shift 2 2>/dev/null || shift
      ;;
    --invocation-count=*)
      invocation_count_arg="${1#--invocation-count=}"
      shift
      ;;
    --session-id)
      session_id_arg="${2:-}"
      shift 2 2>/dev/null || shift
      ;;
    --session-id=*)
      session_id_arg="${1#--session-id=}"
      shift
      ;;
    --phase-map)
      phase_map_arg="${2:-}"
      shift 2 2>/dev/null || shift
      ;;
    --phase-map=*)
      phase_map_arg="${1#--phase-map=}"
      shift
      ;;
    *)
      task_args+=("$1")
      shift
      ;;
  esac
done

if [ -n "$invocation_count_arg" ]; then
  case "$invocation_count_arg" in
    ''|*[!0-9]*)
      echo "ERROR: orchestrate-batch-admit.sh: '--invocation-count $invocation_count_arg' is not a non-negative integer." >&2
      exit 2
      ;;
  esac
fi

# --phase-map <task:group[,task:group...]> (D-phase): OPTIONAL. Absent -> today's behavior
# exactly (no candidate is phase-exempted). Malformed-value rejection posture matches
# --invocation-count above: a value that does not match the closed grammar is a usage error, not
# a best-effort partial parse.
if [ -n "$phase_map_arg" ]; then
  if ! [[ "$phase_map_arg" =~ ^[0-9]+:[a-zA-Z_]+(,[0-9]+:[a-zA-Z_]+)*$ ]]; then
    echo "ERROR: orchestrate-batch-admit.sh: '--phase-map $phase_map_arg' is not a valid task:group[,task:group...] list." >&2
    exit 2
  fi
fi

# --- usage validation: zero positional args, or any non-integer positional arg, is a usage error ---
if [ "${#task_args[@]}" -eq 0 ]; then
  echo "ERROR: orchestrate-batch-admit.sh requires at least one <task_number> argument." >&2
  exit 2
fi

for arg in "${task_args[@]}"; do
  case "$arg" in
    ''|*[!0-9]*)
      echo "ERROR: orchestrate-batch-admit.sh: '$arg' is not a non-negative integer task_number." >&2
      exit 2
      ;;
  esac
done

if [ -z "$invocation_count_arg" ]; then
  invocation_count_arg=${#task_args[@]}
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: orchestrate-batch-admit.sh: jq is not available; cannot evaluate admission." >&2
  exit 2
fi

if [ ! -f "$STATE_FILE" ]; then
  echo "ERROR: orchestrate-batch-admit.sh: state file not found at $STATE_FILE." >&2
  exit 2
fi

# --- load and expand the critical-path data file (D5: degrade visibly, never silently) ---
degraded="false"
critical_expanded_json='[]'
if [ ! -f "$CRITICAL_PATHS_FILE" ]; then
  echo "WARNING: orchestrate-batch-admit.sh: critical-path data file not found at $CRITICAL_PATHS_FILE; self-modification check DEGRADED (self_modifying will be null on every verdict)." >&2
  degraded="true"
else
  critical_raw_json=$(jq -c '.' "$CRITICAL_PATHS_FILE" 2>/dev/null) || true
  if [ -z "$critical_raw_json" ] || [ "$critical_raw_json" = "null" ]; then
    echo "WARNING: orchestrate-batch-admit.sh: critical-path data file at $CRITICAL_PATHS_FILE is unparseable; self-modification check DEGRADED (self_modifying will be null on every verdict)." >&2
    degraded="true"
  else
    critical_expanded_json=$(jq -c '
      (.scope_roots // []) as $roots |
      (.critical_paths // []) as $paths |
      [ $roots[] as $r | $paths[] as $p | {path: ($r + "/" + $p.path), label: $p.label} ]
    ' <<<"$critical_raw_json" 2>/dev/null) || true
    if [ -z "$critical_expanded_json" ]; then
      echo "WARNING: orchestrate-batch-admit.sh: critical-path data file at $CRITICAL_PATHS_FILE failed to expand (unexpected shape); self-modification check DEGRADED (self_modifying will be null on every verdict)." >&2
      degraded="true"
      critical_expanded_json='[]'
    fi
  fi
fi

# --- resolve the session-registry input (D6: --session-id is required for it; omitting it
# degrades visibly, never silently) ---
sessions_json='[]'
if [ -n "$session_id_arg" ]; then
  sessions_json=$("$SCRIPT_DIR/task-lock.sh" session-list 2>/dev/null | jq -s -c '.' 2>/dev/null) || true
  if [ -z "$sessions_json" ]; then
    sessions_json='[]'
  fi
else
  echo "WARNING: orchestrate-batch-admit.sh: --session-id not supplied; the session-registry contention input is SKIPPED for this invocation (no defer_reason: \"session_active\" verdict can fire). Without a caller session id, a just-registered session covering this candidate set would be seen as foreign and every candidate would self-block. Pass --session-id \"\$batch_session_id\" to enable it." >&2
fi

# Build the candidates JSON array (preserves input order, including duplicates if given).
candidates_json="[$(printf '%s\n' "${task_args[@]}" | paste -sd, -)]" || true

# Single read of STATE_FILE via --slurpfile, feeding one jq program that computes every
# candidate's verdict and prints NDJSON in input order. No second read, no wildcard expansion,
# and no repo-wide filesystem walk of any kind.
# `if VAR=$(cmd); then jq_exit=0; else jq_exit=$?; fi` rather than a bare `VAR=$(cmd)` followed
# by `jq_exit=$?`: a jq failure here is a DOCUMENTED, routine outcome (exit 2, per this script's
# own header) -- under `set -e` a bare failing assignment would abort the script on this line,
# before jq_exit could ever be captured or the clean ERROR message below could print. Wrapping
# the assignment in the `if` test is `-e`-exempt and preserves the captured status exactly,
# mirroring the fix applied to state-write.sh, task-lock.sh, and git-commit-scoped.sh.
if verdicts=$(jq -n -c \
  --argjson candidates "$candidates_json" \
  --slurpfile state_arr "$STATE_FILE" \
  --argjson critical_expanded "$critical_expanded_json" \
  --argjson degraded "$degraded" \
  --argjson invocation_count "$invocation_count_arg" \
  --arg own_session_id "$session_id_arg" \
  --argjson sessions "$sessions_json" \
  --arg phase_map_raw "$phase_map_arg" \
  "$FILE_SCOPE_OVERLAP_JQ_DEFS"'

  def is_terminal: ascii_downcase as $s | ($s == "completed" or $s == "abandoned" or $s == "expanded");
  def is_in_flight: ascii_downcase as $s | ($s == "researching" or $s == "planning" or $s == "implementing");

  ($state_arr[0].active_projects // []) as $all |
  $candidates as $cands |
  $critical_expanded as $crit |
  $degraded as $is_degraded |
  $invocation_count as $inv_count |
  $own_session_id as $own_sid |
  $sessions as $sess_list |
  ($phase_map_raw
   | if . == "" then {}
     else (split(",") | map(split(":")) | map({(.[0]): .[1]}) | add)
     end
  ) as $phase_map |
  # Designated self-modifying candidate (D-tiebreak, NEW): the LOWEST task number, among the
  # candidates in this cycle, whose own file_scope matches a critical path (non-degraded,
  # non-terminal, non-empty file_scope) -- same ascending-project_number-first-match determinism
  # convention already used by the in_batch deferral direction above. Computed once per
  # invocation, over the full $cands set, independent of any one candidate branch below. null
  # when no candidate in this cycle is self-modifying.
  ($cands
   | map(. as $n |
       ([$all[] | select(.project_number == $n)] | first) as $e |
       (
         if ($e == null) then false
         elif $is_degraded then false
         elif (($e.status // "") | is_terminal) then false
         elif (($e.file_scope // []) | length) == 0 then false
         else (self_mod_match($e.file_scope; $crit) != null)
         end
       ) as $matches |
       if $matches then $n else null end
     )
   | map(select(. != null))
   | if length > 0 then min else null end
  ) as $designated_sm_candidate |

  # Designated absent-scope candidate (NEW, Phase-3-of-the-absent-scope-ruling): the LOWEST task
  # number, among the candidates in this cycle, that is known, non-terminal, and has an
  # absent/empty file_scope (missing key, literal null, or empty array) -- same
  # ascending-project_number-first-match determinism convention as $designated_sm_candidate
  # above. Computed once per invocation, over the full $cands set, independent of any one
  # candidate branch below. null when no candidate in this cycle has an absent file_scope.
  ($cands
   | map(. as $n |
       ([$all[] | select(.project_number == $n)] | first) as $e |
       (
         if ($e == null) then false
         elif (($e.status // "") | is_terminal) then false
         else (($e.file_scope // []) | length) == 0
         end
       ) as $matches |
       if $matches then $n else null end
     )
   | map(select(. != null))
   | if length > 0 then min else null end
  ) as $designated_absent_candidate |

  (
    reduce ($cands | sort)[] as $c (
      {results: {}};
      . as $acc |
      (
    ([$all[] | select(.project_number == $c)] | first) as $entry |
    ($phase_map[($c|tostring)] // null) as $phase_group |

    if ($entry == null) then
      {"$schema": "orchestrate-batch-admit-v6", task_number: $c, decision: "admit",
       self_modifying: (if $is_degraded then null else false end)}
    elif (($entry.status // "") | is_terminal) then
      {"$schema": "orchestrate-batch-admit-v6", task_number: $c, decision: "admit",
       self_modifying: (if $is_degraded then null else (self_mod_match($entry.file_scope; $crit) != null) end)}
    elif (($entry.file_scope // []) | length) == 0 then
      # Admission Posture for an ABSENT file_scope (see the header ruling above): cross_batch
      # stays advisory-only (admit, carrying absent_scope_advisory); in_batch is BLOCKING via the
      # absent_file_scope defer_reason below, converging through the SAME designated-candidate
      # tie-breaker pattern self_modifying already uses (lowest task number among the
      # absent-scope candidates in this cycle admits; every other one defers this wave/cycle). A
      # research or plan dispatch is exempt unconditionally, for the identical D-phase rationale
      # the self-mod branch below already applies: it touches only the own reports/ or plans/
      # subdirectory of the task, never orchestrator machinery, so deferring it merely because its
      # IMPLEMENTATION footprint is undeclared would be a pure false positive. scope_state
      # distinguishes the three sub-states BEFORE the `// []` coalesce above erases the
      # difference between them -- same vocabulary validate-state.sh Check 10 and
      # orchestrate-predispatch-review.sh Class F already use.
      (if (($entry | has("file_scope")) | not) then "missing_key"
       elif ($entry.file_scope == null) then "null_value"
       else "empty_array"
       end) as $scope_state |
      {
        scope_state: $scope_state,
        codispatch_count: $inv_count,
        reason: ("file_scope is " + $scope_state + " for candidate #" + ($c|tostring) +
                 "; declare a file_scope, or run plan-file-scope-harvest.sh / backfill-file-scope.sh once a plan exists")
      } as $absent_advisory |
      if ($phase_group == "research" or $phase_group == "plan") then
        {"$schema": "orchestrate-batch-admit-v6", task_number: $c, decision: "admit",
         self_modifying: (if $is_degraded then null else false end),
         absent_scope_advisory: $absent_advisory}
      elif ($inv_count > 1 and $c != $designated_absent_candidate) then
        {
          "$schema": "orchestrate-batch-admit-v6",
          task_number: $c,
          decision: "defer",
          self_modifying: (if $is_degraded then null else false end),
          defer_reason: "absent_file_scope",
          designated_absent_candidate: $designated_absent_candidate,
          reason: ("candidate #" + ($c|tostring) + " has an absent file_scope (" + $scope_state +
                   "); deferred this wave/cycle in favor of designated absent-scope candidate #" +
                   ($designated_absent_candidate|tostring) + " (lowest task number among the absent-scope candidates in this cycle) -- this is a one-cycle ORDERING CONSTRAINT, not an exclusion: candidate #" + ($c|tostring) + " resolves in a later cycle, in sequence, once #" + ($designated_absent_candidate|tostring) + " clears; the real remedy is to declare a file_scope, which clears this defer immediately")
        } + {absent_scope_advisory: $absent_advisory}
      else
        {"$schema": "orchestrate-batch-admit-v6", task_number: $c, decision: "admit",
         self_modifying: (if $is_degraded then null else false end),
         absent_scope_advisory: $absent_advisory}
      end
    else
      ($entry.dependencies // []) as $c_deps |
      ($entry.file_scope) as $c_scope |
      (if $is_degraded then null else self_mod_match($c_scope; $crit) end) as $sm_hit |
      (if $is_degraded then null else ($sm_hit != null) end) as $sm_flag |
      if ($sm_flag == true) then
        if ($phase_group == "research" or $phase_group == "plan") then
          # Phase-aware gate (D-phase, NEW): a research or plan dispatch touches only the own
          # reports/ or plans/ subdirectory of the task, plus its own
          # .return-meta.json/.orchestrator-handoff.json -- never orchestrator machinery -- so
          # deferring it merely because the IMPLEMENTATION footprint of the task names a critical
          # path is a pure false positive. Exempt unconditionally from both
          # the tie-breaker and the raw inv_count check; self_modifying stays true (hazard visible).
          {
            "$schema": "orchestrate-batch-admit-v6",
            task_number: $c,
            decision: "admit",
            self_modifying: true
          }
        elif ($inv_count > 1 and $c != $designated_sm_candidate) then
          {
            "$schema": "orchestrate-batch-admit-v6",
            task_number: $c,
            decision: "defer",
            self_modifying: true,
            defer_reason: "self_modifying",
            critical_path: $sm_hit.path,
            critical_label: $sm_hit.label,
            reason: ("candidate #" + ($c|tostring) + " file_scope names orchestrator-critical path \"" + $sm_hit.path + "\" (" + $sm_hit.label + "); deferred this wave/cycle in favor of designated self-modifying candidate #" + ($designated_sm_candidate|tostring) + " (lowest task number among the self-modifying candidates in this cycle) -- this is an ORDERING CONSTRAINT, not an exclusion: candidate #" + ($c|tostring) + " resolves in a later cycle, in sequence, once #" + ($designated_sm_candidate|tostring) + " clears, or pass --allow-self-modifying to override")
          }
        else
          {
            "$schema": "orchestrate-batch-admit-v6",
            task_number: $c,
            decision: "admit",
            self_modifying: true
          }
        end
      else
        (
          [
            $all[] | . as $t | select(
              ($t.project_number != $c) and
              ((($t.status // "") | is_terminal) | not) and
              (($c_deps | index($t.project_number)) == null) and
              ((($t.dependencies // []) | index($c)) == null)
            )
          ] | sort_by(.project_number)
        ) as $comparison_set |
        (
          [
            $comparison_set[] as $other |
            ($other.project_number) as $other_num |
            ($cands | index($other_num)) as $in_batch_idx |
            (if $in_batch_idx == null then "cross_batch" else "in_batch" end) as $scope_kind |
            # NARROWED (admitted-set-only in_batch deferral): an in_batch peer blocks the
            # candidate only when that peer is ITSELF admitted this cycle -- its already-folded
            # verdict (this fold visits strictly ascending project_number, so every in_batch peer
            # with a lower project_number has already been folded by the time $c is reached) must
            # read decision == "admit". A lookup miss degrades to "admit-the-peer" (does not
            # block), matching the existing degrade-to-admit posture used elsewhere in this
            # script; it is unreachable
            # by construction here because $in_batch_idx != null is exactly the guard that reached
            # this branch. Duplicate positional task numbers (pre-existing edge case, deliberately
            # unchanged): a duplicate folded twice looks itself up and finds its own
            # first-occurrence verdict.
            select($scope_kind == "cross_batch" or ($other_num < $c and ((($acc.results[($other_num|tostring)].decision) // "admit") == "admit"))) |
            scopes_overlap_first($c_scope; ($other.file_scope // [])) as $ov_path |
            select($ov_path != null and $ov_path != "") |
            {
              other_num: $other_num,
              other_status: ($other.status // ""),
              ov_path: $ov_path,
              scope_kind: $scope_kind,
              in_flight: (($other.status // "") | is_in_flight)
            }
          ]
        ) as $overlaps |
        ($overlaps | map(select(.scope_kind == "in_batch" or .in_flight)) | first) as $hit |
        ($overlaps | map(select(.scope_kind == "cross_batch" and (.in_flight | not))) | first) as $idle_overlap |
        (
          if $idle_overlap == null then {} else
            {
              idle_overlap_advisory: {
                colliding_task_number: $idle_overlap.other_num,
                colliding_task_status: $idle_overlap.other_status,
                overlapping_path: $idle_overlap.ov_path,
                collision_scope: $idle_overlap.scope_kind,
                reason: ("file_scope overlap with IDLE (not in-flight) task #" + ($idle_overlap.other_num | tostring) +
                         " (status \"" + $idle_overlap.other_status + "\", not in this batch) at " + $idle_overlap.ov_path +
                         "; admitted because no execution evidence exists — add a dependencies[] edge if ordering between them matters")
              }
            }
          end
        ) as $idle_advisory_frag |
        if $hit == null then
          # No state.json collision found -- the session-registry input (D3 precedence: reached
          # only here) gets its turn. Every input that defers via the branch above is UNCHANGED by
          # this addition; this new flavor fires strictly where the predicate used to admit.
          session_contention($c_scope; $c; $own_sid; $all; $sess_list) as $sess_hit |
          if $sess_hit == null then
            {"$schema": "orchestrate-batch-admit-v6", task_number: $c, decision: "admit", self_modifying: $sm_flag} + $idle_advisory_frag
          else
            {
              "$schema": "orchestrate-batch-admit-v6",
              task_number: $c,
              decision: "defer",
              self_modifying: $sm_flag,
              defer_reason: "session_active",
              session_id: $sess_hit.session_id,
              colliding_task_number: $sess_hit.covered_task_number,
              overlapping_path: $sess_hit.overlapping_path,
              session_liveness_reason: $sess_hit.liveness_reason,
              reason: ("session " + $sess_hit.session_id + " (liveness: " + $sess_hit.liveness_reason +
                       ") covers non-terminal task #" + ($sess_hit.covered_task_number | tostring) +
                       " whose registered file_scope overlaps this candidate at " + $sess_hit.overlapping_path)
            } + $idle_advisory_frag
          end
        else
          # corroborated_by (D2/v4): always names the state.json signal that produced this verdict;
          # additionally names the session registry when a live, non-self session independently
          # covers the SAME colliding task number -- evidentiary corroboration, not a second
          # detection path (D4 contention-exclusion rules do not gate this check; the question
          # here is only "does independent live evidence exist", not "does this session contend").
          (
            [
              $sess_list[] | select(.live == true and .session_id != $own_sid) |
              select((.task_numbers // []) | index($hit.other_num) != null)
            ] | length > 0
          ) as $session_corroborates |
          (
            ["non_terminal_status"] + (if $session_corroborates then ["session_registry"] else [] end)
          ) as $corroborated_by |
          {
            "$schema": "orchestrate-batch-admit-v6",
            task_number: $c,
            decision: "defer",
            self_modifying: $sm_flag,
            defer_reason: "file_scope_collision",
            colliding_task_number: $hit.other_num,
            colliding_task_status: $hit.other_status,
            overlapping_path: $hit.ov_path,
            collision_scope: $hit.scope_kind,
            corroborated_by: $corroborated_by,
            reason: ("file_scope overlap with non-terminal task #" + ($hit.other_num | tostring) +
                     " (" + (if $hit.scope_kind == "in_batch" then "in this batch" else "not in this batch" end) +
                     ") at " + $hit.ov_path + "; no dependencies[] edge between them")
          } + $idle_advisory_frag
        end
      end
    end
      ) as $v |
      $acc | .results[($c|tostring)] = $v
    )
  ) as $folded |

  $cands[] as $orig |
  ($folded.results[($orig|tostring)])
  ' 2>&1); then
  jq_exit=0
else
  jq_exit=$?
fi

if [ "$jq_exit" -ne 0 ]; then
  echo "ERROR: orchestrate-batch-admit.sh: failed to evaluate admission against $STATE_FILE (jq exit $jq_exit)." >&2
  exit 2
fi

printf '%s\n' "$verdicts"
exit 0
