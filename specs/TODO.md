---
next_project_number: 335
---

# TODO

## Task Order

*Updated 2026-10-04. Generated from state.json dependency graph.*

**Dependency Waves**:
| Wave | Tasks | Blocked by | Topics |
|------|-------|------------|--------|
| 1 | 22,185,251,271,272,280,284,295,296,299,300,306,311,318,319,322,325,333 | -- | core-agent-system, extensions, neovim, ... |
| 2 | 29,170,273,275,281,302,303 | 22,251,271,272,280,300 | core-agent-system, extensions, orchestrator |
| 3 | 274,282,304 | 273,275,281,284,302 | core-agent-system, orchestrator |
| 4 | 312,328 | 170,282,300,303,304,318,322 | core-agent-system, orchestrator |
| 5 | 313 | 306,328 | core-agent-system |

**Grouped by Topic** (indented = depends on parent):

### Core Agent System

185 [IMPLEMENTING] — Retarget the remaining historical "Stage N" and "Stage MT-N"...
251 [NOT STARTED] — Context-corpus reachability probe (filename, directory,...
  └─ 170 [NOT STARTED] — Audit and isolate shell test suites from ambient host state...
    └─ 328 [NOT STARTED] — Systematic top-to-bottom efficiency refactor of the shell...
      └─ 313 [NOT STARTED] — Advisory lint for hand-authored /orchestrate batch proposals...
280 [NOT STARTED] — Forbid record-versioning language in deliverables: the rule,...
  └─ 281 [NOT STARTED] — Repo-wide record-versioning lint with a blocking/advisory...
    └─ 282 [NOT STARTED] — Write-time PreToolUse hook blocking record-versioning...
284 [NOT STARTED] — Exempt a task’s own directory from the postflight filescope...
300 [NOT STARTED] — Resolve AskUserQuestion's unreachability in dispatched...
306 [NOT STARTED] — Make ROADMAP.md a generated artifact: extend the format into...
  └─ 313 [NOT STARTED] — Advisory lint for hand-authored /orchestrate batch proposals... (see above)
318 [NOT STARTED] — Wire lint-directory-pathspec-boundary.sh into...
  └─ 328 [NOT STARTED] — Systematic top-to-bottom efficiency refactor of the shell... (see above)
322 [NOT STARTED] — Fix /todo's directory-move staging gap: a moved task...
  └─ 328 [NOT STARTED] — Systematic top-to-bottom efficiency refactor of the shell... (see above)
325 [NOT STARTED] — Stop git add's gitignore advisory exit code from aborting the...

### Extensions

333 [NOT STARTED] — The /books command with --review and --revise
29 [NOT STARTED] — Generate .mcp.json from extension manifests, then register...

### Neovim

22 [NOT STARTED] — Freeze .opencode: silence fragment validation spam and record...
295 [NOT STARTED] — Add desc field to 44 keymap.set calls missing documentation
296 [NOT STARTED] — Repo hygiene: remove stale init.lua.backup, regenerate...

### Orchestrator

271 [NOT STARTED] — Finish the parenttask edge: declare it in the schema,...
  └─ 273 [NOT STARTED] — Three-channel orchestration conclusion stage with per-channel...
    └─ 274 [NOT STARTED] — Next-admissible-batch suggestion and...
    └─ 304 [NOT STARTED] — Stop one out-of-repository pathspec entry from aborting...
  └─ 303 [NOT STARTED] — Make validate-state.sh resolve its omitted-argument...
272 [NOT STARTED] — Honest session liveness for concurrent same-repo batches:...
  └─ 275 [NOT STARTED] — Per-repo orchestration queue: registered, live, archived on...
    └─ 274 [NOT STARTED] — Next-admissible-batch suggestion and... (see above)
299 [NOT STARTED] — Guarantee detection of in-place plan revision concurrent with...
311 [NOT STARTED] — Replace static build-heavy family membership with a measured...
319 [NOT STARTED] — Surface cross-task claim invalidation when a research...
302 [NOT STARTED] — Pass --task at commit-staging sites to engage the...
  └─ 304 [NOT STARTED] — Stop one out-of-repository pathspec entry from aborting... (see above)
312 [NOT STARTED] — Backlog reconciliation as a required task-creation component:...

## Tasks

### 334. Fix two books-extension scaffold contract defects: the hard implementation agent's artifacts shape and hand-rolled task lookups in both hard skills
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: None
- **Research**: [334_fix_books_scaffold_contract_defects/reports/01_books-scaffold-contract-defects.md]
- **Plan**: [334_fix_books_scaffold_contract_defects/plans/01_books-scaffold-contract-defects.md]
- **Summary**: [334_fix_books_scaffold_contract_defects/summaries/01_books-scaffold-contract-defects-summary.md]

**Description**: Fix two books-extension scaffold contract defects that each fail a verify-deploy gate.

(1) agent-system/extensions/books/agents/books-implementation-hard-agent.md lacks an
object-shaped artifacts array with keys (artifacts, path, summary, type), failing
lint-agent-contracts.sh. The expected shape is in
agent-system/extensions/core/context/contracts/return-meta-artifacts-template.md, and the
non-hard sibling books-implementation-agent.md already carries it correctly, so it is the
in-repo reference for the fix.

(2) agent-system/extensions/books/skills/skill-books-implementation-hard/SKILL.md:52 and
agent-system/extensions/books/skills/skill-books-research-hard/SKILL.md:43 each hand-roll a
full-record task lookup ('.active_projects[] | select(.project_number == $num)'), failing
lint-task-lookup-adoption.sh, which expects the shared task-lookup helper.

Both defects originate in the books scaffold commits (phase 2 for the agent, phase 3 for the
two skills), established by git blame rather than inferred; neither was introduced by the
context-corpus or --gate work that followed. The scaffold's own completion gate passed while
leaving both behind, so this task must also rule on why a completion postflight cleared a task
whose output carried two standing lint failures -- that is the more general defect, and fixing
only the three files would leave it in place.

Verify with: bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh --verbose;
bash agent-system/extensions/core/scripts/lint/lint-task-lookup-adoption.sh --verbose; then
bash .claude/scripts/verify-deploy.sh --skip-slow (currently FAIL 3 of 33; these two gates are
two of the three, the third being an orchestrator context-budget ceiling tracked separately).

---

### 333. The /books command with --review and --revise
- **Effort**: 4-8 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: Task 332

**Description**: SOURCE STORE IS THE EDIT TARGET (agent-system/extensions/books/..., never .claude/**). `.claude/` is a
gitignored, disposable deploy artifact regenerated from the source store; a file hand-authored there
is silently wiped by the next deploy. See rules/source-store-deploy-boundary.md.

No task-number references in any file written into the source store
(rules/no-task-references-in-deliverables.md). Cite durable anchors -- filenames, section headings,
convention clause names -- instead. Task numbers are permitted in this description and in specs/**.

== GOAL ==

A new `/books` command with two sub-modes, `--review` and `--revise`, turning the accumulated
observation records into (i) a read-only performance review of the book convention and (ii) an
interactive proposal of tasks to research and revise that convention. The books extension today
ships `/book` and `/certify` only; there is no `/books` command, so this is a new command surface,
not an extension of an existing one.

== MIRROR /distill's STRUCTURE EXACTLY -- DO NOT INVENT A NEW SHAPE ==

The `/distill` sub-mode architecture is the pattern to follow, and it is already proven in this
codebase. Read these before designing anything:

  - `extensions/memory/commands/distill.md` -- parses the flags.
  - `extensions/memory/skills/skill-distill/SKILL.md` -- dispatches via a SHARED SUB-MODE SKELETON
    (measured ~278-321; RE-MEASURE), a seven-step skeleton with STUB POINTERS out to per-sub-mode
    pattern files.
  - `extensions/memory/context/project/memory/patterns/distill-{revise,review,meta}-submode.md` --
    the stub targets. The skill stays thin; the sub-mode detail lives in context files.

Reproduce that division: flag parse in the command file, shared skeleton plus stub pointers in the
skill, sub-mode detail in two new pattern files. Reproduce also `/distill --review`'s strict
read-only posture and `/distill --meta`'s interaction shape (multiSelect over candidates, then
create/note/skip per candidate, then a confirmation gate).

== `/books --review` -- STRICTLY READ-ONLY ==

A full performance review of the convention, computed from the observation log, the convention
snapshots and the run records. It WRITES NOTHING except its own dated report. It PROPOSES NO TASKS.
Contents:

  - Per dimension (the seven dimensions defined in the observation-record standard): positive and
    negative signals, with FIGURES and TRENDS, not adjectives.
  - WHAT IS UNMEASURED -- stated explicitly. A review that silently omits a dimension it has no
    data for is worse than one that names the gap.
  - Cost per task and per phase kind, from the metrics records.
  - Recurring issue classes, ranked.
  - Burdens created versus burdens lifted, as the paired signals the observation record stores.

Output: a dated report under the consuming repository's `specs/` tree, plus a terminal summary. It
FUNNELS TO `--revise` -- it ends by naming the strongest candidates and telling the user to run
`--revise` -- and it never proposes tasks itself.

== `/books --revise` -- PROPOSE RESEARCH AND REVISION TASKS ==

Evaluates the logs, then does INITIAL RESEARCH on the strongest candidates before proposing
anything. Part of that research is mandatory: READ THE CONVENTION'S DECISION RECORD, so that every
proposal NAMES THE CLAUSE IT BEARS ON and THAT CLAUSE'S VALIDATION MARKER. A proposal that cannot
name its clause is not ready to be proposed.

Interaction, in the LEAD SESSION ONLY (see the interactive-gate constraint below): multiSelect over
candidates, then create/note/skip per candidate, then a confirmation gate before anything is
written. Approved candidates are created as tasks with file scopes and dependencies, AFTER BACKLOG
RECONCILIATION against the open backlog -- compare each proposed task against open tasks and create,
widen, add a dependency edge, or narrow a file scope, whichever the comparison warrants, per
`docs/reference/standards/multi-task-creation-standard.md`.

TWO PROHIBITIONS, both binding:
  1. It NEVER EDITS THE CONVENTION. It proposes tasks; the tasks do the work through the normal
     lifecycle.
  2. It NEVER BYPASSES the consuming repository's own escalation protocol. A proposal that bears on
     a BINDING clause is filed as a RESEARCH-AND-ESCALATE task, not as a direct revision task.

WATERMARK: record which observations a `--revise` run has already considered, so a later run does
not re-propose the same evidence. Without this the second run repeats the first.

== INTERACTIVE GATES RUN IN THE LEAD SESSION ==

`AskUserQuestion` is NOT REACHABLE from a dispatched subagent on this harness (measured; a separate
backlog item exists to correct the frontmatter standard's contrary claim and rehome the affected
gates). Every multiSelect, per-candidate choice and confirmation gate in `--revise` must therefore
execute in the LEAD session, with only non-interactive work delegated. Design for this from the
start rather than discovering it at implementation time.

Honour the telemetry guardrails in
`extensions/memory/context/project/memory/telemetry-guardrails.md`: evaluator outside the loop, no
`sess_*`-to-OTel join, and the 30-day transcript window -- which means `--review` reports on what
was CAPTURED at postflight, and must say so rather than appearing to read live telemetry.

== DELIVERABLES ==

  - `commands/books.md` -- flag parsing, mirroring `distill.md`.
  - `skills/skill-books-review/SKILL.md` -- the shared sub-mode skeleton plus stub pointers.
  - `context/project/books/patterns/books-review-submode.md` -- the read-only review in full.
  - `context/project/books/patterns/books-revise-submode.md` -- the proposal flow, the decision-record
    reading requirement, the escalation-protocol prohibition, and the watermark.
  - `manifest.json`, `index-entries.json`, `EXTENSION.md`, `README.md` -- registration and docs.

== ACCEPTANCE ==

`--review` writes only its dated report and proposes nothing; it names unmeasured dimensions
explicitly; every `--revise` proposal names a convention clause and that clause's validation marker;
a proposal against a binding clause is filed as research-and-escalate; the watermark prevents
re-proposal across two consecutive runs; backlog reconciliation precedes creation; every interactive
gate sits in the lead session; registration files are consistent with
`scripts/check-extension-docs.sh`.

== DEPENDENCY ==

Depends on the books observer task, which produces the observation records both sub-modes read.
There is nothing for `--review` to report on, and no evidence for `--revise` to evaluate, until the
observer is writing records.

---

### 332. Books observer: the per-task convention observation record
- **Effort**: 4-8 hours
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: Task 298, Task 329, Task 330, Task 331
- **Research**: [332_books_observer_convention_observation_record/reports/01_books-observer-design.md]
- **Plan**: [332_books_observer_convention_observation_record/plans/01_books-observer-record.md]
- **Summary**: [332_books_observer_convention_observation_record/summaries/01_books-observer-record-summary.md]

**Description**: SOURCE STORE IS THE EDIT TARGET (agent-system/extensions/books/..., never .claude/**). `.claude/` is a
gitignored, disposable deploy artifact regenerated from the source store; a file hand-authored there
is silently wiped by the next deploy. See rules/source-store-deploy-boundary.md.

No task-number references in any file written into the source store
(rules/no-task-references-in-deliverables.md). Cite durable anchors -- filenames, section headings,
convention clause names -- instead. Task numbers are permitted in this description and in specs/**.

== GOAL ==

Register the books extension's own post-task observer on the generic observer seam, and write
`scripts/books-observe.sh`, which produces ONE OBSERVATION RECORD PER BOOKS TASK, appended to a log
in the CONSUMING REPOSITORY's `specs/` tree. The record joins the task's generic per-task records
with books-specific facts, so that the question "is this convention actually working?" becomes
answerable from accumulated evidence rather than from recollection.

== REGISTRATION ==

Declare an observer in `manifest.json` matching topic `books` AND task_type `books`. Both, because
the measured reality in the consuming repository ~/Projects/Logos/Verification is that the 17 tasks
carrying topic `books` have task_type `lean4` (14), `general` (2) and `typst` (1) -- NOT ONE has
task_type `books`. Topic is therefore the key that actually matches; task_type is declared for the
future case where a books-native task type exists. Note also that `manifest.json` today has
`provides.hooks: []` and NO top-level `hooks` object -- this task adds the `observers` block, it
does not add lifecycle hooks.

== WHAT ONE OBSERVATION RECORD CONTAINS ==

The join: the task's `issues.jsonl` and `metrics.jsonl` (both written by the generic per-task record
machinery this task depends on) PLUS books-specific facts:

  - Verification-tier runs and outcomes, with counts and time, for each tier: lake build, layer
    lint, certify, full gate, recheck.
  - Certifier outcome classes; refusals; warnings.
  - Vacuous passes -- a gate that passed while checking nothing is the single most expensive signal
    in the measured corpus and must be first-class, not inferred.
  - Escalations and validation-marker promotions, recorded AGAINST THE CONVENTION DECISION they
    bear on, by that decision's durable name.
  - `book_requires` churn.
  - The BEFORE/AFTER DELTA of the consuming repository's own convention snapshot probe, WHEN IT
    PROVIDES ONE. Invoke it if present; record `absent` otherwise. OWNERSHIP BOUNDARY, binding:
    the repository owns its probes and the contract for them; the extension owns the join. Do not
    ship a probe from the extension and do not make the observer's correctness depend on one
    existing.

== POLARITY AND THE SEVEN DIMENSIONS ==

Every signal carries a POLARITY (`positive` | `negative`) and one or more of exactly seven
dimensions:

  (a) maintainability by scientists and engineers;
  (b) cross-pollination between different customers' formalizations;
  (c) guardrails and QA;
  (d) token and cost efficiency;
  (e) readability for engineers who must understand a book well enough to talk with customers;
  (f) exposing parts to users intuitively;
  (g) compile and compose efficiency -- with IMPORT WEIGHT and COMPILATION WEIGHT first-class,
      not folded into a general performance note.

DIVISION OF LABOUR, and it matters: MECHANICAL FIELDS ARE COMPUTED by the observer (tier runs,
timings, churn, outcome classes, snapshot delta). DIMENSION TAGS ARE SUPPLIED BY THE WORKING AGENTS,
through the `tags` object on issue-log entries -- the open extension seam on that schema. The
observer reads them; it does not guess them. The agents are instructed how to tag by a books context
file injected for books-topic dispatches, which is a deliverable of this task.

== MAINTENANCE BURDENS: PAIRED SIGNALS ==

A convention change that lifts one burden usually creates another. Record burdens CREATED and
burdens LIFTED AS PAIRED SIGNALS on the same record, so a later review cannot read half of a trade
and call it a win. This is a schema requirement on the observation record, not a reviewer habit.

== BACKFILL ==

A `--backfill` mode for already-completed books tasks, deriving what is still derivable and marking
each derived figure as backfilled, consistent with the per-dispatch metrics script's own backfill
posture. The 16 completed books tasks in the consuming repository are the obvious first corpus.

== DELIVERABLES ==

  - `scripts/books-observe.sh` -- the observer, plus `--backfill`.
  - `scripts/tests/test-books-observe.sh` -- the join, the absent-probe path, the paired-burden
    requirement, polarity/dimension validation, backfill marking, and non-blocking failure.
  - `manifest.json` -- the `observers` declaration.
  - `context/project/books/standards/observation-record.md` -- the observation-record standard:
    full schema, the seven dimensions with definitions, the polarity rule, the paired-burden rule,
    the computed-versus-supplied division of labour, and the probe ownership boundary.
  - `context/project/books/patterns/signal-tagging.md` -- the signal-tagging guide for working
    agents: how to populate `tags` on an issue-log entry, with worked examples per dimension.
  - `index-entries.json` and `EXTENSION.md` -- register the two new context files and document the
    observer.

NOTE ON CONTEXT TREE OWNERSHIP: the books context corpus tree
(`extensions/books/context/project/books/**`) is owned by the corpus-authoring backlog item
task 298, which has not yet run. This task depends on it and ADDS two files to that tree; it does
not restructure the tree or edit files the corpus task authors.

== REQUIRED COMPLETION-SUMMARY STATEMENT ==

The implementation summary MUST state plainly that NONE OF THIS TAKES EFFECT in the consuming
repository until the user (i) LOADS THE BOOKS EXTENSION there -- it is currently not loaded -- and
(ii) REDEPLOYS CORE. Both are the user's actions, not this task's, and not something the task can
verify. Omitting this leaves a feature that appears shipped and is inert.

== ACCEPTANCE ==

One observation record per books task, with the generic and books-specific facts joined; vacuous
passes and snapshot deltas present as first-class fields; `absent` recorded when the repository
provides no probe; paired burdens enforced by the schema; dimension tags read from the issue log
rather than inferred; backfill produces marked figures for the completed corpus; the deployment
caveat stated in the summary; shellcheck clean per context/standards/shell-strict-mode.md.

== DEPENDENCIES ==

Depends on task 298 (authors the books context corpus tree this task adds two files to), and on
the three generic tasks that supply what it joins and the seam it registers on: the per-task issue
log (the `tags` seam and the issue records), the per-dispatch cost-and-timing record (the metrics
records), and the topic-keyed observer seam (the registration mechanism itself).

---

### 331. Topic-keyed post-task observer seam for extensions
- **Effort**: 3-6 hours
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: Task 327, Task 330
- **Research**: [331_topic_keyed_post_task_observer_seam/reports/01_topic-keyed-observer-seam.md]
- **Plan**: [331_topic_keyed_post_task_observer_seam/plans/01_topic-keyed-observer-seam.md]
- **Summary**: [331_topic_keyed_post_task_observer_seam/summaries/01_topic-keyed-observer-seam-summary.md]

**Description**: SOURCE STORE IS THE EDIT TARGET (agent-system/extensions/core/..., never .claude/**). `.claude/` is a
gitignored, disposable deploy artifact regenerated from the source store; a file hand-authored there
is silently wiped by the next deploy. See rules/source-store-deploy-boundary.md.

No task-number references in any file written into the source store
(rules/no-task-references-in-deliverables.md). Cite durable anchors -- filenames, section headings,
manifest keys -- instead. Task numbers are permitted in this description and in specs/** artifacts.

== GOAL ==

A manifest-declared `observers` block by which an extension registers a script to run AFTER a task
reaches a resting state under `/orchestrate`, matched on the task's `topic` and/or `task_type`.
Advisory and non-blocking. This is the generic seam; a concrete first consumer is a separate backlog
item that depends on this one.

== THE MATCHING CONTRACT ==

An observer declaration names the script plus the keys it matches on:

  - `topic` match: the task's `topic` field.
  - `task_type` match: the task's `task_type` field.
  - PREFIX-AWARE on both: a declared match on `books` matches a value of `books:certify`, because
    compound task-type values with a `:` sub-route are already an established convention in this
    system (e.g. `present:grant`). Match on the segment before the first `:`.
  - An observer may declare either key or both. Declaring both means match-if-either, and the
    reason is below in WHY TOPIC.

== INVOCATION SITE AND ORDERING ==

Invoked EXPLICITLY from `scripts/orchestrate-cycle-postflight.sh`'s completion arm (measured
~1048-1125; RE-MEASURE BEFORE EDITING, since dependency tasks edit this same file). The script
already receives `--task-type` (measured line 244).

Arguments passed to the observer: task number, task type, topic, task directory, session id, and
the resting status reached.

ORDERING IS PART OF THE CONTRACT: the observer runs AFTER the per-dispatch issue-log and metrics
records for that dispatch have been written, so an observer can READ them. State this ordering in
the guide; an observer that runs before them sees an incomplete record and the whole seam is
worthless.

== ADVISORY AND NON-BLOCKING -- NOT NEGOTIABLE ==

An observer can never change task status, never fail a dispatch, never block. Its return code is
RECORDED AS AN EVENT (in `specs/events.jsonl`) and otherwise ignored. A missing, non-executable, or
crashing observer script produces a warning event and nothing else. Give it a timeout so a hanging
observer cannot wedge an orchestration.

== WHY TOPIC: THIS IS THE FIRST PLACE `topic` BECOMES A BINDING KEY ==

MEASURED, 2026-10-03: `topic` is NEVER a routing key today. Its only readers are
`generate-todo.sh`, `generate-task-order.sh`, `manage-topics.sh`, `validate-state.sh` and
`orchestrate-predispatch-review.sh` -- all of them presentation, grouping or validation. Nothing
dispatches on it.

The motivating measurement for keying on `topic` rather than on `task_type` alone: in the consuming
repository ~/Projects/Logos/Verification, the 17 tasks carrying topic `books` have task_type `lean4`
(14 of them), `general` (2) and `typst` (1). NOT ONE has task_type `books`, and the books extension
is not even loaded in that repo. An observer keyed on `task_type` alone would therefore have
matched NONE of the 17 tasks whose work it exists to observe. That is the whole argument for `topic`
as a match key, and it must be written down where the next person looks.

Because this makes `topic` load-bearing for the first time, DOCUMENT IT PRECISELY in two places:
`context/reference/state-management-schema.md` (the `topic` field's description must stop implying
it is presentational only) and `docs/guides/creating-extensions.md` (the `observers` block schema,
with a worked example).

== WHY NOT REUSE THE LIFECYCLE-HOOK CONTRACT -- RECORD THIS REASONING ==

The existing extension lifecycle hooks (`manifest.json` top-level `hooks` object: preflight,
context_injection, verification, postflight) look like the obvious home and are NOT usable here.
Two measured reasons, both of which belong in the guide so this is not re-litigated:

  1. Lifecycle hooks resolve by MANIFEST TASK_TYPE EQUALITY -- `scripts/skill-base.sh` (measured
     151-170; RE-MEASURE). Equality, not prefix; task_type, not topic. Per the measurement above
     that matches nothing for a topic-grouped corpus.
  2. Under `/orchestrate` the postflight hook receives AN EMPTY TASK TYPE.
     `scripts/orchestrate-cycle-postflight.sh` contains ZERO `TASK_TYPE` references, and
     `skill_postflight_update` passes `"${TASK_TYPE:-}"` (measured `skill-base.sh:1089`). So even
     AFTER the lifecycle-hook repair that has already landed, an extension still has no reliable
     post-task binding under `/orchestrate`. The repair fixed the resolver, the return-code channel
     and the verification stage; it did not and could not supply a task type that is never set on
     that path.

Do not "fix" this by plumbing TASK_TYPE through the postflight hook as a substitute: that would
still be equality-on-task_type and would still match none of the measured 17 tasks.

== DELIVERABLES ==

  - `scripts/run-task-observers.sh` -- resolve declarations across loaded extensions, match, invoke
    with a timeout, emit the rc event.
  - Matching/resolution support in `scripts/lib/manifest-routing-lib.sh`, alongside the existing
    shared routing ladder, so observer resolution is not a second independent manifest reader.
  - `scripts/tests/test-run-task-observers.sh` -- prefix match, topic-only match, task_type-only
    match, both-declared match, no match, missing script, non-zero rc, timeout, and a test that a
    failing observer does not change status.
  - `scripts/orchestrate-cycle-postflight.sh` invocation in the completion arm, correctly ordered
    after the issue-log and metrics writes.
  - `docs/guides/creating-extensions.md` -- the `observers` schema, the ordering guarantee, the
    advisory contract, and the WHY NOT LIFECYCLE HOOKS reasoning above.
  - `context/reference/state-management-schema.md` -- `topic` is now a binding key.
  - `scripts/check-extension-docs.sh` -- extend the doc/manifest consistency check to cover the new
    block, so a declared observer with no documentation is caught.

== ACCEPTANCE ==

A test extension declaring an observer on topic `X` has it invoked for a task with topic `X` and
with topic `X:sub`, and not invoked for topic `Y`; the observer sees a task directory in which this
dispatch's issue-log and metrics lines are already present; a crashing observer leaves the task's
status and the orchestration unaffected and produces an rc event; `check-extension-docs.sh` flags an
undocumented observer; shellcheck clean per context/standards/shell-strict-mode.md.

== DEPENDENCIES ==

Depends on task 327 (the extension lifecycle hook repair), which is COMPLETED: its resolver,
return-code channel and verification-stage work is the ground this task's "why not reuse" argument
is measured against, and the guide sections it rewrote are the ones this task extends.
Depends on the per-dispatch cost-and-timing-record task for the ordering guarantee above (the
observer must run after both per-dispatch records) and for file-footprint serialization on
`scripts/orchestrate-cycle-postflight.sh`.

---

### 330. Per-dispatch cost and timing record
- **Effort**: 4-8 hours
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: orchestrator
- **Dependencies**: Task 329
- **Research**: [330_per_dispatch_cost_and_timing_record/reports/01_dispatch-metrics-script-design.md]
- **Plan**: [330_per_dispatch_cost_and_timing_record/plans/01_dispatch-metrics-record.md]
- **Summary**: [330_per_dispatch_cost_and_timing_record/summaries/01_dispatch-metrics-record-summary.md]

**Description**: SOURCE STORE IS THE EDIT TARGET (agent-system/extensions/core/..., never .claude/**). `.claude/` is a
gitignored, disposable deploy artifact regenerated from the source store; a file hand-authored there
is silently wiped by the next deploy. See rules/source-store-deploy-boundary.md.

No task-number references in any file written into the source store
(rules/no-task-references-in-deliverables.md). Cite durable anchors -- filenames, section headings,
field names -- instead. Task numbers are permitted in this description and in specs/** artifacts.

== GOAL ==

A script, `scripts/dispatch-metrics.sh`, producing an append-only per-task `metrics.jsonl` in the
task directory -- ONE LINE PER DISPATCH -- called from `scripts/orchestrate-cycle-postflight.sh`'s
completion, partial AND blocked arms. Without this, the cost of an orchestration is not merely
unreported, it is unrecoverable.

== WHY: NO COST FIGURE EXISTS ANYWHERE TODAY (MEASURED, 2026-10-03) ==

No token, cost, model or tool-call figure is recorded anywhere under `specs/`. Not one. The figures
exist only in Claude Code's own transcripts:

  ~/.claude/projects/<slug>/<cc_session_id>.jsonl        (lead session)
  ~/.claude/projects/<slug>/agent-*.jsonl                (subagent dispatches)

Each message there carries `usage{input_tokens, cache_creation_input_tokens,
cache_read_input_tokens, output_tokens}` and a `model` field. The join key back to our own records
is the `cc_session_id` recorded on `session_stop` events in `specs/events.jsonl`.

Three measured traps that have already misled analysis and MUST NOT be repeated:

  - `events.jsonl` `duration_seconds` is THE HOOK SCRIPT'S OWN RUNTIME (measured range 0.2-2.6 s).
    It is NOT phase duration. Any report that treats it as phase duration is wrong by three orders
    of magnitude.
  - `dispatch_seq_counter` is NOT a dispatch count. It advances roughly 3 per dispatch.
  - Per-phase wall-clock IS derivable, but from PHASE-COMMIT TIMESTAMPS, not from the above.
    Dispatch counts are derivable from `lifecycle_stage` preflight events. `.dispatch/{seq}.md`
    carries a `dispatch_start_ts` -- that is the correct dispatch-start anchor.

== WHAT ONE LINE RECORDS ==

  phase kind            research | plan | implement | aux kind | conclusion
  agent                 the dispatched agent's name
  model                 as read from the transcript, not as requested by a flag
  wall_clock_seconds    dispatch start (`.dispatch/{seq}.md` `dispatch_start_ts`) to return.
                        EXPLICITLY NOT hook runtime -- see the trap above.
  tokens                by class: input, cache_creation, cache_read, output
  tool_calls            count, and ideally a per-tool breakdown
  outcome               completed | partial | blocked | failed | deferred
  phases_completed      how many plan phases this dispatch closed
  commits               count and subjects
  churn                 lines added/removed, SPLIT into inside-specs/ versus outside-specs/.
                        The split matters: specs/ churn is bookkeeping, outside-specs/ churn is
                        product.
  gate_runs             verification/gate invocations with their durations WHERE THE TRANSCRIPT
                        SHOWS THEM. Where it does not, record absent rather than zero.

== TIMING CONSTRAINT: CAPTURE AT POSTFLIGHT, NOT LATER ==

Tier 4 transcripts have a MEASURED 30-DAY RETENTION WINDOW. The token and tool-call figures are
therefore perishable: they must be read and written at postflight time, while the transcript is
still on disk. A design that defers transcript reading to report time is a design that silently
produces empty metrics for anything older than a month. Honour the telemetry guardrails in
`extensions/memory/context/project/memory/telemetry-guardrails.md` -- in particular the absent
`sess_*`-to-OTel join and the evaluator-outside-the-loop constraint.

== --backfill MODE ==

`dispatch-metrics.sh --backfill N` derives, for an already-completed task N, what is STILL
derivable: per-phase wall-clock from phase-commit timestamps, dispatch counts from `lifecycle_stage`
preflight events, git churn from the commit range. Every figure produced this way is MARKED AS
BACKFILLED in the record, so a later report never presents a derived figure as a measured one.
Token and tool-call figures are omitted (not zeroed) when the transcript is gone.

== NON-BLOCKING ==

A metrics failure NEVER fails a dispatch, never changes status, never emits a user-facing error.
Warn on stderr and continue. This follows the existing posture of `update-task-status.sh` and of
`state-write.sh --regen-todo`.

== CALL SITES ==

`scripts/orchestrate-cycle-postflight.sh` receives `--task-type` (measured line 244) and owns the
completion arm (measured ~1048-1125). RE-MEASURE ALL LINE NUMBERS BEFORE EDITING -- a dependency
task edits this same file. Wire the completion, partial and blocked arms; a blocked dispatch is
precisely the one whose cost is most worth knowing and is today recorded nowhere.

== DELIVERABLES ==

  - `scripts/dispatch-metrics.sh`
  - `scripts/tests/test-dispatch-metrics.sh` -- including a test that a missing transcript yields
    omitted rather than zeroed token fields, and a test that a metrics failure does not fail the
    caller.
  - `context/formats/dispatch-metrics.md` -- the record schema, the join procedure via
    `cc_session_id`, the three measured traps above stated as warnings, and the 30-day window.
  - Postflight call sites in all three arms.

== ACCEPTANCE ==

One line per dispatch appears for a real multi-dispatch orchestration; the wall-clock figure is
dispatch-to-return and demonstrably not hook runtime; a blocked dispatch produces a line; `--backfill`
on a completed task produces marked-as-backfilled figures and omits what is unrecoverable;
shellcheck clean per context/standards/shell-strict-mode.md.

== DEPENDENCY ==

Depends on the per-task issue log task for FILE-FOOTPRINT SERIALIZATION on
`scripts/orchestrate-cycle-postflight.sh`, which both tasks edit. It is also a natural ordering:
`issues.jsonl` and `metrics.jsonl` are sibling per-task append-only records and should share
conventions (append atomicity, non-fatal failure, naming), so build the second against the first
rather than in parallel with it.

---

### 329. Per-task issue log: contract, writer and dispatch threading
- **Effort**: 4-8 hours
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 326, Task 285
- **Research**: [329_per_task_issue_log_contract_writer_and_threading/reports/01_issue-log-contract-writer-threading.md]
- **Plan**: [329_per_task_issue_log_contract_writer_and_threading/plans/01_issue-log-writer-threading.md]
- **Summary**: [329_per_task_issue_log_contract_writer_and_threading/summaries/01_issue-log-writer-threading-summary.md]

**Description**: SOURCE STORE IS THE EDIT TARGET (agent-system/extensions/core/..., never .claude/**). `.claude/` in
every repo is a gitignored, disposable deploy artifact regenerated from the source store; a file
hand-authored there appears to save and is silently wiped by the next deploy. See
rules/source-store-deploy-boundary.md.

No task-number references in any file written into the source store (rules/no-task-references-in-deliverables.md).
Task numbers are renumbered by vault operations and are meaningless to a future reader: cite durable
anchors -- a filename, a section heading, a class name from the taxonomy enum. Task numbers are
permitted in this description, in specs/** artifacts, and in commit messages, nowhere else.

== GOAL ==

An append-only per-task `issues.jsonl` in the task directory (`specs/{NNN}_{SLUG}/issues.jsonl`),
written by ONE script -- `issue-record.sh` -- which appends one validated entry per call, and which
is called by BOTH dispatched agents and the orchestrator. The log survives dispatch overwrites; it
is CAPTURE ONLY (see the CAPTURE ONLY section below); and it becomes the evidence base from which
the orchestration conclusion stage derives its proposals.

Model the writer on `scripts/system-defect-record.sh`, which is the existing append-one-validated-
entry precedent in this codebase (atomic append, schema validation of the entry before it lands,
non-fatal on failure). Read it first and follow its conventions rather than inventing new ones.

== WHY: WHERE ISSUES GO TODAY (MEASURED, 2026-10-03) ==

Issues are recorded today only as free prose, in six scattered and partly ephemeral places:

  1. Implementation summaries, under free-prose "Plan Deviations" / "Follow-ups" headings.
  2. `.decisions.json` Q/A entries. (A writer script for this file is the subject of a separate
     backlog item, task 285, which this task depends on -- see DEPENDENCIES.)
  3. `progress/phase-N-progress.json` `deviations[]` and `approaches_tried[]` -- present on some
     tasks only, absent on others.
  4. Research/implementation handoffs, under "What NOT to Try".
  5. `.orchestrator-handoff.json` `blockers[]` and `dead_ends` -- rarely populated.
  6. `.return-meta.json` `errors[]` -- populated for partial/failed/blocked returns only.

Two of these are DESTROYED routinely: `.return-meta.json` and `.orchestrator-handoff.json` are
OVERWRITTEN on every dispatch, so the detail of a blocked dispatch survives only in the commit
subject line. A `reflection` field is specified in the state schema but is DEAD: its only writer,
`scripts/orchestrator-postflight.sh`, has no live callers; zero state.json entries carry it across
three measured repos; it is present in only 12 of 146 measured `.return-meta.json` files.
Positive signals -- what worked, what saved time -- have NO home at all.
`scripts/system-defect-record.sh` plus `skill_orchestrate_append_detected_defect` cover only
MECHANICALLY DETECTED schema violations in a closed 16-class enum, and are rendered
accumulate-only at conclusion.

Net effect: the cost of a convention, a gate, or a tooling gap is unrecoverable after the fact.

== ENTRY SCHEMA ==

One JSON object per line. Fields:

  kind              "issue" | "win"  -- positive signals get a home, on equal footing.
  class             One of the seed enum below. EXTENSIBLE: unknown classes are accepted with a
                    warning, not refused, so a new failure mode can be recorded the first time it
                    is hit rather than after a schema change.
  severity          Ordered scale (choose and document it; e.g. blocking | costly | minor).
  phase             research | plan | implement | conclusion | other.
  dispatch_seq      The dispatch sequence number this entry belongs to.
  what_happened     Free prose, one paragraph. Required.
  evidence_path     Path to the artifact, log line, commit, or transcript that substantiates it.
  estimated_cost    Minutes, dispatches, or gate runs LOST (for an issue) or SAVED (for a win).
                    Record the unit explicitly; do not force everything into minutes.
  resolution        "fixed_inline" | "worked_around" | "open".
  suggested_channel "fix_now" | "follow_up_task" | "agent_system". A HINT for the conclusion
                    stage, never a decision.
  tags              An OPEN object. Extensions populate it; core neither validates its interior
                    nor depends on it. This is the seam an extension's own dimension tagging uses.

== SEED CLASS ENUM: THE 15-CLASS TAXONOMY ==

Empirically grounded in 16 completed books tasks in ~/Projects/Logos/Verification. Seed the enum
with exactly these, with a one-line gloss each in the format doc:

  design-record defect or ambiguity; gate collision; missing cheap verification tier;
  vacuous or silent pass; tooling bug or gap; resource/OOM including misdiagnosis;
  plan scope-hypothesis wrong; planned feature absent; language or module-system gotcha;
  environment; cross-task ownership/territory; stale deploy or source-store boundary;
  orchestration defect; stale workaround; cost-forced exclusion or substituted verification.

== THREADING: ONE POINT, NOT 78 ==

`scripts/orchestrate-build-dispatch.sh` (measured ~417-558; RE-MEASURE BEFORE EDITING) already
emits per-dispatch prompt sections -- Identity, Handoff, Territory, Prior Decisions, User-Decision
Contract. That is a single threading point that reaches EVERY dispatched agent without editing any
of the 78 agent definition files. Add one `## Issue Log` section there, plus the corresponding
instruction in the shared includes `context/contracts/wrap-up.md` and
`context/contracts/phase-closure.md`, so every implementation and research agent is told to RECORD
AS ISSUES ARISE rather than reconstruct them at the end. Reconstruction at the end is exactly what
produces the free prose the current state consists of.

Orchestrator-side recording: add calls at the sites that today leave only a commit subject --
blocked dispatch, off-schema return, recovery, loop-guard exhaustion, and defer. These live in
`scripts/orchestrate-cycle-postflight.sh`; its completion arm is around lines 1048-1125 (measured;
RE-MEASURE).

== CAPTURE ONLY -- A HARD BOUNDARY OF THIS TASK ==

Nothing is surfaced to the user mid-run. Nothing is acted on. No proposal is generated, no gate is
added, no status is changed. Review of the log belongs exclusively to the orchestration conclusion
stage, which is a separate backlog item (task 273) that this task is a dependency of, and whose
description has been amended to say that its three channels are DERIVED FROM these logs. Resist
the pull to add a mid-run summary here: a mid-run surface is the defect the conclusion-stage design
exists to avoid.

Non-blocking throughout: a failure to record an issue must never fail a dispatch.

== REQUIRED DECISION: RELATION TO THE SIX EXISTING SURFACES ==

Decide and RECORD, in the format doc, the relation of `issues.jsonl` to each of: `.return-meta.json`
`errors[]`; `progress/phase-N-progress.json` `deviations[]`; handoff `dead_ends`/`blockers`;
`system_defect` events; and the dead `reflection` field. For each, the verdict is one of SUBSUME
(the old surface stops being written), MIRROR (both written, one derived from the other), or LEAVE
(independent, with the boundary stated). If `reflection` is judged subsumed, RETIRE it in the same
pass -- remove it from the schema, from `KNOWN_ENTRY_FIELDS` in `scripts/validate-state.sh`, and
from `scripts/orchestrator-postflight.sh` -- rather than leaving a second dead field beside a live
one. Do not leave this decision implicit.

== DELIVERABLES ==

  - `scripts/issue-record.sh` -- the single writer.
  - `scripts/tests/test-issue-record.sh` -- schema validation, append atomicity, unknown-class
    warning path, non-fatal failure path.
  - `context/formats/issue-log.md` -- the format doc: entry schema, the 15-class enum with glosses,
    the recorded relation verdicts above, and when an agent should record.
  - The dispatch threading section and the two shared-contract includes.
  - Orchestrator-side call sites.
  - `context/formats/return-metadata-file.md` updated to state the relation verdict for `errors[]`.

== ACCEPTANCE ==

An agent dispatched through `orchestrate-build-dispatch.sh` receives the `## Issue Log` instruction;
a recorded entry survives a subsequent dispatch's overwrite of `.return-meta.json`; a blocked
dispatch leaves a structured entry rather than only a commit subject; wins are recordable; the
relation verdicts are written down; `reflection` is either live or gone, not dead; shellcheck clean
per context/standards/shell-strict-mode.md.

== DEPENDENCIES AND KNOWN OVERLAP ==

Depends on task 285 (adds the missing `.decisions.json` writer and touches
`orchestrate-cycle-postflight.sh`) and task 326 (adds `--gate` at implement dispatch and touches
`orchestrate-build-dispatch.sh`). Both edges are FILE-FOOTPRINT SERIALIZATION on those two scripts,
not logical prerequisites.

KNOWN OVERLAP, not serialized: task 299 (guarantee detection of in-place plan revision concurrent
with a live implement dispatch) also edits `scripts/orchestrate-build-dispatch.sh`. Whichever of the
two lands second must re-measure the line ranges above before editing.

---

### 328. Systematic script and test corpus efficiency
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 170, Task 318, Task 322, Task 304, Task 303

**Description**: Systematic top-to-bottom efficiency refactor of the shell script AND test corpus under agent-system/extensions/**, driven by script-inventory.sh's ranked output rather than by hand-filed point defects. Supersedes and folds in tasks 307, 308 and 270. Depends on 170, 318, 322, 304, 303.

SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/** (never .claude/**, a disposable deploy artifact).

== MOTIVATION: A GAP IN THE INTAKE MECHANISM ==

Tasks touching this corpus are filed by hand from defects hit live during /orchestrate runs. That intake only ever surfaces what BROKE. Needless complexity, duplicated logic, poor division of labor and slow tests never break anything -- they only cost -- so they are invisible to the filing process by construction and will not self-correct. Task 250 closed half this gap by BUILDING the standing probe (scripts/script-inventory.sh) but spent its decomposition budget on a single file (orchestrate-cycle-plan.sh, 3026->2597 lines, 14.2%). This task is the standing consumer of that probe's output, across the whole corpus, including the test corpus.

== MEASURED 2026-10-03 via scripts/script-inventory.sh (RE-MEASURE BEFORE ACTING) ==

Corpus: 197 non-test *.sh files, 72,761 lines, 3,472,506 bytes. Separately: 85 test suites under core/scripts/tests/.

Duplication: 52 of 197 scripts carry duplicate blocks. Verified clusters:

  (1) THE FIVE-LINT CLUSTER -- the clearest extract-a-lib target in the corpus. All five report peers=4, i.e. all are mutual near-copies:
      - lint/lint-task-lookup-adoption.sh        551L, 107 dup blocks
      - lint/lint-branch-gated-sections.sh       398L,  78 dup blocks
      - lint/lint-directory-pathspec-boundary.sh 369L,  67 dup blocks
      - lint/lint-state-writer-boundary.sh       348L,  97 dup blocks
      - lint/lint-scoped-commit-boundary.sh      346L,  92 dup blocks
      Hand-verified independently of the metric: 115-132 shared non-blank, non-comment lines per pair (comm -12 on sorted unique lines, comments and blanks stripped) -- roughly a third of each file is a shared skeleton, DESPITE each already sourcing two libs. ~2,012 lines total.

  (2) install-extension.sh (299L) / uninstall-extension.sh (237L): mutual pair, 33 dup blocks each.
  (3) typst/scripts/chapter-quality-check.sh (754L) / typst-element-lint.sh (372L): mutual pair, 44 dup blocks each.
  (4) literature/scripts/literature-search.sh: 1,635L with 172 dup blocks and peers=0 -- i.e. SELF-internal repetition inside one file, a different defect class from the cross-file clusters above.

Test-coverage constraint (binds the whole task): 157 of 197 scripts have no paired test, and 50 of those exceed 300 lines. A large untested script cannot be safely refactored, so characterization tests must precede any edit to one. This is why 170 is a dependency rather than a sibling.

Test-corpus runtime: verify-deploy.sh Gate 8 measured at 117.9s of a ~2.8min total run -- the dominant gate. Cause is volume and process-spawn/IO, not compute: 85 suites, each a separate bash process, many shelling out further. Task 265 already added run-all.sh --jobs (capped at JOBS_CAP=4, deliberately below nproc because pooled suites contend) and --skip-slow. Remaining headroom is the 4x cap and per-suite startup cost, NOT more parallelism.

== TWO PROBE METRICS THAT MUST NOT BE TRUSTED AT FACE VALUE ==

  - zero_caller_count = 0 does NOT mean there is no dead code. Task 250's own summary records that a script's own manifest.json entry counts as an inbound caller, so inbound_callers over-counts by design and the field found nothing. Dead-code detection is UNSOLVED and this task must not treat 0 as an answer; devise a real reachability test (note task 251 is solving the analogous problem for the CONTEXT corpus -- borrow its method, do not duplicate it; file_scopes are disjoint so the two run in parallel).
  - has_test is a filename-convention check only. claude-refresh.sh reports has_test=false although task 217 just grew its matcher suite to 163 assertions, because the file is named test-claude-refresh-matcher.sh. So 157 overstates the true coverage gap. Re-derive real coverage before using it to gate anything.

== FOLDED-IN TASKS (supersede and close these three; their file_scopes merge into this task) ==

  - 307 (/todo: consolidate the duplicated skill-todo implementation, wire roadmap pruning, cut the per-task jq and subprocess fan-out). Files: commands/todo.md, skills/skill-todo/SKILL.md, manifest.json, context/architecture/system-overview.md, context/patterns/context-protective-lead.md, scripts/memory-harvest.sh. NOTE: task 322 is a verified REGRESSION fix on todo.md and skill-todo/SKILL.md and MUST land first -- do not refactor those two files before 322 closes.
  - 308 (/review: wire roadmap regeneration, collapse the redundant jq and generate-todo passes). Files: commands/review.md.
  - 270 (re-runnable null-safety audit of jq mutation sites across core scripts, then decide whether a shared guard idiom belongs in scripts/lib/). Files: scripts/check-jq-null-safety.sh, scripts/tests/test-check-jq-null-safety.sh, scripts/orchestrate-build-dispatch.sh, scripts/lib/, docs/reference/utility-scripts-inventory.md. This is the same shape as the rest of the task -- a shared idiom extracted into lib/ -- so it belongs here rather than standing alone.

Each folded task's own substance is to be delivered, not dropped: closing them is a consolidation, not a descope.

== DEPENDENCIES AND WHY EACH GENUINELY BLOCKS ==

  - 170 (audit and isolate shell test suites from ambient host state, record the convention): owns context/standards/shell-script-testing.md, the convention this task must refactor the test corpus AGAINST, plus eight state/timing-sensitive suites and task-lock.sh. Refactoring tests before the convention exists would be rework.
  - 318 (wire lint-directory-pathspec-boundary.sh into verify-deploy.sh as a numbered gate): that script is one of the five IN the duplication cluster above. Extracting its skeleton while it is still unwired churns verify-deploy gate numbering twice.
  - 322 (/todo directory-move staging gap, a verified regression): owns commands/todo.md and skill-todo/SKILL.md -- the exact two files folded-in task 307 owns. Direct file collision; the defect fix lands before the refactor of the same files.
  - 304 (one out-of-repository pathspec entry aborts staging for every valid path; callers sink nonzero exits while the task reports success): owns git-commit-scoped.sh, orchestrate-cycle-postflight.sh, orchestrate-unwind-dispatch.sh and both test-git-commit-scoped.sh / test-orchestrate-cycle-postflight.sh. Every incremental refactor commit in this task rides on that staging and exit-code contract; refactoring on top of a known-broken one would mask failures.
  - 303 (validate-state.sh resolves its omitted-argument default against CWD instead of the repo being validated): small, and a defect fix on a script+test pair this task's test work would otherwise touch mid-flight.

== SCOPE: TOP TO BOTTOM, BOTH CORPORA ==

Both halves are in scope, and the test corpus is a first-class target rather than only a safety net:
  (a) The 197 non-test scripts: de-duplicate the verified clusters into scripts/lib/, remove what is genuinely unneeded (after solving reachability honestly), and improve division of labor on the probe's top-ranked files.
  (b) The 85 test suites: cut per-suite startup cost and the Gate 8 117.9s figure, consolidate the duplicated test scaffolding, and close real coverage gaps on the 50 large untested scripts -- all WITHOUT reducing assertion coverage or functionality.

== HARD CONSTRAINTS ==

  - NO reduction in coverage or functionality. Behaviour preservation must be demonstrated per change, not asserted: prefer byte-identical output diffs against a pre-captured baseline (the technique task 250 used successfully on orchestrate-cycle-plan.sh --dry-run), and never weaken or delete a test to make a refactor pass. Task 250 hit exactly this and correctly REVERTED rather than weaken test-lint-deploy-caller-wrap.sh's two-genuine-caller invariant; it then took its own declared fallback and reported 14.2% against a ~29% target honestly. Do the same.
  - Characterization tests FIRST for any script that is large and genuinely untested.
  - Incremental: one cluster or one file per phase, full suite green and committed before the next starts.
  - Re-measure with script-inventory.sh at the start; the 2026-10-03 figures above are a snapshot, and the probe's own output is the authoritative input.
  - Note task 250's deferred follow-up: it left roughly half the redeploy-checkpoint region inline in orchestrate-cycle-plan.sh (the 479-line move broke test-lint-deploy-caller-wrap.sh's invariant), and separately flagged that deploy-headless.sh's --skip-verify defers run-all.sh so ~40 deploy-tree-first suites are not exercised against a freshly-redeployed tree. Both are in scope here.

---

### 327. Repair the extension lifecycle hook mechanism: broken resolver schema, absent return-code channel, uninvoked verification stage
- **Effort**: 1-3 hours
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: None
- **Research**: [327_repair_extension_lifecycle_hook_mechanism/reports/01_lifecycle-hook-mechanism-repair.md]
- **Plan**: [327_repair_extension_lifecycle_hook_mechanism/plans/01_lifecycle-hook-mechanism-repair.md]
- **Summary**: [327_repair_extension_lifecycle_hook_mechanism/summaries/01_lifecycle-hook-mechanism-repair-summary.md]

**Description**: SOURCE STORE IS THE EDIT TARGET: `agent-system/extensions/core/` (never `.claude/**`, a disposable deploy artifact -- see `rules/source-store-deploy-boundary.md`).

## Goal

Repair the extension lifecycle hook mechanism so a declared hook actually runs, can report
failure, and has a live invocation site. Today none of those three things is true.

## THIS IS A STANDING DEFECT, INDEPENDENT OF ANY ONE EXTENSION

The mechanism is not merely unused -- IT IS SILENTLY BROKEN FOR THE EXTENSIONS THAT ALREADY
DECLARE HOOKS. `agent-system/extensions/nix/manifest.json` declares
`{"preflight": "scripts/nix-preflight.sh", "context_injection": "scripts/nix-context.sh"}` and
`agent-system/extensions/nvim/manifest.json` declares
`{"context_injection": "scripts/nvim-context.sh"}`. NEITHER EVER FIRES. Those are the only two
extensions in the source store declaring a top-level `hooks` object, and both are dead. No
extension anywhere declares a `verification` hook.

That is why this is its own task rather than scope on a books task: the breakage predates and is
independent of the books program, it affects shipped extensions today, and its acceptance gate
("a declared hook actually fires, and a non-zero exit is observable") is disjoint from any books
deliverable.

## The three defects, with evidence

All line numbers in `agent-system/extensions/core/scripts/skill-base.sh`. RE-MEASURE BEFORE
EDITING -- they will have moved.

**1. The resolver is broken against the live `.claude-extensions.json` schema (lines 136-153).**
`skill_get_extension_dir()` at line 147 queries
`.loaded_extensions // [] | .[] | select(.task_type == $tt) | .name`. The live file has top-level
keys `["extensions","version"]`, where `.extensions` is an OBJECT KEYED BY EXTENSION NAME and the
per-extension entries carry no `task_type` field (their keys are `data_skeleton_files`,
`installed_dirs`, `installed_files`, `loaded_at`, `merged_sections`, `source_dir`,
`source_git_head`, `status`, `version`). Verified empirically by sourcing the deployed library:
`lean4 -> []`, `nix -> []`, `rust -> []`, and `skill_run_extension_hook verification ...` returns
0 as a silent no-op. Every other consumer already uses the object form -- compare
`scripts/measure-eager-context.sh:234`
(`.extensions | to_entries[] | select(.value.status=="active") | .key`). The fix must resolve via
`.extensions | to_entries` plus each manifest's OWN top-level `task_type` field (which
`extensions/lean/manifest.json` does carry, as `"lean4"`). THIS DEFECT ALONE MAKES THE ENTIRE
MECHANISM DEAD, so fix it first and prove it with a test that the `nix` preflight hook fires.

**2. There is no return-code channel (lines 159-192, decisively 190-191).** The invocation is:
    "$hook_path" "$task_number" "$task_type" "$task_dir" "$session_id" "$operation" || \
      echo "[skill-base] WARNING: Extension hook '${hook_name}' exited non-zero (non-blocking)"
The `||` branch is the function's LAST statement, so `skill_run_extension_hook` always returns 0.
A non-zero hook exit produces a console warning and nothing else -- no variable, no global, no
file, no `return`. Note that `docs/guides/creating-extensions.md:700-702` makes this NORMATIVE
("Exit non-zero: warning logged (non-blocking, skill continues)"), so changing the behaviour
REQUIRES changing that documented contract in the same change. DECIDE AND RECORD whether
non-blocking stays the DEFAULT with an opt-in blocking mode per stage, or whether the rc simply
becomes observable to the caller while dispositions stay stage-specific. Do not silently flip a
documented contract.

**3. The `verification` stage is dead code (lines 607, 622-624).** Its only call site is inside
`skill_validate_artifact()`, which has ZERO callers outside `skill-base.sh` itself and
`scripts/tests/test-skill-base-lifecycle.sh`; its rc is not even tested at the call site. Skills
call `validate-artifact.sh` inline instead -- for example `skills/skill-reviser/SKILL.md:309`,
and likewise in the cslib and present extensions' skills -- bypassing the function entirely.
`scripts/command-gate-out.sh` calls the DIFFERENT function `skill_validate_task_artifacts()`,
which contains no hook call (see also its comments at lines 272 and 275). The stage is declared
in the contract comment block at lines 114-131 and documented in the stage-mapping table at
`creating-extensions.md:713`, and is invoked by nothing. Either give it a live call site on a
path that actually runs, or move the invocation to a site that exists -- and if the stage is
retired instead, remove it from the contract block and the stage-mapping table in the same
change so the documentation stops advertising a stage that cannot fire.

## Contract facts to preserve

From the contract comment block at lines 114-131: the four stages are `preflight`,
`context_injection`, `verification`, `postflight`; a hook receives five POSITIONAL arguments
(`$1=task_number $2=task_type $3=task_dir $4=session_id $5=operation`) and no environment
variables; hook stdout goes straight to the console with no capture; and missing hook keys or an
absent `.claude-extensions.json` are SILENTLY SKIPPED. Discovery is
`jq -r --arg h "$hook_name" '.hooks[$h] // empty' "$manifest"` (line 179) followed by an
`[ -x "$hook_path" ]` test (line 185) which silently `return 0`s when the script is not
executable -- that silent-skip-on-non-executable is itself a plausible footgun worth a warning.

Keep the distinction between the top-level `hooks` object (stage name -> repo-relative script
path, this mechanism) and `provides.hooks` (an ARRAY of filenames copied into the deploy, a
Claude-Code-native settings hook, unrelated). `extensions/lean/manifest.json` has no top-level
`hooks` key -- zero lifecycle hooks -- but its `provides.hooks` is
`["lean-lsp-register-project.sh"]`, so "lean has hooks" is true in the unrelated sense and false
in this one. Do not conflate them.

## Deliberately un-sequenced overlap -- read before co-scheduling

`scripts/skill-base.sh` is also declared in the `file_scope` of the skeleton-plan follow-up work
(titled *"surface skeleton-plan follow-ups at completion under the batch engine"*), which is
`planned`. THE OVERLAP IS REGION-DISJOINT: that work edits the completion/handoff path, while
this task edits the hook resolver (line 147), the hook rc channel (lines 190-191) and the
verification call site (lines 607, 622-624).

NO DEPENDENCY EDGE IS DECLARED, DELIBERATELY. That work sits behind five dependencies of its own,
and serializing region-disjoint edits in a 900-plus-line infrastructure file behind it would cost
this task's dispatchability for no correctness benefit -- `skill-base.sh` is a broad,
widely-edited infrastructure file, which `context/patterns/file-footprint-overlap.md` and
Component 0's narrowness qualifier both treat as NOT a consolidation signal.

CONSEQUENCE THE NEXT READER MUST KNOW: `scripts/orchestrate-batch-admit.sh` scans every
non-terminal task in `specs/state.json`, so it WILL detect a `cross_batch` overlap on
`skill-base.sh` and may defer this task if it is co-scheduled with that work. Dispatch this task
alone, or alongside tasks whose `file_scope` does not include `skill-base.sh`. If both land
close together, the later one rebases; the regions do not conflict.

## Acceptance

A declared hook fires (prove it with the `nix` preflight hook, which is dead today); a non-zero
exit is observable to the caller under the disposition decided above; the `verification` stage
either has a live call site or is removed from the contract block and the stage-mapping table;
and `scripts/tests/test-skill-base-lifecycle.sh` covers the resolver against the REAL
`.claude-extensions.json` object schema rather than a fixture matching the broken query.

## Reference

No task-number references in any file written into the source store -- cite file paths, script
names and `file:line` anchors instead (`rules/no-task-references-in-deliverables.md`). Refer to
the skeleton-plan follow-up work by its title only.

---

### 326. Add a books verification tier at implement dispatch: the --gate flag mirroring --compare (the lifecycle hook route is rejected with evidence)
- **Effort**: 3-6 hours
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: Task 297
- **Research**: [326_books_verification_tier_at_implement_dispatch/reports/01_gate-flag-verification-tier.md]
- **Plan**: [326_books_verification_tier_at_implement_dispatch/plans/01_gate-flag-verification-tier.md]
- **Summary**: [326_books_verification_tier_at_implement_dispatch/summaries/01_gate-flag-verification-tier-summary.md]

**Description**: SOURCE STORE IS THE EDIT TARGET: `agent-system/extensions/core/` and `agent-system/extensions/books/` (never `.claude/**`, a disposable deploy artifact -- see `rules/source-store-deploy-boundary.md`).

## Goal

Close the verification gap at DISPATCH TIME rather than only where someone remembers to run a
lint. Add a `--gate` flag to `/orchestrate`, modelled EXACTLY on the existing advisory-only
`--compare` flag, which at implement dispatch runs the regex layer lint
(`interface/scripts/layer-lint.sh` in the consuming repository) plus a `Books.Meta`
import-closure check. ADVISORY ONLY: it never blocks, never fails a dispatch, and never
downgrades status.

This is the highest-leverage item in the books program's agent-system work, because it closes the
gap for EVERY future books task rather than for the one task whose author happens to remember the
lint.

## Motivating measurement (live, not hypothetical)

44 layer violations sat undetected across five tagging phases that ALL reported green on `lake
build`. `lake build` invokes neither the layer lint, nor the certifier, nor the Comparator rooms.
No verification tier exists today between `lake build` and the ten-minute fail-closed full gate,
so the cheap middle tier this flag provides does not exist in any form.

## MECHANISM DECISION IS ALREADY MADE, WITH EVIDENCE -- DO NOT RE-DERIVE IT

An extension lifecycle `verification` hook via `skill-base.sh` was the obvious candidate
mechanism and WAS INVESTIGATED AND REJECTED. The hook contract cannot support a gate that
influences a verification outcome. Three stacked defects, each independently fatal, all in
`agent-system/extensions/core/scripts/skill-base.sh`:

1. HOOK EXIT CODES ARE SWALLOWED BY DESIGN. Lines 190-191 are the last statement of
   `skill_run_extension_hook`, so the function ALWAYS returns 0:
       "$hook_path" "$task_number" "$task_type" "$task_dir" "$session_id" "$operation" || \
         echo "[skill-base] WARNING: Extension hook '${hook_name}' exited non-zero (non-blocking)"
   There is no return channel at all -- no variable, no global, no file. The call site inside
   `skill_validate_artifact()` at lines 622-624 does not even test the rc.
   `docs/guides/creating-extensions.md:700-702` makes the non-blocking behaviour NORMATIVE.

2. THE RESOLVER IS BROKEN AGAINST THE LIVE SCHEMA, so no lifecycle hook fires at all today.
   `skill_get_extension_dir()` at line 147 queries
   `.loaded_extensions // [] | .[] | select(.task_type == $tt) | .name`, but the live
   `.claude-extensions.json` has top-level keys `["extensions","version"]` where `.extensions` is
   an OBJECT KEYED BY EXTENSION NAME whose entries carry no `task_type` field. Verified
   empirically by sourcing the deployed library: `lean4`, `nix` and `rust` all resolve to `[]` and
   `skill_run_extension_hook verification ...` returns 0 as a silent no-op. Every other consumer
   uses the object form -- compare `scripts/measure-eager-context.sh:234`.

3. THE `verification` STAGE IS DEAD CODE. Its ONLY call site is `skill_validate_artifact()`
   (`skill-base.sh:607`), which has ZERO callers outside `skill-base.sh` itself and
   `scripts/tests/test-skill-base-lifecycle.sh`. Skills call `validate-artifact.sh` inline
   instead (for example `skills/skill-reviser/SKILL.md:309`), bypassing it entirely.
   `command-gate-out.sh` calls the DIFFERENT function `skill_validate_task_artifacts()`, which
   has no hook call. The stage is declared in the contract and documented in the stage-mapping
   table at `creating-extensions.md:713`, and invoked by nothing.

Additionally the lean implement path has no `skill-base` involvement whatsoever:
`agent-system/extensions/lean/skills/skill-lean-implementation/SKILL.md` contains zero
`skill-base` or `skill_*` references, and its verification is a pure agent self-report read at
SKILL.md:169-170 (`verification.verification_passed`), with green requiring only
`status == "implemented"` AND `verification_passed == true` (SKILL.md:248). That self-report
boolean is precisely the surface this gate must inform.

Repairing the hook mechanism is a SEPARATE task (titled *"repair the extension lifecycle hook
mechanism"*) and is deliberately NOT a dependency of this one: this task uses the live route and
needs none of those repairs.

## The `--compare` precedent -- the exact surface to mirror

`--compare` is advisory-only and lean-implementation-scoped, which is structurally what `--gate`
must be. Its complete threading surface, measured:

- `scripts/parse-command-args.sh` -- `COMPARE_FLAG`.
- `scripts/orchestrate-cycle-plan.sh` -- three sites: declaration at line 348
  (`compare_flag="false"`), parse at line 367, and forwarding at line 2771
  (`[ "$compare_flag" = "true" ] && [ "$g" = "implement" ] && build_args+=(--compare)`), which is
  what scopes it to the implement phase and keeps it from reaching research/plan dispatches.
- `scripts/orchestrate-build-dispatch.sh` -- four sites: the contract comment at lines 33-34,
  declaration at line 134, parse at line 151, and emission at lines 427-428
  (`echo "- compare_flag: true"` into the written dispatch).
- `commands/orchestrate.md:46` -- the flag table row stating advisory-only, never blocking,
  never downgrading status, composability, and that it never reaches research/plan.
- `skills/skill-orchestrate/SKILL.md` -- dispatch threading.
- `scripts/tests/test-orchestrate-build-dispatch.sh` -- flag coverage.
- `context/formats/return-metadata-file.md` -- the metadata field.

Mirror this shape exactly. Re-measure every line number before editing (they will have moved).

## Where the gate binds

Bind the advisory finding where a gate can actually act today: the implement skill's own stage
gate. `skill-lean-implementation/SKILL.md` ALREADY DEMONSTRATES THE PATTERN at its Stage 6b/6c,
where a `compliance_check == "failed"` and a non-`verified` comparator verdict downgrade `status`
to `partial`, and where a missing comparator block logs an INFO line and proceeds (SKILL.md:229).
Follow that live, invoked, already-blocking-capable pattern. Per this task's advisory-only
constraint the `--gate` finding must NOT downgrade status -- it is surfaced and recorded, and the
INFO-line-and-proceed path at SKILL.md:229 is the precedent for the absent-block case.

## Constraints

- ADVISORY ONLY. Never blocks a dispatch, never fails it, never downgrades status. Composable
  with `--hard`, `--lit`, `--compare` and the model flags. Meaningless for research/plan
  dispatches, so it must never reach them -- the line-2771 guard shape is how that is enforced.
- GATES ARE FAIL-CLOSED BY DESIGN. Nothing in this task may weaken, shortcut or quieten a gate to
  make it faster. The flag ADDS a cheap intermediate tier; it does not relax an existing one.
- Books-awareness (which lint to run, and the gate-tier knowledge of what each tier does and does
  not check) comes from the books extension's own context corpus via plain backticked path
  pointers, never eager imports.

## REDEPLOY SEQUENCING -- THIS TASK LANDS LAST IN THE BOOKS CHAIN

The consuming repository's deployed `.claude/` tree is STALE for the `core` and `formal`
extensions. Measured: the source store HEAD is `3a97e937578ffbb89b0780b5a51432885bff070b`, while
that repository's `.claude-extensions.json` records `core` at
`0e465f4f1b9dcc9b393116382f53178b8c1f2756` and `formal` at
`452d521472956008d15eff08b2005bbbeb9515c1`.

Because this task edits `core` (the orchestrate engine, the command file and the skill) and the
books extension, NOTHING in this chain takes effect in a consuming repository until that
repository regenerates its `.claude/` through the loader picker. State explicitly in the
completion summary that a `core` redeploy is required for `--gate` to exist at all, and that
enabling the books extension in a consuming repository's `.claude-extensions.json` is the user's
own action, not this task's work.

## Reference

No task-number references in any file written into the source store -- cite file paths, decision
numbers, script names and `file:line` anchors instead
(`rules/no-task-references-in-deliverables.md`). Refer to the books scaffold, context corpus and
hook-repair work by their titles and deliverables only.

---

### 325. Stop git add's gitignore advisory exit code from aborting the whole commit when the named file is tracked and was in fact staged
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None

**Description**: Stop git-commit-scoped.sh from aborting the whole commit when `git add` emits its gitignore advisory for a TRACKED file whose path matches an ignore rule: git exits 1 while correctly staging the file, and the script reads that false-negative exit as a hard failure. VERIFIED LIVE; hard blocker on every `/todo` archival run in repos where `specs/archive/` is gitignored.

== THE DEFECT ==

`agent-system/extensions/core/scripts/git-commit-scoped.sh`, the git-add guard at line ~396:

    if has_positive_pathspec "${add_pathspecs[@]}"; then
      if ! git add "${add_pathspecs[@]}"; then
        echo "WARNING: git add failed for one or more staged paths (non-blocking); no commit was attempted." >&2
        exit 2
      fi
    fi

TRIGGER: a positive pathspec naming a file that is TRACKED but whose path matches a `.gitignore`
rule via a parent-directory rule.

Concrete live case, repo `/home/benjamin/Projects/BimodalLogic`: `specs/archive/state.json` is
tracked, while `.gitignore:94` contains `specs/archive/`.

GIT'S BEHAVIOR (git 2.54.0), verified:

    $ git add specs/archive/state.json
    The following paths are ignored by one of your .gitignore files:
    specs/archive
    hint: Use -f if you really want to add them.
    $ echo $?
    1
    $ git status --short
    M  specs/archive/state.json        <-- STAGED

So git exits 1 WHILE CORRECTLY STAGING THE FILE. Verified after every invocation via
`git status --short`. Reproduces identically whether the path is passed alone or batched with
other paths. `git -c advice.addIgnoredFile=false add ...` suppresses nothing and still exits 1.

CONSEQUENCE: the script reads the advisory exit 1 as a hard failure and `exit 2`s before
`git commit` is ever reached. No commit is made at all. In BimodalLogic this blocks EVERY `/todo`
archival run, because archival always writes `specs/archive/state.json`.

OBSERVED LIVE: BimodalLogic `/todo` run on 2026-10-02. Worked around by staging manually and
committing directly; landed as BimodalLogic commit f20c2868c.

NOT DEPLOY STALENESS: the source-store copy
(`agent-system/extensions/core/scripts/git-commit-scoped.sh`) is byte-identical to the deployed
copy, and the guard at line ~396 is unchanged in the source.

NO EXISTING COVERAGE: zero tasks, active or archived, match `ignored by one of your` or
`addIgnoredFile`.

== THREE FINDINGS THAT CONSTRAIN THE FIX ==

--- 1. The script's existing `git check-ignore -q` guard pattern CANNOT catch this case ---

The script already uses a conditional `git check-ignore -q` guard for its ephemeral `:(exclude)`
injection (lines ~190-220), and the comments there already document this very git behavior:
naming an already-gitignored path in an explicit `:(exclude)...` pathspec entry makes `git add`
treat it as an EXPLICITLY-NAMED ignored path and refuse the WHOLE add. So the hazard was
understood for exclude entries and never applied to positive entries.

But reusing that same guard here DOES NOT WORK. Verified:

    $ git check-ignore -q -- specs/archive/state.json
    exit 1 ("not ignored")                      <-- check-ignore is INDEX-AWARE; file is tracked

    $ git check-ignore -v --no-index -- specs/archive/state.json
    exit 0
    .gitignore:94:specs/archive/   specs/archive/state.json

git is internally inconsistent here: `check-ignore` reports not-ignored for a tracked file, while
`git add` complains about it anyway. Any fix using plain `check-ignore` will MISS this case.
Either `--no-index` is required, or the fix belongs on the exit-code side.

--- 2. Interaction with task 304 (out_of_repo_pathspec_aborts_whole_commit) ---

SHARED: the same script, and the same all-or-nothing-batch blast mechanism. 304 targets the Case 1
predicate at line ~292 (`[ -e "$p" ] || git ls-files --error-unmatch -- "$p"`), which admits a
path `git add` will then reject. Same line of causation.

DIFFERS: 304's trigger is an out-of-repo absolute path; this defect's trigger is a
tracked-but-ignore-matched path. DIFFERENT FIX SITES -- 304: containment filter at the predicate;
this one: the exit-code check at line ~396.

THE LOAD-BEARING CONSTRAINT: in 304's case `git add` GENUINELY FAILS and stages NOTHING, whereas
here it genuinely SUCCEEDS and the exit code is a false negative. A naive "tolerate git add's exit
code" fix would therefore PAPER OVER 304's REAL FAILURE. The fix MUST distinguish
advisory-emitted-but-staging-succeeded from genuine-failure-nothing-staged -- e.g. by verifying
the intended paths actually landed in the index after the add, rather than trusting the exit code
in either direction.

RESEARCH MUST RULE ON: whether this and 304 are better fixed together at one hardened add step.
Do NOT fold this into 304 pre-emptively -- 304's narrow, carefully-bounded scope should not be
widened by default.

--- 3. Interaction with task 322 (todo_move_vacated_source_never_staged) ---

322 prescribes `stage_paths+=("$src" "$dst")` at three `/todo` directory-move sites. In a repo
where `specs/archive/` is gitignored, `$dst` IS genuinely ignore-matched. Verified:

    $ git check-ignore -q -- specs/archive/708_relay_sliced_certificate_contract_to_model_checker/
    exit 0

So IMPLEMENTING 322 AS WRITTEN would pass an ignored destination as a positive pathspec and draw
the ignore refusal on every archival run. 322 therefore needs either a destination-ignored guard
or to land together with / after this fix. 322's implementer must be warned of this.

== ADJACENT, OUT OF SCOPE ==

`hooks/guard-destructive-git.sh` blocks `git add --dry-run` with a directory pathspec, with no
`--dry-run` exemption, making safe read-only inspection of a directory pathspec impossible. A
distinct concern; noted only so it is not rediscovered. Do NOT widen this task to cover it.

---

### 324. Whitelist scheduled tasks lock in orphan detection
- **Status**: [COMPLETED]
- **Task Type**: neovim
- **Topic**: core-agent-system
- **Dependencies**: None
- **Research**: [324_whitelist_scheduled_tasks_lock_in_orphan_detection/reports/01_whitelist-scheduled-tasks-lock.md]
- **Plan**: [324_whitelist_scheduled_tasks_lock_in_orphan_detection/plans/01_whitelist-scheduled-tasks-lock.md]
- **Summary**: [324_whitelist_scheduled_tasks_lock_in_orphan_detection/summaries/01_whitelist-scheduled-tasks-lock-summary.md]

**Description**: DEFECT. verify-deploy.sh gate 13 (whole-tree orphan detection) FAILs on .claude/scheduled_tasks.lock, which is not an orphan: it is a session-acquired runtime lock file whose contents are a live session.s own sessionId, pid and acquiredAt, created at execution time by the scheduled-task mechanism and never by the copy engine.

That is exactly the class is_runtime_artifact() already whitelists -- tmp/workflow-active-*, RESUME.md, __pycache__/ and the literature venv -- but no pattern matches it, so the gate goes red. Verified 2026-10-02: the lock file was present (116 B) and is_runtime_artifact() at lua/neotex/plugins/ai/shared/extensions/verify.lua:869-884 has no matching branch.

This is half of the current verify-deploy.sh --skip-slow regression from FAIL 1 of 33 to FAIL 2 of 33. The other half (gate 3 doc-lint, core manifest desync) is filed as task 323.

IMPACT. A reproducible false-positive deploy failure that fires any time a scheduled or cron agent task has run before the gate. A gate that goes red with no real defect is the failure mode that trains the reader to stop believing it -- and it sits alongside a true positive right now, which is precisely what makes the true one easy to dismiss.

NOTE ON THE EDIT TARGET. verify.lua under lua/ is real plugin source, not a deploy artifact, so it is edited in place. The companion context file IS a deploy artifact: edit agent-system/extensions/core/context/patterns/deploy-orphan-detection.md, never .claude/context/patterns/deploy-orphan-detection.md, per rules/source-store-deploy-boundary.md.

WHAT TO CHANGE.
1. Add a scheduled_tasks.lock pattern to is_runtime_artifact() in lua/neotex/plugins/ai/shared/extensions/verify.lua, alongside the existing tmp/workflow-active-* and RESUME.md branches.
2. While there, check whether any sibling lock files exist in .claude/ that belong to the same class, and decide whether one pattern should cover them rather than enumerating each.
3. Register the new exclusion in the exclusion-classes table in agent-system/extensions/core/context/patterns/deploy-orphan-detection.md so the whitelist and its documentation stay in step.
4. Confirm gate 13 is green with a scheduled-task lock present -- not merely absent.

PRECEDENT FOR ROUTING. Task 290 (verify.lua cross-extension override precedence, completed 2026-10-02) is the same shape: Lua-implemented deploy-gate logic carrying topic=core-agent-system with task_type=neovim.

CROSS-REFERENCE. Task 250 records this failure in its own description as explicitly out of its scope, describing it as "a sandbox orphan tmp file"; today.s measurement identifies the orphan concretely as .claude/scheduled_tasks.lock. Re-confirm which it is before assuming the two notes describe the same file.

Filed by the 2026-10-02 review: specs/reviews/review-2026-10-02.md

---

### 323. Declare migrate state legacy fields in core manifest
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None
- **Research**: [323_declare_migrate_state_legacy_fields_in_core_manifest/reports/01_declare-script-in-manifest.md]
- **Plan**: [323_declare_migrate_state_legacy_fields_in_core_manifest/plans/01_declare-script-in-manifest.md]
- **Summary**: [323_declare_migrate_state_legacy_fields_in_core_manifest/summaries/01_declare-script-in-manifest-summary.md]

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**, a disposable deploy artifact), per rules/source-store-deploy-boundary.md.

DEFECT. scripts/migrate-state-legacy-fields.sh exists and is executable on disk at agent-system/extensions/core/scripts/migrate-state-legacy-fields.sh (9,914 B) but is declared nowhere in core/manifest.json provides.scripts. check-extension-docs.sh reports, verified independently 2026-10-02:

  [core]
    FAIL: script file on disk NOT in provides.scripts: scripts/migrate-state-legacy-fields.sh
    WARN: README.md older than manifest.json (possible drift)

This is half of the current verify-deploy.sh --skip-slow regression from FAIL 1 of 33 to FAIL 2 of 33 (gate 3, doc lint). The other half is the gate 13 orphan false positive filed separately.

PROVENANCE. The script shipped with task 279 phase 5 (commit 8fdfff0bf, "ship consumer-runnable migrate-state-legacy-fields.sh"); its manifest declaration was never added. Task 279 is completed and archived, so nothing else will return to this.

WHY IT MATTERS BEYOND THE RED GATE. A live deployed script that is invisible to the manifest is a script no gate can verify, no consumer deploy will carry, and no reader will find from the manifest -- the same declared-vs-deployed parity defect class the content-hash gate exists to catch.

WHAT TO CHANGE.
1. Add scripts/migrate-state-legacy-fields.sh to provides.scripts in agent-system/extensions/core/manifest.json.
2. Confirm agent-system/extensions/core/README.md names the script in its inventory and refresh if not -- this also addresses the adjacent README-older-than-manifest WARN.
3. Re-run check-extension-docs.sh and confirm [core] returns OK, then confirm verify-deploy.sh gate 3 is green.

CROSS-REFERENCE. Task 250 records this same failure in its own description as explicitly out of its scope ("neither in this task.s scope -- Re-check whether both are still live before Phase 1 treats them as noise"). This task is that re-check, resolved. 250 need not treat it as noise once this lands.

Filed by the 2026-10-02 review: specs/reviews/review-2026-10-02.md

---

### 322. Todo move vacated source never staged
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None

**Description**: Fix /todo's directory-move staging gap: a moved task directory's vacated SOURCE path is never staged, so every archival commit leaves the deletion half of each `mv` unstaged. This is a verified REGRESSION introduced by the explicit-pathspec migration, found live during an archival run.

== THE DEFECT ==

`commands/todo.md` accumulates a `stage_paths[]` array and passes it to `git-commit-scoped.sh`. At each directory-move site the array receives ONLY the move's destination. The vacated source path is never added, so nothing in the pathspec list covers it, and `git add` is never asked to record its removal. The archive copy commits as a fresh `create mode`; the old tree stays in the index pointing at files that no longer exist on disk.

THREE AFFECTED SITES in `commands/todo.md`, all dest-only:
- line 665 -- Step 5D, archive a completed/abandoned/expanded task's directory: `mv "$src" "$dst"` then `stage_paths+=("$dst")`. `$src` is dropped.
- line 686 -- Step 5E.1, move an approved orphan out of `specs/`: `mv "$orphan_dir" "specs/archive/${dir_name}"` then `stage_paths+=("specs/archive/${dir_name}")`. `$orphan_dir` is dropped.
- line 752 -- Step 5F, move a misplaced directory: `mv "$dir" "$dst"` then `stage_paths+=("$dst")`. `$dir` is dropped.

THE ASYMMETRY IS INTERNAL TO THE SAME FILE, which is what makes this a latent bug rather than a deliberate choice. The vault path in the SAME file already does it correctly and even explains why, at lines 907-912:

    # Stage the rename's exact old and new paths together so `git add` records it as a rename
    # rather than leaving the old tree's removal unstaged. [...]
    stage_paths+=(specs/archive "${vault_path}/")

and Step 5.7.7's prose at line 948 repeats the correct rule (`stage_paths+=("$old_dir" "$new_dir")`). So the file states the invariant twice and then violates it at its three ordinary move sites.

== CONFIRMED CAUSE: REGRESSION FROM THE EXPLICIT-PATHSPEC MIGRATION ==

Not inferred -- read directly out of git history. Before commit c482bf40c ("task 309 phase 3: fix remaining core command sites plus 2 extra findings"), Step 6 committed with a bare `-- specs/` directory pathspec. That single token swept up BOTH the vacated sources and the new archive paths, so the deletions were staged incidentally and the bug was invisible. Task 309 replaced the directory token with the explicit `stage_paths[]` accumulator -- correctly, for the cross-session-bleed reason that task documents -- but the accumulator was only ever taught to collect destinations. `git log -S 'stage_paths+=("$dst")'` on that file returns exactly one commit: c482bf40c.

This is the predictable blind spot of a directory-pathspec-to-explicit-list migration: a directory token silently covered two sides of every rename, and an explicit list only covers what it names. Any other call site converted by that migration which performs a rename deserves the same audit.

== MEASURED BLAST RADIUS (live, this repository) ==

A `/todo` run archiving 15 completed tasks produced:
- `todo: archive 15 completed tasks` -- 176 files changed, 19927 insertions(+), all 15 archive copies landing as `create mode`, ZERO `delete mode` entries.
- 173 files left as unstaged ` D` deletions across the 15 vacated `specs/{NNN}_{slug}/` directories.
- A follow-up remedial commit staging the 15 vacated paths recorded 173 files changed, 19270 deletions(-).

SECOND-ORDER DAMAGE, and the reason this is not merely cosmetic: Step 6.5 runs `assess-repo-health.sh` AFTER Step 6's commit and writes the result into `state.json`'s `repository_health`. With the deletions unstaged, that probe measured `phantom_paths: 109` and persisted it. After the remedial staging commit the same probe returned `phantom_paths: 0`. So the run baked a wrong health metric into committed state -- precisely the failure that Step 6.5's own "run the probe after this run's own commit" re-sequencing rationale exists to prevent. The re-sequencing is correct; it was defeated by this staging gap upstream of it.

Note the interaction with `assess-repo-health.sh`'s `phantom_paths` existence filter: that filter was added so a moved-but-still-tracked path does not inflate `build_errors`. It does its job for `build_errors` while `phantom_paths` faithfully reports the inflated count -- so the metric was accurate about a broken tree, and the tree was broken by this bug.

== WHY NO EXISTING GATE CATCHES IT ==

Verified by reading each guard, not assumed:
- `scripts/lint/lint-directory-pathspec-boundary.sh` detects a bare SHARED-directory pathspec REGROWING at a call site. This bug is the opposite shape: an explicit list that is too NARROW. A missing token is an omission, not a textual pattern, so this lint structurally cannot see it.
- `git-commit-scoped.sh`'s V2 gate classifies each positive pathspec into matched / already-staged-deletion / genuinely-unmatched. It only ever inspects pathspecs it is GIVEN; the vacated source is never passed, so V2 is never consulted about it. Same for V6's partial-drop refusal.
- V5's contention lease is likewise per-passed-path.

So the omission is invisible to every layer, and the commit exits 0 reporting success. A silent false success on the single sanctioned commit path is the same defect class task 277 closed for unresolvable pathspecs.

== FIX ==

1. At all three sites in `commands/todo.md`, stage the move's old and new path TOGETHER, mirroring the vault site's existing correct pattern and its comment:
   - Step 5D: `stage_paths+=("$src" "$dst")` (inside the `[ -n "$src" ]` branch, so an absent source is still skipped).
   - Step 5E.1: `stage_paths+=("$orphan_dir" "specs/archive/${dir_name}")`.
   - Step 5F: `stage_paths+=("$dir" "$dst")`.
   These are two exact paths per `mv`, NOT a bare shared-directory token, so the directory-pathspec lint stays satisfied by construction -- state that explicitly in a comment at each site so a future reader does not "simplify" it back to a directory token.

2. Hoist the invariant out of the vault site's local comment into `context/standards/git-staging-scope.md` as a named rule: any `mv` whose two endpoints are both inside the staged tree must contribute BOTH endpoints to the pathspec list. That standard currently documents per-operation scope and the V2/V3/V5/V6 gate semantics but says nothing about renames, which is why three sites could violate an invariant the same file states twice.

3. `skills/skill-todo/SKILL.md` has the SAME class of gap by a DIFFERENT mechanism and must be fixed too: its Stage 15 stages `git add specs/archive/ specs/TODO.md specs/state.json` (line 1076). `specs/archive/` covers the destinations, nothing covers the vacated `specs/{NNN}_*/` sources. Because the mechanism differs, this is a second distinct edit, not the same edit duplicated -- so unlike the orphan-detection defect folded into task 307, consolidating first saves nothing here.

== SCOPE BOUNDARY (audited, keeps this task small) ==

`scripts/orchestrate-cycle-postflight.sh` was checked and is CLEAN -- do not widen scope into it. Its `mv` calls are all atomic temp-rewrite-in-place (`foo.tmp && mv foo.tmp foo`, identical destination, no vacated source), and its one real move at line 483 lands inside `${TASK_DIR}`, which line 1349 already stages as the task-scoped directory token `"${TASK_DIR}/"` -- covering both endpoints. A repo-wide sweep found no other source-store site that both performs a directory `mv` and builds a commit pathspec.

== REGRESSION TEST ==

Assert that after an archival run which moves at least one directory, `git status --porcelain` reports NO unstaged ` D` entries under `specs/`, and that the resulting commit contains `delete mode` entries for the vacated paths matching the `create mode` entries for their destinations. A one-task fixture is enough; the three move sites should each get a case. Also assert the post-commit `assess-repo-health.sh` probe returns `phantom_paths: 0`, which pins the second-order damage above.

== RELATIONSHIP TO EXISTING TASKS (cross-references, deliberately NOT dependency edges) ==

- Task 307 (`todo_consolidate_and_optimize`, not_started) owns the two-phase /todo consolidation and already folds in a separate live-found /todo correctness bug (orphan/misplaced detection reading only `.completed_projects[]`). This task is kept SEPARATE because the two defects differ in urgency and in fix shape: 307's folded bug requires the operator to answer "Track all orphans" before it can corrupt anything (declined on its live run, no harm done), whereas this one fires unconditionally on every archival run with no operator involvement; and this one needs two different edits across the two copies rather than the same edit twice, so 307's "fix it once after consolidating" argument does not apply. No dependency edge is declared, matching 307's own stated preference not to overconstrain. The `file_scope_collision` admission gate will serialize the two against `commands/todo.md` and `skills/skill-todo/SKILL.md`.
- Task 302 (`scoped_commit_directory_pathspec_and_task_lease`) also edits `commands/todo.md` and `context/standards/git-staging-scope.md`, for the `--task` lease wiring and the carve-out ruling. Its HALF 1 (the directory-pathspec-to-explicit-list migration) is the change that introduced this regression. The rename rule from fix step 2 lands in the same standard 302 touches -- expect serialization there.
- Task 318 (`wire_directory_pathspec_lint_as_verify_deploy_gate`) wires the directory-pathspec lint as a gate. Record there, or here, that the lint's coverage is one-sided: it catches a too-WIDE pathspec regrowing but not a too-NARROW one omitting a rename endpoint. Whether that second check is worth automating is an open question for 318, not a requirement of this task.

---

### 319. Surface cross-task claim invalidation when a research dispatch refutes a filed premise
- **Effort**: large
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: orchestrator
- **Dependencies**: Task 285

**Description**: SOURCE STORE IS THE EDIT TARGET: `agent-system/extensions/core/` (never `.claude/**`, a disposable deploy artifact -- see `rules/source-store-deploy-boundary.md`).

## Goal

When a research dispatch machine-checks a refutation, or closes a question by supersession, the OTHER open tasks whose filed premises that result falsifies must be surfaced for human triage. Today nothing does this, so a refutation's blast radius is found only if a human happens to read the report and hand-check sibling task descriptions.

## Motivating harm (observed live, not hypothetical)

During a five-task `/orchestrate 704,705,707,708,710 --lit --fable` run in `~/Projects/BimodalLogic` on 2026-10-02, a research dispatch machine-checked a refutation: the time-sliced certificate class is incomplete for full L-plus, and already for the CTL-like fragment. The probe is `specs/710_sliced_class_incompleteness_characterization/probes/NoFiniteWidthModel.lean` -- sorry-free, axioms `propext` / `Classical.choice` / `Quot.sound`.

That single result falsified filed claims in FIVE other tasks in the same repository (706, 707, 708, 709, 712). **Nothing in the system surfaced any of them.** They were found only because a human-directed pass read the report and hand-checked sibling task descriptions.

## Concrete cost of the gap

- Task 709's headline was "establish the finite model property for the CTL-like fragment against the sliced class" -- it targeted exactly the fragment that falls, with a recorded estimate of 60-100 hours of formalization. Without the manual pass it would have been dispatched to prove a theorem already machine-checked false.
- Task 707 was a context note whose entire stated purpose is "so the fact is never rediscovered a third time". It was about to enshrine a design rule (`Z x Fin n` with finite fibres) that the same refutation had just shown necessary but NOT sufficient. A task written to stop rediscovery was itself about to record the next stale assumption.

The downstream cost is therefore not a wasted hour; it is an entire dispatched programme aimed at a false target, and a durable context note recording a premise already known to be wrong.

## Reconciliation against the open backlog (verified in the source store, 2026-10-02)

- No existing script, context file, or postflight stage in `agent-system/extensions/core/` performs any refutation or supersession sweep. Greps for `refut` / `supersed` / `invalidat` across `scripts/` and `context/` return only unrelated matches (session reaping, predispatch review, census methodology). This gap has **zero** coverage in the backlog.
- There is **no structured field** for a refuted premise anywhere in the state schema. In the BimodalLogic repo the refutations of this run were recorded as free text inside `description` (29 occurrences of `refut`), which a mechanical sweep cannot key on reliably. Deciding the trigger surface is therefore part of this task, not a given.
- `decisions_made` exists in the orchestrator handoff schema (`docs/architecture/handoff-schema.md`) and is explicitly "informational/historical (settled questions a downstream agent should not re-investigate)" -- the closest existing surface, and a live candidate trigger. Its writer, however, is the subject of open task 285, which is why 285 is declared as a dependency here: if the ruling picks the decision-record route, 285 must land first.

## Scope to settle and implement

A **postflight surfacing step**. When a research artifact records a refutation or a closed-by-supersession decision, sweep the OTHER open task descriptions for the refuted claim and emit an advisory list for human triage.

Declaration names are the strongest key; the probe above is the worked example (a sweep keyed on `NoFiniteWidthModel`, or on the refuted declaration names it establishes, would have hit 706/707/708/709/712).

Research must RULE on, not assume:

1. **What triggers detection.** Three candidates, none yet chosen: (a) an explicit metadata field the research agent sets on `.return-meta.json`; (b) a convention in the report artifact body; (c) a `decisions_made` / `.decisions.json` decision-record line (see the task 285 dependency above).
2. **Where the sweep output lands.** It must reach a human, and it must survive the dispatch that produced it.
3. **Whether it blocks or is purely advisory.** Recommendation: **advisory**.

### Honest difficulty, to be stated in the deliverable rather than papered over

Detecting "this claim is the same claim" in general is hard. The tractable version keys on **declaration names and explicit supersession markers**, not on natural-language equivalence. The task must say so and record its false-negative posture explicitly, rather than over-promising a semantic claim-matcher it cannot deliver.

## Non-goals (hard constraints)

- **SURFACING ONLY.** It must never auto-edit a task description.
- It must never change a task's status. Both of those were human calls in the observed incident and must stay human calls.
- Do not attempt natural-language claim equivalence. See the difficulty note above.

## file_scope note

The trigger-surface path is deliberately NOT declared yet -- declaring one of `context/formats/return-metadata-file.md`, `rules/artifact-formats.md`, or the `.decisions.json` writer would prejudge design question 1 above. Add the chosen one via the research phase's `proposed_file_scope` mechanism once research rules (the same deliberate omission open task 312 uses).

The postflight call site is also NOT declared. `scripts/orchestrate-cycle-postflight.sh` is the obvious integration point but is already in the declared `file_scope` of eight open tasks (184, 263, 273, 279, 284, 285, 304, 315); declaring it here would add eight serializing edges for a file this task touches by one call line. Add it at wiring time.

## Acceptance

Replaying the observed incident -- the `NoFiniteWidthModel` refutation against the task descriptions of 706, 707, 708, 709 and 712 as they stood before the manual pass -- yields an advisory list naming all five, with no task description or status mutated by the sweep.


== ADDED SCOPE (amendment): THE POSITIVE DIRECTION -- PRIOR FINDINGS REACHING THE NEXT TASK ==

The sweep above surfaces the NEGATIVE direction: a result that FALSIFIES a filed premise in
another task. Extend the same sweep to the POSITIVE direction: a finding already RECORDED in one
task's artifacts must reach the later task that would otherwise rediscover it.

MOTIVATING MEASUREMENT (live, from a completed books task in the consumer repository, not
hypothetical). One implement dispatch spent 75 of 127 minutes in a single phase rediscovering six
integration collisions between the books convention and a component's pre-existing gate. THREE OF
THOSE SIX FACTS HAD ALREADY BEEN RECORDED IN EARLIER DISPATCHES' ARTIFACTS and were rediscovered
anyway, because a finding written into `specs/NNN_*/summaries/` is invisible to the next task.
Nothing reads it, nothing indexes it, and the memory extension's `memory-retrieve.sh` preflight
injection did not surface it either.

WHY THIS BELONGS HERE RATHER THAN IN ITS OWN TASK: it is the same mechanism in the other
direction over the same narrow edit target -- the artifact walk this task already builds, plus a
matching rule. Two directions of one matcher sharing one script is exactly the shared-edit-target
signal that Component 0 of `docs/reference/standards/multi-task-creation-standard.md` names as
calling for one task. A parallel cross-task artifact walker built alongside this one is the
duplication that the backlog-reconciliation work exists to prevent.

WHAT TO DECIDE AND IMPLEMENT (a decision is required; a restatement of the problem is not an
acceptable outcome). Weigh at least: (i) a harvest trigger, (ii) coverage through the memory
extension's existing `/distill --dream` surfacing path, and (iii) a dedicated per-domain finding
ledger. Record the verdict with its evidence. NOTE A BOUNDARY: `scripts/memory-harvest.sh` is
owned by the `/todo` consolidation work (titled *"consolidate the duplicated skill-todo
implementation, then wire roadmap pruning"*) -- if the chosen mechanism requires editing that
script, that is ADDED SCOPE TO SPAWN, NOT TO ABSORB.

PRECISION REQUIRED ON THE MATCHING RULE. The negative direction can key on refutation, which is a
sharp signal. The positive direction has no equivalently sharp signal, so an over-broad matcher
would surface every prior artifact for every task and be ignored. State the precision/recall
posture explicitly and pick a matcher whose false-positive rate is defensible.

ESCAPE HATCH, EXPLICIT: if research finds the two directions together exceed one agent dispatch
(the phase-sizing bound), the positive direction is SPAWNED AS ITS OWN TASK ORDERED BEHIND THIS
ONE -- added scope to spawn, not to absorb. Do not silently drop it and do not silently absorb it
past the sizing bound.

Cite durable anchors only in anything written into the source store -- never a task number
(`rules/no-task-references-in-deliverables.md`).

---

### 318. Wire lint-directory-pathspec-boundary.sh into verify-deploy.sh as a numbered gate
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 265, Task 316

**Description**: Wire the directory-pathspec boundary lint into `verify-deploy.sh` as a numbered gate, so the rule it enforces cannot silently regress. The lint and its fixture test already exist and pass; only the gate wiring is missing, and it was deliberately deferred because the wiring target is an orchestrator-critical path.

== CURRENT STATE (verified) ==

`scripts/lint/lint-directory-pathspec-boundary.sh` exists, is registered in `agent-system/extensions/core/manifest.json`, is cross-referenced from `context/standards/git-staging-scope.md`, has a 14-case fixture test at `scripts/tests/test-lint-directory-pathspec-boundary.sh` (auto-discovered by `scripts/tests/run-all.sh`'s `test-*.sh` glob, so it needs no registration), and reports 0 violations across the whole source store.

What it lacks is a `verify-deploy.sh` gate. Its sibling `lint-scoped-commit-boundary.sh` IS wired, as gate 17. So the asymmetry is the defect: the newer rule is enforced only when someone runs the lint by hand, while the older sibling rule is enforced on every deploy.

== WHY IT WAS DEFERRED, AND WHAT THAT MEANS FOR THIS TASK ==

`scripts/verify-deploy.sh` is entry 12 on `context/reference/orchestrator-critical-paths.json` ("deploy verification gate"). The task that built the lint declared a scope note forbidding itself from touching any critical path, so it shipped the lint and recorded the wiring as a follow-up rather than widening its own scope. That was the correct call. This task exists to do the wiring under proper admission.

== THE WORK ==

Add the lint as a gate in `scripts/verify-deploy.sh`, following gate 17's existing shape for its sibling lint (same invocation convention, same `--verbose` handling, same PASS/FAIL line format, same placement relative to the other lint gates). Research must read gate 17 and match it rather than inventing a new gate idiom.

Rule on and record:

- **Gate number and placement.** The lint numbering is not arbitrary -- gates are referenced by number in operator-facing output and in docs. Determine whether this becomes a new trailing gate or is inserted next to gate 17 (its sibling), and what that does to every subsequent gate's number and to any doc that cites a gate by number. An insertion that silently renumbers gates 18-20 would invalidate existing references, including the gate-20 citations in the orchestrator context-budget work. Prefer a placement that does not renumber, or fix every citation.
- **Blocking vs. advisory tier.** Gate 17 is blocking. Confirm whether this lint should be too. It currently reports 0 violations, so wiring it as blocking is safe TODAY -- but verify that claim at implement time rather than trusting this sentence, since the source store changes underneath.

== HARD CONSTRAINT ==

Do not weaken the lint to make the gate green. If wiring reveals violations, the correct response is to fix the violating sites or to justify an allowlist entry in the lint's own allowlist layer -- never to broaden the classifier so the finding disappears.

== CLOSE BY ==

Run `bash .claude/scripts/verify-deploy.sh` and confirm the new gate appears, passes, and that the total gate count in the `[verify-deploy] PASS -- N check(s)` line increments correspondingly. Confirm `scripts/tests/test-lint-directory-pathspec-boundary.sh` still passes and that no other gate regressed.

All edits land under `agent-system/extensions/core/` per `.claude/rules/source-store-deploy-boundary.md`, never under `.claude/**`.

NOTE: `scripts/verify-deploy.sh` IS an orchestrator-critical path, so this task trips the self-modification admission gate by design. It also shares `verify-deploy.sh` with the Gate-8-parallelism task, hence the dependency edge -- do not run the two concurrently.

== BATCHING CONSTRAINT (added after a batchability review) ==

**Ordering dependency on the gate-20 trim task.** This task and the SKILL.md trim task both declare `scripts/tests/test-verify-deploy-context-budget.sh`. That is a genuine ordering dependency, not incidental file sharing: the trim task may re-derive gate 20's per-file ceiling, and this task may renumber the gates that same test refers to. A `dependencies[]` edge now records it -- do not remove it, and do not run the two concurrently.

**Shared file, distinct regions: `context/standards/git-staging-scope.md`.** Three live tasks declare this file and each owns a different region of it: the `--task` lease task owns the task-scoped pathspec carve-out ruling, the out-of-repository-pathspec task owns the exit-code table, and THIS task owns only the gate-number reference beside the existing `lint-directory-pathspec-boundary.sh` cross-reference (already present at the "complementary mechanical" bullet). No `dependencies[]` edge is declared between them, deliberately and on precedent: a live plan in this system already records the same posture for a file shared by eight tasks with no shared region, taking no edge and documenting the reasoning instead. A false serializing edge here would push this small gate-wiring task several waves later for no real conflict.

The consequence is a BATCHING rule, not a dependency: the admission gate matches `file_scope` at FILE granularity, not region granularity, so these three tasks WILL hard-defer each other if placed in the same `/orchestrate` batch. Run them in separate invocations. If a future change makes two of them genuinely contend for the same region, add the edge then.

== OBSERVATION (not a requirement of this task): THE LINT'S COVERAGE IS ONE-SIDED ==

Surfaced by the live regression now tracked as task 322, and recorded here because this task is the one wiring the lint as a gate.

`lint-directory-pathspec-boundary.sh` detects a pathspec that is too WIDE -- a bare shared-directory token regrowing at a call site. It cannot detect a pathspec that is too NARROW. Task 322's defect is exactly that second shape: `commands/todo.md`'s three directory-move sites pass an explicit list naming only each `mv`'s destination and omitting the vacated source, so the deletion half of every rename goes unstaged and the commit still exits 0. A missing pathspec token is an omission rather than a textual pattern, so the lint structurally cannot see it -- and neither can `git-commit-scoped.sh`'s V2/V6 gates, which only ever classify pathspecs they are given.

This does NOT change this task's scope, which remains the gate wiring, and it is NOT a licence to broaden the classifier (see the HARD CONSTRAINT above -- that prohibition still stands). It is recorded so that whoever wires the gate knows a green gate certifies "no over-wide pathspec", not "pathspecs are correct". Whether a complementary too-narrow check (e.g. flagging a `mv` whose source is absent from the nearby staging accumulator) is worth automating is an open question; if judged worthwhile it belongs in its own task, not bolted onto this wiring.

---

### 313. Advisory lint for hand-authored /orchestrate batch proposals in ROADMAP.md phase blocks
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 306, Task 328

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**, a disposable deploy artifact -- see rules/source-store-deploy-boundary.md). No task numbers in deliverable files outside specs/**.

GOAL. Add an ADVISORY lint that validates hand-authored /orchestrate batch proposals written into specs/ROADMAP.md phase blocks, so an under-inclusive batch is caught at authoring time instead of only at dispatch -- or never.

=== THE OBSERVED FAILURE (real, not hypothetical) ===
An agent hand-edited a ROADMAP.md phase batch and REMOVED a task from it because that task depended on another task already in the batch. That reasoning is wrong: /orchestrate performs dependency-aware wave dispatch, so an intra-batch dependency edge merely sequences the two tasks into successive waves. The two tasks also declared overlapping file_scope (three files under one component's certificate/ directory), which under the dominance rule makes batching them MANDATORY rather than optional. Nothing caught either error, because the proposed batch existed only as prose in a markdown file. The user corrected it by hand.

=== RULING ON THE SCOPE-NOTE OBJECTION (settled; do not re-litigate) ===
context/patterns/batch-orchestration-guardrails.md's scope note "Territory is a human judgment, not a machine derivation" does NOT forbid this lint. Its own first sentence draws the line: "This document's admission layers (below) derive collisions mechanically from `file_scope`; the selection criterion here is different". The note excludes machine derivation as a SELECTION input. A lint that reads a batch a human already typed and mechanically compares declared file_scope is an admission-layer act, which that same sentence sanctions.

Corroboration: docs/architecture/batch-admit-schema.md's `idle_overlap_advisory` (v5) ALREADY emits finding (a)'s fact at dispatch time -- it names a cross_batch overlapping task that is not in the batch, with `overlapping_path` and a remedy string. This lint is therefore the AUTHORING-TIME ANALOGUE of a mechanism that already ships. The gap it closes is WHEN the signal arrives, not whether the fact is derivable. Scope the novelty claim accordingly.

=== FINDINGS TO IMPLEMENT (all ADVISORY, never blocking) ===
(a) TERRITORY UNDER-INCLUSION -- the primary and only mandatory-defect finding. A non-terminal task whose declared file_scope overlaps an in-batch task but which is ABSENT from the batch. Rule 1 (shared file territory) is unconditional and does not depend on topic cohesion; this is the one case where an omitted task is a real defect.
(c) The batch exceeds MAX_TASKS=8 (commands/orchestrate.md:232; contract at docs/architecture/orchestrate-state-machine.md's "Batch Size Cap").
(d) The batch cites a task number that is terminal or does not exist in state.json.
(e) DECLARATIVE, and arguably the actual fix: when the batch block is specified in the format contract, state plainly that a batch MAY contain intra-batch dependency edges, that such edges sequence tasks into successive waves rather than disqualifying them, and that a dependent's presence or absence is the author's judgment. The failure above was an author's false BELIEF; a lint can only catch its symptom, so the declarative sentence carries real weight. This is a pointer plus one sentence -- NOT new doctrine. The guardrails document already classifies an unmet predecessor as an ORDERING CONSTRAINT in its Gate Catalogue; cite that rather than re-explaining it.

ALL findings are ADVISORY. They fail the Blocking-vs-Advisory criterion's condition 2: a prose markdown file is never dispatched, so an under-inclusive batch causes no silent concurrent write -- the real admission gate still fires at dispatch time regardless.

=== FINDING (b) WAS CONSIDERED AND DELIBERATELY REJECTED -- DO NOT RE-PROPOSE ===
A proposed finding (b) would have reported "a non-terminal dependent of an in-batch prerequisite that is absent from the batch" as rule-3 under-inclusion. It is dropped ENTIRELY, including its weaker informational variant, for two reasons:
1. It overstates the guardrails document on that document's own terms. In its worked example the dependent C joins as a topic-cohesive OPTIONAL add whose edge means it "cannot dispatch usefully apart from the same invocation" -- a width/fill preference under rule 3, not an unconditional mandate like rule 1's territory requirement. As a defect finding it would assert a rule that does not exist.
2. Even as information it would fire on nearly every batch, given a dense dependency graph and a cap of 8, and it would push batches to grow transitively against that cap. Noise on a never-actionable signal is precisely what trains operators to ignore advisories, degrading finding (a), which IS actionable.
The aim is to ALLOW intra-batch dependency edges where they make sense -- never to mandate pulling dependents in. A dependency edge must simply never be grounds for EXCLUDING a task from a batch. Finding (e) carries that positive half declaratively.

=== HARD CONSTRAINT: THIS IS A VALIDATOR, NEVER A PROPOSER ===
The lint validates a batch a human already wrote. It must NEVER author, suggest, or rank a batch. Machine-derived batch SELECTION is the territory of the next-admissible-batch suggestion task (topic orchestrator), which is gated behind several prerequisites precisely because it is the harder, riskier mechanism. Copy that task's binding constraint as precedent: a second copy of an admission predicate drifts from the real one, and a suggestion the real script then refuses is worse than no suggestion at all.

=== REUSE, DO NOT REBUILD ===
- SPLICE $FILE_SCOPE_OVERLAP_JQ_DEFS from scripts/lib/file-scope-overlap.sh (the `norm` / `scopes_overlap_first` / `edge_connected_nums` defs). NEVER fork, restate, or re-derive the overlap algorithm. Note that scopes_overlap_first is deliberately glob-free and symmetric; do not "improve" it locally.
- ADD this lint to the Consumers list in context/patterns/file-footprint-overlap.md, which names that algorithm's callers. That list currently says three active callers; this becomes a new one.
- REUSE generate-task-order.sh's compute_waves (Kahn's algorithm) for any wave reasoning. Do NOT modify generate-task-order.sh -- it is in another task's file_scope, and consuming rather than modifying is what keeps this task free of a dependency on it.
- RESPECT the truncation precedence rule in the guardrails document: a cap-driven trim to 8 can never split a territory-mandatory group off the end. Finding (c) must not recommend a trim that violates this.

=== OPEN RESEARCH QUESTION: WHICH SEAM ===
Research must settle the call site. Note first that verify-deploy.sh, through which all ten existing scripts/lint/*.sh are wired, is the WRONG seam here: it validates the source store and deploy, whereas this lint reads a CONSUMER repo's specs/ROADMAP.md against that repo's specs/state.json. The precedent does not transfer, which is why a roadmap-touching command is the only seam.
  SEAM A: a new mode on scripts/roadmap-integration.sh, which the /review rewiring already invokes. This may need no commands/review.md edit at all, dissolving the territory overlap noted below -- but it enters the roadmap-generation task's territory.
  SEAM B: a standalone scripts/lint/lint-roadmap-batch-proposals.sh called explicitly from commands/review.md, following the naming and test/manifest-registration precedent of the ten existing lint scripts.
LEAN: seam B for the script itself, with the call site decided in research. If seam A wins, narrow file_scope accordingly and say so.

=== EMPIRICAL FINDING THE ROADMAP-GENERATION TASK NEEDS ===
The batch-block convention is DIVERGENT ACROSS REPOSITORIES, so a lint written to one shape silently no-ops on the other:
  - The consumer repo uses a literal `**Run**:` marker followed by a fenced block containing `/orchestrate 120,121,...`.
  - The global agent-system repo uses NO such marker: it uses a `## Call N -- <description>` header followed by a bare fenced block that may contain SEVERAL `/orchestrate ...` lines, i.e. several distinct batches under one header.
This matters beyond this task: the roadmap-generation task's own description asserts that the live file uses a `**Run**` line, which is true only in the consumer repo. That task should reconcile the two shapes into one specified grammar before this lint can parse anything. This is FLAGGED HERE DELIBERATELY rather than by silently editing that task's description. Confirm the divergence still holds at research time; the two files drift.

=== DEPENDENCIES ===
- On the roadmap-generation task (hard, substantive): there is no parseable grammar to lint until the batch block is specified as a structure element in context/formats/roadmap-format.md, which today specifies only phase headers, checkboxes, status tables, priority markers and completion annotations -- it is 65 lines with zero occurrences of "Run". That task already owns both roadmap-format.md and roadmap-integration.sh and already has the batch-block spec in its scope, so DO NOT duplicate that work here; consume it.
- On the /review rewiring task (hard, footprint-corroborated): it rewrites the /review Step 2.5 call site this lint would hook. Landing this first would simply be overwritten. The edge is deliberately kept EXPLICIT alongside the roadmap-generation edge even though the latter is transitively implied through it, per the standing documented-redundant-edge convention: the two edges record different facts (grammar availability vs. call-site ordering) and a redundant edge costs only a wave.
- NOT a dependency, but note the absent-file_scope admission-posture task: it rules whether an absent file_scope is admission-relevant. For this lint an absent file_scope simply means "no evidence of overlap", so finding (a) cannot fire on it. Adopt the softer posture and RECORD in the script header which absent-scope posture was assumed, so the ruling can be reconciled later. Do not hold this task on it.

=== CROSS-REPO TERRITORY CONSTRAINT (not expressible as an edge) ===
A consumer repository has its own in-flight task that ALSO edits the /review command, to add a Book health section. That is a different repository's task number, so it CANNOT be expressed as a dependencies[] edge on this task. Whoever implements this MUST check for concurrent /review-command work in consumer repos before editing commands/review.md. Choosing seam A would avoid this hazard entirely.

=== ACCEPTANCE ===
- A fixture ROADMAP batch that omits a task whose file_scope overlaps an in-batch task produces finding (a); the real failure case above is reproduced as that fixture and the lint flags it.
- A fixture in which the only omitted task is a DEPENDENT with no territory overlap produces NO finding, demonstrating (b) is genuinely absent.
- Findings (c) and (d) each have a fixture.
- No copy of the overlap predicate exists anywhere in the new code: the lint splices scripts/lib/file-scope-overlap.sh.
- context/patterns/file-footprint-overlap.md's Consumers list names this lint.
- Every finding is advisory: the lint's exit code is unaffected by findings, and this is stated in its header.
- Registered in manifest.json with a scripts/tests/test-*.sh companion, matching the existing lint-script convention.
- shellcheck clean per context/standards/shell-strict-mode.md.

---

### 312. Backlog reconciliation as a required task-creation component: compare every proposed task against the open backlog before it is written
- **Effort**: large
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: orchestrator
- **Dependencies**: Task 165, Task 300, Task 282

**Description**: SOURCE STORE IS THE EDIT TARGET: `agent-system/extensions/core/` (never `.claude/**`, a disposable deploy artifact -- see `rules/source-store-deploy-boundary.md`).

## Goal

No task may be created without first being compared against the open backlog, so that a genuinely new task is created, an existing task is revised or widened, a dependency edge is added, or a `file_scope` is narrowed -- whichever the comparison warrants. Today no creation surface does this, and the standard does not require it.

## The motivating incident (live, this session, not hypothetical)

Three tasks (309, 310, 311) were created from a research report without any comparison against the open backlog. Outcome on inspection:
- Task 310 was a near-total duplicate of open task 272, whose goal statement is almost verbatim identical and which is better scoped (it additionally carries `task-lock.md`, `orchestrator-runtime-files.md`, `test-session-registry.sh`, `test-conflict-predicate.sh` and a heartbeat-never-fires diagnosis). 310 was abandoned and its two unique items folded into 272.
- Task 309 was a strict subset of open task 302's `file_scope` and named the same three line numbers. Resolved by narrowing 302 to drop those three paths and ordering 302 behind 309.
- Task 311 was genuinely new (no open task mentions `BUILD_HEAVY` or build weight) -- so the mechanism must be able to return "genuinely new", not merely flag suspicion.

Only 311 of the three survived creation unchanged. That is the failure rate this task exists to eliminate.

## The precise gap

`docs/reference/standards/multi-task-creation-standard.md` already has Component 4a, "File Footprint Capture and Overlap Detection (Automatic)". Its step 2 reads: apply the overlap check "to every unordered pair of proposed tasks **in the current batch**". The scan scope is the creation batch only. Nothing compares a proposed task against the non-terminal tasks already in `specs/state.json`.

This is corroborated by the predicate's own doc: `context/patterns/file-footprint-overlap.md` describes an "O(n^2) pairwise scan over the items in a single batch (task-creation batch...)" and its Non-Goals section states it holds "No opinion on scan scope... each caller chooses its own scan scope, and this document is not extended" for it. So the PREDICATE is sound and reusable; the missing thing is a caller that applies it against the backlog. Do not rework the predicate.

A second, independent gap: **file overlap alone is insufficient.** Tasks 310 and 272 shared exactly ONE path (`scripts/task-lock.sh`) yet were near-total duplicates in intent. A purely mechanical footprint pass would have added a serializing dependency edge and declared success, never surfacing the duplication. So the mechanism needs two passes, and the second cannot be a footprint comparison.

A third gap, from the standard's own Current Compliance Status table: `/review` and `/errors` do not perform even the existing in-batch Component 4a check ("No" in the Footprint Overlap column). Any new requirement must account for surfaces that do not yet satisfy the old one.

## Required outcomes

1. A new REQUIRED component in `multi-task-creation-standard.md` (sequenced after the existing 4a, before Component 7's user confirmation) specifying backlog reconciliation: its inputs, its two passes, its verdict vocabulary, and its non-silence obligation. Update the Current Compliance Status table to carry the new component as a column, honestly marking each surface's state.
2. A single shared implementation, `scripts/audit-open-tasks.sh`, that every creation surface calls rather than each re-implementing. It must take proposed task(s) and return, per proposal, a structured verdict drawn from a fixed vocabulary -- at minimum: genuinely new; duplicate-of-N; subset-of-N; superset-of-N; overlaps-N-add-edge; narrow-N. It must reuse the existing overlap predicate for the mechanical pass rather than forking it.
3. The semantic/intent pass, which must catch the 310-vs-272 class (near-identical goal, almost no shared paths). Title/description/topic similarity is the obvious approach; the task must rule on the method and state its false-negative posture explicitly.
4. Enforcement, so this cannot be skipped by a surface that forgets to call it. `hooks/validate-task-creation-audit.sh` is declared in `file_scope` as the candidate site.

## The central design question -- research must RULE on this, not assume it

Two enforcement designs, with the trade-off already measured:

(a) **One hook at the state-write boundary.** A new task appearing in `state.json` without a recorded audit is refused. Uniform across every creation surface -- present and future -- and the user has explicitly stated that uniformity and avoiding needless complexity are the governing values here. COST: registering the hook requires `agent-system/extensions/core/manifest.json` and `agent-system/extensions/core/root-files/settings.json`, which are owned by open tasks 263, 280, 281, 282 and 307 -- five serializing dependency edges.

(b) **Per-surface wiring.** Each creation surface calls the shared script: `agents/meta-builder-agent.md`, `commands/task.md`, `skills/skill-fix-it/SKILL.md`, `skills/skill-spawn/SKILL.md`, `commands/review.md`, `commands/errors.md`. COST: six wirings that a seventh future surface can silently omit, and serializing edges against open tasks 44, 300, 302, 308 and 309 -- with 44 itself transitively blocked behind 87/149/210.

Both cost roughly five edges, so edge count does not decide it; uniformity versus blocking depth does. **Neither option's registration or wiring paths are declared in this task's `file_scope` yet, deliberately** -- that would prejudge the ruling. Once research rules, add the chosen option's paths to `file_scope` at that point (via the research phase's `proposed_file_scope` mechanism) and accept the serializing edges then.

## Why the three declared dependencies are functional, not merely serializing

- **#300** (AskUserQuestion unreachability in dispatched subagents): the audit's verdicts need a human ruling, and `/meta`'s creator is a dispatched subagent where that gate is unreachable. 300 resolves exactly this. Without it, a reconciliation that must ask "is this a duplicate of 272?" has nowhere to ask from.
- **#165** (posture for an absent `file_scope`): a backlog comparison keyed on `file_scope` is blind to any task that declares none. 165 settles whether an absent `file_scope` is admission-relevant, which determines whether the mechanical pass can be trusted or must degrade loudly.
- **#282** (write-time PreToolUse hook registered bare so `exit 2` survives): establishes the registration pattern a blocking hook needs. Load-bearing only if design (a) is chosen, but the hook file is in this task's declared scope.

## Explicit non-goals

- Do NOT rework the overlap predicate in `file-footprint-overlap.md`. It is sound and deliberately scope-agnostic.
- Do NOT rework the admission-time layers (the three/five-input model in `batch-orchestration-guardrails.md`). This task is about CREATION time; admission time already works and is a different scan scope.
- Do NOT auto-abandon, auto-merge or auto-rewrite any existing task. Every reconciliation verdict beyond adding a dependency edge is surfaced for a human ruling. Silent mutation of a task a human wrote is a worse failure than the duplication this fixes.

## Acceptance

A task-creation attempt that duplicates, subsumes or is subsumed by an open task cannot complete without the verdict being surfaced; the 309/310/311 incident above is reproducible as a regression fixture and yields the three correct verdicts (309 subset-of-302, 310 duplicate-of-272, 311 genuinely-new).

---

### 311. Replace static build-heavy family membership with a measured co-scheduling signal, and record the isolation-posture findings
- **Effort**: medium
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: orchestrator
- **Dependencies**: None

**Description**: Two folded parts sharing one document. PART 1 -- MEASURED BUILD WEIGHT: BUILD_HEAVY_TASK_TYPES=("lean4" "cslib") at orchestrate-cycle-plan.sh line 1819 is a static task-type family list, so any two lean4 implement candidates are categorically refused co-scheduling regardless of real build weight -- a Mathlib-free lean4 package measured at 6 s wall / 17 jobs from an empty .lake/ is blocked exactly as a full Mathlib build is. This is the binding constraint on real parallelism for Lean-heavy batches, which is the primary intended application of concurrent batching here. Replace family membership with a measured or probed signal (recorded prior job count / wall-clock duration per task, or a cheap dry-run probe) and explicitly design the fallback behavior for a task with no measurement history yet. PART 2 -- ISOLATION POSTURE RECORD (folded in per the research report's own Context Extension Recommendation): append to batch-orchestration-guardrails.md's "Working-Tree and Build Isolation Posture" section (i) the two new hazard classes -- repo-scanning pollution from in-tree worktree provisioning, and mode 2's guard-bypass-via-bare-invocation recurrence, evidenced by a plan-sanctioned certify.sh bypassing lake-build-guard.sh via a bare `lake` call -- and (ii) the CoW/reflink/overlayfs/clone-nothing evaluation including the ext4 no-reflink blocker, cross-referencing specs/decisions/worktree-isolation-removal-reaffirmation.md so any future re-opening of the worktree question starts from a complete evidence base. WHY ONE TASK: that single doc carries both the build-heavy co-scheduling rule and the isolation posture in adjacent sections, and the build-weight change must edit it anyway; territory.md also carries build-heavy references. All edits land under agent-system/extensions/core/ per .claude/rules/source-store-deploy-boundary.md, never under .claude/**. Evidence base: specs/301_reopen_worktree_isolation_verdict/reports/02_worktree-isolation-reopened.md and specs/decisions/worktree-isolation-removal-reaffirmation.md. NON-GOALS: do NOT restore per-dispatch git worktree isolation (that verdict was re-opened, re-argued and CONFIRMED -- see the decision record); do NOT attempt a Lake/Mathlib shared-cache feasibility spike (named as a possible future spike, not requested). SELF-MODIFICATION: this task IS self-modifying (scripts/orchestrate-cycle-plan.sh is an orchestrator-critical path); expect the admission gate to defer it and re-invoke /orchestrate rather than passing --allow-self-modifying.

---

### 306. Make ROADMAP.md a generated artifact: extend the format into a generation contract and add regenerate and prune modes
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None

**Description**: Turn specs/ROADMAP.md into a generated artifact with a standardized format, so its phase/batch structure is derived mechanically from state.json dependencies instead of being hand-maintained.

MOTIVATION (verified): specs/TODO.md's generated "Dependency Waves" table already contains exactly the same waves that a hand rewrite of ROADMAP.md derived by hand -- identical task sets, identical "Blocked by" and "Topics" columns. The roadmap was re-deriving by hand a table the system already computes. Hand-maintained roadmap prose also goes stale silently: the file carried a claim that the `hold` status was unsupported and would break generate-todo.sh and validate-state.sh, which had been false since the HOLD marker landed (validate-state.sh knows hold_reason, held_at and prior_status).

SCOPE:
1. Extend context/formats/roadmap-format.md from a 65-line parse spec into a generation contract. It currently specifies only phase headers, checkboxes, status tables and the completion annotation; it does NOT specify the **Status**, **Milestones**, **Blocked by**, **Topics** or **Run** lines the live file actually uses. The contract must cover these; must keep the per-phase structure with copy-pasteable /orchestrate Run blocks and task batches; and must drop the lengthy header, introduction and narrative description, which duplicate README.md and do not serve the user.
2. Add two modes to scripts/roadmap-integration.sh, which today has only parse-only and --annotate: a regenerate mode that rebuilds the phase/batch structure wholly from the wave data, and a prune mode that removes completed tasks and drops a whole batch or phase once every task in it is complete.
3. Specify which content is authored and which is generated. ONLY the short per-phase/per-batch description of what the phase accomplishes is authored; everything else is derived.

REUSE, DO NOT REBUILD. This is a wiring job, not a generator-building job:
- Wave derivation already exists: compute_waves (scripts/generate-task-order.sh line 393, Kahn's algorithm) and generate_wave_table (line 708), which already emit "Wave | Tasks | Blocked by | Topics". `generate-task-order.sh --print` emits that table read-only and was verified working. roadmap-integration.sh must CONSUME that output. Do NOT write a new wave or DAG implementation, and do NOT modify generate-task-order.sh: that file is in task 271's file_scope, and consuming rather than modifying is precisely what keeps this task free of any dependency on 271.
- Preserving authored prose across regeneration already exists: read_existing_goal (generate-task-order.sh line 905) reads the existing **Goal** line out of TODO.md and retains it unless overridden. Copy that mechanism for the authored per-phase descriptions.
- orchestrate-cycle-plan.sh and orchestrate-batch-admit.sh also compute eligibility and in-batch ordering from the same dependencies[] data. Check any new logic against them for duplication before writing it.

Research must settle the remaining details and is explicitly directed to AVOID NEEDLESS COMPLEXITY: prefer reusing and extending what exists over introducing new machinery. Open questions include where held and user-only tasks live in a generated structure (the hand-written roadmap had a Phase 0 of user-only owner decisions and a wholly-held phase, neither of which appears in the wave table), and whether the cut lines and risk table survive at all.

RESPONSIBILITY SPLIT, implemented by the two dependent tasks: /todo prunes; /review regenerates completely, including regenerating each phase's and batch's brief description of what it accomplishes.

---

### 304. Stop one out-of-repository pathspec entry from aborting staging for every valid path, and stop the callers sinking the script's nonzero exits, while the task still reports success
- **Effort**: 1-3 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: orchestrator
- **Dependencies**: Task 184, Task 263, Task 273, Task 277, Task 279, Task 284, Task 285, Task 302

**Description**: Make an out-of-repository path in a commit pathspec list non-fatal for the rest of the list, so one bad entry cannot abort staging for every valid path while the task still reports success. A narrow fix with a mechanically located cause; research rules on WHERE the fix belongs and on one genuinely open design question, it does not re-litigate whether the defect is real.

== PREMISE CORRECTION (verify before accepting any framing that says otherwise) ==

This task was filed on the hypothesis that `.return-meta.json`'s `modified_files` field "has no stated contract confining its entries to repository-relative paths." **That hypothesis is FALSE and must not be carried into the research.** `context/formats/return-metadata-file.md` already states the constraint emphatically and three times over:

- "**Path form**: entries are **repo-relative** paths, relative to the repository root. This is load-bearing and must not be left implied ... Absolute paths are not permitted."
- The producer-side procedure's step 1: "append that file's **repo-relative** path".
- The procedure's restated "Field constraints" block: "**Repo-relative**, never absolute."

The source-store copy and the deployed copy are byte-identical, so this is not deploy staleness. **Documenting the contract is therefore ALREADY DONE — do not re-do it.** The defect is not underspecification. It is that nothing anywhere ENFORCES the documented contract, and the consumer's failure mode on violation is maximally destructive.

== THE SIBLING-FIELD COMPARISON (narrowing evidence, with its inference corrected) ==

In the SAME dispatch, `.orchestrator-handoff.json`'s `artifacts[]` carried **only repo-relative paths** -- verified, two entries, both `specs/154_.../...`. Meanwhile all four absolute paths were confined to `modified_files`, and they appear nowhere else that is consumed as a pathspec. So the incident is narrow and field-specific, NOT general path carelessness by the agent: it put repo-relative paths in one field and absolute paths in another.

**This exonerates the producing agent and rules out a plausible wrong diagnosis.** Do not read the incident as an agent that was sloppy about paths and needs tighter instructions.

**But the natural inference from it is BACKWARDS, and the research must not repeat it.** The tempting reading is "the sibling schema'd field already has the correct repo-relative contract, so constraining `modified_files` is merely alignment with existing precedent." Verified against the schema, that is false:

- `context/schemas/orchestrator-handoff-schema.json`'s `artifacts[].path` is documented as "**Repo-relative or absolute** path to the artifact." It **permits** absolute. It is schema'd but LOOSE.
- `modified_files` has **no schema at all** (confirmed: nothing under `context/schemas/` covers `.return-meta.json`), but its prose contract is the STRICTEST path statement in the system -- "Absolute paths are not permitted."

So the asymmetry runs the opposite way from the framing above: the field that broke is the one with the STRICTER stated contract and NO schema and NO enforcement; the field that behaved is the one with the LOOSER stated contract, a schema, and no pathspec consumer to punish looseness. `artifacts[]` got repo-relative paths by practice (artifact paths are naturally built from the task directory), not because any contract demanded it.

**Consequence for the design, and this is the load-bearing conclusion:** there is NO in-system precedent of a path field being successfully constrained by documentation. The strictest prose contract in the system was violated anyway, by an agent that was never shown it. **That is a direct argument that candidate 1 is insufficient on its own** -- stronger than the generic version, because the counter-example is this very field. Enforcement (candidate 2, or a schema with validation) is required. If research wants to cite `artifacts[]` as precedent for anything, the honest citation is: a loose contract on a field with no pathspec consumer is harmless, which is why nobody noticed the asymmetry.

== THE DEFECT (precisely located) ==

`scripts/git-commit-scoped.sh:292`, the drop-pass predicate:

    if [ -e "$p" ] || git ls-files --error-unmatch -- "$p" >/dev/null 2>&1; then
      # Case 1 -- matched: present on disk, or already tracked.
      filtered_pathspecs+=("$p")
      add_pathspecs+=("$p")

`[ -e "$p" ]` is a bare filesystem existence test with **no repository-containment check**. An absolute path into a DIFFERENT repository exists on disk, so Case 1 matches it, and the path is admitted to `add_pathspecs`. The existing Case 3 drop (line 311) never sees it, because Case 1 already claimed it.

Staging is then a **single all-or-nothing invocation**, line 372:

    if ! git add "${add_pathspecs[@]}"; then
      echo "WARNING: git add failed for one or more staged paths (non-blocking); no commit was attempted." >&2

`git add` treats an out-of-repository path as **fatal**, not droppable, so that one entry aborts staging for every other entry in the same call. And the failure is deliberately **non-blocking**, so the caller proceeds and the task still transitions to `completed`.

**The authors already reasoned about this exact hazard class -- for a different case.** The Case 2 comment at lines 302-307 says, verbatim, that because `git add "${add_pathspecs[@]}"` "is a single all-or-nothing invocation, that one bad entry would abort staging for every other path in the same call -- silently converting today's 'deletion dropped' bug into a louder 'whole commit aborted' bug". They applied that reasoning to already-staged deletions and built Case 2 to avoid it. Out-of-repo absolute paths are the same hazard with no corresponding guard. **This is the strongest argument that the fix belongs in the drop pass: the drop pass already exists, already has the right instinct, and merely fails to classify this one input.**

== OBSERVED DAMAGE (verified, today) ==

During a live `/orchestrate 119,122,129,151,154,159` run in `~/Projects/Logos/Verification` (session `sess_1790826682_ca5834`), task 154's implement dispatch reported **30 entries** in `modified_files`. The first 26 were correct repo-relative paths. The last 4 were absolute paths into the agent-system source store at `/home/benjamin/.config/nvim/` -- a new lean-extension context page and its three registration sites, which the dispatch had legitimately edited and included for traceability.

    fatal: /home/benjamin/.config/nvim/agent-system/extensions/lean/context/project/lean4/domain/metadata-trust-surfaces.md: '...' is outside repository at '/home/benjamin/Projects/Logos/Verification'
    WARNING: git add failed for one or more staged paths (non-blocking); no commit was attempted.
    [orchestrate] WARNING: commit failed for task 154 (non-blocking) -- proceeding to lock release.

Task 154 then transitioned to `completed`. **No commit was attempted for ANY of the 26 valid paths.** Nothing was ultimately lost only because that dispatch happened to have committed its own source incrementally across ten commits, so the residue was just the plan marker and `.return-meta.json`, recovered by hand afterwards. **A dispatch that relied on the postflight commit instead would have reached `completed` with its work entirely uncommitted.** That is the severity argument: a false green over silent non-persistence, triggered by one entry out of thirty.

== SECOND VERIFIED FINDING: THE CONTRACT IS NOT PROPAGATED TO THE PRODUCERS (THIS IS THE ROOT CAUSE) ==

Of the 13 implementation agents under `agent-system/extensions/*/agents/`, only **4** mention `modified_files` at all (`general-implementation-agent.md`, and email/nix/nvim); all 4 of those do state the repo-relative constraint. The other **9 never mention the field** -- including `agent-system/extensions/lean/agents/lean-implementation-agent.md`, the exact agent that produced the 30-entry list above. They emit the field with no instruction about it, inheriting the contract only if they happen to load the format spec. There is also **no JSON schema** for `.return-meta.json` anywhere under `context/schemas/`, so no mechanical validation of the field exists at any point.

**This is the ROOT CAUSE of the observed incident, and it explains it completely.** The constraint existed; the agent that produced the offending 30-entry list was never told it. Nothing further is needed to account for the defect.

**Propagation to those 9 agents is OUT OF SCOPE here and should be a follow-up task** -- it is a 9-file producer-side surface, and excluding it is a scope judgment, NOT an overlap dodge (those 9 files carry no competing declarations found in this survey). **That follow-up is NOT a nice-to-have: it is the root-cause remediation, and this task is the containment.** Whoever triages it should treat it with the severity that implies, not as documentation tidying. Recorded here so it is filed against evidence rather than rediscovered.

It also reinforces why the consumer-side fix is needed REGARDLESS of propagation: until every producer is told the rule, the field will keep carrying violations, so the consumer must be robust to them.

**The producing agent's behaviour was reasonable against what it was actually given -- not against the contract.** State the distinction precisely, because the looser version invites the wrong fix: the agent DID violate a documented constraint, so this is not a case of defensible divergence from a rule it had seen. It is a case of an agent reasonably recording every file it touched, across both repositories, under a field name that suggests exactly that, having never been shown the rule its own definition omits. Do not frame any part of this as an agent error to be trained away, and do not frame it as the contract being wrong either.

== THE CENTRAL QUESTION: SILENT FILTERING VS LOUD REFUSAL ==

Filtering `modified_files` to entries under the repository root BEFORE staging would have let the observed commit succeed for its 26 valid entries instead of aborting all 30. **Candidate 2 is therefore demonstrably sufficient to close the observed incident** -- this is established, not open. What remains open, and is this task's central decision, is the behavior on a filtered entry:

- **Silent filtering** recovers the valid work but HIDES that an agent produced an out-of-contract entry. The contract violation goes unrecorded and the 9 unpropagated agents keep emitting them undetected.
- **Loud refusal** surfaces the violation but MUST NOT preserve the current behavior of reporting success while staging nothing. A refusal that leaves the task at `completed` with nothing committed is strictly worse than silent filtering.

**The status quo is the worst of both options: it neither commits the valid work nor reports failure.** Any ruling must beat that bar on both axes. The likely shape is filter-and-commit paired with a loud, non-suppressible report plus a non-terminal status or an explicit operator-visible record -- but research rules on it, and must say which axis it is trading if it does not get both.

== CANDIDATE SURFACES (research RULES between these; do not presuppose) ==

1. **`git-commit-scoped.sh`'s drop pass (recommended starting hypothesis).** Add a repository-containment classification ahead of Case 1, so an out-of-repo path is dropped with a loud WARN like any other unusable pathspec instead of poisoning the single `git add`. Closes the failure at the one chokepoint every commit site shares, and is robust to any misbehaving producer. Weigh `git rev-parse --show-toplevel` comparison against `git ls-files`-based containment, and handle symlinked and `..`-containing paths.
2. **The postflight consumer** (`orchestrate-cycle-postflight.sh:1252`, and `orchestrator-postflight.sh`, which also reads the field). Filter or partition `modified_files` before it reaches the commit script. Narrower blast radius but must be duplicated at each consumer, and leaves other commit sites exposed.
3. **A separate field for cross-repository edits.** The underlying need is REAL and currently unserved: a dispatch that legitimately edits the agent-system source store has nowhere to record it, and today those edits are simply left uncommitted for an operator to stumble on. Note the dispatch in question **correctly declined to commit them itself**, because that repo had concurrent in-flight work. Rule on whether to add such a field (and who consumes it) or to state explicitly in the format spec that cross-repo edits are out of `modified_files`'s remit and must be reported in prose.

**A design that does only the documentation half must be challenged** -- the contract is already documented (see PREMISE CORRECTION) and documentation alone demonstrably did not prevent this. At least one of (1) or (2) must land.

**Also rule on the non-blocking policy.** A commit that stages nothing, reports a WARNING, and lets the task reach `completed` is the "false green" direction of wrong. Research should decide whether a staging failure that results in ZERO files committed deserves to be blocking (or at minimum to force a non-terminal status), and must RECORD its reasoning rather than flip the policy silently. Changing the global non-blocking policy is a larger decision owned by other work on these files -- recommend rather than unilaterally impose, and if the ruling is "report only", say so explicitly.

== DISTINCTNESS FROM ALREADY-FILED TASKS (verified by reading their file_scope and titles) ==

- **Task 277** (`not_started`) -- "Make an unresolvable pathspec a hard error in git-commit-scoped.sh instead of a silent WARN-and-drop". **Closely adjacent, and the relationship is tighter than first assumed:** 277 changes the behavior of Case 3, the very drop pass this task must extend with a new classification. Not duplicate -- 277 is about an UNMATCHED path currently being dropped too quietly, this task is about an OUT-OF-REPO path not being dropped at all and killing the whole `git add`. But they edit the same block, and the orders interact: if 277 lands first and makes every drop a hard error, this task must decide whether an out-of-repo path is a hard error too (defensible) or the one case that stays a warn-and-drop (also defensible, since the operator may legitimately have cross-repo paths). **This dependency edge is load-bearing, not merely a serialization formality.**
- **Task 302** (`not_started`) -- bare `-- specs/` directory pathspec over-staging concurrent sessions' files. Different mechanism (over-broad pathspec vs. out-of-repo pathspec), different call sites (command/skill definitions vs. the commit script itself).
- **Task 303** (`not_started`) -- `validate-state.sh`'s CWD-relative state-file default. Unrelated beyond both being path-resolution bugs.

All three are distinct failures of the same subsystem. **Do not merge them.**

== DECLARED FILE_SCOPE OVERLAPS (declared honestly; nothing trimmed to dodge the check) ==

This task's `file_scope` collides with seven live tasks, enumerated so no reader has to re-derive them:

- `scripts/git-commit-scoped.sh` + `scripts/tests/test-git-commit-scoped.sh` -> **277** (load-bearing, see above).
- `context/formats/return-metadata-file.md` -> **263** (consent-gated git push).
- `scripts/orchestrate-cycle-postflight.sh` -> **184, 263, 273, 279, 284, 285**.
- `scripts/tests/test-orchestrate-cycle-postflight.sh` -> **184, 263, 273**.

Only the **277** edge is semantically load-bearing. The other six are pure serialization edges under `context/patterns/file-footprint-overlap.md` -- the regions do not touch, so any order merges cleanly. **An operator who wants this fix sooner should REORDER these edges, not drop a path from `file_scope`.** Both postflight scripts are retained in scope because candidate surface (2) cannot be evaluated without them; if research rules for surface (1) alone, the postflight entries simply go unused and that is the correct outcome, not a mis-declaration.

Six live tasks contending on `scripts/orchestrate-cycle-postflight.sh` is itself a signal worth an operator's attention.

== EXPLICITLY OUT OF SCOPE ==

- Re-documenting the repo-relative constraint in `return-metadata-file.md`. Already present, three times. (Correcting that section's reference to `orchestrator-postflight.sh` so it also names `orchestrate-cycle-postflight.sh`, the batch-engine consumer, IS in scope -- it is a one-line accuracy fix in a section this task already touches.)
- Propagating the constraint to the 9 silent implementation agents. Verified above; follow-up task.
- Adding a JSON schema for `.return-meta.json`. Verified absent; a larger piece of work.
- Flipping the global non-blocking-commit policy. Recommend with reasoning; do not impose.

== ACCEPTANCE ==

1. A pathspec list containing one absolute path outside the repository, mixed with N valid repo-relative paths, results in the N valid paths being **committed**, and the offending entry reported loudly by path. The whole-list abort is gone.
2. The behavior in (1) is covered by a case in `scripts/tests/test-git-commit-scoped.sh` constructed so it **cannot pass vacuously** -- it must fail against the pre-fix script. Assert on committed CONTENT (the N paths are in the resulting tree), not merely on exit code.
3. Existing `git-commit-scoped.sh` behavior is preserved for every other input class: `:(exclude)` entries, Case 2 already-staged deletions, Case 3 genuinely unmatched paths, and the V3 exclude-only refusal. Regression-test these -- Case 2 especially, since it shares the all-or-nothing `git add` reasoning and is the property most at risk from a careless fix.
4. A path inside the repository but given as an ABSOLUTE path continues to work (it is a legal `git add` argument today); the fix must distinguish "absolute" from "outside the repository" and not break the former. State the chosen predicate explicitly.
5. The cross-repository-edit question (surface 3) is RULED ON in the report: either a field/mechanism is specified, or the format spec states that such edits are outside `modified_files` and names what an agent should do instead.
6. The non-blocking-policy question is ruled on in the report with reasoning, whether or not code changes.
7. The silent-filtering-vs-loud-refusal decision is stated in the report, and the chosen behavior is shown to beat the status quo on BOTH axes (valid work committed AND the violation reported). If only one axis is achieved, the report says which was traded and why.
8. `bash scripts/tests/test-git-commit-scoped.sh` passes in full, and `scripts/verify-deploy.sh` passes.

== ADDED SCOPE: THE EXIT-CODE SINK AT EVERY CALLER (now a live, landed concern) ==

The hard-error refusal this task's sibling work introduced has LANDED: `git-commit-scoped.sh` now has a V6 gate that exits **4** when at least one pathspec was dropped AND the resulting commit would be empty, printing a loud `ERROR:` naming every dropped path. Verified in the source store, with regression cases T11/T12/T13 and a documented exit-code table (0-4) plus V2/V3/V5/V6 gate labels in `context/standards/git-staging-scope.md`.

That work deliberately did NOT change any caller, and recorded the reason as an explicit residual. This task inherits it, because the residual is precisely this task's own failure mode:

**Every caller wraps the script as `cmd || echo "WARN: ...(non-blocking)"`, which collapses ANY nonzero exit to 0 for the caller's control flow.** So a new exit code in the script alone is NECESSARY BUT NOT SUFFICIENT: V6 can fire, print its loud error, and the caller will still proceed and let the task transition to `completed`. That is the same "the task still reports success" shape named in this task's own title, reached by a second route.

Rule on, and record with reasons:

- **Which callers must branch on the exit code, and on which codes.** The live script callers are `scripts/orchestrate-cycle-postflight.sh` and `scripts/orchestrate-unwind-dispatch.sh` (`scripts/orchestrator-postflight.sh` is confirmed orphaned with no live callers -- confirm that still holds before either fixing or skipping it). Beyond those, roughly 50 documented bash snippets across core and extension skills/agents share the canonical call shape, so a blanket "every caller branches" ruling has a real cost that must be weighed rather than assumed.
- **Whether exit 4 and exit 2 deserve the same treatment.** Exit 2 (usage error / V3 degenerate-pathspec refusal / `git add` failed) is also currently sunk by `|| echo WARN`, and the `git add` failure is the exact mechanism in this task's OBSERVED DAMAGE section. Decide whether the fix is per-code or a single "any nonzero except 1 is fatal" rule. Exit 1 must remain non-fatal: it is the legitimate "nothing to commit" case and is indistinguishable from a benign no-op by design.
- **Where the branch belongs.** A `$?`-specific branch at ~50 call sites is a different change from a single branch inside the two live script callers plus a documented convention for the snippets. Prefer the narrow mechanical fix plus an enforcement lint over editing 50 prose snippets by hand, unless research shows the snippets are themselves executed rather than copied.

HARD CONSTRAINT: do not make a commit failure fatal in a way that can strand an orchestration mid-batch. The non-blocking posture exists so one task's commit problem does not abort its siblings. The fix must make the failure VISIBLE and ATTRIBUTABLE -- surfaced into the task's own outcome and status rather than swallowed -- not simply convert a silent success into a hard abort. If a task's commit genuinely failed, the honest outcome is a `[PARTIAL]` with a named blocker, never `[COMPLETED]`.

Read `context/standards/git-staging-scope.md`'s exit-code table before planning; it is the current contract and this task must extend it, not contradict it.

---

### 303. Make validate-state.sh resolve its omitted-argument state-file default against the repository being validated, not the current working directory
- **Effort**: 1-3 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: orchestrator
- **Dependencies**: Task 271, Task 279

**Description**: Make `validate-state.sh`'s omitted-argument state-file default resolve against the repository being validated rather than the current working directory, and survey sibling scripts for the same latent pattern. A narrow, verified fix with a known mechanism — research confirms the resolution strategy and the survey, it does not re-litigate whether the defect is real.

== THE DEFECT (precisely located) ==

`scripts/validate-state.sh:241-243`:

    if [[ -z "$STATE_FILE" ]]; then
      STATE_FILE="specs/state.json"
    fi

A bare relative path, so the default resolves against the invoking shell's CWD. The script's own header documents this at line 41 ("STATE_FILE defaults to specs/state.json relative to the current working directory when omitted"). Invoking the validator from one repository while LOADING the script from another repository's deploy therefore silently validates the WRONG repository's state and reports findings belonging to a completely different repository.

**The deliberate design this fix must NOT break.** Header line 14 asserts the script is "Deliberately argument-relative, not PROJECT_ROOT-relative: this script takes a state-file path" — and the body honors that throughout: the sibling `TODO.md`, the sibling `archive/state.json`, and the `--fix` writer's `state-write.sh` candidate search are all located relative to `STATE_FILE`'s own directory (lines 274, 716, 326), not relative to `PROJECT_ROOT`. That argument-relative design is correct and intentional; it is what lets the script validate archive and vault targets. The defect is ONLY the DEFAULT applied when the argument is omitted. The fix is therefore scoped to that default — do not convert the script to PROJECT_ROOT-relative resolution throughout.

**Interface correction, verified:** `validate-state.sh` has NO `--state` flag. The override is a bare POSITIONAL `STATE_FILE` argument (argument parser default case, line 215). `--state` belongs to `generate-todo.sh`, which `validate-state.sh` invokes internally at line 725. Any report or acceptance criterion written against a `--state` flag on this script is wrong; do not add one without a reason beyond this task.

== CANDIDATE FIXES (research rules between them; all three are legitimate) ==

1. Resolve the default from the git toplevel of the CWD, so a repo-relative default still lands in the repo the caller is standing in.
2. Resolve the default from the script's own location via `lib/common.sh`'s `common_repo_root "$SCRIPT_DIR" 2` (already the documented idiom for `scripts/` callers; `SCRIPT_DIR` is computed at line 147 but is not used for the default today). This makes the default name the repo whose deploy the script came from — note this is NOT the same answer as (1) under cross-repo invocation, and choosing between them IS the design decision.
3. Refuse (exit 2) when the argument is omitted and the CWD-relative and script-relative candidates disagree, naming both. Fails loud rather than guessing.

Whichever is chosen, the resolved path MUST be echoed in the existing `Validating state file: $STATE_FILE` banner (line 408) as an ABSOLUTE path, so a false finding is self-diagnosing. In the incident below, printing the resolved path is exactly how the problem was found.

== OBSERVED DAMAGE (verified, today) ==

A dispatched agent with its shell CWD in `/home/benjamin/Projects/Logos/Verification` but loading the generator from the `/home/benjamin/.config/nvim` deploy reported a `TODO.md is OUT OF SYNC with specs/state.json` FAILURE (Check at line 729) against the nvim repo. No such failure existed. It was reading Verification's state — a repo legitimately mid-`/orchestrate` with drifted files. The agent caught it only by probing the validator to print its resolved paths, then re-ran with an absolute positional STATE_FILE and got 0 failures / 17 passed / 7 warnings.

**The failure mode is a false POSITIVE attributed to the wrong repository**, which is the dangerous direction: it invites someone to "fix" a repo that is not broken. This is the motivating severity argument — a false negative would merely be missed coverage.

== WHY A TASK AND NOT A NOTE ==

Cross-repo invocation is NORMAL in this architecture: one source store deploys into many consumer repos, and dispatched agents routinely run with CWD in one repo while a script resolves from another. Any script sharing this resolution pattern carries the same latent bug.

**Part (b) — survey, REPORT, do not necessarily fix.** A first pass over `scripts/*.sh` for a bare relative `specs/{state.json,TODO.md,errors.json,events.jsonl}` default already finds siblings:
- `scripts/command-gate-out.sh:63` — `state_file="specs/state.json"`, and `:87` — `task_dir="specs/${padded_num}_${project_name}"`
- `scripts/git-snapshot.sh:248, 332, 337` — bare `specs/state.json` in the task-inference and `file_scope`-read paths; note `:250` and `:333` already print `(cwd: $(pwd))` in their failure messages, which is the right instinct but does not prevent reading the wrong repo
- `scripts/command-gate-in.sh:65`, `scripts/orchestrate-build-dispatch.sh:213` — same literal, context to confirm
- `scripts/init-specs.sh:101-125` — CWD-relative BY DESIGN (it bootstraps `specs/` into the repo the caller is standing in). Confirm and exclude; do not "fix" it.

Report every sibling with a per-site verdict (same defect / by design / needs its own task). Remediate ONLY `validate-state.sh` here. Siblings live under directories declared wholesale by other tasks (270 declares `scripts/` and `scripts/lib/`), so fixing them inside this task would force avoidable serializing edges — recommend a follow-up task instead.

== DECLARED FILE_SCOPE OVERLAP WITH TASK 279 (declared honestly, not dodged) ==

Task 279 ("Reconcile state-schema.json with the live fields the orchestrator reads", `planned`) already declares BOTH `scripts/validate-state.sh` and `scripts/tests/test-validate-state.sh` in its file_scope — for a DIFFERENT change: adding `research_questions` to the hand-maintained `KNOWN_ENTRY_FIELDS` array (279's plan line 157), with a regression fixture (line 272) and a bidirectional schema/validator drift test (line 279). Grepping 279's plan for CWD or path-resolution language returns nothing, so 279 does NOT cover this defect and this is not duplicate work.

Task 271 ("Finish the parent_task edge", `not_started`) also declares both files, again for a `KNOWN_ENTRY_FIELDS`/schema change.

Both are genuine footprint collisions on the same two files. Declared as `dependencies: [271, 279]` rather than hidden, and `validate-state.sh` is deliberately NOT dropped from this task's file_scope to dodge them. Sequencing rationale: 271 and 279 both edit the `KNOWN_ENTRY_FIELDS` data array and the schema; this task edits the argument-resolution block (lines 241-243) and the banner (line 408). The regions do not touch, so either order merges cleanly — the edges exist to serialize the edits, not because the changes conflict semantically. **This task does NOT touch `KNOWN_ENTRY_FIELDS` or `context/schemas/state-schema.json`.**

== EXPLICITLY OUT OF SCOPE ==

The `research_questions` / `KNOWN_ENTRY_FIELDS` schema-validator drift. Task 279 owns it with an explicit checklist item, a regression fixture, and a bidirectional drift test. Verified — do not re-file or re-implement it.

== ACCEPTANCE ==

1. Invoking `validate-state.sh` with NO positional argument, from a CWD in a DIFFERENT repository than the one the script was loaded from, either validates the intended repository or refuses loudly naming both candidates. It never silently validates the other repo.
2. The `Validating state file:` banner prints an absolute resolved path.
3. An explicit positional `STATE_FILE` continues to behave exactly as today, including the argument-relative location of the sibling `TODO.md`, the sibling `archive/state.json`, and the `--fix` `state-write.sh` candidate search. Regression-test this — it is the property most at risk from a careless fix.
4. `scripts/tests/test-validate-state.sh` gains a case for the cross-repo omitted-argument invocation, constructed so it cannot pass vacuously (it must fail against the pre-fix script).
5. `bash scripts/tests/test-validate-state.sh` passes in full; `scripts/verify-deploy.sh` gate 10 (`--deep`, the only production `--deep` caller) still passes.
6. The sibling survey is recorded in the task report with a per-site verdict.
=== ADJACENT WORKED PRECEDENT (2026-10-04) ===

A defect of the same family was found and fixed in
`agent-system/extensions/core/scripts/tests/test-verify-deploy-context-budget.sh`: it resolved its
repository root by a fixed number of `..` hops, which is correct from the source store
(`agent-system/extensions/core/scripts/tests`) but overshoots to `$HOME` from the deployed tree
(`.claude/scripts/tests`) that `run-all.sh` actually invokes. The suite exited 2 on a path that
never exists, so the gate it guards went entirely unexercised and its failure was recorded in
`known-failures.txt` under a mis-diagnosed reason.

Two transferable conclusions for this task:

1. `scripts/lib/common.sh`'s `common_repo_root()` is NOT a fix for this family. It takes a caller-
   supplied hop count, so it is the same layout-dependent arithmetic behind a function call; a
   caller runnable from two layouts of different depths cannot pass one correct value.
2. The remedy that worked is UPWARD MARKER DISCOVERY: walk up from the script's own directory
   until a directory containing a known marker is found (there,
   `agent-system/extensions/core`), and fail loudly with the probed start directory if the walk
   reaches `/`. That is layout-independent and was verified to yield the same root from both the
   source-store and deployed locations.

Consider whether this task's own remedy should be the same discovery technique, and whether
`common_repo_root()` should gain a marker-based mode rather than every caller re-deriving one.

---

### 302. Pass --task at commit-staging sites to engage the contended-path lease, and rule on the task-scoped pathspec carve-out
- **Effort**: 3-6 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: orchestrator
- **Dependencies**: Task 44, Task 292, Task 300, Task 309

**Description**: Pass `--task` at every commit-staging site so `git-commit-scoped.sh`'s contended-path lease is actually consulted, and rule on whether the sanctioned task-scoped directory pathspec carve-out should be narrowed. This task was originally two halves; HALF 1 IS NOW DONE and must not be re-done.

== SCOPE CORRECTION: HALF 1 IS COMPLETE (verify before planning anything) ==

The original task had two halves. Half 1 -- replacing the bare `-- specs/` DIRECTORY pathspec at commit-staging sites with explicit file lists -- has been implemented and landed. Verified directly in the source store:

- `grep -rn -E -- '--[[:space:]]+specs/([[:space:]]|$|\\)' agent-system/extensions/` now returns only the deliberate negative-case fixtures inside `scripts/tests/test-lint-directory-pathspec-boundary.sh`. Every real staging site is fixed.
- The fix covered 19 sites across 11 files (2 more than the 17/9 originally measured here; `context/standards/git-safety.md` and `memory/skills/skill-learn/SKILL.md` were found by the new lint's own full-tree run).
- `commands/todo.md`'s 7 sites -- flagged in the original description as "the genuinely interesting case" because an archival sweep touches a set not enumerable in advance -- were resolved with a `stage_paths` bash-array accumulator, which is the "enumerate from the archival manifest the command already computes" ruling the original description anticipated. That ruling is made and implemented; do not reopen it.
- A new lint, `scripts/lint/lint-directory-pathspec-boundary.sh`, now mechanically forbids regression, with a 14-case fixture test. (Wiring it as a `verify-deploy.sh` gate is a separate task.)

DO NOT re-audit the pathspec shape of those sites, and do not re-litigate the per-site rulings. If research finds a bare directory staging pathspec that the lint does not catch, that is a lint defect to report, not this task's work.

== WHAT REMAINS: HALF 2 -- THE LEASE WAS NEVER CONSULTED ==

`git-commit-scoped.sh` already implements the mechanism that prevents cross-session commit bleed: `--task <task_number>` (opt-in, empty-value-skips-flag, fails open unconditionally) consults the cycle-scoped contended-path manifest (`specs/.contention-manifest/*.json`) for each POSITIVE pathspec entry, claims each listed path via a first-claim lease (`specs/.contention-claims/<path>`), and REFUSES before any `git add` (exit 3) when another live task holds a path.

Verified current state: `--task` is passed only by the SCRIPTS (`orchestrate-cycle-postflight.sh`, `orchestrator-postflight.sh`, `git-commit-scoped.sh`'s own tests) and by `memory/skills/skill-learn/SKILL.md`. It is passed by NONE of the recipe sites -- `skills/skill-git-workflow/SKILL.md`, `commands/task.md`, `commands/todo.md`, `agents/meta-builder-agent.md`, `skills/skill-meta/SKILL.md`, `epidemiology/commands/epi.md`, `present/commands/grant.md`, `present/commands/slides.md`, `present/commands/timeline.md`.

So the mechanism did not fail; it was never consulted. This is the same systemic shape the worktree-isolation removal verdict already records about an absent `file_scope` ("The guard did not fail; it was never consulted"). That is the argument for auditing commit sites for the missing `--task`, and it survives Half 1's completion intact -- narrowing the pathspec reduced the blast radius of a collision but did nothing to make the lease run.

Rule per site, do not blanket-add: a recipe that commits only its own task's artifacts may have nothing contended to claim, in which case `--task` is harmless but inert, and the honest ruling may be "add it for uniformity" or "document why it is unnecessary here". Decide with reasons.

== ALSO IN SCOPE: THE SANCTIONED TASK-SCOPED CARVE-OUT ==

The new lint deliberately EXEMPTS a task-scoped directory token (one carrying a `${...}` interpolation or an `{N}`/`{NNN}` placeholder, e.g. `specs/{padded}_{slug}/`) while flagging a shared one (`specs/`). That carve-out is not arbitrary: `context/standards/git-staging-scope.md` explicitly sanctions `specs/{padded}_{slug}/ "${ephemeral_excludes[@]}"` as the canonical per-operation scope, and without the carve-out the lint would flag roughly 25 sanctioned sites and be un-greenable.

The open question, recorded as a follow-up when the lint shipped: should those ~25 task-scoped-directory sites be narrowed to explicit file lists too? Arguments to weigh, not assume:

- A task-scoped directory pathspec still over-stages WITHIN one task's own directory, which is exactly how a concurrent in-place plan revision or a sibling's artifact write could be swept in.
- But it is confined to one task's own territory, so the cross-session bleed that motivated Half 1 does not apply, and `git-commit-scoped.sh` already injects `:(exclude)` entries for the canonical ephemeral-runtime-file candidate set for exactly these directories.

Produce a ruling with reasons. "Leave the carve-out as-is, and record why" is a legitimate and possibly correct outcome -- but it must be argued from the exclude-injection behavior, not asserted.

== CLOSE BY ==

Demonstrate that a `--task`-engaged recipe site actually refuses on a contended path (exit 3) rather than merely accepting the flag, so the wiring is proven live and not just present in the text.

All edits land under `agent-system/extensions/` per `.claude/rules/source-store-deploy-boundary.md`, never under `.claude/**`.

SCOPE NOTE: none of the recipe files in `file_scope` is an orchestrator-critical path, so this task does NOT trip the self-modification admission gate -- keep it that way; do not widen `file_scope` to include `git-commit-scoped.sh` or any critical path. If the ruling requires a change to `git-commit-scoped.sh` itself, record it as a follow-up instead.

== HALF 1 INTRODUCED A REGRESSION, NOW TRACKED AS TASK 322 ==

Recorded here because this task's HALF 1 (declared complete above) is the confirmed cause, and because this task edits both files the fix touches.

Replacing the bare `-- specs/` directory pathspec with explicit file lists was correct for the cross-session-bleed reason documented above, but at a RENAME site a directory token had been covering both endpoints incidentally. The explicit lists only ever collected move DESTINATIONS, so the vacated source paths stopped being staged. In `commands/todo.md` this left all three directory-move sites (lines 665, 686, 752) committing the archive copy as a fresh `create mode` while the old tree's deletion stayed unstaged -- measured live at 173 unstaged ` D` entries after one 15-task archival run, plus a wrong `phantom_paths: 109` baked into `state.json`'s `repository_health`.

Task 322 owns that fix. It also lands a named rename rule in `context/standards/git-staging-scope.md` -- a file THIS task also declares -- so expect serialization there, and do not re-derive the rule independently.

GENERAL LESSON FOR THE REMAINING HALF 2 RULING: when ruling on whether the sanctioned task-scoped directory carve-out should be narrowed, treat renames as a first-class case. A directory pathspec covers both endpoints of a `mv` by construction; any explicit list replacing it must name both endpoints explicitly. Narrowing the carve-out without that rule in hand risks reproducing this same regression at whatever sites the ruling converts.

---

### 300. Resolve AskUserQuestion's unreachability in dispatched subagents: verify the mechanism, correct the frontmatter standard's tool-inheritance claim, and rehome every user-choice gate
- **Effort**: 3-6 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None

**Description**: Resolve the fact that `AskUserQuestion` is not reachable from a dispatched subagent on this harness: verify the mechanism by direct probe, correct `agent-frontmatter-standard.md`'s tool-inheritance claim to match measured behaviour, and rehome every user-choice gate that currently sits inside a dispatched agent. The same pass settles one further unmeasured row of that same standard's optional-field table -- `isolation` -- which is documented as supported while the prohibition that fenced it off is gone (MEASUREMENT 7).

== THE OBSERVED FAILURE ==

In a live `/meta` prompt-mode dispatch, the dispatched `meta-builder-agent` could not call `AskUserQuestion`. It therefore could not run `/meta`'s MANDATORY confirmation gate, and routed the gate to the parent session via `SendMessage`; the parent asked the user with `AskUserQuestion` and relayed the answer back. That workaround produced a correct outcome, but nothing in the agent file or the skill anticipates or documents it.

== MEASUREMENTS (taken directly; each states its probe) ==

All path counts below were measured over `~/.config/nvim/agent-system/extensions/` on 2026-09-30/10-01. Directory totals shift as extensions are added -- re-measure before relying on a count, and treat the file lists rather than the integers as the durable part.

MEASUREMENT 1 (tool reachability, direct probe, two independent observations).
Probe: inside a dispatched `meta-builder-agent` subagent, call `ToolSearch` with query `select:AskUserQuestion`.
Result: `No matching deferred tools found`. Additionally, the subagent's own deferred-tool system-reminder enumerated roughly 50 deferred tools (`ArtifactComments`, `ArtifactData`, `CronCreate`, `EnterWorktree`, `Monitor`, `NotebookEdit`, `SendMessage`, `TaskStop`, `WebFetch`, `WebSearch`, plus the MCP tool families) and `AskUserQuestion` was absent from that list.
Note a CORRECTION to the first report of this failure: that report characterised `ToolSearch` as returning "only SendMessage". That phrasing is imprecise. The measured behaviour is that a large deferred-tool set IS available and `AskUserQuestion` specifically is not in it. The distinction matters, because it rules out "the subagent has almost no tools" and points at per-tool withholding instead.
STILL UNVERIFIED, and the task's FIRST obligation: whether the withholding is categorical for every dispatched subagent regardless of frontmatter. Both observations so far are of ONE agent (`meta-builder-agent`) with NO `tools:` line. Do not let research or the plan inherit this description's reading of the cause. Establish by direct test: (a) does a `tools:` allowlist that names `AskUserQuestion` expose it (the `literature-agent` form below is the natural probe subject); (b) does `disallowedTools:` omission behave differently from `tools:` omission; (c) does a `subagent_type` registered with "All tools" differ from a restricted one; (d) does it differ between a fork (`context: fork`) and a plain `Agent` dispatch. Record the measured answer with the exact probe used, and let the remediation follow from it.
THE SCOPE OF THIS OBLIGATION IS THE FULL OPTIONAL-FIELD TABLE, NOT ONLY `tools:`/`disallowedTools:`. The probe matrix this task must build is the natural -- and only cheap -- place to settle every row of `agent-frontmatter-standard.md`'s Supported Fields table that asserts harness behaviour nobody has measured. Probe: `awk '/^## Supported Fields/,/^## Optional Fields/' agent-system/extensions/core/docs/reference/standards/agent-frontmatter-standard.md | grep '^| `' | awk -F'|' '$4 ~ /No/' | wc -l`. Result: 14 optional (Required=No) rows as currently written -- `tools`, `disallowedTools`, `model`, `permissionMode`, `maxTurns`, `skills`, `mcpServers`, `hooks`, `memory`, `background`, `effort`, `isolation`, `color`, `initialPrompt`. (An earlier statement of this fold-in put the count at 13; 14 is the figure measured here by the probe above. Re-measure rather than citing either -- the row NAMES, not the integer, are the durable part.) Of these rows, `isolation` is MANDATORY to resolve, for the reason MEASUREMENT 7 records. The specific question to answer for it: does the harness honour `isolation` from an agent-definition frontmatter block AT ALL, as opposed to only as an `Agent` tool-call parameter? Record the exact probe used, and mark the answer unverified if the probe cannot settle it. The remaining rows are OPPORTUNISTIC: settle whatever the matrix settles for free, explicitly mark the rest unverified, and do NOT let them expand the task.

MEASUREMENT 2 (frontmatter census).
Probe: `find . -path '*/agents/*.md' -type f | wc -l`, and an awk scan of each file's YAML frontmatter block for a `tools:` key.
Result: 76 agent files in the source store. Exactly TWO declare a `tools:` line at all: `core/agents/spawn-agent.md` (`tools: Read, Write, Glob, Grep, Bash(jq:*)`) and `literature/agents/literature-agent.md` (`tools: Bash, Read, Write, Edit, AskUserQuestion`).
(The first report of this gap said 74 files; 76 is the figure measured here. Re-measure rather than citing either.)

MEASUREMENT 3 (which agents promise the tool).
Probe: `grep -rl 'AskUserQuestion' --include='*.md' . | grep '/agents/'`.
Result: 24 agent files reference `AskUserQuestion` in their bodies. 23 of them declare NO `tools:` line:
  core/agents/meta-builder-agent.md
  cslib/agents/cslib-vet-agent.md
  epidemiology/agents/epi-implement-agent.md
  epidemiology/agents/epi-research-agent.md
  founder/agents/analyze-agent.md
  founder/agents/deck-planner-agent.md
  founder/agents/deck-research-agent.md
  founder/agents/finance-agent.md
  founder/agents/financial-analysis-agent.md
  founder/agents/founder-spreadsheet-agent.md
  founder/agents/legal-analysis-agent.md
  founder/agents/legal-council-agent.md
  founder/agents/market-agent.md
  founder/agents/meeting-agent.md
  founder/agents/project-agent.md
  founder/agents/strategy-agent.md
  present/agents/budget-agent.md
  present/agents/funds-agent.md
  present/agents/pptx-assembly-agent.md
  present/agents/slide-critic-agent.md
  present/agents/slides-research-agent.md
  present/agents/slidev-assembly-agent.md
  present/agents/timeline-agent.md
The single exception is `literature/agents/literature-agent.md`, whose allowlist names the tool. If verification shows the harness never exposes it to a subagent, that declaration is inert AND it additionally narrows that agent to an allowlist it cannot fully use -- a second, separate defect to fix in the same pass. (Note `literature-agent.md`'s own body describes `/literature` as a DIRECT-EXECUTION architecture, so whether that file is ever dispatched as a subagent at all is itself worth establishing before deciding what its allowlist should say.)

MEASUREMENT 4 (the standard's claim).
Probe: `grep -n 'inherit the full tool set' core/docs/reference/standards/agent-frontmatter-standard.md`.
Result: the claim appears twice -- in the field table at line 39 ("Omit to inherit the full tool set.") and in the "`tools:`, `disallowedTools:`, and `mcpServers:` Semantics" section at lines 71-72 ("Omitting the field means the agent inherits the full available tool set.").
`meta-builder-agent.md`'s frontmatter is exactly `name`, `description`, `model: opus` -- it omits `tools:`, so by the standard's own rule it inherits everything, `AskUserQuestion` included. It did not. EITHER the standard's claim needs a stated exception for tools the harness withholds from subagents, OR the inheritance is being broken somewhere the standard does not describe. Whichever verification establishes, the standard must end up stating it explicitly, because all 23 files in Measurement 3 are written on the strength of that sentence.
This measurement's ownership of the file is what makes MEASUREMENT 7's `isolation` row this task's business rather than a new task's: same file, same defect class.

MEASUREMENT 5 (blast radius is NARROWER than a raw grep suggests -- the task must say so explicitly).
Probe: `grep -rl 'AskUserQuestion' --include='SKILL.md' .`, then for each hit `grep -m1 -E '^agent:'` and `grep -m1 -E '^context:'`.
Result: 28 SKILL.md files mention the tool, but only THREE declare an `agent:` line, i.e. fork to a subagent:
  core/skills/skill-meta/SKILL.md            -> agent: meta-builder-agent
  present/skills/skill-slide-critic/SKILL.md -> agent: slide-critic-agent   (context: fork)
  present/skills/skill-slide-planning/SKILL.md -> agent: slide-planner-agent (context: fork)
The other 25 are direct-execution skills running in the primary session, where the tool works fine. They are NOT affected and MUST NOT be churned. Scoping the fix to every file that merely greps positive would be wrong.
Two nuances inside that set of three:
  - `slide-planner-agent.md` does NOT itself reference `AskUserQuestion` (it is absent from Measurement 3's list), yet its skill does. Determine where that skill expects the asking to happen before changing either file.
  - `core/skills/skill-spawn/SKILL.md` and `core/skills/skill-fix-it/SKILL.md` mention the tool with no `agent:` line. Research should check whether they interact with a dispatched agent in practice before classing them as unaffected.

MEASUREMENT 6 (a constraint that bites remediation option 1 directly -- not in the original report).
Probe: `sed -n '1,6p' core/skills/skill-meta/SKILL.md`.
Result: `skill-meta`'s frontmatter reads `allowed-tools: Agent, Bash, Edit, Read, Write`. `AskUserQuestion` is NOT in skill-meta's own allowlist either. So "move the interview into the skill" is not a pure relocation: `skill-meta`'s `allowed-tools` must gain `AskUserQuestion` for the rehomed gate to work. Any plan choosing option 1 must include that edit, and should check the sibling skills' `allowed-tools` for the same omission.

MEASUREMENT 7 (the `isolation` frontmatter row: documented as supported, declared by nothing, fenced by nothing -- three probes, taken 2026-10-01).
Probe A: `grep -n -i worktree agent-system/extensions/core/docs/reference/standards/agent-frontmatter-standard.md`.
Result: exactly one hit, line 50, in the Supported Fields table: `| `isolation` | string | No | Isolation mode (e.g., `worktree`) |`. The standard therefore documents a per-agent frontmatter field whose documented example value requests a git-worktree-isolated dispatch.
Probe B: `grep -rn '^isolation:' agent-system/extensions/*/agents/`.
Result: no match (exit 1). NO agent file in the source store declares the field. The row is exercised by nothing today.
Probe C: `grep -n -i isolation agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`.
Result: no match (exit 1). The Move 2 `MUST NOT` that formerly forbade forwarding `isolation`/`worktree_path` to the `Agent` tool is gone from that file. That removal was DELIBERATE, not accidental: `agent-system/extensions/core/context/config/orchestrator-context-budget.json` records dropping "the isolation/worktree_path forwarding-prohibition paragraph, now moot since no dispatch row carries those fields" as part of a 992 B reclamation against that file's byte ceiling (verified by `grep -n -i 'isolation\|worktree_path'` on that JSON, which returns the derivation string quoted here).

THE GAP THOSE THREE PROBES DESCRIBE. Per-dispatch `git worktree` isolation is removed -- `specs/decisions/worktree-isolation-removal-verdict.md` (present, verified by `ls`), reaffirmed and NOT re-openable. The removal is clean at the code level: probe `grep -rln 'dispatch-worktree.sh\|task_selected_for_worktree_isolation' agent-system/` returns nothing, so `dispatch-worktree.sh`, its two test files, and `task_selected_for_worktree_isolation()` are absent from every live file. But the frontmatter row that could re-introduce a per-dispatch worktree THROUGH THE HARNESS is still documented as supported, while the prohibition that fenced it off is gone. Two of the three defects that layer induced remain OPEN, so a re-entry would re-arm them:
  - `agent-system/extensions/core/scripts/git-commit-scoped.sh` reports false success inside a worktree: its `PROJECT_ROOT` is derived from `BASH_SOURCE[0]`, every pathspec falls through WARN-and-drop, nothing stages, exit 0. Separately tracked (task 277, narrowed to the hard-error part); cite by path and defect in anything written into the source store.
  - `agent-system/extensions/core/scripts/lake-build-guard.sh` replays records across trees. Separately tracked (task 268, [implementing]); cite by path and defect in anything written into the source store.
STILL UNVERIFIED, and this is the entire reason for folding it in here: whether the harness honours `isolation` from an agent-definition frontmatter block at all. Probe B establishes only that no agent file DECLARES it; it says NOTHING about whether a declaration would take effect. Do NOT round Probe B up to "the field is inert" -- that is exactly the unverified-reading-promoted-to-finding error MEASUREMENT 1 warns against. MEASUREMENT 1's widened obligation owns answering it.

WHY THIS TASK IS THE RIGHT HOME, NOT A NEW ONE. MEASUREMENT 4 already owns correcting `agent-frontmatter-standard.md`'s unverified claims about what the harness reads from agent frontmatter, and that file is already in this task's `file_scope`. `isolation` is the same defect class -- a table row asserting harness behaviour nobody has measured. Folding it in costs ONE additional probe subject in a probe matrix this task already has to build; a separate task would duplicate the file ownership for no gain.

== WHY IT MATTERS MOST FOR /meta ==

`core/agents/meta-builder-agent.md` does not merely use the tool, it MANDATES it and forbids the fallback:
  - "ALL user choices MUST use AskUserQuestion with the `options` parameter to render interactive checkboxes/radio buttons."
  - "Use AskUserQuestion with `options` array for EVERY user choice point (single-select or multiSelect). Never fall back to text-based option presentation."
  - "**NEVER** present choices as plain text (A/B/C or numbered lists). Always use AskUserQuestion with `options` for interactive selection."
  - It lists "AskUserQuestion - Multi-turn interview for interactive mode" among its own tools.
Its 7-stage interview is built on the tool throughout: Questions 1, 2, 3, 5, 5b and 6 are each specified "via AskUserQuestion", Stage 5 ReviewAndConfirm is the mandatory confirmation gate, Stage 4.5's topic picker has no Skip option, and dependency-validation failures are specified to re-prompt through it.

CONSEQUENCE: `/meta`'s interactive mode -- the no-argument invocation, its primary documented entry point -- cannot run as specified at all. The interview has no way to ask anything, and the agent's own instructions forbid the text fallback that would otherwise rescue it. Prompt mode survives only via the undocumented `SendMessage` relay described above.

`core/skills/skill-meta/SKILL.md` compounds it twice: line 141 specifies "**Interactive**: Run 7-stage interview with AskUserQuestion" as agent work, and line 267 lists `AskUserQuestion` under the skill's postflight MUST NOT as "User interaction is agent work" -- placing the interaction squarely on the side of the boundary where it does not work.

== RESOLUTIONS TO WEIGH, NOT PRE-DECIDE ==

Research chooses with measured evidence; this description deliberately fixes none of them.

1. REHOME THE GATES. Move every user-choice point out of the dispatched agent and into the parent session -- the skill asks before dispatch, or after dispatch on a returned proposal -- and amend the agent files to stop promising a tool they cannot call. For `/meta` interactive mode this likely means the interview runs in `skill-meta` (direct execution) with only task-writing delegated. Requires the Measurement 6 `allowed-tools` edit.
2. SANCTION THE RELAY. Make the `SendMessage`-to-parent round trip a documented pattern with its own context file, since it is already proven to work. Record its real costs honestly: it depends on a parent that is listening, and a relayed answer is one more hop at which a decision can be garbled or a peer agent's message mistaken for user approval. (The agent-teammate contract already warns that no agent message is ever user consent -- a sanctioned relay runs straight at that warning and must address it.)
3. FIX THE FRONTMATTER, if and only if verification finds a form that genuinely exposes the tool -- in which case the 23 files get the declaration and the standard documents the requirement.
4. CORRECT THE STANDARD either way. Both occurrences (field table line 39 and the Semantics section) must state whatever exception verification establishes. This is NOT optional and does not depend on which of 1-3 is chosen.
5. SETTLE THE `isolation` ROW, likewise following the measurement rather than pre-deciding it. IF verification finds the harness DOES honour `isolation` from an agent-definition frontmatter block, then the forwarding prohibition that MEASUREMENT 7's Probe C shows is gone must be re-stated in a durable NON-EAGER home. It must NOT simply go back where it was: `core/skills/skill-orchestrate/SKILL.md`'s byte ceiling is precisely why it left, and `context/config/orchestrator-context-budget.json` records that reclamation, so restoring it there would re-open a closed budget. The candidates are `agent-system/extensions/core/context/contracts/territory.md` (whose lines 136-140 already carry the working-tree-and-build isolation posture and point at the decision record) and `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`'s "Working-Tree and Build Isolation Posture" section (line 1392). BOTH candidates are already another open task's declared edit target -- probe: `jq -r '.active_projects[] | select((.file_scope//[])[] | test("batch-orchestration-guardrails"))' specs/state.json` and the same test for `territory.md`, which return task 311 (`measured_co_scheduling_signal_and_isolation_posture`, [not_started]) whose `file_scope` names both files. The plan MUST declare that overlap explicitly rather than collide with it. IF verification finds the harness does NOT honour `isolation` from frontmatter, DROP the row from the Supported Fields table and say so with the probe that established it. Either way, the row and whatever verification establishes must end up consistent -- on exactly the same footing item 4 demands for the two "inherit the full tool set" occurrences.

PREFERENCE: prefer the option that removes the dependence over the one that documents a workaround, unless the measurement says otherwise.

== NON-GOALS FOR THE `isolation` FOLD-IN (load-bearing -- state these in the plan too) ==

- Do NOT re-open the worktree isolation verdict. It was re-opened once under new evidence and formally CONFIRMED; `specs/decisions/worktree-isolation-removal-verdict.md` is authoritative and the removal is not re-openable. Nothing in MEASUREMENT 7 or resolution 5 is licence to revisit it: the fold-in concerns a DOCUMENTATION row and a missing fence, never the decision itself.
- Do NOT restore any part of the removal layer. `dispatch-worktree.sh`, its two test files, and `task_selected_for_worktree_isolation()` stay absent, and the probe in MEASUREMENT 7 that shows them absent is an acceptance check, not a to-do.
- Do NOT widen into the two open defect tasks -- the `git-commit-scoped.sh` hard-error change and the `lake-build-guard.sh` cross-tree record replay fix. They are separately tracked and MUST NOT be edited by this task. MEASUREMENT 7 cites them only as the reason the re-entry path matters at all. Per `rules/no-task-references-in-deliverables.md`, cite them by FILE PATH AND DEFECT, never by task number, in anything written into the source store; task numbers are permitted only inside this `specs/**` description.
- Do NOT add `territory.md` or `batch-orchestration-guardrails.md` to `file_scope` now. Both are conditional on a verification outcome that has not been taken, and they belong in the plan-time narrowing -- added only if resolution 5's first branch is reached, and then with the overlap against the other open task declared.

== CONSTRAINTS ==

- SOURCE STORE ONLY. Implementation edits `~/.config/nvim/agent-system/extensions/**`; every consuming repo regenerates its own `.claude/` through the loader picker. Nothing hand-authored under `.claude/**` -- the next redeploy wipes it (`rules/source-store-deploy-boundary.md`).
- No task-number references in anything written into the source store (`rules/no-task-references-in-deliverables.md`). Cite file paths, standard section names and script names.
- Any behavioural claim about the harness in the final record must be MEASURED on this harness and state its probe, never asserted from this description. Where a claim stays unverified, mark it unverified rather than rounding it up. The "STILL UNVERIFIED" clauses under Measurement 1 and Measurement 7 are the ones that matter most.
- FILE SCOPE -- DO NOT WIDEN; NARROW IT AT PLAN TIME. This task carries the backlog's coarsest `file_scope` entry. Probe: `bash .claude/scripts/validate-state.sh --deep`. Result: `WARN Coarse file_scope declaration: project_number 300, entry 'agent-system/extensions/core/scripts/tests/' overlaps 19 distinct non-terminal task(s): 165,184,217,250,251,263,265,268,270,271,273,274,277,279,281,282,303,304,313`. That bare-directory entry MUST be replaced at plan time by the explicit test files this task will add or touch; the standing warning clearing is the signal it was done. (Counts are re-measurable; the overlap and the file list, not the integer, are the durable part.) The `isolation` fold-in adds NO net widening: its only file is `agent-system/extensions/core/docs/reference/standards/agent-frontmatter-standard.md`, which MEASUREMENT 4 already required and which is already declared in `file_scope`.
- DELIVERABLE: a fixture or probe that demonstrates the chosen remediation actually lets a user choice reach the user, in the style of the lean and typst extensions' own test suites. Landing site for a shell-level probe: `agent-system/extensions/core/scripts/tests/` (see `run-all.sh` and the existing `test-*.sh` siblings for the harness conventions).

== ACCEPTANCE DIRECTION ==

- `/meta` with no arguments completes a real interview and creates a task.
- The reachability mechanism is recorded with its exact probe, and anything unresolved is marked unverified rather than asserted.
- Both "inherit the full tool set" occurrences in `agent-frontmatter-standard.md` match measured behaviour.
- No agent file instructs an agent to call a tool it cannot call.
- `literature-agent.md`'s allowlist is correct for whatever verification establishes (including the prior question of whether it is ever dispatched as a subagent at all).
- The three fork-to-agent skills' contracts agree with where the asking now happens, and the 25 direct-execution skills are left untouched.
- A probe/fixture under `core/scripts/tests/` demonstrates a user choice actually reaching the user.
- The `isolation` row of `agent-frontmatter-standard.md`'s Supported Fields table is SETTLED BY MEASUREMENT, on one of exactly two branches: either the harness honours the field from frontmatter and the forwarding prohibition is re-stated in a NAMED non-eager home (never `skill-orchestrate/SKILL.md`) with the `file_scope` overlap against the other open isolation-posture task declared; or the row is dropped and the probe that justified dropping it is recorded. An `isolation` row left standing with no measurement behind it is a FAILURE of this task, not a deferral.
- Every optional row of the Supported Fields table is either measured or explicitly marked unverified in the standard -- no row silently retains an unmeasured behavioural claim, and the row list is re-measured at implementation time rather than taken from this description's count.
- The worktree isolation verdict is untouched; the removal layer is not partially restored (`grep -rln 'dispatch-worktree.sh\|task_selected_for_worktree_isolation' agent-system/` still returns nothing); and neither separately-tracked defect script -- `git-commit-scoped.sh`, `lake-build-guard.sh` -- is edited by this task.
- `file_scope`'s `agent-system/extensions/core/scripts/tests/` entry is narrowed to explicit files, and `validate-state.sh --deep` no longer reports a coarse-scope warning for this task.

---

### 299. Guarantee detection of in-place plan revision concurrent with a live implement dispatch
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: orchestrator
- **Dependencies**: None

**Description**: Guarantee that an in-place plan revision landing concurrently with a live implement dispatch is DETECTED, by adopting two complementary remedies together.

THE DEFECT. scripts/orchestrate-cycle-plan.sh can emit a `plan-revision` aux row for the same task and the same cycle as that task's implement dispatch: mutual exclusion is asserted between aux KINDS (drift-inspection vs divergence-audit), never between an aux row and the implement row. See the AUX DECISION comment at orchestrate-cycle-plan.sh:1241-1247 ("Mutual exclusion between `drift-inspection` (base mode) and `divergence-audit` (hard mode) is asserted defensively...") and the `aux_emit_kind` declaration at :1250. skills/skill-orchestrate/SKILL.md's Move 2 then requires every `dispatch[]` AND `aux_dispatch[]` row be issued in ONE message (SKILL.md:131-133, "Issue every Agent call named by `dispatch[]` AND `aux_dispatch[]` in **one message**"). So reviser-agent (the fixed agent for `plan-revision`, orchestrate-cycle-plan.sh:1359) edits plans/*.md IN PLACE while the implement agent is reading that same file. Nothing in any contract makes the implement agent aware the file changed underneath it.

OBSERVED COST (real production run: BimodalLogic, task 703, cycle 5). The implement dispatch excerpted one phase from the post-revision file and another from the pre-revision file, noticing only because line numbers shifted between two reads. It reported a plan bullet as uncorrected when the revision had already corrected it, propagated that false claim into the phase handoff and the round summary, and required a retraction plus two further plan revisions to unwind. It was caught ONLY because reviser-agent chose, on its own initiative, to message the live implement dispatch when its revision landed. Confirmed: agents/reviser-agent.md contains no notification machinery whatsoever (no SendMessage, notify, or concurrent-dispatch obligation anywhere in the file). That load-bearing behavior is entirely discretionary today.

REMEDY 1 - make the landed-revision notification routine rather than discretionary. The aux plan-revision dispatch file must instruct reviser-agent to message the live implement dispatch when its revision lands. Landing site: scripts/orchestrate-build-aux-dispatch.sh - the `plan-revision` arm of the prompt case statement at :189-195, and/or the dispatch-file emit block beginning at :201. This is precisely the mechanism that already worked; the change makes it contractual.

OPEN DECISION (settle during research/plan; do not assume it is free). Remedy 1 stated conditionally - "whenever a plan-revision aux row is co-dispatched with that same task's implement row" - is NOT directly expressible at the point the aux dispatch file is built, for two independently verified reasons. (a) orchestrate-build-aux-dispatch.sh's argument interface (usage block at :59-66) has no parameter carrying any knowledge of a sibling implement row. (b) More fundamentally, the AUX DECISION and AUX EMISSION blocks run at orchestrate-cycle-plan.sh:1241 and :1343, which is BEFORE the all-terminal check (:1500), eligibility (:1517), classification (:1635), force-phase consumption (:1676), admission (:1714), and dispatch-candidate bucketing (:1829). At aux-emission time the cycle does not yet know which tasks receive an implement row this cycle. Three resolutions, in recommended order:
  (c) RECOMMENDED - emit the notification instruction UNCONDITIONALLY in every `plan-revision` aux dispatch file. Requires no reordering and no new flag; the instruction is inert when no implement dispatch is live. Cheapest correct option.
  (b) Defer only the dispatch-file WRITE for plan-revision rows until after bucketing, then pass a new flag. More precise, but splits the aux emission block and must preserve its live-only-side-effect ordering (aux_pending consumption, marker-file consumption, escalation counters) and the shared-decision-section mandate that --dry-run and live render identical choices.
  (a) NOT RECOMMENDED - reorder the aux decision after bucketing. Most invasive; touches the script's documented decision-section structure.

REMEDY 2 - add an implement-side obligation to re-read every excerpted plan phase before writing. This catches a tear that lands between two reads before any message arrives, which is the failure mode remedy 1 alone misses. Landing sites: scripts/orchestrate-build-dispatch.sh's implement-phase "## Plan" block at :435-439 (currently emits only `plan_path`), and/or agents/general-implementation-agent.md (plus extensions/lean/agents/lean-implementation-agent.md for parity).

REMEDY 2 IS GENUINELY NEW - do not mistake it for existing coverage. Two adjacent mechanisms look like they already cover it and do not: (i) the `--territory` payload's "generic re-read-before-editing" note (orchestrate-build-dispatch.sh:67-69) governs re-reading the TARGET files an agent is about to edit, not the plan that instructs it; (ii) context/contracts/pre-edit-gate.md treats "a planning-time list as a hypothesis about the codebase" - it validates plan CLAIMS against the tree, not the plan FILE against its own later revision. Remedy 2's subject is the instruction source itself.

TENSION TO RECONCILE EXPLICITLY. agents/general-implementation-agent.md:59 currently reads "Do NOT re-read the full plan unless necessary (the handoff References section points to deeper context if needed)". It sits under **Successor Behavior** (:55-60), so it is scoped to handoff resumption rather than the primary read path - but a successor dispatch is exactly the case where the plan is most likely to have been revised since the prior read. Remedy 2 must reconcile with this line rather than silently contradict it, and the reconciliation should keep the obligation narrow: re-read the specific excerpted phase before writing, not the full plan.

BYTE-BUDGET INTERACTION (affects the design, not just the ordering). skills/skill-orchestrate/SKILL.md is already 325 B over its 20,000 B ceiling, and a concurrent task promotes ORCHESTRATOR_BUDGET_GATE_MODE from warn to hard (see task #289, which owns agent-system/extensions/core/context/config/orchestrator-context-budget.json and the same SKILL.md). Therefore: prefer putting the actual contract text in a context/ file and emitting only a short pointer into SKILL.md and the dispatch files, rather than adding prose to SKILL.md. No blocking dependency is declared on #289 in either direction - whichever lands second re-measures the budget - but a byte-heavy SKILL.md edit here would re-breach a gate that is becoming hard.

REJECTED ALTERNATIVE (recorded as rejected, NOT as a future phase). Remedy 3: never co-dispatch a plan-revision aux row with the same task's implement row, deferring the revision one cycle. It is the only option that REMOVES the race rather than detecting it. Rejected because it costs a full cycle and contradicts the current one-message dispatch rule at SKILL.md:131. Do not re-scope it into this task or a successor.

DEFERRED OBSERVATION (record only; explicitly OUT OF SCOPE). The same incident surfaced a second finding: a header-only correction label in a long plan does not survive a line-range excerpt, because a reader excerpting from below the labelled block drops the label silently. That was fixed in the affected plan directly. It is a documentation-form finding about plan authoring, not an orchestrator defect, and must not be scoped into this task.

SOURCE-STORE BOUNDARY. All edits land under agent-system/extensions/core/** (and extensions/lean/** for the lean agent). Never edit a deployed .claude/** copy - the next redeploy wipes it (.claude/rules/source-store-deploy-boundary.md). Script behavior changes should carry coverage in agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh and the aux/cycle-plan test siblings.

SHARED-FILE CONTENTION (for batch admission awareness, not dependencies). Other active tasks declare overlapping file_scope: #289, #273, #274, #275, #285 and #263 touch skill-orchestrate/SKILL.md; #250, #165, #272, #265 and #293 touch orchestrate-cycle-plan.sh; #263 touches orchestrate-build-dispatch.sh. Do not batch this task concurrently with those.

---

### 298. Author the books extension context corpus under context/project/books/
- **Effort**: 3-6 hours
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: Task 297
- **Research**: [298_author_books_extension_context_corpus/reports/01_books-extension-context-corpus.md]
- **Plan**: [298_author_books_extension_context_corpus/plans/01_books-context-corpus.md]
- **Summary**: [298_author_books_extension_context_corpus/summaries/01_books-context-corpus-summary.md]

**Description**: Author the domain context corpus for the `books` extension under `agent-system/extensions/books/context/project/books/`. The extension's wiring — manifest, four-block routing, agents, skills, commands, rule, registration files and tests — is the dependency task; this task supplies the knowledge those agents and skills point at.

SCOPE: source store only, and within it `context/project/books/**` only. The dependency task owns `manifest.json`, `agents/`, `skills/`, `commands/`, `rules/` and `scripts/tests/`; this task does not edit them. Nothing is hand-authored under `.claude/**` (`rules/source-store-deploy-boundary.md`); each repo regenerates its own `.claude/` through the loader picker.

Write against the DESIGN RECORD — `docs/book-convention.md` (2450 lines, 18 accepted decisions) and `books/schema/book-toml-v2.md` (normative) in the Logos/Verification repository, plus `docs/architecture-decisions.md` decisions 2, 3, 8, 9 — rather than against the half-landed tooling, and keep the known-gap register honest about what is not yet built.

== DOCUMENTS TO AUTHOR ==

This corpus is one coherent reading; do not fragment it further.

**1. Layer vocabulary and the may-import matrix.** The twelve `book_layer` values: the eight layers `interface | laws | extraction | impl | instances | refinement | challenge | evidence` plus the four opt-in split tiers `impl.defs`, `impl.proofs`, `instances.defs`, `instances.proofs` (Decision 2). The may-import matrix (Decision 3) replacing a total order, enforced at elaboration by `book_layer` over DIRECT imports only and at certification over the computed graph. `challenge` and `evidence` are terminal. The two universal rules that sit OUTSIDE the matrix and are the certifier's responsibility, not `book_layer`'s: Mathlib/Aeneas confinement, and terminal layers.

**2. `book.toml` v2 and what is computed instead.** `schema = 2`; `[book]` name/module/version/status/license/maintainers; `[trust]` with the six ground classes G0_checker, G1_translation, G2_ir_faithfulness, G3_models, G4_specification, G5_binding; `[provenance]` rust_crate/rust_paths/extractor for bridged books only; `[docs] entry`. Fifteen fields across seventeen keys — record that the design record's own "twelve fields" headline is a historical name which the schema document corrects. `status` in {draft, certified, deprecated}; each trust verdict in {verified, validated, trusted, not_applicable}; `stale` is DERIVED, never authored. Computed and never authored: `[layers]`, `[exports]`, `[[depends]]`, `[external]`, `[axioms]`, the summary (which is the book module's docstring), and packages.

**3. The certificate and ledger shape.** `book.cert.json` sits DIRECTLY in the book directory — never a `certificate/` subdirectory, because the framed_channel export tooling treats every `certificate` directory as a discovery root — and is THE ONLY INPUT of every non-Lean tool (Decisions 8, 9, 11). The per-export ledger. And `book.record.json` as the separate, NON-digested reconciliation record binding each guarantee's text hash to its export's ledger digest, with who signed and when.

**4. Identity, chaining and the versioning rule.** Per-export Merkle digests over the statement cone with axiom sets, rolled into `interface_identity` and a full `identity`, chained per export through dependencies' certificates. Versioning keys on canonical statement serialisation; NO bump on a Lean toolchain bump alone.

**5. Status and trust vocabularies** — the three `status` values and the four trust verdicts, with what each licenses and what it forbids. A `certified` book whose record is not fully reconciled FAILS the docs stage and is not certified; a `draft` book only reports.

**6. The metadata split, as an authoring rule.** Facts in Lean, judgments in TOML, everything else computed (Decision 6). In a code module, exactly two things: `@[book_export]` on a declaration (no kind argument — kind is derived from `getOriginalConstKind?`) and one `book_layer <layer>` line. In the book module, everything else: `book`, `book_assume "<id>" "<text>" [<anchor>]`, `book_not_claimed "<text>"`, `book_axioms [...]`, `book_policy`, `book_requires` — all read back by `#book_ledger`. A `book_*` command in a code module WARNS and the build succeeds.

**7. The build -> test -> certify -> document workflow, as an executable checklist.** Measured from the landed reference implementation over `components/distsys/lean/`: nine layer-assigned code modules, four book modules, four `book.toml` manifests, four docs entries.

AUTHOR — code modules with the licence header on line 1 and `module` on line 2, one `book_layer` per code module, `@[book_export]` on each intended export, added by hand to the lakefile's explicit globs list. Then the book module: a PLAIN (private) import of the provider, PUBLIC imports of its own code modules (which is what makes a cross-book dependency declaration resolvable), a module docstring that IS the book's summary, `book <Name>`, `book_axioms [...]` naming the permitted set, per-layer `book_policy` confinement lines, `book_assume` with its discharging anchor, `book_not_claimed`, and `book_requires` for cross-book hypotheses (checked transitively against statement cones, so naming a constant whose declaring module is in the closure is correct and sufficient). Then `book.toml` v2 and the `docs/` entry.

BUILD/TEST — clean build green from an empty `.lake/` with no network, wall time recorded; zero-`sorry` census, no `native_decide`, no search tactic, no vacuously-true definition; axiom audit enumerating every export's axioms against the declared budget with choice absent, and the number of SOURCES distinguished from the number of carrying declarations; universe audit; Mathlib-freedom audit (no require, no import, no mention, in any module or lakefile); `#book_ledger` reporting every code module layered, the book module carrying no layer, every intended export rowed with the right derived kind and NO forged-row flag; `books-tool validate` over each manifest (it decodes and checks all seventeen keys — a stronger check than counting files); `books-tool check --lib` reporting zero unassigned and zero doubly-assigned modules; a rebuild-isolation spot check (a proof-body edit rebuilds exactly that module; a figure materially above 1 means the exposure surface widened); a declaration-inventory diff signature by signature against the design artifact — a weakened restatement that still type-checks is exactly what this catches; `check-spdx.sh`; the regex layer lint, recording EXPLICITLY when it passes VACUOUSLY over a package no rule's file-half reaches; and the task-reference lint. Every figure is recorded as LANDED, never inherited from the design artifact, and a deviation is written as a deviation note rather than silently absorbed.

CERTIFY — the certifier over the built environment: dependencies first in topological order, `reverify`, the advisory shake, computed `depends`, the per-export ledger, `interface_identity` and `identity`, the version check as a ledger diff, the authored judgments copied in with `source: authored`, then the docs stage. Mechanics worth recording: a reader script run under `lake env lean` inside the certified package's workspace does the environment work at the `.private` olean level, where `loadExts := true` after `enableInitializersExecution` is MANDATORY and SILENT when omitted; `reverify` re-verifies every recorded entry against constants and is the only first-implementation pass; the shell driver builds module targets with `lake build --wfail <Module>` and runs `lake shake` ADVISORILY, because shake refuses non-`module` packages on the pin — so that stage reports SKIPPED and never propagates its rc — and refuses on any failed check. Output is byte-stable: an unchanged tree regenerates the certificate byte for byte.

DOCUMENT — author `docs/book.typ` against the certificate ALONE, in three tiers; compile each tier standalone and once embedded through `typst/scripts/build.sh`; then the tier-one prohibition lint, the drift and completeness checks, the element-placement lint and the chapter-quality check with no blocking finding.

**8. The three-tier Typst template contract**, with the constraints that are VERIFIED on Typst 0.14.2 rather than assumed. `typst/lib/book.typ` (183 lines) is the per-book document template: tiers `overview | full | reference` via `--input tier=`, modes `standalone | embedded` via `--input mode=`. Its ONLY data input is the book's `book.cert.json`, loaded by the book DOCUMENT (`json("book.cert.json")`, a path relative to itself) and handed in via `#show: book.with(certificate: ...)`. The library never calls `json()` for a certificate, never reads `book.toml`, never reads `book.record.json` and never reads Lean source — because a relative `json()`/`read()`/`image()` path resolves against the file whose SOURCE TEXT contains the call, so a shared library cannot read a different certificate per book. `typst/lib/phrases.toml` is the only other file it reads, root-absolutely.

Label mechanics: every label is book-id-prefixed from a `state()` so labels cannot collide once several books are embedded in one build; a label built in a SEPARATE `context` block and placed after already-realized content SILENTLY fails to attach, so labelled content and its label must be constructed together inside ONE `context` block (the `tagged`/`tagged-metadata` helpers); and every `metadata` value carries an explicit `kind` field so a generic `typst query <file> 'metadata'` returns every tagged element from every embedded book and the consumer filters on `.value.kind`.

The compile root is the REPOSITORY root (`--root .`, architecture Decision 9) through `bash typst/scripts/build.sh`, so a book's `docs/` outside `typst/` compiles standalone AND embeds in the manual. Pins: thmbox 0.3.0, fletcher 0.5.8, cetz 0.3.4 on Typst 0.14.2. The test suite `typst/tests/book-template/run.sh` runs against `typst/tests/book-template/probe/` (book.toml, book.cert.json, book.record.json, docs/book.typ): three standalone tier compiles, one embedded compile, `typst query` for `<lean-decl>`/`<guarantee>`/`<book-meta>` metadata, and tier=overview containing no backtick span and no math.

The tier-one content bar: no symbols, no Lean identifiers, no tool names; every guarantee names an export and every export has a guarantee; assumptions and not-claimed items rendered FROM the certificate, never retyped; a book that cannot support a section carries a scope note naming what is missing; a reworded guarantee needs re-approval exactly as a changed statement does; and a mechanical tier-one prohibition lint is part of the docs stage.

**9. The reconciliation contract and the agents-write-prose / people-write-records boundary.** Reconciliation is triggered by CERTIFICATION, never by file save or commit: a proof-only edit changes no digest and touches no guarantee; an interface change always does, once. The contract: inputs limited to the documenter pack (certificate + tiers one and two + the phrase table + the record); writes limited to `docs/book.typ` of the NAMED book; only guarantees whose digests changed are touched; every tier compiled and the docs stage and lints green before finishing; and the record, `book.toml`, approvals and book module NEVER edited. The summary names each guarantee touched with old and new digest. Agents write prose; PEOPLE write records — the command prints the signing invocation and never runs it.

**10. The tooling inventory**, naming what each piece READS and WRITES, and marking what the extension consumes rather than reimplements.

`books/` at the repo root is a tooling directory, not a component: nothing there is digested, carries a certificate, or is depended on by a component gate. `books/lean/` — package `books`, library root `Books`, module `Books.Meta` (413 lines), the metadata provider; declares NO `require`; a PRIVATE import of code modules, since `public import Books.Meta` would make every consumer load `Lean`, so only book modules and the certifier import it publicly. `books/tool/` — package `booksTool`, the `books-tool` lean_exe (`Books.Manifest`, `Books.EnvWalk`, `Books.LayerCheck`), invoked as `books-tool validate` and `books-tool check --lib <built lib dir>`. `books/tests/manifest/run.sh` — the fixture suite driving the real `lake build`, the real elaborator and the real executable, with no copy of the provider's rules in the harness; cases BUILD, WF, TIERS, UNASSIGNED, DOUBLE, MATRIX-C, MATRIX-E, DIVERGE, XBOOK, LEDGER, FORGE-A..D, WARN, MANIFEST.

Authoring rules under `books/`: the proprietary header within the first three lines of every `.lean`/`.sh` (comment line 1, `module` line 2, since a comment parses ahead of the `module` keyword), enforced by `components/framed_channel/scripts/check-spdx.sh`; explicit per-module lakefile `globs` and NEVER `Books.+`, because both `books/lean` and `books/tool` use the root `Books`, so a wildcard glob makes each claim the other's modules and the build fails with "bad import 'Books.Meta'"; and fixture packages use library roots distinct from `Books`.

Repo-side documentation machinery to know about and NOT duplicate: `typst/manual/generated/` (every file generated, never hand-edited), `typst-component-doc.sh`, `typst-component-index.sh`, `status-counts.sh`, `script-reference.sh`, `certificate-export.sh`, `typst-manual-sync-check.sh` (regenerate-and-diff; exits non-zero naming the file and its exact regeneration command), `chapter-drift.sh` (non-blocking by design, `--mark` left to the person) and `name-resolution-check.sh`. The typst extension already ships `typst-element-lint.sh` and `chapter-quality-check.sh`.

**11. The known-gap register**, kept honest rather than aspirational:

- The matrix check's domain on the real tree is currently EMPTY. Measured: of 36 built module headers, 0 carry a `book_layer`. So the matrix check and the regex layer lint CANNOT yet disagree.
- `lake shake` refuses non-`module` packages on the pin, so the certifier's shake stage reports SKIPPED and never propagates its rc — it is advisory by necessity, not by preference.
- The regex layer lint `interface/scripts/layer-lint.sh` (plus `layer-rules.sh`, nine rules) runs BESIDE the matrix check during the pilot. Four rules reproduced, four reproduced-by-declaration, one — Mathlib/Aeneas confinement — deliberately not in the matrix at all. It can pass VACUOUSLY over a package no rule's file-half reaches, and that must be recorded as a vacuous pass rather than a pass.
- NOT yet landed (certifier phases 13-23 of 23): the certificate writer, `books/schema/book-cert-v2.md`, the shell driver and the acceptance suite. Planned and named in `docs/development.md`: the certifier's docs stage emitting the documentation queue JSON, `books/tool/approve-guarantees.sh` (the only writer of `book.record.json`) and `books/tool/book-health.sh --json`.
- Also in flight and defining contracts this corpus describes: the ledger-tool-and-certifier build, the two-smallest-books pilot, the framed_channel book family, the documentation-honesty checks, the three-tier book documentation, the provider-side trust defences and the deferred certifier passes.

== CONSTRAINTS ==

No task-number references in any file written into the source store: cite file paths, decision numbers and script names instead (`rules/no-task-references-in-deliverables.md`). Refer to in-flight Verification work by its title and deliverables only.


== ADDED DOCUMENTS (amendment): FIVE MORE, FROM LIVE CONSUMER-REPO EVIDENCE ==

The eleven documents above are authored as specified. FIVE MORE are added to this same corpus,
each grounded in measured cost from a completed books task in the consumer repository rather
than in design-record reading. They land in the same `context/project/books/` tree and are part
of the same coherent reading, which is why they are added here rather than split off.

**12. `domain/gate-tiers.md` -- the tier chain, and what each tier does NOT check.** The chain is
`lake build` -> `interface/scripts/layer-lint.sh` -> `certify.sh` -> `full-gate.sh` ->
`--recheck`. For EACH tier record three things: what it checks, what it does NOT check, and the
cheapest tier that catches each error class. The motivating measurement: 44 layer violations sat
undetected across five tagging phases that ALL reported green on `lake build`, because `lake
build` invokes neither the layer lint nor the certifier nor the Comparator rooms. There is today
no verification tier between `lake build` and the full gate, and the absence of that intermediate
tier is the finding this document must state plainly. Also record that a tier can pass VACUOUSLY
(the regex layer lint over a package no rule's file-half reaches) and that a vacuous pass must be
reported as vacuous, never as a pass -- this connects to the known-gap register above.

**13. `patterns/warning-driven-convergence.md`.** The `grep | sed` loop that generated 179
`book_requires` lines with ZERO guesses, by driving off the compiler's own warnings rather than
off a human reading the source. Record the loop shape, why the warning stream is the correct
oracle, and the termination condition.

**14. `patterns/gate-collision-ledger.md`.** Six integration collisions between the books
convention and a component's pre-existing gate, with their fixes. The measured cost: one implement
dispatch spent 75 of 127 minutes in a SINGLE phase rediscovering them, and five of the six were
discoverable only by running a ten-minute fail-closed full gate. Record each collision as a
ledger row with its symptom, its root cause and its fix, so the next books integration reads the
ledger instead of rediscovering it.

**15. `standards/forgery-probe-discipline.md`.** Every gate predicate gets a forgery probe; a
gate predicate shipped without one is a REVIEWABLE DEFECT, not a gap to be noted. Ground this in
the existing FORGE-A..D fixture cases in `books/tests/manifest/run.sh`, which are the pattern to
generalize rather than a special case.

**16. `tools/certify-guide.md`.** Operating the certifier economically: component-root scoping,
running `--check` FIRST, the `--no-build` economics, and the misreporting closing line (the
certifier's final summary line can report success while an earlier stage reported SKIPPED --
record exactly what the closing line does and does not warrant).

These five are additive to the eleven above and do not change this task's scope boundary: the
dependency task still owns `manifest.json`, `agents/`, `skills/`, `commands/`, `rules/` and
`scripts/tests/`, and nothing is hand-authored under `.claude/**`.

Cite durable anchors throughout -- filenames, decision numbers, script names, `file:line` -- and
never a task number (`rules/no-task-references-in-deliverables.md`).

---

### 297. Scaffold the books extension: manifest, four-block routing, agents, skills, commands, rule and tests
- **Effort**: 3-6 hours
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: None
- **Research**: [297_scaffold_books_extension_routing_and_agents/reports/01_books-extension-scaffold-research.md]
- **Plan**: [297_scaffold_books_extension_routing_and_agents/plans/01_books-extension-wiring.md]
- **Summary**: [297_scaffold_books_extension_routing_and_agents/summaries/01_books-extension-scaffold-summary.md]

**Description**: Build a new `books` extension in the agent-system source store at `agent-system/extensions/books/`, providing the `books` task type for authoring, certifying and documenting **lean books** as that standard is defined in the Logos/Verification repository.

This task owns the extension's WIRING. The domain context corpus under `context/project/books/` is a separate task that depends on this one; author the agents and skills here with plain backticked path pointers into `context/project/books/...` (the system's lazy-loading convention), never eager imports.

SCOPE: source store only. Implementation edits `agent-system/extensions/books/**`; each repo regenerates its own `.claude/` through the loader picker. Nothing is hand-authored under `.claude/**` (see `rules/source-store-deploy-boundary.md`).

== PRECEDENT ==

`agent-system/extensions/cslib/` is the structural precedent: a lean-dependent extension with its own task type and full four-block routing. Measured from its `manifest.json`: `task_type: "cslib"`, `dependencies: ["core","lean","literature"]`, `provides` for agents/skills/commands/rules/context, all four routing blocks (`routing`, `routing_hard`, `routing_agents`, `routing_agents_hard`), `keyword_overrides` with `keywords` + `aliases`, and `merge_targets` for claudemd (with `section_id`) and index. Its `routing_agents.plan` maps to core's `planner-agent` rather than a bespoke planner — follow that unless research justifies otherwise.

For contrast: `lean/manifest.json` has `task_type: "lean4"` and `keyword_overrides: null`; `typst/manifest.json` has `dependencies: ["core"]` and keyword_overrides whose keywords are all `typst `-prefixed.

== WHAT A LEAN BOOK IS (grounding) ==

Design record: `docs/book-convention.md` (2450 lines, 18 accepted decisions) plus `docs/architecture-decisions.md` decisions 2, 3, 8, 9.

A book is a certified unit inside a Lake package, not a directory. It is named by the `book <Name>` command in its book module, and `book.toml`'s `name` must equal it. Its modules are its book module's DIRECT imports, read from the `.olean` header — no module list is ever authored; every module of a package is imported directly by exactly one book module, and unassigned or doubly-assigned modules are certifier errors. Book module naming is `<Root>.Book` (single-book package) or `<Root>.Book.<Name>` (multi-book). The book directory is `<package-dir>/books/<name>/` holding `book.toml`, `book.cert.json` and `docs/`, while Lean sources stay in the package's `lean/` tree and are never moved. The consumer's unit of `require` is the package, the book is the trust/documentation/versioning unit, the module is the build unit.

Metadata split (Decision 6): facts in Lean, judgments in TOML, everything else computed. A code module carries exactly two things — `@[book_export]` on a declaration (no kind argument; kind is derived from `getOriginalConstKind?`) and one `book_layer <layer>` line. The book module carries everything else: `book`, `book_assume`, `book_not_claimed`, `book_axioms`, `book_policy`, `book_requires`, all read back by `#book_ledger`.

Twelve `book_layer` values (Decision 2): the eight layers `interface | laws | extraction | impl | instances | refinement | challenge | evidence` plus the four opt-in split tiers `impl.defs`, `impl.proofs`, `instances.defs`, `instances.proofs`. A may-import matrix (Decision 3) replaces a total order, enforced at elaboration by `book_layer` over DIRECT imports only, and at certification over the computed graph. `challenge` and `evidence` are terminal. Two universal rules sit OUTSIDE the matrix and are the certifier's responsibility, not `book_layer`'s: Mathlib/Aeneas confinement, and terminal layers.

`book.cert.json` sits directly in the book directory — never a `certificate/` subdirectory, because the framed_channel export tooling treats every `certificate` directory as a discovery root — and is THE ONLY INPUT of every non-Lean tool.

== DELIVERABLES ==

1. `manifest.json`: `name`/`version`/`description`; `task_type: "books"`; `dependencies: ["core", "lean", "typst"]` (literature arrives transitively through lean); `provides` for agents, skills, commands, rules, context (`project/books`), scripts and hooks; all four routing blocks keyed on `books`, with compound sub-routes for the lifecycle stages following lean's `lean4:lake`/`lean4:version` precedent (candidates `books:certify`, `books:document` — research decides the exact sub-route set; this description deliberately does not fix it); `keyword_overrides` (see the MANDATORY RESEARCH DECISION below); `merge_targets` for claudemd (`EXTENSION.md`, `section_id: extension_books`), index (`index-entries.json`) and opencode_json (`opencode-agents.json`).

2. Agents: at minimum a research agent and an implementation agent for the `books` task type, with `--hard` variants DECIDED (not assumed) by research, plus whatever the certify/document sub-routes need. Model tier per `docs/reference/standards/agent-frontmatter-standard.md`: Sonnet for workers.

3. Skills: the research/implementation pair plus the lifecycle skills the sub-routes name.

4. Commands: research decides the set. Strong candidates, each to be justified or dropped: a `/book` command driving author -> build -> test -> certify over one book, and a `/certify` command. Read the MANDATORY RECONCILIATION DECISION below before scoping anything reconciliation-shaped.

5. Rules: a `books`-scoped rule with a `paths:` frontmatter glob matching book directories, book modules and `book.toml`, carrying the non-negotiables — the facts-in-Lean/judgments-in-TOML split; the certificate as the only non-Lean input; explicit per-module lakefile `globs` and NEVER `Books.+` (both `books/lean` and `books/tool` use the root `Books`, so a wildcard glob makes each claim the other's modules and the build fails with "bad import 'Books.Meta'"); the licence-header-then-`module` line order (the proprietary header within the first three lines of every `.lean`/`.sh`; in a `module` file the comment is line 1 and `module` line 2, since a comment parses ahead of the `module` keyword, enforced by `components/framed_channel/scripts/check-spdx.sh`); never hand-editing a generated certificate or a generated Typst fragment; and never authoring a computed field.

6. `EXTENSION.md`, `index-entries.json`, `README.md`, `opencode-agents.json`.

7. Fixtures/tests under `scripts/tests/` for any script the extension ships, in the style of the lean and typst extensions' own suites.

== MANDATORY RESEARCH DECISION: task-type detection (possible OUT-OF-EXTENSION scope) ==

`books` keyword detection has a measured structural problem that research MUST resolve and record with evidence before anything is wired.

Measured by sourcing `agent-system/extensions/core/scripts/lib/task-type-detect.sh` and calling `detect_task_type` directly against the real `specs/state.json` and the real extensions directory:

```
"Certify the framed_channel book and reconcile its guarantees against the ledger" -> general
"Add book_layer to Interface.lean and declare book_export"                        -> lean4
"Author the book.toml v2 manifest and the three-tier docs entry"                  -> general
```

Two directional facts behind those outputs, both read from the script itself:

- Step 1 strong anchors resolve IMMEDIATELY, before the step 2 extension `keyword_overrides` scan. The lean4 strong anchors are `\.lean\b` (regex) plus the literals `mathlib`, `lean4`. So a `books` task description naming any `.lean` file, or Mathlib, can never reach a `books` keyword_override — it is captured by `lean4` unconditionally, no matter what `books` declares.
- The keyword_overrides scan iterates `<extensions_dir>/*/manifest.json` in alphabetical directory-name order, and the FIRST match wins and is FINAL (explicitly not subject to alias remapping). `books` sorts first among all 21 current extensions, so its overrides are scanned ahead of every other extension's — which means over-broad keywords (a bare "ledger", "guarantee" or "certify") would capture lean's, cslib's and typst's own tasks.

Research weighs at least these two branches and records the verdict with its evidence:

(a) Amend core's strong anchors in `scripts/lib/task-type-detect.sh` to recognise `book.toml`, `book_layer`, `book.cert.json`. This edits a file OUTSIDE `extensions/books/`, so it is ADDED SCOPE TO SPAWN, NOT TO ABSORB — do not touch core on this task's own authority.

(b) Narrow `keyword_overrides` to unambiguous multi-word book tokens (`book.toml`, `book_layer`, `book_export`, `book module`, `book.cert.json`, `layer matrix`, `certified unit`, ...) and rely on an explicitly-set `task_type` at task creation for the cases strong anchors preempt.

Whichever branch is chosen, the collision against lean's and typst's keyword sets must be explicitly checked and the check RECORDED — a `books` task would otherwise be silently captured by `lean4` or `typst`.

== MANDATORY RECONCILIATION DECISION (do not silently reimplement) ==

The Verification repository already carries a NOT STARTED task titled *"add reconcile command to agent system"* whose scope places: a `/reconcile [N | book...]` command and skill in the TYPST extension; a lifecycle postflight hook in the LEAN extension running the docs stage for every book in a finished task's file scope and offering reconcile-now / follow-up-task / skip; a write guard enforcing the reconciliation contract's file boundary; person-only signing; a Book-health section in `/review`; the manual's drifted chapters under the chapter-quality contract; and five fixtures (stale-by-digest, missing, orphaned, contract violation, and a red docs stage after the agent's edit).

The `books` extension is the more natural home for all of that. Research MUST explicitly decide whether those pieces move into `books` or stay where that task placed them, and MUST NOT silently reimplement them. If they move, that is added scope to spawn, not to absorb. Refer to that work by its title and deliverables only — never by a task number.

== WRITE AGAINST THE DESIGN RECORD, NOT THE HALF-LANDED TOOL ==

Write the extension against the design record (`docs/book-convention.md` and `books/schema/book-toml-v2.md`, both normative) rather than against the in-flight tooling, and NAME which of the extension's own pieces are blocked on the certifier's outstanding phases rather than assuming a finished certifier.

Landed and usable today:
- `books/lean/` — package `books`, library root `Books`, one module `Books.Meta` (413 lines): the metadata provider. Two persistent env extensions plus a fact extension, `@[book_export]`, `book_layer` with the matrix checked at elaboration, the six book-module fact commands and `#book_ledger`. Declares NO `require`. It is a PRIVATE import of code modules, since `public import Books.Meta` would make every consumer load `Lean`; only book modules and the certifier import it publicly.
- `books/tool/` — package `booksTool`, the `books-tool` lean_exe: `Books.Manifest` (the book.toml v2 validator), `Books.EnvWalk` (module-grain environment walker running a cheap header pass plus a record-of-truth pass, where a divergence is an error) and `Books.LayerCheck`. Invoked as `books-tool validate` and `books-tool check --lib <built lib dir>`.
- `books/tests/manifest/run.sh` — the fixture suite, driving the real `lake build`, the real elaborator and the real executable, with no copy of the provider's rules in the harness. Cases: BUILD, WF, TIERS, UNASSIGNED, DOUBLE, MATRIX-C (refused at certification), MATRIX-E (refused at elaboration, messages compared), DIVERGE, XBOOK, LEDGER, FORGE-A..D, WARN, MANIFEST.

NOT yet landed — phases 1-12 of the certifier's plan are complete, 13-23 outstanding: the certificate writer, `books/schema/book-cert-v2.md`, the shell driver, and the acceptance suite. Also only planned, named in `docs/development.md`: the certifier's docs stage emitting the documentation queue JSON, `books/tool/approve-guarantees.sh` (the only writer of `book.record.json`), and `books/tool/book-health.sh --json`.

`books/` at the repo root is a TOOLING directory, not a component: nothing there is digested, carries a certificate, or is depended on by a component gate.

Also in flight in Verification and defining the contracts this extension consumes: the ledger-tool-and-certifier build, the two-smallest-books pilot, the framed_channel book family, the documentation-honesty checks, the three-tier book documentation, the provider-side trust defences and the deferred certifier passes.

== FOLLOW-UP, NOT SCOPE ==

Enabling the extension in the Verification repo — adding `books` to its `.claude-extensions.json` extensions list via the loader picker — is the user's own action, not this task's work.

No task-number references in any file written into the source store: cite file paths, decision numbers and script names instead (`rules/no-task-references-in-deliverables.md`).


== SCOPE CORRECTION (amendment, routing blocks): AUTHOR TWO BLOCKS, NOT FOUR ==

Deliverable 1 above says "all four routing blocks" following the cslib precedent. That is
CORRECTED: author `routing_agents` and `routing_agents_hard` ONLY. Do NOT author `routing` or
`routing_hard`.

REASON, recorded so it is not re-derived: the routing-ladder collapse work -- titled *"collapse
the routing ladder to routing_agents-only across all extension manifests; retire
command-route-skill.sh"* -- is IN FLIGHT with status `implementing`, and it retires the `routing`
and `routing_hard` blocks across the extension manifests. Its own `file_scope` enumerates the
existing extension manifests individually but CANNOT list
`agent-system/extensions/books/manifest.json`, because the books extension does not exist yet.
So four-block routing authored here would not be swept by that work and the two stale blocks
would survive silently in the only manifest nobody is looking at.

This correction is deliberately a SCOPE NOTE AND NOT A DEPENDENCY EDGE. A dependency edge on the
routing-ladder collapse would block this task behind an in-flight task for no benefit; writing
two blocks instead of four removes the ordering constraint entirely and keeps this task
dispatchable with no unmet dependencies.

Consequence for the `--hard` variant decision already required above: `routing_agents_hard` is
still authored, so the question of whether books gets `--hard` agent variants is unchanged by
this correction.

Refer to the routing-ladder collapse work by its title and deliverables only, never by a task
number (`rules/no-task-references-in-deliverables.md`).

---

### 296. Repo hygiene: remove stale init.lua.backup, regenerate project-overview.md, fix README.md link
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: neovim
- **Dependencies**: None

**Description**: Review issues from all review on 2026-10-01 (grouped -- 3 independent small fixes, no shared file):

1. [medium] `init.lua.backup` - stale, tracked, byte-identical duplicate of `init.lua` (present since old task 516/518, pre-vault numbering).
   Impact: dead weight inviting confusion about which file is authoritative; silent drift risk if init.lua changes without the backup.
   Fix: delete init.lua.backup (git history already preserves prior states of init.lua), or move the backup convention to .gitignore if intentional.

2. [medium] `.claude/context/repo/project-overview.md` - still carries the `<!-- GENERIC TEMPLATE -->` notice despite 200+ archived tasks of repo history.
   Impact: any command/agent reading this file for repo orientation gets generic boilerplate instead of a real description.
   Fix: run /project-overview to generate a repo-specific version, then add context/repo/project-overview.md to .syncprotect per the file's own header instruction. Note: this file lives under .claude/context/repo/ -- confirm via .claude-extensions.json's source_dir whether it should be authored in a source store instead of hand-edited under .claude/** directly (source-store-deploy-boundary.md).

3. [low] `README.md:185` - links to a non-existent `.claude/README.md` ("For details on the agent system architecture... see [.claude/README.md](.claude/README.md)"). Only `.claude/CLAUDE.md` exists there, and it is itself marked "generated automatically... do not edit directly" rather than written as a navigable README.
   Impact: minor broken link for a reader following the architecture pointer from root README.
   Fix: point the link at `.claude/docs/docs-README.md` (the actual architecture entry point per .claude/CLAUDE.md's own Quick Reference) or at `.claude/CLAUDE.md` directly.

Related files: init.lua.backup, .claude/context/repo/project-overview.md, README.md

---

### 295. Add desc field to 44 keymap.set calls missing documentation
- **Status**: [NOT STARTED]
- **Task Type**: general
- **Topic**: neovim
- **Dependencies**: None

**Description**: Review issue from all review on 2026-10-01:

**File**: `lua/neotex/util/notifications.lua`, `lua/neotex/util/url.lua`, `lua/neotex/config/notifications.lua`, `lua/neotex/config/autocmds.lua`, `lua/neotex/config/keymaps.lua`, `lua/neotex/plugins/tools/luasnip.lua`, `lua/neotex/plugins/tools/autopairs.lua`, `lua/neotex/plugins/tools/mail.lua`, `lua/neotex/plugins/tools/himalaya/data/templates.lua`, `lua/neotex/plugins/tools/himalaya/data/search.lua`, `lua/neotex/plugins/tools/himalaya/ui/features.lua`, `lua/neotex/plugins/ui/neo-tree.lua`, `lua/neotex/plugins/ai/shared/extensions/picker.lua`
**Severity**: medium
**Description**: Of 88 `vim.keymap.set(...)` calls in active (non-deprecated) code, 44 (50%) have no `desc` field, violating CLAUDE.md's own Lua Code Style standard ("Keymaps: ... use vim.keymap.set with descriptive options") and the Neovim extension's Common Operations note ("Use vim.keymap.set with description for all keymaps"). Concentration: himalaya/ui/features.lua (10), plugins/ui/neo-tree.lua (8), himalaya/data/templates.lua (4), util/notifications.lua (4), himalaya/data/search.lua (2), config/notifications.lua (2), plugins/tools/luasnip.lua (2), plugins/ai/shared/extensions/picker.lua (2), and one each in util/url.lua, config/autocmds.lua, config/keymaps.lua, plugins/tools/autopairs.lua, plugins/tools/mail.lua.
**Impact**: Reduces discoverability via which-key/:map introspection; conflicts with the project's own documented standard.
**Recommended Fix**: Add a concise `desc` string to each flagged `vim.keymap.set` call, describing what the mapping does. Start with himalaya/ui/features.lua and plugins/ui/neo-tree.lua (18 of the 44 between them).

---

### 285. Add the missing .decisions.json writer script and correct the postflight handoff-recovery notice
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None
- **Research**: [285_decisions_writer_script_and_handoff_notice_accuracy/reports/01_decisions-writer-handoff-notice.md]
- **Plan**: [285_decisions_writer_script_and_handoff_notice_accuracy/plans/01_decisions-writer-handoff-notice.md]
- **Summary**: [285_decisions_writer_script_and_handoff_notice_accuracy/summaries/01_decisions-writer-handoff-notice-summary.md]

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/** (never .claude/**), per
rules/source-store-deploy-boundary.md.

Close two lead-facing contract-surface defects in the /orchestrate loop: .decisions.json has a
documented writer but no writer script, and the postflight handoff-recovery notice is both
mislabelled and factually wrong about which phases write a handoff.

Both observed live 2026-09-30, ~/Projects/Logos/Verification, session sess_1790791567_96a2e0.
They are grouped because they share one root: the orchestrate contract tells the LEAD either to
do something, or what just happened, and the instruction is unexecutable as written or untrue.

--- DEFECT 1: A DOCUMENTED WRITER WITH NO WRITER ---

docs/architecture/handoff-schema.md's "Decisions File Schema" section names the loop's own
branch move as the writer of specs/{NNN}_{slug}/.decisions.json, and
skills/skill-orchestrate/SKILL.md Move 4 instructs the lead to "Append each answer to that
task's specs/{padded}_{project}/.decisions.json per handoff-schema.md's 'Decisions File Schema'
section". No script implements it. Every comparable state write in this system goes through one
-- state-write.sh is the mutex-guarded single writer for state.json, update-task-status.sh for
status transitions -- so .decisions.json is the sole place a lead is told to hand-author JSON.

It is additionally the only place where the instruction and the schema live in DIFFERENT files:
Move 4 does not restate the shape, and the shape (a FLAT array of objects carrying question,
answer, cycle, timestamp) sits at handoff-schema.md circa line 960. A lead that follows Move 4
without opening that second file is guessing.

OBSERVED CONSEQUENCE. The lead wrote {"decisions":[...]} instead of [...]. The reader
(orchestrate-build-dispatch.sh:389-392) aborted; that script exited 5; orchestrate-cycle-plan.sh
deferred the task on two consecutive cycles of a five-cycle run with the message
`orchestrate-build-dispatch.sh failed; deferring to a later cycle`, naming neither the file nor
the expectation. Work-cycle budget was consumed for zero work, and the cause was found only by
re-running the planner with stderr captured.

DELIVERABLE 1a. Add the writer. The natural shape is
scripts/orchestrate-record-decision.sh --task N --session SID --cycle C --question TEXT
--answer TEXT, appending exactly one schema-valid entry, creating the file when absent, and
additive only -- handoff-schema.md is explicit that existing entries are never removed or
rewritten by a later append. scripts/system-defect-record.sh, already in this directory, is the
precedent to follow for an append-one-entry-to-a-JSON-file writer. Register the new script in
docs/reference/utility-scripts-inventory.md.
DELIVERABLE 1b. Repoint SKILL.md Move 4 at the script rather than at the prose schema, so the
lead never hand-authors this file. Keep the schema section as the reference for readers.
NOTE THE SPLIT, DO NOT DUPLICATE IT. The reader-side hardening at
orchestrate-build-dispatch.sh:389-392 -- a `length` gate that establishes neither emptiness nor
type before iterating -- is recorded on task 270 as a jq type-safety instance, with the evidence
from this same session. This task owns the AUTHORING surface only. Both should land; neither
blocks the other.

--- DEFECT 2: A RECOVERY NOTICE THAT IS MISLABELLED AND WRONG ---

scripts/orchestrate-cycle-postflight.sh:598 emits, on the research postflight:
  "RECOVERY: no handoff written for this dispatch -- expected outcome for this phase's writer
   (base-mode research/plan/implement never write one). .return-meta.json (fresh, within this
   dispatch window) reports status=researched; recovering the dispatch outcome from it."
Two problems in one sentence. (i) It carries the RECOVERY label, which the script also uses for
genuine degradation, while simultaneously declaring itself the EXPECTED outcome -- so a lead
cannot distinguish a normal path from a fault. (ii) The parenthetical is FALSE. In this same run
the base-mode PLAN dispatch and the base-mode IMPLEMENT dispatch each wrote a handoff, both
confirmed by the script's own following line, "dispatch_seq match (4) -- handoff confirmed as
this dispatch's own report", and the same at seq 5. So base-mode plan and implement do write
handoffs; on this evidence it is research alone that does not.

DELIVERABLE 2. Establish which phases actually write .orchestrator-handoff.json in base mode by
reading the writers -- do not trust this message and do not restate it. Then: correct the
parenthetical to match what the writers do; and split the notice by severity, so the expected
no-handoff path reads as an ordinary informational fallback naming the source it recovered from,
while a genuinely unexpected absence keeps the RECOVERY label and its current prominence. If the
answer is phase-dependent, name the phases in the message itself rather than generalising.

ACCEPTANCE. A lead can record a user decision with one documented script call and no knowledge
of the JSON shape, and a malformed .decisions.json is no longer reachable through the sanctioned
path. The new script is registered in the utility-scripts inventory, and SKILL.md Move 4 cites it
instead of the prose schema. The handoff notice's phase claim is verified against the writers and
matches them, and the expected and unexpected cases are distinguishable at a glance. shellcheck
clean per context/standards/shell-strict-mode.md.

DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 284. Exempt a task’s own directory from the postflight file_scope excursion advisory, so the aggregator signal it was built for is visible
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/** (never .claude/**), per
rules/source-store-deploy-boundary.md.

Make the postflight modified_files-vs-file_scope excursion advisory carry signal, by exempting
the dispatching task's own task directory -- which the lifecycle REQUIRES it to write.

DEFECT (observed live 2026-09-30, ~/Projects/Logos/Verification, session sess_1790791567_96a2e0,
an ordinary single-task /orchestrate run). The advisory fired on EVERY phase, each time naming
only the artifact that phase had been dispatched to produce:
  - research postflight: ["specs/160_.../reports/01_recentre-task-graph-three-layer-aim.md"]
  - plan postflight:     ["specs/160_.../plans/01_recentre-task-graph-three-layer-aim.md"]
Both are the canonical artifact paths mandated by CLAUDE.md's "Artifact Paths" section and
rules/artifact-formats.md. A task cannot close a phase WITHOUT writing them, so no task can ever
avoid the advisory: it is unconditional, and therefore carries zero information while training
the reader to ignore the channel.

SITE. scripts/orchestrate-cycle-postflight.sh:1121-1132. The excursion predicate at lines
1128-1129 compares reported modified_files against the declared file_scope alone; there is no
implicit member for the dispatching task's own specs/{NNN}_{slug}/ tree.

READ THE PROVENANCE BEFORE DESIGNING -- THIS IS NOT COSMETIC. This advisory is direction (a) of
task 100 (close_aggregator_file_scope_blind_spot), now ABANDONED and held in
specs/archive/state.json. Its purpose was specific and narrow: make an AGGREGATOR edit outside a
declared scope visible, after two lean4 tasks were each found editing a module aggregator that
appeared nowhere in their file_scope (one adding `import` plus a docstring index entry to
Metalogic/BXCanonical.lean, the other to Semantics.lean), where the omitted edit was
structurally required for the new module to be reachable from the build. Its acceptance read:
"an aggregator edit made outside a task's declared file_scope is no longer silent -- at minimum
it is reported against that task." As shipped, that genuine aggregator signal arrives in the
same channel as, and is outnumbered by, every task's own required artifacts on every phase. The
detection direction the abandoned task chose was sound; the filter is what defeats it.

ALSO REPAIR A DANGLING CROSS-REFERENCE. Task 270's "RELATED, DELIBERATELY NOT MERGED" paragraph
states that this excursion check's advisory-vs-blocking question "was recorded separately". The
separate record is abandoned task 100, so the follow-on is not live and the pointer misleads a
reader into believing it is. Repoint 270 at this task, or restate the status there.

DELIBERATELY NOT BUNDLED INTO 270. Task 270 owns the same file and says explicitly "Touching the
same file is not a reason to bundle it." Its subject is null/type-safety in jq guards; this is
filter correctness and signal quality. Honour that boundary in both directions: if 270's audit
finds null-safety problems INSIDE lines 1121-1132 it fixes those and leaves this filter alone.

DELIVERABLE. Exempt the dispatching task's own task directory from the excursion comparison. The
natural form is to add the resolved specs/{NNN}_{slug}/ prefix as an implicit file_scope member
for the duration of the check, so that no task ever has to declare its own artifact home. Decide
and RECORD whether the exemption covers the whole task directory or only the sanctioned artifact
subdirectories plus runtime dotfiles (reports/, plans/, summaries/, .dispatch/,
.return-meta.json, .orchestrator-handoff.json, .decisions.json); prefer the whole directory
unless there is a concrete reason that a task writing elsewhere beneath its own tree is worth
surfacing. Note that an archived task's directory moves to specs/archive/{NNN}_{slug}/ -- a
forced round dispatched against an archived task writes there, so resolve the exemption from the
task directory the dispatch actually used rather than assuming the active path.

SECOND, SEPARABLE QUESTION -- ANSWER IT OR DEFER IT EXPLICITLY. Once the channel is quiet, is
advisory still the right enforcement level, or should a genuine excursion gate? Task 165's
recorded prior art is the pattern: advisory-first, write down the promotion criterion, promote
only once coverage is complete. Deciding to STAY advisory and recording the threshold is a
defensible outcome and a real decision -- but it goes in the script header either way. Do NOT
promote to blocking in the same change that fixes the filter: a gate sitting on a
known-false-positive predicate would block correct work.

ACCEPTANCE. A single-task /orchestrate run through research, plan and implement produces ZERO
excursion advisories when every modified file is either inside the declared file_scope or inside
the task's own directory. A task that genuinely edits an undeclared file outside its own tree --
the aggregator case -- still produces exactly one advisory naming that file, demonstrated with a
concrete case rather than argued. The enforcement-level ruling and its reasoning sit in the
script header alongside the existing documentation. shellcheck clean per
context/standards/shell-strict-mode.md.

DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 282. Write-time PreToolUse hook blocking record-versioning language, registered bare so exit 2 survives
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 280, Task 281

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**, a disposable
deploy artifact -- see rules/source-store-deploy-boundary.md).

GOAL. Build the write-time enforcement consumer for the record-versioning rule: a PreToolUse hook
that blocks a Write/Edit introducing forbidden record-version language into a deliverable, driven
ENTIRELY by the shared pattern library, plus its fixture test and its settings.json registration.

DELIVERABLES:
(1) hooks/validate-no-record-versioning.sh -- modeled on hooks/validate-no-task-references.sh, whose
    header records three non-obvious contracts this hook must inherit verbatim:
      - BLOCK VIA EXIT CODE 2 + a stderr message, NOT via `permissionDecision: deny`, which is
        documented-buggy for allow-listed Write/Edit tool calls (settings.json carries bare
        "Write"/"Edit" permissions.allow entries; upstream issues #4669, #13214, #18312).
      - FAIL OPEN (exit 0, with a WARNING on stderr) if the shared library is missing OR fails to
        source. The sibling guards BOTH cases explicitly, because under `set -e` an unguarded `.`
        failure would abort before reaching the fallthrough. A broken guard must never block every
        write in the repo.
      - Resolve the library relative to the hook's own directory via BASH_SOURCE, so resolution is
        independent of the tool's cwd.
(2) hooks/... registration in root-files/settings.json, appended to the existing PreToolUse
    "Write|Edit" matcher block that already carries validate-no-task-references.sh. REGISTER IT BARE
    -- no `2>/dev/null || echo '{}'` wrapper. That wrapper converts exit 2 into exit 0 and silently
    disables the block; the sibling's header calls this out as a specific trap, and the PostToolUse
    entries in the same file DO use that wrapper, so the contrast is easy to get wrong by copying the
    wrong neighbor.
(3) scripts/tests/test-validate-no-record-versioning.sh -- fixture test modeled on
    scripts/tests/test-validate-no-task-references.sh.

=== THE ADVISORY TIER AT WRITE TIME -- RESOLVE THIS EXPLICITLY ===
A hook has only two outcomes (block or allow), so the taxonomy's advisory tier has no direct
write-time expression. Decide and RECORD the posture rather than leaving it implicit: the default
recommendation is that the hook blocks on BLOCKING-tier findings only and stays SILENT on advisory
ones, leaving advisory surfacing to the repo-wide lint. A hook that printed advisory noise on every
Write would train users to ignore it. If research concludes advisory findings warrant a
non-blocking stderr note instead, say so in the hook header and in the taxonomy's Enforcement
section, and keep the two documents consistent.

=== DEPENDENCY NOTE ===
Edges on both prior tasks. On the rule/taxonomy/library task: substantive -- there is no library to
source and no tier to honor until it exists. On the lint task: partly substantive, partly footprint.
Substantive because the lint is where the discriminator gets its first real-corpus exercise, and a
write-time blocker inheriting an unvalidated discriminator would block legitimate writes across the
repo -- the highest-cost failure mode in this batch. Footprint because both touch manifest.json.

=== WIRING ===
  - manifest.json: add the hook to provides.hooks and the test to the tests list (the sibling's
    entries are the `validate-no-task-references.sh` and `tests/test-validate-no-task-references.sh`
    lines).

ACCEPTANCE. Hook shellcheck clean per context/standards/shell-strict-mode.md. Fixture test covers:
blocking finding denied with exit 2 and an actionable stderr message naming the rule; a specs/**
path allowed; an advisory-only finding allowed; marker-exempted content allowed; and a
deliberately-broken/absent library failing OPEN with exit 0. settings.json registration verified
bare (grep the deployed-form command string for the absence of `|| echo` on this entry). After
registration, confirm an ordinary Write to a docs/ file carrying only durable-axis version language
(a toolchain pin, a schema filename, a CI cache key) is NOT blocked -- a false positive here is
worse than no hook. No task-number references in deliverables outside specs/**.

---

### 281. Repo-wide record-versioning lint with a blocking/advisory tier split, driven by the shared pattern library
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 280

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**, a disposable
deploy artifact -- see rules/source-store-deploy-boundary.md).

GOAL. Build the repo-wide lint consumer for the record-versioning rule: a script that scans every
git-tracked file outside specs/** for unexempted record-version language, driven ENTIRELY by the
shared pattern library, plus its fixture test.

DELIVERABLES:
(1) scripts/check-record-versioning.sh -- modeled line-for-line on scripts/check-task-references.sh,
    which is the established shape for this class of lint and already solves several problems worth
    inheriting rather than rediscovering:
      - scans via `git ls-files`, so gitignored/vendored/generated paths are excluded by
        construction (this is what keeps .claude/** out of scope automatically)
      - three exit codes with distinct meanings: 0 clean, 1 findings, 2 environment/usage error, so
        a broken invocation is never mistaken for a clean tree
      - `--quiet` summary mode and an optional positional PATH_SCOPE argument scoping the scan to a
        subtree or single file, where a nonexistent PATH_SCOPE prints [SKIP] and exits 0
      - a `REPO_ROOT=$(pwd)` source-store invocation override, required because
        .claude/scripts/... does not exist until a deploy runs
      - NO hard-coded directory list: the sibling's own header records "Default to Repo-Wide Scope,
        Never a Hard-Coded Directory List" as a design principle, so a consumer repo with any layout
        is scanned in full rather than scanning nothing.
(2) scripts/tests/test-check-record-versioning.sh -- fixture test modeled on
    scripts/tests/test-check-task-references.sh.

=== BLOCKING VS ADVISORY -- THE ONE GENUINELY NEW DESIGN SURFACE ===
The sibling lint has a single severity. This one does not: the tiering decided in the taxonomy means
findings split into BLOCKING (affect the exit code) and ADVISORY (reported, never affect the exit
code). Implement the tier split by consuming the library's per-category tier rather than
re-classifying here, and make the reporting format state the tier per finding. The precedent for
exactly this two-tier reporting contract already exists in this repo -- see
scripts/chapter-quality-check.sh and scripts/typst-element-lint.sh, both of which report advisory
findings without affecting the exit code -- so follow that established convention rather than
inventing a third.

=== DEPENDENCY NOTE ===
Edge on the rule/taxonomy/library task is SUBSTANTIVE, not merely footprint: this script defines
none of its own patterns, exemptions, or tiers, so there is nothing to consume until the library
exists and the taxonomy has fixed the per-category tiers. file_scope also overlaps on manifest.json
and on the library itself (tier refinement driven by what the real scan finds), and the edge
serializes that overlap rather than leaving it to chance.

=== WIRING ===
  - manifest.json: add the script to provides.scripts and the test to the tests list (the sibling's
    entries are the `check-task-references.sh` and `tests/test-check-task-references.sh` lines).
  - docs/reference/utility-scripts-inventory.md: catalogue the new lint there -- that file is the
    documented home for standalone repo-health/doc-lint scripts not invoked in the normal
    research/plan/implement lifecycle, per the CLAUDE.md "Utility Scripts" pointer.

ACCEPTANCE. Script shellcheck clean per context/standards/shell-strict-mode.md. All four sibling
behaviors present and exercised by the fixture test: clean tree, blocking finding, advisory finding
that does NOT change the exit code, and marker-exempted content. Running the lint with no arguments
against the Verification repo returns exit 0 (the de-versioning sweep is committed; a nonzero exit
means either a real miss in the sweep or a discriminator bug -- resolve which, do not relax the
pattern to make it green). Running it against docs/ci.md, docs/consuming.md,
docs/stability-and-versioning-policy.md and docs/setup-without-nix.md individually produces zero
BLOCKING findings, since those carry only durable-axis version language. No task-number references
in deliverables outside specs/**.

---

### 280. Forbid record-versioning language in deliverables: the rule, its exemption taxonomy, and the shared pattern library that discriminates draft history from durable version axes
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**, a disposable
deploy artifact -- see rules/source-store-deploy-boundary.md).

GOAL. State the policy that deliverables outside specs/ describe the CURRENT DESIGN ONLY and never
narrate their own draft history, and build the single mechanical source of truth that this rule's
two enforcement consumers (repo-wide lint, write-time hook) will both consume. This task produces
policy plus mechanism; the consumers are separate tasks and deliberately come later.

DELIVERABLES (three files plus wiring):
(1) rules/no-record-versioning-in-deliverables.md -- the rule, shaped EXACTLY like its sibling
    rules/no-task-references-in-deliverables.md: a "## Path Pattern" section, a "## Principle"
    section, an explicit exceptions list, and a closing pointer to the fuller taxonomy under
    context/standards/. Carry the sibling's deliberate no-`paths:`-frontmatter HTML comment
    rationale if the same universal-scope reasoning applies (it does: any deliverable in any
    location could receive version language).
(2) context/standards/record-version-exemptions.md -- the full taxonomy and enforcement narrative,
    the lazy companion the rule points at.
(3) scripts/lib/record-version-patterns.sh -- the ONLY place detection patterns, axis
    discrimination, and exemption logic are defined. Both later consumers source it and neither
    defines any of that locally. Model its header, its exported-variable shape, its
    `is_exempt_path`, and its `strip_exempt_regions` stdin/stdout filter on
    scripts/lib/task-reference-patterns.sh.

=== SUBSTANCE OF THE RULE -- RULED, DO NOT RE-OPEN ===
Deliverable files (docs/**, README.md, code, and other work product) must state the current design
only and must never narrate their own draft history. Specifically FORBIDDEN in deliverables:
  - page-level version labels in titles or status lines: "The X convention (v2)";
    "**Status**: v2, accepted <date>; supersedes v1"
  - "this is the second version" / "supersedes v1" framing
  - supersession or disposition tables mapping an earlier draft's decisions onto the current ones
  - "(v1 Decision N)" attributions attached to rejected alternatives
  - phrasing relative to an unstated past: "no longer", "previously", "formerly", "used to",
    "carried forward from v1", "withdrawn", "every v1 field removed"

Rejected alternatives are KEPT -- they are the point of a decision record -- but stated on their own
merits rather than attributed to an earlier draft of the same document.

=== EXEMPT ZONES -- RULED, VERSION LANGUAGE IS PERMITTED, NO MARKER NEEDED ===
1. Everything under specs/** -- task descriptions, plans, reports, summaries, `completion_summary`
   fields, TODO.md, state.json, ROADMAP.md. THIS IS THE PRIMARY EXEMPTION and was confirmed
   explicitly by the owner.
2. Git commit messages; PR/branch metadata.
3. Three DURABLE NON-RECORD version axes that are not draft history:
   (a) software/toolchain versions -- `Lean v4.31.0`, `actions/checkout@v4`, `schema = 2` semantics
   (b) file-format and schema versions -- `book.toml` `schema = 2`, `books/schema/book-toml-v2.md`,
       `book-cert-v2.md`
   (c) CI cache-key epoch segments -- `pnpm-v1-`, `lake-recheck-v3-` in docs/ci.md
4. An explicit, DATED cross-document amendment note in a decision record, recording that a decision
   the record OWNS was amended -- docs/architecture-decisions.md's "**Amended by** <doc>, <date>:"
   house style. This records a real change to an accepted decision, not a draft lineage, and MUST
   stay permitted. (Verified present: docs/architecture-decisions.md carries exactly one such note.)

Beyond these four, an exception requires EXPLICIT USER PERMISSION. Provide a marker convention for a
user-permitted exception mirroring the sibling's `task-ref-ok` marker: a block form
(`version-ok:begin` ... `version-ok:end`, matched as plain substrings so comment syntax is
irrelevant) and an inline form, both requiring a trailing reason naming a taxonomy category. Name
the marker in the taxonomy and implement its stripping in the shared library, not in either
consumer.

=== THE HARD DESIGN PROBLEM -- THIS IS WHAT THE TASK IS ACTUALLY ABOUT ===
The forbidden vocabulary OVERLAPS HEAVILY with the legitimate uses in exempt zone 3: `v1`/`v2`
appear in toolchain pins, CI cache keys and schema filenames, so a naive regex is noisy. The shared
library must DISCRIMINATE the record-version axis from the three durable axes. Verified footprint in
the Verification repo at the time of writing: eight files under docs/ plus README.md match a bare
`\bv[0-9]\b`, and docs/book-convention.md still legitimately carries 4 such mentions AFTER the sweep
-- so the discriminator's job is to return zero findings on that already-clean tree while still
catching the patterns in the FORBIDDEN list above. It is ACCEPTABLE for some categories to be
ADVISORY rather than BLOCKING; decide the tier per category in the taxonomy and encode the tiering
in the library so both consumers inherit it rather than each choosing. The bare-past-tense
vocabulary ("no longer", "previously", "formerly", "used to", "withdrawn") is the most
false-positive-prone category and is the leading advisory candidate.

=== RATIONALE TO RECORD IN THE RULE (cite durable anchors, no task numbers) ===
docs/book-convention.md shipped carrying 68 v1/v2 mentions across 1,705 lines, a 22-line "How this
record relates to v1" supersession table with 15 disposition rows, eight "(v1 Decision N)"-attributed
rejected alternatives, and an "Every v1 field removed" migration table -- while BOTH "versions" were
dated the same day and nothing in the repository had ever been built against v1 (no `book.toml`
existed anywhere). The file documented its own authoring process rather than its design, and the
label leaked outward into docs/architecture-decisions.md (5 references), docs/README.md,
specs/ROADMAP.md and eight open task descriptions in state.json. It was also off house style: every
other decision record in docs/architecture-decisions.md carries a bare "**Status**: accepted, <date>"
with no page version. The de-versioning sweep is already committed -- see the commit titled "docs:
state the book convention without version history" -- and this rule is the durable guard against
recurrence.

=== WIRING (do not skip; the sibling occupies all of these surfaces) ===
  - manifest.json: add the rule to provides.rules, the standard to provides.context, and the library
    to provides.scripts (the sibling's entries are at the `no-task-references-in-deliverables.md`,
    `standards/task-reference-exemptions.md` and `lib/task-reference-patterns.sh` lines -- follow
    their exact shape).
  - index-entries.json: add a discovery entry for the standard, modeled on the existing
    `standards/task-reference-exemptions.md` entry (path, summary, keywords).
  - merge-sources/claudemd.md: add the rule to the "Rules References" core-rules list beside the
    `no-task-references-in-deliverables.md` line, so the deployed CLAUDE.md advertises it.

ACCEPTANCE. Rule file structurally parallel to its sibling (same four sections, same pointer
discipline). Taxonomy standard enumerates every category with its blocking/advisory tier and
documents the marker convention. Shared library is shellcheck clean per
context/standards/shell-strict-mode.md, exports its patterns and both exemption helpers, and is
sourceable standalone. All three manifest/index/claudemd surfaces wired. A one-off manual run of the
library's discriminator over the Verification repo's docs/ and README.md returns zero BLOCKING
findings (the sweep is committed, so a green tree is the expected baseline and any finding is either
a real miss in the sweep or a discriminator bug -- resolve which before closing). No task-number
references in deliverables outside specs/**.

---

### 275. Per-repo orchestration queue: registered, live, archived on finish, and consumed by admission
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: orchestrator
- **Dependencies**: Task 272, Task 51

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**, a disposable deploy artifact -- see rules/source-store-deploy-boundary.md).

GOAL. Register orchestrations in a per-repo queue whose metadata stays current, archive them when
they finish, and expose the queue as an admission input so a new orchestration runs when it does
not conflict and is refused with named alternatives when it does.

=== SEMANTICS -- RULED, DO NOT RE-OPEN ===
REGISTRY PLUS IMMEDIATE REFUSAL. The queue is a live record of in-flight orchestrations plus an
archive of finished ones. A conflicting new orchestration is REFUSED IMMEDIATELY, with the conflict
named and alternatives suggested. There is NO WAITING QUEUE, NO SCHEDULER, NO AUTO-START and NO
UNATTENDED EXECUTION. Do not design enqueue-and-wake machinery. "Queue" here means the registry and
its archive, not a work queue that something drains.

SCOPE -- RULED: PER-REPO. One queue per repository, living beside the existing session registry. No
cross-repo global queue and no global-ready schema requirement: file_scope conflicts are inherently
per-repo, so a global queue would carry no information the per-repo one lacks.

=== WHAT THIS OWNS ===
The record schema; the lifecycle states registered -> running -> finished -> archived; keeping the
record's metadata current while an orchestration runs; archiving on completion; and exposing the
queue as an admission input.

This task TAKES OVER PIECE 4 OF TASK 272 IN FULL: per-orchestration identity distinct from
`session_id`, so two batches in two sessions of one repo keep separate
metadata/artifacts/return-meta rather than a single shared in-flight record. That piece has been
removed from 272's scope and lives here.

=== VERIFIED GROUNDING IN THE SOURCE STORE ===
(1) THERE IS NO ORCHESTRATION-LEVEL RECORD TODAY, AND NO HISTORY WHATSOEVER. task-lock.sh's
    `cmd_session_release` is a bare `rm -f "$sessions_dir/${session_id}.json"` -- a finished
    session's entry is DELETED, not archived. Nothing anywhere records that an orchestration ever
    ran. The archive half of this task is therefore genuinely new construction, unlike the live
    half.
(2) NO `orchestration_id` CONCEPT EXISTS anywhere in scripts/, context/, skills/ or commands/
    (measured: zero occurrences). The unit of identity today is `session_id`, and ONE SESSION CAN
    COVER SEVERAL TASK NUMBERS -- observed live, a single session covering 696, 701, 703, 704, 649
    and 650 in one repo. That many-to-one relation is exactly why an orchestration-level id is
    needed and why `session_id` cannot serve as one.
(3) BUILD ON THE EXISTING SESSION REGISTRY, DO NOT REPLACE IT. specs/.sessions/{session_id}.json
    with session-register / session-heartbeat / session-release / session-reap / session-list is
    the substrate.
(4) REUSE THE EXISTING LIVENESS VOCABULARY -- DO NOT TRANSCRIBE A SECOND COPY. `session_liveness()`
    already computes six reasons: `corrupt`, `dead-pid`, `dead-pid-within-grace`, `stale-heartbeat`,
    `pid-alive`, `undeterminable`, governed by two thresholds
    (SESSION_REGISTRY_DEAD_PID_MIN, SESSION_REGISTRY_REAP_MIN) in a documented evaluation order
    (dead-pid tested first). Its own header records that it was factored out precisely so
    cmd_session_list and session_contention() consume the IDENTICAL verdict rather than a second
    transcription. A queue entry's liveness must consume that verdict for the same reason.
(5) ARCHIVAL LOCATION MUST BE SETTLED WITH TASK 51, which relocates the per-session runtime files
    out of the specs root and owns scripts/reap-session-runtime-files.sh,
    context/standards/orchestrator-runtime-files.md and scripts/check-runtime-file-tracking.sh.
    Task 51's own text warns against creating a fourth orphaned naming generation -- an
    independently-chosen archive path here would be exactly that. ALSO check how skills/skill-todo/
    archives tasks, so orchestration archival follows the established convention rather than
    inventing a new one.

=== DEPENDENCY NOTES ===
Edge on 272 is SUBSTANTIVE, not footprint: a queue whose metadata silently stops updating is worse
than no queue at all, so the zero-heartbeat defect (272's piece 1) must be diagnosed before this
queue relies on heartbeat-driven currency. Edge on 51 is substantive too: it relocates the runtime
files this queue lives among and owns the relevant standard. Both droppable per the standing
convention if either stalls -- but if 272 is dropped, record what currency guarantee the queue
assumes in its absence.

file_scope OVERLAP IS DELIBERATE: this task shares scripts/task-lock.sh,
scripts/command-gate-in.sh and context/patterns/task-lock.md with 272. The dependency edge on 272
serializes that overlap rather than leaving it to chance.

NEW SCRIPTS: add a queue script and its test under scripts/ if research concludes one is warranted.
Name them in the plan; do not pre-commit to them here.

ACCEPTANCE. A record schema with its lifecycle states documented to the standard of the existing
session-registry contract in context/patterns/task-lock.md; finished orchestrations demonstrably
archived rather than rm -f'd, at a location agreed with task 51's relocation; queue-entry liveness
shown to consume `session_liveness()`'s verdict rather than recomputing it; the queue readable as an
admission input; a fixture test covering registered -> running -> finished -> archived and the
refusal path. Shellcheck clean per context/standards/shell-strict-mode.md. No task-number references
in deliverables outside specs/**.

---

### 274. Next-admissible-batch suggestion and alternatives-on-conflict, both computed by invoking the real admission script
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: orchestrator
- **Dependencies**: Task 272, Task 273, Task 275, Task 165

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**, a disposable deploy artifact -- see rules/source-store-deploy-boundary.md).

GOAL. The orchestration concludes by suggesting the next most natural batch of tasks to run after
clearing context, computed from the dependency DAG PLUS file_scope disjointness -- i.e. a batch that
scripts/orchestrate-batch-admit.sh would ACTUALLY ADMIT together, so the user can open a fresh
session and run it directly.

=== TWO MODES, ONE PREDICATE ===
MODE A -- NEXT-BATCH AT CONCLUSION (the original scope above): at the end of an orchestration,
suggest the next most natural batch to run after clearing context.

MODE B -- ALTERNATIVES ON CONFLICT (added): when an orchestration is REFUSED for conflicting with
an in-flight one, suggest nearby task sets that could run in parallel instead. Same predicate as
mode A, DIFFERENT TRIGGER -- refusal time rather than conclusion time. Alternatives are drawn from
the orchestration queue (task 275), which is why this task depends on it.

WHAT THE ADMISSION SCRIPT DOES AND DOES NOT GIVE YOU. scripts/orchestrate-batch-admit.sh emits a
PER-CANDIDATE verdict and, for an idle overlapping task, an `idle_overlap_advisory` naming the
colliding task, its status, the overlapping path and the collision scope. It has NO NOTION OF
ALTERNATIVES: it answers "may this candidate set run?", never "what else could run instead?".
The alternatives search is therefore a NEW CALLER-SIDE LOOP over candidate sets, NOT a change to
the script's verdict schema. Do not extend the schema to carry alternatives.

BINDING CONSTRAINT ON HOW THE SUGGESTION IS COMPUTED. The predicate must be established by ACTUALLY
INVOKING scripts/orchestrate-batch-admit.sh over candidate sets and reading its v5 verdicts --
never by re-implementing, approximating, or duplicating its logic. A second copy of the admission
predicate would drift from the real one, and a suggestion the real script then refuses is worse
than no suggestion at all. Respect the existing verdict schema and its consumers
(scripts/orchestrate-predispatch-review.sh is one) rather than extending the schema.

DEPENDENCY NOTES.
- Edge on task 275 (hard, substantive): mode B's alternatives are drawn from the orchestration
  queue, so there is nothing to draw from until 275 exists.
- The existing edge on task 272 is now TRANSITIVELY REDUNDANT, since 275 itself depends on 272.
  It is left in place deliberately -- a redundant edge is harmless and costs only a wave, whereas
  removing it would obscure why live registry scope matters to this task. Do not "clean it up".
- Edge on task 272 (hard, substantive): the suggestion is only trustworthy if the session
  registry's file_scope is LIVE rather than frozen at register time, and if a live-but-stale lock
  is visible as held. Computing a "safe next batch" against a stale registry snapshot produces
  confidently wrong suggestions -- worse than offering none.
- Edge on task 273 (hard): this suggestion is rendered by 273's conclusion stage, and both tasks
  edit skills/skill-orchestrate/SKILL.md, so the edge is footprint-corroborated as well as logical.
- Edge on task 165 (hard, substantive): 165 rules on whether an ABSENT file_scope is
  admission-relevant. That ruling directly changes which batches this task would suggest -- today a
  task with no declared scope is indistinguishable from one that provably collides with nothing, so
  a suggester built before the ruling would confidently propose batches the post-ruling script
  refuses. 165 also owns orchestrate-batch-admit.sh, this task's primary input. Per the standing
  convention, DROP THE EDGE rather than hold this task if 165 stalls -- but if it is dropped, record
  which absent-file_scope posture the suggester assumed.

ACCEPTANCE. A suggested batch is verified by running the real admission script over it and showing
every member admitted; a fixture where two candidates collide on file_scope demonstrably does NOT
appear as a joint suggestion; no copy of the admission predicate exists anywhere in the new code;
shellcheck clean per context/standards/shell-strict-mode.md. No task-number references in
deliverables outside specs/**.

---

### 273. Three-channel orchestration conclusion stage with per-channel approval, as a distinct post-postflight stage
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: orchestrator
- **Dependencies**: Task 271, Task 184, Task 329

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**, a disposable deploy artifact -- see rules/source-store-deploy-boundary.md).

GOAL. Every orchestration concludes by proposing three channels of follow-on work, each fired ONLY
on that channel's own separate explicit user approval:
  (a) DIRECT FIXES to make now, executed by a final cleanup agent;
  (b) AGENT-SYSTEM CHANGES, routed to meta-builder-agent;
  (c) FOLLOW-UP TASKS to create, routed to a task agent, recorded as CHILDREN of the originating
      task via the `parent_task` edge.
No channel may fire on another channel's approval, and none may fire without one.

ANTI-BYPASS CONSTRAINT ON CHANNEL (b) -- NOT RELAXED BY THIS FEATURE. meta-builder-agent must keep
CREATING TASKS rather than editing .claude/ or the source store directly. The constraint in
commands/meta.md and skills/skill-meta/SKILL.md stands unchanged: the conclusion stage may hand it
a change request, but it still produces tasks in specs/, never implementation.

THIS MUST BE A DISTINCT POST-POSTFLIGHT STAGE WITH ITS OWN BOUNDARY CONTRACT -- NOT SMUGGLED INTO
POSTFLIGHT. context/standards/postflight-tool-restrictions.md today prohibits Edit on *.md outside
specs/ and on .claude/** non-specs, and confines postflight Bash to state-write.sh, git add/commit,
and two `rm -f` marker deletions; AskUserQuestion is likewise outside that contract.
skills/skill-orchestrate/SKILL.md:287 carries a `## MUST NOT (Postflight Boundary)` section.
Channels (a) and (b) would violate both if folded into postflight. The new stage therefore needs
its own explicitly written allowed/prohibited table in that standard, stating that it runs AFTER
postflight has closed state and committed.

=== OPEN QUESTION FOR THE RESEARCH PHASE: RECONCILE WITH TASK 184'S RULING ===
THIS MUST BE SETTLED WITH A WRITTEN VERDICT BEFORE PLANNING. The contradiction may NOT be left
standing in both task descriptions.

Task 184's ruling of 2026-09-22 states verbatim:
    "do NOT auto-create tasks: the report is the handoff and the user files them with /task"
Channel (c) as requested REVERSES that operative clause. Both candidate resolutions are live:

  RESOLUTION A -- NARROW OVERTURN. The ruling's implicit premise was that auto-creation is
  UNAPPROVED creation. Per-channel explicit approval removes that premise: user-approved creation
  is not auto-creation. On this reading 184 was right for a report-only postflight (where
  AskUserQuestion is outside the boundary contract anyway) and wrong for an interactively-gated
  post-postflight stage. 184's scope would be rewritten to match rather than left contradictory.

  RESOLUTION B -- SCOPE-LIMITED COEXISTENCE. Task 184 governs one specific payload (skeleton-plan
  sorry_inventory[].follow_up_task entries surfaced from orchestrate-cycle-postflight.sh, reported
  plus recorded in an append-only state.json field), while this task governs conclusion-stage
  follow-ups generally. The two stay distinct. Cost: two adjacent mechanisms produce follow-ups by
  two different routes, and someone reconciles them later regardless.

PRIOR ANALYSIS, RECORDED AS A RECOMMENDATION AND NOT AS THE DECISION: the /meta prompt-mode
analysis that filed this task recommended Resolution A ("overturns, narrowly"), on the grounds
stated above, and judged that the reversal should be named plainly as a reversal rather than
presented as an extension. The research phase is not bound by that recommendation and must reach
its own verdict.

DEPENDENCY NOTE. The edge on task 184 is a HARD dependency: shared footprint on
scripts/orchestrate-cycle-postflight.sh and context/standards/status-markers.md, plus the
substantive ruling conflict above. Its own dependency chain was verified CLEAR at filing time --
242, 243, 258 and 259 are all in specs/archive/ (directories
242_orchestrate_partial_with_blocker_stops_redispatch,
243_reconcile_research_handoff_writer_contract,
258_fix_postflight_recovery_decline_attribution,
259_allow_completion_on_a_gate_skipped_plan_branch), each carrying an implementation summary rather
than an abandonment note, and 266 is completed -- so nothing unresolved is inherited. Per the
standing convention, DROP THE EDGE rather than hold this task if 184 stalls.

The edge on task 271 is also hard and is NOT droppable: channel (c) creates tasks AS CHILDREN, which
is structurally impossible before the `parent_task` edge is declared, validated and rendered.
Without 271 this stage would write a field nothing reads.

ACCEPTANCE. A written verdict on the 184 reconciliation before planning begins, with the losing
resolution's rationale recorded. The stage's own allowed/prohibited table lands in
postflight-tool-restrictions.md to the same standard as the existing postflight table. Each of the
three channels demonstrably cannot fire without its own approval, covered by a test. The
meta-builder-agent anti-bypass constraint is shown still to hold for channel (b). Documented in
docs/architecture/orchestrate-state-machine.md. Shellcheck clean per
context/standards/shell-strict-mode.md. No task-number references in deliverables outside specs/**.

=== AMENDMENT 2026-10-03: THE THREE CHANNELS ARE DERIVED FROM THE PER-TASK ISSUE LOGS ===

Nothing above is withdrawn or rewritten. This amendment supplies the EVIDENCE BASE the conclusion
stage's proposals are built from, which was unspecified when this task was filed.

A new dependency has been added: the per-task issue log task (task 329), which introduces an
append-only `specs/{NNN}_{SLUG}/issues.jsonl` written by `scripts/issue-record.sh` from both
dispatched agents and the orchestrator, surviving the per-dispatch overwrites of
`.return-meta.json` and `.orchestrator-handoff.json`. That task is CAPTURE ONLY by design: it
surfaces nothing to the user mid-run and acts on nothing. Review is THIS stage's job and only this
stage's job.

THE DERIVATION. This stage's three channels are not composed from the orchestrator's recollection
of the run. They are DERIVED FROM THE PER-TASK ISSUE LOGS OF THE TASKS THE RUN TOUCHED:

  - Every entry whose `resolution` is `open` or `worked_around` is classified into EXACTLY ONE of
    the three channels -- (a) what can be fixed now directly; (b) what follow-up tasks are called
    for in the local repository; (c) what agent-system upgrades are needed, routed via /meta.
    Exactly one: an entry may not appear in two channels.
  - The entry's own `suggested_channel` field is a HINT. The ORCHESTRATOR'S JUDGMENT IS THE
    DECISION. A hint that is overridden should be overridden visibly, not silently.
  - RECURRING CLASSES ACROSS TASKS ARE GROUPED INTO ONE PROPOSAL. Three tasks hitting the same
    class is one proposal citing three entries, never three proposals. This is the main reason the
    derivation is worth doing at all: the recurrence is invisible from any single task.
  - Entries with `kind: "win"` ARE SUMMARISED, NEVER ACTIONED. Positive signals belong in the
    report so the user can see what the convention bought; they generate no channel item.
  - REVIEW HAPPENS ONLY AT THIS STAGE, NEVER MID-RUN. This is the complement of the issue log's
    capture-only contract, and the two must not drift: if a mid-run surface is ever added, it is
    added here by amendment, not improvised in the writer.
  - EACH PROPOSAL CITES ITS ISSUE-LOG ENTRIES -- task number plus entry identifier -- so the user
    can audit the proposal against its evidence before approving that channel. A proposal with no
    citation is not presentable.

The per-channel explicit-approval contract above is unchanged by this amendment: deriving a
proposal from evidence is not approval to fire it.

---

### 272. Honest session liveness for concurrent same-repo batches: diagnose why the wired heartbeat never fires, add a live-but-stale lock state, re-derive registry scope, and give each orchestration its own identity
- **Effort**: medium
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: orchestrator
- **Dependencies**: Task 51

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**, a disposable deploy artifact -- see rules/source-store-deploy-boundary.md).

GOAL. Let different batches of tasks be orchestrated CONCURRENTLY in different sessions of the same
repo when there is no file_scope collision and no dependency edge between them, with each
orchestration keeping distinct metadata rather than sharing one in-flight record.

THE DECISION LAYER IS ALREADY SOUND -- DO NOT REWORK IT. Measured live in ~/Projects/BimodalLogic:
scripts/orchestrate-batch-admit.sh returned a correct v5 verdict for a real candidate,
  {"decision":"defer","defer_reason":"file_scope_collision", plus colliding_task_number,
   colliding_task_status, overlapping_path, "collision_scope":"cross_batch",
   "corroborated_by":["non_terminal_status","session_registry"]}
alongside an `idle_overlap_advisory` for an idle overlapping task. The gap is the layer BENEATH
this verdict. MUST NOT modify scripts/orchestrate-batch-admit.sh -- that surface belongs to
task 165, which is already scoped to it.

=== PIECE 1 (SCOPE-DETERMINING, DO THIS FIRST): IS THE HEARTBEAT SILENCE A ROUTING REGRESSION OR A DESIGN GAP? ===

THE MECHANISM ALREADY EXISTS AND IS WIRED. DO NOT BUILD A SECOND ONE. The per-task heartbeat is
called at scripts/update-phase-status.sh:223:
    hb_out=$(bash "$tl_path" heartbeat "$task_number" "$hb_sid" 2>&1) || hb_rc=$?
seventeen lines above the `session-heartbeat` call at line 240, in the same function, with its own
`_hb_trace "heartbeat" "$hb_verdict"` verdict line and its own no-op classifier (`no-lock`,
`session-mismatch`, `unknown`). It is invisible to a naive grep only because the script path is
held in the variable "$tl_path". An implementer who believes the mechanism is missing will build a
redundant second one alongside it.

MEASURED EVIDENCE (the function writes ${repo_root}/.agent-logs/heartbeat-trace.log):
  ~/Projects/BimodalLogic: 580 trace lines, 580 of them `heartbeat ok`, covering 26 task numbers
      -- ALL from EARLIER sessions.
  ~/.config/nvim:          2740 trace lines, 2723 `ok`, 15 `noop:no-entry`, 2 `noop:no-holder`.
  BUT: ZERO trace lines for EITHER in-flight task of the currently-running BimodalLogic session --
      neither the modal-substrate task (lock acquired 2026-09-29T14:57:11Z) nor the Typst
      lean-code-environment task in that same session produced a single line, despite eleven
      phase-completion commits having landed for the former.
  AND: its .lock/holder.json shows acquired_at == heartbeat_at == 2026-09-29T14:57:11Z exactly, so
      `never_heartbeated=true` is literal, not approximate.
  AND: the `noop:session-mismatch` verdict exists in the classifier but appears ZERO times in
      either repo's log -- so the no-op paths are NOT absorbing these calls. The function is not
      being ENTERED at all.

WHY THIS ORDERING MATTERS. The silence is SESSION- or DISPATCH-PATH-scoped, not task-scoped: two
in-flight tasks in one session both traced zero while every earlier session traced cleanly. Cadence
therefore cannot explain it for either task. A routing regression in the currently-running
orchestrate loop is a SMALL fix; a design gap is not. ESTABLISH WHICH BEFORE SCOPING THE REST OF
THIS PIECE. Secondary and genuinely real regardless of that answer: the heartbeat is reachable only
via a phase-status change, so a task sitting in one long phase emits nothing between transitions --
close that with a time-based or dispatch-boundary trigger. Also consider consuming the `_hb_trace`
verdicts, which are written today and read by nothing.

=== PIECE 2: A THIRD LOCK STATE FOR STALE-HEARTBEAT-BUT-PID-ALIVE ===
Observed live: `task-lock.sh check <N>` reported `held-stale session=... heartbeat_age_min=33
threshold_min=30 never_heartbeated=true` while `session-list` reported that SAME session
`live:true, liveness_reason:"pid-alive"` (pid 1015099). cmd_acquire's held-lock overlap pass
degrades to WARN-and-proceed on a stale lock, so a lock belonging to a demonstrably LIVE session
became advisory purely because its heartbeat drifted. Decide whether stale-but-pid-alive should be
a THIRD state distinct from both `held` and `held-stale`, and implement the ruling.

PRECEDENT TO REUSE, NOT TO INVENT AROUND. The distinction piece 2 needs ALREADY EXISTS one level
up: `session_liveness()` computes six reasons -- `corrupt`, `dead-pid`, `dead-pid-within-grace`,
`stale-heartbeat`, `pid-alive`, `undeterminable` -- governed by two thresholds
(SESSION_REGISTRY_DEAD_PID_MIN, SESSION_REGISTRY_REAP_MIN) in a documented evaluation order, and
its own header records that it was factored out so cmd_session_list and session_contention()
consume the IDENTICAL verdict rather than a second transcription. THE GAP IS THAT THE PER-TASK
LOCK HAS NO SUCH DISTINCTION: cmd_check emits only `held-fresh` (line 1033) and `held-stale`
(line 1036), each carrying heartbeat_age_min, threshold_min and never_heartbeated but NO
pid-liveness dimension at all. So piece 2 is bringing an existing, tested session-level vocabulary
down to the per-task lock -- a smaller and better-shaped change than inventing a third state from
scratch. Consume `session_liveness()`'s verdict; do not transcribe it.

CRITICAL CONSTRAINT -- KEY ON session_id, NEVER ON pid. Task 165's absorbed text records that both
sessions in its incident reported the SAME pid with pid_source `ancestor-claude`, because two
/orchestrate runs inside one Claude Code process share an ancestor. The failing task's own
holder.json likewise shows pid_source `ancestor-claude`. A self-exclusion keyed on pid would treat
a foreign session as self and silently disable cross-session detection for the most common case.

=== PIECE 3: RE-DERIVE THE REGISTRY'S file_scope ON HEARTBEAT ===
scripts/command-gate-in.sh:106 registers the session with a task-number CSV, and the union
file_scope is computed AT REGISTER TIME ONLY; `session-heartbeat` refreshes heartbeat_at and
nothing else. So widening a task's file_scope after registration leaves the registry snapshot
permanently narrow. Observed live: the registered scope lacked
FormalSystem/Metalogic/Decidability/PlusWitnessFamily/Incompleteness.lean, which that task's
state.json file_scope does declare. Decide whether the registry should re-derive on heartbeat and
implement it.

=== PIECE 4 HAS MOVED OUT OF THIS TASK ===
Per-orchestration identity (an orchestration-id distinct from session_id, with per-orchestration
metadata/artifacts/return-meta rather than one shared in-flight record) was originally piece 4 of
this task. It now lives IN FULL in task 275, the per-repo orchestration queue, which DEPENDS on
this task. Do not implement it here. This task is pieces 1-3 only: diagnose the unreachable
heartbeat, add the live-but-stale lock state, re-derive registry scope on heartbeat.

DEPENDENCY NOTE. The edge on task 51 is substantive, not merely footprint serialization: 51
relocates the per-session orchestration runtime files (specs/.orchestrator-multi-state-*.json,
specs/.return-meta-multi-*.json) that Piece 4's per-orchestration metadata extends, and it owns the
same two files this task edits (scripts/task-lock.sh,
context/standards/orchestrator-runtime-files.md). Building Piece 4 before 51 lands risks creating
exactly the fourth orphaned naming generation that 51's own text warns against.

ACCEPTANCE. Piece 1's routing-regression-versus-design-gap question answered in writing before any
fix lands, with the answer visible in the trace log or an equivalent probe. A fixture test
reproduces the two-live-sessions overlap case and the stale-but-pid-alive case, and fails against
the current scripts. No change to orchestrate-batch-admit.sh. Existing consumers of task-lock.sh's
output lines (which read them as prefixes/substrings) keep working. Shellcheck clean per
context/standards/shell-strict-mode.md. No task-number references in deliverables outside specs/**.

## ABSORBED AT CREATION-TIME RECONCILIATION (two defects, with evidence)

These two items were drafted as a separate task and folded in here instead, because this task already states the same goal and owns the session-registry trust question. Both are newly verified live; neither was stated by this task before.

(a) CLASS E CONTENTION REVIEW IS DEAD ON ARRIVAL. `commands/orchestrate.md` mints `batch_session_id` AFTER it calls `orchestrate-predispatch-review.sh`, so `--session-id` is never passed and that script's Class E (session-registry contention) section prints `SKIPPED (no --session-id supplied to this script; orchestrate-batch-admit.sh's session-registry input was itself skipped via its own D6 degradation)` on EVERY run. Reproduced live. This is the only surface designed to warn an operator, before dispatch, that another live batch already covers the candidate files -- precisely the capability this task's GOAL section describes. Remedy: mint the session earlier in `commands/orchestrate.md` and pass `--session-id` through. Note the ordering subtlety: the review runs BEFORE `session-register`, so self-exclusion is a no-op on the caller's own not-yet-registered id, which is harmless and still surfaces OTHER live sessions correctly.

(b) STALE, SELF-CONTRADICTING BATCH MESSAGE. The MAX_TASKS guard prints "Batching is not yet supported. Running with first $MAX_TASKS tasks only." at `commands/orchestrate.md` line 235 and `docs/architecture/orchestrate-state-machine.md` line 714. Batching is the DEFAULT -- `context/patterns/batch-orchestration-guardrails.md` opens with a "Batching Is the Default" section. This is the message an operator sees exactly when pushing batch size, so it misleads at the worst moment. Text-only fix.

ALSO OBSERVED (bears on this task's heartbeat diagnosis): `specs/.sessions/` currently holds five dead registry entries dating to 2026-09-08, all reading `live:false / liveness_reason:dead-pid`, never reaped, plus a leftover `specs/.contention-manifest/` directory. `session-reap` is explicit-invocation-only by deliberate design (`task-lock.sh` line 184) and no lifecycle site calls it. They are correctly EXCLUDED today because their PIDs are dead, so this is not presently a false-defer -- but PID recycling would make a leaked entry read as live and false-defer a candidate indefinitely. Argue the reap-policy choice (opportunistic on `session-register` vs. wired into `/refresh`'s documented sweep) rather than assuming either; the current restriction is intentional.

FILE_SCOPE WIDENED by this absorption: `commands/orchestrate.md`, `scripts/orchestrate-predispatch-review.sh`, `docs/architecture/orchestrate-state-machine.md`. The first and third overlap open tasks #273 and #265, so the admission gate will serialize against them -- expected and correct, not a defect.

---

### 271. Finish the parent_task edge: declare it in the schema, validate it, render it in TODO, and make it survive renumbering
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: orchestrator
- **Dependencies**: Task 269, Task 279

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**, a disposable deploy artifact regenerated by the loader -- see rules/source-store-deploy-boundary.md).

GOAL. Finish the `parent_task` edge so that follow-up and spawned tasks can be recorded as CHILDREN of their originating task, as a parent/child relation DISTINCT from the existing `dependencies[]` array.

THIS IS NOT GREENFIELD -- IT IS A HALF-BUILT FIELD WITH TWO PRODUCERS AND ZERO CONSUMERS. Verified in the source store:
  PRODUCERS (already write it):
    - skills/skill-spawn/SKILL.md:380  ("parent_task": $parent)
    - commands/task.md:833             (/task --review follow-up creation)
    plus declared intent in commands/spawn.md:117, agents/spawn-agent.md:176,195
      (as `parent_task_number`), context/orchestration/delegation.md:657,673
  CONSUMERS (all absent -- measured, 0 occurrences each):
    - context/schemas/state-schema.json          0  (field is written but UNDECLARED)
    - scripts/validate-state.sh                  0  (no orphan/cycle checking)
    - scripts/generate-todo.sh                   0  (invisible in TODO.md)
    - context/reference/state-management-schema.md 0 (undocumented)
  NOT A CONSUMER DESPITE APPEARANCES: scripts/generate-task-order.sh has 10 "parent" hits, but
  they are union-find / graph-parent identifiers (lines 459, 464-468, 479, 486) plus two display
  strings ("indented = depends on parent", lines 513 and 881). None reads `parent_task`.

NO MIGRATION BURDEN. Live count of entries carrying `parent_task` in this repo: 0, across both
`active_projects` and `completed_projects`. There is no legacy population to backfill, which makes
this a clean moment to declare the field properly rather than after it has accumulated data.

PREMISE CORRECTION (added after the paragraph above; that paragraph is REPO-LOCAL and does not
generalize). The "live count 0 / no legacy population to backfill" finding holds for THIS
repository only. In the BimodalLogic consumer repo, SIX active entries carry `parent_task: 165`
-- 410, 411, 412, 428, 429 and 430 -- recording real expansion lineage (which task each was split
from). So a deployed consumer repo DOES have a population, and two consequences follow for the
work items above:
  - Work item (2)'s orphaned-parent and cyclic-parentage checks must be designed against a real
    population, not a greenfield one. Note in particular that `parent_task: 165` points at a task
    that is itself still active in that repo, and that four of the six children are `not_started`
    while 428 is `blocked` -- so the checks will encounter live, mid-lifecycle parentage, not just
    settled history.
  - The "clean moment to declare the field properly rather than after it has accumulated data"
    framing no longer applies globally: the data has already accumulated somewhere the loader
    deploys to. Decide whether declaring the field needs an accompanying consumer-side backfill or
    validation pass, and whether an entry whose `parent_task` points at an ARCHIVED or renumbered
    task is an error, a warning, or expected.
Evidence gathered read-only from that repo; it is a separate repository with its own task system
and is not an edit target for this task.

RELATED, SEPARATELY TRACKED. `parent_task` is one of NINE state-schema.json validation failures in
that same consumer repo (`validate-state.sh`: 8 passed, 13 warnings, 9 failed). The other eight
fields -- top-level `active_goal`, `artifacts`, `last_updated`, `metadata`, and entry-level
`blockers`, `previous_status`, `researched`, `resume_phase` -- are ruled on by their own task,
which deliberately EXCLUDES `parent_task` because this task already owns it. That task sets a
per-field widen/migrate/retire policy and a hard constraint that no non-null value may be deleted
without recording where the information went; this task's work item (1) should follow that policy
rather than deciding independently. The two tasks share state-schema.json and validate-state.sh in
their file_scope, so whichever lands second must re-read both files.

WORK ITEMS.
(1) Declare `parent_task` in context/schemas/state-schema.json and document it in
    context/reference/state-management-schema.md, stating explicitly that it is NOT a dependency
    edge: a parent may complete before its children, and parentage must never affect dispatch
    eligibility or the Kahn-algorithm dependency waves.
(2) Add orphaned-parent and cyclic-parentage checks to scripts/validate-state.sh. Follow the
    ADVISORY-FIRST precedent recorded at plan-format.md:259-266 (the Verification Tier rollout):
    a missing or dangling value emits a warning rather than an error, `--strict` enforces, and the
    PROMOTION CRITERION is written down at the same time as the check.
(3) Decide what scripts/generate-task-order.sh and scripts/generate-todo.sh render for parentage.
    CONSTRAINT: generate-task-order.sh's existing indentation already means "depends on parent" in
    the DEPENDENCY sense (its own display strings say so). Parentage rendering must not collide
    with or be mistaken for that. Consider whether parentage belongs in the Task Order tree at all
    versus the per-task TODO.md entry.
(4) Settle renumber survival. scripts/deprecated/vault-operation.sh step 5 renumbers active tasks
    by subtracting 1000 and rewrites `dependencies`, but nothing anywhere handles `parent_task`, so
    a renumber would silently dangle every parentage edge. PRIOR QUESTION TO ANSWER FIRST: that
    script lives under scripts/deprecated/, so establish whether renumbering is a live path at all
    before writing code for it. If it is dead, say so and record that parentage stability rests on
    numbers never being rewritten; if it is live, fix it.

DEPENDENCY NOTE. The edge on task 269 is a FOOTPRINT-SERIALIZATION edge only, on
scripts/validate-state.sh, not a substantive dependency: 269 is a one-line null-safety fix
(presence test -> type test) in that same file. Per the standing convention, DROP THE EDGE rather
than hold this task if 269 stalls.

ACCEPTANCE. The field is declared in the schema and documented; validate-state.sh detects an
orphaned parent and a parentage cycle, advisory-first with a written promotion criterion; the TODO
rendering decision is recorded with its rationale (including a decision NOT to render, if that is
the ruling); the renumber question is answered either way in writing; shellcheck clean per
context/standards/shell-strict-mode.md. No task-number references in deliverables outside specs/**.

RENDERER QUIRK TO FOLD IN (observed 2026-09-29, not a separate task). The Task Order tree
already renders the string "parenttask" -- the underscore stripped by generate-task-order.sh's own
truncation path -- while state.json and the TODO.md task heading both hold "parent_task" correctly.
This is a pre-existing defect in the very script this task is scoped to touch, so fix it as part of
the rendering work item rather than filing it separately.

---

### 265. Run Gate 8 in parallel inside verify-deploy.sh via run-all.sh --jobs
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 165, Task 266, Task 316
- **Research**: [265_parallelize_gate8_shell_test_suite/reports/01_gate8-parallel-and-inline-verify.md]
- **Plan**: [265_parallelize_gate8_shell_test_suite/plans/01_gate8-jobs-and-inline-verify.md]
- **Summary**: [265_parallelize_gate8_shell_test_suite/summaries/01_gate8-jobs-and-inline-verify-summary.md]

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**).

=== WHAT TO CHANGE ===
scripts/verify-deploy.sh line 558 (gate8) currently invokes the shell test suite with no --jobs:

  run_all_output=$(cd "$TARGET" && bash "$TARGET/agent-system/extensions/core/scripts/tests/run-all.sh" --quiet 2>&1)

so it inherits run-all.sh's JOBS=1 default and runs fully sequentially. Make Gate 8 use the
opt-in parallelism that already exists in run-all.sh.

=== MEASURED FACTS (already committed, do not re-measure from scratch) ===
- Gate 8 alone costs ~9m21s of an ~11m03s full verify-deploy.sh run (~86% of the run).
- The shell-test-suite parallelism task added opt-in `--jobs N|auto` to run-all.sh, with a
  JOBS_CAP (4), longest-first scheduling, deterministic output ordering, and a nested-invocation
  guard that forces JOBS=1 when run-all.sh is reached from inside a suite that itself calls
  verify-deploy.sh (see run-all.sh header lines 34-140). Measured 449s -> 187s at --jobs 4 (58%
  reduction) with an identical pass/fail set to --jobs 1.

=== WHY THIS MECHANISM AND NOT THE OTHER ONE (record this reasoning) ===
The sibling redundant-verify-passes task attacked the same cost differently: capture Gate 8 ONCE
per redeploy checkpoint and share the snapshot across the pre/post/confirm passes. That was
REJECTED in its Phase 1 precondition audit because Gate 8 is NOT invariant across a
deploy-headless.sh call -- 41 of 73 files under scripts/tests/ prefer the DEPLOYED copy of their
subject-under-test over the source-store copy, so a pre-deploy snapshot and a post-deploy
snapshot are legitimately measuring different things. The rejected design and its evidence are
recorded in context/patterns/batch-orchestration-guardrails.md; read it before proposing
anything snapshot-shaped here.

Making each Gate 8 run FASTER requires no invariance premise at all, so it sidesteps the exact
reason the sharing design failed. That is the justification for this task existing, and it
should survive into the plan's rationale section.

=== CRITICAL DEPENDENCY TO RESOLVE, NOT ASSUME ===
Parallel-run safety is NOT yet empirically established. The parallelism task's Phase 6 was the
flakiness decision gate -- 3 repeated full-suite runs at --jobs 4, checked against Phase 1's
recorded baseline pass/fail set and against a named set of load-sensitive suites -- and it did
NOT complete: it was interrupted by genuine system-wide memory pressure. That task remains
PARTIAL with Phases 6 and 7 outstanding, and the user has chosen NOT to resume it for now.

Therefore this task must choose ONE of:
  (a) carry that 3-run validation itself, as an explicit EARLY phase that gates every later
      phase, before line 558 is touched at all; or
  (b) declare a hard dependency on the parallelism task's Phase 6 completing.

DECIDE THIS IN RESEARCH/PLANNING. Do not pre-decide it, and under no circumstances change
line 558 on unvalidated parallel safety. No dependency edge is recorded on this task's
`dependencies` field precisely because recording one would pre-decide option (b).

=== ALSO SETTLE ===
- What job count Gate 8 should request: a fixed N, `auto`, or inherit from an env var. Note that
  `auto` resolves to nproc capped at JOBS_CAP=4 (run-all.sh:121-130).
- Whether an environment override is needed for CI or low-memory hosts, and if so its name,
  precedence, and documented default.
- The load-sensitive suites named by the parallelism task's Phase 4 audit -- carry that list
  forward rather than rediscovering it.
- That test-run-all-parallel.sh's own timing assertions were ALREADY redesigned from absolute
  thresholds to load-tolerant relative ratios after flaking under ambient host load. Do not
  regress them to absolute timings, and do not read a ratio-based assertion as a weakened one.
- Interaction with run-all.sh's nested-invocation guard: verify-deploy.sh IS reached from inside
  some suites, so confirm the guard still forces JOBS=1 on those paths and that the new call site
  does not defeat it.

=== VERIFICATION ===
1. The pass/fail set under the new invocation is IDENTICAL to the sequential baseline set. Report
   both sets, not just a count.
2. Report before/after wall times for a full verify-deploy.sh run (no --skip-slow), measured on
   the same host.
3. --skip-slow still skips Gate 8 entirely (verify-deploy.sh:551) -- unchanged.
4. The deploy-consumer and missing-run-all.sh branches (verify-deploy.sh:553-556) are unchanged.
5. scripts/tests/ passes, including test-deploy-verify-wiring.sh,
   test-verify-deploy-gate-selection.sh, and test-run-all-parallel.sh. No test may be weakened,
   skipped, or deleted to make the change pass.


=== ABSORBED 2026-09-28 (path review, fifth pass) from former task 267 (suppress_inline_verify_in_deploy_headless); that task is abandoned into this one. Its text follows verbatim; where it names "the dependency task" or "the sibling task", read this task's other sections. ===

SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**).

=== THE REDUNDANCY ===
scripts/deploy-headless.sh runs its OWN inline verification after deploying ("Verifying deploy
(fast gates; shell test suite deferred)") -- a `verify-deploy.sh --skip-slow` pass, measured at
~1m35s (deploy-headless.sh:402 `local -a VERIFY_ARGS=(--skip-slow)`, invoked at :406).

When deploy-headless.sh is called from scripts/orchestrate-cycle-plan.sh's Inter-Cycle Redeploy
Checkpoint, the checkpoint then runs its OWN pre/post/confirm verify-deploy.sh passes. The inline
pass is duplicated work on that path.

=== THIS WAS ALREADY EVALUATED AND DEFERRED -- CONFRONT THE REASONS, DO NOT REPEAT THEM ===
The redundant-verify-passes task explicitly considered this and ruled it OUT OF SCOPE for two
stated reasons. Both are real and both must be answered here, not rediscovered:

1. deploy-headless.sh was not in that task's declared file_scope. (Procedural only -- it IS in
   this task's file_scope.)
2. Its exit-3 contract has many callers that depend on it. Exit 3 means RESULT=landed_verify_red:
   the deploy LANDED but the resulting tree FAILS verification (deploy-headless.sh:96, :108,
   :160, :454). That exit code is derived from precisely the inline run being discussed, so the
   inline verify cannot simply be deleted. The checkpoint's own branch contract consumes exit 3.

=== POINTS TO SETTLE -- DO NOT PRE-DECIDE ===
- Whether to add an OPT-IN `--no-verify` / `--skip-verify` flag that ONLY the redeploy checkpoint
  passes, leaving every other caller's exit-3 contract byte-identical. Opt-in (rather than
  opt-out) is the shape that makes "no other caller changes" a structural guarantee instead of a
  claim, but argue it rather than assuming it.
- What EXIT CODE a deploy-with-verification-suppressed should return, such that no caller can
  silently misread it as verified-green. A suppressed verify is not a passed verify, and 0 may be
  the wrong answer. Consider a distinct RESULT= token alongside whatever code is chosen, matching
  the existing RESULT= convention at :108.
- ENUMERATE EVERY CALLER of deploy-headless.sh and state what each does with exit 3. The known
  set of source files referencing it includes: verify-deploy.sh, orchestrate-cycle-plan.sh,
  orchestrate-build-dispatch.sh, orchestrate-batch-admit.sh, command-gate-out.sh, skill-base.sh,
  deploy-root-guard.sh, check-deploy-freshness.sh, check-consumer-freshness.sh,
  check-extension-docs.sh, validate-state.sh, git-snapshot.sh, task-lock.sh,
  measure-eager-context.sh, system-defect-record.sh, lib/deploy-baseline-lib.sh, plus tests
  (test-deploy-verify-wiring.sh, test-postflight-deploy-gate.sh, test-deploy-propagation.sh,
  test-deploy-orphans.sh, test-deploy-freshness.sh, test-lint-deploy-caller-wrap.sh,
  test-double-loading-check.sh, test-orchestrate-build-dispatch.sh, test-orchestrate-cycle-plan.sh,
  test-validate-state.sh) and docs (architecture/extension-system.md,
  architecture/orchestrate-state-machine.md, reference/utility-scripts-inventory.md). Verify that
  list rather than trusting it -- some references are mentions, not invocations, and the
  distinction matters.
- Whether run-all.sh's new `--only-gate` flag makes a CHEAPER TARGETED inline verify a better
  answer than suppression outright. A narrowed inline verify keeps the exit-3 contract meaningful
  while removing most of the duplicated cost, which may dominate suppression on every axis. Weigh
  it explicitly and record the comparison either way.
- Note that test-lint-deploy-caller-wrap.sh exists specifically to police how callers wrap
  deploy-headless.sh; any new flag or exit code must satisfy it, or the lint must be extended
  deliberately and with reasoning, never relaxed.

=== VERIFICATION ===
1. Every caller NOT passing the new flag observes byte-identical behavior and exit codes,
   including exit 3. Demonstrate this, do not assert it.
2. The redeploy checkpoint's total wall time is measured before and after, on a checkpoint that
   actually fires (cycle_modified_files touching agent-system/**). Report both numbers.
3. A deploy whose tree genuinely fails verification is still detectable by the checkpoint --
   suppression must not create a path where a red tree is treated as green.
4. The suppressed-verify exit code / RESULT token is distinguishable from verified-green in a
   test.
5. scripts/tests/ passes, including test-deploy-verify-wiring.sh,
   test-lint-deploy-caller-wrap.sh, and test-orchestrate-cycle-plan.sh. No test may be weakened
   or deleted to make the change pass.

=== FILE-FOOTPRINT DEPENDENCIES (auto-added, overlap-derived) ===
This task's file_scope overlaps both sibling tasks: scripts/tests/test-deploy-verify-wiring.sh is
shared with the Gate 8 parallelization task, and scripts/orchestrate-cycle-plan.sh plus
scripts/tests/test-orchestrate-cycle-plan.sh are shared with the deploy-pending/dispatch-guard
task. Both edges are serialization-only, not semantic -- rebase on whatever they land.

=== PATH REVIEW 2026-09-28 (fifth pass): premise update and ordering ===
The parallelism task this text calls PARTIAL is COMPLETED (2026-09-26): its Phase 6 flakiness gate ran three repeated --jobs 4 full-suite runs, found two load-sensitive suites unreliable only under sustained heavy contention (five concurrent agent sessions), and closed COMPLETED WITH EXCLUSIONS without flipping the serial default. Option (b) above is therefore already satisfied; do not re-run a 3-run gate from scratch -- cite that task's recorded pass/fail sets and carry its named load-sensitive suites forward.
WHY THIS IS HIGH LEVERAGE (measured 2026-09-28): the Inter-Cycle Redeploy Checkpoint in orchestrate-cycle-plan.sh takes its pre/post (and confirm) findings snapshots at FULL depth -- never --skip-slow -- so Gate 8 (~9 min of an ~11 min run) is paid two to three times per checkpoint fire, on top of deploy-headless.sh's own inline --skip-slow pass (~1.5 min). Every self-modifying task in this repo fires that checkpoint. The checkpoint runs at the one boundary with no dispatch in flight, so ambient agent load there is minimal -- the condition under which --jobs 4 reproduced the sequential pass/fail set exactly.
PHASES: (A) Gate 8 --jobs (choose a conservative default plus an env override; document; verify --skip-slow and nested-guard paths unchanged); (B) the absorbed inline-verify question in deploy-headless.sh (opt-in flag vs. --only-gate-narrowed inline verify; exit-code contract preserved for every other caller). Serialized behind the deploy-pending/identical-dispatch fix because both touch orchestrate-cycle-plan.sh's checkpoint.

=== SERIALIZATION EDGE ADDED 2026-10-02 (dependencies: 165) ===
Serialization-only, not semantic: this task does not consume any output of the admission-posture task. The edge exists solely to pin the roadmap Call A implement order 165 -> 265 -> 263, which the engine would otherwise resolve as 165 -> 263 -> 265 by its lowest-task-number self-modification tie-break. All three declare orchestrator-critical paths, so only one is admitted per cycle regardless; the edge chooses WHICH. Rebase on whatever the admission-posture task lands in orchestrate-cycle-plan.sh. This edge is unrelated to, and does not reopen, the option-(a)/(b) parallel-safety question recorded above -- that was settled by the path review and remains settled.

---

### 263. Consent-gated git push: grant semantics and enforcement mechanism
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 139, Task 265
- **Research**: [263_consent_gated_git_push/reports/01_consent-gated-push-design.md]
- **Plan**: [263_consent_gated_git_push/plans/01_consent-gated-push-enforcement.md]
- **Summary**: [263_consent_gated_git_push/summaries/01_consent-gated-push-enforcement-summary.md]

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**, a disposable
deploy artifact -- see rules/source-store-deploy-boundary.md).

=== GOAL ===
Make `git push` permissible by an agent ONLY after the user answers an interactive
AskUserQuestion gate granting permission for that specific push. The prohibition stays the
DEFAULT. Permission must never be inferred from a task description, from a prior approval in
another context, or from a user message that merely sounds permissive.

=== CURRENT STATE (verified 2026-09-25, source store) ===
rules/pr-prohibition.md has frontmatter `paths: "**/*"` (with a why-eager comment explaining the
universal glob is deliberate), so it applies repo-wide. It bans three classes:
  1. PR/MR creation (`gh pr create`, `glab mr create`, any API/wrapper equivalent)
  2. `git push` in ALL forms, explicitly including `--force`, `--set-upstream`, `-u`
  3. autonomous `/merge` invocation
Its "Required Behavior" section says agents MUST stop at `[PR READY]`, report readiness, and wait
for the user to invoke `/merge`, and states verbatim: "Never push branches or create PRs even if
asked to in task descriptions or user messages." That sentence is the one this change must
narrow -- carefully, because it is also the sentence that currently makes the rule
un-social-engineerable.

Other places the prohibition is asserted, all of which must stay consistent:
  - rules/git-workflow.md "Git Safety > Never Run" bullet: "`git push --force` to main/master"
  - merge-sources/claudemd.md: `/merge` and `/tag` marked "(user-only)" in the command table
    (lines ~111, ~114), `skill-tag | (user-only)` in the skill table (~153), and the
    "User-Only Skills" note (~165)
  - context/standards/git-integration.md and git-safety.md contain NO push references (checked) --
    so the rule surface is narrower than it might appear; do not assume otherwise without
    re-checking.

=== MECHANISMS THAT ALREADY EXIST AND SHOULD BE EXTENDED, NOT REINVENTED ===
  - scripts/git-commit-scoped.sh -- the single sanctioned path-scoped, mutex-serialized committer.
    This is the structural model for a push wrapper: one sanctioned entry point, everything else
    blocked.
  - hooks/guard-destructive-git.sh -- an existing PreToolUse Bash hook that already blocks two
    command classes (destructive-on-dirty-tree, and over-staging). Read its header in full: it
    documents that it blocks via `exit 2` + stderr, NOT `permissionDecision: deny`, because the
    latter is documented-buggy for allow-listed `Bash(git:*)` commands (GH #4669, #13214, #18312).
    Any new push guard must use the same blocking mechanism for the same reason.
    It also documents a critical asymmetry to respect: the snapshot-marker exemption applies to
    the destructive class but is FORBIDDEN from exempting the over-staging class, because a
    snapshot makes data loss recoverable while over-staging is a scope problem a snapshot does
    not make acceptable. Decide deliberately which side a push grant resembles.
  - scripts/git-snapshot.sh -- its marker-file contract is a working precedent for a ONE-SHOT
    authorization token: a fresh marker (<=120s) authorizes exactly one destructive command and is
    CONSUMED (deleted) on use. Evaluate this as the grant-token shape before designing a new one.
    Note its known observation boundary, documented in guard-destructive-git.sh: a hook only ever
    sees the top-level `tool_input.command` string, so a `git push` run as a subprocess inside a
    wrapper script is structurally invisible to the hook. That is what makes the
    wrapper-plus-hook pair work, and it is also the bypass to reason about.
  - context/standards/interactive-selection.md -- the AskUserQuestion schema and option-
    construction standard the gate must conform to.

=== DESIGN QUESTIONS TO SETTLE (these are the research/plan work; they are deliberately NOT
pre-decided) ===
  1. GRANT SCOPE: one push only, or session-scoped, or task-scoped? What INVALIDATES an existing
     grant -- new commits after the grant, a different branch, a different remote, a change from
     non-force to force? State the invalidation predicate precisely enough to implement.
  2. WHETHER PR/MR CREATION AND `/merge` FOLLOW THE SAME GATE OR STAY FULLY USER-ONLY. Working
     assumption to ARGUE FOR OR AGAINST, not to assume: push is the narrow case being opened;
     PR creation and `/merge` stay prohibited. Whichever way this lands, say why.
  3. CATEGORICAL EXCLUSIONS: are `--force` and `--force-with-lease`, and pushes to the default
     branch (master), outside what ANY grant can cover? Note the repo's default branch is master
     and rules/git-workflow.md already singles out force-push-to-master as a "Never Run".
  4. WHERE THE GATE LIVES SO IT CANNOT BE BYPASSED. A rule edit alone is documentation, not
     enforcement -- this is the central requirement. Design the enforcement pair: a wrapper/guard
     script analogous to git-commit-scoped.sh, plus a PreToolUse hook blocking bare `git push`
     call sites the way guard-destructive-git.sh already blocks its two classes. Confirm the hook
     registration shape in manifest.json against the existing registered hooks.
  5. DURABLE AUDIT RECORD: how the grant request and the user's actual answer are recorded so the
     consent is auditable after the fact. Candidates: a `.decisions.json` entry per the handoff
     schema's Decisions File Schema, and/or a specs/events.jsonl record. Record enough to
     reconstruct WHAT was authorized (remote, branch, commit sha, force-or-not) and WHEN, not
     merely that someone said yes.

=== EXPLICIT NON-GOALS ===
Do not implement the orchestrator-dispatch path here -- a dispatched subagent cannot call
AskUserQuestion, and routing that request is the companion task's scope. This task must, however,
define the grant semantics and guard interface that companion task consumes, and should state
that interface explicitly rather than leaving it implicit.

=== VERIFICATION ===
1. A bare `git push` from an agent is BLOCKED by the hook, with a stderr message naming the
   sanctioned path. Demonstrate the block, do not merely assert it.
2. A push attempted with NO grant present is blocked.
3. A push attempted with an INVALID grant (per whichever invalidation predicate is chosen --
   e.g. stale, wrong branch, wrong remote, commits added since) is blocked. Test each
   invalidation condition the design defines.
4. A categorically excluded push (force, and/or default-branch, per decision 3) is blocked EVEN
   WITH an otherwise-valid grant.
5. A push with a valid, in-scope grant succeeds through the sanctioned wrapper.
6. The audit record is written and contains enough to reconstruct what was authorized.
7. The fail-safe direction is BLOCK: an unreadable, absent, malformed, or unverifiable grant
   must block, never permit. Test the malformed case explicitly.
8. `git push` remains prohibited by default with no grant mechanism invoked -- i.e. existing
   agent behavior is unchanged unless a user actively grants.
9. Re-run the shell test suite under scripts/tests/. No existing test may be weakened or deleted
   to make this pass; a test that asserts the OLD blanket prohibition must be updated
   deliberately, with its new assertion stated in the summary.

=== VERIFIED MECHANISM MAP (surveyed 2026-09-25; use these, do not re-derive) ===
THE PROHIBITION IS CURRENTLY RULE TEXT ONLY -- THERE IS NO MECHANICAL ENFORCEMENT AT ALL.
This is the single most important finding and it reframes the work. Verified:
  - `grep -rln "git push|gh pr create|glab mr create" hooks/ scripts/` over the source store
    returns EMPTY. No hook, script, or lint blocks any of the three prohibited classes.
  - No test under scripts/tests/ (76 files) invokes `git push` or `gh pr create` against a hook to
    assert blocking. Matches for "push" there are incidental (`git stash push`; "push bytes past a
    ceiling"; an unrelated "hand-patch prohibition" string in test-orchestrate-build-dispatch.sh).
  - scripts/check-extension-docs.sh Rule H `check_undeclared_rules()` (~line 508-524) asserts only
    STRUCTURAL registration -- that rules/pr-prohibition.md is declared in manifest.json's
    `provides.rules` so it propagates to consumers. Its motivating comment records that the rule
    once existed on disk while absent from provides.rules, so it "never propagated downstream".
    That is a propagation check, not a behavioral one.
  So the guard being added here is NET-NEW enforcement, not a modification of existing
  enforcement. Consequence worth stating plainly in the plan: this change can leave the system
  STRICTER than it found it (a real hook where there was only text), even while narrowing the
  rule's stated scope. Design for that outcome deliberately.

HOOK REGISTRATION -- the wiring is NOT where you would first look:
  - manifest.json `provides.hooks` (~line 260-280) is a FLAT FILENAME LIST only
    ("guard-destructive-git.sh" among ~19 others). It carries no PreToolUse wiring.
  - merge-sources/settings-hooks.json (the deep-merge fragment applied into a consumer repo's
    .claude/settings.json) registers only `matcher: "Write|Edit"` ->
    validate-no-task-references.sh. It carries NO Bash-matcher entry.
  - root-files/settings.json is the template that actually carries the Bash-matcher registration
    for guard-destructive-git.sh (~line 44-52), shaped as a PreToolUse array entry with
    `matcher: "Bash"` and one `{"type":"command","command":"bash .claude/hooks/<script>.sh"}`.
  A new push guard must be added in BOTH manifest.json `provides.hooks` (so it deploys) AND the
  correct settings template (so it is wired). Missing either yields a silently inert hook -- which
  is precisely the failure mode Rule H exists to catch for rules.

ONE-SHOT MARKER CONTRACT (the reusable grant-token precedent), verified in
scripts/git-snapshot.sh + hooks/guard-destructive-git.sh:
  - Path: `specs/{NNN}_{SLUG}/.git-snapshot-marker`, task-scoped, gitignored via
    `**/.git-snapshot-marker`.
  - Format: line-oriented KEY=VALUE, minimally `TIMESTAMP=<epoch seconds>`, plus tool-specific
    payload fields (HEAD_SHA, PATCH_PATH, STASH_REF, BRANCH_NAME, UNTRACKED_BACKUP).
  - Freshness: `FRESHNESS_WINDOW=120` seconds. The consuming hook does
    `find specs -maxdepth 3 -name ".git-snapshot-marker" -type f`, picks newest by TIMESTAMP, and
    honors it only if `0 <= (NOW - TIMESTAMP) <= 120`.
  - Consumption: `rm -f "$BEST_MARKER"; exit 0` (guard-destructive-git.sh ~line 287-292) -- delete
    on use, so one marker authorizes exactly one gated command.
  A push grant token needs MORE payload than this marker does (remote, branch, sha, force-or-not)
  precisely so it cannot be replayed against a different push. A bare TIMESTAMP-only token would
  be a blank cheque for any push within the window -- do not reuse the shape uncritically.

scripts/git-commit-scoped.sh interface, for the wrapper to be modeled on:
  - `git-commit-scoped.sh --message <msg> --session <sid> [--honest-index-rows <task_number>]
    -- <pathspec>...`
  - PROJECT_ROOT: `SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)`, source lib/common.sh,
    `PROJECT_ROOT="$(common_repo_root "$SCRIPT_DIR" 2)"`, then `. deploy-root-guard.sh`.
  - Mutex: serializes via `specs/.commit-lock/` through `task-lock.sh commit-acquire/commit-release`,
    released in an EXIT trap; `COMMIT_MUTEX_HELD` lets a nested caller reuse the lock as a guest.
  - IMPORTANT DIVERGENCE: it fails OPEN on mutex-acquire failure (proceeds unserialized with a loud
    WARNING), reasoning the worst residual case is a safe index.lock race, not misattribution. A
    PUSH guard must fail CLOSED -- an unavailable lock or unverifiable grant must refuse the push.
    Do not inherit the fail-open direction; state this divergence explicitly in the code comments.
  - Shape to mirror: usage/flag parsing -> PROJECT_ROOT resolution -> mutex acquire/release via
    task-lock.sh verbs -> guarded git operation -> bounded retry on index.lock. Safety gates
    V2/V3/V4 (unmatched-path classification, exclude-only-pathspec refusal, nothing-to-commit
    exit 1) are the precedent for refusing ambiguous input rather than guessing.

AUDIT WRITER: scripts/events-append.sh is the sanctioned specs/events.jsonl writer (analogous to
state-write.sh): builds the line via `jq -c -n`, appends under `flock` on specs/.events.lock.
Required flags `--event-type --category --session --message`; optional `--task --checkpoint
--duration --detail-json --error-ref --cwd --cc-session-id`. `--category` is an enum:
deviation|blocker|milestone|success -- pick the fitting one and justify it. Record fields and the
draft-07 schema live in context/formats/events-format.md and context/schemas/events-schema.json,
which MUST stay in sync with each other. Never hand-append to events.jsonl.

DANGLING REFERENCE TO RESOLVE (small, real, in scope): hooks/guard-destructive-git.sh line 6 says
it is "Modeled line-for-line on .claude/hooks/block-pr-submission.sh", but NO file named
block-pr-submission.sh exists anywhere in the source store, and manifest.json has no
provides.hooks entry for it. It is a deploy-side-only artifact, i.e. either an orphan that
source-store regeneration will wipe or a stale reference to something already gone. Determine
which and fix the reference. Do not leave a header comment pointing at a file the source store
does not contain.


=== ABSORBED 2026-09-28 (path review, fifth pass) from former task 224 (please_grant_integrity_and_git_guards); that task is abandoned into this one. Its text follows verbatim; where it names "the dependency task" or "the sibling task", read this task's other sections. ===

Add a tamper-resistant single-use /please grant mechanism, a new git push guard, and grant checks in the destructive-git guard. Only agent-system/extensions/core/ is edited (hooks/, scripts/tests/, root-files/settings.json and/or merge-sources/settings-hooks.json, context/standards/git-safety.md), never .claude/.

(1) GRANT HOOK. A UserPromptSubmit hook that, when the literal user prompt starts with "/please", writes one grant (request text, timestamp, 10-minute expiry). Research must first verify what the hook payload actually contains (raw "/please ..." text or the expanded command body) and that subagent- or model-generated prompts can never trigger UserPromptSubmit.

(2) INTEGRITY, TO BE SETTLED IN RESEARCH. "The model must not be able to create grants" and "forged grant file rejected" require a real integrity mechanism: a gitignored file the model can Write to is forgeable. Starting point: an HMAC over each grant using a secret key stored outside the model-reachable/writable paths (or readable only by the hook), plus a PreToolUse guard blocking Write/Edit/Bash writes to the grant file and the key path. State the threat model honestly: a same-user shell process can in principle read any file the hook can read, so this raises the bar rather than proving user intent; name the residual risk. Decide whether the grant belongs outside the repo (e.g. $XDG_STATE_HOME) or in a gitignored in-repo path (the repo .gitignore currently ignores /.claude/ and /specs/tmp; root-files/.gitignore only covers .claude/).

(3) MATCHING RULE, TO BE SETTLED IN RESEARCH. Define how the free-text request is matched to the concrete command, e.g. action class (force-push, reset --hard, clean -fd, ...) plus remote/branch extracted from both. Ambiguous or partial matches are refused; one grant covers one action class and one target.

(4) PUSH GUARD. No push guard exists today (rules/pr-prohibition.md is advisory only; root-files/settings.json allow-lists Bash(git:*)). Create a new PreToolUse Bash hook (e.g. hooks/guard-git-push.sh) that blocks git push without a matching unexpired grant, via exit 2 + stderr like guard-destructive-git.sh (permissionDecision: deny is documented-buggy for allow-listed git commands). Research decides whether it also covers gh pr create / glab mr create and how /merge own push stays working.

(5) DESTRUCTIVE-GIT GUARD. hooks/guard-destructive-git.sh allows a matched action only with a matching unexpired grant, consuming it on use (mirror the existing .git-snapshot-marker consume-on-use pattern). Without a grant, behavior is unchanged. Preserve the clean-tree early exit and the COMMAND_SCAN quote/comment-stripping; a grant must never exempt the over-staging detectors. Decide where the grant check sits relative to the clean-tree early exit.

(6) REGISTRATION. Register the new hooks in the source-store settings file(s) research identifies (PreToolUse Bash hooks currently live in root-files/settings.json; UserPromptSubmit hooks in merge-sources/settings-hooks.json).

(7) TESTS in scripts/tests/ following context/standards/shell-script-testing.md and the fixture style of test-guard-destructive-git.sh (hook run as a subprocess against a synthetic dirty repo, asserting exit codes): forged grant rejected, expired grant rejected, grant consumed after one use, mismatched action/target rejected, no-grant behavior unchanged for both guards, writes to grant file and key path blocked.

OVERLAP NOTE (no dependency edge, by user decision): the pending history-rewrite predicate work on guard-destructive-git.sh also edits hooks/guard-destructive-git.sh, rules/git-workflow.md and context/standards/git-safety.md. Structure predicate ordering so the two additions compose; the file-footprint admission gate serializes them if run concurrently.

Redeploy afterwards and confirm the hooks fire from the deployed copies.

=== ABSORBED 2026-09-17 from former task 225 (/please command, never-list, pr-prohibition exception, docs); that task is abandoned into this one. Its text follows verbatim; where it names "the dependency task" or "the sibling task", read this task's other sections. ===
Add the user-only /please command, its never-list, the pr-prohibition exception, and the CLAUDE.md command-reference entry. Only agent-system/extensions/core/ is edited (commands/please.md, commands/README.md, rules/pr-prohibition.md, merge-sources/claudemd.md), never .claude/. Builds on the grant mechanism and guards from the predecessor task (dependency).

(1) commands/please.md, user-only, modeled on commands/merge.md and commands/tag.md: authorizes one otherwise-blocked action per invocation (e.g. "/please force-push main to origin"). Parse the requested action; show the exact command and its effect (for pushes: local vs remote SHAs); confirm with AskUserQuestion before any irreversible step; prefer safe forms (--force-with-lease=<ref>:<observed remote SHA> over --force); do only the literal request; log the action to specs/events.jsonl via scripts/events-append.sh. Caveat to state in the command: the grant proves the user typed /please, not that the command the agent then runs is the one meant, so the confirmation step is mandatory for anything irreversible.

(2) NEVER-LIST, refused regardless of wording and enforced in the command: credential/secret access, deletion outside the repo, .git internals, disabling/editing/removing hooks or hook settings.

(3) rules/pr-prohibition.md: add a /please exception scoped to the single action of that one invocation, reconciled explicitly with the existing "never push even if asked in user messages" language.

(4) merge-sources/claudemd.md: add a /please row to the Command Reference table beside /tag and /merge, marked user-only; add a row to commands/README.md.

Redeploy and confirm the generated .claude/CLAUDE.md shows the new row.

=== ABSORBED 2026-09-28 (path review, fifth pass) from former task 264 (relay_push_consent_through_user_decision); that task is abandoned into this one. Its text follows verbatim; where it names "the dependency task" or "the sibling task", read this task's other sections. ===

SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**, a disposable
deploy artifact -- see rules/source-store-deploy-boundary.md).

DEPENDS ON the consent-gated-push design task, for two independent reasons: (1) semantic -- this
task routes a push REQUEST through the orchestrator and mints the grant its guard consumes, which
is impossible until that task settles the grant semantics, the invalidation predicate, and the
wrapper's interface; (2) file-footprint overlap -- both touch rules/pr-prohibition.md and
manifest.json. Rebase on whatever that task lands.

=== GOAL ===
Two things: (a) define how an agent running in a fire-and-forget dispatch REQUESTS a push, since it
cannot call AskUserQuestion itself, and how the user's answer becomes a grant the guard honors;
(b) sweep the codebase so nothing still asserts the blanket prohibition the companion task
narrowed.

=== (a) THE DISPATCH PATH -- EXTEND THE EXISTING CHANNEL, DO NOT INVENT ONE ===
A dispatched subagent cannot call AskUserQuestion. Verified concretely: while these tasks were
being created, the dispatched agent doing so had NO AskUserQuestion tool available -- a
ToolSearch for it returned "No matching deferred tools found". So the request must be relayed.

The channel exists and this case is already inside its stated remit.
context/standards/user-decision-contract.md defines an agent-authored `user_decision`, and
context/formats/return-metadata-file.md (~line 507, "### user_decision (optional)") gives its
shape: a TOP-LEVEL object on `.return-meta.json`, producer-owned by the agent that sets it,
`{question, options: [...], recommended, blocking: true|false}`, mirrored onto
`.orchestrator-handoff.json` when that dispatch also writes one. Later writers must merge without
touching it. The contract's enumerated qualifying shape 2 is, verbatim: "An external cost or risk
the user must accept -- spending money, granting a credential, deleting data, or taking an action
outside this repository that the agent cannot verify is already sanctioned." A push to a remote is
squarely an action outside this repository. Treat that as the designed home for this request.

VERIFIED RELAY PATH (use these call sites; do not re-derive):
  - scripts/orchestrate-cycle-postflight.sh, "WORK (e): user_decision relay" (~lines 1073-1096):
    reads `.orchestrator-handoff.json` first when fresh (`handoff_stale != true`), else
    `.return-meta.json`; a non-null value sets `verdict="ask_user"`, which "takes precedence over
    every other signal". The script relays and NEVER resolves (its line-68 comment:
    "user_decision is RELAYED, never resolved") and explicitly never writes .decisions.json
    (~line 1088).
  - skills/skill-orchestrate/SKILL.md Move 3 "Postflight" (~lines 208-213) ACCUMULATES rather than
    asking per task: `.pending_ask_user = ((.pending_ask_user // []) + [{"task": $tn,
    "decision": $q}])`.
  - Move 4 "Branch" batched relay (~lines 256-263): if `pending_ask_user[]` is non-empty, call
    AskUserQuestion once per entry (question/options/recommended from `.decision`), all batched at
    the single Move-4 boundary -- "never mid-cycle, never one call per task". Non-blocking
    decisions proceed on the agent's recommendation and are only surfaced in output.
  - Move 4 then appends each answer to `specs/{padded}_{project}/.decisions.json` and clears that
    task's `pending_ask_user`.

*** CRITICAL DESIGN HAZARD -- THE EXISTING REPLAY CHANNEL ***
`.decisions.json` is not inert. Schema in docs/architecture/handoff-schema.md (~lines 951-991):
a JSON array of `{question, answer, cycle, timestamp}` at
`specs/{NNN}_{slug}/.decisions.json`, absent until the first decision is answered, additive only.
scripts/orchestrate-build-dispatch.sh (~lines 38-42, 367-377, 511-518) READS it when building the
NEXT dispatch for the same task and emits a `## Prior Decisions` section so the answer is not
re-asked. That mechanism is desirable for ordinary design decisions and DANGEROUS here: a recorded
"yes, push" would be replayed into every subsequent dispatch for that task as standing prior
approval -- which is exactly the failure the requirement forbids ("permission must never be
inferred from a prior approval in another context"). Resolve this explicitly. Either exclude push
grants from the `## Prior Decisions` injection, or record them in a form that is self-evidently
non-reusable (bound to a specific sha/branch/remote that a later cycle cannot satisfy), or both.
Do NOT leave the default replay behavior in place for this decision class. Whatever is chosen,
verify it with a test that runs two cycles and confirms the second does not inherit the grant.

Also establish:
  - How the push request is expressed in the `user_decision` payload with enough specificity that
    the answer authorizes ONE identifiable push (remote, branch, commit sha, force-or-not). A
    vague "may I push?" the guard then interprets broadly would defeat the design. The payload's
    `options`/`recommended` fields must make the exact target legible to the user at the moment
    they answer -- consent to an unspecified push is not consent.
  - Whether such a request may ever be `blocking: false`. It almost certainly must always be
    `blocking: true`, since the non-blocking path proceeds on the AGENT's recommendation without
    asking -- which would be an agent authorizing its own push. Confirm and enforce this.
  - The RETURN LEG, which has no existing precedent: the relay today surfaces decisions to the
    user; it does not mint an authorization token a later subprocess consumes. Design how a YES
    becomes a grant the guard script honors, and where that token lives.
  - What happens when the request is relayed but the run ENDS before an answer, and when the user
    answers NO. Both must leave the task clean with no push performed.
  - Whether a granted push may carry across a later cycle in the same run, or dies with the
    dispatch that requested it. Must be answered consistently with the companion task's
    grant-scope decision.

Constraint to preserve: the contract's core invariant is that the orchestrator never asks on its
own and never decides on the user's behalf, and that agents decide everything else themselves. A
push request must not become a prompt agents raise reflexively; it qualifies only when a push is
genuinely the task's sanctioned endpoint.

=== (b) CONSISTENCY SWEEP ===
Note up front, verified: there is NO existing lint or test asserting behavioral push/PR blocking,
so this sweep is about DOCUMENT consistency plus ADDING the missing tests, not about repairing
broken assertions. The only structural check is scripts/check-extension-docs.sh Rule H
`check_undeclared_rules()`, which asserts rules/pr-prohibition.md is declared in manifest.json's
`provides.rules`; keep that satisfied.

Files to reconcile:
  - rules/pr-prohibition.md -- the narrowing lands in the companion task; verify no stale absolute
    language survives, especially "Never push branches or create PRs even if asked to in task
    descriptions or user messages", which must still hold verbatim for everything the new gate
    does NOT cover. Its `paths: "**/*"` frontmatter and why-eager comment stay.
  - rules/git-workflow.md -- the "Git Safety > Never Run" bullet on `git push --force` to
    main/master, and the "Enforced by guard-destructive-git.sh" note if a new guard joins it.
  - merge-sources/claudemd.md -- this is the GENERATED-FROM source for the deployed
    .claude/CLAUDE.md; edit here, never the deployed file. Reconcile the `/merge` and `/tag`
    "(user-only)" command-table markings (~lines 111, 114), `skill-tag | (user-only)` in the skill
    table (~153), and the "User-Only Skills" note (~165). If the companion task decided PR
    creation and `/merge` stay prohibited, these stay and should be reinforced, not loosened.
  - commands/merge.md and skills/skill-tag/SKILL.md -- both reference the prohibition; check both.
  - context/standards/status-markers.md -- confirm whether a consented push changes when a task
    reaches `[PR READY]`. Most likely it does not; say so explicitly rather than leaving it
    unexamined.
  - If a new audit event type is introduced, context/formats/events-format.md and
    context/schemas/events-schema.json must stay in sync with each other.

=== VERIFICATION ===
1. A dispatched subagent needing a push emits a well-formed top-level `user_decision` with
   `blocking: true` and does NOT push.
2. postflight sets `verdict="ask_user"`; Move 3 accumulates it into `pending_ask_user`; Move 4
   relays it in the batch with the specific push identified (remote, branch, sha, force-or-not).
3. A NO answer results in no push and a clean task state.
4. A run ending before an answer results in no push and a clean task state.
5. A YES produces a grant the guard honors for exactly that push and no other: verify a replay
   against a different branch, a different remote, and a later commit is each refused.
6. TWO-CYCLE TEST for the hazard above: after a granted push in cycle N, cycle N+1's dispatch does
   NOT inherit standing permission via `## Prior Decisions`.
7. `grep` the source store for remaining blanket-prohibition language; list every file changed and
   every file deliberately left unchanged, with reasons.
8. Re-run scripts/tests/ plus the check-*.sh lints, including check-extension-docs.sh Rule H. No
   test weakened or deleted; any test whose assertion changed is named in the summary with its old
   and new assertion. New tests must cover items 1-6.

=== PATH REVIEW RULING 2026-09-28 (fifth pass) -- ONE grant mechanism, not three ===
Three tasks (this one, the absorbed /please task, and the absorbed user_decision relay task) each designed a git-push grant. They are now one task with three phases, and the following is settled rather than re-litigated:
  1. INTEGRITY DECIDES THE MINT PATH. A grant file the model can Write after reading an AskUserQuestion answer is forgeable by construction -- exactly the artifact the absorbed /please text rejects. So the tamper-resistant mint path is the /please UserPromptSubmit hook (the harness fires it only on a literal user prompt; research item (1) of the absorbed text must still VERIFY the payload shape and that model- or subagent-generated prompts never trigger it). AskUserQuestion is the confirmation surface, never the mint.
  2. THE TOKEN CARRIES THE TARGET. Whatever the /please grant records, it must bind action class + remote + branch + commit sha + force-or-not (this task's design questions 1 and 3), single-use, short expiry, fail-CLOSED on any unreadable/malformed/mismatched grant. The bare TIMESTAMP-only snapshot-marker shape is explicitly insufficient.
  3. THE DISPATCH PATH ONLY RELAYS. A dispatched agent emits a blocking user_decision whose options make the exact push legible; Move 4 relays it once at cycle end (settled decision: the orchestrator never asks on its own and never decides). A YES does NOT mint anything -- the relayed text tells the user the exact /please line to type, and the guard consumes that grant. This closes the .decisions.json replay hazard for free: nothing replayable is ever recorded, but the two-cycle test in the absorbed text still ships to prove it.
  4. PR/MR creation and /merge stay user-only. Force-push and pushes to master are outside any grant unless the /please never-list explicitly admits a --force-with-lease form; decide and record.
  5. skills/skill-orchestrate/SKILL.md sits at 17 B under its 20,000 B ceiling (measured 2026-09-28). Any relay text added there must be offset byte-for-byte (mode-gate it or move it to a context file) -- verify-deploy Gate 20 will otherwise refuse the redeploy.
PHASES: (A) grant token + /please hook + integrity + push guard + destructive-git grant check + tests; (B) /please command, never-list, rule exception, docs sweep (the absorbed consistency sweep); (C) dispatch relay + two-cycle test. Depends on the history-rewrite task (guard-destructive-git.sh, git-safety.md, git-workflow.md are shared; its predicate ordering must compose with the grant check).

=== SERIALIZATION EDGE ADDED 2026-10-02 (dependencies: 265) ===
Serialization-only, not semantic: this task does not consume any output of the Gate 8 / --skip-verify task. The edge pins the roadmap Call A implement order 165 -> 265 -> 263, placing this 13-phase task last so it cannot starve the two shorter ones of cycle budget, and letting the urgent --skip-verify half land first. Rebase on whatever that task lands in deploy-headless.sh and verify-deploy.sh; this task touches neither.

---

### 251. Context-corpus reachability probe (filename, directory, index.json), then act on dead and overlapping files
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 249, Task 44, Task 127

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**).

MOTIVATION. Same structural gap as the script-corpus task: defect-driven intake surfaces only
what breaks, and an unreachable or redundant context file breaks nothing -- it just costs bytes,
deploy time and reader attention. Existing tasks slim SPECIFIC oversized files (commands/task.md,
the literature and distill skills) or collapse ONE mechanism (the routing ladder). Nothing
reviews the corpus, and -- the sharper problem -- nothing in the repo can currently ANSWER what
is reachable.

MEASURED 2026-09-22 (re-measure before acting; standing rule 3).
  - 523 .md files under agent-system/extensions/**/context/**, 3,583,550 B (~3.6 MB) total.
  - A naive basename-grep reachability check over the whole source store returned: 39 files not
    referenced from outside context/, of which 16 were referenced NOWHERE at all.
  - ALL 16 WERE FALSE POSITIVES. Every one is a present-extension slide template under
    context/project/present/talk/contents/**, referenced by DIRECTORY from the present agents
    (`talk/contents/title/`, `talk/contents/methods/`, ...) rather than by filename.
  - CONCLUSION, STATED PLAINLY SO NOBODY RE-DERIVES IT: there are ZERO confirmed dead context
    files today. The finding is not "delete 16 files" -- it is that the naive check is INADEQUATE
    and no adequate one exists. Do not open this task by deleting anything.

THREE REFERENCE STYLES THE PROBE MUST UNDERSTAND (the naive check saw only the first):
  1. by filename -- a backticked or plain path naming the file;
  2. by directory -- a reference to the containing directory, which reaches every file under it
     (the present templates; treat a directory reference as covering its whole subtree);
  3. via index.json -- context indices that enumerate entries the loader resolves at runtime.
A probe that misses any of these produces false orphans, and acting on false orphans deletes live
content. Prove the probe against the present-templates cluster as a REGRESSION FIXTURE: a correct
probe reports all 16 reachable.

PHASE 1 -- THE PROBE (mechanical, becomes permanent).
Add a standing reachability/inventory probe following the EXISTING convention of
scripts/assess-repo-health.sh and scripts/measure-eager-context.sh (JSON to stdout, --check mode,
no side effects, reads the SOURCE STORE not .claude/**). Per context file report:
  - bytes; owning extension; reachable yes/no and by WHICH of the three styles;
  - eager vs lazy -- whether it loads on every session (the eager channels measure-eager-context.sh
    already models: parent chain, assembled CLAUDE.md, @-imports, path-matched rules) or only on
    demand. Reuse that script's channel model; do not build a second, divergent one.
  - inbound reference count, so single-referrer files that could be inlined are visible.
Register it in docs/reference/utility-scripts-inventory.md alongside the other probes.

PHASE 2 -- THE STRONGER EVIDENCE: TELEMETRY, NOT ONLY STATIC ANALYSIS.
Static reachability answers "could this be loaded". The better question is "has any dispatch
ACTUALLY loaded it". The repo already carries the data: specs/events.jsonl, the memory
extension's history.jsonl, and the telemetry tiers the distill review mode queries. Determine
whether load events are recorded at context-file granularity; if they are, cross the probe's
static verdict against observed loads and report files that are statically reachable but never
actually loaded. If they are NOT recorded at that granularity, say so explicitly in the summary
and state what instrumentation would be needed -- that is a legitimate finding, not a failure.

PHASE 3 -- ACT ON THE RANKING.
Only after Phases 1-2 produce evidence: remove confirmed-dead files; merge pairs whose content
substantially overlaps; and for files that are live but oversized, apply the established
rule-or-command -> lazy-narrative split (rules/git-workflow.md -> context/standards/
git-workflow-narrative.md is the worked example). Every removal cites the probe's verdict AND
the telemetry verdict where available. A file that is reachable by any of the three styles is NOT
dead, however unloved it looks.

SCOPE DISCIPLINE -- READ BEFORE DECLARING file_scope.
This task's INITIAL file_scope is the new probe, its test, and the inventory doc ONLY. Do NOT
declare `context/` or any whole-directory or glob entry: coarse entries draw validate-state.sh
warnings and defer unrelated tasks in the dry run -- a mistake already corrected once in this
backlog by narrowing a task that had three whole-directory entries. Phase 3's actual edit targets
MUST be named individually and ADDED to file_scope at plan time, after Phase 1 has ranked them.

ACCEPTANCE.
  1. The probe runs clean, is registered, and reports all 16 present-extension templates as
     REACHABLE (the regression fixture above).
  2. Its output is reproducible across two runs and does not read .claude/**.
  3. The eager/lazy classification agrees with measure-eager-context.sh's totals -- two probes
     must not disagree about what is eager.
  4. Every file removed in Phase 3 has a recorded probe verdict and a stated reference-style check
     against all three styles.
  5. run-all.sh green -- read the summary line AND the exit code, and do NOT pipe it through
     tail/head.
  6. verify-deploy.sh --skip-slow no worse than at task start.

DEPENDENCIES AND WHY.
  - The eager-context budget task performs exactly the rule -> lazy-narrative split this task's
    Phase 3 generalizes, and CREATES a new context/standards file. Measuring the corpus before it
    lands measures a state about to change, and its split is the worked exemplar to follow.
  - The task.md slimming task moves reference material into six new lazily loaded context/patterns
    files. A corpus inventory taken before those exist is stale on arrival.
  - The routing-ladder collapse removes a routing mechanism and may orphan its context; measuring
    before it lands would miss exactly the kind of dead content this task exists to find.

DELIVERABLE RULE: no task numbers in deliverables outside specs/** (no-task-references-in-deliverables.md).

---

### 250. Script-corpus inventory probe, then cut tests/run-all.sh runtime and decompose orchestrate-cycle-plan.sh
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 199, Task 245, Task 249, Task 259, Task 265, Task 266
- **Research**: [250_script_corpus_inventory_and_engine_decomposition/reports/01_script-corpus-inventory-probe-and-decomposition.md]
- **Plan**: [250_script_corpus_inventory_and_engine_decomposition/plans/01_inventory-probe-and-decomposition.md]
- **Summary**: [250_script_corpus_inventory_and_engine_decomposition/summaries/01_inventory-probe-and-decomposition-summary.md]

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**).

MOTIVATION -- A GAP IN THE INTAKE MECHANISM, NOT A SINGLE DEFECT. Tasks in this repo are filed by hand from defects hit live during /orchestrate runs. That intake only ever surfaces what BROKE. Needless complexity, duplicated logic and poor division of labor never break anything -- they only cost -- so they are invisible to the filing process by construction and will not self-correct. Every existing script-touching task is a point fix on one file. Nothing reviews the corpus. This task closes that gap with a standing probe, not a one-off reading pass.

MEASURED 2026-09-22 (re-measure before acting; standing rule 3).
  - 182 non-test .sh files under agent-system/extensions/**, 63,740 lines total.
  - The orchestrate engine alone: 8,207 lines across 14 orchestrate-*.sh scripts.
  - orchestrate-cycle-plan.sh: 2,279 lines -- 27.8% of the engine in ONE file, and 6.5x the
    351-line median of its own 14-script family (next largest: cycle-postflight at 1,256).
  - scripts/lib/ already holds 14 extracted libraries totalling 2,564 lines (common.sh,
    file-scope-overlap.sh, manifest-routing-lib.sh, task-lookup-lib.sh, ...). The extraction
    pattern is ESTABLISHED and working; it simply has never been applied to the largest file.

ANTI-ANALYSIS CONSTRAINT -- READ THIS BEFORE PLANNING. A "review all 182 scripts" pass that
emits a report and no diff is the failure mode this repo's own hard-mode contract names (H2:
forbidden analysis-only outputs, analysis-paralysis signal). This task is therefore explicitly
two-part: build a MECHANICAL probe, then act on its RANKED output. Any phase whose only artifact
is prose is out of contract. The probe is the deliverable that outlives the task.

PHASE 1 -- THE PROBE (mechanical, becomes permanent).
Add a standing inventory probe following the EXISTING convention of scripts/assess-repo-health.sh
and scripts/measure-eager-context.sh (JSON to stdout, --check mode, no side effects, reads the
SOURCE STORE not .claude/**). Per non-test script it must report at minimum:
  - line count and byte count;
  - inbound caller count (how many skills, agents, commands, manifests, hooks and other scripts
    reference it) -- a script with zero callers is a finding in itself;
  - whether a test suite covers it (pair against scripts/tests/ and flat scripts/test-*.sh);
  - duplicated-block detection ACROSS scripts, so copy-paste that belongs in lib/ is visible;
  - whether it is registered in the owning manifest's provides.scripts (the same class of drift
    check-extension-docs.sh already performs -- reuse, do not reimplement).
Register it in docs/reference/utility-scripts-inventory.md alongside the other repo-health probes.
Emit a stable ranked ordering so Phase 2+ targets are chosen by evidence, not by preference.

PHASE 2+ -- ACT ON THE RANKING, HIGHEST FIRST.
Decompose orchestrate-cycle-plan.sh into lib/ extractions, following the shape the 14 existing
libs already demonstrate. This is a BEHAVIOR-PRESERVING refactor:
  - the --dry-run JSON payload and the human table must be byte-identical before and after for a
    representative multi-task invocation (capture the baseline FIRST, diff at the end);
  - md5sum specs/state.json unchanged across a --dry-run call, as today;
  - scripts/tests/test-orchestrate-cycle-plan.sh green throughout, and green after each extraction
    rather than only at the end (commit-per-green-substep, per rules/git-workflow.md).
Size each extraction to one agent run. Do NOT attempt the whole 2,279 lines in a single phase.

SCOPE DISCIPLINE.
  - Phase 2 targets orchestrate-cycle-plan.sh ONLY among the engine scripts. Do NOT edit
    orchestrate-batch-admit.sh (owned by the admission tasks), orchestrate-predispatch-review.sh,
    or orchestrate-cycle-postflight.sh in this task -- each is another open task's declared scope,
    and editing them here reintroduces exactly the undeclared-overlap deferral the batch engine
    exists to prevent.
  - If Phase 1's ranking names further scripts worth decomposing, ADD them to file_scope at plan
    time (the convention already used elsewhere in this backlog) or file them as separate tasks.
    Do NOT declare a whole-directory or glob file_scope entry: coarse entries draw
    validate-state.sh warnings and defer unrelated tasks in the dry run.
  - Never weaken or delete a test to make a refactor pass.

ACCEPTANCE.
  1. The probe runs clean, is registered, and its output is reproducible across two runs.
  2. Every script with zero inbound callers is either removed or justified in the summary.
  3. orchestrate-cycle-plan.sh is materially smaller, with the extracted logic in lib/ and each
     extraction covered by the existing suite.
  4. Byte-identical --dry-run output vs. the captured pre-refactor baseline.
  5. run-all.sh green -- read the summary line AND the exit code, and do NOT pipe it through
     tail/head (that masks both; it is how a red run read as green on 2026-09-22).
  6. verify-deploy.sh --skip-slow no worse than at task start.

DEPENDENCIES AND WHY.
  - 199 declares orchestrate-cycle-plan.sh in its own file_scope and decides the working-tree /
    build isolation posture. Decomposing the file while another task is changing its behavior is
    a guaranteed conflict; 199 lands first.
  - The in-flight admission task rewrites orchestrate-batch-admit.sh, which cycle-plan calls.
    Refactoring the caller across a changing callee contract is the same hazard.

DELIVERABLE RULE: no task numbers in deliverables outside specs/** (no-task-references-in-deliverables.md).

=== WORKED EXAMPLE ADDED 2026-09-22: tests/run-all.sh IS THE FIRST PHASE-2 TARGET ===

Reported by the user as "runs very slow", then profiled. This is the concrete exemplar for what
Phase 1's probe should surface and what Phase 2 should do about it. Every number below was
measured on 2026-09-22 by timing each suite individually; re-measure before acting (standing
rule 3).

MEASUREMENT: 92 suites, 557.1 s (9.3 min) end to end, strictly serial.

  329,016 ms  test-verify-deploy-context-budget.sh   <- 59.1% OF THE ENTIRE RUN, and it is the
   39,778 ms  test-orchestrate-cycle-plan.sh             one suite currently FAILING
   21,828 ms  test-literature-convert.sh
   19,160 ms  test-git-commit-scoped.sh
   13,835 ms  test-roadmap-argv-ceiling.sh
   11,728 ms  test-orchestrate-cycle-postflight.sh
   11,086 ms  test-state-write-concurrency.sh

  Top 5 = 76.0% of total. Top 10 = 83.7%. 56 of the 92 suites finish in under 1 second.

This is an extreme long-tail profile, and it dictates the ORDER of the work.

FINDING 1 -- THE LONG POLE, AND WHY IT COSTS 329 s.
test-verify-deploy-context-budget.sh builds its fixture by rsync-ing the ENTIRE
agent-system/extensions/ tree (17 MB) into a mktemp mirror (its line 74). It does this because a
minimal fixture makes verify-deploy.sh's gates 3-13 SKIP, which would make the suite vacuous --
that is a deliberate, correct design decision, documented in the suite's own header, and it must
NOT be "fixed" by shrinking the fixture back into vacuity. It then runs verify-deploy.sh over
that full-size mirror several times; verify-deploy's own header measures a --skip-slow run at
roughly 50-70 s, and N x ~55 s accounts for the observed 329 s almost exactly. The suite already
uses --skip-slow correctly (its header notes gate 8 "would otherwise recurse"), and it has
already been hand-optimized once (three fixture mutations combined into a single invocation).
The remaining cost is structural, not sloppiness.

FINDING 2 -- THE HIGHEST-LEVERAGE FIX: verify-deploy.sh HAS NO GATE SELECTOR.
verify-deploy.sh accepts [--quiet] [--findings] [--skip-slow] [--minimal-init DIR] [TARGET_REPO]
and nothing else -- there is no --only-gate / --gate / GATE_FILTER. This suite exercises GATE 20
(the orchestrator context budget) and needs the other ~19 gates only so they do not SKIP the
fixture into vacuity. Adding a gate selector to verify-deploy.sh, and having this suite request
only the gate it asserts on, is the single largest available win in the whole harness: it should
take the suite from ~329 s toward tens of seconds, and run-all.sh from ~557 s to roughly ~250 s
on its own. Confirm by measurement, not by assumption, and confirm the suite stays non-vacuous
(the selector must not become a way to skip the gates that give the fixture its realism).

FINDING 3 -- SERIAL BY CONSTRUCTION, WITH ONE STRUCTURAL BLOCKER.
The runner loop (run-all.sh:148) executes `bash "$suite"` one suite at a time: no `&`, no `wait`,
no `xargs -P`, no job control anywhere in the file. The blocker to changing that is concrete: a
SINGLE shared `SUITE_OUT="$(mktemp)"` (line 145) is written by every suite (line 157) and
truncated between them (line 169). Per-suite output files are the prerequisite for any
parallelism. The runner also accepts only `--quiet` -- there is no `--jobs`, no `--filter`, no
`--changed`, so a developer touching one script cannot run only its suite and must pay the full
9.3 minutes.

ORDERING IS LOAD-BEARING -- DO NOT PARALLELIZE FIRST. Parallelism cannot reduce total wall time
below the longest single suite. While the long pole is 329 s, even infinite parallelism leaves
run-all.sh at 329 s -- a 41% improvement at best. Fix the long pole FIRST (Finding 2): that takes
the serial total to ~228 s, after which parallelism has a ~40 s floor (the next-longest suite)
and becomes worth doing. Sequence: gate selector -> re-measure -> per-suite output files ->
parallelism -> selective execution.

PARALLELISM MUST SHIP OPT-IN, SERIAL BY DEFAULT. The shell-test-isolation task in this backlog
already documents, with live evidence, that some suites pass in isolation and fail in a full run
because their assertions are coupled to ambient host state on the TIMING axis (a wall-clock
window that holds on an idle machine and breaks under load). Parallel execution increases
exactly that contention. That task DEPENDS on this one, so this task lands first -- therefore
ship `--jobs` defaulting to 1 (serial, today's behavior byte for byte) and leave flipping the
default to the isolation work. Do NOT make parallel the default here; doing so converts a slow
but honest gate into a fast flaky one, which the isolation task's own description argues is
strictly worse.

WHY THIS MATTERS BEYOND DEVELOPER PATIENCE. run-all.sh is verify-deploy.sh's gate 8. A slow or
flaky gate 8 slows verify-deploy, which gates deploy-headless.sh, which makes the orchestrator's
inter-cycle redeploy checkpoint defer an entire batch. Test-harness latency is on the critical
path for throughput, not merely on developer comfort.

METHOD WARNING -- THREE PLAUSIBLE-LOOKING LEADS THAT ARE FALSE. All three were checked and
refuted on 2026-09-22. Do not re-derive them, and do not let the probe in Phase 1 emit them:
  1. "~225 s of hard-coded sleeps across 32 call sites." FALSE. Those are fixture STRING LITERALS
     -- test-claude-refresh-matcher.sh synthesizes fake `ps` output containing `sleep 10`, and
     test-detect-noop-bash.sh passes "sleep 30" as a CLASSIFIER INPUT. The suite with the largest
     apparent sleep total (158 s) measures 6.9 s. A static `grep sleep` sum is meaningless here.
  2. "43 verify-deploy invocations across the suites." FALSE. That counted every textual mention
     including comments. Real executable invocations are single digits, roughly half already pass
     --skip-slow, and all target fixtures rather than the real source store -- so gate 8 never
     re-enters and there is no recursion bug to find.
  3. "Gate 8 is 43-83% of verify-deploy's runtime." FALSE. That comment in
     test-claude-refresh-matcher.sh states the FAILURE RATE of a flaky reap mechanism, not a
     runtime share.
  The general lesson, which Phase 1's probe must honor: counting occurrences of a token in shell
  source over-reports, because comments, heredocs and fixture literals are indistinguishable from
  code to grep. Where the probe reports a cost, it must measure it.

ACCEPTANCE ADDITIONS FOR THIS EXAMPLE.
  a. run-all.sh total wall time is re-measured before and after, with the per-suite breakdown
     recorded, and the improvement stated as a measured ratio rather than an estimate.
  b. Suite PASS/FAIL outcomes are identical before and after for all 92 suites -- a speedup that
     changes an outcome is a regression, not an optimization.
  c. `--jobs` (if added) defaults to 1 and serial output is byte-identical to today's.
  d. The long-pole suite remains non-vacuous: it must still fail when the eager budget is
     breached and pass when it is not. Demonstrate both directions explicitly.
  e. run-all.sh's exit code still propagates failure (it correctly exits 1 today; a parallel
     rewrite must not lose that through a pipeline or a subshell).

=== EVIDENCE ADDENDUM (2026-09-22, measured live) ===

RUN-ALL.SH WALL-CLOCK, MEASURED: ~40 minutes for a single full `run-all.sh --quiet` over the
source-store copy, with concurrent agent activity on the machine. Observed during an
/orchestrate implement dispatch, where the dispatched agent backgrounded the run and then
stopped and resumed THREE times waiting on it (cumulative agent durations 384s / 1077s / 2287s
across the stop/resume rounds) before the suite exited.

WHY THIS MATTERS BEYOND COST. The runtime is not merely expensive, it is behaviour-changing:
  - It pushed the dispatched agent into a repeated stop/park/resume cycle, which is a
    reliability problem for autonomous orchestration, not just a slow gate.
  - The load the long run generates is itself implicated in ambient-state test failures --
    `test-lake-build-guard.sh` failed inside this run and then passed 47/47 in isolation
    immediately afterwards (recorded in the shell-test-isolation task's own evidence addendum).
    So run-all.sh's runtime and its concurrency are jointly producing false reds.

SUGGESTED MEASUREMENT FOR PHASE 1'S PROBE: capture per-suite wall-clock in the inventory probe
output, not just line/byte/caller counts. The ranking for "what to speed up" needs per-suite
timing, and that data is currently collected nowhere.

=== PATH REVIEW 2026-09-28 (fifth pass): the run-all.sh worked example is CLOSED -- do not redo it ===
The test-suite runtime task completed on 2026-09-26 and delivered exactly the sequence the worked example above prescribes: verify-deploy.sh gained --only-gate; test-verify-deploy-context-budget.sh collapsed to one full battery (391 s -> ~103 s); run-all.sh gained opt-in --jobs N|auto (serial default, JOBS_CAP 4, longest-first, deterministic output, nested-invocation guard) and a durable per-suite timing baseline in that task's report. run-all.sh, test-verify-deploy-context-budget.sh and verify-deploy.sh were removed from this task's file_scope accordingly (verify-deploy.sh now belongs to the Gate 8 parallelism task).
WHAT REMAINS: Phase 1 (the standing script-inventory probe, which must reuse that task's timing baseline as its per-suite wall-clock input rather than re-measuring) and Phase 2 (the behaviour-preserving decomposition of orchestrate-cycle-plan.sh into lib/). Ordered behind the isolation-posture decision, the deploy-pending/identical-dispatch fix and the checkpoint-cost task, so the file is quiet when it is decomposed. Re-measure the 2,279-line figure first.
=== RE-MEASURE CONFIRMATION 2026-10-02: the run-all.sh closure HOLDS; parallelism ceiling recorded ===
Prompted by a user report that the orchestrator's inter-cycle redeploy checkpoint feels slow next
to the picker's [Reload All]. That comparison is not like-for-like and is NOT a finding: [Reload
All] runs exts.resync_all() (a dependency-ordered Lua file copy plus a declared-vs-deployed
presence check), whereas the checkpoint runs deploy-headless.sh followed by verify-deploy.sh's
full numbered gate set. Different verification budgets, same copy.

This entry exists to satisfy Phase 1's instruction to REUSE the existing per-suite timing baseline
rather than re-measure it. The baseline was re-derived from suite-cost-hints.txt and still agrees:

  97 suites, 354.8 s summed sequential cost, 3,658 ms mean.
  103,000 ms  test-verify-deploy-context-budget.sh   <- 29.0% of the total
   43,783 ms  test-orchestrate-cycle-plan.sh
   21,566 ms  test-literature-convert.sh
   19,747 ms  test-git-commit-scoped.sh
   17,001 ms  test-orchestrate-cycle-postflight.sh
   16,996 ms  test-roadmap-argv-ceiling.sh
   11,952 ms  test-state-write-concurrency.sh
  Top 10 = 256 s = 72% of total.

The 103 s long pole is the POST-OPTIMIZATION figure (391 s -> ~103 s, delivered 2026-09-26 via
verify-deploy.sh --only-gate). It is NOT an unmined win, and the "fix the long pole first"
sequencing in the worked example above is spent. Nothing in this entry reopens run-all.sh,
test-verify-deploy-context-budget.sh or verify-deploy.sh -- all three remain correctly OUT of this
task's file_scope, and the PATH REVIEW 2026-09-28 closure stands. Phase 1 should consume the table
above as input and move on; Phase 2 remains the decomposition of orchestrate-cycle-plan.sh.

CONSEQUENCE THAT BELONGS TO THE GATE 8 PARALLELISM TASK, NOT HERE. Because cost is still
long-tailed around a single 103 s suite, --jobs auto (JOBS_CAP 4) has a hard wall-clock floor of
~103 s: roughly 355 s -> ~103 s, about 3.4x, after which that one suite IS the critical path.
Recorded here only so this task's probe output is not misread as an argument for further run-all.sh
work; acting on it is the Gate 8 task's business.

ALSO OBSERVED, unrelated to timing: verify-deploy.sh at the 2026-10-02 redeploy reported 2 of 33
checks failing, both pre-existing and neither in this task's scope -- a doc-lint gap for a newly
added migrate-state-legacy-fields.sh not yet registered in core's manifest.json, and a sandbox
orphan tmp file. Re-check whether both are still live before Phase 1 treats them as noise.

---

### 217. Cost-aware idle Lean tree reclamation in /refresh: PSS accounting, CPU-delta idleness, notify-before-kill
- **Effort**: 2 hours
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 174
- **Research**: [217_refresh_pss_memory_accounting/reports/01_pss-accounting-idle-notify.md]
- **Plan**: [217_refresh_pss_memory_accounting/plans/01_pss-accounting-idle-notify.md]
- **Summary**: [217_refresh_pss_memory_accounting/summaries/01_pss-accounting-idle-notify-summary.md]

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**, a disposable deploy artifact).

OBSERVED LIVE (2026-09-15): a Lean LSP tree was reported as "15.1 GB" reclaimable while earlyoom showed 14-16.6 GB available throughout; real reclaim was ~2.3 GB swap plus a little anon. User policy: idle trees that cost nothing may stay; trees that cost memory get a prompt (never a silent kill) after being idle a while. Memory floor 1 GB approved.

DEFECT. run_claude_pass and run_lean_pass in scripts/claude-refresh.sh both sum per-process RSS + VmSwap (get_vmswap_kb). Lean workers share mmapped Mathlib .olean files (5.6 GB lib), so shared pages are counted once per worker, and file-backed pages are evictable page cache anyway.

WORK.
(a) Add one shared memory helper used by BOTH passes: read $PROC_ROOT/PID/smaps_rollup; reclaimable = Pss_Anon + SwapPss. Report Pss_File separately as "shared cache (not counted)". When smaps_rollup is unreadable, fall back to RSS + VmSwap and label the figure approximate. Read only for candidates (not every process).
(b) Update both passes' report format to show reclaimable (and approximate marker) plus shared cache.
(c) Correct the in-script pcpu comment: procps-ng ps pcpu is lifetime cputime/elapsed, NOT a decaying average. (The idle gate itself is replaced by a follow-on task; only fix the comment here.)
(d) Tests in scripts/tests/test-claude-refresh-matcher.sh: fixture-based /proc via PROC_ROOT covering smaps_rollup parsing (Pss_Anon, SwapPss, Pss_File), shared-page de-duplication across multiple workers, and the unreadable fallback label.

MUST NOT. Change UID/system-slice safety predicates or termination ordering. Edit .claude/**.

ACCEPTANCE. Fixture of N workers sharing a large Pss_File reports reclaimable = sum(Pss_Anon+SwapPss) and shared cache separately; fallback path labeled approximate; test suite passes; shellcheck clean; redeploy and confirm.

DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

=== ABSORBED 2026-09-17 from former task 218 (CPU-delta idleness and the memory-floor cost gate); that task is abandoned into this one. Its text follows verbatim; where it names "the dependency task" or "the sibling task", read this task's other sections. ===
SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**, a disposable deploy artifact).

OBSERVED LIVE (2026-09-15): a Lean LSP tree was reported as "15.1 GB" reclaimable while earlyoom showed 14-16.6 GB available throughout; real reclaim was ~2.3 GB swap plus a little anon. User policy: idle trees that cost nothing may stay; trees that cost memory get a prompt (never a silent kill) after being idle a while. Memory floor 1 GB approved.

DEFECT. lean_row_is_idle uses ps etimes (process AGE) plus ps pcpu, which in procps-ng is lifetime cputime/elapsed. Any long-lived tree reads <1%, so an actively used 5h-old tree counts as "idle".

WORK (consumes the reclaimable figure from the PSS memory helper, hence the dependency).
(a) CPU-delta idle tracking: per-tree state in ~/.local/state/claude-refresh/lean-trees.json keyed by root pid + process starttime (/proc/PID/stat field 22). Each run, store the summed utime+stime of all tree members; if it increased since the last run, reset last_active; idle_for = now - last_active. Replace the pcpu/etimes gate entirely. Hourly run granularity is acceptable. Prune entries for trees that no longer exist.
(b) State file writes atomic (tmp + mv). Tolerate a missing or corrupt file: treat as first sighting, NEVER as idle.
(c) Cost gate: a tree is prompt-eligible only when idle_for >= LEAN_LSP_IDLE_THRESHOLD_MIN (default 240) AND reclaimable >= LEAN_LSP_MEM_FLOOR_MB (default 1024). Otherwise report it as "idle, cheap, kept" (or active). Interactive /refresh uses this same gate and the same numbers for its existing AskUserQuestion prompt.
(d) Tests (fixture /proc via PROC_ROOT, fixture state dir): CPU-delta idle state machine (first sighting not idle; unchanged cputime accrues idle_for; increased cputime resets), pid reuse with different starttime treated as a new tree, corrupt/missing state file, floor gate both sides of the threshold.
(e) Update Pass Inventory rows in commands/refresh.md and skills/skill-refresh/SKILL.md for the new idle definition and cost gate.

MUST NOT. Kill anything silently. Change UID/system-slice predicates or termination ordering. Edit .claude/**.

ACCEPTANCE. Active 5h-old tree whose cputime grows is never idle; a tree idle >=240 min with <1 GB reclaimable is reported kept; tests pass; shellcheck clean; redeploy and confirm.

DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

=== ABSORBED 2026-09-17 from former task 219 (notify-before-kill prompt path with snooze); that task is abandoned into this one. Its text follows verbatim; where it names "the dependency task" or "the sibling task", read this task's other sections. ===
SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**, a disposable deploy artifact).

OBSERVED LIVE (2026-09-15): a Lean LSP tree was reported as "15.1 GB" reclaimable while earlyoom showed 14-16.6 GB available throughout; real reclaim was ~2.3 GB swap plus a little anon. User policy: idle trees that cost nothing may stay; trees that cost memory get a prompt (never a silent kill) after being idle a while. Memory floor 1 GB approved.

WORK (builds on the cost gate and per-tree state file).
(a) Prompt path: when the headless hourly run (--dry-run) finds an eligible tree that is not snoozed or already prompted, launch a detached `systemd-run --user --unit=claude-refresh-prompt-<rootpid>-<starttime>` (the unit name must NOT match claude-*.scope, which the user's claude-session-reaper stops) running `notify-send -a claude-refresh -u critical -t 0 -A default=Kill --wait "Idle Lean tree (<project>)" "idle Xh, N GB reclaimable -- click to kill, dismiss to keep 4h"` (or equivalent that blocks on the chosen action). Project = lake serve cwd (/proc/PID/cwd).
    DESIGN REFINEMENT (notification daemon): the user runs mako with no dmenu-style action launcher, so named notify-send actions cannot be selected by clicking. Therefore use a single `-A default=Kill` action (mako left-click invokes the default action) and treat dismiss / right-click / expiry / no action returned as "Keep" (snooze). Pass `-t 0` so the notification does not auto-expire. The complementary mako rule ([app-name=claude-refresh] default-timeout=0) and the NixOS home-manager install of the timer/service with a correct PATH are handled by a separate ~/.dotfiles task (external, not in this repo).
(b) On the default action ("Kill", i.e. left-click): run `claude-refresh.sh --lean-tree <pid>:<starttime> --force`. The new --lean-tree mode re-verifies starttime identity, still idle, and still over the floor before the existing ordered workers -> server -> root termination; if anything changed, skip and log.
(c) On dismiss / right-click / expiry / any non-default outcome (treated as "Keep"): record snooze_until = now + LEAN_LSP_SNOOZE_MIN (default 240) in the state file. Dedupe so a tree is prompted at most once per snooze window (record prompted state before launching).
(d) Degrade gracefully when notify-send, systemd-run, or a DBus session bus is absent: log only, never kill.
(e) The hourly unit (systemd/claude-refresh.service) ExecStart stays --dry-run; prompting happens only in the separate transient unit. Keep generic units portable, but document that Environment=PATH=/usr/bin:/bin is broken on NixOS and that NixOS installs these units via home-manager (the dotfiles change is a separate task).
(f) Interactive /refresh keeps its AskUserQuestion prompt with the shared gate and numbers.
(g) Tests (fixture /proc via PROC_ROOT, stubbed notify-send/systemd-run on PATH): stubbed notify-send printing "default" -> kill path, printing nothing/other -> snooze path, starttime re-verification refusal (pid reused), still-idle/still-over-floor re-check refusal, snooze dedupe (no second prompt inside window, prompt again after expiry), missing notify-send/systemd-run/DBus degrades to log-only, unit name never matches claude-*.scope.
(h) Docs: commands/refresh.md and skills/skill-refresh/SKILL.md (Pass Inventory rows, --lean-tree flag, env vars LEAN_LSP_IDLE_THRESHOLD_MIN / LEAN_LSP_MEM_FLOOR_MB / LEAN_LSP_SNOOZE_MIN, prompt flow, NixOS note).

MUST NOT. Kill without explicit user action. Change UID/system-slice predicates or termination ordering. Edit .claude/**.

ACCEPTANCE. Tests pass; shellcheck clean; redeploy and confirm; a manual end-to-end check shows one notification per snooze window and a left-click Kill that refuses when the tree became active, and a dismiss that records a 4h snooze.

DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 185. Retarget stage citations to move vocabulary
- **Status**: [IMPLEMENTING]
- **Task Type**: markdown
- **Topic**: core-agent-system
- **Dependencies**: Task 266, Task 199, Task 184
- **Research**: [185_retarget_stage_citations_to_move_vocabulary/reports/01_stage-citation-survey.md]
- **Plan**: [185_retarget_stage_citations_to_move_vocabulary/plans/01_stage-citation-retarget.md]

**Description**: Retarget the remaining historical "Stage N" and "Stage MT-N" citations to the four-move loop vocabulary.

CONTEXT. skill-orchestrate/SKILL.md was rewritten from a two-engine, Stage-numbered state machine (single-task Stages 0-8; multi-task Stages MT-1 through MT-5) into a single four-move loop whose sections are named Move 1 through Move 4. Roughly 120 citations of the old vocabulary remain across 9 context/ and docs/ files. They now point at section names that no longer exist in the file they cite.

KNOWN SITES (from the rewrite's own survey; re-verify by grep rather than trusting this list):
  context/patterns/batch-orchestration-guardrails.md  -- 34 occurrences, the largest single concentration
  docs/architecture/handoff-schema.md
  docs/architecture/orchestrate-cycle-postflight.md
  docs/architecture/batch-admit-schema.md
  context/patterns/orchestrate-batch-results-template.md
  plus four further context/ and docs/ files

WHY IT WAS DEFERRED. The rewrite judged a ~120-citation mechanical sweep disproportionate to its core scope and recorded it as a follow-up rather than attempting it inline.

SCOPE AND CARE. This is a mechanical retarget, not a rewrite of the surrounding prose. Two hazards to respect: (1) some citations are historical-by-intent -- they describe what a now-deleted engine did, in a decision record or incident narrative, and must keep naming the old stage rather than being rewritten to a Move that never had that behavior; distinguish "cites a live section" from "narrates history" before editing. (2) Edit the source store under agent-system/extensions/** and never the deployed .claude/ tree (see rules/source-store-deploy-boundary.md).

ACCEPTANCE: every citation that refers to a LIVE section names the correct Move; every historical citation is either left intact or explicitly marked as historical; a grep for "Stage MT-" and for single-task "Stage [0-8]" returns only intentional historical references; deploy and the full gate run stay green.

=== PATH REVIEW 2026-09-28: scope and ordering ===
file_scope now names the five known sites; research MUST add the remaining files (a grep for 'Stage MT-' and single-task 'Stage [0-8]' matched 72 files under core/context, docs, skills and commands on 2026-09-28, most of them historical-by-intent) to file_scope before the implement dispatch. Ordered behind the three engine tasks that are actively editing batch-orchestration-guardrails.md and handoff-schema.md, so the mechanical sweep runs over settled text.

---

### 184. Surface skeleton-plan follow-ups at completion under the batch engine (ruled: port the sorry_inventory follow-up report, not pr_ready routing)
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 242, Task 243, Task 258, Task 259, Task 266
- **Research**: [184_decide_lean_skeleton_plan_completion_routing/reports/01_skeleton-follow-up-routing.md]
- **Plan**: [184_decide_lean_skeleton_plan_completion_routing/plans/01_skeleton-follow-up-reporting.md]
- **Summary**: [184_decide_lean_skeleton_plan_completion_routing/summaries/01_skeleton-follow-up-reporting-summary.md]

**Description**: === RULED 2026-09-22 (eighth-pass phase 0) ===
Disposition: option (a), narrowed to what was actually lost. The single-task engine's skeleton-exhaustion branch did three things: (1) routed the task to completion via the pr_ready target, (2) propagated a completion summary, (3) derived and reported follow-up tasks from sorry_inventory[].follow_up_task. Under the batch engine (1) is moot: pr_ready is a type=pr-only terminus, and every other task completes through orchestrate-cycle-postflight.sh's completion-claim gate, which a skeleton plan with all phases complete already reaches (orchestrate-cycle-plan.sh's 'no OPEN heading' fallthrough, ~line 2003, and the porting note at ~line 1921). (2) is owned by postflight generally. Only (3) is lost: a skeleton plan completes with its sorry_inventory silently dropped, so the strategic sorries never become tasks.

SCOPE (now concrete; no further decision phase). In orchestrate-cycle-postflight.sh, when the final implement handoff carries skeleton=true and a non-empty sorry_inventory[]: (i) print the follow_up_task entries in the cycle's stderr report and include them in the task's completion summary section; (ii) record them on the state.json entry in an append-only field (research picks the field -- a skeleton_follow_ups array or reuse of the memory_candidates shape -- and state-management-schema.md documents it); (iii) do NOT auto-create tasks: the report is the handoff and the user files them with /task. Document in status-markers.md and handoff-schema.md how a skeleton plan terminates now (through the completion-claim gate, follow-ups reported). Regression test in scripts/tests/test-orchestrate-cycle-postflight.sh with a skeleton=true fixture whose sorry_inventory has two entries. Options (b) and (c) of the original text are closed by this ruling. ORDERING: after 242 (same postflight script and test) and 243 (handoff-schema.md), recorded as dependency edges. The original decision text follows for the record.

Decide the disposition of the Lean/formal skeleton-plan completion routing lost with the single-task engine.

CONTEXT. The deleted single-task /orchestrate engine carried a skeleton-exhaustion completion branch: when no incomplete phase heading remained AND the last handoff declared skeleton=true, it derived a follow-up task list from the handoff's sorry_inventory[].follow_up_task entries, routed the task to completion via update-task-status.sh postflight with the pr_ready target and --allow-pr-ready, and reported the pending follow-ups. The surviving batch engine has no equivalent branch.

WHY THIS ONE NEEDS A DECISION AND HAS NOT HAD ONE. The rewrite recorded TWO capability losses. The loop-guard staleness detector got an explicit recommended follow-up. This one was recorded as a permanent loss with NO follow-up named at all -- it is the only deviation in that summary left without a next step. Lean and formal work is live in this repository, so silent acceptance should be a deliberate choice rather than an oversight.

SCOPE. Determine whether strategic-sorry skeleton plans can still reach a correct terminal status under the batch engine, and if not, what should happen. Evaluate at least: (a) port the skeleton-exhaustion branch into orchestrate-cycle-plan.sh or orchestrate-cycle-postflight.sh; (b) require skeleton plans to close through a different, already-supported path; (c) accept the loss explicitly and document how a skeleton plan is expected to terminate now. Do not pre-commit to an option.

EVIDENCE. The assertions covering this mechanism (.skeleton / last_skeleton and .sorry_inventory / follow_up_tasks) were removed from scripts/tests/test-handoff-reader-parity.sh. Recorded under "Plan Deviations" in specs/088_mode_gate_skill_orchestrate_multi_task_section/summaries/01_four-move-loop-rewrite-summary.md. Related policy: the strategic-sorry skeleton allowance in context/contracts/recovery.md.

ACCEPTANCE: a recorded decision with rationale; if a gap is confirmed, either a working path to terminal status for skeleton plans with test coverage, or documentation naming the expected terminus.

---

### 170. Audit and isolate shell test suites from ambient host state (memory and timing axes), and record the convention
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 51, Task 129, Task 151, Task 169, Task 206, Task 215, Task 250, Task 251

**Description**: Audit all shell test suites in the source store for assertions whose outcome depends on ambient host state, isolate each at the script-under-test's own documented env seams (or, where no seam is possible, by a technique appropriate to the axis), and record the isolation convention in `context/standards/shell-script-testing.md` so future suites inherit it by default.

=== TWO CONFIRMED INSTANCES -- THE DEFECT CLASS IS NOT A SINGLE-SUITE ANOMALY ===

Both were observed live. They sit on DIFFERENT axes and need DIFFERENT remedies.

--- INSTANCE A (memory axis) -- `test-lake-build-guard.sh`, cases 1, 3, 11 ---

Failed because `lake-build-guard.sh` read the REAL `/proc/pressure/memory` and `/proc/meminfo`,
and the host was swapping at 57% of SwapTotal -- over the guard's own
`SWAP_USED_RATIO_THRESHOLD=50`. Cases 1 and 3 assert byte-identical transparency on the guard's
clean path; case 11 asserts preflight exits 0 when the PSI path is unavailable. All three pass on
an idle machine and fail on a busy one -- and a busy machine is exactly what a multi-task
`/orchestrate` batch produces.

ALREADY FIXED -- DO NOT REDO. Commit `878043472` isolates this suite suite-wide by redirecting
`LAKE_BUILD_GUARD_PSI_PATH` and `LAKE_BUILD_GUARD_MEMINFO_PATH` to clean fixture files in the
suite's own mktemp workdir, via the script's documented env seams. Verified 27/27 pass and
verified non-vacuous. This suite is the EXEMPLAR the audit generalizes from, not work to repeat.
The separate positive-direction case for it is tracked as its own prerequisite task (this task
depends on it) -- do not duplicate that either.

--- INSTANCE B (timing axis) -- `test-four-tier-conflict.sh`, case 6 "budget-bound" ---

CONFIRMED AFFECTED, NOT YET FIXED. This one is the task's primary unsolved exemplar.

Evidence, all observed live:
  - Pre-fix full `run-all.sh`: this suite PASSED (only `test-lake-build-guard.sh` failed).
  - Post-fix full `run-all.sh`: this suite FAILED with
      `6: budget-bound -- rc=1 elapsed_ms=2989 budget_ms=1000`
  - Immediate ISOLATED re-run of the same suite: PASSED, with
      `6: budget-bound -- exhaustion elapsed 1752ms within [1000ms, 2000ms)`

Commit `878043472` touched exactly one file (`test-lake-build-guard.sh`), so it cannot have
caused this. The discriminating fact is the isolated re-run passing. The assertion at
`test-four-tier-conflict.sh:294` is a wall-clock window:

    [ "$rc6" -eq 1 ] && [ "$elapsed6_ms" -ge "$BUDGET_MS" ] && [ "$elapsed6_ms" -lt $(( BUDGET_MS * 2 )) ]

with `BUDGET_MS=1000`. The window `[1000ms, 2000ms)` holds on an unloaded machine and breaks under
concurrent load. Same "outcome determined by ambient host state" shape as instance A, on the
timing axis instead of the memory axis.

ADJACENT, SAME SUITE, LIKELY SAME DEFECT: case 5 (`test-four-tier-conflict.sh:271`) asserts
`elapsed5_ms -lt 500` as a proxy for "the retry loop was never entered". That is the same
wall-clock-as-proxy shape and is expected to flake under load for the same reason; triage it
alongside case 6 rather than treating case 6 as isolated. Case 1 also reports elapsed wall
clock -- check whether it merely reports or actually asserts on it.

--- WHAT THE SECOND INSTANCE CHANGES ABOUT SCOPING ---

1. The audit premise is confirmed empirically, not speculative.
2. The timing axis is genuinely represented, so the audit MUST cover wall-clock windows and
   elapsed-time proxies, not only `/proc` reads.
3. The shell-test-suite gate is currently FLAKY, not simply red: `run-all.sh` has now failed
   twice in a row for two DIFFERENT single-suite reasons. Acceptance is set accordingly below.

=== BLAST RADIUS (why this warrants a dedicated audit, not a one-off patch) ===

A single suite failure fails `verify-deploy.sh`'s shell-test-suite gate (1 of 30 checks), which
fails `deploy-headless.sh`, which makes `skill-orchestrate`'s inter-cycle redeploy checkpoint
defer an ENTIRE orchestrate batch. One host-coupled assertion in one suite stalls unrelated work.
The defect class is load-bearing on throughput, not merely on test hygiene. A flaky gate is worse
than a red one: it defers batches nondeterministically and trains readers to re-run rather than
diagnose.

=== THE DEFECT CLASS TO HUNT ===

Any assertion whose outcome depends on ambient host state:
  - memory (`/proc/meminfo`, `/proc/pressure/memory`, swap usage, `free`)          [instance A]
  - wall-clock timing (elapsed-time windows, `sleep`-dependent ordering,
    `date +%s` / `%N` deltas, `SECONDS`, `timeout` values tuned to a fast machine)  [instance B]
  - load / CPU count (`/proc/loadavg`, `nproc`, `getconf`, `uptime`)
  - network reachability (`curl`, `wget`, `ping`, DNS, any live API)
  - free disk (`df`)
  - the process table (`pgrep`, `ps`, PID reuse, pre-existing processes matching a pattern)
  - anything else read from the live host rather than from a fixture

=== SURVEY ALREADY PERFORMED (starting point, NOT the answer) ===

72 files match `test*.sh` under `agent-system/extensions/**`. A keyword grep over the signals
above flagged 25. Ordered by raw hit count:

  13  core/scripts/test-four-tier-conflict.sh               (INSTANCE B -- confirmed affected)
  12  core/scripts/tests/test-lake-build-guard.sh           (INSTANCE A -- already isolated)
   6  literature/scripts/test-lit-pipeline.sh
   6  core/scripts/tests/test-validate-state.sh
   6  core/scripts/tests/test-claude-refresh-matcher.sh
   4  core/scripts/test-state-write-concurrency.sh
   3  literature/scripts/tests/test-literature-convert.sh
   3  lean/scripts/tests/test-lean-comparator-run.sh
   3  core/scripts/tests/test-loop-guard-budget-override.sh
   2  literature/scripts/tests/test-literature-discover-tier3.sh
   2  core/scripts/tests/test-subagent-postflight-marker.sh
   2  core/scripts/tests/test-lint-branch-gated-sections.sh
   2  core/scripts/tests/test-handoff-dispatch-identity.sh
   2  core/scripts/test-state-write-regen-timing.sh
   2  core/scripts/test-session-registry.sh
   2  core/scripts/test-conflict-predicate.sh
   1  each: core/scripts/test-task-lock-reap.sh, core/scripts/test-session-runtime-files.sh,
          core/scripts/tests/{test-validate-return-meta,test-status-vocabulary,
          test-skill-base-lifecycle,test-phase-heartbeat,test-phase-heading-patterns,
          test-guard-destructive-git,test-common-lib}.sh

Both confirmed instances rank first and second, which is mild evidence the ranking carries signal
-- but RAW HIT COUNT IS NOT SEVERITY, and this list is neither sound nor complete:
  - FALSE POSITIVES ARE EXPECTED. A `sleep` inside a concurrency suite that deliberately
    exercises lock contention may be legitimate; `pgrep` inside a suite whose subject IS process
    matching (`test-claude-refresh-matcher.sh`, `test-task-lock-reap.sh`) may be exercising the
    real behavior under test. Triage each hit; do not mechanically "fix" every match.
  - FALSE NEGATIVES ARE LIKELY. The grep cannot see host coupling entering through a library the
    suite sources, through the script under test rather than the suite itself (exactly how
    instance A arrived), or through a helper that shells out. Read the scripts under test, not
    only the suites. Suites absent from this list are NOT thereby cleared.
  - Names containing `timing`, `concurrency`, `heartbeat`, `budget`, `reap`, or `staleness` are
    prior-suspect on the timing axis regardless of hit count.

=== REQUIRED APPROACH -- SEAM-FIRST, BUT DO NOT PRESUME THE SEAM REMEDY TRANSFERS ===

For state READ FROM A FILE OR COMMAND (the memory/`proc`/disk/network/process axes), instance A's
remedy is the model:
  1. Identify the script-under-test's OWN documented env seam (`lake-build-guard.sh` provides
     `LAKE_BUILD_GUARD_PSI_PATH` / `LAKE_BUILD_GUARD_MEMINFO_PATH`). Prefer an existing seam.
  2. If none exists, adding one to the script under test is in scope -- but it must be a genuine,
     documented override point with a real-host default, NEVER a test-only branch or an
     "if running under test" conditional.
  3. Point the seam at a fixture authored into the suite's own mktemp workdir, per the existing
     fixture convention in `context/standards/shell-script-testing.md` (heredoc-authored, fresh
     per case where staleness would otherwise mask behavior, never resolved against the live tree).

For WALL-CLOCK TIMING (instance B), THE SEAM REMEDY MAY NOT APPLY AT ALL. There may be nothing to
redirect: the quantity is elapsed real time, not a readable input. Do not force the memory-case
technique onto it. Evaluate at least these, per assertion, and justify the choice:
  - Inject the clock -- give the script under test a seam for its time source so the suite can
    drive elapsed time deterministically. Strongest option where feasible.
  - Assert ORDERING or CAUSALITY instead of elapsed wall clock -- e.g. for case 6, that the retry
    loop terminated on budget exhaustion rather than on a lock acquisition, and for case 5, that
    the retry loop was never entered at all. Both are the property the elapsed-time window is
    only a PROXY for; asserting the property directly removes the host coupling without weakening
    anything. Prefer this where the underlying property is observable (a counter, a log line, a
    return path).
  - Widen the window to generous-but-still-bounded ONLY as a last resort, and only when the
    widened bound still falsifies the failure mode the assertion exists to catch (for case 6:
    "nowhere near a minutes-scale wait"). A bound that no longer discriminates is a deleted test.
    This option requires explicit justification in the summary naming what it still catches.

NON-VACUOUSNESS CHECK PER ISOLATED SUITE, MANDATORY on every axis. After isolating, demonstrate
the logic under test is still genuinely exercised -- typically by driving the opposite direction
with a fixture or condition that SHOULD trip the behavior and confirming it does. An isolation
that makes a suite assert nothing is worse than the host coupling it replaced. Record each check.

=== CONSTRAINTS ===

- All edits target `agent-system/extensions/**` ONLY. Never hand-author anything under
  `.claude/**`; that tree is a disposable deploy artifact regenerated from source
  (see `.claude/rules/source-store-deploy-boundary.md`).
- NEVER weaken, raise, or bypass a guard threshold, loosen an assertion into vacuity, or mark a
  case skipped to make a suite pass. Isolate the INPUT; do not relax the ASSERTION. The
  last-resort window-widening above is a bounded, justified exception on the timing axis only --
  it is NOT licence to relax thresholds generally, and never applies to a guard's own constants.
- Where a suite legitimately depends on real host state and cannot be isolated, use the loud-skip
  discipline already documented in `shell-script-testing.md` rather than a silent skip, and
  justify the exemption in the summary.

=== DELIVERABLE: THE CONVENTION ===

Extend `agent-system/extensions/core/context/standards/shell-script-testing.md` (127 lines;
existing sections: Location rule, Helper-naming convention, Fixture convention including "Never
resolve a path against the live tree", Loud-skip discipline, Mutation checks for regex-shaped
fixes, Registration, Related). Add an ambient-host-state isolation section that:
  - names the defect class and why it is load-bearing (the deploy-gate blast radius above),
    citing both confirmed instances as the worked examples -- one per axis;
  - states the seam-first rule for readable-input axes, and the bar for adding a new seam;
  - states separately that the timing axis needs a different technique, with the
    inject-clock / assert-causality / bounded-widening ladder and the rule that elapsed wall
    clock must not be used as a proxy for a property that is directly observable;
  - requires the per-suite non-vacuousness check;
  - forbids threshold relaxation as a remedy;
  - cross-references the existing Fixture convention and Loud-skip discipline sections rather
    than restating them.
Place it so it composes with, not duplicates, what is already there.

=== ACCEPTANCE ===

- Every one of the 72 suites has been triaged, with a recorded verdict: affected-and-isolated,
  false-positive-with-reason, or legitimately-host-dependent-and-loud-skipped.
- Instance B (`test-four-tier-conflict.sh` cases 6 and 5) is fixed, with the chosen technique
  justified against the ladder above.
- Each isolated suite carries a demonstrated non-vacuousness check.
- REPEATED-RUN ACCEPTANCE, NOT A SINGLE GREEN RUN. "run-all.sh passes once" is too weak: the gate
  has already failed twice consecutively for two different single-suite reasons, and instance B
  passes in isolation while failing in a full run. Require instead:
    (a) `run-all.sh` green across multiple consecutive runs (at least 3);
    (b) at least one of those runs under DELIBERATE concurrent load -- both memory pressure above
        the lake guard's own threshold and CPU/IO contention sufficient to have reproduced the
        case 6 failure, verified by first confirming the load reproduces the ORIGINAL failures on
        a pre-fix checkout;
    (c) full-run and isolated-run results agreeing for every suite -- a suite that passes alone
        but fails in the batch is still affected.
  Record the load-generation method used so the check is reproducible.


=== SCOPE NARROWED 2026-09-22 (eighth-pass phase 0) ===
The three whole-directory file_scope entries (core/scripts/tests/, lean/scripts/tests/, literature/scripts/) were removed: they deferred 207, 217, 223 and 244 in the dry run and drew two validate-state.sh coarse-scope warnings spanning 11 tasks. The named test-*.sh files, task-lock.sh and shell-script-testing.md stay. Research MUST name the specific suites the audit will edit and ADD them to file_scope before the implement dispatch (the convention the 224 narrowing followed on 2026-09-17). ORDERING: after 51 (task-lock.sh, test-session-runtime-files.sh) and 129 (test-session-runtime-files.sh, test-lake-build-guard.sh), recorded as dependency edges.

=== DEPENDENCY ADDED 2026-09-22 (new suites enter the triage set) ===
Two newly created tasks each add a standing repo-health probe WITH ITS OWN TEST SUITE (test-script-inventory.sh and test-context-reachability.sh). This task's acceptance criterion is that EVERY suite has a recorded triage verdict, so the audit must run after those suites exist or it certifies a set it no longer covers. Dependency edges recorded accordingly; the survey count above ("72 files match test*.sh") is the 2026-09-22 figure and MUST be re-derived at research time rather than trusted -- the corpus grows.

=== EVIDENCE ADDENDUM (2026-09-22, observed live) ===

INSTANCE A IS NOT CLOSED BY THE EXISTING FIX -- the defect class is still live post-878043472.

During an /orchestrate implement dispatch, a full `run-all.sh` over the SOURCE STORE copy
reported `test-lake-build-guard.sh` FAILING. An isolated re-run of the same suite immediately
afterwards, on the same machine and same commit, reported `Passed: 47  Failed: 0`.

This is the SAME discriminating shape already recorded for Instance B
(`test-four-tier-conflict.sh` case 6): fails inside a loaded full-suite run, passes in
isolation. It confirms that the env-seam redirection in 878043472 (LAKE_BUILD_GUARD_PSI_PATH /
LAKE_BUILD_GUARD_MEMINFO_PATH to fixture files) did NOT make the suite fully load-independent --
some assertion in it still reads ambient state, or is timing-sensitive, on an axis the fixture
redirection does not cover.

IMPLICATION FOR THIS TASK'S SCOPE: the "ALREADY FIXED -- DO NOT REDO" note above should be read
as "the memory axis was isolated", NOT as "this suite is now load-independent". The audit must
re-examine this suite rather than treating it purely as the exemplar to generalize from.
Determining WHICH case fails under load is the first concrete step -- the full-suite run does
not name it, so the failing case must be captured by re-running under induced load with
per-case output retained.

Contemporaneous context that plausibly supplied the load: the same run-all.sh invocation took
~40 minutes of wall clock with concurrent agent activity on the machine.

=== ROSTER ADDENDUM (2026-10-04, measured) — A SECOND DEFECT CLASS SHARES THIS GATE ===

Measured roster, from a full `run-all.sh` on a committed tree:
`103 passed, 6 failed (2 expected, 4 NEW), 2 skipped, 111 total`. The suite corpus is now 111,
not the 72 recorded above — re-derive it at research time as this task already instructs.

This task's acceptance requires `run-all.sh` green across at least 3 consecutive runs with
full-run and isolated-run agreement for every suite. That is currently unreachable, and NOT
because of ambient-host-state coupling. A SECOND, DISTINCT defect class is red on the same gate:
**sandbox-fixture incompleteness** — a suite's hardcoded copy-list omits a collaborator the real
script-under-test invokes, so the first real invocation dies with a 127 that surfaces as an
unrelated assertion mismatch much later. This is the same mechanism `known-failures.txt`'s own
header records as having produced three earlier phantom failures via a missing
`lib/return-meta-status-vocabulary.sh`.

DO NOT TRIAGE THESE AS AMBIENT-HOST-STATE. They are load-INdependent and reproduce identically in
isolation. Misfiling them as instance-A/instance-B-class would corrupt this task's triage verdicts.

Current roster, with what is already established about each:

  test-orchestrate-cycle-plan.sh        (NEW) — 335 passed, 14 failed. Fixture gap PARTLY FIXED
      already: `generate-task-order.sh` and `update-plan-status.sh` (transitive collaborators of
      the real `generate-todo.sh`/`update-task-status.sh` the Group 28 block copies) were added to
      its copy-list, which removed the 127 cascade. The 14 remaining failures are Group 28/29 and
      are a REAL product question, not a fixture gap: Group 28 expects an IDENTICAL DISPATCH HALT
      to fire on cycle 2 and it does not; Arms B/C/D expect the same halt and the streak-freeze
      notice. Needs its own verdict: either the halt mechanism is broken or the expectations are
      stale. This is the single largest block of red in the corpus.
  test-orchestrate-build-aux-dispatch.sh (NEW) — 17 passed, 1 failed. `plan-revision`'s model
      resolves to empty where the suite expects `opus`. Established: `reviser-agent.md` really does
      carry `model: opus` in its own frontmatter, and task 331's change to
      `lib/manifest-routing-lib.sh` was purely additive (107 insertions, 0 deletions), so neither
      the agent file nor that change explains it. Root cause undetermined.
  test-detect-noop-bash.sh              (NEW) — root cause undetermined. Note its subject
      (`hooks/detect-noop-bash.sh`) writes the per-session `tmp/noop-bash-count-*` marker whose
      orphan-detector exclusion was added separately; check whether the suite and that exclusion
      now disagree.
  test-lint-deploy-caller-wrap.sh       (NEW) — root cause undetermined. Its reported finding is
      about `orchestrate-cycle-plan.sh` not being "wrapped to true EOF" in a self-test scratch
      copy, which smells like a scratch-copy construction artifact rather than a product defect.
  test-gate-out-repair-reporting.sh     (EXPECTED, real-defect, needs-owner)
  test-lint-json-channel-discipline.sh  (EXPECTED, real-defect, needs-owner)

The two EXPECTED rows carry `needs-owner`, and `known-failures.txt`'s own header states that a
`needs-owner` row is a known gap rather than an accepted steady state, requiring a follow-up to
either fix or formally accept each. Since this task's acceptance is a green gate, give each of
the two an explicit verdict here rather than leaving them to a further task.

ALREADY FIXED — DO NOT REDO (all verified, all committed):
  - `test-verify-deploy-context-budget.sh` resolved `REPO_ROOT` by a fixed four-hop `..` walk,
    correct from the source store but overshooting to `$HOME` from the deployed tree that
    `run-all.sh` actually uses. It exited 2 on a path that never exists, so Gate 20 was entirely
    unexercised. Replaced with upward marker discovery; the suite is now 15 passed, 0 failed and
    its `known-failures.txt` row is REMOVED. That row's recorded reason was a mis-diagnosis
    (it blamed `skill-orchestrate/SKILL.md` being over ceiling; the file measures 19,921 B against
    a 20,000 B ceiling and gate20 reports zero findings) — treat other recorded reasons in that
    file as unverified until re-measured.
  - The root `.gitignore` had drifted five canonical ephemeral-class patterns behind
    `scripts/lib/runtime-file-patterns.sh`; the context-budget fixture copied that root file, so
    gate14 failed inside the fixture. Both the drift and the fixture's dependence on a
    hand-maintained file are fixed (it now appends `runtime_ignore_block()` from the single source
    of truth, as `test-deploy-orphans.sh` already did).
  - `tmp/noop-bash-count-*` is now an `is_runtime_artifact` exclusion with a planted-canary
    regression, removing a flaky whole-tree orphan finding.

METHOD NOTE for the fixture-completeness class: the reliable detection is to enumerate every
`${SCRIPT_DIR}/<name>.sh` invocation in each REAL script a suite copies into its sandbox, then
diff that set against the suite's copy-list. That is mechanical and worth doing corpus-wide; a
lint for it would prevent the class recurring, and is a better deliverable than fixing the
current instances one at a time.

---

### 165. Admission gates in orchestrate-batch-admit.sh: posture for an absent file_scope, then cross-session visibility for self-modifying candidates
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: file-scope-lifecycle
- **Dependencies**: Task 162, Task 163, Task 245
- **Research**: [165_admission_posture_for_absent_file_scope/reports/01_admission-posture-absent-scope.md]
- **Plan**: [165_admission_posture_for_absent_file_scope/plans/01_admission-posture-absent-scope.md]
- **Summary**: [165_admission_posture_for_absent_file_scope/summaries/01_admission-posture-absent-scope-summary.md]

**Description**: Settle whether an ABSENT `file_scope` should be admission-relevant in agent-system/extensions/core/scripts/orchestrate-batch-admit.sh, or remain purely advisory -- and implement the ruling.

THE MOTIVATING HARM (observed live in ~/Projects/BimodalLogic, not hypothetical):
- `/orchestrate 530,531` correctly deferred one task cross-batch for overlapping a live task at README.md -- the collision guard working exactly as designed.
- `/orchestrate 544,545` dispatched BOTH with ZERO collision-guard coverage, purely because neither declares a file_scope at all. A live concurrent task held a broad scope (FormalSystem/, Tests/, docs/, typst/, README.md) and one of the dispatched pair worked the same naming domain that live task was mid-rename on. Nothing would have caught a conflicting concurrent edit.
The guard did not fail. It was never consulted, because the predicate has nothing to compare. An undeclared scope is currently indistinguishable from a scope that provably collides with nothing.

THE TRADEOFF (this is the decision, state it explicitly): treating absence as a defer reason closes the silent-passage hole but risks blocking legitimate work on legacy tasks that predate any file_scope discipline. That risk is what the sequencing mitigates -- this task is gated behind both the detection work and the backfill precisely so the legacy population is already covered before absence can block anything. Verify that mitigation actually landed before tightening; if backfill coverage is incomplete, prefer the softer posture and say why.

EXISTING MECHANICS TO WORK WITHIN (the script's own documented contract): `defer_reason` currently admits "self_modifying", "file_scope_collision", and "session_active". A `file_scope_collision` defer carries `colliding_task_number`, `colliding_task_status`, `overlapping_path`, `collision_scope`, and `corroborated_by`. An absent-scope defer has NO colliding task and NO overlapping path, so it does not fit that payload shape -- it is a different kind of fact (missing information, not detected conflict). If a defer is chosen, it likely needs its OWN reason value rather than being forced into file_scope_collision, whose fields would all be empty. Note also the documented override asymmetry: file_scope_collision and session_active have specific override semantics -- decide where a new reason sits in that hierarchy.

ENFORCEMENT LEVEL -- PRIOR ART, FOLLOW IT: plan-format.md:259-266 records the Verification Tier rollout as the in-repo precedent. Quoted: enforcement is "advisory-first: a missing field emits a warning, not an error, so default-mode validation of plans authored before this vocabulary existed continues to pass. `--strict` mode enforces it today. Promotion criterion: promote the warning to an error once no non-terminal plan under specs/ lacks the field." The same three-part pattern applies: start advisory, WRITE DOWN the promotion criterion, promote only once coverage is complete. A defensible outcome for this task is explicitly deciding NOT to make absence blocking yet, and recording the coverage threshold at which it should become blocking -- that is a real decision, not a deferral, and it must be written into the script header either way.

OPTIONS TO WEIGH: (a) advisory only -- surface in the review, never affect admission; (b) a new non-blocking `defer_reason` visible in output but overridable; (c) a genuine defer gated on a coverage precondition; (d) blocking only when a live task holds a broad scope, i.e. treat absence as risky only in the presence of an actual concurrent hazard, which directly matches the observed harm and is the narrowest fix.

ACCEPTANCE: the ruling and its reasoning are recorded in the script's header contract alongside the existing defer_reason documentation; if a new reason value is added, its payload fields and override semantics are documented to the same standard as the existing three; the observed harm scenario is reproduced as a test case and the chosen posture demonstrably changes its outcome (or is documented as deliberately unchanged); shellcheck clean per context/standards/shell-strict-mode.md.

CANONICAL SOURCE CONSTRAINT (binding): all edits target /home/benjamin/.config/nvim/agent-system/extensions/core/. Never hand-edit any deployed .claude/** tree -- it is gitignored, disposable, and regenerated from the source store by the loader, so edits there are silently wiped. DELIVERABLE RULE: no task numbers in deliverables outside specs/**.


=== ADDITIONAL EVIDENCE (2026-09-21, ~/Projects/Logos/Verification, session sess_1790009936_0a5e95) ===
A SECOND, LARGER INSTANCE OF THE MOTIVATING HARM -- IN-BATCH, NOT CROSS-SESSION. `/orchestrate
66,70,72,76,77,81,84,85` (8 tasks, all task_type general, all created without file_scope) reached
the implement phase with every task planned. `orchestrate-cycle-plan.sh --dry-run` reported:
Dispatch = all 8, Deferred = 0, Blocked = 0 -- i.e. it would have run 8 implementers concurrently
in ONE working tree. The plans themselves showed heavy real overlap, found only by an operator
reading them:
  - framed_channel/check.sh edited by 3 tasks (one a 9-phase refactor of it);
  - .github/workflows/verify.yml: one task edited the comparator-arm job while another DELETED it;
  - docs/ci.md edited by 4 tasks;
  - 4 tasks ran the full local verification gate, which regenerates the committed certificate --
    concurrent gate runs over a tree other agents are mid-edit would have produced wrong results.
The collision guard did not fail; as in the BimodalLogic case it was never consulted, because
every candidate's file_scope was absent.

OPERATOR REMEDY THAT WORKED (and what it implies for the ruling): the operator hand-populated
file_scope for all 8 tasks from each plan's "Files to modify" lists and re-ran the dry-run. The
existing in_batch predicate then serialized correctly (cycle 3: 2 admitted, 6 deferred with
accurate overlap reasons), and the batch completed across 6 implement cycles with zero
cross-task clobbers, all eight committing cleanly. Two implications:
  1. The information needed was already on disk at plan time (every plan listed its files) --
     direct support for harvesting file_scope from plans (the formalize/harvest task) as the
     primary fix, with this task's posture as the backstop.
  2. For the in_batch case specifically, the "defer on absence" posture is cheap: an absent-scope
     task in a multi-task batch has no evidence it is disjoint from its siblings, and the cost of
     wrongly serializing is extra cycles, while the cost of wrongly parallelizing was (here)
     concurrent edits to the same gate script and concurrent certificate-regenerating gate runs.
     Consider ruling separately for in_batch (strict: absent scope => serialize against every
     sibling, or refuse admission until scope is declared) vs cross_batch (the tradeoff already
     stated above).


=== ABSORBED 2026-09-22 from former task 190 (Fix cross-session admission blindness for self-modifying candidates); that task is abandoned into this one. Its text follows verbatim; where it names "the dependency task" or "the sibling task", read this task's other sections. ===

SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**).

DEFECT. Two SELF-MODIFYING tasks running in SEPARATE concurrent /orchestrate sessions are mutually invisible to every admission gate. Each is admitted solo; neither sees the other; they proceed to edit the same orchestrator-critical file concurrently.

OBSERVED LIVE (2026-09-08, this repository, not hypothetical). Two /orchestrate sessions ran concurrently under the same ancestor pid:
  sess_1788883218_cb46bc  /orchestrate 180,181,182
  sess_1788889066_9309df  /orchestrate 189
Both batches claimed agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh. Three commits landed on that file from the 189 session while the other session was in cycle-6 planning for 182. No gate fired. The collision was caught only by a human reading a task notification. 182 had not yet dispatched, so no clobber occurred -- this was luck, not a gate.

MEASURED EVIDENCE (direct probe, reproducible):
  bash .claude/scripts/orchestrate-batch-admit.sh --session-id <A> 182
    -> {"decision":"admit","self_modifying":true}
  bash .claude/scripts/orchestrate-batch-admit.sh --session-id <B> 189
    -> {"decision":"admit","self_modifying":true}
  bash .claude/scripts/orchestrate-batch-admit.sh --session-id <B> 182 189   # SAME batch
    -> 182 admit; 189 DEFER, defer_reason self_modifying, full critical_path + ordering reason
  bash .claude/scripts/orchestrate-batch-admit.sh --session-id <A> 157       # NOT self-modifying
    -> admit + idle_overlap_advisory naming out-of-batch task 170, collision_scope cross_batch

WHAT THIS ISOLATES. The in-batch tie-breaker works correctly. The cross-batch file_scope scan also works -- it fired for the NON-self-modifying candidate (157) against an out-of-batch task. But for a SELF-MODIFYING candidate dispatched solo, the verdict carries no cross-batch collision result and no session-registry result at all. The self-modification branch appears to admit early and short-circuit the file_scope_collision and session_active passes that would have caught the overlap. Confirm that reading against the script's own documented pass ordering (self-mod, then file_scope_collision, then session_active, the last two reached only when the prior finds no hit) before changing anything.

CONTRIBUTING FACTOR, ALREADY REMEDIED, DO NOT RE-FILE. Task 189 carried no file_scope at all, so its session registered an empty covered scope. That was repaired by hand during the incident and is not the root cause: with all 11 paths populated AND the session registry re-registered to match, the solo verdicts above STILL admit. Absent metadata made it worse; it did not cause it.

MUST NOT. Do not make the solo self-modifying candidate DEFER -- that would mean zero dispatch on every solo run of a self-modifying task, which is the exact regression the pre-existing tie-breaker design avoids. The admission DECISION is defensible; what is missing is that the verdict does not carry, and the caller cannot see, a live cross-session collision. Do not change the collision predicate or the verdict schema's existing fields in ways that break orchestrate-predispatch-review.sh, which is a consumer.

ACCEPTANCE. With two live registered sessions whose covered scopes overlap on at least one path, a solo self-modifying candidate in one of them produces a verdict that names the overlap (defer, or admit carrying an explicit cross-session hazard field that orchestrate-predispatch-review.sh renders). A fixture test reproduces the two-session case above and fails against the current script.

NOTE ON LIVENESS DETECTION. Both sessions in the incident reported the SAME pid with pid_source ancestor-claude, because two /orchestrate runs inside one Claude Code process share an ancestor. Any self-exclusion keyed on pid rather than session_id would treat a foreign session as self and silently disable cross-session detection for the most common case. Verify which key the exclusion actually uses; if it is pid, that alone may be the whole defect.

---

### 127. Collapse routing ladder to routing agents
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 121, Task 124, Task 125
- **Research**: [127_collapse_routing_ladder_to_routing_agents/reports/01_routing-ladder-collapse.md]
- **Plan**: [127_collapse_routing_ladder_to_routing_agents/plans/01_routing-ladder-collapse.md]
- **Summary**: [127_collapse_routing_ladder_to_routing_agents/summaries/01_routing-ladder-collapse-summary.md]

**Description**: === REVISED 2026-09-01 (backlog streamline: absorbs the present-routing residue) ===
ADDITIONAL WORK ITEMS, absorbed from the abandoned present-extension routing task: (5) while rewriting the manifests, resolve present/manifest.json's colon-suffixed compound values -- its routing.implement block ("present:grant" -> "skill-grant:assemble" style) disappears with the collapse, mooting the skill-name half of the original defect, but audit routing_agents for any analogous colon-suffixed AGENT value encoding workflow_type into a name no consumer splits, and settle the encoding (drop the suffix and carry workflow_type another way, or make the resolver split and expose it as a sub-mode variable). (6) extend lint-routing-wiring.sh so any routing_agents value naming a nonexistent agent file fails verify-deploy -- the original defect (a manifest naming a nonexistent dispatch target, shipped silently) must be impossible to reintroduce under the collapsed model.
=== ORIGINAL DESCRIPTION FOLLOWS ===
Collapse the routing ladder to routing_agents-only across all 19 extension manifests; retire command-route-skill.sh.

CONTEXT. Every extension manifest may declare up to four routing blocks today (routing, routing_hard, routing_agents, routing_agents_hard), resolved by the shared five-step ladder in scripts/lib/manifest-routing-lib.sh. Once /research, /plan, /implement are deleted (no skill layer left to route to) and the hard-mode collapse lands (no separate hard-routing table needed -- hard mode becomes a dispatch-prep injection, not a different resolved agent file), only routing_agents remains meaningful.

WORK. (1) Remove the routing and routing_hard blocks from every extension manifest that declares them, retaining only routing_agents (plus any extension-specific op like present's critique). (2) Retire command-route-skill.sh -- confirm no remaining caller (only the now-deleted /research, /plan, /implement, /revise-adjacent paths called it; /revise itself does not use this resolver and is unaffected). (3) Update context/guides/manifest-routing-schema.md to document the collapsed two-block model (down from four), including the completeness-lint contract re-scoped to check only routing_agents completeness against itself. (4) Re-scope lint-routing-wiring.sh's Checks A/C accordingly.

DEPENDS ON both the command deletions (routing/skill-dispatch has no remaining caller) and the hard-mode file deletions (routing_hard/routing_agents_hard has no remaining caller) having already landed.

SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/*/manifest.json (all 19), agent-system/extensions/core/scripts/command-route-skill.sh, agent-system/extensions/core/context/guides/manifest-routing-schema.md, agent-system/extensions/core/scripts/lint/lint-routing-wiring.sh (never .claude/**).
DELIVERABLE RULE: no task-number references in any deliverable outside specs/**.

REFERENCE: specs/116_core_agent_system_consolidation/reports/03_target-state-design.md (A3).

---

### 89. Mode gate literature and distill skills
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 87
- **Research**: [089_mode_gate_literature_and_distill_skills/reports/01_mode-gate-literature-distill.md]
- **Plan**: [089_mode_gate_literature_and_distill_skills/plans/01_mode-gate-literature-distill.md]
- **Summary**: [089_mode_gate_literature_and_distill_skills/summaries/01_mode-gate-literature-distill-summary.md]

**Description**: Apply the mode-gated section convention to the two remaining large instances, after the pilot proves it.

skill-literature/SKILL.md, 84,265 B total, 64.5% fenced bash. Seven mutually exclusive mode sections of which exactly ONE fires per invocation: Mode: Rebuild 20,170 | Mode: Convert 17,534 | Mode: Search 10,043 | Mode: Validate 5,989 | Mode: Import Pipeline 5,785 | Mode: Index 5,234 | Mode: Ingest 1,917 = ~65,772 B, 78% of the file. Cleanly '## Mode:'-delimited, so the split is mechanical. Estimated ~14,000 tokens per /literature invocation, taking it from ~46.2k toward ~32k.

skill-distill/SKILL.md, 93,044 B total, only 1.9% bash -- essentially pure prose. `## Auto Distill Complete` is 43,254 B, 46% of the file, and is an OUTPUT TEMPLATE used by --auto alone. It belongs in context/formats/, not in a skill body loaded on every /distill invocation. Estimated ~10,800 tokens per non---auto /distill, taking it from ~42.4k toward ~32k.

Combined estimated saving ~24,800 tokens across the two commands' invocations.

Both carry the same fence-interior heading hazard as the orchestrate application -- '## Mode:' and '## Auto' strings can appear inside fenced examples. Split bottom-up and verify each extracted section round-trips.

ACCEPTANCE: each mode section loads only when its mode is selected; all seven literature modes and both distill paths verified working; measured reductions reported against the 46.2k and 42.4k baselines.

---

### 29. Generate .mcp.json from extension manifests, then register obsidian-memory through it
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: Task 210, Task 22, Task 241

**Description**: TOPIC CORRECTION (backlog streamline 2026-09-01): re-topiced core-agent-system -> extensions. This is deploy-engine (lua merge-path) and manifest-surface work for extension MCP registration, unrelated to the orchestrate-engine collapse; the consolidation audit confirmed no overlap with the routing ladder it carries forward. Original description follows.Build the deploy-engine mechanism that lets an extension declare an MCP server and have it actually registered, by generating a project-scoped .mcp.json.

WHY THIS IS NEEDED: extensions currently express server declarations as `mcpServers` keys inside settings-fragment.json, which register nothing -- settings files are not a registration surface. Project-scoped .mcp.json IS a real registration surface, and it IS reachable by dispatched subagents (verified by direct experiment; the earlier belief to the contrary rested on a session-start snapshot confound). So the fix is to route declarations to a surface that works, not to abandon the idea of extensions declaring servers.

WORK: add a new manifest merge target -- e.g. `merge_targets.mcp` with a source file per extension -- that the deploy engine collects across all LOADED extensions and writes to the repository-root .mcp.json. Mirror the existing settings merge path (process_merge_targets / merge_settings in merge.lua) rather than inventing a second idiom: the existing path is an additive, idempotent deep-merge that does not clobber pre-existing content, and it deliberately targets a file that is NOT install-once, which is exactly the property needed here. Extend manifest_spec.lua so the new key validates.

REQUIREMENTS THE MECHANISM MUST SATISFY: (a) each generated server entry carries an explicit "type" field -- as of Claude Code v2.1.202 a remote server lacking an explicit type fails fast rather than failing silently, and all current declarations omit it; (b) unloading an extension must REMOVE its servers from .mcp.json, because an additive deep-merge alone never retracts, and a stale grant surviving an unload is an already-observed defect class in this system; (c) the operation must be idempotent -- deploying twice yields a byte-identical .mcp.json; (d) hand-written entries a user added to .mcp.json themselves must survive regeneration, or the file must clearly declare itself generated. Decide (d) explicitly and record the choice.

IMPORTANT CONTEXT: a project-scoped .mcp.json server requires workspace-trust approval before `claude mcp list` will read it (v2.1.196+), and a server added to .mcp.json is invisible to any ALREADY-RUNNING session. Both facts must be documented for users, or the mechanism will be reported as broken when it is working correctly. Verify against a fresh session or `claude -p`, never against the current one.

VERIFICATION: build a scratchpad fixture project, load an extension declaring a trivial stdio server, and confirm .mcp.json is generated correctly; confirm a second deploy is a no-op; confirm unloading removes the entry; confirm `claude mcp get <name>` in the fixture reports Scope: Project config. Do NOT deploy against this repository as part of verification. SOURCE-STORE RULE (binding): all edits target /home/benjamin/.config/nvim/agent-system/extensions/**. Never hand-edit any deployed .claude/** tree -- it is gitignored, disposable, and regenerated from the source store. DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

=== ABSORBED 2026-09-22 from former task 30 (register_obsidian_memory_mcp_server); that task is abandoned into this one. Its text follows verbatim; where it names "the dependency task" or "the sibling task", read this task's other sections. ===

TOPIC CORRECTION (backlog streamline 2026-09-01): re-topiced core-agent-system -> extensions, alongside its prerequisite (the .mcp.json generation mechanism). Unrelated to the orchestrate-engine collapse. Original description follows.Register the obsidian-memory MCP server through the new manifest-driven .mcp.json mechanism, and grant its tools at the matching scope.

CURRENT STATE: memory/settings-fragment.json carries a dead `mcpServers` block declaring obsidian-memory (npx -y @anthropic-ai/obsidian-claude-code-mcp@latest, with env OBSIDIAN_WS_PORT). It registers nothing, because settings files are not a registration surface. The memory extension IS loaded in this repository, so unlike the five retired servers this one is wanted and should be made to work.

WORK: move the declaration to the new merge target so it lands in .mcp.json, with an explicit "type": "stdio". Then determine the server's ACTUAL tool names and add matching permission grants to the fragment, applying the grant-at-registration-scope rule. Do NOT guess the tool names and do NOT copy them from any existing documentation: enumerate them empirically by starting the server and issuing a tools/list request. This system has already shipped documentation instructing agents to call MCP tools that never existed, and a naming mismatch between a declared server name and its granted mcp__<name>__* prefix has already been found in another extension -- verify both the server name and every tool name against the running server.

RUNTIME PREREQUISITE, DO NOT PAPER OVER: this server needs OBSIDIAN_WS_PORT set and a running Obsidian instance with the companion plugin. If that prerequisite cannot be satisfied in this environment, wire the declaration correctly, document the prerequisite plainly in the memory extension README, and report the tool-name enumeration as NOT VERIFIED rather than inventing plausible names. A truthful 'could not verify' is the correct outcome here; a fabricated tool list is not.

VERIFICATION: .mcp.json contains the entry after a fixture deploy; `jq empty` on both edited files; doc-lint passes for the memory extension; every granted mcp__ tool name either matches a name observed from the running server or is explicitly marked unverified with the reason. SOURCE-STORE RULE (binding): all edits target /home/benjamin/.config/nvim/agent-system/extensions/**. Never hand-edit any deployed .claude/** tree -- it is gitignored, disposable, and regenerated from the source store. DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 22. Freeze .opencode: silence fragment validation spam and record the frozen-mirror policy
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: neovim
- **Dependencies**: None

**Description**: === STATUS REPAIRED 2026-09-22 (eighth-pass phase 0): researching -> not_started. No specs/022_* directory, no artifacts and no dispatch record exist in the live tree or the archive; the status was left by a dispatch that never wrote anything (last touched 2026-09-01). It deferred tasks 29 and 45 in every dry run via merge.lua. Nothing else changed. ===

=== REVISED 2026-09-01 (backlog streamline: .opencode declared FROZEN) ===
POLICY SETTLED BY USER DECISION: .opencode/ is FROZEN -- not maintained, not generated, not deleted. No sync mechanism will be built (the sibling sync-mechanism task is abandoned with a pointer here); the tree is preserved intact for possible future refactoring, exactly as this task's binding constraint already required. This settles the reframed design question below ("SHOULD opencode-agents.json fragments reference a per-project deploy tree at all?"): under a frozen mirror, no path corrections are owed and defect class (1) breakage is expected and tolerated -- the fix is to stop the noise and record the policy, not to repair paths that will drift again.

REVISED SCOPE, absorbing the narrowed remainder of the abandoned sync-mechanism task:
1. SILENCE THE SPAM (original core): gate or suppress the ~60-notification validation spam on <leader>al reload (emitter: M.generate_opencode_json / validate_opencode_fragment in lua/neotex/plugins/ai/shared/extensions/merge.lua). Under the frozen policy, missing {file:} deploy targets are an EXPECTED state; the validator must not shout about them on every reload. Prefer gating generation/validation behind the frozen policy (skip, or a single-line summary) over deleting the mechanism -- the binding constraint that no opencode fragment, validator function, or .opencode/ file is deleted still holds.
2. FIX THE ONE FAKE-TOOL LINE (from the absorbed task): .opencode/extensions/web/agents/web-implementation-agent.md still teaches browser_verify_text_visible as a real tool; the source store explicitly retracts it. A frozen mirror may drift, but it must not actively teach a nonexistent tool. One-line fix, editing .opencode/** directly (it has no source-store counterpart; the source-store/deploy-boundary rule does not apply to this tree).
3. RECORD THE POLICY where the next person will look (e.g. a note in .opencode/ and/or the extensions docs): the tree is frozen, unmaintained, drift-expected, and preserved for future refactoring.
ACCEPTANCE: a <leader>al reload from a project carrying an opencode.json.managed marker produces no validation-failure spam; the fake tool name no longer appears as usable guidance in .opencode/; the frozen policy is written down; nothing under .opencode/ is deleted.
=== ORIGINAL DESCRIPTION FOLLOWS ===
=== REVISED 2026-08-24 (refactor survey) ===
SUBSTANTIALLY OVERTAKEN, and the remaining half got worse. Re-verified today:
- Defect class (3) is FIXED. merge.lua:1002-1041 now degrades per-agent-key, reports every missing key rather than only the first, and no longer discards a whole fragment. Close it out; do not re-fix.
- Defect class (2) MOVED rather than got fixed. The archived path-fix work changed the lean fragment to reference .claude/agents/lean-research-agent.md instead of .claude/extensions/lean/agents/... -- but that path does not exist either.
- Defect class (1) is WORSE: 30 of 34 {file:} refs across all fragments now point at nonexistent files (was 16 of 18). Only nvim and nix resolve, because those are the extensions loaded in this repo -- which is itself the clue.
REFRAME around the one live question rather than patching paths again: SHOULD opencode-agents.json fragments reference a per-project deploy tree at all? Every {file:} ref is per-repo-deploy-dependent by construction, so any path fix is correct only for the extension set of whichever repo it was fixed in. That is why class (1) keeps regrowing. Answer the design question first; the path corrections fall out of it.
=== ORIGINAL DESCRIPTION FOLLOWS ===
Silence and correct opencode-agents.json fragment validation spam on extension reload.

SYMPTOM (observed live): reloading .claude/ via <leader>al from a project with an
opencode.json.managed marker emits ~60 WARN notifications of the form "Extension 'X'
opencode-agents.json validation failed: Agent 'Y' references missing file: Z. Skipping
fragment." before "Resynced 12 extension(s)".

EMITTER: M.generate_opencode_json in lua/neotex/plugins/ai/shared/extensions/merge.lua
(vim.notify at ~line 994), gated on an opencode.json.managed marker check (~line 931), with
per-fragment validation by M.validate_opencode_fragment (~line 887), which resolves each agent
prompt's {file:PATH} against project_dir.

THREE DISTINCT DEFECT CLASSES (measured against a live project, not assumed):

(1) MISSING DEPLOY TARGETS -- 16 of 18 {file:} refs across python (2), present (5), nix (2),
and filetypes (7) point at .opencode/agent/subagents/*-agent.md files that were never
deployed. The .opencode/agent/subagents/ directory DOES exist and holds 15 agent files
(core, lean, latex, typst, math, logic, physics, formal, meta-builder, planner,
code-reviewer), but none for those four extensions. So this is a partial-deploy gap, not a
wholly absent tree.

(2) LEAN WRONG-PATH BUG (independent of any opencode policy decision) --
agent-system/extensions/lean/opencode-agents.json is the ONLY fragment using a .claude/ path
shape. It references .claude/extensions/lean/agents/lean-research-agent.md and
.claude/extensions/lean/agents/lean-implementation-agent.md, neither of which exists anywhere,
while the CORRECT files .opencode/agent/subagents/lean-research-agent.md and
.opencode/agent/subagents/lean-implementation-agent.md ALREADY EXIST on disk. This is a plain
mis-pathed reference, fixable on its own merits regardless of what is decided about opencode.

(3) NOTIFICATION SPAM AND SIMULTANEOUS UNDER-REPORTING -- the same 5 messages repeat ~12 times
because generation runs once per resynced extension rather than once per reload. Separately,
validate_opencode_fragment iterates with pairs() and returns on the FIRST missing ref, so only
one broken ref per extension is ever named, and WHICH one varies nondeterministically between
runs (python alternates python-research/python-implementation; filetypes alternates
scrape/filetypes-spreadsheet). The true breakage (18 refs) is therefore both over-announced in
aggregate and under-reported per message.

BINDING CONSTRAINT (from the user): .opencode/ is NOT currently used and may be excluded from
scope, BUT the fix MUST NOT damage or delete .opencode/ infrastructure. The opencode-agents.json
fragments, the validator function, the managed-marker gating, and the existing .opencode/ tree
must all survive intact so .opencode/ can be refactored in the future. Prefer suppressing or
gating the noise over removing the mechanism.

ACCEPTANCE: a <leader>al reload from a project carrying an opencode.json.managed marker
produces no validation-failure spam; the lean fragment's two refs resolve to real files;
whatever gating approach is chosen is documented; and no opencode fragment, no validator
function, and no .opencode/ file is deleted.

SOURCE-STORE RULE (binding): edit lua/** for the Lua emitter and agent-system/extensions/** for
the JSON fragments; never edit .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

=== ABSORBED 2026-09-28 (path review, fifth pass) from former task 45 (global_update_extension_repo_registry); that task is abandoned into this one. Its text follows verbatim; where it names "the dependency task" or "the sibling task", read this task's other sections. ===

TOPIC CORRECTION + BACKFILL NOTE (task-116 audit). This task carried topic core-agent-system, but its real scope (the <leader>al extension picker's 'Global Update' action) is nvim-config Lua UI code at lua/neotex/plugins/ai/claude/commands/picker/** and lua/neotex/plugins/ai/shared/extensions/**, NOT agent-system/extensions/** -- it is unrelated to the orchestrate-engine collapse. Re-topiced to neovim; file_scope backfilled from description evidence (was previously empty). Original description follows.\n\nImplement <leader>al repo registration and 'Global Update' action: when <leader>al loads extensions into other repos, register those repos and their loaded extensions in this nvim repo; add a 'Global Update' entry (similar to 'Reload All') that reloads all extensions already loaded in each registered repo, reporting any failures in a message and otherwise success as a count of the total

=== ABSORBED 2026-09-22 from former task 202 (Make the picker's [Reload All] and [Regenerate] entries honest and self-documenting, and rule on their redundancy); that task is abandoned into this one. Its text follows verbatim; where it names "the dependency task" or "the sibling task", read this task's other sections. ===

Fix the <leader>al picker's [Reload All] / [Regenerate] entries: a factually wrong one-line description, an absent Command Details preview for both, and an undecided redundancy question.

EDIT TARGET: lua/neotex/plugins/ai/claude/commands/picker/** and lua/neotex/plugins/ai/shared/extensions/**. This is nvim-config Lua UI code, NOT agent-system/extensions/**; nothing here touches the deployed .claude/ tree.

=== VERIFIED CURRENT BEHAVIOUR (read from source, not inferred) ===

The two entries are DIFFERENT operations, and both act on the CURRENT REPO ONLY (cwd):

[Reload All] (picker/init.lua:159-286) opens a vim.ui.select submenu with four choices --
"Reload All", "Unload All", "Step Through", "Cancel". The "Reload All" choice calls
exts.resync_all(), whose own doc comment at shared/extensions/init.lua:895-898 states: "Never
unloads: each extension is re-loaded in place via manager.load(..., {force = true}), so there is
no destructive intermediate 'everything unloaded' state." It force-resyncs every CURRENTLY LOADED
extension in Kahn's-algorithm dependency order. Non-destructive. No confirmation prompt.
("Step Through" is currently a no-op that just reopens the picker.)

[Regenerate] (picker/init.lua:110-156) calls exts.wipe({project_dir = vim.fn.getcwd()}), which
runs vim.fn.delete(target_dir, "rf") at shared/extensions/init.lua:1253 -- snapshot ->
rm -rf base_dir -> regenerate from the surviving project-root extension manifest -> restore
settings.local.json and .syncprotect-listed paths -> clear staging. Destructive. Confirmation
required.

=== DEFECT 1: THE [Reload All] ONE-LINER DESCRIBES [Regenerate], NOT ITSELF ===

display/entries.lua:980-982 renders [Reload All] with the trailing text:

    "Wipe and reload all loaded extensions"

It does not wipe. resync_all never unloads and never deletes. The word "Wipe" belongs to
[Regenerate], whose own one-liner at entries.lua:995-997 ("Wipe and rebuild from the extension
manifest") is accurate. So the picker currently presents two adjacent entries whose visible
descriptions both begin "Wipe and ...", one of which is false -- which is precisely the confusion
that motivated this task: an operator reaching for a rebuild picked [Reload All] on the strength
of that line.

Note the contradiction is already internal to the codebase: display/previewer.lua:129-130
describes the same entry correctly as "Force-resyncs every currently loaded extension in
dependency order (non-destructive)." Two descriptions of one entry disagree.

=== DEFECT 2: NEITHER ENTRY HAS A Command Details PREVIEW ===

Both entries are created with entry_type = "special" plus a boolean flag (is_reload_all,
is_regenerate) at entries.lua:974-999. The previewer's define_preview dispatch chain
(previewer.lua:628-661) branches on is_heading, is_help, and then eleven entry_type values --
skill, hook_event, lib, script, test, template, doc, command, extension, agent, root_file. There
is NO branch for is_reload_all, is_regenerate, or entry_type == "special". Both therefore fall to
the terminal else at previewer.lua:658-659, which writes the single line "Unknown entry type"
into the "Command Details" pane.

So the pane is not blank -- it renders a developer-facing error string for two entries that are
working as designed. The real documentation for both operations exists, but it is buried inside
preview_help (previewer.lua:129-135), reachable only by selecting the separate [Keyboard
Shortcuts] entry.

DECIDE, do not assume: whether to add a dedicated preview_special branch keyed on the two boolean
flags, or to give special entries a shared preview keyed on entry_type == "special" that reads a
per-entry description field. Either way, the terminal else branch should stop being reachable for
entries the picker itself ships -- consider whether "Unknown entry type" is the right fallback at
all, or whether it should name the offending entry so the next gap is diagnosable.

=== DEFECT 3: THE REDUNDANCY QUESTION, UNDECIDED ===

There is genuine partial overlap: [Regenerate]'s wipe-and-rebuild reloads the same extension set
[Reload All] resyncs, so it subsumes the OUTCOME while differing in method, risk, and guarantees.
Whether that justifies two entries is a real design call, not an obvious yes or no. Weigh at
least: (a) keep both, with corrected descriptions that make the destructive/non-destructive
distinction the FIRST thing each line says; (b) collapse [Regenerate] into the [Reload All]
submenu as a fourth, confirmation-gated choice alongside Unload All, giving one entry point for
all bulk extension operations; (c) keep both but rename them so neither reads as a synonym of the
other. Record the ruling and its reasoning.

While deciding (b), note the [Reload All] submenu already contains a dead choice: "Step Through"
(init.lua:180-185) does nothing but reopen the picker. Decide its disposition too -- implement or
remove; do not leave a menu item that silently no-ops.

=== A CORRECTION TO THE OPERATOR'S MENTAL MODEL, WORTH RECORDING IN THE PREVIEW TEXT ===

[Regenerate] is sometimes remembered as "run Reload All across every repo that has loaded the
agent system, preserving each repo's own loaded extension set". It does NOT do that, and never
has -- it is single-repo, scoped to vim.fn.getcwd(), exactly like [Reload All].

That cross-repo capability is a DIFFERENT, already-filed, not-yet-started piece of work: the
task titled "Implement <leader>al repo registration and 'Global Update' action" describes
registering repos that <leader>al loads extensions into, and adding a 'Global Update' entry
"similar to 'Reload All'" that reloads all extensions already loaded in each registered repo.
Coordinate with it rather than implementing cross-repo behaviour here; this task's job is to make
the two EXISTING single-repo entries honest and self-documenting. Whichever of the two lands
second should make sure all three entries read as a coherent set.

=== ACCEPTANCE ===

- [Reload All]'s visible one-liner no longer claims it wipes, and states its non-destructive
  force-resync nature; [Regenerate]'s continues to state its destructive nature. The two lines are
  distinguishable at a glance.
- Selecting either entry renders real content in the "Command Details" pane -- what it does, what
  it touches, whether it is destructive, whether it prompts -- and "Unknown entry type" is no
  longer reachable for any entry the picker ships.
- The entries.lua one-liner and the previewer text for a given entry agree with each other and
  with the implementation; a check or comment records that they must be kept in sync.
- The redundancy ruling is recorded with reasoning, and "Step Through" is either implemented or
  removed.
- Verified by opening <leader>al and selecting each entry, not by reading the diff alone.
