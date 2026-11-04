# Backlog Reconciliation

Canonical, single-source definition of the two-pass comparison a proposed task must pass against
the existing record corpus before it is created. Every consumer (the Multi-Task Creation
Standard's Component 4b, `scripts/audit-task-proposals.sh`, and each wiring site) references this
document by path and never restates or re-derives the verdict vocabulary.

## Rule

A proposed task — one or more, each carrying at minimum a title, a description, and optionally a
`file_scope` — must be compared against the full backlog corpus (open and closed) before it is
written to `specs/state.json`. The comparison runs two independent passes (mechanical footprint,
semantic shortlist) and renders a verdict from the closed vocabulary below for every corpus record
it matches. A proposal matching no record renders `genuinely-new`. The comparison never silently
drops a proposal and never auto-mutates an existing record beyond adding a serializing dependency
edge (see Non-Goals).

This document is deliberately scope-agnostic about WHO calls the comparison and WHEN: a
creation-time single-attempt call (one proposal, about to be written) and a proposal-time
set call (several proposals, none yet allocated a number or a task directory) are both served by
the same matcher and the same vocabulary — see Consumers below.

## Inputs

The backlog corpus is the UNION of four sources, read fresh on every invocation (never cached
across calls):

1. `specs/state.json`'s non-terminal `active_projects` entries — the OPEN backlog.
2. `specs/state.json`'s entries with `status: "completed"` — CLOSED, but not yet archived. A
   completed task sits in the live file for a window before an archival pass moves it; a matcher
   reading only the archive has a blind window where recently finished work is invisible.
3. `specs/archive/state.json`'s `completed_projects` array — CLOSED.
4. `specs/archive/state.json`'s `archived_projects` and `abandoned_projects` arrays — CLOSED.

Sources 3 and 4 are read via the same loading and duplicate-tolerant set handling
`scripts/lib/project-number-inuse.sh` already implements for the archive document (that library
already unions these same three archive arrays and already handles the archive's real
cross-array duplicate project numbers). The new matcher sources this library rather than
re-deriving archive-loading logic a second time.

Every corpus record contributes: `project_number`, `project_name`, `status`, `title`/description
text, `file_scope` (if declared), `artifacts` (for closed records, to resolve the discharging
artifact), and `dependencies` (for open records, so an `overlaps-open` verdict can state whether
an edge already exists).

## The Two Passes

### Pass 1 — Mechanical (file-footprint)

For every corpus record that declares a non-empty `file_scope`, apply the existing
`overlaps(pathA, pathB)` directory-prefix predicate (`context/patterns/file-footprint-overlap.md`,
physically `scripts/lib/file-scope-overlap.sh`'s `scopes_overlap()`/`FILE_SCOPE_OVERLAP_JQ_DEFS`)
between the proposal's declared `file_scope` and the record's. This predicate is NOT modified,
forked, or re-derived here — it is sourced or spliced exactly as its other three callers already
do. Classify the result:

- **Exact set match** → candidate for `duplicate-of-open` (open) or `covered-by-closed` (closed).
- **Proposal's scope is a strict subset of the record's** → candidate for `subset-of-open`.
- **Proposal's scope is a strict superset of the record's** → candidate for `superset-of-open`.
- **Partial, non-containing overlap** → candidate for `overlaps-open` (an edge should be added) or
  `narrow-open` (the proposal should drop the overlapping portion), decided by which side's scope
  is materially larger outside the overlap.
- **No overlap at all, record has a non-empty `file_scope`** → no mechanical candidate from this
  record.

A corpus record that declares **no `file_scope` at all** is invisible to this pass by
construction — an absent scope cannot overlap or fail to overlap, it can only be unknown. This
case is never silently treated as "no overlap"; it is reported explicitly as `scope-blind` (see
Verdict Vocabulary). This is the loud-degradation behavior the dependency on the file_scope
absence posture exists to enable.

### Pass 2 — Semantic (recall-biased token-overlap shortlist)

Pass 1 alone is insufficient: two records can be near-total duplicates in intent while sharing
almost no file paths (the motivating incident's 310-vs-272 pair shared exactly one path out of a
much larger combined footprint). Pass 2 computes a cheap, recall-biased **shortlist**, never a
semantic verdict:

- Lowercase and stopword-strip the proposal's `title + description` and each corpus record's
  `title + description`. No stemming, no embeddings, no external model call.
- Compute token-overlap (shared-token count over the smaller token set's size) between the
  proposal and every corpus record.
- Any record at or above a single named threshold constant is added to the shortlist as a
  semantic candidate, independent of whether Pass 1 found anything for that same record.

**The script never decides duplication.** It emits the shortlist; the calling surface (itself an
LLM reading the shortlisted candidates' full title/description text) renders the final
disposition. A purely mechanical run of this matcher cannot be claimed to *decide* that two
records are duplicates — only to shortlist for human/LLM judgment. This limit is stated here, in
the matcher script's own header, and in Component 4b of the creation standard — three places
that must agree, never diverge.

### Combining the two passes

A single corpus record can receive candidates from both passes; the verdict emitted for that
record is the MORE SPECIFIC of the two (an exact/subset/superset mechanical match outranks a bare
semantic shortlist hit), but a semantic-only hit with no mechanical candidate is still emitted —
as a plain verdict carrying no `shared_paths` field, never suppressed for lacking file-level
corroboration. This is exactly the shape the 310-vs-272 fixture exercises: Pass 1 alone would
classify that pair as weak/partial overlap on one shared path and likely only reach
`overlaps-open`; Pass 2 independently flags the semantic near-duplicate, and the combination keeps
both signals visible rather than collapsing them into whichever ran first.

## False-Negative Posture (stated explicitly, per D5)

Pass 2's threshold is tuned toward **over-inclusion**. The two error costs are asymmetric:

- A **false positive** (a shortlisted record that turns out unrelated) costs a human exactly one
  line's dismissal in the confirmation table.
- A **false negative** (a genuine near-duplicate the shortlist misses) reproduces the 310-vs-272
  failure this mechanism exists to prevent — invisibly, with no second chance to catch it before
  the duplicate is created.

Given that asymmetry, this mechanism accepts a noisier shortlist on short or generic titles rather
than risk silently missing a real duplicate. This is a tuning posture, not a defect to be
"fixed" by tightening the threshold later without first re-measuring the cost on the other side.

## Verdict Vocabulary

Closed, fixed enum. Open-side verdicts are actionable on the **task graph** (fold, add an edge,
narrow a scope, widen a record); closed-side verdicts are actionable on **evidence** (cite the
artifact that discharged the concern, then let a human rule on it). The two sides never collapse
into one token — a single `duplicate-of-N` cannot correctly carry both meanings.

| Verdict | Side | Carries | Operator action |
|---------|------|---------|-----------------|
| `genuinely-new` | — | nothing | create as proposed |
| `duplicate-of-open` | open | `project_number`, `project_name` | fold the proposal into the existing record |
| `subset-of-open` | open | `project_number`, `project_name`, `shared_paths` | narrow the existing record, order it behind |
| `superset-of-open` | open | `project_number`, `project_name`, `shared_paths` | widen the proposal or narrow it to the delta |
| `overlaps-open` | open | `project_number`, `project_name`, `shared_paths` | add a serializing dependency edge |
| `narrow-open` | open | `project_number`, `project_name`, `shared_paths` | narrow the proposal's own `file_scope` |
| `covered-by-closed` | closed | `project_name`, `discharging_artifact`, `project_number` (convenience only) | cite the artifact; drop the proposal, or state what is genuinely new relative to what landed |
| `scope-blind` | open or closed | `project_number`, `project_name` | the mechanical pass could not see this record (it declares no `file_scope`); judge it on the semantic shortlist alone |

**Closed-record citation rule**: a `covered-by-closed` (or a closed-side `scope-blind`) verdict
MUST carry the record's `project_name` and the path of the artifact that discharged it (resolved
from the record's own `artifacts` array — typically its summary). `project_number` may be
included as a labelled convenience field only, never as the sole identifier. Archived project
numbers are renumbered by vault operations (`rules/state-management.md`); a verdict that points
only at "archived task N" rots into pointing at unrelated work the moment a vault operation runs.
This is the identical constraint `rules/no-task-references-in-deliverables.md` imposes on
deliverables generally, applied here to one specific field.

## Non-Goals

- **No suppression.** A `covered-by-closed` verdict is rendered alongside its discharging
  artifact and the ruling is made by a human. There is no flag, exit code, or mode that drops a
  proposal from the output. A concern can recur after the record that once addressed it closed —
  a workaround applied by hand inside a completed phase, a contract recorded but never enforced,
  a fix that landed for one call site and not its siblings — and silently suppressing a proposal
  on the strength of a closed match is a worse failure than the duplication this document exists
  to prevent: it is unfalsifiable from the proposal side.
- **No auto-mutation of an existing record.** The only verdict this mechanism (or its callers) may
  apply automatically is adding a serializing `dependencies[]` edge for `overlaps-open`, mirroring
  Component 4a's existing in-batch auto-edge behavior. Every other verdict — fold, narrow, widen —
  is surfaced for a human ruling and never applied by the matcher or an enforcement hook.
- **No semantic-embedding comparator.** Pass 2 is a token-overlap shortlist, deliberately. A
  second, divergent matching mechanism grown here would reproduce, inside the deduplication
  machinery itself, exactly the failure this document exists to fix: two independently maintained
  notions of "the same task" drifting apart.
- **No opinion on scan scope beyond "open union closed."** This document defines the CORPUS
  (Inputs, above) and the VERDICT VOCABULARY; it does not revisit the admission-time three/five
  -input model (`context/patterns/batch-orchestration-guardrails.md`), which is a different scan
  scope (dispatch-time admission, not creation-time proposal comparison) that already works and is
  out of scope for this document.
- **No rework of the Pass 1 predicate.** `context/patterns/file-footprint-overlap.md` and its
  physical implementation in `scripts/lib/file-scope-overlap.sh` are sound and deliberately
  scope-agnostic; this document is a fourth consumer of that predicate, not a reviser of it.

## Consumers

- **`scripts/audit-task-proposals.sh`** — the single shared matcher implementing both passes and
  this vocabulary. Serves two call shapes: creation-time single-attempt (one proposal, flags) and
  proposal-time set (`--proposals-file`/stdin, proposals carrying no `project_number` and no task
  directory), callable with no enforcement hook anywhere in the path.
- **Multi-Task Creation Standard, Component 4b** (`docs/reference/standards/multi-task-creation-standard.md`)
  — the REQUIRED component specifying that every creation surface calls the matcher before
  confirmation and renders every non-`genuinely-new` verdict into the confirmation summary.
  References this document by path for the vocabulary rather than restating it.
- **`scripts/state-write.sh`'s audit-evidence gate** — refuses a `specs/state.json` write that
  introduces a new `active_projects` entry with no recorded verdict (or override), anchored at
  the one place that can observe every creation write regardless of which surface originated it.
- **Each wiring site** (`agents/meta-builder-agent.md`, `skills/skill-meta/SKILL.md`,
  `commands/task.md`, `skills/skill-fix-it/SKILL.md`, `skills/skill-spawn/SKILL.md`,
  `commands/review.md`, `commands/errors.md`) — calls the matcher at the skill/command layer
  (where a human-facing confirmation surface is reachable) and forwards the resulting verdict
  document to the write.

## Naming Note (D1)

This document's matcher is `scripts/audit-task-proposals.sh`, not `audit-open-tasks.sh`. The
latter name was the dispatch's original placeholder and is superseded: the widened contract
compares against CLOSED records too (not just "open tasks"), and the set call shape operates on
*proposals* that may not yet be tasks at all. The `audit-` prefix is kept for continuity with
existing precedent (`scripts/audit-deletion-references.sh`); `task-proposals` names what is
actually audited, and the plural matches the set call shape. `audit-open-tasks.sh` must never be
created under that name — this is the single canonical record of that naming ruling, so it is not
re-derived or re-litigated by a later reader encountering the old name in the dispatch history.
