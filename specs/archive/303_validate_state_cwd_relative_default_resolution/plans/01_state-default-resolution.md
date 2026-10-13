# Implementation Plan: Task #303

- **Task**: 303 - Make `validate-state.sh`'s omitted-argument state-file default resolve against
  the repository being validated rather than the current working directory, and survey sibling
  scripts for the same latent pattern
- **Status**: [COMPLETED]
- **Effort**: 3 hours
- **Dependencies**: 271, 279 — both declare `scripts/validate-state.sh` and
  `scripts/tests/test-validate-state.sh` in their `file_scope` for a `KNOWN_ENTRY_FIELDS`/schema
  change. These are footprint (territory) serializations, not work dependencies: nothing in this
  plan consumes either task's result, and this plan touches neither `KNOWN_ENTRY_FIELDS` nor
  `context/schemas/state-schema.json`.
- **Research Inputs**: `specs/303_validate_state_cwd_relative_default_resolution/reports/01_state-default-resolution.md`
- **Artifacts**: plans/01_state-default-resolution.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md,
  source-store-deploy-boundary.md, no-task-references-in-deliverables.md,
  shell-strict-mode.md, git-staging-scope.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`validate-state.sh`'s omitted-argument default assigns the bare relative path
`specs/state.json`, so it resolves against the invoking shell's CWD while the script itself may
have been loaded from a different repository's deploy. That combination silently validates the
wrong repository and reports its findings as if they belonged to the repository the script came
from — a false POSITIVE attributed to the wrong repo, which is the dangerous direction. This plan
re-anchors **only that default** to the git toplevel of the script's own location (upward
`.git` marker discovery via `git -C "$SCRIPT_DIR" rev-parse --show-toplevel`, never
`common_repo_root`'s caller-supplied hop count), refuses loudly when the script's own directory
is not inside a git work tree, canonicalizes the resolved `STATE_FILE` to an absolute path before
the existing banner prints it, and adds two non-vacuous regression cases to the script's own
suite. Done means: a bare invocation from a foreign repository's CWD can no longer read that
repository's state file, the banner is self-diagnosing, and the explicit-positional-argument
path — including every argument-relative sibling lookup — is proven unchanged.

**SOURCE STORE IS THE EDIT TARGET.** Every edit lands under
`agent-system/extensions/core/scripts/**`; never a deployed `.claude/**` path (`.claude/` is
gitignored and regenerated — confirmed at plan-authoring time via
`git check-ignore -v .claude/scripts/validate-state.sh` → `.gitignore:6:/.claude/`). See
`rules/source-store-deploy-boundary.md`. No task-number references in any file landing under
`agent-system/**` (`rules/no-task-references-in-deliverables.md`) — the defect, not the task
number, is what the new comments name.

### Research Integration

The report's load-bearing results drive this plan's shape:

1. **Candidate 2 wins, implemented without `common_repo_root()`.** The report verified directly
   (not by citation) that `common_repo_root "$SCRIPT_DIR" 2` gives two different answers from
   this script's two real locations: 2 hops reaches the repo root from `.claude/scripts/`, but
   only `agent-system/extensions` from `agent-system/extensions/core/scripts/`. A single
   `levels` argument cannot be correct for both, so the fix uses inline
   `git -C "$SCRIPT_DIR" rev-parse --show-toplevel` — depth-independent upward marker
   discovery. `scripts/lib/common.sh` is **not** modified (it lives under `scripts/lib/`, which
   another task declares wholesale; a marker-based mode there is a named follow-up, not an
   in-scope deliverable).
2. **The technique already has in-family precedent.**
   `scripts/tests/test-validate-state.sh` resolves its own `REPO_ROOT` with exactly
   git-toplevel-of-`SCRIPT_DIR`-first (lines 23-26). Phase 1 reuses that idiom rather than
   inventing a third resolution style — with one deliberate divergence: the test harness falls
   back to a fixed-hop guess, whereas the *default under repair* refuses loudly instead, because
   a silent fixed-hop fallback would reopen the exact layout fragility this fix closes.
3. **Candidate 1 (CWD git toplevel) is rejected**: it does not change the outcome of the observed
   incident — it would still have validated the foreign repository, merely more robustly.
   Candidate 3 (refuse on disagreement) is folded in only as the not-a-git-worktree fallback,
   because treating mere disagreement as fatal would break the benign case of running the
   deployed script from an unrelated CWD.
4. **No production caller exercises the default today** (gate 10 of `verify-deploy.sh`,
   `commands/task.md`, `tests/test-init-specs.sh`, and the suite's own fixtures all pass an
   explicit positional path). Two consequences this plan acts on: regression risk against CI is
   very low, and the new test case must be genuinely new — there is no existing coverage of the
   zero-argument form to extend.
5. **Sibling survey is already complete and is report-only.** Acceptance #6 is discharged by the
   report's `## Sibling Survey (Part b)` table; Phase 3 verifies its presence and carries the
   recommended follow-ups into the summary. No sibling is remediated here.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch; no roadmap phases are included.

## Goals & Non-Goals

**Goals**:
- The omitted-argument default resolves from the script's own location, never from the ambient
  CWD, so a bare invocation names the repository whose deploy is actually running.
- A bare invocation from a foreign repository's CWD never silently validates that repository: it
  either validates the script-anchored repository or refuses (exit 2) naming the probed
  directory.
- The `Validating state file:` banner prints an ABSOLUTE resolved path, for both the defaulted
  and the explicit-argument cases, so a false finding is self-diagnosing.
- The explicit-positional-argument path behaves exactly as today, including the argument-relative
  location of the sibling `TODO.md`, the sibling `archive/state.json`, and `--fix`'s
  `state-write.sh` candidate search.
- `scripts/tests/test-validate-state.sh` gains a cross-repo omitted-argument case and an
  argument-relativity regression case, both non-vacuous.

**Non-Goals**:
- Converting the script to `PROJECT_ROOT`-relative resolution anywhere in its body. The
  argument-relative design is intentional and is what lets the script validate archive and vault
  targets; only the DEFAULT changes.
- Adding a `--state` flag. This script has no such flag and must not gain one — the override is
  the bare positional `STATE_FILE` argument (`--state` belongs to `generate-todo.sh`).
- Remediating any sibling script (`command-gate-in.sh`, `command-gate-out.sh`,
  `git-snapshot.sh`, `orchestrate-build-dispatch.sh`, `init-specs.sh`). Survey and report only.
- Touching `KNOWN_ENTRY_FIELDS` or `context/schemas/state-schema.json` (owned elsewhere), or
  modifying `scripts/lib/common.sh`.
- Changing the missing-file error message shape or the existence-check ordering.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Line numbers shift under the two footprint-colliding tasks, so an edit lands in the wrong block | M | H | Every phase re-greps its anchor by CONTENT, never by line number (`grep -n 'STATE_FILE="specs/state.json"'`, `grep -n 'Validating state file'`). Re-read both files immediately before editing, per territory discipline. |
| Canonicalizing `STATE_FILE` changes an error/output string some caller parses | H | L | Canonicalization is sited strictly on the success path, AFTER the existing `-f` check, so the "File not found" message is byte-unchanged. Verified at plan-authoring time: no file outside the two copies of `validate-state.sh` greps `Validating state file`; `commands/task.md` greps only `file_scope` lines; gate 10 and `test-init-specs.sh` read only the exit code. |
| `cd "$(dirname …)" && pwd` alters an already-valid explicit path (symlinked `/tmp`, logical vs. physical pwd) | M | L | Reuse the file's own existing idiom verbatim (the `state_dir` computation already in the `--deep` block), so defaulted and explicit paths are normalized identically to how `--deep` already normalizes today. Phase 2's argument-relativity case asserts sibling lookups still resolve against the fixture dir. |
| A stale deployed `.claude/scripts/validate-state.sh` makes the new test case pass vacuously | H | M | New case resolves its validator source-store-first and grep-gates the candidate on a stable marker token, exactly as the suite's existing `D5_VALIDATOR`/`FS_VALIDATOR`/`SCOPE_VALIDATOR` resolutions already do. |
| New case flaky because it depends on the live repo's own `specs/state.json` validating cleanly | M | M | Assertions are non-contamination assertions (output must not name the foreign CWD, must not carry the foreign fixture's distinctive failure signature, must name a path under the script-anchored root) — never a hard-coded exit code against the live state file. |
| `git` unavailable, or the deploy tree exported without `.git` | M | L | Explicit `command -v git` guard plus empty-toplevel guard, both routing to one loud exit 2 that names the probed `SCRIPT_DIR` and tells the caller to pass an explicit positional `STATE_FILE`. No silent fallback. |
| Concurrent sibling redeploy races Phase 3's `deploy-headless.sh` | L | M | `.claude/` is gitignored, so a redeploy produces no commit conflict; redeploy is idempotent. Re-run the suite against the deployed copy after redeploying, and if a foreign commit or foreign uncommitted modification appears, STOP and report per the dispatch's concurrency note. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 1, 2 |

Phases within the same wave can execute in parallel. This plan is strictly serial: the test case
needs Phase 1's marker token and behavior, and the gate run needs both.

---

### Phase 1: Script-anchored default resolution and absolute banner [COMPLETED]

**Goal**: The omitted-argument default names the repository the script itself came from, refusing
loudly when that cannot be determined; the resolved `STATE_FILE` is absolute before the banner
prints it. Nothing else in the resolution chain changes.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/scripts/validate-state.sh` immediately before *(completed)*
      editing (territory discipline — two other tasks declare this file). Re-locate all four
      anchors by content, not by the line numbers quoted in this plan:
      `grep -n 'STATE_FILE="specs/state.json"'`, `grep -n 'Validating state file'`,
      `grep -n 'SCRIPT_DIR='`, `grep -n 'defaults to specs/state.json'`.
- [x] Replace the `if [[ -z "$STATE_FILE" ]]; then STATE_FILE="specs/state.json"; fi` block with *(completed)*
      script-anchored resolution, immediately above a comment carrying the literal grep-gate
      token **`default-resolution: script-anchored`** (Phase 2 greps for this exact string; keep
      it byte-stable):
  - [x] Guard `command -v git >/dev/null 2>&1` (the same guard this file already uses for its *(completed)*
        git-dependent `--deep` check) and compute
        `_default_root="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || true)"`.
  - [x] When git is unavailable OR `_default_root` is empty: `exit 2` with a message naming the *(completed)*
        probed `SCRIPT_DIR`, stating that the omitted-argument default cannot be resolved
        without a git work tree at the script's own location, and instructing the caller to pass
        an explicit positional `STATE_FILE`. **No fixed-hop fallback** — a silent layout guess
        for the default itself is exactly the fragility under repair.
  - [x] Otherwise `STATE_FILE="$_default_root/specs/state.json"` and echo one informational line *(completed)*
        stating the default was resolved from the script's own location, naming the resolved
        path.
  - [x] Add a self-diagnosing divergence note: compute the CWD's own git toplevel *(completed)*
        (`git rev-parse --show-toplevel`, failure tolerated) and, when it is non-empty and
        differs from `_default_root`, print a note on stderr naming BOTH candidates and stating
        which one was used. Informational only — it does NOT refuse, because disagreement is the
        benign common case of running the deployed script from an unrelated directory.
  - [x] Preserve `set -uo pipefail` compatibility: every new variable is assigned before use and *(completed)*
        every command substitution that may legitimately fail carries `|| true` or an explicit
        test (`context/standards/shell-strict-mode.md`).
- [x] Leave the existing `if [[ ! -f "$STATE_FILE" ]]` existence check and its *(completed)*
      `[FAIL] File not found: $STATE_FILE` message **byte-identical**, and leave it in its
      current position (it must still name the path exactly as given/resolved).
- [x] Immediately AFTER that existence check — i.e. strictly on the success path, before the *(completed)*
      banner — canonicalize unconditionally for both the defaulted and explicit cases, reusing
      this file's own existing idiom rather than introducing a second style:
      `STATE_FILE="$(cd "$(dirname "$STATE_FILE")" && pwd)/$(basename "$STATE_FILE")"`.
      Add a short comment recording WHY (the banner must be self-diagnosing; a false finding
      must name the repository it came from).
- [x] Do **not** modify the three argument-relative sibling-resolution sites (the `--deep` block's *(completed)*
      `state_dir`/`sibling_todo`, the `archive_file`, and `--fix`'s `_fix_state_dir` /
      `state-write.sh` candidate search). They read `STATE_FILE` after the normalization above and
      are correct unchanged.
- [x] Update the header comment block, which is also the `--help` output (the `--help` handler *(completed)*
      prints every leading `#` line, so no separate usage text exists to edit):
  - [x] Replace the sentence "STATE_FILE defaults to specs/state.json relative to the current *(completed)*
        working directory when omitted." with the new contract: the default is
        `specs/state.json` under the git toplevel of the SCRIPT's own directory, independent of
        the caller's CWD, with a loud exit 2 when that toplevel cannot be determined.
  - [x] Extend the existing "Deliberately argument-relative, not PROJECT_ROOT-relative" paragraph *(completed)*
        with one or two sentences distinguishing the two grains explicitly: the BODY stays
        argument-relative (sibling `TODO.md`, sibling `archive/state.json`, `--fix`'s writer
        search all key off `STATE_FILE`'s own directory), while only the DEFAULT applied when the
        argument is omitted is script-anchored — and state the reason (cross-repo invocation is
        normal in this architecture, and a CWD-relative default silently validated the wrong
        repository, reporting a false positive against it).
  - [x] Note that `common_repo_root()` is deliberately NOT used, because its caller-supplied hop *(completed)*
        count cannot be correct for both of this script's locations simultaneously
        (`.claude/scripts/` and `agent-system/extensions/core/scripts/` sit at different depths).

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts (i) the default block is a 3-line
`if [[ -z "$STATE_FILE" ]]` assignment of the bare literal `specs/state.json`, (ii) the banner is
a single `echo "Validating state file: $STATE_FILE"`, (iii) `SCRIPT_DIR` is already computed near
the top of the argument section and is otherwise unused for the default, (iv) exactly one header
sentence documents the CWD-relative default, and (v) exactly three argument-relative sibling
sites exist and need no change. All five were re-derived at plan-authoring time by grep against
`agent-system/extensions/core/scripts/validate-state.sh` (hits at lines 279, 445, 184, 47, and
311-312/799-800/832 respectively) — the research report's own line numbers already differ from the
dispatch's, so these WILL shift again once the two footprint-colliding tasks land. Confirm at
implementation time by re-running the four content greps listed in the first task above; if any
anchor returns zero or more than one hit, stop and report rather than editing by line number.

**Files to modify**:
- `agent-system/extensions/core/scripts/validate-state.sh` - replace the omitted-argument default
  with script-anchored git-toplevel resolution plus a loud no-worktree refusal; add the
  `default-resolution: script-anchored` marker comment; add success-path absolute-path
  canonicalization before the banner; update the header/`--help` contract text

**Verification**:
- `bash -n agent-system/extensions/core/scripts/validate-state.sh` exits 0, and
  `shellcheck agent-system/extensions/core/scripts/validate-state.sh` reports no new findings
  relative to a pre-change run of the same command (compare the two outputs; check the exit
  status of each run, never only the diff of captured stdout).
- `bash agent-system/extensions/core/scripts/validate-state.sh --help` prints the revised
  default contract and no longer contains the string
  "relative to the current working directory".
- Explicit-argument parity, the enumerated direct dependents for this tier:
  `bash agent-system/extensions/core/scripts/tests/test-validate-state.sh` still passes in full
  (pre-existing cases only — Phase 2 has not added its cases yet);
  `bash agent-system/extensions/core/scripts/tests/test-init-specs.sh` still passes; and a
  base-mode invocation with an explicit positional `specs/state.json` still emits the
  `file_scope` lines `commands/task.md` greps for.
- Omitted-argument behavior, by hand from a directory outside this repository (for example
  `$HOME`): `bash <abs path>/agent-system/extensions/core/scripts/validate-state.sh` names
  THIS repository's `specs/state.json` in its banner, as an absolute path, and the banner path is
  not under the invoking CWD.
- `git diff` on the script shows changes confined to the default block, the canonicalization
  line, the marker comment, and the header text — no hunk inside `KNOWN_ENTRY_FIELDS` or any
  check body.

---

### Phase 2: Non-vacuous cross-repo and argument-relativity regression cases [COMPLETED]

**Goal**: The suite proves both halves of the acceptance bar mechanically: a bare invocation from
a foreign repository's CWD does not read that repository's state file (and would have, pre-fix),
and an explicit positional argument still drives every sibling lookup from the argument's own
directory regardless of CWD.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/scripts/tests/test-validate-state.sh` immediately *(completed)*
      before editing (same two tasks declare it). Note its existing conventions to reuse
      verbatim: `pass()`/`fail()`/`info()` helpers, `PASSED`/`FAILED` counters, one shared
      `WORKDIR="$(mktemp -d)"` with an `EXIT` trap, `# ====` section banners, and the
      source-store-first grep-gated validator-resolution blocks.
- [x] Add an `XREPO_VALIDATOR` resolution block in the established shape: candidates *(completed)*
      `"$SCRIPT_DIR/../validate-state.sh"` then `"$REPO_ROOT/.claude/scripts/validate-state.sh"`,
      each trusted only after `grep -q 'default-resolution: script-anchored'` succeeds, with a
      header comment stating that source-store-first ordering plus the grep gate is what prevents
      a stale deployed copy from producing a false green. Skip the cases with an `info` note (not
      a `fail`) when no candidate qualifies, matching the existing blocks' posture.
- [x] Case A — cross-repo omitted-argument invocation (Acceptance #1, #2): *(completed)*
  - [x] Build `OTHER_CWD="$WORKDIR/other-repo"` with `specs/state.json` containing a *(completed)*
        DELIBERATELY DISTINCTIVE and invalid payload (malformed JSON), so reading it produces a
        recognizable signature that cannot occur by coincidence from the correct file. Add a
        comment stating this is the non-vacuity device.
  - [x] Invoke in a subshell: `out=$( cd "$OTHER_CWD" && bash "$XREPO_VALIDATOR" 2>&1 )`, with *(completed)*
        **no** positional argument, capturing `rc` separately.
  - [x] Assert non-contamination, never a hard-coded exit code against the live state file: *(completed)*
        output contains no occurrence of `$OTHER_CWD`; output does not carry the malformed-JSON
        failure signature; and output names a `specs/state.json` path under the validator's own
        script-anchored repository root as an ABSOLUTE path (accept either the banner line or,
        if that repository has no `specs/state.json`, the `File not found:` line — assert the
        path, not the outcome).
  - [x] Add a comment recording that pre-fix this case fails by construction, because the bare *(completed)*
        relative default would have read `$OTHER_CWD/specs/state.json`.
- [x] Case B — explicit-argument argument-relativity regression (Acceptance #3), run from a *(completed)*
      foreign CWD so the property under test is isolated from the ambient CWD:
  - [x] Build `$WORKDIR/argrel/specs/state.json` as a valid fixture whose only dependency edge *(deviation: altered — built at `$WORKDIR/argrel/state.json` with no intervening `specs/` subdirectory, exactly mirroring the archived-parent fixture's own construction (`$WORKDIR/d6-archived-fixture.json` + sibling `$WORKDIR/archive/state.json`), which the plan separately instructs this item to mirror; functionally identical argument-relative-sibling-lookup property, one directory level shallower)*
        points at a project number present solely in a sibling `archive/state.json`
        (`archived_projects`/`completed_projects`), mirroring the existing archived-parent
        fixture's construction.
  - [x] With the sibling archive present, `--deep` from inside `$OTHER_CWD` with the fixture's *(completed)*
        ABSOLUTE path as the positional argument reports no dangling dependency; with the
        sibling archive removed (or absent), the same invocation DOES report the dangling
        dependency. The flip proves the archive was located relative to the argument, not to CWD
        or to any repo root.
  - [x] With no sibling `TODO.md`, assert the output carries the existing *(completed)*
        `No sibling TODO.md next to <fixture path>` warning naming the FIXTURE's path (not a path
        under `$OTHER_CWD` and not this repository's `specs/TODO.md`); with a sibling `TODO.md`
        created next to the fixture, assert that warning is absent. This asserts WHICH sibling
        was addressed without depending on `generate-todo.sh`'s deploy-root guard succeeding.
  - [x] Assert the banner for this explicit-argument invocation also prints an absolute path *(completed)*
        equal to the fixture's own absolute path.
- [x] Non-vacuity demonstration (Acceptance #4), performed once at implementation time and *(completed)*
      recorded, not left as an assertion the suite cannot make about its own past:
  - [x] Extract the pre-fix script to a scratch file — *(completed)*
        `git show HEAD:agent-system/extensions/core/scripts/validate-state.sh > <scratch>/prefix-validate-state.sh`
        taken from the commit BEFORE Phase 1's commit — and run Case A's invocation against it
        from `$OTHER_CWD`.
  - [x] Record the verbatim evidence (the pre-fix run reads `$OTHER_CWD`'s fixture and carries *(completed)*
        the malformed-JSON signature; the post-fix run does not) in the phase's progress notes,
        for the implementation summary. Use a scratch path outside the repository; do not commit
        the extracted copy.
- [x] Add no task-number references anywhere in the test file; name the defect and the behavior, *(completed)*
      not the task.

**Timing**: 1.25 hours

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts (i) no existing case in the suite exercises the
zero-argument form (every existing invocation passes an explicit `"$WORKDIR/<fixture>.json"`),
(ii) the suite already carries three source-store-first grep-gated validator-resolution blocks
to copy (`D5_VALIDATOR`, `FS_VALIDATOR`, `SCOPE_VALIDATOR`), and (iii) a sibling-archive fixture
precedent already exists in the file. (i) is carried from the research report and re-derived at
plan-authoring time by inspecting the suite's invocation sites; (ii) and (iii) were re-derived by
grep at plan-authoring time (resolution blocks and the archived-parent fixture, around lines
47-108 and 1176-1234 respectively). Confirm at implementation time with
`grep -n 'bash "\$[A-Z_]*VALIDATOR"' agent-system/extensions/core/scripts/tests/test-validate-state.sh`
— if any existing invocation turns out to pass no positional argument, reconcile with it rather
than adding a duplicate case.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-validate-state.sh` - add the `XREPO_VALIDATOR`
  resolution block, Case A (cross-repo omitted argument), and Case B (explicit-argument
  argument-relativity regression)

**Verification**:
- `bash -n` and `shellcheck` clean on the test file (check each command's exit status).
- `bash agent-system/extensions/core/scripts/tests/test-validate-state.sh` exits 0 with every
  case passing, and its summary line shows a strictly larger passed count than the pre-change
  run (record both numbers).
- Both new cases genuinely execute rather than silently skipping: confirm the `XREPO_VALIDATOR`
  grep gate resolved (its `info` skip note is absent from the output).
- The recorded pre-fix demonstration shows Case A failing against the pre-fix script —
  the evidence that the case is not vacuous.
- Re-run the suite twice in a row: it is idempotent and leaves no residue outside `WORKDIR`
  (`git status --short` unchanged by the run).

---

### Phase 3: Redeploy, full gate set, and acceptance ledger [COMPLETED WITH EXCLUSIONS]

**Goal**: The fix is live in the deployed tree, the complete repository gate set is green, and
every acceptance criterion — including the report-only sibling survey — is explicitly accounted
for in the summary.

**Tasks**:
- [x] Re-read both changed files and run `git status --short` first. If a foreign commit, a *(completed)*
      foreign uncommitted modification, or a build you did not start is present, STOP and report
      it after checking `git log` to confirm the work is not your own (dispatch concurrency
      note).
- [x] Redeploy: `bash agent-system/extensions/core/scripts/deploy-headless.sh`. *(completed)*
- [x] Confirm deploy parity for both changed files: *(completed)*
      `diff -q .claude/scripts/validate-state.sh agent-system/extensions/core/scripts/validate-state.sh`
      and the same for `scripts/tests/test-validate-state.sh` — both must report no difference.
- [x] Re-run the suite against the DEPLOYED copy as well as the source-store copy *(completed)*
      (`bash .claude/scripts/tests/test-validate-state.sh`), so the deployed path is exercised,
      not merely assumed.
- [x] Run the complete gate set: `bash .claude/scripts/verify-deploy.sh` (this tier's required *(deviation: altered — gate 10 confirmed green as required; the full gate set reported 3 of 35 failing, each confirmed via git log/git status to be caused by concurrent sibling task work outside this task's file_scope rather than by this change — see this phase's Reasoned Exclusions table)*
      entry point). Confirm specifically that gate 10 — `validate-state.sh --deep` against the
      live `specs/state.json`, the only production `--deep` caller — passes. If any gate fails,
      fix forward; never discard uncommitted changes to reach a passing gate
      (`rules/error-handling.md`).
- [x] Verify Acceptance #6 without rewriting the report: confirm *(completed)*
      `reports/01_state-default-resolution.md` contains the `## Sibling Survey (Part b …)`
      section with a per-site verdict for every surveyed site, and reference that section from
      the implementation summary rather than duplicating it.
- [x] Record in the implementation summary, as recommendations only (do not file tasks, do not *(completed)*
      edit any sibling script): (a) a follow-up covering `command-gate-in.sh` and
      `command-gate-out.sh`, the two siblings the survey classes as the same defect family;
      (b) a lower-priority diagnostic-only improvement to `git-snapshot.sh`'s success-path
      logging; (c) the optional `common_repo_root()` marker-mode and
      `context/patterns/` path-resolution-idioms documentation follow-ups the report names.
- [x] Write the acceptance ledger into the summary: each of the six dispatch acceptance criteria *(completed)*
      with the verbatim command or observation that discharges it.
- [x] Commit with targeted, work-scoped staging only — an explicit two-path *(completed)*
      `git add -- <script> <test>`, never `git add -A`, never a directory or glob pathspec
      (`context/standards/git-staging-scope.md`). Review `git status --short` and
      `git diff --staged` before committing. `.claude/**` is gitignored and must not appear in
      the staged set.

#### Reasoned Exclusions

| Item | Reason | Evidence |
|------|--------|----------|
| Gate 3 (doc-lint, `check-extension-docs.sh`) full-green requirement | Fails on an advisory item unrelated to this task's file_scope: `observers.books-observe` (`scripts/books-observe.sh`) not yet deployed, under the `books` extension. This drift pre-dates this dispatch — present in the repository's dirty working tree before this task's first commit — and is outside the `agent-system/extensions/core/scripts/{validate-state.sh,tests/test-validate-state.sh}` footprint this task declares. | `bash .claude/scripts/check-extension-docs.sh` output: `core FAIL` with the single advisory `observers.books-observe ('scripts/books-observe.sh') resolves to scripts/books-observe.sh, which is not yet deployed`; no mention of `validate-state.sh` or `test-validate-state.sh` anywhere in the output. |
| Gate 5 (manifest-driven content-hash equality, `verify.lua`) full-green requirement | Fails on `scripts/lib/redeploy-checkpoint-lib.sh` differing between the deployed tree and the source store — a file this task never touches. `git log` confirms the last commit to that file predates this task's Phase 1 commit; `git status`/`git log` taken mid-Phase-3 showed it uncommitted-modified, then (after two further commits landed) committed by `task 367 phase 1`/`task 367 phase 2` — concurrent sibling work. Task 367 declares this exact file in its own `file_scope` per this dispatch's Territory block. The deployed copy is simply stale relative to task 367's own in-flight source-store edits; redeploying again mid-flight would chase a moving target that is task 367's own responsibility to land and redeploy, not this task's. | `diff .claude/scripts/lib/redeploy-checkpoint-lib.sh agent-system/extensions/core/scripts/lib/redeploy-checkpoint-lib.sh` reports a difference; `git log --oneline -5` shows `4b22dab0e task 367 phase 2: widen the promotion pass to a system-wide deploy-pending sweep` and `abd37b973 task 367 phase 1: reproduction harness and pre-fix characterization` landing after this task's `44b1ab112`/`4bc84e609` commits; the dispatch's Territory JSON lists `agent-system/extensions/core/scripts/lib/redeploy-checkpoint-lib.sh` under task 367's `file_scope`. |
| Gate 8 (shell test-suite runner, `run-all.sh`) full-green requirement | Fails via `test-gate-out-repair-reporting.sh`'s own internal "contamination guard" (Case 8), which asserts the real `specs/` tree is byte-identical before and after the suite runs. The one diff between its captured baseline and final `git status --short` snapshots is `specs/367_reduce_deploy_staleness_completion_round_trip/issues.jsonl` newly modified — a concurrent write by sibling task 367's own dispatch during this suite's brief run window, not by anything `validate-state.sh`/`test-validate-state.sh`-related. This task's own pre-existing `specs/303_.../issues.jsonl` modification is present identically in BOTH the baseline and final snapshots (not the diff trigger). | `tail` of the suite's own failure output: `[FAIL] real specs/ tree status changed during this suite (baseline vs. final differ)`, with the printed baseline/final `git status --short` block showing `specs/367_reduce_deploy_staleness_completion_round_trip/issues.jsonl` present only in "final"; `git log` confirms task 367's phase-1/phase-2 commits landed in this same window. |

Gate 10 (`validate-state.sh --deep`, this task's actually-governing acceptance gate per the
dispatch's ACCEPTANCE #5) is independently confirmed `[PASS]` in the same `verify-deploy.sh` run
("10. specs/state.json schema validation (validate-state.sh --deep) [PASS]"), and separately via
direct invocation (`bash .claude/scripts/validate-state.sh --deep specs/state.json`, exit 0, zero
`[FAIL]` lines). None of the three excluded gates names `validate-state.sh` or
`test-validate-state.sh` in any failure line. No follow-up task is recorded for these three
exclusions: each is either pre-existing drift in an unrelated extension (gate 3) or squarely
owned by sibling task 367's own in-flight work, which that task's own Phase 3/redeploy step will
resolve (gates 5, 8) — nothing remains for THIS task to do.

**Timing**: 0.75 hours

**Depends on**: 1, 2

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts that gate 10 of `verify-deploy.sh` is the only
production `--deep` caller and that the live caller set is exactly `verify-deploy.sh` gate 10,
`commands/task.md`, `tests/test-init-specs.sh`, and this script's own suite. Carried from the
research report (which enumerated it by `grep -rn 'validate-state.sh'` across both
`agent-system/extensions/core` and `.claude`) and spot-confirmed at plan-authoring time against
`verify-deploy.sh`'s gate-10 block. Confirm at implementation time by re-running
`grep -rn 'validate-state.sh' --include='*.sh' --include='*.md' agent-system/extensions .claude`
before declaring the gate run sufficient; a caller that appeared since the research pass must be
exercised too.

**Files to modify**:
- None in the source store. This phase runs the deploy and the gate set; its outputs are the
  regenerated (gitignored) `.claude/**` tree and the implementation summary.

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` exits 0 — the complete gate set for this repository,
  gate 10 included and named explicitly in the recorded output.
- Both `bash agent-system/extensions/core/scripts/tests/test-validate-state.sh` and
  `bash .claude/scripts/tests/test-validate-state.sh` exit 0.
- Both `diff -q` deploy-parity checks report no difference.
- The implementation summary contains the six-row acceptance ledger and the follow-up
  recommendations, and references the report's survey section.
- `git log -1 --stat` shows exactly the two intended source-store files and no `.claude/**` path.

---

## Testing & Validation

- [ ] `bash -n` and `shellcheck` clean on `validate-state.sh` and `test-validate-state.sh`, with
      each command's exit status checked (no new findings relative to a pre-change run). This
      repository provides no wrapper entry point for `shellcheck` — verified at plan-authoring
      time: `agent-system/extensions/core/scripts/lint/` contains no shell-lint wrapper and the
      aggregate gate (`verify-deploy.sh`) invokes none — so the bare tool is the only available
      invocation, and every criterion naming it above therefore also requires asserting the
      command's exit status rather than only diffing captured output.
- [ ] `bash agent-system/extensions/core/scripts/tests/test-validate-state.sh` passes in full,
      with a strictly higher passed count than before this task, and the two new cases confirmed
      to have executed rather than skipped.
- [ ] `bash .claude/scripts/tests/test-validate-state.sh` passes in full after redeploy.
- [ ] `bash agent-system/extensions/core/scripts/tests/test-init-specs.sh` passes (the other
      suite that invokes this validator).
- [ ] `bash .claude/scripts/verify-deploy.sh` exits 0, gate 10 included.
- [ ] Manual cross-repo probe from a CWD outside this repository: bare invocation names this
      repository's `specs/state.json` absolutely and never the foreign CWD's.
- [ ] Recorded pre-fix demonstration proves the new cross-repo case is non-vacuous.
- [ ] Explicit-argument parity: sibling `TODO.md`, sibling `archive/state.json`, and the banner
      path all resolve from the argument's own directory, asserted from a foreign CWD.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/validate-state.sh` — script-anchored omitted-argument
  default, loud no-worktree refusal, absolute-path banner, revised header/`--help` contract.
- `agent-system/extensions/core/scripts/tests/test-validate-state.sh` — `XREPO_VALIDATOR`
  resolution block plus the cross-repo omitted-argument case and the explicit-argument
  argument-relativity regression case.
- Regenerated (gitignored) `.claude/**` deploy tree.
- `specs/303_validate_state_cwd_relative_default_resolution/summaries/01_state-default-resolution-summary.md`
  — acceptance ledger, pre-fix non-vacuity evidence, and the survey follow-up recommendations.

## Rollback/Contingency

Both edits are confined to two tracked source-store files with no schema, state, or data
migration, so rollback is a revert of this task's commits (`git revert <sha>`) followed by
`bash agent-system/extensions/core/scripts/deploy-headless.sh` to restore the deployed tree.
Before any intentional rollback that would otherwise be blocked by the destructive-git guard,
take a snapshot first: `bash .claude/scripts/git-snapshot.sh 303`. For an ordinary defensive
checkpoint before risky work (not a rollback), use
`bash .claude/scripts/git-snapshot.sh 303 --no-revert`, which is durable without reverting the
working tree.

Contingencies:
- **Gate 10 fails for a reason unrelated to this change** (the live `specs/state.json` genuinely
  drifted, plausible with concurrent siblings in flight): record the finding, confirm by running
  the same gate against `HEAD`'s pre-change deployed copy, and report rather than "fixing" the
  live state file inside this task — state repair is outside this task's declared footprint.
- **A footprint-colliding task lands mid-implementation**: re-read the file, re-locate anchors by
  content, and re-apply. The regions do not overlap (`KNOWN_ENTRY_FIELDS` and the schema vs. the
  default-resolution block and the banner), so either order merges cleanly.
- **The no-worktree refusal proves too strict for a real caller**: do NOT reintroduce a silent
  fallback. Report it and let the caller pass an explicit positional `STATE_FILE`, which is the
  documented override and is unaffected by this change.
