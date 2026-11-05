# Research Report: Cross-Task Traceability and CHANGE_LOG Verdict

- **Task**: 459 - Design cross-record traceability and render an explicit keep-or-retire verdict on `specs/CHANGE_LOG.md`
- **Started**: 2026-11-05T15:39:47Z
- **Completed**: 2026-11-05T16:30:00Z
- **Effort**: ~1 session, research only (no implementation; none is required — see Decisions)
- **Dependencies**: None (sequencing note only, not an edge — see Recommendations)
- **Sources/Inputs**:
  - `specs/state.json`, `specs/archive/state.json`, `specs/events.jsonl`, `specs/CHANGE_LOG.md`, `specs/ROADMAP.md` (live, this repository)
  - `agent-system/extensions/core/context/reference/state-management-schema.md`, `rules/git-workflow.md`, `rules/no-task-references-in-deliverables.md`, `rules/no-record-versioning-in-deliverables.md`, `context/patterns/todo-archival-reference.md`, `context/formats/issue-log.md`, `context/formats/dispatch-metrics.md`, `context/formats/report-format.md`, `context/formats/plan-format.md`, `context/formats/summary-format.md`, `context/standards/user-decision-contract.md`, `docs/architecture/handoff-schema.md`
  - `agent-system/extensions/core/scripts/orchestrate-record-decision.sh`, `commands/todo.md` (Step 5.7.7/5.7.8), `skills/skill-todo/SKILL.md`
  - `agent-system/extensions/memory/context/project/memory/knowledge-capture-usage.md`
  - `specs/436_orient_command_with_scout_agent_retire_review` description (the named future consumer)
  - `specs/328_systematic_script_and_test_corpus_efficiency`, `specs/458_consolidate_duplicated_todo_implementation`, `specs/archive/307_todo_consolidate_and_optimize` (precedent)
  - Git history: `git log -- specs/CHANGE_LOG.md`, `git log -- specs/ROADMAP.md`, commit `f737b4d4b`/`2045f2e21` (task 21 vault-comment precedent), `git log --format=%B` sampling for `Session:` coverage
- **Artifacts**: this report
- **Standards**: report-format.md, subagent-return.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md, no-record-versioning-in-deliverables.md

## Executive Summary

- **CHANGE_LOG verdict: KEEP, unchanged.** It was measured stale (a ~5-week gap) on
  2026-11-02, but by 2026-11-04 — one day before this dispatch — a routine `/todo` run
  (`aac4a8c6a`, "archive 44 completed tasks") caught the gap up in one batch with no data
  loss. The mechanism is self-healing by construction: a long gap between `/todo` runs
  delays entries, it never drops them. Retiring a cheap, already-working, self-healing file
  so that its one named future reader (`/orient`, task 436) would have to reconstruct the
  same chronological human-readable feed from two JSON files plus `git log` is strictly more
  machinery, not less.
- **No new mechanism, field, file, or script is warranted.** Every durable traceability
  primitive the design needs already exists and is already structurally written as a
  side effect of work already being done: `## Decisions` is a mandatory, mechanically
  checked heading in reports and summaries; `issues.jsonl`/`metrics.jsonl` already mint
  renumbering-immune ids; `parent_task` already survives renumbering; `session_id` already
  joins commits to dispatches. The one genuine gap is a **citation convention**, not a
  missing field: nothing currently tells an agent to cite a prior record's decision by its
  durable `project_name` slug rather than by its mutable number. That gap closes with a
  documentation change to three existing format files, never a new JSON field.
- **The `task {N}:` commit convention is accepted and worked around, not changed.**
  `dispatch-metrics.sh`, the one live mechanical consumer that correlates commits with
  dispatches, already joins on `session_id` via `git log --grep`, not on the number in the
  message — so the number is human-skimming sugar, not a load-bearing key. `session_id`
  appears in 192/200 (96%) of the last 200 commit bodies and is immune to renumbering.
  One vault operation has already fired in this repository's history (2026-08-10) with no
  recorded incident of historical-commit misattribution. Rewriting history is forbidden;
  changing the convention going forward has a real, repo-wide cost for a benefit the
  `session_id` join already provides one hop away.
- **`parent_task` should not be overloaded.** It already does its one job (lineage) and
  already survives renumbering (`commands/todo.md` Step 5.7.7 item 4). The traceability gap
  is a *different*, non-hierarchical relation — "record B's decision builds on record A's
  Decision N" — which this system already expresses today as free prose citing the other
  task by slug (this very task's own description does it repeatedly). That practice needs
  naming and light formalizing, not a new field.
- **Re-verification surfaced three factual corrections to the dispatch's 2026-11-02
  measurements**, each recorded under Findings: CHANGE_LOG.md is no longer stale (see
  above); the "exactly three files reference CHANGE_LOG" count is now five (two inert
  path-listing hits added since); and `specs/ROADMAP.md` in *this* accessible repository
  carries no `## Maintenance` section and no CHANGE_LOG mention anywhere in its current
  content or its full git history — the pointer the dispatch described must live in the
  other consumer repository referenced by task 436 (a FormalSystem/Lean repository outside
  this session's filesystem access), which is moot here anyway since the verdict is KEEP.
- **Corroborating precedent**: the backlog already tried and abandoned four closely related
  "strengthen dependency metadata" proposals (`carry_reason_on_dependency_edges`,
  `decide_disposition_for_terminal_dependency_edges`,
  `post_creation_burst_dependency_analysis_pass`,
  `surface_dependency_graph_health_metrics`, `file_scope_derived_dependency_edge_inference`
  — all abandoned in the "seventh-pass backlog consolidation"), and task 21
  (`f737b4d4b`/`2045f2e21`) shows this repository's working norm when a decision's
  enforcement mechanism silently rots: delete the dead machinery, don't add a parallel
  enforcement point for an ambiguity nothing has actually reported.

## Context & Scope

Scope: produce a recorded design, verdict-first, answering the five questions the dispatch
poses about cross-record traceability and `specs/CHANGE_LOG.md`'s disposition, with every
existing-mechanism claim re-verified against the live tree (measured 2026-11-05) rather than
trusted from the 2026-11-02 figures baked into the task description. Explicitly out of
scope per the dispatch: pre-deciding a mechanism, pre-deciding retirement, and any
implementation beyond what the accepted design itself requires. This record's declared
`file_scope` is its own `specs/459_.../` directory only; every file read above is an input,
never an edit target, in this dispatch.

Constraint carried from the dispatch and treated as binding evidence, not merely a caveat:
a traceability mechanism that depends on an agent remembering to populate it will degrade
exactly as `specs/CHANGE_LOG.md`'s writer did for five weeks — so the design below is judged
against "does this fall out of work already being done," not against "is this a good idea
in isolation."

## Findings

### Raw-material inventory (re-verified live, 2026-11-05)

| Mechanism | Shape | Durable under renumbering? | Status |
|---|---|---|---|
| `dependencies[]` | array of `project_number` on each `active_projects[]` entry | No (rewritten by Step 5.7.7 item 3, so internally consistent, but a *number* is the key) | Live; 57 of the current active entries carry at least one edge |
| `parent_task` | scalar `project_number` | **Yes, deliberately rewritten** by Step 5.7.7 item 4 alongside `project_number`/`dependencies` | Live; 16 of the current active entries carry it; explicitly inert in the Kahn wave computation |
| `artifacts[]` | array of `{path, type, summary}` | **No** — `path` embeds the directory's `{NNN}_{slug}` name; a confirmed casualty exists in `state-management-schema.md`'s own field table (an orphaned `.artifacts[0].path` from a recycled, since-renumbered task, now resolving to neither the working tree nor git history) | Append-only with same-type supersession |
| `issues.jsonl` / `metrics.jsonl` | per-task JSONL, minted `iss_{ts_ms}_{rand6}` / `met_{ts_ms}_{rand6}` ids | **Yes** — opaque, timestamp-seeded, never rewritten | 9 live tasks carry `issues.jsonl`, 7 carry `metrics.jsonl`, confirmed present |
| `.decisions.json` | bare top-level JSON array, `{question, answer, cycle, timestamp, description_fingerprint?}` | **Yes** — same opaque-timestamp durability as above, and the only one of this set that actually targets "decisions" by name | Scoped **narrowly**: only `AskUserQuestion`-surfaced `user_decision` answers, written solely by `orchestrate-record-decision.sh`. **Not** a general design-decision log. |
| `decisions_made` | array of free-text strings on `.orchestrator-handoff.json` | N/A — **the file itself is overwritten every dispatch cycle** (confirmed in `handoff-schema.md`'s own Writing Contract: "The filename is static... Each dispatch cycle overwrites the previous handoff.") | **Ephemeral working memory for the next dispatch only** — never a durable record. Easy to mistake for a decision log; it is not one. |
| Mandatory `## Decisions` heading | prose section, exact-text matched by `validate-artifact.sh` | **Partially** — the *section* is durable (artifacts are append-only), but a *citation into it* from another task is only as durable as the citing path | Required in `report-format.md` and `summary-format.md`; **absent from `plan-format.md`**'s own top-level structure |
| `specs/events.jsonl` | repo-wide append-only JSONL, `evt_{ts_ms}_{rand6}` ids, carries `session_id`/`task` | **Yes** | 7,533 lines, 2.87 MB at measurement (dispatch's 2.2 MB figure has grown ~30% since 2026-11-02 — expected drift, not an error) |
| `specs/archive/state.json` | `completed_projects[]` + `archived_projects[]`, confirmed exactly these two sibling arrays | Numbers inside it are **not** renumbered by the vault transform (only `active_projects` is renumbered) | Confirmed two-array shape matches the dispatch's claim exactly |
| Git history / `task {N}: {action}` | commit message convention | **No**, by construction — immutable history, mutable key | See dedicated subsection below |
| `session_id` in commit body | `Session: sess_{ts}_{rand}[_{task}]` trailer | **Yes** — opaque, never rewritten | Present in 192/200 (96%) of the last 200 commits sampled |
| `specs/CHANGE_LOG.md` | hand-format prose log, dated blocks, one entry per archived task | N/A (not keyed on task number at all — entries are self-contained prose) | See dedicated subsection below |

**Corrections to the dispatch's "seven/eight directory types" claim.** The dispatch listed
`issues.jsonl`, `metrics.jsonl`, `handoffs/`, `records/`, `reports/`, `plans/`, `summaries/`,
and `.return-meta.json` as "all seven... confirmed present... `prototype/` appears in at
least one." Live re-check across every `specs/*` directory at `mindepth 2` finds `records/`
nowhere under a current task directory — the only `records/` anywhere in `specs/` is
`specs/archive/109_fix_ingest_online_failure_modes/harness/records`, a subdirectory of that
one archived task's own test harness, not a general per-task artifact category. `prototype/`
does not exist anywhere in the current tree. Both were likely transient contents of a
since-cleaned-up task directory; neither is a traceability-relevant artifact category today,
and the design below does not rely on either.

### `specs/CHANGE_LOG.md`: re-verified, not stale, and worth keeping

The dispatch's framing ("stopped being written for a month across four archival runs with
nobody noticing... VERIFY rather than assume") is exactly right to insist on — and verifying
it changes the conclusion. `git log --format="%ai %s" -- specs/CHANGE_LOG.md` shows the real
commit cadence:

```
2026-11-04 16:20:14  todo: archive 44 completed tasks   <- catches up the gap below, one day before this dispatch
2026-09-29 14:31:19  todo: archive 9 completed tasks
2026-09-18 15:28:00  todo: archive 12 completed tasks
2026-09-17 16:21:57  todo: archive 21 tasks (1 completed, 20 abandoned)
2026-09-07 12:17:26  todo: archive 7 completed tasks, track 4 orphaned directories
```

There *was* a real ~5-week gap (2026-09-29 to 2026-11-04) during which `/todo` was not run
and nothing was appended — the observation that motivated the dispatch's skepticism is
correct as a historical fact. But the 2026-11-04 commit added 222 lines in one pass covering
every task completed since, correctly dated under `### 2026-11-05` and chronologically
ordered. **Nothing was lost; the write was simply batched to the next `/todo` invocation.**
This is the mechanism working as designed, not failing: `skill-todo/SKILL.md`'s
`UpdateChangelog` stage (Stage 13) appends one dated entry per archived task on every run, so
a gap between runs is a latency property of how often `/todo` is invoked, never a durability
property of the log itself.

**Is anything in it unrecoverable from `archive/state.json` + git + per-record artifacts?**
Mostly no at the data level — each `archive/state.json` entry already carries the same
`completion_summary` free text that CHANGE_LOG renders, so the underlying facts are
duplicated, not uniquely sourced. What CHANGE_LOG uniquely provides is **presentation**: one
flat, chronologically sorted, single-file, human-skimmable, git-diffable prose feed spanning
every task type, with no JSON to parse and no cross-referencing two files required. That is
exactly the shape task 436's `/orient` scout needs for its "WHAT HAPPENED" brief section, and
`/orient` is this design's one concretely named future consumer. Retiring the file would not
remove any capability — it would move the cost of reconstructing that same feed from
`archive/state.json` plus `git log` onto every future reader, including the first one named.
That is a net increase in machinery in the retirement direction, which the dispatch's own
additive/reductive-ratio constraint weighs against.

**Reference-count re-verification** (dispatch claimed "exactly three files," measured
2026-11-02): live grep for `CHANGE_LOG` across the source store now returns **five** files:
`context/patterns/todo-archival-reference.md`, `skills/skill-todo/SKILL.md`, and the memory
extension's `context/project/memory/knowledge-capture-usage.md` (the original three,
confirmed unchanged) — plus `scripts/lib/engine-written-state-paths-lib.sh` and its test
`scripts/tests/test-engine-written-state-paths-lib.sh`, which merely *catalogue*
`specs/CHANGE_LOG.md` as one of the paths `/todo` writes (one is a one-line inventory
comment, the other a tripwire asserting it stays *absent* from an unrelated allowlist). The
drift is real, exactly as the dispatch warned it would be, but it does not change the
calculus: none of the five is a load-bearing content *consumer*, and the KEEP verdict does
not require touching any of them.

**The external pointer, re-checked.** The dispatch asserts a consumer repository's
`specs/ROADMAP.md` has a `## Maintenance` section naming CHANGE_LOG.md as "the durable
record." In this session's one accessible repository, `grep -n "CHANGE_LOG" specs/ROADMAP.md`
and `git log -p --all -- specs/ROADMAP.md | grep "## Maintenance\|durable record is"` both
return **nothing**, across the file's entire 58-commit history. This repository's
`ROADMAP.md` carries no `## Maintenance` section at all, in any revision checked. The pointer
the dispatch describes, if it is real, is almost certainly in the *other* consumer
repository this task space references elsewhere (task 436's description names
`FormalSystem/Metalogic/Decidability/...` paths, evidence of a second, Lean-focused
repository deploying this same `agent-system/` source store with its own independent
`specs/`) — a repository outside this session's filesystem access and therefore not
re-verifiable from here. This is moot for the verdict below regardless: the verdict is
KEEP, so no pointer needs fixing anywhere, in either repository.

### The `task {N}: {action}` commit convention: already worked around, not a live problem

The dispatch is right that a vault operation bakes a mutable number into immutable history,
and that this repository has already lived through one: `vault_count: 1`,
`vault_history: [{vault_number: 1, vault_dir: "specs/vault/01-vault/", created_at:
"2026-08-10T19:49:05Z"}]` in the live `specs/state.json`, corroborated by the commit
`842606729 todo: vault operation - archive to 01-vault, renumber 11 tasks`. The question is
whether anything downstream actually depends on the number in commit prose remaining
meaningful across that event.

It does not, mechanically. `scripts/dispatch-metrics.sh`'s own header states its churn/commit
correlation is derived "via `git log --since="@<since_epoch>" --grep="<session_id>"` over
`<repo_root>`" — it joins commits to a dispatch by **`session_id`**, never by parsing the
`task {N}:` prefix out of the subject line. A repo-wide search for any script that parses
`task {N}:` out of commit history to resolve a task number found none. The number in the
commit subject is read by humans skimming `git log --oneline`, and by nothing else.

`session_id` trailers are near-universal (`192/200` of the last 200 commits sampled carry a
`Session:` line) and are opaque, timestamp-seeded strings, immune to renumbering by
construction — exactly the same durability class as `iss_*`/`met_*`/`evt_*` ids. A reader who
needs to know what a historical `task 459:` commit actually refers to, after a renumbering
has made "459" ambiguous, already has a one-hop path: read the commit's `Session:` line and
look it up in `specs/events.jsonl` (which records `task` alongside `session_id` for the
*current* epoch) or in the task's own git-history-preserved artifacts. No new epoch marker
is needed to provide that path; it already exists.

Precedent for how this repository treats a decision whose enforcement has silently rotted:
commit `f737b4d4b` ("task 21: create resolve non-durable vault transition comment") records
that a TODO.md vault-transition comment was decided against in favor of `vault_history`, the
script was removed, but a dead prose instruction lingered in `commands/todo.md` and
`skill-todo/SKILL.md` until it visibly double-inserted itself; `2045f2e21` then deletes the
dead step rather than reviving or replacing it. The working norm here is: when a mechanism
rots silently, delete it, don't add a second mechanism to compensate for an ambiguity nobody
has actually hit. Adding a new epoch-marker convention now — before any task, issue, or
confusion has been recorded about a stale commit-message number in the ~3 months since the
one real vault operation — runs against that norm and against the dispatch's own
additive/reductive-ratio constraint.

**Verdict: accepted and worked around.** Rewriting history is not an option (and is barred
by this repository's own git-safety rules regardless of this task). Changing the convention
going forward has a real, repo-wide documentation/tooling cost (every emitter of
`task {N}: {action}` — `git-commit-scoped.sh`, every skill/agent body, this very CLAUDE.md
table) for a benefit — disambiguating a historical commit after a renumbering — that the
existing `session_id` join already delivers, one hop away, with no new mechanism.

### Corroborating precedent: the backlog already tried and abandoned this shape of fix

`specs/CHANGE_LOG.md` itself (entries dated under the "seventh-pass backlog consolidation")
records five sibling proposals in the same "strengthen cross-task metadata" family, all
abandoned: `carry_reason_on_dependency_edges` (task 229), `decide_disposition_for_terminal_
dependency_edges` (230), `post_creation_burst_dependency_analysis_pass` (231),
`surface_dependency_graph_health_metrics` (232), and `file_scope_derived_dependency_edge_
inference` (233). None of these is the exact mechanism this dispatch considers, but all five
share its shape — add a field, a script, or an inference pass to make dependency/traceability
metadata richer — and all five were judged not worth building. This is independent,
pre-existing evidence for the same conclusion this design reaches on its own facts: the
cheapest and most durable move available here is to strengthen two existing conventions in
prose, not to mint new structure.

## Decisions

1. **`specs/CHANGE_LOG.md` is KEPT, unmodified, with no pointer fix required in this
   repository.** Grounds: re-verified not stale (self-healing batch catch-up observed live);
   carries no uniquely-sourced data but real presentation value; is a plausible cheap input
   to the one concretely named future consumer (`/orient`, task 436); and this repository's
   `ROADMAP.md` carries no reference to it to fix, in any revision. (Answers dispatch
   question 3 and the Hard Constraints' explicit keep-or-retire requirement.)
2. **The `task {N}: {action}` git commit convention is accepted and worked around, not
   changed.** Grounds: the one live mechanical consumer already joins on `session_id`, not
   the number; `session_id` is near-universal and renumbering-immune; one real vault
   operation has already occurred without incident; and this repository's own precedent
   (task 21) favors deleting rotted enforcement over adding compensating enforcement for an
   ambiguity nothing has actually reported. (Answers the "sharpest instance" requirement.)
3. **No new durable-id scheme is minted for "a decision made inside a record."** The
   existing mandatory `## Decisions` heading in `report-format.md`/`summary-format.md`,
   combined with the task's durable `project_name` slug and its already-stable artifact
   round number, already supplies everything a citation needs:
   `{project_name}'s {artifact-type} {NN}, Decision {N}`. This is "the existing minted-id
   convention, applied" in its strongest form — recognizing that no *new* id is needed
   because the slug + artifact-round + ordinal-heading-position triple is already durable
   and already in routine informal use (this very task's own description cites
   `consolidate_duplicated_todo_implementation` and
   `orient_command_with_scout_agent_retire_review` by slug throughout, never trusting a bare
   number). (Answers dispatch question 1.)
4. **`parent_task` is left as-is and not overloaded to carry decision-citation semantics.**
   It already does its one job (lineage) correctly and already survives renumbering (Step
   5.7.7 item 4). The traceability gap this design closes is a different, non-hierarchical
   relation that this system already expresses as free prose naming another task by slug —
   that practice needs naming, not a new field grafted onto `parent_task`. (Answers dispatch
   question 2's "obvious candidate to strengthen" prompt by declining it on evidence, not by
   ignoring it.)
5. **The one genuinely missing piece is a documentation-only citation convention**, landing
   in the Writing Guidance of `report-format.md` and `summary-format.md` (and, as a smaller
   follow-on, adding the currently-absent top-level `## Decisions` structure to
   `plan-format.md` so plans gain the same mandatory home reports and summaries already
   have): when a decision in the current record is informed by, builds on, or revises a
   decision recorded in another task's artifact, cite it as
   `{project_name}'s {artifact-type} {NN}, Decision {N}` — never by bare task number alone.
   This is advisory/review-enforced prose, the same tier as this repository's existing
   carried-figure-discipline guidance, not a new mechanical gate. (Answers dispatch question
   4: it falls out of writing the artifact an agent already must write, not a new
   remember-to-do-it step; and question 2's "genuinely missing" prompt.)
6. **No implementation lands in this record.** Per the dispatch's own acceptance criterion
   and this phase's RESEARCH-AND-DESIGN classification, the three documentation edits named
   in Decision 5 are recorded here as the accepted design, not applied — they belong to a
   future `/plan`+`/implement` pass against `agent-system/extensions/core/context/formats/
   {report,summary,plan}-format.md`, which is outside this record's deliberately narrow
   `file_scope` (its own `specs/` artifact directory).

## Recommendations

1. **Advance this task to planning**, with a plan scoped to exactly the three documentation
   edits in Decision 5 — no script, no new field, no new file. Expected size: small (prose
   additions to three existing format-standard files under
   `agent-system/extensions/core/context/formats/`, plus a redeploy).
2. **Do not create a dependency edge onto `consolidate_duplicated_todo_implementation`
   (task 458)**, matching this task's own sequencing instruction and the precedent it cites
   (`todo_consolidate_and_optimize`'s phase-ordering rationale). Since the verdict is KEEP
   with no new `/todo` writer behavior, there is in fact no interaction with task 458 at
   all — the recommendation collapses to "no action," which is itself the predicted outcome
   for the retirement branch, now also true for the keep branch because nothing about
   `/todo`'s CHANGE_LOG-writing behavior changes.
3. **Leave a recommendation (not an edge) on task 436 (`orient_command_with_scout_agent_
   retire_review`)**: when its scout agent is built, it should (a) resolve any cross-record
   citation it renders by `project_name` slug rather than by trusting a bare task number
   still being current, and (b) treat `specs/CHANGE_LOG.md` as a legitimate, cheap data
   source for its "WHAT HAPPENED" brief section rather than reconstructing the same
   chronological feed by hand from `archive/state.json` plus `git log`. This is advisory
   context for that task's own eventual research/plan phase, not a dependency edge — task
   436 does not need this record to land first, and this record does not need task 436 to
   exist to be correct.
4. **If a future reader ever does hit a genuinely ambiguous historical `task {N}:` commit**
   (the scenario Decision 2 judges unlikely but not impossible), the resolution path is
   already available and should simply be documented as such wherever the commit convention
   itself is documented (`rules/git-workflow.md`): read the commit's `Session:` trailer and
   resolve it against `specs/events.jsonl`'s `session_id`/`task` fields for the correct
   epoch. This is a one-line documentation addition, optional, and lower priority than
   Recommendation 1 — it is not required by this design's verdict, only a cheap insurance
   note for the rare case.

## Risks & Mitigations

- **Risk**: a future task, encountering this record's verdict out of context, re-proposes
  one of the five already-abandoned dependency-metadata mechanisms or a new CHANGE_LOG
  retirement, having not read this record. **Mitigation**: this report's Decisions section
  states the grounds plainly (per the dispatch's own acceptance requirement) specifically so
  a disagreement can target the grounds rather than re-deriving the question from scratch;
  cite this record by slug (`cross_task_traceability_and_changelog_verdict`) rather than by
  number, per Decision 3's own convention, so the citation survives any future renumbering.
- **Risk**: the documentation-only citation convention (Decision 5) is adopted in the three
  format files but, lacking mechanical enforcement, degrades the same way CHANGE_LOG's
  writer did. **Mitigation**: this is accepted as the correct trade-off, not an oversight —
  the dispatch's own primary design constraint (question 4) explicitly prefers a mechanism
  that falls out of work already being done over one requiring new remembered discipline,
  and a prose citation convention inside a section (`## Decisions`) that is *already*
  mechanically mandatory (via `validate-artifact.sh`'s heading check) is about as close to
  that ideal as a citation *style* can get without becoming a new structured field — which
  the additive/reductive-ratio evidence above argues against building.
- **Risk**: the external `ROADMAP.md` pointer the dispatch described really does exist, live,
  in the other (FormalSystem/Lean) consumer repository, and this record's inability to check
  it from this session leaves it genuinely unverified rather than refuted. **Mitigation**:
  stated as an explicit limitation above rather than silently assumed either way; moot for
  this record's verdict (KEEP implies no pointer needs fixing anywhere), but worth flagging
  to that repository's own maintainer if this record's slug-based citation convention is
  ever adopted there too.

## Context Extension Recommendations

- **Topic**: cross-record decision citation.
  **Gap**: no existing context/standards file states the `{project_name}'s {artifact-type}
  {NN}, Decision {N}` citation form as a named, reusable convention — it exists today only
  as an unnamed practice visible in task descriptions' free prose.
  **Recommendation**: once Decision 5's documentation edits land (via the future plan this
  record recommends), consider whether the convention also deserves a short named mention in
  `context/reference/state-management-schema.md` near the `Parent Task Field` section, so a
  reader of that section learns both the mechanical lineage relation (`parent_task`) and the
  prose citation relation in the same place. Not required for this record's verdict; a
  nice-to-have for the implementing plan to decide.

## Appendix

- Live measurements taken 2026-11-05 (all commands run from `/home/benjamin/.config/nvim`):
  `git log --format="%ai %s" -- specs/CHANGE_LOG.md`; `git show aac4a8c6a --stat`;
  `wc -l specs/events.jsonl` (7,533 lines, 3,008,330 bytes); `jq` queries against
  `specs/state.json` and `specs/archive/state.json` for field unions, `parent_task`/
  `dependencies` counts, and vault history; `find specs -type d -name records -o -iname
  "prototype*"`; `grep -rl CHANGE_LOG agent-system/`; `git log -p --all -- specs/ROADMAP.md`;
  `git log -200 --format=...` for `Session:` trailer coverage.
- Key files read in full or by targeted section: `agent-system/extensions/core/scripts/
  orchestrate-record-decision.sh`; `agent-system/extensions/core/docs/architecture/
  handoff-schema.md` (Decisions File Schema, `decisions_made`, Writing Contract sections);
  `agent-system/extensions/core/context/reference/state-management-schema.md` (Parent Task
  Field, Renumber survival, Vault Fields sections); `agent-system/extensions/core/context/
  formats/{report,plan,summary}-format.md` (structure headings); `agent-system/extensions/
  core/context/standards/user-decision-contract.md`.
- Task-space cross-references consulted (by slug, per this record's own recommended
  convention): `consolidate_duplicated_todo_implementation` (458, not_started),
  `todo_consolidate_and_optimize` (307, archived/abandoned into 328),
  `systematic_script_and_test_corpus_efficiency` (328, implementing — source of the
  "sixteen additive vs. three reductive" figure, re-verified verbatim),
  `orient_command_with_scout_agent_retire_review` (436, not_started — the named future
  consumer).
