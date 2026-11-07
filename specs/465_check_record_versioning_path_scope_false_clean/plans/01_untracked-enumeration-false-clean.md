# Implementation Plan: Task #465

- **Task**: 465 - check-record-versioning.sh PATH_SCOPE mode must never report clean for a file it did not actually scan
- **Status**: [IMPLEMENTING]
- **Effort**: 5.5 hours
- **Dependencies**: None
- **Research Inputs**: None (planned directly from the task specification plus direct source inspection -- see Overview)
- **Artifacts**: plans/01_untracked-enumeration-false-clean.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The defect is a single enumeration site: `scan_tree()` in `check-record-versioning.sh` feeds its
scan loop from `git ls-files "$enum_path"`, which reads the git INDEX and therefore returns zero
rows for a file that exists on disk but is not yet tracked. The surrounding `[[ ! -e "$enum_dir" ]]`
guard passes (the path does exist), so no `[SKIP]` fires, the `while` loop never iterates, and the
summary prints `0 BLOCKING, 0 ADVISORY` / `PASS`. The fix replaces that enumeration with the union
of tracked and untracked-but-not-ignored paths, and adds explicit stderr diagnostics for every
on-disk file the union still excludes, so a caller can always distinguish "clean" from "not
examined".

The sibling audit the task requires has been performed by direct inspection (see Sibling
Enumeration Audit below). `check-task-references.sh` carries a byte-identical `scan_tree` with the
same `git ls-files` enumeration and the same `PATH_SCOPE` contract, and it additionally backs
verify-deploy gate 4 and the blocking `validate-no-task-references.sh` write-time hook -- so it
shares the defect in a strictly higher-stakes position and is fixed in the same change rather than
left for a follow-up. Because the two lints must behave identically here, the union enumeration and
its diagnostics are extracted into one shared library both consume, not copy-pasted twice.

### Research Integration

No research report was produced for this round; the task description is a specification (defect,
measured evidence, required outcome, acceptance bar), and the remaining unknowns were all
resolvable by targeted reads within this planning dispatch. Established by that inspection:

- The defect site is `check-record-versioning.sh:201`, `done < <(git -C "$REPO_ROOT" ls-files "$enum_path" 2>/dev/null)`.
- `check-task-references.sh:159` is the same line in the same function shape, with the same
  `PATH_SCOPE` existence guard (`-e`, not `-d`) and the same `[SKIP]`-only-when-absent behavior.
- `script-inventory.sh:290-308` already implements exactly the remedy (`ls-files` unioned with
  `ls-files --others --exclude-standard`, plus a deliberate untracked-set *visibility disclosure*:
  a per-script `tracked` field, an `untracked_count`/`untracked_paths` pair, and a stderr warning).
  That is the in-repo precedent this plan mirrors rather than inventing a convention.
- `--exclude-standard` honors `.gitignore`, so the union does NOT reintroduce gitignored content.
  This matters twice: the existing suite's Case 7 (a gitignored file carrying a BLOCKING finding
  must not be found) keeps passing unchanged, and this repo's `/.claude/` deploy tree -- gitignored
  per `.gitignore:6`, confirmed via `git check-ignore` -- stays excluded, so the repo-wide mode does
  not suddenly start scanning thousands of deployed files.
- Blast radius of the repo-wide union in this repo today is one file:
  `git ls-files --others --exclude-standard | grep -v '^specs/'` returns exactly
  `agent-system/extensions/core/scripts/gate-cost-model.csv`. Everything else untracked is under
  `specs/**`, which both lints path-exempt via `is_exempt_path`.
- `check-record-versioning.sh` is absent from `scripts/gate-registry.data`;
  `check-task-references.sh` is gate 4 (`gate4_run`, `verify-deploy.sh:921`), invoked as
  `cd "$TARGET" && bash "$CLAUDE_DIR/scripts/check-task-references.sh" --quiet >/dev/null 2>&1`
  against the DEPLOYED copy, with a findings extractor that greps `^  [^:]+:[0-9]+:`.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch and no roadmap flag is set; ROADMAP.md was not
consulted and is not modified.

## Goals & Non-Goals

**Goals**:

- An untracked-but-present file inside `PATH_SCOPE` is scanned on its merits, so a BLOCKING-tier
  occurrence in it yields a non-clean verdict.
- Any on-disk file inside `PATH_SCOPE` that is still deliberately excluded from enumeration (i.e.
  gitignored) produces an explicit stderr line naming the file and the reason -- never silence.
- A `PATH_SCOPE` that exists on disk but enumerates zero files produces an explicit stderr
  diagnostic rather than a bare `PASS`.
- `check-task-references.sh` receives the identical fix, from one shared definition, so gate 4 and
  the blocking task-reference hook cannot drift from the record-versioning lint's semantics.
- A fixture in `test-check-record-versioning.sh` covers exactly the acceptance case: a file on
  disk, not git-tracked, containing a BLOCKING-tier occurrence, does not yield a clean verdict
  under `PATH_SCOPE` mode.

**Non-Goals**:

- Changing any exit-code semantics. Exit 0/1/2 keep their current meanings; all new diagnostics are
  stderr-only. Gate 4 consumes exit status, so an exit-code change would be a blast radius this
  defect does not justify.
- Changing any stdout line format. The per-finding `^  path:line: TIER: content` shape and the
  `  LABEL: N BLOCKING, M ADVISORY` summary stay byte-identical, so gate 4's findings extractor and
  every existing assertion in both suites keep working untouched.
- Scanning gitignored content. `--exclude-standard` is retained deliberately; build output and the
  disposable `.claude/` deploy tree remain out of scope, now loudly rather than silently.
- Fixing `check-extension-docs.sh`'s adjacent enumeration blind spot (see Sibling Enumeration
  Audit). It is named, classified, and left to its own record.
- Adding the missing `check-task-references.sh` entry to `utility-scripts-inventory.md`. That gap is
  pre-existing and already documented as such in the sibling entry's own text.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Repo-wide union turns gate 4 or the record-versioning lint red on pre-existing untracked files | M | L | Measured during planning: exactly one untracked non-`specs/` file exists today (`gate-cost-model.csv`). Phase 4 runs both lints repo-wide after the change and triages. A genuine finding in an untracked file is a real violation to fix or exempt, never a reason to revert the enumeration. |
| A new shared library is missing in a consumer repo's deployed tree, silently restoring the defective enumeration | H | L | Source the library with a hard `exit 2` on absence plus a `declare -F` required-function check, mirroring the existing `record-version-patterns.sh` treatment in the same script (`check-record-versioning.sh:111-140`) -- explicitly NOT the degrade-safe no-op pattern used for `redeploy-remedy-lib.sh`, since a silent fall-through here is the very defect being fixed. |
| New diagnostics suppressed by `--quiet`, making the loud skip inaudible to exactly the callers that use `--quiet` | M | M | Diagnostics are written directly to stderr, never through `info()`. A dedicated test case asserts the diagnostic survives `--quiet`. |
| Diagnostic noise on the repo-wide run (the ignored set includes the whole `.claude/` tree) | M | H | The per-file unenumerated report runs only in `PATH_SCOPE` mode, where the candidate set is small and the caller asked about a specific path. Repo-wide mode gets the zero-enumeration and untracked-count disclosures only. |
| Gate 4 verification requires the deployed copy, which does not change until a redeploy | L | H | Phases 2-3 verify via the documented `REPO_ROOT=$(pwd)` source-store invocation and the two fixture suites; the deployed gate-4 run is deliberately deferred to Phase 4, after `deploy-headless.sh`. |
| Appending untracked paths changes finding ORDER, breaking an order-sensitive assertion | L | L | The union is passed through `sort -u`, giving a deterministic lexicographic order; both suites' assertions are `grep`-based, not order-based. |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Shared git-corpus enumeration library + unit suite [COMPLETED]

**Goal**: One definition of "the set of files a git-backed lint should scan under a path scope",
with the diagnostics that make an exclusion audible, plus its own fixture suite. Nothing consumes
it yet, so this phase cannot change any existing verdict.

**Tasks**:

- [x] Create `agent-system/extensions/core/scripts/lib/git-corpus-enum-lib.sh` exposing: *(completed)*
  - `git_corpus_enum <repo_root> <enum_path>` -- prints, newline-delimited and `sort -u`'d, the
    union of `git -C <repo_root> ls-files <enum_path>` and
    `git -C <repo_root> ls-files --others --exclude-standard <enum_path>`. Output shape is
    repo-root-relative paths, byte-compatible with what both lints' existing `while IFS= read -r rel`
    loops already consume, so no call-site loop body changes.
  - `git_corpus_unenumerated_report <repo_root> <enum_path>` -- for a scoped (non-`.`) enum_path,
    prints one line per on-disk regular file under that path that the union does NOT contain, in the
    form `  [SKIP] <rel>: gitignored (not scanned)`. Silent when the exclusion set is empty.
    Intended for the caller to redirect to stderr; the library itself never writes to stderr and
    never exits.
  - `git_corpus_untracked_count <repo_root> <enum_path>` -- prints the count of untracked-but-
    included paths, for the caller's disclosure line.
- [x] Give the library the contract header `lib/common.sh` and `lib/lint-corpus-scan-lib.sh` both
  use verbatim: sets no shell options, never calls `exit`, reports conditions by return status. *(completed)*
- [x] Record in that header the "Known adjacent enumeration sites" note from the Sibling
  Enumeration Audit section below (which sibling scripts share the `git ls-files` shape, which were
  classified as not-defective and why, and which one remains an open adjacent instance), citing
  script filenames only -- no task-number references, per `rules/no-task-references-in-deliverables.md`. *(completed)*
- [x] Create `agent-system/extensions/core/scripts/tests/test-git-corpus-enum-lib.sh` following *(completed: all 8 enumerated cases plus 2 extra, 10 total, all passing)*
  `context/standards/shell-script-testing.md` (mktemp WORKDIR via `common_test_workdir_init`,
  `common_test_pass`/`common_test_fail`, exit 0/1/2 convention), with cases: tracked file included;
  untracked-not-ignored file included; gitignored file excluded; scoped single untracked file
  enumerated; union deduplicated and sorted; non-existent enum_path returns empty without error;
  `git_corpus_unenumerated_report` names a gitignored file and is silent when there is none;
  `git_corpus_untracked_count` is accurate.
- [x] Register both new files in `agent-system/extensions/core/manifest.json` `provides.scripts`
  (alongside the existing `lib/*.sh` and `tests/*.sh` entries) and add the test to
  `scripts/tests/suite-classification.data` as `unit`. *(completed)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: The new files have no consumers yet, so the covering checks are exactly
`bash agent-system/extensions/core/scripts/tests/test-git-corpus-enum-lib.sh` and
`lint/lint-shellcheck.sh` over the two new paths.

**Scope Hypothesis**: This phase asserts the manifest needs exactly two new `provides.scripts`
entries and `suite-classification.data` exactly one new row. Confirm by running
`sync-manifest-scripts.sh` (read-only, no `--write`) and `check-extension-docs.sh` after the edits
and checking that neither reports an undeclared script.

**Files to modify**:

- `agent-system/extensions/core/scripts/lib/git-corpus-enum-lib.sh` - new shared enumeration
  library (union enumeration, unenumerated-file report, untracked count)
- `agent-system/extensions/core/scripts/tests/test-git-corpus-enum-lib.sh` - new fixture suite for
  the library
- `agent-system/extensions/core/manifest.json` - declare both new files in `provides.scripts`
- `agent-system/extensions/core/scripts/tests/suite-classification.data` - classify the new suite

**Verification**:

- `bash agent-system/extensions/core/scripts/tests/test-git-corpus-enum-lib.sh` exits 0 with every
  case passing.
- `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh agent-system/extensions/core/scripts/lib/git-corpus-enum-lib.sh agent-system/extensions/core/scripts/tests/test-git-corpus-enum-lib.sh`
  is clean.
- `jq -e '.provides.scripts | index("lib/git-corpus-enum-lib.sh")' agent-system/extensions/core/manifest.json`
  succeeds, and the same for the test path.

---

### Phase 2: Wire check-record-versioning.sh + acceptance fixture [COMPLETED]

**Goal**: The task's own acceptance criterion holds: an untracked, on-disk file with a BLOCKING
occurrence is scanned under `PATH_SCOPE` and yields a non-clean verdict; any still-excluded on-disk
file is named on stderr.

**Tasks**:

- [x] Add `git-corpus-enum-lib.sh` to the script's library resolution: extend the existing
  `LIB_CANDIDATES` pattern (deployed `.claude/scripts/lib/` first, source-store
  `agent-system/extensions/core/scripts/lib/` fallback) for the new library, failing with `exit 2`
  and a named remedy when absent -- matching the existing not-found branch at
  `check-record-versioning.sh:111-117`, not the degrade-safe no-op used for the redeploy-remedy lib. *(completed)*
- [x] Extend the existing `declare -F` required-function loop (`check-record-versioning.sh:130-140`)
  with `git_corpus_enum`, `git_corpus_unenumerated_report`, and `git_corpus_untracked_count`, so a
  stale deployed library fails loudly rather than reinstating the defect. *(completed: added as its own CORPUS_LIB_CANDIDATES block + required-function loop, right after the existing record-version-patterns.sh block)*
- [x] Replace `scan_tree`'s enumeration (`check-record-versioning.sh:201`) with
  `done < <(git_corpus_enum "$REPO_ROOT" "$enum_path")`. Leave the loop body untouched. *(completed: enumerated once into `$enum_output`, loop body fed via `<<< "$enum_output"` instead of process substitution so the same enumeration can also drive the zero-enumeration check; loop body itself unchanged)*
- [x] In `scan_tree`, after enumeration, emit on stderr (never through `info()`, so `--quiet` cannot
  suppress it):
  - the untracked-inclusion disclosure when `git_corpus_untracked_count` is non-zero, naming the
    count and the scope;
  - the per-file `git_corpus_unenumerated_report` output, in `PATH_SCOPE` mode only;
  - a zero-enumeration diagnostic when the scope exists on disk but the union is empty, naming the
    scope and the reason, so a bare `PASS` is never the only signal. *(completed)*
- [x] Leave exit codes and every stdout line format unchanged (Non-Goals). *(completed: verified -- all 18 pre-existing suite assertions pass unmodified)*
- [x] Update the script header: the "scans every git-tracked file" claim in the opening paragraph,
  the `PATH_SCOPE` usage paragraph (lines 37-42) to state the untracked-inclusion and loud-skip
  behavior, and a note that enumeration now lives in the shared library. *(completed)*
- [x] Add to `test-check-record-versioning.sh` the acceptance case: write a file into the fixture
  with BLOCKING content, do NOT `git add` it, run `PATH_SCOPE` over exactly that path, and assert
  the verdict is non-clean (exit 1 with a `BLOCKING` finding line naming the path). Wrap the literal
  fixture content in a `version-ok:begin/end` pair, per this suite's existing convention and its
  header note. *(completed: Case 16)*
- [x] Add three supporting cases to the same suite: (a) a gitignored file under a `PATH_SCOPE`
  produces the `[SKIP] ...: gitignored` stderr line and still does not count as a finding (Case 7's
  exclusion preserved, now audible); (b) that stderr diagnostic still appears under `--quiet`;
  (c) a `PATH_SCOPE` directory containing only gitignored files emits the zero-enumeration
  diagnostic instead of a silent `PASS`. Note that the suite's `run_lint` helper currently folds
  stderr into stdout via `2>&1`, which is sufficient for these assertions; if a case needs the
  streams separated, add a second helper rather than changing `run_lint`'s existing signature. *(completed: Cases 17-19; run_lint's existing 2>&1 fold was sufficient, no second helper needed)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: Both edited paths are covered by
`bash agent-system/extensions/core/scripts/tests/test-check-record-versioning.sh`, which already
asserts the full stdout contract (Cases 1-15) that this phase must leave byte-identical, and this
script backs no verify-deploy gate (it is absent from `gate-registry.data`).

**Scope Hypothesis**: This phase asserts the loop body in `scan_tree` needs no change because
`git_corpus_enum` emits the same newline-delimited repo-root-relative path shape as
`git ls-files`. Confirm by running the full existing suite before adding new cases and checking
that all 15 pre-existing cases still pass unmodified.

**Files to modify**:

- `agent-system/extensions/core/scripts/check-record-versioning.sh` - consume the shared
  enumeration, add required-function entries, emit the three stderr diagnostics, update header docs
- `agent-system/extensions/core/scripts/tests/test-check-record-versioning.sh` - add the acceptance
  fixture plus the three supporting cases

**Verification**:

- `bash agent-system/extensions/core/scripts/tests/test-check-record-versioning.sh` exits 0, with
  every pre-existing case (1-15) still passing and the four new cases passing.
- Direct acceptance reproduction, run by hand to confirm the defect is actually gone: create an
  untracked file under a scratch path containing a BLOCKING occurrence, then
  `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-record-versioning.sh <that path>`
  exits 1 and names the file. Remove the scratch file afterwards.
- `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-record-versioning.sh --quiet`
  repo-wide: exit status and summary line unchanged from a pre-change run, except for any genuine
  new finding in the single untracked non-`specs/` file (triaged, not reverted).
- `lint/lint-shellcheck.sh` clean over both edited paths.

---

### Phase 3: Mirror onto check-task-references.sh + its suite [COMPLETED]

**Goal**: The higher-stakes sibling -- the lint backing verify-deploy gate 4 and the blocking
`validate-no-task-references.sh` write-time hook -- gets the identical fix from the same shared
definition, so the two lints cannot drift.

**Tasks**:

- [x] Apply the Phase 2 changes to `check-task-references.sh`: shared-library resolution with a
  loud `exit 2` on absence, required-function check, `git_corpus_enum` enumeration at
  `check-task-references.sh:159`, and the same three stderr diagnostics placed so `--quiet` cannot
  suppress them. *(completed: added fresh -- this script had no prior required-function loop at all)*
- [x] Leave the `marker_balance_report` branch and the `strip_exempt_regions | grep -nEi` finding
  loop untouched; this phase changes enumeration only. *(completed)*
- [x] Update the script header's "scans every git-tracked file" claim and its `PATH_SCOPE` usage
  paragraph to match the new behavior. *(completed)*
- [x] Add the mirrored acceptance case to
  `agent-system/extensions/core/scripts/tests/test-check-task-references.sh`: an untracked on-disk
  file with a task-reference occurrence under `PATH_SCOPE` yields a non-clean verdict. Wrap the
  literal fixture content in the `task-ref-ok` marker pair this suite already uses for its own
  fixtures. *(completed: Case 9)*
- [x] Add the gitignored-file loud-skip case and the `--quiet`-survival case to the same suite,
  mirroring Phase 2's supporting cases. *(completed: Cases 10-11)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: interface

**Tier Justification**: This script is gate 4's executable, consumed by `verify-deploy.sh`'s
`gate4_run` and its `^  [^:]+:[0-9]+:` findings extractor, so the covering checks are its own suite
plus `verify-deploy.sh --only-gate 4` -- a surface `local` would not reach.

**Scope Hypothesis**: This phase asserts the gate-4 findings extractor is unaffected because it keys
only on per-finding stdout lines, which this change leaves byte-identical. Confirm by running
`verify-deploy.sh --only-gate 4` in Phase 4 (after redeploy) and checking the gate still reports the
same verdict and, in findings mode, the same `FINDING gate4 ...` line shape.

**Files to modify**:

- `agent-system/extensions/core/scripts/check-task-references.sh` - consume the shared enumeration,
  add required-function entries, emit the three stderr diagnostics, update header docs
- `agent-system/extensions/core/scripts/tests/test-check-task-references.sh` - add the mirrored
  acceptance case plus the two supporting cases

**Verification**:

- `bash agent-system/extensions/core/scripts/tests/test-check-task-references.sh` exits 0 with every
  pre-existing case still passing and the new cases passing.
- `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-task-references.sh --quiet`
  repo-wide: exit status unchanged from a pre-change run (gate 4's own verdict is re-confirmed
  against the deployed copy in Phase 4).
- Source-store acceptance reproduction for this lint, same shape as Phase 2's.
- `lint/lint-shellcheck.sh` clean over both edited paths.

---

### Phase 4: Documentation, redeploy, and full gate sweep [COMPLETED]

**Goal**: The inventory record matches the shipped behavior, the sibling audit is recorded in a
durable place, the deployed tree carries the fix, and the whole gate set is green.

**Tasks**:

- [x] Correct the `check-record-versioning.sh` entry in
  `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md`: it currently states
  the lint "scans every git-tracked file outside `specs/**` (via `git ls-files`...)". Restate it as
  the tracked-plus-untracked union, with gitignored content excluded but loudly reported, and note
  that `PATH_SCOPE` mode names any on-disk file it did not scan. Do not add a new entry for
  `check-task-references.sh` -- that gap is out of scope and already noted in this entry's own text. *(completed)*
- [x] Confirm the Sibling Enumeration Audit note landed in the shared library header in Phase 1
  (one durable home, not duplicated into the inventory doc). *(completed: confirmed present in git-corpus-enum-lib.sh's header)*
- [x] Redeploy the source store: `bash agent-system/scripts/deploy-headless.sh` (or the repo's
  documented headless deploy entry point), so `.claude/scripts/` carries the new library, both
  updated lints, and the new suites. *(completed: bash .claude/scripts/deploy-headless.sh, bounded 540s inner timeout, run three times -- the second two to carry forward an exec-bit fix and a wording fix discovered during post-deploy verification)*
- [x] Repo-wide triage pass: run both lints repo-wide after the redeploy and resolve any finding
  newly surfaced in an untracked file -- fix the content or add a properly-categorized
  `version-ok` / `task-ref-ok` marker. A new finding is a real violation, never grounds for
  reverting the enumeration. *(completed: the one anticipated untracked non-specs/ file, gate-cost-model.csv, carried one genuine ADVISORY finding (bare "previously" vocabulary) -- fixed by rewording both printf template sites in its generator, measure-gate-costs.sh, plus the already-generated CSV's own header line, rather than adding a version-ok marker, since this is ordinary prose that reads cleanly either way. Verified: tracked-only and union enumeration now report byte-identical 3 BLOCKING / 833 ADVISORY repo-wide. check-task-references.sh's repo-wide union introduced zero new findings (none of the 13 untracked files carry a task-reference citation).)*
- [x] Record the issue-log entry(ies) for this phase per the dispatch's Issue Log section. *(completed: 2 entries via issue-record.sh -- the triaged ADVISORY finding, and the pre-existing/unrelated gate failures observed during redeploy verification)*
- [x] Follow-up (continuation dispatch): the redeploy checkpoint's self-attribution screen held
  this task for one further gate-3 finding -- `script file on disk NOT in provides.scripts:
  scripts/gate-cost-model.csv`. This is the "Adjacent instance, named but deliberately not fixed
  here" item from the Sibling Enumeration Audit above, but the concrete trigger was unrelated to
  that enumeration blind spot: gate-cost-model.csv (and its generator, measure-gate-costs.sh)
  were already git-tracked and already declared in `provides.scripts` -- only the CSV itself had
  never been added to the list. Root cause: `check-extension-docs.sh` Rule Q requires every file
  under an extension's `scripts/` tree to be named in that extension's own `provides.scripts`
  regardless of file type (data file vs. shell script) -- the same precedent already followed by
  `gate-registry.data`, `tests/suite-classification.data`, and `tests/suite-cost-hints.txt`.
  Resolved by running the sanctioned repair tool,
  `bash agent-system/extensions/core/scripts/sync-manifest-scripts.sh --write`, which added the
  one missing `"gate-cost-model.csv"` entry to `agent-system/extensions/core/manifest.json`
  (alphabetically, next to `gate-registry.data`) -- no new convention invented. The two
  previously-uncommitted excursion files this dispatch was asked to resolve
  (`measure-gate-costs.sh`, `gate-cost-model.csv`) turned out to already be committed, in the
  prior dispatch's own `task 465 phase 4: triage fix` commit; nothing was left dangling.
  Redeployed and confirmed: `verify-deploy.sh --only-gate 3` now reports `PASS -- 2 check(s), 0
  failure(s)` for core. The full gate sweep after this redeploy shows exactly the two findings
  already confirmed pre-existing and out of scope (the gate10 30s-timeout flake and the two
  memory-extension `/ide` dead-command-recommendation findings) -- no new finding introduced.
  *(completed)*

**Timing**: 1 hour

**Depends on**: 2, 3

**Verification Tier**: full

**Files to modify**:

- `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md` - correct the
  enumeration description in the `check-record-versioning.sh` entry
- `__WHOLE_TREE__` - this phase runs `deploy-headless.sh`, regenerating the entire deployed
  `.claude/` tree

**Verification**:

- `bash agent-system/extensions/core/scripts/verify-deploy.sh` -- the complete gate set, green,
  with gate 4 passing against the redeployed `check-task-references.sh`.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` -- the complete suite set, green,
  including the three suites this task touched or added.
- `bash .claude/scripts/check-record-versioning.sh` and
  `bash .claude/scripts/check-task-references.sh` (the DEPLOYED copies, no `REPO_ROOT` override):
  both exit 0 after triage.
- `bash agent-system/extensions/core/scripts/check-extension-docs.sh` -- clean, confirming the two
  new files are properly declared in the manifest and deployed.
- Post-deploy acceptance reproduction against the deployed copy: an untracked on-disk file with a
  BLOCKING occurrence under a `PATH_SCOPE` yields exit 1 from
  `bash .claude/scripts/check-record-versioning.sh <path>`.

---

## Sibling Enumeration Audit

The task requires that sibling lints sharing the `git ls-files` enumeration be examined and named
rather than this one being fixed in isolation. All `git ls-files` call sites under
`agent-system/extensions/core/scripts/` were inspected. Findings:

**Same defect, fixed in this task** (Phase 3):

- `check-task-references.sh` -- byte-identical `scan_tree` shape, same `PATH_SCOPE` contract, same
  `-e`-only existence guard. Strictly higher stakes: it is verify-deploy gate 4 and is paired with
  the blocking `validate-no-task-references.sh` write-time hook, so its false-clean hits the same
  self-hygiene check for a new hook that the record-versioning near-miss did.

**Adjacent instance, named but deliberately not fixed here**:

- `check-extension-docs.sh:623` -- the "script file on disk NOT in `provides.scripts`" rule
  enumerates each extension's `scripts/` via `git ls-files`, so a newly written but uncommitted
  script is invisible to the manifest-declaration parity check it is supposed to be caught by. Same
  class of blind spot, but a different contract (declaration parity, with `sync-manifest-scripts.sh`
  as its paired repair tool, which needs its own audit) and a different gate (gate 3). Fixing it
  here would widen this task's footprint into gate 3's territory without the fixture coverage that
  change deserves. Recommend a separate record.

**Inspected and classified as NOT sharing the defect**:

- `script-inventory.sh:290-308` -- already enumerates the tracked/untracked union and already
  discloses the untracked set. This is the precedent this plan follows, not a defect.
- `check-runtime-file-tracking.sh:93` -- uses `git ls-files` to *determine tracking status*;
  untracked-ness is the signal the check exists to detect, not a blind spot in it.
- `lint/lint-shellcheck.sh:148` -- its default repo-wide enumeration is `git ls-files`-tracked by
  documented design, but an explicit `SCAN_PATHS` argument switches it to `find`, so the scoped
  self-check case -- the one that matters for a just-created file -- already sees untracked files.
- `assess-repo-health.sh:165` and `context-reachability.sh:245` -- tracked-only enumeration with a
  documented `find` fallback outside a work tree. Both produce health/reachability reports rather
  than a clean/dirty verdict on a specific named file, so there is no false-clean claim to make.
  Not changed here; not asserted defect-free beyond that reasoning.

## Testing & Validation

- [ ] An untracked, on-disk file containing a BLOCKING-tier record-versioning occurrence does not
  yield a clean verdict from `check-record-versioning.sh` `PATH_SCOPE` mode (the task's stated
  acceptance criterion), covered by a fixture in `test-check-record-versioning.sh`.
- [ ] The equivalent fixture passes for `check-task-references.sh` in
  `test-check-task-references.sh`.
- [ ] A gitignored file under a `PATH_SCOPE` is reported on stderr by name and reason, and is still
  not counted as a finding (existing Case 7 behavior preserved).
- [ ] The stderr diagnostics survive `--quiet`.
- [ ] A `PATH_SCOPE` that exists but enumerates nothing emits the zero-enumeration diagnostic.
- [ ] Every pre-existing case in both lint suites passes unmodified (stdout formats and exit codes
  unchanged).
- [ ] `test-git-corpus-enum-lib.sh` passes.
- [ ] `verify-deploy.sh` full gate set green, gate 4 included, against the redeployed tree.
- [ ] `run-all.sh` full suite set green.
- [ ] `lint-shellcheck.sh` clean over all five touched/created shell paths.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/lib/git-corpus-enum-lib.sh` (new)
- `agent-system/extensions/core/scripts/tests/test-git-corpus-enum-lib.sh` (new)
- `agent-system/extensions/core/scripts/check-record-versioning.sh` (modified)
- `agent-system/extensions/core/scripts/tests/test-check-record-versioning.sh` (modified)
- `agent-system/extensions/core/scripts/check-task-references.sh` (modified)
- `agent-system/extensions/core/scripts/tests/test-check-task-references.sh` (modified)
- `agent-system/extensions/core/manifest.json` (modified)
- `agent-system/extensions/core/scripts/tests/suite-classification.data` (modified)
- `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md` (modified)
- Regenerated `.claude/` deploy tree (disposable build artifact, not committed)

## Rollback/Contingency

Every change is confined to the source store under `agent-system/extensions/core/`, committed
per-phase, so rollback is `git revert` of the phase commits followed by a redeploy
(`deploy-headless.sh`) to restore the previous deployed tree. No state, schema, or data migration is
involved.

Partial-failure contingency: Phases 2 and 3 are independent consumers of Phase 1's library, so if
one lint's wiring proves problematic the other still ships. If the shared-library extraction itself
turns out to conflict with either script's library-resolution convention, the fallback is to inline
the union enumeration and diagnostics at both call sites and record the duplication explicitly in
both headers -- a worse outcome for drift, but it preserves the defect fix, which is the point of
the task. Do not fall back to a single-script fix that leaves `check-task-references.sh` defective.

If the repo-wide triage in Phase 4 surfaces a large, unexpected volume of findings in untracked
files (the measured expectation is one file), stop and report rather than mass-marking exemptions:
that volume would indicate the union is picking up a path class the `--exclude-standard` filter was
expected to exclude, which is a design question, not a triage task.
