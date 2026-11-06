# Implementation Plan: Task #408

- **Task**: 408 - Gate the formal extension's mandatory Mathlib-lookup step on an actual Lean target
- **Status**: [IMPLEMENTING]
- **Effort**: 4 hours
- **Dependencies**: Task 359
- **Research Inputs**: specs/408_gate_mathlib_lookup_on_lean_target/reports/01_gate-mathlib-lookup-surfaces.md
- **Artifacts**: plans/01_gate-mathlib-lookup-on-lean-target.md (this file)
- **Standards**:
  - .claude/context/formats/plan-format.md
  - .claude/context/standards/status-markers.md
  - .claude/rules/artifact-formats.md
  - .claude/rules/state-management.md
  - .claude/rules/source-store-deploy-boundary.md
  - .claude/rules/no-task-references-in-deliverables.md
  - .claude/rules/no-record-versioning-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The unconditional Mathlib-lookup obligation is restated at ~30 individual line sites across four
research-agent contracts and their four skill wrappers in the `formal` extension's source store.
This plan extracts one shared gate definition into a new `context/patterns/mathlib-lookup-gate.md`
file (registered through the extension's `manifest.json` and `index-entries.json`), then rewrites
each of the eight contract surfaces to point at that single definition plus whatever
domain-specific residue must stay inline. The gate makes the step mandatory only when the task has
a genuine Lean target AND the four `lean_*` lookup tools are registered in the session; otherwise
the step is skipped with a one-line report note and a machine-visible metadata field.

### Research Integration

Key findings carried from the research report and re-derived at plan-authoring time:

- **Source store confirmed, `formal` not deployed here.** `.claude-extensions.json` has no
  top-level `source_dir` and no `formal` entry at all (`extensions` keys re-derived:
  `approvals, core, email, lean, literature, memory, nix, nvim, sapience`). The edit target is
  therefore `agent-system/extensions/formal/` directly, and no deployed `.claude/` copy of these
  files exists in this repository.
- **All eight named files verified present** with the line counts the report states
  (`logic` 385, `math` 384, `physics` 353, `formal` 290; skills 202 / 177 / 130 / 131).
- **The report's surface line numbers were re-derived and match exactly.** The grep inventory in
  Phase 2/3 below is this plan's own measurement, not a copy.
- **`task_type == "lean4"` will never fire for these four agents.** They are routed only under
  `formal`, `formal:logic`, `formal:math`, `formal:physics`. The `file_scope`-contains-`*.lean`
  sub-signal is the one that actually fires in practice; `lean-mcp-preflight-check.sh` already
  solved this exact structural gap by gating on lakefile presence rather than `task_type`.
- **A research agent cannot read its own `file_scope` from the dispatch file.**
  `orchestrate-build-dispatch.sh` echoes only *sibling* tasks' `file_scope` (for the Territory
  block), so the gate procedure must instruct a direct `specs/state.json` read keyed on
  `project_number` (confirmed field name, not `task_number`).
- **Condition (b) needs no new infrastructure** — a single `ToolSearch` call returning no match is
  exactly the mechanism already observed in the originating dispatch.

### Finding This Plan Adds Beyond the Research Report

The research report recommends creating `context/patterns/mathlib-lookup-gate.md` but does not
address **registration**, and states the implementation file list "is already pinned and needs no
further discovery" at the eight `file_scope` files. That is incomplete. Verified at
plan-authoring time:

- `agent-system/extensions/formal/context/patterns/` **does not exist** — the extension's
  `context/` tree holds only `project/logic`, `project/math`, `project/physics`.
- The formal manifest's `provides.context` declares exactly those three directory entries. A file
  under a fourth, undeclared tier **never propagates** through the manifest-driven descriptor
  copier (`loader.lua`'s `M.copy_category`).
- `check-extension-docs.sh` enforces this in both directions: line 236-240 fails when a declared
  `provides.context` entry is missing on disk, and Rule L (line ~1447) reports a deployed context
  file tracing to no `provides.context` entry. `EXT_DIR` defaults to
  `$REPO_ROOT/agent-system/extensions`, so these checks scan the **source store** and apply to
  `formal` even though it is undeployed here.
- A top-level `patterns` entry is precedent-following, not novel: `core`'s `provides.context`
  already declares `patterns`, and Rule L's own comment states multiple extensions may legitimately
  declare the same directory-name entry, each extension's files being unioned rather than
  overwritten.

**Consequence**: the implementation file set is **eleven** files, not eight — the eight contract
files plus the new pattern file, `manifest.json`, and `index-entries.json`. Phase 1 covers the
three additions.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch's delegation context, so no roadmap consultation
was performed and no roadmap phases are included.

## Goals & Non-Goals

**Goals**:

- One shared, registered gate definition that all eight contract surfaces point at, so the
  extension cannot end up with one gated and three ungated copies of the same step.
- The gate conditions the step on (a) a genuine Lean target and (b) the lookup tools being
  registered, with a skip-and-log outcome when either is false.
- The step remains mandatory, unchanged, when both conditions hold.
- A skip is machine-visible in `.return-meta.json`, not only in report prose.
- The source store stays lint-clean: the new context tier is declared and indexed.

**Non-Goals**:

- Deploying the `formal` extension into this repository's `.claude/` tree. There is no
  `.claude-extensions.json` entry for it; adding one is out of scope.
- Touching `physics-research-agent.md:36` ("Mathlib4 integration patterns"), which is unrelated
  domain-knowledge context-loading guidance, not part of the lookup-step obligation.
- Changing the behaviour of the tool-*failure* handling block beyond making it clear that it
  applies only once the gate has resolved to "perform".
- Any change to the `lean` extension, to `lean-mcp-preflight-check.sh`, or to
  `orchestrate-build-dispatch.sh`. The gate is read by the agent at its own runtime; no dispatch
  plumbing changes.
- Introducing a new logging channel. The skip note reuses the existing report-prose convention;
  `issue-record.sh` stays reserved for genuine deviations and wins.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Implementation checks only `task_type == "lean4"` for condition (a), so the gate behaves as if (a) is always false for these four `formal`-routed agents | H | M | Phase 1 states the `file_scope`-contains-`*.lean` sub-signal as the PRIMARY, actually-firing form, with the `task_type` sub-signal as the secondary `OR` branch. Phase 1 verification greps the pattern file for both sub-signals. |
| The gate prose is duplicated across eight files and drifts — the same failure mode this task exists to prevent, recurring one level down | H | M | Phases 2-3 replace prose with a pointer to the single pattern file; only domain-specific example queries stay inline. Phase 4 greps all eight files for the pointer path and asserts eight hits. |
| `manifest.json` declares `patterns` before the directory exists, tripping `check-extension-docs.sh:236-240` | M | M | Phase 1 orders the steps file-first, manifest-second, so no intermediate state is red; `Commit Mode` stays `per-substep`. |
| The new pattern file never propagates to a future `formal` deploy because registration is forgotten | M | L | Phase 1 makes registration (`manifest.json` + `index-entries.json`) explicit substeps with their own verification, not an afterthought of file creation. |
| A task-number reference or record-versioning phrasing lands in a file under `agent-system/**` | M | M | Phase 4 runs gate 4 (task-reference lint) over the repository root; Phases 1-3 each verify their own touched files with a targeted grep before commit. |
| A concurrent sibling (464, 478, 489) has edited a file this task also touches | M | L | Territory re-read before each edit. Declared sibling scopes are all under `agent-system/extensions/core/**`; no overlap with `extensions/formal/**`. Task 489 declares `__WHOLE_TREE__`, so Phase 4's deploy must not run concurrently with its implement dispatch. |
| `deploy-headless.sh` is read as having deployed `formal` when it has not | L | M | Phase 4 states explicitly that the deploy run is hygiene verification of the repository's currently active extensions and does not deploy `formal`; the plan does not treat a green deploy as evidence the new pattern file reached any `.claude/` tree. |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 1, 2, 3 |

Phases within the same wave can execute in parallel. Phases 2 and 3 touch disjoint file sets (the
four `agents/*.md` versus the four `skills/*/SKILL.md`) and both depend only on the pattern file
existing, so they are genuinely parallelisable.

---

### Phase 1: Author and Register the Shared Gate Pattern [COMPLETED]

**Goal**: One registered source of truth for the gate definition, the skip-log wording, and the
metadata field, so the eight contract surfaces can point at it instead of restating it.

**Tasks**:

- [x] Re-read `.claude-extensions.json` and confirm `formal` still has no entry and no top-level
      `source_dir`, so the edit target is `agent-system/extensions/formal/` (per
      `rules/source-store-deploy-boundary.md`). Record the resolution in the progress file.
      *(completed: re-confirmed via jq; extensions keys are approvals/core/email/lean/literature/memory/nix/nvim/sapience, no formal entry, no top-level source_dir)*
- [x] Create directory `agent-system/extensions/formal/context/patterns/`. *(completed)*
- [x] Write `agent-system/extensions/formal/context/patterns/mathlib-lookup-gate.md` containing:
  - **Condition (a), Lean-target signal** — true when EITHER the task's `file_scope` contains at
    least one `*.lean` path, OR the task's `task_type` names the `lean4` extension's routing
    value. State the `file_scope` branch FIRST and explicitly as the one that actually fires for
    `formal`-routed agents; include the concrete read, since the dispatch file does not carry the
    task's own `file_scope`:
    `jq --arg n "$TASK_NUMBER" '.active_projects[] | select(.project_number==($n|tonumber)) | .file_scope' specs/state.json`
    (field name `project_number`, not `task_number`).
  - **Condition (b), tool-registration signal** — true when one `ToolSearch` call for
    `select:lean_leansearch,lean_loogle,lean_leanfinder,lean_local_search` returns at least one
    match. Made ONCE, before attempting the step, not after a failure.
  - **Resolution table**: (a) false -> skip regardless of (b); (a) true and (b) false -> skip as an
    accepted degraded mode, never a `partial` status (mirroring the framing
    `lean-mcp-preflight-check.sh`'s `emit_dispatch_block()` already uses for Lean work without
    lean-lsp); both true -> the step is mandatory, unchanged.
  - **Skip-log wording**: exactly one line in the research report, in the same place and register
    as the existing "Note in report that Mathlib lookup was limited" convention — e.g.
    `Mathlib lookup skipped: no Lean target (no *.lean path in file_scope, task_type not lean4-routed)`
    or `Mathlib lookup skipped: lookup tools not registered in this session (ToolSearch: no match)`.
    State that this does NOT go through `issue-record.sh`, which stays reserved for genuine
    deviations and wins.
  - **Metadata contract**: a `mathlib_lookup_gated` field alongside the existing
    `mathlib_lookups_performed`, taking
    `"performed" | "skipped_no_lean_target" | "skipped_tools_unregistered"`; and
    `mathlib_lookups_performed` reads `0` when skipped rather than being omitted, preserving its
    existing integer type.
  - **Relationship to the tool-failure block**: the failure-handling path applies only once the
    gate has resolved to "perform"; it is not a second gate.
- [x] Verify the new file contains no task-number reference and no record-versioning phrasing:
      `grep -n -iE 'task [0-9]|tasks [0-9]|\(task |no longer|previously|formerly|supersed|used to|v1\b' <new file>`
      must return nothing. *(completed: zero hits)*
- [x] Append `"patterns"` to `.provides.context` in
      `agent-system/extensions/formal/manifest.json` (file-first ordering means the declared entry
      already exists on disk, so `check-extension-docs.sh:236-240` cannot fail on an intermediate
      state). *(completed)*
- [x] Add one entry to `agent-system/extensions/formal/index-entries.json` `.entries[]` matching
      the schema already in use there (`path`, `summary`, `line_count`, `load_when.agents`,
      `load_when.task_types`, `domain`, `subdomain`, optional `keywords`). `path` is
      `patterns/mathlib-lookup-gate.md`; `load_when.agents` lists all four research agents
      (`logic-research-agent`, `math-research-agent`, `physics-research-agent`,
      `formal-research-agent`); `load_when.task_types` lists `logic`, `math`, `physics`, `formal`.
      Set `line_count` to the file's actual `wc -l` output, measured after writing it.
      *(completed: domain="core"/subdomain="patterns" following the only existing precedent for a
      top-level `patterns/` tier -- core extension's own `patterns/*` entries -- since `domain`'s
      enum is closed to core/project/system and formal's `project` value is reserved for the
      logic/math/physics domain-knowledge tier, not this cross-cutting gate mechanism;
      line_count=82 matches actual `wc -l`)*

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: interface

**Tier Justification**: `suite_selection_select` resolves the two touched JSON paths to a
27-of-143-suite union (re-derived at plan-authoring time), discharged by
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-common-lib.sh,test-context-reachability.sh,test-deploy-orphans.sh,test-deploy-propagation.sh,test-deploy-verify-overlap.sh,test-double-loading-check.sh,test-gate3-parallel-equivalence.sh,test-gate3-strict-equivalence.sh,test-gate-cache-equivalence.sh,test-gate-lock.sh,test-index-entries-schema.sh,test-install-uninstall-extension.sh,test-lint-branch-gated-sections.sh,test-lint-task-lookup-adoption.sh,test-manifest-scripts-sync.sh,test-mcp-merge-target.sh,test-orchestrate-cycle-postflight.sh,test-routing-resolution.sh,test-run-all-failure-reporting.sh,test-run-all-parallel.sh,test-run-all-selection.sh,test-run-all-shared-fixture.sh,test-run-task-observers.sh,test-script-inventory.sh,test-skill-base-lifecycle.sh,test-validate-no-python-state-write.sh,test-verify-deploy-gate-selection.sh`
plus `bash agent-system/extensions/core/scripts/check-extension-docs.sh` for the
`provides.context` declaration, which together cover the registration surface that no cheaper
subset reaches.

**Scope Hypothesis**: This phase asserts (i) `context/patterns/` does not yet exist under the
formal extension, (ii) `provides.context` currently declares exactly `project/logic`,
`project/math`, `project/physics`, and (iii) the 27-suite union above is the current
`suite_selection_select` answer for `manifest.json` and `index-entries.json`. Confirm all three at
implementation time: `ls -d agent-system/extensions/formal/context/patterns`,
`jq -r '.provides.context[]' agent-system/extensions/formal/manifest.json`, and re-running
`suite_selection_select` on both JSON paths. If the union has changed, use the freshly derived list
and note the delta in the progress file rather than the list transcribed above.

**Files to modify**:

- `agent-system/extensions/formal/context/patterns/mathlib-lookup-gate.md` - new file; the single
  gate definition
- `agent-system/extensions/formal/manifest.json` - append `"patterns"` to `.provides.context`
- `agent-system/extensions/formal/index-entries.json` - add one `.entries[]` record for the new
  pattern file

**Verification**:

- `test -f agent-system/extensions/formal/context/patterns/mathlib-lookup-gate.md`
- The pattern file names BOTH sub-signals of condition (a):
  `grep -c 'file_scope' <file>` is non-zero AND `grep -c 'task_type' <file>` is non-zero
- The pattern file names all three `mathlib_lookup_gated` values
- `jq -e '.provides.context | index("patterns")' agent-system/extensions/formal/manifest.json`
  succeeds
- `jq -e '.entries[] | select(.path == "patterns/mathlib-lookup-gate.md")' agent-system/extensions/formal/index-entries.json`
  succeeds
- `jq empty` passes on both JSON files
- The declared `line_count` equals the file's actual `wc -l`
- The `--only` suite run named in the Tier Justification is green
- `check-extension-docs.sh` reports no `provides.context` failure for `formal`
- Task-reference and record-versioning greps return nothing on the new file

---

### Phase 2: Gate the Four Research-Agent Contracts [NOT STARTED]

**Goal**: Every Mathlib-lookup obligation site in the four `agents/*.md` contracts points at the
shared gate instead of mandating the step unconditionally, with domain-specific example queries
left inline.

**Tasks**:

- [ ] Re-read each file immediately before editing it (concurrent siblings are dispatched this
      same cycle; see the Territory block).
- [ ] `agents/logic-research-agent.md` — rewrite these surfaces (line numbers re-derived at
      plan-authoring time; re-derive again before editing):
  - L48-50: `### Mathlib Lookup MCP Tools` section intro gains the gate pointer sentence; the tool
    table (L52-57) and the `**Example queries**` block (L59-63) stay inline unchanged, since the
    queries are domain-specific.
  - L105-106: decision-tree item 3 becomes conditional on the gate.
  - L120: `**Search Priority**` item 2 becomes conditional.
  - L168: Stage-2 research-question bullet "What Mathlib theorems apply?" becomes conditional.
  - L178-182: `**Step 2: Mathlib Lookup (For Theorem Discovery)**` gains an explicit
    resolve-the-gate-first instruction pointing at the pattern file, and the skip-and-log outcome.
  - L197: Stage-4 synthesis bullet becomes conditional ("when the gate resolved to perform").
  - L219: report-template `**Sources/Inputs**` line marks the Mathlib entry conditional.
  - L237-238: report-template `### Mathlib Theorems` section states what it carries when the gate
    skipped (the one-line skip note).
  - L258: `## Appendix` bullet "Mathlib lookup results" becomes conditional.
  - L291: add `"mathlib_lookup_gated"` beside `"mathlib_lookups_performed": 3` in the Stage 6 JSON
    example.
  - L304: Stage 7 example-return bullet gains a gated-skip variant.
  - L344-346: `### MCP Tool Errors` block states it applies only once the gate resolved to
    "perform".
  - L372: MUST DO item 8 becomes "Resolve the Mathlib-lookup gate ... and use the lookup tools
    when it resolves to perform", pointing at the pattern file.
- [ ] `agents/math-research-agent.md` — same twelve surface classes at L48-50/52-57/59-63, L112-113,
      L124, L173, L183-187, L202, L224, L242-243, L263, L296, L309, L349-351, L371. Keep the
      lattice-theory example queries inline.
- [ ] `agents/physics-research-agent.md` — same classes at L62-64/66-71/73-77, L112-113, L124,
      L177-181, L197, L219, L237-238, L258, L289, L302, L344 (MUST DO item 6, **not** 8). This file
      has no Stage-2 research-question bullet. **Leave L36 ("Mathlib4 integration patterns")
      untouched** — unrelated domain-knowledge guidance.
- [ ] `agents/formal-research-agent.md` — thinner footprint: L60-67 (table, no examples), L135
      (bare Stage 3 bullet "Use Mathlib lookup tools"), L159 (`**Sources/Inputs**`), L226
      (`mathlib_lookups_performed`), L241 (example-return bullet), L280 (MUST DO item 5). No
      decision tree, no `Step 2` header, no `### Mathlib Theorems` section of its own.
- [ ] After each file, grep it for task-number references and record-versioning phrasing and
      confirm zero hits.
- [ ] Commit each file as its own green sub-step.

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: prose

**Tier Justification**: `suite_selection_select` returns `__FULL_SWEEP__` for these agent-contract
markdown paths (verified at plan-authoring time), so no suite covers them; per `plan-format.md`'s
`__FULL_SWEEP__` sub-case (b) the honest covering check is
`bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
(repository root as `TARGET`, since it holds both a deployed `.claude/` tree and the
`agent-system/extensions` source store) together with the `prose` row's diff read-through.

**Scope Hypothesis**: This phase asserts twelve surface classes in `logic` and `math`, eleven in
`physics` (no Stage-2 research-question bullet), and six in `formal`, at the line numbers listed
above. Confirm at implementation time with
`grep -n -i 'mathlib\|lean_leansearch\|lean_loogle\|lean_leanfinder\|lean_local_search' <file>`
per file and reconcile against the list; if a surface is missing or an extra one appears, edit what
is actually there and record the delta in the progress file rather than forcing the asserted count.

**Files to modify**:

- `agent-system/extensions/formal/agents/logic-research-agent.md` - gate all twelve obligation
  sites; keep modal-logic example queries inline
- `agent-system/extensions/formal/agents/math-research-agent.md` - same; keep lattice example
  queries inline
- `agent-system/extensions/formal/agents/physics-research-agent.md` - same minus the Stage-2
  question bullet; L36 untouched
- `agent-system/extensions/formal/agents/formal-research-agent.md` - gate the six sites present

**Verification**:

- Diff read-through confirming every changed hunk lies in prose/markdown with no executable
  surface
- Each of the four files contains at least one reference to `patterns/mathlib-lookup-gate.md`:
  `grep -l 'mathlib-lookup-gate' agent-system/extensions/formal/agents/*.md | wc -l` equals 4
- Each of the four files' Stage 6 JSON example contains `mathlib_lookup_gated`
- `grep -n 'Mathlib4 integration patterns' agent-system/extensions/formal/agents/physics-research-agent.md`
  still returns L36 unchanged
- No file retains an ungated imperative: `grep -n '^8\. Use Mathlib lookup tools for theorem discovery$'`
  and the physics/formal equivalents return nothing
- `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
  is green, with neither gate reporting SKIP (a SKIP here means nothing was checked)
- Task-reference and record-versioning greps return nothing on all four files

---

### Phase 3: Gate the Four Skill Wrappers [NOT STARTED]

**Goal**: The six restatement sites across the four `SKILL.md` wrappers carry the same gate
pointer, so a reader of the skill layer is not told the step is unconditional.

**Tasks**:

- [ ] Re-read each file immediately before editing.
- [ ] `skills/skill-logic-research/SKILL.md` — L110 (narrative "Use Mathlib lookup tools
      (lean_leansearch, lean_loogle, lean_leanfinder, lean_local_search)" inside the Required Tool
      Invocation section) becomes conditional with the gate pointer; L172 (example-return bullet
      "Used Mathlib lookup tools to discover relevant theorems") gains a gated-skip variant.
- [ ] `skills/skill-math-research/SKILL.md` — L92 and L154, same treatment.
- [ ] `skills/skill-physics-research/SKILL.md` — L92 only (single narrative mention).
- [ ] `skills/skill-formal-research/SKILL.md` — L93 only (single narrative mention).
- [ ] Grep each file for task-number references and record-versioning phrasing; confirm zero hits.
- [ ] Commit each file as its own green sub-step.

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: prose

**Tier Justification**: `suite_selection_select` returns `__FULL_SWEEP__` for these `SKILL.md`
paths, so per `plan-format.md`'s sub-case (b) the covering check is
`bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
alongside the `prose` row's diff read-through; the edits are narrative-prose-only with no
executable surface.

**Scope Hypothesis**: This phase asserts six mention sites across the four wrappers — two each in
`skill-logic-research` (L110, L172) and `skill-math-research` (L92, L154), one each in
`skill-physics-research` (L92) and `skill-formal-research` (L93). Confirm with
`grep -n -i 'mathlib\|lean_leansearch' agent-system/extensions/formal/skills/*/SKILL.md` and edit
what is actually present.

**Files to modify**:

- `agent-system/extensions/formal/skills/skill-logic-research/SKILL.md` - gate L110 and L172
- `agent-system/extensions/formal/skills/skill-math-research/SKILL.md` - gate L92 and L154
- `agent-system/extensions/formal/skills/skill-physics-research/SKILL.md` - gate L92
- `agent-system/extensions/formal/skills/skill-formal-research/SKILL.md` - gate L93

**Verification**:

- Diff read-through confirming every changed hunk is prose
- `grep -l 'mathlib-lookup-gate' agent-system/extensions/formal/skills/*/SKILL.md | wc -l` equals 4
- No wrapper retains a bare unconditional `- Use Mathlib lookup tools` line:
  `grep -n '^- Use Mathlib lookup tools$' agent-system/extensions/formal/skills/*/SKILL.md`
  returns nothing
- `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
  is green with neither gate SKIPping
- Task-reference and record-versioning greps return nothing on all four files

---

### Phase 4: Redeploy and Full Gate Verification [NOT STARTED]

**Goal**: The repository is lint-clean and the deploy pipeline is green with all eleven files in
place, and the gate is demonstrably consistent across all eight contract surfaces.

**Tasks**:

- [ ] Confirm no sibling `implement` dispatch is mid-flight. Task 489 declares `__WHOLE_TREE__` in
      its `file_scope`, so its implement dispatch and this phase's deploy must not run
      concurrently. If 489 is live, wait (bounded, per
      `context/patterns/bounded-build-waiter.md`) rather than regenerating the tree under it.
- [ ] Cross-surface consistency check: all eight contract files reference
      `patterns/mathlib-lookup-gate.md`, and none retains an ungated imperative form. This is the
      phase that actually discharges the task's "not one gated and three ungated copies" concern.
- [ ] Run `bash agent-system/extensions/core/scripts/deploy-headless.sh` and confirm
      `RESULT=landed_verify_clean`. Run it in the FOREGROUND with a bounded timeout, redirecting
      output to a file and grepping that file for the `RESULT=` line.
- [ ] Run the complete gate set: `bash .claude/scripts/verify-deploy.sh` (all gates, no
      `--only-gate`, no `--skip-slow`).
- [ ] Record in the summary that the deploy run is **hygiene verification of the repository's
      currently active extensions** and does **not** deploy `formal` into `.claude/` here — there is
      no `.claude-extensions.json` entry for it. A green deploy is therefore not evidence that the
      new pattern file reached any deployed tree.

**Timing**: 0.75 hours

**Depends on**: 1, 2, 3

**Verification Tier**: full

**Files to modify**:

- `__WHOLE_TREE__` - this phase invokes whole-tree regeneration via `deploy-headless.sh`

**Verification**:

- `deploy-headless.sh` output contains `RESULT=landed_verify_clean`
- `bash .claude/scripts/verify-deploy.sh` — the complete gate set it aggregates, run with no gate
  selection and no `--skip-slow` — exits 0 with every gate either PASS or a documented,
  pre-existing SKIP
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` is green (full Gate 8 battery, not
  an `--only` subset)
- `bash agent-system/extensions/core/scripts/check-extension-docs.sh` is green, in particular the
  `provides.context`-on-disk check and Rule L
- `grep -l 'mathlib-lookup-gate' agent-system/extensions/formal/agents/*.md agent-system/extensions/formal/skills/*/SKILL.md | wc -l`
  equals 8
- `bash .claude/scripts/check-task-references.sh` reports no violation under `agent-system/**`

---

## Testing & Validation

- [ ] The new pattern file exists, is registered in `manifest.json` `provides.context`, and is
      indexed in `index-entries.json` with an accurate `line_count`
- [ ] Condition (a) in the pattern file names the `file_scope`-contains-`*.lean` sub-signal FIRST
      and does not reduce to a bare `task_type == "lean4"` check
- [ ] Condition (b) is a single pre-step `ToolSearch` call, not a post-failure recovery
- [ ] A skip is framed as an accepted degraded mode, never a `partial` status
- [ ] All eight contract surfaces point at the shared pattern file (8/8, not 1/8)
- [ ] All four agent contracts' Stage 6 JSON examples carry `mathlib_lookup_gated`
- [ ] `physics-research-agent.md:36` is unchanged
- [ ] No file under `agent-system/**` gained a task-number reference or record-versioning phrasing
- [ ] `deploy-headless.sh` reaches `RESULT=landed_verify_clean`
- [ ] The complete `verify-deploy.sh` gate set is green

## Artifacts & Outputs

- `agent-system/extensions/formal/context/patterns/mathlib-lookup-gate.md` (new)
- Eleven modified/created files in the `formal` extension source store (new pattern file,
  `manifest.json`, `index-entries.json`, four `agents/*.md`, four `skills/*/SKILL.md`)
- `specs/408_gate_mathlib_lookup_on_lean_target/summaries/01_gate-mathlib-lookup-on-lean-target-summary.md`
- Per-phase commits following `task {N}: ...` / `task {N} phase {P}: ...` conventions

## Rollback/Contingency

All changes are confined to markdown and two small JSON files in the source store; no runtime code
and no deployed tree is modified by Phases 1-3. Each phase commits per green sub-step, so reverting
is a per-file `git revert` of the relevant commit — no snapshot-then-rollback is needed for ordinary
recovery.

If Phase 1's registration turns out to be rejected (for example, a future lint requires a
per-file `provides.context` entry rather than the directory-name `patterns` entry that `core`
already uses), the contingency is to place the gate file under an existing declared tier and point
the four contracts there instead; the gate content itself is unaffected. Record the reason in the
progress file.

If Phase 4's deploy cannot reach `RESULT=landed_verify_clean` for a reason outside this task's
eleven files — a concurrent sibling's in-flight edit being the most likely cause, per the Territory
block's guidance — do not fix forward into another task's territory. Stop, report the foreign
change after confirming via `git log` that it is not this task's own work, and mark the phase
`[PARTIAL]` with the blocking observation recorded.
