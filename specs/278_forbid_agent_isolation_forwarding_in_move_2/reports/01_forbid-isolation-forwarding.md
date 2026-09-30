# Research Report: Task #278

**Task**: 278 - Forbid Agent isolation forwarding in Move 2
**Started**: 2026-09-30
**Completed**: 2026-09-30
**Effort**: small (documentation-and-contract change; no executable logic changes)
**Dependencies**: None (no hard dependency edges declared; file_scope-driven serialization at
  admission handles coordination with tasks 263/273/274/275 (SKILL.md) and 250/165/265/272
  (orchestrate-cycle-plan.sh))
**Sources/Inputs**:
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (source store)
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` (source store)
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` (source store)
- The harness's own Agent tool schema (system-provided; not a repo file)
**Artifacts**:
- `specs/278_forbid_agent_isolation_forwarding_in_move_2/reports/01_forbid-isolation-forwarding.md` (this report)
**Standards**: report-format.md, subagent-return.md, source-store-deploy-boundary.md

## Executive Summary

- Confirmed empirically: `grep -n isolation` over `skills/skill-orchestrate/SKILL.md` (source
  store) returns nothing — Move 2 nowhere mentions `isolation`, so there is no existing explicit
  rule, only an implicit omission in the Move 2 Agent-call comment block (lines 142-146).
- Confirmed: `orchestrate-cycle-plan.sh` emits `isolation` and `worktree_path` on every
  `dispatch[]` row, both in the live path (line 2758-2759) and the `--dry-run` path
  (line 2385-2386), and documents them in the script's own output-schema header (lines 202-223).
- The collision is sharper than generic field confusion: the harness's own `Agent` tool has a
  real parameter literally named `isolation` with enum values `"worktree"`/`"remote"`. A
  dispatch row's `isolation: "worktree"` is not just superficially similar to an Agent-tool
  argument name — it is a syntactically valid value for that exact argument, which is what makes
  accidental forwarding so easy to do without any type or schema error surfacing.
- The destructiveness rationale (stacked worktree -> harness refuses cross-checkout git ->
  uncommittable work) does not currently exist anywhere in the source store searched (`grep -rn
  "cross-checkout\|stacked checkout\|second checkout"` over the whole extension returns nothing).
  The only existing prohibition-adjacent prose is `batch-orchestration-guardrails.md`'s
  "Deliberate Divergences" bullet (lines 1493-1501), and it argues a *different* rationale
  (`specs/` staleness under a harness-level whole-repo relocation), not the stacked-checkout /
  uncommittable-work hazard task 278's dispatch describes. This confirms edit (c) (a two-way
  pointer) is worthwhile: the two rationales are complementary, not duplicates, and currently
  live in isolation from each other.
- Generalization check (requested in the dispatch): of the eight fields on a `dispatch[]` row
  (`task, phase, agent, model, dispatch_file, force, focus, isolation, worktree_path`), only
  `agent` (-> `subagent_type`) and `model` (-> `model`) are ever named as Agent-tool call
  arguments in Move 2's own bash/comment block. `dispatch_file` is read to build the prompt text
  (not passed as a raw tool arg); `force`/`focus` are consumed elsewhere (postflight,
  dispatch-file authoring in Move 1) and never touch the Move 2 Agent call; `isolation` and
  `worktree_path` are used nowhere in Move 2 today. A categorical MUST NOT ("no field of a
  dispatch row is an Agent-tool argument unless Move 2 names it") is accurate and supported by
  this enumeration — `isolation`/`worktree_path` should be named as the motivating example
  because they are the only fields that collide with a real Agent-tool parameter name.
- `aux_dispatch[]` rows (`{task, kind, agent, model, dispatch_file, orchestrator_mode}`) carry no
  `isolation`/`worktree_path` field at all, so the MUST NOT's concrete example only needs to
  cover `dispatch[]` rows; the categorical phrasing naturally covers both without extra casework.

## Context & Scope

Task 278 is a documentation-and-contract-only fix (explicitly stated in the dispatch: "no
executable logic changes"). The scope is exactly the two files plus one optional cross-link named
in the dispatch:

(a) `skills/skill-orchestrate/SKILL.md`, Move 2 — add an explicit MUST NOT forbidding forwarding
    `isolation`/`worktree_path` (or, generalized, any un-named dispatch-row field) to the Agent
    tool call.
(b) `scripts/orchestrate-cycle-plan.sh` header — strengthen the existing "dispatch-site wiring"
    language for `isolation`/`worktree_path` into an explicit "never an Agent-tool argument"
    statement.
(c) (optional) `context/patterns/batch-orchestration-guardrails.md`'s "Deliberate Divergences"
    section — a one-line pointer to the new SKILL.md MUST NOT, and back.

All edits target the source store under `agent-system/extensions/core/` per
`source-store-deploy-boundary.md` — never the deployed `.claude/**` tree.

## Findings

### Codebase Patterns

**SKILL.md Move 2 (lines 129-166).** The Agent-call shape is documented only as a bash comment
inside a `while read` loop (lines 136-146):

```
# Agent tool: subagent_type: agent (model param if non-empty). Prompt: "You are dispatched by
# /orchestrate for task $t, phase $phase. Read $dispatch_file first and execute it exactly; it
# names every input, output path and contract." Context: { task_number: t,
# orchestrator_mode: true, session_id: ctx_sid, task_dir: task_dir_abs,
# handoff_path: "${task_dir_abs}/.orchestrator-handoff.json", dispatch_seq }
```

Only `agent` (-> `subagent_type`) and `model` (-> `model` param, when non-empty) are named as
Agent-tool arguments. `isolation` is never mentioned — not even to say it is intentionally
omitted. The `Context: {...}` fields are embedded as prompt text (this is confirmed directly by
how this very dispatch was relayed: the team lead's message embedded `task_number`,
`orchestrator_mode`, `session_id`, `task_dir`, `handoff_path`, `dispatch_seq` as plain bullet text
in the message body, not as a structured Agent-tool JSON parameter) — they are not Agent-tool
call arguments at all, which is a second, related point worth making explicit if the MUST NOT is
generalized: the "Context" block is prompt content, and the only fields that are genuine
Agent-tool arguments are `subagent_type`/`agent`, `model`, and (per the harness's Agent tool
schema) `description`, `isolation`, `name`, `team_name`.

The existing MUST NOT at line 159 ("an `aux_dispatch[]` row never reaches Move 3...") is a
different topic and does not cover this hazard. There is exactly one other MUST NOT in the file
(line 117, about not re-invoking `orchestrate-cycle-plan.sh` live), confirming the file's
established style for a standalone contract line: a `**MUST NOT**: ...` paragraph, not a
sub-bulleted list.

**orchestrate-cycle-plan.sh header (lines 202-223).** The output schema documents `isolation` and
`worktree_path` in prose:

```
# `isolation` (`"none"` or `"worktree"`, working-tree and build isolation posture dispatch-site
# wiring) is selected by task_selected_for_worktree_isolation() -- phase == "implement" AND a
# lean4/cslib-family task_type -- and is emitted identically in BOTH modes. `worktree_path` is
# `null` whenever `isolation` is `"none"`, and ALSO always `null` under --dry-run regardless of
# what `isolation` says ...
```

"dispatch-site wiring" describes *what the field configures* (the worktree/build-isolation
posture already decided and provisioned before the row is built), but never states that the field
is *not* an input to anything downstream, specifically not an Agent-tool argument. This is exactly
the weakness task 278's dispatch identifies.

Both the live row builder (lines 2753-2759) and the `--dry-run` row builder (lines 2380-2386)
emit `isolation`/`worktree_path` identically in shape, confirming the field is a stable,
always-present part of every `dispatch[]` row's JSON — not an occasional or debug-only field a
lead might reasonably treat as safe to ignore.

**batch-orchestration-guardrails.md (lines 1362-1547).** The "Working-Tree and Build Isolation
Posture" section (starting line 1362) is the design-record home for the `isolation` decision
itself (why script-provisioned worktrees were chosen). Its "Deliberate Divergences" subsection
(lines 1491-1501) contains the one existing sentence of rationale against forwarding a
harness-level isolation parameter — but it argues from `specs/` staleness under whole-repo
relocation, not from the stacked-worktree/cross-checkout-git-refusal failure mode task 278's
dispatch reports as observed. Both rationales are true and independent; neither subsumes the
other. This section is also where a reader would expect to land after reading the new MUST NOT in
SKILL.md, making it the natural target for edit (c)'s pointer.

### External Resources

Not applicable — this is a documentation-and-contract fix entirely internal to the source store;
no external API or library research was needed. The only "external" reference consulted was the
harness's own Agent tool parameter schema (provided natively in this session's tool definitions),
which confirms `isolation` (enum `"worktree"`/`"remote"`) is a real, distinct Agent-tool argument
— the fact that makes this collision dangerous rather than merely confusing.

## Recommendations

1. **Edit (a) — SKILL.md Move 2.** Insert a new `**MUST NOT**` paragraph between the end of the
   Move 2 bash/comment block (after line 157, i.e. right before the existing
   `echo "$plan_json" | jq -c '.aux_dispatch[]' | while ...` block, or immediately after that
   second block ends at line 157/166 — either position keeps it inside the Move 2 section).
   Recommended phrasing direction (not final prose, but the required content):
   - State the categorical rule: no field of a `dispatch[]`/`aux_dispatch[]` row is an Agent-tool
     argument unless this section names it (today: only `agent` -> `subagent_type` and `model`).
   - Name `isolation`/`worktree_path` explicitly as the motivating example, since `isolation` is
     a real Agent-tool parameter name (enum `"worktree"`/`"remote"`) and a dispatch row's
     `isolation: "worktree"` value is a syntactically valid value for it — the exact reason this
     is an easy, undetected mistake rather than an obvious type error.
   - State the consequence in one clause so the rule is self-justifying at the point of use: a
     second, harness-provisioned worktree stacks on top of the one `dispatch-worktree.sh` already
     provisioned; the harness then refuses cross-checkout git by design while still permitting
     file writes and build runs, so the dispatched agent authors and verifies its work green and
     then cannot commit it.
   - Optionally cite the observed-evidence data point (20 of 21 phases lost on one dispatch in a
     separate repository) as a parenthetical, matching this file's existing style of citing
     concrete costs (e.g. the `--hard` cost-multiplier table elsewhere in the project CLAUDE.md).

2. **Edit (b) — orchestrate-cycle-plan.sh header.** Extend lines 214-223's `isolation`/
   `worktree_path` documentation with an explicit sentence such as: these two fields are a record
   of a posture already put into effect before the row was built (the worktree, if any, was
   provisioned earlier in this same function) and are consumed only by this script's own
   downstream bookkeeping — **never** an argument to pass to the Agent tool call in
   `skill-orchestrate/SKILL.md`'s Move 2. Point forward to the new SKILL.md MUST NOT line (by
   section name, not a task-number reference, per `no-task-references-in-deliverables.md`) so the
   two edits stay linked.

3. **Edit (c) (optional) — batch-orchestration-guardrails.md.** Add one line to the "Deliberate
   Divergences" bullet (lines 1493-1501) pointing to the new SKILL.md MUST NOT, e.g. noting that
   the enforced point-of-use rule lives there and citing the complementary failure mode
   (stacked-worktree/uncommittable-work) this design-record bullet does not itself cover. Keep
   both rationales in prose (do not delete the `specs/` staleness argument — it remains valid and
   distinct).

4. **Generalization phrasing.** Prefer the categorical MUST NOT ("no dispatch-row field is an
   Agent-tool argument unless Move 2 names it") over an `isolation`-only prohibition. The
   enumeration in Findings above shows this costs nothing (only `agent`/`model` are legitimately
   forwarded today) and future-proofs against the same mistake recurring if the dispatch-row
   schema grows a new field that happens to share a name with a future Agent-tool parameter.

5. **No test/script changes needed.** The dispatch is explicit that this is documentation-only;
   no `.sh` test file under `scripts/tests/` needs updating, and no behavior of
   `orchestrate-cycle-plan.sh`'s row-emission logic should change — only its header comment.

## Decisions

- Target the source store (`agent-system/extensions/core/...`), never `.claude/**`, per
  `source-store-deploy-boundary.md` — confirmed via `.claude-extensions.json`'s
  `"source_dir": "/home/benjamin/.config/nvim/agent-system/extensions/core"` entry.
- Phrase the new MUST NOT categorically (covering any un-named dispatch-row field), with
  `isolation`/`worktree_path` as the named, motivating example — not an `isolation`-only rule —
  per the dispatch's "CONSIDER GENERALIZING" prompt and the field enumeration in Findings.
- Treat edit (c) as genuinely optional/additive: the core fix is edits (a) and (b); (c) improves
  discoverability but is not required for the prohibition to be enforced at the point of use.
- Do not touch any file in task 250's decomposition scope beyond the header comment at its current
  location; if task 250 lands first and moves/rewrites that header block, a future editor should
  re-derive where the note belongs rather than assume the current line numbers, per the dispatch's
  own coordination note.
- Do not attempt to verify or reproduce the BimodalLogic incident (task 278's dispatch marks that
  repository read-only evidence); the destructiveness claim is accepted as given and is
  independently plausible given the harness's own documented cross-checkout git refusal behavior
  for worktree/remote isolation.

## Risks & Mitigations

- **Risk**: Inserting the new MUST NOT inside the Move 2 bash/comment block could be read as
  another inert comment rather than a binding contract, the same failure mode that afflicted the
  implicit omission today. **Mitigation**: use the file's established `**MUST NOT**:` paragraph
  convention (matching lines 117 and 159) placed as prose *outside* the bash code fence, not as a
  bash comment line, so it renders as a first-class contract statement.
- **Risk**: File-scope overlap with tasks 263/273/274/275 (SKILL.md) and 250/165/265/272
  (orchestrate-cycle-plan.sh) could cause a merge conflict or a stale line-number reference if a
  sibling task lands first. **Mitigation**: re-read both files immediately before editing (per
  the Territory contract already required by this dispatch), and word the new content so it does
  not depend on exact surrounding line numbers remaining stable.
- **Risk**: Overgeneralizing the MUST NOT could inadvertently forbid legitimate future use of a
  currently-unused dispatch-row field (e.g. if a future change intentionally wants to forward
  `focus` or `force` to the Agent tool). **Mitigation**: phrase the rule as "unless Move 2 names
  it" (an escape hatch requiring an explicit, visible edit to this same section), not as an
  absolute ban on ever using other fields.

## Context Extension Recommendations

- **Topic**: Harness Agent-tool parameter names vs. dispatch-row field names.
- **Gap**: No existing context file enumerates which dispatch-row fields are safe to treat as
  Agent-tool arguments and which are not. This report's Findings/Recommendations sections supply
  that enumeration but it currently exists only here and (after implementation) in the two edited
  files.
- **Recommendation**: No new standalone context file is needed for a fix this narrow; the MUST
  NOT in SKILL.md Move 2 plus the strengthened header in orchestrate-cycle-plan.sh are sufficient
  point-of-use documentation. If a third or fourth harness-level parameter collision is discovered
  later, consider promoting the categorical rule into a dedicated
  `context/patterns/dispatch-row-vs-agent-tool-args.md` reference at that point — premature now
  with only one confirmed collision (`isolation`).

## Appendix

Search queries / commands used:
- `grep -n -i "isolation" skills/skill-orchestrate/SKILL.md` (source store) — zero matches,
  confirming the dispatch's premise.
- `grep -n "Move 2" skills/skill-orchestrate/SKILL.md` — located Move 2 section (line 129).
- `grep -n -i "isolation\|worktree_path" scripts/orchestrate-cycle-plan.sh` — located every
  emission site (header lines 202-223; live builder lines 2549-2759; dry-run builder lines
  2380-2386).
- `grep -n "Deliberate Divergences\|Working-Tree and Build Isolation Posture"
  context/patterns/batch-orchestration-guardrails.md` — located both sections (1362, 1491).
- `grep -rn "cross-checkout\|stacked checkout\|second checkout" .` (whole extension) — zero
  matches, confirming this specific rationale does not exist anywhere in the source store yet.
- `grep -n '"source_dir"' .claude-extensions.json` — confirmed the source store path for the
  `core` extension.

References:
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` lines 129-166 (Move 2)
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` lines 190-231 (output schema
  header), 2549-2759 (live row builder), 2380-2386 (dry-run row builder)
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` lines
  1362-1547 (Working-Tree and Build Isolation Posture, Deliberate Divergences, Related Documents)
