# Implementation Plan: Task #625

- **Task**: 625 - Roadmap preflight approval gate
- **Status**: [IMPLEMENTING]
- **Effort**: 5.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/625_roadmap_preflight_approval_gate/reports/01_roadmap-preflight-gate.md
- **Artifacts**: plans/01_roadmap-preflight-gate.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`roadmap-integration.sh --regenerate` already classifies `specs/ROADMAP.md` before writing and
refuses loudly on an unrecognised layout (a permanent, documented property), but no caller
escalates that refusal — and the file-absent case is a silent successful no-op. This plan adds a
preflight that sits strictly IN FRONT of the generator: one shared library that classifies the
file four ways and mechanically scaffolds the classic eight-header skeleton on approval, wired
into both write-mode callers with the gate each one's surface can actually support (an
`AskUserQuestion` approval in `skill-roadmap`'s own pre-dispatch execution, a loud structured
degrade plus durable evidence at `/orchestrate`'s conclusion stage). Done when both callers are
gated, the caller contract and Move 5 allow-list name the preflight, and
`test-roadmap-generation.sh` covers all four verdicts plus scaffold-then-regenerate idempotence.

### Premise Re-Validation (Carried-Figure Discipline)

Each flagged description claim was checked against live source, not assumed:

| Claim | Verdict |
|-------|---------|
| `--regenerate` refuses on `unknown`, exits non-zero, no write | **Confirmed** — `mode_regenerate` dispatches `*) refuse_unrecognised_layout regenerate unknown; return 1` (`scripts/roadmap-integration.sh:746-753`) |
| `--regenerate` no-ops with `NOTE: no roadmap tracked at ...` when absent | **Confirmed** — `scripts/roadmap-integration.sh:738-742`, `return 0` |
| `skill-roadmap/SKILL.md` Stage 3 escalates no further than a soft `WARNING:` echo | **Confirmed** — two `|| echo "WARNING: ..."` lines, no non-zero propagation |
| Move 5 allow-list currently lists `roadmap-integration.sh --regenerate` and not the preflight | **Confirmed** — `context/standards/postflight-tool-restrictions.md`, Conclusion Stage (Move 5) Allowed Tool Surface, `Bash` row; neither a preflight entry nor `issue-record.sh` is present |
| `infrastructure/transport unavailable` "may not be the best fit" | **Confirmed poor fit** — its own gloss scopes it to an external system being unreachable; re-read all 16 seed classes, none covers "approval required, no answerer present". The open-enum Extensibility Rule sanctions minting a new class |
| Both consumer-repo measurements (two `/roadmap` passes, judgment stuck for weeks) | **Accepted as given, not re-derived** — the description instructs this explicitly; nothing in this repository contradicts them |
| `.dotfiles/specs/ROADMAP.md` hand-migration is out of scope | **Confirmed untouched** — no phase below reads or writes it |

**One divergence found, and it changes a design premise rather than a fact.** The description
states Move 5 "runs autonomously with no interactive surface." As a *tool-availability* claim
that is false: Move 5's own allowed-tool table grants `AskUserQuestion` for channel (a)'s
approval gate and Step 7's `edges` gate. As a *posture* claim it holds — those are two
pre-existing, narrowly-keyed gates backed by a durable approval ledger, and `/orchestrate` is
defined as running without confirmation gates between phases. This plan follows the description's
directive (loud degrade at Move 5, never a third prompt); see Decision 4 for why, and the Risks
table for the residual.

### Research Integration

Six research findings are load-bearing here and are not re-litigated in the phases below:

1. **Extract, do not source or shell out.** `roadmap-integration.sh` parses `$@` and calls `exit`
   at top level with no `BASH_SOURCE` run-as-script guard, so sourcing it would run its argument
   parser against the sourcing shell's `$@` and could exit that shell. `detect_layout`,
   `CLASSIC_HEADERS`, and the two fence helpers are side-effect-free and move cleanly.
2. **The verdict space is four-way; `detect_layout` only produces three.** `absent` is checked by
   the caller, before `detect_layout` is reached. The library's public entry point owns both
   checks so neither gated caller re-derives file existence.
3. **The gate fires on exactly two verdicts.** `classic` and `stage` already round-trip; only
   `absent` (create) and `unknown` (repair) are gated.
4. **The real write-mode call under `/roadmap` is in `roadmap-agent.md`, not the skill.** The skill
   only dry-runs. The gate must therefore run pre-dispatch in the skill, so the agent's own
   `--regenerate` lands on an already-`classic` file.
5. **`skill-meta/SKILL.md` Section 2 is the proven template** for collecting a user choice before
   an `Agent` dispatch, for exactly this withholding reason.
6. **`roadmap-update.md`'s "Live Callers" section is already stale** — it claims exactly one live
   `--regenerate` caller, while `roadmap-agent.md` is a second, pre-existing one.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch and `roadmap_flag` is not set, so no roadmap
review/update phases are added.

## Goals & Non-Goals

**Goals**:
- One shared library owning the four-way classification, with exactly one copy of the eight-header
  list in the repository.
- A mechanical, judgment-free skeleton scaffolder that never discards authored prose.
- Both write-mode callers gated, each with the arm its surface supports; neither silent.
- Caller contract, Move 5 allow-list, and regression suite updated in the same pass.

**Non-Goals**:
- Weakening, bypassing, or adding a `--force` path to the generator's Destructive-Overwrite
  Refusal. The preflight sits in front of it; the refusal itself is untouched.
- Any agent hand-authoring roadmap body content. The only sanctioned write is the mechanical
  skeleton.
- Re-doing the `/home/benjamin/.dotfiles/specs/ROADMAP.md` migration.
- Converting the tasks 558 / 562 file-territory overlap into a dependency edge (co-batch ordering
  note only).
- Touching `--prune` (a deprecated alias for `--regenerate`).
- Adding a new `AskUserQuestion` prompt to `/orchestrate`'s conclusion stage.

## Decisions

1. **Library shape.** `scripts/lib/roadmap-preflight-lib.sh` holds `CLASSIC_HEADERS`,
   `body_has_orchestrate_fence`, `roadmap_has_orchestrate_fence`, and `detect_layout` (moved
   verbatim), plus two new public functions: `roadmap_preflight_classify PATH` (prints exactly one
   of `absent|unknown|classic|stage`, always exit 0 — classification never fails) and
   `roadmap_preflight_scaffold PATH` (the mechanical skeleton write).
   `roadmap-integration.sh` sources it back and keeps zero copies of its own.
2. **One file, two uses.** The library carries a `[[ "${BASH_SOURCE[0]}" == "${0}" ]]` run-as-script
   guard exposing `classify PATH` and `scaffold PATH` subcommands, so a Bash-only caller (both
   gated callers are Bash-only) invokes it without sourcing. Rejected alternative: a second
   `scripts/roadmap-preflight.sh` wrapper — it would need its own Move 5 allow-list entry and its
   own copy into every test scratch tree, for no behavioral gain. The guard is what
   `roadmap-integration.sh` itself lacks and is the precise reason sourcing that script is unsafe.
3. **Gate applicability.** Both arms fire only on `absent` or `unknown`. `classic` and `stage`
   proceed straight to `--regenerate`, unchanged, ungated.
4. **Move 5 degrades, never prompts.** Per the description's explicit directive, and because the
   divergence noted above is a posture claim rather than a tool-availability one: adding a third
   `AskUserQuestion` key to the conclusion stage would expand its approval-ledger surface for a
   write that is not time-critical (the next interactive `/roadmap` resolves it). Move 5 instead
   emits a named structured warning in its own Step 5 output, writes `specs/events.jsonl` via
   `events-append.sh` (the mechanism Move 5 already uses for its own non-task-scoped evidence),
   and best-effort loops `issue-record.sh` once per task directory in the invocation's own
   already-resolved task list. `--regenerate` is not called and nothing is auto-written.
5. **New `issue-record.sh --class` value**: `roadmap regenerate blocked, no approval surface`,
   `--severity costly`, `--resolution open`. Re-confirmed against the current 16-class seed enum at
   plan time (research Recommendation 6): still no closer fit, and the Extensibility Rule
   explicitly sanctions a new value on first use.
6. **Scaffold content.** `absent`: the eight classic headers in Section Order order, under a
   `# Roadmap` title and an italic preamble paragraph; `## Gate state` gets `Not yet measured.`,
   `## Next` / `## Open work` get a one-line `(rendered by --regenerate)` placeholder, and the
   remaining authored-verbatim sections get a short honest stub — never an invented mission
   statement or rule. `unknown`: the same skeleton, with the original file's full prior content
   appended verbatim under `## Unfiled observations (none worth a task yet)`, the section
   `roadmap-format.md` itself describes as a deliberately unstructured scratch list.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The extraction breaks every existing roadmap test, because `build_scratch` copies a fixed dependency list into each scratch `.claude/scripts/lib/` and would not copy the new library | H | H | Phase 1 adds the `cp` line and the `_SRC` resolution in the same phase as the extraction, and Phase 1's verification runs the full suite before the phase closes |
| A future bugfix re-inlines `detect_layout` into the generator and the two copies drift | M | M | Phase 1 leaves a one-line ownership comment at the generator's `source` line naming the library as sole owner, mirroring `status-vocabulary.sh`'s framing |
| Scaffolding an `unknown` file appends a large prior body under `## Unfiled observations` | L | M | Accepted deliberately: nothing is lost and the salvage is visibly flagged for human triage, which is strictly safer than any alternative that discards content. Stated here rather than silently accepted |
| Move 5's per-task `issue-record.sh` loop silently does nothing when the task list is empty or unresolved | M | L | The `events-append.sh` write is the durable record regardless; the per-task loop is additive. Phase 5 fixes the ordering: events first, issue-record loop best-effort second |
| Move 5 still has no human in the loop for a blocked roadmap write, so a consumer repo could sit degraded for several cycles | M | M | The degrade is loud at three surfaces (stage output, `events.jsonl`, per-task `issues.jsonl`) and the next interactive `/roadmap` resolves it. Flagged as the accepted residual of Decision 4 |
| `skill-roadmap`'s MUST NOT list forbids the skill touching anything but the two `specs/` files and forbids it invoking `--regenerate` | M | H | Phase 4 amends the list with an explicit preflight carve-out; the scaffold writes `specs/ROADMAP.md` (already in scope) and is not `--regenerate` |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3, 4, 5 | 2 |
| 4 | 6 | 3, 4, 5 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Extract classification into a shared library [COMPLETED]

**Goal**: One copy of `CLASSIC_HEADERS`/`detect_layout` in the repository, owned by a new library,
with `roadmap-integration.sh` sourcing it back and the test suite still green.

**Tasks**:
- [x] Create `agent-system/extensions/core/scripts/lib/roadmap-preflight-lib.sh` with a header
      comment stating it is the single owner of the roadmap layout vocabulary, following
      `scripts/lib/status-vocabulary.sh`'s "one sourced shared library, many consumers" framing. *(completed)*
- [x] Move `CLASSIC_HEADERS`, `body_has_orchestrate_fence`, `roadmap_has_orchestrate_fence`, and
      `detect_layout` into it verbatim, comments included. *(completed)*
- [x] Add `roadmap_preflight_classify PATH`: prints `absent` when the file does not exist,
      otherwise delegates to `detect_layout`; always exits 0. *(completed)*
- [x] In `scripts/roadmap-integration.sh`, delete the four moved definitions and add
      `source "${SCRIPT_DIR}/lib/roadmap-preflight-lib.sh"` immediately after the existing
      `lib/status-vocabulary.sh` source line, with a one-line comment naming the library as the
      sole owner of the layout vocabulary. *(completed)*
- [x] In `scripts/tests/test-roadmap-generation.sh`, add a deploy-tree-first `_SRC` resolution for
      `lib/roadmap-preflight-lib.sh` alongside the existing dependency resolutions, and add the
      matching `cp` into `build_scratch`'s `.claude/scripts/lib/` population. *(completed)*

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: interface

**Tier Justification**: `suite_selection_select` over this phase's touched path set returns the
`__FULL_SWEEP__` sentinel — the new library file maps to no suite of its own — so no suite claim is
made here; the honest in-phase check is the `interface` row's build-plus-enumerated-dependents
read, discharged against the one direct dependent (`roadmap-integration.sh`) by the suite run named
in this phase's verification criteria below.

**Scope Hypothesis**: exactly four definitions move (`CLASSIC_HEADERS`,
`body_has_orchestrate_fence`, `roadmap_has_orchestrate_fence`, `detect_layout`) and
`roadmap-integration.sh` retains zero copies. Confirm by `grep -n 'CLASSIC_HEADERS\|detect_layout\|_orchestrate_fence'`
over the generator after the edit: every hit must be a call or a comment, never a definition.

**Files to modify**:
- `agent-system/extensions/core/scripts/lib/roadmap-preflight-lib.sh` - new library; moved
  classification vocabulary plus `roadmap_preflight_classify`
- `agent-system/extensions/core/scripts/roadmap-integration.sh` - source the library, delete the
  four moved definitions, add the ownership comment
- `agent-system/extensions/core/scripts/tests/test-roadmap-generation.sh` - resolve and copy the
  new library into each scratch tree

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-roadmap-generation.sh,test-migrate-roadmap-next-to-state.sh,test-skill-base-lifecycle.sh,test-sweep-invalidated-claims.sh`
  passes with the same case count as before the edit.
- `bash -n` clean on both edited shell files and the new library.
- `roadmap_preflight_classify` returns `absent`/`classic`/`stage`/`unknown` correctly against
  ad hoc fixtures (formalized as suite cases in Phase 3).

---

### Phase 2: Mechanical skeleton scaffolder and run-as-script CLI [NOT STARTED]

**Goal**: `roadmap_preflight_scaffold PATH` writes the classic eight-header skeleton without
discarding authored prose, and the library is invocable as a CLI by a Bash-only caller.

**Tasks**:
- [ ] Add `roadmap_preflight_scaffold PATH` to the library: emits `# Roadmap`, an italic preamble
      paragraph, and the eight `## ` headers in `roadmap-format.md`'s Section Order order, with the
      placeholder bodies fixed by Decision 6.
- [ ] When the target file exists (the `unknown` repair case), read its full prior content first and
      append it verbatim under `## Unfiled observations (none worth a task yet)`, under a short
      literal marker line introducing it as salvaged content. Never discard, never reorder, never
      reinterpret it.
- [ ] Make the scaffolder refuse (non-zero, named stderr reason, no write) when
      `roadmap_preflight_classify` on the same path returns `classic` or `stage` — a scaffold is
      only ever correct for the two gated verdicts, and this is the structural guard against it
      being reached for an already-round-tripping file.
- [ ] Add a `[[ "${BASH_SOURCE[0]}" == "${0}" ]]` run-as-script guard exposing
      `classify PATH` and `scaffold PATH` subcommands, with a usage line and a non-zero exit on an
      unknown subcommand. Keep argument parsing strictly inside the guard so sourcing stays safe.
- [ ] Write a one-paragraph header note stating that this file writes only the mechanical skeleton
      and never roadmap body content, pointing at `roadmap-format.md`'s Destructive-Overwrite
      Refusal as the untouched, in-front-of property.

**Timing**: 1.25 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: the edit is confined to the single new library file, whose
`suite_selection_select` result is the `__FULL_SWEEP__` sentinel (no suite maps to it), so the
honest in-phase check is the `local` row's lint-of-that-one-module — `bash -n` plus a
`shellcheck` pass plus a manual scaffold-into-`mktemp -d` exercise of all four verdicts; the
behavioral coverage is formalized in Phase 3.

**Scope Hypothesis**: this phase adds exactly one public function plus the guard block and
touches no file outside the library. Confirm with `git diff --stat` naming only
`roadmap-preflight-lib.sh`.

**Files to modify**:
- `agent-system/extensions/core/scripts/lib/roadmap-preflight-lib.sh` - add the scaffolder
  function, the classic/stage refusal guard, and the run-as-script CLI guard

**Verification**:
- `bash -n` and `shellcheck` clean on the library.
- Against a `mktemp -d` scratch: `scaffold` on an absent path produces a file that
  `classify` then reports as `classic`; `scaffold` on an `unknown`-vocabulary file produces a
  `classic` file whose output contains every byte of the original content; `scaffold` on a
  `classic` or `stage` file refuses non-zero with no write.
- Sourcing the library from a shell with arbitrary `$@` set neither parses arguments nor exits.

---

### Phase 3: Regression coverage in the roadmap suite [NOT STARTED]

**Goal**: `test-roadmap-generation.sh` covers all four classify verdicts, both scaffold cases, the
classic/stage refusal, and scaffold-then-regenerate idempotence.

**Tasks**:
- [ ] Add a preflight-library section to `scripts/tests/test-roadmap-generation.sh` using the
      suite's existing `build_scratch` / fixture-writer helpers; reuse
      `write_stage_vocabulary_fixture` and `write_unknown_vocabulary_fixture` rather than adding
      parallel fixtures.
- [ ] Case: `classify` returns `absent` for a scratch tree with no `specs/ROADMAP.md`.
- [ ] Case: `classify` returns `unknown`, `classic`, and `stage` for the three existing
      vocabulary fixtures.
- [ ] Case: `scaffold` on an absent path yields a file `classify` reports as `classic`, carrying
      all eight headers in Section Order order.
- [ ] Case: `scaffold` on the unknown-vocabulary fixture preserves the original content verbatim
      (assert every original non-blank line is still present) and yields `classic`.
- [ ] Case: `scaffold` refuses with non-zero exit and no content change on a `classic` fixture and
      on a `stage` fixture.
- [ ] Case: scaffold-then-regenerate idempotence — `scaffold`, then `--regenerate`, then a second
      `--regenerate --dry-run` reports `no content change`.
- [ ] Confirm the suite's live-tree isolation guard still passes (every new case drives the scratch
      tree via `--roadmap`/`--state`, never the real `specs/` files).

**Timing**: 1.25 hours

**Depends on**: 2

**Verification Tier**: local

**Tier Justification**: the edit is confined to one test file whose own
`suite_selection_select` output is `test-roadmap-generation.sh`, `test-migrate-roadmap-next-to-state.sh`,
and `test-sweep-invalidated-claims.sh`, discharged by
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-roadmap-generation.sh,test-migrate-roadmap-next-to-state.sh,test-sweep-invalidated-claims.sh`.

**Scope Hypothesis**: seven new cases land in one existing suite file and no new test file is
created. Confirm by the suite's own `Results: N passed` line rising by exactly the number of new
assertions added, with zero failures.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-roadmap-generation.sh` - preflight-library case
  section covering the four verdicts, both scaffold cases, the refusal, and idempotence

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-roadmap-generation.sh,test-migrate-roadmap-next-to-state.sh,test-sweep-invalidated-claims.sh`
  exits 0 with every new case reported PASS.
- The suite's trailing live-tree isolation case still passes.

---

### Phase 4: Interactive arm in skill-roadmap [NOT STARTED]

**Goal**: `/roadmap` classifies `specs/ROADMAP.md` and, on `absent`/`unknown`, asks the user for
approval and scaffolds before `roadmap-agent` is ever dispatched.

**Tasks**:
- [ ] Add `AskUserQuestion` to `skills/skill-roadmap/SKILL.md`'s `allowed-tools:` frontmatter
      (`Bash` is already present and is the only other tool the gate needs — the scaffold write
      goes through the library's CLI, never the `Write` tool).
- [ ] Extend Stage 1 with a classify step:
      `bash .claude/scripts/lib/roadmap-preflight-lib.sh classify specs/ROADMAP.md`.
- [ ] On `classic`/`stage`: proceed to Stage 2 unchanged, with no question asked.
- [ ] On `absent`/`unknown`: ask a single `AskUserQuestion` for approval to create (absent) or
      repair (unknown) the file, naming the verdict, what the skeleton write does, and — for
      `unknown` — that the existing content is preserved verbatim under
      `## Unfiled observations (none worth a task yet)`. Model the block's shape on
      `skills/skill-meta/SKILL.md` Section 2, and state in the stage prose why the question lives
      here and not in `roadmap-agent` (the measured `AskUserQuestion` withholding from every
      dispatched subagent).
- [ ] On approval: run
      `bash .claude/scripts/lib/roadmap-preflight-lib.sh scaffold specs/ROADMAP.md` in this
      skill's own execution, then proceed to Stage 2 with the file already `classic`.
- [ ] On decline: do not dispatch `roadmap-agent`, do not write anything, and return a named
      summary stating that roadmap rendering is blocked pending an approved scaffold.
- [ ] Pass only the resolved outcome into the Stage 2 dispatch prompt — never a flag telling the
      agent to ask anything itself.
- [ ] Update Stage 3's second `WARNING:` text to name the Stage 1 preflight as the first thing to
      re-check on a recurrence; leave the dry-run check's mechanism unchanged.
- [ ] Amend the MUST NOT list: carve out the Stage 1 preflight scaffold explicitly from item 3
      (which forbids the skill invoking `--regenerate` — the scaffold is not `--regenerate`) and
      confirm item 4 still holds (the scaffold writes `specs/ROADMAP.md`, already in scope).

**Timing**: 1 hour

**Depends on**: 2

**Verification Tier**: full

**Tier Justification**: a skill definition is global config consumed by the orchestration dispatch
machinery, and `suite_selection_select` maps this one path to a 28-suite set spanning routing,
dispatch-building, handoff, deploy-propagation, and lint surfaces — no narrowing below the whole
gate set covers that blast radius, so a cheaper tier would have to fabricate one.

**Scope Hypothesis**: exactly one new `AskUserQuestion` block is added, in Stage 1, and no
question is added to `agents/roadmap-agent.md`. Confirm with
`grep -rn 'AskUserQuestion' agent-system/extensions/core/agents/roadmap-agent.md` returning no
hits, and the same grep over the skill returning the frontmatter line plus the single Stage 1
block.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-roadmap/SKILL.md` - `allowed-tools` frontmatter,
  Stage 1 classify + approval + scaffold gate, Stage 3 warning text, MUST NOT carve-out

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` (the complete gate set it aggregates) exits 0.
- `agents/roadmap-agent.md` is unmodified and contains no `AskUserQuestion` reference.
- Stage 1 prose names the two gated verdicts and the two ungated ones explicitly.

---

### Phase 5: Non-interactive arm at the conclusion stage [NOT STARTED]

**Goal**: Move 5 classifies before `--regenerate`, and on `absent`/`unknown` degrades loudly at
three surfaces instead of calling the generator or writing anything.

**Tasks**:
- [ ] In `context/contracts/conclusion-stage.md`'s Step 5, insert a classify step before the
      existing `--regenerate` invocation:
      `bash .claude/scripts/lib/roadmap-preflight-lib.sh classify specs/ROADMAP.md`.
- [ ] On `classic`/`stage`: Step 5 proceeds exactly as written today — `--regenerate`, the scoped
      `specs/ROADMAP.md` commit, then the advisory batch-proposal lint. Nothing changes.
- [ ] On `absent`/`unknown`: emit a named structured warning in Step 5's own surfaced output
      (naming the verdict, the path, and that the next interactive `/roadmap` resolves it); skip
      `--regenerate` and the commit entirely; leave `specs/ROADMAP.md` untouched.
- [ ] Record the degrade durably via `events-append.sh` FIRST (the stage's existing non-task-scoped
      evidence channel), then best-effort loop
      `bash .claude/scripts/issue-record.sh --task-dir <dir> --kind issue --class "roadmap regenerate blocked, no approval surface" --severity costly --phase conclusion --resolution open --what-happened "..."`
      once per task directory in the invocation's already-resolved task list. State explicitly that
      the events write is the durable record and the loop is additive, so an empty or unresolved
      task list degrades the evidence rather than losing it.
- [ ] State explicitly in the contract prose that this call site NEVER scaffolds and NEVER
      auto-writes: the scaffold is an approved-write-only action and Move 5 has no approver for it.
- [ ] In `context/standards/postflight-tool-restrictions.md`'s Move 5 Allowed Tool Surface `Bash`
      row, add `lib/roadmap-preflight-lib.sh classify` and `issue-record.sh` to the enumerated
      allow-list. Add a Prohibited bullet: no `lib/roadmap-preflight-lib.sh scaffold` at this
      stage (classify-only), since the scaffold needs an approval this stage cannot obtain.

**Timing**: 0.75 hours

**Depends on**: 2

**Verification Tier**: local

**Tier Justification**: `suite_selection_select` over this phase's touched path set returns the
`__FULL_SWEEP__` sentinel — no suite covers these prose contracts — so no suite claim is made here;
per the sentinel's source-store-markdown sub-case the covering check is the gate subset
`bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
(the repository root, which holds both a deployed `.claude/` tree and `agent-system/extensions`),
alongside the `local` row's diff read-through.

**Scope Hypothesis**: exactly two context files change and no script changes in this phase. The
`index-entries.json` `line_count` rows for both edited context files move as a consequence and are
declared below; that check (`check-extension-docs.sh` Rule R) is advisory, not commit-blocking, in
this repository, so its reconciliation lands in Phase 6.

**Files to modify**:
- `agent-system/extensions/core/context/contracts/conclusion-stage.md` - Step 5 classify-first
  branch, loud degrade, events-then-issue-record evidence ordering, never-scaffold statement
- `agent-system/extensions/core/context/standards/postflight-tool-restrictions.md` - Move 5 Bash
  allow-list entries and the scaffold prohibition bullet
- `agent-system/extensions/core/index-entries.json` - derived line-count rows for both edited
  context files (coupled generated surface; reconciled in Phase 6)

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-conclusion-aggregate.sh`
  exits 0.
- `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
  reports no new doc-lint or task-reference findings.
- Step 5's `classic`/`stage` path is byte-identical in behavior to today's (the existing
  `--regenerate` + commit + lint sequence is unmodified).

---

### Phase 6: Caller contract, index reconciliation, and full gate [NOT STARTED]

**Goal**: `roadmap-update.md` documents the preflight as every write-mode caller's obligation and
its stale caller count is corrected; the derived `line_count` rows are reconciled; the complete
gate set runs green.

**Tasks**:
- [ ] In `context/patterns/roadmap-update.md`, document the preflight as part of every write-mode
      caller's obligation: classify before any write-mode invocation, gate on `absent`/`unknown`,
      and use the arm the caller's surface supports (interactive approval where a user-facing
      surface exists, loud degrade plus durable evidence where it does not).
- [ ] Correct the "Live Callers" section's claim that `--regenerate` has exactly one live caller:
      `agents/roadmap-agent.md`'s Write Contract is a second, pre-existing one, independent of
      anything this task adds. If that section has changed since authoring time and the claim is
      already corrected, record that and make no edit to it.
- [ ] State the hard constraint in this contract: the preflight sits IN FRONT of the generator and
      never weakens, bypasses, or adds a `--force` path to the Destructive-Overwrite Refusal; the
      mechanical skeleton is the only sanctioned write.
- [ ] Reconcile the derived line counts:
      `bash .claude/scripts/generate-context-line-counts.sh --write`, then confirm the
      `index-entries.json` rows for the three edited context files match `wc -l`.
- [ ] Run the complete gate set and record the result in the phase's own notes.

**Timing**: 1.25 hours

**Depends on**: 3, 4, 5

**Verification Tier**: full

**Scope Hypothesis**: exactly three `index-entries.json` `line_count` rows move
(`patterns/roadmap-update.md`, `contracts/conclusion-stage.md`,
`standards/postflight-tool-restrictions.md`). Confirm with
`bash .claude/scripts/generate-context-line-counts.sh --check` reporting zero remaining drift
after the `--write` pass, and `git diff --stat` on `index-entries.json` showing only those rows.

**Files to modify**:
- `agent-system/extensions/core/context/patterns/roadmap-update.md` - preflight obligation for
  every write-mode caller, Live Callers correction, hard-constraint statement
- `agent-system/extensions/core/index-entries.json` - regenerated `line_count` rows for all three
  edited context files

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` (the complete gate set it aggregates) exits 0.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` exits 0 with zero failing suites.
- `bash .claude/scripts/generate-context-line-counts.sh --check` reports no drift.
- `grep -rn 'CLASSIC_HEADERS' agent-system/extensions/core/` returns exactly one definition site
  (the library) — the dispatch's "do NOT duplicate the eight-header list in two places" constraint,
  checked end-to-end.
- `roadmap-format.md`'s Destructive-Overwrite Refusal section is unmodified, and no `--force` path
  exists anywhere in `roadmap-integration.sh`.

---

## Testing & Validation

- [ ] All four classify verdicts return correctly against suite fixtures (Phase 3).
- [ ] Scaffold-then-regenerate is idempotent: a second `--regenerate --dry-run` reports
      `no content change` (Phase 3).
- [ ] Scaffolding an `unknown` file preserves every original non-blank line (Phase 3).
- [ ] Scaffold refuses on `classic` and `stage` with no write (Phase 3).
- [ ] The live-tree isolation guard still passes: the real `specs/ROADMAP.md` and
      `specs/state.json` are byte-identical after the suite runs (Phase 3).
- [ ] `agents/roadmap-agent.md` contains no `AskUserQuestion` reference (Phase 4).
- [ ] Move 5's `classic`/`stage` path is behaviorally unchanged (Phase 5).
- [ ] `verify-deploy.sh` and the full `run-all.sh` battery exit 0 (Phase 6).
- [ ] Exactly one `CLASSIC_HEADERS` definition exists in the repository (Phase 6).

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/lib/roadmap-preflight-lib.sh` (new)
- `agent-system/extensions/core/scripts/roadmap-integration.sh` (sources the library; zero local
  copies of the classification vocabulary)
- `agent-system/extensions/core/skills/skill-roadmap/SKILL.md` (interactive arm)
- `agent-system/extensions/core/context/contracts/conclusion-stage.md` (non-interactive arm)
- `agent-system/extensions/core/context/standards/postflight-tool-restrictions.md` (Move 5
  allow-list)
- `agent-system/extensions/core/context/patterns/roadmap-update.md` (caller contract)
- `agent-system/extensions/core/scripts/tests/test-roadmap-generation.sh` (regression coverage)
- `agent-system/extensions/core/index-entries.json` (reconciled `line_count` rows)
- `specs/625_roadmap_preflight_approval_gate/summaries/01_roadmap-preflight-gate-summary.md`

## Rollback/Contingency

Every phase is a separately committed, independently revertable unit, and no phase edits any
repository's `.claude/` deploy tree (regenerated from the source store, so a revert of the source
store is sufficient). The highest-risk single step is Phase 1's extraction: if the suite goes red
and cannot be fixed forward, revert that phase's commit — `roadmap-integration.sh` returns to
self-contained and nothing else in the plan has landed yet.

If an intentional rollback of uncommitted work becomes necessary at any phase, follow
`context/contracts/recovery.md`'s rollback rung for the snapshot-then-rollback invocation shape
(including its out-of-scope override flag); never discard uncommitted changes without that
snapshot first.

No phase ever modifies the generator's refusal path, so the worst case for a partially-landed plan
is the status quo ante: the generator still refuses loudly on `unknown` and still no-ops on
`absent`, with no caller escalation — exactly today's behavior, never a weakened gate.
