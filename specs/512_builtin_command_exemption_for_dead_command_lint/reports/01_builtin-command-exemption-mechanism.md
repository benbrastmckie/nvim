# Research Report: Built-in command exemption for dead-command lint

**Task**: 512 - Built-in command exemption for dead-command lint
**Started**: 2026-11-06T00:00:00Z
**Completed**: 2026-11-06T00:00:00Z
**Effort**: Small (single mechanism decision + two scripts + two doc lines)
**Dependencies**: None
**Sources/Inputs**:
- Codebase: `agent-system/extensions/core/scripts/lint/lint-dead-command-recommendations.sh`,
  `agent-system/extensions/core/scripts/tests/test-lint-dead-command-recommendations.sh`,
  `agent-system/extensions/core/scripts/verify-deploy.sh` (gate 24), `agent-system/extensions/core/scripts/lib/task-reference-patterns.sh`,
  `agent-system/extensions/core/scripts/lib/record-version-patterns.sh`,
  `agent-system/extensions/core/context/patterns/adoption-lint-conventions.md`,
  `agent-system/extensions/memory/context/project/memory/memory-setup.md`,
  `agent-system/extensions/memory/context/project/memory/memory-troubleshooting.md`,
  `agent-system/extensions/founder/commands/consult.md` (style precedent)
**Artifacts**:
- This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- `lint-dead-command-recommendations.sh` derives its valid-command set purely by enumerating
  `agent-system/extensions/*/commands/*.md`. A Claude Code host built-in like `/ide` can never
  appear there, so any correct recommendation of a built-in is a permanent false positive.
  Confirmed exactly two live violations today: `memory-setup.md:93` and
  `memory-troubleshooting.md:34`, both recommending `/ide`.
- This repository already has an established, precedent idiom for exactly this shape of problem:
  a plain-substring, comment-syntax-agnostic inline marker (`task-ref-ok`, `version-ok`) that
  exempts one specific, author-asserted line from an otherwise mechanical, no-hardcoded-list
  lint, with a trailing human-readable reason. `founder/commands/consult.md:22` even shows the
  exact rendered style (`<!-- task-ref-ok inline, ... -->` trailing an ordinary markdown bullet).
- **Recommended mechanism**: add a new marker, `builtin-cmd-ok`, to this lint's `classify_line()`
  using the same plain-substring convention, and apply it to the two violating lines. This keeps
  the lint's "nothing is ever hardcoded here" invariant intact (the marker names no command and
  requires no maintained set), reuses a pattern this codebase's own recent history already
  vindicated for a structurally identical problem, and needs no new allowlist, no "authoritative
  built-in command set," and no owner to maintain one.
- The two other candidates considered in the dispatch (a maintained built-in allowlist; teaching
  gate 24 to bucket these findings separately) are both weaker: the allowlist option
  reintroduces the exact hardcoded list the lint's header explicitly rejects and needs an
  authoritative built-in-command source that does not exist anywhere in this repo; the
  gate-side-bucketing option only relocates the hardcoding into `verify-deploy.sh` while leaving
  the lint itself permanently red when run standalone (its only other caller besides its own test
  suite).

## Context & Scope

`lint-dead-command-recommendations.sh` (source store:
`agent-system/extensions/core/scripts/lint/lint-dead-command-recommendations.sh`; deployed copy
`.claude/scripts/lint/lint-dead-command-recommendations.sh`, never hand-edited per
`source-store-deploy-boundary.md`) scans the full `agent-system/extensions/` corpus
(`*.md`/`*.json`) for any line shaped like `Next: /name` or `Run /name` and flags `/name` unless a
`commands/name.md` file exists somewhere under `agent-system/extensions/*/commands/`. Its own
header (lines 15-24, 36-45) documents a deliberate, explicit decision: no hardcoded allowlist,
ever — the valid-command set is derived purely by filesystem enumeration, and the lint is meant
to retire its own findings to zero.

`/ide` is a Claude Code **host-provided built-in** slash command (not part of this repository's
agent-system command surface), used by the memory extension's Obsidian-MCP setup instructions to
tell the user to run Claude Code's native IDE-connection flow. There is no `commands/ide.md`
anywhere in `agent-system/extensions/*/commands/`, and per the task description no authoritative
list of Claude Code built-ins exists anywhere in this repo to build or validate one against. The
two lines recommending it are correct and must keep working; this is a false positive in the
lint, not a defect in the documentation.

**Confirmed via direct run** (`bash lint-dead-command-recommendations.sh --verbose
agent-system/extensions/memory`):
- `agent-system/extensions/memory/context/project/memory/memory-setup.md:93` — `2. Run `/ide` in
  Claude Code and select the Obsidian instance`
- `agent-system/extensions/memory/context/project/memory/memory-troubleshooting.md:34` — `- Run
  `/ide` in Claude Code and select the running Obsidian instance from the list`

No other line in either file matches the candidate shape (the fenced-code-block-only `/ide` at
`memory-setup.md:78` and the `Run /research N --remember` step at `memory-setup.md:97` are both
owned by the sibling record `reword_dead_lifecycle_command_prose_per_class` per this task's own
scope boundary, and are out of scope here).

**Scope boundary respected**: this research addresses only the lint mechanism and its test suite
(`lint-dead-command-recommendations.sh`,
`test-lint-dead-command-recommendations.sh`) plus the minimal per-line change to the two owning
documents needed to prove the mechanism (adding the exemption marker to the existing correct
text) — never rewording the `/ide` recommendation itself, and never touching the unrunnable
`--remember` flag or the three-deleted-lifecycle-command prose, which belong to the sibling
record. All edits are source-store-targeted (`agent-system/extensions/**`), never
`.claude/**`.

## Findings

### Codebase Patterns

**The marker-exemption idiom is already established, twice, for this exact problem shape.**
Both existing instances guard a mechanical, no-hardcoded-list scan against a line that is
correct but structurally matches the scan's trigger shape:

1. `task-ref-ok` (`agent-system/extensions/core/scripts/lib/task-reference-patterns.sh`,
   `context/standards/task-reference-exemptions.md`): guards `check-task-references.sh` /
   `hooks/validate-no-task-references.sh`.
2. `version-ok` (`agent-system/extensions/core/scripts/lib/record-version-patterns.sh`,
   `context/standards/record-version-exemptions.md`): guards the record-versioning-language
   prohibition.

Both implement the identical convention, stated verbatim in `record-version-patterns.sh`'s
`strip_exempt_regions()` header (lines 259-272):
- **Inline form**: any single line containing the plain substring `version-ok` (or
  `task-ref-ok`) is itself exempt — matched as literal text, not parsed as a language comment,
  so it works identically in Markdown `<!-- -->`, shell `#`, or Lua `--`.
- **Block form**: `version-ok:begin` ... `version-ok:end` exempts every line in between.
- Both forms expect a trailing human-readable reason on the marker line itself; this is a
  human-review convention, not something the stripping function parses or validates.
- The exemption function blanks (never deletes) the matched line(s) before the real pattern
  match runs, so line numbers in any later diagnostic stay stable.

**Rendered style precedent, in this exact repo, for a markdown bullet/numbered line**:
`agent-system/extensions/founder/commands/consult.md:22`:
```
- `/consult --legal 458` - Attach consultation to existing task 458 (artifacts stored in task directory) <!-- task-ref-ok inline, command-usage example -->
```
This is structurally identical to what `memory-setup.md:93` / `memory-troubleshooting.md:34`
would need: an ordinary markdown list line, unchanged, with a trailing HTML comment carrying the
marker and a one-clause reason.

**`lint-dead-command-recommendations.sh`'s own detection model** (`classify_line()`, lines
214-238) is a single Bash function: strip markdown emphasis characters, test two anchored
regexes, then check the enumerated `VALID_SET`. It already has a clean insertion point for a
marker check — one more `[[ "$text" == *builtin-cmd-ok* ]]` (or equivalent) test ahead of (or
alongside) the enumeration check, returning the same `EXEMPT: <reason>` string shape the function
already uses for the enumerated-command case (line 232). Because the function classifies one
line (`$text`, the raw matched line including trailing content) at a time, only the inline form
of the marker idiom is needed here — there is no multi-line candidate shape in this lint's model
that a block form would ever exempt, unlike `version-ok`'s prose-paragraph use case.

**`adoption-lint-conventions.md`'s zero-tolerance/allowlist decision rule does not govern this
lint.** That document's decision rule ("non-zero migration debt selects the allowlist
convention; a class already at zero selects zero-tolerance") is scoped explicitly to *adoption
lints* — guards against a hand-rolled pattern regrowing once a shared helper exists
(`lint-state-writer-boundary.sh`, `lint-task-lookup-adoption.sh`). `lint-dead-command-
recommendations.sh` is a content-correctness lint (is this recommendation runnable?), a different
class, and its own header states its own, independently-reasoned zero-tolerance/no-allowlist
decision. The dispatch's framing ("amend that recorded decision rather than quietly contradict
it") therefore means amending `lint-dead-command-recommendations.sh`'s own header — not
`adoption-lint-conventions.md`, which is about a different lint class entirely and needs no
change.

**`gate24_run()` in `verify-deploy.sh` (lines 1890-1916) is the lint's only live caller** besides
its own test suite (confirmed by a repo-wide grep for the script's name). It runs the lint with
`--verbose` and promotes every `[VIOLATION]` line verbatim into `FINDINGS_LIST`; it has no
independent filtering logic of its own. This matters for evaluating the "teach the gate to report
separately" candidate below: there is no existing per-finding bucketing seam in `gate24_run()` to
extend without inventing one.

### External Resources

Not applicable — this is a self-contained repository-mechanism decision with no external
API/library surface; no web research was needed or performed.

## Recommendations

**Adopt the inline marker idiom, scoped to this lint only — this is the implementation path for
the plan phase:**

1. **Lint change** (`lint-dead-command-recommendations.sh`): in `classify_line()`, before (or
   alongside) the `VALID_SET` lookup, add a plain-substring check for a new marker token —
   `builtin-cmd-ok` — against the raw matched line text (not the markdown-emphasis-stripped
   `norm`, so the marker survives even if a future line happens to use emphasis characters near
   it). On a match, return `EXEMPT: line carries builtin-cmd-ok marker` using the same
   `EXEMPT: <reason>` shape the function already emits for the enumerated-command path. No
   `VALID_SET` entry is added, and no command name is ever named inside the lint's own source —
   the marker is the only new thing the lint recognizes, and it is generic (any `/name` can be
   marked on its own line by its own document author; the lint still never maintains a name
   list).
2. **Header amendment** (same file, in place of/alongside the existing "VALID-COMMAND
   ENUMERATION" section): add a short "BUILT-IN COMMAND EXEMPTION" paragraph stating plainly:
   this marker exists because a Claude Code host-provided built-in slash command (e.g. `/ide`)
   can never have a `commands/<name>.md` definition file in this corpus, so it is a structural,
   permanent false positive for this lint, not a migration-debt case; the marker is a per-site,
   author-asserted claim carrying its own trailing reason, auditable with a single `grep -rn
   builtin-cmd-ok`, and it does not reintroduce a maintained allowlist of command names — this
   is the "amend the recorded decision" step the dispatch calls for, stated in the same file the
   original zero-tolerance decision lives in, not in a separate standards doc (proportionate to
   there being exactly one exemption category, unlike `task-ref-ok`'s seven-category taxonomy).
3. **Apply the marker** to the two violating lines in the source-store copies (never
   `.claude/**`):
   - `agent-system/extensions/memory/context/project/memory/memory-troubleshooting.md:34`
   - `agent-system/extensions/memory/context/project/memory/memory-setup.md:93`
   using the rendered style already precedented at `founder/commands/consult.md:22` — append
   ` <!-- builtin-cmd-ok: /ide is a Claude Code native command, not an agent-system command -->`
   to the existing, unchanged line. No prose wording changes (that path was already considered
   and rejected in the task description).
4. **Test coverage** (`test-lint-dead-command-recommendations.sh`): add a case proving (a) a
   fixture line carrying the marker next to an undefined command name is EXEMPT (no violation,
   ideally asserting the `--verbose` output's exempt reason text), and (b) the identical fixture
   **without** the marker is still flagged — reusing Case 1's offender shape as the "without"
   control so the new case demonstrably shows the marker, not the command name, drives the
   verdict. This mirrors Case 2/Case 3's existing pattern of a positive case plus a negative
   control in the same suite.
5. **Verify**: re-run `lint-dead-command-recommendations.sh` (and/or gate 24 via
   `verify-deploy.sh`) over the full `agent-system/extensions/` corpus and confirm zero
   violations, then redeploy so the deployed `.claude/` copy picks up both the lint and the two
   documentation files.

**Why this beats the other two candidates named in the dispatch:**

- *Maintained built-in allowlist with a named owner*: requires inventing and sustaining an
  "authoritative set of Claude Code built-in commands" that, per the task description, exists
  nowhere in this repo today — and would drift silently if a host build adds/renames/removes a
  built-in, since nothing here observes the host's own command surface. It also directly
  reinstates the "hardcoded... nothing is ever hardcoded here" condition the lint's header
  currently asserts, which is a much larger amendment to defend than a generic per-line marker
  that names no commands at all.
- *Teach gate 24 to bucket these findings separately*: `gate24_run()` has no existing per-finding
  classification seam, so this would mean adding the same kind of hardcoded name check one layer
  up, in `verify-deploy.sh`, rather than in the lint — strictly worse for discoverability (a
  reader of the lint alone would still see it fail forever) and it does nothing for the lint's
  only other caller, its own test suite, or any future standalone invocation (e.g. a pre-commit
  hook) that does not go through `gate24_run()`.

## Decisions

- **Mechanism chosen**: inline substring marker (`builtin-cmd-ok`), following the `task-ref-ok`/
  `version-ok` precedent exactly, implemented inside `lint-dead-command-recommendations.sh`'s
  existing `classify_line()` — no new shared library file needed, since neither
  `task-reference-patterns.sh` nor `record-version-patterns.sh` is a natural host for a
  dead-command-recommendation-specific marker, and this lint does not currently depend on either.
- **Rejected**: a maintained built-in-command allowlist (no authoritative source to build it
  from; reinstates the exact hardcoded-list condition the lint's header rejects).
- **Rejected**: gate-24-side bucketing in `verify-deploy.sh` (relocates, rather than resolves,
  the hardcoding; leaves the lint itself red forever when invoked outside the gate).
- **Not a new standards document**: unlike `task-ref-ok`/`version-ok`, which each warrant a
  dedicated taxonomy doc because they guard many categories of legitimate exception across the
  whole repo, this lint has exactly one exemption category (a Claude Code host built-in). The
  amendment belongs in the lint's own header, where the original zero-tolerance decision already
  lives, not in a new file.

## Risks & Mitigations

- **Marker misuse as a general escape hatch** (someone marks a genuinely dead command to silence
  the lint): mitigated the same way `version-ok`/`task-ref-ok` are — the marker is `grep`-able
  (`grep -rn builtin-cmd-ok`), carries a mandatory human-readable reason inline, and remains a
  human-review concern at marker-review time, not a code-enforced claim. This is an accepted,
  precedented trade-off in this codebase, not a new risk class.
- **Marker collides with emphasis-stripping**: mitigated by checking the marker against the raw
  `$text`, not the `tr -d '`*_'`-stripped `norm` used for shape detection, so an underscore inside
  `builtin-cmd-ok` (there are none) or adjacent markdown emphasis cannot accidentally hide or
  duplicate the token.
- **Future built-in commands beyond `/ide`** (e.g. `/compact`, `/clear`, `/model` if ever
  recommended in prose): the same marker applies per-line with no further lint change required,
  since the mechanism is generic rather than naming `/ide` specifically anywhere in code.

## Context Extension Recommendations

- **Topic**: a single cross-reference doc section listing all three marker idioms
  (`task-ref-ok`, `version-ok`, and the new `builtin-cmd-ok`) side by side.
- **Gap**: each marker idiom is currently documented only in its own guarding lint/library's
  header and its own standards doc; there is no single index a future author would find by
  searching for "exemption marker" in general.
- **Recommendation**: consider, as a separate low-priority follow-up (not in this task's scope),
  adding a short "Exemption Marker Idioms" index note under `context/patterns/` cross-referencing
  all three, so a future fourth marker is designed by analogy rather than rediscovered from
  scratch. Not required for this task's own correctness.

## Appendix

### Search queries / commands used

- `find agent-system/extensions -iname "*lint-dead-command*" -o -iname "*memory-setup*" -o -iname "*memory-troubleshooting*"`
- `bash agent-system/extensions/core/scripts/lint/lint-dead-command-recommendations.sh --verbose agent-system/extensions/memory`
- `grep -n "Next:\|Run /\|/ide" agent-system/extensions/memory/context/project/memory/memory-setup.md agent-system/extensions/memory/context/project/memory/memory-troubleshooting.md`
- `grep -rn "task-ref-ok" agent-system/extensions/core/scripts/`
- `grep -n "version-ok" agent-system/extensions/core/scripts/lib/record-version-patterns.sh`
- `grep -rln "lint-dead-command-recommendations" agent-system/ .claude/`
- `grep -rn "task-ref-ok\|version-ok" --include="*.md" agent-system/extensions/`

### References

- `agent-system/extensions/core/scripts/lint/lint-dead-command-recommendations.sh` (lines 1-45,
  154-238, 240-317)
- `agent-system/extensions/core/scripts/tests/test-lint-dead-command-recommendations.sh` (full
  file — fixture structure to extend)
- `agent-system/extensions/core/scripts/verify-deploy.sh:1890-1916` (`gate24_run`)
- `agent-system/extensions/core/scripts/lib/task-reference-patterns.sh:130-150`
- `agent-system/extensions/core/scripts/lib/record-version-patterns.sh:255-281`
- `agent-system/extensions/core/context/patterns/adoption-lint-conventions.md` (full file)
- `agent-system/extensions/memory/context/project/memory/memory-setup.md:60-100`
- `agent-system/extensions/memory/context/project/memory/memory-troubleshooting.md:25-40`
- `agent-system/extensions/founder/commands/consult.md:22` (rendered-style precedent)
