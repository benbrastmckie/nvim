# Implementation Plan: Task #326

- **Task**: 326 - Add an advisory `--gate` verification tier at implement dispatch
- **Status**: [IMPLEMENTING]
- **Effort**: 7.5 hours
- **Dependencies**: None blocking. Sibling-in-flight (territory only, not a dependency): the
  books domain context corpus task, which owns
  `agent-system/extensions/books/context/project/books/**`. The extension lifecycle hook
  mechanism repair task is deliberately NOT a dependency.
- **Research Inputs**: `specs/326_books_verification_tier_at_implement_dispatch/reports/01_gate-flag-verification-tier.md`
- **Artifacts**: plans/01_gate-flag-verification-tier.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add an advisory-only `--gate` flag to `/orchestrate` that, at implement dispatch only, surfaces a
cheap intermediate verification tier: the consuming repository's regex layer lint plus a
`Books.Meta` import-closure check. The flag is threaded through the exact same seven-site surface
the existing `--compare` flag occupies, binds in the **books** extension's implementation agent
and skill (not the lean ones), and is backed by a new extension-local resolve-and-run wrapper
because `check-extension-docs.sh` Rule E forbids naming a consuming-repository script in any
extension doc location. Definition of done: `--gate` reaches an implement dispatch file as exactly
one added line, never reaches a research/plan dispatch, produces a structured advisory `gate`
block in `.return-meta.json`, and never blocks, fails, or downgrades anything.

**Edit target is the source store** — `agent-system/extensions/core/` and
`agent-system/extensions/books/` — never `.claude/**`, which is a disposable deploy artifact
(`rules/source-store-deploy-boundary.md`).

### Research Integration

The research report is the controlling input and its ten numbered Decisions are adopted wholesale;
this plan sequences them rather than re-deriving them. Key findings folded in:

- **Every line number in the task description was stale and has been re-measured.** The report's
  corrected table was independently re-confirmed while writing this plan (see Phase 1's Scope
  Hypothesis): `orchestrate-cycle-plan.sh` declaration **360**, parse **379**, forwarding
  **2342**; `orchestrate-build-dispatch.sh` 23/33-34/106/134/151/427-428; `orchestrate.md` 46 and
  52; `skill-orchestrate/SKILL.md` 32 and 82.
- **Two threading sites the task description omits**: `parse-command-args.sh` needs a
  `FOCUS_PROMPT` strip-chain entry (line 169) and an `export`-list entry (line 183). Without the
  strip, `--gate` leaks into focus-prompt text.
- **The gate binds in books, not lean.** Confirmed from `books/manifest.json`: `books` and
  `books:certify` route to `books-implementation-agent` / `books-implementation-hard-agent`. No
  books task ever reaches `skill-lean-implementation`. The lean Stage 6b/6c pair is the *pattern*;
  `books-implementation-agent.md:149` (`### Stage 5: Final Verification`) is the insertion point.
- **A new wrapper is mechanically required, not a preference**: Rule E hard-fails on any bare
  `<name>.sh` token in an extension's `commands/*.md`, `skills/*/SKILL.md`, `agents/*.md`,
  `README.md` or `EXTENSION.md` that no extension declares. The consuming repository's layer lint
  can never be declared. `books-certify.sh` is the shipped precedent and says so in its own header.
- **Three measured hazards** a naive wrapper gets wrong: a vacuous pass is indistinguishable from
  a real pass by exit code (0 of 9 rules matched for `books`); the rule-set library `exit 1`s
  *during sourcing* when no queue model is found, so exit 1 is not necessarily a violation; exit 2
  is a usage error. Hence five distinct layer-lint outcomes, not two.
- **The import-closure baseline is clean and simpler than the description's gloss**: zero live
  public imports of the provider across 214 private import sites, zero `require` lines in the
  provider lakefile; the only two public-import occurrences in the tree sit under `specs/archive/`,
  so pruning `specs/` as well as `.lake/` is mandatory or the gate reports two false violations on
  its very first run.
- **The byte-identity invariant**: the dispatch emission is conditional precisely so a no-flag
  dispatch file is byte-identical to one built before the flag existed. `--gate` must preserve
  this — one conditional line, nothing else.

### Prior Plan Reference

No prior plan. This is the first planning round for this task.

### Roadmap Alignment

No `roadmap_path` was provided in the dispatch context, so no roadmap was consulted and no
roadmap phases are included.

## Goals & Non-Goals

**Goals**:

- Thread `--gate` through the complete `--compare` surface in the **core** extension, scoped to
  implement dispatches by the single forwarding guard in `orchestrate-cycle-plan.sh`.
- Document the flag at all four layers where `--compare` is documented, including a new
  `### gate (optional)` section in `return-metadata-file.md` that restates the advisory MUST-NOTs
  in the schema itself.
- Ship `agent-system/extensions/books/scripts/books-gate.sh`: a resolve-and-run wrapper that
  emits one JSON object on stdout and **always exits 0** in its advisory role, classifying five
  layer-lint outcomes and reporting a vacuous pass as vacuous.
- Ship a narrow fixture suite for the wrapper, with a forgery probe per predicate.
- Bind the advisory finding in `books-implementation-agent.md` Stage 5, its `-hard` twin, and both
  books implementation skills, following the lean Stage 6c template including its asymmetry note.
- Add core test coverage asserting the one-added-line byte-identity property and the
  implement-only scoping.

**Non-Goals**:

- Re-deriving the mechanism decision. The `skill-base.sh` `verification` lifecycle hook was
  investigated and rejected (three stacked, independently fatal defects). This plan uses the live
  route and needs none of those repairs. Repairing the hook mechanism is a separate task.
- Editing anything in the consuming repository. The layer lint, the rule-set library, the
  per-component check drivers, the certify driver and the full gate all live there and are
  invoked, never modified.
- Weakening, shortcutting or quietening any existing gate. This work ADDS a cheap intermediate
  tier below the existing fail-closed one; it relaxes nothing.
- Writing any file under `agent-system/extensions/books/context/project/books/` — the concurrent
  sibling task's declared `file_scope`. Books-awareness reaches the gate through plain backticked
  pointers to that corpus only.
- A `--gate-strict` or any other `--gate-*` sibling flag (the substring-regex detector shape makes
  such a sibling unsafe).
- Documenting `--gate` in `docs/architecture/orchestrate-state-machine.md` or in
  `commands/orchestrate.md`'s `argument-hint`. `--compare` appears in neither; mirroring exactly
  means `--gate` needs neither.
- Enabling the books extension in any consuming repository's `.claude-extensions.json`. That is
  the user's own action.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `--gate` is a dangerously generic name; this codebase uses "gate" pervasively in the fail-closed sense (GATE IN/GATE OUT, the gate-out script, the stage-gates script, the full gate), so a reader may expect it to block | H | H | Name is mandated. Mitigate in prose at four layers: the Options row, the dispatch contract comment, the `### gate (optional)` schema section, and both agent steps each state "advisory only; never blocks, never fails a dispatch, never downgrades status" **inside the step**, copying the lean agent's placement discipline so a later editor cannot fold it into a failure enumeration |
| A vacuous lint pass read as a real pass — the highest-value failure mode, since the motivating measurement is 44 violations hiding behind green | H | M | `pass_vacuous` is a first-class status, never collapsed into `pass`; `rules_matched`/`rules_total` travel in the JSON; derived by sourcing the real rule set in a subshell, never by copying rules. Phase 4 asserts a 0-of-N vacuous fixture directly |
| Lint exit 1 conflated with violations — the rule-set library `exit 1`s during sourcing when no queue model is found, common in any repository lacking that component | H | H | Classify on stderr content (`no queue model found`) before treating exit 1 as violations; report `rule_set_error` distinctly. Phase 4 asserts it with a fixture rule library that exits 1 on source |
| The two archived public-import occurrences under `specs/archive/` produce false violations on the gate's first run | M | H | Prune `specs/` as well as `.lake/`. Phase 4 asserts both exclusions as separate negative cases |
| Rule E breaks the deploy if the consuming repository's lint script is named in any of the five scanned doc locations | H | M | Never name it in `commands/*.md`, `skills/*/SKILL.md`, `agents/*.md`, `README.md` or `EXTENSION.md`. Name only `books-gate.sh` there. The wrapper's own header comment and the books context corpus may name it freely (`scripts/**` and `context/**` are not scanned) |
| Rule Q fails on any file under `scripts/` not declared in `provides.scripts`, matched by full relative path | M | M | Declare `books-gate.sh` in the same commit that adds it (Phase 3) and `tests/test-books-gate.sh` in the same commit that adds it (Phase 4), each by its full relative path |
| Sibling territory collision on `agent-system/extensions/books/**` — the concurrent corpus task's declared scope is the whole `context/project/books/` directory | M | M | This work touches no file under `context/project/books/`. Re-read every books file immediately before editing; stage only this work's own hunks; never a directory or glob `git add`; never `git-snapshot.sh` in its reverting default mode |
| The substring-regex detector `[[ "$remaining" =~ --gate ]]` false-positives on a focus prompt containing the literal flag text | L | L | Pre-existing hazard shared by every flag in that parser. Note it in the implementation summary; introduce no `--gate-*` sibling |
| Rule U caps `EXTENSION.md` at 60 lines and the books one is at 52 | L | L | Prefer not to touch `EXTENSION.md` at all; if a mention proves necessary, keep it to one line |
| Verification gates read the **deployed** `.claude/` tree, so a source-store-only change is invisible to them until a regeneration | M | H | Run the two new/edited suites directly against the source store in the meantime; state the redeploy requirement explicitly in the completion summary |
| Over-reach into a hard gate | H | L | Nothing here modifies any gate script; the wrapper only invokes. Record promotion-to-hard-gate criteria in the implementation summary (N consecutive clean non-vacuous runs across M distinct package roots with zero unavailable/error outcomes, plus a measured p95 runtime), mirroring the lean agent's own promotion-criteria obligation |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 3 | -- |
| 2 | 2, 4, 5, 6 | 1 (phases 2, 5, 6); 3 (phases 4, 5) |

Phases within the same wave can execute in parallel. Wave 1's two phases are disjoint by
extension (core vs. books). Wave 2's four phases are file-disjoint from each other: Phase 2 owns
core docs, Phase 4 owns the books test suite, Phase 5 owns the books agents and skills, Phase 6
owns the core test suites. Only `books/manifest.json` is touched by two phases (3 and 4), and
those sit in different waves.

---

### Phase 1: Core flag plumbing [COMPLETED]

**Goal**: `--gate` is parsed, declared, forwarded only for implement dispatches, and emitted into
the dispatch file as exactly one added line.

**Tasks**:
- [x] `parse-command-args.sh`: add a `GATE_FLAG` paragraph to the header doc-comment block
      (alongside the `COMPARE_FLAG` paragraph), the `GATE_FLAG="false"` initializer, the
      `--gate` detector arm, the `sed 's/--gate//g'` entry in the `FOCUS_PROMPT` strip chain, and
      `GATE_FLAG` in the `export` list. Five edits, the fourth and fifth of which the task
      description omits. *(completed)*
- [x] `orchestrate-cycle-plan.sh`: add the parallel header contract paragraph, `[--gate]` to the
      usage heredoc, the `gate_flag="false"` declaration, the `--gate) gate_flag="true"; shift ;;`
      parse arm, and the implement-scoped forwarding line
      `[ "$gate_flag" = "true" ] && [ "$g" = "implement" ] && build_args+=(--gate)` immediately
      adjacent to the `--compare` one. *(completed)*
- [x] `orchestrate-build-dispatch.sh`: add `[--gate]` to the usage comment and the usage heredoc,
      the parallel contract comment block (stating advisory-only and the conditional-emission
      byte-identity rationale), the `gate_flag="false"` declaration, the `--gate)` parse arm, and
      the conditional `echo "- gate_flag: true"` emission in the Identity section. *(completed)*
- [x] Confirm `build_args` is still composed at exactly one site, so no second forwarding path
      exists to keep in sync. *(completed: one site, orchestrate-cycle-plan.sh:2339)*

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts 16 edit sites across 3 files at specific line numbers.
Re-measured at plan time and all 16 confirmed present:
`parse-command-args.sh:23,91,135-136,169,183`; `orchestrate-cycle-plan.sh:157,165,335,360,379,2342`;
`orchestrate-build-dispatch.sh:23,33-34,106,134,151,427-428`. They will nonetheless have moved by
implementation time (and each edit shifts the ones below it). Confirm at implementation time by
`grep -n 'compare_flag\|--compare\|COMPARE_FLAG'` on each of the three files before editing, and
re-grep after each file's edits; treat a site that greps absent as a finding to report, not a site
to skip silently.

**Files to modify**:
- `agent-system/extensions/core/scripts/parse-command-args.sh` - add `GATE_FLAG` (doc comment,
  initializer, detector, focus-prompt strip chain, export list)
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` - add `gate_flag` (header
  contract paragraph, usage heredoc, declaration, parse arm, implement-scoped forwarding guard)
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` - add `gate_flag` (usage
  comment, contract block, usage heredoc, declaration, parse arm, conditional emission)

**Verification**:
- `bash -n` on all three scripts.
- Build an implement dispatch with `--gate` and one without, into two temp directories, and
  `diff` them: the difference must be exactly one added line, `- gate_flag: true`.
- Build a research dispatch and a plan dispatch through the cycle planner with `--gate` set and
  confirm neither dispatch file contains `gate_flag`.
- Confirm `--gate` passed in a focus prompt position is stripped from `FOCUS_PROMPT`.
- Existing `test-orchestrate-build-dispatch.sh` and `test-orchestrate-cycle-plan.sh` still pass
  unchanged (the new groups arrive in Phase 6).

---

### Phase 2: Core documentation and the metadata contract [COMPLETED]

**Goal**: `--gate` is documented wherever `--compare` is documented, and the advisory `gate`
metadata block has a schema a reader can follow without the design record.

**Tasks**:
- [x] `commands/orchestrate.md`: add a `--gate` Options row immediately after the `--compare` row,
      stating advisory-only, never blocking, never failing a dispatch, never downgrading status,
      composability, and that it never reaches research/plan dispatches. Add `--gate` to the
      `--hard` row's composable list. *(completed)*
- [x] `skills/skill-orchestrate/SKILL.md`: add `gate_flag` to the Setup field list and the
      parallel `$( [ "${gate_flag:-false}" = "true" ] && echo --gate )` line to Move 1's dispatch
      invocation. *(completed)*
- [x] `context/formats/return-metadata-file.md`: add a `### gate (optional)` section modelled on
      `### comparator (optional)`, with an explicit "Include if ... `gate_flag == true`; omitted
      entirely otherwise" clause, the JSON shape from the research report's Phase 3 sketch, and
      the advisory MUST-NOTs restated in the schema itself.
- [x] Deliberately do NOT add `--gate` to `docs/architecture/orchestrate-state-machine.md` or to
      the `argument-hint`; `--compare` is in neither, and mirroring exactly is the contract. *(completed)*

**Timing**: 45 minutes

**Depends on**: 1

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts 3 files and 5 edit sites, with the `comparator` schema
section as the template. Re-measured at plan time: `commands/orchestrate.md:46,52`;
`skill-orchestrate/SKILL.md:32,82`; `return-metadata-file.md` `### comparator (optional)` section.
Confirm by `grep -n 'compare'` on each of the three files before editing.

**Files to modify**:
- `agent-system/extensions/core/commands/orchestrate.md` - `--gate` Options row; `--hard`
  composability row
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - `gate_flag` in the Setup
  field list and the Move 1 forwarding line
- `agent-system/extensions/core/context/formats/return-metadata-file.md` - new
  `### gate (optional)` section

**Verification**:
- Diff read-through confirming every changed hunk is prose/table/schema text.
- The `--gate` row and the schema section each contain the literal advisory MUST-NOT language.
- No occurrence of the consuming repository's lint script name in any of the three files.
- Cross-check that the field name used in all three files is `gate_flag` (dispatch/delegation
  context) and `gate` (metadata block), matching Phase 1's emission exactly.

---

### Phase 3: The `books-gate.sh` wrapper [COMPLETED]

**Goal**: one extension-local script that resolves and runs the layer lint plus the import-closure
check, classifies five lint outcomes, detects vacuity, emits one JSON object, and always exits 0.

**Tasks**:
- [x] Write `agent-system/extensions/books/scripts/books-gate.sh`, modelled on
      `books-certify.sh`'s resolve-and-fail-loudly shape: resolve the repository root via
      `git rev-parse --show-toplevel` with a `pwd` fallback; accept `--json`, `--root DIR`, and a
      repeatable `--package-root DIR`. *(completed)*
- [x] Header comment stating the Rule E rationale explicitly (as `books-certify.sh`'s header
      does), that the script is advisory-only, and that it always exits 0 in that role. *(completed)*
- [x] Layer-lint leg: derive package roots (default `interface` plus every `components/*`
      containing a `lean/` subdirectory; never hardcode a component name), invoke the lint,
      classify into `pass`, `pass_vacuous`, `violations`, `lint_unavailable`, `rule_set_error`,
      `usage_error` — disambiguating exit 1 by matching `no queue model found` on stderr before
      treating it as violations, and exit 2 as a usage error. *(completed)*
- [x] Vacuity detection: source the real rule-set library **in a subshell** (it can `exit 1`
      during sourcing), count how many rules' file-halves match at least one discovered `.lean`
      path, and carry `rules_matched`/`rules_total`. Never copy the rules into the wrapper. *(completed)*
- [x] Import-closure leg: two predicates — no live `.lean` file carries a public import of the
      provider module (including the `public meta import` form), and the provider package declares
      no `require` — with `.lake/` **and `specs/`** pruned. Report `provider_absent` when the
      provider package is not present. *(completed)*
- [x] Emit the single JSON object (the research report's Phase 3 shape), `exit 0` unconditionally
      in advisory mode. *(completed)*
- [x] Declare `books-gate.sh` in `books/manifest.json` `provides.scripts` in the same commit. *(completed)*
- [ ] Add `books/index-entries.json` / `README.md` entries only if the existing convention for
      `books-certify.sh` requires them; check first rather than assuming. *(deviation: skipped — checked: index-entries.json carries no books-certify.sh entry, so the convention requires none; README.md is inside the concurrent sibling task's declared file_scope)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts that `provides.scripts` currently holds exactly two
entries (`books-certify.sh`, `tests/test-books-certify.sh`) and that `scripts/` holds exactly one
script plus one test. Re-measured at plan time and confirmed. Confirm at implementation time with
`jq '.provides.scripts' manifest.json` and `find scripts -type f` before editing, since the
sibling books task may have landed changes.

**Files to modify**:
- `agent-system/extensions/books/scripts/books-gate.sh` - new resolve-and-run advisory wrapper
- `agent-system/extensions/books/manifest.json` - declare `books-gate.sh` in `provides.scripts`

**Verification**:
- `bash -n` and `shellcheck` (if available) clean on the new script.
- Invoke with `--root` pointed at a directory with no lint script: `lint_unavailable`, exit 0.
- Invoke with `--root` pointed at the live consuming repository, if reachable: a well-formed JSON
  object, `jq -e .` clean, exit 0; record the observed statuses and runtime in the phase notes.
- `jq -e '.provides.scripts | index("books-gate.sh")' manifest.json` is non-null.
- No occurrence of the consuming repository's lint script name outside this script's own header
  comment (i.e. none in any of the five Rule-E-scanned doc locations).

---

### Phase 4: The `test-books-gate.sh` fixture suite [COMPLETED]

**Goal**: every classification branch and every pruning rule is pinned by a fixture, with a
forgery probe per predicate.

**Tasks**:
- [x] Write `agent-system/extensions/books/scripts/tests/test-books-gate.sh`, following
      `test-books-certify.sh`'s harness conventions (so `run-all.sh`'s glob discovery picks it up
      and Gate 8 runs it).
- [x] Case: lint script absent in the fixture root -> `lint_unavailable`, wrapper exit 0.
- [x] Case: a fixture root no rule's file-half can reach -> `pass_vacuous` with
      `rules_matched: 0`, never `pass`.
- [x] Case: a fixture root every rule reaches and no violation planted -> `pass` with
      `rules_matched == rules_total`.
- [x] Case: a fixture rule library that `exit 1`s on source -> `rule_set_error`, wrapper still
      exits 0 (and the wrapper's own shell survives, proving the subshell).
- [x] Case: lint invoked with an absent named root -> `usage_error`, wrapper exit 0.
- [x] Case: a planted public import of the provider -> exactly one closure violation, with the
      offending path reported.
- [x] Negative case: the same planted public import under a `specs/`-prefixed path -> **not** a
      violation.
- [x] Negative case: the same planted public import under a `.lake/`-prefixed path -> **not** a
      violation.
- [x] Case: provider package absent from the fixture -> `provider_absent`.
- [x] Case: a `require` line planted in the provider lakefile -> reported in
      `provider_require_lines`.
- [x] **Forgery probe per predicate**: for each predicate above, assert that the suite would
      actually fail if the predicate's check were removed or stubbed to a constant — a reviewable
      obligation here, following the forgery-probe discipline in the books context corpus
      (`context/project/books/standards/forgery-probe-discipline.md`) and the FORGE-cases in the
      consuming repository's own manifest suite that generalize it.
- [x] Declare `tests/test-books-gate.sh` in `books/manifest.json` `provides.scripts` by full
      relative path (Rule Q matches on full relative path, not basename), in the same commit.

**Timing**: 1.5 hours

**Depends on**: 3

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts 11 fixture cases plus one forgery probe per predicate.
The case list is derived from measured behaviours in the research report, not invented; confirm at
implementation time that each case's expected status string matches what Phase 3's wrapper
actually emits, and add a case for any branch Phase 3 introduced that this list omits rather than
leaving it uncovered.

**Files to modify**:
- `agent-system/extensions/books/scripts/tests/test-books-gate.sh` - new fixture suite
- `agent-system/extensions/books/manifest.json` - declare `tests/test-books-gate.sh` in
  `provides.scripts`

**Verification**:
- `bash agent-system/extensions/books/scripts/tests/test-books-gate.sh` passes, run directly
  against the source store.
- Every case listed above is present and asserted (count the assertions, do not assume).
- Each forgery probe demonstrably fails when its predicate is stubbed; record the demonstration in
  the phase notes.
- `jq -e '.provides.scripts | index("tests/test-books-gate.sh")' manifest.json` is non-null.

---

### Phase 5: Books agent and skill binding [COMPLETED]

**Goal**: an implement dispatch carrying `gate_flag: true` runs the gate in the agent and the
skill surfaces the finding read-only from metadata, with no status effect on any verdict.

**Tasks**:
- [x] `books-implementation-agent.md`: add a gate step to `### Stage 5: Final Verification`, with
      the gate condition as the step's **literal first line** (copying the lean agent's own
      wording for reading `gate_flag` from the delegation context), the invocation of
      `books-gate.sh --json`, the obligation to copy the result into `.return-meta.json`'s `gate`
      block, and the advisory MUST-NOTs stated **inside the step**.
- [x] `books-implementation-hard-agent.md`: the same step in its own `### Stage 5: Final
      Verification`.
- [x] `skill-books-implementation/SKILL.md`: add `gate_flag` to Stage 4's delegation context
      (forwarded unchanged, defaulting to `false` when absent) and to the Stage 5 bullet list; add
      a new read-only surfacing stage after Stage 6 (Parse Subagent Return), copied from the lean
      skill's Stage 6c **including its asymmetry note** and its absent-block INFO-line-and-proceed
      path. *(deviation: altered — neither books skill has a Stage 5 bullet list; `gate_flag` is
      threaded via Stage 4's delegation context, their only field list. New stage added as
      Stage 6d.)*
- [x] `skill-books-implementation-hard/SKILL.md`: the same three additions.
- [x] Books-awareness via plain backticked pointers only — `context/project/books/domain/gate-tiers.md`
      and `context/project/books/tools/certify-guide.md` — never eager imports, and write no file
      under `context/project/books/`.
- [x] Respect the postflight boundary: the gate runs in the agent and is only *read* from metadata
      by the skill. The skill must not invoke the wrapper, run a build, or grep source.
- [x] Name only `books-gate.sh` in these four files; never the consuming repository's lint script.

**Timing**: 1.5 hours

**Depends on**: 1, 3

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts 4 files and that each agent has a `### Stage 5: Final
Verification` heading and each skill a `### Stage 6: Parse Subagent Return` heading. Re-measured at
plan time: `books-implementation-agent.md:149`, `books-implementation-hard-agent.md:155`,
`skill-books-implementation/SKILL.md:53` (Stage 4) and `:78` (Stage 6),
`skill-books-implementation-hard/SKILL.md:102` and `:123`. Confirm by grepping the stage headings
before editing — the sibling books task may have shifted them.

**Files to modify**:
- `agent-system/extensions/books/agents/books-implementation-agent.md` - gate step in Stage 5
- `agent-system/extensions/books/agents/books-implementation-hard-agent.md` - gate step in Stage 5
- `agent-system/extensions/books/skills/skill-books-implementation/SKILL.md` - `gate_flag` in
  Stage 4 and the Stage 5 bullet list; new read-only surfacing stage after Stage 6
- `agent-system/extensions/books/skills/skill-books-implementation-hard/SKILL.md` - the same three
  additions

**Verification**:
- `bash .claude/scripts/check-extension-docs.sh` Rules E, Q and U pass (noting it reads the
  deployed tree; if the source store is not yet deployed, grep the four files directly for any
  bare `<name>.sh` token and confirm each is declared somewhere in `provides.scripts`).
- `books/EXTENSION.md` is untouched, or still at or under 60 lines if a one-line mention proved
  necessary.
- Each of the four files states the advisory MUST-NOTs inside the gate step/stage, not in a
  separate section.
- Both skills' new stage carries the asymmetry note verbatim in substance and the absent-block
  INFO path.
- `grep -rn` across the four files finds no occurrence of the consuming repository's lint script
  name and no file written under `context/project/books/`.

---

### Phase 6: Core test coverage [COMPLETED]

**Goal**: the one-added-line byte-identity property and the implement-only scoping are pinned by
tests in the core suites.

**Tasks**:
- [x] `test-orchestrate-build-dispatch.sh`: add a new group modelled on the existing `--compare`
      group, asserting that a `--gate` dispatch file differs from the no-flag dispatch file by
      exactly one added line (`- gate_flag: true`), and asserting the script under test's
      deliberate phase-agnosticism (it records whatever it is told).
- [x] `test-orchestrate-cycle-plan.sh`: add a new group modelled on the existing `--compare`
      forwarding group, asserting forwarding for an implement candidate, **non**-forwarding for a
      plan candidate and for a research candidate, and `--gate --compare --hard` composition.
- [x] Use the next free group number in each suite; do not renumber existing groups.

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts the next free group number in each suite (the research
report measured Group 17 for the dispatch suite and Group 35 for the cycle-plan suite). Confirm at
implementation time by grepping the group headers in each suite — the numbers may have moved if
another task added a group.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh` - new `--gate`
  group
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` - new `--gate`
  forwarding group

**Verification**:
- Both suites pass, run directly against the source store.
- The new groups fail when Phase 1's forwarding guard is temporarily inverted (demonstrating the
  tests actually bind the behaviour, not just the flag's presence).
- No existing group was renumbered or modified.

---

## Testing & Validation

- [x] `bash -n` clean on all four edited/added shell scripts plus the new wrapper and its suite. *(completed: 7 scripts, all clean; `shellcheck` unavailable on this machine, exit 127)*
- [x] `bash agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh` passes,
      including the new group. *(completed: 131 passed / 0 failed, up from 124/0)*
- [x] `bash agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` passes,
      including the new group. *(completed: 349 passed / 0 failed, up from 344/0)*
- [x] `bash agent-system/extensions/books/scripts/tests/test-books-gate.sh` passes. *(completed: 44 passed / 0 failed)*
- [x] `bash agent-system/extensions/books/scripts/tests/test-books-certify.sh` still passes
      (regression check on the shared manifest edit). *(completed: 9 passed / 0 failed)*
- [x] A no-flag implement dispatch file is byte-identical to one built before this work (the
      byte-identity invariant). *(completed: Group 17 asserts `gate_flag:` absent without the flag and exactly one added line with it)*
- [x] `--gate` never appears in a research or plan dispatch file. *(completed: Group 35 asserts non-forwarding for both a plan and a research candidate, with non-vacuity guards; inverting the guard makes 4 assertions fail)*
- [x] `--gate` in a focus-prompt position does not leak into `FOCUS_PROMPT`. *(completed: `326 --gate do the thing` yields `GATE_FLAG=true`, `FOCUS_PROMPT="do the thing"`)*
- [x] `--gate --compare --hard --lit` compose without interference. *(completed: all four parsed, `FOCUS_PROMPT` empty; Group 35 additionally asserts all three of `--gate --compare --hard` reach the implement dispatch)*
- [x] `bash .claude/scripts/check-extension-docs.sh` (Rules E, Q, U) — noting it reads the
      **deployed** `.claude/` tree, so a source-store-only change is invisible to it until a
      regeneration; run it after any redeploy and, in the meantime, verify Rules E and Q by direct
      grep against the source store. *(completed: core Rule R repaired (return-metadata-file.md 772 -> 842); remaining core FAILs are deploy-content drift from the three edited scripts, resolved by a redeploy; the books Rule R FAIL on `project/books/README.md` belongs to the concurrent sibling task, not this work; Rule E verified by direct grep — the only `.sh` token added to any scanned doc location is `books-gate.sh`, now declared; Rule U: `EXTENSION.md` untouched at 52 lines)*
- [x] `bash .claude/scripts/tests/run-all.sh` — same deployed-tree caveat; the new books suite is
      discovered by glob, so confirm a non-zero discovered-suite count. *(completed: 107 suites discovered, 100 passed / 6 failed (3 expected) / 1 skipped. None of the 6 reference `--gate`/`gate_flag`/`books-gate.sh`, and `test-lint-deploy-caller-wrap.sh` was reproduced failing identically against the pre-change `orchestrate-cycle-plan.sh`, confirming it is pre-existing)*
- [x] `bash .claude/scripts/check-task-references.sh` (or equivalent) confirms no task-number
      reference landed in any source-store file. *(completed: PASS, 0 unexempted occurrences)*

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/parse-command-args.sh` (modified)
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` (modified)
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` (modified)
- `agent-system/extensions/core/commands/orchestrate.md` (modified)
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (modified)
- `agent-system/extensions/core/context/formats/return-metadata-file.md` (modified)
- `agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh` (modified)
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` (modified)
- `agent-system/extensions/books/scripts/books-gate.sh` (new)
- `agent-system/extensions/books/scripts/tests/test-books-gate.sh` (new)
- `agent-system/extensions/books/manifest.json` (modified — two `provides.scripts` entries)
- `agent-system/extensions/books/agents/books-implementation-agent.md` (modified)
- `agent-system/extensions/books/agents/books-implementation-hard-agent.md` (modified)
- `agent-system/extensions/books/skills/skill-books-implementation/SKILL.md` (modified)
- `agent-system/extensions/books/skills/skill-books-implementation-hard/SKILL.md` (modified)
- `specs/326_books_verification_tier_at_implement_dispatch/summaries/01_gate-flag-verification-tier-summary.md`
  (new) — must state the redeploy requirement, the promotion-to-hard-gate criteria, and the
  substring-regex detector hazard

## Rollback/Contingency

Every phase is independently revertible and every edit is additive: no existing line is removed
and no existing behaviour is modified. The flag is inert when absent — a no-flag dispatch is
byte-identical to one built before this work — so a partially landed implementation degrades to
"the flag does nothing", never to a broken dispatch path.

- **Per-phase**: each phase commits its own scoped hunks, so `git revert` of a single phase commit
  restores the prior state without touching the others.
- **Phase 1 or 6 regression**: revert that commit; the remaining books-side work is dormant
  because no dispatch ever carries `gate_flag`.
- **Phase 3 or 4 regression**: revert both the script and its `provides.scripts` declaration
  together, or Rule Q fails on an undeclared file (or an absent declared one).
- **Phase 5 regression**: revert the four doc files; the wrapper remains on disk and declared,
  which is harmless and Rule-Q-clean.
- **If uncommitted work must be discarded**: this is a genuine rollback scenario, so use the
  snapshot-then-rollback recipe in `context/contracts/recovery.md`'s rollback rung for the exact
  invocation shape (including its out-of-scope override flag). Do **not** emit a bare reverting
  snapshot as a routine start-of-phase precaution; for an ordinary defensive checkpoint before
  risky work use the durable non-reverting checkpoint form instead.
- **Concurrency caution**: a sibling task is live on `agent-system/extensions/books/**` in this
  same working tree. Never roll back with a directory-wide or whole-tree discard; revert by commit
  only, and if a foreign commit or foreign uncommitted modification appears, stop and report it
  after checking `git log` to confirm the work is not this task's own.
