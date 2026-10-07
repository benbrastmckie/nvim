# Research Report: Task #333

**Task**: 333 - The /books command with --review and --revise
**Started**: 2026-10-04T00:00:00Z
**Completed**: 2026-10-04T00:00:00Z
**Effort**: 4-8 hours (per task entry)
**Dependencies**: Task 332 (books-observe.sh post-task observer) — complete
**Sources/Inputs**: Codebase exploration only (`agent-system/extensions/memory/`,
`agent-system/extensions/books/`, `agent-system/extensions/core/`); no web search was needed —
the mirror target and the domain vocabulary are both already fully specified in this repository's
source store.
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The mirror target (`/distill`) is a three-layer split: `commands/distill.md` parses flags only;
  `skills/skill-distill/SKILL.md` is a single **direct-execution** skill holding a **Shared
  Sub-Mode Skeleton** (measured, re-confirmed: lines 278-321 of that file, immediately followed by
  `### Purge Sub-Mode` at line 322) plus thin stub pointers (`READ {pattern-file} now and follow
  it exactly`) out to one pattern file per sub-mode; the pattern files hold all sub-mode-specific
  logic. `/books --review`/`--revise` should reproduce this exact three-layer split, not invent a
  new shape.
- `--review`'s closest existing analogue is `distill-review-submode.md`: strictly read-only, no
  `AskUserQuestion` mutation gate (an explicitly *stated* exemption, not a silent omission), a
  per-tier access table with a named degraded-behavior string for each tier, and a mandatory
  **funnel rule** — it names what to do next, never acts itself.
- `--revise`'s closest existing analogue is `distill-meta-submode.md`: `AskUserQuestion`
  `multiSelect` over candidates -> per-candidate create/note/skip -> a second, explicit
  confirmation gate before any task is created -> delegation of the actual task-creation
  primitive to an agent (there, `meta-builder-agent`; here, the planner-agent/general task-creation
  path) rather than reimplementing `/task` inline.
- `AskUserQuestion` is confirmed unreachable from a dispatched subagent by this codebase's own
  existing practice, not only by the dispatch file's assertion: `skill-fix-it`'s own documented
  flow states "No subagent delegation. Everything executes directly in skill-fix-it using
  `AskUserQuestion` for interactivity" (`agent-system/extensions/core/docs/examples/
  fix-it-flow-example.md:56`), and `skill-distill` itself is a direct-execution skill with no
  agent dispatch anywhere in its `--meta`/`--revise`/`--learn` interactive paths. The constraint is
  therefore not new to this task — it is the reason every existing analogous skill is already
  shaped this way.
- The books convention's "validation marker" is a concrete, already-built artifact: the
  `- **Validated by**:` line at the head of each numbered Decision in the consuming repository's
  `docs/book-convention.md`, in a three-form vocabulary (`none yet [-- reason]` /
  `partially, <instances>` / anything else named outright = **binding**), mechanically linted by
  that repository's own `books/scripts/lint-validated-by.sh`. A `--revise` proposal must quote
  this marker verbatim, and a proposal touching a `binding` decision is exactly the case the
  dispatch's escalation prohibition targets.
- No pre-existing "research-and-escalate task" primitive or task_type exists anywhere in this
  agent system today. This is new design surface this task must define, not an existing contract
  to mirror — the closest precedent is textual only (`known-gap-register.md`'s "binding -- work
  that cannot satisfy it stops and escalates", and the recorded fact that Decision 1 was already
  amended once "by owner ruling").
- The books extension's registration surface (`manifest.json`, `index-entries.json`,
  `EXTENSION.md`, `README.md`) already has a settled shape to extend, and the memory extension's
  own `manifest.json` shows the right template for a maintenance-only command family: `/distill`
  and `/learn` carry **no** `routing_agents` entries at all, because they are direct-execution
  commands outside the task research/plan/implement lifecycle — `/books --review`/`--revise`
  should follow that same template, not add new `routing_agents` rows to the `books` manifest.

## Context & Scope

Task 333 asks for a new `/books` command with `--review` (read-only convention performance review)
and `--revise` (interactive proposal of research-and-revision tasks) sub-modes, built on top of the
observation records `books-observe.sh` (task 332's deliverable, now complete and deployed) writes
per books-topic task. The dispatch is explicit that this phase must not invent a new architecture
but reproduce `/distill`'s proven sub-mode split verbatim, adapted to the books domain's own
vocabulary (the seven dimensions, paired burdens, the `Validated by` marker, the consuming
repository's escalation posture). This report's scope is confined to research: it grounds every
design choice the forthcoming plan will need in an already-read source (file path, line range, or
quoted text) rather than inventing new vocabulary. It does not write any deliverable file.

**Stale-deploy caveat** (dispatch's own `<deploy-freshness-context>`): the deployed `.claude/` tree
is stale for the `core` extension. This report reads exclusively from the source store
(`agent-system/extensions/`), which is the correct edit target per
`rules/source-store-deploy-boundary.md` and is unaffected by deploy staleness.

## Findings

### Codebase Patterns

**1. The `/distill` three-layer split (the shape to reproduce), file paths and line numbers:**

| Layer | File | Role |
|---|---|---|
| Command | `agent-system/extensions/memory/commands/distill.md` | Parses `--purge`/`--merge`/.../`--review`/`--revise`/`--meta`/etc. into `sub_mode`; delegates to `skill-distill` with `mode=distill, sub_mode={sub_mode}`. |
| Skill | `agent-system/extensions/memory/skills/skill-distill/SKILL.md` (836 lines) | Direct-execution skill (frontmatter `allowed-tools: Bash, Grep, Read, Write, Edit, AskUserQuestion`). Holds the Scoring Engine, the Shared Sub-Mode Skeleton (lines 278-321), two sub-modes specified inline (`gc`, `auto`), and one-line stub pointers for the rest. |
| Pattern files | `agent-system/extensions/memory/context/project/memory/patterns/distill-{purge,merge,compress,refine,revise,meta,review,learn,dream}-submode.md` | Each is "the COMPLETE and ONLY specification" for its sub-mode (verbatim opening sentence in both `distill-review-submode.md` and `distill-meta-submode.md`); the `SKILL.md` stub reads `READ {path} now and follow it exactly.` |

**2. The Shared Sub-Mode Skeleton, verbatim seven steps** (`skill-distill/SKILL.md:278-321`):
1. Edge Case Checks (preconditions; specific early-return message on failure).
2. Candidate Identification (sub-mode-specific; cite shared dependencies like the Scoring Engine
   by name rather than re-deriving them).
3. Dry-Run (`--dry-run` shows the candidate list and returns early; no file modified).
4. Interactive Selection (MANDATORY STOP) — `AskUserQuestion`, `multiSelect: true`. Stated as
   "non-negotiable in every sub-mode that mutates ... no mutation may proceed without an explicit,
   user-confirmed selection at this step."
5. Execution (sub-mode-specific; never usefully generalized).
6. Batch Index Regeneration (after the whole confirmed batch, never per-item).
7. Log Entry (append to the sub-mode's own log file; update a summary counter).

**Non-mutating sub-modes (`report`, `--review`) explicitly skip step 4** — this exemption is
stated in the skeleton's own text, not left as a silent gap, and is one of three sanctioned skeleton
deviations (alongside `report` and `auto`).

**3. `--review`'s full specification** (`distill-review-submode.md`, read in full):
- "Strictly read-only. `--review` never proposes and never writes." Distinguished explicitly from
  `report` (fixed structured output) and from `--revise`/`--meta` (which do propose writes).
- MANDATORY STOP Exemption stated explicitly (quoted above) rather than omitted silently.
- Candidate Identification is a **per-tier access table**: each of the four telemetry tiers gets a
  named access path and a named degraded-behavior string for when that tier is unavailable (e.g.
  `"No events captured yet in specs/events.jsonl for this query."`).
- `--dry-run` is an accepted no-op (nothing to suppress because nothing writes).
- Output shape: free-text answer, then an `Evidence:` block citing `[Tier N / source]` per claim,
  then a **Funnel rule**, stated explicitly: "`--review` performs none of the three actions above
  itself. It only names which follow-on sub-mode or command applies."
- Logging is optional and lightweight (`pre_metrics`/`post_metrics` identical, mirroring `report`'s
  convention for read-only operations) — not required for the sub-mode to function.

**4. `--meta`'s full specification** (`distill-meta-submode.md`, read in full) — the closest
analogue for `--revise`'s interaction shape:
- Edge Case Checks resolve a `target_root`, run validate-on-read, and early-return with a named
  message if zero signal exists.
- Candidate Identification states a closed discovery rule (recurring three-strikes deviation/
  blocker, or recurring reflection phrases) and explicitly refuses to invent new detection logic:
  "Extension targeting ... **Do not write new detection logic here**," delegating the affected-area
  guess to the downstream agent and relying on the human-correction step below for when that guess
  is wrong.
- Interactive Selection (MANDATORY STOP): `AskUserQuestion` `multiSelect` over candidates (one
  option per candidate, `description` carrying the evidence citations), **then a second,
  per-candidate choice** (Create as task / Note in report only / Skip), **then an explicit
  confirmation gate** before anything is created — "mirroring every other multi-task creator in
  this codebase... including the user's opportunity to select and modify the proposed tasks before
  anything is created."
- Execution is a **delegation contract**: a fixed JSON payload (`proposal_set`, `target_root`,
  `orchestrator_mode: false`) is handed to an agent via the Agent tool; `--meta` "MUST NOT edit any
  file itself" and "Do not reimplement the `/task` primitive inline." A proposal whose remedy is a
  prose edit (not a new task) is explicitly a **report-only finding**, never auto-applied.
- A dedicated `meta-log.json` schema records `proposals: {surfaced, created_as_task, noted_only,
  skipped, task_numbers_created}` per run.

**5. Direct-execution + `AskUserQuestion` precedent, independent confirmation of the dispatch's
constraint**: `agent-system/extensions/core/docs/examples/fix-it-flow-example.md:56` — "**Key
difference from old pattern**: No subagent delegation. Everything executes directly in
skill-fix-it using `AskUserQuestion` for interactivity." Combined with `skill-distill`'s own
frontmatter (`allowed-tools: ... AskUserQuestion`, no `Agent` tool listed for the interactive
sub-modes' gate steps), this is an established, repeated pattern in this codebase: every
multi-candidate interactive gate lives in a direct-execution skill body, never inside a dispatched
subagent. `/books --review`/`--revise` must follow the identical shape.

**6. Telemetry Guardrails** (`agent-system/extensions/memory/context/project/memory/
telemetry-guardrails.md`, read in full) — binding design constraints cited by name from each
telemetry-consuming sub-mode rather than restated: the four-tier source model (OTel / `events.jsonl`
/ `history.jsonl` / transcripts+sidecars, each with a named blind spot); the
evaluator-outside-the-loop rule ("Propose-then-human-review. NEVER auto-apply," motivated by a
documented 220+-loop fabrication incident); the six failure-mode design checklist; the `~70%` v1
miss-rate expectation (stated explicitly in the sub-mode's own description, not hidden); the
`sess_*`-to-OTel dead end (closed, never re-propose); the per-repo cross-repo signal limitation;
the mandatory chained `cd "$GLOBAL_ROOT" && bash .claude/scripts/{name}.sh ...` invocation form for
the four cross-repo scripts. The books domain's own telemetry surface (`metrics.jsonl`,
`issues.jsonl`, the per-task observation record, the digest log) is narrower than memory's
five-tier stack, but the **evaluator-outside-the-loop** and **CAPTURE ONLY** principles apply
identically and must be stated, not silently assumed, in both new pattern files.

### Books Domain Facts

**7. The observation record schema** (`agent-system/extensions/books/context/project/books/
standards/observation-record.md`, 249 lines, read in full) — this is `--review`'s and `--revise`'s
primary data source:
- **Location**: canonical record is one file per task, `specs/{NNN}_{SLUG}/book.observation.json`;
  a compact append-only digest line is additionally written to
  `specs/books-evidence/observations.jsonl` on every write, carrying `{task, recorded_at,
  record_path, backfilled}` plus a short dimension-signal rollup. The digest is "explicitly a
  pointer/derived index ... never a second source of truth" — `--review`/`--revise` should read the
  digest log to enumerate tasks, then dereference `record_path` for full detail.
- **The Seven Dimensions**, spelled verbatim, never respelled or abbreviated: `maintainability` (a),
  `cross_pollination` (b), `guardrails_qa` (c), `token_cost_efficiency` (d), `readability` (e),
  `intuitive_exposure` (f), `compiling_composing` (g, with two first-class sub-fields
  `import_weight`/`compilation_weight`).
- **Polarity**: exactly `positive` or `negative`, no default; untagged signals are retained and
  counted as `untagged`, never defaulted onto a dimension.
- **Paired Burdens, a schema requirement**: `burdens_created[]` and `burdens_lifted[]` are *both
  always present*, defaulting to `[]`, "never one present without the other" — enforced by the
  observer and asserted by its test suite. Each entry: `{description, dimension,
  convention_decision}`, where `convention_decision` names the bearing Decision **by its durable
  heading text** (e.g. `"Decision 13: Exposure policy"`), never an invented identifier.
- **Omit, never zero (D5)**: an undiverable field is dropped, never a fabricated `0`; `"absent"` is
  used only for the two fields the standard names explicitly (`vacuous_passes`, `snapshot_delta`).
- **Vacuous passes are first-class**, never inferred by negating an ordinary pass.
- **Generic join half** (`generic.{issues_present, metrics_present, issue_counts, dispatch_count,
  phases, outcomes, wall_clock_seconds_total}`) is exactly the source `--review`'s "cost per task
  and per phase kind" requirement should read from — these fields are themselves sourced from
  `metrics.jsonl`, whose own format doc states **"CAPTURE ONLY — No Reporting Here"**
  (`agent-system/extensions/core/context/formats/dispatch-metrics.md:44`) and documents a 30-day
  transcript retention window. `--review` must state this capture-time caveat per the dispatch's
  own instruction, rather than reading as if it queries live telemetry.

**8. The `Validated by` marker vocabulary** (`agent-system/extensions/books/context/project/books/
domain/known-gap-register.md`, read in full) — this is the "validation marker" the dispatch
requires every `--revise` proposal to name:
- Authority: the `- **Validated by**:` marker at the head of each numbered Decision in the
  consuming repository's `docs/book-convention.md`, mechanically linted by that repository's own
  `books/scripts/lint-validated-by.sh` (802 lines; CHECK 1 marker well-formedness and CHECK 2
  instance liveness are **blocking**; CHECK 3/4 are advisory).
- **Three-form vocabulary**, adopted not invented by this register:
  | Form | Meaning |
  |---|---|
  | `none yet [-- reason]` | no instance at all |
  | `partially, <instances>` | some clauses exercised, some not, some **contradicted** |
  | anything else (an instance named outright) | **binding** — "work that cannot satisfy it stops and escalates" |
- **Measured census** (2026-10-03, this register's own snapshot): eighteen decisions, eighteen
  markers — **two binding** (Decision 5 "Shared support modules and the `ladder` book", Decision 14
  "Pilot go/no-go criteria"), **fifteen `partially`**, **one `none yet`** (Decision 18,
  "Composition and consumption ergonomics" — zero of seven mechanisms built).
- This register is itself explicitly a "dated projection, not an authority" — the live authority is
  `docs/book-convention.md`'s markers directly, with this register stale whenever it disagrees.
  `--revise` should read the live markers, citing this register only as a navigation aid.

**9. No pre-existing "research-and-escalate" primitive.** A targeted search for `escalat` across
every extension found no task_type, template, or script implementing a "research-and-escalate"
task shape. The only load-bearing precedent is textual: the `known-gap-register.md` row quoted
above ("binding ... stops and escalates"), and the recorded historical fact that Decision 1 "was
already amended once 2026-10-02 by owner ruling" (per `known-gap-register.md`'s Part A table and
`certificate-ledger-and-records.md`'s cross-references). The books extension's own `rules/
cslib.md` analogue (a sibling extension, not books itself) does define an unrelated "Escalation"
line for a different context (literature-fidelity gaps in proof encoding), confirming "escalate"
already means, elsewhere in this codebase, "stop autonomous work and hand a human the decision" —
not a formal task_type, just a documented behavior. This task's `--revise` sub-mode must therefore
*define* the research-and-escalate task shape (a task filed to research a binding-clause finding
and surface it for the repository owner's ruling, never to implement a convention change
unilaterally), not look one up.

**10. Registration surface, both extensions compared:**
- The **books** extension's `manifest.json` already carries a settled shape worth extending
  in-place: `provides.{agents, skills, commands, rules, context, scripts}`, an `observers` block
  (`books-observe`), `routing_agents`/`routing_agents_hard` keyed by `books`/`books:certify`, and
  `keyword_overrides`. Its two existing commands (`/book`, `/certify`) both carry `routing_agents`
  entries because they are tied to the task research/plan/implement lifecycle (`books-research-
  agent`, `planner-agent`, `books-implementation-agent`).
- The **memory** extension's `manifest.json` is the correct template for `/books --review`/
  `--revise` specifically: its `provides.{commands, skills}` list `distill.md`/`skill-distill` and
  `learn.md`/`skill-learn`, and its `routing_agents` block carries **only** a `memory` task_type
  entry (for actual `task_type: memory` tasks) — `/distill` and `/learn` themselves have **no**
  `routing_agents` rows at all, because they are direct-execution maintenance commands outside the
  task lifecycle, never dispatched via research/plan/implement phase routing.
- `agent-system/extensions/core/scripts/check-extension-docs.sh` (read: header comment and rule
  index) enforces, among other things: Rule A (every skill directory on disk must appear in
  `provides.skills`), Rule K (every deployed command must trace to a `provides.commands` entry),
  Rule U (`EXTENSION.md` capped at 60 lines per `extension-slim-standard.md`), Rule T
  (`index-entries.json` entries must conform to `index.schema.json`'s field set), Rule R
  (`index-entries.json` `line_count` must match `wc -l` of the real file). All five are directly
  relevant to this task's "registration files are consistent with `check-extension-docs.sh`"
  acceptance criterion.

**11. Multi-task creation standard** (`agent-system/extensions/core/docs/reference/standards/
multi-task-creation-standard.md`) supplies the exact mechanics the dispatch calls "backlog
reconciliation" without naming a component:
- **Component 0 (Task-Count Reasoning)**: default to ONE task per finding unless a closed reason
  (disjoint file scope, different task_type/owning domain, real dependency ordering, or size
  exceeding one dispatch) justifies splitting — directly applicable to consolidating multiple
  `--revise` candidates that bear on the same convention clause.
- **Component 2 (Interactive Selection)**: the exact `AskUserQuestion` `multiSelect` JSON shape
  `--revise` should reuse verbatim (same shape `--meta` already uses).
- **Component 4a (File Footprint Overlap Detection)**: automatically adds a dependency edge between
  two proposed tasks (or a proposed and an open task) whose `file_scope` entries overlap — this is
  the mechanical half of "compare each proposed task against open tasks and create, widen, add a
  dependency edge, or narrow a file scope."
- **Component 7 (User Confirmation)**: the final gate before any task is actually created,
  matching `--meta`'s own second confirmation step.

## Decisions

1. **Single skill, two sub-modes, mirroring `skill-distill`'s one-skill-many-submodes shape.** The
   dispatch's deliverable list names exactly one skill file, `skills/skill-books-review/SKILL.md`,
   to hold the shared skeleton plus stub pointers for *both* `--review` and `--revise` (just as
   `skill-distill/SKILL.md` is the single skill behind twelve sub-modes). The skill directory name
   naming only "review" while also dispatching "revise" is the same shape `skill-distill` already
   uses (one skill name, many sub-mode flags) and is not a naming defect to correct.
2. **All interactive gates stay inline in the direct-execution skill**, never inside a dispatched
   subagent, per Finding 5. If `--revise`'s mandatory decision-record research step benefits from
   delegation, only a **non-interactive** research pass (reading `docs/book-convention.md`,
   computing candidate evidence) may be delegated to an agent (e.g. `books-research-agent`); every
   `AskUserQuestion` multiSelect, per-candidate choice, and confirmation gate must execute back in
   the skill body, in the lead session.
3. **Registration follows memory's template, not books' own `/book`/`/certify` template.** Add
   `"books.md"` to `provides.commands` and `"skill-books-review"` to `provides.skills` in the books
   `manifest.json`; do **not** add a `routing_agents` entry for `books:review`/`books:revise` —
   these are maintenance commands outside the task lifecycle, exactly like `/distill`/`/learn` in
   the memory manifest.
4. **The "validation marker" `--revise` must cite is the `- **Validated by**:` line at the head of
   each Decision in the consuming repository's `docs/book-convention.md`**, in its three-form
   vocabulary (`none yet [-- reason]` / `partially, <instances>` / binding). Every `--revise`
   proposal names the Decision by its durable heading text (never an invented identifier, mirroring
   `convention_decision`'s own discipline in the observation record) and quotes that Decision's
   current marker verbatim.
5. **A proposal bearing on a `binding` marker is filed as a research-and-escalate task** — a task
   whose description states explicitly that its plan/implement phases perform research only and
   surface findings to the repository owner for a ruling, never implement a convention change
   directly. This is new design surface (Finding 9); it is not an existing task_type and must be
   expressed as a description convention on an ordinarily-typed task (likely `task_type: meta`,
   matching task 333's own type), not a new field or enum value, since no mechanical enforcement
   for a distinct type exists today.
6. **Watermarking follows the digest-log-cursor shape, not the memory extension's
   `.memory/revise-log.json` shape** (books has no `.memory`-equivalent persistent store). Record a
   `specs/books-evidence/revise-log.json` (sibling to the existing `specs/books-evidence/
   runs.jsonl`/`observations.jsonl`) whose latest entry carries `{considered_through:
   {recorded_at, record_path}}`; a `--revise` run reads only digest-log lines with `recorded_at`
   strictly after the stored cursor, mirroring memory's `--since {last_revise}` mechanism
   structurally without depending on `.memory/`.
7. **`--review`'s cost figures come from the observation record's `generic` join group**
   (`dispatch_count`, `phases`, `outcomes`, `wall_clock_seconds_total`), aggregated across every
   books-topic task's record reached via the digest log — never from a live OTel/events query. The
   report must state, per the dispatch's explicit instruction, that these figures reflect what was
   captured at each task's postflight, not live telemetry (mirroring `dispatch-metrics.md`'s own
   "CAPTURE ONLY" framing).

## Recommendations

- **`commands/books.md`**: parse `--review` (default when no flag given is ambiguous — recommend
  requiring an explicit flag rather than defaulting to `--review`, since unlike `/distill`'s bare
  invocation `/books` with no flag has no natural "health report" analogue yet defined; flag this
  choice for the plan phase to confirm) and `--revise`; delegate to a single `skill-books-review`
  with `mode=books, sub_mode={review|revise}`, mirroring `distill.md`'s argument-parsing shape
  exactly (including its Sub-Mode Dispatch table and its `--dry-run`/`--verbose` convention for
  `--revise`, which plausibly wants a `--dry-run` showing candidates without proposing tasks).
- **`skills/skill-books-review/SKILL.md`**: frontmatter `allowed-tools: Bash, Grep, Read, Write,
  Edit, AskUserQuestion` (no `Agent` tool — keep every interactive step inline per Decision 2,
  unless the plan phase deliberately adds a bounded non-interactive research delegation). Body:
  a short "Mode: books" section describing the digest-log read path, then two one-line stub
  pointers (`READ context/project/books/patterns/books-{review,revise}-submode.md now and follow it
  exactly.`) exactly as `skill-distill/SKILL.md`'s `### Sub-Mode: review`/`### Sub-Mode: meta`
  sections already do.
- **`context/project/books/patterns/books-review-submode.md`**: structure directly off
  `distill-review-submode.md`'s five sections (Edge Case Checks / Candidate Identification / Dry-
  Run / Execution-Output-Shape / Log Entry), substituting the seven books dimensions for the four
  memory telemetry tiers as the per-dimension access table, each row carrying a named degraded-
  behavior string for "no data for this dimension yet" (the dispatch's explicit "WHAT IS
  UNMEASURED" requirement). End with the same Funnel rule shape, naming `--revise` by name as the
  only next step (never proposing a task directly).
- **`context/project/books/patterns/books-revise-submode.md`**: structure off
  `distill-meta-submode.md`'s six sections. Candidate Identification reads the digest log since the
  watermark (Decision 6), groups by `convention_decision`/dimension, and — as a **mandatory**
  preliminary research step per the dispatch — reads `docs/book-convention.md`'s current marker for
  every Decision a candidate touches before any candidate is presented. The `AskUserQuestion`
  multiSelect candidate `description` field should carry the Decision's durable heading text and
  its current marker verbatim (Decision 4), exactly as `--meta`'s candidate description carries
  evidence event IDs. Insert the binding-clause branch (Decision 5) as an explicit fork inside
  Execution, before Backlog Reconciliation: a `binding`-marked candidate is filed as a
  research-and-escalate task using the description convention above; every other candidate follows
  the ordinary create/note/skip path. Backlog reconciliation (Finding 11) runs after the
  create/note/skip choice and before the final confirmation gate, applying Components 0/4a from
  `multi-task-creation-standard.md` against the open backlog (`specs/state.json`
  `active_projects`).
- **Registration files**: `manifest.json` per Decision 3; `index-entries.json` gains two new
  entries (one per new pattern file) following the existing per-entry schema books already uses
  (see the sixteen existing entries read in Finding 10 for the exact field set — `path`,
  `line_count`, `load_when`, `domain`, `subdomain`, `topics`, `summary`, `keywords`); `EXTENSION.md`
  gains a `### Commands` row for `/books` and a `Skill-Agent Mapping` row for `skill-books-review`
  (watch the 60-line cap, Finding 10's Rule U — the existing file has headroom but a new table row
  plus a sub-mode note should be checked against `wc -l` before finalizing); `README.md`'s
  navigation table (if `project/books/README.md` carries one — confirm in the plan phase) gains
  rows for the two new pattern files.
- **The books-side watermark store** (`specs/books-evidence/revise-log.json`, Decision 6) should be
  added as a new deliverable in the plan, since it is implied by the dispatch's WATERMARK
  requirement but not explicitly listed among the five named deliverable files.

## Risks & Mitigations

- **Risk**: treating `--review`'s default-no-flag case ambiguously (dispatch is silent on whether
  bare `/books` should behave like `/distill`'s bare report mode). **Mitigation**: the plan phase
  should make `--review` or `--revise` mandatory and reject a bare `/books` with a usage message,
  since no "books health report" concept parallel to `/distill`'s bare report mode is specified
  anywhere in this task's deliverables.
- **Risk**: a future reader conflates the digest log `observations.jsonl` with the canonical
  per-task record and double-counts or stales a figure. **Mitigation**: both new pattern files
  should repeat the observation-record standard's own framing verbatim ("explicitly a pointer/
  derived index ... never a second source of truth") rather than silently assuming it.
- **Risk**: `--revise` is built to auto-escalate by inventing a new task_type or state.json field,
  which no script currently reads or enforces, silently becoming dead weight. **Mitigation**:
  Decision 5 pins the escalation mechanism to a description-text convention on an existing
  `task_type`, not a new enum value or schema field — nothing new needs to be taught to
  `validate-state.sh` or any other script for this task to ship correctly.
- **Risk**: scope creep into actually building the repo-side snapshot probe or the RUN log
  (`specs/books-evidence/runs.jsonl`) that `--review`'s verification-tier/certifier-outcome figures
  would ideally read. **Mitigation**: `observation-record.md`'s own Probe Ownership Boundary
  already establishes these are "absent" by design on a repository that hasn't built them; `--
  review` should report `verification_tiers`/`certifier_outcomes` as omitted/absent exactly as the
  schema specifies, never synthesizing a probe as part of this task.

## Context Extension Recommendations

- **Topic**: a generic, core-owned "research-and-escalate task" pattern.
  **Gap**: this task's `--revise` design (Decision 5) introduces the concept of a task that
  researches a finding and surfaces it for an owner's ruling rather than implementing a change,
  but no `context/patterns/*.md` document defines this shape generically today — it exists only as
  an ad hoc description convention this report proposes.
  **Recommendation**: after this task ships, consider extracting a
  `context/patterns/research-and-escalate-task.md` (core-owned, domain-agnostic) if a second
  domain besides books independently needs the same shape — premature to create it from a single
  instance, but worth flagging now so the pattern is named consistently if it recurs.
- **Topic**: books-domain telemetry guardrails.
  **Gap**: `telemetry-guardrails.md` (Finding 6) is memory-extension-owned prose; the books domain
  needs the same evaluator-outside-the-loop/CAPTURE-ONLY framing but has no equivalent document of
  its own, and the new `books-revise-submode.md` would otherwise have to restate it in full.
  **Recommendation**: the plan phase should decide whether `books-revise-submode.md` cites
  `telemetry-guardrails.md` by cross-extension reference (if that is a supported load-on-demand
  pattern) or restates the two or three directly-applicable principles briefly in a dedicated
  "books telemetry posture" subsection of its own pattern file — either is acceptable, but silent
  duplication without citation is not.

## Appendix

### Search queries / reads performed

- `.claude-extensions.json` → resolved `source_dir` for every loaded extension (books is present on
  disk but not yet "loaded" via the picker; confirmed present at
  `agent-system/extensions/books/`).
- `agent-system/extensions/memory/commands/distill.md` (full read).
- `agent-system/extensions/memory/skills/skill-distill/SKILL.md` (836 lines; targeted reads of the
  Shared Sub-Mode Skeleton section and the five sub-mode stub pointers).
- `agent-system/extensions/memory/context/project/memory/patterns/distill-review-submode.md` (full
  read).
- `agent-system/extensions/memory/context/project/memory/patterns/distill-meta-submode.md` (full
  read).
- `agent-system/extensions/memory/context/project/memory/patterns/distill-revise-submode.md`
  (partial read, watermark mechanism).
- `agent-system/extensions/memory/context/project/memory/telemetry-guardrails.md` (full read).
- `agent-system/extensions/books/context/project/books/standards/observation-record.md` (full read,
  249 lines).
- `agent-system/extensions/books/context/project/books/domain/known-gap-register.md` (partial read,
  marker vocabulary and Part A table).
- `agent-system/extensions/books/context/project/books/domain/certificate-ledger-and-records.md`
  (full read, for Decision-citation convention precedent).
- `agent-system/extensions/books/rules/books.md` (full read).
- `agent-system/extensions/books/context/project/books/standards/reconciliation-contract.md`
  (partial read, escalation/owner-approval precedent).
- `agent-system/extensions/books/manifest.json`, `EXTENSION.md`, `index-entries.json` (full reads).
- `agent-system/extensions/memory/manifest.json` (routing_agents/provides comparison).
- `agent-system/extensions/books/commands/certify.md`,
  `agent-system/extensions/books/skills/skill-books-certify/SKILL.md` (full reads, direct-execution
  command precedent).
- `agent-system/extensions/core/scripts/check-extension-docs.sh` (header comment and rule index
  only).
- `agent-system/extensions/core/docs/reference/standards/multi-task-creation-standard.md` (partial
  read, Components 0/2/4a/7).
- `agent-system/extensions/core/docs/examples/fix-it-flow-example.md`,
  `agent-system/extensions/cslib/rules/cslib.md` (grep + targeted read, AskUserQuestion/escalation
  precedent).
- `agent-system/extensions/core/context/formats/dispatch-metrics.md` (targeted read, CAPTURE-ONLY
  framing).
- `specs/TODO.md` (task 333's full description entry, cross-checked against the dispatch file).
- Repo-wide `grep -rn -i "escalat"` across every extension's `.md` files (confirmed no
  research-and-escalate primitive exists).
