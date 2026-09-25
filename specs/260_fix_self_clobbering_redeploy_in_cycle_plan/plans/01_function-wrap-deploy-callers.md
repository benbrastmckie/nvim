# Implementation Plan: Task #260

- **Task**: 260 - Fix self-clobbering redeploy in cycle-plan
- **Status**: [NOT STARTED]
- **Effort**: 7.25 hours
- **Dependencies**: None (the sibling redundant-verify-deploy-passes task depends on THIS one; land this first)
- **Research Inputs**: specs/260_fix_self_clobbering_redeploy_in_cycle_plan/reports/01_self-clobbering-redeploy-hazard.md
- **Artifacts**: plans/01_function-wrap-deploy-callers.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Close the mid-execution self-overwrite hazard by generalizing the mitigation `deploy-headless.sh`
already applies to itself (its `SELF-OVERWRITE HAZARD` header at lines 69-84: the entire executable
body lives inside one `main()` function, fully parsed before any of it runs, invoked as the file's
last physical statement) to the two scripts that *invoke* `deploy-headless.sh` and must keep
running afterward. Research established these are the only two genuine invocation sites in
`agent-system/extensions/core`: `orchestrate-cycle-plan.sh` (the observed incident) and
`command-gate-out.sh` (the same class, not yet observed). The plan lands a red-first regression
test, the two wraps, a mechanical class guard so a future third caller cannot silently reopen the
hole, and the two documentation corrections research identified.

All edits target the SOURCE STORE (`agent-system/extensions/core/...`), never `.claude/**`.

### Research Integration

- **Mechanism confirmed independently of orchestrator timing.** The research pass built a synthetic
  self-rewriting harness: an unprotected flat script silently truncated 5/5 runs; the
  `main() { ... }; main "$@"` wrap completed correctly 3/3; the self-copy-then-`exec` variant also
  completed 3/3. The wrap is therefore a proven, not a speculative, mitigation.
- **Candidate (b) rejected on mechanism, not preference.** Invoking the source-store copy of
  `deploy-headless.sh` changes only which deployer binary runs. `deploy-headless.sh` is already
  self-protected either way; the victim is the *caller*, which is overwritten by the resync
  regardless. The operator's one surviving manual run is byte-offset luck, exactly the kind of
  single non-crash the dispatch instructs not to treat as proof.
- **Candidate (c) rejected on contract cost.** Deferring the deploy out of the running script
  splits one invocation into two and breaks the in-band `deploy_exit` + pre/post findings
  comparison the three-branch failure contract depends on, for no correctness gain.
- **Candidate (a) (re-exec from a copy) works but costs more here.** Both call sites derive sibling
  paths from their own on-disk location (`SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"`
  at `orchestrate-cycle-plan.sh:204`, `.claude/scripts/...` literals in `command-gate-out.sh`), so a
  re-exec from a `mktemp` file would require threading the original `SCRIPT_DIR` separately through
  every sibling reference, and changes process identity. The function-wrap needs zero path changes.
- **The wrap must run to true EOF.** A partial wrap that closes at the end of the checkpoint returns
  control to flat top-level code, which then resumes reading the already-rewritten file at a stale
  offset — the identical hazard, relocated a few hundred lines later.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch and no roadmap phases were requested; ROADMAP.md
was not consulted or modified.

## Goals & Non-Goals

**Goals**:
- Make both genuine `deploy-headless.sh` call sites survive the redeploy they themselves trigger,
  using the pattern already proven in-tree, with no change to what the code does or in what order.
- Preserve the three-branch (a)/(b)/(c) deploy-failure contract byte-for-byte in behavior,
  including the deploy-failure defer and its `defer_ledger` entry.
- Add a mechanical guard so a future third automated caller fails loudly rather than silently
  reopening the hazard class.
- Add a regression test that actually exercises a mid-run rewrite of the script under test —
  something the existing deploy stub does not do today.
- Record, for the sibling redundant-verify-deploy-passes task, that this fix does NOT change which
  copy of `deploy-headless.sh` is invoked and therefore does not change its internal verify depth.

**Non-Goals**:
- Changing which copy of `deploy-headless.sh` is invoked (candidate (b)) — explicitly rejected.
- Restructuring the checkpoint's logic, its ledger skips, its confirmation/attribution filters, or
  its verify depth. This task moves code syntactically; the sibling task changes verify behavior.
- Re-indenting the wrapped bodies (see Phase 2's decision note).
- Auditing the `.opencode/` tree's own `commands/implement.md`. Research established it is a
  different call shape (Claude tool calls, a fresh subprocess each time) and out of scope; it is
  flagged in Risks only.
- Producing a timing-dependent reproducer of the original incident. The failure is intermittent by
  construction; the deterministic byte-shift harness in Phase 1 replaces it.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The ~1,700-line wrap in `orchestrate-cycle-plan.sh` is mechanically mis-applied (stray brace, mangled heredoc) | H | M | Do NOT re-indent the body (Phase 2 decision). `bash -n` immediately after the edit, then the full existing `test-orchestrate-cycle-plan.sh` suite, which already covers checkpoint cases (a)-(r) end to end |
| `declare -A` / `declare -a` after the wrap anchor become function-local instead of global | M | M | Bash uses dynamic scoping: every consumer is either inside the wrapper or in a function called from it, so visibility is preserved. The existing suite exercises those arrays; a regression surfaces as a test failure, not a silent wrong answer. If one is genuinely needed outside, use `declare -g` for that name only |
| `set -e` semantics shift in `command-gate-out.sh` when its body moves into a function | M | L | `set -e` is inherited by called functions. It is suppressed only when the function is invoked in a condition or `||` context — Phase 3 invokes it as a plain statement, preserving today's semantics exactly. Verified by re-running the gate-out suites |
| The new regression test does not actually fail against the unfixed script (byte-offset luck) | M | M | Phase 1 is deliberately red-first and uses a large *prepended* banner so every byte offset after it shifts; if the first shift still passes, increase it until the pre-fix run fails, and record the observed pre-fix failure text |
| The very first deploy that lands this fix still runs against the OLD, unprotected deployed copies | M | M | Inherent and one-time: the deploy that installs the protection is itself triggered from an unprotected caller. If that deploy run crashes, simply re-run — the second run's callers are the protected copies. Note this in the implementation summary rather than attempting to engineer around it |
| A future third automated caller reopens the class | H | M | Phase 4's mechanical lint plus the Phase 5 doc updates, which make the wrap a stated precondition of "sanctioned call site", not just a listed path |
| Doc edits accidentally cite a task number outside `specs/**` | L | M | `.claude/rules/no-task-references-in-deliverables.md`: cite durable anchors (filenames, section headings, the `SELF-OVERWRITE HAZARD` header) only |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 3 | -- |
| 2 | 2 | 1 |
| 3 | 4, 5 | 2, 3 |
| 4 | 6 | 2, 3, 4, 5 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Red-First Regression Test for the Mid-Run Rewrite [NOT STARTED]

**Goal**: Add a Group 11 case to the existing cycle-plan suite whose `deploy-headless.sh` stub
rewrites the script under test mid-run, and demonstrate it FAILS against the current, unfixed
script — establishing the test actually detects this hazard before any fix is applied.

**Tasks**:
- [ ] Read `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` around
      `write_g11_deploy_headless_stub` (currently ~line 1187) and the Group 11 fixture helpers
      (`g11_seed_state_and_mt`, `g11_reset_mt`) to match the suite's existing conventions.
- [ ] Add a sibling helper `write_g11_self_rewriting_deploy_stub <exit_code>` that does everything
      the existing stub does (bump `G11_DEPLOY_CALL_MARKER`, emit its stderr line, exit `rc`) and
      additionally rewrites `$WORKDIR/.claude/scripts/orchestrate-cycle-plan.sh` in place with a
      byte-shifted copy of `$SUT_SRC` — a large comment banner prepended, so every byte offset
      after the rewrite point moves. This mirrors the incident, where the deployed and source
      copies were content-identical yet the byte stream was still invalidated.
- [ ] Add case `(s)` using that stub with exit 3 (the ordinary deploy-landed path) and assert:
      the SUT exits 0; its stdout plan JSON parses and is non-empty; stderr contains no
      `unbound variable`, `syntax error`, or `unexpected` text; the deploy stub was called exactly
      once.
- [ ] Add case `(t)` using that stub with exit 1 (the deploy-failure branch) and assert the
      remaining tasks are still deferred and the `defer_ledger` entry is intact — i.e. the wrap
      does not weaken the deploy-failure defer even when the rewrite happens.
- [ ] Run the suite against the UNFIXED script; confirm the two new cases fail. Record the exact
      observed failure text (truncation vs. spurious parse error) in the phase notes.
- [ ] If a new case unexpectedly passes pre-fix, enlarge the prepended banner and re-run until the
      pre-fix failure is deterministic across 3 consecutive runs; do not proceed on a green
      pre-fix result.

**Timing**: 1.25 hours

**Depends on**: none

**Verification Tier**: full

**Scope Hypothesis**: this phase assumes the suite stages the SUT at
`$WORKDIR/.claude/scripts/orchestrate-cycle-plan.sh` (copied from `$SUT_SRC`) and invokes it from
there, so a stub can legitimately overwrite that staged copy. Confirm by reading the harness's
`SUT_SRC`/`SUT` assignments (currently ~lines 51-86) before writing the stub; if the harness runs
the SUT from a different path, retarget the rewrite to whatever path `$SUT` resolves to.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` - new
  `write_g11_self_rewriting_deploy_stub` helper plus Group 11 cases (s) and (t)

**Verification**:
- `bash -n` on the edited suite file
- `bash agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` — every
  pre-existing case still passes; the two new cases FAIL, with the failure text recorded
- No existing case weakened, renamed, or removed to accommodate the new ones

---

### Phase 2: Function-Wrap `orchestrate-cycle-plan.sh` [NOT STARTED]

**Goal**: Wrap the redeploy checkpoint and everything textually after it, through true EOF, inside
one function defined before it runs — so no byte read after the deploy call can be a stale-offset
read.

**Tasks**:
- [ ] Insert `orchestrate_cycle_plan_main() {` immediately before the
      `# ── (k, part 1) Budget guard` comment block (currently ~line 698), i.e. at or before the
      first statement that could still be pending when the deploy fires.
- [ ] Append the closing `}` at EOF followed by a bare `orchestrate_cycle_plan_main` as the file's
      last physical statement, with nothing after it. No `"$@"` forwarding: confirm again by grep
      that no top-level code after the anchor reads `$1`/`$2`/`$@`/`$#` outside an already-`local`
      function scope (research verified this; re-verify because it is load-bearing).
- [ ] Do NOT re-indent the wrapped body. Record the reason in a short comment at the wrap: quoted
      heredoc bodies must not gain leading whitespace, the behavioral diff must stay reviewable as
      three added lines, and `git blame` continuity matters for a 1,700-line region. Note that this
      deliberately differs in cosmetics — not in mechanism — from `deploy-headless.sh`'s own
      originally-authored indented `main()`.
- [ ] Confirm the wrapper's terminal statement path still always `exit`s: the file's last call is
      `emit_and_exit "$new_cycle_count"`, and `emit_and_exit` ends in `exit 0`. No `return`
      followed by further reads.
- [ ] Add a `SELF-OVERWRITE HAZARD` note to the file's top header comment: why the wrap exists,
      that it must extend to true EOF, and a pointer to `deploy-headless.sh`'s own header comment
      as the origin of the pattern. State explicitly: do not undo this structure by moving logic
      back to top level.
- [ ] Re-run Phase 1's cases (s) and (t): both must now pass.

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: full

**Scope Hypothesis**: the wrap boundary is asserted as "the `# ── (k, part 1) Budget guard` comment
through EOF" (currently lines ~698-2408, ~1,700 lines). Line numbers are a hypothesis, not a fact —
locate both boundaries by content anchor (that comment string; the final `emit_and_exit` call), not
by line number, and confirm the file's last physical statement before editing.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` - opening brace before the
  budget-guard comment, closing brace + invocation at EOF, header hazard note

**Verification**:
- `bash -n agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` clean
- Full `bash agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` passes,
  including every pre-existing Group 11 checkpoint case (a)-(r) and the new (s)/(t)
- `git diff --stat` on the script shows a small line delta (the added brace/invocation/comment
  lines), not a whole-file rewrite — proof the body was not re-indented
- `bash agent-system/extensions/core/scripts/tests/test-force-phases.sh` and
  `test-orchestrate-cycle-postflight.sh` still pass (nearest consumers of this script's output)

---

### Phase 3: Function-Wrap `command-gate-out.sh` [NOT STARTED]

**Goal**: Apply the identical wrap to the second genuine call site, whose `rc==6` redeploy-trigger
branch has ~90 lines of top-level work still to do after the deploy returns.

**Tasks**:
- [ ] Insert `command_gate_out_main() {` immediately after the two top-of-file `source` lines
      (`skill-base.sh`, `lib/deploy-baseline-lib.sh`, currently ~lines 36-41), leaving `set -e` and
      both `source` statements at top level where they are today.
- [ ] Append the closing `}` at EOF followed by `command_gate_out_main "$@"` as the file's last
      physical statement. Argument forwarding IS required here: the body reads `$1`/`$2`/`$3`
      (`task_number`, `operation`, `session_id`).
- [ ] Do not re-indent the wrapped body, for the same reasons as Phase 2.
- [ ] Confirm the invocation is a plain statement (not in a condition, `if`, or `||` context) so
      `set -e` behavior inside the function is identical to today's top-level behavior.
- [ ] Verify the trailing non-executable content (the closing `NOTE:` comment block about never
      deleting `.return-meta.json`) ends up either inside the wrap or after the invocation — a
      comment is inert either way, but keep it readable and adjacent to what it describes.
- [ ] Add the same `SELF-OVERWRITE HAZARD` header note, pointing at `deploy-headless.sh`'s header
      and naming the `rc==6` branch as the reason this file is in the hazard class.

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: full

**Scope Hypothesis**: asserts exactly two `source` lines at the top and that the deploy call sits at
`.claude/scripts/deploy-headless.sh` inside the `rc==6` branch (currently ~line 176), with ~90 lines
of work after it to EOF (~line 265). Confirm both anchors by content before editing.

**Files to modify**:
- `agent-system/extensions/core/scripts/command-gate-out.sh` - opening brace after the `source`
  lines, closing brace + `command_gate_out_main "$@"` at EOF, header hazard note

**Verification**:
- `bash -n agent-system/extensions/core/scripts/command-gate-out.sh` clean
- `bash agent-system/extensions/core/scripts/tests/test-gate-out-repair-reporting.sh` passes
- `bash agent-system/extensions/core/scripts/tests/test-postflight-deploy-gate.sh` and
  `test-deploy-baseline-lib.sh` pass
- A manual read-through confirming the three-branch (a)/(b)/(c) handling inside `rc==6` is
  textually unchanged apart from its enclosing braces

---

### Phase 4: Mechanical Class Guard for Future Callers [NOT STARTED]

**Goal**: Make the hazard class closed by construction rather than by memory — a new caller that
invokes `deploy-headless.sh` from a still-running deployed script without wrapping its remaining
logic must fail a test, loudly and by name.

**Tasks**:
- [ ] Create `agent-system/extensions/core/scripts/tests/test-lint-deploy-caller-wrap.sh`.
- [ ] Classify invocation sites across `agent-system/extensions/*/scripts/**/*.sh` (excluding
      `tests/` fixtures): a line is a GENUINE invocation when it executes the script
      (`bash .../deploy-headless.sh`, a command substitution around it, or a direct `./` call) and
      is not inside a comment, an `echo`/`printf`/`fail`/remedy string. Everything else is a
      mention and is ignored. Re-derive this classification in the test itself rather than
      hardcoding a path list, so a new caller is discovered automatically.
- [ ] For each genuine caller, assert the structural wrap: the invocation line lies inside a
      top-level function (nearest preceding `^[A-Za-z_][A-Za-z0-9_]*\(\) *\{`), that function's
      closing `^}` follows it, and after that brace only comments, blank lines, and a single bare
      invocation of that same function remain — i.e. nothing executable is read from the file after
      the deploy can have rewritten it.
- [ ] Assert `deploy-headless.sh` itself satisfies the same rule (it already does, via `main()`),
      so the deployer is covered by the same guard rather than exempted by special case.
- [ ] Emit a named, actionable failure message on a violation: the offending file and line, the
      rule, and a pointer to `deploy-headless.sh`'s `SELF-OVERWRITE HAZARD` header.
- [ ] `chmod +x` the new suite (auto-discovered by `tests/run-all.sh`; no registration needed — the
      runner globs `scripts/tests/test-*.sh`). Confirm a lost exec bit would surface as a loud
      `[SKIP]`, matching the runner's documented discipline.
- [ ] Self-test the guard: temporarily unwrap one caller in a scratch copy and confirm the lint
      fails; restore.

**Timing**: 1.5 hours

**Depends on**: 2, 3

**Verification Tier**: full

**Scope Hypothesis**: research classified exactly two genuine caller sites (plus `deploy-headless.sh`
itself) out of ~15 files that merely mention the path. Re-run the classification inside the new
lint at implementation time and assert the count matches; if a third genuine site appears, do NOT
silently widen the allowlist — wrap it the same way and say so in the summary.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-lint-deploy-caller-wrap.sh` - new file

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-lint-deploy-caller-wrap.sh` passes against
  the post-Phase-2/3 tree
- The scratch-unwrap self-test failed before restore (recorded in phase notes)
- The lint's discovered genuine-caller set is printed in its output, so the classification is
  auditable rather than implicit

---

### Phase 5: Documentation Corrections [NOT STARTED]

**Goal**: Make the structural precondition part of what "sanctioned automated call site" means, and
correct the guardrails prose that currently reads as though this hazard were already covered.

**Tasks**:
- [ ] In `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md`, update BOTH
      `Automated Exception` subsections (the Inter-Cycle Redeploy Checkpoint one and the Postflight
      Completion-Deploy Gate one) to state that a sanctioned call site must wrap its own remaining
      logic in a function extending to true EOF, pointing at `deploy-headless.sh`'s
      `SELF-OVERWRITE HAZARD` header for the mechanism and at the Phase 4 lint for enforcement.
- [ ] In `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`, amend
      hazard 3's `(iii) The replacement exposure` discussion to distinguish two cases explicitly:
      a *later, fresh* subprocess reading the new bytes (true, and safe) versus the
      *currently executing* invocation that triggered the redeploy having its own byte stream
      invalidated (the real incident; now closed at both call sites by the function-wrap).
- [ ] In the same file's `### The Inter-Cycle Redeploy Checkpoint` subsection, record the decision
      the sibling redundant-verify-deploy-passes task depends on: the checkpoint continues to invoke
      the DEPLOYED copy (`$SCRIPT_DIR/deploy-headless.sh`), unchanged, so `deploy-headless.sh`'s own
      internal `--skip-slow` verify depth is untouched by this fix and the sibling task can build on
      today's fast/full split without re-deriving it.
- [ ] Confirm the three-branch (a)/(b)/(c) contract prose is unchanged in substance — the fix moves
      code syntactically and must not be described as altering the contract.
- [ ] Cite durable anchors only (filenames, section headings, the `SELF-OVERWRITE HAZARD` header
      name). No task numbers in any file outside `specs/**`
      (`.claude/rules/no-task-references-in-deliverables.md`).

**Timing**: 1 hour

**Depends on**: 2, 3

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md` - wrap precondition
  in both Automated Exception subsections
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` - hazard 3 (iii)
  clarification; sibling-task decision note in the checkpoint subsection

**Verification**:
- Diff read-through confirming every changed hunk is prose, with no executable or front-matter
  surface touched
- `bash agent-system/extensions/core/scripts/check-task-references.sh` (or the repo-wide task-
  reference lint, whatever its current entry point) reports no new occurrences
- Every cross-reference added resolves to a real file and a real section heading

---

### Phase 6: Full Gate Sweep [NOT STARTED]

**Goal**: Confirm nothing regressed anywhere, with no test weakened or deleted, and hand the change
off for the sanctioned deploy rather than triggering one by hand.

**Tasks**:
- [ ] `bash agent-system/extensions/core/scripts/tests/run-all.sh` (source-store mode) — full sweep.
- [ ] Explicitly re-run the dispatch-named deploy suites: `test-deploy-orphans.sh`,
      `test-deploy-verify-wiring.sh`, plus `test-deploy-propagation.sh` and
      `test-orchestrate-cycle-plan.sh`.
- [ ] Confirm via `git diff` that no test file lost a case, an assertion, or a `fail` call in the
      course of this task. Any test change must be additive.
- [ ] Do NOT invoke `deploy-headless.sh` manually. Propagation to `.claude/**` is owned by the
      sanctioned automated triggers (the postflight completion-deploy gate and the inter-cycle
      checkpoint) — the same two sites this task just made safe.
- [ ] Record in the implementation summary: (i) the pre-fix failure text observed in Phase 1;
      (ii) the classification result from Phase 4's lint (which callers are genuine); (iii) the
      sibling-task decision (deployed copy unchanged, verify depth untouched); (iv) the one-time
      residual exposure — the first deploy that lands this fix is still triggered from the old,
      unprotected deployed callers, so if it dies mid-run, re-running it is the expected remedy and
      the second run is protected.

**Timing**: 1 hour

**Depends on**: 2, 3, 4, 5

**Verification Tier**: full

**Files to modify**:
- None (verification-only phase; the summary artifact is written by the implementation postflight)

**Verification**:
- `run-all.sh` exits 0 with a nonzero discovered-suite count
- All four named suites pass individually
- `git diff` review confirms only additive test changes
- The four summary items above are present in the execution summary

---

## Testing & Validation

Mapping to the dispatch's five verification requirements:

- [ ] **(1) Synthetic self-rewriting demonstration.** Satisfied durably by Phase 1's byte-shifting
      stub, which rewrites the script under test mid-execution with content of a different length —
      the in-repo, deterministic successor to the research pass's scratch harness. The research
      harness itself (unprotected 5/5 truncated; wrapped 3/3 correct) stands as the recorded
      independent demonstration of the underlying bash behavior.
- [ ] **(2) Checkpoint completes with non-empty plan JSON and dispatch rows when a deploy fires
      mid-cycle.** Phase 1 case (s), passing after Phase 2.
- [ ] **(3) Deploy-failure branch still defers with the `defer_ledger` entry intact.** Phase 1 case
      (t) (stub exit 1), plus the pre-existing Group 11 cases covering exit 1/2.
- [ ] **(4) Deploy-landed branches (exit 0 and exit 3) still run the baseline comparison.**
      Pre-existing Group 11 cases, re-run unmodified in Phases 2 and 6.
- [ ] **(5) `scripts/tests/` re-run for cycle-plan and the deploy suites, with nothing weakened.**
      Phase 6, including the explicit additive-only diff review.
- [ ] Gate-out side covered by `test-gate-out-repair-reporting.sh` and
      `test-postflight-deploy-gate.sh` in Phase 3.
- [ ] Class closure covered by Phase 4's lint, self-tested against a deliberately unwrapped copy.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` (wrapped, header note)
- `agent-system/extensions/core/scripts/command-gate-out.sh` (wrapped, header note)
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` (new stub + cases s, t)
- `agent-system/extensions/core/scripts/tests/test-lint-deploy-caller-wrap.sh` (new)
- `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md` (updated)
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` (updated)
- Execution summary recording the four items named in Phase 6

## Rollback/Contingency

Every phase is an independent, self-contained commit, so rollback is per-phase `git revert` of the
relevant commit — no schema, state, or on-disk data migration is involved.

- If Phase 2's wrap breaks the cycle-plan suite in a way that is not resolved quickly, revert that
  single commit: the tree returns to the pre-wrap script with Phase 1's new tests still present and
  red, which is a correct, honest intermediate state (a known, now-detected defect), not a
  corrupted one.
- If Phase 4's lint proves too brittle to classify invocation sites reliably, downgrade it to a
  warning-only advisory in the same commit rather than deleting it, and say so explicitly in the
  summary — do not silently drop the class guard, since the dispatch's core instruction is to
  generalize rather than patch one site.
- Do not use `git-snapshot.sh` in its default reverting form as a routine checkpoint here; if a
  defensive checkpoint is wanted before Phase 2's large mechanical edit, use
  `bash .claude/scripts/git-snapshot.sh 260 --no-revert`.
