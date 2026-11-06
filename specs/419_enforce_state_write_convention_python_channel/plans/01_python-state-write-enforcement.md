# Implementation Plan: Task #419

- **Task**: 419 - Extend the state-writer boundary lint to the Python/ad hoc JSON re-serialization channel
- **Status**: [NOT STARTED]
- **Effort**: 7 hours
- **Dependencies**: None
- **Research Inputs**: specs/419_enforce_state_write_convention_python_channel/reports/01_python-state-write-lint-extension.md
- **Artifacts**: plans/01_python-state-write-enforcement.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Close the mechanical enforcement gap on the Python/interpreter re-serialization channel for
`specs/state.json` writes. `scripts/lint/lint-state-writer-boundary.sh` (gate 12) today detects
only the jq-shaped channel: every limb of its candidate pattern requires an `mv` onto a
`state.json` target or a shell redirect, neither of which a `json.dump` through an already-open
file object produces. The work extracts the detection predicate into one shared pattern library,
extends the lint with a single new candidate limb plus one `classify_line` branch keyed on a
write-capable `open()` call whose path literal contains `state.json`, pins both polarities plus a
corruption-reproduction fixture in the lint's test suite, adds a `PreToolUse` Bash hook consuming
the same library (the incident that raised this work was an ad hoc in-session interpreter call
that never existed as a scannable file, so a content lint alone is evidenced-insufficient), and
points the prose standard at its own enforcer. Done when gate 12 flags every named Python shape,
flags none of the existing legitimate non-state Python JSON writers, the hook blocks the same
shape at write time, and the full gate battery passes against an explicit source-store TARGET.

### Research Integration

Findings carried forward from `reports/01_python-state-write-lint-extension.md`:

- The detection predicate is `open\([^)]*state\.json` as a candidate limb, narrowed by a
  write-capable mode token (`w`, `a`, `r+`, `w+`, `a+`, `x`) on the same line. Keying on
  `open(` + the same-line `state.json` literal — rather than on a bare `json.dump`/`json.dumps`/
  `json.load` token — was measured to produce **zero** new candidate matches anywhere in the live
  source store, where a bare-token approach would have false-positived on every legitimate JSON
  writer in the tree and required a large new allowlist.
- `r+` must be treated as write-capable: the in-place rewrite idiom (`open(path, "r+")` ->
  `json.load` -> `seek(0)` -> `json.dump`) backs both read and write through one `open()` call,
  which is why the dispatch names `json.load` in the write-path language.
- Mode-based detection fires identically with or without `ensure_ascii=False`, satisfying the
  requirement that the unsynchronized-read-modify-write half of the hazard be caught and not just
  the escaping half.
- Archive and vault-root targets are covered for free by the same `state\.json` substring test the
  jq channel already uses — no path-prefix special-casing.
- The three literature-extension Python JSON writers (`literature-search.sh`,
  `literature-repair-combining.sh`, `literature-combining-audit.sh`) write `manifest.json` and ad
  hoc result envelopes; confirmed by grep not to match the new pattern at all, so they are exempt
  by content with no allowlist marker.
- The originating incident was a live Bash-tool `python3` invocation that never landed as a file
  under the scanned tree. A content lint can stop a future copy-paste recurrence into a tracked
  file; it provably could not have stopped, and cannot stop a repeat of, the actual incident
  shape. Hence the companion hook, with `Bash` as its trigger surface (mirroring
  `guard-destructive-git.sh`, which reads `tool_input.command`) rather than `Write|Edit`.
- Gate 12 measures 4.8s today against its declared 30s timeout — ample margin for one added
  regex limb, to be re-measured rather than assumed in the final phase.

**Planning-time addition the research measurement does not cover**: the "zero new
`EXCLUDED_FILES` entries needed" result is true of the tree *as it stands today*. This work
creates files that themselves carry the anti-pattern text by necessity — the shared pattern
library (which holds the regex) and the new hook's both-polarity test suite (which feeds the bad
shape as synthetic fixture command strings). Those two files must gain `EXCLUDED_FILES` entries
with inline reasons, exactly as `lint-state-writer-boundary.sh` and
`test-validate-task-creation-audit.sh` already have, or the lint will fail on this task's own
output.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No roadmap context was provided to this dispatch.

## Goals & Non-Goals

**Goals**:
- Extend `lint-state-writer-boundary.sh` to flag a write-capable Python `open()` on a `state.json`
  target (live, archive, or vault-root), regardless of `ensure_ascii`, within the lint's existing
  two-layer detection model.
- Extract the predicate into one shared pattern library consumed by both the lint and the new
  write-time hook, mirroring `task-reference-patterns.sh`'s dual-consumer structure.
- Carry a remedy message naming `state-write.sh` and its `--arg`/`--argjson` passthrough.
- Pin every named shape and control case in `test-lint-state-writer-boundary.sh`, including a
  reproduction fixture that evidences the whole-file-diff claim rather than asserting it.
- Add a `PreToolUse` Bash hook blocking the same shape in a live interpreter invocation, with its
  own both-polarity test and fragment-surface registration.
- Point `task-lock.md`'s State-Write Convention section at its mechanical enforcer.

**Non-Goals**:
- Re-landing the three layers that already exist: `state-write.sh` itself, the prose standard, the
  jq-channel lint and its registered gate 12 row. No new gate row is added.
- Fixing the unconditional-`allow` `matcher: Write` stub in `root-files/settings.json`
  (unrelated, enforces nothing, out of scope per research).
- Addressing the known-unrelated pre-existing failures: gate 3 lean4 doc-lint index entry, gate 20
  eager-load budget, gate 8 suites `test-detect-noop-bash.sh`, `test-four-tier-conflict.sh`,
  `test-guard-git-push.sh`.
- Writing the recommended `context/patterns/hook-trigger-surface-selection.md` context file (a
  research-suggested context extension, not part of this enforcement work).
- Catching variable-indirected paths or writes assembled across distant lines — the lint's
  documented limitation applies verbatim to the Python shape and is accepted, not papered over;
  the hook narrows but does not eliminate it.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| New files created by this work trip the extended lint on their own fixture/pattern text | M | H | Phase 1 and Phase 4 each add an inline-reasoned `EXCLUDED_FILES` entry for the file they create, following the existing self-exclusion precedent; Phase 6's live gate 12 run is the check |
| Mode-check regex false-positives on a long line carrying an unrelated `'w'`/`'a'` literal | M | L | Measured zero occurrences in the live tree today; the Layer 2 individually-reasoned allowlist is the sanctioned escape hatch if one ever appears |
| Shared library extraction changes jq-channel classification behavior as a side effect | H | L | Extract the Python predicate only; leave every existing `classify_line` branch and candidate limb byte-identical. Cases 1-6 of the existing suite are the regression check and must stay green unmodified |
| A new hook that fails closed on a sourcing error blocks every Bash call in the session | H | L | Hook fails OPEN (exit 0) when the shared library cannot be sourced, per the write-time-hook convention; blocks via `exit 2` + stderr only on a positive match, never `permissionDecision: deny` |
| New lib/hook/test files not added to `manifest.json` `provides` never reach a deployed tree | M | M | Each creating phase adds its manifest entry in the same phase; Phase 6's redeploy plus full battery is the end-to-end proof |
| Scope creep: the hook turns a lint extension into a larger hook-plus-library task | M | M | Phases 1-3 fully satisfy the dispatch's REQUIRED DIRECTION and are independently shippable; Phases 4-5 are separately phased so a partial outcome degrades cleanly rather than leaving the lint half-built |
| Concurrent sibling tasks editing the shared tree | M | M | No declared sibling scope intersects this plan's file list; still re-read every file immediately before editing, stage only this task's own hunks, never a directory or glob add |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 4 | 1 |
| 3 | 3, 5 | 2 (for 3), 4 (for 5) |
| 4 | 6 | 3, 5 |

Phases within the same wave can execute in parallel.

### Phase 1: Shared pattern library and lint extension [NOT STARTED]

**Goal**: The Python channel is mechanically detected by gate 12's lint, with the predicate living
in one library both this lint and the later hook consume.

**Tasks**:
- [ ] Create `agent-system/extensions/core/scripts/lib/state-writer-boundary-patterns-lib.sh`
      exporting (a) the candidate limb `open\([^)]*state\.json`, (b) a write-capable-mode
      predicate accepting `w`, `a`, `r+`, `w+`, `a+`, `x` and rejecting bare/no-mode and plain
      `r`/`rb`, and (c) a single function that takes one line of text and returns
      violation/exempt-read-only/no-match. Header states the dual-consumer role and names both
      consumers, mirroring `scripts/lib/task-reference-patterns.sh`'s structure.
- [ ] Source the new library from `lint-state-writer-boundary.sh` and append the library's
      candidate limb to `CANDIDATE_PATTERN` (append only — every existing limb stays
      byte-identical).
- [ ] Add one new `classify_line` branch, before the final catch-all, delegating to the library's
      function: write-capable mode -> `VIOLATION`; no write-capable mode -> `EXEMPT:` naming
      read-only as the reason. Carry the inline comment explaining that the `with open(...) as f:`
      idiom's second line (`json.dump(obj, f)`) carries neither token and falls under the already
      documented cross-line limitation.
- [ ] Extend the lint's bottom-of-run `Fix:` echo block to name `--arg`/`--argjson` passthrough
      and to state that the acquire -> stage -> transform -> validate -> mv -> release sequence is
      the only sanctioned path regardless of escaping choices. One shared addition to the existing
      uniform message, not a second shape-specific message.
- [ ] Add an `EXCLUDED_FILES` entry for the new library with its reason stated inline (it holds
      the detection pattern itself, as the lint's own entry already does).
- [ ] Update the lint's `KNOWN LIMITATION` and `DETECTION MODEL` header paragraphs to name the
      Python channel alongside the jq one.
- [ ] Add `lib/state-writer-boundary-patterns-lib.sh` to `manifest.json`'s `provides.scripts`.

**Timing**: 1.25 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: the new candidate limb is hypothesized to produce zero new candidate matches
anywhere in the live source store beyond the library and the lint themselves (research measured
this before the library existed). Confirm at implementation time by running the grep in this
phase's verification criteria and by a clean `lint-state-writer-boundary.sh` exit — if any other
file matches, add an inline-reasoned `EXCLUDED_FILES` entry for it rather than weakening the
predicate.

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-lint-state-writer-boundary.sh`
is the covering check — the existing suite's unmodified Cases 1-6 are the jq-channel regression
guard for this edit, and `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh` covers
the new library's shell surface.

**Files to modify**:
- `agent-system/extensions/core/scripts/lib/state-writer-boundary-patterns-lib.sh` - new shared predicate library
- `agent-system/extensions/core/scripts/lint/lint-state-writer-boundary.sh` - source the library, append the candidate limb, add the classify branch, extend the remedy message, add the self-exclusion entry, update the header
- `agent-system/extensions/core/manifest.json` - add the new library to `provides.scripts`

**Verification**:
- Existing suite green unmodified: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-lint-state-writer-boundary.sh`
- Shellcheck clean on the two shell files: `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh`
- Live source-store scan still exits 0 with no new violations:
  `bash agent-system/extensions/core/scripts/lint/lint-state-writer-boundary.sh`
- Ad hoc confirmation that the new limb matches nothing new in the live tree:
  `grep -rnE 'open\([^)]*state\.json' agent-system/extensions --include='*.sh' --include='*.md'`
  returns only the library and the lint itself

---

### Phase 2: Lint test cases for every named shape and control [NOT STARTED]

**Goal**: Each shape the dispatch names is pinned flagged, and each legitimate writer it names is
pinned not-flagged, against deliberately seeded fixtures so a lint extension matching nothing
cannot pass as working.

**Tasks**:
- [ ] Add a fixture case asserting `json.dump(obj, open('specs/state.json', 'w'))` is flagged
      (default `ensure_ascii`).
- [ ] Add a fixture case asserting a write against a `state.json` target carrying an explicit
      `ensure_ascii=False` is **also** flagged.
- [ ] Add a fixture case for the two-line `with open(path, 'w') as f:` / `json.dump(obj, f)` idiom
      asserting the `open()` line is flagged, with a comment recording that the second line is
      covered by the documented cross-line limitation rather than by this check.
- [ ] Add fixture cases asserting `with open('specs/archive/state.json', 'a') as f:` and
      `with open(f"{vault_root}/state.json", 'r+') as f:` are both flagged.
- [ ] Add control cases asserting `with open('specs/state.json') as f:` (no mode) and
      `with open('specs/state.json', 'r') as f:` are NOT flagged, with the EXEMPT reason text
      asserted so a future regression to "flag everything" is visible.
- [ ] Add a control case running the lint directly against the three real literature-extension
      script paths (not synthetic copies) and asserting exit 0.
- [ ] Confirm the existing Case 2 (`state-write.sh` call not flagged) still covers the positive
      polarity with no change needed; leave Cases 1-6 otherwise untouched.
- [ ] Assert each new flagged case reports `file:line`, following Case 1's existing assertion
      shape.

**Timing**: 1.25 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: exactly three literature-extension Python JSON writers are hypothesized to
exist (`literature-search.sh`, `literature-repair-combining.sh`, `literature-combining-audit.sh`).
Confirm at implementation time with
`grep -rln 'json\.dump\|json\.dumps' agent-system/extensions/literature` before writing the
control case, and cover whatever that enumeration actually returns rather than the three assumed
names.

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-lint-state-writer-boundary.sh`
is the covering check — this phase edits only that one suite file, which is the suite
`suite_selection_select` resolves for it.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-lint-state-writer-boundary.sh` - new flagged-shape cases, read-only controls, real-path literature control

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-lint-state-writer-boundary.sh` exits 0 with
  every new case reported PASS and no case silently absent from the summary count
- Negative control of the test itself: temporarily revert Phase 1's `classify_line` branch and
  confirm the new cases FAIL (then restore), proving the cases exercise the new code rather than
  passing vacuously
- `bash agent-system/extensions/core/scripts/lint/lint-test-harness-adoption.sh` clean (the new
  cases use the existing `common_test_pass`/`fail`/`info` harness)

---

### Phase 3: Corruption reproduction fixture [NOT STARTED]

**Goal**: The remedy message's whole-file-diff claim is evidenced by an executed reproduction, not
asserted.

**Tasks**:
- [ ] Add a new case to `test-lint-state-writer-boundary.sh` that builds a scratch JSON state file
      in the suite's existing `$WORKDIR` with 3+ synthetic project entries, at least two carrying
      non-ASCII content (em dash, arrow) in fields *other* than the one to be modified.
- [ ] Run a `python3` one-liner that `json.load`s the scratch file, appends one trivial entry to
      one project's `file_scope`, and `json.dump`s it back with default `ensure_ascii`.
- [ ] Diff before/after and assert the diff touches the untouched projects' non-ASCII fields (now
      `\uXXXX`-escaped) in addition to the one intentionally-changed entry — i.e. assert the diff
      is NOT scoped to one project's one field.
- [ ] Assert the complementary direction too: the same append performed via a `--argjson`-style
      transform leaves the untouched projects' bytes unchanged, so the case demonstrates the
      remedy as well as the hazard.
- [ ] Keep the fixture entirely within `$WORKDIR`; it must never read or write the real
      `specs/state.json`.

**Timing**: 1 hour

**Depends on**: 2

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-lint-state-writer-boundary.sh`
is the covering check — this phase adds one case to that same single suite file and touches nothing
else.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-lint-state-writer-boundary.sh` - reproduction-fixture case

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-lint-state-writer-boundary.sh` exits 0 and
  the new case's PASS line names the escaped-field assertion explicitly
- `git status --short` after the run shows no modification to `specs/state.json`, confirming the
  fixture stayed inside `$WORKDIR`

---

### Phase 4: Write-time Bash hook and its test [NOT STARTED]

**Goal**: A live `python3` invocation carrying the bad shape is blocked before it runs — the
incident shape the content lint provably cannot see.

**Tasks**:
- [ ] Create `agent-system/extensions/core/hooks/validate-no-python-state-write.sh`: `PreToolUse`,
      reading `INPUT=$(cat)` and `COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')`
      exactly as `guard-destructive-git.sh` does, applying the Phase 1 library's predicate to
      `$COMMAND`.
- [ ] On a match, block via `exit 2` plus a stderr remedy naming `state-write.sh` and its
      `--arg`/`--argjson` passthrough — never `permissionDecision: deny`, which is
      documented-buggy for allow-listed Bash calls.
- [ ] Fail OPEN (`exit 0`) when the shared library cannot be sourced, and state that polarity
      choice and its rationale in the hook's header (a broken write-time guard must never block
      every Bash call; this is the opposite polarity from a deploy gate, deliberately).
- [ ] Create `agent-system/extensions/core/scripts/tests/test-validate-no-python-state-write.sh`
      mirroring `test-validate-no-task-references.sh`'s both-polarity structure: a synthetic
      `python3 -c "..."` command string carrying a write-capable `open()` on `specs/state.json` is
      blocked (exit 2); the archive and vault-root variants are blocked; a read-only `open()` is
      allowed; an equivalent `state-write.sh` invocation is allowed; a missing-library simulation
      exits 0 (fail-open pinned).
- [ ] Add an `EXCLUDED_FILES` entry to `lint-state-writer-boundary.sh` for the new hook test with
      its reason stated inline (it feeds the bad shape as synthetic fixture command strings,
      following `test-validate-task-creation-audit.sh`'s existing entry).
- [ ] Add both new files to `manifest.json` (`provides.hooks` for the hook,
      `provides.scripts` for the test suite).

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-validate-no-python-state-write.sh,test-lint-state-writer-boundary.sh`
is the covering check — the new hook's own suite plus the lint suite whose `EXCLUDED_FILES` list
this phase also edits.

**Files to modify**:
- `agent-system/extensions/core/hooks/validate-no-python-state-write.sh` - new write-time Bash guard
- `agent-system/extensions/core/scripts/tests/test-validate-no-python-state-write.sh` - new both-polarity hook suite
- `agent-system/extensions/core/scripts/lint/lint-state-writer-boundary.sh` - `EXCLUDED_FILES` entry for the new hook test
- `agent-system/extensions/core/manifest.json` - `provides.hooks` and `provides.scripts` entries

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-validate-no-python-state-write.sh` exits 0
  with both polarities and the fail-open case PASS
- Direct manual probe: piping a JSON payload whose `tool_input.command` carries the bad shape into
  the hook exits 2 and prints a stderr message naming `state-write.sh`; the same payload with a
  `state-write.sh` command exits 0 silently
- `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh` clean on the new hook and test
- `bash agent-system/extensions/core/scripts/lint/lint-state-writer-boundary.sh` still exits 0 (the
  new test's fixture text is covered by the added exclusion entry)

---

### Phase 5: Hook registration and prose pointer [NOT STARTED]

**Goal**: The hook is reachable through a fragment surface in a deployed tree, and the prose
standard names its own mechanical enforcer.

**Tasks**:
- [ ] Register the hook in `merge-sources/settings-hooks.json`'s existing `"matcher": "Bash"`
      `PreToolUse` array, alongside `guard-destructive-git.sh`,
      `validate-bounded-waiter.sh` and `validate-task-creation-audit.sh`, using the settled
      `bash "$CLAUDE_PROJECT_DIR"/.claude/hooks/...` absolute shape.
- [ ] Register it as a blocking guard (no `2>/dev/null || echo '{}'` suppression), matching
      `guard-destructive-git.sh`'s registration rather than the advisory hooks' suppressed form.
- [ ] Add one sentence to `context/patterns/task-lock.md`'s State-Write Convention section,
      immediately after the existing sentence naming the three forbidden write shapes (around
      lines 802-808), naming `scripts/lint/lint-state-writer-boundary.sh`, gate 12, and the new
      hook as the mechanical enforcers of both the jq- and Python-shaped forms of the rule.
      Confine the edit to that section; touch no other part of the file.
- [ ] Verify the added sentence introduces neither task-number references nor record-versioning
      language (both prohibited under `agent-system/**`).

**Timing**: 0.5 hours

**Depends on**: 4

**Verification Tier**: local

**Scope Hypothesis**: the State-Write Convention section's three-forbidden-shapes sentence is
hypothesized to sit around lines 802-808 of `context/patterns/task-lock.md`. Confirm by grepping
for the section heading immediately before editing — a sibling task may have shifted line
numbers — and anchor the insertion on the sentence text, never on a line number.

**Tier Justification**: `bash agent-system/extensions/core/scripts/lint/lint-hook-registration-paths.sh`
is the covering check for the registration edit — it gates exactly the four registration defect
classes this phase could introduce (CWD-relative path, template teaching the defect,
root-files-only reachability, nonexistent invoked script).

**Files to modify**:
- `agent-system/extensions/core/merge-sources/settings-hooks.json` - register the new hook in the `Bash` `PreToolUse` array
- `agent-system/extensions/core/context/patterns/task-lock.md` - one pointer sentence in the State-Write Convention section

**Verification**:
- `bash agent-system/extensions/core/scripts/lint/lint-hook-registration-paths.sh` exits 0
- `jq -e . agent-system/extensions/core/merge-sources/settings-hooks.json` parses
- `git diff -- agent-system/extensions/core/context/patterns/task-lock.md` shows a change confined
  to the State-Write Convention section
- `bash agent-system/extensions/core/scripts/check-task-references.sh` and the record-versioning
  lint clean on the edited markdown

---

### Phase 6: Redeploy and full gate battery [NOT STARTED]

**Goal**: The extension is live in the deployed tree and the whole repository's gate set is green
except the known-unrelated pre-existing failures, with gate 12's runtime measured rather than
assumed.

**Tasks**:
- [ ] Redeploy the source store: `bash agent-system/extensions/core/scripts/deploy-headless.sh`,
      then confirm the new library, hook, and test suite are present under `.claude/` and the hook
      registration landed in the deployed `settings.json`.
- [ ] Measure gate 12's actual runtime against the live source store and record the figure:
      `time bash .claude/scripts/lint/lint-state-writer-boundary.sh --quiet`. State the measured
      value and the remaining margin against the registry's declared 30s timeout; do not assert
      the margin without the measurement.
- [ ] Run the complete gate battery with an explicit source-store TARGET (the bare no-argument
      form run from elsewhere silently skips the source-store-only gates):
      `bash agent-system/extensions/core/scripts/verify-deploy.sh /home/benjamin/.config/nvim`.
- [ ] Confirm gate 12 reports PASS (not SKIP) in that run.
- [ ] Run the full shell-suite battery: `bash agent-system/extensions/core/scripts/tests/run-all.sh`.
- [ ] Triage every failure against the dispatch's known-unrelated list (gate 3 lean4 doc-lint
      index entry; gate 20 eager-load budget; gate 8 suites `test-detect-noop-bash.sh`,
      `test-four-tier-conflict.sh`, `test-guard-git-push.sh`) and state explicitly that nothing
      outside that list failed, rather than reporting a bare count.

**Timing**: 1.5 hours

**Depends on**: 3, 5

**Verification Tier**: full

**Scope Hypothesis**: the five known-unrelated pre-existing failures named in the dispatch (gate 3,
gate 20, and three gate 8 suites) are hypothesized to be the complete set of expected red results.
Confirm at implementation time by triaging each observed failure individually against that list;
any failure outside it belongs to this work and must be fixed, never attributed to the list.

**Files to modify**:
- `__WHOLE_TREE__` - deploy-headless.sh regenerates the entire deployed `.claude/` tree

**Verification**:
- `bash agent-system/extensions/core/scripts/deploy-headless.sh` completes without error and the
  three new files plus the hook registration are present in the deployed tree
- Complete gate set green under an explicit source-store TARGET:
  `bash agent-system/extensions/core/scripts/verify-deploy.sh /home/benjamin/.config/nvim`, with
  gate 12 reporting PASS rather than SKIP, and every failure accounted for against the
  known-unrelated list
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` green apart from the three
  known-unrelated gate 8 suites
- Gate 12 runtime stated as a measured figure with its margin against the declared 30s timeout

---

## Testing & Validation

- [ ] `test-lint-state-writer-boundary.sh` passes, covering: default-`ensure_ascii` `json.dump`
      flagged; explicit `ensure_ascii=False` against a `state.json` also flagged; the two-line
      `with open(...)` idiom's `open()` line flagged; archive and vault-root targets flagged;
      no-mode and `'r'` reads not flagged; a correct `state-write.sh` call not flagged; the three
      real literature-extension scripts not flagged.
- [ ] Each flagged shape is proven detected from a deliberately seeded fixture, not from the live
      tree, so a silently-matching-nothing extension cannot pass.
- [ ] The reproduction fixture demonstrates a whole-file diff from a default-`ensure_ascii`
      round-trip over non-ASCII state content, and the `--argjson`-style remedy leaves untouched
      rows byte-identical.
- [ ] `test-validate-no-python-state-write.sh` passes both polarities plus the fail-open case.
- [ ] `lint-hook-registration-paths.sh`, `lint-shellcheck.sh`, and `lint-test-harness-adoption.sh`
      clean on every new and edited shell file.
- [ ] Gate 12 PASSes on the live source store post-extension, with a measured runtime inside its
      declared 30s timeout.
- [ ] Full battery under an explicit source-store TARGET green apart from the enumerated
      known-unrelated failures.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/lib/state-writer-boundary-patterns-lib.sh` (new)
- `agent-system/extensions/core/scripts/lint/lint-state-writer-boundary.sh` (extended: candidate
  limb, classify branch, remedy message, two exclusion entries, header)
- `agent-system/extensions/core/scripts/tests/test-lint-state-writer-boundary.sh` (extended: shape
  cases, controls, reproduction fixture)
- `agent-system/extensions/core/hooks/validate-no-python-state-write.sh` (new)
- `agent-system/extensions/core/scripts/tests/test-validate-no-python-state-write.sh` (new)
- `agent-system/extensions/core/merge-sources/settings-hooks.json` (hook registration)
- `agent-system/extensions/core/manifest.json` (`provides` entries for the three new files)
- `agent-system/extensions/core/context/patterns/task-lock.md` (one pointer sentence)
- Regenerated `.claude/` deploy tree
- Measured gate 12 runtime figure, recorded in the implementation summary

## Rollback/Contingency

Each phase is independently revertable and committed on its own, so a failure localizes to the
phase that introduced it.

- Phase 1 regression (jq-channel classification changed): revert the `classify_line` branch and
  the `CANDIDATE_PATTERN` append; the existing Cases 1-6 are the detector.
- Phase 4-5 regression (the hook blocks legitimate Bash calls): remove the single registration
  entry from `merge-sources/settings-hooks.json` and redeploy. The hook file can stay on disk
  unregistered and inert while the predicate is corrected, so the lint half of the enforcement
  remains in force.
- Phases 1-3 fully satisfy the dispatch's REQUIRED DIRECTION on their own. If Phases 4-5 prove
  unworkable, close them as a reasoned exclusion with the lint extension shipped, and record the
  residual write-time gap explicitly — do not drop it silently, since the lint alone is
  evidenced-insufficient against the incident that raised this work.
- If a rollback must discard uncommitted work, follow `context/contracts/recovery.md`'s rollback
  rung for the exact snapshot-then-rollback invocation shape; never emit a bare reverting
  `git-snapshot.sh` as a precautionary checkpoint.
