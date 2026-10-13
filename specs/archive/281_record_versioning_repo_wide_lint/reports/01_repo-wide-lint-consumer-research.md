# Research Report: Repo-Wide Lint Consumer for Record-Versioning

**Task**: 281 - Build the repo-wide lint consumer for the record-versioning rule
**Started**: 2026-10-12T21:00:00Z
**Completed**: 2026-10-12T22:15:00Z
**Effort**: medium (research only; no code written this phase)
**Dependencies**: rule/taxonomy/library task (confirmed complete and merged into this corpus)
**Sources/Inputs**:
- Codebase: `scripts/check-task-references.sh` and its test, `scripts/lib/record-version-patterns.sh`
  and its test, `context/standards/record-version-exemptions.md`,
  `rules/no-record-versioning-in-deliverables.md`, `scripts/chapter-quality-check.sh`,
  `scripts/typst-element-lint.sh`, `docs/reference/utility-scripts-inventory.md`,
  `context/standards/shell-strict-mode.md`, `manifest.json`
- Live dry-run data: a reproduction harness (`strip_durable_axis_lines | strip_exempt_regions |
  grep -E "$RV_BLOCKING_ERE"/"$RV_ADVISORY_ERE"`) run against this repo's full `git ls-files`
  (excluding `specs/**`) AND against `/home/benjamin/Projects/Logos/Verification`'s deployed
  `.claude/` tree plus its `docs/` subtree — the acceptance criterion's named target repo
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The two building blocks this task depends on are already fully built and tested:
  `scripts/lib/record-version-patterns.sh` (patterns, tiers, `is_exempt_path`,
  `strip_durable_axis_lines`, `strip_exempt_regions`) and its fixture suite
  (`tests/test-record-version-patterns.sh`) both exist, pass, and match what
  `record-version-exemptions.md` documents. **There is no library gap blocking the start of
  implementation** — `scripts/check-record-versioning.sh` can be written today, line-for-line
  on `check-task-references.sh`'s shape, consuming `RV_BLOCKING_ERE`/`RV_ADVISORY_ERE` exactly as
  the dispatch specifies.
- **The acceptance criterion "running the lint with no arguments against the Verification repo
  returns exit 0" does NOT currently hold**, and will not hold the moment
  `check-record-versioning.sh` is built and pointed at either this repo or the Verification repo,
  unmodified. A live dry run using the real library found **251 BLOCKING matches across 44 files
  in this repo** and **213 BLOCKING matches across 44 files in the Verification repo's committed
  `.claude/` tree** (excluding `specs/**` in both cases).
- Root cause, isolated and reproduced: `RV_PAGE_LABEL_ERE`'s heading-form branch
  (`^#{1,6}[[:space:]].*\bv[0-9]+\b`) fires on *any* line starting with 1-6 `#` characters that
  contains a bare `vN` token *anywhere later in the line* — with no check that the token names
  the page's *own* draft version. This conflates markdown ATX headings with shell/code `#`
  comment lines that use `V<N>` as an unrelated internal invariant-naming convention, and also
  fires on legitimate headings naming a *different* entity's real version. The library's own
  calibration note states it was calibrated only against the Verification repo's `docs/`,
  `README.md`, `books/`, and `records/` trees — never against `.sh` files or other extensions'
  markdown, which is exactly where the false positives concentrate (see Findings).
- A second, narrower gap: `strip_durable_axis_lines` does not recognize a *bare* `vN` (no dot, no
  hyphen-cache-key shape, no filename, no backticks) naming a real external tool's major version
  in prose or a schema's own version in a heading — e.g. "Tailwind CSS v4", "Global Index Schema
  (v2)" — causing additional false positives distinct from the heading/comment conflation above.
- A third, self-referential gap: `tests/test-record-version-patterns.sh` embeds its own
  BLOCKING/ADVISORY positive-test strings as unmarked literal content (10 matches when scanned),
  mirroring exactly the problem `tests/test-check-task-references.sh` already solved for the
  sibling lint via `task-ref-ok:begin/end` markers around its fixture blocks.
- Separately confirmed: the acceptance criterion names `docs/setup-without-nix.md` in the
  Verification repo, which **does not exist** at that repo's current `HEAD`
  (`272d0d26`) — `git ls-files` finds no such path. The three other named files
  (`docs/ci.md`, `docs/consuming.md`, `docs/stability-and-versioning-policy.md`) do exist and
  each independently produces **0 BLOCKING matches**, confirming that narrower part of the
  acceptance bar already holds.
- Everything else the dispatch asks for (script shape, two-tier reporting precedent, wiring
  locations) has a clean, directly-copyable precedent in this repo; see Findings and
  Recommendations below.

## Context & Scope

This is a research-only dispatch for task 281: build `scripts/check-record-versioning.sh` (the
repo-wide lint consumer for `rules/no-record-versioning-in-deliverables.md`) and its fixture test
`scripts/tests/test-check-record-versioning.sh`, modeled on the sibling
`check-task-references.sh`/`test-check-task-references.sh` pair, with manifest and
utility-scripts-inventory wiring. The dispatch explicitly frames the BLOCKING/ADVISORY two-tier
reporting as "the one genuinely new design surface" and names
`chapter-quality-check.sh`/`typst-element-lint.sh` as the precedent to follow for that split.

Research scope was: (1) confirm the shared library and sibling lint shapes to copy; (2) confirm
the two-tier reporting precedent; (3) confirm the wiring locations; (4) — because the dispatch's
own acceptance criteria make specific, checkable, falsifiable claims about exit codes against a
real external repo — actually exercise the library's patterns against both this repo and the
named Verification repo to see whether those claims hold *before* a planner commits to them
unmodified. No code for the deliverable scripts was written this phase (research only); the
dry-run reproduction was done via a throwaway harness in the scratch directory, not committed.

## Findings

### Codebase Patterns

**The shared library is complete and already matches its own documentation.**
`scripts/lib/record-version-patterns.sh` exports `RV_BLOCKING_ERE` (5 sub-patterns: page-level
label, version-qualified supersession, `(v1 Decision N)` attribution, version-qualified migration
claim, past-tense-escalated-by-adjacent-vN) and `RV_ADVISORY_ERE` (bare past-tense vocabulary,
disposition-heading heuristic, disposition-table heuristic), plus `is_exempt_path`
(`specs/**`/`*/specs/*`), `strip_durable_axis_lines` (dotted semver, `@vN` pins, CI cache-key
epoch segments, filename-`vN`.md, backtick-quoted schema identifiers, the dated `**Amended
by**` note), and `strip_exempt_regions` (`version-ok`/`version-ok:begin`/`version-ok:end`). This
is a verbatim match to what `context/standards/record-version-exemptions.md` documents — **no gap
between the rule's claim and the library's actual implementation** for the patterns themselves.
Its own fixture suite (`tests/test-record-version-patterns.sh`) passes and exercises every
BLOCKING/ADVISORY category plus the three helper functions.

**The sibling lint's shape is a clean, direct template.** `check-task-references.sh`
(173 lines) gives:
- `REPO_ROOT` resolution via `deploy-root-guard.sh`, bypassed by `REPO_ROOT=$(pwd)` for
  source-store invocation (same pattern `check-extension-docs.sh` uses).
- `LIB_CANDIDATES` array trying the deployed path first, then the source-store path —
  `check-record-versioning.sh` needs the identical two-candidate array pointed at
  `record-version-patterns.sh` instead.
- `--quiet` flag, optional positional `PATH_SCOPE` (trailing-slash stripped), `[SKIP]`-and-exit-0
  on a nonexistent `PATH_SCOPE`, "." as the default repo-wide enumeration path passed straight to
  `git ls-files`.
- A `scan_tree()` function enumerating via `git -C "$REPO_ROOT" ls-files "$enum_path"`, skipping
  `is_exempt_path` matches, piping each surviving file through `strip_exempt_regions` (and, for
  the new script, also `strip_durable_axis_lines` first — the one pipeline-order difference from
  the sibling, per the library's own documented Usage order) before `grep -nEi`.
- Exit codes 0/1/2 exactly as the dispatch specifies.
- `set -uo pipefail` (no `-e`): this is a **Class B** script per
  `context/standards/shell-strict-mode.md` (it accumulates a count across every file and must
  keep scanning after an individual file's grep returns no-match, which is itself a "failure" the
  script must tolerate to produce an accurate total) — the new script should keep this same
  classification, now with two counters (BLOCKING, ADVISORY) instead of one.

**Its test's shape is an equally clean template**, including a lint/hook "scope agreement"
assertion (Case 8) that has no analogue for `check-record-versioning.sh` today, because
`hooks/validate-no-record-versioning.sh` (the planned write-time guard) does not exist yet and is
explicitly out of this task's scope — the new test should drop that one case rather than invent a
hook to agree with.

**The two-tier reporting precedent is `typst-element-lint.sh`** (and its sibling
`chapter-quality-check.sh`): per-finding lines are prefixed `[FAIL]`/`[WARN]` (color-coded,
RED/YELLOW), a running `TOTAL_FAILURES`/`TOTAL_WARNINGS` pair is accumulated, a `Summary` block
prints both counts unconditionally, and **only** `TOTAL_FAILURES` (BLOCKING-equivalent) drives the
exit code — `TOTAL_WARNINGS` (ADVISORY-equivalent) is reported but never flips `exit 1`. The exit
message itself states the warning count when warnings-only: `"...PASSED WITH WARNINGS (N advisory
findings)"`. This is directly transplantable: `check-record-versioning.sh` should report
`BLOCKING`/`ADVISORY` per finding (not `FAIL`/`WARN`, to match this rule's own vocabulary) with
two running totals, and gate only on the BLOCKING total, following `check-task-references.sh`'s
existing `PASS:`/`FAIL:` summary-line wording pattern rather than inventing a third convention.

**Wiring locations, confirmed by direct precedent inspection**:
- `manifest.json`: `check-task-references.sh` is listed in `provides.scripts` (line 90) and
  `tests/test-check-task-references.sh` in the tests list (line 308) — exact strings to mirror
  for the new script/test.
- `docs/reference/utility-scripts-inventory.md`: **`check-task-references.sh` itself has no entry
  in this file today** — it is not catalogued there despite being exactly the "standalone
  repo-health/doc-lint script not invoked in the normal lifecycle" class this file's header
  describes. This means there is no existing bullet to copy verbatim for the new script; a
  planner should write a fresh entry in this file's established style (one bullet, scope +
  exit-code behavior + any dual-purpose caveat), rather than expecting a sibling entry to pattern-
  match against. (This is a pre-existing gap in the precedent, not something task 281 introduced
  or need fix for the sibling — noted for awareness only.)

### External Resources — Live Dry-Run Against the Acceptance Target

Because the acceptance criteria make specific, falsifiable claims ("exit 0 against the
Verification repo", "zero BLOCKING findings against four named docs files"), these were tested
directly using the real library, via a harness that replicates the planned script's exact
matching pipeline (`strip_durable_axis_lines | strip_exempt_regions | grep -E
"$RV_BLOCKING_ERE"`/`"$RV_ADVISORY_ERE"`), run over `git ls-files` excluding `specs/**`, in both
this repo and `/home/benjamin/Projects/Logos/Verification`.

**Named-files sub-claim: holds.** `docs/ci.md`, `docs/consuming.md`,
`docs/stability-and-versioning-policy.md` each produce 0 BLOCKING matches. **`docs/setup-without-
nix.md` does not exist** in the Verification repo at its current HEAD (`272d0d26`,
`git ls-files | grep -i setup-without-nix` returns nothing); the acceptance criterion names a file
that is not present in the target repo today.

**Repo-wide sub-claim: does not hold, in either repo, as currently written.**

| Repo | BLOCKING matches | Files affected | ADVISORY matches |
|------|------------------:|----------------:|------------------:|
| This repo (`agent-system/`, `.opencode/`, `lua/`, `.github/`, `.gitignore`, excl. `specs/**`) | 251 | 44 | 731 |
| Verification repo (whole tree incl. its committed `.claude/`, excl. `specs/**`) | 213 | 44 | 757 |

Three distinct, separable root causes were isolated by inspecting the actual matched lines:

1. **Dominant cause — heading/code-comment conflation (the large majority of the 251/213 counts).**
   `RV_PAGE_LABEL_ERE`'s heading branch, `^#{1,6}[[:space:]].*\bv[0-9]+\b`, matches any line that
   merely *starts* with 1-6 `#` characters and *contains* a `vN` token anywhere later — with no
   requirement that the token denote the page's own draft version. A markdown ATX heading and a
   shell/Python `#`-comment line are syntactically indistinguishable to this regex. Confirmed by
   direct reproduction:
   - `scripts/git-commit-scoped.sh`: 75 matches, every one a `# ...` header comment referencing
     its own internal invariant labels ("V3 safety gate", "V9 drops", "see V7") — an established
     in-repo naming convention for numbered invariants, unrelated to document versioning.
   - `scripts/tests/test-git-commit-scoped.sh`: 70 matches, same cause (comments mirroring the
     script under test).
   - `scripts/orchestrate-batch-admit.sh`: 23 matches, same cause.
   - Several more `.sh` files in the 1-10 match range, same cause (`orchestrate-predispatch-
     review.sh`, `test-four-tier-conflict.sh`, `orchestrate-triage-classify.sh`,
     `lint-directory-pathspec-boundary.sh`, etc.) — collectively this single cause accounts for
     the large majority of every `.sh`-file match in both corpora.
   - The same branch also fires on *legitimate* markdown headings naming something **other than
     the page's own version**: `### Tailwind v4 Optimizations` (`performance-standards.md`),
     `### Tailwind CSS v4 Specifics` (`web-astro.md`), `## Breaking Changes from v2.x`
     (`migration-guide.md`) — real external-tool version references in prose, not draft-history
     labels about the page itself.
   - And on headings using a **decision/ruling-numbering idiom** this repo already relies on
     elsewhere (e.g. `(v1 Decision N)`'s sibling pattern, `**Amended by**`): `## Admission Posture
     for an Absent file_scope (v6 Ruling)` and `## Degradation (D6, NEW in v4)`
     (`batch-admit-schema.md`), `## Absent file_scope Hazard: ... (v6)`
     (`batch-orchestration-guardrails.md`), `## The ~70% v1 Miss-Rate Expectation`
     (`telemetry-guardrails.md`), `## 3. DISCARD verdicts (recorded, per v3 Phase 0)`
     (`email-preferences.md`). Whether these particular headings are themselves a latent instance
     of the exact anti-pattern this rule targets, or a legitimate numbered-ruling convention this
     taxonomy didn't anticipate, is a genuine judgment call requiring the rule owner's review —
     not something to resolve mechanically inside this task.
   - `record-version-exemptions.md`'s own calibration note states the library was "calibrated to
     zero BLOCKING findings... against the Verification repository's `docs/`, `README.md`,
     `books/`, and `records/` trees" — explicitly **not** against `.sh` files, `.claude/`, or
     other extensions' context trees. The repo-wide acceptance bar this dispatch sets is strictly
     broader than what was calibrated, and the gap between those two scopes is exactly where this
     cause concentrates.

2. **Secondary cause — durable-axis coverage gap for bare major-version mentions.**
   `strip_durable_axis_lines` recognizes dotted semver (`v[0-9]+\.[0-9]+`), `@vN` pins, hyphenated
   CI cache-key segments, and filename/backtick-anchored schema identifiers — but not a *bare*
   `vN` (no dot, no hyphen, no filename, no backticks) naming a real external tool's major version
   in ordinary prose or a heading (`Tailwind CSS v4`, `Global Index Schema (v2)`, `missing
   required v2 fields`). These are durable-axis uses by the taxonomy's own stated intent (3a/3b)
   but are not mechanically recognized today because they lack the specific shapes the function
   checks for.

3. **Self-referential cause — the pattern library's own test fixtures are unmarked.**
   `tests/test-record-version-patterns.sh`'s `assert_blocking`/`assert_advisory` calls pass
   literal strings like `"This record supersedes v1 of the convention entirely."` and `"This
   option is no longer supported."` as bash arguments — exactly the content the future
   `check-record-versioning.sh` is designed to find, and these lines carry no `version-ok`
   marker. 10 BLOCKING matches were confirmed in this one file alone. `tests/test-check-task-
   references.sh` already solved the identical self-reference problem for the sibling lint by
   wrapping every fixture-content block in `task-ref-ok:begin ... task-ref-ok:end` pairs with an
   explicit header comment explaining why ("the source lines of this test file itself ... must be
   marked exempt ... category 6: test fixture for the reference-pattern detector itself"). No
   equivalent treatment exists yet for `test-record-version-patterns.sh`.

4. **Confirmed likely-genuine, un-swept positives (distinct from all of the above).**
   `lua/neotex/plugins/tools/himalaya/docs/ARCHITECTURE_V2.md` (`# Himalaya Plugin Architecture
   V2: Elegant Module Distribution`) and `DRAFT_SYSTEM_V2.md` (`# Draft System v2 Documentation`)
   carry literal page-level version-labeled titles — the exact shape
   `record-version-exemptions.md`'s own motivating example describes (`books/convention.md`'s
   "(v2)"/"supersedes v1" case). These look like real instances of the forbidden pattern in this
   repo's own Neovim-plugin documentation, outside the agent-system corpus the original
   de-versioning sweep covered, and are a genuine "miss in the sweep" in the dispatch's own sense
   — not a discriminator bug.

### What Did NOT Need Investigating

The predecessor task's corpus-reachability probe already confirmed the confirmed-dead context set
is empty (0 of 591 files) — no context-corpus cleanup interacts with this task's file_scope, and
nothing from that report needed re-deriving here.

## Decisions

- **No library changes are required to START building `check-record-versioning.sh` and its
  test.** The script and test can and should be written now, directly modeled on
  `check-task-references.sh`/`test-check-task-references.sh`, consuming
  `RV_BLOCKING_ERE`/`RV_ADVISORY_ERE`/`is_exempt_path`/`strip_durable_axis_lines`/
  `strip_exempt_regions` exactly as documented — this task defines no patterns of its own, per the
  dispatch's own instruction.
- **The acceptance criterion's repo-wide "exit 0 against the Verification repo" clause cannot be
  met by the consumer script alone, unmodified, today.** The dispatch itself anticipates this
  outcome ("file_scope also overlaps on ... the library itself (tier refinement driven by what the
  real scan finds)" and "a nonzero exit means either a real miss in the sweep or a discriminator
  bug -- resolve which, do not relax the pattern to make it green"). This research resolves that
  "which": it is overwhelmingly cause 1 (a genuine discriminator bug in `RV_PAGE_LABEL_ERE`'s
  heading-form branch, confirmed and reproduced above), with causes 2 and 3 as smaller, distinct,
  also-genuine gaps, plus at least one confirmed real miss-in-the-sweep instance (cause 4) that is
  not a library bug at all.
- **The named `docs/setup-without-nix.md` acceptance target does not exist in the Verification
  repo.** This is a factual mismatch in the dispatch's acceptance text, not a research finding
  about the lint itself; the planner/implementer should treat the three files that do exist as the
  binding part of that sub-claim and flag this one as unverifiable against the stated name, rather
  than inventing a substitute file to test against.
- **The pattern library's own test fixture file needs the same `version-ok`-marker treatment the
  sibling lint's test already applies via `task-ref-ok` markers**, independent of whatever fix
  lands for the heading/comment conflation — this is a distinct, mechanical, low-risk fix (wrap
  the existing literal fixture strings) that should land alongside or before the repo-wide
  acceptance check is attempted, or that check will self-flag the library's own test file.

## Recommendations

1. **Write `scripts/check-record-versioning.sh` and `scripts/tests/test-check-record-versioning.sh`
   now**, following the precedents and pipeline order established in Findings above (two
   counters, BLOCKING/ADVISORY labeled findings, exit code driven only by the BLOCKING counter,
   `--quiet`/`PATH_SCOPE`/`REPO_ROOT=$(pwd)` all mirrored from the sibling). This part of the
   dispatch has no open questions.
2. **Before attempting the repo-wide acceptance check, resolve the `RV_PAGE_LABEL_ERE` heading
   false-positive class** (cause 1 above) in `scripts/lib/record-version-patterns.sh`, since
   this is squarely the library's territory per the dispatch's own file_scope note, not something
   the new consumer script should work around locally (e.g. by re-filtering results itself, which
   would defeat "the script defines none of its own patterns"). A plan should budget a phase for
   this before claiming the acceptance criterion met, rather than discovering the 251/213-finding
   flood only at verification time. Any fix must preserve every existing assertion in
   `test-record-version-patterns.sh` (its calibrated true positives, including genuinely
   version-labeled headings) while narrowing what counts as "the page's own version" — the
   concrete direction is an open design question for the plan to resolve, not pre-decided here.
3. **Extend `strip_durable_axis_lines` to cover bare major-version mentions of named external
   tools/schemas in prose and headings** (cause 2), as a smaller, additive change alongside (2).
4. **Wrap `tests/test-record-version-patterns.sh`'s own literal fixture strings in `version-ok`
   markers**, mirroring `test-check-task-references.sh`'s `task-ref-ok:begin/end` precedent
   exactly (cause 3) — low-risk, mechanical, and independent of (2)/(3).
5. **Treat the himalaya `ARCHITECTURE_V2.md`/`DRAFT_SYSTEM_V2.md` family (cause 4) as a separate,
   out-of-scope finding** for this task: either a follow-up de-versioning pass or a judgment call
   that these predate the rule and are accepted with `version-ok` markers — not something
   `check-record-versioning.sh`'s own implementation should silently special-case.
6. **Re-run this report's dry-run harness (or the finished script) against the Verification repo
   once (2)-(4) land**, before declaring the acceptance criterion met, since this report's own
   counts were produced against the *current* state of the library and will change once those
   fixes land.
7. For the `docs/reference/utility-scripts-inventory.md` wiring step, write a fresh bullet in that
   file's established style — there is no existing `check-task-references.sh` entry to copy
   verbatim, since that script itself was never catalogued there (a pre-existing gap, noted for
   awareness, not this task's to fix for the sibling).

## Risks & Mitigations

- **Risk**: a planner reads the acceptance criterion literally and schedules only the consumer
  script, discovers the 251/213-finding flood at verification time, and is tempted to "relax the
  pattern to make it green" (explicitly forbidden by the dispatch). **Mitigation**: this report's
  Decisions/Recommendations sections state the resolution explicitly so the plan can budget a
  library-fix phase up front instead of hitting this as a late surprise.
- **Risk**: a fix to `RV_PAGE_LABEL_ERE` that is too narrow (e.g. simply excluding `.sh` files by
  extension) would miss the equally-real false positives inside legitimate markdown headings
  (Tailwind v4, decision-numbering idioms) and could also under-fix if a future non-`.sh` file
  adopts the same internal-numbering convention. **Mitigation**: any fix should be judged against
  *both* failure classes identified here (code-comment conflation AND non-self-referential
  markdown headings), not just the `.sh`-file symptom that happens to dominate the raw count.
- **Risk**: the `ARCHITECTURE_V2.md`/`DRAFT_SYSTEM_V2.md` instances could be mistaken for more
  discriminator-bug noise and dismissed, when they appear to be genuine, un-swept violations.
  **Mitigation**: flagged explicitly as cause 4, structurally distinct from causes 1-3, in both
  Findings and Decisions.

## Context Extension Recommendations

- **Topic**: parity between the task-reference and record-versioning enforcement pairs.
- **Gap**: the task-reference pair has a `contracts/no-task-references-bullet.md` (an
  agent-frontmatter lint-coverage contract, consumed by `lint-agent-contracts.sh`); no analogous
  `no-record-versioning-bullet.md` contract exists yet for the record-versioning pair. This is not
  blocking for task 281 (no agent frontmatter needs a record-versioning bullet today) but is worth
  recording for whichever future task eventually builds `hooks/validate-no-record-versioning.sh`
  and wants full parity with the task-reference enforcement model.
- **Recommendation**: no action needed now; note for the write-time-hook follow-up task's own
  research phase.

## Appendix

- Search queries / commands used: `find`/`grep` over `agent-system/extensions/core/scripts`,
  `agent-system/extensions/core/context/standards`, `agent-system/extensions/typst/scripts`;
  `jq` queries against `agent-system/extensions/core/index-entries.json`; a bespoke dry-run
  harness (`strip_durable_axis_lines | strip_exempt_regions | grep -ncEi "$RV_BLOCKING_ERE"` /
  `"$RV_ADVISORY_ERE"`) sourcing the real `scripts/lib/record-version-patterns.sh` and run via
  `git -C <repo> ls-files .` over both this repo and
  `/home/benjamin/Projects/Logos/Verification`.
- References: `agent-system/extensions/core/scripts/check-task-references.sh`,
  `agent-system/extensions/core/scripts/lib/record-version-patterns.sh`,
  `agent-system/extensions/core/scripts/tests/test-check-task-references.sh`,
  `agent-system/extensions/core/scripts/tests/test-record-version-patterns.sh`,
  `agent-system/extensions/core/context/standards/record-version-exemptions.md`,
  `agent-system/extensions/core/rules/no-record-versioning-in-deliverables.md`,
  `agent-system/extensions/typst/scripts/typst-element-lint.sh`,
  `agent-system/extensions/typst/scripts/chapter-quality-check.sh`,
  `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md`,
  `agent-system/extensions/core/context/standards/shell-strict-mode.md`,
  `agent-system/extensions/core/manifest.json`.
- Issue log: one `issue` entry recorded via `issue-record.sh` (class "discriminator calibration
  gap", severity costly, suggested_channel follow_up_task) summarizing the repo-wide dry-run
  finding, pointing at this report as evidence.
