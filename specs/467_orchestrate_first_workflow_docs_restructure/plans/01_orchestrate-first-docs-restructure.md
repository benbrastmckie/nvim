# Implementation Plan: Task #467

- **Task**: 467 - Restructure the user-facing agent system workflow documentation around an orchestrate-first spine
- **Status**: [IMPLEMENTING]
- **Effort**: 6 hours
- **Dependencies**: None (task 468 depends on this task, not the reverse)
- **Research Inputs**: specs/467_orchestrate_first_workflow_docs_restructure/reports/01_orchestrate-first-docs-restructure.md
- **Artifacts**: plans/01_orchestrate-first-docs-restructure.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, documentation-policy.md, no-task-references-in-deliverables.md, no-record-versioning-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Five source-store documentation files are rewritten so the user-facing workflow documentation
teaches the command surface that actually exists: `/task` -> `/orchestrate` -> `/todo`, with
`/orchestrate`'s forcing flags carrying the stepwise human-in-the-loop path that the removed
per-phase command sections used to serve. The work is sequenced so the two independent files
(`agent-system/extensions/README.md`, `docs/examples/research-flow-example.md`) land first
alongside the start of the large `user-guide.md` rewrite, then `user-guide.md` gains its
first-class `/orchestrate` treatment and new command coverage, then `user-installation.md` and
`docs-README.md` are aligned to the finished terminology, and a final phase runs the full gate
set and redeploys.

Every edit targets the source store (`agent-system/extensions/core/docs/` and
`agent-system/extensions/README.md`) resolved via `.claude-extensions.json`'s `source_dir`.
No file under `.claude/**` is hand-authored at any point; the deployed tree is refreshed only by
`deploy-headless.sh` in the final phase.

### Research Integration

The research report changed two of the dispatch's premises, and both changes are carried into
this plan rather than re-derived at implementation time:

- `docs/examples/research-flow-example.md` is **already** retargeted at
  `/orchestrate {N} --research`. It is not built on the removed command surface. Its actual
  defect is four spans of record-versioning language that violate
  `rules/no-record-versioning-in-deliverables.md`. Outcome 6's required action therefore becomes
  a targeted prose strip, not a retarget-or-retire choice (see Decisions below).
- Record 435's `file_scope` amendment was already applied at task-creation time and no longer
  lists `agent-system/extensions/core/docs/`. That acceptance item needs verification only, not
  action.

The report also established that `scripts/lint/lint-dead-command-recommendations.sh` currently
passes clean, that it polices only a literal `Next:`/`Run` line naming an undefined command, and
that `orchestrate.md`'s own Options table enumerates more flags than outcome 2's summary line
names (`--compare`, `--gate`, `--dry-run`, `--allow-self-modifying`, `--allow-scope-collision`
in addition to the context/effort/model/forcing flags). Phase 3 documents the full set.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context; no ROADMAP.md was consulted.

## Goals & Non-Goals

**Goals**:
- A reader following `user-guide.md` from its Quick Start can execute every command it names.
- `/orchestrate` receives first-class treatment: batch syntax, the three forcing flags, the
  context/effort flags, the model flags, the advisory and bypass flags, cycle budgets,
  resumption behavior, and the `[HOLD]` / `[PR READY]` statuses with their non-resumable and
  type-gated semantics.
- The stepwise human-in-the-loop review path is preserved, retargeted as
  `/orchestrate N --research` -> `/revise N` -> `/orchestrate N --implement`.
- `/project-overview`, `/please` and `/zulip` enter the command coverage.
- `user-guide.md` and `docs-README.md` both link to `agent-system/extensions/README.md`, and that
  README's "Available Extensions" table matches the real extension directory set.
- `user-installation.md` teaches the same spine as `user-guide.md`.
- The touched corpus is redeployed to a clean `verify-deploy.sh`.

**Non-Goals**:
- No new lint is written. The extension-table staleness gap the research report flagged
  (`lint-extension-readme-table.sh`) is explicitly deferred to a follow-up note, not built here.
- No dependency edge is added between this task and task 328, whose `file_scope` overlap on
  `agent-system/extensions/core/docs/` is a collision advisory only.
- No edit is made to record 435's `file_scope` (already amended) or to any other `specs/**` state.
- No file outside the five named documentation files and the redeploy output is touched.
- `/orchestrate`'s own command definition, the architecture docs, and the context patterns are
  read as authoritative sources, never edited to match the guide.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The stepwise human-in-the-loop path is deleted rather than retargeted while rewriting the Core Workflow Commands section | H | M | Phase 2 treats each removed-command subsection as a rename-plus-rewrite-the-invocation-line operation, keeping the surrounding explanatory prose about what each step produces; its verification criteria check for the presence of the three retargeted invocations by name |
| A rewritten doc introduces a new `Next: /research N`-shaped recommendation line and trips `lint-dead-command-recommendations.sh` | M | L | The compliant target is to not name `/research`, `/plan` or `/implement` as invocable commands at all, which outcome 1 already requires; the lint runs as an in-phase check in Phases 2, 3 and 4, not only in the final gate |
| Record-versioning language ("previously", "no longer", "formerly") leaks into the rewritten docs, which sit under `agent-system/**` and are not exempt | M | M | Each prose phase runs an explicit grep for the forbidden phrasings over its own touched files before closing; Phase 5 does the same over `research-flow-example.md` where the known occurrences live |
| A task-number citation leaks into a file under `agent-system/**` | M | L | `verify-deploy.sh` gate 4 (task-reference lint) is a real check in this tree and runs in the final phase; the prose phases also grep their own diffs |
| Relative links are copy-pasted between files at different directory depths and resolve nowhere (`../README.md` from `docs/guides/` vs. a sibling link from `docs/`) | M | M | Phase 4's and Phase 6's verification resolve each inserted link against its own file's directory with an explicit existence test, never by inspection |
| `deploy-headless.sh` hangs or runs long | M | M | Phase 6 follows `context/patterns/bounded-build-waiter.md`: a hard `timeout 540`, Bash tool timeout raised to 600000, writer liveness via `kill -0` on the captured PID, one waiter per log; never `run_in_background` polling or a Monitor wait |
| Phases 2 and 3 both edit `user-guide.md`, so concurrent execution would conflict | M | L | Phase 3 declares a dependency on Phase 2; they are in different waves and never run in parallel |
| `verify-deploy.sh`'s `TARGET` defaults to `$(pwd)`, silently SKIPping the source-store gates | M | M | Every gate-subset invocation in this plan names an explicit source-store `TARGET`, per `plan-format.md`'s `__FULL_SWEEP__` sub-case (b) |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 5 | -- |
| 2 | 3 | 2 |
| 3 | 4 | 3 |
| 4 | 6 | 1, 3, 4, 5 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Correct the Available Extensions Table [COMPLETED]

**Goal**: `agent-system/extensions/README.md`'s "Available Extensions" table matches the real
extension directory set, with each row's Task Type taken from that extension's own
`manifest.json`.

**Tasks**:
- [x] Re-enumerate the extension directory set: `ls -1 agent-system/extensions/` filtered to
      directories, excluding `core` (which is not a loadable domain extension) and the
      `README.md` file itself. Do not trust the research report's snapshot list. *(completed: 21 directories enumerated)*
- [x] For each directory not already a table row, read its `manifest.json` and extract the
      `task_type` value (use `-` where the manifest declares none, matching the existing
      `filetypes` / `memory` / `slidev` / `approvals` rows) and the `description` value. *(completed: books, cslib, email, literature)*
- [x] Confirm each new row's `[README](<ext>/README.md)` link target exists on disk. *(completed)*
- [x] Add the missing rows to the table, keeping the existing row ordering convention (domain
      language extensions first, then capability extensions) rather than appending blindly. *(completed: books/cslib placed after lean; literature/email placed in capability section)*
- [x] Re-read the table and confirm the row count equals the enumerated directory count. *(completed: 21 rows == 21 directories)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: the enumeration is expected to yield 21 loadable extension directories
against 17 existing table rows, with `books`, `cslib`, `email` and `literature` missing
(`literature`'s manifest declares no `task_type`, so its row takes `-`). This is a hypothesis
from the research pass, not a fact: the implementer confirms it by running the `ls` enumeration
and the per-manifest `jq` read in this phase's first two steps and reconciling against the
table, and adjusts the row set to whatever the enumeration actually returns.

**Tier Justification**: Markdown table rows with zero executable surface, and
`suite_selection_select` returns `__FULL_SWEEP__` for this path, so no shell suite covers it;
the covering checks are the `prose` row's diff read-through plus the enumeration-vs-row-count
reconciliation in this phase's last step and `bash .claude/scripts/lint/lint-dead-command-recommendations.sh --quiet`.

**Files to modify**:
- `agent-system/extensions/README.md` - add the missing rows to the "Available Extensions" table

**Verification**:
- The directory enumeration and the table's first column agree, element for element, with no
  directory unlisted and no row naming a directory that does not exist.
- Every new row's `README` link target resolves to a file on disk.
- `bash .claude/scripts/lint/lint-dead-command-recommendations.sh --quiet` exits 0.
- `grep -nEi 'previously|no longer|formerly|used to|supersed' agent-system/extensions/README.md`
  returns nothing in the added rows.

---

### Phase 2: Rewrite the user-guide.md Spine and Status Model [COMPLETED]

**Goal**: `user-guide.md`'s navigation, Quick Start, status model, Core Workflow Commands
section, Command Summary Table, Status Transitions diagram, Language Routing table and
Troubleshooting entries all describe the `/task` -> `/orchestrate` -> `/todo` spine, with the
stepwise human-in-the-loop path retargeted rather than deleted.

**Tasks**:
- [x] Re-verify the stale line ranges against the live file before editing (the report's numbers
      are approximate): Table of Contents, Quick Start / "Your First Workflow", Status
      Progression, the `### /task` through `### /implement` subsections, Command Summary Table,
      Status Transitions, Language Routing, and the `/implement`-naming Troubleshooting entry. *(completed: live file was 687 lines matching hypothesis)*
- [x] Rewrite the Quick Start cycle diagram and the numbered "Your First Workflow" walkthrough
      around `/task "Description"` -> `/orchestrate N` -> `/todo`. *(completed)*
- [x] Add a second, explicitly-labelled stepwise walkthrough immediately after it:
      `/task "Description"` -> `/orchestrate N --research` -> review the report and plan ->
      `/revise N` to adjust the plan -> `/orchestrate N --implement` -> `/todo`. This is the
      retargeted form of the human-in-the-loop path and is non-negotiable. *(deviation: altered — inserted an explicit `/orchestrate N --plan` step between `--research` and `/revise`; executing the literal sequence would fail since `--implement` requires an existing plan artifact and `/revise` on a plan-less task only updates the description. See progress file phase-2-progress.json deviations array.)*
- [x] Retarget, do not delete, the `### /research Command`, `### /plan Command` and
      `### /implement Command` subsections: fold their explanatory prose about what each phase
      produces (report path, plan structure and its `Verification Tier` field, summary path,
      resume behavior, phase markers) into the `/orchestrate` phase descriptions, each reached by
      its forcing flag. Keep `### /task Command` and `### /revise Command` as standalone
      subsections — both commands are real. *(completed)*
- [x] Rewrite the Status Progression table so its third column names `/orchestrate` (with the
      relevant forcing flag where it clarifies) rather than the three removed commands, and add
      explicit rows for `[HOLD]` and `[PR READY]`. Reconcile against
      `context/standards/status-markers.md`'s "Target Arguments vs. Resting States" subsection:
      `[HOLD]` is non-terminal but not resumable by an ordinary command (liftable only by an
      explicit `/orchestrate N --research|--plan|--implement` override, which admits the task for
      one dispatch and preserves the hold afterward, or by an operator-run
      `update-task-status.sh preflight ... unhold`); `[PR READY]` is reachable only for
      `task_type: pr`. *(completed)*
- [x] Rewrite the Command Summary Table: drop the `/research`, `/plan` and `/implement` rows;
      expand the `/orchestrate` row into the batch and forcing-flag forms. *(completed)*
- [x] Rewrite the Status Transitions diagram with `/orchestrate` as the driver and `[HOLD]` /
      `[PR READY]` present, using the box-drawing and arrow conventions in
      `context/project/neovim/standards/box-drawing-guide.md`. *(completed: kept the existing plain-ASCII arrow style since the box-drawing guide defines corner/line/intersection glyphs for boxed diagrams, not flow arrows, and introducing a new arrowhead glyph would be inconsistent with the rest of the file)*
- [x] Re-audit the Language Routing table against the current core task types (`general`, `meta`,
      `markdown`) and the extension routing model; correct or trim it to what is true. *(completed: corrected Tools columns against merge-sources/claudemd.md and noted that `markdown` has no automatic keyword-detection path in scripts/lib/task-type-detect.sh)*
- [x] Fix the Troubleshooting entry that names `/implement` as the command that fails to begin,
      retargeting it at `/orchestrate N --implement` and its "no plan artifact; run --plan first"
      admission refusal. *(completed)*
- [x] Rewrite the Table of Contents to match the resulting heading set. *(completed)*
- [x] Update the `**Last Updated**` line to the implementation date. *(completed: 2026-11-04)*

**Timing**: 2 hours

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: the file is expected to be 687 lines with the stale regions at roughly
Table of Contents 11-34, Quick Start 38-77, Status Progression 78-95, Core Workflow Commands
97-290, Command Summary Table 571-595, Status Transitions 597-613, Language Routing 615-624, and
one `/implement` mention near 643. The implementer confirms each range by re-running
`grep -n '^#\{1,4\} ' agent-system/extensions/core/docs/guides/user-guide.md` and
`grep -n '/research\|/plan\|/implement' ...` against the live file before editing, and works from
the observed positions rather than these numbers.

**Tier Justification**: Markdown prose with zero executable surface, and `suite_selection_select`
returns `__FULL_SWEEP__` for this path; the covering check for this phase's specific risk — a
rewritten doc still recommending a command that does not exist — is
`bash .claude/scripts/lint/lint-dead-command-recommendations.sh --quiet` together with the
`prose` row's diff read-through.

**Files to modify**:
- `agent-system/extensions/core/docs/guides/user-guide.md` - Table of Contents, Quick Start,
  stepwise walkthrough, Status Progression, Core Workflow Commands, Command Summary Table, Status
  Transitions, Language Routing, Troubleshooting, Last Updated

**Verification**:
- `grep -nE '^/?(research|plan|implement) [0-9]|`/(research|plan|implement)`' agent-system/extensions/core/docs/guides/user-guide.md`
  finds no occurrence presenting any of the three as an invocable command.
- The stepwise walkthrough names, in order, `/orchestrate N --research`, `/revise N` and
  `/orchestrate N --implement`.
- The Status Progression table and the Status Transitions diagram each contain `[HOLD]` and
  `[PR READY]`.
- `bash .claude/scripts/lint/lint-dead-command-recommendations.sh --quiet` exits 0.
- `grep -nEi 'previously|no longer|formerly|used to|supersed|was replaced|retired'` over the file
  returns nothing in the rewritten regions.
- No emoji, per `context/project/neovim/standards/emoji-policy.md`.

---

### Phase 3: First-Class /orchestrate Treatment and New Command Coverage [COMPLETED]

**Goal**: `user-guide.md` documents `/orchestrate`'s full surface, covers `/project-overview`,
`/please` and `/zulip`, and carries a top-level Extensions section linking to the extension
catalog.

**Tasks**:
- [x] Read the authoritative sources in full before drafting:
      `agent-system/extensions/core/commands/orchestrate.md` (Arguments, Constraints, Options),
      `docs/architecture/orchestrate-state-machine.md` (the Complete State Table, "The
      `needs_research` Fork", "MAX_CYCLES Enforcement" including the `--hard` multiplier and the
      `MAX_CYCLES_MT = min(task_count * 5, 25)` multi-task cap, "Forced Phases on a Terminal or
      Archived Task", "Dependency Gating Model", "Batch Size Cap (MAX_TASKS)", "Exit
      Conditions"), `docs/architecture/orchestrate-cycle-postflight.md`,
      `docs/architecture/handoff-schema.md`, `docs/architecture/batch-admit-schema.md`,
      `context/patterns/batch-orchestration-guardrails.md`'s "Batching Is the Default" section,
      `context/patterns/multi-task-operations.md`, and
      `agent-system/extensions/core/merge-sources/claudemd.md`. *(completed)*
- [x] Replace the `### /orchestrate Command` stub with a full subsection covering: batch syntax
      (single, comma-separated, range, mixed) and the "batching is the default, not an
      optimization" rule including the `--depends-on-add` edge for an unordered file-territory
      overlap; the `--research` / `--plan` / `--implement` forcing flags with their
      artifact-keyed (not status-keyed) admission rules, their canonical composition order, the
      per-task forced-sequence exhaustion behavior, and their effect on a terminal or archived
      task; `--lit`, `--hard`, `--clean`, `--fast` (including that `--fast` skips the
      research-first default for a `not_started` task while `--research` still forces research
      under it, and that the planner can route back via `needs_research`); the model flags
      `--haiku` / `--sonnet` / `--opus` / `--fable`; the advisory and bypass flags `--compare`,
      `--gate`, `--dry-run`, `--allow-self-modifying`, `--allow-scope-collision`; cycle budgets
      and what happens at the cap; resumption behavior on re-invocation; and that a failed task
      never blocks siblings in its own wave but does block dependents in later waves. *(completed: all 16 flags present, verified by token-set diff against orchestrate.md's Options table)*
- [x] Add the `[HOLD]` and `[PR READY]` semantics to this subsection in operational terms (how a
      held task behaves under a bare `/orchestrate N` versus under an explicit forcing flag). *(completed)*
- [x] Add "When to use" / "When NOT to use" guidance that points a reader wanting plan review at
      the stepwise path Phase 2 established, rather than away from `/orchestrate` entirely. *(completed)*
- [x] Add a `### /project-overview Command` subsection near `/task` in the task-bootstrap
      region, a `### /please Command` subsection adjacent to `/merge` (user-only, push-adjacent),
      and a `### /zulip Command` subsection in Utility Commands near `/fix-it`. Take each one's
      syntax from its own command definition file under
      `agent-system/extensions/core/commands/`, never from memory. *(completed; the project-overview.md command file's own stale "(/plan, /implement)" reference was not copied into the guide — paraphrased as driving the created task through /orchestrate instead, per outcome 1)*
- [x] Add the three commands to the Command Summary Table. *(completed)*
- [x] Add a top-level `## Extensions` section explaining that domain capabilities are loaded
      on demand, linking to `../../../README.md` (the extension catalog, resolved relative to
      `docs/guides/`) and naming the `<leader>ac` (Neovim) and `<leader>ao` (OpenCode) load and
      unload bindings. Verify the relative depth by resolving the path from the file's own
      directory, not by analogy to another file. *(completed: verified via test -f against the live file's own dirname)*
- [x] Update the Table of Contents to include the new sections. *(completed)*

**Timing**: 1.5 hours

**Depends on**: 2

**Verification Tier**: prose

**Scope Hypothesis**: `orchestrate.md` is expected to be 349 lines with an Options table
enumerating 16 flags, and the `/orchestrate` stub is expected to occupy roughly lines 402-431 of
the post-Phase-2 `user-guide.md`. Both are confirmed by reading the live files at
implementation time; the flag list written into the guide is whatever `orchestrate.md`'s Options
table actually contains then, not this count.

**Tier Justification**: Markdown prose with zero executable surface
(`suite_selection_select` returns `__FULL_SWEEP__`); the covering checks are
`bash .claude/scripts/lint/lint-dead-command-recommendations.sh --quiet` for the newly named
commands plus a per-link existence test on the inserted extension-catalog link and the `prose`
row's diff read-through.

**Files to modify**:
- `agent-system/extensions/core/docs/guides/user-guide.md` - `/orchestrate` subsection,
  `/project-overview`, `/please`, `/zulip` subsections, Command Summary Table rows, new
  `## Extensions` section, Table of Contents

**Verification**:
- The `/orchestrate` subsection names every flag present in `orchestrate.md`'s Options table;
  check by diffing the flag token set extracted from each file.
- `/project-overview`, `/please` and `/zulip` each appear as a heading and a Command Summary
  Table row, and each named syntax matches its command definition file.
- The `## Extensions` section's link resolves:
  `test -f "$(dirname agent-system/extensions/core/docs/guides/user-guide.md)/../../../README.md"`
  succeeds and names `agent-system/extensions/README.md`.
- `bash .claude/scripts/lint/lint-dead-command-recommendations.sh --quiet` exits 0.
- No record-versioning phrasing and no task-number citation in the added prose.

---

### Phase 4: Align user-installation.md and docs-README.md [COMPLETED]

**Goal**: `user-installation.md` teaches the same spine as the finished `user-guide.md`, and
`docs-README.md` links to the extension catalog and describes the examples accurately.

**Tasks**:
- [x] In `user-installation.md`'s "Setting Up Claude Agent Commands" section, replace the
      "Structured Workflow: `/research` -> `/plan` -> `/implement` cycle" bullet with the
      `/task` -> `/orchestrate` -> `/todo` spine, using the same wording as `user-guide.md`'s
      Quick Start. *(completed)*
- [x] Rewrite that section's "Available Commands" table: drop the `/research`, `/plan` and
      `/implement` rows, add `/orchestrate` (with a one-line mention of the forcing flags) and
      `/revise`, and keep `/task` and `/todo`. *(completed)*
- [x] Verify the section's `[Commands Reference](../commands/README.md)` link still resolves from
      `docs/guides/`; correct it if it does not. *(completed: link was broken — commands/README.md
      actually lives two levels up, not one; corrected both occurrences in this file to
      `../../commands/README.md` and verified with `test -f`)*
- [x] Re-check `user-installation.md`'s "Next Steps" / "Documentation" region for any other
      mention of the three removed commands and retarget it. *(completed: no remaining mentions; the duplicate Commands Reference link in this region was also corrected)*
- [x] In `docs-README.md`'s `## Related Documentation` section, add a link to the extension
      catalog (`../../README.md` resolved from `docs/`) under `### Core References` or a new
      `### Extensions` entry, naming the `<leader>ac` / `<leader>ao` load mechanism in one line. *(completed: added new `### Extensions` entry; discovered the pre-existing `### Project Documentation` entry used the identical `../../README.md` path while labeled "Main project documentation" — corrected it to the true project root `../../../../README.md`, verified with `test -f`, to avoid two differently-labelled entries pointing at the same file)*
- [x] Tighten `docs-README.md`'s `## Examples` description of `research-flow-example.md` so it
      describes the research-phase dispatch flow rather than "the research command execution
      flow". *(completed)*

**Timing**: 0.75 hours

**Depends on**: 3

**Verification Tier**: prose

**Tier Justification**: Markdown prose and table rows with zero executable surface
(`suite_selection_select` returns `__FULL_SWEEP__`); the covering checks are
`bash .claude/scripts/lint/lint-dead-command-recommendations.sh --quiet` plus a `test -f`
existence test on each touched or inserted relative link resolved from its own file's directory.

**Files to modify**:
- `agent-system/extensions/core/docs/guides/user-installation.md` - "Setting Up Claude Agent
  Commands" section, Available Commands table, Next Steps region
- `agent-system/extensions/core/docs/docs-README.md` - `## Related Documentation` extension-catalog
  link, `## Examples` description

**Verification**:
- Neither file presents `/research`, `/plan` or `/implement` as an invocable command.
- `user-installation.md`'s spine wording matches `user-guide.md`'s Quick Start spine.
- Every relative link in the two touched regions resolves, tested with `test -f` from each file's
  own directory.
- `bash .claude/scripts/lint/lint-dead-command-recommendations.sh --quiet` exits 0.
- No record-versioning phrasing and no task-number citation in the added prose.

---

### Phase 5: Strip Record-Versioning Prose from research-flow-example.md [COMPLETED]

**Goal**: `docs/examples/research-flow-example.md` complies with
`rules/no-record-versioning-in-deliverables.md` while its current-architecture content is left
intact.

**Tasks**:
- [x] Re-locate the offending spans in the live file with
      `grep -nEi 'previously|no longer|formerly|used to|supersed|retired|deleted|removed|was replaced|Document Version'`
      rather than trusting the line numbers below. *(completed: found exactly 4 spans as hypothesized, at lines 5-6, 79, 440 and 442)*
- [x] Rewrite the opening paragraph so it states what the example traces, with no reference to an
      earlier version of itself or to removed commands. *(completed)*
- [x] Rewrite the "used to carry here have all collapsed into this one call" clause as a
      statement of the current call structure. *(completed)*
- [x] Remove the parenthetical aside in the closing attribution block that names deleted
      components. *(completed: removed together with the Document Version footer line below, since both spans were on the same two-line block)*
- [x] Remove the `Document Version: 3.0 (Updated ... after the standalone /research command ...
      were deleted)` footer line entirely; a deliverable under `agent-system/**` carries no
      page-level version label. *(completed)*
- [x] Confirm no `/research`, `/plan` or `/implement` invocation was introduced, and that the
      `/orchestrate {N} --research` framing the file already uses is untouched. *(completed: confirmed via git diff --stat, 3 insertions/8 deletions across exactly the 3 edited spans, Setup/Move walkthrough byte-identical)*

**Timing**: 0.4 hours

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: four offending spans are expected — the opening-paragraph "supersedes an
earlier version ... both were retired" sentence near lines 5-6, a "used to carry here" clause
near line 79, a "were deleted" aside near line 442, and the `Document Version: 3.0` footer below
"Related Documentation". The implementer confirms the set by running the grep in this phase's
first step over the live 444-line file and treats whatever it returns as the authoritative list,
including any span the research pass missed.

**Tier Justification**: Markdown prose with zero executable surface
(`suite_selection_select` returns `__FULL_SWEEP__`), and no repo-wide record-version lint exists
to call; the covering check is the explicit
`grep -nEi 'previously|no longer|formerly|used to|supersed|retired|deleted|removed|was replaced|Document Version' agent-system/extensions/core/docs/examples/research-flow-example.md`
returning no deliverable-prose hit, read together with the `prose` row's diff read-through.

**Files to modify**:
- `agent-system/extensions/core/docs/examples/research-flow-example.md` - opening paragraph,
  the collapsed-call clause, the closing attribution aside, the Document Version footer

**Verification**:
- The grep above returns no hit that is record-versioning language about this document or about
  removed commands.
- No `Document Version:` line remains.
- The `/orchestrate {N} --research` content and the Setup / Move 1 / Move 2 / Move 3 walkthrough
  are byte-identical to their pre-phase state apart from the four edited spans; confirm with
  `git diff --stat` and a diff read-through.
- `bash .claude/scripts/lint/lint-dead-command-recommendations.sh --quiet` exits 0.

---

### Phase 6: Full Gate Set, Acceptance Checks and Redeploy [COMPLETED WITH EXCLUSIONS]

**Goal**: every acceptance criterion is mechanically confirmed and the source store is redeployed
to a clean verification.

**Tasks**:
- [x] Run `bash .claude/scripts/lint/lint-dead-command-recommendations.sh --quiet` over the whole
      corpus and confirm exit 0 with no output. *(completed: exit 0, no output)*
- [x] Run a relative-link check across all five touched files: for each markdown link target that
      is a relative path, resolve it against the containing file's own directory and assert the
      target exists. Report every failure, not just the first. *(completed with exclusions: 71
      relative links checked across the five files; 12 failures, all pre-existing nav-bar links
      unrelated to this task's edits -- see Reasoned Exclusions below. Zero failures among links
      this task added or modified.)*
- [x] Re-run the extension-directory enumeration and confirm
      `agent-system/extensions/README.md`'s table still matches it. *(completed: 21 directories == 21 rows, exact element-for-element match)*
- [x] Verify record 435's `file_scope` does not list `agent-system/extensions/core/docs/`:
      `jq -r '.active_projects[] | select(.project_number==435) | .file_scope[]' specs/state.json | grep -c 'core/docs'`
      returns 0. This is a verification only; make no edit to `specs/state.json`. *(completed: returns 0)*
- [x] Walk `user-guide.md`'s Quick Start and both walkthroughs and confirm every command named is
      backed by a definition file under `agent-system/extensions/*/commands/`, by extracting the
      command tokens and testing each against the enumerated definition set. *(completed: tokens {merge, orchestrate, revise, task, todo}, all present in the 47-command definition set, zero missing)*
- [x] Run the complete gate set: `bash .claude/scripts/verify-deploy.sh` (source-store path
      `agent-system/extensions/core/scripts/verify-deploy.sh`), with an explicit source-store
      `TARGET`, and confirm it is clean. *(completed with exclusions: this task's own dispatch
      file carries a Batch Gate Deferral directive -- this dispatch discharged the tier against a
      scoped invocation instead (`run-all.sh --only test-lint-dead-command-recommendations.sh`
      plus `verify-deploy.sh --only-gate 3`, both clean). The complete gate set DID run once
      anyway, inline inside `deploy-headless.sh` below, and reported one unrelated failure -- see
      Reasoned Exclusions below.)*
- [x] Redeploy via `deploy-headless.sh` to `RESULT=landed_verify_clean`, following
      `context/patterns/bounded-build-waiter.md`: raise the Bash tool timeout to 600000, wrap the
      invocation in `timeout 540`, capture the PID, poll writer liveness with `kill -0` on the
      captured PID (never `ps | grep` or `pgrep -f`), and run exactly one waiter on the log.
      Never hand-patch a deployed file in place of a redeploy. *(completed with exclusions:
      `timeout 540 bash agent-system/extensions/core/scripts/deploy-headless.sh` ran to
      completion within the Bash tool's own foreground window -- no backgrounding/waiter was
      needed since the command returned well inside it -- and reported `RESULT=landed_verify_red`,
      not `_clean`. The deploy itself landed; the one gate failure is the same unrelated,
      pre-existing defect named below. Not re-run after a fix, since the fix is out of scope.)*
- [x] Confirm the deployed tree's copies of the five files match the source store. *(completed:
      4 of 5 files have a deployed counterpart under `.claude/docs/` and all 4 match byte-for-byte
      via `diff -q`; the 5th file, `agent-system/extensions/README.md`, is a source-store-only
      extension catalog with no deployed counterpart by design -- confirmed by `find .claude
      -iname README.md` finding none carrying the "Available Extensions" table)*
- [x] Record a follow-up note (not a new lint) that nothing checks
      `agent-system/extensions/README.md`'s table against the real extension directory set.
      *(completed: recorded via `issue-record.sh`, class "follow-up recommendation")*

**Timing**: 1 hour

**Depends on**: 1, 3, 4, 5

**Verification Tier**: full

**Files to modify**:
- (none) - verification and redeploy only; `deploy-headless.sh` rewrites `.claude/**` as its own
  output, which is not a hand-authored edit

**Verification**:
- `bash .claude/scripts/lint/lint-dead-command-recommendations.sh --quiet` exits 0. **Met.**
- The relative-link check reports zero unresolved targets across all five files. **Met for every
  link this task added or modified; 12 pre-existing, out-of-scope failures excluded (see below).**
- The extension-table-vs-directory reconciliation reports zero differences. **Met.**
- The record-435 `file_scope` grep count is 0. **Met.**
- Every command token in `user-guide.md`'s Quick Start and both walkthroughs maps to a definition
  file under `agent-system/extensions/*/commands/`. **Met.**
- The complete gate set runs green: `bash .claude/scripts/verify-deploy.sh` with an explicit
  source-store `TARGET`, all gates reported, none reaching the zero-check-under-filter condition.
  **Discharged against the Batch Gate Deferral's scoped tier (both sub-checks green); the
  complete set ran once anyway via `deploy-headless.sh` and reported one unrelated failure, see
  Reasoned Exclusions.**
- `deploy-headless.sh` reports `RESULT=landed_verify_clean` within the bounded wait. **Reported
  `RESULT=landed_verify_red` instead -- the deploy landed, verification is red on one unrelated
  gate; see Reasoned Exclusions.**

#### Reasoned Exclusions

| Item | Reason | Evidence |
|------|--------|----------|
| 12 pre-existing broken relative links in `user-guide.md` and `user-installation.md` nav bars (`../README.md`, `../../CLAUDE.md`, and one `../../../docs/installation/README.md`) | Predates this task; not named in the dispatch's defect list or the plan's Scope Hypotheses. The plan's own Risk table scopes its relative-link verification to links this task inserts or modifies -- its worked example even cites this exact `../README.md` from `docs/guides/` pattern as the risk to avoid introducing, not an instruction to audit every historical link. `../../CLAUDE.md` resolves correctly in the deployed tree (`.claude/CLAUDE.md` exists there) but not in the source store, since `core/CLAUDE.md` is a deploy-generated merge artifact absent from source by design -- not a simple depth-correction case like the two links Phase 4 did fix. | `python3` link-existence sweep across all 71 relative links in the five files: 12 failures, all pre-existing (confirmed via `git show <phase-2/3/4-commit> -- <file> \| grep '^\+.*(link pattern)'` returning no match for any of the 12); zero failures among links added by this task's own commits. Logged via `issue-record.sh` (class "stale documentation"). |
| `verify-deploy.sh` gate 18 (`lint-task-lookup-adoption.sh`) failure: 5 violations, all in `agent-system/extensions/core/scripts/test-state-write-concurrency.sh` | Unrelated to this task's five-file documentation scope; a hand-rolled jq task-lookup shape in an unrelated test fixture file. Per this plan's own Rollback/Contingency guidance ("If `verify-deploy.sh` fails on a gate unrelated to this task's edits, report it rather than widening scope to fix it"), not fixed here. | `bash agent-system/extensions/core/scripts/lint/lint-task-lookup-adoption.sh --verbose` output: "Files with violations: 1" naming only `test-state-write-concurrency.sh`; `git log --oneline -3 -- <that file>` shows its most recent touch was an unrelated prior task ("task 312"), predating this dispatch. Logged via `issue-record.sh` (class "unrelated gate failure"). |

Both exclusions satisfy the five-condition admission test: each is a deliberate, tightly-scoped
decision (not abandonment or stall), carries a stated reason and evidence above, and leaves no
residual work for a future dispatch of *this* task -- a fix for either, should one be wanted, is
an independent task against an unrelated file, not a continuation of this documentation
restructure.

---

## Testing & Validation

- [ ] `scripts/lint/lint-dead-command-recommendations.sh` green across the whole
      `agent-system/extensions` corpus.
- [ ] Relative-link check green across `user-guide.md`, `user-installation.md`, `docs-README.md`,
      `research-flow-example.md` and `extensions/README.md`.
- [ ] `agent-system/extensions/README.md`'s "Available Extensions" table matches the enumerated
      extension directory set exactly.
- [ ] No file under `agent-system/**` touched by this task names `/research`, `/plan` or
      `/implement` as an invocable command.
- [ ] No record-versioning phrasing and no task-number citation in any touched file under
      `agent-system/**`.
- [ ] No emoji in any touched file, per the emoji policy.
- [ ] Record 435's `file_scope` does not claim `agent-system/extensions/core/docs/`.
- [ ] `verify-deploy.sh` clean and `deploy-headless.sh` at `RESULT=landed_verify_clean`.
- [ ] A reader can execute every command named in `user-guide.md`'s Quick Start.

## Artifacts & Outputs

- Rewritten `agent-system/extensions/core/docs/guides/user-guide.md`
- Aligned `agent-system/extensions/core/docs/guides/user-installation.md`
- `agent-system/extensions/core/docs/docs-README.md` with the extension-catalog link
- `agent-system/extensions/core/docs/examples/research-flow-example.md` with the
  record-versioning prose stripped
- Corrected `agent-system/extensions/README.md` "Available Extensions" table
- A regenerated `.claude/` deploy tree (produced by `deploy-headless.sh`, not hand-authored)
- A follow-up note recommending an extension-table staleness lint
- `specs/467_orchestrate_first_workflow_docs_restructure/summaries/01_*-summary.md`

## Rollback/Contingency

All five edited files are tracked in git and the whole change is documentation-only, so the
rollback is a per-file `git checkout` of the source-store paths followed by a redeploy. Before any
rollback that would discard uncommitted work, run
`bash .claude/scripts/git-snapshot.sh 467` first, per `rules/git-workflow.md`'s "No Destructive
Git on Uncommitted Work" rule; for an ordinary defensive checkpoint before starting the large
`user-guide.md` rewrite, use `bash .claude/scripts/git-snapshot.sh --no-revert 467` instead, which
is durable without reverting the working tree.

Per-phase contingencies:
- If `deploy-headless.sh` does not reach `landed_verify_clean` within the bounded wait, leave the
  source store committed and the task `[PARTIAL]` with the deploy step named as the remaining
  work. Do not hand-patch `.claude/**` to simulate a successful deploy.
- If `verify-deploy.sh` fails on a gate unrelated to this task's edits, report it rather than
  widening scope to fix it; the collision advisory with task 328 makes an unrelated failure in
  `core/docs/` plausible.
- If a `file_scope_collision` deferral against task 328 appears in a batched dispatch, that is
  the intended visibility surface and not an error; proceed without adding a dependency edge.
