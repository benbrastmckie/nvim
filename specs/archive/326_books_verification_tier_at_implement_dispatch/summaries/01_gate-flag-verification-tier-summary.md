# Implementation Summary: Task #326

- **Task**: 326 - Add an advisory `--gate` verification tier at implement dispatch
- **Status**: [COMPLETED]
- **Started**: 2026-10-03T19:40:00Z
- **Completed**: 2026-10-03T20:35:00Z
- **Effort**: ~55 minutes
- **Dependencies**: None blocking. Sibling-in-flight (territory only): the books domain context
  corpus task, which owns `agent-system/extensions/books/context/project/books/**`. The
  extension lifecycle hook mechanism repair task was deliberately not a dependency.
- **Artifacts**: plans/01_gate-flag-verification-tier.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Added an advisory-only `--gate` flag to `/orchestrate` that, at implement dispatch only, surfaces
a cheap intermediate verification tier between `lake build` and the ten-minute fail-closed full
gate: the consuming repository's regex layer-import lint plus a `Books.Meta` import-closure check.
The flag is threaded through the same surface the existing `--compare` flag occupies, binds in the
books extension's implementation agents and skills, and is backed by a new extension-local
resolve-and-run wrapper that emits one JSON object and always exits 0. All six plan phases are
`[COMPLETED]`; the flag never blocks a dispatch, never fails one, and never downgrades status.

## What Changed

- `agent-system/extensions/core/scripts/parse-command-args.sh` — `GATE_FLAG` at five sites: the
  header doc-comment paragraph, the `GATE_FLAG="false"` initializer, the `--gate` detector arm,
  the `sed 's/--gate//g'` entry in the `FOCUS_PROMPT` strip chain, and the `export` list. The
  last two are the sites the task description omitted; without the strip, `--gate` leaks into
  focus-prompt text.
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` — `gate_flag` at six sites,
  including the implement-scoped forwarding guard
  `[ "$gate_flag" = "true" ] && [ "$g" = "implement" ] && build_args+=(--gate)` placed
  immediately adjacent to the `--compare` one. `build_args` is composed at exactly one site, so
  there is no second forwarding path to keep in sync.
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` — `gate_flag` at six
  sites, including the conditional one-line `echo "- gate_flag: true"` emission in the Identity
  section. The conditional is what preserves the byte-identity invariant.
- `agent-system/extensions/core/commands/orchestrate.md` — a `--gate` Options row immediately
  after the `--compare` row, and `--gate` added to the `--hard` row's composable list.
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — `gate_flag` in the Setup
  field list and the parallel `$( [ "${gate_flag:-false}" = "true" ] && echo --gate )` line in
  Move 1's dispatch invocation.
- `agent-system/extensions/core/context/formats/return-metadata-file.md` — a new
  `### gate (optional)` section modelled on `### comparator (optional)`: the Include-if clause,
  the full field tables for `layer_lint` and `books_meta_closure`, the closed six-value
  `layer_lint.status` vocabulary, and the advisory MUST-NOTs restated in the schema itself.
- `agent-system/extensions/core/index-entries.json` — `line_count` for
  `formats/return-metadata-file.md` corrected 772 to 842 (a surgical one-line edit, not the
  global `--write`, which would also have rewritten the sibling-owned books index-entries file).
- `agent-system/extensions/books/scripts/books-gate.sh` — **new**. A resolve-and-run advisory
  wrapper: `--json`, `--root DIR`, repeatable `--package-root DIR`; derived package roots
  (`interface` plus every `components/*` holding a `lean/` subdirectory, never a hardcoded
  component name); six-way layer-lint classification; vacuity detection by sourcing the real rule
  set in a subshell; the two import-closure predicates with `.lake/` and `specs/` pruned; one
  JSON object on stdout; `exit 0` unconditionally in the advisory role.
- `agent-system/extensions/books/scripts/tests/test-books-gate.sh` — **new**. 44 assertions
  across every classification branch, both pruning rules, the derivation rule, and seven forgery
  probes (one per predicate).
- `agent-system/extensions/books/manifest.json` — `books-gate.sh` and
  `tests/test-books-gate.sh` declared in `provides.scripts` (Rule Q matches full relative path).
- `agent-system/extensions/books/agents/books-implementation-agent.md` and
  `books-implementation-hard-agent.md` — a gate step appended to `### Stage 5: Final
  Verification`, with the gate condition as the step's literal first line and the advisory
  MUST-NOTs stated inside the step.
- `agent-system/extensions/books/skills/skill-books-implementation/SKILL.md` and
  `skill-books-implementation-hard/SKILL.md` — `gate_flag` in Stage 4's delegation context
  (forwarded unchanged, defaulting to `false`), and a new read-only `### Stage 6d: Advisory Gate
  Tier Surface (Read from Metadata)` after Stage 6, carrying the asymmetry note and the
  absent-block INFO-line-and-proceed path.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh` — new Group 17
  (66 insertions, 0 deletions).
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` — new Group 35
  (146 insertions, 0 deletions).

## Decisions

- **The mechanism decision was not re-derived.** The `skill-base.sh` `verification` lifecycle hook
  was already investigated and rejected for three stacked, independently fatal defects. This work
  uses the live route and needs none of those repairs.
- **A vacuous pass is a first-class status, never collapsed into `pass`.** The lint's `[ok]` line
  reports module and import counts but never rule applicability. `pass_vacuous` travels with
  `rules_matched`/`rules_total`, derived by sourcing the real rule set — never by copying rules
  into the wrapper. Measured live: a `books` package root matches 0 of 9 rules and still exits 0.
- **Lint exit 1 is ambiguous and is classified on stderr before being read as violations.** The
  rule-set library `exit 1`s while being sourced when its queue-model derivation yields nothing,
  terminating the lint with the same code a real violation produces. `rule_set_error` is reported
  distinctly, and the library is sourced in a **subshell** so that exit cannot kill the wrapper.
- **`specs/` is pruned alongside `.lake/`.** Two archived prototype sources under `specs/archive/`
  carry the public provider import and would otherwise be reported as live violations on the
  gate's very first run.
- **A new extension-local wrapper was mechanically required, not preferred.**
  `check-extension-docs.sh` Rule E hard-fails on any bare `<name>.sh` token in an extension's
  `commands/*.md`, `skills/*/SKILL.md`, `agents/*.md`, `README.md` or `EXTENSION.md` that no
  extension declares, and the consuming repository's lint can never be declared. Only
  `books-gate.sh` is named in those five locations; the consuming repository's script names
  appear solely in the wrapper's own header, which Rule E does not scan.
- **`--gate` is not documented in `docs/architecture/orchestrate-state-machine.md` or in the
  `argument-hint`.** `--compare` is in neither, and mirroring exactly was the contract.
- **No file was written under `agent-system/extensions/books/context/project/books/`.**
  Books-awareness reaches the gate through plain backticked pointers to
  `context/project/books/domain/gate-tiers.md` and `context/project/books/tools/certify-guide.md`.

## Plan Deviations

- **Task 3.7** skipped: add `books/index-entries.json` / `README.md` entries only if the existing
  convention for `books-certify.sh` requires them. Checked first: `index-entries.json` carries no
  entry for `books-certify.sh`, so the convention requires none. `README.md`'s only mentions are a
  directory-tree gloss and `/certify` command rows, and `README.md` is inside the concurrent
  sibling task's declared `file_scope`, so it is deliberately left untouched.
- **Task 5.3** altered: "add `gate_flag` to the Stage 5 bullet list". Neither books skill has a
  bullet list at Stage 5 — Stage 5 is a one-line Agent-tool invocation. `gate_flag` is threaded in
  Stage 4's delegation context, the only field list these skills carry. The new surfacing stage
  was added as Stage 6d.

## Verification

- Build: N/A (no compiled artifact). `bash -n` clean on all seven edited/added shell scripts.
  `shellcheck` is unavailable on this machine (binary missing from its nix store path, exit 127).
- Tests:
  - `test-orchestrate-build-dispatch.sh`: 131 passed / 0 failed (was 124/0).
  - `test-orchestrate-cycle-plan.sh`: 349 passed / 0 failed (was 344/0).
  - `test-books-gate.sh`: 44 passed / 0 failed.
  - `test-books-certify.sh`: 9 passed / 0 failed (regression check on the shared manifest edit).
  - `run-all.sh`: 107 suites discovered, 100 passed / 6 failed (3 expected) / 1 skipped. None of
    the six reference `--gate`, `gate_flag` or `books-gate.sh`, and
    `test-lint-deploy-caller-wrap.sh` was reproduced failing **identically** against the
    pre-change `orchestrate-cycle-plan.sh`, confirming it is pre-existing rather than caused here.
  - `check-task-references.sh`: PASS, 0 unexempted occurrences.
- **Tests demonstrably bind the behaviour, not the flag's mere presence**: inverting the
  implement-only forwarding guard makes 4 Group 35 assertions fail; inverting the dispatch-file
  emission condition makes 6 Group 17 assertions fail. Both inversions were reverted and the
  files confirmed byte-identical to their committed state.
- **Forgery probes**: each of the seven predicates, with its input forged, demonstrably produces
  a different result than the real case expects — printed in the suite's own output (for example
  the vacuity probe yields `pass` where the real case requires `pass_vacuous`; the `specs/`-pruning
  probe yields `violations` where the real case requires `pass`).
- **Live run against the reachable consuming repository**: `layer_lint.status: pass`,
  `rules_matched: 9` of 9, `modules: 179`, `imports: 733`; `books_meta_closure.status: pass`,
  `private_import_sites: 214`, `provider_require_lines: 0` — matching the research baseline
  exactly. 3.167 s wall clock, `jq -e .` clean, exit 0.
- Files verified: Yes.

## Impacts

- **A `core` redeploy is required for `--gate` to exist at all.** Every edit in this work landed
  in the source store (`agent-system/extensions/core/` and `agent-system/extensions/books/`), and
  a consuming repository's `.claude/` tree is a disposable deploy artifact regenerated through the
  loader picker. Until that regeneration happens, `--gate` is not a recognized flag in any
  consuming repository, the new wrapper is not on disk there, and the verification gates — which
  read the **deployed** tree — cannot see any of this. `check-extension-docs.sh` already reports
  deploy-content drift for the three edited core scripts for exactly this reason; that drift
  resolves on redeploy and is not a defect.
- **Enabling the books extension in a consuming repository's `.claude-extensions.json` is the
  user's own action, not this work's.** Nothing here enables it anywhere.
- No existing gate was weakened, shortcut or quietened. This work ADDS a cheap intermediate tier
  below the existing fail-closed one. Every existing gate remains fail-closed by design.
- A no-flag dispatch file is byte-identical to one built before this work, so a consuming
  repository that never passes `--gate` sees no behavioural change at all.

## Follow-ups

- **Promotion-to-hard-gate criteria** (recorded here so a later decision to promote this tier from
  advisory to blocking has evidence rather than vibes): N consecutive clean **non-vacuous** runs
  (`layer_lint.status == pass` with `rules_matched == rules_total`, and
  `books_meta_closure.status == pass`) across M distinct package roots, with **zero**
  `lint_unavailable`, `rule_set_error` or `usage_error` outcomes in that window, plus a measured
  p95 runtime under an agreed budget. The one live measurement available today is a single
  non-vacuous clean run at 3.167 s wall clock — one data point, not a window.
- **The `--gate` detector is a substring regex**, `[[ "$remaining" =~ --gate ]]`, and the strip is
  `sed 's/--gate//g'`. A focus prompt containing the literal flag text would false-positive, and a
  hypothetical `--gate-strict` sibling would be mangled by the strip. This is a pre-existing
  hazard shared by every flag in that parser, not one introduced here. Do not introduce any
  `--gate-*` sibling flag while the detector has this shape.
- **`--gate` is a deliberately risky name**: this codebase uses "gate" pervasively in the
  fail-closed sense (GATE IN/GATE OUT, the gate-out script, the stage-gates script, the full
  gate), so a reader may reasonably expect `--gate` to block. The name was mandated, and the
  mitigation is prose at four layers — the Options row, the dispatch contract comment, the
  `### gate (optional)` schema section, and both agent steps and both skill stages, each stating
  the advisory MUST-NOTs **inside** the step so a later editor cannot fold it into a
  failure enumeration. A future rename would be the cleaner fix.
- **Two observations reported, not acted on** (see the Observation Duty note below): the
  `project/books/README.md` Rule R `line_count` mismatch belongs to the concurrent sibling task
  and was left alone; and the Phase 5 commit of `agent-system/extensions/core/index-entries.json`
  unavoidably carried three pre-existing uncommitted `line_count` corrections that were already
  in the working tree at this dispatch's start (path-scoped committing stages by path, not by
  hunk). Those three are correct repairs that `check-extension-docs.sh` Rule R demands, so they
  were not reverted.
- The `--gate` tier currently runs over **derived** package roots rather than intersected with the
  task's own touched `.lean` paths. The research report's Decision 7 allows that intersection when
  the agent can determine those paths; the wrapper accepts `--package-root` for exactly this, and
  an agent that knows its touched paths may narrow the run. No caller does so yet.

## References

- `specs/326_books_verification_tier_at_implement_dispatch/plans/01_gate-flag-verification-tier.md`
- `specs/326_books_verification_tier_at_implement_dispatch/reports/01_gate-flag-verification-tier.md`
- `agent-system/extensions/core/context/formats/return-metadata-file.md` (`### gate (optional)`)
- `agent-system/extensions/books/scripts/books-gate.sh` (the wrapper's own header carries the
  Rule E rationale and names the consuming repository's scripts, which Rule E does not scan)
- `.claude/rules/source-store-deploy-boundary.md`
