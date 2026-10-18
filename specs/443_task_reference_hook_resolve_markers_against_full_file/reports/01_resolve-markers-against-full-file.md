# Research Report: Resolve `task-ref-ok` Markers Against the Full File

**Task**: 443 - Task-reference hook resolve markers against full file
**Started**: 2026-10-18T08:24:00Z
**Completed**: 2026-10-18T08:35:00Z
**Effort**: Medium (one hook + one shared library + one doc section + test coverage; no change
to the lint, which already reads whole files)
**Dependencies**: None
**Sources/Inputs**: Codebase (`hooks/validate-no-task-references.sh`,
`scripts/lib/task-reference-patterns.sh`, `scripts/check-task-references.sh`,
`scripts/tests/test-validate-no-task-references.sh`), `context/standards/task-reference-exemptions.md`,
`root-files/settings.json` (hook registration), the cited issue-log entry's observation.
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The write-time hook scans only the Edit tool's `new_string` payload (or the Write tool's
  `content` payload) in isolation. For **Edit**, that payload is a snippet, not the file — so a
  file-wide `task-ref-ok:begin`/`:end` pair that lives outside the edited span is invisible to
  the hook even though it already covers that span. For **Write**, the payload *is* the whole
  new file already, so this defect does not exist there today.
- Recommended semantics: **region-aware, not whole-file-boolean.** For an Edit, reconstruct the
  post-edit file (on-disk content with `old_string` → `new_string` applied) and ask whether the
  *specific lines the edit inserted* fall inside a **well-formed** marker span in that
  reconstructed file. A whole-file boolean ("the file contains a complete pair somewhere, so
  exempt the whole file") is explicitly rejected — it would let one marker pair anywhere turn
  off the hook for every future edit to that file, which is a bypass, not a fix.
- "Well-formed" means every `begin` is closed by a later `end` before EOF. An unterminated
  `begin` (or a stray `end` with no open `begin`) must **not** establish exemption for anything
  — this is what keeps the change fail-closed per the task's own constraint.
- Nested/overlapping pairs are naturally subsumed by switching the current boolean `in_block`
  flag to a **depth counter**: depth > 0 at a line means "inside a well-formed region" whether
  that's because of one outer pair or several nested ones. This also explains why the nested
  pairs the observation complains about were pure noise — once resolution is file-wide, the
  outer pair alone already covers the edit; an inner pair adds nothing.
- The Write path needs **no behavioral change** — it must keep using `tool_input.content`
  (the complete post-write file) and must **never** read the on-disk file to decide a Write's
  exemption, since on-disk content there is the stale pre-write state. The task's "Write that
  would remove a marker" test case exists specifically to guard against a regression that would
  pull on-disk markers into the Write decision.
- New-file / unreadable-on-disk-file case: degrade gracefully to the current snippet-only,
  self-contained-marker-only resolution (no merge attempted, no error) rather than failing the
  hook open or crashing.

## Context & Scope

Scope: evaluate whether `hooks/validate-no-task-references.sh` should resolve `task-ref-ok`
markers against the full on-disk file rather than only the current Edit/Write payload, so a
file-wide marker pair is honored for edits anywhere inside it, while keeping the hook and the
repo-wide lint (`scripts/check-task-references.sh`) consistent (both consume
`scripts/lib/task-reference-patterns.sh`) and keeping the fail-closed posture intact. Also in
scope: deciding whether a "region-aware" or "whole-file boolean" formulation is correct, and
documenting the chosen semantics in `context/standards/task-reference-exemptions.md`.

Out of scope (per the dispatch and per this agent's research-only contract): writing the actual
code changes, the doc-section edit, or new tests. Those are plan/implementation work; this
report is the design evaluation and recommendation they should execute from, including the
exact algorithm, edge cases, and the specific test fixtures to add.

## Findings

### Current behavior (confirmed by reading the code)

`hooks/validate-no-task-references.sh` (source store: `agent-system/extensions/core/hooks/`):

- Parses the PreToolUse payload, extracting `FILE` from `.tool_input.file_path` and `CONTENT`
  from `.tool_input.content // .tool_input.new_string` (falls back to `CLAUDE_TOOL_INPUT` env
  var). **It never reads `.tool_input.old_string`, and it never reads the file at `FILE` from
  disk.**
- Exits 0 (allow) early for `is_exempt_path` matches (`specs/**`, `.memory/**`) and for empty
  `FILE`/`CONTENT`.
- Otherwise pipes `CONTENT` through `strip_exempt_regions` (the shared library's awk-based
  marker stripper) and matches `TASK_PATTERN`/`PHASE_PATTERN` against what survives; a match
  exits 2 (block), with a `system-defect-record.sh` call and nothing otherwise exits 0.
- Registered in `root-files/settings.json` under `"matcher": "Write|Edit"` — both tools hit the
  same script, and the script's own content extraction (`.content // .new_string`) is what makes
  Write and Edit behave identically in shape today, even though their semantics differ (see
  below).

`scripts/lib/task-reference-patterns.sh`'s `strip_exempt_regions`:

```awk
/task-ref-ok:begin/ { in_block = 1; next }
/task-ref-ok:end'   { in_block = 0; next }
in_block             { next }
/task-ref-ok/        { next }
{ print }
```

This is a **boolean flag**, not a counter, and it only ever sees whatever `CONTENT` it is handed
— it has no notion of "this snippet sits inside a region whose `begin` is somewhere else." Three
consequences follow directly from this shape, and all three are exactly the dispatch's
observation and constraints:

1. **Edit's payload is a snippet, not the file.** `new_string` is the replacement text only. A
   file-wide pair living outside that snippet is structurally unreachable by this function no
   matter how it's tuned — the function only ever receives the snippet.
2. **Write's payload already is the whole file.** `tool_input.content` for a Write *is* the
   complete new file content. `strip_exempt_regions` already resolves markers across that whole
   content today. There is no "Write defect" to fix in the sense the Edit side has one — the
   open question for Write is purely "don't let it also consult the *old*, on-disk file," which
   the current code already avoids (it never reads disk at all) and must continue to avoid.
3. **An unterminated `begin` already exempts everything after it to EOF**, because `in_block`
   never resets. This is latent in today's code too, but today's blast radius is capped at one
   snippet; once the hook starts reading the whole on-disk file for Edit, the same latent
   boolean-flag defect would have a much larger blast radius (the rest of a real file, not a
   `new_string`) — so it must be fixed as part of this change, not left as-is.

`scripts/check-task-references.sh` (the repo-wide lint, the file's second consumer) already
reads whole files (`strip_exempt_regions < "$file"`, via `git ls-files`), so it is the one
"ground truth" for what whole-file-aware resolution should look like, and it is unaffected by
this change — the task's constraint ("keep the two library consumers consistent... the lint
already reads whole files; the point of the change is to close the gap, not open a new
divergence") is satisfied automatically as long as the new Edit-path logic, once it reconstructs
the full post-edit file, uses the *same* marker-matching semantics the lint/awk already uses
(modulo the depth-counter upgrade below, which should land in the shared library so both
consumers benefit identically rather than only the hook).

### Why "whole-file boolean" is the wrong formulation

A naive fix would be: "if the on-disk (or merged) file contains *any* complete
`task-ref-ok:begin`/`:end` pair, treat the whole file as exempt for this edit." This satisfies
the observation (a file-wide pair now protects edits anywhere in the file) but violates the
task's explicit fail-closed constraint: once a file acquires one complete pair anywhere — even
one wrapping an unrelated single line — every future edit to that file, anywhere, including an
edit that introduces a brand new, totally unrelated task-number citation far from the original
pair, would be silently allowed. That is a standing bypass, not a bug fix, and it also diverges
from the lint, which does region-based stripping (lines *inside* a pair are dropped; lines
*outside* a pair are still scanned) rather than an all-or-nothing file verdict. Region-aware
resolution is the only formulation consistent with the lint's existing behavior and with the
fail-closed constraint.

### Recommended algorithm

**Shared-library change** (`scripts/lib/task-reference-patterns.sh`): generalize
`strip_exempt_regions`'s boolean `in_block` into a **depth counter**, and add a second function
that reports exempt/non-exempt **per line** (needed by the hook's region check) rather than only
stripping:

```awk
# depth starts at 0; a line is "covered" if depth > 0 at that line, OR the line itself
# is an inline `task-ref-ok` (non begin/end) marker line, OR it is a begin/end marker
# line that is itself part of a WELL-FORMED pair.
#
# Well-formedness must be checked in a first pass: walk the file once counting
# begin (+1) and end (-1); if depth is ever negative (stray end) clamp it back to 0
# and do NOT treat that end as closing anything; if depth > 0 at EOF (unterminated
# begin(s)), the LAST unterminated begin's region (from that begin's line to EOF)
# is NOT exempt -- re-run with that trailing, never-closed region treated as
# ordinary scannable content. A single forward pass with a clamp-at-zero counter and
# a "did we reach EOF at depth 0" check implements this directly: if the pass ends at
# depth > 0, the result is invalid and the function should report that every line
# from the outermost still-open begin onward is NOT exempt (append, don't silently
# swallow).
```

In practice this is a small, well-tested rewrite of the existing 5-line awk block plus a
pre-pass validity check; it does not need a general nesting grammar, only the three guarantees
the task asks for: (a) nested pairs behave sanely (depth counter handles this for free), (b) a
stray `end` is inert rather than going negative/toggling something off that was never open, and
(c) an unterminated `begin` does not swallow the remainder of the file.

**Hook change** (`hooks/validate-no-task-references.sh`), Edit path only:

1. In addition to the existing `CONTENT` (`new_string`), also extract
   `.tool_input.old_string` and `.tool_input.replace_all` when the tool is Edit. (Write has no
   `old_string`; its path is unchanged — see below.)
2. Attempt `ON_DISK=$(cat "$FILE" 2>/dev/null)`. If the read fails (new file, race, permission
   issue) or `old_string` is empty/absent or not found in `ON_DISK`, **fall back to today's
   behavior exactly** (scan `new_string` alone via `strip_exempt_regions`) — this is the
   "new-file case... without erroring" and "old_string not found" degenerate case the task asks
   for. No hook error, no crash, just the pre-existing narrower check.
3. Otherwise, construct `MERGED` = `ON_DISK` with `old_string` replaced by `new_string` at the
   matched occurrence(s) (all occurrences if `replace_all` is true, matching Edit-tool
   semantics), and record the line range(s) the inserted `new_string` occupies in `MERGED`.
4. Run the shared library's per-line exemption classifier (see above) over `MERGED`. The edit is
   **exempt** iff every line in the recorded `new_string` range is classified "covered." If
   exempt, exit 0 immediately — do not also pattern-match that range (a covered-but-literally-
   matching line is the whole point of the marker).
5. If not exempt (or only partially covered), scan **only the non-covered lines of the inserted
   range** for `TASK_PATTERN`/`PHASE_PATTERN` — never the rest of the file. This preserves the
   existing invariant that the hook blocks only on what *this edit introduces*, not on
   pre-existing, untouched violations elsewhere in the file that this edit never touches. (A
   file that already has an unrelated, unmarked violation elsewhere is the repo-wide lint's job
   to catch on its own sweep, not this edit's problem.)

**Hook change, Write path: none.** Keep extracting `CONTENT` from `.tool_input.content` exactly
as today, and keep *not* reading `FILE` from disk on the Write path. The task's "Write that
would remove a marker" test case is a regression guard for exactly this: it must assert that a
Write whose new content lacks a marker that *was* present in the pre-write on-disk file is still
blocked if the new content contains an unmarked citation — i.e. that no future edit accidentally
makes the Write path consult on-disk markers the way the Edit path now consults on-disk content.

### Test matrix (maps directly to the six cases the dispatch names)

| # | Case | Fixture shape | Expected |
|---|------|----------------|----------|
| 1 | Edit inside a file-wide pair | On-disk file has `begin`...(unrelated lines)...`old_string region`...(unrelated)...`end`; edit's `new_string` lands between them and contains a bare task-number citation | exit 0 (allowed) |
| 2 | Edit outside any pair in a file that has one | Same file, but `old_string`/`new_string` region is physically outside (before/after) the `begin`/`end` span | exit 2 (blocked) |
| 3 | Unterminated marker | On-disk file has a `begin` with no matching `end` anywhere in the file; edit lands after the `begin` and contains a bare citation | exit 2 (blocked) — proves the unterminated marker does NOT silently exempt the remainder |
| 4 | Nested pairs | On-disk file has `begin A` ... `begin B` ... `end B` ... `end A`; edit lands inside the B-in-A nest with a bare citation | exit 0 (allowed), and a second case with the edit between `end B` and `end A` (still inside A only) also exit 0 |
| 5 | Write of a new file | `file_path` does not exist on disk at all; `tool_input.content` is the full new content, with and without a citation | exit 0/2 purely by content, and critically: **no error/crash** from the (skipped) on-disk read |
| 6 | Write that would remove a marker | On-disk file has `begin`/`end` wrapping a citation; the Write's `content` (full replacement) keeps the citation but drops the markers | exit 2 (blocked) — proves the Write path never falls back to the stale on-disk markers to rescue content that no longer carries its own marker |

All six need the Edit cases (1-4) to write real fixture files into the test's `mktemp -d`
workdir (the existing harness already creates a workdir with `hooks/` and `scripts/lib/`
subdirectories for the copied hook and library; adding target fixture files alongside, and a new
`run_hook_edit <file_path> <disk_content> <old_string> <new_string>` helper that (a) writes
`disk_content` to `file_path` inside the workdir and (b) pipes a
`{tool_input:{file_path, old_string, new_string}}` JSON payload, mirroring the existing
`run_hook`/`hook_exit_code` helpers in `scripts/tests/test-validate-no-task-references.sh`) is
the natural extension point. Cases 5-6 reuse the existing Write-shaped
`{tool_input:{file_path, content}}` payload helper; case 5 additionally asserts the target path
is absent before invocation (`[ ! -e "$file_path" ]`) so the "no on-disk read attempted" claim is
actually exercised, not merely assumed.

A parallel, smaller addition to `scripts/tests/test-check-task-references.sh` is **not**
required — the lint already reads whole files and is not touched by this change — but it is
worth a quick negative check there too (a nested-pair fixture) once the shared library's
`strip_exempt_regions` is rewritten to a depth counter, purely to confirm the lint's existing
behavior is unaffected by the library's internal rewrite.

## Decisions

- **Region-aware resolution over a reconstructed post-edit file is the chosen semantics**, not a
  whole-file boolean. Only the specific lines an Edit inserts are checked for marker coverage;
  pre-existing, untouched content elsewhere in the file is never re-scanned by this hook (that
  remains the lint's job).
- **Depth-counter marker parsing** (not a boolean flag) is the chosen parsing model in the
  shared library, specifically so nested pairs are handled correctly and so the counter's
  validity (reaching 0 by EOF) can be used to detect — and refuse to honor — unterminated
  `begin`s and stray `end`s.
- **The Write path's exemption decision must never read the on-disk file.** `tool_input.content`
  (the complete post-write content) remains the sole basis, exactly as today; this is a
  no-op for the Write path, formalized by a dedicated test rather than new code.
- **Graceful degradation, not an error, when a merge isn't possible** (new file, unreadable
  on-disk file, `old_string` not found on disk): fall back to the current snippet-only,
  self-contained-marker check. This never WEAKENS the existing fail-closed behavior — it simply
  declines to grant a file-wide exemption it cannot safely compute, which is exactly today's
  status quo for that edit.
- The semantics above should be recorded in `context/standards/task-reference-exemptions.md` as
  a new subsection under "Enforcement" (e.g. "Write-time gate: full-file marker resolution"),
  stating: the write-time gate resolves markers against the reconstructed post-edit file for
  Edit calls (region-aware: only the inserted lines need be covered), resolves markers against
  the Write call's own complete new content for Write calls (never the stale on-disk file), and
  that an unterminated `begin` or a stray `end` never grants exemption. This is a resolution-
  algorithm clarification, not a change to the marker syntax or the Exemption Taxonomy table
  itself — no taxonomy category changes are implied by this task.

## Recommendations

1. Implement the shared-library depth-counter rewrite in `scripts/lib/task-reference-patterns.sh`
   first, with its own fixture-driven unit coverage (nested pairs, stray `end`, unterminated
   `begin`) before wiring it into the hook — this isolates the trickiest part (marker-validity
   parsing) from the Edit-merge logic and lets the lint's existing test suite
   (`test-check-task-references.sh`) double as a regression guard for the rewrite with zero
   behavior change expected there.
2. Then implement the hook's Edit-path merge-and-region-check logic as described above, extending
   `scripts/tests/test-validate-no-task-references.sh` with the six fixture cases in the Test
   Matrix section, using a new `run_hook_edit` helper alongside the existing `run_hook`/
   `hook_exit_code` Write-shaped helpers.
3. Add the Write-path regression test (case 6) even though no Write-path code changes — it is
   the cheapest possible guard against a future refactor accidentally pulling on-disk content
   into that path.
4. Document the chosen semantics in `context/standards/task-reference-exemptions.md` per the
   Decisions section above, in the same pass as the code change (not deferred), since the
   taxonomy doc explicitly claims to be the behavioral source of truth both consumers implement.
5. No change to `scripts/check-task-references.sh` itself is needed; only confirm (via the
   library rewrite's own tests) that its existing whole-file scanning behavior is unaffected by
   the `strip_exempt_regions` internals changing from boolean to depth-counter.
6. Per the task's own blanket instruction: any new fixture content landing under
   `agent-system/**` (test file literals) is the standing marker-exempt zone already used by
   `test-validate-no-task-references.sh` today — no new exemption mechanism is needed, reuse the
   file's existing self-contained-pair / trailing-inline-comment conventions documented in that
   file's own header comment.

## Risks & Mitigations

- **Risk**: the Edit-merge step (locating `old_string` in on-disk content and substituting
  `new_string`) could misbehave on `replace_all` edits with multiple occurrences, or on content
  containing regex-metacharacters if implemented naively with `sed`. **Mitigation**: implement
  the substitution as a literal (non-regex) single-pass string replace — e.g. via a small
  `awk`/`python3 -I`-free bash routine using parameter-expansion-safe literal matching, or by
  locating the byte offset of `old_string` and splicing — never by feeding `old_string`/
  `new_string` through `sed`'s regex-flavored substitution syntax.
- **Risk**: a merge failure or an ambiguous `old_string` match (zero or multiple occurrences
  when `replace_all` is false) could silently misclassify the edit. **Mitigation**: treat
  anything other than exactly the expected occurrence count as a merge failure and fall back to
  the degrade path (recommendation above), never to a looser or stricter verdict than today's.
- **Risk**: the depth-counter rewrite changes `strip_exempt_regions`'s output for some edge case
  the current boolean flag happened to handle differently (e.g. a stray `end` before any
  `begin`, which today's flag silently no-ops on since `in_block` is already 0 and the
  unconditional `in_block = 0; next` branch still fires, dropping that `end` line regardless).
  **Mitigation**: the library rewrite's own fixture tests should include every edge case the
  *current* awk block's control flow implies, not just the new ones this task adds, so the
  rewrite is verified to be behavior-preserving everywhere except the specific defects being
  fixed (unterminated `begin`, nesting).
- **Risk**: performance — reading the on-disk file and reconstructing merged content on every
  Edit adds I/O to a PreToolUse hook that runs on every Write/Edit in the repo. **Mitigation**:
  negligible in practice (one `cat`, one in-memory substitution, one awk pass over a single
  file); no caching or further optimization is warranted at this scale.

## Context Extension Recommendations

- **Topic**: write-time marker resolution algorithm.
- **Gap**: `context/standards/task-reference-exemptions.md`'s "Enforcement" section currently
  describes the write-time gate only at the behavioral level ("scans new/edited content...
  denies the write via exit code 2") without stating *which* content it resolves markers
  against for Edit vs. Write. This gap is exactly what let the Edit-snippet-only defect persist
  unnoticed.
- **Recommendation**: add the subsection named in the Decisions section above as part of the
  implementation phase for this task (not deferred to a separate meta task), since it is a
  direct, small addition to a file this task's implementation will already be touching.

## Appendix

- Files read: `hooks/validate-no-task-references.sh`, `scripts/lib/task-reference-patterns.sh`,
  `scripts/check-task-references.sh`, `context/standards/task-reference-exemptions.md`,
  `scripts/tests/test-validate-no-task-references.sh`, `root-files/settings.json` (hook
  registration section only).
- Searches run: `find . -iname "*task-reference*" -o -iname "*validate-no-task*"` (enumerated
  all six touch points: hook, library, lint, two test files, two docs); `grep` for the hook's
  registration and matcher in `root-files/settings.json`.
- No web search was needed — this is a closed, self-contained shell/awk design question fully
  answered by the existing codebase and the cited issue-log observation.
