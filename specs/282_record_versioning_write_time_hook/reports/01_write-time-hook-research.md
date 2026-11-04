# Research Report: Task #282

**Task**: 282 - Write-time PreToolUse hook blocking record-versioning language, registered bare so exit 2 survives
**Started**: 2026-11-03T00:00:00Z
**Completed**: 2026-11-03T00:00:00Z
**Effort**: Small (single hook + fixture test + two wiring edits)
**Dependencies**: Task 280 (rule/taxonomy/library), Task 281 (repo-wide lint consumer), Task 364 (hook registration path convention) — all three CLOSED/archived; no blocker remains.
**Sources/Inputs**:
- Codebase: `agent-system/extensions/core/hooks/validate-no-task-references.sh` (sibling model, full read)
- Codebase: `agent-system/extensions/core/scripts/lib/record-version-patterns.sh` (shared pattern library, full read)
- Codebase: `agent-system/extensions/core/scripts/check-record-versioning.sh` (repo-wide lint consumer, already built, full read)
- Codebase: `agent-system/extensions/core/scripts/tests/test-validate-no-task-references.sh` (fixture test model, full read)
- Codebase: `agent-system/extensions/core/scripts/tests/test-check-record-versioning.sh` (sibling fixture test, header + Case 8 read)
- Codebase: `agent-system/extensions/core/context/standards/record-version-exemptions.md` (Enforcement + Design Principle sections)
- Codebase: `agent-system/extensions/core/context/standards/shell-strict-mode.md` (strict-mode classification)
- Codebase: `agent-system/extensions/core/root-files/settings.json`, `agent-system/extensions/core/merge-sources/settings-hooks.json`, `agent-system/extensions/core/manifest.json`
- Codebase: `specs/archive/364_cwd_relative_hook_registration_paths/summaries/01_*.md`
**Artifacts**: This report (`specs/282_record_versioning_write_time_hook/reports/01_write-time-hook-research.md`)
**Standards**: report-format.md, subagent-return.md, shell-strict-mode.md

## Executive Summary

- All three declared dependencies (tasks 280, 281, 364) are closed. The shared pattern library
  (`scripts/lib/record-version-patterns.sh`) and the repo-wide lint
  (`scripts/check-record-versioning.sh`) already exist and already implement the full
  BLOCKING/ADVISORY two-tier contract and the durable-axis/marker exemption pipeline. Task 282's
  hook has nothing to design from scratch — it is a thin consumer, exactly as the taxonomy's
  Enforcement section already describes it.
- The new hook should be a **simplified** derivative of `validate-no-task-references.sh`: it must
  inherit the three named contracts (exit-2 blocking, fail-open on a missing/unsourceable
  library, BASH_SOURCE-relative resolution) and the Write-vs-Edit field-presence discrimination,
  but should **not** replicate that sibling's elaborate Edit-path region-aware marker
  reconstruction (occurrence counting, nested-marker depth, splice-based disk reconstruction).
  That machinery exists in the task-reference hook because `task-reference-patterns.sh`'s
  exemption stripper is depth-counting; `record-version-patterns.sh`'s `strip_exempt_regions` is
  a flat toggle (no nesting), and task 282's own acceptance criteria list only five fixture cases
  that never require disk reconstruction. Building the full region-aware machinery here would be
  scope creep against both the acceptance criteria and the underlying library's actual exemption
  semantics.
- **Finding with a concrete gap**: the dispatch directs editing only `root-files/settings.json`
  for the hook registration. `root-files/settings.json`'s own header `_comment` states it is
  **install-once** ("copied only when no project copy exists yet, never overwritten on resync")
  and explicitly instructs "Add NEW hook registrations to
  `core/merge-sources/settings-hooks.json` instead, where they propagate on every resync." The
  sibling hook (`validate-no-task-references.sh`) is in fact registered in **both** files today,
  and `manifest.json`'s own `merge_targets.settings` entry declares
  `merge-sources/settings-hooks.json` → `.claude/settings.json` as the mechanical propagation
  path. This repo is already deployed (`.claude/` exists), so editing only `root-files/
  settings.json` would never reach the live `.claude/settings.json` the dispatch's acceptance
  criterion ("grep the deployed-form command string") actually checks. The plan MUST add the bare
  registration to **both** `root-files/settings.json` AND `merge-sources/settings-hooks.json`,
  mirroring exactly where the sibling line already lives in each file.
- The hook MUST run the shared library's full two-step strip pipeline — `strip_durable_axis_lines`
  **then** `strip_exempt_regions` — before matching `rv_grep_blocking`. Omitting the first step
  (easy to do if copying the sibling file structure too literally, since the task-reference
  library has no durable-axis concept at all) is exactly what would make the acceptance
  criterion's false-positive check fail (an ordinary docs/ Write citing only a toolchain pin,
  schema filename, or CI cache-key segment must NOT be blocked).
- The write-time advisory-tier question the dispatch asks to resolve: **recommend blocking on
  BLOCKING findings only, staying silent on ADVISORY findings**, for the reason the dispatch
  itself states (write-time noise trains users to ignore the hook) — this is also consistent with
  how `check-record-versioning.sh` already treats the two tiers (ADVISORY never affects exit
  status there either; it only gates verbose reporting).

## Context & Scope

Task 282 builds the write-time enforcement consumer for the record-versioning rule
(`agent-system/extensions/core/rules/no-record-versioning-in-deliverables.md`). Two sibling
systems already exist for this rule and are the direct analogues this research draws from:

1. The **shared pattern library** (`scripts/lib/record-version-patterns.sh`), built by task 280,
   already exports everything a consumer needs: `is_exempt_path`, `strip_durable_axis_lines`,
   `strip_exempt_regions`, `rv_grep_blocking`, `rv_grep_advisory`, and `rv_is_markdown_path`. It
   fully implements the BLOCKING/ADVISORY tiering and the durable-axis discrimination (toolchain
   pins, CI cache-key epochs, schema/file-format identifiers, the dated amendment note).
2. The **repo-wide lint** (`scripts/check-record-versioning.sh`), built by task 281, is the first
   real-corpus consumer of that library and already demonstrates the correct call sequence:
   `is_exempt_path` → `strip_durable_axis_lines` → `strip_exempt_regions` →
   `rv_grep_blocking`/`rv_grep_advisory`, plus the two-tier exit-status contract (BLOCKING drives
   exit 1; ADVISORY never affects exit status).

This task's own scope is three deliverables: the hook itself
(`hooks/validate-no-record-versioning.sh`), its settings.json registration, and its fixture test
(`scripts/tests/test-validate-no-record-versioning.sh`), plus the `manifest.json` wiring for both
new files. The research below resolves every open design question the dispatch raises and
surfaces one wiring gap the dispatch's literal text does not account for.

## Findings

### Codebase Patterns

**Sibling hook structure** (`hooks/validate-no-task-references.sh`, full source read):
- `set -euo pipefail` at top (Class A per `shell-strict-mode.md` — no counter idiom, not
  sourced).
- Resolves `HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"` then
  `LIB="$HOOK_DIR/../scripts/lib/task-reference-patterns.sh"`.
- Fail-open guard has **two** explicit checks: `[ ! -f "$LIB" ]` (missing file) and
  `! . "$LIB"` (source failure) — each prints a `WARNING:` to stderr and `exit 0`. Both are
  necessary under `set -e`: an unguarded `.` failure would otherwise abort the whole hook before
  reaching any fallthrough.
- Parses stdin JSON via `jq '.tool_input // {}'`, with a `CLAUDE_TOOL_INPUT` env-var fallback for
  the flat shape.
- No `file_path` resolved → `exit 0` immediately (non-file tools).
- `is_exempt_path "$FILE"` (from the shared library) is checked before any content scan.
- Write vs. Edit discrimination is by **field presence**, never `tool_name`: `has("content")` →
  write path; `has("old_string")`/`has("new_string")` with no `content` → edit path.
- Write path: scans `content` (or `.new_string` as a fallback field name) directly, stripped
  through `strip_exempt_regions`, then matched.
- Edit path (the sibling's own later-added complexity): reconstructs the post-edit file on disk
  (splicing `old_string` → `new_string`), computes the inserted line range(s), builds an
  exempt-line mask over the **reconstructed** content via a depth-counting
  `exempt_line_mask`/`strip_exempt_regions` equivalent, and scans only the non-exempt inserted
  lines. It degrades to a payload-only scan of `new_string` alone whenever the reconstruction
  cannot be trusted (`old_string` absent from disk, ambiguous occurrence count, unreadable file).
- `scan_and_block()` is a shared helper that prints a multi-line, actionable stderr message
  naming the rule file, explains the durable-anchor alternative, mentions the marker-exemption
  escape hatch, calls `system-defect-record.sh` non-fatally, and `exit 2`s.

**Shared library for record-versioning** (`scripts/lib/record-version-patterns.sh`, full source
read) — already built, nothing to add here:
- `is_exempt_path` — `specs/**` only (no `.memory/**` carve-out exists for this rule, unlike the
  task-reference library; record-versioning has no equivalent memory-provenance exemption zone).
- `strip_durable_axis_lines` — **the one real structural difference from the task-reference
  library**: blanks (never deletes) lines matching dotted semver/toolchain pins, `@vN` action
  pins, CI cache-key epoch segments, schema/file-format filenames and backtick-quoted
  identifiers, the dated `**Amended by**` note, schema/format-anchored bare version mentions, and
  the literal `Tailwind(.. CSS)? vN` anchor. This step has **no task-reference-library
  counterpart** and **must** run before `strip_exempt_regions` (the library's own documented
  Usage order, step 3 before step 4).
- `strip_exempt_regions` — a flat `version-ok`/`version-ok:begin`/`version-ok:end` toggle (awk
  `in_block` variable), **not depth-counting**. Nesting two `version-ok:begin` pairs inside each
  other is not a meaningful fixture for this library the way it is for
  `task-reference-patterns.sh` (confirmed depth-counting per the sibling hook's own header
  comment).
- `rv_grep_blocking <path>` / `rv_grep_advisory <path>` — path-class-gated (markdown vs.
  non-markdown) and case-sensitivity-gated matching functions; a consumer never matches
  `$RV_BLOCKING_ERE`/`$RV_ADVISORY_ERE` directly.

**Repo-wide lint** (`scripts/check-record-versioning.sh`, full source read) — demonstrates the
correct consumption pattern a second time:
- Explicitly checks for all five required functions (`is_exempt_path`,
  `strip_durable_axis_lines`, `strip_exempt_regions`, `rv_grep_blocking`, `rv_grep_advisory`) via
  `declare -F` after sourcing, erroring loudly (exit 2) if any is missing — guards against a
  *stale* library (one that sourced fine but predates the two-tier API) silently producing a
  false-clean result. The hook currently has no equivalent guard; see Risks below.
- Pipeline per file: `strip_durable_axis_lines < "$file" | strip_exempt_regions`, then both
  `rv_grep_blocking` and `rv_grep_advisory` against that single stripped buffer.
- Two-tier exit contract: BLOCKING > 0 → exit 1 (`FAIL:`); BLOCKING == 0 and ADVISORY > 0 → exit 0
  with `PASSED WITH WARNINGS`; both zero → exit 0 with `PASS:`. **ADVISORY never affects exit
  status.**

**Fixture test model** (`scripts/tests/test-validate-no-task-references.sh`, full source read):
- Copies the hook and its library byte-for-byte into a `mktemp -d` workdir at the exact relative
  layout the hook expects (`<workdir>/hooks/x.sh` sourcing `<workdir>/scripts/lib/y.sh`), so the
  hook is tested as a real subprocess and is never instrumented for testability.
- `run_hook`/`hook_exit_code` helpers build synthetic PreToolUse JSON via `jq -n` (quote-safe) and
  assert on exit code (2 = blocked, 0 = allowed), never on stdout.
- Separate `assert_triggers`/`assert_silent` helpers plus a dedicated
  shared-library-missing fixture (copies only the hook, no lib dir at all) asserting `exit 0` +
  non-empty stderr.
- One marker-exempted-content fixture per Exemption Taxonomy category, each wrapped in a
  self-contained `task-ref-ok:begin`/`:end` pair or inline marker.

**Record-versioning's own lint fixture test** (`test-check-record-versioning.sh`, header +
Case 8 read) **already anticipates this task**: its header explicitly says it omits a
"lint/hook scope-agreement" case "because `hooks/validate-no-record-versioning.sh` does not exist
yet and is out of scope for this task." The task-reference sibling's equivalent case
(`test-check-task-references.sh`'s Case 8) drives both the lint and the hook over the same
fixture set and fails if their BLOCKING verdicts ever disagree on a given path+content pair. This
is a natural, already-scoped follow-up this task's plan should restore once the hook exists —
see Recommendations.

### Wiring / Registration Surfaces

- `manifest.json` has two **distinct** top-level `provides` arrays: `hooks` (where
  `"validate-no-task-references.sh"` sits, line 382) and `scripts` (a single flat array that also
  carries every `tests/test-*.sh` entry inline, e.g. `"tests/test-validate-no-task-references.sh"`
  at line 332). The new hook and test file go into these two **different** arrays respectively —
  not both into the same list.
- `root-files/settings.json`'s own header `_comment` (line 2) states it is install-once-only and
  directs new hook registrations to `merge-sources/settings-hooks.json`. Despite that, the
  sibling hook's registration is present, byte-for-byte compatible in shape, in **both**
  `root-files/settings.json` (multi-line JSON form, lines 56-64) and
  `merge-sources/settings-hooks.json` (compact single-line form). `manifest.json`'s own
  `merge_targets.settings` entry (`source: "merge-sources/settings-hooks.json"`, `target:
  ".claude/settings.json"`) is the only mechanical path from the source store into an
  already-deployed repo's live `.claude/settings.json` — confirmed by directly diffing this
  repo's deployed `.claude/settings.json` against `merge-sources/settings-hooks.json`: the
  deployed file's compact single-line hook-entry formatting matches the merge-source file, not
  `root-files/settings.json`'s multi-line formatting.
- Task 364 (closed) rewrote every hook command in both files to the
  `bash "$CLAUDE_PROJECT_DIR"/.claude/hooks/x.sh` form specifically because a bare `bash
  .claude/hooks/x.sh` resolves against the session's drifted Bash-tool cwd and silently fails
  open. The new hook's registration in both files must use this exact `$CLAUDE_PROJECT_DIR`-
  prefixed form, with no `2>/dev/null || echo '{}'` wrapper (per the dispatch's explicit
  instruction and the sibling's own precedent in both files).
- `shellcheck` 0.11.0 is present on `$PATH` in this environment; the repo's existing convention
  for a sourced-but-possibly-missing library is `# shellcheck source=<relative-path>` immediately
  above the guarded `.` line (seen in `check-record-versioning.sh` line 85 and several other
  scripts) — the new hook should carry the equivalent `# shellcheck disable=SC1090` the sibling
  hook already uses for its own dynamic source line.

### External Resources

None consulted — this is a pure codebase-pattern-replication task with no external library or
API surface; both the pattern to follow and the library to consume already exist in-repo.

## Decisions

1. **Advisory tier at write time: silent.** The hook blocks on BLOCKING findings only (via
   `rv_grep_blocking`) and takes no action at all on ADVISORY findings — it does not even call
   `rv_grep_advisory`. Rationale, matching the dispatch's own stated default: a write-time hook
   that printed advisory noise on every matching Write would train users to ignore it; advisory
   surfacing stays the repo-wide lint's job (`check-record-versioning.sh` already reports and
   counts ADVISORY findings without blocking on them). This must be recorded both in the new
   hook's own header comment and in `record-version-exemptions.md`'s Enforcement section (see
   Recommendations) so the two documents stay consistent, per the dispatch's explicit
   instruction.
2. **Edit-path scope: payload-only, not region-aware disk reconstruction.** The new hook detects
   Write vs. Edit by field presence exactly as the sibling does (`has("content")` vs.
   `has("old_string")`/`has("new_string")`), but for the Edit path it scans `new_string` alone
   (the same content the Write path would scan, just read from a different field) rather than
   reconstructing the post-edit file from disk. Rationale: `record-version-patterns.sh`'s
   `strip_exempt_regions` is a flat toggle with no nesting concept, so the nested-marker and
   occurrence-counting machinery the sibling hook's Edit path needs for `task-reference-
   patterns.sh`'s depth-counting parser has no analogous requirement here; and task 282's own
   acceptance criteria list exactly five fixture cases, none of which exercises disk
   reconstruction. Building that machinery now would be unrequested scope against both the
   acceptance list and the shared library's actual semantics. If a future task finds a real
   false-positive from scanning `new_string` alone (an edit landing inside a file-wide
   `version-ok:begin`/`:end` region whose markers sit outside the edited span), that is new,
   separate scope for a later task — mirroring exactly how the sibling's region-aware logic was
   evidently added as a distinct refinement rather than required by its own original task.
3. **Registration lands in both `root-files/settings.json` and `merge-sources/settings-
   hooks.json`.** Despite the dispatch's literal text naming only `root-files/settings.json`,
   the research above establishes that only `merge-sources/settings-hooks.json` mechanically
   propagates into an already-deployed repo's `.claude/settings.json` (via `manifest.json`'s
   `merge_targets.settings` entry), and the sibling hook is registered in both files today. The
   plan should treat "append the bare registration to the existing PreToolUse Write|Edit matcher
   block that already carries `validate-no-task-references.sh`" as applying to **both** files,
   each in its own existing JSON formatting style (multi-line in `root-files/settings.json`,
   compact single-line in `merge-sources/settings-hooks.json`), followed by a headless redeploy
   (`.claude/scripts/deploy-headless.sh`, confirmed present) to materialize the change into
   `.claude/settings.json` before the acceptance criterion's deployed-form grep is run.
4. **The hook must run `strip_durable_axis_lines` before `strip_exempt_regions`.** This is the
   one pipeline step with no task-reference-library analogue, and skipping it is the most likely
   way a naive port of the sibling hook would fail the dispatch's own false-positive acceptance
   check (an ordinary docs/ Write citing a toolchain pin, schema filename, or CI cache-key segment
   must not be blocked).
5. **Stderr message format mirrors the sibling's, scoped to this rule.** The blocking message
   must name `.claude/rules/no-record-versioning-in-deliverables.md`, state the forbidden-category
   rationale in one line, point to the `version-ok`/`version-ok:begin`/`version-ok:end` marker
   escape hatch, and (per the dispatch's acceptance wording) be "actionable" — i.e., tell the
   author what durable alternative to use, matching the sibling's own phrasing style rather than
   inventing new phrasing.

## Recommendations

1. **Hook file** (`agent-system/extensions/core/hooks/validate-no-record-versioning.sh`):
   `set -euo pipefail`; resolve `LIB` via `BASH_SOURCE`-relative `../scripts/lib/record-version-
   patterns.sh`; two-guard fail-open (missing file, source failure) each with a `WARNING:` stderr
   line and `exit 0`; parse stdin JSON the same way the sibling does (`jq '.tool_input // {}'`
   with `CLAUDE_TOOL_INPUT` fallback); `is_exempt_path` check before any content scan; Write/Edit
   field-presence discrimination; for whichever field resolves (`content` or `new_string`), pipe
   through `strip_durable_axis_lines` then `strip_exempt_regions`, then `rv_grep_blocking "$FILE"`
   — on a match, print the actionable multi-line stderr message and `exit 2`; otherwise `exit 0`.
   Do not call `rv_grep_advisory` at all (Decision 1). Do not attempt Edit-path disk
   reconstruction (Decision 2).
2. **Registration**: append the bare command (no `|| echo` wrapper) to the existing `"Write|Edit"`
   PreToolUse matcher block in both `agent-system/extensions/core/root-files/settings.json` and
   `agent-system/extensions/core/merge-sources/settings-hooks.json`, using the
   `bash "$CLAUDE_PROJECT_DIR"/.claude/hooks/validate-no-record-versioning.sh` command form
   (matching the sibling's post-task-364 form exactly). Then run a headless redeploy so the
   acceptance criterion's "grep the deployed-form command string" check has something real to
   grep.
3. **Fixture test** (`scripts/tests/test-validate-no-record-versioning.sh`): copy the hook-plus-
   library-into-`mktemp`-workdir structural model from `test-validate-no-task-references.sh`
   (adjusted for `record-version-patterns.sh`'s sibling path), and cover at minimum the
   dispatch's five named cases: (a) a BLOCKING fixture (e.g. a bare-parenthesized heading-version
   label or a supersession-plus-`vN` clause) → exit 2 + non-empty, rule-naming stderr; (b) a
   `specs/**` path with the same BLOCKING content → exit 0; (c) an ADVISORY-only fixture (bare
   past-tense vocabulary with no adjacent `vN` token) → exit 0 (silent, per Decision 1); (d) a
   `version-ok`-marked BLOCKING fixture → exit 0; (e) a deliberately-missing/broken-library
   fixture → exit 0 + non-empty warning stderr. Add a sixth case explicitly for the dispatch's
   named false-positive guard: a durable-axis-only fixture (a toolchain pin, a schema filename, a
   CI cache-key segment, with no other BLOCKING/ADVISORY content) → exit 0, proving
   `strip_durable_axis_lines` is actually wired in (Decision 4) rather than merely present in the
   sourced library.
4. **Manifest wiring**: add `"validate-no-record-versioning.sh"` to `provides.hooks` (near line
   382, alongside `"validate-no-task-references.sh"`) and
   `"tests/test-validate-no-record-versioning.sh"` to `provides.scripts` (near line 332,
   alongside `"tests/test-validate-no-task-references.sh"`) in
   `agent-system/extensions/core/manifest.json`.
5. **Taxonomy doc update**: rewrite `record-version-exemptions.md`'s Enforcement section (current
   lines ~132-152) to state, as current fact and without draft-history language (this file is a
   deliverable outside `specs/**` and is itself subject to
   `no-record-versioning-in-deliverables.md`/`no-task-references-in-deliverables.md`), that both
   consumers (the lint and the write-time hook) now exist, name their paths, and record the
   advisory-tier posture decision (Decision 1) in the same place the hook's own header states it,
   so the two documents cannot drift.
6. **Follow-up, not required for this task's acceptance**: once the hook exists, restore a
   lint/hook scope-agreement case into `test-check-record-versioning.sh` (mirroring
   `test-check-task-references.sh`'s Case 8), since that suite's own header already flags the
   omission as temporary. This can be a small addition to this task's plan or a trivial separate
   follow-up; either is reasonable, but it should not be silently dropped now that the hook this
   case needs finally exists.
7. **Optional hardening, not required**: consider porting `check-record-versioning.sh`'s
   `declare -F` guard (checking all five required library functions exist post-source) into the
   hook as well, so a *stale* (not missing, not syntactically broken) library fails open
   intentionally rather than via the incidental exit-127-is-non-2 behavior Claude Code's hook
   exit-code semantics happen to produce today (see Risks below). This is a robustness
   improvement beyond the dispatch's named three contracts, not a correctness requirement.

## Risks & Mitigations

- **Risk**: a future edit to `record-version-patterns.sh` renames or removes one of the five
  functions the hook (and the lint) depend on, without the hook noticing. **Mitigation**: either
  adopt Recommendation 7's `declare -F` guard now, or accept that Claude Code's hook-exit
  semantics (a non-0, non-2 exit from an undefined-command failure under `set -e` is treated as a
  non-blocking error, not a block) happen to fail open in this specific case anyway — document
  whichever choice is made in the hook's header so it is not accidental.
- **Risk**: editing only `root-files/settings.json` (literal dispatch text) and skipping
  `merge-sources/settings-hooks.json` would pass a superficial read of deliverable (2) but leave
  the live, already-deployed `.claude/settings.json` completely unregistered, making the
  dispatch's own acceptance check ("grep the deployed-form command string") fail or
  silently check nothing. **Mitigation**: Decision 3 above — edit both files, redeploy, then
  verify against the deployed form.
- **Risk**: copying the sibling hook's file structure too literally (including its Edit-path
  region-aware reconstruction) would require either porting depth-counting into
  `record-version-patterns.sh`'s `strip_exempt_regions` (out of scope — that library is owned by
  a closed task and this task's acceptance criteria do not ask for it) or writing a parallel,
  record-versioning-specific depth-counting routine duplicating logic the shared library is
  supposed to own exclusively, violating the library's own stated design ("Neither consumer
  defines a detection pattern ... locally"). **Mitigation**: Decision 2 — scope the Edit path to
  a payload-only scan, matching the dispatch's own five-case acceptance list.
- **Risk** (false positive, the acceptance criterion's own named worst case): forgetting
  `strip_durable_axis_lines` would block ordinary docs/ writes citing toolchain pins, schema
  filenames, or CI cache keys. **Mitigation**: Decision 4, plus the sixth fixture-test case in
  Recommendation 3 specifically proving this step is wired into the hook, not just present in the
  library.

## Context Extension Recommendations

None — this is a `meta` task operating entirely within an already-documented pattern family
(the task-reference hook/lint/library triad and its direct record-versioning analogue); no new
undocumented topic surfaced during this research.

## Appendix

Search queries / investigations used (all codebase-internal; no web search was needed):
- `find . -iname '*record-version*'` / `*task-reference*'` to locate every sibling file pair.
- Full reads: `hooks/validate-no-task-references.sh`, `scripts/lib/record-version-patterns.sh`,
  `scripts/check-record-versioning.sh`, `scripts/tests/test-validate-no-task-references.sh`.
- Targeted reads: `scripts/tests/test-check-record-versioning.sh` (header + Case-8 omission note
  in the task-reference sibling), `context/standards/record-version-exemptions.md` (Enforcement,
  Design Principle sections), `context/standards/shell-strict-mode.md` (strict-mode class rules).
- `grep`/`cat` over `manifest.json`, `root-files/settings.json`, `merge-sources/settings-
  hooks.json`, and the live deployed `.claude/settings.json` to establish the registration/
  propagation-gap finding (Decision 3).
- `specs/TODO.md` ROADMAP entry for task 282 (dependencies: 280, 281, 364) cross-checked against
  `specs/archive/280_*`, `specs/archive/281_*`, `specs/archive/364_*` to confirm all three are
  closed.
- `shellcheck --version` to confirm tool availability for the implementation phase's acceptance
  check.
