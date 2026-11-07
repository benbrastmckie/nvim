# Research Report: Task #471

**Task**: 471 - Add lint-extension-readme-table.sh and wire it into verify-deploy.sh's gate set
**Started**: 2026-11-05
**Completed**: 2026-11-05
**Effort**: medium (one new lint script + one new test suite + two small verify-deploy.sh edits + one registry row + a manifest sync)
**Dependencies**: task 470 (verify-deploy.sh TARGET-contract task) — same header/argument-parsing
  region; serialize, do not co-schedule
**Sources/Inputs**: codebase (agent-system/extensions/core/scripts/, gate-registry.data,
  verify-deploy.sh, agent-system/extensions/README.md, manifest.json files), git log/show
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The required lint has no existing mechanical analog: `check-extension-docs.sh` checks each
  extension's *own* README against its own manifest, never the top-level
  `agent-system/extensions/README.md` Available Extensions table against the real directory set.
  The new lint is genuinely new, not a near-duplicate of anything in `scripts/lint/`.
- **Outcome #3 ("stale gate-id cap") is already fixed on current HEAD** — confirmed independently
  by reading the code, not by trusting the dispatch's description. The `--only-gate` validation
  at `verify-deploy.sh` no longer uses a literal `-gt 23`; commit `3d28b4399` ("task 810 phase 4")
  already rewrote it to derive `_only_gate_max_id` from `gate_registry_ids` at runtime, falling
  back to the literal `23` only if the registry degrades to empty. `--only-gate 24` and
  `--only-gate 25` both validate correctly today. The implementer should re-confirm this at
  implementation time (concurrent writers are touching this same file — see Risks) and, if still
  true, report outcome #3 as "already resolved, no code change needed" rather than inventing a
  change to code that isn't broken.
- **A genuine, currently-live table/directory mismatch exists right now**, independent of the
  four-rows-missing drift task 467 fixed: the `sapience` extension (created by task 482, which
  landed *after* this task's dispatch context was authored) has a real directory at
  `agent-system/extensions/sapience/` with no row in the Available Extensions table. This directly
  contradicts the dispatch's "CURRENT STATE... the table is CORRECT right now" framing — that
  framing was accurate when captured, but a concurrent task has since invalidated it. The new
  lint, once wired into the gate set, **will fail on the real corpus** until a `sapience` row is
  added to the table. Outcome #5 ("full gate set green after redeploy") is unreachable without
  that row. This is an in-scope fix the implementation phase must make (add the row, following
  the `approvals`/`memory`/`slidev` pattern of `Task Type: -` for a routing-exempt extension),
  not scope creep — it is a precondition for the task's own acceptance criterion.
- The registry already has 25 gates (not 24); `gate24_run` and `gate25_run` are both defined. The
  new gate should be numbered **26**, contingent on reconfirming no other in-flight task has
  claimed that id by the time implementation starts (see Risks/concurrency note).
- `sync-manifest-scripts.sh --write` is the correct, already-built mechanism for the manifest
  `provides.scripts`/test declaration — confirmed it exists, is source-store-only, and is
  surgical (never a whole-document rewrite).

## Context & Scope

Researched: (1) what sibling lint scripts in `agent-system/extensions/core/scripts/lint/` look
like structurally, to follow their conventions rather than invent a new shape; (2) the exact
current state of `gate-registry.data` and `verify-deploy.sh`'s gate wiring, dependency grammar,
and `--only-gate` cap logic; (3) whether outcome #3's described bug is still present; (4) whether
the dispatch's "table is correct right now" claim still holds; (5) the manifest/test-declaration
mechanism (`sync-manifest-scripts.sh`).

Out of scope for this report (left for planning/implementation): the exact byte-for-byte new
lint script and its test fixtures; the precise new gate id (needs a fresh concurrency check at
implementation time); the exact README.md table-row text for `sapience`.

## Findings

### Codebase Patterns

**Sibling lint shape** (read `lint-dead-command-recommendations.sh` in full as the template,
since it is the most recent full-corpus table/registry-style lint added):
- `set -euo pipefail`, sources `lib/common.sh` and (where a scan-path/flag-parsing helper is
  wanted) `lib/lint-corpus-scan-lib.sh` via `lint_corpus_scan_parse_flags` for `--verbose`/
  `--quiet`/positional-path handling.
- Dual-mode `resolve_project_root()`: tries `common_repo_root "$SCRIPT_DIR" 3` first, then walks
  up to 8 parents looking for `agent-system/extensions`, so the script runs identically from the
  source-store copy and the deployed copy.
- Default scan root falls back to `$PROJECT_ROOT/agent-system/extensions` when no path args are
  given; an empty/missing default root is a loud `exit 2`, never a silent no-op.
- `[VIOLATION]`/`[EXEMPT]` (or `[FAIL]`/`[PASS]`) tagged lines via `echo -e` with `RED`/`GREEN`/
  `YELLOW`/`NC` color vars, a final summary block, and exit codes `0` (clean) / `1` (violations
  found) / `2` (script/environment error — unresolvable root, missing shared lib, empty
  enumeration).
- Extensive header comment documenting WHY/WHAT/detection model/known limitations — every sibling
  lint in this directory carries this density; the new lint should match it, not abbreviate it.

**The table-vs-directory diff task itself has no existing analog.** `check-extension-docs.sh`
(grep for "Available Extensions"/"README.md") only ever reads an extension's own
`<ext>/README.md` against its own `<ext>/manifest.json` (commands-mentioned, staleness-vs-
manifest-mtime, etc.) — it never touches the top-level `agent-system/extensions/README.md` file
at all. `lint-routing-wiring.sh` is the closest structural cousin (diffs a declared set against
a filesystem-derived set) but operates on `manifest.json routing_agents` keys, not a markdown
table's first column, so it is read-for-shape only, not extended.

**Real directory set today** (`ls -d agent-system/extensions/*/`, 23 entries): approvals, books,
core, cslib, email, epidemiology, filetypes, formal, founder, latex, lean, literature, memory,
nix, nvim, present, python, rust, sapience, slidev, typst, web, z3.

**Table's first column today** (`agent-system/extensions/README.md`'s Available Extensions
table, 21 rows): nvim, lean, books, cslib, latex, typst, python, rust, nix, web, z3,
epidemiology, formal, filetypes, founder, present, memory, literature, email, slidev, approvals.

**Diff**: 23 directories − `core` (deliberately exempt, confirmed below) = 22 expected rows;
table has 21. Missing row: **`sapience`**. No extra/dangling row exists today (every table row
names a real directory).

**Why `core` is exempt, and why it must be an explicit name check, not an inferred one**: the
README's own prose states core "contains only language-agnostic elements" loaded unconditionally
— it is the base system, never a pickable "available extension," so its absence from the table is
intentional. There is no manifest field that reliably signals this: `routing_exempt: true` is
also set by `approvals`, `slidev`, and `sapience` manifests, all three of which DO have (or, for
sapience, should have) a table row — so `routing_exempt` cannot be used to infer the exemption.
The only robust signal is the directory name itself (`core`), matching the dispatch's explicit
instruction to exempt it "explicitly rather than by accident."

**`sapience` is a real, intentionally-table-worthy extension missing its row** — confirmed via
`git log`: task 482 (phases 1–5, commits `41a650a9a`..`b2e67d392`) created
`agent-system/extensions/sapience/` including its own `manifest.json`, `EXTENSION.md`, and
`README.md`, and task 482's phase 2 commit (`97f8327cd`, "EXTENSION.md and README.md") touched
only `agent-system/extensions/sapience/README.md`, never
`agent-system/extensions/README.md` (the top-level table file). `sapience/manifest.json` sets
`routing_exempt: true` with no task type, matching the pattern already used for `approvals`,
`memory`, `slidev`, `literature`, `filetypes` (all rendered with `Task Type: -` in the existing
table). `sapience/README.md`'s own first line and `manifest.json`'s `description` field give a
ready-made description: "Permission grants and orientation docs for the hosted Sapience knowledge
vault (app.spnc.ai)."

**Gate-registry.data current state** (`agent-system/extensions/core/scripts/gate-registry.data`):
25 gates declared (ids 1–25, contiguous), not 24. Format is documented in the file's own header:
9 TAB-separated fields — `id name invoke dependencies requires_source_store timeout_s cost_class
serialized input_corpus`. The named view `@extensions` means "the shared `git ls-files`
enumeration of agent-system/extensions/, repo-relative" and is already used as the sole
`input_corpus` value for several structurally similar full-corpus lints (gates 6, 7, 11, 12, 19,
21, 23, 24 among others) — since `agent-system/extensions/README.md` lives inside that tree,
`@extensions` alone already satisfies the dispatch's "its inputs are
agent-system/extensions/README.md plus the extension directory set" requirement; no compound
corpus expression is needed. `lint-gate-registry.sh` independently enforces the registry's own
structural invariants (function exists, deps acyclic, id set contiguous from 1, 9-field rows,
valid `input_corpus` grammar) — the new row must satisfy all of these or that lint (already a
gate) will fail post-change.

**`verify-deploy.sh` gate-function pattern** (read `gate7_run` and `gate24_run` in full as
templates): each `gateN_run()` wraps its body in `if gate_selected N; then ... fi`, emits
`say "N. <description>"`, sets `CURRENT_GATE="gateN"`, SKIPs with a stated reason when
`$TARGET/agent-system/extensions` doesn't exist (deploy-consumer tree, not source store —
matches `requires_source_store=true` in the registry), `fail`s loudly if the lint script itself
is missing from the source store, otherwise runs the lint with `--verbose` via
`cd "$TARGET" && REPO_ROOT="$TARGET" bash .../lint-X.sh --verbose`, and on nonzero exit calls
`fail` plus (under `--findings`) streams `[VIOLATION]`/`[FAIL]`-tagged lines through
`verify_deploy_extract_verdict_lines` into `FINDINGS_LIST` tagged `FINDING gateN ...`. The new
gate function should follow this shape exactly, matching whatever bracketed tag
(`[VIOLATION]`/`[FAIL]`) the new lint actually emits.

**`--only-gate` cap — outcome #3, confirmed independently**: `git log -L
375,397:agent-system/extensions/core/scripts/verify-deploy.sh` shows commit `3d28b4399`
("task 810 phase 4: Gate 16 WARN finding stops escalating to batch blocking") already replaced
the literal `1-23` bound with a derived `_only_gate_max_id` computed by iterating
`gate_registry_ids` and taking the max, falling back to the literal `23` **only** if that
iteration yields `0` (an empty/degraded registry). This commit precedes task 470's current
in-flight header edits in the log (`e1a2f3a1b`, `7736b38bc`) and long precedes this dispatch's
authoring. The dispatch's cited line numbers (171, 177, 329-341) no longer match a hardcoded cap
at all — they now describe a `for`/derive/fallback block whose only literal `23` is the
degrade-path fallback, not an enforced ceiling. **Current behavior**: `--only-gate 24` and
`--only-gate 25` both validate successfully today (the derived max is 25). Two cosmetic,
non-functional `23`-mentioning doc comments remain stale (line ~173's "every one of the 23 real
gates" and line ~2033's gate-id list in a cache-invalidation comment, both missing 24/25) — these
are prose nits, not the cap bug the dispatch described, and are optional cleanup, not a required
outcome.

**`sync-manifest-scripts.sh`**: confirmed it exists at
`agent-system/extensions/core/scripts/sync-manifest-scripts.sh`, is a `--check`/`--write` pair
that derives `provides.scripts` for a source-store manifest from `git ls-files <ext>/scripts`,
operates surgically (line-oriented rewrite of just the `provides.scripts` array, never a whole-
document `jq` round-trip — two manifests, `books` and `rust`, are not `jq --indent 2` canonical
elsewhere and a round-trip would reformat them unrelatedly), and already lists
`tests/test-lint-dead-command-recommendations.sh` as a precedent entry in `core`'s manifest. This
is unambiguously the tool outcome #4 names ("declared ... via sync-manifest-scripts.sh --write,
never by hand-editing the manifest").

**Test suite template**: `tests/test-lint-dead-command-recommendations.sh` is a clean model for
the new suite — `mktemp`-scoped workdir via `common_test_workdir_init`, dual-mode candidate
resolution via `common_test_resolve_candidate` (deployed copy first, source-store fallback),
numbered cases each producing a synthetic fixture file and asserting on the lint's exit code and
`[VIOLATION]`-tagged output lines via `common_test_pass`/`_fail`/`_info`. The four cases outcome
#4 names (clean table passes, missing row fails, extra row fails, core's exemption) map directly
onto this case-per-fixture shape; a fixture for this lint will need a synthetic
`agent-system/extensions/README.md`-shaped file AND a synthetic directory tree (or an explicit
scan-path override), since the lint's two inputs are a markdown table and a directory listing,
not a single file — check how the lint accepts path overrides (likely a `--readme PATH` /
`--extensions-dir PATH` pair, or positional args mirroring the corpus-scan-lib convention) when
designing the fixture harness.

### External Resources

Not applicable — this is a pure in-repo mechanical-lint task with no external library/API
surface.

## Recommendations

1. **Re-verify outcome #3 is still resolved immediately before editing**, since `verify-deploy.sh`
   has multiple concurrent writers (this task depends on task 470 for exactly this reason). If it
   is still resolved at implementation time, record that explicitly in the plan/summary rather
   than silently skipping outcome #3 — the dispatch asked for independent confirmation, and a
   confirmed-already-fixed finding is itself the deliverable for that outcome, not a no-op.
2. **Treat the missing `sapience` row as in-scope, required work**, not as "repair" the dispatch's
   framing disclaimed. Add one row (`Task Type: -`, description drawn from
   `sapience/manifest.json`'s `description` or `sapience/README.md`'s opening line, Docs link
   `[README](sapience/README.md)`) in the same alphabetical/thematic position the table already
   uses (after `approvals` or wherever the table's existing ordering convention places it — the
   table is not strictly alphabetical, e.g. `nvim`/`lean` lead by prominence, so match whatever
   local convention the immediately-surrounding rows establish). Without this row, outcome #5
   (full gate set green) cannot be met once the new gate is wired in.
3. **New lint**: build `lint-extension-readme-table.sh` following
   `lint-dead-command-recommendations.sh`'s structural conventions (dual-mode root resolution,
   `--quiet`/`--verbose`, numbered exit codes, dense header comment). Explicitly hardcode `core`
   as the sole exemption by directory-name string match (not inferred from any manifest field),
   per the dispatch's own instruction and the `routing_exempt` false-signal finding above. Check
   both directions: a real directory (other than `core`) with no table row, and a table row
   naming no real directory.
4. **Registry row**: new gate id **26** (25 is the current max) — but re-enumerate
   `gate-registry.data`'s max id fresh at implementation time given the stated concurrent writers
   (#418, #414 declare `gate-registry.data`; #444/#445/#449 also declare `verify-deploy.sh`), and
   pick the next free id then, not from this report's snapshot. `input_corpus` = `@extensions`
   (sufficient on its own; no compound expression needed — see Findings). `requires_source_store`
   = `true`, `serialized` = `false`, `cost_class` likely `free` (matches every other pure-lint
   gate's cost class in the registry today; confirm via the gate-cost-model tooling if a
   measurement run is warranted, but a free-cost default matches every comparable sibling).
5. **`verify-deploy.sh` wiring**: add `gate26_run()` mirroring `gate24_run()`'s shape exactly
   (SKIP-on-deploy-consumer, fail-on-missing-script, run `--verbose`, extract `[VIOLATION]` or
   whatever tag the new lint actually emits into `FINDINGS_LIST` under `--findings`). Fix the
   `--only-gate` cap and header text together with this task's own new gate id *only if*
   re-verification in step 1 finds something still broken; if already fixed, this outcome
   collapses to "confirmed no change needed," and the header's stale `23`-mentioning prose
   (lines ~173, ~2033) is optional incidental cleanup, not a required edit.
6. **Manifest + tests**: run `sync-manifest-scripts.sh --write` against `core`'s manifest after
   the lint and test files exist on disk — never hand-edit `provides.scripts`. Write
   `test-lint-extension-readme-table.sh` with the four named cases (clean/missing/extra/
   core-exempt), modeled on `test-lint-dead-command-recommendations.sh`.
7. **Redeploy discipline**: edit only under `agent-system/extensions/core/` (confirmed
   `source_dir` via `.claude-extensions.json`), then redeploy via the bounded-wait idiom the
   dispatch already specifies (`timeout 540 bash .claude/scripts/deploy-headless.sh`, Bash tool
   timeout raised to 600000) — never hand-patch `.claude/**`.

## Decisions

- The new gate's `input_corpus` should be the single named view `@extensions`, not a compound
  `agent-system/extensions/README.md,@extensions` expression — `@extensions` already covers the
  README file, since it lives inside the tree that view enumerates. This resolves an apparent
  (but only textual) discrepancy between the dispatch's informal description and the registry's
  existing grammar.
- `core`'s exemption must be an explicit, hardcoded directory-name check inside the new lint, not
  inferred from `routing_exempt` or any other manifest field — `routing_exempt: true` is also set
  by three extensions (`approvals`, `slidev`, `sapience`) that DO belong in the table, so it is
  not a usable proxy.
- The missing `sapience` table row is in-scope, required remediation for this task (a precondition
  of outcome #5), not an out-of-scope repair task — it was not foreseeable at dispatch-authoring
  time because the extension that created the drift (task 482) landed afterward.

## Risks & Mitigations

- **Gate-id collision risk**: multiple open/concurrent tasks (#444, #414, #445, #449 for
  `verify-deploy.sh`; #418, #414 for `gate-registry.data`) may claim a gate id before this task's
  implementation phase runs. Mitigation: re-enumerate the registry's max id immediately before
  adding the row, do not trust gate id 26 from this report as final.
- **Outcome #3 re-drift risk**: because `verify-deploy.sh`'s header/arg-parsing region is being
  actively edited by task 470 concurrently (dependency already serializes on this), the exact
  line numbers and even the fixed/not-fixed status of the `--only-gate` cap could change between
  this report and implementation. Mitigation: re-run the independent confirmation (grep for a
  literal `-gt 23`/`1-23` string in the `--only-gate` parsing block) right before editing, not from
  this report's line numbers.
- **README table ordering ambiguity**: the table is not strictly alphabetical (e.g. `nvim`/`lean`
  lead), so there is no single mechanical rule for *where* to insert the new `sapience` row.
  Mitigation: match the nearest established local pattern (grouping routing-exempt, "-"-task-type
  extensions like `memory`/`literature`/`slidev`/`approvals` near each other) rather than
  re-deriving an ordering policy; the lint only checks set membership, not row order, so this is
  purely a documentation-readability choice with no correctness consequence.
- **Fixture design for the new test suite**: since the lint consumes two different corpora (a
  markdown table file and a directory listing), the test suite will need either CLI flags on the
  lint for overriding both inputs, or a scratch directory shaped like
  `<scratch>/README.md` + `<scratch>/*/` subdirectories passed as a root override — confirm which
  shape the lint itself supports once it's written, rather than assuming a single-path positional
  argument suffices (unlike `lint-dead-command-recommendations.sh`, which only ever needed one
  kind of input).

## Context Extension Recommendations

None — this is a narrowly-scoped mechanical lint addition with ample existing sibling precedent
in `scripts/lint/`; no new context documentation gap was identified.

## Appendix

- Search queries / commands used: `ls -d agent-system/extensions/*/`, `grep -n "Available
  Extensions" -A 40 agent-system/extensions/README.md`, `git log --oneline -- .../sapience/`,
  `git show 97f8327cd -- agent-system/extensions/README.md`, `git log -L
  375,397:agent-system/extensions/core/scripts/verify-deploy.sh`, `grep -n "only_gate_max_id"
  verify-deploy.sh`, `grep -n "routing_exempt" agent-system/extensions/*/manifest.json`.
- Files read in full or substantially: `lint-dead-command-recommendations.sh`,
  `test-lint-dead-command-recommendations.sh`, `gate-registry.data` (header + tail),
  `verify-deploy.sh` (header region, gate7_run, gate24_run, `--only-gate` parsing block),
  `sync-manifest-scripts.sh` (header/usage), `lint-gate-registry.sh` (header),
  `agent-system/extensions/README.md`, `agent-system/extensions/sapience/manifest.json` and
  `README.md`.
