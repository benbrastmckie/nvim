# Research Report: Task #448

**Task**: 448 - Contain deliberate-break source mutations
**Started**: 2026-11-09
**Completed**: 2026-11-09
**Effort**: medium
**Dependencies**: 328 (must land first — see Risks & Mitigations)
**Sources/Inputs**: Codebase exploration (agent-system/extensions/core/scripts/tests/,
scripts/lint/, scripts/verify-deploy.sh, scripts/gate-registry.data)
**Artifacts**: specs/448_contain_deliberate_break_source_mutations/reports/01_contain-deliberate-break-mutations.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The one unsafe mutation site is `test-orchestrate-cycle-postflight.sh`'s regression-anchor
  check (around lines 2658-2695). It mutates `$CORE_DIR/orchestrate-cycle-postflight.sh` — the
  real, shared source-store file — in place, via `sed -i`, BEFORE calling `setup_sandbox()`.
  `setup_sandbox()` then copies the already-mutated file into `$WORKDIR`, and `run_sut` executes
  that `$WORKDIR` copy (`$SUT="$WORKDIR/.claude/scripts/orchestrate-cycle-postflight.sh"`), never
  `$CORE_DIR` directly.
- That execution order is the root defect, and it is fixable by a pure reorder, with **no new
  test-harness infrastructure required**: call `setup_sandbox()` FIRST (producing a clean copy at
  `$SUT`), then apply the identical `sed -i` mutation to `$SUT` instead of `$ANCHOR_SRC`
  (`$CORE_DIR`'s file). This closes hole (2) (the shared-tree exposure window) outright — the
  real source-store file is never written, so there is nothing for a concurrent reader to
  observe — and it makes hole (1) (EXIT-trap unreliability) moot, since there is nothing to
  restore: the mutated `$WORKDIR` copy is naturally discarded by the next `setup_sandbox()` call
  or the suite's own `cleanup()`.
- `scripts/lib/test-harness-lib.sh`, named in the dispatch as the place to check for
  `setup_sandbox`'s source resolution, **does not exist**. `setup_sandbox` is defined
  independently inside each test file (confirmed in at least 34 files); there is no shared
  harness library to extend with an "override source directory" feature. This rules out
  option (1) as originally framed (a generic harness feature) in favor of the surgical,
  single-file reorder above, which achieves the same outcome with zero new abstraction.
- Two existing precedents in the same test corpus already use exactly the safe pattern (mutate a
  private/scratch copy, never the real source-store file): `test-git-commit-scoped.sh`'s X1/X2
  inversion probes, and `test-lint-deploy-caller-wrap.sh`'s self-test. Both are explicitly
  commented as deliberately avoiding the real source file. The recommended fix brings the one
  outlier in line with the codebase's own established convention — it is not a novel technique.
- A repo-wide audit (two independently-shaped search patterns, see Findings) found **no other**
  source-store-mutating test site under `agent-system/extensions/core/scripts/tests/` — the
  dispatch's own audit claim is confirmed, not merely accepted.
- A mechanical detector (option 3) is recommended as a paired defense-in-depth measure, not a
  substitute for the reorder fix. An anchored-start regex, `^[[:space:]]*while false[[:space:]]*&&`,
  correctly distinguishes a real code-level guard from the test file's own `sed` replacement-string
  text containing that phrase — verified directly against the live corpus (see Findings), not
  merely asserted.

## Context & Scope

This task is prevention-only: the cited incident (an uncommitted `while false &&` mutation left in
`orchestrate-cycle-postflight.sh`, degrading `cycle_modified_files`/`invocation_modified_files`
accumulation in a later, unrelated session) was already reverted and is confirmed absent from the
source store. The research scope is: (a) re-derive the mechanics of the one known deliberate-break
site, (b) determine the minimal containment that closes the shared-working-tree exposure window
without weakening the regression-anchor's own guarantee, (c) determine a non-blocking mechanical
detector that can distinguish a real anti-pattern occurrence from the test file's own legitimate
`sed` pattern text, (d) audit the rest of `scripts/tests/` for any other site doing the same thing,
and (e) locate the conventions for registering a new `scripts/lint/*.sh` check into the gate
framework.

## Findings

### Codebase Patterns

**The unsafe site, re-derived.** `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh`:
- Line 24: `CORE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"` — the real, live source-store directory
  (`agent-system/extensions/core/scripts`), not a sandbox.
- Line 125: `SUT="$WORKDIR/.claude/scripts/orchestrate-cycle-postflight.sh"` — the sandboxed copy
  that is actually executed (`run_sut` at line 161: `bash "$SUT" ...`).
- Lines 2658-2695 (regression-anchor check): sets `ANCHOR_SRC="$CORE_DIR/orchestrate-cycle-postflight.sh"`,
  backs it up to `${ANCHOR_SRC}.anchor-bak`, installs `trap 'anchor_restore; cleanup' EXIT`,
  `sed -i`s the real `$CORE_DIR` file to neuter the `while IFS= read -r f; do` loop, **then** calls
  `setup_sandbox()` (which copies the now-mutated file from `$CORE_DIR` into `$WORKDIR`), runs the
  fixture, then calls `anchor_restore` and resets the trap.
- This means the shared, real source-store file is live-mutated for the entire window between the
  `sed -i` and `anchor_restore` — including the `setup_sandbox()` call, fixture setup, and
  `run_sut` itself. Any concurrently running session reading `orchestrate-cycle-postflight.sh`
  during that window observes the broken file.

**`setup_sandbox` has no shared implementation.** The dispatch names `scripts/lib/test-harness-lib.sh`
as the place to check for where `setup_sandbox`'s copy source is resolved. That file does not
exist in this repository:
```
$ find agent-system/extensions/core/scripts/lib -iname "*test*" -o -iname "*harness*"
(no output)
```
`setup_sandbox` is instead defined independently inside each test file that needs one — confirmed
in `test-orchestrate-recover-message-findings.sh`, `test-orchestrate-predispatch-review.sh`,
`test-handoff-dispatch-identity.sh`, `test-orchestrate-batch-gate.sh`, and
`test-orchestrate-cycle-postflight.sh` itself (via `grep -rn "setup_sandbox()" ...`), plus many
more test files that use the same `cp "$CORE_DIR/$f" "$WORKDIR/..."` shape without naming the
function `setup_sandbox`. There is no central place to add a generic "override the copy source"
feature; any fix has to be local to the one call site that actually mutates `$CORE_DIR`.

**The fix is a pure reorder, not a new feature.** Because `run_sut` always executes `$SUT`
(`$WORKDIR/.claude/scripts/orchestrate-cycle-postflight.sh`), and `setup_sandbox()` is what
populates `$SUT` from `$CORE_DIR`, the anchor check can be restructured as: call `setup_sandbox()`
first (clean copy lands at `$SUT`), THEN apply the identical `sed -i` mutation to `$SUT` directly,
THEN `run_sut`. No backup, no trap, no restore — `$CORE_DIR` is never written, so there is nothing
to protect against a SIGKILL/OOM/interrupt, and the mutated `$WORKDIR` copy is naturally wiped the
next time `setup_sandbox()` runs (`rm -rf "$WORKDIR"` at its top) or when the suite's own
`cleanup()` fires at EXIT. The anchor's own guarantee is preserved exactly: the mutated text is
byte-identical, only its target path changes, so the fixture still goes RED when the block is
re-gated.

**Two existing precedents already use this safe pattern.** Confirmed by direct reading, not
inference:
- `test-git-commit-scoped.sh` (X1/X2 inversion probes, ~lines 629-660 and ~812-825): copies
  `$SRC_SCRIPTS_DIR/git-commit-scoped.sh` into a `mktemp -d` scratch directory, `sed -i`s the
  *scratch copy*, then copies the mutated scratch file into a throwaway sandbox repo's
  `.claude/scripts/` — never touching the real source file. Explicitly commented: "Temporarily
  inverts the sense ... in a scratch COPY of the script (never the suite's own copies)."
- `test-lint-deploy-caller-wrap.sh` (self-test, ~lines 243-258): copies
  `$CORE_DIR/orchestrate-cycle-plan.sh` into `$(mktemp -d)`, mutates the copy, runs the check
  against it. Explicitly commented: "Restored immediately after; never touches the real
  source-store file."

These confirm the safe technique is already idiomatic in this codebase; the recommended fix for
task 448 brings the one outlier in line with it rather than inventing something new.

**Audit: no other source-store-mutating test site exists.** Two independently-shaped searches,
both run against `agent-system/extensions/core/scripts/tests/*.sh`:
1. Direct write-pattern search for any `sed -i`, redirection, or `cp` whose *target* is `$CORE_DIR`
   or `$SRC_DIR` (the two variable names used for the real source directory across the corpus) —
   zero hits other than the flagged site.
2. A second pass enumerating every file that defines a "real source dir" variable via
   `"$(cd "$SCRIPT_DIR/.." && pwd)"` (34 files), then grepping each for `sed -i`/`cp`/redirection
   targeting that file's own variable — confirms every other such file only ever *reads from*
   `$CORE_DIR`/`$SRC_DIR` (copying files INTO `$WORKDIR`), never writes into it. The only outlier
   is `test-orchestrate-cycle-postflight.sh`'s `ANCHOR_SRC` mutation.
3. `test-validate-no-task-references.sh`'s "regression anchor" (lines 188-200, named by the
   dispatch as already-confirmed-safe) was independently re-read: it operates entirely on
   in-memory fixture strings passed to `assert_silent`/`assert_triggers` helper functions — no
   file mutation of any kind, let alone a source-store file. Confirmed safe, not merely accepted
   on the dispatch's word.
4. `grep -rln "ANCHOR_SRC\|_SRC=\"\$CORE_DIR" agent-system/extensions/*/scripts/tests/*.sh` across
   ALL extensions (not just core) returns only `test-orchestrate-cycle-postflight.sh` — the
   pattern does not recur in lean/nix/neovim/email/memory/literature/approvals test suites either.

This enumeration used two differently-shaped search strategies (direct-target grep, and
variable-enumeration-then-grep) plus a manual re-read of the one named comparison case, and found
the same single result by all three routes.

### External Resources

Not applicable — this is a pure codebase-internal containment question; no external library or
documentation bears on it.

**Lint family and gate-registration conventions** (for the detector, option 3):
- `scripts/lint/lint-scoped-commit-boundary.sh` is a good structural model: a header stating the
  anti-pattern, a stated KNOWN LIMITATION section (regex-only, line-oriented; not a proof of
  absence), and a two-layer detection model (broad candidate pattern, then an exemption layer).
- Gates are registered in TWO places that must agree:
  1. `scripts/verify-deploy.sh`: a `gateN_run()` function following the exact template seen at
     `gate27_run` (lines 2050-2070): `if gate_selected N; then say "N. ..."; CURRENT_GATE="gateN";
     if [ ! -d "$TARGET/agent-system/extensions" ]; then say "  [SKIP] ... not the source store";
     elif [ ! -f ".../lint-X.sh" ]; then fail "lint-X.sh not found in source store"; else ...
     run with --verbose, pass()/fail(), populate FINDINGS_LIST via
     verify_deploy_extract_verdict_lines ...; fi; fi`. The `[ ! -d
     "$TARGET/agent-system/extensions" ]` branch is exactly the "scoped to the SOURCE STORE"
     mechanism the hard constraints require — it is the established idiom, not something to
     invent.
  2. `scripts/gate-registry.data`: one new TAB-separated row (9 fields: id, name, invoke,
     dependencies, requires_source_store, timeout_s, cost_class, serialized, input_corpus).
     `scripts/lint/lint-gate-registry.sh` structurally validates this file (contiguous ids,
     9-field rows, valid `cost_class`, no dependency cycles, etc.) — a new row must satisfy all of
     these or the registry lint itself fails.
- Current highest-numbered gate is 27 (`Subject-resolution declaration lint`); a new detector
  would be gate 28.
- `scripts/tests/run-all.sh` auto-discovers suite files (no manual registration list found for
  test files); a new `test-lint-*.sh` file is picked up automatically.

**Self-exclusion regex, verified against the live corpus.** The hard constraint requires the
detector to recognize a real `while false &&` guard while not firing on the test file's own `sed`
replacement-string text (which legitimately contains that phrase as a quoted argument, never as
code). Verified directly:
```
$ grep -n "while false" .../test-orchestrate-cycle-postflight.sh
2666:  sed -i "s/^    while IFS= read -r f; do\$/    while false \&\& IFS= read -r f; do/" "$ANCHOR_SRC"

$ grep -nE '^[[:space:]]*while false[[:space:]]*&&' .../test-orchestrate-cycle-postflight.sh
(no output)

$ grep -rnE '^[[:space:]]*while false[[:space:]]*&&' agent-system/extensions/core --include="*.sh" | grep -v "/tests/"
(no output)
```
Line 2666's text is `  sed -i "..."`, not a line that itself *begins* (after whitespace) with
`while false &&` — the literal phrase appears only as a substring inside a quoted sed argument,
never at the start of a bash statement. An anchored-start regex therefore distinguishes the two
cases correctly, without a blanket path exclusion (which would also blind the detector to a real
mutation planted inside a test file). The same regex currently matches nothing anywhere else in
the source store (a true, verified negative, not an assumed one) — so a detector built on this
regex can ship with zero known false positives today.

## Recommendations

1. **Primary containment — reorder, don't add infrastructure.** In the regression-anchor check
   (`test-orchestrate-cycle-postflight.sh`, ~lines 2658-2695): call `setup_sandbox()` before
   mutating anything, then `sed -i` the mutation onto `$SUT`
   (`$WORKDIR/.claude/scripts/orchestrate-cycle-postflight.sh`) instead of `$ANCHOR_SRC`
   (`$CORE_DIR/orchestrate-cycle-postflight.sh`). Drop the `cp "$ANCHOR_SRC"
   "${ANCHOR_SRC}.anchor-bak"` backup, the `anchor_restore` function, and the
   `trap 'anchor_restore; cleanup' EXIT` — all become unnecessary once `$CORE_DIR` is never
   written. Keep the `grep -qF "$anchor_marker"` presence check, run against `$SUT` instead of
   `$ANCHOR_SRC` (functionally identical immediately after `setup_sandbox()`, since `$SUT` is a
   direct copy). This is option (1) from the dispatch's candidate list, achieved without the
   generic "override source directory" feature the dispatch speculated about — that feature's
   natural home (`scripts/lib/test-harness-lib.sh`) does not exist, and building one would be
   over-engineering for a defect confined to one call site in one file.
2. **Harden the invariant inline, in the same suite.** Add two assertions immediately after the
   restructured anchor check (these are the dispatch's own VERIFY bullets, and they become
   trivially satisfiable once `$CORE_DIR` is never written): (a) `$CORE_DIR/orchestrate-cycle-postflight.sh`
   is byte-identical before and after the suite's full run (e.g. a checksum captured near the top
   of the file and compared at the very end); (b) no `*.anchor-bak` file exists anywhere under
   `$CORE_DIR` after the run. Both assertions should fail loudly (not just silently pass) if a
   future edit reintroduces a direct `$CORE_DIR` write.
3. **Pair with a mechanical detector (option 3), scoped to the whole source store.** Add
   `scripts/lint/lint-deliberate-break-residue.sh` (naming is a recommendation, not a hard
   requirement — pick a name that does not collide with the unrelated existing
   `lint-anchor-pointer-collapse.sh`). Two independent checks, both advisory/gate-level:
   - **A**: any line under `agent-system/extensions/core/**/*.sh` matching
     `^[[:space:]]*while false[[:space:]]*&&` (anchored-start; verified above to correctly exclude
     the test file's own `sed` replacement text without a path exclusion).
   - **B**: `find agent-system/extensions/core -name "*.anchor-bak"` — any match is a finding (a
     leftover backup implies either a crash mid-run or a bug in a restore step).
   Register as gate 28 in `scripts/verify-deploy.sh` (a `gate28_run()` function following
   `gate27_run`'s exact template, including the `[ ! -d "$TARGET/agent-system/extensions" ]`
   SKIP-if-not-source-store branch) and as a new row in `scripts/gate-registry.data`
   (`requires_source_store=true`, `cost_class=free`, `serialized=false`). This check is advisory
   by construction — it runs as part of an explicit `verify-deploy.sh` gate pass, never as a
   PreToolUse write-time block — satisfying the hard constraint that the deliberate-break
   technique must remain usable mid-run.
4. **Give the detector its own test suite**, per the dispatch's VERIFY requirement: a new
   `scripts/tests/test-lint-deliberate-break-residue.sh` (auto-discovered by `run-all.sh`, no
   manual registration needed) pinning: (a) it fires on a planted `while false &&` guard placed
   in a **scratch copy** (never the real source tree — following the same safe-copy convention
   recommended for fix #1 itself); (b) it fires on a planted leftover `*.anchor-bak` file in a
   scratch copy; (c) it does NOT fire against the real, current
   `test-orchestrate-cycle-postflight.sh` (the negative control for the self-exclusion design).
5. **No change needed to `test-validate-no-task-references.sh`** — independently re-read and
   confirmed to use only in-memory fixture strings, never a source-store file mutation. Record
   this as "audited, no action" rather than silently omitting it.

## Decisions

- **Option (1) is accepted, but not as the dispatch's own candidate framing (a generic
  test-harness-lib override-source feature).** That framing presupposed a shared harness library
  that does not exist in this repository. The equivalent outcome — the real source-store file is
  never written — is achieved instead by reordering the one call site's existing operations
  (`setup_sandbox()` before the mutation, mutate `$SUT` not `$CORE_DIR`). This still closes hole
  (2) outright, which is what the dispatch requires of whichever option is chosen to close it; it
  simply does so without new infrastructure, because the existing per-test `setup_sandbox`/`$SUT`
  shape already provides everything needed.
- **Option (2) (serialize the window via a repo-level lock) is rejected as unnecessary.** Once
  option (1)'s reorder removes the write to `$CORE_DIR` entirely, there is no window left to
  serialize — a lock would add suite-runtime coupling (exactly the cost the dispatch itself flags)
  to close a hole that the reorder already closes for free.
- **Option (3) (mechanical detector) is accepted, as a paired defense-in-depth measure, not a
  substitute for (1).** It guards against a *future* regression of the same anti-pattern (in this
  file or any other), which a one-time reorder fix cannot do by itself.
- **Detector scope is the whole source store (`agent-system/extensions/core/**/*.sh`), not just
  `orchestrate-cycle-postflight.sh`.** A `while false &&` guard is never legitimate in ANY
  production or test script, so there is no reason to narrow the pattern to the one file the
  cited incident happened to hit.
- **Self-exclusion is solved by an anchored-start regex, not a path exclusion.** Verified directly
  against the live corpus (see Findings) that this correctly separates the test file's own
  `sed` replacement-string occurrence from a genuine code-level guard, satisfying the hard
  constraint's explicit rejection of a blanket path exclusion.

## Risks & Mitigations

- **Risk**: task 328 (a net-deletion corpus consolidation over `scripts/tests/`, `scripts/lint/`,
  and `context/standards/shell-script-testing.md`, naming
  `test-orchestrate-cycle-postflight.sh` by name) is a declared territory edge that must land
  first. If this task's plan/implementation lands before 328, the files 328 touches would need to
  be re-touched by 328's own consolidation pass immediately after. **Mitigation**: sequencing is
  already recorded as a dependency in this task's description; the implementation plan should
  re-confirm 328's status before dispatching and defer if 328 has not yet landed.
- **Risk**: the reorder fix changes the *shape* of the regression-anchor block (removing the
  trap/backup/restore machinery). A careless edit could accidentally remove the
  `grep -qF "$anchor_marker"` presence guard itself, silently turning the anchor check into a
  vacuous pass. **Mitigation**: keep the presence-check branch's `else` (failure) arm exactly as
  it is today; only change what the `sed -i` targets and remove the now-dead backup/trap lines.
- **Risk**: a future developer reintroduces the unsafe `$CORE_DIR`-mutation pattern in a new test
  file, reasoning by analogy from the (now-fixed) anchor check without noticing it was fixed for a
  reason. **Mitigation**: this is exactly what recommendation 3 (the detector) is for; its header
  comment should state the incident and the reasoning plainly, mirroring
  `lint-scoped-commit-boundary.sh`'s own header style.
- **Risk**: the detector's regex is line-oriented and cannot catch an indirected mutation (e.g. a
  variable holding the pattern text, assembled across multiple lines). **Mitigation**: state this
  limitation explicitly in the new lint's header (following the established
  `lint-scoped-commit-boundary.sh` KNOWN LIMITATION convention) rather than overclaiming
  completeness; a line-oriented regex guard against regression of a known, named anti-pattern is
  the lint's actual job, not a proof of absence of all possible source mutations.

## Context Extension Recommendations

- **Topic**: shell-script-testing.md's treatment of source-store mutation during a test run.
- **Gap**: `context/standards/shell-script-testing.md` (the standards file task 328 is also
  consolidating) does not currently appear to state a rule against mutating the real source-store
  file from within a test fixture, even temporarily with a backup/restore pair. This task's own
  finding (a safe pattern — mutate a scratch/sandbox copy — already used in at least two other
  test files) would be a natural addition once 328's consolidation pass has landed and the
  standard's structure is settled.
- **Recommendation**: after task 328 lands, add a short rule to the consolidated testing standard
  naming the safe pattern explicitly (mutate a sandboxed or scratch copy, never
  `$CORE_DIR`/`$SRC_DIR` itself) so the convention this task restores is documented, not just
  re-derived ad hoc the next time someone needs a "deliberately break X, confirm red, then revert"
  fixture.

## Appendix

Search queries / commands used:
- `find agent-system/extensions/core/scripts/lib -iname "*test*" -o -iname "*harness*"` (confirmed
  `test-harness-lib.sh` does not exist)
- `grep -rln "setup_sandbox" agent-system/extensions/core/scripts/` and
  `grep -rn "setup_sandbox()" agent-system/extensions/core/scripts/`
- `grep -n "ANCHOR\|anchor" .../test-orchestrate-cycle-postflight.sh`
- `grep -n "^SUT=\|SUT=\"" .../test-orchestrate-cycle-postflight.sh`
- `grep -rn "regression.anchor\|regression anchor" agent-system/extensions/*/scripts/tests/*.sh`
- `grep -rl "sed -i" agent-system/extensions/*/scripts/tests/*.sh` plus per-file inspection,
  filtering out `$WORKDIR`-scoped targets
- `grep -rln 'SCRIPT_DIR/\.\." && pwd' agent-system/extensions/*/scripts/tests/*.sh` (34 files),
  then per-file targeted-write grep against each file's own real-source-dir variable
- `grep -rln "ANCHOR_SRC\|_SRC=\"\$CORE_DIR" agent-system/extensions/*/scripts/tests/*.sh` (across
  all extensions, not just core)
- `grep -n "while false" .../test-orchestrate-cycle-postflight.sh` vs.
  `grep -nE '^[[:space:]]*while false[[:space:]]*&&' .../test-orchestrate-cycle-postflight.sh` vs.
  `grep -rnE '^[[:space:]]*while false[[:space:]]*&&' agent-system/extensions/core --include="*.sh"`
- `find agent-system/extensions/core -name "*.anchor-bak"` (confirmed none present)
- `grep -n '^say "[0-9]' agent-system/extensions/core/scripts/verify-deploy.sh` (gate numbering,
  currently through 27)
- `tail -10 agent-system/extensions/core/scripts/gate-registry.data`,
  `head -20 agent-system/extensions/core/scripts/gate-registry.data` (registry row format)
- `grep -n "gate27_run()" -A 20 agent-system/extensions/core/scripts/verify-deploy.sh` (gate
  function template)

References:
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` (the unsafe
  site and its two safe-pattern siblings' techniques)
- `agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` (X1/X2 inversion-probe
  safe-copy precedent)
- `agent-system/extensions/core/scripts/tests/test-lint-deploy-caller-wrap.sh` (self-test safe-copy
  precedent)
- `agent-system/extensions/core/scripts/tests/test-validate-no-task-references.sh` (confirmed-safe
  comparison case)
- `agent-system/extensions/core/scripts/lint/lint-scoped-commit-boundary.sh` (structural model for
  the new detector)
- `agent-system/extensions/core/scripts/verify-deploy.sh` (gate registration template, `gate27_run`)
- `agent-system/extensions/core/scripts/gate-registry.data` and
  `agent-system/extensions/core/scripts/lint/lint-gate-registry.sh` (registry format and its own
  structural validation)
