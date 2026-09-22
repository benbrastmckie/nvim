# Implementation Plan: Task #243

- **Task**: 243 - Reconcile research handoff writer contract
- **Status**: [IMPLEMENTING]
- **Effort**: 2.75 hours
- **Dependencies**: None
- **Research Inputs**: specs/243_reconcile_research_handoff_writer_contract/reports/01_reconcile-handoff-writer-contract.md
- **Artifacts**: plans/01_reconcile-handoff-writer-contract.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Research settled the rule from the runtime consumer itself: `orchestrate-cycle-postflight.sh`
logs an absent handoff after a base-mode research/plan/implement dispatch as the *expected*
outcome, and `docs/architecture/handoff-schema.md` already documents the same decision. The
defect is therefore in the agent contracts, not the docs: all 21 `*research-agent.md` /
`*research-hard-agent.md` files carry a copy-templated section unconditionally instructing the
agent to write `.orchestrator-handoff.json` under `orchestrator_mode: true`.

This plan replaces that section, in every one of the 21 files, with a single canonical
prohibition paragraph; corrects the stale cross-reference sentences and MUST DO / MUST NOT
bullets that point at it; corrects `handoff-schema.md`'s misattributed citation; and closes with
a repo-wide grep that proves one consistent statement remains. No script changes are needed.

### Research Integration

Key findings carried into the phase structure:

- **The one rule**: research agents never write `.orchestrator-handoff.json`, in any mode. Fix
  direction is the agent contracts, not `handoff-schema.md`'s rule statement.
- **`orchestrate-build-dispatch.sh` needs no change**: its `## Handoff` block is phase-agnostic
  connectivity information (`handoff_path`/`task_dir` for every dispatch alike) and asserts no
  writing obligation. It is named in the task description's scope, so the plan verifies this
  explicitly rather than editing it.
- **21 files, not 3**: the section is verbatim-identical in 20 of them; `lean-research-agent.md`
  uses a `##` heading rather than `###`. Four files carry extra references to the section beyond
  the section itself. This plan splits those apart (Phase 2 vs. Phase 3) so the mechanical bulk
  edit stays mechanical.
- **Out of scope, confirmed**: `planner-agent.md` and `general-implementation-agent.md` carry the
  same defect class. `general-implementation-agent.md` is claimed by concurrent sibling task 242's
  declared `file_scope` this same cycle. Neither is touched here; Phase 4 records the follow-up.

Additional detail established during planning, beyond the report:

- The 20 extension copies carry the `**Echo dispatch_seq unchanged**` paragraph **only** inside
  the handoff section, scoped to "the handoff's own `dispatch_seq` field". Deleting the section
  outright would leave those 20 files with no `dispatch_seq` instruction at all. The canonical
  replacement text below therefore *redirects* the echo to `.return-meta.json` rather than
  dropping it. (`general-research-agent.md` already carries a separate `.return-meta.json`
  `dispatch_seq` instruction; the redirect is harmless there and keeps all 21 files uniform.)
- `context/contracts/wrap-up.md` was checked and is already consistent ("Every hard-mode
  implementation dispatch MUST write..."). It needs no edit.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:

- One consistent handoff-writer statement across all 21 research-agent contract files, the
  architecture doc, and the dispatch template text.
- Preserve the `dispatch_seq` echo instruction by redirecting it to `.return-meta.json` rather
  than deleting it along with the handoff section.
- Verification that survives future template propagation: a repo-wide grep, not a three-file spot
  check.

**Non-Goals**:

- Any change to `scripts/orchestrate-cycle-postflight.sh`, `orchestrate-recover-outcome.sh`, or
  `orchestrate-build-dispatch.sh`. The runtime is already correct; this is a contract-text fix.
- Any change to `planner-agent.md` or `general-implementation-agent.md` (same defect class,
  different territory, one of them claimed by a concurrent sibling task this cycle).
- Any change to the rule stated in `docs/architecture/handoff-schema.md`'s Handoff Writers table
  (already correct — only its misattributed citation parenthetical changes).
- Any hand-edit under `.claude/**`, which is a disposable deploy artifact regenerated from
  `agent-system/extensions/**`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Bulk edit across 17 files strays outside declared territory | H | L | Explicit file list per phase; per-file targeted `git add`, never a directory or glob pathspec; re-read each file immediately before editing (concurrent siblings active this cycle) |
| Deleting the handoff section drops the only `dispatch_seq` instruction in the 20 extension files | M | H (if unguarded) | Canonical replacement text redirects the echo to `.return-meta.json`; Phase 4 greps that all 21 files still carry a `dispatch_seq` instruction |
| Heading-level / wording drift makes the replacement non-uniform and defeats the acceptance grep | M | M | Phase 1 fixes the canonical text once; Phases 2-3 copy it verbatim apart from the documented `##` heading level in `lean-research-agent.md`; Phase 4 greps for residual "MUST write" phrasing |
| A future extension author scaffolds a new research agent from an uncorrected copy and reintroduces the section | M | M | Fixing all 21 known copies removes every current template source; Phase 4's repo-wide grep is the reusable check |
| Stale cross-references left pointing at a renamed section heading | M | M | Phase 1 and Phase 3 explicitly enumerate the four files with extra references; Phase 4 greps for the old heading text |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel. Phases 2 and 3 touch disjoint file sets.

### Canonical Replacement Text (authored in Phase 1, reused verbatim in Phases 2-3)

The entire existing `### \`.orchestrator-handoff.json\` (orchestrator-mode dispatches)` section —
heading through the `Use the shape defined by ...` paragraph inclusive — is replaced by:

```markdown
### `.orchestrator-handoff.json` — research agents never write one

This agent MUST NOT write `.orchestrator-handoff.json`, in any mode. That includes a dispatch
whose delegation context carries `orchestrator_mode: true` and supplies `handoff_path`: the
`## Handoff` block of a dispatch file is phase-agnostic connectivity information given to every
dispatch alike, never an instruction to write the file.

`.orchestrator-handoff.json` is hard-mode-implement-only. This agent returns its outcome — on
success and on a `partial` or `blocked` outcome alike — exclusively through `.return-meta.json`,
which `orchestrate-recover-outcome.sh` reads on the orchestrator's behalf. An absent handoff
after a research dispatch is the expected, non-defective case that
`scripts/orchestrate-cycle-postflight.sh` is built around and logs as such; writing one is the
defect this prohibition exists to prevent. See `docs/architecture/handoff-schema.md`'s
"Handoff Writers — the settled decision, in one place" section for the rationale.

**Echo `dispatch_seq` into `.return-meta.json`, not into a handoff.** If your delegation context
carries a `dispatch_seq` field, copy its value verbatim into `.return-meta.json`'s top-level
`dispatch_seq` key — never invent, increment, or recompute one; if it is absent, omit it. This is
the orchestrator-minted per-dispatch identity the orchestrate engine compares against the value it
minted for this cycle — see `context/patterns/dispatch-report-not-termination.md`.
```

One documented deviation: in `lean/agents/lean-research-agent.md` the heading is `##`, not `###`
(that file's section sits at the top document level). Preserve that file's existing heading level.

---

### Phase 1: Author canonical text and fix the core contract [COMPLETED]

**Goal**: Replace the handoff section in `general-research-agent.md` with the canonical
prohibition, and correct the Stage 3.6 sentence that currently claims a handoff-writing
obligation — the exact sentence `handoff-schema.md` misreads as a prohibition.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/agents/general-research-agent.md` immediately before
      editing (concurrent siblings are active on this working tree) *(completed)*
- [x] Replace the section at ~lines 234-261 (`### \`.orchestrator-handoff.json\`
      (orchestrator-mode dispatches)` through the `Use the shape defined by ...` paragraph) with
      the Canonical Replacement Text above *(completed)*
- [x] Rewrite the Stage 3.6 "Scoping Decision" cross-reference at ~line 228, replacing "See the
      `.orchestrator-handoff.json` (orchestrator-mode dispatches) subsection below for this
      agent's own handoff-writing obligation, which is a separate file, a separate consumer, and
      a separate trigger from the partial-report handoff artifact above." with a sentence that
      instead points at the prohibition — e.g. "The partial-report handoff artifact above is
      unrelated to `.orchestrator-handoff.json`, which this agent never writes; see the
      `.orchestrator-handoff.json` — research agents never write one subsection below." *(completed)*
- [x] Confirm the file's separate `.return-meta.json` `dispatch_seq` instruction (~lines 405-410)
      is intact and not duplicated in a contradictory way *(completed: both instructions redirect to .return-meta.json, no contradiction)*
- [x] Commit this file alone with a targeted `git add -- <path>` *(completed)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: the handoff section occupies ~lines 234-261 and the stale cross-reference
sits at ~line 228 of `general-research-agent.md`. Line numbers are pre-edit observations, not
facts — locate both by their quoted text, not by line number, and confirm `grep -c
"orchestrator-handoff" agent-system/extensions/core/agents/general-research-agent.md` drops from
6 to the post-edit count implied by the canonical text.

**Files to modify**:
- `agent-system/extensions/core/agents/general-research-agent.md` - replace handoff section;
  rewrite Stage 3.6 cross-reference sentence

**Verification**:
- `grep -n "MUST\s*$\|MUST write" agent-system/extensions/core/agents/general-research-agent.md`
  returns no line instructing a handoff write
- `grep -n "handoff-writing obligation" agent-system/extensions/core/agents/general-research-agent.md`
  returns nothing
- `grep -n "dispatch_seq" agent-system/extensions/core/agents/general-research-agent.md` still
  shows both the new `.return-meta.json` redirect and the pre-existing `.return-meta.json`
  instruction
- Diff read-through confirms every changed hunk is prose inside a markdown contract file

---

### Phase 2: Apply canonical text to the 17 uniform extension copies [COMPLETED]

**Goal**: Replace the verbatim-identical handoff section in the 17 extension research-agent files
whose only reference to the file is the section itself.

**Tasks**:
- [x] Re-read each file immediately before editing it *(completed)*
- [x] Replace the handoff section in each of the 17 files with the Canonical Replacement Text,
      preserving each file's existing `###` heading level *(completed)*
- [x] After each file, confirm `grep -c "orchestrator-handoff" <file>` matches the expected
      post-edit count and that no "MUST write" phrasing remains *(completed)*
- [x] Commit per file (or per small, explicitly listed group) with targeted `git add -- <paths>`;
      never a directory or glob pathspec *(completed: single commit with explicit 17-path list)*

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: prose

**Scope Hypothesis**: exactly 17 files carry the section and nothing else referencing it, all
with an identical section body (md5-identical across 20 of the 21 files). Confirm before editing
by re-running the sweep:
`for f in $(find agent-system/extensions -iname "*research-agent.md" -o -iname "*research-hard-agent.md"); do echo "$(grep -c orchestrator-handoff "$f") $f"; done`
— the 17 files below must each report exactly 5. Any file reporting a different count belongs to
Phase 3, not here.

**Files to modify** (all under `agent-system/extensions/`):
- `cslib/agents/cslib-research-hard-agent.md`
- `cslib/agents/pr-review-research-agent.md`
- `epidemiology/agents/epi-research-agent.md`
- `formal/agents/formal-research-agent.md`
- `formal/agents/logic-research-agent.md`
- `formal/agents/math-research-agent.md`
- `formal/agents/physics-research-agent.md`
- `founder/agents/deck-research-agent.md`
- `latex/agents/latex-research-agent.md`
- `nix/agents/nix-research-agent.md`
- `nvim/agents/neovim-research-agent.md`
- `present/agents/slides-research-agent.md`
- `python/agents/python-research-agent.md`
- `rust/agents/rust-research-agent.md`
- `typst/agents/typst-research-agent.md`
- `web/agents/web-research-agent.md`
- `z3/agents/z3-research-agent.md`

**Verification**:
- `grep -rn "MUST\s*write\s*\`\?\.orchestrator-handoff" <the 17 paths>` returns nothing
- `grep -rln "orchestrator-mode dispatches)" <the 17 paths>` returns nothing (old heading gone)
- `grep -rc "dispatch_seq" <the 17 paths>` shows each file still carries the echo instruction
- Diff read-through confirms all hunks are prose

---

### Phase 3: Apply canonical text to the 3 variant copies and their extra references [COMPLETED]

**Goal**: Fix the three files that reference the handoff beyond the section itself — a MUST DO
bullet, and in one case a MUST NOT bullet — plus the one file whose heading level differs.

**Tasks**:
- [x] Re-read each of the three files immediately before editing *(completed)*
- [x] `lean/agents/lean-research-agent.md`: replace the section (~line 340), preserving its `##`
      heading level; delete or rewrite the MUST DO bullet at ~lines 410-412 ("**Write
      `.orchestrator-handoff.json`** on every dispatch ... see the ... subsection above") so it no
      longer instructs a write — replace it with a MUST NOT bullet forbidding the write, or remove
      it and renumber the surrounding list *(completed: removed MUST DO bullet, renumbered, added MUST NOT bullet 16)*
- [x] `lean/agents/lean-research-hard-agent.md`: replace the section (~line 357); fix the MUST DO
      bullet at ~lines 421-423 the same way *(completed: removed MUST DO bullet, renumbered, added MUST NOT bullet 9)*
- [x] `cslib/agents/cslib-research-agent.md`: replace the section (~line 299); fix the MUST DO
      bullet at ~lines 371-373; rewrite the MUST NOT bullet at ~line 393 ("Write
      `.orchestrator-handoff.json` when the delegation context does NOT carry `orchestrator_mode:
      true`") to the unconditional form ("Write `.orchestrator-handoff.json` at all, in any mode") *(completed)*
- [x] Renumber any list items disturbed by a bullet removal, and confirm no dangling references to
      the removed/renamed section remain in each file *(completed)*
- [x] Commit per file with targeted `git add -- <path>` *(completed)*

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: prose

**Scope Hypothesis**: exactly 3 files carry extra references (pre-edit `grep -c
"orchestrator-handoff"` of 7, 7, and 8 respectively vs. 5 for the uniform set), and
`lean-research-agent.md` is the only file with a `##`-level heading. Confirm both by the sweep
command in Phase 2's Scope Hypothesis plus `grep -n "^##\+ \`\.orchestrator-handoff" ` across all
21 files before editing.

**Files to modify** (all under `agent-system/extensions/`):
- `lean/agents/lean-research-agent.md` - section (`##` heading) + MUST DO bullet
- `lean/agents/lean-research-hard-agent.md` - section + MUST DO bullet
- `cslib/agents/cslib-research-agent.md` - section + MUST DO bullet + MUST NOT bullet

**Verification**:
- `grep -n "orchestrator-handoff" <each of the 3 files>` shows only the new prohibition section's
  own mentions, with no remaining instruction to write the file
- The MUST DO / MUST NOT lists in each file are contiguously numbered with no gaps
- `grep -n "subsection above" <each of the 3 files>` returns no reference to a heading that no
  longer exists
- Diff read-through confirms all hunks are prose

---

### Phase 4: Correct the schema doc citation and prove consistency [IN PROGRESS]

**Goal**: Fix `handoff-schema.md`'s misattributed citation, confirm
`orchestrate-build-dispatch.sh` genuinely needs no change, and run the repo-wide acceptance grep.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/docs/architecture/handoff-schema.md` immediately
      before editing *(completed)*
- [x] In the Handoff Writers table's base-mode row, replace the parenthetical citation `(Stage 3.6
      "Scoping Decision" in the research agents)` — which points at a passage that does not state
      the prohibition — with a citation to the now-correct section: the
      `.orchestrator-handoff.json` — research agents never write one section in the research-agent
      contracts. Leave the rule statement itself unchanged *(completed)*
- [x] Confirm `scripts/orchestrate-build-dispatch.sh`'s `## Handoff` block (~lines 461-465) emits
      only `handoff_path`/`task_dir` with no writing obligation, and record that no edit was
      needed (this file is named in the task's acceptance scope) *(completed: confirmed lines 463-467 emit only handoff_path/task_dir, no edit needed)*
- [x] Run the acceptance grep across all 21 research-agent files plus `handoff-schema.md` and the
      dispatch-builder script; confirm one consistent statement *(completed: 21/21 hits for canonical statement, 0 hits for stale phrasing)*
- [x] Confirm no file under `.claude/**` was hand-edited during this task *(completed: git status --short shows no .claude/ modifications)*
- [x] Record the `planner-agent.md` / `general-implementation-agent.md` same-class defect as a
      follow-up in the task summary (do not edit either file) *(completed: recorded in summary)*
- [x] Commit `handoff-schema.md` with a targeted `git add -- <path>` *(completed)*

**Timing**: 0.5 hours

**Depends on**: 2, 3

**Verification Tier**: prose

**Scope Hypothesis**: the misattributed citation is a single parenthetical in one table row of
`handoff-schema.md`, and `orchestrate-build-dispatch.sh` needs zero edits. Confirm the second
claim by reading the `## Handoff` emission block before concluding it; if it does assert a writing
obligation, it moves into scope and this phase gains an edit.

**Files to modify**:
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` - citation parenthetical only

**Files to verify, not modify**:
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh`

**Verification**:
- `grep -rn "MUST write \`\?\.orchestrator-handoff" agent-system/extensions --include="*research*agent.md"`
  returns nothing
- `grep -rln "orchestrator-mode dispatches)" agent-system/extensions --include="*research*agent.md"`
  returns nothing
- `grep -rc "research agents never write one" agent-system/extensions --include="*research*agent.md"`
  reports a hit in all 21 files
- `grep -rn "Stage 3.6" agent-system/extensions/core/docs/architecture/handoff-schema.md` returns
  nothing (citation corrected)
- `git status --short` shows no modification under `.claude/`

---

## Testing & Validation

- [x] All 21 research-agent contract files carry the identical prohibition section (one hit each
      for `research agents never write one`) *(completed)*
- [x] No research-agent contract file instructs writing `.orchestrator-handoff.json` under any
      condition *(completed)*
- [x] All 21 files still carry a `dispatch_seq` echo instruction (now pointed at
      `.return-meta.json`) *(completed)*
- [x] `handoff-schema.md`'s rule statement is unchanged; only its citation parenthetical differs *(completed)*
- [x] `orchestrate-build-dispatch.sh` is unmodified and confirmed obligation-free *(completed)*
- [x] No cross-reference anywhere in the 21 files points at the removed heading text *(completed)*
- [x] No file under `.claude/**` was modified *(completed)*
- [x] `git log --oneline` shows per-file (or explicitly-listed-group) commits, no directory or
      glob `git add` pathspec used *(completed)*

## Artifacts & Outputs

- 21 corrected research-agent contract files under `agent-system/extensions/*/agents/`
- 1 corrected architecture doc: `agent-system/extensions/core/docs/architecture/handoff-schema.md`
- Execution summary at `specs/243_reconcile_research_handoff_writer_contract/summaries/01_*-summary.md`,
  recording the `planner-agent.md` / `general-implementation-agent.md` follow-up

## Rollback/Contingency

All changes are markdown-only in the source store, each committed per file. To revert a single
file: `git revert` that file's commit, or `git checkout <pre-task-sha> -- <path>` on a clean tree.
No runtime behavior changes, so a partial revert leaves the system functional — the worst case is
a return to the pre-task inconsistency, which postflight already recovers from via
`.return-meta.json` either way. If a concurrent sibling's edit is observed in a file in this
task's scope, STOP and report rather than proceeding (see the dispatch's concurrency note); do not
run `git-snapshot.sh` in its reverting default mode.
