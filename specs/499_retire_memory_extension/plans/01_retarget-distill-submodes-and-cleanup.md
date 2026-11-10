# Implementation Plan: Task #499

- **Task**: 499 - Retarget the store-coupled distill sub-modes and retire the memory extension (Parts A, B, C, C2 only; Part D out of scope per the dispatch's SCOPE NARROWING section)
- **Status**: [NOT STARTED]
- **Effort**: 10.5 hours
- **Dependencies**: 496 (completed), 497 (completed)
- **Research Inputs**: specs/499_retire_memory_extension/reports/01_retarget-distill-submodes-and-cleanup.md
- **Artifacts**: plans/01_retarget-distill-submodes-and-cleanup.md (this file)
- **Standards**:
  - .claude/context/formats/plan-format.md
  - .claude/context/standards/status-markers.md
  - .claude/rules/artifact-formats.md
  - .claude/rules/state-management.md
  - .claude/rules/source-store-deploy-boundary.md
  - .claude/rules/no-task-references-in-deliverables.md
  - .claude/rules/no-record-versioning-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The hosted Sapience store has replaced the local `.memory/` vault as this repo's knowledge path
for everything except the email preference substrate. This plan completes that replacement for
the four parts the email substrate does not gate: it retargets the two store-coupled `/distill`
sub-modes (`--revise`, `--learn`) onto hosted knowledge objects, deletes the six sub-modes the
hosted store already performs server-side, removes the orphaned memory-coupled callers that live
in core rather than in the memory extension, and closes the tagged-write half of the sapience
retrieval loop so the live retrieval injection has a population to read. Definition of done: both
retargeted sub-modes operate against hosted knowledge objects with their degraded paths intact,
nothing in the source store references either deleted core script, `/todo` archival completes
without an archive-time harvest stage, an `/orchestrate` dispatch still receives repo-scoped
injected context and still degrades to empty context on failure, `.memory/` is present and
unmodified, and a full deploy plus the complete gate set passes.

The memory extension itself stays registered and installed. That is the intended end state here,
not an unfinished edge: the extension is left present but no longer load-bearing.

### Research Integration

`reports/01_retarget-distill-submodes-and-cleanup.md` supplies five findings this plan is built
on, each re-derived live at plan-authoring time (see Carried-Figure Re-Derivation below):

- The dispatch's premise that `memory-retrieve.sh` is "already dead" is refuted. Twenty-five live
  call sites across twelve extensions' `SKILL.md` Stage 4a blocks still invoke it, independent of
  the single `orchestrate-build-dispatch.sh` call site that was already swapped. Phase 1 exists
  solely to close that gap before the script is deleted in Phase 4.
- `sapience-retrieve.sh` is a confirmed drop-in replacement (identical three positional
  arguments, identical `<memory-context>` envelope, identical deployed directory), so Phase 1 is
  a script-name substitution, not a logic change.
- `memory-harvest.sh` is genuinely dead and deletable outright.
- Part B is a surgical scoring-engine prune, not six independent section deletions: the composite
  score and `health_score` calculation are consumed by the surviving `auto` sub-mode and must be
  retained, while the Health Report Template and Maintenance Candidate Classification table are
  consumed only by the six being deleted.
- Part C2's shape (a) is the natural fit, because `sapience_wrapup` is an MCP tool only an agent
  process can call and `orchestrate-cycle-postflight.sh` has no agent in the loop to compose note
  content.

The research deliberately left three decisions open for this phase. All three are decided below
under Decisions.

### Prior Plan Reference

No prior plan. `plans/` was empty at plan-authoring time.

### Roadmap Alignment

No `roadmap_path` was supplied in this dispatch's delegation context, so ROADMAP.md was not
loaded as a formal input. It was consulted read-only for sequencing context and advances the
"sapience migration" strand recorded there as the keystone-plus-five-records closure. Two
observations worth recording, neither an action for this plan:

- ROADMAP.md states `499 blocked:421,496,498`. Live `specs/state.json` records
  `dependencies: [496, 497]` for this task, both `completed`; `498` is on `hold` and gates Part D
  only, and `421` carries no edge into this task in live state. The ROADMAP line is stale
  relative to live state, which is the authority this plan follows.
- ROADMAP.md's rationale for sequencing `421` ahead of this task is that this task "deletes
  `agent-system/extensions/memory/` wholesale". Under the SCOPE NARROWING that is no longer true.
  A real overlap nevertheless remains, because Phases 2 and 3 rewrite
  `memory/skills/skill-distill/SKILL.md` substantially, and that file is `421`'s one surviving
  target. Retargeting or abandoning `421` is out of scope here.

## Goals & Non-Goals

**Goals**:

- `--revise` and `--learn` operate against hosted knowledge objects, carrying forward the
  three-strikes threshold, the interactive selection gate, the empty-event-store degraded path as
  a first-class normal outcome, and an explicit (never silent) announcement when the OTel session
  join is unavailable.
- A decided, recorded replacement for `--revise`'s CONTRADICTED outcome against a store with no
  delete API and no in-place rewrite.
- `report`, `--purge`, `--merge`, `--compress`, `--refine` and `--gc` removed, with the reason
  they are absent recorded where a reader looks for them, so their absence is distinguishable
  from a capability regression.
- `memory-retrieve.sh` and `memory-harvest.sh` removed, with every reference in the source store
  — executable and prose — updated or removed.
- `/todo` archival no longer carries an archive-time local-vault harvest, and the archival flow's
  own accounting of what it touches is updated to match.
- The sapience retrieval loop closed on the write side: the task-boundary moment that already
  writes vault notes writes repo-tagged ones that `sapience-retrieve.sh` can actually see, under
  an enforced 3-8-note-per-completed-task bound.
- `.memory/` present and byte-identical at task end.

**Non-Goals**:

- Removing the memory extension, editing `.claude-extensions.json`, or uninstalling anything
  (Part D, explicitly overridden by the dispatch's SCOPE NARROWING section).
- Deleting, importing, migrating or otherwise mutating `.memory/`. There is no re-import path and
  no delete API on the hosted store, so a bad import is permanent. This is a separate, later,
  owner-initiated decision.
- Deleting or retargeting the `auto` sub-mode. The dispatch enumerates exactly six sub-modes for
  deletion and `auto` is not among them. `auto` survives unchanged, including its local-vault
  Tier 1 refine fixes, which run only when the owner explicitly invokes `/distill --auto`. The
  task's read-only `.memory/` constraint governs what this task does to the vault, not what a
  future explicit owner invocation may do.
- Porting the email preference-harvest tally substrate, or any change to the email extension's
  behavior beyond a prose reference update.
- Retargeting or abandoning the `--meta` evidence-consumer record that ROADMAP.md flags as
  overlapping this task's `skill-distill/SKILL.md` edits.
- Adding an enumeration or raw-read mode to `sapience-retrieve.sh`. Phase 2 inverts the
  correlation direction instead (see Decisions), so no new read path is needed.

## Decisions

These three were left open by the research report and are settled here, with their reasoning, so
the implementer does not re-litigate them.

**D1 — `--revise`'s CONTRADICTED outcome becomes a single superseding-note write.** Against the
hosted store neither of the two current branches exists: there is no delete API, so a contradicted
item cannot be tombstoned, and `/ingest-kos` appends rather than rewrites, so the UPDATE branch's
rewrite-in-place with the old body moved to a `## History` section has no mechanism either. Both
branches therefore collapse into one: write one superseding knowledge object via
`sapience-remember.sh` whose body carries both the corrected guidance and the superseded guidance
it corrects, so a later reader of either note sees the correction. The hosted store performs its
own conflict surfacing and stale-position re-confirmation server-side, so the superseded note
being left in place is the store's designed behavior rather than a leak this sub-mode must clean
up. The three-option interactive gate keeps its shape — the two write options become one, so the
gate presents SUPERSEDE / SKIP.

**D2 — `--revise` correlates evidence-to-store, not store-to-evidence.** The current sub-mode
enumerates every vault memory from `.memory/memory-index.json` and correlates events onto it.
There is no hosted equivalent: `sapience-retrieve.sh` is a keyword-query read with a hardcoded
`MAX_ENTRIES=5` and a 2000-token budget, not a population enumeration, and adding an enumeration
mode would be new territory for a sub-mode the owner runs by hand. The correlation direction
inverts instead: for each recurring event cluster that has already crossed the three-strikes
threshold, query the hosted store with that cluster's keywords; a hit whose guidance the cluster's
evidence contradicts is CONTRADICTED, a hit consistent with it is CORROBORATED, and a miss is a
GAP. This preserves every classification outcome and the three-strikes semantics, needs no new
read path, and is strictly cheaper, because only clusters that already crossed the threshold are
queried rather than the whole population being enumerated.

D2 carries one hazard that must be designed for, not discovered: `sapience-retrieve.sh` exits 1
with empty stdout on *both* a zero-hit result and a network or credential failure, so an
unreachable host would make every cluster look like a GAP and generate spurious permanent writes.
`--revise` must therefore open with a reachability probe — one query whose keywords are known to
match at least one existing repo-tagged note — and, on probe failure, announce the degraded path
and classify nothing as a GAP for that run.

**D3 — Part C2 takes shape (a), instruction-level, and REPLACES the untagged `sapience_wrapup`
call rather than keeping both.** Shape (a) over shape (b): `sapience_wrapup` is an MCP tool
invokable only by an agent process, and `orchestrate-cycle-postflight.sh` has no agent in the loop
at its `[IMPLEMENTING] -> [COMPLETED]` transition, so shape (b) would require that script to
synthesize note text mechanically from the summary artifact — a worse note for a write that is
both permanent and unreviewed. Shape (a) also costs no new core territory in shared, high-traffic
code. The cost accepted: instruction-dependent rather than mechanically guaranteed.

Replace rather than keep both, settled by live probe rather than judgment: an unfiltered
`sapience_search` returns a repo-tagged knowledge object alongside untagged ones, confirming that
the `[repo:<slug>]` provenance tag narrows only reads that explicitly request the `source=`
filter. A tagged write is therefore strictly more reachable than an untagged one — unfiltered
reads see it and repo-filtered reads see it, while an untagged write is invisible to a
repo-filtered read. Keeping both would double permanent, unreviewed, undeletable write volume for
zero added reachability. The 3-8-note bound is a bound on the shared note set per completed task,
not per write path.

## Carried-Figure Re-Derivation

Every mechanical claim this plan carries from the dispatch description or the research report was
re-derived live at plan-authoring time. Results, stated even where they only confirm the source:

| Claim | Source | Re-derivation result |
|---|---|---|
| 25 live `memory-retrieve.sh` call sites across 12 extensions | research report | **CONFIRMED.** `grep -rlc 'bash .claude/scripts/memory-retrieve.sh' agent-system/` returns 25 files; 54 total references, so 29 are prose. |
| `memory-harvest.sh` has zero live callers | research report | **CONFIRMED.** All 13 remaining references are comments, docs, or the script's own header/usage. |
| Eager-context baseline 68606 B / 17151 tokens, CHECK PASSED | research report + dispatch hard constraint | **CONFIRMED** by a live `measure-eager-context.sh --check` run at plan-authoring time: identical byte and token figures, zero volatile-file hits. |
| `sapience-retrieve.sh` is a drop-in replacement | research report | **CONFIRMED** by reading its header and argument parse: same three positional arguments, same `<memory-context>` envelope, same deployed directory. |
| `orchestrate-build-dispatch.sh` Stage 3.5 already calls the sapience script and already degrades | research report + dispatch | **CONFIRMED** live: a direct `sapience-retrieve.sh` invocation returned a populated `<memory-context>` block, exit 0; the call site's `\|\| memory_context=""` degradation is present. |
| The hosted store performs consolidation, staleness re-confirmation and conflict detection (2372 knowledge objects compacted into 5 structures; a stale-position prompt; 10 open conflicts) | dispatch description, reported from a session briefing | **CARRIED-UNVERIFIED.** Not re-derivable from this repo; it is an observation about the hosted service's own behavior at one point in time. Phase 3 records the *capability* claim, attributed to that observation, and must not restate the three figures as current. |
| The entire `[repo:nvim]`-tagged population is 3 knowledge objects | dispatch description, measured 2026-11-10 | **PARTIALLY CONFIRMED, count CARRIED-UNVERIFIED.** A live unfiltered `sapience_search` returned 2 repo-tagged notes, both self-referential artifacts of building the scoping mechanism. The exact population size is not enumerable through either available read path (`sapience-retrieve.sh` caps at 5 entries and filters by keyword), so the "3" is carried from the dispatch's own measurement. The load-bearing part of the claim — that the tagged population is tiny and self-referential — is confirmed. |
| `remember_provenance()` in `~/.sapience/mcp.py` admits no caller-injectable repo marker | dispatch, marked "verified, do not re-derive" | **NOT RE-DERIVED**, per the dispatch's explicit instruction. The downstream consequence was independently confirmed instead: the live unfiltered search shows MCP-written notes carrying `via Claude Code session (MCP)` with no repo tag, while the script-written note carries `[repo:nvim]`. |
| A `hooks.postflight` entry in the sapience manifest can never fire | dispatch, marked "DO NOT ATTEMPT" | **NOT RE-DERIVED**, per instruction. Phase 6 does not attempt a lifecycle hook. |
| Live task dependencies | `specs/state.json` | **RE-DERIVED AND CORRECTED.** `dependencies: [496, 497]`, both `completed`. ROADMAP.md's `499 blocked:421,496,498` line is stale; `498` is `hold` and gates Part D only, `421` is `not_started` with no edge here. |

## Scope Declaration Correction

The task's declared `file_scope` in `specs/state.json` is materially narrower than the work the
dispatch requires. It omits all 25 extension `SKILL.md` call sites, `memory/EXTENSION.md`,
`memory/commands/distill.md`, the four deleted sub-mode pattern files, `core/manifest.json`, and
roughly a dozen prose-reference files. Each phase's `Files to modify` block below declares what
that phase actually touches, so `plan-file-scope-harvest.sh` widens `file_scope` at plan
postflight. Two entries in the declared scope are deliberately left untouched:
`orchestrate-cycle-postflight.sh` (declared so that choosing Part C2 shape (b) would not produce
an undeclared-path drop; shape (a) is chosen per D3, so it stays untouched) and
`sapience-remember.sh` (called, not modified).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Deleting `memory-retrieve.sh` before the 25 extension call sites are migrated breaks memory-context injection for every non-core task type | H | H if sequencing ignored | Phase 4 declares `Depends on: 1`. Phase 4's first task is a residual-reference grep that must return zero call sites before either script is deleted. |
| Seven phases against a standard-mode per-task cycle budget of 5 risks a `[PARTIAL]` mid-plan | M | M | The wave structure collapses to 4 waves, and a dispatch may close a whole wave. Every wave boundary leaves a coherent, deployable source store: no phase depends on a later phase's edit to be internally consistent. If a partial lands, the next cycle resumes at the next unstarted phase with no repair step. |
| Pruning the scoring engine too aggressively silently breaks `auto`'s `health_score` write | H | M | Phase 3 retains the Composite Score, Health Score Formula and Health Status Thresholds verbatim and deletes only the Health Report Template body and the Maintenance Candidate Classification table. Phase 3's verification re-reads `auto`'s Execution Flow, Auto Log Entry and the State Integration table and confirms every identifier they name still resolves. |
| A network or credential failure during `--revise` makes every event cluster look like a GAP, generating spurious permanent, unreviewable writes | H | M | D2's reachability probe: one query with keywords known to match an existing repo-tagged note, run before classification; on probe failure the run announces the degraded path and classifies nothing as a GAP. |
| Part C2's wiring lands a bound defect, writing permanent garbage removable only by hand in the web app | H | M | Phase 6's instruction states the 3-8 bound at the call site and requires a `--dry-run` pass before any real write. Phase 7 verifies a single bounded real write rather than a bulk rollout. |
| The Part C2 `EXTENSION.md` edit pushes the eager-load budget further over its recorded baseline | M | M | Phase 6 runs `measure-eager-context.sh --check` before and after and requires the sapience `EXTENSION.md` byte count to be unchanged or smaller **on its own**, without borrowing headroom from Phase 3's `memory/EXTENSION.md` shrink. Detail prose goes to `per-repo-scoping.md`, which is not eager-loaded. |
| Recording Part B's reasoning trips the no-record-versioning rule, which forbids "we removed X" / "no longer" / "previously" framing outside `specs/**` | M | H if written naively | Phase 3 states the reasoning positively as a current-design fact ("vault maintenance is performed server-side by the hosted store, so `/distill` provides none of it locally"), never as a change narrative. Phase 3's verification runs the record-versioning lint over every file it touched. |
| A sibling task dispatched this same cycle edits a file this plan also touches | M | L | Declared concurrent siblings (`423`, `461`) touch `measure-eager-context.sh`, `orchestrator-context-budget.json`, `git-commit-scoped.sh`, `git-staging-scope.md` and two test files — none in this plan's declared scope. `423` nevertheless owns `measure-eager-context.sh`, which Phase 6 *invokes*; invoke it, never edit it, and re-read any shared file immediately before editing. |
| Deleting two scripts from `core/manifest.json` leaves orphaned deployed copies until a redeploy prunes them | L | H until Phase 7 | Expected and handled: Phase 7's deploy plus the whole-tree orphan gate is where the deployed tree is reconciled. No intermediate phase claims a clean orphan check. |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 6 | -- |
| 2 | 3 | 2 |
| 3 | 4, 5 | 1, 2, 3 |
| 4 | 7 | 4, 5, 6 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Migrate the extension Stage 4a retrieval call sites [NOT STARTED]

**Goal**: Every per-extension research/implementation skill reaches memory context through the
sapience retrieval script, so the local retrieval script can be deleted in Phase 4 without
breaking context injection for any non-core task type.

**Tasks**:

- [ ] Re-derive the live call-site set with `grep -rln 'bash .claude/scripts/memory-retrieve.sh' agent-system/`
      and work from that output, not from the enumeration in this plan or the research report.
- [ ] In each file found, substitute the script name `memory-retrieve.sh` -> `sapience-retrieve.sh`
      in the Stage 4a invocation. Change nothing else: the three positional arguments, the
      `2>/dev/null`, the `|| memory_context=""` degradation and the `clean_flag` gate are all
      already correct for the replacement script.
- [ ] Update any surrounding prose in the same Stage 4a block that names the local memory vault as
      the source, so the block describes the hosted store it now reads.
- [ ] Confirm `sapience-retrieve.sh` is declared in the sapience manifest's `provides.scripts`
      array, so the deployed path each migrated call site uses will exist after Phase 7's deploy.
- [ ] Commit per extension (12 commits), not per file, so each commit is one coherent
      research/implementation skill pair.

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: interface

**Tier Justification**: `bash .claude/scripts/validate-wiring.sh --claude` plus two direct
residual greps (`grep -rn 'bash .claude/scripts/memory-retrieve.sh' agent-system/` returning
zero, and the same grep for `sapience-retrieve.sh` returning the same file count the pre-edit
re-derivation found) is the cheapest check that actually covers a cross-file script-name
substitution, since the only failure mode is a dangling or mistyped script reference.

**Scope Hypothesis**: 25 call-site files across 12 extensions, carried from the research report
(`reports/01_retarget-distill-submodes-and-cleanup.md`) and re-derived at plan-authoring time as
25 files. Confirm by re-running the grep in the first task above before editing; if the count has
moved, work from the live output and record the delta in the phase's commit message.

**Files to modify**:
- `agent-system/extensions/books/skills/skill-books-implementation/SKILL.md` - Stage 4a script name
- `agent-system/extensions/books/skills/skill-books-research/SKILL.md` - Stage 4a script name
- `agent-system/extensions/cslib/skills/skill-cslib-implementation/SKILL.md` - Stage 4a script name
- `agent-system/extensions/cslib/skills/skill-cslib-research/SKILL.md` - Stage 4a script name
- `agent-system/extensions/cslib/skills/skill-pr-review-implementation/SKILL.md` - Stage 4a script name
- `agent-system/extensions/cslib/skills/skill-pr-review-research/SKILL.md` - Stage 4a script name
- `agent-system/extensions/email/skills/skill-email-implementation/SKILL.md` - Stage 4a script name
- `agent-system/extensions/epidemiology/skills/skill-epi-implement/SKILL.md` - Stage 4a script name
- `agent-system/extensions/epidemiology/skills/skill-epi-research/SKILL.md` - Stage 4a script name
- `agent-system/extensions/latex/skills/skill-latex-implementation/SKILL.md` - Stage 4a script name
- `agent-system/extensions/latex/skills/skill-latex-research/SKILL.md` - Stage 4a script name
- `agent-system/extensions/nix/skills/skill-nix-implementation/SKILL.md` - Stage 4a script name
- `agent-system/extensions/nix/skills/skill-nix-research/SKILL.md` - Stage 4a script name
- `agent-system/extensions/nvim/skills/skill-neovim-implementation/SKILL.md` - Stage 4a script name
- `agent-system/extensions/nvim/skills/skill-neovim-research/SKILL.md` - Stage 4a script name
- `agent-system/extensions/python/skills/skill-python-implementation/SKILL.md` - Stage 4a script name
- `agent-system/extensions/python/skills/skill-python-research/SKILL.md` - Stage 4a script name
- `agent-system/extensions/rust/skills/skill-rust-implementation/SKILL.md` - Stage 4a script name
- `agent-system/extensions/rust/skills/skill-rust-research/SKILL.md` - Stage 4a script name
- `agent-system/extensions/typst/skills/skill-typst-implementation/SKILL.md` - Stage 4a script name
- `agent-system/extensions/typst/skills/skill-typst-research/SKILL.md` - Stage 4a script name
- `agent-system/extensions/web/skills/skill-web-implementation/SKILL.md` - Stage 4a script name
- `agent-system/extensions/web/skills/skill-web-research/SKILL.md` - Stage 4a script name
- `agent-system/extensions/z3/skills/skill-z3-implementation/SKILL.md` - Stage 4a script name
- `agent-system/extensions/z3/skills/skill-z3-research/SKILL.md` - Stage 4a script name

**Verification**:
- `grep -rn 'bash .claude/scripts/memory-retrieve.sh' agent-system/` returns zero matches.
- `grep -rln 'bash .claude/scripts/sapience-retrieve.sh' agent-system/extensions/*/skills/` returns
  the same file count the pre-edit re-derivation produced.
- `bash .claude/scripts/validate-wiring.sh --claude` reports no new failures against its pre-edit
  output, and exits with the same status.
- A spot diff of two migrated files confirms exactly one token changed per call site, with the
  argument list, redirection, degradation and gate untouched.

---

### Phase 2: Retarget `--revise` and `--learn` onto hosted knowledge objects [NOT STARTED]

**Goal**: Both store-coupled sub-modes read and write hosted knowledge objects instead of the
local vault, with D1's superseding-note outcome, D2's inverted correlation and reachability probe,
and every carried-forward guarantee intact.

**Tasks**:

- [ ] Rewrite `distill-revise-submode.md`'s Candidate Identification, Correlation and
      Classification sections to D2's evidence-to-store direction: cluster the
      deviation/blocker/reflection events pulled by `events-query.sh`, apply the three-strikes
      threshold to each cluster, and query the hosted store once per surviving cluster via
      `sapience-retrieve.sh`. Classify a hit consistent with the cluster as CORROBORATED, a hit
      the cluster contradicts as CONTRADICTED, and a miss as GAP.
- [ ] Add the D2 reachability probe as an Edge Case Check: one query whose keywords are known to
      match at least one existing repo-tagged note. State explicitly that
      `sapience-retrieve.sh` exits 1 with empty stdout on both a zero-hit result and a transport
      failure, so the two are indistinguishable without this probe, and that on probe failure the
      run announces the degradation and classifies nothing as a GAP.
- [ ] Replace the Contradicted/Stale Handling section's three options with D1's two: SUPERSEDE
      (one `sapience-remember.sh` write whose body carries both the corrected guidance and the
      guidance it corrects) and SKIP. Delete the TOMBSTONE option and its dependency on the purge
      sub-mode's Tombstone Application template, and delete the UPDATE option's
      rewrite-in-place/`## History` mechanics. State why in one sentence, as a property of the
      store (no delete API, append-only ingest, server-side conflict surfacing), not as a change
      narrative.
- [ ] Rewrite Gap Handling's CREATE branch as a `sapience-remember.sh` write. Keep the escalation
      discriminator that routes a system-change gap to an improvement proposal rather than a
      knowledge-object write, and keep its pointer to the relocated telemetry sub-mode path.
- [ ] Rewrite the No Events Yet degraded path so its continuation rule no longer references a
      deleted sub-mode. Keep `total_events: 0` as an explicitly normal, first-class outcome and
      keep the exact displayed message's intent: the run proceeds and reports zero correlations.
- [ ] Add the explicit OTel-absent announcement the dispatch requires: when
      `CLAUDE_CODE_ENABLE_TELEMETRY` is not set, the event-to-session join is unavailable and the
      run says so rather than silently skipping the Tier 1 join.
- [ ] Replace Batch Index Regeneration with a statement that hosted writes need no local index
      regeneration, and that the run touches no file under `.memory/`.
- [ ] Rewrite `distill-learn-submode.md`'s apply step to `sapience-remember.sh` writes, keeping
      its archived-task scan, its transcript/`history.jsonl` sourcing, its per-task grouped
      interactive classification, and its own `learn-harvest-log.json` bookkeeping. Add the
      per-invocation note bound explicitly, since `--learn` is a batch sweep across many archived
      tasks and every write is permanent and unreviewed.
- [ ] State in both files that neither sub-mode may ever run under `--auto`, preserving the
      interactive selection gate as a hard constraint rather than a default.
- [ ] Update `skill-distill/SKILL.md`'s `revise`/`learn` stub pointers and the State Integration
      table's note about which sub-modes touch `memory_health`, so both reflect that neither
      sub-mode writes to the local vault.
- [ ] Update the two `index-entries.json` summaries for the revise and learn pattern files to
      describe the hosted-store behavior.

**Timing**: 2 hours

**Depends on**: none

**Verification Tier**: prose

**Tier Justification**: every touched path is non-executable markdown or a JSON index summary with
no compile or elaboration surface, so the tier table's diff read-through is the covering check;
`suite_selection_select` over this phase's paths returns `__FULL_SWEEP__`, confirming no suite
maps to them, and the source-store markdown sub-case adds
`bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`.

**Files to modify**:
- `agent-system/extensions/memory/context/project/memory/patterns/distill-revise-submode.md` - retarget to hosted store; D1 superseding note; D2 inverted correlation and reachability probe; OTel-absent announcement
- `agent-system/extensions/memory/context/project/memory/patterns/distill-learn-submode.md` - retarget apply step to hosted writes; per-invocation bound
- `agent-system/extensions/memory/skills/skill-distill/SKILL.md` - revise/learn stub pointers and State Integration note
- `agent-system/extensions/memory/index-entries.json` - revise and learn summaries

**Verification**:
- Diff read-through confirms every changed hunk lies inside prose or a JSON string value.
- `grep -n 'tombstone\|TOMBSTONE\|memory-index.json\|10-Memories\|\.memory/' agent-system/extensions/memory/context/project/memory/patterns/distill-revise-submode.md agent-system/extensions/memory/context/project/memory/patterns/distill-learn-submode.md`
  returns only intentional mentions (for example the statement that no file under `.memory/` is
  touched), and no live instruction to write there.
- Both files still contain their three-strikes threshold, their MANDATORY STOP interactive gate,
  and their `total_events: 0` normal-outcome path; `--revise` additionally contains the
  OTel-absent announcement and the reachability probe.
- `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
  exits 0 with neither gate reporting SKIP.
- `python3 -c "import json;json.load(open('agent-system/extensions/memory/index-entries.json'))"`
  parses.

---

### Phase 3: Delete the six hosted-store-redundant sub-modes and prune the scoring engine [NOT STARTED]

**Goal**: `report`, `--purge`, `--merge`, `--compress`, `--refine` and `--gc` are gone; the
scoring machinery the surviving `auto` sub-mode consumes is retained intact; and the reason vault
maintenance is absent from `/distill` is recorded where a reader looks for it.

**Tasks**:

- [ ] Delete the four extracted pattern files for `purge`, `merge`, `compress` and `refine`.
- [ ] In `skill-distill/SKILL.md`, remove the six rows from the Sub-Mode Dispatch table and the
      sentence that counts the sub-modes, leaving `auto`, `revise` and `learn`.
- [ ] Remove the Maintenance Candidate Classification table, the Health Report Template body, the
      Purge Sub-Mode section together with its Link-Scan Procedure, Retrieval Exclusion and
      Health-Report-Tombstoned-Memories subsections, the GC Sub-Mode section, and the `merge`,
      `compress` and `refine` stub pointers.
- [ ] **Retain verbatim**: the Scoring Engine's Input, all four component scores, the Composite
      Score, Topic-Cluster Grouping, the Health Score Formula and the Health Status Thresholds.
      `auto` recalculates `health_score` and writes it to `state.json`, so these are live
      consumers, not residue. The Health Score Formula defines its own three counts inline, so it
      survives the Classification table's removal self-contained.
- [ ] Update the Shared Sub-Mode Skeleton's own enumeration of which sub-modes it governs, and its
      mandatory-stop exemption note, so both name only surviving sub-modes.
- [ ] Prune the Distill Log Schema's Operation Types to the surviving operations, keeping `refine`
      as `auto`'s own log type (`auto` logs `type: "refine"` with an `"auto mode"` note).
- [ ] Update the State Integration field-update table's column headers so they name only
      surviving sub-modes, and drop the `report`-specific rationale paragraph.
- [ ] In `commands/distill.md`, remove the six flags from the Mode Detection list and the
      `sub_mode` parse chain, remove their Section-anchor table rows and their output-contract
      blocks, and update the Purpose line.
- [ ] Decide and implement the bare-`/distill` behavior, since `report` was the default: a bare
      invocation prints the surviving sub-mode usage and exits without a default sub-mode. Every
      surviving sub-mode either mutates (`auto`) or requires an interactive gate (`--revise`,
      `--learn`), so silently defaulting to one is wrong.
- [ ] In `context/project/memory/distill-usage.md`, rebuild the Quick Reference per-flag table and
      the Memory Lifecycle rendering around the surviving sub-modes, and **record the reasoning**
      here, where a reader looks for a missing flag: state as a current-design fact that
      consolidation and compaction, staleness re-confirmation of load-bearing positions, and
      active conflict detection between a person's own notes are performed server-side by the
      hosted store, and that `/distill` therefore provides none of them locally. Attribute the
      capability observation to the hosted store's own session briefing as its source. Do not
      restate the three carried figures (2372 objects, 5 structures, 10 conflicts) as current
      state — they are CARRIED-UNVERIFIED per the re-derivation table above.
- [ ] Mirror the same positive framing, in one sentence, in `memory/EXTENSION.md`'s `/distill`
      command row. This file is merged verbatim into the assembled `.claude/CLAUDE.md` and is
      therefore eager-loaded: the row must come out shorter than it went in, since six flags are
      leaving it.
- [ ] Update `memory/README.md` and `memory/context/project/memory/README.md` where they enumerate
      sub-modes or point at the deleted pattern files.
- [ ] Remove the four deleted pattern files' entries from `memory/index-entries.json` and update
      the `distill-usage.md` entry's summary and keyword list.
- [ ] Re-read every file this phase touched for record-versioning language. The reasoning must
      read as a statement about the current design, never as a change narrative — no "no longer",
      "previously", "removed", "superseded" or version framing anywhere under `agent-system/**`.

**Timing**: 2 hours

**Depends on**: 2

**Verification Tier**: prose

**Tier Justification**: every touched path is markdown or a JSON index with no executable surface
— `suite_selection_select` over this phase's paths returns `__FULL_SWEEP__`, so no suite covers
them — and the source-store markdown sub-case's covering check is
`bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
alongside the tier's diff read-through.

**Scope Hypothesis**: four pattern-file deletions and eight file edits, estimated from reading
`skill-distill/SKILL.md`'s heading map and `commands/distill.md`'s flag table at plan-authoring
time. Confirm by grepping each deleted sub-mode's name across `agent-system/extensions/memory/`
after the edits; any surviving live reference means a file this estimate missed.

**Files to modify**:
- `agent-system/extensions/memory/context/project/memory/patterns/distill-purge-submode.md` - delete
- `agent-system/extensions/memory/context/project/memory/patterns/distill-merge-submode.md` - delete
- `agent-system/extensions/memory/context/project/memory/patterns/distill-compress-submode.md` - delete
- `agent-system/extensions/memory/context/project/memory/patterns/distill-refine-submode.md` - delete
- `agent-system/extensions/memory/skills/skill-distill/SKILL.md` - dispatch table, classification table, health report template, purge/gc sections, stubs, skeleton enumeration, log schema, state-integration table
- `agent-system/extensions/memory/commands/distill.md` - flags, parse chain, section anchors, output contracts, bare-invocation behavior
- `agent-system/extensions/memory/context/project/memory/distill-usage.md` - quick reference, lifecycle, and the recorded server-side-maintenance reasoning
- `agent-system/extensions/memory/EXTENSION.md` - `/distill` command row (eager-loaded; must shrink)
- `agent-system/extensions/memory/README.md` - sub-mode enumeration and pattern-file pointers
- `agent-system/extensions/memory/context/project/memory/README.md` - context index entries
- `agent-system/extensions/memory/index-entries.json` - remove four deleted pattern entries; update distill-usage summary

**Verification**:
- The four pattern files are absent from disk.
- `grep -rn 'purge\|merge\|compress\|refine\|--gc\|health report' agent-system/extensions/memory/`
  returns only intentional survivors: `auto`'s inline Tier 1 refine fixes, its `type: "refine"`
  log entry, and the Health Score Formula's own three count definitions.
- `skill-distill/SKILL.md` still contains the Composite Score, the Health Score Formula and the
  Health Status Thresholds, and every identifier named by `auto`'s Execution Flow, Auto Log Entry
  and the State Integration table resolves within the file.
- `commands/distill.md`'s Section-anchor table resolves: every anchor it names exists as a heading
  in `skill-distill/SKILL.md` or in a surviving pattern file.
- A bare `/distill` path through `commands/distill.md` reaches the usage-and-exit branch, not an
  undefined `sub_mode`.
- `bash .claude/scripts/check-record-versioning.sh` (or
  `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`,
  whose gate set includes the record-versioning and task-reference lints) exits 0 with neither
  gate reporting SKIP.
- `python3 -c "import json;json.load(open('agent-system/extensions/memory/index-entries.json'))"`
  parses, and `bash .claude/scripts/validate-context-index.sh` reports no entry pointing at a
  deleted file.
- `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/measure-eager-context.sh --check`
  reports a TOTAL no larger than the 68606 B pre-edit baseline.

---

### Phase 4: Delete the orphaned core scripts and update every reference [NOT STARTED]

**Goal**: Neither `memory-retrieve.sh` nor `memory-harvest.sh` exists in the source store, and no
reference anywhere in it — executable, test, manifest or prose — points at either.

**Tasks**:

- [ ] Gate on Phase 1: confirm
      `grep -rn 'bash .claude/scripts/memory-retrieve.sh' agent-system/` returns zero before
      deleting anything. If it does not, stop and complete Phase 1 first.
- [ ] Delete `scripts/memory-retrieve.sh` and `scripts/memory-harvest.sh`.
- [ ] Remove both entries from `core/manifest.json`'s `provides.scripts` array.
- [ ] Update `test-orchestrate-build-aux-dispatch.sh`'s negative assertion, which greps the aux
      dispatch builder for the retired script name. The assertion's purpose is that the aux
      builder never shells out to a retrieval script, so repoint its pattern at
      `sapience-retrieve.sh`; leaving it naming a script that no longer exists would make the
      assertion vacuously true.
- [ ] Update the matching comment in `orchestrate-build-aux-dispatch.sh`'s header so the script it
      promises never to call is the one that exists.
- [ ] Update `scripts/lib/common.sh`'s sourcer-inventory comment, which lists both scripts.
- [ ] Update `scripts/sweep-invalidated-claims.sh`'s header, which describes `memory-harvest.sh`
      as an existing potential caller, and `scripts/lib/task-reference-patterns.sh`'s comment
      attributing harvest-written data to it.
- [ ] Sweep the remaining prose references: `core/README.md`,
      `core/docs/guides/creating-extensions.md`, `core/context/patterns/skill-lifecycle.md`,
      `core/context/patterns/context-protective-lead.md`,
      `core/context/standards/telemetry-guardrails.md`,
      `core/context/standards/task-reference-exemptions.md`,
      `core/context/standards/shell-script-testing.md`,
      `core/context/meta/meta-guide.md`,
      `literature/skills/skill-literature/SKILL.md`, and
      `email/context/project/email/design/email-to-memory-preferences.md`. Repoint each at the
      sapience retrieval script where it describes a live mechanism; remove the reference where it
      describes a mechanism that no longer exists.
- [ ] While editing `core/context/patterns/skill-lifecycle.md`, take the research report's context
      recommendation: state in its Stage 4a row that the retrieval call site is duplicated once
      per extension skill rather than centralized, so a future sweep for every memory-context
      injection point does not have to re-derive that from a repo-wide grep.
- [ ] Update the memory extension's own references in `memory/EXTENSION.md`'s
      Memory-Augmented Research paragraph, `memory/README.md` and
      `memory/skills/skill-learn/README.md`, and the stale comment in `skill-distill/SKILL.md`.
      `memory/EXTENSION.md` is eager-loaded, so this edit must not grow it.

**Timing**: 2 hours

**Depends on**: 1, 2, 3

**Verification Tier**: full

**Tier Justification**: this phase edits core's `provides.scripts` manifest declaration, a
cross-cutting surface read by the deploy engine, the whole-tree orphan-detection gate and the
standing script-inventory probe alike, so no narrowing by suite or gate subset covers it — the
selector returns `__FULL_SWEEP__` for this phase's combined touched-path set, confirming that no
suite maps to the two deleted scripts or to most of the prose files beside them.

**Scope Hypothesis**: two deletions plus roughly seventeen reference files, derived at
plan-authoring time from `grep -rn 'memory-retrieve\.sh\|memory-harvest\.sh' agent-system/`
(54 and 13 references respectively). Confirm by re-running that grep after the edits; it must
return zero, and any file it names that is absent from the list below is one this estimate missed.

**Files to modify**:
- `agent-system/extensions/core/scripts/memory-retrieve.sh` - delete
- `agent-system/extensions/core/scripts/memory-harvest.sh` - delete
- `agent-system/extensions/core/manifest.json` - remove both script entries
- `agent-system/extensions/core/scripts/tests/test-orchestrate-build-aux-dispatch.sh` - repoint the negative assertion's pattern
- `agent-system/extensions/core/scripts/orchestrate-build-aux-dispatch.sh` - header comment
- `agent-system/extensions/core/scripts/lib/common.sh` - sourcer-inventory comment
- `agent-system/extensions/core/scripts/sweep-invalidated-claims.sh` - header reference
- `agent-system/extensions/core/scripts/lib/task-reference-patterns.sh` - comment reference
- `agent-system/extensions/core/README.md` - script-list reference
- `agent-system/extensions/core/docs/guides/creating-extensions.md` - topic-taxonomy example reference
- `agent-system/extensions/core/context/patterns/skill-lifecycle.md` - Stage 4a row, plus the per-extension-duplication note
- `agent-system/extensions/core/context/patterns/context-protective-lead.md` - two references
- `agent-system/extensions/core/context/standards/telemetry-guardrails.md` - two references
- `agent-system/extensions/core/context/standards/task-reference-exemptions.md` - three references
- `agent-system/extensions/core/context/standards/shell-script-testing.md` - one reference
- `agent-system/extensions/core/context/meta/meta-guide.md` - two references
- `agent-system/extensions/literature/skills/skill-literature/SKILL.md` - token-counting pattern attribution
- `agent-system/extensions/email/context/project/email/design/email-to-memory-preferences.md` - six references
- `agent-system/extensions/memory/EXTENSION.md` - Memory-Augmented Research paragraph (eager-loaded; must not grow)
- `agent-system/extensions/memory/README.md` - three references
- `agent-system/extensions/memory/skills/skill-learn/README.md` - one reference
- `agent-system/extensions/memory/skills/skill-distill/SKILL.md` - stale comment reference

**Verification**:
- `grep -rn 'memory-retrieve\.sh\|memory-harvest\.sh' agent-system/` returns zero matches.
- Neither script exists on disk; neither appears in `core/manifest.json`.
- `bash .claude/scripts/verify-deploy.sh` exits 0 — the complete gate set this phase's `full`
  declaration requires, not a gate subset and not a `--skip-slow` substitution. The manifest-sync,
  script-inventory and aux-dispatch assertions run inside it; confirm specifically that the
  aux-dispatch suite's negative assertion exercises the repointed pattern rather than a dead name.
- `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/measure-eager-context.sh --check`
  reports a TOTAL no larger than the figure Phase 3 left.
- `.memory/` carries no change attributable to this task: `git status --porcelain .memory/` is
  byte-identical to the baseline captured at the task's start. **Baseline, captured at
  plan-authoring time: ` M .memory/memory-index.json` — one pre-existing modification that
  predates this task.** The criterion is "unchanged from that baseline", never "empty"; an
  empty-tree criterion would fail on state this task did not create.

---

### Phase 5: Strip the archive-time memory harvest from `/todo` [NOT STARTED]

**Goal**: `/todo` archival no longer reads memory candidates, dedups against the local index,
prompts for them, or writes record files and regenerates local indices — and the archival flow's
own accounting of what it touches matches.

**Tasks**:

- [ ] Remove Stage 7 (`HarvestMemories`) in full, including its collection, keyword-overlap dedup
      against `.memory/memory-index.json`, and three-tier classification.
- [ ] Remove Stage 14 (`CreateMemories`) in full, including record-file creation from the local
      template, the per-candidate field mapping, and the batch regeneration of
      `memory-index.json`, `20-Indices/index.md` and `10-Memories/README.md`.
- [ ] Remove Stage 8's `Memory candidates:` dry-run preview line.
- [ ] Remove Stage 9's memory-harvest sub-step and renumber the sub-steps after it, so the
      status-reconciliation sub-step keeps a correct ordinal.
- [ ] Remove the CHANGE_LOG stage's "append memory harvest note if memories were suggested" step.
- [ ] Renumber or re-anchor any stage cross-reference that named a removed stage by number, and
      confirm no surviving stage references `harvest_candidates` or `approved_memories`.
- [ ] Record the reason the archival flow does not harvest, stated as a current-design fact: a
      task's recorded candidates are harvested by `/distill --learn`'s retroactive sweep across
      already-archived tasks, which is bounded per invocation and gated interactively, rather than
      at archival time where one `/todo` run archives many tasks at once and would write
      permanent, unreviewed notes in bulk. Note that `memory_candidates` is still recorded on each
      task entry and is still implicitly cleaned when the entry moves to archive, so nothing is
      lost by not harvesting here.

**Timing**: 1 hour

**Depends on**: 2, 3

**Verification Tier**: prose

**Tier Justification**: the one touched path is a markdown skill definition with no compile or
elaboration surface, and a removed stage's only failure mode is a dangling cross-reference or a
broken sub-step ordinal, which the tier's diff read-through plus
`bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
is the cheapest combination that actually reaches.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-todo/SKILL.md` - remove Stages 7 and 14, the Stage 8 preview line, the Stage 9 sub-step (with renumbering), and the CHANGE_LOG harvest note; record the rationale

**Verification**:
- `grep -n 'HarvestMemories\|CreateMemories\|harvest_candidates\|approved_memories\|memory-index\|10-Memories\|30-Templates' agent-system/extensions/core/skills/skill-todo/SKILL.md`
  returns only the rationale paragraph's intentional mention of `/distill --learn`, with no live
  instruction to read or write the local vault.
- Every `<stage id=...>` in the file has a unique id, and no surviving stage's prose references a
  removed stage by number.
- Stage 9's surviving sub-steps are numbered consecutively from 1.
- `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
  exits 0 with neither gate reporting SKIP.
- A dry-run read-through of the archival flow confirms no stage can reach a `.memory/` write.

---

### Phase 6: Close the tagged-write half of the sapience retrieval loop [NOT STARTED]

**Goal**: The task-boundary moment that already writes vault notes writes repo-tagged ones that
`sapience-retrieve.sh` can see, under an enforced 3-8-note-per-completed-task bound, with the
eager-context budget no larger than before.

**Tasks**:

- [ ] Record the pre-edit baseline:
      `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/measure-eager-context.sh --check`,
      and the byte count of `agent-system/extensions/sapience/EXTENSION.md`.
- [ ] Amend `EXTENSION.md`'s Postflight wrapup instruction per D3: at the
      `[IMPLEMENTING]` -> `[COMPLETED]` transition, write 3-8 distilled notes from the summary
      artifact just written by calling `scripts/sapience-remember.sh` once per note, replacing the
      `sapience_wrapup` call. State the bound at the call site, because the script deliberately
      does not enforce it and every write is permanent and unreviewed. Keep the existing
      prohibition on proactive mid-run `sapience_remember` calls.
- [ ] Offset the addition: the "What this extension adds" paragraph's claim that
      `sapience-remember.sh` "is not wired into any call site by this extension" becomes wrong and
      can be replaced by a shorter statement of where it is called from. The net byte count of
      `EXTENSION.md` must be unchanged or smaller **on its own**, without borrowing headroom from
      Phase 3's `memory/EXTENSION.md` shrink.
- [ ] Put the detail in `domain/per-repo-scoping.md`, which is read-on-demand rather than
      eager-loaded: the call-site contract, the 3-8 bound and why it is load-bearing at the call
      site rather than in the script, the dry-run-before-real-write requirement, and the degrade
      rule (a failed write is logged and stepped over, never failing postflight or blocking the
      status transition).
- [ ] Record in `per-repo-scoping.md` the D3 replace-not-both reasoning and its evidence: an
      unfiltered vault read returns repo-tagged knowledge objects, so the tag narrows only reads
      that request the `source=` filter, making a tagged write strictly more reachable than an
      untagged one. Update that file's own statement that `sapience-remember.sh` is unwired.
      State this as a property of the current design, not as a change narrative.
- [ ] Do **not** add a `hooks.postflight` entry to the sapience manifest. It can never fire: hook
      resolution is gated on the extension declaring a `task_type`, and this extension is
      deliberately typeless. Record that constraint in `per-repo-scoping.md` so the question is
      not reopened.
- [ ] Leave `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` untouched. It
      is declared in `file_scope` only so that shape (b) would not have produced an
      undeclared-path drop; shape (a) is chosen.
- [ ] Update `context/project/sapience/README.md`'s index entry for `per-repo-scoping.md` if its
      summary no longer describes the file's contents.
- [ ] Dry-run the wiring before Phase 7's real write:
      `bash .claude/scripts/sapience-remember.sh --subject "..." --value "..." --dry-run` exits 0
      and prints a request body whose `provenance` carries `[repo:nvim]` and whose token is
      redacted.
- [ ] Re-run the eager-context check and confirm the TOTAL has not grown.

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/measure-eager-context.sh --check`
is the specific check that covers this phase's one real hazard — growing the eager-load budget via
a merged-verbatim `EXTENSION.md` — and it is the same measurement gate 20 runs, so a broader tier
would add no coverage for a three-file markdown edit.

**Scope Hypothesis**: three files, and an `EXTENSION.md` net byte delta of zero or less. Confirm
by `wc -c` on `EXTENSION.md` before and after, and by the eager-context check's TOTAL; if the
delta is positive, move more prose into `per-repo-scoping.md` rather than accepting the growth.

**Files to modify**:
- `agent-system/extensions/sapience/EXTENSION.md` - postflight wrapup instruction becomes the tagged-write call with its bound; the unwired-script sentence is replaced (eager-loaded; net bytes must not grow)
- `agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md` - call-site contract, bound rationale, dry-run requirement, degrade rule, D3 reachability evidence, and the no-lifecycle-hook constraint
- `agent-system/extensions/sapience/context/project/sapience/README.md` - index-entry summary for per-repo-scoping.md

**Verification**:
- `wc -c agent-system/extensions/sapience/EXTENSION.md` is less than or equal to its pre-edit
  value.
- `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/measure-eager-context.sh --check`
  exits 0, reports zero volatile-file hits, and a TOTAL no larger than the pre-edit value.
- `EXTENSION.md` names `scripts/sapience-remember.sh`, states the 3-8-note bound, and no longer
  instructs a `sapience_wrapup` call; it contains no `hooks` declaration.
- `grep -n 'task_type\|hooks.postflight\|lifecycle hook' agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md`
  shows the no-lifecycle-hook constraint recorded.
- `bash .claude/scripts/sapience-remember.sh --subject 'wiring dry run' --value 'Dry-run verification of the tagged-write call site.' --dry-run`
  exits 0 and prints a body containing `[repo:nvim]` with no token value.
- `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
  exits 0 with neither gate reporting SKIP.
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` is unmodified:
  `git diff --stat -- agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` is
  empty.

---

### Phase 7: Redeploy and verify the whole change under the complete gate set [NOT STARTED]

**Goal**: The deployed tree matches the source store, the complete gate set passes, and every
applicable verification bullet from the dispatch is observed rather than asserted.

**Tasks**:

- [ ] Re-read the working tree for foreign changes before deploying: `git status --short` and
      `git log --oneline -5`. Concurrent siblings were scheduled this same cycle; a foreign commit
      or uncommitted modification is reported, not worked around.
- [ ] Run `bash .claude/scripts/deploy-headless.sh /home/benjamin/.config/nvim` (the
      non-destructive force-resync default, not `--wipe`) and confirm it exits 0.
- [ ] Confirm the deployed tree reflects the change: `.claude/scripts/memory-retrieve.sh` and
      `.claude/scripts/memory-harvest.sh` are absent, `.claude/scripts/sapience-retrieve.sh` and
      `.claude/scripts/sapience-remember.sh` are present, the four deleted sub-mode pattern files
      are absent from `.claude/context/project/memory/patterns/`, and the assembled
      `.claude/CLAUDE.md` carries the amended sapience and memory sections.
- [ ] Run the complete gate set: `bash .claude/scripts/verify-deploy.sh`. Do not substitute
      `--skip-slow` or a gate subset — this is the final phase and the full set is owed here.
- [ ] Verify repo-scoped injection still works end to end:
      `bash .claude/scripts/sapience-retrieve.sh "<a description drawn from this task>" meta`
      returns a populated `<memory-context>` block, and a forced failure (an unset or bogus
      `SAPIENCE_HOST`) exits non-zero with empty stdout, so the dispatch builder's
      `|| memory_context=""` degradation yields empty context rather than an error.
- [ ] Verify `--revise`'s and `--learn`'s degraded paths as specified: with the event store
      reporting `total_events: 0`, each announces the normal degraded outcome and proceeds; with
      `CLAUDE_CODE_ENABLE_TELEMETRY` unset, `--revise` announces the unavailable session join
      explicitly rather than skipping it silently.
- [ ] Verify `/todo` archival completes without a harvest stage erroring, via a `--dry-run`
      archival pass that reaches its preview output with no memory-candidate line and no error.
- [ ] Discharge the Part C2 write verification within what one task can observe: at this task's
      own postflight, write the bounded 3-8-note set through `sapience-remember.sh` and confirm
      each call reports `written >= 1` with no `gated` and no `set_aside`. Then confirm a forced
      write failure is logged and stepped over without failing postflight or blocking the status
      transition. Record explicitly that the third item — a later dispatch's
      `sapience-retrieve.sh` returning a note originating from this completed task rather than
      only the pre-existing build artifacts — is observable only on a subsequent dispatch and is
      therefore stated as pending observation, not claimed as verified here.
- [ ] Confirm `.memory/` is present and carries no change attributable to this task:
      `git status --porcelain .memory/` matches the baseline captured at the task's start
      (` M .memory/memory-index.json`, a pre-existing modification), and the directory's file
      list is unchanged. Do not treat the pre-existing entry as a violation, and do not
      "repair" it — reverting it would itself be a write to a tree this task holds read-only.
- [ ] Confirm the three verification bullets the SCOPE NARROWING section retired are not claimed
      anywhere in this task's artifacts: no claim that the memory extension is absent, that a
      clean-tree deploy succeeds without it, or that email triage Stage 7 was verified.

**Timing**: 1 hour

**Depends on**: 4, 5, 6

**Verification Tier**: full

**Files to modify**:
- `__WHOLE_TREE__` - this phase invokes whole-tree regeneration via the deploy script

**Verification**:
- `bash .claude/scripts/deploy-headless.sh /home/benjamin/.config/nvim` exits 0.
- `bash .claude/scripts/verify-deploy.sh` exits 0 — the complete gate set, including the shell
  test-suite battery, the whole-tree orphan detection that prunes the two deleted scripts'
  deployed copies, the record-versioning and task-reference lints, and the orchestrator
  context-budget lock. No gate subset and no `--skip-slow` substitution.
- `bash .claude/scripts/sapience-retrieve.sh "<task description>" meta` returns a populated
  `<memory-context>`; the same call under a bogus `SAPIENCE_HOST` exits non-zero with empty
  stdout.
- `grep -rn 'memory-retrieve\.sh\|memory-harvest\.sh' agent-system/` returns zero.
- `git status --porcelain .memory/` matches the task's starting baseline, and the directory's
  file list is unchanged.
- Each `sapience-remember.sh` call in the postflight note set reports `written >= 1` with no
  `gated` and no `set_aside`; the forced-failure case leaves the task's status transition intact.

---

## Testing & Validation

- [ ] `grep -rn 'bash .claude/scripts/memory-retrieve.sh' agent-system/` returns zero (Phase 1).
- [ ] `grep -rn 'memory-retrieve\.sh\|memory-harvest\.sh' agent-system/` returns zero (Phase 4).
- [ ] `bash .claude/scripts/validate-wiring.sh --claude` reports no new failures (Phase 1).
- [ ] `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
      exits 0 with neither gate reporting SKIP, at each markdown-editing phase.
- [ ] `bash .claude/scripts/verify-deploy.sh` exits 0, complete gate set, at Phase 4 (its `full`
      declaration) and again at Phase 7.
- [ ] The archival flow's own read-through confirms no surviving stage references a removed stage
      by number and that Stage 9's sub-steps are numbered consecutively (Phase 5).
- [ ] `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/measure-eager-context.sh --check`
      exits 0 with a TOTAL no larger than 68606 B at every phase that touches an eager-loaded file.
- [ ] `python3 -c "import json;json.load(open('agent-system/extensions/memory/index-entries.json'))"`
      parses, and `validate-context-index.sh` reports no entry pointing at a deleted file.
- [ ] `bash .claude/scripts/deploy-headless.sh /home/benjamin/.config/nvim` exits 0 (Phase 7).
- [ ] `bash .claude/scripts/verify-deploy.sh` exits 0, complete gate set (Phase 7).
- [ ] `git status --porcelain .memory/` matches the baseline captured at the task's start
      (` M .memory/memory-index.json`) at every phase boundary — never required to be empty.
- [ ] Both retargeted sub-modes take their stated degraded paths for an empty event store and for
      an absent OTel session join (Phase 7).
- [ ] `/todo --dry-run` reaches its preview with no memory-candidate line and no error (Phase 7).
- [ ] A dry-run and then a single bounded real `sapience-remember.sh` write succeed, and a forced
      write failure degrades without breaking postflight (Phases 6 and 7).

## Artifacts & Outputs

- `agent-system/extensions/memory/context/project/memory/patterns/distill-revise-submode.md` —
  retargeted to hosted knowledge objects, with the superseding-note outcome, the inverted
  correlation direction and the reachability probe.
- `agent-system/extensions/memory/context/project/memory/patterns/distill-learn-submode.md` —
  retargeted apply step with a per-invocation write bound.
- Four deleted sub-mode pattern files and a pruned `skill-distill/SKILL.md` and `commands/distill.md`.
- `agent-system/extensions/memory/context/project/memory/distill-usage.md` — surviving sub-mode
  reference plus the recorded server-side-maintenance reasoning.
- Two deleted core scripts, a pruned `core/manifest.json`, and roughly seventeen updated
  reference files.
- `agent-system/extensions/core/skills/skill-todo/SKILL.md` — archival flow with no local-vault
  harvest and a recorded rationale.
- `agent-system/extensions/sapience/EXTENSION.md` and `domain/per-repo-scoping.md` — the closed
  tagged-write loop, its bound, and its degrade rule.
- A regenerated `.claude/` deploy tree (not a tracked artifact; regenerated, never hand-authored).
- `specs/499_retire_memory_extension/summaries/01_*-summary.md` at implementation completion.
- `.memory/` — unchanged, by design.

## Rollback/Contingency

Every phase is a markdown, JSON or shell-comment edit plus two file deletions; nothing here
migrates data, and `.memory/` is never written, so no phase has an irreversible local effect. Each
phase closes with its own commit, so reverting a single phase is `git revert` of that phase's
commit followed by a redeploy.

Two things are not revertible by git and must be treated accordingly:

- **A landed hosted-store write.** There is no delete API on the vault; removal is manual, in the
  web app. This is why Phase 6 dry-runs the wiring before Phase 7 writes anything real, and why
  Phase 7 writes one bounded note set rather than a bulk rollout. If a wiring defect is discovered
  after a real write, revert the `EXTENSION.md` instruction immediately so no further writes land,
  then remove the landed notes by hand; do not attempt a scripted cleanup.
- **The deployed `.claude/` tree.** It is a gitignored, disposable artifact. Recovering it is a
  redeploy from the reverted source store, never a hand edit.

Should the working tree need to be reverted wholesale before a phase's commit, take the snapshot
first per `context/contracts/recovery.md`'s rollback rung, then run the destructive command — and
never use the reverting default form of the snapshot script as an ordinary precaution, since
sibling tasks are live on this same tree this cycle.

If the plan runs out of cycle budget mid-way, the correct contingency is to stop at a phase
boundary and let the task resume: every wave boundary leaves a source store that is internally
consistent and deployable, and no phase requires a later phase's edit to be correct.
