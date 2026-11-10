# Implementation Plan: Task #444

- **Task**: 444 - Retire routing_agents_hard in favour of hard_contracts across books, cslib and lean, then remove the ladder rung and gate16
- **Status**: [IMPLEMENTING]
- **Effort**: 13 hours
- **Dependencies**: 445 (completed; unrelated gate8 work, no interaction)
- **Research Inputs**: `specs/444_retire_routing_agents_hard_for_hard_contracts/reports/01_retire-routing-agents-hard.md`
- **Artifacts**: plans/01_retire-routing-agents-hard.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`--hard` stops dispatching six separate `-hard` agents and instead dispatches each domain's
STANDARD agent with that domain's behavioural contracts injected into the dispatch prompt by the
already-built `hard_contracts` mechanism. The migration runs in three movements: first make the
contract-injection path actually work per domain (it is wired nowhere today, and a basename
clobber currently makes every `--hard` dispatch of any task type read lean-flavoured generic
contracts), then remove `routing_agents_hard` and its resolution rung, then retire the twelve now
unreachable wrapper files and converge the documentation, tests and lint rosters that name them.

The ordering is deliberate: contract injection lands and is demonstrated per domain BEFORE the
routing rung is removed, so no intermediate state silently downgrades a `--hard` dispatch to a
contract-free standard agent.

### Research Integration

The research report settles the gating question with evidence and this plan proceeds on its YES:
all six `-hard` agents reduce to standard-agent body plus injected contracts. Its two
independently-found defects are folded in as corollary work of Phase 2/3 rather than deferred,
because they share one root cause with this task's own step 2 — where domain override contract
files live and under what basename. The report's recommended convention (flat basenames directly
under the deployed `context/contracts/`, the only shape
`orchestrate-build-dispatch.sh`'s renderer can resolve) is adopted, with one refinement this
planning pass established: the files stay OWNED by their extension rather than moving into core,
and collide no longer because their basenames carry a domain prefix.

This pass additionally closed the one question the report left open and surfaced three facts the
report did not have:

1. **The hard-only lean residue has no home today.** `grep` over the standard
   `lean-implementation-agent.md` finds no `phase_number`, no `sorry_inventory`, and no
   `Zero-Debt` content. The report flagged this as unconfirmed; it is now confirmed absent, so
   that procedural content needs a real destination (Phase 2 authors it as a contract file) and
   is not droppable as already-present.
2. **gate16 cannot simply be deleted.** `lint-gate-registry.sh` Check E FAILS unless gate ids are
   contiguous from 1, and `gate-registry.data` holds exactly ids 1..27. Deleting id 16 forces
   renumbering 17..27 — 40 `gateN` references inside `verify-deploy.sh` plus seven other files,
   plus gate-cache churn. See the Decisions note below for what this plan does instead.
3. **The retirement blast radius is roughly fifty files, not twelve.** Six orphaned hard SKILL
   directories wrap the six agents and must retire with them (`check-extension-docs.sh` Rule A
   fails on a skill directory absent from `provides.skills`, so the directory and the declaration
   must move together). `lint-agent-contracts.sh` carries six hardcoded roster arrays that
   `log_fail` on a missing rostered file; `lint/collapsed-blocks/registry.tsv` row 12 uses
   `cslib-implementation-hard-agent.md` as its exemplar; four `index-entries.json` files, one
   `opencode-agents.json`, and ten core context/doc files cite a `-hard` agent by name.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch's delegation context, so no roadmap consultation
was performed and no roadmap phases are included.

## Carried-Premise Re-Validation

Every trigger-class claim the dispatch description carries was re-measured in this planning pass.
Result, stated explicitly even where it only confirms the description unchanged:

| Dispatch claim | Re-measured verdict |
|----------------|---------------------|
| `routing_hard` declared by no manifest | CONFIRMED — `grep '"routing_hard"' agent-system/extensions/*/manifest.json` is empty |
| `routing_agents_hard` declared by exactly books, cslib, lean, with the quoted shapes | CONFIRMED verbatim, all three shapes byte-match the description |
| `hard_contracts` declared by no manifest | CONFIRMED — empty grep |
| Only lean is deployed, so gate16 reports ONE hit | CONFIRMED — lean is the only one of the three in `.claude/extensions/` |
| The rung is genuinely consulted at `command-route-agent.sh` ~line 69 | CONFIRMED — the three-rung `if`/`elif`/`else` sits at lines 68-84 |
| gate16 WARNS and never fails | CONFIRMED — its sole finding call is `warn_advisory`, and it `pass`es when hits are zero |
| gate16's header names this work as "the one remaining follow-on" | CONFIRMED at `verify-deploy.sh` lines 1597-1607 |
| Scope item 5's "remove gate16 and its registry row" | **CONTRADICTED by a constraint the description did not know** — see Decisions, gate16 |
| Scope item 3's "retire the six -hard agent files" | CONFIRMED as necessary, but INCOMPLETE — six orphaned hard skill directories wrap them and must retire too |
| The premise that `-hard` agents reduce to standard + injected contracts | CONFIRMED (research report, plus this pass's heading-set check of the lean pair) |

Additionally re-measured and confirmed live: the deployed
`.claude/context/contracts/anti-analysis.md` is byte-identical to lean's override and DIFFERS
from core's generic version (Defect A, reproduced), and `.claude/extensions/<ext>/` holds
`manifest.json` only, with no `context/` subtree (Defect B, reproduced).

## Goals & Non-Goals

**Goals**:
- Every `--hard` dispatch in `books`, `cslib` and `lean` receives that domain's behavioural
  contracts through `hard_contracts`, demonstrated per domain against a real built dispatch file.
- `--hard` dispatches the standard agent in all three domains; `routing_agents_hard` is declared
  by no manifest and resolved by no code path.
- Every `--hard` dispatch of a NON-lean task type reads core's generic contracts rather than
  lean's domain overrides (Defect A fixed).
- No surviving citation of a contract file at a path that does not exist in a deployed tree
  (Defect B fixed).
- The twelve unreachable wrapper files (six agents, six skills) are gone, with every roster,
  index row, lint enumeration and illustrative citation that names them converged.
- `lint-routing-wiring.sh` passes with Check C removed; the full gate set passes with no new
  findings and gate16 green.

**Non-Goals**:
- Adding a `phase` dimension to `hard_contracts`. It is deliberately keyed by `task_type` only
  (`manifest-routing-schema.md` states the rationale), so a domain's additive entry reaches all
  three phases. Accepted and documented, not redesigned here.
- Renumbering gates 17..27. See Decisions.
- Widening `check-extension-docs.sh` Rule G's dangling-reference regex to catch the
  extension-namespaced path shape. Defect B's live instances all disappear with the agents in
  Phase 6, so the widening protects only against recurrence; recorded as a follow-up, not done
  here.
- Changing `orchestrate-build-dispatch.sh`'s Stage 3.5 renderer. The plan adopts the convention
  the shipped renderer already supports rather than changing it.
- Reinstating a hard-mode planning path. `--hard` plan dispatches continue to resolve
  `planner-agent`; plan parity was never required in `routing_agents_hard` and is not added.

## Decisions

**Override contracts stay owned by their extension, with domain-prefixed basenames.**
The renderer emits `- context/contracts/${basename}`, so an override must deploy to a flat path
directly under the shared `context/contracts/` directory. Two ways to get there: move the files
into core, or keep them in the owning extension and let its `provides.context: ["contracts"]`
directory entry deploy them into the shared directory under non-colliding names. This plan takes
the second. Core would otherwise accumulate per-domain content it does not own, and the collision
that caused Defect A was never the directory entry itself — it was three shared basenames.
Rejected alternative: move everything into `core/context/contracts/`; rejected because it puts
lean's proof-specific language in the core extension and leaves lean unable to change its own
contract without editing core.

**gate16 is kept in place as the absence-assertion guard, not deleted.**
Scope item 5 directs removal and separately asks whether a replacement gate asserting the ABSENCE
of both keys is worth keeping. Measurement makes the two questions one: `lint-gate-registry.sh`
Check E fails unless registry ids run contiguously from 1, the registry holds 1..27, and removing
id 16 therefore forces renumbering eleven gates across eight files. Meanwhile gate16 in its
present form ALREADY is the absence assertion — with zero hits it emits
`pass "no extension manifest declares routing_hard/routing_agents_hard"`. Keeping it costs one
header-comment rewrite and one registry `name` field; deleting it costs the renumber. It also
keeps the only cheap, fixture-selectable `warn_advisory` gate alive, which
`test-verify-deploy-gate-selection.sh` case (r) uses as the sole demonstration of the
non-blocking WARN channel (the only other `warn_advisory` call site is inside gate8, a slow gate
needing a failing-suite fixture). The standing-warning complaint that motivated this task is
resolved by the manifest cleanup alone: gate16 goes green in Phase 4 and stays green.

**The hard rung's removal collapses the hard branch entirely.**
With `routing_agents_hard` gone, `command-route-agent.sh`'s hard branch becomes identical to its
standard branch, so the whole `if [ "$_route_effort_flag" = "hard" ]` conditional goes rather than
being hollowed out. Consequence to handle, not discover at implementation time: the trace value
`via=hard-miss-standard-fallback` ceases to exist, and
`test-routing-resolution.sh` asserts it in six places.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Removing `routing_agents_hard` before contract injection works silently downgrades every `--hard` dispatch in three domains to a contract-free standard agent | H | H if misordered | Phases 2-3 land and demonstrate injection per domain BEFORE Phase 4 touches the manifests' routing block; Phase 3's verification is a real built dispatch file per domain, not an assertion |
| Fixing Defect A changes what every currently deployed `--hard` dispatch of any task type reads (reverting lean's accidental clobber to core's generic content) | M | Certain | This is a behaviour change, not a pure bugfix. Call it out explicitly in the Phase 3 commit body and the task summary so review does not read it as a regression. This repo is the only consumer exercising the path |
| Deleting a rostered agent file makes `lint-agent-contracts.sh` fail (`log_fail "$rel: in-scope agent file not found"`) | M | Certain if rosters are not edited in the same phase | Phase 6 edits all six roster arrays and the three roster tests in the same phase as the deletions, and runs the lint before closing |
| Removing a skill directory without its `provides.skills` entry (or vice versa) fails `check-extension-docs.sh` Rule A in one direction and Rule J-equivalent orphan detection in the other | M | Certain if split | Phase 5 moves directory and declaration together, per extension |
| `test-verify-deploy-gate-selection.sh` case (r) reads the REAL deployed lean manifest through a symlinked `.claude`, so it hard-fails once lean stops declaring the key | M | Certain | Phase 7 retargets case (r) onto a dedicated synthetic fixture that declares the key itself, making the warn-channel demonstration independent of real manifest content |
| A domain's additive `hard_contracts` entry reaches research and plan dispatches too, not only implement | L | Certain | Accepted; keep each override's content phase-agnostic in wording, and document the behaviour in Phase 1's convention subsection so the next author is not surprised |
| The twelve retirements leave a dangling illustrative citation in a core context file that no gate catches | M | M | Phase 6 sweeps the ten core files by name from a fresh grep rather than from this plan's list, and re-greps for all twelve names at phase close |
| Deploy-time basename behaviour is inferred from one reproduced clobber rather than from reading the copier | M | L | Phase 3 verifies the deployed tree directly after redeploy: both `contracts/anti-analysis.md` (core content) and `contracts/lean4-anti-analysis.md` (lean content) must be present and distinct |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |
| 5 | 5, 7 | 4 |
| 6 | 6 | 5 |
| 7 | 8 | 6, 7 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Record the override-contract convention [COMPLETED]

**Goal**: `manifest-routing-schema.md` states, before any manifest is touched, where a domain
override contract file lives, what basename it must carry, and why — so the rest of the plan
implements a written convention rather than inventing one per file.

**Tasks**:
- [x] Add a subsection to `manifest-routing-schema.md`'s `## The hard_contracts Block` documenting
      the renderer-imposed constraint: `orchestrate-build-dispatch.sh` emits
      `- context/contracts/${entry}`, so every additive path and every `replace:` override path
      must be a flat basename resolving directly under the deployed `context/contracts/`
      directory. A nested or extension-namespaced path cannot resolve. *(completed)*
- [x] Document the sanctioned way a non-core extension places an override there: declare
      `"contracts"` in `provides.context` and give the file a domain-prefixed basename
      (`lean4-anti-analysis.md`, `cslib-adversarial-verification.md`). *(completed)*
- [x] Document the clobber hazard this prevents: two extensions declaring the same bare
      `provides.context` directory merge additively by directory copy, and two same-basename files
      silently overwrite each other with the winner set by extension load order. Name it as the
      reason the domain prefix is mandatory, not stylistic. *(completed)*
- [x] Document that `hard_contracts` is keyed by `task_type` only, so a domain's additive entry
      reaches research, plan and implement dispatches alike — and that an override's wording
      should therefore stay phase-agnostic. *(completed)*
- [x] Leave the `**Current status**: no extension declares this block today` paragraph alone in
      this phase; Phase 3 updates it once declarations exist. *(completed: left verbatim)*

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: prose

**Tier Justification**: `suite_selection_select` maps this guide to exactly one suite, so the
covering check is
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-routing-resolution.sh`
alongside the tier's diff read-through.

**Files to modify**:
- `agent-system/extensions/core/context/guides/manifest-routing-schema.md` - add the
  override-convention subsection (confirmed present, 269 lines; if absent at implementation time,
  stop and report rather than creating a new guide)

**Verification**:
- The new subsection names the flat-basename constraint, the domain-prefix rule, the clobber
  hazard and the task_type-only keying.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-routing-resolution.sh`
  exits 0.
- Diff read-through confirms every changed hunk is prose.

---

### Phase 2: Rename the override contracts and give the lean residue a home [COMPLETED]

**Goal**: every domain override contract file carries a domain-prefixed basename, is declared by
its own extension, and is indexed on-demand — and lean's genuinely hard-only procedural content
exists as a contract file instead of only as agent-body text.

**Tasks**:
- [x] Rename lean's four override files to domain-prefixed basenames:
      `anti-analysis.md` -> `lean4-anti-analysis.md`, `reference-grounding.md` ->
      `lean4-reference-grounding.md`, `adversarial-verification.md` ->
      `lean4-adversarial-verification.md`, `context-hygiene.md` -> `lean4-context-hygiene.md`
      (all four confirmed present under `agent-system/extensions/lean/context/contracts/`; if one
      is absent at implementation time, report it and continue with the rest rather than
      recreating it). *(completed: Scope Hypothesis confirmed exactly, all four present; also
      fixed two dangling extension-namespaced self-references this rename exposed, in
      lean4-adversarial-verification.md and mcp-tools-guide.md)*
- [x] Rename cslib's one orphaned override
      (`agent-system/extensions/cslib/context/contracts/adversarial-verification.md`, confirmed
      present but never deployed) to `cslib-adversarial-verification.md`, and add `"contracts"`
      to cslib's `provides.context` so it actually deploys. *(completed; also removed a
      pre-existing stale index-entries.json row for the old unprefixed basename, and rewrote the
      file's header narrative which described the now-retired directory-merge clobber mechanism
      as still live)*
- [x] Author `agent-system/extensions/lean/context/contracts/lean4-sorry-discipline.md` carrying
      the lean-only procedural residue that the standard `lean-implementation-agent.md` is
      confirmed NOT to contain: the sorry-inventory lifecycle (import from prior handoff or
      initialise empty; task-scoped, not phase-scoped), the Zero-Debt policy with its two tracked
      exceptions, and the single-phase-focus rule for a set `phase_number`. Write it
      phase-agnostically, and point its strategic-sorry test at `lean4-anti-analysis.md` rather
      than at the extension-namespaced path the hard agent body uses. *(completed, 92 lines)*
- [x] Fix core `contracts/anti-analysis.md`'s `## Domain Specialization` bullet, which states
      overrides live at `.claude/extensions/{domain}/context/contracts/anti-analysis.md` — a path
      that exists in no deployed tree. Replace with the flat domain-prefixed convention Phase 1
      recorded. *(completed)*
- [x] Update lean's `index-entries.json`: rename the four `contracts/*` paths to their prefixed
      forms, add a row for `contracts/lean4-sorry-discipline.md`, set every one of the five to
      `on_demand: true` with an EMPTY `load_when.agents` array (matching core's own contract rows,
      so the `hard_contracts` dispatch block is the sole loader and injection stays `--hard`-gated
      rather than loading at every standard-agent spawn), and regenerate `line_count`. *(completed;
      matched core's full load_when shape of agents/commands/task_types, all empty)*
- [x] Add a `contracts/cslib-adversarial-verification.md` row to cslib's `index-entries.json` on
      the same shape. *(completed)*
- [x] Confirm the duplicate index paths are gone: core and lean currently BOTH declare
      `contracts/anti-analysis.md`, `contracts/adversarial-verification.md` and
      `contracts/reference-grounding.md`. *(completed: confirmed gone by direct comparison of all
      three extensions' contracts/ index rows)*

**Timing**: 2 hours

**Depends on**: 1

**Verification Tier**: full

**Tier Justification**: Renaming deployed `context/contracts/` basenames while editing two
manifests' `provides.context` and two `index-entries.json` files crosses the deploy-merge,
context-index-schema and double-loading surfaces simultaneously — `suite_selection_select` over
this phase's mixed path set returns `__FULL_SWEEP__`, so no suite subset is claimable, and the
manifest paths alone resolve to 26 suites, which is not meaningfully cheaper than the gate set.

**Scope Hypothesis**: Four lean override files plus one orphaned cslib file, five renames total,
and exactly three core/lean duplicate index paths. Confirm by re-listing both extensions'
`context/contracts/` directories and re-running the duplicate-path comparison between core's and
lean's `index-entries.json` before editing, and report any divergence from these counts rather
than proceeding on them.

**Files to modify**:
- `agent-system/extensions/lean/context/contracts/anti-analysis.md` - rename to `lean4-anti-analysis.md`
- `agent-system/extensions/lean/context/contracts/reference-grounding.md` - rename to `lean4-reference-grounding.md`
- `agent-system/extensions/lean/context/contracts/adversarial-verification.md` - rename to `lean4-adversarial-verification.md`
- `agent-system/extensions/lean/context/contracts/context-hygiene.md` - rename to `lean4-context-hygiene.md`
- `agent-system/extensions/lean/context/contracts/lean4-sorry-discipline.md` - new; sorry inventory, Zero-Debt policy, single-phase focus
- `agent-system/extensions/cslib/context/contracts/adversarial-verification.md` - rename to `cslib-adversarial-verification.md`
- `agent-system/extensions/cslib/manifest.json` - add `"contracts"` to `provides.context`
- `agent-system/extensions/core/context/contracts/anti-analysis.md` - correct the Domain Specialization override-path bullet
- `agent-system/extensions/lean/index-entries.json` - rename four contract rows, add one, set on-demand, regenerate line_count
- `agent-system/extensions/cslib/index-entries.json` - add the cslib override row

**Verification**:
- No basename appears in both core's and any other extension's `context/contracts/` directory.
- No path string appears in two `index-entries.json` files.
- Every contract row for a domain override has `on_demand: true` and an empty
  `load_when.agents`.
- `bash agent-system/extensions/core/scripts/verify-deploy.sh` is clean (run from the repo root).
- No surviving reference to `.claude/extensions/{domain}/context/contracts/` in core's
  `anti-analysis.md`.

---

### Phase 3: Declare hard_contracts and demonstrate injection per domain [NOT STARTED]

**Goal**: all three domains declare `hard_contracts`, the deployed tree holds core's generic
contracts and the domain overrides side by side without clobber, and a real built `--hard`
dispatch file in each domain is shown carrying that domain's contract list.

**Tasks**:
- [ ] Declare `hard_contracts` in lean's manifest for `lean4`: `replace:` directives substituting
      `lean4-anti-analysis.md`, `lean4-reference-grounding.md` and
      `lean4-adversarial-verification.md` for their generic counterparts, plus plain additive
      entries for `lean4-context-hygiene.md` and `lean4-sorry-discipline.md`.
- [ ] Declare `hard_contracts` in cslib's manifest for `cslib`: a `replace:` directive for
      `cslib-adversarial-verification.md`, plus an additive `lean4-context-hygiene.md` (cslib
      edits Lean theorem files and its hard agent already reused lean's hygiene content; note the
      cross-extension dependency explicitly in the manifest comment or the README table so it is
      not mistaken for a copy-paste error).
- [ ] Decide and declare books' `hard_contracts` for `books`: the research found no
      books-specific override file and found books' H2/H7/H9 content byte-near-identical to core's
      generic contracts. If the books-specific three-tier reference-grounding elaboration is
      judged worth preserving, extract it to
      `agent-system/extensions/books/context/contracts/books-reference-grounding.md`, add
      `"contracts"` to books' `provides.context`, add its index row, and `replace:` it; otherwise
      declare no `hard_contracts` for books at all and record in the commit body that books' hard
      behaviour is fully covered by the generic core contract set. Do not declare an empty block.
- [ ] Update `manifest-routing-schema.md`'s `**Current status**: no extension declares this block
      today` paragraph, which becomes false in this phase.
- [ ] Redeploy via `bash .claude/scripts/deploy-headless.sh` (or the source-store equivalent) and
      confirm the deployed `.claude/context/contracts/` holds BOTH `anti-analysis.md` with core's
      generic content AND `lean4-anti-analysis.md` with lean's override content, as distinct
      files.
- [ ] Build a `--hard` dispatch file for each of the three domains and read its
      `<hard-mode-contracts>` block, confirming per domain that the override paths appear in the
      expected positions (a `replace:` preserves the replaced entry's position; an additive entry
      appends after the core entries).
- [ ] Confirm the generic path is restored: build a `--hard` dispatch for a NON-lean task type
      (`meta`) and confirm its block names bare `anti-analysis.md`, and that the deployed file at
      that path now holds core's generic content rather than lean's.

**Timing**: 2 hours

**Depends on**: 2

**Verification Tier**: full

**Tier Justification**: This phase changes what every `--hard` dispatch of every task type reads
and regenerates the whole deployed tree — the dispatch-prompt-composition and whole-tree-deploy
surfaces together, which no suite subset observes.

**Scope Hypothesis**: Three manifests gain a `hard_contracts` block (possibly two, if books is
ruled fully covered by the generic set). Confirm the per-domain override inventory against
Phase 2's actual output before writing the declarations rather than against this plan's list.

**Files to modify**:
- `agent-system/extensions/lean/manifest.json` - add `hard_contracts.lean4`
- `agent-system/extensions/cslib/manifest.json` - add `hard_contracts.cslib`
- `agent-system/extensions/books/manifest.json` - add `hard_contracts.books`, or leave unchanged per the recorded decision
- `agent-system/extensions/books/context/contracts/books-reference-grounding.md` - new, only if the books elaboration is preserved
- `agent-system/extensions/books/index-entries.json` - row for the above, only if created
- `agent-system/extensions/core/context/guides/manifest-routing-schema.md` - correct the "no extension declares this block today" status paragraph
- `__WHOLE_TREE__`

**Verification**:
- Deployed `.claude/context/contracts/` holds `anti-analysis.md` (core content) and
  `lean4-anti-analysis.md` (lean content) as distinct, non-identical files.
- A built `--hard` dispatch file for `lean4`, for `cslib`, and for `books` each shows the expected
  `<hard-mode-contracts>` list, captured in the phase's verification record.
- A built `--hard` dispatch for `meta` names bare `anti-analysis.md`, and that deployed file
  matches core's source rather than lean's.
- `bash .claude/scripts/verify-deploy.sh` is clean.

---

### Phase 4: Remove routing_agents_hard and its resolution rung [NOT STARTED]

**Goal**: no manifest declares `routing_agents_hard`, no code resolves it, and the routing tests
assert the collapsed single-block model rather than the retired three-rung ladder.

**Tasks**:
- [ ] Remove the `routing_agents_hard` block from books', cslib's and lean's manifests.
- [ ] Collapse `command-route-agent.sh`'s hard branch: with the first rung gone, the hard and
      standard branches are identical, so remove the `if [ "$_route_effort_flag" = "hard" ]`
      conditional entirely rather than hollowing it out. `_route_effort_flag` survives only as a
      `routing_trace` argument. Update the script's own header comment, which describes the
      three-rung composition.
- [ ] Delete `check_c()` from `lint-routing-wiring.sh` together with its `--help` line (65-66
      region), its header-comment block (lines 15-19), and its call site in the runner (line 268);
      drop `routing_agents_hard` from Check B's `for block in ...` loop and from Check B's own
      header and output strings.
- [ ] Update `manifest-routing-lib.sh`'s doc comments, which name `routing_agents_hard` as a live
      block. No functional change — `routing_lookup()` takes the block name as a parameter and has
      no hard-coded knowledge of it.
- [ ] Update `test-routing-resolution.sh`: drop `routing_agents_hard` from Assert 2's block loop
      and its pass message; DELETE the lean4 sub-assertion (lines ~222-235) that requires lean4's
      hard resolution to differ from its standard resolution, which has no subject once the block
      is gone; retarget the nix-based Assert 3 semantic check, whose expected
      `via=hard-miss-standard-fallback` no longer exists — it must now expect the standard
      block's own `via`; and rewrite the header narrative (lines 9, 19, 29-37, 92) that documents
      the retired ladder.
- [ ] Re-grep for `hard-miss-standard-fallback` and remove its remaining mentions in
      `hard-mode-routing.md` (Phase 8 owns that file's full rewrite; remove only the now-false
      trace-value claim here if it is cheaper to do in one pass there — record which).
- [ ] Confirm gate16 now reports zero hits and passes.

**Timing**: 2 hours

**Depends on**: 3

**Verification Tier**: full

**Tier Justification**: `command-route-agent.sh` resolves the agent for every dispatch of every
task type in every extension, so an error here misroutes the whole system — a cross-cutting
surface no single-suite subset covers.

**Files to modify**:
- `agent-system/extensions/books/manifest.json` - remove `routing_agents_hard`
- `agent-system/extensions/cslib/manifest.json` - remove `routing_agents_hard`
- `agent-system/extensions/lean/manifest.json` - remove `routing_agents_hard`
- `agent-system/extensions/core/scripts/command-route-agent.sh` - collapse the hard branch, update the header comment
- `agent-system/extensions/core/scripts/lint/lint-routing-wiring.sh` - delete Check C, its help line, header block and call site; narrow Check B's block loop
- `agent-system/extensions/core/scripts/lib/manifest-routing-lib.sh` - doc-comment-only update
- `agent-system/extensions/core/scripts/tests/test-routing-resolution.sh` - Assert 2 loop, delete the lean4 hard/standard distinction assertion, retarget the nix `via` expectation, rewrite the header narrative

**Verification**:
- `grep -r routing_agents_hard agent-system/extensions/*/manifest.json` is empty.
- `bash agent-system/extensions/core/scripts/lint/lint-routing-wiring.sh --verbose` passes with no
  Check C and no remaining reference to it.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-routing-resolution.sh`
  passes.
- gate16 emits `pass "no extension manifest declares routing_hard/routing_agents_hard"`.
- `bash .claude/scripts/verify-deploy.sh` is clean.

---

### Phase 5: Retire the six orphaned hard skill directories [NOT STARTED]

**Goal**: the six hard skill wrappers — already unrouted before this task, since no routing block
names a skill any more — are gone along with every declaration and enumeration that reaches them.

**Tasks**:
- [ ] Delete the six skill directories:
      `books/skills/skill-books-{research,implementation}-hard`,
      `cslib/skills/skill-cslib-{research,implementation}-hard`,
      `lean/skills/skill-lean-{research,implementation}-hard` (all six confirmed present; report
      and continue if one is already absent).
- [ ] Remove their six entries from the three manifests' `provides.skills` arrays, in the same
      change as the directory deletions — `check-extension-docs.sh` Rule A fails on a skill
      directory absent from `provides.skills`, and orphan detection fails in the other direction.
- [ ] Update the lint and test enumerations that name a hard skill:
      `lint/lint-task-lookup-adoption.sh`, `tests/test-resume-scan-nonconformance.sh`, and the
      literature extension's `scripts/test-lit-pipeline.sh`.
- [ ] Update the docs that name a hard skill as live:
      `core/docs/reference/utility-scripts-inventory.md`,
      `core/context/contracts/phase-closure.md`, `core/context/formats/plan-format.md`,
      `cslib/context/project/cslib/domain/hard-mode-selection.md`,
      `lean/context/project/lean4/domain/hard-mode.md`, and the three extensions'
      `EXTENSION.md` / `README.md` skill tables.
- [ ] Re-grep for all six skill names across the source store and confirm nothing survives except
      deliberate historical prose, if any.

**Timing**: 1.5 hours

**Depends on**: 4

**Verification Tier**: full

**Tier Justification**: `provides.skills` is the roster the deploy copier, the orphan gates and
`check-extension-docs.sh`'s Rule A all read, so a half-applied edit breaks the deploy of three
extensions — a cross-cutting surface the mixed markdown/script path set returns `__FULL_SWEEP__`
for, so no suite subset is claimable.

**Scope Hypothesis**: Six skill directories, six `provides.skills` entries across three manifests,
three lint/test enumerations and roughly ten doc mentions. Confirm by listing
`agent-system/extensions/*/skills/*hard*` and re-running the six-name grep before editing, and
report any count divergence rather than proceeding on these figures.

**Files to modify**:
- `agent-system/extensions/books/skills/skill-books-research-hard/` - delete
- `agent-system/extensions/books/skills/skill-books-implementation-hard/` - delete
- `agent-system/extensions/cslib/skills/skill-cslib-research-hard/` - delete
- `agent-system/extensions/cslib/skills/skill-cslib-implementation-hard/` - delete
- `agent-system/extensions/lean/skills/skill-lean-research-hard/` - delete
- `agent-system/extensions/lean/skills/skill-lean-implementation-hard/` - delete
- `agent-system/extensions/books/manifest.json` - drop two `provides.skills` entries
- `agent-system/extensions/cslib/manifest.json` - drop two `provides.skills` entries
- `agent-system/extensions/lean/manifest.json` - drop two `provides.skills` entries
- `agent-system/extensions/core/scripts/lint/lint-task-lookup-adoption.sh` - drop hard-skill enumeration
- `agent-system/extensions/core/scripts/tests/test-resume-scan-nonconformance.sh` - drop hard-skill fixture entries
- `agent-system/extensions/literature/scripts/test-lit-pipeline.sh` - drop hard-skill references
- `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md` - drop hard-skill mentions
- `agent-system/extensions/core/context/contracts/phase-closure.md` - drop hard-skill mention
- `agent-system/extensions/core/context/formats/plan-format.md` - drop hard-skill mention
- `agent-system/extensions/cslib/context/project/cslib/domain/hard-mode-selection.md` - rewrite for the contract-injection model
- `agent-system/extensions/lean/context/project/lean4/domain/hard-mode.md` - rewrite for the contract-injection model
- `agent-system/extensions/books/EXTENSION.md` - skill table
- `agent-system/extensions/books/README.md` - skill table
- `agent-system/extensions/cslib/EXTENSION.md` - skill table
- `agent-system/extensions/cslib/README.md` - skill table

**Verification**:
- No `*hard*` directory remains under any `agent-system/extensions/*/skills/`.
- `grep -r` for the six skill names across the source store returns only intentional survivors.
- `bash agent-system/extensions/core/scripts/check-extension-docs.sh` passes Rule A for all three
  extensions.
- `bash .claude/scripts/verify-deploy.sh` is clean.

---

### Phase 6: Retire the six hard agent files and converge every roster that names them [NOT STARTED]

**Goal**: the six `-hard` agent files are gone and no roster, index row, lint array, fixture or
illustrative citation still names them.

**Tasks**:
- [ ] Before deleting, re-diff each hard agent against its standard counterpart one final time and
      confirm every behaviour it carries now reaches the standard agent either through its own
      body or through a Phase 2/3 contract. Fold anything that does not into the relevant contract
      file rather than deleting it — this is the last point at which the content is recoverable
      without git archaeology.
- [ ] Delete the six agent files under `books/agents/`, `cslib/agents/` and `lean/agents/`.
- [ ] Remove their six entries from the three manifests' `provides.agents` arrays, in the same
      change.
- [ ] Remove the `-hard` agent rows from `books/index-entries.json`, `cslib/index-entries.json`
      and `lean/index-entries.json`, and any core `index-entries.json` row whose `load_when.agents`
      names one.
- [ ] Remove the `-hard` agent entries from `books/opencode-agents.json`.
- [ ] Edit every roster array in `lint-agent-contracts.sh` that lists a `-hard` agent path — the
      lint `log_fail`s on a rostered file that does not exist, so this is a hard failure, not a
      vacuous pass — and update its three roster tests
      (`test-lint-agent-contracts.sh`, `test-lint-agent-contracts-handoff-section.sh`,
      `test-lint-agent-contracts-heartbeat.sh`) plus any header comment that cites a hard agent as
      an exemplar.
- [ ] Retarget `lint/collapsed-blocks/registry.tsv` row 12, which uses
      `cslib/agents/cslib-implementation-hard-agent.md` as its collapsed-block exemplar, onto a
      surviving agent that carries the same shared block, and regenerate the corresponding
      `collapsed-blocks/*.txt` fixture (renaming it to match the new exemplar). Delete the stale
      `early-metadata-stage0-cslib-agents-cslib-implementation-hard-agent.txt`.
- [ ] Sweep the illustrative citations in core context/docs that name a `-hard` agent as an
      example: `context/architecture/context-layers.md`,
      `context/contracts/modified-files-bullet.md`,
      `context/contracts/no-task-references-bullet.md`,
      `context/contracts/plan-status-ownership.md`, `context/formats/return-metadata-file.md`,
      `context/patterns/bounded-build-waiter.md`,
      `context/patterns/dispatch-report-not-termination.md`,
      `docs/architecture/handoff-schema.md`, plus `books/context/project/books/domain/approvals-detection.md`,
      `books/scripts/tests/test-books-approvals-signal.sh` and
      `cslib/context/contracts/cslib-adversarial-verification.md`. Derive the list from a fresh
      grep at implementation time, not from this enumeration.
- [ ] Re-grep for all six agent names and confirm nothing survives.

**Timing**: 2 hours

**Depends on**: 5

**Verification Tier**: full

**Tier Justification**: Agent rosters are read by `lint-agent-contracts.sh`, the collapsed-block
registry, `check-extension-docs.sh`'s agent-resolvability rules and the deploy orphan gate at
once, so a missed roster entry fails the gate set rather than one suite; the phase's mixed
markdown/script/JSON path set returns `__FULL_SWEEP__`, so no suite subset is claimable.

**Scope Hypothesis**: Six agent files, six `provides.agents` entries, roughly forty-eight
source-store files citing one of the twelve retired names (measured this planning pass), six
roster arrays in `lint-agent-contracts.sh`, and one collapsed-block registry row with one fixture
file. Confirm each count with a fresh grep and a fresh roster read before editing; treat every
figure here as a hypothesis and report divergence rather than trusting it.

**Files to modify**:
- `agent-system/extensions/books/agents/books-research-hard-agent.md` - delete
- `agent-system/extensions/books/agents/books-implementation-hard-agent.md` - delete
- `agent-system/extensions/cslib/agents/cslib-research-hard-agent.md` - delete
- `agent-system/extensions/cslib/agents/cslib-implementation-hard-agent.md` - delete
- `agent-system/extensions/lean/agents/lean-research-hard-agent.md` - delete
- `agent-system/extensions/lean/agents/lean-implementation-hard-agent.md` - delete
- `agent-system/extensions/books/manifest.json` - drop two `provides.agents` entries
- `agent-system/extensions/cslib/manifest.json` - drop two `provides.agents` entries
- `agent-system/extensions/lean/manifest.json` - drop two `provides.agents` entries
- `agent-system/extensions/books/index-entries.json` - drop hard-agent rows
- `agent-system/extensions/cslib/index-entries.json` - drop hard-agent rows
- `agent-system/extensions/lean/index-entries.json` - drop hard-agent rows
- `agent-system/extensions/core/index-entries.json` - drop hard-agent mentions in summaries and `load_when.agents`
- `agent-system/extensions/books/opencode-agents.json` - drop hard-agent entries
- `agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` - edit every roster array and exemplar comment naming a hard agent
- `agent-system/extensions/core/scripts/tests/test-lint-agent-contracts.sh` - roster expectations
- `agent-system/extensions/core/scripts/tests/test-lint-agent-contracts-handoff-section.sh` - roster expectations
- `agent-system/extensions/core/scripts/tests/test-lint-agent-contracts-heartbeat.sh` - roster expectations
- `agent-system/extensions/core/scripts/lint/collapsed-blocks/registry.tsv` - retarget row 12
- `agent-system/extensions/core/scripts/lint/collapsed-blocks/early-metadata-stage0-cslib-agents-cslib-implementation-hard-agent.txt` - delete, replaced by a regenerated fixture for the new exemplar
- `agent-system/extensions/core/context/architecture/context-layers.md` - illustrative citation
- `agent-system/extensions/core/context/contracts/modified-files-bullet.md` - illustrative citation
- `agent-system/extensions/core/context/contracts/no-task-references-bullet.md` - illustrative citation
- `agent-system/extensions/core/context/contracts/plan-status-ownership.md` - illustrative citation
- `agent-system/extensions/core/context/formats/return-metadata-file.md` - illustrative citation
- `agent-system/extensions/core/context/patterns/bounded-build-waiter.md` - illustrative citation
- `agent-system/extensions/core/context/patterns/dispatch-report-not-termination.md` - illustrative citation
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` - illustrative citation
- `agent-system/extensions/books/context/project/books/domain/approvals-detection.md` - illustrative citation
- `agent-system/extensions/books/scripts/tests/test-books-approvals-signal.sh` - hard-agent reference
- `agent-system/extensions/cslib/context/contracts/cslib-adversarial-verification.md` - hard-agent reference (path as renamed in Phase 2)

**Verification**:
- `grep -r` for all six agent names across the source store returns nothing.
- `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` passes with no
  "in-scope agent file not found" failure.
- `bash agent-system/extensions/core/scripts/lint/lint-collapsed-blocks.sh` (or the registry's own
  lint entry point) passes against the retargeted row.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-lint-agent-contracts.sh,test-lint-agent-contracts-handoff-section.sh,test-lint-agent-contracts-heartbeat.sh`
  passes.
- `bash .claude/scripts/verify-deploy.sh` is clean.

---

### Phase 7: Settle gate16 as the absence guard and repair its test fixture [NOT STARTED]

**Goal**: gate16 survives as a permanent regression guard asserting the absence of both retired
keys, its narrative no longer promises its own removal, and its WARN-channel demonstration no
longer depends on a real manifest declaring the key.

**Tasks**:
- [ ] Rewrite gate16's header comment block (`verify-deploy.sh` lines 1597-1607), which currently
      frames the gate as transitional and names "the dependent hard-mode work" as the trigger for
      its own removal. It becomes a standing absence guard: both keys are retired, and a manifest
      declaring either is a migration regression. Keep it at `warn_advisory` level.
- [ ] Update the `gate-registry.data` row 16 `name` field, which reads "hard_contracts migration
      warning (routing_hard/routing_agents_hard)".
- [ ] Update the two narrative comments that cite gate16 as the only `warn_advisory` user
      (`verify-deploy.sh` lines ~198 and ~691-706). Note that gate8's all-expected branch is the
      other call site, so "today, only gate16's" is already imprecise.
- [ ] Retarget `test-verify-deploy-gate-selection.sh` case (r). It currently reads the REAL
      deployed lean manifest through `FIXTURE_RICH`'s symlinked `.claude`, so cases (r-a2) and
      (r-b) hard-fail once no manifest declares the key. Build a dedicated fixture whose
      `.claude/extensions/<synthetic>/manifest.json` declares `routing_agents_hard` itself, and
      run `--only-gate 16` against that. Do NOT add the synthetic manifest to `FIXTURE_CHEAP`,
      which other cases share. Keep all five sub-assertions (r-a, r-a2, r-b, r-c, r-d) intact —
      they are the suite's only demonstration of the non-blocking WARN channel.
- [ ] Add a case asserting the green side: `--only-gate 16` against a fixture with no declaring
      manifest emits the `pass` line and no WARN finding.
- [ ] Update the gate16 mentions in `test-gate-cache-equivalence.sh`,
      `context/standards/shell-script-testing.md`, `context/contracts/batch-gate-stage.md` (which
      cites gate16 as the sole example of a non-blocking migration-warning gate) and
      `lib/gate-store-fixture-lib.sh`'s shape comment.
- [ ] Explicitly record that gates are NOT renumbered and why, in the gate16 header comment, so a
      future reader does not re-derive the renumber question.

**Timing**: 1.5 hours

**Depends on**: 4

**Verification Tier**: full

**Tier Justification**: `verify-deploy.sh` is the gate aggregator every other phase's verification
runs through, and the registry row feeds `--only-gate` selection and the gate cache, so an error
here corrupts the signal the whole plan is verified by.

**Scope Hypothesis**: Twenty-seven contiguous gate ids, seventeen gate16 references inside
`verify-deploy.sh`, seventeen inside `test-verify-deploy-gate-selection.sh`, and one registry row.
Re-measure each with a fresh grep and a fresh `cut -f1` over the registry before editing; if the
id sequence is no longer 1..27, re-evaluate the keep-versus-renumber decision rather than
assuming it.

**Files to modify**:
- `agent-system/extensions/core/scripts/verify-deploy.sh` - rewrite gate16's header comment and the two warn_advisory narrative comments
- `agent-system/extensions/core/scripts/gate-registry.data` - update row 16's `name` field
- `agent-system/extensions/core/scripts/tests/test-verify-deploy-gate-selection.sh` - retarget case (r) onto a dedicated synthetic fixture, add the green-side case
- `agent-system/extensions/core/scripts/tests/test-gate-cache-equivalence.sh` - update the stale gate16 comment
- `agent-system/extensions/core/scripts/lib/gate-store-fixture-lib.sh` - update the gate16 shape comment
- `agent-system/extensions/core/context/standards/shell-script-testing.md` - update the gate16 mention
- `agent-system/extensions/core/context/contracts/batch-gate-stage.md` - update the gate16 example

**Verification**:
- `bash agent-system/extensions/core/scripts/lint/lint-gate-registry.sh` passes, including Check
  E's contiguity assertion (ids still 1..27).
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-verify-deploy-gate-selection.sh,test-gate-cache-equivalence.sh`
  passes, with case (r) green against the synthetic fixture and the new green-side case green
  against the real tree.
- `bash .claude/scripts/verify-deploy.sh --only-gate 16` reports the `pass` line against this
  repository.
- `bash .claude/scripts/verify-deploy.sh` is clean.

---

### Phase 8: Documentation convergence, redeploy, and full gate set [NOT STARTED]

**Goal**: every authoritative description of hard-mode routing describes the single-block
contract-injection model, the generated CLAUDE.md agrees, and the whole change is verified green
end to end on a freshly deployed tree.

**Tasks**:
- [ ] Rewrite `context/guides/hard-mode-routing.md`, the file most invested in the retired model:
      its 4-step precedence section, its "Extension Overrides This" table naming all six retired
      agents, and its own "`routing_agents_hard` Is Transitional" section, which narrates this
      task as a pending follow-on and is now self-resolved. Replace with the contract-injection
      model and a per-domain `hard_contracts` table.
- [ ] Finish `context/guides/manifest-routing-schema.md`: its title paragraph, its "two surviving
      routing blocks" framing, its `## The Two Routing Blocks (Plus One Unrelated Key)` section
      and table, and the completeness-rule prose naming Check C all assume
      `routing_agents_hard` survives. Collapse to a one-block-plus-one-unrelated-key model.
- [ ] Update `merge-sources/claudemd.md`'s Hard Mode section (line ~188), which names
      `routing_agents_hard` as live extension routing, so the generated CLAUDE.md stops
      advertising it.
- [ ] Update `check-extension-docs.sh`'s Rules B and C header comments, which document
      `routing_agents_hard` target-resolvability semantics that no longer exist; decide whether
      the `routing_agents_hard` arm of Rule B's resolvability check is worth keeping as a
      guard-against-reappearance or should go with the key.
- [ ] Sweep the remaining doc mentions: `cslib/README.md`'s hard-mode routing section,
      `docs/guides/copy-claude-directory.md`, `docs/guides/creating-commands.md`,
      `docs/reference/utility-scripts-inventory.md`'s Check C description, and
      `docs/architecture/handoff-schema.md`.
- [ ] Regenerate the affected `index-entries.json` summaries, keywords and line counts for every
      context file this plan rewrote, including core's two rows whose summaries name
      `routing_agents_hard`.
- [ ] Redeploy via `bash .claude/scripts/deploy-headless.sh`.
- [ ] Run the complete gate set and `lint-routing-wiring.sh --verbose`, and re-demonstrate a
      `--hard` dispatch in each of the three domains against the freshly deployed tree — the
      post-everything confirmation that contract injection still works after the routing block,
      the agents and the skills are all gone.
- [ ] Record, for the summary, the one deliberate behaviour change a reviewer could mistake for a
      regression: non-lean `--hard` dispatches now read core's generic contracts instead of
      lean's accidentally-clobbering overrides.

**Timing**: 2 hours

**Depends on**: 6, 7

**Verification Tier**: full

**Files to modify**:
- `agent-system/extensions/core/context/guides/hard-mode-routing.md` - substantial rewrite to the contract-injection model
- `agent-system/extensions/core/context/guides/manifest-routing-schema.md` - collapse to the one-block model
- `agent-system/extensions/core/merge-sources/claudemd.md` - Hard Mode section
- `agent-system/extensions/core/scripts/check-extension-docs.sh` - Rules B/C header comments and the routing_agents_hard arm
- `agent-system/extensions/cslib/README.md` - hard-mode routing section
- `agent-system/extensions/core/docs/guides/copy-claude-directory.md` - stale mention
- `agent-system/extensions/core/docs/guides/creating-commands.md` - stale mention
- `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md` - Check C description
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` - stale mention
- `agent-system/extensions/core/index-entries.json` - regenerate the two routing-guide rows' summaries, keywords and line counts
- `__WHOLE_TREE__`

**Verification**:
- `grep -r "routing_agents_hard\|routing_hard" agent-system/` returns only the deliberate
  absence-guard mentions in gate16, its registry row, its tests, and the schema guide's own
  retirement note.
- `bash agent-system/extensions/core/scripts/lint/lint-routing-wiring.sh --verbose` passes.
- `bash .claude/scripts/verify-deploy.sh` is fully clean with no new findings and gate16 green.
- A `--hard` dispatch file built for `lean4`, `cslib` and `books` against the freshly deployed
  tree each carries the expected `<hard-mode-contracts>` block.
- The generated CLAUDE.md's Hard Mode section no longer names `routing_agents_hard`.

---

## Testing & Validation

- [ ] `bash agent-system/extensions/core/scripts/lint/lint-routing-wiring.sh --verbose` passes with
      Check C removed and no surviving reference to it.
- [ ] `bash agent-system/extensions/core/scripts/lint/lint-gate-registry.sh` passes, gate ids still
      contiguous 1..27.
- [ ] `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` passes with no
      "in-scope agent file not found" failure.
- [ ] `bash agent-system/extensions/core/scripts/check-extension-docs.sh` passes for all three
      extensions, Rule A included.
- [ ] `bash agent-system/extensions/core/scripts/tests/run-all.sh` passes, with
      `test-routing-resolution.sh`, `test-verify-deploy-gate-selection.sh`,
      `test-gate-cache-equivalence.sh`, the three `test-lint-agent-contracts*` suites,
      `test-resume-scan-nonconformance.sh` and `test-lit-pipeline.sh` each green on their
      retargeted assertions rather than vacuously passing.
- [ ] `bash .claude/scripts/verify-deploy.sh` fully clean, gate16 green, no new findings.
- [ ] Per-domain demonstration, not assertion: a built `--hard` dispatch file for `lean4`, for
      `cslib` and for `books` each shows its expected contract list.
- [ ] Generic-path regression check: a built `--hard` dispatch for `meta` names bare
      `anti-analysis.md`, and that deployed file matches core's source.

## Artifacts & Outputs

- Three manifests declaring `hard_contracts` (or two, per the books decision) and none declaring
  `routing_agents_hard`.
- Six domain override contract files on the flat domain-prefixed convention, plus one new
  `lean4-sorry-discipline.md`.
- Twelve retired wrapper files (six agents, six skills) and every roster, index row, lint array,
  fixture and citation that named them.
- `command-route-agent.sh` with a single resolution path; `lint-routing-wiring.sh` without Check C.
- gate16 retained as a documented absence guard, with a fixture-independent WARN-channel test.
- Rewritten `hard-mode-routing.md` and `manifest-routing-schema.md`; an updated generated
  CLAUDE.md Hard Mode section.
- An implementation summary recording the one deliberate behaviour change (non-lean `--hard`
  dispatches now read core's generic contracts).

## Rollback/Contingency

Every phase closes with its own commit, so rollback is per-phase rather than all-or-nothing, and
the phase order is chosen so that stopping after any completed phase leaves a coherent system:

- After Phases 1-3: `routing_agents_hard` still resolves and still dispatches the `-hard` agents,
  so hard mode works exactly as before; the only landed change is that contract injection ALSO
  works and the clobber is fixed. Safe resting point.
- After Phase 4: `--hard` dispatches the standard agent with contracts injected. The twelve
  wrapper files are unreachable but harmless — `command-route-agent.sh`'s default-agent fallback
  guarantees any stale reference degrades to the standard agent rather than erroring. Safe resting
  point.
- After Phases 5-7: retirement and gate work are each self-contained; an incomplete sweep is
  caught by the gate set rather than by runtime behaviour.

If Phase 3's per-domain demonstration fails — the `<hard-mode-contracts>` block does not carry a
domain's overrides — do NOT proceed to Phase 4. The whole plan's safety rests on injection working
before the routing rung is removed. Revert to the pre-Phase-2 commit, redeploy, and report the
renderer or deploy behaviour that contradicted the convention Phase 1 recorded.

If the deploy copier turns out NOT to merge same-directory `provides.context` entries additively
at file level (the Phase 2/3 scope hypothesis), the override files must move into
`core/context/contracts/` instead — the rejected alternative in Decisions. That is a contained
change to Phases 2-3 only and does not disturb Phases 4-8.
