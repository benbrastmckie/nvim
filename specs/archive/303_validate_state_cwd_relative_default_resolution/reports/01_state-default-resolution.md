# Research Report: Task #303

**Task**: 303 - Make `validate-state.sh`'s omitted-argument state-file default resolve against
the repository being validated rather than the current working directory, and survey sibling
scripts for the same latent pattern.
**Started**: 2026-10-08
**Completed**: 2026-10-08
**Effort**: small (single-file remedy, scoped to one default-resolution block + banner + one new
test case)
**Dependencies**: 271, 279 (declared file-scope collision on `scripts/validate-state.sh` and
`scripts/tests/test-validate-state.sh`; different edit regions, see Decisions)
**Sources/Inputs**: Codebase (`agent-system/extensions/core/scripts/validate-state.sh`,
`lib/common.sh`, `tests/test-validate-state.sh`, sibling scripts named in the dispatch), git
history context already embedded in file headers.
**Artifacts**: - `specs/303_validate_state_cwd_relative_default_resolution/reports/01_state-default-resolution.md` (this report)
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The defect is real, precisely located, and currently dormant in production: every live caller
  of `validate-state.sh` (gate 10 of `verify-deploy.sh`, `commands/task.md`, and
  `tests/test-init-specs.sh`) already passes an explicit positional `STATE_FILE`. The
  omitted-argument default at `scripts/validate-state.sh:277-279` (current line numbers; the
  dispatch's `241-243` reflects an earlier revision) is exercised only by ad hoc/interactive
  invocation — exactly the circumstance that produced the observed cross-repo false positive.
- **Recommended fix**: anchor the omitted-argument default to the git toplevel of the script's
  own location (`git -C "$SCRIPT_DIR" rev-parse --show-toplevel`), not to the CWD and not to a
  fixed hop-count (`common_repo_root`). This is candidate (2) from the dispatch, implemented via
  the layout-independent technique the Adjacent Worked Precedent recommends, rather than via
  `common_repo_root()`'s caller-supplied hop count, which is the wrong tool here for a documented
  reason explained below. Refuse loudly (exit 2) only in the residual case where `SCRIPT_DIR` is
  not inside a git work tree at all (folding candidate (3) in as a fallback, not a primary
  mechanism).
- **This exact technique is not a novel import** — `scripts/tests/test-validate-state.sh` itself
  already uses "git toplevel of `SCRIPT_DIR`, fixed-hop fallback only if that fails" (lines
  16-23) to resolve its own `REPO_ROOT` across the deployed/source-store split. The fix for
  `validate-state.sh`'s default should reuse the identical idiom already proven correct, in the
  same file family, rather than introduce a new strategy.
- `common_repo_root("$SCRIPT_DIR", 2)` (candidate 2 as the dispatch literally phrases it) was
  checked directly against both of this script's real deploy locations and does **not** produce
  the same answer from both: from the deployed location (`.claude/scripts`) 2 hops reaches the
  repo root; from the source-store location
  (`agent-system/extensions/core/scripts`) 2 hops reaches only `agent-system/extensions`, two
  levels short of the real repo root. `common_repo_root()` is confirmed unsuitable for this
  family of caller, matching the Adjacent Worked Precedent's warning verbatim.
- Sibling survey (Part b) completed: two siblings share the same defect family
  (`command-gate-in.sh:65`, `command-gate-out.sh:63/87`), one is already fail-loud with partial
  CWD diagnostics but shares the same latent risk by a different, more defensible design rationale
  (`git-snapshot.sh:248,332,337`), one is *not* the same defect because it pins CWD before the
  bare reference is ever reached (`orchestrate-build-dispatch.sh:246`), and `init-specs.sh` is
  confirmed CWD-relative by design (excluded, per the dispatch's own instruction).
- No code was changed in this research pass. Remediation is scoped to `validate-state.sh` and its
  test suite only, per the dispatch.

## Context & Scope

Researched: the exact resolution mechanism for the omitted-`STATE_FILE` default in
`scripts/validate-state.sh`, verification that no production caller currently depends on that
default, confirmation of the argument-relative design that must be preserved, a concrete and
verified choice among the three candidate fixes the dispatch poses, and the Part (b) sibling
survey. Out of scope (per the dispatch): the `research_questions`/`KNOWN_ENTRY_FIELDS` schema
work owned by task 279, and remediating any sibling other than `validate-state.sh` itself.

All line numbers below are current-file line numbers (re-greped during this research pass), not
the dispatch's own line numbers, which were taken against an earlier revision of the file and
have since shifted (e.g. the default block is now at lines 277-279, not 241-243; the banner is at
line 445, not 408). The content and shape of both are otherwise exactly as the dispatch
describes.

## Findings

### Codebase Patterns

**The default-resolution site, current line numbers** (`scripts/validate-state.sh:277-279`):
```bash
if [[ -z "$STATE_FILE" ]]; then
  STATE_FILE="specs/state.json"
fi
```
Immediately followed (280-283) by the existence check that exits 2 on a missing file, and by the
banner at line 445: `echo "Validating state file: $STATE_FILE"`.

**The argument-relative design to preserve** is implemented three separate times, all
keyed off `STATE_FILE`'s own directory, never `PROJECT_ROOT`:
- `state_dir="$(cd "$(dirname "$STATE_FILE")" && pwd)"` (line 799, inside the `--deep` block) —
  already canonicalizes to an absolute path today, just scoped to the `--deep` block rather than
  applied unconditionally up front.
- `sibling_todo="$state_dir/TODO.md"` (line 800) and `archive_file="$state_dir/archive/state.json"`
  (line 832).
- The `--fix` `state-write.sh` candidate search (`_fix_state_dir`, lines 311-312, feeding the
  candidate list at 316-318) walks from `STATE_FILE`'s own directory's git toplevel, not from
  `SCRIPT_DIR` or any fixed `PROJECT_ROOT`.

None of these three sites needs to change. The fix is scoped exclusively to the *default value
assigned* at lines 277-279 and to making the printed/used `STATE_FILE` absolute from that point
on (satisfying Acceptance #2) — once `STATE_FILE` is absolute, `dirname`/`cd`/`pwd` at line 799
remains correct and unaffected for both the default and the explicit-argument cases alike.

**No `--state` flag exists on this script** — confirmed by reading the full argument-parsing
loop (lines 183-233): the only recognized flags are `--deep`, `--fix`, `--strict`,
`--session-id`, `--allow-artifact-removal`, `--help`/`-h`; every other token falls to the
default case and is assigned positionally to `STATE_FILE` (line 231). `--state` belongs to
`generate-todo.sh`, invoked internally at the TODO-sync check. The dispatch's interface
correction is confirmed accurate; no acceptance criterion here should reference a `--state`
flag.

**No production caller currently exercises the default.** Grepped every call site across
`agent-system/extensions/core` and the deployed `.claude/`:
- `scripts/verify-deploy.sh:668` (gate 10, the only production `--deep` caller) — passes
  `"$TARGET/specs/state.json"` explicitly, absolute.
- `commands/task.md:231` — passes `specs/state.json` explicitly (relative, but explicit).
- `scripts/tests/test-init-specs.sh:118` — passes `specs/state.json` explicitly.
- `scripts/tests/test-validate-state.sh` (the script's own suite) — every existing fixture call
  passes an explicit `"$WORKDIR/<fixture>.json"` path; no existing case exercises the
  zero-argument form.

This means the fix carries very low regression risk against anything currently wired into CI —
the omitted-argument path is, today, reachable only by a human or an agent invoking the script
bare, which is exactly how the Observed Damage incident happened. It also means Acceptance #4
("constructed so it cannot pass vacuously") must introduce a genuinely new test case; there is no
existing coverage to extend.

### `common_repo_root()` is confirmed unsuitable (verified directly, not just cited)

`lib/common.sh:116-139` implements `common_repo_root <script_dir> <levels>` by literally
appending `/..` `<levels>` times to `<script_dir>` and canonicalizing via `cd && pwd` — a
caller-supplied hop count, exactly as the Adjacent Worked Precedent describes. This script's two
real deploy locations sit at different depths below the true repo root:
- Deployed: `.claude/scripts/validate-state.sh` — 2 hops up reaches the repo root.
- Source store: `agent-system/extensions/core/scripts/validate-state.sh` — 2 hops up reaches only
  `agent-system/extensions`, not the repo root (4 hops would be needed).

A single `levels` argument therefore cannot be correct for both locations this script is
documented to run from unmodified — the same failure mode that silently broke
`test-verify-deploy-context-budget.sh`'s gate. This is a second, independent confirmation of the
Adjacent Worked Precedent's conclusion, found by reading `common_repo_root()`'s own
implementation and `validate-state.sh`'s own two real deploy paths, not merely by citing the
precedent.

### The chosen remedy is already proven, in this exact file family

`scripts/tests/test-validate-state.sh:16-23` resolves its own `REPO_ROOT` with:
```bash
REPO_ROOT="$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
fi
```
— git-toplevel-of-`SCRIPT_DIR` first (depth-independent, exactly the "upward marker discovery"
technique the Adjacent Worked Precedent recommends, with `.git` as the marker), fixed-hop only as
a fallback when `SCRIPT_DIR` is not inside a git work tree at all. This is the right-shaped
solution for `validate-state.sh`'s own default, in the same file family, already carrying
in-repo precedent and already passing today for this test suite from both deploy locations.

### Candidate-fix evaluation

1. **Git toplevel of the CWD.** Rejected. This still anchors the default to wherever the
   invoking shell happens to be standing, which is the exact mechanism that produced the Observed
   Damage (CWD in `Verification`, script loaded from the `nvim` deploy). Normalizing the CWD-based
   default to a repo root (rather than an arbitrary CWD subdirectory) is strictly better than
   today's raw bare-relative path, but it does not change *which* repository gets validated in
   the cross-repo case — it would still have silently validated `Verification`, just more
   robustly if the agent's CWD had been a subdirectory of `Verification` rather than its root.
2. **Git toplevel of the script's own location (`SCRIPT_DIR`), via upward discovery — chosen.**
   Anchoring to `git -C "$SCRIPT_DIR" rev-parse --show-toplevel` (not `common_repo_root`'s
   fixed-hop arithmetic) resolves to whichever repository's deploy or source-store copy is
   actually running, independent of the invoking shell's CWD and independent of which of the two
   known layouts is in play. Applied to the Observed Damage scenario: the script loaded from the
   `nvim` deploy would default to `nvim`'s own `specs/state.json`, regardless of the dispatched
   agent's drifted CWD — exactly the "intended repository" Acceptance #1 asks for, and consistent
   with the header's own stated design principle that this script's identity is tied to where its
   own file lives (already the basis for every other sibling-library candidate search in this
   file: `VOCAB_LIB_CANDIDATES`, `FSO_LIB_CANDIDATES`, `FIX_STATE_WRITE_CANDIDATES`).
3. **Refuse when CWD-derived and SCRIPT_DIR-derived candidates disagree.** Not needed as the
   primary mechanism — folded in only as the residual fallback for the case `SCRIPT_DIR` is not
   inside a git work tree at all (exit 2, naming the probed `SCRIPT_DIR`), mirroring
   `test-validate-state.sh`'s own two-tier resolution. Treating disagreement itself as an error
   would needlessly break the common, benign case of running the deployed script while sitting in
   an unrelated directory for an unrelated reason (e.g. a developer's shell CWD in `$HOME`) —
   candidate 2 already answers that case correctly without a refusal.

**Recommendation: implement candidate 2 (git-toplevel-of-`SCRIPT_DIR` discovery), with
candidate 3's refusal reserved for the true not-a-git-worktree edge case.** Do not extend
`common_repo_root()` to add a marker-based mode as part of this task — that function lives under
`scripts/lib/`, which task 270 declares wholesale in its `file_scope`; broadening it here would
create an avoidable serializing edge for no benefit this task needs (the fix needed is a single
inline `git -C ... rev-parse --show-toplevel` call, matching the pattern this very script already
uses elsewhere for `--fix`'s candidate resolution). This is recorded as a follow-up opportunity
below, not an in-scope deliverable.

### Banner / absolute-path requirement (Acceptance #2)

Once `STATE_FILE` is resolved (whether from the new default or from an explicit argument), it
should be canonicalized to an absolute path *before* the banner at line 445, not just before the
`--deep` block's `state_dir` computation at line 799. The existing `-f` existence check (lines
280-283) should still run against whatever `STATE_FILE` holds at that point; canonicalization
should happen immediately after a successful existence check (so a missing-file error still names
the path as originally given/resolved, matching today's error message shape) and before the
banner echoes it. This keeps the change minimal: one `cd "$(dirname ...)" && pwd` call sited
right after the existing `-f` check, reusing the exact idiom already present at line 799 rather
than introducing a new canonicalization style.

### Regression surface (Acceptance #3)

The explicit-argument path is untouched by the recommended fix: `STATE_FILE` assignment at the
argument-parser's default case (line 231) is unmodified; the new git-toplevel resolution only
executes inside the existing `if [[ -z "$STATE_FILE" ]]` branch. The only shared code the fix
touches outside that branch is the post-check canonicalization step described above, which is a
pure absolute-path normalization (`cd dirname && pwd`) that does not change which file is
selected for an already-absolute or already-valid relative explicit argument — `dirname`/`pwd`
round-trips a valid path losslessly. The three argument-relative sibling-resolution sites (lines
799-800, 832, 311-318) read `STATE_FILE` (or its dirname) after this normalization and are
unaffected either way, since they already independently re-derive an absolute `state_dir` via the
identical `cd && pwd` idiom.

### Test-suite integration point (Acceptance #4)

`tests/test-validate-state.sh` already establishes the exact `VALIDATOR`-resolution idiom needed
to add a cross-repo case (candidate-list resolution against both deploy locations, `WORKDIR`
fixtures via `mktemp -d`, `pass`/`fail`/`info` helpers, `rm -rf` cleanup trap). A new case should:
1. Create a *second* temp directory (`OTHER_CWD`) with its own `specs/state.json` fixture that is
   deliberately distinguishable from (and, to force a crisp failure signal, deliberately invalid
   relative to) whatever `$VALIDATOR`'s own repo holds — e.g. malformed JSON, so that if the
   defect causes `$OTHER_CWD`'s file to be read, the run fails in a specific, recognizable way
   (a JSON-parse failure) rather than coincidentally agreeing with the correct answer.
2. `cd "$OTHER_CWD"` and invoke `bash "$VALIDATOR"` with **no** positional argument.
3. Assert, pre-fix (to confirm the case is not vacuous): the run reads `$OTHER_CWD`'s fixture (the
   bug), observable as the specific malformed-JSON failure. This is the step that proves the case
   fails against the pre-fix script, satisfying Acceptance #4's non-vacuity requirement.
4. Assert, post-fix: the run does **not** read `$OTHER_CWD`'s fixture (no malformed-JSON failure)
   and the "Validating state file:" banner names an absolute path that is NOT under `$OTHER_CWD`.
This isolates the assertion from the live, ever-changing `specs/state.json` of whichever repo the
test suite itself runs in — the test should not need to assert a specific exit code for that live
file, only that it was not contaminated by `$OTHER_CWD`'s content. This dual-repo construction
(separate temp CWD vs. the real `$VALIDATOR` location) is the most direct way to reproduce the
cross-repo invocation shape without needing to construct a second, fully-faked deploy tree.

### External Resources

None consulted — this is a pure codebase-internal shell-scripting defect with an already-present,
in-repo precedent for the correct technique; no external documentation applies.

## Sibling Survey (Part b — report only, no remediation here)

| Site | Verdict | Rationale |
|---|---|---|
| `scripts/command-gate-in.sh:65` (`specs/state.json` read, no override, no `cd`) | **Same defect family** | Sourced via `source .claude/scripts/command-gate-in.sh ...` from a command `.md` bash block with no CWD-pinning of its own; relies entirely on the ambient "CWD = repo root" convention, with no fallback or diagnostic. A dispatched-agent CWD drift of the kind that caused the Observed Damage would silently read/look up the wrong repo's task table here too. Needs its own task. |
| `scripts/command-gate-out.sh:63,87` (`state_file="specs/state.json"`, `task_dir="specs/${padded_num}_${project_name}"`) | **Same defect family** | Same rationale as `command-gate-in.sh` — invoked as `bash .claude/scripts/command-gate-out.sh ...`, no `cd` of its own, no CWD-pinning, and this one also *writes* downstream (via `skill_validate_task_artifacts` and status corrections), making a silent wrong-repo read arguably higher-impact than a read-only validator. Needs its own task. |
| `scripts/git-snapshot.sh:248,332,337` (`specs/state.json` existence/read in `resolve_task_dir` and the out-of-scope guard) | **Partially by design, same latent risk** | `git-snapshot.sh`'s stated job is to snapshot *the working tree the caller is standing in*, so CWD-relative resolution is semantically closer to "by design" than `validate-state.sh`'s case (there is no `STATE_FILE`-style override argument whose default is wrong — there is no override at all for this use). It already prints `(cwd: $(pwd))` in every failure message on this path (lines 250, 333) — "the right instinct" the dispatch itself credits. The remaining risk is the dangerous one: if the wrong repo's `specs/state.json` exists AND happens to have an `implementing`-status task, `resolve_task_dir` would silently infer and operate against the wrong repo's task directory rather than failing loudly. Recommend only a cheap diagnostic addition (echo the resolved repo/CWD in the success path too, not just failure messages) in a follow-up task — not a structural resolution-strategy change, since CWD-relative is the semantically correct default here. |
| `scripts/command-gate-in.sh:65` / `scripts/orchestrate-build-dispatch.sh:246` (`specs/state.json` inside `if [ "$phase" = "plan" ]`) | **Not the same defect — confirmed by design** | `orchestrate-build-dispatch.sh:193` runs `cd "$SKILL_REPO_ROOT"` near the top of the script, *before* any bare `specs/state.json` reference is reached. `SKILL_REPO_ROOT` is supplied by the caller (not derived via a fixed hop count inside this file), so by the time line 246 executes, CWD has already been deliberately pinned to the correct repo root. This is CWD-relative-after-pinning, not an unguarded ambient-CWD dependency — excluded from the "same defect" bucket. |
| `scripts/init-specs.sh:101-125` | **By design — confirmed, excluded** | Bootstraps `specs/`, `specs/archive/state.json`, and `specs/TODO.md` into whatever repository the caller is standing in; that is its entire purpose (there is no "other repo" to accidentally target — the CWD repo is unconditionally the correct target for a bootstrap operation). Read in full; no override argument exists or should exist. |

**Overall recommendation for the survey**: file one follow-up task covering
`command-gate-in.sh`/`command-gate-out.sh` (same defect family, needs a real fix — likely the
same `git -C "$SCRIPT_DIR" rev-parse --show-toplevel`-anchoring technique, or an explicit
`cd` to a caller-supplied repo root mirroring `orchestrate-build-dispatch.sh`'s own pattern) and,
separately and lower-priority, a diagnostic-only improvement to `git-snapshot.sh`'s success-path
logging. Both land under `scripts/`, which task 270 already declares wholesale in its
`file_scope` — sequencing either behind or alongside 270 avoids an avoidable serializing edge,
matching the same reasoning this task's own dispatch already applied when declaring dependencies
on 271/279.

## Decisions

- **Chosen fix mechanism**: git-toplevel-of-`SCRIPT_DIR` upward discovery (dispatch candidate 2,
  implemented without `common_repo_root()`), with a refuse-loudly fallback (dispatch candidate
  3) reserved for the non-git-worktree edge case only. Candidate 1 (CWD-anchored, even if
  git-toplevel-normalized) is rejected because it does not change the outcome of the Observed
  Damage scenario.
- **`common_repo_root()` is not modified and not used for this fix.** Verified directly (not
  merely cited) that its fixed-hop-count contract gives two different, both-wrong-for-one-layout
  answers across this script's two real deploy locations. A marker-based mode for that shared
  function is a plausible follow-up but is explicitly deferred — it lives under
  `scripts/lib/`, declared wholesale by task 270, and this task's narrow fix does not need it (an
  inline `git -C ... rev-parse --show-toplevel` call, matching this file's own existing idiom for
  `--fix`'s writer-candidate search, is sufficient and simpler).
- **Banner canonicalization is sited once, immediately after the existing `-f` existence check**,
  reusing the `cd "$(dirname ...)" && pwd` idiom already present at line 799, rather than
  introducing a second canonicalization style.
- **This task does not touch `KNOWN_ENTRY_FIELDS` or `context/schemas/state-schema.json`** —
  confirmed no overlap with task 279's or task 271's in-flight work on those fields; the
  file-scope collision with both tasks is on `validate-state.sh`/`test-validate-state.sh` only,
  in non-overlapping regions (lines 277-283/445 and a new test case, vs. the
  `KNOWN_ENTRY_FIELDS` array elsewhere in the same files).
- **Sibling remediation is out of scope here**; the survey table above is the complete, verified
  deliverable for Acceptance #6, with a recommended follow-up task named rather than filed.

## Risks & Mitigations

- **Risk**: the new git-toplevel resolution could behave unexpectedly if `SCRIPT_DIR` itself is
  symlinked or the deploy tree is checked out without `.git` present (e.g. a tarball export).
  **Mitigation**: `test-validate-state.sh`'s own `REPO_ROOT` resolution already handles exactly
  this by falling back to a fixed-hop guess when `git rev-parse --show-toplevel` fails; the new
  default-resolution code should use the same two-tier shape, and the no-worktree case should
  additionally refuse loudly per candidate 3 rather than silently falling back, since a silent
  fixed-hop fallback for the *default itself* would reopen exactly the layout-dependent fragility
  this fix exists to close. (The existing `test-validate-state.sh` fallback is acceptable for a
  *test harness* resolving its own location once at startup; it is not acceptable for
  `validate-state.sh`'s own default, which is the thing under repair.)
- **Risk**: canonicalizing `STATE_FILE` to an absolute path immediately after the `-f` check could
  change existing error-message text for the missing-file case if any caller parses that message.
  **Mitigation**: grepped all callers (`verify-deploy.sh`, `task.md`, `test-init-specs.sh`,
  `test-validate-state.sh`) — none parses the "File not found" message text; all three
  production callers only check the exit code or grep unrelated lines (`file_scope`). The planned
  canonicalization point (after the existence check, before the banner) does not alter that
  message at all, since it fires only on the success path.
- **Risk**: the new cross-repo test case could be flaky if it depends on the live repo's own
  `specs/state.json` validating cleanly. **Mitigation**: design the assertion (see Findings,
  Test-suite integration point) around non-contamination (banner path, absence of the
  `$OTHER_CWD`-specific failure signature) rather than a hard-coded exit-0 expectation against the
  live file, exactly to avoid this coupling.

## Context Extension Recommendations

- **Topic**: path-resolution idioms for scripts that run unmodified from both the deployed tree
  and the source store.
- **Gap**: this codebase has at least three distinct, undocumented resolution idioms in live use
  — (a) CWD-relative by design (`init-specs.sh`, `git-snapshot.sh`), (b) `common_repo_root()`'s
  caller-supplied fixed hop count (correct only when every caller's `SCRIPT_DIR` sits at the same
  depth below the root in both layouts), and (c) git-toplevel-of-`SCRIPT_DIR` upward discovery
  (`test-validate-state.sh`'s `REPO_ROOT`, and now this task's fix). Nothing under
  `context/patterns/` names when each is appropriate or warns that (b) silently gives a
  layout-dependent wrong answer for a `scripts/` caller whose two deploy depths differ (exactly
  this script's situation, and the root cause of the already-fixed
  `test-verify-deploy-context-budget.sh` incident this dispatch cites).
- **Recommendation**: a new `context/patterns/script-location-resolution-idioms.md` (or an
  addition to `context/standards/source-store-deploy-boundary-narrative.md`) naming the three
  idioms, their respective correctness conditions, and the specific `common_repo_root()`
  fixed-hop pitfall for any `scripts/` caller whose source-store and deployed locations differ in
  depth. Not created in this pass (meta/documentation addition, not part of this task's
  acceptance criteria); recommended as a follow-up, possibly paired with the `common_repo_root()`
  marker-mode follow-up named in Decisions above.

## Appendix

- Files read in full or substantially: `agent-system/extensions/core/scripts/validate-state.sh`
  (header, argument parser, default-resolution block, `--fix` candidate search, banner,
  `--deep` block's `state_dir`/sibling resolution), `agent-system/extensions/core/scripts/lib/common.sh`
  (`common_repo_root` implementation and consumer-migration comment block),
  `agent-system/extensions/core/scripts/tests/test-validate-state.sh` (header, `REPO_ROOT`/
  `VALIDATOR` resolution, first positive-fixture case), `scripts/command-gate-in.sh`,
  `scripts/command-gate-out.sh`, `scripts/git-snapshot.sh` (`resolve_task_dir` and the out-of-scope
  guard), `scripts/orchestrate-build-dispatch.sh` (the `cd "$SKILL_REPO_ROOT"` line and the
  `phase = "plan"` block), `scripts/init-specs.sh` (bootstrap steps), `scripts/verify-deploy.sh`
  (gate 10).
- Confirmed identical content between `.claude/scripts/validate-state.sh` and
  `agent-system/extensions/core/scripts/validate-state.sh` (`diff` returned no output) — the
  deploy is current for this file as of this research pass.
- Grep commands used: `grep -n "specs/state.json" <file>` per sibling; `grep -rn
  "validate-state.sh" --include=*.sh --include=*.md` across both `agent-system/extensions/core`
  and `.claude` to enumerate every caller and confirm none exercises the omitted-argument
  default; `grep -n "common_repo_root\|PROJECT_ROOT" validate-state.sh` to confirm the script
  deliberately avoids that helper today.
