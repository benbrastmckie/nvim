# Implementation Plan: Task #434

- **Task**: 434 - Add a self-updating lint for actionable recommendations naming a command with no definition file, and drive the dead lifecycle-command recommendation lines to zero
- **Status**: [IMPLEMENTING]
- **Effort**: 8 hours
- **Dependencies**: None (the companion prose-sweep task carries the edge onto this one, not the reverse)
- **Research Inputs**: specs/434_lint_and_fix_actionable_dead_command_references/reports/01_lint-and-fix-dead-command-references.md
- **Artifacts**: plans/01_lint-dead-command-recommendations.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Build one new lint (`lint-dead-command-recommendations.sh`) that derives its valid-command set by
enumerating `agent-system/extensions/*/commands/*.md` at run time — so it self-updates and needs
no hardcoded allowlist — and flags any literal `Next: /X` / `Run /X` recommendation line naming a
command with no definition file. The lint is written FIRST, deliberately red, and its own output
is the authoritative worklist for the fix: 188 lines across 92 files in 12 extensions (independent
grep, 2026-10-17). The fix then runs extension-group by extension-group, retargeting every such
line onto `/orchestrate` (the only lifecycle driver that exists), plus a separate structural fix
to `core/context/formats/command-output.md`, whose "Assigned Commands" lines and Template
Assignment Table rows must be remapped or deleted rather than string-substituted. The final phase
wires the now-green lint into `verify-deploy.sh` as gate 24 with a `gate-registry.data` row and
redeploys to `RESULT=landed_verify_clean`.

### Research Integration

Findings carried directly into the phases below:

- **A new lint file is warranted** (NET-SIZE requirement discharged in writing). Research read
  both candidate hosts in full source: `lint-routing-wiring.sh` (288 lines) operates purely on
  `manifest.json` `routing_agents` keys plus agent-file existence via jq — it never enumerates
  `commands/*.md` and its manifest-keyed detection model is incompatible with a line-oriented
  full-corpus text scan; `lint-contract-compliance.sh` (448 lines) is scoped to hard-mode
  behavioral contracts. Neither is a natural host. The additive cost is held down instead by
  reusing `lint-corpus-scan-lib.sh` for the file-collection and flag-parsing layers rather than
  reimplementing them.
- **Scope must be the full corpus, not the executable-surface subset.**
  `core/context/patterns/adoption-lint-conventions.md` states that an adoption lint's scope is
  `scripts/*.sh` plus `*.md` restricted to `commands/`, `skills/`, `agents/`, with `docs/`,
  `context/`, `rules/` out of scope "by construction." This lint is a different class — an
  actionable recommendation line IS the defect wherever it is rendered — and 18 of the 92 hit
  files live under `context/` (14) and `docs/` (4), including sites the task description names
  explicitly. Only that doc's dual-mode-root-resolution requirement transfers.
- **Zero-tolerance, no allowlist**, per that same doc's own decision rule: debt retired to zero
  within the same landing event selects zero-tolerance; the allowlist convention exists for debt
  retired incrementally across future tasks.
- **Scan scope must include `*.json`**, not only `*.md`: one hit is an embedded example string in
  `core/context/schemas/errors-schema.json`.
- **Valid-command enumeration verified**: raw enumeration of `*/commands/*.md` yields 47 unique
  basenames; excluding `README` (case-insensitively, the safer general rule) yields exactly the 46
  real commands. `agent-system/extensions/core/commands/README.md` is the one real-world
  non-command file.
- **Gate wiring is mandatory, not incidental**: gates run 1-23 today with no gaps, so this is gate
  24. Every lint meant to run in CI has both a `gateN_run()` function and a `gate-registry.data`
  row; an ungated lint provides no regression protection.
- **The fixture suite needs no registration**: `scripts/tests/run-all.sh` glob-discovers every
  `scripts/tests/test-*.sh` per extension. Suite basenames include the `.sh` suffix.
- **Sub-class B is confined to one file**: the only two files referencing `command-output.md`
  (`index-entries.json`, `context/standards/interactive-selection.md`) do so by prose
  cross-reference; neither parses the Assigned-Commands lines or the table programmatically.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No roadmap context was provided to this dispatch.

## Goals & Non-Goals

**Goals**:
- A lint that flags a literal `Next: /X` / `Run /X` recommendation naming a command with no
  definition file, deriving its valid-command set by enumeration so it self-updates when a command
  is added or removed.
- That lint running green over the whole source store, wired as gate 24 with a fixture suite that
  includes a deliberately-violating fixture proving it fires.
- Every sub-class (A) literal recommendation line retargeted onto `/orchestrate`.
- Sub-class (B)'s template assignments in `command-output.md` structurally corrected (rows deleted
  or remapped onto commands that exist), not string-substituted.
- `deploy-headless.sh` reaching `RESULT=landed_verify_clean` after the source-store edits land.

**Non-Goals**:
- Phase-versus-command prose and architectural/dispatch-model references — owned by the companion
  prose-sweep task, which carries the dependency edge onto this one.
- Any edit under a deployed `.claude/**` tree. `.claude/` is a gitignored, disposable deploy
  artifact; every edit lands under `agent-system/extensions/**` and reaches `.claude/` only via
  redeploy.
- An addendum to `adoption-lint-conventions.md` distinguishing lint classes (research flagged it;
  explicitly deferred).
- Inventing a replacement command. `/orchestrate` is the only lifecycle driver that exists.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The lint's regex over- or under-matches relative to the description's 187 figure (independent grep found 188) | M | H | Design the regex against the description's own worked examples first, then treat any count differing from 187-188 as a cue to inspect specific false positives/negatives — not as a figure to force-match. Both counts enumerate the same defect class; line-for-line agreement across regex dialects is not required. Record the reconciliation in the phase's notes. |
| A bare `*.json` scan picks up incidental `/plan`-like filesystem paths | M | M | Anchor the regex on the `Next:`/`Run`-prefixed recommendation shape, never a bare command-name substring. Verify with `--verbose` that no JSON hit is a path. |
| Blanket find-and-replace across the 360-file union (explicitly FORBIDDEN) | H | M | The fix phases are driven by the lint's own `file:line` output, line by line. Sub-class B is a separate phase with no string substitution at all. |
| Concurrent dispatches touching `verify-deploy.sh` / `gate-registry.data` (shared contended files) | M | M | Confine the gate wiring to its own final phase and its own narrow commit scope; check `git status --short` on both files before editing, per `git-staging-scope.md`. |
| Task-number or record-versioning language leaking into `agent-system/**` | M | M | Both are forbidden outside `specs/**`. Gate 4 (task-reference lint) catches the former; review every new header comment for the latter before committing. |
| Landing the lint pre-wired into gate 24 while still red would break `verify-deploy.sh` for every other dispatch | H | M | Gate wiring is deliberately deferred to the final phase, which runs only after the lint is confirmed green. Phases 1-6 leave the lint standalone and ungated. |
| A naive regex misses the JSON-string recommendation shape (`"Run /plan to create..."` inside a JSON value) and `deck-builder-agent.md`'s bare `Run /plan first.` | M | M | Both shapes are named as explicit must-catch cases in Phase 1's task list and asserted in the Phase 2 fixture suite. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 3 | -- |
| 2 | 2, 4, 5, 6 | 1 (and 3, for phase 4) |
| 3 | 7 | 2, 3, 4, 5, 6 |

Phases within the same wave can execute in parallel. Phases 4, 5 and 6 partition the corpus by
extension and touch disjoint file sets; phase 4's edge onto phase 3 serializes the two `core`
territory edits so their commit scopes never collide (`command-output.md` carries no sub-class A
line, so the file sets are disjoint even so — the edge is commit-scope hygiene, not a content
dependency).

**Edit target for every phase**: the source store, `agent-system/extensions/**`. Never a deployed
`.claude/**` path. No task-number references and no record-versioning language in any file landing
under `agent-system/**`.

### Phase 1: Write the dead-command-recommendation lint (expected red) [COMPLETED]

**Goal**: A standalone, ungated lint at
`agent-system/extensions/core/scripts/lint/lint-dead-command-recommendations.sh` that enumerates
the valid-command set at run time and reports every literal recommendation line naming a command
with no definition file. Its red output becomes the worklist for phases 4-6.

**Tasks**:
- [x] Create the script with the cluster's standard header: purpose, exit-code convention
      (`0` clean / `1` violations / `2` environment-or-usage error), `Usage:
      lint-dead-command-recommendations.sh [--verbose] [--quiet] [path...]`. *(completed)*
- [x] Implement the dual-mode root-resolution probe (`resolve_project_root()` walking up from
      `SCRIPT_DIR` until `agent-system/extensions` is found, falling back to `common_repo_root`),
      copied in shape from a sibling lint so the script runs from the source store or a deployed
      tree. *(completed: copied from lint-state-writer-boundary.sh/lint-task-lookup-adoption.sh)*
- [x] Build the valid-command set by enumerating `"$EXT_ROOT"/*/commands/*.md` at `-maxdepth 1`,
      excluding `-iname 'readme.md'`, stripping `.md`, `sort -u`. No hardcoded command list
      anywhere in the file. Exit `2` if the enumeration yields an empty set (wrong root).
      *(completed: implemented as `collect_commands_from_root`, additively run over the real
      extensions root plus every explicit directory scan-path argument, so the fixture suite's
      self-updating-behavior case can introduce a synthetic command without editing this script)*
- [x] Collect files via `lint_corpus_scan_collect_files` with patterns `*.md` and `*.json` and a
      default scan root of `$REPO_ROOT/agent-system/extensions`, and parse flags via
      `lint_corpus_scan_parse_flags`. Do not reimplement either layer. *(completed)*
- [x] Implement the line classifier: a literal `Next: /X` or `Run /X` recommendation shape,
      tolerant of backticks and markdown emphasis around the command name and of a following
      `{N}`/argument, anchored on the `Next`/`Run` keyword rather than a bare command-name
      substring. Must catch all three observed shapes: the `Next: /implement {N}` form, the bare
      prose form (`deck-builder-agent.md`'s `Run /plan first.`), and the JSON-value form
      (`analyze-agent.md`'s `"Run /plan to create..."`, and the `next_steps` string in
      `core/context/schemas/errors-schema.json`). *(completed: all three shapes confirmed caught
      by live run — see worklist)*
- [x] Emit each finding as a `[VIOLATION]`-tagged line carrying `file:line` plus the offending
      command name, so `verify-deploy.sh`'s `FINDINGS_LIST` can key on it in phase 7. Under
      `--verbose`, also report every candidate line that was NOT flagged, with the reason.
      *(completed)*
- [x] Write the NET-SIZE rationale into the script header in one short paragraph: why neither
      `lint-routing-wiring.sh` (manifest-keyed, never enumerates `commands/*.md`) nor
      `lint-contract-compliance.sh` (hard-mode-contract-scoped) is a natural host, and why the
      scope is the full corpus rather than the executable-surface subset
      `adoption-lint-conventions.md` prescribes for its own lint class. Zero-tolerance, no
      allowlist. *(completed)*
- [x] Run the lint over the source store. Confirm it exits `1`. Capture the full finding list to a
      scratch worklist file for phases 4-6 and reconcile its count against the 187/188 figures,
      inspecting any disagreement rather than tuning the regex to hit a number. *(completed: live
      run exits 1 with exactly 188 violations across 92 files — matches the Overview's figure and
      the per-extension distribution in Phases 4-6's own scope hypotheses exactly: founder 102,
      core 42, present 27, formal 4, cslib 3, web 2, literature 2, lean 2, nvim 1, nix 1,
      epidemiology 1, books 1. 187 of the 188 name implement/research/plan; the 188th is
      command-output.md:458's literal `/cmd` placeholder token, a legitimate sub-class A hit under
      the same shape, deferred to Phase 4. Worklist captured at
      specs/434_lint_and_fix_actionable_dead_command_references/progress/phase1-lint-worklist.txt)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: The new script is standalone and sourced by nothing yet, so its blast
radius is one file; `bash -n agent-system/extensions/core/scripts/lint/lint-dead-command-recommendations.sh`
plus `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh agent-system/extensions/core/scripts/lint/lint-dead-command-recommendations.sh`
covers it.

**Scope Hypothesis**: This phase asserts the lint will report 187-188 findings across ~92 files in
12 extensions. That is a hypothesis from an independent grep, not a fact: confirm it by running
the lint and recording the actual figure, and investigate any material divergence (false positives
from the `*.json` scan, or missed shapes) before proceeding.

**Files to modify**:
- `agent-system/extensions/core/scripts/lint/lint-dead-command-recommendations.sh` - new file, the
  lint itself.

**Verification**:
- `bash -n` on the new script is clean.
- `lint-shellcheck.sh <new script>` is clean.
- The lint exits `1` over the source store and its `[VIOLATION]` lines carry resolvable
  `file:line` references (spot-check three against the files).
- Running the lint with an explicit path argument naming one known-clean file
  (`agent-system/extensions/core/commands/revise.md`, fixed by an earlier commit) exits `0`.
- `grep -n '/orchestrate\|analyze\|approve' <new script>` shows no hardcoded command-name
  allowlist.

---

### Phase 2: Fixture suite proving the lint fires [COMPLETED]

**Goal**: A fixture suite at
`agent-system/extensions/core/scripts/tests/test-lint-dead-command-recommendations.sh` that proves
the lint fires on a planted offender and, separately, that the valid-command enumeration (not just
the regex) drives the verdict.

**Tasks**:
- [x] Create the suite modeled on `test-lint-task-lookup-adoption.sh`: `common_test_workdir_init`
      for the `mktemp -d` scratch workdir, `common_test_resolve_candidate` for deploy-tree-first /
      source-store-fallback script resolution, and `common_test_pass`/`common_test_fail`/
      `common_test_info` for reporting. *(completed)*
- [x] Case 1 (acceptance criterion, the deliberately-violating fixture): plant a synthetic file
      naming a command that has no definition file; assert the lint exits non-zero AND names the
      exact `file:line`. *(completed)*
- [x] Case 2 (negative, proves enumeration drives the verdict): plant the same recommendation
      shape naming a REAL command (`/orchestrate`); assert it is NOT flagged and the lint exits
      `0`. *(completed)*
- [x] Case 3 (self-updating behavior): in the scratch tree, plant a fixture `commands/` directory
      containing a definition file for an otherwise-unknown command name, and assert a
      recommendation naming it is then NOT flagged — proving the set is derived, not hardcoded.
      *(completed)*
- [x] Case 4 (shape coverage): assert the JSON-value form and the bare-prose form are both caught.
      *(completed)*
- [x] Case 5 (`README` exclusion): assert a recommendation naming `/README` IS flagged, proving
      `commands/README.md` is excluded from the valid set. *(completed)*
- [x] Confirm `run-all.sh` glob-discovers the suite with no registration edit anywhere.
      *(completed: `run-all.sh --only test-lint-dead-command-recommendations.sh` discovers and
      passes it)*

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: The edit adds one self-contained test file whose only consumer is
`run-all.sh`'s glob, and `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-lint-dead-command-recommendations.sh`
covers it exactly.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-lint-dead-command-recommendations.sh` - new
  file, the fixture suite.

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-lint-dead-command-recommendations.sh`
  exits `0` with every case reported passing (the suite is green even while the real corpus is
  still red — the suite asserts lint behavior on synthetic fixtures, not corpus cleanliness).
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-lint-dead-command-recommendations.sh`
  discovers and runs it without an "unknown suite basename" refusal.
- `lint-shellcheck.sh <new suite>` is clean.

---

### Phase 3: Structural fix to command-output.md's template assignments [COMPLETED]

**Goal**: `core/context/formats/command-output.md` no longer assigns output templates to commands
that do not exist. This is a structural change (rows deleted or remapped), never a string
substitution.

**Tasks**:
- [x] Read the file's Template A / Template B / Template C sections and the Template Assignment
      Table in full before editing. The four known sites are the `**Assigned Commands:**` lines at
      lines 80 (`/research`, `/plan`, `/task`) and 110 (`/implement`, `/revise`, `/errors`), and
      the table rows at lines 163 (`/research`), 164 (`/plan`) and 166 (`/implement`). Re-locate
      them by content, not line number. *(completed)*
- [x] Remove `/research` and `/plan` from line 80's Assigned Commands, keeping `/task`. Remove
      `/implement` from line 110's, keeping `/revise` and `/errors`. *(completed)*
- [x] Delete the `/research`, `/plan` and `/implement` rows from the Template Assignment Table.
      *(completed)*
- [x] Decide and record, in the file itself, whether `/orchestrate` gains a template assignment.
      `/orchestrate` is currently assigned to no template at all and appears only in `Next:`
      example lines. The judgment this plan makes: assign `/orchestrate` to the Standard (B)
      template and add it to line 110's Assigned Commands plus a Template Assignment Table row,
      because `/orchestrate` is the lifecycle driver that produces exactly the phase-metrics and
      summary-artifact output Template B describes, and leaving the only lifecycle command
      unassigned would reintroduce a structural gap as soon as the dead rows are deleted. If
      reading the file contradicts that reasoning, deviate and record why in the handoff.
      *(completed: assigned as planned, with a short in-file rationale sentence added directly
      under Template B's Assigned Commands line)*
- [x] Verify the three in-file `Plan: specs/.../plans/...` example lines (around lines 268, 278,
      319) are artifact-path examples rather than command recommendations, and leave them
      untouched. *(completed: confirmed untouched)*
- [x] Confirm by grep that neither `index-entries.json` nor
      `context/standards/interactive-selection.md` parses the Assigned-Commands lines or the table
      programmatically, so no coordinated second edit is needed. If either does, update it in this
      same phase. *(completed: both reference command-output.md only by prose cross-reference /
      path pointer; neither parses it programmatically — no second edit needed)*
- [x] Incidental housekeeping surfaced by gate 3 (doc-lint), fixed in this same phase: registered
      the Phase 1/2 new script files into `core/manifest.json`'s `provides.scripts` via
      `sync-manifest-scripts.sh --write`, and corrected `core/index-entries.json`'s
      `command-output.md` `line_count` via `generate-context-line-counts.sh --write` (both run
      against the deployed `.claude/` copy per their own root-requirement, writing back to the
      source store). *(completed; not a pre-planned task but required for gate 3 to pass)*

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: prose

**Tier Justification**: The edit is confined to prose and table rows in one markdown file with no
executable surface, and `suite_selection_select` returns `__FULL_SWEEP__` for it, so the honest
covering check is sub-case (b): `bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
alongside the `prose` row's diff read-through.

**Files to modify**:
- `agent-system/extensions/core/context/formats/command-output.md` - remove the dead commands from
  both Assigned Commands lines and delete their Template Assignment Table rows; add
  `/orchestrate`'s assignment.

**Verification**:
- `grep -nE '/(implement|research|plan)\b' agent-system/extensions/core/context/formats/command-output.md`
  returns no Assigned-Commands line and no Template Assignment Table row.
- Every command name remaining in an Assigned Commands line or a table row appears in
  `find agent-system/extensions/*/commands -maxdepth 1 -name '*.md' ! -iname 'readme.md' -printf '%f\n' | sed 's/\.md$//' | sort -u`.
- The Template Assignment Table's markdown renders as a well-formed table (column count
  unchanged on every surviving row).
- Diff read-through confirming every changed hunk lies inside prose or a table row.
- `bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
  is clean.

---

### Phase 4: Clear sub-class A in the core extension [COMPLETED]

**Goal**: Zero lint findings under `agent-system/extensions/core/`.

**Tasks**:
- [x] Re-run the Phase 1 lint scoped to `agent-system/extensions/core` to get the current
      authoritative `file:line` list. Work from that output, never from a grep-and-replace.
      *(completed: 41 findings across 26 files, matching the 42-1-already-fixed reconciliation)*
- [x] Retarget each line onto `/orchestrate`, reading enough surrounding context per site to keep
      the sentence correct — a `Next: /implement {N}` becomes a `/orchestrate {N}` invocation; a
      line recommending research-then-plan-then-implement collapses onto one `/orchestrate` call
      rather than three. Do not invent a replacement command. *(completed: all 41 sites fixed;
      skill-project-overview/SKILL.md's two-step plan-then-implement sequence collapsed to one
      `/orchestrate {N}` call, with its "skip the plan step" alternative mapped to the
      `--implement` forcing flag documented in orchestrate-state-machine.md)*
- [x] Handle `context/schemas/errors-schema.json` as a JSON edit: fix the embedded `next_steps`
      example string and confirm the file still parses. *(completed: `jq empty` succeeds)*
- [x] Cover the sites the task description names explicitly: `commands/review.md`,
      `commands/meta.md`, `commands/fix-it.md`, `context/formats/subagent-return.md` (three
      `next_steps` examples), `context/patterns/checkpoint-execution.md`,
      `context/orchestration/orchestration-reference.md`, `context/schemas/errors-schema.json`,
      `agents/meta-builder-agent.md` (five sites), `docs/guides/user-guide.md`,
      `docs/guides/creating-agents.md`, `docs/guides/creating-skills.md`. *(completed: all named
      sites fixed; subagent-return.md's three flagged lines were at lines 134/178/244, not the
      description's exact line citations — reconciled by content, not line number)*
- [x] Introduce no task-number reference and no record-versioning language in any edited line.
      *(completed; confirmed via gate 4 task-reference lint PASS)*

**Timing**: 1 hour

**Depends on**: 1, 3

**Verification Tier**: prose

**Tier Justification**: Every edit is confined to a prose recommendation line or an embedded
example string with no executable surface, and
`bash agent-system/extensions/core/scripts/lint/lint-dead-command-recommendations.sh agent-system/extensions/core`
is the exact check that covers the edit class.

**Scope Hypothesis**: This phase asserts 42 lines across 27 files under `core/`. Confirm against
the lint's own scoped output at the start of the phase and work from that list; a different figure
is the lint's to report, not this plan's to assert.

**Files to modify**:
- `agent-system/extensions/core/**` - the files the scoped lint run enumerates (expected ~27,
  across `commands/`, `agents/`, `skills/`, `context/`, `docs/`, plus one `.json`).

**Verification**:
- `bash agent-system/extensions/core/scripts/lint/lint-dead-command-recommendations.sh agent-system/extensions/core`
  exits `0`.
- `jq empty agent-system/extensions/core/context/schemas/errors-schema.json` succeeds.
- Diff read-through confirming every changed hunk lies inside a prose line or a JSON string value.
- `bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
  is clean (no task-number reference introduced).

---

### Phase 5: Clear sub-class A in the founder extension [NOT STARTED]

**Goal**: Zero lint findings under `agent-system/extensions/founder/`.

**Tasks**:
- [ ] Re-run the Phase 1 lint scoped to `agent-system/extensions/founder` for the authoritative
      `file:line` list.
- [ ] Retarget each line onto `/orchestrate`, per-site, reading enough context to keep each
      sentence correct. This is the largest single group — work file by file down the lint's
      output, re-running the scoped lint periodically to track remaining findings, and commit each
      green sub-step as it lands rather than holding the whole group back.
- [ ] Introduce no task-number reference and no record-versioning language in any edited line.

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: prose

**Tier Justification**: Every edit is confined to a prose recommendation line with no executable
surface, and
`bash agent-system/extensions/core/scripts/lint/lint-dead-command-recommendations.sh agent-system/extensions/founder`
is the exact check that covers the edit class.

**Scope Hypothesis**: This phase asserts 102 lines across 36 files under `founder/`. Confirm
against the lint's own scoped output at the start of the phase and work from that list.

**Files to modify**:
- `agent-system/extensions/founder/**` - the files the scoped lint run enumerates (expected ~36).

**Verification**:
- `bash agent-system/extensions/core/scripts/lint/lint-dead-command-recommendations.sh agent-system/extensions/founder`
  exits `0`.
- Diff read-through confirming every changed hunk lies inside a prose line.
- `bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
  is clean.

---

### Phase 6: Clear sub-class A in the remaining ten extensions [NOT STARTED]

**Goal**: Zero lint findings in `present`, `formal`, `cslib`, `web`, `literature`, `lean`, `nvim`,
`nix`, `epidemiology`, `books`.

**Tasks**:
- [ ] Re-run the Phase 1 lint over the whole source store and take every finding outside `core/`
      and `founder/` as the worklist.
- [ ] Retarget each line onto `/orchestrate`, per-site. Expected distribution: `present` 27 lines
      / 12 files, `formal` 4/4, `cslib` 3/3, `web` 2/2, `literature` 2/2, `lean` 2/2, and one line
      each in `nvim`, `nix`, `epidemiology`, `books`.
- [ ] Confirm `deck-builder-agent.md`'s bare-prose site (`Run /plan first.`) and
      `analyze-agent.md`'s JSON-value `next_steps` site are both in the worklist and both fixed —
      they are the two non-canonical shapes Phase 1's regex was designed against.
- [ ] Introduce no task-number reference and no record-versioning language in any edited line.

**Timing**: 1.25 hours

**Depends on**: 1

**Verification Tier**: prose

**Tier Justification**: Every edit is confined to a prose recommendation line or a JSON string
value with no executable surface, and
`bash agent-system/extensions/core/scripts/lint/lint-dead-command-recommendations.sh agent-system/extensions/<ext>`
run per touched extension is the exact check that covers the edit class.

**Scope Hypothesis**: This phase asserts 44 lines across 29 files across ten extensions. Confirm
against the lint's own output at the start of the phase and work from that list.

**Files to modify**:
- `agent-system/extensions/{present,formal,cslib,web,literature,lean,nvim,nix,epidemiology,books}/**`
  - the files the lint run enumerates (expected ~29).

**Verification**:
- The scoped lint exits `0` for each of the ten extensions.
- `jq empty` succeeds on any `.json` file touched.
- Diff read-through confirming every changed hunk lies inside a prose line or a JSON string value.
- `bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
  is clean.

---

### Phase 7: Wire gate 24, confirm green corpus-wide, redeploy [NOT STARTED]

**Goal**: The lint runs green over the whole source store and is enforced as gate 24 by
`verify-deploy.sh`; the deploy tree is regenerated to `RESULT=landed_verify_clean`.

**Tasks**:
- [ ] Run the lint over the whole source store with no path argument. It MUST exit `0` before any
      gate wiring is written. If it does not, the remaining findings belong to phases 4-6, not
      here.
- [ ] Check `git status --short` on `verify-deploy.sh` and `gate-registry.data` for concurrent
      edits before touching either; both are shared, contended files.
- [ ] Add `gate24_run()` to `agent-system/extensions/core/scripts/verify-deploy.sh`, modeled
      line-for-line on gate 18/21/23's shape: `[SKIP]` when `$TARGET/agent-system/extensions` does
      not exist, `fail` when the lint script is missing, `pass`/`fail` plus `FINDINGS_LIST`
      populated from the lint's `[VIOLATION]`-tagged output lines.
- [ ] Append one tab-separated row to `agent-system/extensions/core/scripts/gate-registry.data`:
      id `24`, description, invoke-fn `gate24_run`, `-`, boolean, timeout, cost tier `free`,
      boolean, scan-path hint `@extensions`. Match the existing rows' field count and tab
      separation exactly — do not introduce a 40-line copy-pasted if/fi block in
      `verify-deploy.sh`.
- [ ] Run `bash agent-system/extensions/core/scripts/lint/lint-gate-registry.sh` to confirm the
      new row and function are consistent with each other.
- [ ] Run the complete gate set: `bash agent-system/extensions/core/scripts/verify-deploy.sh /home/benjamin/.config/nvim`.
      All 24 gates must pass, including gate 8's full shell-suite battery (which picks up the
      Phase 2 fixture suite by glob) and the new gate 24.
- [ ] Redeploy: `bash .claude/scripts/deploy-headless.sh` and confirm the output carries
      `[deploy-headless] RESULT=landed_verify_clean` with exit `0`. Any other `RESULT=` value is a
      failure to resolve, not a result to report past.
- [ ] Confirm the deployed tree picked up the new lint:
      `.claude/scripts/lint/lint-dead-command-recommendations.sh` exists and exits `0`.

**Timing**: 1 hour

**Depends on**: 2, 3, 4, 5, 6

**Verification Tier**: full

**Files to modify**:
- `agent-system/extensions/core/scripts/verify-deploy.sh` - add `gate24_run()`.
- `agent-system/extensions/core/scripts/gate-registry.data` - append the gate 24 row.

**Verification**:
- `bash agent-system/extensions/core/scripts/lint/lint-dead-command-recommendations.sh` exits `0`
  over the whole source store with no path argument and no allowlist.
- `bash agent-system/extensions/core/scripts/lint/lint-gate-registry.sh` is clean.
- `bash agent-system/extensions/core/scripts/verify-deploy.sh /home/benjamin/.config/nvim` — the
  complete gate set, gates 1-24, all pass. Not `--skip-slow`, not `--only-gate`: this is the
  final phase and the full run is the gate.
- `bash .claude/scripts/deploy-headless.sh` prints `[deploy-headless] RESULT=landed_verify_clean`
  and exits `0`.
- `bash .claude/scripts/lint/lint-dead-command-recommendations.sh` (deployed copy) exits `0`.

---

## Testing & Validation

- [ ] `test-lint-dead-command-recommendations.sh` passes standalone and under
      `run-all.sh --only test-lint-dead-command-recommendations.sh`.
- [ ] The deliberately-violating fixture proves the lint fires, naming the exact `file:line`.
- [ ] A recommendation naming a real command (`/orchestrate`) is not flagged; a fixture
      `commands/*.md` file added in the scratch tree makes a previously-unknown command valid,
      proving the set is derived rather than hardcoded.
- [ ] A recommendation naming `/README` is flagged, proving `commands/README.md` is excluded.
- [ ] The lint exits `0` over the whole source store with no allowlist and no path argument.
- [ ] Gate 24 is present in `gate-registry.data` and `verify-deploy.sh`, and
      `lint-gate-registry.sh` confirms the pairing.
- [ ] `verify-deploy.sh` passes all 24 gates.
- [ ] `deploy-headless.sh` reaches `RESULT=landed_verify_clean`.
- [ ] No file under `agent-system/**` gained a task-number reference or record-versioning
      language.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/lint/lint-dead-command-recommendations.sh` (new)
- `agent-system/extensions/core/scripts/tests/test-lint-dead-command-recommendations.sh` (new)
- `agent-system/extensions/core/scripts/verify-deploy.sh` (gate 24 function added)
- `agent-system/extensions/core/scripts/gate-registry.data` (gate 24 row appended)
- `agent-system/extensions/core/context/formats/command-output.md` (template assignments
  structurally corrected)
- ~92 files across 12 extensions with their dead recommendation lines retargeted onto
  `/orchestrate`
- A regenerated `.claude/` deploy tree at `RESULT=landed_verify_clean`

## Rollback/Contingency

Every phase commits per green sub-step, so rollback granularity is one commit. If a phase must be
reverted, `git revert` the relevant commits — the phases are independent enough that reverting a
fix phase (4, 5 or 6) leaves the lint and fixture suite intact and simply returns the lint to red
for that extension subtree.

If the gate wiring in phase 7 destabilizes `verify-deploy.sh` for other dispatches, revert the
`gate24_run()` function and the `gate-registry.data` row as a pair (never one without the other,
which `lint-gate-registry.sh` would then flag) and leave the lint standalone; the fix itself
survives and the lint remains runnable by hand.

If `deploy-headless.sh` returns `RESULT=landed_verify_red`, the deploy DID land — do not re-deploy
blindly. Read the named failing gate, fix the source store, and redeploy. If it returns
`RESULT=not_landed`, the deploy did not land and `.claude/` is unchanged from before the attempt.

Before any intentional rollback that would discard uncommitted work, take a snapshot first:
`bash .claude/scripts/git-snapshot.sh 434`.
