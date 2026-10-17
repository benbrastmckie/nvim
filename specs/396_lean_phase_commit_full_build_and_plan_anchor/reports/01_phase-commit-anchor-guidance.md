# Research Report: Task #396

**Task**: 396 - Add two explicit guidance items to the lean implementation agent guidance in the
lean extension source store, distilled from prior implementation issues.
**Started**: 2026-10-17T08:24:19Z
**Completed**: 2026-10-17
**Effort**: Small (prose-only additions/revisions across 3 markdown files; no code)
**Dependencies**: 376 (per state.json)
**Sources/Inputs**:
- Codebase: `agent-system/extensions/lean/agents/lean-implementation-agent.md`,
  `agent-system/extensions/lean/agents/lean-implementation-hard-agent.md`,
  `agent-system/extensions/lean/context/project/lean4/agents/lean-implementation-flow.md`,
  `agent-system/extensions/lean/context/project/lean4/operations/long-builds.md`,
  `agent-system/extensions/core/agents/reviser-agent.md`,
  `agent-system/extensions/core/agents/general-implementation-agent.md`,
  `agent-system/extensions/core/context/patterns/` (directory survey)
- Task description / dispatch file (provenance narrative for both items)
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- All three dispatch-named edit sites for **ITEM 1** (full-build phase-commit gate) and
  **ITEM 2** (plan-section anchor-forward-from-heading rule) were located and read in full; their
  current text contradicts ITEM 1 exactly as the task description predicted, and line numbers are
  close to the task's estimates (drift of a few lines, consistent with "will drift" caveat).
- ITEM 1 is a genuine **revision**, not an addition: three passages across the primary flow file
  and both agent files currently instruct the opposite of the new guidance (prefer/accept scoped
  `lake build Module.Name` for phase-end; reserve full `lake build` for final verification only).
  All three must change together or the agents will contradict each other.
- The orthogonal detach+guard build-safety contract (`long-builds.md`) already treats scoped and
  full builds identically for detachment/guarding purposes ("Scoped builds are covered too") —
  ITEM 1 does not touch that contract, it only removes scoped builds as an acceptable
  phase-commit gate. No change to `long-builds.md` is strictly required, though a one-line
  cross-reference there would help a future reader; this is optional and would require widening
  `file_scope` (see Recommendations).
- ITEM 2's failure mode (bare-substring end-anchor matching an earlier prose occurrence of the
  same string) has **no existing generic home** anywhere in the core extension — surveyed
  `core/context/patterns/*.md` (35 files) and `core/agents/reviser-agent.md` (the other agent that
  splices plan-file sections); neither documents an anchor-forward-from-heading rule today. This
  is a genuinely open design question the dispatch explicitly defers to planning.
- Recommendation: land both items narrowly in the three named lean files, phrased in
  self-contained generic language (not lean-specific wording) so a future core pattern file could
  later absorb them by reference without a rewrite; do not create a new core pattern file now for
  a single observed incident. Rationale and tradeoffs below.

## Context & Scope

This is a `task_type: meta` task whose deliverable is prose guidance change inside the **lean
extension's source store** (`agent-system/extensions/lean/`), never the deployed `.claude/**`
tree (per `rules/source-store-deploy-boundary.md`). The task's own `file_scope` currently lists
exactly three files:

```
agent-system/extensions/lean/context/project/lean4/agents/lean-implementation-flow.md
agent-system/extensions/lean/agents/lean-implementation-agent.md
agent-system/extensions/lean/agents/lean-implementation-hard-agent.md
```

Both guidance items originate from two minor-severity issues logged during a prior task's
implementation (provenance cited in the task description: `iss_1791860085296_Yr2gXO` for ITEM 1,
`iss_1791862806295_NnFCBA` for ITEM 2). The originating task directory has since been renumbered
out of the active `specs/` tree (task numbers are periodically reset by vault operations per
`rules/state-management.md`), so the `issues.jsonl` entries themselves were not independently
re-read; the task description's narrative of both incidents was treated as the authoritative
source, and this research instead focused on verifying the *current* state of every file the
guidance must land in or near.

Scope of this research: locate and read every edit site named in the task description, confirm
or correct line-number estimates, check for an orthogonal constraint (the detach+guard build
contract) that the ITEM 1 change must not weaken, and determine whether ITEM 2 has an existing
generic home elsewhere in the source store before planning narrows or widens `file_scope`.

## Findings

### Codebase Patterns

**ITEM 1 — current (contradictory) state, confirmed at these exact locations:**

1. `context/project/lean4/agents/lean-implementation-flow.md`:
   - Stage 4C "Verify Phase Completion" (L109-113): *"Run `lake build Module.Name` to verify the
     module compiles (preferred; faster than full build). Fall back to `lake build` only if the
     module name is unknown or the phase spans multiple modules."*
   - Stage 5 "Run Final Build Verification" (L121-128): frames the full `lake build` as *"the
     only required full build"*, with an explicit note: *"Phase-end uses `lake build
     Module.Name`. Only this final stage requires full `lake build`."*
   - This file is correctly identified by the task description as the primary target: both
     `lean-implementation-agent.md` and `lean-implementation-hard-agent.md` independently restate
     the same scoped-preferred policy rather than deferring to this shared file, so all three need
     coordinated edits or two of the three will end up contradicting the third.

2. `agents/lean-implementation-agent.md`:
   - MUST DO item 7 (L752-753, dispatch estimated ~L738): *"Prefer `lake build Module.Name` for
     phase-end verification — scoped is less work, not categorically safe; it still uses the same
     guarded, detached invocation as any other build"*
   - MUST DO item 8 (L754-761, dispatch estimated ~L740): scopes the mandatory full build to
     *"final verification only"*.
   - MUST NOT item 3 (L776-778, dispatch estimated ~L754-755): *"Skip final `lake build`
     verification (scoped `lake build Module.Name` is acceptable for phase-end; only full `lake
     build` is mandatory at the final stage — both use the same guarded, detached invocation)"*
   - Phase Checkpoint Protocol (L683-711, dispatch estimated ~L672-690): step 6 commits after step
     3 ("Mark phase [COMPLETED]") with **no build-gate reference at all** — the commit currently
     follows directly from the phase steps and self-review, not from any build verdict. This is
     the site where the new full-build gate needs to be inserted as an explicit precondition on
     step 6, not merely a wording tweak to existing prose.

3. `agents/lean-implementation-hard-agent.md`:
   - Stage 4D "Verify Phase Completion" (L241-262, dispatch estimated ~L238/~L272): the inline
     comment *"Scoped build for current module — less work, not categorically safe"* precedes a
     `lake-build-guard.sh build ... -- build ModuleName` invocation; Stage 4H "Git Commit"
     (L279-287) follows immediately after Stage 4E "Mark Phase Complete" with no build-gate
     reference, same gap as the non-hard agent.
   - MUST DO item 7 (L798-804, dispatch estimated ~L779): *"Run full lake build before returning
     implemented status"* — correctly scopes the full-build requirement to end-of-task only, not
     phase-end.

**Orthogonal constraint confirmed intact and unaffected:** `context/project/lean4/operations/
long-builds.md`'s "Scoped builds are covered too" section (L114-128) already states that a single
module build can itself exceed the foreground cap and that the detach+guard obligations apply
identically regardless of whether the wrapped `lake build` is scoped or full. ITEM 1 does not
need to touch this file's detach/guard mechanics — it only removes the *option* to satisfy the
phase-commit gate with a scoped build; the build itself (whichever flavor runs) still goes through
the same canonical invocation this file already mandates. No existing text in this file claims
scoped builds are faster in a way that needs correcting — the removed claim ("faster than full
build", "less work") lives only in the three files above, as prose comparing the two build kinds
for *gating purposes*, not as a cost-mechanics claim this file makes.

**ITEM 2 — current (contradictory or absent) state:**

- `agents/lean-implementation-agent.md` L100-106 shows the Edit-tool pattern already used for
  phase-marker updates: `old_string: "### Phase {P}: {exact_phase_name} [NOT STARTED]"`. This
  pattern is *already* anchored on a full heading line (not a bare substring), because the
  heading text plus bracketed status is unique within the file by construction. The ITEM 2
  failure mode described in the task (a bare `## Heading Text` string recurring in earlier prose)
  is a *different, section-splice* operation — not the single-line phase-marker swap already
  shown here. No existing text in either agent file documents a rule for a *multi-line section
  replacement* (replacing everything between one heading and the next), which is the operation
  that actually failed in the originating incident.
- MUST NOT item 15/14 in both agent files (`lean-implementation-agent.md` L806,
  `lean-implementation-hard-agent.md` L834 — dispatch's "~L780"/"~L805") already delimits
  plan-file write authority to phase headings and checklist items, but says nothing about *how*
  to anchor a multi-line edit within that authority.
- `context/project/lean4/agents/lean-implementation-flow.md` Stage 4A (L79-84) and 4D (L115-117)
  show the same single-line marker-swap pattern as the agent files; no section-splice guidance
  exists here either.
- **No generic home exists in core**: surveyed all 35 files under
  `core/context/patterns/*.md` and `core/agents/reviser-agent.md` (the other agent in the source
  store that edits plan-file sections, during plan revision) for any existing "anchor on heading
  line, search forward" or "never match a bare substring that may recur in prose" rule. None
  exists. The closest adjacent material is `core/context/patterns/file-footprint-overlap.md`'s
  use of "splice" (concurrent-edit overlap detection, not anchor correctness) and the
  `no-task-references`/`no-record-versioning` rules' use of "anchor" to mean citation anchors —
  neither is the same concept.

### External Resources

Not applicable — this is a pure in-repo prose/documentation task with no external library,
framework, or API surface. No web research was performed.

## Recommendations

1. **ITEM 1 placement**: Revise all three sites in `lean-implementation-flow.md` (the primary,
   shared target per the task description) plus the corresponding restated passages in both agent
   files, so no two of the three contradict each other after the edit. Concretely:
   - `lean-implementation-flow.md` Stage 4C: change the preference order so a full `lake build` is
     the only build that satisfies phase-end verification for the purpose of gating the commit
     step; a scoped `lake build Module.Name` may still be run earlier in the phase as a fast
     interim correctness check (the plan-development loop already uses `lean_goal`/`lean_verify`
     per-step, so this is not a new capability, just clarifying scoped builds remain legitimate
     for *non-gating* feedback). Stage 5's "only this final stage requires full `lake build`"
     sentence must be removed or corrected — it would otherwise be literally false once phase-end
     also requires one.
   - `lean-implementation-agent.md`: reword MUST DO items 7-8 so the full build is the phase-end
     gate (not "final verification only"), and reword MUST NOT item 3 so a scoped build is no
     longer stated as "acceptable for phase-end". Insert the gate explicitly into the Phase
     Checkpoint Protocol (new step between "Mark phase [COMPLETED]" and "Git commit"): the commit
     step does not run until a full `lake build` for the whole library has passed.
   - `lean-implementation-hard-agent.md`: same treatment at Stage 4D/4H — insert the full-build
     gate between "Mark Phase Complete" and "Git Commit", and update the inline comment that
     currently frames the scoped build as the phase-end verification step.
   - **Name the cost explicitly** (per the task description's instruction): add one sentence at
     each phase-commit gate site stating that this makes every phase commit as slow as the
     slowest full build, and that this is a deliberate accuracy-over-speed tradeoff recorded here
     rather than an accidental regression — point to `long-builds.md`'s preference-order and
     "Known gaps" framing for *how* to run that build (detached+guarded), not duplicate it.
   - Do not widen `file_scope` for ITEM 1: `long-builds.md` needs no correction (its "scoped
     builds are covered too" framing is about detach/guard parity, not about phase-commit
     gating), though planning may choose to add a one-line cross-reference there for discoverability.

2. **ITEM 2 placement — recommend narrow, lean-local, not a new core pattern file.** Add the
   anchor-forward-from-heading rule at the three "natural homes" the task description names
   (near the Edit-tool phase-marker instructions and the write-authority MUST NOT items in both
   agent files, and the phase-marker steps in the flow file), phrased in fully generic language
   (e.g. "when replacing a plan-file section, anchor the end boundary on a line that itself
   begins with a heading marker (`## `/`### `) and search forward from the section's own start
   line — never on a bare substring, which may recur earlier in the file's prose") rather than
   lean-specific wording. Rationale for not creating a new `core/context/patterns/*.md` file now:
   - Only one incident has been observed; the core pattern files surveyed are each backed by
     multiple call sites or a cross-cutting mechanism already in place (e.g.
     `bounded-build-waiter.md`, `checkpoint-before-overflow.md`). A new file for a single
     occurrence is process overhead ahead of evidence it recurs.
   - `file_scope` is currently exactly the 3 lean files; widening it to add a new core file is a
     non-trivial scope change for what is otherwise a same-paragraph-sized addition.
   - Writing the guidance generically now (not "Lean plan files" but "plan-file section edits")
     costs nothing extra and leaves a future second incident free to promote the same paragraph
     into a shared `core/context/patterns/` file by reference, without rewriting it.
   - If planning disagrees and prefers the shared-home route, the reviser-agent.md is the other
     concrete consumer that would benefit (it also splices plan-file sections during revision) —
     widening `file_scope` to include `core/agents/reviser-agent.md` and a new
     `core/context/patterns/` file would be the correct scope for that alternative.

3. Both items are small, independent prose edits with no mechanical/script-level counterpart
   (confirmed: `git-commit-scoped.sh` has no build-status gate today, and no script anchors plan
   sections on behalf of these agents) — this is pure agent-instruction text, well suited to a
   single implementation phase per item, or one phase covering both if the plan prefers.

## Decisions

- Treated the task description's incident narrative as authoritative provenance; did not attempt
  to re-read the renumbered-away `issues.jsonl` entries, since the description already quotes the
  relevant fields (what happened, commit shas, severity, phase, dispatch_seq) in full.
- Confirmed line-number drift is real but minor (single-digit to ~15 lines) at every site; used
  the current, re-read text as the planning basis rather than the dispatch's estimates.
- Did not expand `file_scope` during research (out of scope for this phase); recommendation 2
  above flags the one plausible reason planning might choose to.

## Risks & Mitigations

- **Risk**: gating every phase commit on a full `lake build` meaningfully slows down multi-phase
  Lean tasks (a full build can already exceed the 10-minute foreground cap on its own per
  `long-builds.md`). **Mitigation**: this is the task's explicit intent (closing a real
  correctness gap), and the cost is to be named explicitly in the new guidance rather than hidden;
  no code change is needed since the detach+guard contract already handles arbitrarily long
  builds safely.
- **Risk**: editing three files in two agents plus one shared flow file risks leaving one site
  stale relative to the other two (the exact failure mode ITEM 1 itself is about, applied to
  documentation maintenance). **Mitigation**: plan should sequence the shared flow file first,
  then both agent files, with a final grep pass for the removed phrases (`"faster than full
  build"`, `"acceptable for phase-end"`, `"Only this final stage requires full"`) to confirm no
  stale copy survives.
- **Risk** (ITEM 2): generic wording chosen now might not match whatever a future core pattern
  file eventually uses verbatim, requiring a second edit later if centralized. **Mitigation**:
  low cost either way — a later centralization is a copy-then-point-there change, not a rewrite,
  if the wording is generic from the start as recommended above.

## Context Extension Recommendations

- **Topic**: markdown section-splice anchoring (ITEM 2's failure mode).
- **Gap**: no file under `core/context/patterns/` documents the anchor-forward-from-heading rule
  for multi-line section replacement in a markdown file; the only existing anchoring guidance in
  the source store is the single-line, inherently-unique phase-marker swap pattern, which does
  not generalize to section-level edits.
- **Recommendation**: not actionable now per this task's narrow scope (see Recommendations item
  2) — surfaced here for visibility in case a second incident of the same class occurs elsewhere
  in the source store, at which point promoting the (by-then twice-written) paragraph into a new
  `core/context/patterns/markdown-section-anchoring.md` (or similarly named) file becomes clearly
  justified.

## Appendix

- Files read in full or in relevant excerpt: `agents/lean-implementation-agent.md` (L95-140,
  L650-807), `agents/lean-implementation-hard-agent.md` (L195-285, L760-836),
  `context/project/lean4/agents/lean-implementation-flow.md` (full, 200 lines),
  `context/project/lean4/operations/long-builds.md` (full, ~240 lines).
- Searches run: `grep -rn "anchor"` across all extensions (scoping survey); `grep -rln "anchor"`
  excluding lean; `grep -rn "forward from\|bare substring\|section.*anchor\|splice"` in core;
  `ls core/context/patterns/`; `grep -n "Phase-Commit Containment Self-Check"` in
  `general-implementation-agent.md`; `grep -n "build\|lake"` in `git-commit-scoped.sh`.
- `.claude-extensions.json` consulted to resolve the lean extension's `source_dir`
  (`agent-system/extensions/lean`) per `rules/source-store-deploy-boundary.md`.
- Attempted but unavailable: `git log`/`git show` for the two commit shas cited in the task
  description (`83085ed7e`, `f0ef67f81`) — not found in local history, consistent with the
  originating task directory's renumbering/archival since those commits landed; not required
  given the task description's self-contained narrative.
