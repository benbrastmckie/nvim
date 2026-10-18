# Implementation Plan: Task #443

- **Task**: 443 - Task-reference hook resolve markers against full file
- **Status**: [NOT STARTED]
- **Effort**: 5.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/443_task_reference_hook_resolve_markers_against_full_file/reports/01_resolve-markers-against-full-file.md
- **Artifacts**: plans/01_resolve-markers-against-full-file.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The write-time gate `hooks/validate-no-task-references.sh` scans only the current Edit call's
`new_string` payload, so a file-wide `task-ref-ok:begin`/`:end` pair living outside the edited
span is structurally invisible to it. The fix is region-aware resolution over a reconstructed
post-edit file for the Edit path only: read the on-disk file, splice `old_string` -> `new_string`
literally, and ask whether the lines the edit actually inserted fall inside a **well-formed**
marker span. The Write path keeps using its own `tool_input.content` and must never consult the
stale on-disk file.

Making that question answerable requires upgrading the shared library's marker parser from a
boolean toggle to a depth counter with an explicit well-formedness verdict, so that nested pairs
behave sanely and an unterminated `begin` or stray `end` grants no exemption at all. That
tightening is **not** behavior-preserving on the current tree: five source-store test files end
their marker parse at non-zero depth today, so a marker-hygiene phase lands first, before the
parser changes under them.

### Research Integration

The research report's design is adopted substantially unchanged, and this plan executes it:

- **Region-aware over whole-file-boolean** — adopted as the chosen semantics. A whole-file
  boolean ("one complete pair anywhere exempts the file") is a standing bypass and diverges from
  the repo-wide lint's own region-based stripping.
- **Depth counter over boolean flag** — adopted, in the shared library so both consumers benefit
  identically rather than only the hook.
- **Well-formedness gates exemption** — adopted. An unterminated `begin` or a stray `end`
  establishes nothing. The plan strengthens the report's "last unterminated begin" wording to
  **outermost** still-open `begin` (the one whose depth 0 -> 1 transition never returns to 0),
  which is strictly more fail-closed.
- **Write path unchanged** — adopted; formalized by a regression test rather than new code.
- **Graceful degradation** — adopted: a new file, an unreadable on-disk file, an `old_string`
  that is absent, or an ambiguous occurrence count all fall back to today's payload-only scan,
  which is never weaker than the status quo for that edit.
- **Six-case test matrix** — adopted verbatim as Phase 3's checklist.

One finding this plan adds that the report did not anticipate, confirmed by an `awk` depth trace
over every git-tracked non-exempt file: **five source-store files currently parse to
`eof_depth > 0`**, two of them because of the very redundant nested `begin`s the dispatch calls
noise, and three because *prose that merely mentions the literal token* is itself parsed as a
marker. Under the new validity rule their trailing regions become scannable and the repo-wide
lint (verify-deploy gate 4) would go red. Phase 1 therefore remediates marker hygiene *before*
Phase 2 changes the parser, and Phase 4 adds a standing balance diagnostic so the condition
cannot silently re-accumulate.

| File (under `agent-system/extensions/core/scripts/tests/`) | eof_depth | first unclosed `begin` | cause |
|---|---|---|---|
| `test-check-task-references.sh` | 1 | line 28 | prose mention parsed as a marker |
| `test-gate-cache-equivalence.sh` | 1 | line 349 | prose mention parsed as a marker |
| `test-git-commit-phase.sh` | 1 | line 16 | redundant nested `begin` (line 375) with no own `end` |
| `test-git-commit-scoped.sh` | 1 | line 1422 | redundant nested `begin` (line 1696) with no own `end` |
| `test-orchestrate-record-decision.sh` | 3 | line 23 | prose mention + two self-described "no-op re-assertion" `begin`s (lines 246, 373) |

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch; no roadmap consultation was performed.

## Goals & Non-Goals

**Goals**:
- The write-time gate honors a file-wide `task-ref-ok` pair for an Edit landing anywhere inside
  it, removing the need for redundant nested pairs.
- Exemption is decided region-aware, over the reconstructed post-edit file, for the inserted
  lines only.
- An unterminated `begin` or a stray `end` grants no exemption, in either consumer.
- Nested and overlapping pairs resolve correctly via a depth counter.
- The Write path's decision stays based solely on its own complete new content.
- A new file, an unreadable file, or an unresolvable `old_string` degrades silently to today's
  payload-only scan — never an error, never a weaker verdict.
- The hook and the repo-wide lint share one marker parser, so neither can diverge.
- The chosen semantics are recorded in `context/standards/task-reference-exemptions.md`.
- Test coverage for all six cases the dispatch names, plus the library's own parser edge cases.

**Non-Goals**:
- No change to `TASK_PATTERN`, `PHASE_PATTERN`, `TASK_SEP`, `is_exempt_path`, the marker syntax
  itself, or the Exemption Taxonomy table's categories. This is a resolution-algorithm change.
- No change to `scripts/check-task-references.sh`'s scan scope or its whole-file reading. The
  only lint change is the additive balance diagnostic in Phase 4.
- `strip_exempt_regions` keeps its line-**deleting** semantics (not the line-blanking shape used
  by the separate `record-version-patterns.sh` library). The lint's reported line numbers are
  therefore still post-strip numbers, which is a pre-existing cosmetic defect left untouched
  here.
- `scripts/lib/record-version-patterns.sh` and `scripts/check-record-versioning.sh` are a
  parallel, independent implementation that happens to export a same-named
  `strip_exempt_regions` over a different token (`version-ok`). They are **out of scope** and
  must not be edited. They carry the same latent boolean-toggle shape; that is an observation
  for a future task, not work for this one.
- No new exemption mechanism for test fixtures. The existing inline-marker convention is reused.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The depth-counter tightening turns verify-deploy gate 4 red because of the five imbalanced files | H | H (confirmed, not hypothetical) | Phase 1 remediates all five *before* Phase 2 touches the parser; Phase 1's own verification is "today's lint still green AND the balance trace reports zero imbalance" |
| A prose mention of the literal `task-ref-ok:begin` token in newly written code or docs re-creates an imbalance | M | H | Phase 4 adds a standing balance diagnostic to the lint; every file this task touches is re-traced in its own phase verification; new prose refers to the markers without embedding the `:begin`/`:end` literal |
| The library's own source file must itself stay marker-balanced — the rewrite adds `awk` patterns and comments containing the literal tokens | H | M | Each `begin`-bearing line added to the library is paired with an `end`-bearing line, in order; the phase verification re-traces the library file itself, not just its behavior |
| New test fixtures embedding literal marker tokens unbalance their own file | M | H | Prescribed convention: keep citation literals in variable assignments carrying a trailing inline `# task-ref-ok` comment (the existing file convention, which adds no depth), and compose any needed `:begin`/`:end` fixture token at runtime from concatenated parts so the literal substring never appears in the source |
| `sed`-based splicing corrupts the merge on regex metacharacters in `old_string`/`new_string` | H | M | Literal splicing only, via bash parameter expansion with a quoted pattern (`${s%%"$old"*}` / `${s#*"$old"}`); never `sed`, never a regex |
| An ambiguous `old_string` match (zero occurrences, or multiple with `replace_all` false) silently misclassifies the edit | M | M | Treat any occurrence count other than the expected one as a merge failure and take the degrade path, which is exactly today's verdict — never looser, never stricter |
| The live deployed hook is the OLD payload-only one until Phase 5, so Phases 1-4 edits that add fixture literals get blocked by the very defect being fixed | M | H | Use the inline-marker-on-assignment-line convention for every new fixture literal (self-contained on one line, visible to the old hook); redeploy only in Phase 5 |
| Reading the on-disk file adds I/O to a hook that runs on every Write/Edit in the repo | L | L | One `cat`, one in-memory splice, one `awk` pass per Edit; measured as negligible at this scale, no caching warranted |
| A sibling task in this same cycle edits a shared file | M | L | No file in this plan's scope appears in any concurrent sibling's declared `file_scope`; re-read every file immediately before editing and stage only this task's own hunks |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3, 4 | 2 |
| 4 | 5 | 3, 4 |

Phases within the same wave can execute in parallel.

### Phase 1: Marker Hygiene — Rebalance the Five Imbalanced Files [NOT STARTED]

**Goal**: Bring every git-tracked non-exempt file's `task-ref-ok` marker parse to `eof_depth = 0`
with no stray `end`, so the Phase 2 parser change lands on a tree that already satisfies the new
validity rule. Under today's boolean toggle these edits are semantically inert, which is what
makes this phase independently verifiable.

**Tasks**:
- [ ] Re-read each of the five files immediately before editing it (sibling-concurrency rule).
- [ ] `test-git-commit-phase.sh`: delete the redundant nested `begin` block near line 375 (the
      marker line and its two explanatory comment lines), leaving the file-wide pair at line 16
      and the `end` at line 454 as the only region. This is precisely the noise the dispatch
      observation names.
- [ ] `test-git-commit-scoped.sh`: delete the redundant nested `begin` near line 1696 and its
      explanatory comment lines, leaving the pairs at 968/1150 and 1422/1798.
- [ ] `test-orchestrate-record-decision.sh`: delete the two self-described "no-op re-assertion"
      `begin` lines near 246 and 373 (with their comment continuations), leaving the pair at
      29/430; then reword the header prose near line 23 so it no longer contains the literal
      `:begin` token (refer to the markers by name without embedding the parseable substring).
- [ ] `test-check-task-references.sh`: reword the header prose near line 28 so it no longer
      embeds the literal token. Leave the in-heredoc fixture pair (lines 154/156) alone — it is
      already balanced in order.
- [ ] `test-gate-cache-equivalence.sh`: reword the prose near line 349 so it no longer embeds the
      literal token. Leave the pair at 358/360 alone.
- [ ] Re-run the balance trace and confirm it reports nothing.

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: exactly five files are imbalanced, at the line numbers tabulated in
"Research Integration" above, and the prose rewordings expose no previously-shielded citation
(spot-checked at plan time: lines 29-91 of `test-check-task-references.sh`, 350-357 of
`test-gate-cache-equivalence.sh`, and 24-28 of `test-orchestrate-record-decision.sh` contain no
`TASK_PATTERN`/`PHASE_PATTERN` match). Confirm at implementation time by re-running the balance
trace before and after, and by running the repo-wide lint after each file.

**Tier Justification**: covered by `bash agent-system/extensions/core/scripts/check-task-references.sh --quiet` plus `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-check-task-references.sh,test-gate-cache-equivalence.sh,test-git-commit-phase.sh,test-git-commit-scoped.sh,test-orchestrate-record-decision.sh` — the five edited files are the five suites, and no parser or shared code changes in this phase.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-check-task-references.sh` - reword the header prose mention near line 28
- `agent-system/extensions/core/scripts/tests/test-gate-cache-equivalence.sh` - reword the prose mention near line 349
- `agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh` - delete the redundant nested `begin` near line 375
- `agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` - delete the redundant nested `begin` near line 1696
- `agent-system/extensions/core/scripts/tests/test-orchestrate-record-decision.sh` - delete two re-assertion `begin`s, reword the header prose near line 23

**Verification**:
- The balance trace reports zero imbalanced files across the whole tree:
  ```
  git ls-files | grep -v '^specs/' | grep -v '^\.memory/' | while read -r f; do
    grep -q 'task-ref-ok' "$f" 2>/dev/null || continue
    awk -v F="$f" '
      /task-ref-ok:begin/ { if (depth==0) fo=NR; depth++; next }
      /task-ref-ok:end/   { if (depth>0) depth--; else stray++; next }
      END { if (depth>0 || stray>0) printf "%s eof_depth=%d first_unclosed=%s stray=%d\n", F, depth, (depth>0?fo:"-"), stray+0 }
    ' "$f"
  done
  ```
- `bash agent-system/extensions/core/scripts/check-task-references.sh --quiet` exits 0.
- The five suites named in the Tier Justification all pass.

---

### Phase 2: Shared Library — Depth-Counter Parser, Validity Verdict, Per-Line Mask [NOT STARTED]

**Goal**: Replace `strip_exempt_regions`' boolean toggle with a depth-counting parser that
carries an explicit well-formedness verdict, and expose the per-line exemption classification the
hook's region check needs — all in the one shared library, so the hook and the repo-wide lint
cannot diverge.

**Tasks**:
- [ ] Rewrite `strip_exempt_regions` as a buffered two-pass `awk` program: pass one buffers every
      input line while counting `begin` (+1) and `end` (-1, clamped at 0 so a stray `end` closes
      nothing and is inert); pass two emits the surviving lines.
- [ ] Implement the validity rule: if the counter is above 0 at EOF, every line from the
      **outermost** still-open `begin` (the `begin` whose 0 -> 1 transition never returned to 0)
      through EOF is NOT exempt and is emitted as ordinary scannable content. Well-formed pairs
      earlier in the same file keep their exemption. A line that itself carries an inline
      `task-ref-ok` token stays exempt by the inline rule regardless.
- [ ] Preserve today's behavior everywhere else: `begin`/`end`/inline marker lines are dropped,
      lines inside a well-formed region (depth > 0) are dropped, everything else is printed.
- [ ] Add `exempt_line_mask`: reads content on stdin, writes exactly one `1` (exempt) or `0` (not
      exempt) per input line, using the identical parser and validity rule. This is the function
      the hook's region check consumes; it never strips, so the caller can map mask positions
      back to line numbers.
- [ ] Add `marker_balance_report`: reads content on stdin, writes a one-line diagnostic naming
      `eof_depth`, the first unclosed `begin`'s line number, and any stray-`end` count when the
      parse is invalid, and writes nothing when it is well-formed. Phase 4's lint diagnostic
      consumes this rather than re-deriving it.
- [ ] Factor the parser once (a single `awk` program text, or one helper the three functions
      share) so the three entry points cannot drift apart.
- [ ] Keep the library file **itself** marker-balanced: every added line containing the literal
      `:begin` token is matched, in order, by a line containing the literal `:end` token. Re-run
      the balance trace against the library file specifically.
- [ ] Update the library's header comment block to describe depth-counting, the validity rule,
      and the two new functions, without embedding an unbalanced literal token.
- [ ] Create `scripts/tests/test-task-reference-patterns-lib.sh`, a dedicated fixture-driven
      suite for the parser itself (the library has no direct suite today; both existing suites
      test consumers). Follow the `pass()`/`fail()`/`info()` + `PASSED`/`FAILED` + `mktemp -d` +
      `trap EXIT` conventions in `context/standards/shell-script-testing.md`. Cases:
      a well-formed pair; nested pairs; a stray `end` before any `begin`; an unterminated
      `begin` with a citation after it (NOT exempt); an unterminated `begin` preceded by a
      well-formed pair (the earlier pair stays exempt); the inline form; a `begin` and `end` on
      the same line; content with no markers at all; and `exempt_line_mask` emitting exactly one
      value per input line. Compose fixture marker tokens at runtime from concatenated parts so
      the literal `:begin`/`:end` substrings never appear in this new file's own source.
- [ ] Register `tests/test-task-reference-patterns-lib.sh` in `manifest.json`'s `scripts` array
      (the whole-tree orphan-detection gate requires it, and an unregistered script never reaches
      a deployed tree). Optionally add an advisory `tests/suite-cost-hints.txt` entry; the hint
      file is advisory-only and a missing entry yields an INFO line, not a failure.

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: `strip_exempt_regions` has exactly two consumers within this library's own
contract — `scripts/check-task-references.sh` and `hooks/validate-no-task-references.sh` — and no
other caller depends on its edge-case behavior. The same-named function in
`scripts/lib/record-version-patterns.sh` is a separate implementation over a different token and
is not a consumer of this library. Confirm at implementation time with
`grep -rn 'strip_exempt_regions\|exempt_line_mask\|marker_balance_report' --include='*.sh' agent-system/`
before and after, and by confirming no script sources both libraries.

**Tier Justification**: this changes a shared library's observable edge-case behavior through an unchanged signature, so the covering check is the two enumerated direct dependents' suites plus the repo-wide lint they drive: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-task-reference-patterns-lib.sh,test-check-task-references.sh,test-validate-no-task-references.sh` together with `bash agent-system/extensions/core/scripts/check-task-references.sh --quiet`.

**Files to modify**:
- `agent-system/extensions/core/scripts/lib/task-reference-patterns.sh` - depth-counter rewrite of `strip_exempt_regions`; new `exempt_line_mask` and `marker_balance_report`; header documentation
- `agent-system/extensions/core/scripts/tests/test-task-reference-patterns-lib.sh` - NEW dedicated parser suite
- `agent-system/extensions/core/manifest.json` - register the new test script
- `agent-system/extensions/core/scripts/tests/suite-cost-hints.txt` - optional advisory cost hint for the new suite

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-task-reference-patterns-lib.sh` passes.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-task-reference-patterns-lib.sh,test-check-task-references.sh,test-validate-no-task-references.sh` passes — the two existing consumer suites must pass **unchanged**, proving the rewrite is behavior-preserving outside the specific defects being fixed.
- `bash agent-system/extensions/core/scripts/check-task-references.sh --quiet` exits 0 (Phase 1 already made the tree satisfy the new validity rule).
- The Phase 1 balance trace still reports nothing, including for the library file and the new test file themselves.
- Manifest registration confirmed: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-manifest-scripts-sync.sh,test-script-inventory.sh` passes.

---

### Phase 3: Hook — Edit-Path Merge and Region Resolution, With the Six-Case Matrix [NOT STARTED]

**Goal**: Make the Edit path resolve markers against the reconstructed post-edit file,
region-aware over the inserted lines only, while leaving the Write path's decision basis exactly
as it is — and prove all six of the dispatch's named cases.

**Tasks**:
- [ ] Extend payload parsing to also extract `.tool_input.old_string` and
      `.tool_input.replace_all`, on both the stdin path and the `CLAUDE_TOOL_INPUT` env fallback.
- [ ] Discriminate the two tool paths by **field presence** (`content` present -> Write;
      `old_string`/`new_string` present -> Edit), not by `tool_name`. The existing suites' synthetic
      payloads carry only `tool_input`, and the env fallback carries no tool name at all, so a
      `tool_name` dependency would silently change which path the tests exercise.
- [ ] Write path: unchanged. Keep `CONTENT` from `.tool_input.content` and keep **not** reading
      `FILE` from disk. Add a comment stating that the on-disk file is the stale pre-write state
      and is the wrong basis here.
- [ ] Edit path: attempt `ON_DISK=$(cat "$FILE" 2>/dev/null)`. On any failure (new file, race,
      permissions), or when `old_string` is empty/absent, take the degrade path — today's
      payload-only `strip_exempt_regions` scan of `new_string`, no error, no warning noise.
- [ ] Edit path merge: splice **literally** via bash parameter expansion with a quoted pattern
      (`prefix="${rest%%"$old"*}"`, `rest="${rest#*"$old"}"`). Never `sed`, never a regex. Count
      occurrences while splicing; replace the first occurrence only unless `replace_all` is true,
      in which case replace all.
- [ ] Occurrence-count guard: zero occurrences, or more than one with `replace_all` false, is a
      merge failure -> degrade path. Never a looser or stricter verdict than today's.
- [ ] Record the 1-based line range each inserted `new_string` occupies in the merged content
      (line count of the merged prefix + 1, through that plus the newline count of `new_string`).
- [ ] Run `exempt_line_mask` over the merged content. The edit is exempt iff **every** line in
      **every** recorded inserted range is masked exempt; if so, exit 0 without pattern-matching
      those lines at all (a covered-but-literally-matching line is the entire point of a marker).
- [ ] Otherwise scan **only the non-exempt lines of the inserted ranges** against
      `PHASE_PATTERN` then `TASK_PATTERN`, preserving the existing two-message ordering, the
      stderr guidance text, the `system-defect-record.sh` call, and `exit 2`. Never scan the rest
      of the file: a pre-existing unmarked violation this edit never touched remains the
      repo-wide lint's finding, not this edit's block.
- [ ] Preserve the fail-open-on-missing-library contract and the early `is_exempt_path` /
      empty-`FILE` / empty-`CONTENT` exits exactly as they are.
- [ ] Add a `run_hook_edit <file_path> <disk_content> <old_string> <new_string>` helper to
      `scripts/tests/test-validate-no-task-references.sh`: write `disk_content` to `file_path`
      inside the suite's existing `mktemp -d` workdir, then pipe a
      `{tool_input:{file_path, old_string, new_string}}` payload built with `jq -n --arg` (safe
      against quotes and parens), mirroring the existing `run_hook`/`hook_exit_code` shape.
- [ ] Case 1 — Edit inside a file-wide pair: on-disk file has `begin` ... edited region ...
      `end`; `new_string` carries a bare citation. Expect exit 0. **This is the dispatch's
      observation, asserted.**
- [ ] Case 2 — Edit outside any pair in a file that has one: same file, edited region physically
      before or after the marker span. Expect exit 2.
- [ ] Case 3 — Unterminated marker: on-disk file has a `begin` with no `end`; the edit lands
      after it and carries a bare citation. Expect exit 2 — the unterminated marker exempts
      nothing.
- [ ] Case 4 — Nested pairs: on-disk file has `begin A` ... `begin B` ... `end B` ... `end A`.
      Assert exit 0 for an edit inside the B-within-A nest, and a second exit-0 case for an edit
      between `end B` and `end A` (still inside A only).
- [ ] Case 5 — Write of a new file: `file_path` does not exist. Assert `[ ! -e "$file_path" ]`
      before invoking, so the "no on-disk read attempted" claim is exercised rather than assumed.
      Assert exit 0 for clean content and exit 2 for a citation-bearing content, and no
      crash/stderr noise either way.
- [ ] Case 6 — Write that would remove a marker: on-disk file has a `begin`/`end` pair wrapping a
      citation; the Write's `content` keeps the citation but drops the markers. Expect exit 2 —
      the Write path never falls back to stale on-disk markers to rescue content that no longer
      carries its own.
- [ ] Add degenerate Edit cases: `old_string` absent from the on-disk file, and an unreadable
      target — both must take the degrade path and behave exactly as today's payload-only scan.
- [ ] Keep every new citation literal in a variable assignment carrying a trailing inline
      `# task-ref-ok` comment, per this suite's own documented convention, and compose any
      needed `:begin`/`:end` fixture token at runtime so no new unbalanced literal enters the
      file. Re-run the balance trace against this file after editing.
- [ ] Add a nested-pair fixture to `scripts/tests/test-check-task-references.sh` confirming the
      lint's whole-file behavior is unaffected by the library's internal rewrite.

**Timing**: 2 hours

**Depends on**: 2

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: the six cases the dispatch names, plus the two degenerate Edit cases above,
are the complete new coverage, and the hook is a leaf consumer with no dependents of its own.
Confirm at implementation time that the new assertions all appear in the suite's PASSED count and
that `grep -rn 'validate-no-task-references' agent-system/` surfaces no caller beyond the
settings registration and the suite.

**Tier Justification**: the edit is confined to one script with no externally visible signature and no dependents, and is covered end-to-end by `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-validate-no-task-references.sh,test-check-task-references.sh`, which drives the hook as a real subprocess over all six fixture cases.

**Files to modify**:
- `agent-system/extensions/core/hooks/validate-no-task-references.sh` - Edit-path merge + region resolution; Write path documented as unchanged
- `agent-system/extensions/core/scripts/tests/test-validate-no-task-references.sh` - `run_hook_edit` helper + the six dispatch cases + two degenerate Edit cases
- `agent-system/extensions/core/scripts/tests/test-check-task-references.sh` - nested-pair regression fixture

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-validate-no-task-references.sh` passes with every pre-existing assertion still green and all six new cases green.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-validate-no-task-references.sh,test-check-task-references.sh,test-task-reference-patterns-lib.sh` passes.
- `bash -n agent-system/extensions/core/hooks/validate-no-task-references.sh` is clean, and `shellcheck` reports nothing new if available.
- The fail-open-on-missing-library assertion still passes (it is already in the suite).
- The balance trace still reports nothing for the two edited test files.

---

### Phase 4: Lint Diagnostic and Documented Semantics [NOT STARTED]

**Goal**: Give the new validity rule a loud, named diagnostic instead of a confusing cascade of
unrelated findings, and record the chosen resolution semantics where both consumers' contract
lives.

**Tasks**:
- [ ] In `scripts/check-task-references.sh`, call the library's `marker_balance_report` per
      scanned file and emit an explicit, named finding when a file's marker parse is invalid
      (naming the file, the `eof_depth`, and the first unclosed `begin`'s line), so the operator
      sees "unbalanced marker in <file>" rather than a sudden pile of fixture-literal findings.
      Keep the existing per-file finding loop, exit-code contract, and `--quiet` behavior
      otherwise unchanged; this is additive.
- [ ] Add an "Enforcement" subsection to `context/standards/task-reference-exemptions.md` stating
      the resolution algorithm precisely: for an Edit, markers resolve against the reconstructed
      post-edit file and only the inserted lines need be covered; for a Write, markers resolve
      against that call's own complete new content and never the stale on-disk file; an
      unterminated `begin` or a stray `end` grants no exemption, and the non-exempt span runs
      from the outermost still-open `begin` to EOF; nested pairs resolve by depth; and an
      unresolvable merge degrades to the payload-only scan. State that both consumers get this
      from one shared parser.
- [ ] Note in the same subsection that prose which embeds the literal `:begin` token is itself
      parsed as a marker, and that documentation should name the markers without embedding that
      substring — the hazard that produced three of the five imbalances Phase 1 fixed.
- [ ] Do not alter the Exemption Taxonomy table or any category definition.
- [ ] Keep the doc file marker-balanced; re-run the balance trace against it.

**Timing**: 0.75 hours

**Depends on**: 2

**Verification Tier**: local

**Commit Mode**: per-substep

**Tier Justification**: covered by `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-check-task-references.sh,test-validate-no-task-references.sh` for the lint change plus `bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 agent-system/extensions/core` for the markdown edit, whose suite selection returns only `test-validate-no-task-references.sh` and therefore needs the explicit source-store `TARGET` form rather than the bare no-argument one.

**Files to modify**:
- `agent-system/extensions/core/scripts/check-task-references.sh` - additive unbalanced-marker finding via `marker_balance_report`
- `agent-system/extensions/core/context/standards/task-reference-exemptions.md` - new Enforcement subsection stating the resolution semantics

**Verification**:
- `bash agent-system/extensions/core/scripts/check-task-references.sh --quiet` exits 0 on the clean tree.
- Seeding a scratch fixture file with an unterminated `begin` produces the named unbalanced-marker finding and a non-zero exit; removing it restores exit 0.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-check-task-references.sh,test-validate-no-task-references.sh` passes.
- `bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 agent-system/extensions/core` passes.
- The balance trace reports nothing for the edited doc.

---

### Phase 5: Redeploy and Full Gate Verification [NOT STARTED]

**Goal**: Land the source-store changes into the deployed `.claude/` tree and verify the complete
gate set, including the live hook behaving as designed against a real edit.

**Tasks**:
- [ ] Confirm every change lives under `agent-system/extensions/core/` and nothing was
      hand-authored under `.claude/**` (a disposable deploy artifact).
- [ ] Run `bash .claude/scripts/deploy-headless.sh` to regenerate the deploy tree.
- [ ] Confirm the deployed copies match the source store for all seven touched source files plus
      the new test script, and that the new test script actually reached
      `.claude/scripts/tests/`.
- [ ] Run the complete gate set: `bash .claude/scripts/verify-deploy.sh`.
- [ ] Run the complete shell suite battery: `bash .claude/scripts/tests/run-all.sh`.
- [ ] Exercise the live, deployed hook end-to-end: make a real Edit inside a file-wide marker
      pair that would have required a nested pair before this change, and confirm it is allowed
      without one; then confirm an unmarked citation in an ordinary deliverable is still blocked.
- [ ] Re-run the balance trace across the whole tree one final time.

**Timing**: 0.5 hours

**Depends on**: 3, 4

**Verification Tier**: full

**Commit Mode**: per-substep

**Files to modify**:
- No source files are modified in this phase; it regenerates the `.claude/` deploy tree from the
  source-store changes made in Phases 1-4 and verifies the complete gate set.

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` passes — the complete gate set it aggregates, not a
  hand-picked subset, and not under `--skip-slow` or `--only-gate`.
- `bash .claude/scripts/tests/run-all.sh` passes with no new failures and no new entries needed
  in `known-failures.txt`.
- The live deployed hook allows an Edit inside a file-wide pair with no nested pair present, and
  still blocks an unmarked citation outside any pair.
- The whole-tree balance trace reports nothing.

---

## Testing & Validation

- [ ] All six cases the dispatch names are asserted in
      `scripts/tests/test-validate-no-task-references.sh`: Edit inside a file-wide pair, Edit
      outside any pair in a file that has one, unterminated marker, nested pairs, Write of a new
      file, Write that would remove a marker.
- [ ] Both degenerate Edit cases (absent `old_string`, unreadable target) take the degrade path.
- [ ] The new `scripts/tests/test-task-reference-patterns-lib.sh` covers the parser directly:
      well-formed, nested, stray `end`, unterminated `begin`, unterminated `begin` after a
      well-formed pair, inline form, same-line `begin`+`end`, no markers, and mask arity.
- [ ] Every pre-existing assertion in `test-validate-no-task-references.sh` and
      `test-check-task-references.sh` still passes unchanged — the rewrite is behavior-preserving
      outside the two specific defects being fixed.
- [ ] `bash agent-system/extensions/core/scripts/check-task-references.sh --quiet` exits 0 on the
      clean tree, and emits a named finding for a seeded unbalanced-marker fixture.
- [ ] The whole-tree marker balance trace reports zero imbalanced files.
- [ ] `bash .claude/scripts/verify-deploy.sh` and `bash .claude/scripts/tests/run-all.sh` both
      pass after redeploy.
- [ ] No file landing under `agent-system/**` carries an unmarked task-number citation or any
      record-versioning language.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/lib/task-reference-patterns.sh` — depth-counting parser,
  validity verdict, `exempt_line_mask`, `marker_balance_report`.
- `agent-system/extensions/core/hooks/validate-no-task-references.sh` — region-aware Edit-path
  resolution over the reconstructed post-edit file; Write path unchanged and documented as such.
- `agent-system/extensions/core/scripts/check-task-references.sh` — additive unbalanced-marker
  finding.
- `agent-system/extensions/core/context/standards/task-reference-exemptions.md` — the recorded
  resolution semantics.
- `agent-system/extensions/core/scripts/tests/test-task-reference-patterns-lib.sh` — new parser
  suite.
- `agent-system/extensions/core/scripts/tests/test-validate-no-task-references.sh` — the six-case
  matrix plus `run_hook_edit`.
- `agent-system/extensions/core/scripts/tests/test-check-task-references.sh` — nested-pair
  regression.
- Five rebalanced test files (Phase 1).
- `agent-system/extensions/core/manifest.json` — new test script registered.
- A regenerated `.claude/` deploy tree.

## Rollback/Contingency

Every phase is a separate commit, so rollback is per-phase with `git revert`. Reverting Phase 2
alone would leave the hook calling library functions that no longer exist, so Phases 2 and 3 must
be reverted together if either is rolled back; Phase 1 and Phase 4's doc edit are independently
revertible.

If the depth-counter tightening proves to have a blast radius beyond the five files Phase 1
identified, the contingency is to keep the depth counter (which fixes nesting) and relax the
validity consequence to today's behavior for `strip_exempt_regions` only, while keeping the strict
verdict in `exempt_line_mask` — the hook stays fail-closed, the lint keeps its current tolerance,
and the two consumers still share one parser. This is a documented fallback, not the plan: it
trades the standing fail-closed guarantee in the lint for compatibility, so take it only on
observed evidence.

If the Edit-path merge proves unreliable on real payloads, the degrade path is already the whole
of today's behavior, so widening the degrade condition (for example, degrading on any
`replace_all` edit) reduces the fix's reach without ever making the gate weaker than it is now.

After any rollback, re-run `bash .claude/scripts/deploy-headless.sh` so the deployed tree matches
the source store, then `bash .claude/scripts/verify-deploy.sh`.
