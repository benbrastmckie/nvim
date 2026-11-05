# Implementation Plan: Task #482

- **Task**: 482 - Create sapience extension
- **Status**: [IMPLEMENTING]
- **Effort**: 4.25 hours
- **Dependencies**: None
- **Research Inputs**: specs/482_create_sapience_extension/reports/01_create-sapience-extension.md
- **Artifacts**: plans/01_create-sapience-extension.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Create a new `sapience` extension in the source store at `agent-system/extensions/sapience/`,
modeled on `agent-system/extensions/memory/` for directory layout and merge-target shape but on
`agent-system/extensions/approvals/` and `agent-system/extensions/literature/` for its top-level
manifest fields (no `task_type`, no `routing_agents`, `routing_exempt: true`). The extension
carries three payloads: MCP write-tool permission grants in `settings-fragment.json` (gap 1, the
blocker), a postflight `sapience_wrapup` instruction in `EXTENSION.md` (gap 2), and
`context/project/sapience/` domain notes recording the vault model, the review-gate boundary, the
transcript-filter ceiling, and why no per-dispatch context injection exists (gap 3, resolved as
documentation rather than code). Done when the extension is activated, the deployed tree is
regenerated, and the full gate set passes with the four write-tool grants present in
`.claude/settings.local.json`.

### Research Integration

The research report drove four plan-shaping conclusions, three of which are adopted verbatim and
one of which overrides a dispatch-named deliverable:

1. **Model the manifest on `approvals`/`literature`, not `memory`**, for top-level fields.
   `memory/manifest.json` declares `task_type: "memory"` and a full `routing_agents` block, both
   forbidden by the dispatch's non-goal (a). `memory/` remains the model for merge-target shape
   and directory layout only.
2. **`settings-fragment.json` carries `permissions.allow` only**, modeled on
   `nix/settings-fragment.json`'s shape. Never `memory/settings-fragment.json`'s shape, which
   declares an `mcpServers` block that registers nothing (the open sibling task's finding) and is
   stale precedent.
3. **Gap 2 is documentation-only.** `EXTENSION.md` merges into `.claude/CLAUDE.md`, which is
   demonstrably injected into every agent dispatch (this plan's own dispatch prompt contains both
   CLAUDE.md files verbatim). No script and no hook is needed to deliver the wrapup instruction.
4. **Gap 3's prescribed mechanism cannot work, so `scripts/sapience-context.sh` is dropped.**
   The dispatch names it as a deliverable; the research refuted it; this plan re-verified the
   refutation directly at plan-authoring time rather than carrying it on trust.
   `skill_get_extension_dir()` in `agent-system/extensions/core/scripts/skill-base.sh` gates on
   `[ -n "$ext_task_type" ] && [ "$ext_task_type" = "$task_type" ]` and returns the FIRST match,
   so an extension declaring no `task_type` is skipped unconditionally, for every task of every
   type. A `hooks.context_injection` entry on a `task_type`-less sapience manifest is structurally
   unreachable, not merely narrow. See Goals & Non-Goals and Risks below.

Two figures carried from the research were re-derived live during plan authoring rather than
repeated on trust, and both held: the dotfiles allow-list contains exactly 7 `mcp__sapience__*`
entries (6 real read tools plus the tool-matching-nothing `mcp__sapience__sapience`), and
`.claude/settings.local.json` contains 0 sapience entries today. The 12-tool MCP surface was
confirmed against this session's own live sapience tool registration, which exposes
`sapience_adddoc`, `_ask`, `_briefing`, `_connect`, `_context`, `_handoff`, `_join`,
`_outstanding`, `_papers`, `_remember`, `_search`, `_wrapup`.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context; ROADMAP.md was not consulted and is not
modified by this plan.

## Goals & Non-Goals

**Goals**:

- Close gap 1: grant the four sapience MCP write tools (`sapience_remember`, `sapience_wrapup`,
  `sapience_handoff`, `sapience_adddoc`) through the extension's own `settings-fragment.json`, so
  an autonomous dispatch inside this repository can save a finding without hitting a permission
  prompt.
- Close gap 2: carry a postflight wrapup instruction (3-8 distilled notes per completed task,
  written from the summary artifact at the `[IMPLEMENTING]` -> `[COMPLETED]` transition) in
  `EXTENSION.md`, where it reaches every agent through the merged `.claude/CLAUDE.md`.
- Document gap 3 and its deliberate resolution in `context/project/sapience/`, with the code
  citation that makes the refutation checkable rather than asserted.
- Ship a schema-conformant, lint-clean extension: `EXTENSION.md` within the 60-line Rule U limit,
  `index-entries.json` conformant to `context/index.schema.json` with accurate `line_count`
  values, every context file reachable from the index.
- Activate the extension and regenerate the deployed tree, leaving the full gate set green.

**Non-Goals**:

- **No `scripts/sapience-context.sh` and no manifest `hooks` object.** This deliberately drops a
  deliverable the dispatch named, on the mechanical grounds re-verified in Research Integration
  item 4 above. Shipping the hook would ship dead code: it can never fire for any task of any
  type while the manifest declares no `task_type`, and declaring a `task_type` is itself forbidden
  by the dispatch's non-goal (a). The rationale is recorded in the domain notes (Phase 3) rather
  than silently omitted.
- **No second per-dispatch retrieval injection.** The dispatch's explicit anti-goal. The one
  existing cross-cutting precedent (`<memory-context>`) is a hardcoded call to
  `memory-retrieve.sh` inside core's own `orchestrate-build-dispatch.sh`, not an extension-
  declarable seam; replicating it for sapience would mean editing a shared core script AND adding
  a network round-trip to every dispatch in every batch. The two systems stay split by altitude:
  sapience for session-level orientation and cross-project recall, the memory extension for
  per-dispatch injection.
- **No `task_type` and no `routing_agents`** in the manifest. Sapience is not a domain one
  implements in.
- **No `/sapience` slash command.** Review, sync, coverage, pending and stats are terminal verbs
  already covered by the GNOME desktop launchers the nix module installs.
- **No re-registration** of the MCP server (`~/.claude.json`, written by the nix module's
  activation) or of the three existing hooks in `~/.dotfiles/config/claude/settings.json`
  (SessionStart/SessionEnd/Stop). Those keys are reset from the dotfiles repo by
  `home.activation.claudeSettings` on every home-manager switch; the extension must not attempt
  to write them.
- **No `mcpServers` key anywhere** in `settings-fragment.json`.
- **No edit to `~/.dotfiles`.** Making gap 1's fix machine-wide would require adding the same four
  entries to `~/.dotfiles/config/claude/settings.json`, a different repository and out of scope.
  The repository-scoped limitation is documented, not silently accepted.
- **No `sapience_connect` / `sapience_join` grants.** Both are ungranted today, but no
  connect/sharing workflow is part of this task.
- **No proactive mid-run `sapience_remember` instruction for every agent.** MCP write tools bypass
  the `sapience review` gate that `config.json`'s `auto_approve: false` exists to preserve; a
  per-agent instruction would flood the hosted vault with unreviewed content across an
  `/orchestrate` batch.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A future reader or task assumes gap 1 is closed machine-wide, and is surprised by a permission prompt in another project on this machine | M | H | State the repository-scoped tradeoff explicitly in the domain notes, naming `~/.dotfiles/config/claude/settings.json` as the file that would need the same four entries, as a deliberately out-of-scope follow-up |
| A future edit re-attempts the gap-3 hook because the dispatch's own prose made it sound achievable ("the mechanism already exercised by the nix and nvim extensions") | M | H | Record the specific, checkable code citation (`skill_get_extension_dir`'s `[ -n "$ext_task_type" ] && [ "$ext_task_type" = "$task_type" ]` first-match gate in `skill-base.sh`) in the domain notes, plus why `nvim`/`nix` succeed where sapience cannot |
| Explicit per-tool grants (not a `mcp__sapience__*` wildcard) mean a future new sapience write tool is not auto-granted | L | M | Consistency with the existing 7-entry dotfiles list, which is also explicit; note it in the domain notes so a future tool addition is a known maintenance item rather than a surprise |
| The extension's shape (claudemd + settings + context merge targets, zero skills/commands/agents/scripts) is not exercised by any existing extension, so a deploy-pipeline edge case is possible | H | L | Phase 5 verifies each merge target independently in the deployed tree (grep `.claude/CLAUDE.md` for the section, jq `.claude/settings.local.json` for the four entries, jq `.claude/context/index.json` for the five paths) rather than trusting a single aggregate exit code |
| `generate-context-line-counts.sh --write` operates over EVERY extension's source `index-entries.json`, so a pre-existing stale count elsewhere would be rewritten and could be over-staged into this task's commit | M | M | Run `--check` first to census pre-existing staleness; stage only `agent-system/extensions/sapience/index-entries.json` with an explicit file-list `git add --`, never a directory or glob pathspec |
| A new extension is not in `.claude-extensions.json`, so `deploy-headless.sh`'s default mode (resync of already-active extensions only) would deploy nothing and appear to succeed | H | M | Phase 5 activates sapience explicitly before redeploying, and asserts the deployed artifacts exist rather than reading only the deploy exit code |
| Activation requires an `nvim --headless` manager call or the interactive picker, either of which may be unavailable to a headless dispatch | M | M | Phase 5's fallback: leave the source files complete (they are inert until loaded), mark the phase `[BLOCKED]`, and report that the user must load sapience from the extension picker; no partial deploy state is left behind |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |
| 4 | 5 | 4 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Scaffold, Manifest, and Permission Grants [COMPLETED]

**Goal**: Create the extension directory and its two JSON files, closing gap 1's payload. This is
the blocker phase: gaps 2 and 3 are unreachable until the extension exists as a loadable unit.

**Tasks**:

- [x] Create `agent-system/extensions/sapience/` and `agent-system/extensions/sapience/context/project/sapience/domain/`. *(completed)*
- [x] Write `manifest.json`: `name: "sapience"`, `version: "1.0.0"`, a one-line `description` (shown
      in the picker UI), `dependencies: ["core"]`, `routing_exempt: true`, and a `provides` object
      with `agents`, `commands`, `skills`, `rules`, `scripts`, `hooks`, `data` all `[]` and
      `context: ["project/sapience"]`. Add `merge_targets` for `claudemd` (source `EXTENSION.md`,
      target `.claude/CLAUDE.md`, `section_id: extension_sapience`), `index` (source
      `index-entries.json`, target `.claude/context/index.json`), and `settings` (source
      `settings-fragment.json`, target `.claude/settings.local.json`) — copy the three-target shape
      from `agent-system/extensions/memory/manifest.json` verbatim, changing only the `section_id`.
      *(completed)*
- [x] Assert the manifest declares NO `task_type`, NO `routing_agents`, and NO top-level `hooks`
      object (`provides.hooks: []` is the file-copy array and is a different key — it stays, empty).
      *(completed: verified via jq -e)*
- [x] Write `settings-fragment.json` with `permissions.allow` listing exactly the four write tools:
      `mcp__sapience__sapience_remember`, `mcp__sapience__sapience_wrapup`,
      `mcp__sapience__sapience_handoff`, `mcp__sapience__sapience_adddoc`. Model the file's shape on
      `agent-system/extensions/nix/settings-fragment.json`. No other key. *(completed)*

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts that exactly four write tools are missing a grant, and
that the existing dotfiles allow-list holds 7 `mcp__sapience__*` entries. Both figures are
carried from `reports/01_create-sapience-extension.md` and were re-derived at plan-authoring time
(`jq -r '[.permissions.allow[]? | select(test("sapience"))] | .[]' ~/.dotfiles/config/claude/settings.json`
returned the 7; the same query against `.claude/settings.local.json` returned 0). Confirm at
implementation time by re-running both queries plus the live tool census, and reconcile before
writing the fragment if either has changed.

**Tier Justification**: The covering check is `jq empty` on both new JSON files plus
`jq -e '(has("task_type")|not) and (has("routing_agents")|not) and (has("hooks")|not)' manifest.json`
and `jq -e '(has("mcpServers")|not) and (.permissions.allow|length==4)' settings-fragment.json` —
these are two new files in an extension no deployed tree yet reads, so nothing beyond them can
break, and deployed-tree effects are phase 5's concern.

**Files to modify**:

- `agent-system/extensions/sapience/manifest.json` - new; extension declaration, no routing, three merge targets
- `agent-system/extensions/sapience/settings-fragment.json` - new; `permissions.allow` with the four MCP write tools, nothing else

**Verification**:

- `jq empty agent-system/extensions/sapience/manifest.json` and
  `jq empty agent-system/extensions/sapience/settings-fragment.json` both exit 0.
- `jq -e '(has("task_type")|not) and (has("routing_agents")|not) and (has("hooks")|not)' agent-system/extensions/sapience/manifest.json`
  exits 0.
- `jq -e 'has("mcpServers")|not' agent-system/extensions/sapience/settings-fragment.json` exits 0.
- `jq -r '.permissions.allow | sort | join(",")' agent-system/extensions/sapience/settings-fragment.json`
  prints exactly the four expected tool names and no fifth.
- `jq -r '.merge_targets | keys | sort | join(",")' agent-system/extensions/sapience/manifest.json`
  prints `claudemd,index,settings`.

---

### Phase 2: EXTENSION.md and README.md [COMPLETED]

**Goal**: Write the two required extension docs. `EXTENSION.md` is the gap-2 payload: it merges
into `.claude/CLAUDE.md` and therefore reaches every agent dispatch.

**Tasks**:

- [x] Write `EXTENSION.md`, opening with `## Sapience Extension` (match `memory/EXTENSION.md`'s
      heading level, since the merge inserts it as a CLAUDE.md section). Content, in order:
      one line on what sapience is, pointing at `~/.dotfiles/docs/sapience.md` for the machine
      configuration rather than duplicating it; a short "Already ambient — do not rebuild" note
      naming the MCP server registration and the three SessionStart/SessionEnd/Stop hooks; the
      gap-2 wrapup instruction; a one-line statement that this extension provides no task type, no
      routing, and no slash command; and a read-on-demand Context Pointers list of the five
      `context/project/sapience/` paths as plain backticked paths (never `@`-imports). *(completed)*
- [x] Phrase the gap-2 instruction precisely: at the `[IMPLEMENTING]` -> `[COMPLETED]` transition,
      call `sapience_wrapup` with 3-8 distilled notes drawn from the summary artifact just written;
      do NOT call `sapience_remember` proactively mid-run, because MCP write tools bypass the
      `sapience review` gate and a per-dispatch save would flood the vault across an
      `/orchestrate` batch. *(completed)*
- [x] Keep `EXTENSION.md` at 60 lines or fewer (`check-extension-docs.sh` Rule U, per
      `extension-slim-standard.md`). Target roughly 35-45 lines, matching `memory/EXTENSION.md`'s
      38, to leave headroom. *(completed: 44 lines)*
- [x] Write `README.md`: purpose, file inventory, the three gaps this extension closes and how, the
      repository-scoped limitation of the permission fix, and an explicit note that gap 3 is closed
      by documentation rather than a hook (with a pointer to the domain note carrying the code
      citation). `README.md` is not merged into CLAUDE.md and has no line limit. *(completed)*

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: prose

**Scope Hypothesis**: This phase asserts a two-file set and a 35-45 line target for
`EXTENSION.md` against Rule U's 60-line ceiling. The ceiling is a verified external constraint
(`extension-slim-standard.md`'s Size Limit section); the target is calibrated against
`agent-system/extensions/memory/EXTENSION.md`, re-measured at plan-authoring time as 38 lines.
Confirm at implementation time with `wc -l` on the written file, and treat 60 as the hard bound
rather than the target as a quota to fill.

**Tier Justification**: Both files are new source-store markdown with no executable surface, so
`suite_selection_select` returns `__FULL_SWEEP__` and no test suite covers them; the honest
covering checks are `wc -l agent-system/extensions/sapience/EXTENSION.md` against Rule U's 60-line
limit plus a diff read-through confirming every line is prose, with the deployed-tree doc-lint
deferred to phase 5 because `check-extension-docs.sh` iterates `.claude/extensions/*/` and cannot
see an extension that is not yet loaded.

**Files to modify**:

- `agent-system/extensions/sapience/EXTENSION.md` - new; merged CLAUDE.md section, carries the gap-2 wrapup instruction
- `agent-system/extensions/sapience/README.md` - new; extension purpose, file inventory, gap inventory

**Verification**:

- `wc -l < agent-system/extensions/sapience/EXTENSION.md` is 60 or less.
- `EXTENSION.md` contains `sapience_wrapup`, the string `[IMPLEMENTING]`, and the five
  `context/project/sapience/` pointer paths.
- `EXTENSION.md` contains no `@`-prefixed import line (`grep -c '^@' EXTENSION.md` is 0) and no
  `/sapience` command claim.
- Diff read-through: every changed hunk in both files is prose or a markdown table; neither file
  introduces a code block that would be executed.
- `README.md` mentions `~/.dotfiles/config/claude/settings.json` as the machine-wide follow-up and
  states that gap 3 is documentation-only.

---

### Phase 3: Domain Notes [COMPLETED]

**Goal**: Write `context/project/sapience/` — the README index plus four domain notes covering the
vault model, the review-gate boundary, the transcript-filter ceiling, and the deliberate absence of
per-dispatch injection (gap 3's documented resolution).

**Tasks**:

- [x] `context/project/sapience/README.md`: context index and navigation, plus a loading-strategy
      table stating that all of these files are read-on-demand reference material with no eager
      load hook. *(completed)*
- [x] `context/project/sapience/domain/vault-model.md`: hosted vault at app.spnc.ai, the MCP server
      as a thin client, the local `sf1`/`sapience` CLI, and the exact CLI mode inventory of
      `~/.sapience/mcp.py` (`--briefing-text`, `--statusline`, `--stats`, `--status`, `--receipt`,
      `--effect-line`, `--adddoc`, `--adddir`, `--refresh-cache`) with the explicit note that there
      is NO `--search` and NO `--ask` mode, so any shell-side query is a network round-trip through
      `sf1 "question"` or `/v1/ask`. *(completed)*
- [x] `context/project/sapience/domain/review-gate-boundary.md`: `config.json`'s
      `auto_approve: false` gates the transcript-extraction path (`sapience sync`/`coverage`/
      `pending`/`review`, i.e. `~/.sapience/upload.py`) by staging locally; the MCP write tools
      (`sapience_remember`, `_wrapup`, `_handoff`, `_adddoc`) write straight to the hosted vault
      with no staging and no review. State why this makes the postflight-only, 3-8-notes-per-task
      scoping load-bearing: it bounds unreviewed content per task rather than per tool call. Also
      record the repository-scoped limitation of the permission grant and name
      `~/.dotfiles/config/claude/settings.json` as the out-of-scope machine-wide follow-up, plus the
      explicit-vs-wildcard grant tradeoff. *(completed)*
- [x] `context/project/sapience/domain/transcript-filter-ceiling.md`: `source_skip()` in
      `~/.sapience/upload.py` classifies a transcript as `subagent` (by path or `agent-` filename
      prefix) or `harness-started` (from its opening human turns); both classifications are final
      and cached, and `harness-started` is explicitly not overridable by
      `SAPIENCE_INCLUDE_HEADLESS=1`. Conclude that orchestrated work cannot reach the vault by
      extraction at all, which is why an explicit tool call is the only path in. *(completed)*
- [x] `context/project/sapience/domain/subagent-orientation.md`: gap 3's documented resolution.
      State that subagents receive no briefing because SessionStart fires for the root session
      only; that no per-dispatch injection hook exists for sapience by design; and the checkable
      refutation — `skill_get_extension_dir()` in
      `agent-system/extensions/core/scripts/skill-base.sh` gates on
      `[ -n "$ext_task_type" ] && [ "$ext_task_type" = "$task_type" ]` and returns the first match,
      so a `task_type`-less extension's lifecycle hook is unreachable for every task of every type.
      Explain why `nvim`/`nix` succeed (each declares a matching `task_type` and fires only on its
      own domain's tasks) and why post-task observers are also the wrong shape (they fire only
      after a task reaches a resting state, so they cannot deliver pre-work orientation). Name the
      deliberate alternative: session-level briefing plus an explicitly invoked `sf1 "question"`
      escape hatch, and the anti-goal against a second always-on injection path. *(completed)*
- [x] Across all five files: no task-number references (these are deliverables outside `specs/**`
      — cite durable anchors such as filenames and function names instead), and no record-
      versioning language.

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: prose

**Scope Hypothesis**: This phase asserts a five-file set (one README plus four domain notes) and a
`1013 / 203` transcript census carried from `reports/01_create-sapience-extension.md`, itself
measured from `~/.sapience/upload.py`'s own run output. Confirm the file count by
`find agent-system/extensions/sapience/context -name '*.md' | wc -l` returning 5 before phase 4
harvests the index entries; for the census, either re-derive it on this machine or write it in the
domain note attributed as a measured figure with its source named, never as a bare current fact.

**Tier Justification**: All five files are new source-store markdown with no executable surface
(`suite_selection_select` returns `__FULL_SWEEP__`), so the honest covering checks are the diff
read-through the `prose` row prescribes plus `bash .claude/scripts/check-task-references.sh` over
the new paths for the no-task-references rule; index reachability is phase 4's obligation and the
deployed-tree doc-lint is phase 5's.

**Files to modify**:

- `agent-system/extensions/sapience/context/project/sapience/README.md` - new; context index, navigation, on-demand loading strategy
- `agent-system/extensions/sapience/context/project/sapience/domain/vault-model.md` - new; hosted vault, MCP thin client, CLI mode inventory
- `agent-system/extensions/sapience/context/project/sapience/domain/review-gate-boundary.md` - new; staged-and-reviewed vs. direct-and-unreviewed, grant scope tradeoffs
- `agent-system/extensions/sapience/context/project/sapience/domain/transcript-filter-ceiling.md` - new; `source_skip()` mechanics and the extraction ceiling
- `agent-system/extensions/sapience/context/project/sapience/domain/subagent-orientation.md` - new; gap 3's refutation, code citation, and deliberate alternative

**Verification**:

- `find agent-system/extensions/sapience/context -name '*.md' | wc -l` returns 5.
- `subagent-orientation.md` contains the literal string `skill_get_extension_dir` and names
  `skill-base.sh`, so the refutation is checkable rather than asserted.
- `review-gate-boundary.md` names all four MCP write tools and the string `auto_approve`.
- `transcript-filter-ceiling.md` contains `source_skip` and `SAPIENCE_INCLUDE_HEADLESS`.
- `bash .claude/scripts/check-task-references.sh` exits 0 (these files are outside `specs/**`).
- Diff read-through: every changed hunk is prose or a markdown table.

---

### Phase 4: Index Entries [NOT STARTED]

**Goal**: Write `index-entries.json` so all five context files are reachable from
`.claude/context/index.json`, schema-conformant, with accurate `line_count` values and the
`on_demand` intent marker that keeps them out of the dead-entry report.

**Tasks**:

- [ ] Write `agent-system/extensions/sapience/index-entries.json` with one entry per context file,
      modeled on `agent-system/extensions/memory/index-entries.json`'s shape. Each entry carries the
      four schema-required keys (`path`, `domain`, `summary`, `line_count`) plus `subdomain`,
      `topics`, and `keywords`. `path` is relative to the extension's `context/` directory (e.g.
      `project/sapience/domain/vault-model.md`); `domain` is `project`; `subdomain` is `sapience`.
- [ ] Set `load_when` to an empty object and set `on_demand: true` on every entry. This is the
      schema's documented use of the marker: these entries are deliberately reachable only by
      grep/explicit Read, and an all-hooks-empty entry WITHOUT the marker is reported as dead by
      `validate-context-budgets.sh`'s Dead Entry Check. Leave `load_when.agents` empty — an entry
      listed in `agents[]` is auto-loaded at agent spawn regardless of any tier label, which would
      silently make this reference material eager.
- [ ] Assert no forbidden key appears in any entry: `description`, `tags`, and `tier` are absent
      from the entry shape by design and `additionalProperties` is `false`.
- [ ] Run `bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --check` to
      census `line_count` accuracy. If any sapience entry is wrong, run the same script with
      `--write` and then stage ONLY `agent-system/extensions/sapience/index-entries.json` with an
      explicit file-list `git add --` — the script rewrites every extension's source
      `index-entries.json`, so a pre-existing stale count elsewhere must not be swept into this
      task's commit.
- [ ] Re-run `--check` and confirm it reports no correction needed for any sapience entry.

**Timing**: 0.5 hours

**Depends on**: 2, 3

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts exactly five index entries whose `line_count` values match
`wc -l` of the five files phase 3 wrote — a count that depends on phase 3's actual output, not on
this plan's estimate. Confirm by comparing
`jq -r '.entries | length' agent-system/extensions/sapience/index-entries.json` against
`find agent-system/extensions/sapience/context -name '*.md' | wc -l`, and by
`generate-context-line-counts.sh --check` reporting zero corrections needed.

**Tier Justification**: The covering checks are
`bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --check` for
`line_count` accuracy and `bash agent-system/extensions/core/scripts/check-extension-docs.sh` for
schema conformance — both of which read SOURCE `index-entries.json` files including unloaded
extensions, so they genuinely cover this one new file before any deploy, while the deployed-index
reachability check remains phase 5's.

**Files to modify**:

- `agent-system/extensions/sapience/index-entries.json` - new; five on-demand entries, one per context file

**Verification**:

- `jq empty agent-system/extensions/sapience/index-entries.json` exits 0.
- `jq -r '.entries | length' agent-system/extensions/sapience/index-entries.json` equals
  `find agent-system/extensions/sapience/context -name '*.md' | wc -l`.
- `jq -e '[.entries[] | (has("path") and has("domain") and has("summary") and has("line_count"))] | all' index-entries.json`
  exits 0.
- `jq -e '[.entries[] | (has("description") or has("tags") or has("tier"))] | any | not' index-entries.json`
  exits 0.
- `jq -e '[.entries[] | .on_demand == true and (.domain == "project")] | all' index-entries.json`
  exits 0, and `jq -e '[.entries[] | (.load_when.agents // []) | length == 0] | all' index-entries.json`
  exits 0.
- Each entry's `path` resolves: for every `p` in `.entries[].path`,
  `agent-system/extensions/sapience/context/$p` exists.
- `bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --check` reports no
  correction needed for any sapience entry (exit status checked, not just stdout inspected).
- `git status --short` shows only `agent-system/extensions/sapience/` paths as this phase's
  intended changes; any other extension's `index-entries.json` touched by a `--write` run is
  reviewed and deliberately excluded from staging.

---

### Phase 5: Activate, Redeploy, and Verify [NOT STARTED]

**Goal**: Activate the extension, regenerate the deployed `.claude/` tree, and prove all three
payloads landed, with the full gate set green.

**Tasks**:

- [ ] Take a durable, non-reverting checkpoint before the first whole-tree regeneration:
      `bash .claude/scripts/git-snapshot.sh 482 --no-revert`.
- [ ] Activate sapience. It is absent from `.claude-extensions.json`, so `deploy-headless.sh`'s
      default mode (which force-loads `core` then resyncs only already-active extensions) would
      deploy nothing for it. Load it explicitly with a one-shot headless manager call modeled on
      `deploy-headless.sh`'s own default-mode nvim invocation — read that script's
      `manager.load('core', {confirm = false, force = true, project_dir = ...})` line and adapt it
      to `'sapience'` rather than composing a new command shape from memory.
- [ ] Confirm activation: `jq -r '.extensions.sapience.status' .claude-extensions.json` prints
      `active`.
- [ ] Redeploy: `bash .claude/scripts/deploy-headless.sh` (source-store path
      `agent-system/extensions/core/scripts/deploy-headless.sh`). Check the exit status and the
      `DEPLOY_COUNT=` / `RESULT=` markers; a suppressed or skipped verify is not a passed verify.
- [ ] Verify each merge target independently in the deployed tree, rather than inferring from one
      aggregate exit code (this extension's merge-target combination is not exercised by any
      existing extension):
      `grep -c 'Sapience Extension' .claude/CLAUDE.md` is at least 1;
      `jq -r '[.permissions.allow[] | select(test("sapience_remember|sapience_wrapup|sapience_handoff|sapience_adddoc"))] | length' .claude/settings.local.json`
      returns 4; `jq -r '[.entries[] | select(.path | startswith("project/sapience/"))] | length' .claude/context/index.json`
      returns 5; `ls .claude/context/project/sapience/` lists the README and the `domain/`
      directory; `ls .claude/extensions/sapience/manifest.json` exists.
- [ ] Confirm the gap-1 fix is real end to end: the four write-tool names are present in
      `.claude/settings.local.json`'s `permissions.allow`, and the deployed
      `.claude/settings.local.json` still carries the pre-existing entries it had before the deploy
      (the settings merge is additive, not a replacement).
- [ ] Run the complete gate set: `bash .claude/scripts/verify-deploy.sh` (source-store path
      `agent-system/extensions/core/scripts/verify-deploy.sh`), with no `--skip-slow` and no
      `--only-gate` filter. This is the final phase's full-gate obligation; a selected subset does
      not satisfy it. Check the command's exit status, not only its findings output.
- [ ] Confirm `bash agent-system/extensions/core/scripts/check-extension-docs.sh` is clean for the
      now-deployed sapience extension: required files present, every manifest `provides` entry
      resolves, `EXTENSION.md` within Rule U's 60-line limit, every deployed
      `.claude/context/project/sapience/*.md` file carrying an index entry.
- [ ] If the headless activation cannot run (no nvim available to the dispatch, or the manager call
      fails): leave the source files complete and unmodified, do not attempt a hand-authored write
      into `.claude/**`, mark this phase `[BLOCKED]` with the failure recorded, and report that the
      user must load sapience from the extension picker (see `agent-system/README.md`). The source
      extension is inert until loaded, so this leaves no partial deploy state.

**Timing**: 0.75 hours

**Depends on**: 4

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts that the deployed tree will carry 4 new
`permissions.allow` entries and 5 new `project/sapience/` index entries — figures derived from
phases 1 and 4, not independently measured. Confirm with the two `jq ... | length` queries in the
task list above, comparing against the pre-deploy baseline captured before the redeploy rather
than against this plan's numbers.

**Files to modify**:

- `__WHOLE_TREE__` - this phase invokes `deploy-headless.sh`, regenerating the entire deployed `.claude/` tree, which is an implicit scope claim over that whole tree
- `.claude-extensions.json` - extension activation state gains the `sapience` entry (written by the manager, not hand-edited)

**Verification**:

- `bash .claude/scripts/verify-deploy.sh` exits 0, run with no `--skip-slow` and no `--only-gate`
  filter — the complete gate set this plan's final phase is responsible for.
- `bash agent-system/extensions/core/scripts/check-extension-docs.sh` exits 0 with no FAIL line
  naming `sapience`.
- `jq -r '.extensions.sapience.status' .claude-extensions.json` prints `active`.
- The four independent merge-target assertions in the task list above all hold.
- `git status --short` shows no hand-authored file under `.claude/**` staged for commit; the
  deployed tree is gitignored output, and the task's committed change set is the source store plus
  `.claude-extensions.json`.

---

## Testing & Validation

- [ ] Both new JSON files parse (`jq empty`) and `index-entries.json` conforms to
      `context/index.schema.json`'s real field set: four required keys present, `description` /
      `tags` / `tier` absent, `domain` in the `core|project|system` enum, `load_when` restricted to
      the closed `agents|commands|task_types|always` key set.
- [ ] `manifest.json` declares no `task_type`, no `routing_agents`, and no top-level `hooks` object.
- [ ] `settings-fragment.json` declares no `mcpServers` key and exactly four `permissions.allow`
      entries.
- [ ] `EXTENSION.md` is 60 lines or fewer and carries the gap-2 wrapup instruction.
- [ ] `generate-context-line-counts.sh --check` reports no correction needed for any sapience entry.
- [ ] `check-task-references.sh` exits 0: no task-number references in these deliverables, which
      live outside `specs/**`.
- [ ] After deploy: the CLAUDE.md section, the four permission entries, and the five index entries
      are each independently confirmed present in the deployed tree.
- [ ] `verify-deploy.sh` (complete gate set, no filters) exits 0.
- [ ] Negative check: `grep -r 'sapience-context.sh' agent-system/extensions/sapience/` returns
      nothing — the dropped gap-3 hook is absent from the manifest and from every file, not merely
      unwritten.

## Artifacts & Outputs

- `agent-system/extensions/sapience/manifest.json`
- `agent-system/extensions/sapience/settings-fragment.json`
- `agent-system/extensions/sapience/EXTENSION.md`
- `agent-system/extensions/sapience/README.md`
- `agent-system/extensions/sapience/index-entries.json`
- `agent-system/extensions/sapience/context/project/sapience/README.md`
- `agent-system/extensions/sapience/context/project/sapience/domain/vault-model.md`
- `agent-system/extensions/sapience/context/project/sapience/domain/review-gate-boundary.md`
- `agent-system/extensions/sapience/context/project/sapience/domain/transcript-filter-ceiling.md`
- `agent-system/extensions/sapience/context/project/sapience/domain/subagent-orientation.md`
- Regenerated deployed tree (gitignored): `.claude/CLAUDE.md` section `extension_sapience`,
  `.claude/settings.local.json` permission grants, `.claude/context/index.json` entries,
  `.claude/context/project/sapience/**`, `.claude/extensions/sapience/manifest.json`
- `.claude-extensions.json` gains the `sapience` activation entry
- `specs/482_create_sapience_extension/summaries/01_create-sapience-extension-summary.md`

## Rollback/Contingency

Phases 1-4 create only new files in the source store and touch nothing else, so reverting them is
`git rm` / deleting `agent-system/extensions/sapience/` — no snapshot is needed to undo an
unloaded extension, which is inert until the manager loads it.

Phase 5 is the only phase that mutates shared state (`.claude-extensions.json` and the whole
deployed tree). Take the durable, non-reverting checkpoint named in that phase's first task
(`bash .claude/scripts/git-snapshot.sh 482 --no-revert`) before the first regeneration. To undo a
bad activation: unload sapience through the extension picker (or
`bash .claude/scripts/uninstall-extension.sh`, reading that script's own usage first), then
`bash .claude/scripts/deploy-headless.sh` to regenerate the tree without it, then confirm
`jq -r '.extensions.sapience' .claude-extensions.json` is gone or inactive and that
`.claude/settings.local.json` no longer carries the four grants.

If a rollback must instead discard uncommitted working-tree changes, follow
`context/contracts/recovery.md`'s rollback rung for the exact invocation shape, including its
out-of-scope override flag — do not improvise a destructive git command here.
