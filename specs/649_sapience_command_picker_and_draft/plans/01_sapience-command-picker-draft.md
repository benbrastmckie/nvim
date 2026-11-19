# Implementation Plan: Task #649

- **Task**: 649 - Add the /sapience command: draft assembly and the approval-gated surface picker
- **Status**: [IMPLEMENTING]
- **Effort**: 5.5 hours
- **Dependencies**: 647 (sapience_project_binding_and_vault_read, completed), 648 (sapience_publish_write_surfaces, completed)
- **Research Inputs**: specs/649_sapience_command_picker_and_draft/reports/01_sapience-command-picker-draft.md
- **Artifacts**: plans/01_sapience-command-picker-draft.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add the `/sapience` command to the sapience extension's source store: a direct-execution skill
that assembles a draft update from local repository state and read-only vault state, then gates
every outward write behind ONE `AskUserQuestion` checkbox multi-select showing each candidate
surface's literal payload. The task adds **no new script** — `commands/sapience.md` and
`skills/skill-sapience/SKILL.md` are pure consumers of the four scripts tasks 647/648 already
built and deployed. Definition of done: the command and skill exist in the source store, the
manifest/README/EXTENSION.md/index-entries.json surfaces are wired and consistent, the deploy
regenerates cleanly, and `check-extension-docs.sh` plus the full gate set pass.

### Research Integration

The research report's nine recommendations are adopted wholesale and drive the phase split:
no new script (Phase 2-3 author instruction surfaces only); **no `Agent`-tool dispatch at all**
(`skill-literature`'s fully-direct shape rather than `skill-roadmap`'s pre-delegation-then-dispatch
shape, which sidesteps the `AskUserQuestion` tool-withholding hazard rather than working around
it); one option-construction site for task 581's eventual absorption; `SAPIENCE_DRY_RUN`/the
publishers' own dry-run print reused verbatim as the literal-payload mechanism; the
`GET /v1/docs` `activity` field as the mechanical "most relevant doc" signal; and `README.md`
added to the dispatch's own FILE SCOPE because `check-extension-docs.sh`'s
`check_readme_vs_manifest()` hard-fails when a `provides.commands` entry is not textually
mentioned as `/<name>` in that extension's `README.md`.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` provided in this dispatch; no roadmap consultation performed.

### Premise Re-Validation (dispatch's flagged lines)

All three flagged lines were re-checked live at plan-authoring time, not carried:

- **EDIT TARGET** — `jq -r '.extensions.sapience.source_dir' .claude-extensions.json` returns
  `/home/benjamin/.config/nvim/agent-system/extensions/sapience`, and that directory exists with
  `context/ EXTENSION.md hooks/ index-entries.json manifest.json README.md rules/ scripts/
  settings-fragment.json`. **Confirmed unchanged.** The extension has `commands/` and `skills/`
  absent entirely, and `manifest.json`'s `provides.commands` and `provides.skills` are both `[]`
  — the dispatch's item-6 claim is confirmed. `routing_exempt: true` confirmed present.
- **Credential/host precedence lives in the shared `scripts/lib/sapience-api-lib.sh`** —
  confirmed: the file exists, and `SAPIENCE_DRY_RUN=1` handling sits inside both
  `sapience_post` and `sapience_get` (the dry-run print is the lib's, not each caller's).
  **Confirmed unchanged.**
- **Creating the bound project is an outward-facing mutation** — confirmed: the only creator is
  `scripts/sapience-project-bind.sh`, which requires an explicit `--confirm`; nothing in this
  plan's scope invokes it. **Confirmed unchanged.**

Two further figures carried from the research report were re-derived rather than trusted:
`MAX_DOC_FETCH=10` is live at `scripts/sapience-vault-read.sh:58`, and
`sapience-publish.sh`'s four subcommands plus their exact flag sets were re-read from the
script's own `usage()` block (`doc-comment <slug> --body ...`, `doc-version <slug> --body-file
...`, `dm --to ... --body ...`, `ko --note ... [--project <cid>]`, every one dry-run by default).

### Newly Measured Gate Collisions (not in the research report)

Two mechanical ceilings that the report did not measure were measured here, and both change
Phase 5's shape:

- **`EXTENSION.md` is exactly 60 lines (3,817 B)** — precisely at `check-extension-docs.sh`
  Rule U's 60-line maximum, with zero slack. Any net line addition fails the gate, so Phase 5's
  EXTENSION.md edit must be net-zero-or-negative in lines (replace the existing "No task type,
  no routing, no slash command" paragraph rather than appending a new section).
- **`EXTENSION.md` is this extension's declared `merge_targets.claudemd.source`**, so its bytes
  land in the eager `.claude/CLAUDE.md` assembly that `verify-deploy.sh` gate 20 budgets.

## Goals & Non-Goals

**Goals**:
- `commands/sapience.md`: argument grammar for `/sapience [text]`, `/sapience --message <Name>
  [text]`, and `/sapience --message [text]`, delegating to `skill-sapience` (direct execution).
- `skills/skill-sapience/SKILL.md`: binding gate, vault-read-backed draft assembly, optional
  collaborator picker, ONE approval picker over 3-4 candidate surfaces with literal payloads,
  and confirmed execution through `sapience-publish.sh` only.
- A durable design record (`context/project/sapience/domain/command-draft-and-picker.md`) stating
  the "most relevant doc" and "decision-shaped" heuristics as explicit, falsifiable rules.
- Full extension wiring: `manifest.json`, `EXTENSION.md`, `README.md`, `index-entries.json`,
  and the top-level extensions README row — all passing `check-extension-docs.sh`.

**Non-Goals**:
- No new script. The four scripts (`lib/sapience-api-lib.sh`, `sapience-vault-read.sh`,
  `sapience-project-bind.sh`, `sapience-publish.sh`) already exist and are already declared in
  `provides.scripts`; `provides.scripts` therefore needs no change.
- No autonomous project creation. `/sapience` never invokes `sapience-project-bind.sh`; a
  missing binding is a hard stop with instructions for the user to run it themselves.
- No extraction of a shared `AskUserQuestion` option renderer (task 581's job; no dependency
  edge added, per the dispatch's explicit coordination note).
- No migration onto the `project_cid`/`REPO_LINK_FOR` dark path — that flag is off for this
  token; the design only avoids foreclosing it.
- No second, independently-sized note bound: the KO surface inherits the existing 3-8-per-task
  bound and adds no cap of its own.
- No task type, no routing agents; `routing_exempt: true` stays.
- No edit to `agent-system/extensions/core/context/config/orchestrator-context-budget.json` —
  another in-flight task owns that file, and this plan's eager-byte contingency is trim-first.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `EXTENSION.md` already sits exactly at Rule U's 60-line ceiling; any net addition fails the gate | H | H | Phase 5 replaces the existing "no slash command" paragraph in place; `wc -l` is a phase-5 verification criterion, not an afterthought |
| `README.md` omitted from the dispatch's FILE SCOPE; `check_readme_vs_manifest()` hard-fails without a literal `/sapience` mention | H | H | `README.md` is explicitly in Phase 5's `Files to modify`; `grep -q '/sapience'` is a phase-5 verification criterion |
| Eager-context gate 20 fires once EXTENSION.md bytes grow | M | M | Keep the EXTENSION.md edit byte-neutral where possible; re-measure in Phase 6; if it fires, trim EXTENSION.md/README prose (route a), never move the shared budget config another task owns |
| The decision-log target doc's body may be absent from the vault-read envelope (`doc_bodies` is bounded to `MAX_DOC_FETCH=10` **unread** docs), leaving `doc-version` with no `--body-file` content | M | H | Decision D5 below: fetch that one body by sourcing the shared lib and calling `sapience_get`, never by re-deriving credentials; if the fetch fails, the option is shown UNAVAILABLE with the reason, never with a fabricated body |
| An implementer names an MCP write tool as a prescribed write path, violating `rules/sapience-write-path.md` and the 7-tool read-only grant | H | M | Phases 2-4 state the write path positively (scripts only) and name no MCP write tool at all; Phase 6 greps both new files for the four tool names |
| No delete API exists: every confirmed KO and doc-version is permanent and bypasses the vault's `auto_approve:false` review gate | H | M | Design-level, already settled: the picker is single, mandatory, shows literal payloads rather than summaries, and nothing is re-tried after a confirmed write |
| Dry-run previews cost up to 2 extra network GETs per run (`doc-version` resolves `base_rev` even under dry-run; `ko` resolves the project key) | L | H | Pre-existing, tested behavior of the dependency scripts — documented in the design record so a reviewer does not mistake it for an avoidable inefficiency |
| The "most relevant doc" signal is absent on day one (all four Oliver+Ben docs currently have zero comments) | M | H | The fallback branch is specified as a rule, not left to judgment (D3 below), and is the branch that actually fires first |

## Decisions

- **D1 — No `Agent`-tool dispatch anywhere.** `skill-sapience` is a fully direct-execution skill
  (`allowed-tools: Bash, Read, Write, AskUserQuestion`), matching `skill-literature`. This is a
  stronger resolution of the dispatch's load-bearing constraint than collecting choices before a
  dispatch: with no dispatch, `AskUserQuestion`'s withholding from named-`subagent_type`
  dispatches cannot bite at all.
- **D2 — One option-construction site.** The picker's option objects are built in exactly one
  block in `SKILL.md`, bracketed by a stable marker comment
  (`<!-- askuserquestion-option-construction: sapience-approval-picker -->` …
  `<!-- /askuserquestion-option-construction -->`), so task 581 can absorb this fifth site
  without hunting scattered call sites. No dependency edge on 581 is added.
- **D3 — "Most relevant doc" is a rule, not a judgment.** Among the bound project's docs in
  `vault.docs`: pick the doc with the greatest `activity.at` whose `activity.by` is NOT the
  running identity; if no such doc exists, pick the greatest `updated`; break a tie by
  lexicographically smallest slug. Never hardcode a slug.
- **D4 — "Decision-shaped" is a rule, not a judgment.** True iff EITHER the assembled draft text
  matches a documented, case-insensitive marker set (`decided`, `we will`, `going with`,
  `chose`, `settled on`) OR `local.git` since the cursor contains a commit subject matching
  `^task [0-9]+: (create implementation plan|complete implementation)$`. False otherwise. The
  decision-log-row option is pre-checked only when this is true.
- **D5 — The decision-log row needs the target doc's current body.** When that body is not
  present in the envelope's `doc_bodies` (bounded to `MAX_DOC_FETCH=10` unread docs), obtain it
  by sourcing `.claude/scripts/lib/sapience-api-lib.sh` and calling
  `sapience_get "/v1/docs/<slug>"` — reusing the shared credential/host precedence rather than
  re-deriving it, and never printing the token. On failure the option renders UNAVAILABLE with
  the failure reason; it is never offered with a fabricated or empty body.
- **D6 — The literal payload is the publishers' own dry-run print, never a second string.**
  Each candidate surface's preview is produced by invoking the same `sapience-publish.sh`
  subcommand, with the same arguments, WITHOUT `--confirm`; the confirmed run re-invokes the
  identical argument vector with `--confirm` appended. The full payload text is printed to the
  transcript immediately before the picker; each option's `description` carries a short excerpt
  plus an explicit pointer to the full payload printed above (AskUserQuestion descriptions are
  length-limited, so the full text cannot live only inside the option object).
- **D7 — The KO surface issues exactly one `ko` call.** Every confirmed note is passed via
  repeated `--note` in a single invocation (the subcommand POSTs them in one `/ingest-kos`
  call), bounded to the inherited 3-8 range. Never one call per note.
- **D8 — `--message` with no name opens a SECOND, earlier `AskUserQuestion`.** The collaborator
  single-select (roster from `GET /v1/people`) resolves WHO before the approval picker resolves
  WHETHER. These are two distinct questions and are deliberately not merged.
- **D9 — No MCP write tool is named in any new instruction surface.** `rules/sapience-write-path.md`
  enumerates its sanctioned discussion sites by path; `commands/sapience.md` and
  `skills/skill-sapience/SKILL.md` are not among them, so they state the script write path
  positively and name no MCP write tool at all. Adding such a mention would require amending
  that rule's sanctioned-site list in the same phase, which this plan does not do.

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3, 4 | 2 |
| 4 | 5 | 3, 4 |
| 5 | 6 | 5 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Design Record for the Draft and Picker [COMPLETED]

**Goal**: Land the durable design record that Phases 2-4 implement against, so the heuristics are
written once, checkably, rather than re-decided inside an instruction surface.

**Tasks**:
- [x] Create `agent-system/extensions/sapience/context/project/sapience/domain/command-draft-and-picker.md`
      documenting: the four candidate write surfaces and their 1:1 mapping onto
      `sapience-publish.sh` subcommands (`doc-comment`, `doc-version`, `ko`, `dm`); the
      pre-check defaults (doc comment and KOs by default, decision-log row only when D4 is true,
      DM only when `--message` was passed); D3's "most relevant doc" rule verbatim; D4's
      "decision-shaped" rule verbatim; D6's dry-run-equals-confirmed-payload discipline; D5's
      body-fetch fallback; D7's single-`ko`-call and inherited 3-8 bound; and D2's
      option-construction marker so task 581 can find the site. *(completed)*
- [x] Record the no-delete-API consequence explicitly: every confirmed KO and doc-version is
      permanent and bypasses the vault's `auto_approve:false` review gate, which is why the
      picker is single, mandatory, and payload-literal. *(completed)*
- [x] Record the `project_cid`/`REPO_LINK_FOR` dark path as the eventual target, naming the two
      live confirmations that it is currently off, and state that migrating is a change inside
      the scripts, not in the command or skill (so this design does not foreclose it). *(completed)*
- [x] Add a nav row for the new file to
      `agent-system/extensions/sapience/context/project/sapience/README.md`'s Loading Strategy
      table, matching the existing "Need to …" phrasing of its sibling rows. *(completed)*
- [x] Add the matching `index-entries.json` entry with the five Rule-T-required keys (`path`,
      `domain`, `subdomain`, `summary`, `line_count`) plus `topics`, `keywords`, `load_when: {}`
      and `on_demand: true`, exactly as every other sapience entry is shaped. *(completed)*
- [x] Set `line_count` from the finished file (`wc -l`), and update the existing
      `project/sapience/README.md` entry's `line_count` for the nav row just added. *(completed: new file 108 lines, README.md entry corrected to 20 lines)*

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `suite_selection_select` returns the `__FULL_SWEEP__` sentinel for this
phase's touched paths (the two markdown files have no mapped suite, which collapses the whole
selection), so no suite covers them and the honest check is the source-store gate subset
`bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
together with `check-extension-docs.sh` and the diff read-through this tier already prescribes.

**Scope Hypothesis**: this phase adds exactly one new indexed context file and therefore exactly
one new `index-entries.json` entry, plus one `line_count` correction on the existing
`project/sapience/README.md` entry; confirm at implementation time by running
`bash .claude/scripts/check-extension-docs.sh` (or its source-store equivalent) and reading its
Rule R output, which names every entry whose `line_count` is wrong.

**Files to modify**:
- `agent-system/extensions/sapience/context/project/sapience/domain/command-draft-and-picker.md` - new design record
- `agent-system/extensions/sapience/context/project/sapience/README.md` - nav row for the new file
- `agent-system/extensions/sapience/index-entries.json` - new entry; `line_count` for both touched context files

**Verification**:
- `jq empty agent-system/extensions/sapience/index-entries.json` succeeds.
- `bash .claude/scripts/check-extension-docs.sh` reports no Rule R (line_count) or Rule T
  (schema) finding for the sapience extension.
- `bash .claude/scripts/verify-touched.sh <this phase's three paths>` is green.
- Diff read-through confirms both markdown changes are prose-only.

---

### Phase 2: skill-sapience — Intake, Binding Gate, and Draft Assembly [COMPLETED]

**Goal**: Create `skills/skill-sapience/SKILL.md` through the point where a complete draft and a
resolved collaborator (when asked for) exist in hand — everything before the picker.

**Tasks**:
- [x] Create `agent-system/extensions/sapience/skills/skill-sapience/SKILL.md` with frontmatter
      `name: skill-sapience`, a one-line `description`, and
      `allowed-tools: Bash, Read, Write, AskUserQuestion` — no `Agent`, per D1; `Write` is
      required only for the scratchpad `--body-file` the `doc-version` surface needs. *(completed)*
- [x] State the skill's own mode contract: the four argument shapes the command passes through
      (no args; free text; `--message <Name> [text]`; `--message [text]`), and what each changes. *(completed)*
- [x] Stage: binding gate. Resolve the repo toplevel and require `.sapience/project.json`
      (already surfaced as the envelope's `repo.binding`). On a missing binding, STOP with the
      exact `sapience-project-bind.sh --name "<name>" --confirm` invocation for the USER to run
      — never run it from the skill, in any mode (HARD CONSTRAINT 5). *(completed)*
- [x] Stage: read. Invoke `bash .claude/scripts/sapience-vault-read.sh` and parse the pinned
      `sapience-vault-read/1` envelope with `jq`. Handle the per-source failure isolation the
      script already implements: a `null` top-level key plus its `errors[]` entry degrades the
      surfaces that depend on it and is reported, never silently ignored; exit 2 (all five vault
      sources failed) is a hard stop. *(completed)*
- [x] Stage: draft assembly. Compose the candidate update text from `local.{git,state,events,
      errors,sessions}` and `vault.{docs,doc_bodies,doc_comments,project_notes,suggestions,
      notifications}`, explicitly RESPONDING to the collaborator's most recent comment/answer
      rather than talking past it, and state the `MAX_DOC_FETCH=10`-unread-docs bound on how much
      comment/body content the envelope carries. *(completed)*
- [x] Stage: target resolution. Implement D3's "most relevant doc" rule and D4's
      "decision-shaped" rule as written in the Phase 1 design record, citing that record rather
      than restating the rationale. *(completed)*
- [x] Stage: collaborator resolution (only when `--message` was passed). A named collaborator
      resolves against the `GET /v1/people` roster; a bare `--message` presents a single-select
      `AskUserQuestion` over that roster (D8) BEFORE the approval picker. An unresolvable name is
      a loud stop, never a silent fallback to the only connection. *(completed)*
- [x] State the write-path contract positively: every outward write in this skill goes through
      `sapience-publish.sh`; name no MCP write tool anywhere (D9). *(completed)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: the edit is confined to one new instruction-surface file with no
executable surface of its own, and `bash .claude/scripts/verify-touched.sh
agent-system/extensions/sapience/skills/skill-sapience/SKILL.md` resolves and runs that path's
own mapped suite set itself — the one command "narrow" means, never a hand-assembled subset.

**Files to modify**:
- `agent-system/extensions/sapience/skills/skill-sapience/SKILL.md` - new skill, stages through draft assembly and collaborator resolution

**Verification**:
- The file exists with the exact `allowed-tools` line from D1 and no `Agent` entry.
- `grep -nE 'sapience_(remember|wrapup|handoff|adddoc)' <the file>` returns nothing (D9).
- Every `*.sh` basename the file mentions is already in some extension's `provides.scripts`
  (`check-extension-docs.sh` Rule E).
- `bash .claude/scripts/verify-touched.sh agent-system/extensions/sapience/skills/skill-sapience/SKILL.md`
  is green.

---

### Phase 3: skill-sapience — The Single Approval Picker and Confirmed Execution [COMPLETED]

**Goal**: Complete `SKILL.md` with the one option-construction site, the single approval picker,
and the confirmed-write execution and reporting path.

**Tasks**:
- [x] Add the preview stage: for each candidate surface, build its exact `sapience-publish.sh`
      argument vector and invoke it WITHOUT `--confirm`, capturing the literal payload the
      script prints (D6). For `doc-version`, write the proposed new body (the current body plus
      the appended decision row) to a scratchpad file first, obtaining that current body per D5. *(completed)*
- [x] Add the single option-construction block, bracketed by D2's marker comments, building 3-4
      option objects: doc comment (pre-checked when a target doc resolves), decision-log row
      (pre-checked only when D4 is true), repo-tagged KOs (pre-checked), DM (present and
      pre-checked only when `--message` was passed). Explicitly note the measured 4-option
      ceiling and that this picker never needs batching or tiering because the surfaces are at
      most four. *(completed)*
- [x] Add the approval stage: print every full literal payload to the transcript, then ONE
      `AskUserQuestion` with `multiSelect: true` whose option descriptions carry a short excerpt
      plus a pointer to the full payload above. An UNAVAILABLE surface (D5 failure, or an
      unresolvable target) is shown with its reason and cannot be checked. *(completed)*
- [x] Add the execution stage: for each checked option, re-invoke the IDENTICAL argument vector
      with `--confirm` appended. The KO surface issues exactly one `ko` invocation carrying every
      confirmed note via repeated `--note`, bounded to the inherited 3-8 range (D7, HARD
      CONSTRAINT 2) — state that this skill adds no second, independently-sized bound. *(completed)*
- [x] Add the outcome-reporting stage: report each surface's result distinctly, naming
      `doc-version`'s four verified outcomes (`409 head_moved` refused, `202` proposed awaiting
      owner, `404 share_gone` refused, `2xx` saved) and `dm`'s two sequential writes. State that
      a confirmed write is never retried, because there is no delete API and a retry can only
      duplicate a permanent record. *(completed)*
- [x] Add the empty-selection behavior: zero checked options is a legitimate outcome that writes
      nothing and exits cleanly, never a re-prompt loop. *(completed)*

**Timing**: 1.5 hours

**Depends on**: 2

**Verification Tier**: local

**Tier Justification**: the same single `skills/**/SKILL.md` file as Phase 2 and no other file's
blast radius, so
`bash .claude/scripts/verify-touched.sh agent-system/extensions/sapience/skills/skill-sapience/SKILL.md`
resolves and runs that path's own mapped suite set itself, exactly as in Phase 2.

**Files to modify**:
- `agent-system/extensions/sapience/skills/skill-sapience/SKILL.md` - picker, confirmed execution, reporting

**Verification**:
- Exactly one `AskUserQuestion` call constructs the approval picker, and exactly one marker-
  bracketed option-construction block exists (`grep -c 'askuserquestion-option-construction'`
  returns 2 — the open and close markers).
- Every confirmed-write invocation in the file is a `sapience-publish.sh` subcommand; no other
  write mechanism appears.
- `grep -nE 'sapience_(remember|wrapup|handoff|adddoc)' <the file>` still returns nothing.
- `bash .claude/scripts/verify-touched.sh agent-system/extensions/sapience/skills/skill-sapience/SKILL.md`
  is green.

---

### Phase 4: commands/sapience.md [COMPLETED]

**Goal**: Add the thin command layer that parses `/sapience`'s arguments and delegates to
`skill-sapience`.

**Tasks**:
- [x] Create `agent-system/extensions/sapience/commands/sapience.md` with frontmatter
      `description`, `allowed-tools: Skill`, and `argument-hint: [message text] | --message
      [Name] [text]`, matching `commands/literature.md`'s confirmed convention. *(completed)*
- [x] Body: `**Purpose**`, `**Layer**: 2 (Command File - Argument Parsing Agent)`,
      `**Delegates To**: skill-sapience (direct execution)`, and `**Input**: $ARGUMENTS`. *(completed)*
- [x] Argument parsing: first-match-wins mode detection for the three shapes — `--message <Name>
      [text]` (name present), `--message [text]` (bare, triggers the collaborator picker), and
      the default no-flag form with optional free text. An unknown flag is a loud refusal, not a
      silent pass-through. *(completed)*
- [x] State the single guarantee the command surface itself must carry: the run ALWAYS ends in
      one approval picker and nothing leaves the machine unapproved — with the detail living in
      `skill-sapience` and the design record rather than duplicated here. *(completed)*
- [x] Name no MCP write tool (D9) and name no script not already in `provides.scripts`. *(completed)*

**Timing**: 0.75 hours

**Depends on**: 2

**Verification Tier**: prose

**Tier Justification**: `suite_selection_select` returns `__FULL_SWEEP__` for
`agent-system/extensions/sapience/commands/sapience.md`, so no suite covers this pure-guidance
markdown file; per the source-store sub-case the honest check is
`bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
(this repository root is simultaneously the deploy consumer and the source store) alongside the
`prose` row's diff read-through.

**Files to modify**:
- `agent-system/extensions/sapience/commands/sapience.md` - new command file

**Verification**:
- The frontmatter carries `allowed-tools: Skill` and an `argument-hint`.
- The body names `skill-sapience` as its delegate.
- `grep -nE 'sapience_(remember|wrapup|handoff|adddoc)' <the file>` returns nothing.
- `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
  is green (gate 3 doc-lint, gate 4 task-reference lint).

---

### Phase 5: Manifest Wiring and Documentation Parity [COMPLETED]

**Goal**: Wire the new command and skill into `manifest.json` and bring every documentation
surface that currently asserts "no slash command" into parity — without breaking Rule U's
60-line `EXTENSION.md` ceiling.

**Tasks**:
- [x] `manifest.json`: add `"sapience.md"` to `provides.commands` and `"skill-sapience"` to
      `provides.skills`. Leave `provides.scripts` untouched (no new script) and leave
      `routing_exempt: true` in place. *(completed)*
- [x] `EXTENSION.md`: replace the existing two-line "**No task type, no routing, no slash
      command**: review/sync/coverage/pending/stats are already covered by the GNOME desktop
      launchers the nix module installs." paragraph IN PLACE with a `/sapience` command line of
      equal or fewer lines — net line delta must be ≤ 0. The replacement states the command's
      shape, that it always ends in one approval picker, and that the desktop launchers still
      cover review/sync/coverage/pending/stats. *(completed: still exactly 60 lines)*
- [x] `README.md`: correct the opening paragraph's "This extension provides no task type, no
      routing agents, and no slash command" claim and its matching closing section; add a
      `/sapience` mention (the literal substring `check_readme_vs_manifest()` greps for); add
      File Inventory rows for `commands/sapience.md`, `skills/skill-sapience/SKILL.md`, and the
      new domain note. *(completed)*
- [x] `agent-system/extensions/README.md`: update the sapience row's description cell so the
      top-level inventory no longer describes the extension as grants-and-docs only. The row
      itself already exists (the first-column set diff this lint performs is already satisfied);
      this is a description-accuracy edit, not a membership fix. *(completed)*
- [x] Re-run `wc -l agent-system/extensions/sapience/EXTENSION.md` after the edit and confirm it
      is ≤ 60. *(completed: 60)*

**Timing**: 1 hour

**Depends on**: 3, 4

**Verification Tier**: interface

**Tier Justification**: a `manifest.json` `provides` change alters what the deploy emits for
every downstream consumer of this extension, so the covering check is
`bash .claude/scripts/verify-touched.sh` over this phase's four paths, which resolves and runs
that one-hop dependent suite set itself — a cheaper per-file tier reaches none of it.

**Scope Hypothesis**: `EXTENSION.md` is currently exactly 60 lines / 3,817 B — precisely at Rule
U's 60-line ceiling with zero slack (measured live at plan authoring with `wc -lc`, not carried
from the research report, which did not measure it). Confirm with `wc -l` BEFORE editing and
again after; if the pre-edit count differs from 60, recompute the allowable delta from the
live count rather than from this figure.

**Files to modify**:
- `agent-system/extensions/sapience/manifest.json` - add the command and skill entries to the provides block
- `agent-system/extensions/sapience/EXTENSION.md` - replace the "no slash command" paragraph in place, net line delta ≤ 0
- `agent-system/extensions/sapience/README.md` - drop the "no slash command" claims, add the literal `/sapience` mention and File Inventory rows
- `agent-system/extensions/README.md` - sapience row description accuracy

**Verification**:
- `jq -e '.provides.commands | index("sapience.md")' agent-system/extensions/sapience/manifest.json`
  and `jq -e '.provides.skills | index("skill-sapience")' …` both succeed.
- `jq -e '.routing_exempt == true' agent-system/extensions/sapience/manifest.json` succeeds.
- `wc -l agent-system/extensions/sapience/EXTENSION.md` reports ≤ 60.
- `grep -q '/sapience' agent-system/extensions/sapience/README.md` succeeds.
- `grep -rn 'no slash command' agent-system/extensions/sapience/` returns nothing.
- `bash .claude/scripts/verify-touched.sh <this phase's four paths>` is green.

---

### Phase 6: Deploy, Gate Reconciliation, and Closing Verification [COMPLETED]

**Goal**: Regenerate the deployed tree so the new command and skill are live, reconcile every
gate the change touches, and close the task.

**Tasks**:
- [x] Regenerate the deployed tree from the source store (`deploy-headless.sh`, or the extension
      picker's reload/regenerate entry) so `.claude/commands/sapience.md`,
      `.claude/skills/skill-sapience/SKILL.md`, the merged `.claude/CLAUDE.md` section, and the
      merged `.claude/context/index.json` entries all appear. *(completed)*
- [x] Confirm the deployed command and skill resolve: `.claude/commands/sapience.md` exists and
      the `/sapience` entry is present in the merged CLAUDE.md assembly. *(completed: byte-identical to source)*
- [x] Run `bash .claude/scripts/check-extension-docs.sh` and confirm zero findings for the
      sapience extension across Rules A, E, R, T, U, and `check_readme_vs_manifest`. *(completed: zero findings across these six; the one remaining sapience finding is Rule F, a pre-existing one-byte trailing-newline drift in scripts/sapience-vault-read.sh from the project-binding task's scope, not named by this criterion and not in this task's FILE SCOPE)*
- [x] Run `REPO_ROOT=$(pwd) bash .claude/scripts/measure-eager-context.sh --check` and compare
      the reported TOTAL against `eager_load.baseline_bytes`. If it exceeds the baseline, trim
      EXTENSION.md/README prose (route a) rather than editing the shared budget config — another
      in-flight task owns that file. Record the measured figure either way. *(completed: TOTAL 70,505 B, baseline 71,600 B -- 1,095 B under, no trim needed)*
- [x] Run the scoped touched-path check over every path this task touched:
      `bash .claude/scripts/verify-touched.sh <all touched paths>`. *(completed: mapped SELECT set 63/66 passed -- 2 expected + 1 pre-existing-unrelated NEW (test-mcp-merge-target.sh, independently corroborated by tasks 648/650); OWED fallback set clean 98/98)*
- [x] Record the issue-log entries for this task's gate collisions (the 60-line EXTENSION.md
      ceiling, and the `doc_bodies` unread-docs bound that forced D5) and any wins. *(completed)*

**Timing**: 0.75 hours

**Depends on**: 5

**Verification Tier**: full

**Scope Hypothesis**: the eager-context budget config records `baseline_bytes: 71600` and
`measured_bytes: 70472` (dated 2026-11-18), i.e. roughly 1,128 B of headroom — carried from
`agent-system/extensions/core/context/config/orchestrator-context-budget.json`, not re-measured
at plan authoring, and liable to have moved because another in-flight task owns that file.
Confirm by reading the live `baseline_bytes` and running `measure-eager-context.sh --check`
rather than trusting either figure.

**Files to modify**:
- `__WHOLE_TREE__` - this phase invokes whole-tree regeneration of the deployed `.claude/` tree

**Verification**:
- `.claude/commands/sapience.md` and `.claude/skills/skill-sapience/SKILL.md` both exist after
  the regeneration, and `grep -q '/sapience' .claude/CLAUDE.md` succeeds.
- `bash .claude/scripts/check-extension-docs.sh` reports no sapience finding.
- `REPO_ROOT=$(pwd) bash .claude/scripts/measure-eager-context.sh --check` reports a TOTAL at or
  below the live `eager_load.baseline_bytes`.
- In-dispatch obligation under `/orchestrate`: run the scoped touched-path check
  (`bash .claude/scripts/verify-touched.sh <all touched paths>`) and record that the complete
  gate set is DEFERRED to the orchestration close (`context/contracts/batch-gate-stage.md`),
  not independently re-run here. Outside `/orchestrate` (a standalone, non-orchestrated run with
  no Move 4 to defer to), run `bash .claude/scripts/verify-deploy.sh` in full instead.

---

## Testing & Validation

- [ ] `jq empty` succeeds on both edited JSON files (`manifest.json`, `index-entries.json`).
- [ ] `check-extension-docs.sh` reports zero sapience findings, specifically covering Rule A
      (undeclared skill dirs), Rule E (referenced scripts declared), Rule R (index line_count),
      Rule T (index schema), Rule U (EXTENSION.md ≤ 60 lines), and `check_readme_vs_manifest`
      (`/sapience` literally present in `README.md`).
- [ ] Neither `commands/sapience.md` nor `skills/skill-sapience/SKILL.md` names any of
      `sapience_remember`, `sapience_wrapup`, `sapience_handoff`, `sapience_adddoc`.
- [ ] `skill-sapience`'s `allowed-tools` contains no `Agent` entry.
- [ ] Exactly one `AskUserQuestion` call builds the approval picker, inside exactly one
      marker-bracketed option-construction block.
- [ ] Every outward write named in either new file is a `sapience-publish.sh` subcommand.
- [ ] The deployed tree carries the command and skill after regeneration.
- [ ] `measure-eager-context.sh --check` is at or below the live baseline.
- [ ] The scoped touched-path check is green; the complete gate set is discharged at the
      orchestration close.

## Artifacts & Outputs

- `agent-system/extensions/sapience/commands/sapience.md` (new)
- `agent-system/extensions/sapience/skills/skill-sapience/SKILL.md` (new)
- `agent-system/extensions/sapience/context/project/sapience/domain/command-draft-and-picker.md` (new)
- `agent-system/extensions/sapience/manifest.json` (modified: `provides.commands`, `provides.skills`)
- `agent-system/extensions/sapience/EXTENSION.md` (modified, net line delta ≤ 0)
- `agent-system/extensions/sapience/README.md` (modified)
- `agent-system/extensions/sapience/index-entries.json` (modified)
- `agent-system/extensions/sapience/context/project/sapience/README.md` (modified)
- `agent-system/extensions/README.md` (modified: sapience row description)
- Regenerated `.claude/` deploy artifacts (not source-controlled)

## Rollback/Contingency

Every change in this plan is additive source-store authoring plus four in-place documentation
edits; nothing mutates the vault, and the vault is never written during implementation (only the
dry-run previews, which make no network call for the comment/DM surfaces).

- **Phases 1-5** are revertible by ordinary per-phase commit revert; each phase's commit is
  scoped to its own `Files to modify` list.
- **Phase 6** regenerates `.claude/`, which is a gitignored, disposable deploy artifact — rolling
  back means reverting the source-store commits and regenerating again, never hand-editing
  `.claude/**`.
- If the eager-context gate fires in Phase 6 and prose trimming cannot recover the bytes, the
  contingency is to stop and surface the overage rather than edit the shared budget config
  another in-flight task owns; the command and skill remain correct and deployed, and the
  budget reconciliation becomes that other task's or a follow-up's business.
- If a genuine rollback of uncommitted work becomes necessary, follow
  `context/contracts/recovery.md`'s rollback rung for the snapshot-then-rollback invocation
  shape; do not emit a bare precautionary snapshot as a routine start-of-phase step.
