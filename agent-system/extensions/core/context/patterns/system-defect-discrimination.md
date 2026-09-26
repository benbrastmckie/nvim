# System-Defect vs. Task-Work Discrimination

Distinguishes a defect IN THE AGENT SYSTEM ITSELF (a bug in an agent definition, skill, hook, or
script under `agent-system/extensions/**`) from an ordinary failure of the user's task work (a
Lean proof that will not compile, a plan that is incomplete, a research report the user rejects),
so the former can eventually be turned into a durable, deduplicated record and the latter is left
to the ordinary `failed`/`partial`/`blocked` task-status machinery untouched.

This document settles the discrimination contract and enumerates the sites where such defects are
already detected. It is modelled closely on
[Infra-Failure vs. Work-Cycle Discrimination](infra-failure-discrimination.md), which solves a
structurally identical two-signal discrimination problem (transport error vs. genuine work
cycle) — the same section shape, the same conservative-default reasoning, and the same explicit
warning against weakening the rule are reused here rather than reinvented.

**Scope of this document**: the predicate, the detection-point registry, the recursion-guard
rule, and the deduplication rule. It defines no recorder script, wires no detection site, and
changes no command — those are downstream work that must encode, not re-derive, the answers
below.

## The motivating case

An autonomous run dispatched a research agent for two tasks. Both produced correct, fully
verified research, but both wrote a status value outside the normative vocabulary (see
[return-metadata-file.md](../formats/return-metadata-file.md) lines 88-94:
`in_progress|researched|planned|implemented|partial|failed|blocked`) plus an artifacts array of
bare path strings instead of `{type, path, summary}` objects. The orchestrator's off-schema
branch behaved correctly: it emitted a loud `[OFF-SCHEMA DISPATCH STATUS ...]` banner, refused
the status transitions, and charged both tasks to `failed_tasks`. And then it stopped. Nothing
connected "this is a defect in an agent definition" to "a fix task should be created against the
source store." A human noticed the banner, diagnosed the root cause across five files, and
invoked `/meta` by hand. Closing that manual hop is the point of this work.

### The dead-signal finding

Half of the motivating defect was **already detected and discarded**. This is the sharpest single
piece of evidence for why a discrimination contract — not just louder banners — is needed.

`scripts/orchestrate-recover-outcome.sh` line 205 sets
`evidence_reason="ARTIFACTS_SHAPE_MISMATCH"`, and the in-file comment already explains exactly why
it matters (lines 92-93): *"A non-empty array yielding no path is proof of a shape mismatch (e.g.
a bare-string array), not proof of 'no artifacts'."*

**Historical note (citations superseded by the four-move loop rewrite)**: at the time this
document was written, every site that reads `evidence_reason` lived inline in the single-task
engine and gated on `PHASES_ZERO_ON_SUCCESS` alone, ignoring `ARTIFACTS_SHAPE_MISMATCH` entirely —
four dead-signal consumer sites at specific `skill-orchestrate/SKILL.md` line numbers. That engine
is now deleted; the single shared per-task postflight body,
`scripts/orchestrate-cycle-postflight.sh`, is both consumer sites' current home, and BOTH now
gate on `ARTIFACTS_SHAPE_MISMATCH` explicitly (verified against current file text, 2026-09-08):

- `scripts/orchestrate-cycle-postflight.sh` (handoff-present path, "Advisory
  ARTIFACTS_SHAPE_MISMATCH probe" section) — records `ARTIFACTS_SHAPE_MISMATCH` via
  `skill_orchestrate_append_detected_defect`
- `scripts/orchestrate-cycle-postflight.sh` (recovered `.return-meta.json` path, the
  `evidence_reason` check alongside `PHASES_ZERO_ON_SUCCESS`) — records `ARTIFACTS_SHAPE_MISMATCH`
  via the same function

The dead-signal gap this section originally documented is closed; this paragraph is kept as
motivating-case history, not a live defect report.

## The predicate

A system defect is registered **iff both signals hold**.

| Signal | Kind | Question it answers |
|--------|------|----------------------|
| A — schema violation | mechanical, bash-checkable | Is the failure a violation of a schema the agent system **itself** owns? |
| B — attribution | mechanical, bash-checkable | Is the violation attributable to a **named** source-store file under `agent-system/extensions/**`? |

**Classification: system defect iff A AND B. Every other combination is task work.** Both signals
are already-computed booleans by the time either is consulted; neither requires new LLM judgment
— this mirrors infra-failure-discrimination.md's own framing exactly (`dispatch_was_transport_error`
and `meta_touched` are likewise pre-computed booleans, not judgments made at classification time).

### Signal A — schema violation instances

Signal A is `true` for any of these (a closed, extensible list — extending it is a future task's
decision, not silently done by a detection site):

| Instance | Where it is already computed |
|----------|-------------------------------|
| `OFF_SCHEMA_STATUS` — a status value outside the seven-value normative enum (`researched\|planned\|implemented\|needs_research\|partial\|failed\|blocked`; `in_progress` is a valid non-terminal marker, not a violation) | Tier C branches, see registry below |
| `ARTIFACTS_SHAPE_MISMATCH` — an artifacts array that is non-empty but yields no `.path` | `scripts/orchestrate-recover-outcome.sh:205` |
| `HANDOFF_MISLOCATED` — a handoff written outside its task directory | the stray-handoff sweep, see registry below |
| `META_MISSING_AFTER_NARRATION` — a `.return-meta.json` missing or unparseable after a dispatch that produced subagent-authored narration (i.e., not the infra-failure case — see [infra-failure-discrimination.md](infra-failure-discrimination.md) for that adjacent, already-solved discrimination) | the completion-claim gate, see registry below |
| `ARTIFACTS_MISSING_ON_SUCCESS` — a `null`, absent, or empty `artifacts` field accompanying a success status (`researched\|planned\|implemented`), where both owning schemas mark the field required ([return-metadata-file.md](../formats/return-metadata-file.md)'s `### artifacts (required)` section and [handoff-schema.md](../../docs/architecture/handoff-schema.md)'s `### \`artifacts\` (required)` section); ALSO fires when `artifacts[0].path` is populated but the file it names does not exist, or exists empty, on disk — the field is present but the artifact it promises was never actually produced | `orchestrate-cycle-postflight.sh`'s research report gate (`researched)` case, detecting site `cycle-postflight-research-report-gate`) — phase=research only; plan and implement are still **not currently computed anywhere** for this instance |
| `HANDOFF_STALE_OR_ABSENT` — a handoff whose mtime predates the dispatch window (or is otherwise absent when expected), as detected by the stale-handoff gate | the stale-handoff gate, see registry below |
| `SOURCE_STORE_BOUNDARY_VIOLATION` — a direct write under `.claude/**` instead of the source store (`agent-system/extensions/**`) | `hooks/validate-meta-write.sh` |
| `TASK_REFERENCE_IN_DELIVERABLE` — a task-number citation in a deliverable outside `specs/**` | `hooks/validate-no-task-references.sh` |
| `ARTIFACT_FORMAT_VIOLATION` — an artifact write under `specs/*/{plans,reports,summaries}/*.md` that fails format validation | `hooks/validate-plan-write.sh` |
| `STATE_SYNC_DIVERGENCE` — `state.json`/`TODO.md` desynchronization | `hooks/validate-state-sync.sh` |
| `SESSION_LOCK_CONTENTION` — a task-lock acquire/release call keyed to a session-id string that does not match the session-id used to register the same unit of work elsewhere (e.g. batch admission), so exact-match self-exclusion logic spuriously contends against the caller's own registration | **not currently computed anywhere** |
| `HOOK_REGEX_BOUNDARY_DEFECT` — a validation hook's regex or path-depth pattern encodes an unstated boundary assumption (e.g. a fixed digit-count quantifier) that silently breaks once real inputs cross that boundary, wrongly rejecting (or wrongly accepting) otherwise-valid inputs | **not currently computed anywhere** |
| `DEPLOY_ORPHAN_DRIFT` — a file or index entry present in the deployed tree with no corresponding source-store owner, surviving indefinitely because the deploy/merge routine is purely additive with no stale-entry pruning step | **not currently computed anywhere** |
| `AMBIENT_BINDING_MISMATCH` — a downstream guard keyed to an ambient/global shell variable that only some callers populate, so the guard's condition silently evaluates false instead of erroring, and the guarded behavior is skipped without any signal | **not currently computed anywhere** |
| `RECOVERY_DECLINED` — a dispatch wrote no handoff, but `orchestrate-recover-outcome.sh`'s `.return-meta.json` recovery declined for a reason that means a terminal marker was written and read, not that nothing was produced: `STATUS_IN_PROGRESS` (a terminal write never happened — the interrupted-fan-out shape) or `STATUS_NOT_SUCCESS` (an out-of-vocabulary terminal status value, e.g. `"completed"`). Distinguished from `HANDOFF_STALE_OR_ABSENT`, which stays handoff-shaped and covers the case where recovery declines because nothing usable exists at all (`META_MISSING`, `META_STALE`, `META_DISPATCH_SEQ_MISMATCH`, or the genuinely stale-mtime handoff) | `orchestrate-cycle-postflight.sh`'s WORK (d) absent-handoff branch, discriminated on `recover_json`'s `.reason` field — see registry below |

Not every instance above yet has a working detector — see the `ARTIFACTS_MISSING_ON_SUCCESS` row:
it defines what counts as a violation of this kind, not what currently fires everywhere it could.
A detector now exists for the research-phase, file-missing-on-disk sub-case (the row above); the
`null`/absent/empty-field sub-case, and plan/implement phase coverage generally, remain downstream
work — adding a detector for one sub-case does not widen this task's scope to cover the others (no
recorder, no wiring, no command change beyond what the row above already names).

**Empirical finding motivating the row above**: the existing `ARTIFACTS_SHAPE_MISMATCH` detector
(`scripts/orchestrate-recover-outcome.sh:205`, comment at lines 92-93 above) has exactly two firing
arms — `artifacts_length > 0` with an empty resolved path, and a non-zero `jq` exit while resolving
`artifact_path`/`artifact_type`/`artifact_summary` (`jq_artifact_failure`). A `null` or absent
`artifacts` field satisfies **neither** arm:

```
$ echo '{"status":"planned","artifacts":null}' | jq -r '(.artifacts // []) | length'
0
$ echo '{"status":"planned","artifacts":null}' | jq -r '.artifacts[0].path // ""'; echo $?
       # (empty output)
0
```

Both arms report clean (`evidence_suspect=false, evidence_reason="NONE"`) even though the field is
required by both owning schemas. By contrast, the bare-string-array form (`artifacts:
["some/path.md"]`) exits non-zero while indexing `.path` on a string, so it **does** fire — but via
the `jq_artifact_failure` arm, not the length-and-empty-path arm the in-file comment's prose
describes as the mismatch's signature. This is not hypothetical: a planner handoff during this same
task's own orchestration run emitted `status: "planned"` with `artifacts: null`, and the artifact
row had to be reconstructed by hand because no detector fired on either arm.

A missing required field is a schema *violation*, not a conformant failure — see "A
schema-conformant failure is always task work" below; this new instance does not weaken that
invariant, it names a previously-unlisted violation of the same kind the other four instances
already cover.

### Extending the Signal A vocabulary is an explicit decision, not a silent act

Per this section's own opening clause — "a closed, extensible list — extending it is a future
task's decision, not silently done by a detection site" — the five instances added above
(`HANDOFF_STALE_OR_ABSENT`, `SOURCE_STORE_BOUNDARY_VIOLATION`, `TASK_REFERENCE_IN_DELIVERABLE`,
`ARTIFACT_FORMAT_VIOLATION`, `STATE_SYNC_DIVERGENCE`) were added deliberately, by downstream work
that wires a recorder to sites this document's own registry already names as ready (Class (a)'s
stale-handoff gate and Class (c)'s five hooks). None of the five pre-existing instances was
reworded or reinterpreted to cover a new site; each new instance names a site that previously
mapped to no Signal A instance at all. This is recorded here, in the document that owns the
enum, rather than left implicit in a recorder's validation logic.

A further three instances (`SESSION_LOCK_CONTENTION`, `HOOK_REGEX_BOUNDARY_DEFECT`,
`DEPLOY_ORPHAN_DRIFT`) were added deliberately, to name three concrete recorded defect shapes: a
lock/session self-contention where an acquire/release call is keyed to a session-id that does not
match the session-id used to register the same unit of work elsewhere; a hook-regex path-depth
boundary defect where a validation hook's pattern encodes an unstated boundary assumption that
silently breaks once real inputs cross it; and deploy ghost index entries / undercounted orphan
files that survive indefinitely because the deploy/merge routine is purely additive with no
stale-entry pruning step. None of the ten pre-existing instances was reworded or reinterpreted to
cover these shapes, and no recorder was wired for any of the three — naming the vocabulary and
instrumenting a detection site remain separate, sequential pieces of work, as with
`ARTIFACTS_MISSING_ON_SUCCESS` above.

`HOOK_REGEX_BOUNDARY_DEFECT` has since been exercised by a concrete instance from a non-hook
site: an orchestration gate's `grep` matcher (not a validation hook) whose unstated boundary
assumption was a `\b` word-boundary anchor composed downstream of an earlier `\b`-anchored
subexpression, separated by a `[^|]*` run — mis-evaluated by the deployed POSIX/DFA `-E` grep
engine, producing a false negative that wrongly rejected conforming input. This is the same
*kind* of violation the existing row names (an unstated boundary assumption silently breaking
once real inputs cross it), reached from a different site class than the row's own wording
covers. The row itself is not reworded or reinterpreted here, and no count in this file is
touched — whether the row's site-class wording ("a validation hook's regex or path-depth
pattern") should be widened to cover this site class is left to separate, dedicated defect-class
vocabulary work. See
`standards/grep-word-boundary-portability.md` for the full remediation guidance: the
invocation-context engine split, the compositional-not-missing-feature framing, the
unaffected-shape rule, the delimiter-anchored preference, and the execute-before-commit
obligation this instance motivates.

A fourteenth instance, `AMBIENT_BINDING_MISMATCH`, was added deliberately, to name one further
concrete recorded defect shape: a downstream guard reading an ambient shell variable that its
caller never bound, so the guard's condition silently evaluates false instead of erroring and the
guarded behavior — an annotation, a cleanup step, a lock release, anything gated the same way —
is skipped without any signal reaching the caller. `skill_postflight_update`'s exit-6
deploy-pending annotation block, guarded on an ambient `TASK_DIR` that the `/orchestrate` caller
never set, is the concrete instance that motivated naming this shape. None of the thirteen
pre-existing instances was reworded or reinterpreted to cover it; this paragraph is where this
document first names it.

A fifteenth instance, `RECOVERY_DECLINED`, was added deliberately, to correct a misattribution
rather than to name a wholly new site. The WORK (d) absent-handoff branch in
`orchestrate-cycle-postflight.sh` previously recorded every dispatch that wrote no handoff and
whose `.return-meta.json` recovery declined as `HANDOFF_STALE_OR_ABSENT`, attributed to
`skill-orchestrate/SKILL.md` — correct when nothing usable was produced at all (`META_MISSING`),
but wrong when the dispatched agent's own `.return-meta.json` exists, was read, and carries a
terminal marker the orchestrator could not accept (`STATUS_IN_PROGRESS`, `STATUS_NOT_SUCCESS`,
`META_DISPATCH_SEQ_MISMATCH`): the research agent involved is contractually forbidden to write a
handoff at all, so "the skill did not write a handoff" is actively false, and the real fault is
agent-side status vocabulary. `HANDOFF_STALE_OR_ABSENT`'s own definition above is handoff-shaped
("a handoff whose mtime predates the dispatch window, or is otherwise absent when expected"); a
`.return-meta.json` carrying `status: "completed"` is status-shaped, and no rewording of the
existing class name would make it accurate. None of the fourteen pre-existing instances was
reworded or reinterpreted to cover this shape; this paragraph is where this document first names
it. The predecessor absent-handoff site (`META_MISSING`) keeps `HANDOFF_STALE_OR_ABSENT`
unchanged — see the registry row below for the discriminating detail.

### Signal B — attribution

Detection alone is not enough: the violation must resolve to a **named** file under
`agent-system/extensions/**`, derivable from the dispatched agent's name (or, for
orchestrator-internal sites, from the detecting site itself). The resolution is a mechanical path
transform, not judgment: a `.claude/{agents,skills,commands,rules,context,scripts,hooks,extensions}/**`
path is always a deploy artifact of exactly one source-store path — `agent-system/extensions/core/**`
for core files, or the matching `agent-system/extensions/<ext>/**` for extension-owned files (see
[source-store-deploy-boundary.md](../../rules/source-store-deploy-boundary.md)). For an agent
dispatch failure, the attributed file is the dispatched agent's own definition file (e.g. a
research-agent status violation attributes to that agent's `.md` definition under
`agent-system/extensions/<ext>/agents/`).

An agent-name → agent-file resolver for this already exists — a caller does not need to build
one. `scripts/system-defect-record.sh --dispatched-agent NAME` globs
`agent-system/extensions/*/agents/NAME.md` and refuses with exit 3 if it does not resolve;
`--attributed-path` takes precedence when both are passed. `RECOVERY_DECLINED`'s recording site
uses this resolver directly rather than hand-deriving the agent's path.

**Detection without attribution must log only and never offer a task.** Unattributable detections
are the main noise vector this predicate exists to suppress — a violation that cannot be pinned to
a named file is exactly the case where an automatically-filed task would have no actionable scope,
and would instead train operators to ignore the mechanism's output.

## A schema-conformant failure is always task work

This is the load-bearing consequence, not a corollary — an implementer who loses this property
rebuilds the exact noise problem this predicate exists to prevent, so it gets its own named
section, in the manner of infra-failure-discrimination.md's "Either signal alone defaults to
charging a genuine cycle" section.

**A Lean proof that will not compile writes `status: "failed"` with a well-formed artifacts
array.** Signal A is false — nothing about that outcome violates a schema the agent system owns;
the implementation agent followed its own contract to the letter and reported an honest failure
of the *user's* work. The mechanism never fires, however severe the underlying failure is, however
many times it recurs, and however loudly `/errors` or a human reviewer later complains about it.

This is deliberate and total: severity of the underlying failure is not an input to the predicate
at all. A catastrophic, repeatedly-failing Lean proof and a single successful research report both
score Signal A = false. The predicate only ever looks at whether the *system's own contract* —
the status vocabulary, the artifacts shape, the handoff location, the metadata-write obligation —
was honored, never at whether the *content* of the work succeeded. Conflating "this failed badly"
with "this is a system defect" is exactly the drift that would turn every hard user-facing problem
into system-defect noise, defeating the entire purpose of discriminating between the two in the
first place.

## Detection-point registry

The real detection points fall into three classes that need **different** downstream work — the
registry states which class each site is in so a future implementer does not try to treat them
uniformly. All line citations below were verified against current file text at the time of
writing; a future reader should re-verify before building on them, per the same discipline
demonstrated above for the dead-signal citations.

### Class (a) — loud but unactioned

Already emits a clear, human-legible signal at the point of detection, but nothing downstream
converts that signal into a durable record or task. These sites need **a recorder call added
beside the existing banner** — the diagnosis is already in hand.

| Site | File:line | What it detects | Defect class |
|------|-----------|------------------|--------------|
| Off-schema Tier C | `scripts/orchestrate-cycle-postflight.sh` (`--defect-class OFF_SCHEMA_STATUS` site, "cycle-postflight-tier-c") | `dispatch_status` outside the accept-list — the single shared per-task postflight body for every batch size and effort mode (the former single-task/multi-task engine split, and each one's separate mirrored site, no longer exist) | `OFF_SCHEMA_STATUS` |
| Stale-handoff gate | `scripts/orchestrate-cycle-postflight.sh` (mtime staleness gate, before the handoff-present branch) | handoff mtime predates the dispatch window — may indicate a stale write, a hung writer, or a writer bug | `HANDOFF_STALE_OR_ABSENT` |
| Stray-handoff sweep | `scripts/orchestrate-cycle-postflight.sh` (`--defect-class HANDOFF_MISLOCATED` site) | `HANDOFF_MISLOCATED` — a writer produced the handoff outside its task directory (moved to `.stray-handoff-{ts}.json` for inspection, never actioned further) | `HANDOFF_MISLOCATED` |
| Completion-claim gate, Case 3/3 refuse | `scripts/skill-base.sh:729` | `META_MISSING_AFTER_NARRATION`-shaped: phase accounting absent/malformed AND no corroborating plan-marker signal — already logs the phrase `handoff-writer defect suspected` verbatim | `META_MISSING_AFTER_NARRATION` |
| Recovery-declined sub-branch, detecting site `cycle-postflight-recovery-declined` | `scripts/orchestrate-cycle-postflight.sh` (WORK (d) absent-handoff branch, discriminated on `recover_json`'s `.reason`) | a `.return-meta.json` exists, was read, and recovery declined because the reported status could not be accepted as terminal (`STATUS_IN_PROGRESS`, `STATUS_NOT_SUCCESS`, `META_DISPATCH_SEQ_MISMATCH`) — attributed to the dispatched agent's own file via `--dispatched-agent`, never to `skill-orchestrate/SKILL.md`. The sibling `META_MISSING` sub-case (nothing usable produced at all) stays on the pre-existing `HANDOFF_STALE_OR_ABSENT` row above, unchanged | `RECOVERY_DECLINED` |

### Class (b) — computed but discarded

`ARTIFACTS_SHAPE_MISMATCH` is the sole current instance (defect class: `ARTIFACTS_SHAPE_MISMATCH`):
`scripts/orchestrate-recover-outcome.sh` already computes and emits it (line 205), and the five
consumer sites enumerated under "The dead-signal finding" above already read `evidence_reason` —
they simply branch only on the sibling value. These sites need **a consumer, not a new detector**:
the mechanical work is already done; what is missing is a conditional arm.

**Detection hole, distinct from all three classes above**: all five sites listed under "The dead-signal
finding" sit on the **recovered** (`.return-meta.json`, via `orchestrate-recover-outcome.sh`)
outcome path. `skill-orchestrate/SKILL.md`'s handoff-present branch (verified at lines 795-845)
reads `blockers`, the continuation forms, `next_action_hint`, the phase counts, and
`plan_markers_verified` from the handoff JSON, and performs no `artifacts` shape check of any
kind — `evidence_reason` is never computed on this path at all, let alone consumed. So the
`ARTIFACTS_MISSING_ON_SUCCESS` instance above (Signal A) is not detected-and-unactioned (class
(a)) nor computed-but-discarded (class (b)): on the handoff-present path it is **undetected**,
full stop. This is a fourth, distinct outcome the registry's three classes do not name, and it
matters precisely because it is easy to mistake for class (b): a downstream implementer who adds
a consumer arm at the five recovered-path sites enumerated above will cover the recovered-path
occurrence of this instance but will do nothing for the handoff-present path, where the defect
that motivated this row was actually observed.

### Class (c) — ephemeral

Five `PostToolUse` advisory hooks in `hooks/`, each of which emits `additionalContext` into
exactly one agent's context and **persists nothing** — the signal exists only for the duration of
that single tool-call turn:

| Hook | Detects | Defect class |
|------|---------|--------------|
| `validate-meta-write.sh` | a direct write under `.claude/**` during `/meta`-adjacent work | `SOURCE_STORE_BOUNDARY_VIOLATION` |
| `validate-handoff-location.sh` | a handoff written outside its task directory (Write/Edit-tool path only — structurally blind to the Bash-redirection write path, by design; see the hook's own header) | `HANDOFF_MISLOCATED` |
| `validate-no-task-references.sh` | a task-number citation in a deliverable outside `specs/**` (blocking, not advisory — the one hook in this class that denies the write rather than merely annotating context) | `TASK_REFERENCE_IN_DELIVERABLE` |
| `validate-plan-write.sh` | an artifact write under `specs/*/{plans,reports,summaries}/*.md` that fails format validation | `ARTIFACT_FORMAT_VIOLATION` |
| `validate-state-sync.sh` | `state.json`/`TODO.md` desynchronization | `STATE_SYNC_DIVERGENCE` |

`validate-meta-write.sh` already names the correct source-store target in its own message (`"Edit
the source store instead: agent-system/extensions/core/** for core system files, or
agent-system/extensions/<ext>/** for extension-owned files"`) — so for this hook, Signal B's
attribution work is largely already done; a future recorder need only capture the `FILE` variable
it already resolves, rather than re-deriving the source-store mapping from scratch.

## The recursion guard rule

The mechanism must not fire on defects in itself — a bug in the discrimination/recording pipeline
being reported by that same pipeline risks an unbounded regress (the recorder crashing while
recording a defect about its own crash; a dedup-logic bug producing infinite duplicate records of
itself). This is a narrower, more specific concern than "every orchestrator-critical file" — most
of the Class (a) detection sites above (`skill-orchestrate/SKILL.md` (both effort modes),
`scripts/skill-base.sh`) are ordinary orchestrator machinery whose defects are exactly the kind of
thing this mechanism should record normally, not exempt. The guard's scope is limited to the files
that **implement the discrimination/recording pipeline itself**.

**Decision: extend `context/reference/orchestrator-critical-paths.json`, do not add a sibling
file.** That file already enumerates the orchestrator's own critical files in a `scope_roots` +
`critical_paths` shape, and `scripts/orchestrate-batch-admit.sh` already consumes it — via
`self_mod_match` in `scripts/lib/file-scope-overlap.sh`'s shared jq definitions — for the
self-modification hazard check (a task whose `file_scope` names a critical path is deferred from
concurrent co-dispatch). The recursion guard is a **second consumer of the same predicate and the
same data**, not a new one: "is this attributed path one of the declared critical paths?" is
exactly `self_mod_match`'s question, just asked at defect-detection time instead of at admission
time. A sibling file would require independently maintaining a second scope-roots-plus-paths
structure that must be kept in sync with the first by hand — the DRY choice this codebase already
prefers elsewhere (`scripts/lib/file-scope-overlap.sh`'s own shared defs, `scripts/lib/phase-heading-patterns.sh`
as the single grammar anchor, `skill_corroborate_phase_counts` as the single anchor for
plan-heading corroboration).

**Accepted, deliberate side effect**: extending the shared list means a task whose `file_scope`
touches one of the newly-added entries also becomes self-modification-hazard-protected for
concurrent dispatch admission, exactly like every other entry already in the file. This is
correct, not incidental — these files genuinely are foundational orchestrator plumbing by the
same reasoning that justifies every other entry's presence.

**New entries this document adds** (all pre-existing files; no path is added for a file that does
not yet exist):

| Path (relative to a `scope_roots` entry) | Label |
|---|---|
| `context/patterns/system-defect-discrimination.md` | system-defect discrimination contract (this document) |
| `context/reference/orchestrator-critical-paths.json` | orchestrator critical-path registry (self-reference) |
| `scripts/orchestrate-recover-outcome.sh` | return-meta evidence-signal computation (`PHASES_ZERO_ON_SUCCESS` / `ARTIFACTS_SHAPE_MISMATCH`) |
| `scripts/system-defect-record.sh` | system-defect recorder (recursion-guard self-reference) |

**Forward reference — discharged.** The recorder script (`scripts/system-defect-record.sh`) has
been created and its own path has been appended to `orchestrator-critical-paths.json` as the
fourth entry above — the recorder guarding itself against recursive self-recording is the single
sharpest instance of this rule.

**The guard matches a labeled SUBSET of `critical_paths`, never the whole list.** All four entries
above, and only those four, carry an additional `"recursion_guard": true` boolean field in
`orchestrator-critical-paths.json`. The recorder filters
`.critical_paths | map(select(.recursion_guard == true))` **before** calling `self_mod_match` — it
never matches against the unfiltered list. This is deliberate and load-bearing: `critical_paths`
already contains `skills/skill-orchestrate/SKILL.md` (both effort modes),
and `scripts/skill-base.sh`, and matching the whole list would suppress every defect attributed to
those files — the exact opposite of this section's own stated intent above ("most of the Class (a)
detection sites ... are ordinary orchestrator machinery whose defects are exactly the kind of thing
this mechanism should record normally, not exempt"). The field is additive and backward-compatible:
`orchestrate-batch-admit.sh` reads only `.path`/`.label` for its self-modification-hazard check and
ignores unknown keys, so that consumer's behavior is unchanged by the field's presence. The
`$schema` value `orchestrator-critical-paths-v1` stays as-is — an added optional field is not a
breaking revision.

**Rejected alternative (unchanged from the original decision above): a sibling data file listing
only the four pipeline paths.** Rejected for the same DRY reason already stated in this section's
"Decision" paragraph, and it would additionally require hand-syncing two lists rather than one.

**Considered and excluded**: `context/formats/return-metadata-file.md` (the schema Signal A
checks against) and the five Class (c) hooks were both considered for inclusion and left out.
`return-metadata-file.md` is a general-purpose format specification consumed far beyond this
mechanism (every agent's Stage 7 contract, `handoff-schema.md`'s cross-reference) — a defect in it
is ordinary system-defect work, not a recursion hazard. The five hooks are detection *sites*, not
part of the discrimination/recording pipeline's own implementation — a bug in one of them is
likewise ordinary system-defect work, exactly like a bug in `skill-orchestrate/SKILL.md`.

Two further orchestrator-load-bearing scripts were considered and are likewise excluded, for the
same reason: `scripts/reconcile-task-status.sh` (runs at every `/orchestrate` entry) and
`scripts/check-extension-docs.sh` (feeds `verify-deploy.sh`, already a `critical_paths` entry
above). Neither is part of the discrimination/recording pipeline this guard scopes itself to — the
guard's stated scope is limited to files that *implement* the discrimination/recording pipeline
itself, and a status-reconciliation script and a documentation-lint script are ordinary
orchestrator machinery, not part of that pipeline. So the recursion guard supplies no reason to
add either. Whether they belong in `critical_paths` for the file's *other* consumer — the
self-modification-hazard check in `scripts/orchestrate-batch-admit.sh` — is a separate question
this document's scope boundary excludes; it is named here as a follow-on for whoever next revisits
that consumer, not decided.

**Degraded behaviour, when the critical-paths data file is missing or unparseable**: the guard
degrades to an **unknown** recursion status and refuses to record or file a task — never to fail
open silently. This differs in *direction* from `orchestrate-batch-admit.sh`'s own precedent
(which degrades `self_modifying` to `null` on every verdict, warns loudly, and falls through to
the ordinary collision scan unaffected — because that scan has independent, still-meaningful work
to do without the self-mod signal). The defect-recording path has no equivalent independent work
to fall through to: if the guard cannot determine whether a detection is self-referential, the
only safe default is the same one Signal B's attribution failure already uses — **log only, never
create a task**. The shared *principle* — degrade loudly, never silently, never fail open — is
identical to batch-admit's; only the resulting action differs, because the two consumers are
protecting against different failure modes (an admission scan that has other useful work to do,
versus a recording pipeline that has no safe action to take without the recursion signal).

## The deduplication rule

A defect already having an open task must not spawn a duplicate.

**Identity key**: `{defect_class}:{attributed_source_path}` — the Signal A instance
(`OFF_SCHEMA_STATUS`, `ARTIFACTS_SHAPE_MISMATCH`, `HANDOFF_MISLOCATED`,
`META_MISSING_AFTER_NARRATION`, or `ARTIFACTS_MISSING_ON_SUCCESS`) paired with the Signal B
attributed path. This is deliberately
coarser than including the detecting site or the dispatched agent's task number: the same
underlying bug in the same source-store file will keep tripping the same class at whatever site
next encounters it, and a fix for one occurrence fixes all of them — recording each detecting
site as a separate identity would fragment one bug into several open tasks.

**Where the open-task check reads from**: `specs/events.jsonl`, queried for prior
`event_type: "system_defect"` events whose `detail.defect_key` matches the identity key above (the
schema's `detail` object is `additionalProperties: true`, so `defect_key` requires no schema
revision — see `context/schemas/events-schema.json`). For each match, resolve
`detail.linked_task_number` (present once a detection has been promoted to a task; absent for a
detection-only record) against `specs/state.json`'s `active_projects` and classify:

- **No prior matching event** → not a duplicate; proceed.
- **A prior matching event exists with a `linked_task_number` whose `state.json` status is
  non-terminal** (per [state-management.md](../../rules/state-management.md)'s terminal-state
  list: `completed`, `abandoned`, `expanded`) → duplicate; log only, do not record or file again.
- **A prior matching event exists but carries no `linked_task_number`** (detected, never
  promoted), **or** its linked task is terminal → not a duplicate; a fresh occurrence of a
  previously-unfixed or since-closed defect is worth a new record, since either nothing is
  currently tracking it or the prior fix evidently did not hold.

This keeps the check entirely inside the already-decided `specs/events.jsonl` substrate — no new
file, no new field on `active_projects`, and no dependency on `errors.json`'s independently
tracked schema drift.

## The live-cycle acceptance criterion

**Decision (recorded here 2026-09-02)**: a clean orchestration cycle's acceptance bar is *not*
"zero `system_defect` events". It is **no new defect classes on a clean run, AND no unexplained
increase in a known class's firing rate absent a corresponding real incident.**

A pure "zero events" bar was never sound: Signal A's detection sites are correctly-firing
detectors, and a clean run can legitimately still trip one when a genuine agent-compliance slip
occurs mid-cycle — that is the recorder working as designed, not noise. A pure "no new classes"
bar alone is under-specified in the other direction, established by live evidence (below): a
class firing zero times for weeks and then once is architecturally "not new" yet may be exactly
the incident the bar exists to catch. The adopted criterion requires both halves.

**Evaluation procedure**: `grep 'system_defect' specs/events.jsonl | jq -r '.detail.defect_class' | sort | uniq -c`,
compared against the immediately-prior baseline census taken the same way. A failing evaluation
looks like either: (a) a `defect_class` value appears in the current census that is absent from
the baseline census (a new class — investigate whether Signal A's vocabulary needs the extension
recorded per the "Extending the Signal A vocabulary" section above, and whether the triggering
site is a genuine defect or a detector miscalibration); or (b) an existing class's count rises
between baseline and current census without a corresponding recorded incident (own task, error,
or dated evidence block) explaining the rise. A rise that is fully explained by a recorded,
understood incident (e.g. a live-predecessor clobber correctly caught) is not a failing
evaluation — see the evidence below for why that distinction matters.

**Live event census (taken 2026-09-02, re-derived at decision time rather than trusted from any
prior filing)**: 13 `system_defect` events across 4 classes —
`AMBIENT_BINDING_MISMATCH`: 1, `HANDOFF_STALE_OR_ABSENT`: 7, `META_MISSING_AFTER_NARRATION`: 1,
`OFF_SCHEMA_STATUS`: 4.

**Evidence weighed, both directions** (from the sibling task "Suppress expected handoff absence
defect", `specs/TODO.md`, whose three dated blocks bear directly on this decision):

- *For relaxing a pure zero-events bar*: the task's original filing observed
  `HANDOFF_STALE_OR_ABSENT` fire on a clean, fully-successful base-mode `/orchestrate` run — a
  contractual non-writer (base-mode implement) left no fresh handoff, exactly as designed, and
  the recorder still filed a defect. This is a recorder firing on expected, correct behavior, not
  on an incident — the textbook case for "zero events" being the wrong bar.
- *Against relaxing carelessly, to a bare "no new classes" bar*: the same task's two
  `EVIDENCE ADDED` blocks (2026-08-24 and 2026-09-01) record two independent, real, live
  predecessor-clobber incidents — a still-running dispatch completing late, and a closed
  dispatch's files resurrected via `git restore` — in both of which the single
  `HANDOFF_STALE_OR_ABSENT` event was the *only* signal distinguishing the clobber from a normal
  report. `HANDOFF_STALE_OR_ABSENT` is not a new class in either incident (it already has prior
  occurrences), so a "no new classes" bar alone would have accepted both clobbers as clean. This
  is why the adopted criterion's second half — rate-of-a-known-class, not merely class novelty —
  is required, not optional.

**Precedent matched**: this re-scoping follows the framing set by
`specs/reviews/review-2026-08-10-agent-system-refactor-capstone.md`'s UNVERIFIABLE-AS-WRITTEN
gate-out item (`err_1786350581339_Q4VnFy`), which holds that an acceptance criterion with no
instrumented way to evaluate it may be amended to something checkable rather than left waiting on
new instrumentation. The prior "zero events" bar was checkable but unsound, rather than
unverifiable; the correction here is the same posture — replace an unworkable criterion with a
workable one rather than defer the decision — applied to a different failure mode of the same
underlying problem (an acceptance bar that does not survive contact with real recorded evidence).

**Out of scope, not dispositioned here**: the two individually-owned defect classes discussed
above (`OFF_SCHEMA_STATUS` and `META_MISSING_AFTER_NARRATION`) remain owned by their respective
in-flight tasks (the handoff identity-contract work and the nonterminal-fanout work,
respectively). This decision settles only the acceptance-bar shape and its evaluation procedure —
it does not fix, close, or otherwise disposition either individual defect class, and must not be
read as having done so.

## Related documentation

- [Infra-Failure vs. Work-Cycle Discrimination](infra-failure-discrimination.md) — the structural
  precedent this document mirrors; a different failure surface (Agent-tool transport errors vs.
  Signal A/B schema-and-attribution violations)
- [return-metadata-file.md](../formats/return-metadata-file.md) — the normative status/artifacts
  vocabulary Signal A checks against
- [source-store-deploy-boundary.md](../../rules/source-store-deploy-boundary.md) — the
  source-store/deploy-artifact split Signal B's attribution resolves against
- [file-footprint-overlap.md](file-footprint-overlap.md) — the shared overlap predicate
  (`self_mod_match`) the recursion guard reuses rather than reimplements
- `docs/architecture/batch-admit-schema.md` — the self-modification hazard's existing schema and
  degradation contract, whose direction the recursion guard deliberately diverges from (see above)
