# Implementation Plan: Task #512

- **Task**: 512 - Built-in command exemption for dead-command lint
- **Status**: [NOT STARTED]
- **Effort**: 1.5 hours
- **Dependencies**: None (see Cross-Record Handoff below for a non-blocking downstream relation)
- **Research Inputs**: specs/512_builtin_command_exemption_for_dead_command_lint/reports/01_builtin-command-exemption-mechanism.md
- **Artifacts**: plans/01_builtin-command-exemption-marker.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`lint-dead-command-recommendations.sh` derives its valid-command set purely by enumerating
`agent-system/extensions/*/commands/*.md`, so a correct recommendation of a Claude Code
host-provided built-in (`/ide`) is a structural, permanent false positive that the lint's own
zero-tolerance/no-allowlist decision cannot retire. This plan adds a generic, per-line inline
exemption marker (`builtin-cmd-ok`) to the lint's `classify_line()`, following the `task-ref-ok`
/ `version-ok` plain-substring idiom already established in this repository, amends the lint's
own header where the original no-allowlist decision is recorded, and extends the lint's test
suite with a positive case plus a negative control. The mechanism names no command anywhere in
code, so the lint's "nothing is ever hardcoded here" invariant survives intact.

### Research Integration

Key findings carried into this plan:
- The marker idiom is precedented twice (`task-ref-ok` in `task-reference-patterns.sh`,
  `version-ok` in `record-version-patterns.sh`), with a rendered markdown style precedent at
  `agent-system/extensions/founder/commands/consult.md:22`.
- Only the **inline** form is needed: `classify_line()` classifies one physical line at a time,
  so there is no multi-line candidate shape a block form (`...:begin`/`...:end`) could ever
  exempt.
- `adoption-lint-conventions.md` does **not** govern this lint (it is scoped to adoption lints);
  the decision to amend lives in this lint's own header, and no new standards doc is warranted
  for a single exemption category.
- Rejected alternatives (maintained built-in allowlist; gate-24-side bucketing in
  `verify-deploy.sh`) are carried into Goals & Non-Goals rather than re-litigated.

Two mechanical facts established during planning that the research report did not cover, and
that drive the phase ordering below:
- `gate24_run()` (`verify-deploy.sh:1890-1916`) invokes the **source-store** copy directly
  (`REPO_ROOT="$TARGET" bash "$TARGET/agent-system/extensions/core/scripts/lint/..."`), so gate
  24 sees the lint change with no redeploy.
- The test suite resolves the **deployed** copy first
  (`common_test_resolve_candidate "$REPO_ROOT/.claude/scripts/lint/..."` ahead of the source-store
  fallback, and `common_test_resolve_candidate` returns the first existing path). A new marker
  case therefore runs against the stale `.claude/` lint and fails until a redeploy lands. The
  dispatch already reports `core` and `lean` as stale, so the redeploy is required work, not an
  optional tidy-up.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch; ROADMAP.md was not consulted.

## Goals & Non-Goals

**Goals**:
- Give the lint a generic, author-asserted, per-line exemption mechanism for a command that can
  never have a `commands/<name>.md` definition file in this corpus.
- Amend the no-allowlist decision in the file that records it, rather than quietly contradicting
  it.
- Prove by test that the **marker**, not any command name, drives the exempt verdict (positive
  case plus negative control in the same suite).
- Leave the deployed `.claude/` copy consistent with the source store so the test suite and any
  standalone invocation exercise the same lint.

**Non-Goals**:
- A maintained allowlist of Claude Code built-in command names (rejected: no authoritative source
  exists in this repository, and it reinstates exactly the hardcoded list the lint's header
  rejects).
- Gate-24-side bucketing in `verify-deploy.sh` (rejected: relocates the hardcoding one layer up
  and leaves the lint red forever for its other callers).
- A new standards/taxonomy document for the marker (one exemption category does not warrant
  `task-ref-ok`'s seven-category treatment; the lint header is the right home).
- A block (`begin`/`end`) form of the marker — no multi-line candidate shape exists in this
  lint's model.
- **Editing `memory-setup.md` or `memory-troubleshooting.md`.** Both are owned by
  `reword_dead_lifecycle_command_prose_per_class`, which declares
  `agent-system/extensions/memory/context/` in its own `file_scope`. This record owns the lint and
  its test suite only (task 512 `file_scope` confirmed to be exactly those two files).
- Rewording the `Run /<name>` recommendation shape out of either document (considered and
  rejected in the task description as a non-fix).

## Cross-Record Handoff (read before judging the final gate)

This task delivers the **mechanism**; it cannot clear the two live gate-24 findings, because the
lines carrying them are in another record's territory:
- `agent-system/extensions/memory/context/project/memory/memory-setup.md:93`
- `agent-system/extensions/memory/context/project/memory/memory-troubleshooting.md:34`

Applying the marker to those two lines belongs to
`reword_dead_lifecycle_command_prose_per_class` (status `not_started`), whose `file_scope` already
covers them. Phase 1's header amendment must therefore carry the exact copy-pasteable rendered
marker string so that record's implementer can apply it verbatim without re-deriving the design.

Expected post-completion state, stated plainly so it is not mistaken for a regression: gate 24
still reports those two `/ide` findings until that sibling record lands. Everything else in this
task is green. A non-blocking operator option, if the two findings should be cleared in sequence
rather than whenever that record is next scheduled:
`bash .claude/scripts/update-task-status.sh --depends-on-add <that record> 512` — a sequencing
choice for the orchestrator/user, not an action this task takes.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Marker used as a general escape hatch to silence a genuinely dead command | M | L | Same accepted, precedented trade-off as `version-ok`/`task-ref-ok`: single-token auditable (`grep -rn builtin-cmd-ok`), mandatory trailing human-readable reason, human-review concern at marker-review time. Stated explicitly in the header amendment. |
| Marker hidden or duplicated by the markdown-emphasis strip | L | L | Test the marker against raw `$text`, never the `tr -d '`*_'`-stripped `norm`. |
| Marker check placed so a shapeless line reports a misleading exempt reason | L | M | Insert the check strictly between the `-z "$cmd"` early return and the `VALID_SET` lookup, so a line with no recommendation shape still reports the accurate "no Next:/Run recommendation shape" reason. |
| New test case red until the redeploy lands | M | H (certain) | Phase 2 verifies the fixture pair through the source-store lint directly; Phase 3's redeploy is what makes the suite itself green. Phases are ordered accordingly, and Phase 2 must not be committed as "green suite". |
| Redeploy regenerates the whole tree and collides with a concurrent sibling | M | M | Phase 3 declares `__WHOLE_TREE__` so admission serializes it; re-read every file immediately before editing; stage only this task's own hunks, never a directory or glob add. |
| `deploy-headless.sh` exits 3 (`landed_verify_red`) because of the two out-of-scope `/ide` findings | L | H (expected) | Phase 3's success criterion is `landed_verify_clean` **or** `landed_verify_red` with gate-24 findings limited to those two known, out-of-scope lines — any third finding or a `not_landed` result is a genuine failure. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel (this plan is a strict chain; no wave has
more than one phase).

### Phase 1: Marker recognition and header amendment [NOT STARTED]

**Goal**: `lint-dead-command-recommendations.sh` recognizes an inline `builtin-cmd-ok` marker and
its header records the amended decision.

**Tasks**:
- [ ] Re-read `agent-system/extensions/core/scripts/lint/lint-dead-command-recommendations.sh`
      immediately before editing (concurrent siblings are live on this tree).
- [ ] In `classify_line()`, insert the marker check between the `-z "$cmd"` early return (current
      lines 226-229) and the `VALID_SET` lookup (current line 231), testing the **raw** `$text`:
      ```bash
      if [[ "$text" == *builtin-cmd-ok* ]]; then
          printf 'EXEMPT: line carries builtin-cmd-ok marker\n'
          return 0
      fi
      ```
      This reuses the function's existing `EXEMPT: <reason>` return shape, so the verbose
      reporter at line 279 and the `EXEMPTED` counter need no change.
- [ ] Add a `BUILT-IN COMMAND EXEMPTION` header section (immediately after the existing
      `VALID-COMMAND ENUMERATION (no hardcoded allowlist)` section, lines 15-24, so the amendment
      sits with the decision it amends) stating: a Claude Code host-provided built-in slash
      command can never have a `commands/<name>.md` file in this corpus, making it a structural
      permanent false positive rather than migration debt; the marker is generic and names no
      command in this script, so the no-hardcoded-list invariant is intact; it is a per-site,
      author-asserted claim carrying its own trailing human-readable reason; it is auditable with
      `grep -rn builtin-cmd-ok`; and the inline form is the only form (this lint classifies one
      physical line at a time, so a block form would exempt nothing).
- [ ] In that same header section, record the exact rendered form for a markdown line, matching
      the style precedent at `agent-system/extensions/founder/commands/consult.md:22`, as the
      copy-pasteable string a document author (including the sibling record named in
      Cross-Record Handoff) applies:
      `` <!-- builtin-cmd-ok: /ide is a Claude Code native command, not an agent-system command -->``
- [ ] Record any issue/win via `issue-record.sh` as it arises.

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: The edit is confined to one function and one header comment block in a
single script, and `gate24_run()` invokes this exact source-store copy, so running the
source-store lint directly over a marked/unmarked synthetic fixture pair plus
`shellcheck -x` on that one file covers the whole blast radius.

**Scope Hypothesis**: this phase touches exactly one file, adding roughly 4 lines inside
`classify_line()` and roughly 12 header-comment lines. Confirm with
`git diff --stat -- agent-system/extensions/core/scripts/lint/lint-dead-command-recommendations.sh`
showing that single path and no other, before committing.

**Files to modify**:
- `agent-system/extensions/core/scripts/lint/lint-dead-command-recommendations.sh` - marker check
  in `classify_line()`; `BUILT-IN COMMAND EXEMPTION` header section

**Verification**:
- `bash .claude/scripts/lint/lint-shellcheck.sh
  agent-system/extensions/core/scripts/lint/lint-dead-command-recommendations.sh` exits 0.
- Write a scratch fixture pair under the session scratchpad and run the **source-store** lint
  (`bash agent-system/extensions/core/scripts/lint/lint-dead-command-recommendations.sh --verbose
  <fixture>`): the line `Run /totally-fake-cmd-512 <!-- builtin-cmd-ok: reason -->` exits 0 and
  reports `[EXEMPT] ... line carries builtin-cmd-ok marker`; the same line without the marker
  exits 1 and reports `[VIOLATION] ... /totally-fake-cmd-512 has no definition file`.
- A candidate line with no `Next:`/`Run` shape but carrying the marker still reports the
  `no Next:/Run recommendation shape` reason (ordering assertion).
- `bash agent-system/extensions/core/scripts/lint/lint-dead-command-recommendations.sh --verbose`
  over the full corpus still reports exactly the two known out-of-scope `/ide` violations and no
  others (no behavior change for unmarked lines).

---

### Phase 2: Test coverage for the marker [NOT STARTED]

**Goal**: The lint's own suite proves the marker drives the verdict, with a negative control in
the same case.

**Tasks**:
- [ ] Re-read `agent-system/extensions/core/scripts/tests/test-lint-dead-command-recommendations.sh`
      immediately before editing.
- [ ] Append a `Case 6 (built-in exemption marker)` block after Case 5 (current lines 163-188),
      following the file's established structure: `common_test_info` banner, fixture written into
      `$WORKDIR` via a quoted heredoc, `bash "$LINT_SCRIPT" <fixture>` with output captured to
      `$WORKDIR/case6-*.txt`, `common_test_pass`/`common_test_fail` assertions.
- [ ] Positive half: a fixture whose only candidate line is
      `Run /totally-fake-cmd-512 <!-- builtin-cmd-ok: synthetic built-in, no definition file by design -->`
      exits 0, prints no `VIOLATION`, and under `--verbose` prints the
      `line carries builtin-cmd-ok marker` reason.
- [ ] Negative control half: the byte-identical line with the marker comment removed exits
      non-zero and names `totally-fake-cmd-512` — demonstrating the marker, not the command name,
      drives the verdict (mirrors the Case 2 / Case 3 positive-plus-control pattern).
- [ ] Do **not** register anything new: both files are already listed in
      `agent-system/extensions/core/manifest.json` (lines 240, 367) and the suite is already
      classified in `agent-system/extensions/core/scripts/tests/suite-classification.data:114`.
- [ ] Record any issue/win via `issue-record.sh` as it arises.

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: The change is additive to one test suite and exercises only the Phase 1
function; the fixture pair run through the source-store lint is the specific covering check, and
no other suite reads this file.

**Scope Hypothesis**: this phase touches exactly one file and adds one self-contained case block
(roughly 45 lines) with no edits to Cases 1-5. Confirm with `git diff --stat` naming only
`test-lint-dead-command-recommendations.sh`, and with `git diff` showing no hunk inside the
existing cases.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-lint-dead-command-recommendations.sh` - new
  Case 6 (marker exemption plus negative control)

**Verification**:
- `bash .claude/scripts/lint/lint-shellcheck.sh
  agent-system/extensions/core/scripts/tests/test-lint-dead-command-recommendations.sh` exits 0.
- Run the two Case 6 fixtures through the **source-store** lint directly and confirm the expected
  exit codes and output text (0/exempt-reason, and non-zero/named-command). The suite itself is
  expected to be RED at this point, because `common_test_resolve_candidate` picks the stale
  `.claude/scripts/lint/` copy — this is the known, planned-for state, resolved in Phase 3, and
  must not be reported as a green suite.
- `git diff` confirms Cases 1-5 are byte-unchanged.

---

### Phase 3: Redeploy and full-gate verification [NOT STARTED]

**Goal**: The deployed `.claude/` copy matches the source store, the suite is green against it,
and the remaining gate-24 findings are confirmed to be exactly the two out-of-scope `/ide`
lines.

**Tasks**:
- [ ] Confirm no foreign uncommitted modification or foreign commit is in flight (`git status
      --short`, `git log --oneline -5`); if one is observed, STOP and report rather than
      proceeding — a sibling may be mid-edit on this shared tree.
- [ ] Redeploy: `timeout 540 bash .claude/scripts/deploy-headless.sh` with the Bash tool
      `timeout` parameter set to 600000 (not its 120000 default), per
      `context/patterns/external-process-wait.md` Rule 1. Record the `RESULT=` marker and exit
      code.
- [ ] Run the suite against the now-fresh deployed lint:
      `bash agent-system/extensions/core/scripts/tests/run-all.sh --only
      test-lint-dead-command-recommendations.sh`.
- [ ] Run gate 24 standalone for the finding inventory:
      `bash .claude/scripts/verify-deploy.sh --only-gate 24`.
- [ ] Confirm the surviving gate-24 findings are exactly `memory-setup.md:93` and
      `memory-troubleshooting.md:34`, both `/ide`, both out of this record's `file_scope`; any
      third finding is a genuine regression from this task.
- [ ] Record the Cross-Record Handoff explicitly in the task summary and in
      `.orchestrator-handoff.json`'s `summary`, so the two surviving findings are not re-filed as
      a fresh defect by the next gate run.
- [ ] Record any issue/win via `issue-record.sh` as it arises; if there is genuinely nothing to
      record for this phase, attest that explicitly in the handoff prose.

**Timing**: 0.5 hours

**Depends on**: 2

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase authors no source edit of its own — it regenerates the deployed
tree and asserts. Confirm with `git status --short` showing no modification under
`agent-system/extensions/**` beyond what Phases 1-2 already committed.

**Files to modify**:
- `__WHOLE_TREE__` - `deploy-headless.sh` regenerates the entire deployed tree
- `.claude/scripts/lint/lint-dead-command-recommendations.sh` - regenerated from source (not
  hand-edited; listed for traceability only)
- `.claude/scripts/tests/test-lint-dead-command-recommendations.sh` - regenerated from source
  (not hand-edited; listed for traceability only)

**Verification** (complete gate set — this is the plan's final phase):
- `bash .claude/scripts/verify-deploy.sh` full gate set: every gate passes except gate 24, whose
  only findings are the two known out-of-scope `/ide` lines named above.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` — the full suite run is green,
  including `test-lint-dead-command-recommendations.sh` Cases 1-6 (a `--only` subset pass is not
  sufficient evidence on its own; the narrowed run above is a development check, this full run is
  the gate).
- `deploy-headless.sh` reported `RESULT=landed_verify_clean` (exit 0) or
  `RESULT=landed_verify_red` (exit 3) with gate-24 findings limited to those two lines.
  `RESULT=not_landed` is a failure.
- `grep -rn builtin-cmd-ok agent-system/ .claude/` shows the token only in the lint, its test
  suite, and their deployed copies — no stray application to a line outside this record's scope.
- Task status transitions `[IMPLEMENTING]` -> `[COMPLETED]` via
  `update-task-status.sh postflight`, with the surviving two findings documented as out-of-scope
  in the summary.

---

## Testing & Validation

- [ ] A candidate line carrying `builtin-cmd-ok` and naming an undefined command is EXEMPT, with
      the reason text `line carries builtin-cmd-ok marker` under `--verbose`.
- [ ] The byte-identical line without the marker is still a VIOLATION naming the command.
- [ ] A line carrying the marker but having no `Next:`/`Run` shape reports the shapeless reason,
      not the marker reason (insertion-order assertion).
- [ ] Cases 1-5 of the existing suite remain byte-unchanged and green.
- [ ] Full-corpus lint behavior for unmarked lines is unchanged (same violation inventory as
      before Phase 1, no additions, no silent removals).
- [ ] No command name appears in the lint's `VALID_SET` or anywhere else in the lint as a
      hardcoded exemption.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/lint/lint-dead-command-recommendations.sh` - marker
  recognition plus `BUILT-IN COMMAND EXEMPTION` header amendment (the amended record of the
  original no-allowlist decision, in the file that holds it)
- `agent-system/extensions/core/scripts/tests/test-lint-dead-command-recommendations.sh` - Case 6
- Regenerated deployed copies of both files under `.claude/`
- Task summary documenting the Cross-Record Handoff: the exact rendered marker string and the two
  lines awaiting it in the sibling record's territory

## Rollback/Contingency

Both source edits are additive and confined to two files, each committed in its own phase, so
`git revert` of the two phase commits restores the prior behavior exactly; a redeploy then
restores the deployed copies. No state, schema, or registry change is involved, and nothing
outside these two files (plus their regenerated deployed copies) is touched.

If Phase 1's insertion point turns out to interact badly with the verbose reporter or the
`EXEMPTED` counter (not expected — the return shape is reused verbatim), fall back to returning
the marker reason from a dedicated branch placed after the `VALID_SET` lookup instead; the
observable difference is only the reported reason for a line that is both marked and a defined
command, which no real line is.

If the redeploy cannot land (`RESULT=not_landed`), leave both source commits in place, mark the
task `[PARTIAL]` naming the deploy failure, and do **not** hand-patch any file under `.claude/**`
as a substitute — that would mask the divergence rather than fix it.
