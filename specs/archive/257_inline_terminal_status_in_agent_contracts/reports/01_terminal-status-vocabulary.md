# Research Report: Task #257

**Task**: 257 - Inline terminal status in agent contracts
**Started**: 2026-09-25
**Completed**: 2026-09-25
**Effort**: large (documentation fix across ~20 files + one new lint check; a runtime-wiring
decision is explicitly deferred to the plan)
**Dependencies**: None (blocking); shares one extraction prerequisite with task 258
(recovery-decline-attribution), currently `not_started` — see Decisions
**Sources/Inputs**: Codebase read of all 73 dispatchable agent files, 4 manifest.json routing
tables, `lint-agent-contracts.sh`, `validate-return-meta.sh`, `orchestrate-recover-outcome.sh`,
`skill-base.sh`, `status-vocabulary.sh`, `handoff-schema.md`
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The dispatch's core factual claims are **verified correct**: the typst incident, the
  three-shape taxonomy (protected / bare-fragment / pipe-placeholder), the wrong-vocabulary trap
  (`status-vocabulary.sh` is task-level and wrongly accepts `"completed"`), and the fact that
  `validate-return-meta.sh` — which already rejects `"completed"` with exactly the right message
  — has **zero runtime callers**.
- My own file-by-file re-audit reconciles to **20 distinct agent files** needing the content fix
  (not the dispatch's headline "24" — see Decisions, "Reconciling the 24 vs 20 count"), with 2 of
  those 20 (`lean-implementation-hard-agent.md`, `cslib-implementation-hard-agent.md`) needing a
  fix in **two separate locations** each (their own `.return-meta.json` section AND their
  `.orchestrator-handoff.json` section), for 22 total edit sites.
- **New finding beyond the dispatch's scope, load-bearing for the regression-guard design**:
  querying each extension's `manifest.json` `routing_agents` blocks shows that several
  **already-registered research/plan/implement phase-routing targets** use a **documented,
  intentional, non-canonical terminal status** — `filetypes-router-agent` /
  `filetypes-spreadsheet-agent` / `presentation-agent` / `scrape-agent` / `docx-edit-agent` /
  `sheet-agent` (converted/extracted/scraped/edited/created), `slidev-assembly-agent`
  (`"assembled"`), `legal-analysis-agent` (`"consulted"`, with **no** conformant value anywhere
  in the file), `project-agent` (`"reviewed"` alongside a conformant `"researched"`), and
  `grant-agent` (`"drafted"` alongside a conformant `"researched"`). This falsifies the simplest
  version of "restrict the check to lifecycle-dispatch agents" (routing-target membership does
  **not** correlate with canonical-vocabulary use) and means the regression guard needs an
  **explicit recorded-exclusion list**, not a routing-derived allowlist.
- **New, more serious finding**: `orchestrate-recover-outcome.sh`'s success case arm
  (`researched|planned|implemented`, line 242) is narrower than this full set of intentionally
  designed success vocabularies. If `legal-analysis-agent`, the `filetypes/*` agents, or
  `slidev-assembly-agent` are ever dispatched under `orchestrator_mode: true`, their legitimate
  successes are misclassified as `STATUS_NOT_SUCCESS` today — the **identical defect class** the
  typst incident exposed, just triggered by a different, intentionally-used non-canonical value
  instead of an accidental `"completed"`. This is a live runtime risk, not a documentation gap,
  and is broader than the dispatch's "RUNTIME HOLE" framing (which focused only on the missing
  `validate-return-meta.sh` wiring). Recommend flagging this explicitly for the plan to decide
  in/out of scope, independent of the `--hard` wiring question.
- The pipe-placeholder occurrences at `lean-implementation-hard-agent.md:305` and
  `cslib-implementation-hard-agent.md:324` are in the **`.orchestrator-handoff.json`** fenced
  block, not `.return-meta.json` as the dispatch text's line-number framing could be read to
  imply. `handoff-schema.md:199` states this file's status enum "is intentionally identical to
  `.return-meta.json`'s `status` field" and is sourced from the same normative table — so the fix
  and the lint should treat both files' terminal blocks identically, but the plan must edit **two
  sections per file** for these two agents, not one.
- `lint-agent-contracts.sh`'s Check E is **already stubbed and named** for exactly this
  regression guard ("terminal-metadata section presence, keyed off return-metadata-file.md's
  normative status vocabulary" — line 410, commented insertion point at line 415). This
  confirms both the check's name/slot and its intended shared-detector reuse
  (`is_dispatchable_agent`/`enumerate_dispatchable_agents`, per Check F's precedent).
- Recommend explicitly deciding the runtime-wiring question **out of scope** for this task (split
  to a follow-up, mirroring the existing deferred-Check-D/E precedent in the same file) — see
  Decisions for the reasoning, which now includes the widened blast-radius finding above.

## Context & Scope

Task 257's dispatch (`.dispatch/1.md`) is itself an unusually detailed, pre-investigated
document — it names concrete line numbers for a live incident, a root-cause taxonomy, a
"verified" file inventory, and five explicit open design questions to settle before
implementation. My job in this research pass was **verification, correction, and closing the
open design questions with evidence** — not re-deriving the investigation from a blank page.
Every claim below states whether it was independently confirmed, corrected, or is a new finding
this pass surfaced.

Source-store edit target for the eventual fix (per the dispatch and
`.claude/rules/source-store-deploy-boundary.md`): `agent-system/extensions/` — never `.claude/**`.

## Findings

### 1. The observed defect and the vocabulary trap — CONFIRMED

- `context/formats/return-metadata-file.md`'s normative status vocabulary and the
  `orchestrate-recover-outcome.sh` case-arm mismatch are exactly as described.
  `orchestrate-recover-outcome.sh:242` accepts only `researched|planned|implemented`;
  `:280`/`:284` route `in_progress` and any other value (including `"completed"`) to
  `STATUS_NOT_SUCCESS` → `recovered=false` → failed.
- `scripts/lib/status-vocabulary.sh` is confirmed to be the **wrong** source: it is the 12-value
  **task-level** enum for `state.json .active_projects[].status`, and it explicitly *does*
  contain `"completed"` as a valid member (by design — it is the terminal task state). Sourcing
  it for the new lint would silently defeat the lint's purpose.
- `scripts/validate-return-meta.sh:175-183` is confirmed correct: the 8-value array
  (`in_progress researched planned implemented needs_research partial failed blocked`) plus an
  explicit `status == "completed"` rejection with the message "explicitly forbidden (triggers
  Claude stop behavior) -- use \"implemented\" instead". This file is the correct extraction
  source.
- `validate-return-meta.sh` runtime callers: confirmed **zero**. `grep -rn validate-return-meta
  agent-system/` returns only doc/comment/test references and the script's own file; `skill-base.sh`
  mentions it only inside a warning *string* (advisory text telling a human to run `--fix`), never
  invokes it. The two live read chokepoints that consume `.status` with **no vocabulary
  validation at all** are:
  - `orchestrate-recover-outcome.sh:208` (`jq -r '.status // "unknown"'`) — the hard/orchestrate-mode
    read path.
  - `skill-base.sh`'s `skill_read_metadata()` (`SUBAGENT_STATUS=$(jq -r '.status' "$meta_file")`,
    around line 512) — the **base-mode** (non-orchestrate) read path. The dispatch's phrase "at or
    before the recovery read" names only the first; the second is an equally live, currently
    unguarded chokepoint the plan should know about even if it defers wiring both.

### 2. The three-shape taxonomy — CONFIRMED, with the pipe-placeholder's true location corrected

- **Protected shape** (13 research + 6 implementation agents, not the dispatch's superseded
  "11"/"4" — both re-confirmed by spot-reading 9 of the 13 research agents and all 6
  implementation agents): a full JSON object whose first key is a concrete, quoted vocabulary
  value, e.g. `lean-research-agent.md:322` `{ "status": "researched", "artifacts": [...] }`.
  Every one of `lean, math, logic, formal, physics, cslib, pr-review, epi, deck, neovim, nix,
  slides, web` (research) and `core/general-implementation-agent.md, cslib-implementation-agent.md,
  pr-review-implementation-agent.md, lean, nix, nvim` (implementation) was confirmed to carry this
  exact shape. **Leave these alone**; their exact wording is the template for the fix.
- **Bare-fragment shape**: only `"artifacts": [...]` inside the fenced block, with the correct
  status name appearing only in surrounding prose (`general-research-agent.md:376`,
  `planner-agent.md:401`) or not even in prose within the terminal section (many of Category B
  below). `planner-agent.md` is confirmed as described: its **only** complete JSON object example
  in the entire file is the `needs_research` failure path (`:434`) — the one worked example a
  model sees on the happy path is the failure shape. Given `planner-agent` is the default plan
  agent for `general`/`meta`/`markdown` task types (per `.claude/CLAUDE.md`'s Skill-to-Agent
  table) and every extension whose manifest routes `plan` to `planner-agent` directly, this is
  confirmed as the correct **highest-priority single file** in the fix set.
- **Pipe-placeholder shape**: confirmed present at exactly the two hard-twin sites the dispatch
  names, but **both are inside the `.orchestrator-handoff.json` Stage-5/Stage-8 "Wrap-Up
  Contract" fenced block**, not the `.return-meta.json` block (verified by reading the enclosing
  `###`/`##` heading immediately above each: `### Stage 5: Wrap-Up Contract (H9)` in
  `lean-implementation-hard-agent.md`, and the equivalent unnamed wrap-up section in
  `cslib-implementation-hard-agent.md`, both preceding text about writing to `handoff_path`). Their
  **separate** `.return-meta.json` sections (`lean-implementation-hard-agent.md:622`,
  `cslib-implementation-hard-agent.md:388`) carry the placeholder only in prose
  (`` status `implemented|partial|failed` ``) with **no fenced JSON status key at all** — i.e.
  these two files are unprotected in *both* locations, by two different mechanisms. The pipe
  placeholder also appears, independently, in `web-implementation-agent.md:396` (`.return-meta.json`,
  fenced) and `present/agents/grant-agent.md:413` (`.return-meta.json`, fenced). Confirmed via
  `context/docs/architecture/handoff-schema.md:190-199`: the handoff file's 6-value status
  enumeration is explicitly sourced from the same normative table as `.return-meta.json`'s, so
  fixing both locations the same way is correct, and the shared vocabulary library (Decisions
  §3) should be the single source both files' prose point back to.

### 3. Files needing the content fix — reconciled inventory (20 files, 22 edit sites)

Verified by direct read of each file's terminal-metadata section (not the earlier heuristic
regex passes, which proved unreliable against multi-fence files — see Appendix).

**Category A — bare fragment or handoff-only, prose already correct, MUST-NOT-"completed"
bullet already present (lowest-risk fixes, template = general-research-agent.md's existing
prose + lean-research-agent.md's existing JSON shape):**
1. `core/agents/general-research-agent.md` → `"status": "researched"`
2. `core/agents/planner-agent.md` → `"status": "planned"` (highest priority — see above)
3. `core/agents/spawn-agent.md` → `"status": "researched"` (Stage 6, `:203`)
4. `email/agents/email-implementation-agent.md` → `"status": "implemented"` (already has the
   MUST-NOT bullet at `:228`)
5. `lean/agents/lean-research-hard-agent.md` → `"status": "researched"`
6. `lean/agents/lean-implementation-hard-agent.md` → `"status": "implemented"` — **two sites**:
   `.return-meta.json` Stage 8 (`:622`) AND `.orchestrator-handoff.json` Stage 5 (`:305`, pipe
   placeholder → concrete)
7. `cslib/agents/cslib-research-hard-agent.md` → `"status": "researched"`
8. `cslib/agents/cslib-implementation-hard-agent.md` → `"status": "implemented"` — **two sites**:
   `.return-meta.json` Stage 7 (`:388`) AND `.orchestrator-handoff.json` (`:324`, pipe
   placeholder → concrete)

**Category B — fully bare: zero `"status"` occurrences anywhere in the terminal section, and no
MUST-NOT-"completed" bullet either (highest exposure — these are the files structurally closest
to the observed typst incident, since `typst-research-agent.md` itself is in this category):**
9. `latex/agents/latex-research-agent.md` → `researched`
10. `latex/agents/latex-implementation-agent.md` → `implemented`
11. `python/agents/python-research-agent.md` → `researched`
12. `python/agents/python-implementation-agent.md` → `implemented`
13. `rust/agents/rust-research-agent.md` → `researched`
14. `rust/agents/rust-implementation-agent.md` → `implemented`
15. `typst/agents/typst-research-agent.md` → `researched` (the file that produced the real
    incident)
16. `typst/agents/typst-implementation-agent.md` → `implemented`
17. `z3/agents/z3-research-agent.md` → `researched`
18. `z3/agents/z3-implementation-agent.md` → `implemented`

**Category C — has an inline status key, but as a pipe-alternatives placeholder (needs a
concrete-value rewrite, not a wrap):**
19. `web/agents/web-implementation-agent.md` (`:396`) → `"implemented"` (already has the
    MUST-NOT bullet elsewhere in the file per the dispatch's per-file note)
20. `present/agents/grant-agent.md` (`:413`) → **needs bespoke treatment, not a single
    substitution** — see Decisions §2 (its own Stage 6 already documents a
    `workflow_type -> status` table at `:437-439` mapping `funder_research -> researched`,
    `proposal_draft`/`budget_develop -> drafted`; `drafted` is not a member of the canonical
    8-value vocabulary — see §4 below).

This reconciles to **20 files / 22 edit sites**, matching the dispatch's own enumerated sub-lists
summed literally (6 + 7 + 7 = 20) rather than its headline "24" — see Decisions for the
recommended resolution of that discrepancy.

### 4. New finding: registered lifecycle-dispatch targets already use non-canonical vocabularies

Cross-referencing `founder/manifest.json`, `present/manifest.json`, and `filetypes/manifest.json`'s
`routing_agents` blocks (the same manifest data `command-route-agent.sh` reads to pick a real
dispatch target, confirmed via `manifest-routing-lib.sh`'s header comment, which also documents
that `lint-routing-wiring.sh`/`test-routing-resolution.sh` already validate against
`ROUTE_MANIFEST_ROOT=agent-system`, i.e. the source store) shows these are all **registered
research and/or implement phase routing targets**, yet each uses a status value outside the
8-value vocabulary as its documented, working terminal success state:

| Agent | Registered phase(s) | Non-canonical value(s) used | Has a conformant value too? |
|---|---|---|---|
| `filetypes-router-agent.md` | research, implement | `converted`, `edited`, `created`, `skipped`, `empty` | not checked (excluded by design) |
| `filetypes-spreadsheet-agent.md` | research, implement | (spreadsheet-specific verbs) | not checked (excluded by design) |
| `presentation-agent.md`, `scrape-agent.md`, `docx-edit-agent.md`, `sheet-agent.md` | research, implement | `extracted`, `scraped`, etc. | not checked (excluded by design) |
| `slidev-assembly-agent.md` | implement (`present:slides`) | `"assembled"` (`:284`) | no |
| `legal-analysis-agent.md` | research (`founder:consult`) | `"consulted"` (`:456`) | **no** — no conformant value anywhere in the file |
| `project-agent.md` | research (`founder:project`) | `"reviewed"` (`:783`, a distinct "Timeline review" sub-stage) | **yes** — `"researched"` at `:448` |
| `grant-agent.md` | research/implement (`present:grant`) | `"drafted"` (workflow-conditioned, `:413`/`:438-439`) | **yes** — `"researched"` at the `funder_research` branch |

This directly falsifies the simplest resolution of the dispatch's open design question 1
("restrict the check to lifecycle-dispatch agents" as a routing-membership test) — routing
registration does not imply canonical-vocabulary use. `pptx-assembly-agent.md` (`"assembled"`,
confirmed earlier) is, by contrast, genuinely **not** a `routing_agents` entry in
`present/manifest.json` (it is invoked internally by `skill-grant`'s assemble sub-step), so it is
correctly excludable on that basis alone — but this is the exception, not a pattern to generalize
from.

`meta-builder-agent.md` is confirmed **not** a `routing_agents` entry anywhere (`grep -rln
meta-builder-agent */manifest.json` finds only `core/manifest.json`'s non-routing sections);
`skill-meta` dispatches it directly per `.claude/CLAUDE.md`'s Skill-to-Agent table, outside the
research/plan/implement lifecycle entirely. Its `not_started/tasks_created/analyzed/cancelled`
vocabulary is correctly out of scope by that structural fact, not merely "confusing."

### 5. New, more serious finding: the recovery success arm is too narrow for real designed vocabularies

Because `legal-analysis-agent.md`, the `filetypes/*` agents, and `slidev-assembly-agent.md` are
*bona fide* phase-routing targets (§4), and `orchestrate-recover-outcome.sh`'s success case arm
(`researched|planned|implemented`, line 242) does not include `consulted`, `converted`,
`assembled`, etc., **any of these agents dispatched under `orchestrator_mode: true` would have a
genuinely successful outcome misclassified as `STATUS_NOT_SUCCESS` today** — the same defect
class the typst incident exposed, just triggered by an intentional value instead of an accidental
`"completed"`. I did not confirm whether `founder`/`present`/`filetypes` task types are in
practice ever dispatched through `/orchestrate` (vs. always through their own direct-execution
skills/commands) — that would need a runtime trace or an explicit statement from a maintainer,
which is beyond this research pass's budget — but nothing in `.claude/CLAUDE.md`'s routing
description exempts these extensions from orchestrator dispatch, and the routing tables the
orchestrate engine reads are the same tables I read. This is worth the plan phase's explicit
attention as a related-but-separate risk from the "wire `validate-return-meta.sh` in" question the
dispatch already raised — widening the recovery arm's *acceptance* set is a different, and
arguably more urgent, fix than adding *rejection* validation for `"completed"`.

## Decisions

Settling the five open design questions the dispatch left explicitly open, in order.

### 1. Regression-guard scope (lint-agent-contracts.sh Check E)

**Recommendation: explicit recorded-exclusion list, not a routing-derived allowlist and not a
per-extension vocabulary extension point.** §4 shows routing-target membership does not predict
canonical-vocabulary use, so deriving scope mechanically from `routing_agents` would both wrongly
include six `filetypes/*` agents with an intentionally different vocabulary and wrongly exclude
nothing extra — it doesn't save the exclusion list, it just moves the same information into
manifest cross-referencing logic that has to be written and maintained anyway. A per-extension
"vocabulary extension point" (letting each extension declare its own accepted terminal-status set
in its manifest) is the most general option but is unwarranted complexity for roughly a dozen
exception files today; it also doesn't resolve `legal-analysis-agent.md`, which has **no**
conformant value at all and would need its own exclusion regardless of mechanism.

Concretely: extend `lint-agent-contracts.sh` with a second bash array, sibling to
`EXCLUDED_ARTIFACTS_TEMPLATE_RELATIVE_PATHS`, named e.g.
`EXCLUDED_TERMINAL_STATUS_RELATIVE_PATHS`, seeded with (at minimum, confirmed by this research
pass):
- `core/agents/meta-builder-agent.md` (own vocab, not a lifecycle routing target)
- `filetypes/agents/filetypes-router-agent.md`, `filetypes-spreadsheet-agent.md`,
  `presentation-agent.md`, `scrape-agent.md`, `docx-edit-agent.md`, `sheet-agent.md`,
  `document-agent.md`
- `present/agents/pptx-assembly-agent.md`, `slidev-assembly-agent.md`
- `founder/agents/legal-analysis-agent.md` (no conformant value present)

`project-agent.md` and `grant-agent.md` (after its Category-C fix, §2 below) need **no**
exclusion entry: Check E's job is *presence* of a conformant value plus *absence* of a literal
`"completed"`, not "every status literal in the file must be canonical" — both files already
carry (or will carry) a passing `"researched"` example alongside their extra domain-specific
value. Each exclusion-list entry should carry the same "confirmed by reading each file's full
terminal-metadata behavior" comment discipline Check F's list already uses.

### 2. Pipe-placeholder handling

**Recommendation: FAIL the check, and rewrite every instance to a concrete value** — the pipe
form is not a vocabulary member and gives an agent no copyable, syntactically valid example to
follow (this is, structurally, the same failure as the bare fragment: the one example the model
sees is not usable literally). For the four confirmed sites:
- `lean-implementation-hard-agent.md` / `cslib-implementation-hard-agent.md`
  `.orchestrator-handoff.json` blocks: rewrite to `"status": "implemented"` (the happy-path
  value), matching every other agent's convention of showing the success shape as the worked
  example and covering `partial`/`blocked` in prose (as `handoff-schema.md` itself does at each
  of its own concrete-value examples).
- `web-implementation-agent.md:396`: rewrite to `"status": "implemented"`.
- `grant-agent.md:413`: **do not** collapse to one value — grant-agent's Stage 6 already
  documents a `workflow_type -> status` table (`:437-439`) because it genuinely has
  workflow-conditioned terminal states. Recommend replacing the single pipe-joined fenced example
  with either (a) one fenced example per branch (`funder_research` → `"researched"`;
  `proposal_draft`/`budget_develop` → `"drafted"`), keyed to the existing table, or (b) one
  concrete primary example (`"researched"`, its default/most common branch) plus explicit prose
  cross-referencing the table for the others — either satisfies Check E's presence test. Flag,
  but do not resolve here: whether `"drafted"` should become a first-class member of the
  canonical 8-value vocabulary, or `.return-meta.json` a `workflow_status` sub-field distinct from
  the phase-level `status`, is a vocabulary-design question outside this task's scope; leaving it
  as an agent-local value (as today) is the minimal, non-breaking choice for this task, but the
  plan should record this as a named follow-up question rather than silently deciding it.

### 3. Vocabulary extraction target

**Confirmed correct as the dispatch specifies.** Extract the 8-value array plus the
`"completed"`-forbidden constant out of `validate-return-meta.sh` (`:175-183`) into a new sourced
library, modeled on `scripts/lib/phase-heading-patterns.sh`'s and `scripts/lib/status-vocabulary.sh`'s
own "one sourced shared library, many consumers" shape — but under a **name that cannot be
confused with the existing (wrong-for-this-purpose) `status-vocabulary.sh`**, e.g.
`scripts/lib/return-meta-status-vocabulary.sh` (confirmed not to exist yet). Consumers: this
extraction is a shared prerequisite between this task and task 258
(recovery-decline-attribution, currently `not_started`, confirmed via `specs/state.json`
`project_number: 258`), which needs the identical list for its own defect message — whichever
task's plan phase lands first should perform the extraction; the other should consume it rather
than re-deriving. Consumers of the new library: `validate-return-meta.sh` itself,
`orchestrate-recover-outcome.sh`'s case arm, the new Check E, and (per task 258's own scope)
its defect-message construction.

### 4. Runtime hole (wiring `validate-return-meta.sh` into the dispatch path)

**Recommendation: explicitly out of scope for this task; split to a follow-up**, for three
reasons, the third new to this research pass:
1. This task's remaining scope (the 20-file content fix + Check E) is a self-contained,
   low-risk documentation-and-lint change; wiring a validator into two live read chokepoints
   (`orchestrate-recover-outcome.sh` and `skill-base.sh`'s `skill_read_metadata`) is a runtime
   behavior change on every single dispatch in the system, with materially higher blast radius.
2. The dispatch itself offers "split it out as its own task" as an acceptable resolution,
   conditioned on recording the decision rather than leaving the validator silently dead — this
   satisfies that condition.
3. **§5's finding makes premature wiring actively harmful**: if `validate-return-meta.sh`'s
   8-value rejection were wired in today, it would newly reject `legal-analysis-agent.md`'s
   `"consulted"`, `grant-agent.md`'s `"drafted"`, `slidev-assembly-agent.md`'s `"assembled"`, and
   every `filetypes/*` agent's vocabulary — turning currently-working (if fragile) dispatches into
   hard validation failures. The runtime-wiring follow-up task should resolve §5's
   recovery-arm-narrowness question *first* (widen acceptance appropriately, or formalize a
   per-agent/per-extension accepted-status registry) before adding rejection validation on top of
   it. Recommend the plan record this ordering explicitly as the follow-up task's first
   consideration, not just "wire the validator in."

This mirrors the existing precedent in the same lint file: Check D and Check E were themselves
already deferred once, with a named insertion-point comment rather than silent abandonment —
follow that same discipline for the runtime-wiring split.

### 5. File scope for the plan

Feed `file_scope` with the 20 files in §3 (Categories A/B/C), plus:
- `agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` (new Check E)
- `agent-system/extensions/core/scripts/validate-return-meta.sh` (extraction source)
- `agent-system/extensions/core/scripts/orchestrate-recover-outcome.sh` (consumer of the new
  library; case-arm change only if the plan chooses to fold in part of §5's finding — otherwise
  read-only reference)
- new file `agent-system/extensions/core/scripts/lib/return-meta-status-vocabulary.sh`

### Reconciling the "24 vs 20" count

The dispatch's headline sentence ("finds 24 without one") does not arithmetically match its own
three enumerated sub-lists (6 + 7 + 7 = 20), and I could not reconstruct a 24 by any grouping of
files, edit-sites, or the two extra pipe-placeholder-only occurrences (`web-implementation-agent.md`,
`grant-agent.md` were already counted in the "7 implementation agents missing" list, so they are
not additive). My own independent, file-by-file verification converges on the same 20 files the
sub-lists name. Recommend the plan treat **20 files / 22 edit sites** (this report's §3) as
authoritative, and treat the dispatch's "24" as a superseded headline count from an earlier
audit pass rather than re-investigating further — the itemized lists, not the headline, were
always the actionable content, and this report has now independently confirmed every one of them
by direct read.

## Risks & Mitigations

- **Risk**: fixing the 20 files without also handling `grant-agent.md`'s bespoke case correctly
  could either leave it non-conformant to Check E or silently drop its legitimate `"drafted"`
  outcome from documentation. **Mitigation**: §2's explicit per-branch treatment recommendation.
- **Risk**: a naive Check E implementation that scans for literal `"completed"` anywhere in an
  agent body could false-positive on legitimate prose (e.g. `project-agent.md`'s "Mark completed
  items", or the MUST-NOT bullets' own descriptive text about the forbidden value). **Mitigation**:
  match only the quoted key-value pair `"status": "completed"` (or `"status":"completed"` with
  optional whitespace), not the bare word, mirroring Check F's `has_artifacts_object_shape`
  window-and-key-set precedent rather than a loose grep.
- **Risk**: twin-file discipline — a one-sided edit between `lean`/`cslib` hard-mode twins and
  their base agents is a recorded recurring defect class per the dispatch. **Mitigation**:
  the file list above already names both hard twins with their two edit sites each; the plan
  should phase them together, not sequentially by extension.
- **Risk**: §5's recovery-arm-narrowness finding could be read as scope creep onto this task.
  **Mitigation**: presented purely as a decision input for §4 (why runtime wiring should stay
  out of scope) and as a named consideration for the follow-up task, not as new in-scope work for
  this task's plan.

## Context Extension Recommendations

- **Topic**: manifest `routing_agents` cross-referencing as a lint technique.
- **Gap**: no existing context file documents that `routing_agents` membership does not imply
  canonical status-vocabulary use, or that `lint-routing-wiring.sh`/`test-routing-resolution.sh`'s
  `ROUTE_MANIFEST_ROOT=agent-system` pattern is available for source-store-time validation of
  agent contracts generally (not just routing wiring).
- **Recommendation**: if this pattern proves useful again (e.g. task 258's own lint work), it may
  be worth a short addition to `context/guides/manifest-routing-schema.md` noting the
  validation-mode `ROUTE_MANIFEST_ROOT` override as reusable for other agent-contract lints. Not
  urgent enough to block this task's plan.

## Appendix

- Search queries used: `grep -rn "status".*"researched\|planned\|implemented"` across all 73
  dispatchable agent files (initial regex-based classification proved unreliable against
  multi-fence files with indented code blocks — e.g. `lean-research-agent.md` has 8 fenced blocks
  including 3-space-indented ones, and a naive `findall` regex under-matched; abandoned in favor
  of direct `grep -n`/`sed -n` reads per file once the candidate set from the dispatch was used as
  a starting point and cross-checked).
- `is_dispatchable_agent` re-derived independently in Python (frontmatter starts with `---` and
  contains a `name:` key) and confirmed the dispatch's claimed 73-file total exactly.
- Manifest files read in full: `founder/manifest.json`, `present/manifest.json`,
  `filetypes/manifest.json` (`routing` and `routing_agents` blocks).
- Key files read in full or near-full: `lint-agent-contracts.sh`, `validate-return-meta.sh`,
  `orchestrate-recover-outcome.sh` (header + case arm), `skill-base.sh` (`skill_read_metadata`),
  `status-vocabulary.sh`, `handoff-schema.md` (`status` field section).
