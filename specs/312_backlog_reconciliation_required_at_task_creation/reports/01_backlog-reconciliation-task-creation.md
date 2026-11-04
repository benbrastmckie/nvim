# Research Report: Task #312

**Task**: 312 - Backlog reconciliation as a required task-creation component: compare every proposed task against the open backlog before it is written
**Started**: 2026-11-04T01:08:54Z
**Completed**: 2026-11-04T01:08:54Z
**Effort**: large
**Dependencies**: 165 (completed), 282 (completed), 300 (completed), 344 (completed) — all four cleared
**Sources/Inputs**: Codebase (`agent-system/extensions/core/`), `specs/state.json`, `specs/archive/state.json`, `specs/TODO.md`
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **The central design question's own cost framing is now moot.** Every dependency named in both
  options (a) and (b) in the dispatch — 263, 280, 281, 282, 307 for (a); 44, 300, 302, 308, 309
  for (b) — is now `completed` or `abandoned`. Neither option is blocked. The decision must be
  made on the uniformity-vs-blocking-depth grounds the dispatch names, not edge count, and —
  critically — on a premise the dispatch did not test: **where does a new task actually enter
  `specs/state.json` today?**
- **That premise is false for the literal reading of option (a).** A single `PreToolUse` hook
  matched on the `Write|Edit` tool (the slot `validate-no-task-references.sh` /
  `validate-no-record-versioning.sh` already occupy) cannot see most task-creation writes,
  because they do not happen through the `Write`/`Edit` tool at all: `/task` and four other
  surfaces call `scripts/state-write.sh` (a Bash-invoked mutex-guarded jq writer); `/meta`
  (`meta-builder-agent.md`) and `skill-fix-it` mutate `specs/state.json` via raw `jq`/Bash calls
  that bypass `state-write.sh` entirely. A hook keyed to the `Write`/`Edit` tool name never fires
  for any of these — confirmed by reading `root-files/settings.json`'s existing `PreToolUse`
  registration and the actual write code in `commands/task.md`, `agents/meta-builder-agent.md`,
  and `skills/skill-fix-it/SKILL.md`.
- **Ruling**: neither (a) nor (b) as literally stated is correct; they answer two different
  sub-questions the dispatch conflated. (1) **Where the audit verdict is obtained** must be
  per-surface (closer to (b)), because only the LLM creation surface knows the proposal content
  before a task exists — but the wiring sites are the *skill* files
  (`skill-meta`, `commands/task.md`, `skill-fix-it`, `skill-spawn`, `commands/review.md`,
  `commands/errors.md`), not `agents/meta-builder-agent.md` as the dispatch's list of six assumed.
  (2) **Where skipping the audit is refused** should be anchored at `scripts/state-write.sh` —
  already the de facto single mutex-guarded writer for `specs/state.json`, already adopted by
  seven-plus call sites — not a new Claude-Code hook on the `Write|Edit` matcher. See Decisions
  for the full two-layer design and Findings for the evidence.
- **Why the skill layer, not the agent layer, for anything requiring human judgment**: task 300
  (now completed) measured `AskUserQuestion` as categorically unreachable from a dispatched
  subagent and fixed this by rehoming every interactive gate into the calling skill's own
  pre-delegation stage (`skill-meta` Stage 2.5), never the agent. Component 7 of
  `multi-task-creation-standard.md` already documents and enforces exactly this
  "Foreground Requirement." The new backlog-reconciliation component must follow the identical
  pattern: ambiguous verdicts render into Component 7's existing confirmation table, not a new,
  separately-invented `AskUserQuestion` call inside the agent.
- **No existing title/description similarity utility exists in this codebase.** The semantic pass
  (deliverable 3) has nothing to extend; the recommended design is a cheap, recall-biased
  keyword/token-overlap shortlist computed mechanically, with the actual duplicate/subset/
  superset verdict rendered by the LLM-in-the-loop creation surface against the shortlisted
  candidates' full title+description — never a fully-automated semantic verdict.
- **The closed-records widening is well-grounded**: `specs/archive/state.json` has three arrays
  (`completed_projects`, `archived_projects`, `abandoned_projects`); `specs/state.json` also
  carries `status: "completed"` entries awaiting archival, confirming the dispatch's union
  requirement is real, not speculative. The existing hand-written duplicate-check convention
  (found verbatim in `specs/TODO.md`) cites bare archived task numbers — exactly the anti-pattern
  the dispatch's "cite a durable anchor" instruction is correcting; the new mechanism must not
  repeat it.

## Context & Scope

Researched: (1) the current status of all nine tasks named as blocking dependencies for options
(a) and (b); (2) how `specs/state.json` is actually mutated by each of the six named task-creation
surfaces (not how the standard document says it should be); (3) the existing shared predicate
(`lib/file-scope-overlap.sh`) and its consumer taxonomy, to determine the correct reuse pattern
for deliverable 2's mechanical pass; (4) whether any existing title/description similarity
utility exists for deliverable 3's semantic pass; (5) how `specs/archive/state.json` and the
live `state.json`'s `completed` entries are structured, to ground the closed-records widening;
(6) task 300's resolution, since the dispatch names it as functionally load-bearing for "a human
ruling" and research was asked to determine *how*, concretely, that ruling gets surfaced from a
dispatched subagent.

Out of scope, per the dispatch's explicit non-goals: reworking `lib/file-scope-overlap.sh`
itself; reworking the admission-time three/five-input model in
`context/patterns/batch-orchestration-guardrails.md`; any auto-abandon/auto-merge/auto-rewrite of
an existing task.

## Findings

### Codebase Patterns

**All nine previously-blocking dependencies have cleared.** Checked directly against
`specs/state.json` and `specs/archive/state.json`:

| Task | Status | Relevant to |
|------|--------|-------------|
| 263 | completed | option (a) |
| 280 | completed | option (a) |
| 281 | completed | option (a) |
| 282 | completed | option (a); also one of 312's own three declared functional dependencies |
| 307 | abandoned | option (a) |
| 44 | completed | option (b) |
| 300 | completed | option (b); also one of 312's own three declared functional dependencies |
| 302 | completed | option (b) |
| 308 | abandoned | option (b) |
| 309 | completed | option (b) |
| 165 | completed | one of 312's own three declared functional dependencies |
| 344 | completed | 312's fourth, later-added dependency |

Both options' stated "roughly five edges" cost is now zero. The dispatch's own framing
("edge count does not decide it; uniformity versus blocking depth does") is the correct remaining
axis, but it must be applied to the *actual* write mechanism, not the mechanism the dispatch
assumed.

**`specs/state.json`'s write path is heterogeneous, not a single tool-level boundary.**
Read `root-files/settings.json`'s `PreToolUse` block directly:

```
"PreToolUse": [
  {"matcher": "Write", "hooks": [... a state.json-filtering inline allow-stub ...]},
  {"matcher": "Bash", "hooks": [guard-destructive-git.sh]},
  {"matcher": "Write|Edit", "hooks": [validate-no-task-references.sh, validate-no-record-versioning.sh]},
  {"matcher": "Bash|Write|Edit", "hooks": [guard-git-push.sh]}
]
```

The `Write|Edit` matcher — the slot option (a) as literally stated would add a third hook to — is
already populated by two hooks that scan Write/Edit *payload content* for forbidden text
patterns. That works for `validate-no-task-references.sh`/`validate-no-record-versioning.sh`
because deliverable files genuinely are edited via the `Write`/`Edit` tool. It does **not** work
for `specs/state.json`, because:

- `commands/task.md` Step 6 writes via `bash .claude/scripts/state-write.sh '<jq-filter>' ...`
  — a Bash tool invocation, never `Write`/`Edit`.
- `agents/meta-builder-agent.md` (Stage on task creation, around the "state.json Entry" block)
  constructs each new entry via a `jq` call executed through Bash — its own inline comment
  ("Edit tool target") is stale/misleading; the actual mechanism documented a few lines later
  ("Pass `--arg title`... to the jq call") is a raw jq/Bash mutation, and `grep -c "state-write"
  agents/meta-builder-agent.md` returns `0` — it does not call the shared writer at all.
- `skills/skill-fix-it/SKILL.md` Step 9.1 ("Update state.json") reads `current=$(cat
  specs/state.json)` and applies a two-step jq/slurpfile pattern directly via Bash — also bypasses
  `state-write.sh` and its mutex entirely.
- `commands/review.md`, `skills/skill-spawn/SKILL.md`, `skills/skill-reviser/SKILL.md`,
  `skills/skill-status-sync/SKILL.md`, `skills/skill-todo/SKILL.md`, and
  `skills/skill-project-overview/SKILL.md` **do** call `scripts/state-write.sh` (confirmed by
  `grep -rl "state-write.sh"` across the extension).

So of the six surfaces the dispatch's option (b) names, three (`task.md`, `review.md`,
`skill-spawn`) already route through the one real chokepoint and three
(`meta-builder-agent.md`, `skill-fix-it`, and — unverified in this pass —
`commands/errors.md`'s exact create-step) do not. No hook registered on `Write|Edit` ever sees
any of these Bash-mediated mutations, whichever surface performs them. This is the single most
important correction to the dispatch's framing: **option (a) as stated would be a no-op hook** —
registered, bare, exit-2-capable, and never triggered by the write it exists to gate.

**`scripts/state-write.sh` already has the right internal shape to host the real gate.** Its own
header documents an "acquire -> stage -> transform -> validate -> mv -> release" sequence, and it
already implements one structurally analogous check: `--allocate-into`'s "recording assertion"
refuses the write (exit 3) unless the caller's own jq filter demonstrably recorded the newly
allocated number somewhere the in-use set can see (e.g. by adding it to `active_projects`). The
same technique — diff `active_projects`' `project_number` set before and after the jq transform,
and refuse (a new dedicated exit code) if a newly-appearing entry lacks evidence of a recorded
audit verdict — is the natural extension point, not a new Claude-Code hook.

**The `Bash` `PreToolUse` matcher is the correct family for a structural backstop, not a content
scanner.** `guard-destructive-git.sh` and `guard-git-push.sh` are both registered on `Bash` (or
`Bash|Write|Edit`) and already inspect *command text*, not file content — the established
pattern for "is this Bash invocation one we must refuse" rather than "does this file's new
content contain a forbidden string." `hooks/validate-task-creation-audit.sh` (the file_scope's
named candidate site) fits this family far better than the `Write|Edit` content-scanner family
`validate-no-task-references.sh` belongs to — but its job, following this family's own pattern,
should be narrow and structural ("does this Bash command write `active_projects` outside
`state-write.sh`"), not the actual audit-verdict check, which only `state-write.sh` has the
pre/post-transform visibility to perform correctly.

**Component 4a (file-footprint overlap) is implemented differently at the task-creation level
than at the two script-level consumers**, per `context/patterns/file-footprint-overlap.md`'s own
Consumers section: only the lock-acquisition-level (`task-lock.sh`) and batch-admission-level
(`orchestrate-batch-admit.sh`) callers are described as sourcing/splicing the one physical
implementation in `lib/file-scope-overlap.sh`. The task-level caller (Component 4a at creation
time) is not documented as doing so, and no occurrence of `scopes_overlap`/
`find_overlapping_pairs`/`file-scope-overlap.sh` exists anywhere in `meta-builder-agent.md` or
`skill-meta/SKILL.md` — Component 4a at creation time is applied by the LLM agent reading and
following the published pseudocode, not by executing a script. Deliverable 2's mechanical pass is
different in kind: it is explicitly named as a literal script
(`scripts/audit-open-tasks.sh`), so it must follow the **script-sourcing** precedent
(`task-lock.sh`'s lazy `scopes_overlap()` source, `orchestrate-batch-admit.sh`'s spliced
`FILE_SCOPE_OVERLAP_JQ_DEFS`), not Component 4a's LLM-manual-application precedent.

**No title/description similarity utility exists anywhere in this codebase to extend.**
`grep -rl "similarity|jaccard|cosine|levenshtein|fuzzy"` across `scripts/` turns up only
`script-inventory.sh`'s exact-duplicate-block detector for refactoring candidates (explicitly
scoped away from "near-duplicate fuzzy matching... left for a future, separately-scoped task"
in its own header) and unrelated hits. Deliverable 3 starts from nothing.

**Task 300's resolution is the concrete mechanism behind "a human ruling... has nowhere to ask
from."** Its completed summary confirms: `AskUserQuestion` is measured categorically unreachable
in every dispatched-subagent configuration tested, including a live fork probe. The fix was not a
frontmatter change but a structural rehome — `/meta`'s entire interactive interview moved out of
`meta-builder-agent.md` (a dispatched subagent) into `skill-meta/SKILL.md`'s own pre-delegation
Stage 2.5, which runs in the foreground session where `AskUserQuestion` is reachable; the agent
was stripped of its own self-instruction to call it. `multi-task-creation-standard.md`'s Component
7 already states this as a standing rule — "Foreground Requirement... `AskUserQuestion` called
from background agents... does not reliably surface to users" — with `skill-meta` Stage 2.5 +
`meta-builder-agent` Stage 3D cited as the reference implementation. Any new component that can
produce an ambiguous verdict requiring human disposition must follow this identical shape.

**The closed-records widening is empirically grounded, not speculative.** `specs/archive/
state.json` has exactly the three arrays the dispatch names
(`completed_projects`/`archived_projects`/`abandoned_projects`), and `specs/state.json` does
carry `status: "completed"` entries still resident in the live file (confirmed structurally,
though this pass did not re-derive the dispatch's exact "35" count). The existing hand-written
duplicate-check convention this mechanism replaces is real and present verbatim in
`specs/TODO.md` (line 866 at research time): *"DUPLICATE CHECK PERFORMED against all open entries
in this repository's state.json. 427 (completed) fixed a different defect..."* — citing the
closed record by **bare number only**, exactly the anti-pattern the dispatch's "cite a durable
anchor, never a bare archived number" instruction is correcting. The new mechanism must not
reproduce this.

### External Resources

Not applicable — this is a pure in-repo architecture question; no external documentation or
library research was relevant.

## Decisions

1. **The central design question is answered as a two-layer design, not a selection between
   (a) and (b).** (a) and (b) conflate two distinct sub-questions that have different correct
   answers:
   - **Audit invocation** (obtaining the verdict for a proposal) is per-surface, but at the
     **skill** layer, not the agent layer: `skill-meta/SKILL.md` (not
     `agents/meta-builder-agent.md`), `commands/task.md`, `skills/skill-fix-it/SKILL.md`,
     `skills/skill-spawn/SKILL.md`, `commands/review.md`, `commands/errors.md`. This corrects the
     dispatch's option (b) wiring list, which named `agents/meta-builder-agent.md` — the wrong
     layer per task 300's measured finding.
   - **Enforcement** (refusing a task-creation write that skipped the audit) is anchored at
     `scripts/state-write.sh`, extending its existing transform -> validate pipeline with a new
     check: when the jq transform introduces a new `active_projects` entry (a `project_number` not
     present pre-transform), require the caller to have supplied evidence of a recorded audit
     verdict for that entry (e.g. a required flag carrying the verdict, consumed the same way
     `--allocate-into`'s recording assertion already consumes the transform's own output), and
     refuse (new dedicated exit code) otherwise. This is the real "state-write boundary" — not a
     `Write|Edit`-matched Claude-Code hook, which cannot observe this mutation at all.
   - A secondary, structural `Bash`-matcher `PreToolUse` hook
     (`hooks/validate-task-creation-audit.sh`, confirming the file_scope's named candidate site)
     is retained as a backstop: its job is narrow — detect a Bash command mutating
     `specs/state.json`'s `active_projects` outside `state-write.sh` (the raw-jq pattern
     `meta-builder-agent.md` and `skill-fix-it` currently use) — and refuse it, forcing every
     write through the one place (layer above) that can actually check the audit evidence. It
     does not itself re-implement the audit-verdict check.
   - **Corollary, out of this task's current `file_scope`**: `agents/meta-builder-agent.md` and
     `skills/skill-fix-it/SKILL.md` must be migrated to route their `active_projects` mutations
     through `scripts/state-write.sh` for the enforcement layer to reach them at all. Without
     this migration, the structural backstop hook would block them outright (an acceptable, even
     desirable, forcing function) but the migration itself is new work this record should
     propose into `file_scope`, not silently assume.

2. **Deliverable 1 placement**: the new component is sequenced as **4b** (mirroring the existing
   4a naming, inserted after 4a and before 5/6/7 without renumbering the later components), titled
   "Backlog Reconciliation (Required)." Its human-facing surface (any verdict beyond a clean
   `genuinely-new` or an auto-handled `overlaps-N-add-edge`) is rendered as an **extension of
   Component 7's existing confirmation table** (a new "Backlog Check" column), not a new,
   separately invented `AskUserQuestion` call — reusing the Foreground Requirement Component 7
   already states and enforces, consistent with task 300's rehome pattern.

3. **Deliverable 2's mechanical pass sources `lib/file-scope-overlap.sh` the way `task-lock.sh`
   and `orchestrate-batch-admit.sh` do** (lazy source / spliced jq defs), not the way Component
   4a's creation-time LLM-manual application does — because `audit-open-tasks.sh` is a literal
   script, and the two existing script-level consumers are the correct precedent to follow, per
   `context/patterns/file-footprint-overlap.md`'s own Consumers taxonomy.

4. **Deliverable 2's input/backlog scope is open ∪ closed, unioned from two sources**:
   `specs/state.json`'s non-terminal `active_projects` (open) and `status: "completed"` entries
   still resident there, unioned with `specs/archive/state.json`'s
   `completed_projects`/`archived_projects`/`abandoned_projects` (closed). A closed match must
   carry the record's `project_name` and the discharging artifact's path — never a bare number —
   correcting the existing hand-written convention found in `specs/TODO.md`.

5. **Deliverable 2's interface serves both call shapes task 421 needs**: it must accept a
   proposal (title + description + optional `file_scope`) with no allocated task number and no
   task directory, and must be callable standalone, without the enforcement hook anywhere in the
   path — e.g. a `--proposals-file <json>` / stdin mode distinct from the task-creation-time
   single-attempt mode. This record owns the shared matcher; task 421 (or any future proposal-time
   consumer) calls it the same way a task-creation surface does, just earlier and over a set.

6. **Deliverable 3's semantic pass is a recall-biased keyword/token-overlap shortlist, not an
   automated verdict.** No similarity utility exists in this codebase to reuse or extend; building
   a full semantic-embedding comparator is out of proportion to a Bash-script-based mechanism and
   would itself become a second, divergent matcher. The mechanical shortlist (e.g. shared
   significant-term count or ratio between a proposal's title+description and each backlog
   entry's) is deliberately tuned toward **over-inclusion** — a few extra false-positive
   candidates cost a human a moment's dismissal in Component 7's confirmation table; a missed true
   duplicate (the 310-vs-272 case, which shared exactly one file path) reproduces the exact
   failure this task exists to eliminate. The actual duplicate/subset/superset/covered-by-closed
   disposition is rendered by the calling surface (which is itself an LLM) reading the shortlisted
   candidates' full text — the script never decides semantic equivalence on its own; stated
   explicitly as this deliverable's false-negative posture.

7. **The deliverable's name should be decided at planning time, not inherited**, per the
   dispatch's own instruction — `audit-open-tasks.sh` no longer describes the closed-records-
   inclusive scope. This report does not rule on the replacement name; it is a planning decision
   with a direct `file_scope` consequence (the file must be created under its final name, not
   renamed after).

## Recommendations

- **Propose `file_scope` additions** (via `proposed_file_scope`) beyond the three paths already
  declared:
  - `agent-system/extensions/core/scripts/state-write.sh` — add the new-entry audit-evidence gate
    to its transform -> validate pipeline (Decision 1).
  - `agent-system/extensions/core/root-files/settings.json` — register
    `hooks/validate-task-creation-audit.sh` on the `Bash` matcher (bare, following the `exit 2`
    convention `guard-destructive-git.sh`/`guard-git-push.sh` already establish).
  - `agent-system/extensions/core/skills/skill-meta/SKILL.md` — wire the audit call and Component
    7 table extension into its existing Stage 2.5 Pre-Confirmation.
  - `agent-system/extensions/core/agents/meta-builder-agent.md` — migrate its direct-jq
    `active_projects` mutation to call `scripts/state-write.sh` (prerequisite for the enforcement
    layer to reach `/meta` at all — the surface responsible for the motivating incident).
  - `agent-system/extensions/core/skills/skill-fix-it/SKILL.md` — same migration.
  - `agent-system/extensions/core/commands/task.md`, `commands/review.md`,
    `skills/skill-spawn/SKILL.md`, `commands/errors.md` — wire the audit call into each surface's
    own pre-confirmation stage (these four already call `state-write.sh` for the write itself, so
    only the audit-call wiring, not a migration, is needed).
- **Build the regression fixture named in the dispatch's Acceptance section first**: a harness
  reproducing the exact 309/310/311 inputs against the backlog state as it stood at that
  incident, asserting the three verdicts (`subset-of-302`, `duplicate-of-272`, `genuinely-new`),
  plus the extended acceptance case (one archived-record match, one still-live-`completed`-record
  match, both rendering `covered-by-closed-N` with `project_name` + discharging artifact path).
- **Plan phase should settle `audit-open-tasks.sh`'s replacement name before any file is
  created** (Decision 7) — this is a `file_scope` decision, not a cosmetic one.
- **Plan phase should explicitly phase the `meta-builder-agent`/`skill-fix-it` migration to
  `state-write.sh` as its own early phase**, since every later phase (the audit-evidence gate, the
  Bash-matcher backstop) is only meaningfully testable once both of the motivating incident's
  actual write paths are mutex-guarded and inspectable the same way the already-compliant
  surfaces are.

## Risks & Mitigations

- **Risk**: migrating `meta-builder-agent.md`/`skill-fix-it` to `state-write.sh` is itself
  nontrivial, unscoped work discovered by this research, not named in the original task
  description. **Mitigation**: surfaced explicitly above and proposed into `file_scope`/phasing
  rather than silently assumed or silently dropped.
- **Risk**: a Bash-matcher structural hook that pattern-matches command text for "does this write
  `active_projects` outside `state-write.sh`" is itself a scanner with false-negative surface
  (a sufficiently obfuscated jq invocation could evade text matching). **Mitigation**: treat it
  as a backstop, not the primary gate — the primary gate (the audit-evidence check inside
  `state-write.sh`) has full pre/post-transform JSON visibility and cannot be evaded by command
  phrasing, only by bypassing `state-write.sh` entirely, which is exactly what the backstop
  catches.
- **Risk**: a keyword/token-overlap shortlist with a deliberately low (lenient) threshold will
  surface many false positives on short or generic task titles, degrading the confirmation
  table's signal. **Mitigation**: explicitly accepted trade-off per Decision 6's stated
  false-negative posture — a human dismissing extra candidates is strictly cheaper than a missed
  duplicate, and the dispatch's own non-goals forbid any auto-decided suppression.

## Context Extension Recommendations

- **Topic**: backlog/closed-record reconciliation at task-creation time.
- **Gap**: `.claude/context/index.json` has no entry under the `orchestrator` subdomain for
  backlog-reconciliation, dedup, or audit topics (confirmed: `jq` query against the index for
  these keywords returns nothing).
- **Recommendation**: once implemented, add a new pattern document
  (`context/patterns/backlog-reconciliation.md`), mirroring `file-footprint-overlap.md`'s own
  structure (Rule, Consumers, Non-Goals), as the home for the verdict vocabulary and the
  open/closed distinction, and index it under the `orchestrator` subdomain.

## Appendix

- Searches/greps used: `jq` queries against `specs/state.json` and `specs/archive/state.json`
  for dependency statuses; `grep -rl "state-write.sh"` and `grep -c "state-write"` across
  `agent-system/extensions/core/` to determine actual write-mechanism adoption per surface; `jq`
  read of `root-files/settings.json`'s `PreToolUse`/`PostToolUse` blocks; `grep` across
  `scripts/` for similarity/fuzzy-matching utilities (none found); read of
  `context/patterns/file-footprint-overlap.md`'s Consumers section; read of task 300's completed
  summary (`specs/archive/300_askuserquestion_unreachable_in_subagents/summaries/
  01_rehome-askuserquestion-gates-summary.md`) and `multi-task-creation-standard.md`'s Component 7
  (Foreground Requirement).
- Files read in full or in relevant part: `scripts/state-write.sh`, `commands/task.md`,
  `agents/meta-builder-agent.md`, `skills/skill-fix-it/SKILL.md`, `hooks/validate-state-sync.sh`,
  `hooks/validate-no-task-references.sh`, `docs/reference/standards/
  multi-task-creation-standard.md`, `context/patterns/file-footprint-overlap.md`.
