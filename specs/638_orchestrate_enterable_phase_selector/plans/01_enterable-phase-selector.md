# Implementation Plan: Task #638

- **Task**: 638 - Make /orchestrate's hard-mode phase selector pick the first ENTERABLE phase, not the first heading that merely parses as open
- **Status**: [IMPLEMENTING]
- **Effort**: 4.25 hours
- **Dependencies**: Task 547 (`[COMPLETED]`; the shared-file edge on `orchestrate-cycle-plan.sh` is discharged)
- **Research Inputs**: specs/638_orchestrate_enterable_phase_selector/reports/01_enterable_phase_selector.md
- **Artifacts**: plans/01_enterable-phase-selector.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The hard-mode (H1) per-phase selector in `orchestrate-cycle-plan.sh` picks the first phase
heading whose marker merely parses as OPEN, with no notion of whether that phase can actually be
entered. This plan replaces that single `grep | head -1` with a real enterability predicate:
marker in a new, narrower alternation (OPEN minus `BLOCKED`) AND every phase named in the
candidate's own `**Depends on**:` line closed. The predicate and its `Depends on` parser land in
`phase-heading-patterns.sh` — the existing sole sourced anchor for phase grammar — as purely
additive exports, so `PHASE_STATUS_OPEN_ALT`'s meaning is preserved unchanged for any future
consumer. The selector gains a third, distinct outcome: "open headings exist, none enterable"
becomes a named blocked row (with per-heading diagnostics) instead of silently falling through
to an unscoped dispatch, while the pre-existing "no open heading at all" fallthrough is left
byte-identical.

### Premise Re-Validation (Carried-Figure Discipline)

Every carried figure in the dispatch `## Description` was re-checked against live state before
planning. Results, stated explicitly even where unchanged:

- **CORRECTED (line number drifted)**: the description cites `orchestrate-cycle-plan.sh:2393` as
  the selector call site. Live, it is **line 2453** (`grep -n "PHASE_STATUS_OPEN_ERE\|h1_next_heading"`).
  The file grew since task filing; the code at that line is otherwise exactly as described. The
  research report had already caught this drift and this plan uses 2453 throughout.
- **CONFIRMED (unchanged)**: `PHASE_STATUS_OPEN_ALT='NOT STARTED|IN PROGRESS|PARTIAL|BLOCKED'` is
  at `scripts/lib/phase-heading-patterns.sh:120`, verbatim as described, read live.
- **CONFIRMED (unchanged)**: `grep -rn PHASE_STATUS_OPEN_ERE agent-system/extensions/` returns the
  definition site plus exactly one real consumer (line 2453). The only other textual hit, in
  `agents/general-implementation-agent.md`, is a comment explaining why that file defines its OWN
  narrower `STALE_STATUS_ALT`, not a second consumer. Blast radius of a selector-scoped change is
  one call site, as claimed.
- **CONFIRMED (unchanged)**: `diff -q` of both named files between
  `agent-system/extensions/core/scripts/` and `.claude/scripts/` produced no output — source and
  deploy are still byte-identical, so the source store is a safe and sufficient edit target and
  the redeploy obligation below is the only sync step required.
- **CONFIRMED (unchanged)**: the serializing dependency is discharged — task 547 is `[COMPLETED]`
  with all six of its own phases closed, so no concurrent writer holds `orchestrate-cycle-plan.sh`.

### Research Integration

Five research findings shape the phase structure directly:

1. **No new "disposition" vocabulary needs inventing.** `[COMPLETED WITH EXCLUSIONS]` is already
   a member of `PHASE_STATUS_DONE_ALT`, so the dynamic-bypass case (gate executes, fails,
   contingency branch runs) is *already* invisible to the selector. The plan therefore builds
   only two checks — narrower marker set, and `Depends on` closure — and explicitly adds no
   prose-disposition mechanism. This also honors the dispatch's own non-goal forbidding
   natural-language inference from plan prose.
2. **`[BLOCKED]` is overloaded and must not be disambiguated.** `plan-format.md` sanctions a
   pre-decided, permanently-`[BLOCKED]` decision gate (wave 1, `Depends on: none`) that shares
   the identical marker text with an ordinary, temporarily-blocked phase. Neither is a legitimate
   dispatch target, so the selector treats `[BLOCKED]` as universally non-enterable and attempts
   no disambiguation.
3. **`**Depends on**:` is prose-only — no parser exists anywhere.** It must be written from
   scratch, and the documented absence default is "depends on all prior phases" (full
   sequential), **not** "no dependency". Getting that default backwards would under-gate exactly
   the plans that rely on it.
4. **Group 9 of `test-orchestrate-cycle-plan.sh` is the established fixture home**, with a
   copyable harness idiom (`write_state` heredoc / `mkdir -p .../plans` / plan heredoc /
   `run_sut --session X --hard -- N` / `jqf` / `$ARGV_LOG`) demonstrated by Cases A–E.
5. **The two "nothing to select" conditions must not collapse into one.** Case D ("no OPEN
   heading at all") must keep falling through unchanged; the NEW case ("OPEN headings exist, all
   rejected") must block. Phase 2 encodes these as two distinct exit codes, never one boolean.

### Prior Plan Reference

No prior plan. This is the task's first planning round.

### Roadmap Alignment

No `roadmap_path` supplied in this dispatch and `roadmap_flag` is not set; no roadmap phases are
added and `specs/ROADMAP.md` is not consulted or modified.

### Measured Facts Established During Planning

Two figures were measured during planning and are load-bearing for Phase 1's parser design:

- **Both field spellings are in live use.** Repo-wide, `**Depends on**:` occurs 4907 times and
  `**Depends on:**` (colon inside the bold) 296 times — `plan-format.md`'s own field definition
  uses the *minority* spelling. A parser matching only one form silently mis-reads the other as
  absent, which the absence default then converts into the strictest possible gate. The parser
  MUST accept both.
- **Unparseable values exist in the corpus.** Live survey found values such as
  `Phase 3 (directory skeleton must exist)` and `Tasks 593 (shared utilities), 594 (skill base)`
  — the latter naming *task* numbers, not phase numbers. Parsing those as phase numbers would be
  actively wrong, so Phase 1 specifies all-or-nothing token validation with a conservative
  fallback.

## Goals & Non-Goals

**Goals**:

- A plan whose first open-by-marker heading is `[BLOCKED]` is not selected for it.
- A plan whose first open-by-marker heading has an unmet `Depends on` prerequisite is not
  selected for it; an enterable phase later in file order is selected instead.
- A plan with one or more open-by-marker headings and no enterable phase produces a named,
  diagnostic blocked row rather than an unscoped dispatch.
- A plan whose first open heading IS enterable behaves exactly as it does today (Group 9 Cases
  A–E keep passing verbatim).
- `PHASE_STATUS_OPEN_ALT`'s meaning is preserved for every present and future consumer; the
  narrower set is a NEW, separately named export, and the split is recorded in the library header.
- Regression coverage lands in the core extension's own `scripts/tests/`, covering at minimum the
  three plan shapes named in the acceptance criteria.

**Non-Goals**:

- No change to how phases are MARKED by implementation agents (`[NOT STARTED]` ->
  `[IN PROGRESS]` -> closed stays exactly as it is).
- No change to the `[COMPLETED WITH EXCLUSIONS]` admission test or to the status-marker enum.
- No natural-language inference of enterability from plan prose; every consumed signal is a
  structured, greppable form (a heading marker or a `Depends on` field).
- No per-phase operator override flag (the dispatch's open question 4, explicitly optional). See
  Decisions.
- No lint enforcing that a permanently-`[BLOCKED]` gate is never named as a literal dependency
  (the research report's Context Extension Recommendation) — a natural follow-up once this task's
  parser exists to reuse, out of scope here.
- No new script file, no new test suite file (see Decisions for why).

## Decisions

Four design choices this plan makes, recorded here so the implementer does not re-litigate them:

- **D1 — The predicate lives in `phase-heading-patterns.sh`, not a new library.** The research
  report left open whether `Depends on` reasoning belongs in a file whose header scopes it to
  "phase-heading parsing". A new `scripts/lib/phase-enterability-lib.sh` would be architecturally
  tidier but costs three extra coupled surfaces: a `provides.scripts` entry in
  `agent-system/extensions/core/manifest.json` (which enumerates every script individually), a
  companion test suite, and a row in `scripts/tests/suite-classification.data` (whose
  `lint-unit-integration-boundary.sh` fails loudly on an unclassified suite). Extending the
  existing library keeps the change to four files, reuses its existing unit-test home, and keeps
  the marker alternation beside the one it narrows. The cost is a modest widening of the library's
  own stated scope, which Phase 1 pays for explicitly by updating the header.
- **D2 — A new alternation, never a redefinition.** `PHASE_STATUS_OPEN_ALT` keeps all four
  members. `PHASE_STATUS_ENTERABLE_ALT` is added beside it. This is the dispatch's own stated
  preference and discharges the acceptance criterion about preserving OPEN's meaning.
- **D3 — The absence/unparseable default is strict, and that is the feature.** A phase with no
  parseable `Depends on` line requires every prior phase closed. On a plan with a `[BLOCKED]`
  phase and no explicit `Depends on` lines, this means NO phase after it is enterable and the run
  blocks with a diagnostic. That is a genuine behavior change beyond pure bug-fixing, and it is
  the behavior the observed field failure needed: reporting "this plan needs a `/revise`" beats
  dispatching an agent into a closed route and burning a cycle to learn what the plan file
  already said. The mitigation is diagnostic quality, not leniency — Phase 2's blocked reason
  names each rejected heading and why. The rejected alternative (treat a prior `[BLOCKED]` phase
  as satisfying the default) was discarded because it re-admits entry past an unfinished blocker,
  which is the exact failure mode this task exists to remove.
- **D4 — No per-phase operator override.** Adding one is in scope "to consider but not required",
  and nothing in the acceptance criteria needs it. The existing remedy (edit the plan's markers,
  or `/revise`) is adequate and already understood; a second forcing mechanism at a grain no
  existing flag operates at would be new surface with no demonstrated demand.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The two "nothing selectable" conditions collapse into one check, silently preserving today's bug under a renamed code path | H | M | Phase 1 gives them distinct exit codes (3 vs 4), never one boolean; Phase 2's Case D assertions (no OPEN heading -> ordinary dispatch, no `--phase-number`) must pass verbatim alongside the new Case H |
| The `Depends on` parser mis-splits tokens (`1, 3` vs `1,3` vs `3.1`) or swallows a prose value as a number | M | M | Validate every comma-split token against the already-exported `PHASE_NUMBER_TOKEN_ERE` rather than inventing a second number grammar; all-or-nothing — one bad token discards the whole parse and falls back to the absence default |
| Only one of the two live field spellings is matched, so 296 real occurrences read as absent | M | M | Phase 1's parser accepts both `**Depends on**:` and `**Depends on:**`; Phase 1's unit tests assert both spellings explicitly |
| The strict absence default blocks plans that run fine today (D3) | M | M | Accepted deliberately (D3); mitigated by a diagnostic blocked reason naming every rejected heading, its marker, and its rejection cause, plus the `/revise` remedy |
| New library functions abort the sourcing script under `set -euo pipefail` (line 282 of the caller) | H | L | Functions return status codes rather than relying on command exit propagation; the caller uses the `rc=0; out=$(fn) \|\| rc=$?` idiom; never a `fn \| grep -q` pipe (the library header already documents that exact SIGPIPE/pipefail race) |
| Selection now prefers a dependency-satisfied later phase over an earlier open one in multi-wave plans | L | M | This is the intended, acceptance-sanctioned improvement ("a plan with an enterable phase later in file order selects that phase"), not scope creep; called out here so it is not mistaken for a regression |
| Source edited but not redeployed, so consumer repos keep the defective selector | M | M | Phase 4 runs `deploy-headless.sh` and declares `__WHOLE_TREE__`; `verify-deploy.sh`'s own freshness gate independently fails on a stale deploy |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |

Phases within the same wave can execute in parallel. This plan is fully sequential.

---

### Phase 1: Enterability vocabulary and `Depends on` parser in the pattern library [COMPLETED]

**Goal**: Add — purely additively — a narrower enterable-marker alternation, a `Depends on` field
parser, and an enterability predicate to `phase-heading-patterns.sh`, with unit coverage, leaving
every existing export byte-identical in meaning.

**Tasks**:

- [x] Add beside `PHASE_STATUS_OPEN_ALT` (do NOT modify it):
      `PHASE_STATUS_ENTERABLE_ALT='NOT STARTED|IN PROGRESS|PARTIAL'`, plus
      `PHASE_STATUS_ENTERABLE_ERE` and `PHASE_HEADING_ENTERABLE_ERE` derived in the same shape the
      DONE/OPEN pairs already use (including the `# shellcheck disable=SC2034` export-contract
      comment the file's other exported constants carry). *(completed)*
- [x] Add a comment block immediately above the new alternation recording the deliberate split:
      OPEN means "not closed" and keeps all four members for any sourcing consumer; ENTERABLE
      means "a dispatch may be scoped into this phase" and excludes `BLOCKED` because both
      sanctioned meanings of a `[BLOCKED]` phase heading (a pre-decided gate that never executes,
      and a phase waiting on an external unblock) are wrong to dispatch into, and nothing in the
      marker text distinguishes them. *(completed)*
- [x] Update the library's top-of-file header to state the widened scope (phase-heading grammar
      *and* the per-phase enterability fields it governs), so D1 is recorded where a future reader
      meets it. *(completed)*
- [x] Implement `phase_marker_of <file> <phase_number>`: prints the marker text of that phase's
      conforming heading; returns 1 when no such heading exists. *(completed)*
- [x] Implement `phase_dependency_numbers <file> <phase_number>`: prints the phase's EFFECTIVE
      dependency numbers, one per line. Rules, all of them:
      - Scan from the phase's own heading line to the next `^### ` line (or EOF) for the first
        line matching the field label in EITHER live spelling — `**Depends on**:` and
        `**Depends on:**` — with an optional leading list bullet.
      - Strip the label and trim. A value equal to `none` (case-insensitive) yields an EMPTY set.
      - Otherwise split on commas, trim each token, and validate each against the already-exported
        `PHASE_NUMBER_TOKEN_ERE`. All-or-nothing: if ANY token fails validation, discard the whole
        parse and apply the absence default.
      - Absence default (field missing, or parse discarded): every conforming phase number
        appearing strictly earlier in file order than this phase. This is `plan-format.md`'s
        documented "Absence means sequential (depends on all prior phases)" — never "no
        dependency". *(completed)*
- [x] Implement `phase_is_enterable <file> <heading_line>`: returns 0 only when the heading's
      marker is in `PHASE_STATUS_ENTERABLE_ALT` AND every number from `phase_dependency_numbers`
      resolves to a heading in the file whose marker is in `PHASE_STATUS_DONE_ALT`. On refusal,
      print one short machine-readable reason token on stdout: `marker`,
      `unmet-dependency:<n>`, or `dangling-dependency:<n>` (a dependency naming a phase with no
      heading in the file). *(completed)*
- [x] Implement `select_enterable_phase <file>` with a three-way exit contract, documented in its
      own header comment:
      - exit 0 — prints the first (lowest file-order) enterable heading line on stdout;
      - exit 3 — at least one heading matched `PHASE_STATUS_OPEN_ERE` but none was enterable;
        prints one `<phase>:<marker>:<reason>` diagnostic line per rejected heading;
      - exit 4 — no heading matched `PHASE_STATUS_OPEN_ERE` at all (the pre-existing fallthrough
        condition, preserved as its own distinct code). *(completed)*
- [x] Write unit cases in the existing `scripts/tests/test-phase-heading-patterns.sh`: both field
      spellings; `none`; `1`; `1, 3`; `1,3`; a decimal `3.1` token; an unparseable prose value
      (`Phase 3 (directory skeleton must exist)`) falling back to all-prior; a `Tasks 593 (...)`
      value falling back to all-prior rather than parsing task numbers as phases; an absent field
      falling back to all-prior; `[BLOCKED]` rejected on marker; an unmet dependency rejected; a
      dangling dependency rejected; a satisfied phase accepted; and one fixture per
      `select_enterable_phase` exit code (0, 3, 4). *(deviation: altered — the "falls back to
      all-prior rather than parsing task numbers as phases" fixture uses the literal text "Items
      593 (shared utilities), 594 (skill base)" rather than "Tasks 593 (...)", because the literal
      word "Tasks" followed by a number is itself a pattern the repo's own task-reference guard
      (`hooks/validate-no-task-references.sh`) blocks from landing under `agent-system/**`. The
      fixture is wrapped in a `task-ref-ok` exempt region regardless, as a backstop. The substance
      of the assertion is unchanged: a multi-token prose value whose first token fails
      `PHASE_NUMBER_TOKEN_ERE` must fall back to the all-prior default, never be parsed as phase
      numbers.)*
- [x] Add a line to that suite's existing "Deliberate-break check" comment block naming one
      mutation that must make the new assertions fail (e.g. restoring `BLOCKED` to
      `PHASE_STATUS_ENTERABLE_ALT`), matching the convention already there. *(completed)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: The edit is additive-only to one sourced library plus its own unit suite —
no existing export changes name, value, or meaning — so the covering check is
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-common-lib.sh,test-corroborate-phase-counts.sh,test-deploy-freshness.sh,test-deploy-propagation.sh,test-derived-artifact-probe-lib.sh,test-errors-append.sh,test-orchestrate-cycle-plan.sh,test-orchestrate-cycle-postflight.sh,test-orchestrate-unwind-dispatch.sh,test-phase-heading-patterns.sh,test-phase-heartbeat.sh,test-postflight-deploy-gate.sh,test-reconcile-handoff-status.sh,test-record-version-patterns.sh,test-redeploy-checkpoint-promotion.sh,test-resume-scan-nonconformance.sh,test-status-vocabulary.sh,test-update-plan-status.sh,test-update-task-status.sh,test-validate-handoff.sh,test-validate-state.sh`,
which is `suite_selection_select`'s complete output for this phase's two touched paths, run
verbatim rather than asserted.

**Scope Hypothesis**: This phase asserts that `PHASE_STATUS_OPEN_ALT` has exactly one real
consumer, so adding a sibling alternation changes no existing behavior. Confirm at implementation
time with `grep -rn 'PHASE_STATUS_OPEN_ERE\|PHASE_STATUS_OPEN_ALT' agent-system/extensions/` —
expect the definition site, `orchestrate-cycle-plan.sh:2453`, and one comment-only mention in
`agents/general-implementation-agent.md`. A fourth hit means the blast radius is wider than
planned: stop and re-scope rather than proceeding.

**Files to modify**:

- `agent-system/extensions/core/scripts/lib/phase-heading-patterns.sh` - new ENTERABLE
  alternation and its ERE forms, three new functions, widened header scope note
- `agent-system/extensions/core/scripts/tests/test-phase-heading-patterns.sh` - unit cases for
  the parser, the predicate, and the three selector exit codes

**Verification**:

- `bash agent-system/extensions/core/scripts/tests/test-phase-heading-patterns.sh` exits 0 with
  every new assertion passing and zero pre-existing assertions changed.
- The `run-all.sh --only ...` invocation named verbatim in this phase's Tier Justification above
  passes, with a non-zero exit treated as a failure (never a stdout diff against a baseline).
- `bash -n agent-system/extensions/core/scripts/lib/phase-heading-patterns.sh` and `shellcheck`
  on the library are clean.
- `git diff` shows `PHASE_STATUS_OPEN_ALT`'s own line unchanged.

---

### Phase 2: Rewire the H1 selector onto the predicate, with a named no-enterable-phase refusal [NOT STARTED]

**Goal**: Replace the `grep | head -1` at `orchestrate-cycle-plan.sh:2453` with
`select_enterable_phase`, add a distinct blocked row for "open headings exist, none enterable",
and leave the no-open-heading fallthrough byte-identical in behavior.

**Tasks**:

- [ ] Replace the single `h1_next_heading=$(grep ... | head -1)` with a call to
      `select_enterable_phase "$h1_plan_path"`, captured with the `rc=0; out=$(...) || rc=$?`
      idiom (never a pipe into `grep -q`, and never `$(cmd || echo ...)` — the file's own
      neighboring comment documents why that form corrupts output).
- [ ] Branch on the three exit codes:
      - 0 — set `h1_next_heading` from stdout and continue into the existing
        `extract_phase_number` call and marker/handoff crosscheck, untouched;
      - 3 — set `h1_blocked_reason[$t]` to a new named reason (below) and take no dispatch;
      - 4 — leave `h1_next_phase_val` empty so control reaches the pre-existing fallthrough
        comment and the ordinary status-derived dispatch, exactly as today.
- [ ] Compose the new blocked reason to carry everything the operator needs without a second
      investigation: the literal prefix `H1: NO ENTERABLE PHASE`, the plan path, the count of
      open-but-rejected headings, a per-heading list (`phase N [MARKER] — <reason>`) capped at the
      first five with a `(+K more)` suffix, and the remedy ("the plan needs a `/revise`, or the
      gate phases need closing").
- [ ] Leave the whole-file conformance gate (`has_nonconforming_phase_headings`), the
      `extract_phase_number` call, the marker/handoff crosscheck, the disputed-heading
      `[PARTIAL]` downgrade, and the H7 territory literal exactly where and as they are.
- [ ] Confirm the new branch sits in the shared decision section ABOVE the dry-run/live fork, so
      `--dry-run` reports the identical verdict and mutates nothing.
- [ ] Add Group 9 regression fixtures to `scripts/tests/test-orchestrate-cycle-plan.sh`, reusing
      the Case A–E idiom verbatim (`write_state` heredoc, `mkdir -p .../plans`, plan heredoc,
      `run_sut --session X --hard -- N`, `jqf`, `$ARGV_LOG`):
      - **Case F** — phase 1 `[BLOCKED]` (`Depends on: none`), phase 2 `[COMPLETED]`, phase 3
        `[NOT STARTED]` (`Depends on: 2`), handoff `phases_completed: 1`: dispatches with
        `--phase-number 3`, never 1.
      - **Case G** — phase 1 `[COMPLETED]`, phase 2 `[NOT STARTED]` (`Depends on: 4`), phase 3
        `[NOT STARTED]` (`Depends on: 1`), phase 4 `[NOT STARTED]` (`Depends on: 1`), handoff
        `phases_completed: 1`: dispatches with `--phase-number 3`, never 2.
      - **Case H** — phase 1 `[BLOCKED]`, phase 2 `[NOT STARTED]` (`Depends on: 1`), handoff
        `phases_completed: 0`: zero dispatch rows, exactly one blocked row whose reason contains
        `NO ENTERABLE PHASE`.
      - **Case I** — `--dry-run` parity over Case H's fixture: identical blocked verdict, plan
        file byte-identical before and after.
- [ ] Re-run Group 9 Cases A–E unchanged and confirm each still passes without edits to its
      assertions — in particular Case C (first open heading IS enterable: still dispatches
      `--phase-number 2`) and Case D (no open heading: still falls through with no
      `--phase-number`).
- [ ] Verify no file landing under `agent-system/**` gained a task-number reference (the fixture
      project numbers 906+ are test identifiers, not task citations).

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: The change is confined to one branch of one script plus that script's own
integration suite, with no externally visible signature change, so the covering check is
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-deploy-baseline-lib.sh,test-deploy-ledger-lib.sh,test-force-phases.sh,test-gate-out-self-attribution.sh,test-git-commit-scoped.sh,test-handoff-dispatch-identity.sh,test-handoff-reader-parity.sh,test-lint-deploy-caller-wrap.sh,test-lint-json-channel-discipline.sh,test-mint-dispatch-seq.sh,test-orchestrate-batch-gate.sh,test-orchestrate-build-dispatch.sh,test-orchestrate-churn.sh,test-orchestrate-context-growth.sh,test-orchestrate-cycle-plan.sh,test-orchestrate-cycle-postflight.sh,test-orchestrate-predispatch-review.sh,test-orchestrate-record-decision.sh,test-orchestrate-triage-classify.sh,test-orchestrate-unwind-dispatch.sh,test-postflight-deploy-gate.sh,test-redeploy-checkpoint-promotion.sh,test-resume-scan-nonconformance.sh,test-routing-resolution.sh,test-session-runtime-files.sh`,
which is `suite_selection_select`'s complete output for this phase's two touched paths, run
verbatim rather than asserted.

**Scope Hypothesis**: This phase assumes the selector rewiring touches exactly one call site and
that Group 9 Cases A–E need no assertion edits. Confirm by running the full Group 9 block before
adding Cases F–I and again after: a pre-existing case that needs its assertions rewritten is
evidence the change altered behavior it was supposed to preserve — stop and re-examine the
predicate rather than editing the assertion.

**Files to modify**:

- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` - selector rewiring at the H1
  branch (line ~2453) and the new `h1_blocked_reason` composition
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` - Group 9 Cases
  F, G, H, I

**Verification**:

- `bash agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` exits 0, with
  Cases A–E passing unmodified and F–I passing.
- The `run-all.sh --only ...` invocation named verbatim in this phase's Tier Justification above
  passes, with a non-zero exit treated as a failure (never a stdout diff against a baseline).
- `bash -n` and `shellcheck` clean on `orchestrate-cycle-plan.sh`.
- `grep -c 'head -1' ` at the former call site confirms the old single-shot selection is gone, not
  merely bypassed.

---

### Phase 3: Record the now-machine-consumed `Depends on` contract in the authoring docs [NOT STARTED]

**Goal**: Update `plan-format.md` so plan authors learn that the per-phase `Depends on` field and
the `[BLOCKED]` phase marker are now read by the H1 selector, and that the absence default is
mechanically enforced rather than merely documented.

**Tasks**:

- [ ] In `context/formats/plan-format.md`'s per-phase field list, extend the `**Depends on:**`
      bullet to state that the field is now parsed by the hard-mode phase selector, that BOTH
      bold spellings are accepted, that an unparseable value falls back to the
      absence-means-all-prior default, and that the default is enforced, not advisory.
- [ ] In the same file's "A decision gate that is already `[BLOCKED]` at plan-authoring time"
      subsection, add one sentence noting that a `[BLOCKED]` phase heading is never a dispatch
      target under hard mode, which is why that subsection's existing `Depends on: none`
      obligation (and the rule that no later phase names such a gate as a dependency) now has a
      mechanical consequence: a plan violating it reports "no enterable phase" instead of
      advancing.
- [ ] Do not restate the predicate's implementation in prose — cite the library by name and keep
      the executable contract single-sourced in `phase-heading-patterns.sh`.
- [ ] Confirm no task-number reference enters any file under `agent-system/**`.

**Timing**: 0.5 hours

**Depends on**: 2

**Verification Tier**: prose

**Tier Justification**: Every changed hunk is prose inside one markdown authoring guide with no
executable surface, and the honest covering check for a source-store non-`specs/**` markdown edit
is the gate subset `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
(doc-lint plus the task-reference lint, with the repository root — which holds both a deployed
`.claude/` tree and the `agent-system/extensions` source store — as `TARGET`), run alongside the
`prose` row's diff read-through.

**Files to modify**:

- `agent-system/extensions/core/context/formats/plan-format.md` - `Depends on` field bullet and
  the plan-authoring-time-`[BLOCKED]` gate subsection

**Verification**:

- Diff read-through confirms every changed hunk is prose, with no code fence or executable
  surface touched.
- `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
  passes with both gates actually running (neither SKIPped).
- `bash .claude/scripts/check-task-references.sh` reports no new occurrence under
  `agent-system/**`.

---

### Phase 4: Redeploy and full gate [NOT STARTED]

**Goal**: Regenerate the deployed tree from the source store so consumer repositories pick up the
fixed selector, and discharge the complete gate set.

**Tasks**:

- [ ] Run `bash .claude/scripts/deploy-headless.sh` and confirm it reports a landed, verify-clean
      result.
- [ ] Confirm post-deploy that `diff -q` between source and deploy is silent for all four touched
      source files (the same byte-identity relationship the premise re-validation established
      pre-change).
- [ ] Run the complete gate set: `bash .claude/scripts/verify-deploy.sh` (no `--skip-slow`, no
      `--only-gate` — a narrowed pass is never evidence for the final phase).
- [ ] Re-observe the acceptance criteria end-to-end against the DEPLOYED tree: Group 9 Cases
      C, D, F, G, H, I all pass when `test-orchestrate-cycle-plan.sh` runs from
      `.claude/scripts/tests/`.
- [ ] Record any issue or win encountered across all four phases via `issue-record.sh`, per the
      dispatch's Issue Log obligation.

**Timing**: 0.75 hours

**Depends on**: 3

**Verification Tier**: full

**Files to modify**:

- `__WHOLE_TREE__` - `deploy-headless.sh` regenerates the entire deployed `.claude/` tree from the
  source store; no individual deployed path is hand-authored

**Verification**:

- `bash .claude/scripts/deploy-headless.sh` reports a landed, verify-clean result.
- `bash .claude/scripts/verify-deploy.sh` passes in full — the complete gate set, including
  Gate 8's full shell-suite battery, with no `--skip-slow` and no gate subset.
- `diff -q` is silent between each touched source file and its deployed counterpart.
- `bash .claude/scripts/tests/test-orchestrate-cycle-plan.sh` and
  `bash .claude/scripts/tests/test-phase-heading-patterns.sh` both exit 0 from the deployed tree.

---

## Testing & Validation

- [ ] A plan whose first open-by-marker heading is `[BLOCKED]` is not selected for it (Group 9
      Case F).
- [ ] A plan with an enterable phase later in file order selects that phase (Group 9 Cases F and
      G, covering the `[BLOCKED]`-first and unmet-`Depends on`-first shapes separately).
- [ ] A plan with no enterable phase reports that fact and dispatches nothing (Group 9 Case H),
      with dry-run parity (Case I).
- [ ] Existing behavior on a plan whose first open heading IS enterable is unchanged (Group 9
      Case C, assertions unmodified).
- [ ] The no-OPEN-heading fallthrough is unchanged and remains a distinct condition from
      no-enterable-phase (Group 9 Case D, assertions unmodified).
- [ ] `PHASE_STATUS_OPEN_ALT` is byte-identical and the ENTERABLE split is recorded in the library
      header.
- [ ] Both `Depends on` field spellings parse; an unparseable value falls back to all-prior; an
      absent field falls back to all-prior (Phase 1 unit cases).
- [ ] `bash .claude/scripts/verify-deploy.sh` passes in full after redeploy.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/lib/phase-heading-patterns.sh` — ENTERABLE alternation,
  `Depends on` parser, enterability predicate, three-way selector
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` — H1 selector rewired, new
  named no-enterable-phase blocked row
- `agent-system/extensions/core/scripts/tests/test-phase-heading-patterns.sh` — unit coverage
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` — Group 9 Cases F–I
- `agent-system/extensions/core/context/formats/plan-format.md` — authoring-contract note
- Regenerated `.claude/` deploy tree (`__WHOLE_TREE__`)

## Rollback/Contingency

Every phase is a self-contained, independently revertible commit against the source store; nothing
is generated into a form that cannot be regenerated. To revert: `git revert` the phase commits in
reverse order, then re-run `bash .claude/scripts/deploy-headless.sh` to restore the deployed tree
from the reverted source. Phases 1 and 3 are additive-only (new exports, new unit cases, prose) and
carry essentially no rollback risk. Phase 2 is the only behavior-changing commit; if the new
predicate proves too strict in practice (D3's accepted risk), the minimal containment — restoring
the `grep | head -1` selection while keeping the library additions and tests in place — is a
one-hunk revert within that single commit, and the fixtures then document the known-failing shapes
for a follow-up. If `verify-deploy.sh` fails in Phase 4 for a reason traceable to this task, fix
forward against the source store; never discard uncommitted work to reach a passing gate (see
`context/contracts/recovery.md`).
