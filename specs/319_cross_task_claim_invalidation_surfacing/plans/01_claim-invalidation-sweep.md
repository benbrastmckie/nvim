# Implementation Plan: Task #319

- **Task**: 319 - Surface cross-task claim invalidation when a research dispatch refutes a filed premise
- **Status**: [IMPLEMENTING]
- **Effort**: 6 hours
- **Dependencies**: 285 (satisfied -- the `.decisions.json` writer landed; research confirmed it and ruled that route out on shape grounds)
- **Research Inputs**: `specs/319_cross_task_claim_invalidation_surfacing/reports/01_claim-invalidation-surfacing.md`
- **Artifacts**: plans/01_claim-invalidation-sweep.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md,
  source-store-deploy-boundary.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

A machine-checked refutation produced by one research dispatch must have its blast radius across
the open backlog surfaced for human triage. This plan delivers the three pieces research ruled on:
a structured, producer-owned trigger field (`claim_invalidations`) on `.return-meta.json`; the
research-agent contract instruction that populates it; and a read-only matcher script
(`sweep-invalidated-claims.sh`) that takes declaration names and returns every non-terminal sibling
task whose own `title`/`description` names one of them, plus its regression fixture replaying the
motivating incident. Every edit lands under `agent-system/extensions/core/`, never `.claude/**`,
per `source-store-deploy-boundary.md`. Definition of done: the fixture replays the incident and
names all five affected sibling analogs with the fixture state file byte-identical afterwards, the
field is specified where every agent already loads it from, and the full gate set is green.

The call site that invokes the matcher is deliberately **not** wired here -- see Non-Goals and
Decision 5 for why, and `## Artifacts & Outputs` for the follow-up this leaves owed.

### Research Integration

Carried from `reports/01_claim-invalidation-surfacing.md`:

- **The trigger surface is settled and the two alternatives are eliminated on shape, not taste.**
  `decisions_made` lives only on `.orchestrator-handoff.json`, which `handoff-schema.md`'s own
  "Handoff Writers" section says research agents "never write... in any mode" -- physically
  unreachable from the dispatch that produces a refutation. `.decisions.json` is scoped
  exclusively to answers the user gave to an `AskUserQuestion` relay (required fields `question`,
  `answer`, `cycle`, `timestamp`), written only by the loop's own branch move, never by a
  dispatched agent; a machine-checked refutation is not a question anyone asked the user. The
  report-body-convention candidate is the status quo that failed. A new optional top-level field
  on `.return-meta.json` is the only reachable, correctly-shaped surface.
- **The matching rule is literal and deliberately false-negative-biased**: word-boundary,
  case-sensitive matching of declaration names against the `title`/`description` of every
  non-terminal task other than the producing one. No natural-language equivalence.
- **Posture is advisory-only.** No description, `file_scope`, or status is ever written.
- **The script contract**: stdin-free, read-only, JSON array on stdout, exit 0 unconditionally so
  it can never fail a dispatch.
- **Postflight Boundary clears this as a postflight-callable operation.** A literal substring match
  over `state.json` is the same mechanical class as the `proposed_file_scope` merge and the
  research-report gate that postflight already performs; it is not the LLM "analyze or grep source"
  the boundary prohibits.
- **The positive direction needs no new code at all, and is NOT absorbed as build scope here.**
  `scripts/memory-harvest.sh` already reads a task's `memory_candidates` from `state.json`,
  gates on `confidence >= 0.7`, dedupes against `memory-index.json`, and writes the vault entry
  that `memory-retrieve.sh` already injects at every dispatch preflight -- but its own header says
  it "is presently uncalled (no caller in the skill/command pipeline)", because `skill-todo`'s
  `HarvestMemories` stage duplicates the logic inline and scopes it to completed tasks in an
  archival batch. The fix is one new call site at the same deferred wiring point, with zero edits
  to that script or to `skill-todo` -- so the amendment's "ADDED SCOPE TO SPAWN, NOT TO ABSORB"
  boundary is not crossed. The escape hatch is not triggered.

**Three corrections to the research report, found by direct verification at plan-authoring time:**

1. **`proposed_file_scope` is not referenced from any agent contract.** Recommendation 1 says the
   agent-contract update should mirror "how `proposed_file_scope` is already referenced from
   `general-research-agent.md`'s own Stage 5/6/7 instructions". `grep -rln proposed_file_scope`
   over `agents/` and `skills/` across every extension returns **zero** hits -- the field is
   documented only in `context/formats/return-metadata-file.md` and consumed only by
   `update-task-status.sh`. Phase 2 therefore authors a genuinely new instruction rather than
   copying an existing pattern, and Decision 3 states why the field still gets an explicit agent
   instruction instead of relying on the format doc alone.
2. **A new script requires a `manifest.json` declaration, which the report does not mention.**
   `check-extension-docs.sh`'s Rule Q (`check_undeclared_scripts`) fails on any
   `scripts/**/*.sh` absent from its extension's `provides.scripts`, and `run-all.sh` discovers
   test suites by glob so the omission produces no authoring-time signal. Phase 5 runs
   `sync-manifest-scripts.sh --write`, which derives the array from disk.
3. **Editing `return-metadata-file.md` has a measurable context-budget consequence.**
   `index-entries.json` records its `line_count` (835 today, matching `wc -l`), Rule R fails on a
   stale count, and `validate-context-budgets.sh` multiplies that count by 8 for each of the eight
   agents hooked to the file. That gate is *already* failing repo-wide for ten agents against
   stale `EXCEPTIONS` caps and is **not** one of `verify-deploy.sh`'s 21 gates -- so it is a
   pre-existing red this task neither causes nor repairs. Phase 1 still keeps its addition tight
   and Phase 5 re-derives the line count rather than hand-editing it. See Risks.

### Prior Plan Reference

No prior plan. This is artifact round 01 for this task.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch's delegation context and `roadmap_flag` is not
set; no ROADMAP.md consultation or roadmap phases apply.

## Goals & Non-Goals

**Goals**:

- Specify `claim_invalidations` as an optional, producer-owned, top-level `.return-meta.json`
  field in the one document every agent contract already loads for this schema.
- Instruct the research agent to populate it when, and only when, a dispatch machine-checks a
  refutation or closes a question by supersession.
- Deliver `sweep-invalidated-claims.sh`: read-only, JSON-on-stdout, exit-0-always, taking
  declaration names (directly, or read out of a `.return-meta.json`) and returning every
  non-terminal sibling task whose own text names one.
- Deliver a regression fixture that replays the motivating incident end-to-end and asserts both
  halves of the acceptance criterion: all five affected analogs named, and the state file
  byte-identical afterwards.
- State the false-negative posture in the shipped artifacts themselves, not only in this plan.

**Non-Goals**:

- Do **not** wire any call site. `orchestrate-cycle-postflight.sh` is the integration point and
  sits in the declared `file_scope` of eight open tasks; wiring it here would add eight serializing
  edges for one call line. Deferred by the task's own stated principle (Decision 5).
- Do **not** attempt natural-language or semantic claim equivalence.
- Do **not** mutate any task's `description`, `file_scope`, or `status`, from the sweep or from
  anything this task ships. The matcher opens `state.json` read-only.
- Do **not** edit `scripts/memory-harvest.sh` or `skill-todo`'s `HarvestMemories` stage -- both
  are owned by the `/todo` consolidation work and stay byte-for-byte unchanged.
- Do **not** repair `validate-context-budgets.sh`'s stale `EXCEPTIONS` caps. Pre-existing, ten
  agents wide, unrelated to this change, and not a `verify-deploy.sh` gate.
- Do **not** hand-edit `.claude/**`.

## Decisions

Five design choices this plan owns, either because research left them to the plan phase or because
plan-time verification closed an option.

**Decision 1 -- word boundaries are explicit lookarounds inside one `jq` pass, not `grep -w` or
`\b`.** Matching happens entirely inside a single `jq` invocation over `state.json`, with each
declaration name regex-escaped by `gsub` and wrapped in
`(?<![A-Za-z0-9_])...(?![A-Za-z0-9_])`. Both mechanics were verified directly at plan-authoring
time against the installed `jq` 1.8.2: Oniguruma lookbehind/lookahead works, and named-capture
`gsub("(?<c>[.*+?^${}()|\\[\\]\\\\])"; "\\" + .c)` correctly escapes a dotted name such as
`Foo.bar`. `\b` is rejected because a declaration name ending in a non-word character makes its
behaviour at that edge surprising; the lookarounds say exactly what is meant. A shell loop piping
descriptions to `grep -wF` is rejected because descriptions are multi-line JSON strings and the
loop would reintroduce exactly the stream-vs-data channel confusion `lint-json-channel-discipline.sh`
exists to catch.

**Decision 2 -- the producing task is excluded with `== | not`, never `!=`.** Per CLAUDE.md's "jq
Command Safety" section, `!=` is escaped as `\!=` by a known Claude Code defect and produces a
parse error. The self-exclusion predicate is `select(.project_number == $self | not)`. Likewise
terminal-status exclusion is written as a membership test over the terminal set, not a chain of
inequalities.

**Decision 3 -- the field gets an explicit agent instruction, not format-doc documentation
alone.** `proposed_file_scope` is documented only in the format doc and instructed nowhere (see
correction 1), and that is precisely why nothing in this repository has ever observed a research
dispatch populate it. A trigger field whose entire value depends on an agent choosing to emit it
cannot inherit that posture. The instruction lands in `general-research-agent.md`'s Stage 7 (where
the metadata file is written) plus one MUST-DO line, and is deliberately conditional -- "only when
this dispatch machine-checked a refutation or closed a question by supersession" -- so it does not
become a routine field agents feel obliged to fill. Extension research agents are left to inherit
the field through the always-loaded format doc; widening to each of them is follow-up scope, not
this task's.

**Decision 4 -- output carries `title` alongside `{task_number, matched_name}`.** Research
Decision 4 specifies the pair; this plan adds the matched task's `title` because the output's
entire purpose is to reach a human, and a bare number forces a `state.json` lookup per row before
triage can even begin. Nothing consumes the shape yet (no call site exists), so widening it later
would be a breaking change to a live contract while widening it now is free.

**Decision 5 -- the matcher ships deliberately uncalled, and says so in its own header.** This is
the exact dormant-script trap research identified in `memory-harvest.sh`: a complete, tested
mechanism nobody invokes. It is accepted here because the alternative -- declaring
`orchestrate-cycle-postflight.sh` in this task's `file_scope` -- adds eight serializing edges for
one call line, which the task description already ruled against for this very reason. The
mitigation is explicitness rather than hope: the script header states that it is uncalled, names
the single integration point, and names **both** calls that integration owes (this matcher keyed
on `claim_invalidations`, and `memory-harvest.sh <task_number>` keyed on non-empty
`memory_candidates`) so the positive direction cannot be lost with it.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|-------------|
| The matcher ships and is never called, repeating the `memory-harvest.sh` dormancy this task exists to fix | H | M | Decision 5: the header states the dormancy, names the one integration point, and names both owed calls. `## Artifacts & Outputs` records the follow-up wiring task as an explicit deliverable of this task's wrap-up, not an implicit hope |
| A declaration name coincides with a common word and produces a false positive | L | M | Word-boundary (not substring) matching plus advisory-only posture: a false positive costs a human one line of review and can never mutate anything |
| Over-promising on recall -- a refutation referenced only by paraphrase is missed | M | H | Accepted and stated in the shipped artifacts, not just here: both the field spec and the script header record the false-negative posture explicitly |
| Adding to `return-metadata-file.md` pushes the three `EXCEPTIONS`-capped implementation agents past their recorded caps | L | M | `validate-context-budgets.sh` is not a `verify-deploy.sh` gate and is already failing for ten agents against stale caps (measured `general-implementation-agent` 41,232 vs. recorded cap 17,188). Phase 1 keeps the addition to one field section; Phase 5 re-derives `line_count` mechanically so Rule R stays green |
| A new script trips Rule Q (undeclared in `provides.scripts`) or Gate 13 orphan detection | M | H | Phase 5 runs `sync-manifest-scripts.sh --write` (derives the array from disk) and `deploy-headless.sh` before the full gate set; Phase 5's verification re-runs `check-extension-docs.sh` |
| A diagnostic `echo` leaks into the JSON stdout contract | M | M | The header declares the JSON-on-stdout contract and every diagnostic is `>&2`; `lint-json-channel-discipline.sh`'s EMIT check covers exactly this shape and is run in Phase 3's own verification, not deferred to the final gate |
| Source-store edits appear to have no effect because `.claude/` is stale | M | M | Phase 5 runs `deploy-headless.sh` before the gate set; no phase hand-edits `.claude/**` |
| A concurrent sibling dispatch edits a shared file | M | L | Declared scopes are disjoint: the other scoped sibling touches `skill-orchestrate/SKILL.md`, three `orchestrate-*.sh` scripts, and three implementation/reviser agent files -- none of which this task touches. The unscoped sibling may touch anything, so every phase re-reads its target immediately before editing, stages per-file, and never runs `git-snapshot.sh` in reverting mode |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 3 | -- |
| 2 | 2, 4 | 1 (for 2); 3 (for 4) |
| 3 | 5 | 2, 4 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Specify `claim_invalidations` on the return-metadata contract [COMPLETED]

**Goal**: Add the trigger field's normative specification to the one document every agent contract
already loads for this schema, following the established optional-top-level-field pattern.

**Tasks**:

- [x] Re-read `agent-system/extensions/core/context/formats/return-metadata-file.md` immediately
      before editing (concurrent-sibling discipline). *(completed)*
- [x] Add a `### claim_invalidations (optional)` section in `## Field Specifications`, placed
      immediately after `### research_questions (optional)` and before
      `### user_decision (optional)`, matching the prose shape those two sections already use
      (**Type** / **Include if** / producer / consumer / ownership paragraphs). *(completed)*
- [x] Specify the type: optional array of objects at the **top level**, a sibling of
      `proposed_file_scope` and `memory_candidates`, never nested under `completion_data`. *(completed)*
- [x] Specify each entry's four keys: `declaration_names` (`string[]`, the sharp grep-able keys),
      `kind` (`"refutation"` or `"supersession"`), `claim` (one sentence stating what was
      falsified or closed), `evidence_path` (repo-relative path to the probe or artifact
      substantiating it; the key name deliberately matches `issue-log.md`'s field of the same
      name). *(completed)*
- [x] Specify **Include if** narrowly: only when this dispatch machine-checked a refutation or
      closed a question by supersession. Absent in every other case -- state that it is not a
      routine field, in the same words `user_decision`'s section uses. *(completed)*
- [x] State the false-negative posture in the section itself: the field's consumer matches
      declaration names literally and will miss a refutation referenced only by paraphrase, so an
      entry whose `declaration_names` array is empty surfaces nothing. *(completed)*
- [x] Name the consumer as `scripts/sweep-invalidated-claims.sh` and state plainly that **no call
      site invokes it yet**, with the integration point named (Decision 5) -- so a reader of the
      spec cannot mistake the field for a live, already-acted-on signal. *(completed)*
- [x] Add `claim_invalidations` to the producer-owned enumeration in the
      `### Multiple Sequential Writers` section's final sentence, alongside `modified_files`,
      `completion_data`, `memory_candidates`, `proposed_file_scope`, and `artifacts`. *(completed)*
- [x] Confirm no validator change is needed: `validate-return-meta.sh` has no closed-schema
      unknown-field rejection (re-derive with a grep for a known-fields list rather than trusting
      the research report's claim). *(completed)*

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: `return-metadata-file.md` is hypothesized to be 835 lines before this edit
(carried from `index-entries.json`'s recorded `line_count`, re-derived with `wc -l` at
plan-authoring time -- the two agreed) and the addition is hypothesized to stay under 60 added
lines, which is the slack the `EXCEPTIONS` headroom allows at 8 tokens per line. Confirm at
implementation time with `wc -l` before and after.

**Tier Justification**: The edit is confined to one markdown context file with no executable
surface, for which `suite_selection_select` returns `__FULL_SWEEP__` (no suite covers it), so the
honest covering check is `bash .claude/scripts/verify-deploy.sh --only-gate 3,4` (doc-lint and
task-reference lint) plus the `local` row's own diff read-through.

**Files to modify**:

- `agent-system/extensions/core/context/formats/return-metadata-file.md` - add the
  `### claim_invalidations (optional)` field section; extend the `Multiple Sequential Writers`
  producer-owned enumeration

**Verification**:

- `bash .claude/scripts/verify-deploy.sh --only-gate 3,4` is green (doc-lint, task-reference lint).
- The new section's heading matches the `### <field> (optional)` shape the sibling sections use.
- `grep -n "claim_invalidations" agent-system/extensions/core/context/formats/return-metadata-file.md`
  shows the field in both its own section and the `Multiple Sequential Writers` enumeration.
- No task number appears in the added text (`rules/no-task-references-in-deliverables.md`).

---

### Phase 2: Research-agent producer instruction [COMPLETED]

**Goal**: Make the field actually get emitted, by instructing the one agent that produces
refutations -- without turning it into a routine field.

**Tasks**:

- [x] Re-read `agent-system/extensions/core/agents/general-research-agent.md` immediately before
      editing. *(completed)*
- [x] Extend `### Stage 7: Write Metadata File` with a short conditional paragraph: when this
      dispatch machine-checked a refutation or closed a question by supersession, emit
      `claim_invalidations` as a top-level array, with the four keys named in Phase 1, citing
      `return-metadata-file.md`'s new section rather than restating the full schema. *(completed)*
- [x] State the trigger bar explicitly in that paragraph: a *machine-checked* refutation or an
      *explicit* supersession, never a hunch, a suspicion, or a merely-unconfirmed finding -- the
      field's whole value is that it is sharper than prose. *(completed)*
- [x] Add one `MUST DO` list entry pointing at the Stage 7 paragraph, so the obligation survives
      a reader who skims only the Critical Requirements block. *(completed)*
- [x] Do **not** add a new Stage, a new context reference, or any instruction to the implement or
      plan agents -- the field is research-only. *(completed)*
- [x] Re-check the file's own length against the agent-contract lint
      (`scripts/lint/lint-agent-contracts.sh`) rather than assuming a prose addition is free. *(completed)*

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: the edit is hypothesized to touch exactly one agent file -- no extension
research agent is widened (Decision 3). Confirm at implementation time with
`grep -rln claim_invalidations agent-system/extensions/*/agents/`, which must list only
`core/agents/general-research-agent.md`.

**Tier Justification**: The edit is confined to one agent-contract markdown file with no
executable surface (`suite_selection_select` returns `__FULL_SWEEP__`), so the covering checks are
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-lint-agent-contracts.sh`
plus `bash .claude/scripts/verify-deploy.sh --only-gate 3,4`.

**Files to modify**:

- `agent-system/extensions/core/agents/general-research-agent.md` - add the conditional
  `claim_invalidations` emission paragraph to Stage 7 and one matching `MUST DO` entry

**Verification**:

- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-lint-agent-contracts.sh`
  is green.
- `bash .claude/scripts/verify-deploy.sh --only-gate 3,4` is green.
- `grep -rln claim_invalidations agent-system/extensions/*/agents/` lists exactly one file.
- The added text names no task number and cites `return-metadata-file.md` by filename.

---

### Phase 3: `sweep-invalidated-claims.sh` [COMPLETED]

**Goal**: The matcher itself -- read-only, JSON on stdout, exit 0 unconditionally, CLI-testable
without any orchestrator context.

**Tasks**:

- [x] Write `agent-system/extensions/core/scripts/sweep-invalidated-claims.sh` with a header that
      declares, in this order: the JSON-on-stdout output contract (so
      `lint-json-channel-discipline.sh`'s EMIT check applies); the advisory-only,
      never-mutating posture; the explicit false-negative posture (declaration names and explicit
      supersession markers only, never natural-language equivalence); and the Decision 5 dormancy
      note naming `orchestrate-cycle-postflight.sh` as the single integration point and **both**
      calls that integration owes. *(completed)*
- [x] Implement two input modes: declaration names passed directly (`--name NAME`, repeatable),
      and `--from-return-meta PATH` which reads every entry's `declaration_names` out of a
      `.return-meta.json`'s `claim_invalidations` array. Both modes accept `--self TASK_NUMBER`
      (the producing task, excluded from results) and `--state-file PATH` (default
      `specs/state.json`, present so the fixture can drive the script without touching real
      state). *(completed)*
- [x] Implement the match in ONE `jq` invocation per Decision 1: non-terminal tasks only
      (`completed`, `abandoned`, `expanded` excluded via a membership test over a terminal set,
      never a chain of `!=`), the producing task excluded via
      `select(.project_number == $self | not)` per Decision 2, each name regex-escaped by `gsub`
      and matched against `title` and `description` with
      `(?<![A-Za-z0-9_])...(?![A-Za-z0-9_])`. *(completed)*
- [x] Emit a JSON array of `{task_number, title, matched_name}` objects on stdout (Decision 4),
      sorted by `task_number` then `matched_name` so output is deterministic and diffable. Emit
      `[]` -- never nothing, never prose -- when there is no match, no name, or no state file. *(completed)*
- [x] Route every diagnostic to `>&2`. Exit 0 on every path, including a missing state file, a
      malformed state file, an absent `claim_invalidations` array, and a `jq`-unavailable host:
      advisory means it can never fail the dispatch that calls it. *(completed)*
- [x] Open the state file read-only and never pass it to any writer; do not source
      `state-write.sh` or any mutation helper. *(completed)*
- [x] Add `--help` describing both input modes and the exit-0-always contract. *(completed)*
- [x] `bash -n` the script and run it by hand against the real `specs/state.json` with a name
      certain to match nothing, confirming `[]` on stdout and exit 0. *(completed)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: the phase creates exactly one new file and modifies none; no existing script
needs an edit to accommodate it (the `manifest.json` declaration is Phase 5's). Confirm at
implementation time with `git status --short`, which must show exactly one untracked script under
`agent-system/extensions/core/scripts/`.

**Tier Justification**: The edit is one new, self-contained, read-only script with no caller
anywhere in the tree, so nothing downstream can break; it is covered by
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-lint-json-channel-discipline.sh`
plus the phase's own `bash -n` and by-hand invocation.

**Files to modify**:

- `agent-system/extensions/core/scripts/sweep-invalidated-claims.sh` - new file: the matcher

**Verification**:

- `bash -n agent-system/extensions/core/scripts/sweep-invalidated-claims.sh` passes.
- `bash agent-system/extensions/core/scripts/sweep-invalidated-claims.sh --name
  ZzNoSuchDeclarationZz` prints exactly `[]` on stdout and exits 0.
- The same invocation against a deliberately absent `--state-file` also prints `[]` and exits 0.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-lint-json-channel-discipline.sh`
  is green (no diagnostic leaks into the declared JSON stdout contract).
- `git diff --stat specs/state.json` is empty after every by-hand invocation -- the sweep wrote
  nothing.
- `grep -n '!=' agent-system/extensions/core/scripts/sweep-invalidated-claims.sh` finds no `jq`
  filter using `!=` (Decision 2).

---

### Phase 4: Regression fixture replaying the motivating incident [COMPLETED]

**Goal**: Assert the acceptance criterion mechanically -- all five affected analogs named, and the
state file byte-identical afterwards.

**Tasks**:

- [x] Write `agent-system/extensions/core/scripts/tests/test-sweep-invalidated-claims.sh` on the
      structural model the existing suites use: `pass()`/`fail()` counters, a `mktemp -d` workdir
      with a `trap EXIT` cleanup, the script under test resolved source-store-first with the
      deployed copy as fallback, and exit 0 / 1 / 2 for all-pass / any-fail / environment error. *(completed)*
- [x] Build the incident fixture: a synthetic `state.json` holding five non-terminal tasks whose
      `description` each names the refuted declaration in a different textual position (prose
      sentence, inline backticked path, mid-sentence, a title-only occurrence, and one whose only
      occurrence is in `title`), reproducing the five-affected-sibling shape of the observed
      incident. *(completed)*
- [x] Add the controls the acceptance criterion needs to be meaningful: a non-terminal task that
      does not name the declaration at all; a task whose text contains the name only as a
      substring of a longer identifier (must NOT match -- the word-boundary assertion); a
      **terminal** (`completed`) task that does name it (must NOT match); and the producing task
      itself naming it (must NOT match, via `--self`). *(completed)*
- [x] Assert the primary criterion: the output names exactly the five expected task numbers, no
      more and no fewer, with each row's `matched_name` correct. *(completed)*
- [x] Assert the non-mutation half of the criterion by checksum: capture the fixture
      `state.json`'s hash before and after, and fail on any difference. *(completed)*
- [x] Assert the robustness contract: exit 0 and `[]` on a missing state file, on a malformed
      state file, on no `--name` arguments, and on a `.return-meta.json` with an absent or empty
      `claim_invalidations`. *(completed)*
- [x] Assert the `--from-return-meta` mode end-to-end: a fixture `.return-meta.json` carrying one
      `claim_invalidations` entry with two `declaration_names` yields the union of both names'
      matches, deduplicated per `{task_number, matched_name}`. *(completed)*
- [x] Assert output determinism: two consecutive runs produce byte-identical stdout. *(completed)*
- [x] Run the suite directly and confirm it passes, then confirm `run-all.sh` discovers it by glob
      with no registration step. *(completed)*

**Timing**: 1.5 hours

**Depends on**: 3

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: the suite is hypothesized to need no entry in any registry --
`run-all.sh` discovers `scripts/tests/test-*.sh` by glob, and `suite-cost-hints.txt` is advisory
and optional by its own header. Confirm at implementation time by running `run-all.sh --only
test-sweep-invalidated-claims.sh` and checking it resolves the basename without any file being
edited to list it.

**Tier Justification**: The edit is one new test fixture that no other suite or script imports, so
its blast radius is itself; it is covered by
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-sweep-invalidated-claims.sh`.

**Files to modify**:

- `agent-system/extensions/core/scripts/tests/test-sweep-invalidated-claims.sh` - new file: the
  regression fixture

**Verification**:

- `bash agent-system/extensions/core/scripts/tests/test-sweep-invalidated-claims.sh` exits 0 with
  every assertion passing.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-sweep-invalidated-claims.sh`
  resolves the basename and is green, with no registry file edited.
- The acceptance assertion is present and names five expected task numbers.
- The before/after checksum assertion on the fixture `state.json` is present and passes.

---

### Phase 5: Declare, deploy, and run the full gate set [NOT STARTED]

**Goal**: Bring the new files into the extension's declared surface, regenerate the deployed tree,
and verify the whole repository is green.

**Tasks**:

- [ ] Re-read `agent-system/extensions/core/manifest.json` immediately before editing, then run
      `bash agent-system/extensions/core/scripts/sync-manifest-scripts.sh --check` to see the two
      missing declarations, and `--write` to derive `provides.scripts` from disk rather than
      hand-adding entries.
- [ ] Run `bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --write` so
      `index-entries.json`'s `line_count` for `formats/return-metadata-file.md` matches the file
      Phase 1 grew (Rule R).
- [ ] Run `bash .claude/scripts/deploy-headless.sh` so the deployed `.claude/` tree carries the new
      script, the new test suite, the edited agent contract, and the edited format doc. Hand-edit
      nothing under `.claude/**`.
- [ ] Run `bash .claude/scripts/verify-deploy.sh` -- the complete gate set, all 21 gates, not a
      hand-picked subset.
- [ ] Triage every finding against a pre-change baseline before treating it as this task's: run
      `git stash list`-free comparison by re-running the failing gate on `HEAD` if needed.
      `validate-context-budgets.sh` is NOT one of the 21 gates and its ten-agent failure is
      pre-existing -- do not attempt to repair it here (Non-Goals).
- [ ] Record, as this task's wrap-up output, the follow-up wiring task the deferral owes: one task
      against `orchestrate-cycle-postflight.sh` adding **two** calls at the research-postflight
      site -- `sweep-invalidated-claims.sh` keyed on `claim_invalidations`, and
      `memory-harvest.sh <task_number>` keyed on non-empty `memory_candidates` -- bundled as one
      task, never two, to halve the serializing edges against that contended file.

**Timing**: 1.25 hours

**Depends on**: 2, 4

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: `sync-manifest-scripts.sh --check` is hypothesized to report exactly two
missing `provides.scripts` entries (the matcher and its suite) and nothing else -- the script's own
header records that all nine extensions' arrays were derived clean at its authoring time. Confirm
by reading `--check`'s output before running `--write`, and by diffing `manifest.json` afterwards
to verify exactly two added lines.

**Files to modify**:

- `agent-system/extensions/core/manifest.json` - two `provides.scripts` entries, derived by
  `sync-manifest-scripts.sh --write`
- `agent-system/extensions/core/index-entries.json` - refreshed `line_count` for
  `formats/return-metadata-file.md`, derived by `generate-context-line-counts.sh --write`

**Verification**:

- `bash agent-system/extensions/core/scripts/sync-manifest-scripts.sh --check` exits clean.
- `bash agent-system/extensions/core/scripts/check-extension-docs.sh` reports no Rule Q
  (undeclared script) or Rule R (stale `line_count`) failure.
- `bash .claude/scripts/verify-deploy.sh` is green across the complete 21-gate set -- including
  Gate 3 (doc-lint), Gate 4 (task-reference lint), Gate 8 (`tests/run-all.sh`, with the new suite
  discovered), Gate 13 (whole-tree orphan detection, with the new script no longer an orphan), and
  Gate 20 (orchestrator context budget lock).
- `bash .claude/scripts/check-deploy-freshness.sh` reports the deployed tree current.
- The follow-up wiring task's content is recorded in this task's summary and handoff, naming both
  owed calls.

---

## Testing & Validation

- [ ] `bash agent-system/extensions/core/scripts/tests/test-sweep-invalidated-claims.sh` passes
      every assertion.
- [ ] The acceptance criterion is asserted mechanically: the incident replay names all five
      affected analogs, and the fixture `state.json` is byte-identical afterwards.
- [ ] Word-boundary discipline is asserted negatively: a longer-identifier substring does not match.
- [ ] Non-terminal scoping is asserted negatively: a `completed` task naming the declaration does
      not match; the producing task does not match itself.
- [ ] The advisory contract holds on every failure path: exit 0 and `[]` for a missing state file,
      a malformed state file, no names, and an empty `claim_invalidations`.
- [ ] `bash agent-system/extensions/core/scripts/tests/run-all.sh` discovers the new suite by glob.
- [ ] `bash .claude/scripts/verify-deploy.sh` is green across all 21 gates.
- [ ] `git diff` shows no change under `.claude/**` that `deploy-headless.sh` did not generate, and
      no change to `scripts/memory-harvest.sh` or `skills/skill-todo/SKILL.md`.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/sweep-invalidated-claims.sh` - the matcher: read-only,
  JSON-on-stdout, exit-0-always, advisory.
- `agent-system/extensions/core/scripts/tests/test-sweep-invalidated-claims.sh` - the incident
  replay fixture.
- `agent-system/extensions/core/context/formats/return-metadata-file.md` - the
  `claim_invalidations` field specification.
- `agent-system/extensions/core/agents/general-research-agent.md` - the producer instruction.
- `agent-system/extensions/core/manifest.json`, `index-entries.json` - mechanically derived
  declaration and line-count refresh.
- `specs/319_cross_task_claim_invalidation_surfacing/summaries/01_claim-invalidation-sweep-summary.md`
  - the completion summary.
- **One follow-up task this plan deliberately leaves owed** (Decision 5, Phase 5's final step):
  wire the research-postflight call site in `orchestrate-cycle-postflight.sh` with **both** calls
  -- the matcher keyed on `claim_invalidations`, and `memory-harvest.sh <task_number>` keyed on
  non-empty `memory_candidates` -- as one task, plus the decision on the durable sink the sweep's
  advisory output lands in. Until that task lands, both the matcher and the positive-direction
  harvest remain built-but-uncalled, which is the known, accepted, and documented state of this
  deliverable rather than an oversight.

## Rollback/Contingency

Every phase is additive and independently revertible by commit: Phases 1 and 2 add prose to two
markdown files, Phases 3 and 4 add two new files that nothing imports or invokes, and Phase 5's
two edits are both mechanically re-derivable from disk (`sync-manifest-scripts.sh --write`,
`generate-context-line-counts.sh --write`). Reverting any single phase's commit cannot break a
caller, because no caller exists (Decision 5).

If a genuine rollback of uncommitted work becomes necessary, take the snapshot first per
`context/contracts/recovery.md`'s rollback rung -- which documents the exact invocation shape,
including its out-of-scope override flag for a deliberate whole-tree revert -- and only then run
the destructive command. Do not emit a bare reverting snapshot as a routine start-of-phase
checkpoint; an ordinary defensive checkpoint uses the non-reverting mode instead.
