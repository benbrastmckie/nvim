# Orchestrator Handoff JSON Schema

**Status**: Current architecture.

**File location**: `specs/{NNN}_{SLUG}/.orchestrator-handoff.json` (per-dispatch runtime state,
tracked as durable provenance)
**Written by**: A hard-mode implementation agent only — this artifact is formally
hard-mode-implement-only (see "Handoff Writers" below). Core's own standalone hard-mode
implementation agent was deleted along with the rest of core's `-hard` lifecycle skills/agents;
today only cslib's and lean's hard-mode implementation agents still write this file, since core's
`general`/`meta`/`markdown` task types now resolve hard-mode implement dispatch to the SAME
base-mode `general-implementation-agent`, which never writes a handoff — see "Handoff Writers"
below for the full, current writer set.
**Read by**: `skill-orchestrate`'s state machine loop (a single engine now covers both effort
modes)
**Machine-checkable schema**: `context/schemas/orchestrator-handoff-schema.json` is the single
source of truth this document, `wrap-up.md`, and `validate-handoff.sh` all point at rather than
restating independently.

This file **is** git-tracked, unlike the loop guard and churn-state files `skill-orchestrate`
also writes. The reader-side freshness gate documented below ("Readers MUST check freshness")
neutralizes the "restored from an old commit" scenario a tracked file would otherwise risk —
exactly the gate the loop guard lacks, which is why that file stays gitignored instead. See
`context/standards/orchestrator-runtime-files.md` for the full two-class policy and rationale.

**See Also**: `orchestrate-state-machine.md`,
`context/standards/orchestrator-runtime-files.md`

## Path Resolution Contract

**Writers MUST use an absolute path.** A bare `.orchestrator-handoff.json` filename resolves
against whatever the ambient working directory happens to be at write time, stranding the file
outside the task directory. The orchestrator then either reports a missing handoff or — worse —
reads the previous cycle's leftover file and reports its status as the current dispatch's
result.

One write mechanism exists today — the hard-mode implementation agent's direct Write-tool write,
anchored by `handoff_path` (absolute) supplied in the delegation context, with absolute
`task_dir` as fallback. `hooks/validate-handoff-location.sh` (PostToolUse, matcher
`Write\|Edit`) rejects out-of-tree destinations with exit 2.

**Hook coverage note, kept for the record even though the second mechanism it once described no
longer exists.** `validate-handoff-location.sh` reads `tool_input.file_path`, a field only
`Write` and `Edit` calls carry — it is complete coverage for the one live write mechanism. A
hypothetical Bash-redirect write would expose only the raw, unexpanded command text (the
redirect target would appear as the literal string `"$handoff_path"`, with its resolved value
absent from the hook input), so the hook is structurally blind to that class of write. This
codebase previously had exactly such a writer (a Bash-redirect helper function in
`scripts/skill-base.sh` with zero callers); it has been deleted rather than rewired, closing the
coverage gap by removing the class of writer rather than patching the hook. The orchestrator-side
stray-handoff sweep (`skill-orchestrate` Stage 5, covering both effort modes) remains the
mechanism-agnostic backstop should a future Bash-redirect writer ever be introduced.

**Readers MUST check freshness.** A handoff at the correct path is not necessarily *this
dispatch's* handoff. Both orchestrators compare the file's mtime against `dispatch_start_ts` —
the same dispatch window already captured for infra-failure discrimination — and treat an
out-of-window handoff exactly as they treat a missing one. **mtime alone is not sufficient**: a
still-live predecessor that wakes (via a self-armed watcher/monitor, or an operator resume — see
`context/patterns/dispatch-report-not-termination.md`) and writes late always produces a newer
mtime than the current dispatch window, so the late write passes an mtime-only check and looks
exactly like this dispatch's own on-time report. The actual discriminator is `dispatch_seq`: an
orchestrator-minted, unforgeable per-dispatch identity embedded in the delegation context before
the `Agent` call and echoed back unchanged in the handoff. Stage 5 of both engines compares the
handoff's `dispatch_seq` against the value minted for the current cycle, rejecting a mismatch
even when the mtime check alone would have passed. The mtime check is retained as a second line
of defense against a different hazard (a handoff silently restored from an old git commit); it is
not itself sufficient against a woken predecessor.

**Dual-Consumer Note**: `orchestrator_mode` has TWO independent consumers as of the
sparse-literature-detection reconciliation (see `EXTENSION.md`'s "Sparse-Coverage Detection"
section in the literature extension): (1) the handoff-write gate documented on this page
("Skills MUST write `.orchestrator-handoff.json` when and ONLY when `orchestrator_mode: true`"),
and (2) the literature Stage 4a autonomy gate in
`context/patterns/lit-stage4a-flow.md` (`orchestrator_mode: true` suppresses `AskUserQuestion`
and takes the deterministic `[lit:auto]` global-corpus fallback instead). A future edit to
either consumer's semantics MUST re-check the other before landing -- fixing the autonomy gate
must never silently regress the handoff-write gate, or vice versa.

---

## Two Distinct Handoff Types

This document covers only the **orchestrator handoff**. Do not confuse with continuation handoffs:

| Type | File | Format | Written by | Read by | Purpose |
|------|------|--------|------------|---------|---------|
| **Orchestrator handoff** | `.orchestrator-handoff.json` | JSON, ≤400 tokens | Hard-mode implementation agent only | skill-orchestrate | State machine dispatch decisions |
| Continuation handoff | `handoffs/phase-N-handoff-TIMESTAMP.md` | Markdown | Agents (context exhaustion) | Successor agents | Resume after context exhaustion |

These serve different consumers and MUST NOT be conflated. The orchestrator reads structured JSON;
the successor agent reads markdown prose.

---

## One Write Form, Deprecated-But-Accepted Read Form

The continuation pointer — "where is the markdown continuation handoff a `partial` dispatch left
behind" — has **one canonical, writable form**:

| Form | Shape | Who writes it | Canonical source |
|------|-------|----------------|-------------------|
| **Flat** `continuation_path` | top-level string, e.g. `"specs/NNN_slug/handoffs/phase-N-handoff-TS.md"` | A hard-mode implementation agent's H9 wrap-up (core's own is deleted; the cslib and lean counterparts are the surviving writers today) | `context/contracts/wrap-up.md`'s Orchestrator Handoff JSON Schema and `context/schemas/orchestrator-handoff-schema.json` — this is the canonical, required shape |

The **nested** `continuation_context` form (`{ "handoff_path": "...", "orchestrator_mode": true
}`) is **deprecated and read-only-accepted**: no writer anywhere emits it — its sole writer, a
Bash-redirect helper function in `scripts/skill-base.sh`, has been deleted (it had zero callers).
It is documented here, and remains a live schema property with `deprecated: true`, only
because the reader-side dual-form resolution below is deliberately RETAINED, for two reasons:
(a) `test-orchestrate-triage-classify.sh` asserts the dual-form `continuation_ok` predicate, so
removing the read path would be a test-breaking behavior change on an orchestrator-critical path
for no writer-side benefit; (b) an in-flight handoff written by a pre-change dispatch could still
carry the nested form, and a reader that suddenly stopped accepting it would misclassify a real
continuation as absent.

**Reader behavior is unchanged by the writer's retirement.** `validate-handoff.sh`,
`scripts/orchestrate-triage-classify.sh`'s `continuation_ok` predicate, and
`skill-orchestrate/SKILL.md` (Stage 4 partial handler and hard-mode H1 branch, Stage 5 result
read, Stage MT-4 dispatch bullet — one engine, both effort modes) all continue to resolve
**either** form, normalizing to `{ handoff_path, orchestrator_mode: true }` before the value is
handed to a successor dispatch. Do not narrow any of these readers to reject the nested form
without first confirming no in-flight handoff still carries it.

**Do not re-introduce a nested-form writer** without updating this document, the schema file's
`deprecated` annotation, and re-deriving the reasoning above — the point of retiring the writer
was to collapse "one continuation form" down to a single writable shape, not to leave the door
open for a second one to reappear.

---

## Complete JSON Schema

The machine-checkable authority for this shape is
`context/schemas/orchestrator-handoff-schema.json` (draft-07 JSON Schema, validated by
`scripts/validate-handoff.sh`). This document is the prose companion — the two must stay in
sync, and this document must never restate the shape independently of the schema file.

A short illustrative example (fields shown are a representative subset; see the schema file for
the authoritative required/optional/deprecated list):

```json
{
  "status": "implemented",
  "summary": "2-4 sentence description of what was accomplished. Must be concise — this field has a ~100 token budget.",
  "artifacts": [
    {"type": "summary", "path": "specs/NNN_slug/summaries/01_slug-summary.md", "summary": "One-line description"}
  ],
  "phases_completed": 2,
  "phases_total": 4,
  "blockers": [],
  "continuation_path": null,
  "plan_markers_verified": true
}
```

`phases_completed` and `phases_total` are TOP-LEVEL fields, always — never members of
`continuation_context`. See the `continuation_context` field definition below and the
Completion-Claim Verification Gate section for why this matters.

---

## Field Definitions

### `phase` (optional, informational)
Which lifecycle phase just completed. Not required by the schema — informational only.
- `"research"`: `/research` skill completed
- `"plan"`: `/plan` skill completed
- `"implement"`: `/implement` skill completed (full or partial)
- `"revise"`: `/revise` skill completed

**Not an identity mechanism.** This four-value lifecycle enum cannot discriminate one plan
phase's dispatch from another's — it names which *kind* of skill ran, not which cycle. Do not
use it, or attempt to extend it, as a substitute for `dispatch_seq` below.

### `dispatch_seq` (optional, integer)
Orchestrator-minted, unforgeable per-dispatch identity. See "Readers MUST check freshness" above
for the full rationale. Minted by the orchestrator immediately before the `Agent` tool call,
embedded in that dispatch's delegation context (alongside `handoff_path`), and echoed back
unchanged by the dispatched agent in this field. Stage 5 of `skill-orchestrate` (both effort
modes, one engine) compares this value against the value minted for the current cycle:
- Match (or field absent from the handoff): accepted, subject to the existing mtime check.
- Mismatch: rejected — `handoff_stale=true`, the same loud-error path the mtime check already
  takes, naming both the expected and observed values.
- Absent: a loud WARN naming the writer contract, never a rejection. The strict
  reject-on-absent form is deliberately not adopted, so a writer that predates this field (or
  omits it) degrades to mtime-only discrimination rather than being treated as an error.

Not in the schema's `required` set for exactly this reason — see
`context/schemas/orchestrator-handoff-schema.json`.

### `status` (required)
Outcome of this dispatch cycle.
- `"researched"`: Research complete, report written
- `"planned"`: Plan written, ready for implementation
- `"implemented"`: All plan phases complete
- `"partial"`: Incomplete — see `continuation_context` or `blockers`
- `"failed"`: Non-recoverable failure — implementation cannot continue
- `"blocked"`: Hard blockers prevent progress — escalation required

This six-value enumeration is intentionally identical to `.return-meta.json`'s `status` field.
`context/formats/return-metadata-file.md` is the shared, normative source for both — this field
draws from that table rather than defining a second, independently-maintained enumeration.

### `summary` (required)
2-4 sentences describing what was accomplished. **Token budget: ~100 tokens**. Be concise.
The orchestrator reads this to understand cycle outcome without reading full artifacts.

### `artifacts` (required)
List of artifacts written by this cycle. The orchestrator uses these to populate delegation
context for the next cycle (e.g., plan path for implement dispatch), and `skill_link_artifacts`
consumes `artifacts[0]` to link the produced file into `state.json`. Must be present and be a
JSON array; non-empty is required when `status` is `researched`/`planned`/`implemented` (an
empty array is legal for `partial`/`failed`/`blocked`, which may not have produced an artifact
yet). Each entry requires `type` and `path`; `summary` (a one-line description) is optional but
read by both orchestrate engines as `artifacts[0].summary` — omitting it degrades the
orchestrator's dispatch summary without failing validation.

**A bare-string element is never an accepted shorthand, in any context.** `"artifacts":
["path/to/file.md"]` is not a valid form of this field — every element MUST be a JSON object
carrying `type` and `path` (with `summary` optional), never a plain path string. This sentence
does not introduce a second source of truth: `orchestrator-handoff-schema.json` remains the sole
machine-checkable authority for the shape (`items.type: "object"` already forbids a bare string
structurally); this sentence closes the gap that the schema's structural rule was previously
asserted only implicitly, by required-fields listing and worked example, with no prose stating
the prohibition explicitly.

### `blockers` (required array; entries populated only when there is a blocker)
Must be present as a JSON array — `[]` is normal and expected for `implemented` status. Non-empty
only when `status = "partial"` or `status = "blocked"`. Each blocker entry uses the canonical
hard/wrap-up shape (fragment below — a single `blockers[]` entry, not a complete handoff object;
it will not independently pass `validate-handoff.sh`):

```json
{
  "phase": 3,
  "target": "exact description of what was attempted",
  "verbatim_goal": "exact text from plan checklist item",
  "what_was_tried": "one sentence",
  "why_it_failed": "one sentence"
}
```

`phase` and `target` are required per entry; `verbatim_goal`, `what_was_tried`, and
`why_it_failed` are optional but expected in practice. **The older `{description, phase,
severity}` shape is retired**: verified by grep-audit (see the research report this plan is built
on) that neither orchestrate engine reads `.description` or `.severity` anywhere — they are dead
fields, not an alternate accepted shape. `target` is read by the hard engine's H5 divergence audit
and blocked-escalation flow; `verbatim_goal` is read by the hard engine's blocked-escalation flow
for re-dispatch prompts. The base engine only ever reads `blockers | length`, never individual
field content.

### `next_action_hint` (optional)
Suggested next action. The orchestrator's state machine may override this hint. It is advisory only.

### `files_modified` (optional)
Paths of files changed during this cycle. Used by the orchestrator to include in downstream
delegation context (e.g., "the plan was revised to include these changes").

### `decisions_made` (optional)
Key decisions that downstream cycles should be aware of. Prevents downstream agents from
re-investigating already-settled questions.

### `user_decision` (optional)
Shape: `{question, options: [...], recommended, blocking: true|false}` — see
`context/standards/user-decision-contract.md` for the full contract. **Distinct from
`decisions_made` above**: `decisions_made` is informational/historical (settled questions a
downstream agent should not re-investigate); `user_decision` is a live, forward-looking request
for the user's judgment on a choice that is NOT yet settled. Mirrored here only when the same
dispatch that set it on `.return-meta.json` also writes this handoff. A git-push-consent request
(`context/standards/push-consent-relay.md`) is mirrored exactly like any other `user_decision` —
no new handoff field is introduced for it.

### `dead_ends` (optional)
Approaches tried but failed. The orchestrator passes these to downstream delegation context
to prevent repetition.

### `skeleton` (optional, boolean, hard-mode-only)
`true` ONLY when `status == "implemented"` and completeness rests on one or more strategic
sorries meeting `anti-analysis.md`'s strategic-sorry policy — the "implemented (skeleton)"
outcome. Read only by the hard engine (H5 divergence-audit routing). See `wrap-up.md`'s
status/skeleton interaction table for the full validity matrix.

### `sorry_inventory` (optional, array, hard-mode-only)
Array of entries, one per sorry introduced, with the canonical schema `{file, line, statement,
strategic, assumption, why_deferred, follow_up_task}` — see `wrap-up.md`'s field-semantics
section for the full per-field definition. Read only by the hard engine.

### `git_checkpoint` (optional)
A git checkpoint reference (commit SHA, `working-progress-*.patch` path, `stash@{N}` ref, or
`untracked-backup-{ts}` path) recorded at a context-pressure or phase-end handoff, so a fresh
dispatch can locate checkpointed state without re-deriving it. See
`context/patterns/checkpoint-before-overflow.md`, the shared CHECKPOINT-BEFORE-OVERFLOW procedure
every implementation agent (base and hard-mode alike, core and extension) follows, for the full
write contract — it may appear at the top level or nested inside the relevant `blockers` entry
for the interrupted phase.

### `phases_completed` / `phases_total` (required, integers, TOP LEVEL)
Phase-accounting fields read by the completion-claim verification gate (see below). These are
ALWAYS top-level fields on the handoff object — never members of `continuation_context`.
`continuation_context` carries only `handoff_path` and `orchestrator_mode`. The single active
handoff writer (the hard-mode implementation agents' H9 wrap-up) and the orchestrator's readers
at all three call sites (base Stage 5, base Stage MT-4, hard Stage 5) agree on top level; do not
move these fields into `continuation_context` in either a writer or a reader.

**`[COMPLETED WITH EXCLUSIONS]` accounting**: a phase closed via `[COMPLETED WITH EXCLUSIONS]`
(see `context/standards/status-markers.md`'s `[COMPLETED WITH EXCLUSIONS]` subsection) counts
toward `phases_completed` identically to a `[COMPLETED]` phase. The reasoning is the same reason
this whole section exists: `skill_gate_completion_claim` below consumes only these two
self-reported integers and never reads the plan file, so the agent-side self-report at handoff
time is the sole lever. Under-counting an exclusion-closed phase here drives the gate's Case 1
(phase accounting present, incomplete) and refuses completion forever — the task can never reach
`completed` no matter how many times implement re-dispatches, since the plan file (the only place
that could show the phase is actually closed) is never consulted.

**No new handoff field is introduced for this outcome, deliberately.** The `Item | Reason |
Evidence` record itself lives in the plan artifact (`#### Reasoned Exclusions`,
`context/formats/plan-format.md`), and the handoff carries only the already-existing
`phases_completed` integer, incremented exactly as it would be for a plain `[COMPLETED]` phase.
This is a deliberate contrast with the strategic-sorry family member: a strategic sorry DOES carry
a dedicated handoff-side field, `sorry_inventory` (see `wrap-up.md`), because a sorry is
*tracked* with a follow-up that a future dispatch must locate. A reasoned exclusion is *decided
and will not be revisited*, so there is nothing to track and no follow-up-locating field is
needed — the difference in handoff shape follows directly from the difference in the two family
members' defining property (see `context/contracts/anti-analysis.md`'s "Family relationship" note
for that property).

### `continuation_path` (optional, the one canonical writable form, present when `status = "partial"`)
The **flat** form of the continuation pointer: a top-level string naming the continuation
handoff markdown file the agent wrote. This is the ONLY form any live writer emits
(`context/contracts/wrap-up.md`'s canonical schema; see "One Write Form, Deprecated-But-Accepted
Read Form" above). `null` when `status = "implemented"`.

The orchestrator resolves this field (or the deprecated nested `continuation_context.handoff_path`
below, whichever is present) and normalizes the result to `{ handoff_path, orchestrator_mode:
true }` before passing it to the next implement dispatch as `continuation_context` in the
dispatch context — see "Reading Contract" below. `orchestrator_mode: true` is supplied by the
reader during this normalization, since a flat `continuation_path` carries no `orchestrator_mode`
field of its own (cross-reference: `### orchestrator_mode Flag` below).

### `continuation_context` (deprecated, read-only-accepted; no writer emits it)
The **nested** form of the continuation pointer: a top-level object `{ handoff_path,
orchestrator_mode }`. This form has NO writer today — its sole writer, a Bash-redirect helper
function formerly in `scripts/skill-base.sh`, has been deleted (zero callers). It remains a documented,
`deprecated: true` schema property, and every reader still accepts it, solely for backward
compatibility with a handoff written by a pre-deletion dispatch; do not write this form. It does
NOT carry `phases_completed` or `phases_total`.

**Note**: either continuation-pointer form and `blockers` can both be present (partial completion
with identified blockers). The orchestrator handles blockers first via escalation — see
`scripts/orchestrate-triage-classify.sh`'s documented precedence (continuation outranks
blockers whenever a continuation pointer, in either form, is present).

### `plan_markers_verified` (optional, boolean)
Set to `true` when Stage 5a of the implementation agent completed successfully — i.e., all
phase headings in the plan file carry `[COMPLETED]` after the final verification and repair pass.

**Semantics**:
- `true`: Stage 5a ran and confirmed (or repaired) all phase headings to `[COMPLETED]`
- `false` or absent: Stage 5a was skipped, ran but found unresolvable stale markers, or the
  agent did not implement Stage 5a (behavior predating Stage 5a's introduction)

**Orchestrator behavior — the completion-claim verification gate**: `plan_markers_verified` is
a corroborating signal consumed by `skill_gate_completion_claim` (defined once, in
`skill-base.sh`, and called identically from all three sites: base Stage 5, base Stage MT-4, and
hard Stage 5). The gate itself has three fail-closed cases, evaluated in this order, and its own
refusal logic is unconditional and unchanged:

1. **Case 1 — phase accounting present, incomplete** (`phases_total > 0` and
   `phases_completed < phases_total`): always REFUSES.
2. **Case 2 — phase accounting present and complete** (`phases_total > 0` and
   `phases_completed >= phases_total`): always ALLOWS.
3. **Case 3 — phase accounting absent or malformed** (`phases_total == 0`): falls back to
   `plan_markers_verified`. `true` ALLOWS; `false`, absent, `null`, or any other value REFUSES.

**What changed is only which INPUTS the gate sees, not the gate itself.** Its caller
(`orchestrate-cycle-postflight.sh`) now corroborates the plan's own phase markers via
`skill_corroborate_phase_counts` BEFORE calling the gate, for every `implemented` dispatch — not
only when `phases_total == 0` as originally scoped. When corroboration succeeds
(`plan_markers_verified == "true"`, i.e. the plan's own headings show every phase closed via
`[COMPLETED]` or `[COMPLETED WITH EXCLUSIONS]`), the caller supplies the corroborated
`phases_completed`/`phases_total` counts to the gate instead of the handoff's own — which can move
a call that would otherwise land in Case 1 (a handoff understating progress, e.g. a
decision-gate/contingency-branch plan whose handoff still reports the pre-branch counters) into
Case 2. This is the mechanism that lets a branched plan — see
`context/formats/plan-format.md`'s "Decision gates and contingency branches" subsection for the
full shape and a worked example — complete without a new handoff field, a new phase-heading
marker, or a new gate case.

**The fail-closed guarantee is unchanged.** When corroboration does NOT succeed (the plan is
missing, unreadable, has non-conforming headings, or genuinely does not show every phase closed),
the caller leaves the handoff's own `phases_completed`/`phases_total` counters completely
untouched — the call reaches the gate exactly as it would have before this corroboration step
existed, so a genuine shortfall still refuses, and still refuses as an ordinary Case 1 (never
silently reclassified into Case 3's defect-recording path). An agent cannot escape the gate by
under-reporting `phases_total` against an incomplete plan: with no plan to corroborate against
(or a plan that itself confirms the shortfall), the counters and the refusal are exactly what the
handoff reported.

**No handoff field was added.** `phases_total` continues to mean "phases the handoff reports
authored" in every case; it is never redefined to mean something else for a corroborated call. The
evidence for a gate-skipped branch travels entirely through the plan's own phase-heading markers —
an artifact the orchestrator already reads — not through any new field on this schema.

A refusal means the `completed` transition does NOT happen this cycle: the task stays
`implementing`, `cycle_count` still increments, and the existing MAX_CYCLES / MAX_CYCLES_MT caps
bound the retry — the next cycle re-dispatches implement against the same plan. This supersedes
the previous "non-blocking warning only" behavior for the phase-accounting-absent case.

Every gate decision logs one of four greppable shapes (all carry the literal token
`COMPLETION-CLAIM GATE case N/3` plus the task number):
```
${log_prefix} COMPLETION-CLAIM GATE case 2/3 (phase accounting present and complete) task ${task_number}: ${phases_completed}/${phases_total} — allowing completion.
${log_prefix} COMPLETION-CLAIM GATE case 1/3 (phase accounting present, incomplete) task ${task_number}: ${phases_completed}/${phases_total} — refusing completion; task stays implementing.
${log_prefix} COMPLETION-CLAIM GATE case 3/3 (phase accounting absent, plan_markers_verified=true) task ${task_number}: allowing completion on the corroborating marker signal.
${log_prefix} COMPLETION-CLAIM GATE case 3/3 (phase accounting absent, plan_markers_verified=${plan_markers_verified}) task ${task_number}: refusing completion — handoff-writer defect suspected; task stays implementing.
```
`${log_prefix}` is `[orchestrate]` (base and multi-task) or `[hard-orchestrate]` (hard mode).

### Handoff Writers — the settled decision, in one place

`.orchestrator-handoff.json` is formally **hard-mode-implement-only**. Base-mode
research/plan/implement return via `.return-meta.json` (recovered by
`orchestrate-recover-outcome.sh` — see "Outcome Channels" below); research agents never write a
handoff at all, in any mode. This is a decided contract, not a default that happened to emerge.

Core's own standalone hard-mode implementation agent (the former sole core writer, H9 Stage 5)
was deleted along with the rest of core's `-hard` lifecycle skills/agents. Core's
`general`/`meta`/`markdown` task types now resolve hard-mode implement dispatch to the SAME
base-mode `general-implementation-agent` used by standard mode (routing_agents_hard for core was
removed; resolution falls through to routing_agents) — which, per the base-mode row below, never
writes a handoff. **Consequence**: core task types produce no `.orchestrator-handoff.json` under
`--hard` any more than they do under standard mode; only cslib and lean, which still declare
their own hard-mode implementation agents, remain active writers.

| Writer | Status | Continuation form emitted | Notes |
|--------|--------|----------------------------|-------|
| cslib and lean hard-mode implementation agent counterparts | Active | **Flat** `continuation_path` | The only writers of `.orchestrator-handoff.json` today (core's own counterpart is deleted; see above), with two known, named, unlanded gaps left as follow-ups (both extensions are out of this document's declared scope): `cslib-implementation-hard-agent.md` Stage 5 hardcodes `continuation_context: null` with no population instruction, and lacks the `artifacts`-shape spec; `lean-implementation-hard-agent.md` Stage 5 omits `artifacts` entirely and also carries a redundant `continuation_context: null` now that only the flat form is canonical. See `context/contracts/wrap-up.md`'s canonical schema |
| Base-mode `general-research-agent`, `planner-agent`, `general-implementation-agent` (used for BOTH standard and hard-mode dispatch on core task types) | Never writes a handoff, by design | Neither (no handoff written at all) | Research is explicitly prohibited from writing one (the `.orchestrator-handoff.json` — research agents never write one section in the research-agent contracts); plan/implement rely exclusively on `.return-meta.json`. This is the decided, expected, `.return-meta.json`-recoverable case — see "Outcome Channels" below — not an unaddressed defect. |

Every agent contract that could nonetheless end up writing this file carries its own "Defensive
case" paragraph covering exactly that scenario; those paragraphs are the fallback guidance for
this categorical decision, and they pin the `artifacts[]` element shape (see `### artifacts
(required)` above) alongside their `dispatch_seq` echo instruction rather than restating it.

### Writer-Contract Determination (D1) — dispatch-derived, not agent-name-derived

`orchestrate-cycle-postflight.sh` must decide, for every dispatch it postflights, whether "no
handoff" is a genuine defect. This used to be answered by testing the dispatch's `--agent` name
against a small, single-site allowlist (`is_contractual_handoff_writer()`), naming exactly the two
hard-mode agents in the Handoff Writers table above. That allowlist has been **deleted**: it
necessarily drifted behind the agent roster (a live incident recorded an absent-handoff miss from
`general-implementation-agent` — a base-mode agent, never on the list — going completely
unrecorded), and every non-listed agent's absent handoff was silently excused regardless of
whether `.return-meta.json` recovery also failed.

**Current mechanism: `--handoff-expected true|false` (default `true`).** The predicate is derived
from the dispatch itself, not from the agent's name. Every caller of this script is a
`dispatch[]` row — `skill-orchestrate/SKILL.md` Move 3 loops `dispatch[]` only, never
`aux_dispatch[]`, and Move 2 supplies `handoff_path` to every `dispatch[]` row — so by
construction every dispatch reaching this script expects a handoff. The flag exists as the
explicit, narrow opt-out for a caller that knows otherwise (e.g. a future aux path that starts
reaching postflight); nothing calls it with `false` today.

**Where the defect is actually recorded.** WORK (d) (the absent-handoff branch) is reached only
when BOTH the handoff is genuinely absent (never for a present-but-stale or
present-but-mismatched handoff, which already record unconditionally under the mtime/`dispatch_seq`
gates above) AND `.return-meta.json` recovery also declined. This is why the default `true` is
safe for base-mode research/plan/implement agents too: when such an agent writes a valid
`.return-meta.json` (the documented, expected case — see the Handoff Writers table), recovery
succeeds and WORK (d) is never reached at all. WORK (d) only fires on a genuine double miss —
exactly the observed `general-implementation-agent` case — and records
`HANDOFF_STALE_OR_ABSENT` with detecting site `cycle-postflight-absent-expected-writer`, a message
naming the agent, and `transport_error=`/`meta_touched=` annotations (D2) so triage can
distinguish an infra failure from a genuine writer miss. `--handoff-expected false` instead emits
a neutral INFO line and records nothing.

**Registering a new writer**: add a row to the Handoff Writers table above. No script-side
registration step exists any more — the predicate no longer depends on the agent's name.

**No consumer-side dual-shape tolerance exists for this file today.** The direct handoff-artifact
read in `skill-orchestrate/SKILL.md` (both effort modes, one engine) is a raw, unguarded
`jq -r '.artifacts[0].path // ""'` — there is no tolerance to remove or retain, and a future
reader should not search for one.

**The nested-form writer has been deleted.** The Bash-redirect helper function that formerly
lived in `agent-system/extensions/core/scripts/skill-base.sh` — previously defined with zero
callers — has been removed entirely. Its deletion is what collapses the continuation pointer down to one
canonical writable form (see "One Write Form, Deprecated-But-Accepted Read Form" above); the
nested `continuation_context` shape survives only as a deprecated, read-only-accepted schema
property for backward compatibility with handoffs written before the deletion.

`agent-system/extensions/core/scripts/validate-handoff.sh` enforces exactly the schema documented
above: `phases_completed` and `phases_total` as top-level required fields (its `required_fields`
array reads them via `jq ".phases_completed"` / `jq ".phases_total"`, not
`.continuation_context.phases_completed` / `.continuation_context.phases_total`), the full
six-value `status` vocabulary, and the `artifacts`/`summary` presence-and-shape checks described
in `context/schemas/orchestrator-handoff-schema.json`.

**`validate-handoff.sh` wiring status**: this script is invoked as a **log-only, non-gating**
producer-defect diagnostic from `skill_corroborate_phase_counts()` in
`agent-system/extensions/core/scripts/skill-base.sh`, firing only when that function receives a
non-empty, existing `handoff_path` argument (the handoff-present corroboration call sites in
`skill-orchestrate/SKILL.md` Stage 5, both effort modes, pass the current handoff; the
recovery-path call sites pass an empty string, since there is no handoff to validate there). Its
exit status never influences `skill_corroborate_phase_counts()`'s own return value or the
completion-claim gate.

---

## Outcome Channels

**One channel per mode, by decision.** Hard-mode implement writes `.orchestrator-handoff.json`
and only that; base-mode research/plan/implement write `.return-meta.json` and only that. Neither
is a fallback bolted onto the other's absence — each mode has exactly one designated channel, and
the "missing handoff" branch below fires by design for base-mode dispatches every time, not as an
error condition.

`.orchestrator-handoff.json` is the outcome channel Stage 5 (single-task, base and hard mode) and
Stage MT-4 step 1 (multi-task) read after a dispatch, for the one mode that writes it — see
Handoff Writers above.

`.return-meta.json` is read inside the missing/stale-handoff branch, which is the expected,
every-time path for the writers in the "Never writes a handoff, by design" row: a missing handoff
from base-mode research, plan, or implement is the designed outcome for those writers, not a
defect, since `.return-meta.json` is written by every research/plan/implement dispatch (base and
hard mode alike) per each skill's own Stage 7 postflight contract.

`agent-system/extensions/core/scripts/orchestrate-recover-outcome.sh` is the single, shared
implementation of this fallback — the ONE place that normalizes `.return-meta.json`'s `status`,
`artifacts[0]`, and phase-accounting fields into the same outcome shape Stage 5 already reads from
a handoff (`recovered`, `status`, `phases_completed`, `phases_total`, `artifact_path/type/summary`,
plus a `reason` token for the non-recovered case). Base Stage 5, hard-mode Stage 5, and multi-task
Stage MT-4 step 1 each call this one script rather than maintaining three separately-derived
recovery rules. See that script's own header for its full field/exit-code contract, and see the
"MUST NOT (Context Flatness Constraint) — Recovery exception (return-meta fallback)" section in
`skills/skill-orchestrate/SKILL.md` for the token-budget and fail-closed bounds it operates under.

A recovered outcome is fail-closed: only a present, fresh (within the current dispatch window),
parseable `.return-meta.json` whose `status` is `researched`, `planned`, or `implemented` is ever
treated as a success. A missing, stale, unparseable, `in_progress`, or otherwise non-success
`.return-meta.json` preserves the pre-existing missing-handoff error path exactly, unchanged by
this fallback. This three-value accept-list is drawn from the same normative vocabulary in
`context/formats/return-metadata-file.md` as the schema field above — it is restated here only
because it is a strict subset (the success values), not a competing enumeration.

**Freshness is orthogonal to vocabulary, by design.** The accept-list above needed no change when
the skill-status vocabulary's forbidden `"completed"` writer was fixed elsewhere (Stage 8 of
`skill-orchestrate/SKILL.md` now emits `"implemented"`): this script's gate is `meta_mtime` versus
the current dispatch's `window_start_ts`, not the status string. A `.return-meta.json` left over
from a *previous* invocation's Stage 8 always has an mtime before the current invocation's
`window_start_ts` and is therefore classified stale regardless of what status value it contains.
Do not couple these two mechanisms — a future change to the status vocabulary should never need a
corresponding change here, and vice versa.

**`completion_summary` / `roadmap_items` live exclusively in `.return-meta.json`, never in this
handoff.** The JSON Schema above has no `completion_summary` or `roadmap_items` field, and none
should ever be added to it: these two values are completion metadata (see
`context/formats/return-metadata-file.md`'s `completion_data` object), not dispatch-outcome
metadata, and they are read exclusively through `orchestrate-recover-outcome.sh`'s
`completion_summary`/`roadmap_items` output fields — regardless of whether a handoff is present or
missing for that dispatch. This matters most for hard mode: its implement dispatch ALWAYS writes
a handoff (H9 wrap-up), so its `implemented` outcome is read from the handoff-present branch, not
the recovery branch above — if a future editor assumed the handoff carried completion data (by
analogy with `status`/`phases_completed`/artifact fields, which it does carry), the propagation
would silently break again. Every `implemented)` postflight site (base Stage 5, hard Stage 5,
Stage MT-4 step 3) therefore issues its own `orchestrate-recover-outcome.sh` read for this purpose
independently of which branch supplied `dispatch_status`, reusing that cycle's already-recovered
JSON when the recovery branch already ran rather than reading the file twice.

---

## Token Budget Constraints

The full `.orchestrator-handoff.json` object MUST stay under **400 tokens**. This is the mechanism
that keeps orchestrator context flat across cycles.

Field-level budgets:
| Field | Max Tokens |
|-------|-----------|
| `summary` | ~100 |
| `artifacts` (all entries) | ~50 |
| `blockers` (all entries) | ~100 |
| `decisions_made` (all entries) | ~50 |
| `dead_ends` (all entries) | ~50 |
| `files_modified` (all entries) | ~30 |
| `continuation_path` OR `continuation_context` (whichever form is present; never both) | ~20 |
| Schema overhead (field names, JSON structure) | ~50 |

If content would exceed 400 tokens, truncate `decisions_made` and `dead_ends` first (these are
advisory). Never truncate `status`, `summary`, or `blockers`.

---

## Writing Contract

### When to Write

Only the hard-mode implementation agent writes `.orchestrator-handoff.json` — see "Handoff
Writers" above for the settled, one-channel-per-mode contract. `orchestrator_mode: true` in the
delegation context is a necessary condition (the file is never written outside orchestrator
dispatch) but not a sufficient one: base-mode research/plan/implement also receive
`orchestrator_mode: true` under `/orchestrate`, and correctly write `.return-meta.json` only,
never this file.

```bash
# In a hard-mode implementation agent's Stage 5 (cslib/lean; core's own is deleted), after
# receiving delegation context:
orchestrator_mode=$(echo "$delegation_context" | jq -r '.orchestrator_mode // "false"')

if [ "$orchestrator_mode" = "true" ]; then
  write_orchestrator_handoff   # hard-mode implement only
fi
```

When NOT in orchestrator mode (normal `/research`, `/plan`, `/implement` invocation), or when in
base mode, no skill writes this file. The file's presence signals a hard-mode implement dispatch
specifically, not orchestrator dispatch in general.

### File Path

```bash
handoff_path="specs/${padded_num}_${project_name}/.orchestrator-handoff.json"
```

The filename is static (not timestamped). Each dispatch cycle overwrites the previous handoff.
There is no session-scoped variant: per-task directories already isolate concurrent
different-task sessions, and `task-lock.sh`'s acquire/heartbeat/release contract already
serializes concurrent same-task sessions, so a session component here would add nothing.

### When to Write a Continuation Pointer

Write `continuation_path` — the one canonical writable form (see "One Write Form,
Deprecated-But-Accepted Read Form" above) — only when the skill returns `status = "partial"` AND
a continuation handoff file was written by the agent. The continuation handoff path comes from
the agent's `.return-meta.json` `partial_progress.handoff_path` field. Hard-mode wrap-up (the
only writer) writes this flat top-level string, per `context/contracts/wrap-up.md`. Do NOT write
the nested `continuation_context` object — it is deprecated and read-only-accepted; no writer
should ever produce it again.

### `orchestrator_mode` Flag in Continuation Context

A flat `continuation_path` string carries no `orchestrator_mode` field of its own — there is
nowhere on a bare string to attach one. The **reader** supplies `orchestrator_mode: true` during
normalization: every reader site (the classifier and both SKILL.md engines) resolves whichever
form is present (the canonical flat form from a live writer, or a deprecated nested form from a
pre-deletion handoff) and builds `{ handoff_path: <resolved path>, orchestrator_mode: true }`
before handing the result to the next dispatch as `continuation_context`. This normalization is
unconditional — `orchestrator_mode: true` is set regardless of which form supplied
`handoff_path`.

A pre-deletion handoff that still carries the nested form directly (from when its
now-deleted writer function was live) would have preserved the `orchestrator_mode` flag itself,
since the value already existed on the object being written rather than being synthesized by the
reader (abbreviated fragment below — `summary`, `artifacts`, and `blockers` omitted for brevity;
it will not independently pass `validate-handoff.sh`):

```json
{
  "status": "partial",
  "phases_completed": 2,
  "phases_total": 4,
  "continuation_context": {
    "handoff_path": "specs/.../handoffs/phase-2-handoff-T.md",
    "orchestrator_mode": true
  }
}
```

Either way — reader-synthesized (the live flat form) or writer-preserved (a legacy nested-form
handoff still on disk) — the next implement dispatch receives `orchestrator_mode: true` and
continues operating in orchestrator mode rather than re-enabling the inner continuation loop.

---

## Reading Contract

The orchestrator reads the handoff after each dispatch:

```bash
handoff_file="specs/${padded_num}_${project_name}/.orchestrator-handoff.json"

# Safety: check file exists before reading
if [ ! -f "$handoff_file" ]; then
  echo "[orchestrate] ERROR: handoff not written by skill (orchestrator_mode not detected?)"
  exit 1
fi

# Read only what the state machine needs — do NOT load full artifacts
handoff=$(cat "$handoff_file")
status=$(echo "$handoff" | jq -r '.status')
blockers=$(echo "$handoff" | jq -c '.blockers // []')
next_hint=$(echo "$handoff" | jq -r '.next_action_hint // "none"')
# Dual-form resolution + normalization: accept EITHER the deprecated nested
# continuation_context.handoff_path OR the canonical flat top-level continuation_path (see
# "One Write Form, Deprecated-But-Accepted Read Form" above), and normalize the result to a
# single shape before it reaches a downstream dispatch context.
continuation=$(echo "$handoff" | jq -c '
  ((.continuation_context // null) | if . != null then (.handoff_path // null) else null end) as $nested |
  (.continuation_path // null) as $flat |
  ($nested // $flat) as $resolved |
  if $resolved != null then {handoff_path: $resolved, orchestrator_mode: true} else null end
')
artifacts=$(echo "$handoff" | jq -c '.artifacts // []')
phases_completed=$(echo "$handoff" | jq -r '.phases_completed // 0')
phases_total=$(echo "$handoff" | jq -r '.phases_total // 0')
plan_markers_verified=$(echo "$handoff" | jq -r '.plan_markers_verified // "absent"')
```

This dual-form resolution is applied identically at every reader site:
`scripts/orchestrate-triage-classify.sh`'s `continuation_ok` predicate, and
`skill-orchestrate/SKILL.md` (Stage 4 partial handler and hard-mode H1 branch, Stage 5 result
read, Stage MT-4 dispatch bullet — one engine, both effort modes). It is one rule, applied in
several places — never independently re-derived.

When `status = "implemented"`, the orchestrator additionally calls
`skill_gate_completion_claim` (see the `plan_markers_verified` field definition above) to decide
whether the `completed` transition is corroborated. This introduces NO new file read — it
consumes only fields already parsed out of the handoff object above, so the ~450-tokens-per-cycle
context-flatness invariant is unchanged and the three sanctioned grep exceptions table below is
unaffected.

On the normal path the orchestrator reads the ~400-token handoff object and nothing else — it
never opens research reports, plan files, or implementation summaries for comprehension. Three
narrow, grep-only exceptions are sanctioned, and all three are bounded to `### Phase N: ...
[STATUS]` heading lines or equivalent pattern matches, never full-file reads:

| Exception | Variant | When it fires | Bound |
|-----------|---------|---------------|-------|
| Adversarial-verification grep over reports | hard mode | Stage 4, before the plan dispatch | Pattern match; no full-file read |
| Next-phase selection grep over the plan | hard mode | Stage 4 `planned`/`implementing` handler, every cycle | One matched heading, reduced to a phase number |
| Phase-marker recovery grep over the plan | base + hard | Stage 5, missing/stale-handoff branch only | Two `grep -c` integers, ≤10 tokens per recovery event |

Outside these three, the reading contract is unchanged: the handoff object is the sole channel
by which artifact content reaches the orchestrator. See the "Recovery exception (phase-marker
grep)" contract and Read allowlist, both in `skill-orchestrate/SKILL.md`, for the binding
wording.

---

## Example Handoff Objects

**Note on scope**: `.orchestrator-handoff.json` is written today by exactly one writer — the
hard-mode implementation agent (see "Handoff Writers" above) — so in practice only
`implemented`/`partial`/`failed`/`blocked` statuses ever appear on disk. The `researched` and
`planned` examples below remain schema-valid and are kept as illustrations of the full six-value
`status` vocabulary the schema shares with `.return-meta.json`
(`context/formats/return-metadata-file.md`); they do not describe a live write path for research
or plan dispatches, which never write this file at all.

### Successful Research (schema-illustrative; no live writer produces this today)

```json
{
  "status": "researched",
  "summary": "Researched shared command infrastructure patterns across research.md, plan.md, and implement.md. Found ~525 lines of identical duplication across 3 commands. Identified 3 extraction candidates: parse-command-args.sh, command-gate-in.sh, command-gate-out.sh.",
  "artifacts": [
    {"type": "report", "path": "specs/593_extract_shared_workflow_utilities/reports/01_extraction-research.md"}
  ],
  "phases_completed": 0,
  "phases_total": 0,
  "blockers": [],
  "next_action_hint": "plan",
  "files_modified": [],
  "decisions_made": [
    "Extraction to .claude/scripts/ is preferred over context documents (scripts can be executed)"
  ],
  "dead_ends": []
}
```

### Successful Implementation

```json
{
  "status": "implemented",
  "summary": "Implemented all 3 shared command scripts. parse-command-args.sh, command-gate-in.sh, and command-gate-out.sh created. research.md, plan.md, implement.md updated to source shared scripts. All verification tests passed.",
  "artifacts": [
    {"type": "summary", "path": "specs/593_extract_shared_workflow_utilities/summaries/01_extraction-summary.md"}
  ],
  "phases_completed": 3,
  "phases_total": 3,
  "blockers": [],
  "next_action_hint": "none",
  "files_modified": [
    ".claude/scripts/parse-command-args.sh",
    ".claude/scripts/command-gate-in.sh",
    ".claude/scripts/command-gate-out.sh",
    ".claude/commands/research.md",
    ".claude/commands/plan.md",
    ".claude/commands/implement.md"
  ],
  "decisions_made": [
    "Command files now source shared scripts via 'source .claude/scripts/NAME.sh'",
    "Existing update-task-status.sh and validate-artifact.sh left unchanged"
  ],
  "dead_ends": [],
  "plan_markers_verified": true
}
```

### Partial with Continuation (the one canonical form)

This is the shape hard-mode H9 wrap-up (Stage 5 of a hard-mode implementation agent — today only
cslib's and lean's, since core's own is deleted; see "Handoff Writers" above) emits — a flat
top-level `continuation_path` string, per `context/contracts/wrap-up.md`:

```json
{
  "$schema": "orchestrator-handoff-v1",
  "phase": "implement",
  "status": "partial",
  "summary": "Completed phases 1-2 of 4 (parse-command-args.sh and command-gate-in.sh created). Context exhaustion during phase 3. Continuation handoff written at specified path.",
  "artifacts": [
    {"type": "summary", "path": "specs/593_extract_shared_workflow_utilities/summaries/01_extraction-summary.md"}
  ],
  "blockers": [],
  "next_action_hint": "implement",
  "files_modified": [
    ".claude/scripts/parse-command-args.sh",
    ".claude/scripts/command-gate-in.sh"
  ],
  "decisions_made": [
    "parse-command-args.sh exports FOCUS_PROMPT as remaining text after all flags stripped"
  ],
  "dead_ends": [],
  "phases_completed": 2,
  "phases_total": 4,
  "continuation_path": "specs/593_extract_shared_workflow_utilities/handoffs/phase-3-handoff-20260522T120000Z.md"
}
```

The orchestrator reader resolves `continuation_path` above and normalizes it to
`{ handoff_path: "specs/593_extract_shared_workflow_utilities/handoffs/phase-3-handoff-20260522T120000Z.md", orchestrator_mode: true }`
before passing it to the next implement dispatch — see "Reading Contract" below.

### Partial with Continuation (deprecated nested form — no writer emits this today)

**No live writer produces this shape.** It is shown here only because every reader still accepts
it for backward compatibility with a handoff written before the nested-form writer function
(formerly in `scripts/skill-base.sh`) was deleted — see "Handoff Writers" and "One Write Form,
Deprecated-But-Accepted Read Form" above. Do not use this shape as a template for a new writer:

```json
{
  "$schema": "orchestrator-handoff-v1",
  "phase": "implement",
  "status": "partial",
  "summary": "Completed phases 1-2 of 4 (parse-command-args.sh and command-gate-in.sh created). Context exhaustion during phase 3. Continuation handoff written at specified path.",
  "artifacts": [
    {"type": "summary", "path": "specs/593_extract_shared_workflow_utilities/summaries/01_extraction-summary.md"}
  ],
  "blockers": [],
  "next_action_hint": "implement",
  "files_modified": [
    ".claude/scripts/parse-command-args.sh",
    ".claude/scripts/command-gate-in.sh"
  ],
  "decisions_made": [
    "parse-command-args.sh exports FOCUS_PROMPT as remaining text after all flags stripped"
  ],
  "dead_ends": [],
  "phases_completed": 2,
  "phases_total": 4,
  "continuation_context": {
    "handoff_path": "specs/593_extract_shared_workflow_utilities/handoffs/phase-3-handoff-20260522T120000Z.md",
    "orchestrator_mode": true
  }
}
```

### Blocked with Escalation Required

```json
{
  "status": "partial",
  "summary": "Implemented parse-command-args.sh successfully. Blocked at command-gate-in.sh: the current update-task-status.sh script does not export SESSION_ID, which is required by the gate-in design.",
  "artifacts": [],
  "blockers": [
    {
      "phase": 2,
      "target": "command-gate-in.sh SESSION_ID generation",
      "verbatim_goal": "command-gate-in.sh generates SESSION_ID for use by downstream postflight",
      "what_was_tried": "Sourced update-task-status.sh expecting it to export SESSION_ID",
      "why_it_failed": "update-task-status.sh does not export SESSION_ID; command-gate-in.sh needs to generate it independently or update-task-status.sh needs modification"
    }
  ],
  "phases_completed": 1,
  "phases_total": 3,
  "next_action_hint": "revise",
  "files_modified": [".claude/scripts/parse-command-args.sh"],
  "decisions_made": [],
  "dead_ends": [
    "Tried sourcing update-task-status.sh to get SESSION_ID — it does not set this variable"
  ]
}
```

---

## Relationship to Continuation Handoffs

The orchestrator handoff and continuation handoff are written by different components and read by
different consumers:

```
a hard-mode implementation agent (H9 wrap-up — cslib/lean today; core's own is deleted):
  ├── Writes: handoffs/phase-2-handoff-T.md   (for successor agent)
  └── Writes: .orchestrator-handoff.json      (for skill-orchestrate)
              └── continuation_path = "handoffs/phase-2-handoff-T.md"   (the one canonical
                  writable form — see "One Write Form, Deprecated-But-Accepted Read Form" above)

skill-orchestrate (next cycle, either effort mode — one engine):
  ├── Reads: .orchestrator-handoff.json       (400 tokens)
  │          └── resolves continuation_path (or a deprecated legacy continuation_context.handoff_path)
  └── Passes: normalized continuation_context = { handoff_path, orchestrator_mode: true }
              to next implement dispatch
              └── successor agent reads: handoffs/phase-2-handoff-T.md
```

The two files are never confused because:
1. They are in different locations (`.orchestrator-handoff.json` vs. `handoffs/*.md`)
2. They use different formats (JSON vs. Markdown)
3. They are read by different components (skill-orchestrate vs. successor agent)

---

## Postflight Boundary

This is distinct from, and additive to, the Context Flatness Constraint (`docs/architecture/orchestrate-cycle-postflight.md` and `skill-orchestrate/SKILL.md`'s own `## MUST NOT` section): that constraint bounds what the lead reads between dispatches; this section bounds what the lead *does*. After each stage dispatch (research/plan/implement) returns, the lead MUST NOT:

1. **Edit source files** — all research, planning, and implementation work is done by the dispatched skill/agent, never by the orchestrator's own loop.
2. **Run build/test commands** — verification is done by the dispatched skill/agent.
3. **Use MCP/WebSearch/domain tools** — domain tools are for the dispatched skill/agent's use only.
4. **Analyze or grep source** — analysis is dispatched-skill work.
5. **Write reports/plans/summaries** — artifact creation is dispatched-skill work. **One narrow,
   named exception (D4)**: when `orchestrate-cycle-postflight.sh` reports `report_missing: true`
   for a research-phase dispatch (its report file or `.return-meta.json` was missing or empty,
   and no outcome was recovered), the lead writes that dispatch's own Agent-tool return text
   **verbatim** — no summarizing, no editing, no analysis — to a local capture file, then calls
   `orchestrate-recover-message-findings.sh` (a mechanical, narrowly-scoped script, not the
   lead's own judgment) to persist it into the task's `reports/` directory under a
   clearly-tagged "recovered from agent message" banner that states plainly it is not a
   completed report. Persisting a subagent's own already-produced text verbatim is
   preservation, not authorship: the lead adds no new content and edits nothing. This exception
   is scoped exclusively to this one script-mediated path — it does not license the lead to
   write, edit, or synthesize report/plan/summary content by any other means.

The per-dispatch postflight phase is limited to: reading the dispatch's `.orchestrator-handoff.json` (or the bounded return-meta/phase-marker recovery exceptions the Context Flatness doc names), driving the state-machine transition to the next stage, cleanup of temp/marker files, and the one named exception in item 5 above. `orchestrate-cycle-postflight.sh` is the sole implementation of this boundary for every task in a batch (including a batch of one) — there is no second, inline copy of this logic in `skill-orchestrate/SKILL.md` to keep in sync. `lint-postflight-boundary.sh` enforces that `skill-orchestrate/SKILL.md` carries a heading its heuristic can locate as this boundary's home; see that script's own header for the current heading pattern it matches.

Reference: `context/standards/postflight-tool-restrictions.md`.

---

## Decisions File Schema (`.decisions.json`)

`specs/{NNN}_{slug}/.decisions.json` persists the answers to `user_decision` questions the loop's
batched `AskUserQuestion` relay has already asked and the user has already answered, so a later
dispatch file (built by `orchestrate-build-dispatch.sh`) can carry the settled answer forward
instead of the same question surfacing again. The file does not exist until the first cycle in
which the loop asks and receives an answer for that task; its absence is the normal, expected
state for a task that has never surfaced a `user_decision`.

**Shape**: a JSON array of entries, each carrying at minimum:

```json
[
  {
    "question": "Which logging backend should the new metrics pipeline use?",
    "answer": "Use the existing structured-logging module; do not add a new dependency.",
    "cycle": 3,
    "timestamp": "2026-09-08T04:00:00Z"
  }
]
```

- `question` (string, required) — the question text exactly as surfaced to `AskUserQuestion`.
- `answer` (string, required) — the user's chosen answer (or free-text response).
- `cycle` (integer, required) — the loop cycle number during which the question was asked and
  answered (so a later reader can tell how stale the decision is relative to the current cycle).
- `timestamp` (string, required, ISO 8601 UTC) — when the answer was recorded.

**Writer**: the loop's own branch move, after every other task's postflight has run for the
cycle, batches every accumulated `ask_user` verdict into one `AskUserQuestion` call and appends
one entry per answered question to this file (creating it if absent). This is additive —
existing entries are never removed or rewritten by a later cycle's append.

**Reader**: `orchestrate-build-dispatch.sh` (see its own header comment and the "## Prior
Decisions" section it conditionally emits) reads this file when building the NEXT dispatch file
for the same task, rendering every entry so the dispatched agent can see what has already been
settled rather than re-surfacing the same ambiguity. `orchestrate-cycle-postflight.sh` never
writes this file — see the Context Flatness / Postflight Boundary sections above for why a
per-task postflight body must not itself prompt or persist a user-facing decision; only the
lead's own loop-level branch move, running after every task's postflight for the cycle has
completed, does that.
