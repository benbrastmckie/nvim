# Research Report: Task #528

**Task**: 528 - Add purpose-written title fields to task records so TODO.md stops rendering truncated description prose as task names
**Started**: 2026-11-11T16:09:30Z
**Completed**: 2026-11-11T16:30:00Z
**Effort**: small-to-medium, mostly editorial judgment
**Dependencies**: None
**Sources/Inputs**:
- specs/state.json (this repository's live active_projects corpus)
- .claude/scripts/generate-todo.sh, generate-task-order.sh, validate-state.sh (fallback-chain source)
- .claude/context/reference/state-management-schema.md (`.title` field documentation)
- specs/TODO.md and a `generate-task-order.sh --print` / `generate-todo.sh --dry-run` run (live rendering verification)
- /home/benjamin/Projects/BimodalLogic/specs/state.json (origin-repo cross-check for the dispatch's cited project-number list)
**Artifacts**:
- specs/528_state_json_title_fields_for_todo_readability/reports/01_title-fields-for-active-projects.md (this report)
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The dispatch's own counts and its "dependency-ready wave-1" project-number list are carried
  from a different corpus and are stale against this repository's live `specs/state.json`: only
  **24** `active_projects` entries currently lack `.title` (not 61), and of the 28 numbers named
  in SCOPE item 1, only six (481, 502, 559, 566, 570, 604) exist in this repository's
  `active_projects` at all. The rest (127, 128, 178, 257, 298, 464, 616, 617, 664, 709, 711, 712,
  713, 714, 716, 720, 722, 723, 725, 726, 728) are absent here, and mostly absent from
  `~/Projects/BimodalLogic`'s own live `specs/state.json` as well (checked directly: only 178,
  257, 298, 664, 713, 714 still exist there) — this list was evidently computed against an
  earlier, since-superseded snapshot of a BimodalLogic-side "next" selection before this record's
  own 2026-11-08 migration, not against anything resolvable today in either repository.
- Re-deriving "dependency-ready" against the live dependency graph (`generate-task-order.sh
  --print`'s Wave 1, i.e. no open predecessor) narrows the 24 title-less entries to a **17-entry**
  actionable subset: 338, 412, 456, 502, 503, 504, 510, 511, 512, 521, 522, 567, 568, 572, 590,
  591, 601. The remaining 7 are either in a later wave (421 → wave 4, 439 → wave 3, 602 → wave 4,
  603 → wave 2) or already `status: completed` (569, 573, 589) and thus candidates for near-term
  `/todo` archival regardless of title.
- Both fallback chains the dispatch cites were confirmed live and correct by direct code
  inspection plus a `--dry-run`/`--print` run; no generator change is needed, matching the stated
  NON-GOALS. See Findings below for the exact mechanics and one nuance worth knowing before
  verifying SCOPE item 2.
- The specific "truncated status note" rendering the dispatch quotes (e.g. `338 [NOT STARTED] —
  SOURCE STORE IS THE EDIT TARGET:...`) is produced by `generate-task-order.sh`'s Grouped-by-Topic
  listing — which is itself embedded into TODO.md's own `## Task Order` section by
  `generate-todo.sh` — not by the per-task `### N. Title` heading, which already falls back to a
  readable `project_name`-derived string today (confirmed live: task 456 currently renders as
  `### 456. Tag version gate unpassable for private manifest`). SCOPE item 2's verification should
  target the `## Task Order` section specifically, not just the per-task headings.
- Task 528's own `file_scope` (derived at migration time from literal path mentions in its
  description) omits `specs/state.json` and `specs/TODO.md` — the two files this task actually
  edits/regenerates — and also omits `generate-task-order.sh`, which the description names
  directly (`generate-task-order.sh:192`). It does carry `validate-state.sh` and
  `state-management-schema.md`, neither of which needs editing under the stated NON-GOALS.
- `state-management-schema.md`'s own `.title` row claims the field is "confirmed live on all
  current entries," which is false today (24 counterexamples) and will remain false after this
  task if any entry is deliberately left title-less per SCOPE item 3 — this is in the task's own
  file_scope and is a natural companion correction.
- Draft noun-phrase titles (all under 70 characters, no dates/status-prefixes/task-number
  references) are provided below for all 24 current title-less entries, ready for direct `.title`
  population at implement time.

## Context & Scope

This task adds purpose-written `.title` fields to `specs/state.json`'s `active_projects` entries
so generated views stop falling back to truncated `.description` prose. The research here covers:
(1) establishing the actual current set of title-less entries and verifying the dispatch's cited
counts and priority list against live data; (2) confirming the two documented fallback mechanisms
(`generate-todo.sh`, `generate-task-order.sh`) behave as described and locating precisely where the
readability defect the dispatch describes actually renders; (3) drafting concrete title text for
every title-less entry, honoring the stated constraints (under 70 characters, no dates, no status
prefixes, no task-number references); (4) checking whether the task's own `file_scope` and the
schema documentation it covers are consistent with the work ahead. No code or generator changes
are in scope (NON-GOALS), and none are proposed.

## Findings

### Live Corpus vs. Dispatch-Cited Figures

- `jq '.active_projects | length' specs/state.json` → 150 entries total (not 61 — that figure
  describes a different, smaller corpus).
- `jq -r '.active_projects[] | select((.title // "") == "") | .project_number' specs/state.json`
  → exactly 24 entries: 338, 412, 421, 439, 456, 502, 503, 504, 510, 511, 512, 521, 522, 567, 568,
  569, 572, 573, 589, 590, 591, 601, 602, 603.
- Of the 28 project numbers SCOPE item 1 names as the "dependency-ready wave-1 set," only six
  (481, 502, 559, 566, 570, 604) are present in this repository's `active_projects` at all, and of
  those six only 502 is currently title-less (481, 559, 566, 570, 604 already carry a `.title`).
  The other 22 numbers do not exist in this repository.
- Cross-checked directly against `/home/benjamin/Projects/BimodalLogic/specs/state.json` (the
  repository this record's migration provenance names as its origin, where it was `#729`): of the
  21 non-overlapping numbers checked there (127, 128, 178, 257, 298, 464, 616, 617, 664, 709, 711,
  712, 713, 714, 716, 720, 722, 723, 725, 726, 728), only six still exist (178, 257, 298, 664, 713,
  714) — the rest have themselves been renumbered, completed, or archived there since whatever
  snapshot produced the cited list. This confirms the list is stale against *both* repositories,
  not merely mis-sited by the migration.
- Conclusion: SCOPE item 1's project-number list cannot be used literally in this repository. The
  24-entry title-less set above, re-derived live, is the correct target population.

### Dependency-Readiness Re-Derivation (addresses "prioritize... since those are the entries
selected from next")

`bash .claude/scripts/generate-task-order.sh --print` computes six dependency waves over the 150
open records (matching `specs/ROADMAP.md`'s own re-derived "## Next" figures: 6 waves, 82 in wave
1). Intersecting Wave 1's membership with the 24 title-less entries yields 17: 338, 412, 456, 502,
503, 504, 510, 511, 512, 521, 522, 567, 568, 572, 590, 591, 601. The remaining 7 of the 24 are not
wave-1: 421 and 602 are in wave 4, 439 is in wave 3, 603 is in wave 2, and 569/573/589 are already
`status: completed` (excluded from the dependency graph entirely, and candidates for `/todo`
archival independent of this task). This 17-entry set is the dependency-ready population the
dispatch's stale list was evidently trying to name.

### Fallback Mechanics (confirms SCOPE item 3; no generator change needed)

- `generate-todo.sh:185-198` (`generate_task_entry`): when `.title` is empty, derives
  `title="${project_name//_/ }"` then capitalizes the first letter; falls back further to
  `"Task ${task_num}"` only if `project_name` is also empty. This fallback is unconditional and
  entry-independent — adding `.title` to some entries cannot break it for entries deliberately
  left title-less, since the check is a per-entry `[[ -z "$title" ]]` test with no cross-entry
  state. Verified live: `generate-todo.sh --dry-run` currently renders task 456 (title-less) as
  `### 456. Tag version gate unpassable for private manifest` — a readable project_name-derived
  heading, not a truncated description.
- `generate-task-order.sh:227` (`get_active_tasks`'s desc_data jq pass): falls back
  `(.title // .description // .project_name)`, truncated to 65 characters via `wb_truncate`. Note
  the ordering: **`.description` is checked before `.project_name`** here, unlike
  `generate-todo.sh`'s heading logic which goes straight to `project_name`. This asymmetry is why
  the dispatch's quoted examples ("SOURCE STORE IS THE EDIT TARGET:...",
  "MIGRATED FROM BimodalLogic...") are real and reproducible — confirmed live in both
  `generate-task-order.sh --print`'s Grouped-by-Topic section and in TODO.md's own `## Task Order`
  section (which embeds that generator's output verbatim via `generate-todo.sh:360`) — but they
  come from this second fallback chain, not the first. Example confirmed live: entry 338 renders
  as `338 [NOT STARTED] — SOURCE STORE IS THE EDIT TARGET:...` in both places today.
- Both fallback chains are correct, documented, and unconditional per-entry. SCOPE item 3's
  verification obligation is already discharged by this inspection; no further code check is
  needed at implement time beyond re-running `--dry-run`/`--print` after the `.title` edits land,
  to visually confirm the still-title-less entries keep falling back cleanly.

### `file_scope` / Schema-Documentation Gaps (not a NON-GOAL violation, but worth flagging)

- Task 528's own `file_scope` (migration-derived from literal path mentions in its description) is
  `["agent-system/extensions/core/scripts/generate-todo.sh",
  "agent-system/extensions/core/scripts/validate-state.sh",
  "agent-system/extensions/core/context/reference/state-management-schema.md"]`. It omits
  `specs/state.json` and `specs/TODO.md` — the two files the implement phase actually writes — and
  omits `generate-task-order.sh`, which the description cites directly at line 192. It does
  include `validate-state.sh`, which this task has no reason to touch under the stated NON-GOALS
  (no schema change).
- `.claude/context/reference/state-management-schema.md` line 123 documents `.title` as
  "Documented-optional, confirmed live on all current entries." This is false today (24
  counterexamples, re-derived above) and will remain false after this task completes if any entry
  is deliberately left title-less, which SCOPE item 3 explicitly permits. The file is already in
  this task's `file_scope`, making its correction a natural, in-scope companion edit rather than a
  separate task.

## Decisions

- Treat `specs/state.json` in **this** repository (`/home/benjamin/.config/nvim`) as the sole edit
  target for the `.title` additions. The task's own migration provenance situates it here, its
  `project_number` is nvim-native (528), and no BimodalLogic file is reachable or editable from
  this dispatch's working tree.
- Discard SCOPE item 1's literal 28-number list as a prioritization input (it is stale against
  both repositories per Findings above) and substitute the re-derived 17-entry Wave-1 intersection
  (338, 412, 456, 502, 503, 504, 510, 511, 512, 521, 522, 567, 568, 572, 590, 591, 601) as the
  priority-ordered subset, while still covering all 24 title-less entries in one pass (the task's
  own text frames prioritization, not exclusion — it does not say skip the rest).
- Verify SCOPE item 2 ("confirm titles render... in the dependency-wave table") against TODO.md's
  embedded `## Task Order` → Grouped-by-Topic listing specifically, since that is where the
  truncated-description defect actually manifests; the bare numeric Dependency Waves table itself
  carries no title/description text to verify.
- Recommend (not perform, as this is a research dispatch) amending task 528's `file_scope` to add
  `specs/state.json`, `specs/TODO.md`, and `generate-task-order.sh` before or during the implement
  dispatch, so the territory contract matches the files that dispatch will actually write.

## Recommendations

1. **Implement phase edits `specs/state.json` directly** (via the sanctioned `state-write.sh`
   path per `state-management.md`, not a wholesale-array rewrite), adding a `.title` string to
   each of the 24 entries below — or a deliberately-chosen subset if SCOPE item 3's title-less
   demonstration is wanted — then regenerates TODO.md (`generate-todo.sh`) and re-runs
   `generate-task-order.sh --print` to visually confirm both the per-task headings and the
   `## Task Order` listing now show the new titles.
2. **Amend `file_scope`** for task 528 to include `specs/state.json`, `specs/TODO.md`, and
   `generate-task-order.sh` (and drop `validate-state.sh`, which no edit under this task's
   NON-GOALS touches) before the implement dispatch, to avoid a territory-contract mismatch
   against the files actually written.
3. **Correct `state-management-schema.md` line 123** ("confirmed live on all current entries") to
   state the true optional-field contract — e.g. "optional; several active entries rely on the
   documented fallback" — as part of the same implement phase, since the file is already in scope
   and the current wording will be freshly false the moment this task lands.
4. **Draft titles** (noun phrase, <70 characters, no dates/status-prefixes/task-number
   references) for all 24 current title-less entries, ready to paste into `.title`:

   | # | project_number | Draft `.title` |
   |---|---|---|
   | 1 | 338 | Classify every task-support file as tracked or ignored |
   | 2 | 412 | Map core verification tiers to Lean build scopes |
   | 3 | 421 | Close three gaps in the telemetry --meta evidence consumer |
   | 4 | 439 | Rule on the propagation model for the bounded-wait agent contract |
   | 5 | 456 | Exempt private npm/Cargo manifests from /tag's version gate |
   | 6 | 502 | Require research reports to enumerate generated doc-sync surfaces |
   | 7 | 503 | Document /revise's unavailability to a dispatched agent |
   | 8 | 504 | Reconcile the Lean Goals-block harvester with its documented contract |
   | 9 | 510 | Fix a missing lib dependency in the predispatch-review test fixture |
   | 10 | 511 | Require git grep, not plain grep, for scope-hypothesis counts |
   | 11 | 512 | Exempt built-in commands from the dead-command-recommendation lint |
   | 12 | 521 | Fix Check N's agent glob to match the -implement-agent.md variant |
   | 13 | 522 | Fix report/summary heading-skeleton conformance across agents |
   | 14 | 567 | Port the deployed-tree containment strip into git-commit-scoped.sh |
   | 15 | 568 | Fix 25 failing assertions in the orchestrate-cycle-postflight suite |
   | 16 | 569 | Fix stale fixture dependency-copy lists across four test suites |
   | 17 | 572 | Make the full verification tier honorable under batch concurrency |
   | 18 | 573 | Fix two single-assertion test suite failures |
   | 19 | 589 | Fix the hardcoded repo-root walk-up depth in five test suites |
   | 20 | 590 | Resolve gate 24's /ide dead-command-recommendation findings |
   | 21 | 591 | Decide the fate of the errors.json triage surface |
   | 22 | 601 | Add a lint closing the repo-root walk-up defect class |
   | 23 | 602 | Improve the conclusion stage's next-batch proposal quality |
   | 24 | 603 | Make ROADMAP.md a generated artifact rendered from state.json |

   All 24 were checked for length (longest is 69 characters, #8/504) and against the stated
   constraints (no dates, no RE-SCOPED/STANDING/HARD/CAPSTONE-style status prefixes, no
   task-number references).
5. **Prioritize rows 1, 2, 5-13, 15, 20-22, 24** (project numbers 338, 412, 456, 502, 503, 504,
   510, 511, 512, 521, 522, 568, 590, 591, 601) first if a partial pass is needed for time budget
   — this is the re-derived Wave-1 intersection, minus 567 and 572 only for brevity of this
   specific sentence (they are equally wave-1 and equally fine to include; there is no reason to
   exclude them, see Decisions). In short: all 17 wave-1 numbers listed in the Executive Summary
   are the priority-ordered subset, with the remaining 7 (421, 439, 569, 573, 589, 602, 603) safe
   to title in the same pass since the task's own description does not ask for exclusion.

## Risks & Mitigations

- **Re-derivation drift**: the 24-entry count and the Wave-1 membership are both live figures that
  can change before the implement dispatch runs, especially since this task's own dispatch names
  concurrent sibling tasks running in the same `/orchestrate` cycle on the same working tree
  (territory note: 369, 532, 507). *Mitigation*: implement must re-run
  `jq -r '.active_projects[] | select((.title // "") == "") | .project_number' specs/state.json`
  and `generate-task-order.sh --print` fresh rather than trusting this report's lists verbatim,
  and must re-read `specs/state.json` immediately before editing per the Territory section's
  concurrency guidance.
- **Three of the 24 entries are already `status: completed`** (569, 573, 589) and are natural
  `/todo` archival candidates independent of this task. Titling them is harmless but low-value if
  archival happens first; no action needed here beyond noting it, since NON-GOALS already forbids
  touching status.
- **`file_scope` mismatch** (see Findings) could cause the implement dispatch's territory/scope
  check to flag `specs/state.json`/`specs/TODO.md` writes as out-of-declared-scope. *Mitigation*:
  Recommendation 2 above — amend `file_scope` before or at the start of the implement dispatch.

## Context Extension Recommendations

- **Topic**: `.title` field documentation accuracy.
- **Gap**: `.claude/context/reference/state-management-schema.md` line 123 states `.title` is
  "confirmed live on all current entries," which is already false (24 counterexamples) and will
  remain false after this task if any entry is deliberately left title-less (SCOPE item 3
  explicitly permits this).
- **Recommendation**: update that line during the implement phase (the file is already in task
  528's declared `file_scope`) to describe the optional-field contract accurately — e.g. that the
  field is optional, most active entries carry one, and the documented fallback chain
  (`generate-todo.sh`/`generate-task-order.sh`) covers the rest — rather than claiming universal
  presence.

## Appendix

- Commands run: `jq '.active_projects | length' specs/state.json`; `jq -r '.active_projects[] |
  select((.title // "") == "") | .project_number' specs/state.json`; per-project-number existence
  checks against both this repository's and BimodalLogic's `specs/state.json`;
  `bash .claude/scripts/generate-task-order.sh --print`; `bash .claude/scripts/generate-todo.sh
  --dry-run`; `grep -n title` over `generate-todo.sh`, `generate-task-order.sh`,
  `validate-state.sh`, `state-management-schema.md`.
- References: `.claude/scripts/generate-todo.sh:185-212`, `.claude/scripts/generate-task-order.sh:215-235`,
  `.claude/context/reference/state-management-schema.md:120-123`, `specs/ROADMAP.md:94-96` (the
  independently-confirmed 6-wave/82-in-wave-1 figures), task 528's own `migrated_from` block in
  `specs/state.json`.
