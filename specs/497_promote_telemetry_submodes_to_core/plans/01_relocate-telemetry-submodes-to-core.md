# Implementation Plan: Task #497

- **Task**: 497 - Promote telemetry sub-modes to core
- **Status**: [COMPLETED]
- **Effort**: 8.5 hours
- **Dependencies**: None (re-sequences 421 to depend on this task; declared edges with 328, 435)
- **Research Inputs**: specs/497_promote_telemetry_submodes_to_core/reports/01_relocate-telemetry-submodes-research.md
- **Artifacts**: plans/01_relocate-telemetry-submodes-to-core.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Relocate the `--meta`, `--review` and `--dream` sub-modes out of the memory extension's
`/distill` surface into a new core-owned `/telemetry` command backed by a new direct-execution
`skill-telemetry`, so all three survive the memory extension's retirement. The move lands five
new core files (three sub-mode specifications, the shared `telemetry-guardrails.md`
design-constraints document, and the command file), registers them in core's manifest and
context index, repoints every cross-extension citation, then strips the three sub-modes from
memory's command/skill/doc surface and deletes the relocated files. The relocation is mechanical
in *scope* — no sub-mode is retargeted, redesigned or extended — but it is not a verbatim copy:
six dependencies must be re-anchored at the new location and the copied prose must be
de-narrated to satisfy core's deliverable-tree rules.

### Research Integration

The research report's six recommendations are all adopted, with destinations and the unresolved
invocation-surface question now decided:

- Rec #1 (relocate the three specs): destination is `core/context/patterns/`, matching the
  originals' own `patterns/` category and co-locating them with
  `context/patterns/mode-gated-section-loading.md`, the extraction convention they already
  follow. Core has no `context/project/` tree (verified absent), so the research's alternative
  destination does not exist.
- Rec #2 (relocate `telemetry-guardrails.md` wholesale): adopted, to
  `core/context/standards/telemetry-guardrails.md` — `standards/` is the correct category for a
  "binding design constraints" document. This also repairs **two pre-existing cross-extension
  references from core into memory** the research found but did not count as a driver:
  `core/context/formats/dispatch-metrics.md` (3 citations) and
  `core/context/formats/events-format.md` (3 citations) already cite
  `context/project/memory/telemetry-guardrails.md`, so core already depends on a memory file
  today.
- Rec #3 (inline the `### Overlap Scoring` formula): adopted. The formula was read at
  `memory/skills/skill-learn/SKILL.md:188-198` and is three lines of generic term-set overlap
  ratio.
- Rec #4 (repoint the three-strikes citation): adopted, and now verified concretely —
  `core/context/contracts/convergence.md` carries a literal `## Three-Strikes Rule` section
  (`target_churn_count[target]` reaching 3), which is the precedent
  `distill-revise-submode.md:147-149` was itself only citing by name.
- Rec #5 (resolve the invocation surface at plan time): decided — a single new core command
  `/telemetry` hosting all three flags under their existing names. See "Invocation-surface
  decision" below.
- Rec #6 (re-verify the `meta-builder-agent.md` quotation): adopted; confirmed the quoted
  "Known limitation" text returns zero matches in the current agent file.

**Six dependencies the research inventory did not cover**, each resolved by a named phase task
below, because each would otherwise break the dispatch's "invocable after relocation" criterion:

1. **The Shared Sub-Mode Skeleton.** All three specs declare "Follows the Shared Sub-Mode
   Skeleton in `skill-distill/SKILL.md`" and state only their deltas from it. That skeleton lives
   in memory and has no core counterpart. `skill-telemetry/SKILL.md` must carry its own
   telemetry-scoped skeleton for the three specs to be self-sufficient.
2. **Log-file destinations are memory-extension data paths.** `--meta` logs to
   `.memory/meta-log.json`, `--dream` to `.memory/dream-log.json`, and `--review` optionally to
   `.memory/distill-log.json`. All three move to `specs/telemetry/`, a tracked, core-owned,
   repo-level location mirroring the existing `specs/events.jsonl` / `specs/errors.json`
   precedent (deliberately not a gitignored runtime class, so no
   `lib/runtime-file-patterns.sh` or `.gitignore` change is required).
3. **`--dream`'s existing-coverage check reads `.memory/memory-index.json`.** It must become
   conditional on the vault being present, with `specs/TODO.md` as the always-available coverage
   source.
4. **`skill-distill`'s `allowed-tools` frontmatter omits the Agent tool** that `--meta`'s
   documented `meta-builder-agent` delegation requires (`Bash, Grep, Read, Write, Edit,
   AskUserQuestion`). `skill-telemetry` declares it.
5. **`AskUserQuestion` is categorically withheld from dispatched subagents** (see
   `scripts/tests/test-askuserquestion-rehome.sh`'s header and
   `docs/reference/standards/agent-frontmatter-standard.md`'s "Tool Withholding from Dispatched
   Subagents"). `--meta`'s MANDATORY STOP therefore requires `skill-telemetry` to be a
   **direct-execution** skill run by the invoking session, never an agent dispatch — matching
   `skill-distill`'s existing posture.
6. **`memory_health.last_dream` / `dream_count` state coupling.** `--dream`'s `--since` cursor
   is also carried by its own log file's `since` / `last_operation` fields, so the
   `memory_health` coupling is dropped and the log becomes the sole cursor. Stated explicitly in
   the relocated spec rather than silently omitted.

### Invocation-surface decision

**Chosen**: one new core command, `/telemetry`, with the three sub-mode flags keeping their
existing names and arguments — `/telemetry --meta`, `/telemetry --review "<question>"`,
`/telemetry --dream` — backed by one new direct-execution skill, `skill-telemetry`.

Rationale, in order of weight:

1. It avoids both collisions the research identified. Core's existing `/review` command means
   "analyze the codebase and create fix tasks" (mutating); a bare `/review` or a flag on it
   would conflate two unrelated concepts. Core's existing `/meta` is the interactive system
   builder; `/telemetry --meta` feeds the same `meta-builder-agent` from a signal source
   instead of an interview, so the two remain distinguishable entry points rather than one
   overloaded command.
2. It keeps the three co-located, which preserves their internal funnel references
   (`--dream` → `--meta`, `--review` → `--meta` / `--revise` / `/learn`) as same-command
   cross-references rather than converting them into cross-command ones.
3. It is one new command and one new skill rather than three of each.
4. The flag names and the specs themselves are unchanged, so the sub-modes' documented output
   shapes — the dispatch's actual verification bar — are preserved.

**Rejected alternative**: folding `--meta` onto the existing `/meta` command and hosting only
`--review`/`--dream` elsewhere. It splits three co-dependent sub-modes across two commands,
adds a fourth mode to an already-documented reference-implementation command, and breaks the
funnel references in (2) for no gain.

The relocated files are renamed `distill-*-submode.md` → `telemetry-*-submode.md` to match the
host command, so a grep for the old basenames is a meaningful completeness check rather than a
no-op.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context, so no roadmap consultation was
performed and no roadmap phases are included.

## Goals & Non-Goals

**Goals**:

- All three sub-modes' complete specifications, plus their shared `telemetry-guardrails.md`
  design-constraints document, live under `agent-system/extensions/core/**`.
- All three are invocable from a core-owned command and skill that do not depend on any
  memory-extension file surviving.
- Every cross-extension citation (core → memory, books → memory, memory → the relocated files)
  resolves after the move; zero references to the old memory-extension paths remain anywhere in
  the source store.
- Both sanctioned MANDATORY STOP exemptions (`--review`, `--dream`) remain explicitly stated,
  not silently dropped.
- The OTel-absent degraded path and the `reflection`-dead-signal caveat are carried into the
  relocated specifications as stated facts.
- The six undiscovered dependencies above are each re-anchored at the new core location.

**Non-Goals**:

- Retargeting, redesigning or extending any of the three sub-modes. Task 421 owns `--meta`'s
  retargeting (issues.jsonl ingestion, matcher consumption, consolidation channel,
  per-invocation cap) and will land it at the new core paths.
- Relocating `--revise` or `--learn` (store-coupled; they belong to the memory retirement task).
- Deleting the six store-maintenance sub-modes (`report`, `--purge`, `--merge`, `--compress`,
  `--refine`, `--gc`) or `--auto`; they stay in `/distill`, which keeps its own command file.
- Enabling OTel, or reviving the `reflection` event type's producer.
- Cross-repo signal aggregation (an out-of-scope follow-up the guardrails document already
  records).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Verbatim copy trips the record-versioning write hook. All three specs narrate their own draft history ("redefined by overlap resolution, not deletion", "inherits, in substance unchanged, the current `dream` section", "Phase 10 removes the now-duplicated copy", "pre-redefinition, historical"), and `core/**` is a deliverable tree where `rules/no-record-versioning-in-deliverables.md` and `rules/no-task-references-in-deliverables.md` both apply, enforced at write time by `hooks/validate-no-record-versioning.sh` and `hooks/validate-no-task-references.sh` | H | H | Phase 1 carries an explicit de-narration obligation: each relocated spec states the current charter only. The three MANDATORY STOP / exemption statements and the OTel + `reflection` caveats are substance, not draft history, and are preserved |
| The three specs are not self-sufficient at the new location (skeleton, Overlap Scoring, three-strikes, log paths, memory-index read, Agent tool) | H | H | Each of the six is a named task in Phase 1 or Phase 2, and Phase 5 verifies by invoking all three live |
| `deploy-headless.sh` does not prune deployed copies of deleted source files, leaving orphaned `.claude/context/project/memory/{telemetry-guardrails.md,patterns/distill-*-submode.md}` that `test-deploy-orphans.sh` flags | M | M | Phase 5 explicitly checks for and removes orphaned deployed files after redeploy, rather than assuming the installer prunes |
| Phase 4's memory-side edits collide with tasks 328 (`implementing` across memory `commands/` and `skills/`) and 435 (declares memory `context/` and `skills/`) | M | M | Edges already declared at the confirmation gate. Per the dispatch's concurrency note: re-read each memory file immediately before editing, stage only this task's own hunks by explicit file list, never a directory or glob add |
| Concurrent sibling 446 is dispatched this same cycle on this same tree | L | M | 446's declared `file_scope` (`plan-file-scope-harvest.sh`, `skill-base.sh`, `orchestrator-postflight.sh`, `git-commit-phase.sh`, `update-task-status.sh`, two test suites, `plan-format.md`, `git-staging-scope.md`, `phase-closure.md`, `general-implementation-agent.md`) is disjoint from every path in this plan. Treat an unexpected failure in any of those files as 446's in-flight edit, not a regression here |
| A new top-level `specs/telemetry/` directory is mistaken for a task directory by a specs walker | L | L | `specs/` already carries non-numeric siblings (`archive`, `decisions`, `reviews`, `literature`, `vault`, `tmp`); Phase 5's gate run covers `validate-state.sh` |
| `/telemetry` registered in `manifest.json` but unmentioned in core's `README.md` fails `check-extension-docs.sh` | M | M | Phase 2 edits `core/README.md` in the same phase as the manifest entry |
| Renaming `DISTILL_META_LOCAL` → `TELEMETRY_META_LOCAL` breaks a consumer | L | L | Verified: exactly one occurrence in the source store, inside the file being relocated |

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

### Phase 1: Author the Core-Owned Telemetry Content Set [COMPLETED]

**Goal**: Land the five new core markdown files — the three sub-mode specifications, the shared
guardrails document, and the `/telemetry` command file — each self-sufficient at its new
location and free of draft-history narration.

**Tasks**:

- [x] Create `agent-system/extensions/core/context/standards/telemetry-guardrails.md` from
      memory's copy. Retitle from "Telemetry Guardrails for Distill Sub-Modes" to "Telemetry
      Guardrails" (the document now serves two host commands). Keep all fifteen sections,
      including `## The No-New-Hygiene-Below-~100-Entries Constraint`, whose consumers are the
      memory extension's hygiene sub-modes citing this core copy. Update its
      `## Related Documentation` section's own outbound paths. *(completed)*
- [x] Create `agent-system/extensions/core/context/patterns/telemetry-review-submode.md` from
      `distill-review-submode.md`. Preserve the `## MANDATORY STOP Exemption (Stated, Not
      Omitted)` section and the four-tier access table including Tier 1's exact degraded string
      "OTel not enabled for this session/repo -- outcome evidence unavailable for this
      question." Repoint the skeleton citation at `skill-telemetry/SKILL.md`, the guardrails
      citation at `context/standards/telemetry-guardrails.md`, and the optional log destination
      at `specs/telemetry/review-log.json` (still optional, audit-only). *(completed)*
- [x] Create `agent-system/extensions/core/context/patterns/telemetry-dream-submode.md` from
      `distill-dream-submode.md`. Preserve its `## MANDATORY STOP Exemption (Stated, Not
      Omitted)` section. Inline the three-line `overlap_score = |segment_terms intersect
      memory_terms| / |segment_terms|` formula (read from
      `memory/skills/skill-learn/SKILL.md:188-198`) in place of the cross-extension
      `### Overlap Scoring` citation. Repoint the three-strikes citation at
      `context/contracts/convergence.md`'s `## Three-Strikes Rule` section. Make the
      existing-coverage check read `specs/TODO.md` unconditionally and
      `.memory/memory-index.json` only when that file is present. Move the log destination to
      `specs/telemetry/dream-log.json` and state that this log is the sole `--since` cursor,
      replacing the `memory_health.last_dream` / `dream_count` coupling. *(completed)*
- [x] Create `agent-system/extensions/core/context/patterns/telemetry-meta-submode.md` from
      `distill-meta-submode.md`. Drop the `validate-on-read` precondition from its Edge Case
      Checks (promotion frees it from the knowledge-store gate). Rename `DISTILL_META_LOCAL` to
      `TELEMETRY_META_LOCAL`, keeping `--local` as the primary opt-out and
      `CLAUDE_AGENT_GLOBAL_ROOT` / `$GLOBAL_ROOT` resolution unchanged (already core-owned via
      `commands/meta.md`, `agents/meta-builder-agent.md`, `skills/skill-meta/SKILL.md`). Repoint
      the three-strikes citation at `context/contracts/convergence.md`'s `## Three-Strikes Rule`
      section. Move the log destination to `specs/telemetry/meta-log.json`. Preserve the
      MANDATORY STOP, the confirmation gate, the `meta-builder-agent` delegation contract, the
      doc-edit-proposal rule, and the single-repo signal limitation verbatim in substance.
      *(completed)*
- [x] In that same file, replace the stale `meta-builder-agent.md` "Known limitation" quotation
      with fresh prose grounded in that agent's current `SCOPE BOUNDARY` section. Re-read
      `agent-system/extensions/core/agents/meta-builder-agent.md` first; the quoted text is
      absent from it today. Keep the behavioral point that `--meta` writes no extension-detection
      logic of its own and relies on the delegation contract's `AskUserQuestion` step for human
      correction. *(completed: text was already corrected in a prior commit from this planning
      cycle; relocation carried the already-fixed prose forward -- see the `win` issue-log entry)*
- [x] Carry the `reflection` producer-status caveat forward as a stated fact in
      `telemetry-meta-submode.md`: the event type has one historical record in this repo and no
      live producer (`context/formats/events-format.md`), so it must not be presented as a live
      input. *(completed)*
- [x] Create `agent-system/extensions/core/commands/telemetry.md`: frontmatter `description`,
      argument parsing for `--meta` / `--review "<question>"` / `--dream` plus `--dry-run`,
      `--verbose` and `--local`, a sub-mode availability table whose Section column anchors into
      `skill-telemetry/SKILL.md`, delegation to `skill-telemetry`, per-sub-mode result
      presentation, error handling with the three-flag availability message, and a State
      Management block listing the reads (`specs/events.jsonl` via `events-query.sh`,
      `~/.claude/history.jsonl`, transcripts, OTel when enabled) and writes
      (`specs/telemetry/*.json`; task directories only via `meta-builder-agent`). *(completed)*
- [x] De-narrate all five files: remove every sentence describing an earlier draft of the same
      content, every phase-number reference, and every "no longer / previously / redefined /
      pre-redefinition / inherits from the current X section" construction, per
      `rules/no-record-versioning-in-deliverables.md` and
      `rules/no-task-references-in-deliverables.md`. State each sub-mode's current charter
      directly. *(completed; verified via check-record-versioning.sh and
      check-task-references.sh, both 0 findings on all five new files)*

**Timing**: 2 hours

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: five new files is the hypothesis — one guardrails document, three sub-mode
specifications, one command file. Confirm at implementation time by re-reading the four memory
source files (`telemetry-guardrails.md`, `distill-{meta,review,dream}-submode.md`) and checking
that no further cross-reference inside them names a fifth memory file this phase must also
carry; if one does, report it rather than silently widening the phase.

**Tier Justification**: `suite_selection_select` returns `__FULL_SWEEP__` for all five paths
(measured), so no suite covers them and the honest check is sub-case (b) —
`bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
— alongside the `prose` row's diff read-through.

**Files to modify**:

- `agent-system/extensions/core/context/standards/telemetry-guardrails.md` - new; relocated
  guardrails document, retitled, outbound paths updated
- `agent-system/extensions/core/context/patterns/telemetry-review-submode.md` - new; `--review`
  specification with its exemption and OTel degraded path preserved
- `agent-system/extensions/core/context/patterns/telemetry-dream-submode.md` - new; `--dream`
  specification with the Overlap Scoring formula inlined and the coverage check made conditional
- `agent-system/extensions/core/context/patterns/telemetry-meta-submode.md` - new; `--meta`
  specification with validate-on-read dropped and the stale quotation rewritten
- `agent-system/extensions/core/commands/telemetry.md` - new; the `/telemetry` command file

**Verification**:

- All five files exist and are non-empty; each sub-mode spec opens with the
  "COMPLETE and ONLY specification" declaration naming its new path.
- `grep -rn "context/project/memory\|skill-distill\|\.memory/" agent-system/extensions/core/context/patterns/telemetry-*-submode.md agent-system/extensions/core/context/standards/telemetry-guardrails.md agent-system/extensions/core/commands/telemetry.md`
  returns only the deliberate conditional `.memory/memory-index.json` mention in
  `telemetry-dream-submode.md`.
- `grep -n "MANDATORY STOP Exemption" agent-system/extensions/core/context/patterns/telemetry-review-submode.md agent-system/extensions/core/context/patterns/telemetry-dream-submode.md`
  returns one hit each.
- `bash .claude/scripts/check-record-versioning.sh` and
  `bash .claude/scripts/check-task-references.sh` report no new findings for the five paths.
- `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
  is green (neither gate SKIPs, since this repo root is simultaneously the deploy consumer and
  the source store).

---

### Phase 2: Create `skill-telemetry` and Register the New Core Surface [COMPLETED]

**Goal**: Give the three relocated specifications an executable host and make the new command,
skill and context files reachable through core's manifest, context index, README and CLAUDE.md
merge source.

**Tasks**:

- [x] Create `agent-system/extensions/core/skills/skill-telemetry/SKILL.md` with frontmatter
      `name: skill-telemetry`, a `description` naming the three sub-modes, and
      `allowed-tools: Bash, Grep, Read, Write, Edit, AskUserQuestion, Agent` — the Agent tool is
      required by `--meta`'s `meta-builder-agent` delegation and is absent from
      `skill-distill`'s own frontmatter today. *(completed)*
- [x] State in that skill's body that it is a **direct-execution** skill invoked by the session
      that ran `/telemetry`, never dispatched as a subagent, because `AskUserQuestion` is
      categorically withheld from dispatched subagents (see
      `docs/reference/standards/agent-frontmatter-standard.md`'s "Tool Withholding from
      Dispatched Subagents") and `--meta`'s MANDATORY STOP depends on it. *(completed)*
- [x] Write the skill's `## Shared Sub-Mode Skeleton` section: the six-step telemetry-scoped
      shape (Edge Case Checks, Candidate Identification, Dry-Run, Interactive Selection
      (MANDATORY STOP), Execution, Log Entry), omitting the vault-specific Batch Index
      Regeneration step that all three relocated specs already mark "Not applicable". State the
      two sanctioned exemptions explicitly: `--review` and `--dream` carry no mutation gate
      because neither mutates; `--meta` does. *(completed)*
- [x] Add the skill's `### Sub-Mode: meta|review|dream` stub pointers, each reading
      `READ .claude/context/patterns/telemetry-<name>-submode.md now and follow it exactly.`,
      plus a Sub-Mode Dispatch table and a `## Context References` block citing
      `@.claude/context/standards/telemetry-guardrails.md`, `@.claude/scripts/events-query.sh`
      and `@.claude/context/contracts/convergence.md`. *(completed)*
- [x] Add a `## Telemetry Log Schemas` section carrying the `meta-log.json` and `dream-log.json`
      shapes verbatim in substance from the relocated specs, at their new `specs/telemetry/`
      paths, plus the optional `review-log.json` note. Include the "no events yet" and "OTel not
      enabled" degraded-path outcomes as normal results, not errors. *(completed)*
- [x] Register in `agent-system/extensions/core/manifest.json`: append `"telemetry.md"` to
      `provides.commands` and `"skill-telemetry"` to `provides.skills`. `provides.context`
      already covers `patterns` and `standards`, so no entry is needed there — verify that before
      concluding it. *(completed: confirmed provides.context already lists both; no third
      append made)*
- [x] Add four entries to `agent-system/extensions/core/index-entries.json` (schema per the
      existing entries: `path`, `domain: "core"`, `subdomain`, `summary`, `line_count`,
      `keywords`, `topics`, `load_when`, `on_demand`) for
      `standards/telemetry-guardrails.md` and `patterns/telemetry-{meta,review,dream}-submode.md`.
      Set `line_count` from the actual files written in Phase 1, not an estimate. *(completed)*
- [x] Mention `/telemetry` in `agent-system/extensions/core/README.md`'s command coverage —
      `check-extension-docs.sh` fails a command that is listed in `manifest.json` but unmentioned
      in `README.md`. *(completed)*
- [x] Add `/telemetry` to the Command Reference table in
      `agent-system/extensions/core/merge-sources/claudemd.md`, and add a
      `skill-telemetry | (direct execution)` row to its Skill-to-Agent Mapping table.
      *(completed; deviation: altered -- ran verify-deploy.sh --skip-slow --only-gate 3,4 plus
      targeted lint/JSON checks instead of the unscoped full run, deferred to batch-end due to
      measured concurrent gate contention; see issue log)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: full

**Scope Hypothesis**: four new `index-entries.json` entries and exactly two `manifest.json`
array appends is the hypothesis. Confirm by re-reading `provides.context` immediately before
editing — if `patterns` or `standards` is absent from it (it was present at plan time), a third
manifest append is required, and that discovery should be reported, not absorbed silently.

**Tier Justification**: `manifest.json` plus `index-entries.json` change what
`deploy-headless.sh` emits into every consuming repo's `.claude/` tree and what every context
index consumer resolves — the deploy pipeline's own global-config surface, which no cheaper tier
reaches, since a narrowing that covered the skill body would miss the manifest and index schema
and vice versa.

**Files to modify**:

- `agent-system/extensions/core/skills/skill-telemetry/SKILL.md` - new; direct-execution host
  with the telemetry sub-mode skeleton, stub pointers and log schemas
- `agent-system/extensions/core/manifest.json` - register `telemetry.md` and `skill-telemetry`
- `agent-system/extensions/core/index-entries.json` - four new context-index entries
- `agent-system/extensions/core/README.md` - mention `/telemetry`
- `agent-system/extensions/core/merge-sources/claudemd.md` - command-table and
  skill-mapping rows

**Verification**:

- `python3 -c "import json; json.load(open('agent-system/extensions/core/manifest.json'))"` and
  the same for `index-entries.json` both parse.
- `bash .claude/scripts/check-extension-docs.sh` reports no missing-README-mention finding for
  `telemetry.md`.
- `bash .claude/scripts/verify-deploy.sh` is green (this phase's cross-cutting registration
  surface is the declared `full` tier).

---

### Phase 3: Repoint Every Cross-Extension Guardrails Citation [COMPLETED]

**Goal**: Make every file outside memory's `/distill` surface that cites
`context/project/memory/telemetry-guardrails.md` or the three old sub-mode basenames resolve
against the new core paths.

**Tasks**:

- [x] Re-read each file immediately before editing (concurrent siblings are live on this tree),
      then repoint `agent-system/extensions/core/context/formats/dispatch-metrics.md`'s three
      guardrails citations to `context/standards/telemetry-guardrails.md`. *(completed)*
- [x] Repoint `agent-system/extensions/core/context/formats/events-format.md`'s three guardrails
      citations, and drop the "in the memory extension" qualifier that accompanies two of them —
      the document is core-owned after this move. *(completed; also fixed a resulting
      index-entries.json line_count drift mechanically)*
- [x] Repoint `agent-system/extensions/books/context/project/books/patterns/books-review-submode.md`'s
      single guardrails citation. *(completed)*
- [x] Repoint `agent-system/extensions/books/context/project/books/patterns/books-revise-submode.md`'s
      single guardrails citation **and** its five `distill-meta-submode.md` references (lines 11,
      84, 239, 247, 265 at plan time) to `context/patterns/telemetry-meta-submode.md`. *(completed;
      also fixed a resulting index-entries.json line_count drift mechanically)*
- [x] Repoint `agent-system/extensions/memory/context/project/memory/patterns/distill-learn-submode.md`'s
      single guardrails citation at the core path. A memory-extension file citing a core file is
      the correct direction: core is the permanent extension. *(completed)*
- [x] Repoint `agent-system/extensions/memory/context/project/memory/patterns/distill-revise-submode.md`'s
      four guardrails citations, and its `distill-meta-submode.md` reference, at the core paths.
      Leave its own `## Classification` three-strikes prose as-is — it is `--revise`'s own
      content and already cites `context/contracts/convergence.md` correctly. *(completed;
      deviation: altered -- found TWO distill-meta-submode.md references, not the one the plan's
      Scope Hypothesis counted (lines 10 and 230 at plan time); repointed both, see issue log)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: prose

**Scope Hypothesis**: six files and sixteen citations is the hypothesis (3 + 3 + 1 + 1+5 + 1 +
4+1, counted by grep at plan time). Confirm by re-running
`grep -rn "telemetry-guardrails\|distill-meta-submode\|distill-review-submode\|distill-dream-submode" agent-system/`
immediately before and after the phase; the before-count must match the hypothesis or the
discrepancy must be reported.

**Tier Justification**: every touched path is guidance markdown with no executable surface and
`suite_selection_select` returns `__FULL_SWEEP__` over the phase's touched path set (measured),
so no suite covers it and the honest check is sub-case (b) —
`bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
— alongside the `prose` row's diff read-through.

**Files to modify**:

- `agent-system/extensions/core/context/formats/dispatch-metrics.md` - three guardrails paths
- `agent-system/extensions/core/context/formats/events-format.md` - three guardrails paths plus
  the "in the memory extension" qualifier
- `agent-system/extensions/books/context/project/books/patterns/books-review-submode.md` - one
  guardrails path
- `agent-system/extensions/books/context/project/books/patterns/books-revise-submode.md` - one
  guardrails path and five `telemetry-meta-submode.md` references
- `agent-system/extensions/memory/context/project/memory/patterns/distill-learn-submode.md` -
  one guardrails path
- `agent-system/extensions/memory/context/project/memory/patterns/distill-revise-submode.md` -
  four guardrails paths and one `telemetry-meta-submode.md` reference

**Verification**:

- `grep -rn "context/project/memory/telemetry-guardrails" agent-system/` returns zero hits.
- `grep -rn "distill-meta-submode\|distill-review-submode\|distill-dream-submode" agent-system/`
  returns hits only inside the memory files Phase 4 edits or deletes.
- `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
  is green (neither gate SKIPs from this repo root).

---

### Phase 4: Retire the Three Sub-Modes from the Memory Extension Surface [COMPLETED]

**Goal**: Reduce `/distill` to its nine remaining sub-modes, point its documentation at
`/telemetry` for the three that moved, and delete the four relocated source files.

**Tasks**:

- [x] Re-read every file in this phase immediately before editing. Tasks 328 (`implementing`
      across memory `commands/` and `skills/`) and 435 (declares memory `context/` and
      `skills/`) are live on these same directories; stage only this task's own hunks with an
      explicit file list, never a directory or glob `git add`. *(completed)*
- [x] Edit `agent-system/extensions/memory/commands/distill.md`: remove `--meta`, `--review` and
      `--dream` from the Sub-Mode Dispatch list, the parsing pseudocode, the availability table,
      the Present Results block, the Error Handling flag lists, and the State Management
      reads/writes. Change "12 sub-modes" to nine throughout. Add a one-line pointer that those
      three now live at `/telemetry --meta|--review|--dream`. *(completed)*
- [x] Edit `agent-system/extensions/memory/skills/skill-distill/SKILL.md`: delete the three
      `### Sub-Mode: meta|review|dream` stub pointers and their Sub-Mode Dispatch table rows;
      update the header paragraph and frontmatter `description` to name only the remaining
      sub-modes; repoint its `## Context References` guardrails path at the core copy; amend the
      Shared Sub-Mode Skeleton's non-mutating-sub-mode paragraph so it names `report` (and
      `auto`) without citing `distill-review-submode.md`; and update the `## State Integration`
      field-update table and the Distill Log Schema's `review` note to drop the three departed
      sub-modes. *(completed; also fixed a pre-existing stale "--review" mention in auto's own
      inline spec and dropped the now-orphaned last_dream/dream_count memory_health coupling)*
- [x] Edit `agent-system/extensions/memory/context/project/memory/distill-usage.md`: remove the
      `### Meta`, `### Review` and `### Dream` sections, their Quick Reference lines, their
      "when to use" table rows and their log-file table rows; repoint the guardrails citation at
      the core copy; add a pointer line naming `/telemetry` as their host. *(completed; also
      fixed a resulting index-entries.json line_count drift mechanically)*
- [x] Edit `agent-system/extensions/memory/README.md` and
      `agent-system/extensions/memory/skills/skill-distill/README.md`: repoint the guardrails
      citation at the core copy and reduce "the five telemetry-sourced sub-modes" to the two that
      remain (`--revise`, `--learn`). *(completed)*
- [x] Edit `agent-system/extensions/memory/EXTENSION.md`'s `/distill` command-table row to name
      the nine remaining sub-modes. *(completed)*
- [x] Remove the four stale entries from
      `agent-system/extensions/memory/index-entries.json`:
      `project/memory/telemetry-guardrails.md` and
      `project/memory/patterns/distill-{dream,review,meta}-submode.md`. *(completed)*
- [x] Delete `agent-system/extensions/memory/context/project/memory/patterns/distill-meta-submode.md`,
      `distill-review-submode.md`, `distill-dream-submode.md`, and
      `agent-system/extensions/memory/context/project/memory/telemetry-guardrails.md`.
      *(completed; deviation: altered -- ran verify-deploy.sh --skip-slow --only-gate 3,4 plus
      targeted lint/grep/JSON checks instead of the unscoped full run, deferred to batch-end due
      to measured concurrent gate contention; see issue log)*

**Timing**: 2 hours

**Depends on**: 2, 3

**Verification Tier**: full

**Scope Hypothesis**: seven files edited and four deleted is the hypothesis, and `/distill`
retains exactly nine sub-modes afterward. Confirm by grepping each edited file for the three
flag names after the edits and by counting the Sub-Mode Dispatch table rows in
`skill-distill/SKILL.md`; report any additional memory file that still names one of the three.

**Tier Justification**: removing three sub-modes from `/distill`'s dispatch surface changes the
memory extension's context-index registration, its README/EXTENSION tables and the
`skill-distill` skill body simultaneously, and deletes four registered context files — a
cross-extension deploy-surface change that no narrowing covering one of those classes also
covers for the others.

**Files to modify**:

- `agent-system/extensions/memory/commands/distill.md` - nine sub-modes; pointer to `/telemetry`
- `agent-system/extensions/memory/skills/skill-distill/SKILL.md` - stub pointers, dispatch
  table, skeleton exemption paragraph, State Integration table, guardrails path
- `agent-system/extensions/memory/context/project/memory/distill-usage.md` - remove the three
  sections and their table rows; guardrails path
- `agent-system/extensions/memory/README.md` - guardrails path; two remaining
  telemetry-sourced sub-modes
- `agent-system/extensions/memory/skills/skill-distill/README.md` - guardrails path; two
  remaining telemetry-sourced sub-modes
- `agent-system/extensions/memory/EXTENSION.md` - `/distill` command-table row
- `agent-system/extensions/memory/index-entries.json` - remove four entries
- `agent-system/extensions/memory/context/project/memory/patterns/distill-meta-submode.md` -
  delete
- `agent-system/extensions/memory/context/project/memory/patterns/distill-review-submode.md` -
  delete
- `agent-system/extensions/memory/context/project/memory/patterns/distill-dream-submode.md` -
  delete
- `agent-system/extensions/memory/context/project/memory/telemetry-guardrails.md` - delete

**Verification**:

- `grep -rn -- "--meta\|--review\|--dream" agent-system/extensions/memory/` returns only the
  deliberate `/telemetry` pointer lines.
- `grep -rn "distill-meta-submode\|distill-review-submode\|distill-dream-submode\|context/project/memory/telemetry-guardrails" agent-system/`
  returns zero hits across the whole source store.
- `python3 -c "import json; json.load(open('agent-system/extensions/memory/index-entries.json'))"`
  parses and the four paths are absent.
- `bash .claude/scripts/verify-deploy.sh` is green (this phase's declared `full` tier).

---

### Phase 5: Redeploy, Prune Orphans, and Verify All Three Sub-Modes Live [COMPLETED]

**Goal**: Regenerate the deployed tree, confirm no orphaned deployed copies of the deleted
source files remain, and demonstrate end to end that each relocated sub-mode is invocable at its
new location and produces its documented output shape against this repo's real data.

**Tasks**:

- [x] Redeploy the source store with the bounded-wait idiom required by
      `context/patterns/external-process-wait.md` Rule 1:
      `timeout 540 bash .claude/scripts/deploy-headless.sh`, with the Bash tool's `timeout`
      parameter raised to 600000. The dispatch's deploy-freshness context already reports core
      as stale, so this also clears a pre-existing divergence. *(completed; ran twice -- first
      pass surfaced orphans, second pass confirmed clean)*
- [x] Confirm the deployed tree gained `.claude/commands/telemetry.md`,
      `.claude/skills/skill-telemetry/SKILL.md`,
      `.claude/context/standards/telemetry-guardrails.md` and
      `.claude/context/patterns/telemetry-{meta,review,dream}-submode.md`. *(completed)*
- [x] Check for orphaned deployed copies of the four deleted source files
      (`.claude/context/project/memory/telemetry-guardrails.md`,
      `.claude/context/project/memory/patterns/distill-{meta,review,dream}-submode.md`). If
      `deploy-headless.sh` did not prune them, remove them explicitly — do not leave them for
      `test-deploy-orphans.sh` to flag. *(completed: deploy-headless.sh did not prune them;
      removed explicitly, plus their ghost rows in the deployed context/index.json aggregate,
      which cleared on the second redeploy pass)*
- [x] Run `/telemetry --meta` against this repo and confirm it surfaces the handoff-schema
      cluster the dispatch describes (the `dispatch_status`-instead-of-`status` off-schema
      writes and the "handoff mtime predates this dispatch window" occurrences), demonstrating
      the signal path works at the new location. Use `--dry-run` so no task is created, and
      access Tier 2 only through `bash .claude/scripts/events-query.sh`, never hand-rolled `jq`.
      *(completed: live run confirmed 23 handoff-mtime-predates-window occurrences, 4
      dispatch_status off-schema, 3 dispatch_seq mismatches, attributing to
      skill-orchestrate/SKILL.md and general-implementation-agent.md)*
- [x] Run `/telemetry --dream` against this repo and confirm it reads
      `~/.claude/history.jsonl`, slices by the `project` field, and produces the documented
      surfacing output shape. Confirm its MANDATORY STOP exemption is stated in the output.
      *(completed: live history.jsonl slice, 4273 prompts for this repo, confirmed the
      batch-dependency-auditing theme with no existing TODO.md coverage; logged a real operation
      to specs/telemetry/dream-log.json)*
- [x] Run `/telemetry --review "<question>"` and confirm it (a) answers in prose with per-tier
      evidence citations, (b) announces the Tier 1 degraded path explicitly as "OTel not enabled
      for this session/repo -- outcome evidence unavailable for this question." rather than
      silently omitting it, and (c) states its MANDATORY STOP exemption and its funnel rule.
      *(completed: confirmed OTel unset on this machine; announced the exact required degraded
      path string; logged optional audit entry to specs/telemetry/review-log.json)*
- [x] Confirm `specs/telemetry/` was created with the expected log file(s) in the documented
      shape, and that nothing was written under `.memory/` by any of the three runs.
      *(completed; both log files parse, .memory/ dirty state pre-dates this dispatch)*
- [x] Run the complete gate set and resolve any finding by fixing forward in the source store,
      never by hand-patching `.claude/**`.
      *(completed; deviation: altered -- ran verify-deploy.sh --skip-slow --only-gate 3,4,13
      instead of the unscoped full run, deferred to batch-end per this phase's own named Batch
      Gate Deferral directive; 3 unrelated pre-existing/concurrent findings (eager-budget,
      shellcheck in lean, dead-command-recommendation in memory-setup.md/
      memory-troubleshooting.md) surfaced during two earlier unscoped attempts and recorded in
      the issue log rather than fixed here -- see issue log)*

**Timing**: 1.5 hours

**Depends on**: 4

**Verification Tier**: full

**Scope Hypothesis**: the deployed tree is expected to gain exactly six new files (the command,
the skill, the guardrails document and the three sub-mode specifications) and to require pruning
of exactly four orphans (the deleted memory copies). Confirm by listing the deployed paths after
redeploy rather than assuming the counts; a mismatch in either direction means a registration
step in Phase 2 or a deletion in Phase 4 did not land, and must be reported before the gate run
rather than patched in the deployed tree.

**Files to modify**:

- `__WHOLE_TREE__` - this phase invokes `deploy-headless.sh`, which regenerates the entire
  deployed `.claude/` tree
- `specs/telemetry/` - created by the live sub-mode runs (`meta-log.json`, `dream-log.json`, and
  optionally `review-log.json`)

**Verification**:

- `bash .claude/scripts/verify-deploy.sh` — the complete gate set, including Gate 8's full
  shell-suite battery, `check-deploy-freshness.sh`, `check-extension-docs.sh`,
  `check-record-versioning.sh`, `check-task-references.sh`, `context-reachability.sh` and
  `validate-state.sh` — is green with no `--skip-slow` and no `--only-gate` narrowing.
- All three sub-modes ran and produced their documented output shapes; `--meta` surfaced the
  handoff-schema cluster; `--review` announced the OTel degraded path explicitly.
- `grep -rn "distill-meta-submode\|distill-review-submode\|distill-dream-submode\|context/project/memory/telemetry-guardrails" agent-system/ .claude/`
  returns zero hits in both trees.
- `grep -rn "MANDATORY STOP Exemption" .claude/context/patterns/telemetry-review-submode.md .claude/context/patterns/telemetry-dream-submode.md`
  returns one hit each in the deployed tree.

---

## Testing & Validation

- [ ] Each of the three sub-modes is invocable as `/telemetry --meta`,
      `/telemetry --review "<question>"` and `/telemetry --dream`, and produces its documented
      output shape against this repo's real `specs/events.jsonl` and `~/.claude/history.jsonl`.
- [ ] `/telemetry --meta` surfaces the handoff-schema cluster described in the task description,
      demonstrating the signal path end to end at the new core location.
- [ ] `/telemetry --review` with OTel absent takes the stated degraded path and says so
      explicitly rather than silently.
- [ ] No reference anywhere in the source store (or the deployed tree) points at the old
      memory-extension paths for the three sub-mode files or for `telemetry-guardrails.md`.
- [ ] Both MANDATORY STOP exemptions (`--review`, `--dream`) are explicitly stated in the
      relocated specifications.
- [ ] `/distill` still offers its nine remaining sub-modes and nothing in the memory extension
      is required for the three relocated ones to run.
- [ ] No relocated core file narrates its own draft history or cites a task or phase number
      (`check-record-versioning.sh`, `check-task-references.sh`).
- [ ] `bash .claude/scripts/verify-deploy.sh` is green with no narrowing flags.

## Artifacts & Outputs

- `agent-system/extensions/core/commands/telemetry.md`
- `agent-system/extensions/core/skills/skill-telemetry/SKILL.md`
- `agent-system/extensions/core/context/standards/telemetry-guardrails.md`
- `agent-system/extensions/core/context/patterns/telemetry-meta-submode.md`
- `agent-system/extensions/core/context/patterns/telemetry-review-submode.md`
- `agent-system/extensions/core/context/patterns/telemetry-dream-submode.md`
- Updated `agent-system/extensions/core/{manifest.json,index-entries.json,README.md,merge-sources/claudemd.md}`
- Reduced memory `/distill` surface (nine sub-modes) with four source files deleted
- Repointed guardrails citations in core, books and memory
- A regenerated deployed `.claude/` tree
- `specs/telemetry/{meta,dream}-log.json` (and optionally `review-log.json`) created by the
  live verification runs

## Rollback/Contingency

All work is confined to tracked source-store files plus a regenerated, gitignored deploy tree,
so rollback is a git revert of this task's own scoped commits followed by one redeploy. Before
any rollback that would otherwise be blocked by `guard-destructive-git.sh`, take a snapshot
first: `bash .claude/scripts/git-snapshot.sh 497`. Concurrent siblings are live on this tree, so
never use `git-snapshot.sh` in its reverting default mode as a routine checkpoint — use
`--no-revert` for an ordinary defensive checkpoint.

Per-phase contingencies:

- **Phase 1 or 3 partially applied**: harmless on its own. The new core files are unreferenced
  until Phase 2 registers them, and the repointed citations in Phase 3 resolve as soon as
  Phase 1's guardrails file exists.
- **Phase 2 applied, Phase 4 not**: both `/distill --meta|--review|--dream` and
  `/telemetry --meta|--review|--dream` resolve. This is a safe resting state, not a broken one;
  the duplication is removed by Phase 4.
- **Phase 4 applied but Phase 5's live verification fails**: the three sub-modes are reachable
  only via `/telemetry`, so a defect there is user-visible. Fix forward in the source store and
  redeploy; do not hand-patch `.claude/**`, which the next regeneration would wipe.
- **A deleted file is still needed**: recover it from git history rather than re-authoring it,
  then repoint rather than re-duplicate.
