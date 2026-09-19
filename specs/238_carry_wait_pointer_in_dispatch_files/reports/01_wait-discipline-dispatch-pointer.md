# Research Report: Task #238

**Task**: 238 - Carry an external-process wait-discipline pointer in every orchestrate dispatch file
**Started**: 2026-09-19T01:17:00Z
**Completed**: 2026-09-19T01:35:00Z
**Effort**: 1.5 hours (per task estimate)
**Dependencies**: 236 (authored `context/patterns/external-process-wait.md`) — satisfied, already committed (`4b506fffe task 236 phase 1: author external-process-wait.md`)
**Sources/Inputs**: Codebase (script source, existing test suite, sibling contract docs), no web search needed (purely internal convention question)
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md, shell-strict-mode.md

## Executive Summary

- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` is the single writer of
  every `/orchestrate` dispatch file (`specs/{NNN}_{slug}/.dispatch/{seq}.md`), for all three
  phases and both base/`--hard` modes. Injecting the wait-discipline pointer here, once, reaches
  every dispatched agent regardless of `task_type` or which agent contract/hard-mode-contracts
  list it loads — exactly what the deliverable asks for.
- The correct construction is a **new unconditional block**, not a gated one. Every existing
  optional block in this script (`memory_context`, `lit_context`, `hard_contracts_block`,
  `deploy_freshness_context`, the `## Territory` pointer, `prior_decisions_block`) is emitted
  only when some flag/state is present, preserving "byte-identical when the feature doesn't
  apply." This new block must NOT follow that pattern — the deliverable explicitly wants it
  "always-present ... regardless of which agent contract it loads." The one existing precedent
  for an always-rendered, no-gate block is the closing `## User-Decision Contract` section
  (lines 510-516 of the current script), which is echoed unconditionally at the very end of the
  heredoc-style write block with no `if` around it at all. That is the structural template to
  copy, not the conditional `## Territory` pointer (which the task description names only as the
  closest *documentation-style* precedent for how the script records "the one behavior it owns,"
  not as a gating template).
- Recommended placement: a new `## Wait Discipline` section, emitted unconditionally, positioned
  immediately before the existing unconditional `## User-Decision Contract` block at the end of
  the `{ ... } > "$dispatch_file"` block (current lines ~509-517). This placement is outside every
  `if [ "$phase" = ... ]` and `if [ "$hard_mode" = "true" ]` branch, so it fires for
  research/plan/implement and base/`--hard` alike without needing three separate call sites.
- Recommended content is one pointer line plus one summary line (matching the task's "pointer
  plus one-line summary; do not inline the pattern" instruction and the terse style of the
  existing `Read context/contracts/territory.md (...) before editing any file.` pointer line):
  ```
  ## Wait Discipline

  Read context/patterns/external-process-wait.md before waiting on any long-running external or
  remote process (e.g. a CI run) — bounded polling only, never an unbounded watch, no-op filler,
  or a backgrounded/Monitor-armed wait from within this dispatch.
  ```
- Test strategy: extend `scripts/tests/test-orchestrate-build-dispatch.sh` (already the
  authoritative fixture suite for this script) with a new group asserting the pointer text is
  present in (a) a base-mode research dispatch, (b) a base-mode plan dispatch, (c) a base-mode
  implement dispatch, and (d) a `--hard` implement dispatch — i.e. the full phase × mode matrix
  the deliverable calls out ("base mode as well as `--hard`, for research, plan and implement
  phases"). Because the new block is unconditional, these assertions can mostly piggyback on
  `content` variables already captured by Groups 1, 4, 5, and 6 rather than requiring entirely new
  `run_sut` invocations — but the deliverable asks for an explicit assertion, so a small dedicated
  group is cleaner for review-legibility even though the coverage overlaps.
- `orchestrate-build-dispatch.sh` is already Class A (`set -euo pipefail`) per
  `context/standards/shell-strict-mode.md`; a handful of unconditional `echo` lines added to an
  already-strict-mode script introduces no new `-e`-hostile constructs and needs no shellcheck
  directives beyond what the file already carries.

## Context & Scope

The task is a **meta** task confined to two files:
`agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` (the dispatch-file writer)
and `agent-system/extensions/core/scripts/tests/` (its test suite). It is explicitly scoped to
adding a pointer, not inlining the six-rule wait-discipline pattern from
`context/patterns/external-process-wait.md` into the dispatch file itself. Two sibling tasks are
in flight this same `/orchestrate` cycle on disjoint files (237: agent contract files; 239: a
no-op-bash detection hook) — this task's territory (`orchestrate-build-dispatch.sh` and its
tests) does not overlap either sibling's declared `file_scope`.

## Findings

### Codebase Patterns

**Script anatomy** (`orchestrate-build-dispatch.sh`, 521 lines): the script resolves task
identity via `skill_validate_input`, computes the artifact round, gathers five "Stage 3.5"
optional inputs (`memory_context`, `lit_context`, `effort_note`, `hard_contracts_block`,
`deploy_freshness_context`), reads `.decisions.json` for `prior_decisions_block`, then writes the
entire dispatch file in one `{ echo ...; echo ...; } > "$dispatch_file"` block (lines 376-517).
Every one of those five gathered blocks, plus the `## Territory` section and its territory.md
pointer sentence, plus `prior_decisions_block`, is rendered **conditionally** — `if [ -n "$X" ]`
— so that an inactive feature produces a byte-identical dispatch file to a build from before that
feature existed. This "byte-identical when absent" invariant is explicitly called out in the
script's own comments for `--compare` (line 36-37: "so a no-flag dispatch file is byte-identical
to one built before this flag existed") and for `deploy_freshness_context` (lines 337-340: "a
build with nothing stale produces a dispatch file byte-identical to one built before this feature
existed").

The **one exception** to that invariant already in the script is the trailing
`## User-Decision Contract` section (lines 510-516), which is `echo`ed with no surrounding `if`
at all — it always appears, in every phase, every mode, regardless of any flag. This is the
correct structural precedent for a genuinely "always-present" addition, because the deliverable's
own wording — "always-present pointer ... base mode as well as `--hard`, for research, plan and
implement phases ... regardless of which agent contract it loads" — describes exactly this
unconditional-render shape, not a conditional one.

The task description points at "the script's existing single-owned-behavior conventions (see its
header note on the territory.md pointer for base-mode dispatches, which is the closest
precedent)." Reading that header note (lines 52-67) shows what it actually documents: not a
gating template, but the practice of the script's header explicitly naming, in prose, "the one
behavior this script DOES own" beyond passing through caller-supplied JSON/strings unchanged —
i.e., when this script decides on its own initiative to add prose to the dispatch file (as
opposed to relaying data the caller handed it), that decision and its rationale get a comment
block at the script's top explaining what it does and, if applicable, when it is/isn't rendered.
That is the convention to follow: add a comparable header comment block above the usage
docstring, stating plainly that the script now unconditionally appends a wait-discipline pointer
to every dispatch file it writes, and why (so a dispatched agent gets the discipline "regardless
of which agent contract it loads" — i.e., independent of `task_type`-specific `hard_contracts`
routing overrides, which is a materially different mechanism from this pointer; see next
paragraph).

**Why not route this through `hard_contracts`/`routing_lookup_flat` instead**: the script already
has a per-`task_type` override mechanism for hard-mode contract lists
(`routing_lookup_flat "hard_contracts" "$task_type"`, lines 304-321), which lets an extension
`manifest.json` replace or append contract-pointer entries. That mechanism is deliberately
**hard-mode-only** (`hard_contracts_block` is built entirely inside `if [ "$hard_mode" = "true"
]`) and **task-type-scoped**. Using it for this pointer would violate the deliverable's explicit
"base mode as well as `--hard`" requirement and would make the pointer's presence depend on
`task_type` routing configuration rather than being unconditional. The unconditional top-level
`echo` approach (matching `## User-Decision Contract`) is the only one of the two existing
mechanisms in this script that satisfies "regardless of which agent contract it loads."

**Content precedent for pointer-plus-one-line-summary style**: the closest existing single-line
pointer sentence in the script is the territory.md pointer itself (line 476): `"Read
context/contracts/territory.md (Cross-Task Territory section) before editing any file."` — a bare
imperative naming the file and, parenthetically, which section to consult. The
`external-process-wait.md` file itself is 129 lines with six numbered rules; the deliverable is
explicit that the dispatch file must carry only "a pointer plus one-line summary," not an inlined
restatement of those rules. A summary sentence naming the two or three highest-signal behaviors
(bounded polling, no unbounded watch, no no-op filler / backgrounded Monitor) mirrors how
`external-process-wait.md`'s own header line ("State, once and canonically, the defect class...")
compresses its purpose into one sentence.

**Dependency status**: task 236, which authored `context/patterns/external-process-wait.md`, is
already complete and committed (commit `4b506fffe`). The file currently has exactly two
referrers in the whole extension tree: `index-entries.json` (the context index entry, confirming
it is indexed under `domain: core`, `subdomain: patterns`) and
`context/patterns/anti-stop-patterns.md`. No agent contract and no dispatch-time script currently
points a dispatched agent at it — this task is the first wiring of it into the active dispatch
path, confirming the task's premise that "a dispatched agent receives the wait discipline
regardless of which agent contract it loads" is not yet true today.

### Existing Test Suite Structure

`scripts/tests/test-orchestrate-build-dispatch.sh` (765 lines) is the sole test suite for this
script. It follows the Class B (report-everything, `set -uo pipefail`, `PASSED`/`FAILED` counter,
`pass()`/`fail()`/`info()` helpers) shape documented in `shell-strict-mode.md`. It builds a
fixture repo under a `mktemp -d` `WORKDIR`, stubs the script's three `.claude/scripts/*.sh`
collaborators (`memory-retrieve.sh`, `literature-lit-flag-resolve.sh`,
`literature-briefing-invoke.sh`), and drives the real SUT via `run_sut <phase> [args...]`,
populating `LAST_STDOUT`/`LAST_STDERR`/`LAST_EXIT`/`LAST_DISPATCH_FILE`. It already has thirteen
numbered groups, most recently Group 13 (base-mode `--territory` pointer — the closest structural
analog to this task's own addition, since it also asserts a pointer-sentence's presence/absence
across the base/`--hard` × research/implement matrix). `assert_contains` / `assert_not_contains`
helpers (grep -qF over captured file content) are the established way to check for pointer text.

A **caveat surfaced by Group 12's `dispatch_seq` line**: two of the existing groups (12) strip
`dispatch_seq: [0-9]+` before diffing two dispatch files for an exact changed-line count, because
`run_sut`'s `--seq` value appears verbatim in the Identity section. Any new test that diffs full
dispatch files for exact line-count parity (rather than just `assert_contains`/`assert_not_contains`)
would need the same normalization; a pure presence assertion avoids this concern entirely.

### Recommendations

1. **Script change** (implementation phase, not this report): add a new unconditional block in
   `orchestrate-build-dispatch.sh`'s write section, placed after the `## Handoff` block (or
   anywhere outside the phase/mode `if` branches) and before the final `## User-Decision Contract`
   block, e.g.:
   ```bash
     echo "## Wait Discipline"
     echo ""
     echo "Read context/patterns/external-process-wait.md before waiting on any long-running external or remote process (e.g. a CI run) — bounded polling only, never an unbounded watch, no-op filler, or a backgrounded/Monitor-armed wait from within this dispatch."
     echo ""
   ```
   Add a short header-comment block above the script's usage docstring (matching the style of the
   `--territory`/`--compare`/`--phase-number` comment blocks already there) stating: this script
   unconditionally appends one wait-discipline pointer line to every dispatch file it writes, in
   every phase and every mode, so a dispatched agent receives it independent of `task_type`-scoped
   `hard_contracts` routing.
2. **Test change**: add a new group to `test-orchestrate-build-dispatch.sh` asserting
   `context/patterns/external-process-wait.md` (or the exact summary sentence) appears in the
   captured `content` for: a base-mode research dispatch, a base-mode plan dispatch, a base-mode
   implement dispatch, and a `--hard` implement dispatch (and, for completeness matching the
   deliverable's explicit phase list, a `--hard` research or plan dispatch too — hard mode's
   `hard_contracts_block` differs by phase, so exercising at least one non-implement hard-mode
   case is worthwhile the way Group 13's Case B already does for the territory pointer). Reuse
   existing captured `content` variables from Groups 1/4/5/6 where convenient instead of adding
   redundant `run_sut` calls.
3. **Do not** route this through `routing_lookup_flat "hard_contracts"` or make it
   `task_type`-conditional — that would contradict "regardless of which agent contract it loads."
4. **Do not** gate the block on `-n "$something"` the way every other optional block is gated —
   that would silently make the pointer absent by default, which is the opposite of what the
   deliverable/incident calls for. The `## User-Decision Contract` block is the correct template;
   the `## Territory` pointer is only a naming/documentation-style precedent, not a gating one.
5. shellcheck: no new sourcing, subshells, or unguarded commands are introduced by adding plain
   `echo` lines inside the existing `{ ... } > "$dispatch_file"` block, so no new `shellcheck
   disable` comments should be needed. Run `shellcheck` on the modified script as a verification
   step during implementation per `context/standards/shell-strict-mode.md`'s Class A expectations.

## Decisions

- **Placement**: unconditional, at the end of the write block, immediately before
  `## User-Decision Contract` (not inside any phase/mode conditional, and not merged into the
  conditional `## Territory` section).
- **Gating precedent to follow**: the always-rendered `## User-Decision Contract` block, not the
  conditional `## Territory`/`hard_contracts_block` blocks — despite the task description citing
  the territory.md pointer's header-note as "the closest precedent," that citation is about the
  script's convention of documenting a self-owned behavior in a header comment, not about
  replicating that pointer's conditional gating logic.
- **Content shape**: one `## Wait Discipline` heading, one blank line, one pointer-plus-summary
  sentence naming `context/patterns/external-process-wait.md` and the highest-signal behaviors
  (bounded polling; no unbounded watch/no-op filler/backgrounded-Monitor wait), one trailing blank
  line — deliberately not restating all six numbered rules from the pattern file.
- **No `hard_contracts` routing table involvement** — this pointer is script-owned and
  unconditional, not an extension-overridable contract list entry.

## Risks & Mitigations

- **Risk**: adding an always-present block breaks the "byte-identical when a feature doesn't
  apply" invariant that every other optional block in this script preserves, which could surprise
  a future reader auditing dispatch-file diffs.
  **Mitigation**: the new header-comment block (recommendation 1) should explicitly call out that
  this is a deliberate, permanent exception to that invariant — mirroring how `## User-Decision
  Contract` is already such an exception with no comment currently explaining it. Adding that one
  clarifying comment for both blocks (or at least the new one) prevents a future contributor from
  "fixing" it into a conditional.
- **Risk**: test additions duplicate existing Group 1/4/5/6/13 coverage without adding real
  signal, inflating the suite without proportionate value.
  **Mitigation**: prefer extending the existing groups' assertion lists (one `assert_contains`
  line each) over adding a wholly new group with new `run_sut` invocations, except where the
  matrix isn't already exercised (e.g., a `--hard` research/plan case) — Group 13's Case B is the
  existing invocation to attach the new assertion to for that combination.
- **Risk**: wording drift between the dispatch-file summary sentence and the actual six rules in
  `external-process-wait.md`, if that file is later revised (e.g., the ~45-minute cap or the 540s
  inner-timeout numbers change).
  **Mitigation**: keep the summary sentence deliberately vague about numeric constants (already
  planned above — it says "bounded polling," not "540 seconds") so it does not need to be
  re-synchronized every time the pattern file's specifics are tuned.

## Context Extension Recommendations

None. This is a meta task whose target files (`orchestrate-build-dispatch.sh` and its test
suite) are already fully documented by their own in-file comments and by
`context/standards/shell-strict-mode.md`; no new `.claude/context/` topic is warranted.

## Appendix

- Files read: `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` (full),
  `agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh` (full),
  `agent-system/extensions/core/context/patterns/external-process-wait.md` (full),
  `agent-system/extensions/core/context/standards/shell-strict-mode.md` (full),
  `agent-system/extensions/core/context/formats/return-metadata-file.md` (full).
- Commands run: `grep -rln "external-process-wait"`, `git log --oneline -- <two paths>`,
  `jq -r '.active_projects[] | select(.project_number==238)' specs/state.json`.
- No web search was needed; this is a purely internal shell-script convention question with a
  single canonical source file (`orchestrate-build-dispatch.sh`) and a single canonical test
  suite already covering it.
