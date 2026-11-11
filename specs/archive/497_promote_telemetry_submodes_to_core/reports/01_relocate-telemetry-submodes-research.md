# Research Report: Task #497

**Task**: 497 - Promote telemetry sub-modes to core
**Started**: 2026-11-09T00:00:00Z
**Completed**: 2026-11-09T00:00:00Z
**Effort**: medium
**Dependencies**: None (re-sequences 421 to depend on this task; see dispatch's "Relation to Existing Records")
**Sources/Inputs**: - Codebase (agent-system/extensions/memory/**, agent-system/extensions/core/**), live `specs/events.jsonl` via `events-query.sh`, live `~/.claude/history.jsonl`, environment/settings inspection for OTel
**Artifacts**: - specs/497_promote_telemetry_submodes_to_core/reports/01_relocate-telemetry-submodes-research.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The dispatch's framing ("mechanical, not a rewrite... no dependency untangling required") holds
  for `events-query.sh` (already in core, verified live) but is **incomplete** for two other
  shared dependencies: the `### Overlap Scoring` formula (`--dream` cites it, but it is only
  defined in `skill-learn/SKILL.md`, which stays in memory) and the three-strikes recurrence
  threshold (`--meta`/`--dream` cite "`--revise`'s Classification step," but `--revise` stays in
  memory too). Both are small and mechanically fixable, but must be explicitly addressed in the
  plan — see Findings and Risks below.
- `telemetry-guardrails.md` is a **shared** dependency of all five telemetry-sourced sub-modes
  (the 3 relocating plus `--revise`/`--learn`, which stay in memory). Its content is generically
  about telemetry-consumption discipline, not vault internals, except one section. Recommend
  relocating it wholesale to core, with the two staying sub-modes referencing the core copy.
- There is **no existing core command for `--review` or `--dream`**, and core already owns a
  `/review` command with an unrelated meaning (codebase review), so a bare `/review` name
  collides. `--meta`'s job (propose a task, delegate to `meta-builder-agent`) strongly overlaps
  the existing `/meta` command's own job, making it the natural host for a new flag rather than a
  new command. These invocation-surface questions are unresolved by the dispatch and must be
  decided at plan time; this report lays out the options with a recommendation.
- Live verification against this repo's real `specs/events.jsonl` (now 7,998 events, up from the
  dispatch's 7,586) and `~/.claude/history.jsonl` (31,901 lines) confirms the signal clusters the
  dispatch describes are real and current, and confirms the OTel-absent and `reflection`-dead-
  signal caveats are accurate as stated.
- One quoted cross-reference in `distill-meta-submode.md` (attributed to `meta-builder-agent.md`'s
  "Known limitation") no longer matches that file's current text — a pre-existing drift the
  relocation should correct rather than carry forward verbatim.

## Context & Scope

Researched what is required to relocate the `/distill` sub-modes `--meta`, `--review`, and
`--dream` from the memory extension (`agent-system/extensions/memory/**`) into core
(`agent-system/extensions/core/**`), per the dispatch's framing: purely mechanical relocation, no
retargeting/redesign, preserving the stated `MANDATORY STOP` exemptions for `--review`/`--dream`
and the OTel-absent/`reflection`-dead-signal caveats. Scope was: (1) locate every file in the
memory extension that defines or is cited by the three sub-modes, (2) determine which of those
dependencies already exist in core vs. need relocation/duplication, (3) check for naming or
command-surface collisions with existing core commands, (4) verify the dispatch's live-data
claims against the repo's actual `events.jsonl`/`history.jsonl`/OTel-environment state.

## Findings

### Codebase Patterns

**Where the three sub-modes currently live** (all under `agent-system/extensions/memory/`):

- `commands/distill.md` — the `/distill` command file; argument parsing lists all 12 sub-modes
  (`report`/`purge`/`merge`/`compress`/`refine`/`gc`/`auto`/`revise`/`meta`/`review`/`learn`/
  `dream`) and delegates to `skill-distill` for all of them.
- `skills/skill-distill/SKILL.md` — contains the "Shared Sub-Mode Skeleton" (the 7-step shape
  every mutating sub-mode follows, plus the two stated exemptions for non-mutating sub-modes),
  the "Distill Log Schema" and "State Integration" tables (both describe all 12 sub-modes, not
  just the 3 relocating), and three one-line stub pointers:
  `### Sub-Mode: meta` / `### Sub-Mode: review` / `### Sub-Mode: dream`, each reading
  `READ .claude/context/project/memory/patterns/distill-<name>-submode.md now and follow it
  exactly.`
- `context/project/memory/patterns/distill-meta-submode.md`,
  `distill-review-submode.md`, `distill-dream-submode.md` — the full, self-contained
  specifications (per `context/patterns/mode-gated-section-loading.md`, already resident in
  core). These are the primary relocation payload.
- `context/project/memory/telemetry-guardrails.md` — shared design-constraints doc cited by
  name from **all five** telemetry-sourced sub-modes, not only the three relocating
  (`--revise` and `--learn`, which stay in memory per the dispatch's explicit non-goals, also
  cite it).
- `skills/skill-learn/SKILL.md` — defines `### Overlap Scoring` (a 3-line keyword-overlap
  formula: `|segment_terms ∩ memory_terms| / |segment_terms|`), used directly by `skill-learn`'s
  own memory-dedup logic and cited by name from `--dream`'s Candidate Identification section
  ("reuse the existing `### Overlap Scoring` formula by name -- do not restate or fork it").

**What already exists in core (no relocation needed, verified present)**:

- `agent-system/extensions/core/scripts/events-query.sh` — the mandated Tier-2 access path for
  all three sub-modes. Ran it live via the deployed copy (`.claude/scripts/events-query.sh`,
  **not** the source-store path directly — invoking it from
  `agent-system/extensions/core/scripts/` fails fast with a clear "must run from a deployed
  scripts/ tree" error, which is itself a useful fact for whoever verifies this relocation).
  Confirmed live output: `{"total_events":7998,"by_category":{"blocker":2,"deviation":104,
  "milestone":6997,"success":895},...}`.
- `agent-system/extensions/core/context/patterns/mode-gated-section-loading.md` — the extraction
  convention the three pattern files already follow.
- `agent-system/extensions/core/context/contracts/convergence.md` — holds the actual canonical
  three-strikes/Divergence-Audit precedent that `--revise`'s own Classification step (in memory)
  merely cites by name. This matters for Risk #2 below.
- `agent-system/extensions/core/context/formats/events-format.md` — the OTel ↔ `events.jsonl`
  seam contract and the `reflection` producer-status note.
- `agent-system/extensions/core/agents/meta-builder-agent.md` — the delegation target for
  `--meta`'s task creation, and already the delegation target for the **existing** `/meta`
  command (see Risk #4 below for the naming/surface-overlap implication).
- `agent-system/extensions/core/commands/review.md` — an **existing** `/review` command with an
  unrelated meaning ("Analyze codebase, identify issues, and optionally create tasks for fixes");
  see Risk #3.

### External Resources

Not applicable — this is a purely internal codebase relocation with no external library or API
surface involved.

## Recommendations

1. **Relocate the three pattern files verbatim** to
   `agent-system/extensions/core/context/project/...` (or wherever core's analogous
   `context/project/` tree for cross-cutting telemetry content should live — core has no
   existing `context/project/telemetry/` directory; `context/patterns/` or a new
   `context/project/telemetry/` subtree are both plausible destinations and should be chosen at
   plan time for consistency with core's existing layout), updating the two stale internal
   cross-references identified in Risks #1 and #2 as part of the move (not left as dangling
   memory-extension pointers).
2. **Relocate `telemetry-guardrails.md` to core wholesale**, since none of its content is vault-
   internals-specific except the "No-New-Hygiene-Below-~100-Entries" section (which concerns the
   seven hygiene sub-modes staying in memory). Recommend either dropping that one section from
   the core copy or leaving it as a harmless historical note; either way, `--revise`/`--learn`
   (staying in memory) should cite the core copy going forward — an acceptable cross-extension
   reference because core is the permanent extension, never subject to retirement.
3. **Duplicate (not reference) the `### Overlap Scoring` formula** into whichever core document
   hosts the relocated `--dream` spec. It is three lines, fully generic (a Jaccard-style term-set
   overlap ratio), and already duplicated in spirit between `skill-learn/SKILL.md` and the old
   `--dream`/`--revise` sections per the existing memory-extension pattern-file prose itself. Do
   not leave `--dream` pointing cross-extension at `skill-learn/SKILL.md`.
4. **Repoint the three-strikes citation at `context/contracts/convergence.md` directly**, not at
   `--revise`'s own Classification step. This is strictly more correct after relocation: the
   canonical definition already lives in core, and `--revise`'s own table was itself only a
   sibling citation of that same precedent, not its origin.
5. **Resolve the invocation-surface question explicitly at plan time** (see Risk #3/#4) rather
   than defaulting silently to "keep `/distill --meta|--review|--dream`" — the dispatch's
   Verification criteria require the sub-modes to be "invocable after relocation" but do not
   mandate preserving the current command syntax, and the current `/distill` command file itself
   stays owned by memory (whose retirement is a separate future task), so an entry point that
   depends on that file surviving does not fully achieve "survive the memory extension's
   retirement" on its own.
6. **Re-verify, not carry forward, the `meta-builder-agent.md` quotation** in
   `distill-meta-submode.md`'s Candidate Identification section (see Risk #5) — write fresh
   prose grounded in the agent's current "SCOPE BOUNDARY" text rather than relocating a quote
   that no longer matches its source.

## Decisions

- Scope boundary confirmed: this research treats `--revise` and `--learn` as explicitly out of
  scope for relocation (per the dispatch's non-goals), but treats `telemetry-guardrails.md` and
  the `### Overlap Scoring` formula as in-scope *supporting* relocations/duplications, since
  `--dream` cannot function at its new core location without one of the two remedies in
  Recommendations #2/#3 — this is support for the mechanical relocation, not a redesign of any
  sub-mode's behavior.
- Verified live that `CLAUDE_CODE_ENABLE_TELEMETRY` is unset both in the process environment and
  in every reachable settings file on this machine, confirming the dispatch's OTel-absent caveat
  is accurate today, not speculative.
- Verified live that the `reflection` event type has exactly one record in this repo's
  `events.jsonl`, matching the dispatch's "dead signal" caveat exactly.

## Risks & Mitigations

1. **`--dream`'s `### Overlap Scoring` dependency is cross-extension and would break on memory's
   retirement.** The formula is defined only in `skill-learn/SKILL.md` (memory, not relocating).
   *Mitigation*: duplicate the 3-line formula into the relocated `--dream` spec (Recommendation
   #3) — low-risk since it is fully generic and already treated as a reusable primitive, not
   vault-specific logic.
2. **`--meta`/`--dream`'s three-strikes threshold is cited via `--revise`'s own Classification
   step (memory, not relocating), not via its actual canonical source.** *Mitigation*: repoint
   both citations at `context/contracts/convergence.md` (already in core) directly
   (Recommendation #4) — this is a correction, not a new dependency.
3. **Naming collision: core already has a `/review` command with an unrelated meaning**
   ("Analyze codebase, identify issues, and optionally create tasks for fixes" — mutating,
   creates tasks). The telemetry `--review` sub-mode is strictly read-only and answers free-text
   questions over four telemetry tiers — a different domain entirely. A bare new `/review`
   command, or folding it as a flag onto the existing `/review`, would conflate two unrelated
   concepts under one name. *Mitigation*: the plan phase must pick a distinct command name (or a
   namespaced flag on a different, non-colliding host) for the relocated `--review`; this report
   does not decide it, since doing so would exceed "relocation, not redesign."
4. **`--meta`'s job overlaps the existing `/meta` command's own job** (both: surface a candidate,
   confirm via `AskUserQuestion`, delegate task creation to `meta-builder-agent`, same
   `task_type: "meta"` outcome shape). This is a strong signal that the relocated `--meta` could
   become a new flag on the *existing* `/meta` command (e.g. a telemetry-signal-sourced entry
   point alongside the existing interactive-interview/prompt-analysis entry points) rather than a
   new command — but this is also a design choice with user-facing consequences (argument-hint
   changes, a fourth mode added to an already-documented reference-implementation command) that
   the plan phase, not this research, should decide.
5. **A quoted cross-reference has already drifted.** `distill-meta-submode.md`'s Candidate
   Identification section quotes `meta-builder-agent.md`'s "Known limitation" verbatim
   ("has no reliable signal to distinguish core scope from an extension's own source directory
   ... without parsing extension manifests, so extension-scoped tasks require human correction
   rather than a guess"). That exact text is **absent** from the current
   `agent-system/extensions/core/agents/meta-builder-agent.md`; the file's current "SCOPE
   BOUNDARY" section describes a file-scope-naming requirement instead, not a confessed
   detection-limitation disclaimer. *Mitigation*: Recommendation #6 — write fresh prose at
   relocation time rather than copying a now-stale quotation forward.
6. **No remaining-references check has been run yet** (the dispatch's Verification item "No
   remaining reference anywhere in the source store points at the old memory-extension paths for
   these three files" is an implementation-time check, not something this research phase can
   satisfy before the files move). Flagging it here so the plan explicitly includes a grep sweep
   (`grep -rn "distill-meta-submode\|distill-review-submode\|distill-dream-submode"
   agent-system/`) as a post-move verification step.

## Context Extension Recommendations

- **Topic**: Core's `context/project/` tree has no existing home for cross-cutting
  telemetry-consumption guardrails (the kind `telemetry-guardrails.md` provides).
- **Gap**: If `telemetry-guardrails.md` relocates to core per Recommendation #2, core currently
  has no established directory convention for this content (unlike memory's
  `context/project/memory/`). `context/patterns/` (generic, process-shaped) or a new
  `context/project/telemetry/` (domain-shaped, mirroring other extensions' `context/project/*`
  convention) are the two live options.
- **Recommendation**: decide the destination directory as part of the implementation plan for
  this task, consistent with core's existing `context/` subdirectory taxonomy (see
  `agent-system/extensions/core/context/` top-level listing: `architecture/`, `contracts/`,
  `formats/`, `guides/`, `patterns/`, `reference/`, `standards/`, etc. — none of which is an
  obvious drop-in fit, since this content is neither a architecture doc, a contract, a format
  spec, nor a narrow pattern, but a cross-sub-mode design-constraints document).

## Appendix

- Search queries / commands used:
  - `find agent-system/extensions/{core,memory} -maxdepth 2 -type d` (directory topology)
  - `grep -n "^### Sub-Mode: meta\|^### Sub-Mode: review\|^### Sub-Mode: dream\|^## "
    skills/skill-distill/SKILL.md` (section locations)
  - `grep -rn "Overlap Scoring" agent-system/extensions/{memory,core}` (cross-reference tracing)
  - `grep -n "no reliable signal to distinguish core scope" agent-system/extensions/core/agents/meta-builder-agent.md`
    (quotation-drift check; zero matches)
  - `bash .claude/scripts/events-query.sh --format summary-counts` (live Tier-2 verification;
    must run from the **deployed** `.claude/scripts/` tree, not the source store)
  - `bash .claude/scripts/events-query.sh --format json-array | jq -r '.[] | .message' | grep -ic
    "handoff mtime"` → 25 matches (dispatch cited 14; cluster has grown, confirming it is live
    and recurring, not a one-time artifact)
  - `wc -l ~/.claude/history.jsonl` → 31,901 lines (dispatch cited 31,666; consistent with
    ongoing accrual)
  - `env | grep -i telemetry` and settings-file grep for `CLAUDE_CODE_ENABLE_TELEMETRY` → both
    empty, confirming OTel is genuinely unavailable on this machine today
- References: `agent-system/extensions/memory/skills/skill-distill/SKILL.md`,
  `agent-system/extensions/memory/context/project/memory/patterns/distill-{meta,review,dream}-submode.md`,
  `agent-system/extensions/memory/context/project/memory/telemetry-guardrails.md`,
  `agent-system/extensions/memory/skills/skill-learn/SKILL.md`,
  `agent-system/extensions/core/scripts/events-query.sh`,
  `agent-system/extensions/core/context/contracts/convergence.md`,
  `agent-system/extensions/core/context/formats/events-format.md`,
  `agent-system/extensions/core/agents/meta-builder-agent.md`,
  `agent-system/extensions/core/commands/{meta,review}.md`
