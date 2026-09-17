# Research Report: Task #194

**Task**: 194 - Align lifecycle agent handoff contracts
**Started**: 2026-09-17
**Completed**: 2026-09-17
**Effort**: Large (62 of 64 reachable agent contract files need an edit)
**Dependencies**: None (this task's own research round)
**Sources/Inputs**: Codebase exploration (`agent-system/extensions/*/manifest.json`,
`agent-system/extensions/*/agents/*.md`, `skill-orchestrate/SKILL.md`,
`docs/architecture/handoff-schema.md`)
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Enumerated the full **dispatch[]-reachable agent set**: **64 unique agent names**, derived
  mechanically from every `manifest.json`'s `routing_agents`/`routing_agents_hard` blocks
  (`research`/`plan`/`implement` keys only — see Derivation Method).
- Of those 64, only **2 agents** (`cslib-implementation-hard-agent`,
  `lean-implementation-hard-agent`) currently carry a correct, affirmative "MUST write
  `.orchestrator-handoff.json`" obligation. These match `docs/architecture/handoff-schema.md`'s
  documented 2-entry writer allowlist exactly.
- **56 agents mention `.orchestrator-handoff.json` zero times** — the gap the dispatch's
  starting evidence already flagged, now verified complete across the full reachable set
  (not just the six samples given).
- **A previously-unflagged finding**: **6 more agents** (`general-implementation-agent`,
  `general-research-agent`, `cslib-implementation-agent`, `cslib-research-agent`,
  `lean-research-agent`, `lean-research-hard-agent`) mention the filename, but every single
  mention is an explicit **"MUST NOT write" / "non-writer by design" / "prohibition"**
  statement — the *opposite* of the obligation this task adds. These are not "already
  compliant" (the dispatch's own caution that "a nonzero count is not by itself evidence... of
  correctness" undersold the risk here — it isn't incompleteness, it's direct contradiction).
  Adding a bare "MUST write" bullet next to this existing text would make the file
  self-contradictory; each of these 6 needs its prohibition language **reversed/rewritten**, not
  merely supplemented.
- This reform is a deliberate, sweeping widening of a documented "settled decision":
  `docs/architecture/handoff-schema.md`'s "Handoff Writers" section states
  `.orchestrator-handoff.json` is "formally hard-mode-implement-only" and that "research agents
  never write a handoff at all, in any mode." That doc will become stale once this task (and its
  companion) land — flagged below as a follow-up, out of this task's file scope.
- `present`'s `critique` phase (`slide-critic-agent`) and second-level sub-dispatches
  (`document-agent`, `pptx-assembly-agent`, `spreadsheet-agent`) are correctly **excluded** from
  the reachable set — neither is ever the direct value of a `dispatch[]` row's `agent` field.

## Context & Scope

Task 194's SCOPE: every agent reachable via a `dispatch[]` row (research, plan, and implement
phases, core + every loaded extension) that lacks the handoff-writing obligation must gain an
explicit contract statement, worded and placed like the existing correct examples. The
companion task (out of this task's file scope) widens `orchestrate-cycle-postflight.sh`'s
`is_contractual_handoff_writer()` predicate to match; this task must land first so the widened
predicate does not flood `errors.json` with defects against agents never told to write anything.

**MUST NOT** (from the dispatch): do not touch `orchestrate-cycle-postflight.sh` or its
predicate; do not weaken/restate the `aux_dispatch[]` exemption; do not write task numbers into
any agent contract; edit `agent-system/extensions/*/agents/**` (source store), never
`.claude/**` (disposable deploy tree).

## Findings

### Derivation Method (reproducible)

1. `skill-orchestrate/SKILL.md` Move 2 confirms every `dispatch[]` row's `agent` field is
   resolved by `orchestrate-cycle-plan.sh` at plan time, and every row is issued as an `Agent`
   call with `orchestrator_mode: true` and a `handoff_path` key. `aux_dispatch[]` rows are
   categorically different: `agent` is fixed by `kind` (never task-type-routed) and the context
   carries **no `handoff_path` key at all** — an aux dispatch never writes a handoff. This
   asymmetry must be preserved (per the dispatch's own MUST NOT).
2. `dispatch[]`'s `phase` vocabulary is fixed at exactly `{research, plan, implement}` —
   confirmed directly in `orchestrate-cycle-plan.sh`'s own header comment ("dispatch[]'s own
   phase vocabulary (which stays exactly {research, plan, implement}") and its `jq`
   `["research","plan","implement"]` literal arrays. No other phase value ever appears as a
   `dispatch[]` row.
3. Each of the 19 extension `manifest.json` files (`core`, `cslib`, `email`, `epidemiology`,
   `filetypes`, `formal`, `founder`, `latex`, `lean`, `literature`, `memory`, `nix`, `nvim`,
   `present`, `python`, `rust`, `slidev`, `typst`, `web`, `z3`) was read directly. `literature`
   and `slidev` declare `"routing_exempt": true` and carry no `routing_agents` block at all —
   confirmed correctly out of scope (matches `CLAUDE.md`'s "skill-literature -> direct
   execution" note; `literature-agent` and any `slidev` agents are never `/orchestrate`-dispatched
   via `dispatch[]`).
4. Collected every value under each manifest's `.routing_agents.{research,plan,implement}` and
   `.routing_agents_hard.{research,plan,implement}` objects (18 manifests that declare
   `routing_agents`; only `cslib` and `lean` additionally declare `routing_agents_hard`),
   excluding `present`'s extra `critique` key (not a `dispatch[]` phase — confirmed via grep:
   `critique` appears nowhere in `orchestrate-cycle-plan.sh`'s phase handling, and
   `skill-slide-critic/SKILL.md`, the actual invoker of `slide-critic-agent`, never sets
   `orchestrator_mode`/`dispatch_file`/`handoff_path` — it is invoked by a separate,
   non-orchestrate skill).
5. Deduplicated to **64 unique agent names** (full list below). Every name resolved to exactly
   one `agent-system/extensions/*/agents/{name}.md` file — no missing files.
6. Second-level, router-internal sub-agents (`document-agent`, `spreadsheet-agent`,
   `pptx-assembly-agent`) are invoked by `filetypes-router-agent`/`presentation-agent` via their
   own internal `Agent` tool calls, whose delegation context (shown in
   `filetypes-router-agent.md` Stage 5) carries only `source_path`/`output_path`/`session_id`/
   `delegation_depth`/`delegation_path` — no `orchestrator_mode` or `handoff_path` at all.
   These are correctly excluded: they never receive `orchestrator_mode: true`, so the obligation
   (as worded by the dispatch — "on every dispatch where `orchestrator_mode` is true") does not
   reach them regardless. The router agent itself (`filetypes-router-agent`, `presentation-agent`)
   *is* the one directly named by `routing_agents` and *is* in scope.
7. `reviser-agent` was checked and confirmed **not** in any manifest's `routing_agents`/
   `routing_agents_hard` — it is dispatched only via `aux_dispatch[]` (fixed by `kind`, per
   SKILL.md Move 2), never via `dispatch[]`. Correctly out of scope; 0 mentions of the filename
   in its own contract, consistent with never needing the obligation.

### Full reachable set (64 agents) and current mention count

Mention count = occurrences of the literal string `orchestrator-handoff.json` in the agent's own
contract file (`grep -c`). **A count alone does not indicate obligation-correctness** — see next
subsection for the crucial distinction the dispatch's own caution undersold.

```
0  analyze-agent                       (founder)
0  budget-agent                        (present)
5  cslib-implementation-agent          (cslib)          -- PROHIBITION, see below
6  cslib-implementation-hard-agent     (cslib)          -- CORRECT existing obligation
5  cslib-research-agent                (cslib)          -- PROHIBITION, see below
0  cslib-research-hard-agent           (cslib)
0  deck-builder-agent                  (founder)
0  deck-planner-agent                  (founder)
0  deck-research-agent                 (founder)
0  docx-edit-agent                     (filetypes)
0  email-implementation-agent          (email)
0  epi-implement-agent                 (epidemiology)
0  epi-research-agent                  (epidemiology)
0  filetypes-router-agent              (filetypes)
0  filetypes-spreadsheet-agent         (filetypes)
0  finance-agent                       (founder)
0  financial-analysis-agent            (founder)
0  formal-research-agent               (formal)
0  founder-implement-agent             (founder)
0  founder-plan-agent                  (founder)
0  founder-spreadsheet-agent           (founder)
0  funds-agent                         (present)
5  general-implementation-agent        (core)           -- PROHIBITION, see below
2  general-research-agent              (core)           -- PROHIBITION, see below
0  grant-agent                         (present)
0  latex-implementation-agent          (latex)
0  latex-research-agent                (latex)
0  lean-implementation-agent           (lean)
7  lean-implementation-hard-agent      (lean)           -- CORRECT existing obligation
2  lean-research-agent                 (lean)           -- PROHIBITION, see below
2  lean-research-hard-agent            (lean)           -- PROHIBITION, see below
0  legal-analysis-agent                (founder)
0  legal-council-agent                 (founder)
0  logic-research-agent                (formal)
0  market-agent                        (founder)
0  math-research-agent                 (formal)
0  meeting-agent                       (founder)
0  neovim-implementation-agent         (nvim)
0  neovim-research-agent               (nvim)
0  nix-implementation-agent            (nix)
0  nix-research-agent                  (nix)
0  physics-research-agent              (formal)
0  planner-agent                       (core)
0  presentation-agent                  (filetypes)
0  project-agent                       (founder)
0  pr-review-implementation-agent      (cslib)
0  pr-review-research-agent            (cslib)
0  python-implementation-agent         (python)
0  python-research-agent               (python)
0  rust-implementation-agent           (rust)
0  rust-research-agent                 (rust)
0  scrape-agent                        (filetypes)
0  sheet-agent                         (filetypes)
0  slide-planner-agent                 (present)
0  slides-research-agent               (present)
0  slidev-assembly-agent               (present)
0  strategy-agent                      (founder)
0  timeline-agent                      (present)
0  typst-implementation-agent          (typst)
0  typst-research-agent                (typst)
0  web-implementation-agent            (web)
0  web-research-agent                  (web)
0  z3-implementation-agent             (z3)
0  z3-research-agent                   (z3)
```

**56 agents (count = 0)**: verified these are genuinely silent on `.orchestrator-handoff.json`,
not merely using different phrasing — checked every 0-count agent for case-insensitive
`handoff` mentions. Nine implementation agents (`latex`, `lean-implementation-agent` [non-hard],
`neovim`, `nix`, `python`, `rust`, `typst`, `web`, `z3`) do mention "handoff", but every mention
is the **unrelated** progressive/context-pressure handoff mechanism
(`specs/{NNN}_{SLUG}/handoffs/phase-{P}-handoff-{TIMESTAMP}.md`) — a completely different file,
purpose, and consumer from `.orchestrator-handoff.json`. These 9 genuinely need the new
obligation added as new content, not a rewording of existing handoff text.

### The 6 "prohibition" agents — a distinct, higher-risk sub-scope

`general-implementation-agent`, `general-research-agent`, `cslib-implementation-agent`,
`cslib-research-agent`, `lean-research-agent`, `lean-research-hard-agent` each carry deliberate,
well-reasoned **"MUST NOT write `.orchestrator-handoff.json`"** or **"non-writer by design"**
language, e.g.:

- `cslib-implementation-agent.md:461-463`: "**`.orchestrator-handoff.json` prohibition**: this
  agent MUST NOT write `.orchestrator-handoff.json`, in any mode, including when
  `orchestrator_mode: true` is present in the delegation context." Also appears as a numbered
  MUST-NOT checklist item (line 691-692): "22. Write .orchestrator-handoff.json -- base-mode
  implementation never writes a handoff (see Stage 7)".
- `cslib-research-agent.md:299-301,370`: identical prohibition wording plus checklist item 16.
- `general-implementation-agent.md:688-694`: "### `.orchestrator-handoff.json` (base-mode
  implement is a non-writer by design)... does **not** write `.orchestrator-handoff.json`, by
  design — matching the 'Never writes a handoff, by design' row of
  `docs/architecture/handoff-schema.md`'s 'Handoff Writers' table."
  (This is also this agent's own general-research-agent counterpart's mirror — this present
  research-agent's own contract has the equivalent text: "Do NOT use `wrap-up.md`'s H9 schema or
  `.orchestrator-handoff.json` for research — that schema and its consumer allowlist are
  implementation-agent-only.")
- `general-research-agent.md:206,212`: matching "Do NOT" language plus a "Defensive case, if
  this scoping decision is ever reversed" fallback paragraph.
- `lean-research-agent.md:340-342`, `lean-research-hard-agent.md:357-359`: "`.orchestrator-
  handoff.json` (research is a non-writer by design) ... does **not** write
  `.orchestrator-handoff.json`, by contract."

**Implication for planning**: these 6 files cannot receive an additive edit (append a "MUST
write" bullet) without becoming internally self-contradictory. Each needs its prohibition
section's core claim reversed to the new obligation while preserving whatever adjacent content
is still correct (e.g. `general-research-agent`'s and `general-implementation-agent`'s
"Defensive case" fallback paragraphs, which already correctly describe *how* to write the file
if ever needed — that mechanical detail remains useful and should likely be promoted from
"defensive/hypothetical" framing to the new normal-path obligation, not deleted). This is
materially more delicate than the 56 zero-count agents' additive edit and should likely be
called out as its own phase or explicitly enumerated sub-step in the plan.

### The 2 correct existing examples (template source)

`cslib-implementation-hard-agent.md` and `lean-implementation-hard-agent.md` are the only two
agents matching `docs/architecture/handoff-schema.md`'s documented writer allowlist
(`is_contractual_handoff_writer()` in `orchestrate-cycle-postflight.sh` — not modified by this
task). Representative wording to match (`lean-implementation-hard-agent.md:279-311` area,
`cslib-implementation-hard-agent.md:281-311` area — near-identical since one was cloned from the
other):

- States the absolute-path requirement: use `{handoff_path}` from the delegation context, or
  `{task_dir}/.orchestrator-handoff.json` with absolute `task_dir` as fallback; "NEVER write a
  bare `.orchestrator-handoff.json` filename."
- States it is written "at end of every dispatch" with `sorry_inventory`/domain-specific fields,
  and on `status: "partial"` returns and context-pressure handoffs alike.

The dispatch names these two as "the fullest existing examples" to match wording/placement
against — confirmed accurate; they are also the *only* agents with an affirmative (non-
prohibitive) obligation statement anywhere in the reachable set.

### Architecture-documentation tension (flagged, not resolved here)

`agent-system/extensions/core/docs/architecture/handoff-schema.md`'s "Handoff Writers — the
settled decision, in one place" section (lines 386-410) currently documents:
- `.orchestrator-handoff.json` is "formally hard-mode-implement-only."
- "Research agents never write a handoff at all, in any mode... This is a decided contract, not
  a default that happened to emerge."
- Base-mode `general-research-agent`/`planner-agent`/`general-implementation-agent` are "Never
  writes a handoff, by design."
- A **recorded, explicit "Open question, not decided here"** paragraph (lines 449-453) already
  acknowledges the exact tension this task resolves: "live delegation contexts have been
  observed supplying a `handoff_path` and an instruction to write to a base-mode research agent,
  contradicting the categorical... claim." It names two candidate resolutions — (a) stop
  instructing research agents to write the file, or (b) expand the documented writer set to
  match observed practice — and explicitly declines to pick, leaving it "a maintainer-level
  decision."

Task 194 (plus its companion) is, in effect, resolving that open question in favor of option
(b) — this reads as deliberate given the dispatch's precise, detailed SCOPE wording ("on every
dispatch where `orchestrator_mode` is true," unconditional). This is not treated as a
`user_decision`-worthy ambiguity here: the dispatch's instruction is unambiguous and detailed
enough to execute directly, not underspecified. It is flagged instead as a **required follow-up**
(see Context Extension Recommendations) — `handoff-schema.md`'s "Handoff Writers" table and
"Writer-Contract Determination (D1)" allowlist section will both go stale the moment the
companion task widens the predicate and this task's obligations land; nothing in this task's
own file scope (`agent-system/extensions/*/agents/**`) touches that doc, so a follow-up task
should update it (or the companion task's own scope should, if it already touches
`orchestrate-cycle-postflight.sh` and is naturally positioned to update the doc describing that
script's predicate in the same commit).

## Decisions

- **Reachable-set derivation is manifest-driven, not `.claude/agents/*.md`-file-driven**: used
  `agent-system/extensions/*/manifest.json`'s `routing_agents`/`routing_agents_hard` blocks
  (the source-of-truth mapping `orchestrate-cycle-plan.sh` itself reads), per the dispatch's own
  instruction, rather than enumerating every `agents/*.md` file on disk (which would incorrectly
  include second-level sub-agents like `document-agent`/`pptx-assembly-agent` and any
  not-yet-wired agent files).
- **`present`'s `critique` phase and `slide-critic-agent` are excluded** — confirmed
  `dispatch[]`'s phase vocabulary is fixed at `{research, plan, implement}`; `critique` is
  routed by a separate, non-orchestrate skill (`skill-slide-critic`).
- **`literature` and `slidev` extensions are excluded** — both declare `routing_exempt: true`
  and no `routing_agents` block.
- **`reviser-agent` is excluded** — `aux_dispatch[]`-only, never `dispatch[]`, per
  `skill-orchestrate/SKILL.md` Move 2's explicit "never task-type-routed" note for aux rows.

## Risks & Mitigations

- **Risk**: treating all 8 nonzero-count agents as "already has the obligation, skip" (a naive
  reading of the dispatch's starting evidence) would leave 6 of them self-contradictory after a
  naive additive edit elsewhere in the same file, or — worse — leave them completely untouched
  and still stating the *opposite* of the new system-wide obligation.
  **Mitigation**: plan phase should explicitly split the edit set into three groups: (1) 56
  zero-count agents — pure additive edit; (2) 6 prohibition agents — targeted reversal of the
  specific prohibition section/checklist item, preserving other correct adjacent content; (3) 2
  already-correct agents — no edit needed (verify only).
- **Risk**: `docs/architecture/handoff-schema.md` becomes misleading/stale immediately after
  this task lands (still says "hard-mode-implement-only" when the contracts now say otherwise).
  **Mitigation**: not in this task's file scope — flagged as a follow-up (see below); plan phase
  should decide whether to note this explicitly in the task's own summary for a future task, or
  leave it for whoever owns the companion task.
- **Risk**: some of the 56 zero-count implementation agents (`latex`, `neovim`, `nix`, `python`,
  `rust`, `typst`, `web`, `z3`, `lean-implementation-agent`) already have a "Stage 4E context-
  pressure handoff" or similar section under a heading like "#### Stage 4E. Handoff on Context
  Pressure" — the new `.orchestrator-handoff.json` obligation must be placed so it is clearly
  distinguished from that pre-existing, differently-scoped handoff mechanism, to avoid a reader
  conflating the two file types (a confusion this report itself had to resolve carefully).

## Context Extension Recommendations

- **Topic**: `.orchestrator-handoff.json` writer-contract documentation
  **Gap**: `docs/architecture/handoff-schema.md`'s "Handoff Writers" table and
  "Writer-Contract Determination (D1)" section will describe a 2-agent allowlist that is no
  longer accurate once this task and its companion land.
  **Recommendation**: a follow-up task (or the companion task, if convenient) should update
  `docs/architecture/handoff-schema.md` to reflect the widened writer set and resolve its own
  "Open question, not decided here" paragraph, which this task effectively answers.

## Appendix

### Search commands used

```bash
# Manifest phase-key survey
for f in agent-system/extensions/*/manifest.json; do jq -r '.routing_agents // {} | keys[]' "$f"; done | sort -u
for f in agent-system/extensions/*/manifest.json; do jq -r '.routing_agents_hard // {} | keys[]' "$f"; done | sort -u

# Reachable-set extraction (research/plan/implement only, both routing_agents and routing_agents_hard)
for f in agent-system/extensions/*/manifest.json; do
  jq -r '[(.routing_agents.research//{}),(.routing_agents.plan//{}),(.routing_agents.implement//{}),
          (.routing_agents_hard.research//{}),(.routing_agents_hard.plan//{}),(.routing_agents_hard.implement//{})][] | .[]?' "$f"
done | sort -u

# Per-agent mention count + file resolution
while read -r agent; do
  f=$(find agent-system/extensions -path "*/agents/${agent}.md" | head -1)
  grep -c "orchestrator-handoff.json" "$f"
done < reachable_agents.txt

# Alternate-phrasing check on zero-count agents
grep -ic "handoff" "$f"   # per zero-count agent file
```

### References

- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (Move 2, Move 3)
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` (phase vocabulary, dispatch
  agent resolution)
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` ("Handoff Writers", D1)
- `agent-system/extensions/filetypes/agents/filetypes-router-agent.md` (second-level sub-dispatch
  pattern)
- `agent-system/extensions/present/skills/skill-slide-critic/SKILL.md` (critique phase, non-
  orchestrate invocation)
- All 19 `agent-system/extensions/*/manifest.json` files
- All 64 reachable agents' `agent-system/extensions/*/agents/*.md` contract files
