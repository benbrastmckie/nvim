# Implementation Plan: Task #347

- **Task**: 347 - Turn bounded-build-waiter.md Rule 2 into a blocking PreToolUse Bash hook
- **Status**: [IMPLEMENTING]
- **Effort**: 4.5 hours
- **Dependencies**: None (the declared `file_scope` overlap with task 282 on `manifest.json` is deliberately un-sequenced per the task description; task 282 re-confirmed `not_started` at plan time)
- **Research Inputs**: specs/347_self_match_waiter_pretooluse_block_hook/reports/01_self-match-waiter-hook.md
- **Artifacts**: plans/01_self-match-waiter-hook.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md, shell-strict-mode.md, shell-script-testing.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`bounded-build-waiter.md` Rule 2 forbids `ps | grep`, `pgrep -f`, and any process-name-matching
liveness test, and it already failed to bind: a dispatched agent wrote
`until ! pgrep -f 'distsys/check.sh' >/dev/null 2>&1; do sleep 20; done` twice with that
prohibition live in its own reference chain. This plan adds mechanical teeth and no prose: one
new blocking PreToolUse Bash hook (`hooks/validate-bounded-waiter.sh`) matching the narrow
three-way conjunction of a loop construct, a `sleep`, and a name-match liveness test; one fixture
suite driving it as a real subprocess; a bare registration in the one surface that can actually
reach an already-deployed repo; and manifest wiring. Done means: all four bad shapes including the
`[b]racket` variant are refused with exit 2 and a stderr block carrying the `kill -0` idiom
inline; every legitimate diagnostic shape stays legal, proven by fixture; the hook fails open on
internal error, proven by fixture; and the registration is verified bare in the deployed
`.claude/settings.json` with the hook observed to actually fire. Net pattern-document count does
not increase.

### Research Integration

Findings carried in and re-derived at plan-authoring time rather than taken on trust:

- **Structural model** (adopted): `hooks/validate-no-task-references.sh`, not
  `hooks/guard-destructive-git.sh`. Both are PreToolUse, block via `exit 2` + stderr (never
  `permissionDecision: deny`), fail open, and are registered bare; the former has exactly one
  hazard class and no internal branching, which is this hook's shape. Re-confirmed: all three
  precedent hooks (`guard-destructive-git.sh:122`, `validate-no-task-references.sh:26`,
  `detect-noop-bash.sh:65`) carry `set -euo pipefail` (Class A), and
  `validate-no-task-references.sh` guards **every** `jq` call with `|| true`.
- **`detect-noop-bash.sh` is the wrong mechanism** (confirmed by reading it): PostToolUse,
  `exit 0` unconditionally, registered with the `2>/dev/null || echo '{}'` wrapper. It
  structurally cannot block. It remains the reference only for the per-session state-file idiom.
- **Registration surface** (settled, re-confirmed): `merge-sources/settings-hooks.json`'s existing
  exact-string `"Bash"` matcher block, which today carries `guard-destructive-git.sh` alone.
  `verify-deploy.sh`'s own Gate 2 remediation string says verbatim *"add it to
  merge-sources/settings-hooks.json, not root-files/settings.json"*. `root-files/settings.json`
  gets nothing: it is install-once, so an entry placed there reaches only a fresh install.
- **Family B gap** (re-derived, and the research report's figure corrected): `build_waiter_family()`
  in `scripts/claude-refresh.sh` classifies Family B as
  `(until|while) && *"grep -q"* && *sleep*`. The motivating incident command contains `until` and
  `sleep` but **no** `grep -q` substring, so the existing reaper classifier does not match it.
  `grep -n pgrep` over the whole 2444-line file returns **zero** matches (the research report said
  one, a prose comment; re-derived at plan time it is zero — the line-1577 comment names
  `until ! ps aux | grep -q ...` only). The inventory is directional guidance about shape
  *families*, never a drop-in regex set.
- **Merge semantics** (carried, load-bearing): `deep_merge` dedupes `hooks.PreToolUse` blocks by
  exact string-equal `matcher` and the merge is add-only, so a mis-spelled matcher creates a
  second live block no later merge can ever remove. The matcher string must be exactly `"Bash"`.
- **Rule 2 text and the canonical idiom** re-read verbatim at plan time and confirmed unchanged by
  the recently-completed neighbor task that owns that file.

### Prior Plan Reference

No prior plan. This is the task's first plan round.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch's delegation context, so no roadmap was consulted
and no roadmap phases are added.

### Neighbor-Status Correction (affects the collision ruling the dispatch requires)

The dispatch and the research report both describe task 345 as `[not_started]`; `specs/state.json`
now shows it `[completed]`. The collision risk the dispatch flagged — "if both tasks independently
build a blocking Bash gate" — was therefore re-checked rather than assumed: `detect-noop-bash.sh`
is still PostToolUse, still exits 0 unconditionally, and is still registered with the
`|| echo '{}'` wrapper. Task 345 did **not** build a blocking gate. There is no collision, and
this task's hook is the first blocking Bash gate over wait-loop shapes. Task 282 — the closest
sibling in shape — is re-confirmed `not_started`, so there is no landed house pattern to follow;
this task establishes it.

## Goals & Non-Goals

**Goals**:
- A PreToolUse Bash hook that BLOCKS, via `exit 2` + stderr, a command conjoining a wait-loop
  construct with a name-matching liveness test — including the `[b]racket` variant.
- A rejection message that is actionable: the self-match mechanism in one line, `bounded-build-waiter.md`
  Rule 2 named, and the canonical `kill -0` idiom carried INLINE, not as a pointer.
- Fail OPEN on every internal error, proven by fixture.
- A fixture suite driving the hook as a real subprocess, covering every must-block and every
  must-allow shape, plus flag-clustering regressions.
- Bare registration (no `2>/dev/null || echo '{}'` wrapper) in the one surface that reaches an
  already-deployed repo, verified by deploying and inspecting the deployed `.claude/settings.json`.
- An explicit, recorded ruling on the Rule 4 "one waiter per log" second leg.
- An explicit, recorded ruling on the shared-pattern-library question, with no silent-drift path
  left open against `claude-refresh.sh`'s Family B classifier.
- `manifest.json` wiring for both the hook and the test.

**Non-Goals**:
- No new `context/` or pattern document, and no restatement of Rule 2 in new prose anywhere. This
  is the task's central constraint; the rulings above live in the hook's own header comment and in
  the implementation summary under `specs/**`, which is where they belong.
- No weakening or relaxation of any existing rule in `bounded-build-waiter.md`.
- No change to `claude-refresh.sh`'s reaper behavior. Its classifier is an input, not a target.
- No broadening to no-op filler commands (`echo idle`, bare `true`) or to absent-waiter parking —
  adjacent tasks' territory, and this hook must not classify either.
- No fix to the consumer repo's gate script or runtime; consumer-repo consequences are
  recommendations only.
- No entry added to `root-files/settings.json`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `jq` exits 2 on a usage or system error; under `set -euo pipefail` an unguarded `jq` aborts the hook with **exit 2**, which for PreToolUse means BLOCK — inverting fail-open into fail-closed | H | M | Guard every `jq` call with `\|\| true` (the verified `validate-no-task-references.sh` idiom), gate on `command -v jq` first, and assert the inversion is absent with a fixture that masks `jq` off `PATH` and requires exit 0 |
| Deploying a blocking Bash PreToolUse hook makes it live for this tree's own sessions; a false positive would refuse unrelated Bash tool calls repo-wide | H | L | The full fixture suite must be green before Phase 4 deploys; the match requires all three conjunction legs; every internal error exits 0; rollback is a one-entry removal plus redeploy (see Rollback) |
| A mis-spelled matcher creates a second PreToolUse block that the add-only `deep_merge` can never remove | H | L | Matcher string exactly `"Bash"`, appended into the existing block rather than as a new block; Phase 4 asserts exactly one registration and no new matcher key |
| Registration placed in a surface that cannot reach a deployed repo would leave the task looking complete while the hook never fires | H | L | Settled by three independent confirmations; `file_scope` already excludes `root-files/settings.json`; Phase 4 greps the **deployed** file and live-fires the deployed copy |
| After deploy, authoring or editing the fixture file through a Bash heredoc would be refused by the hook itself — the heredoc text contains the banned shapes | M | M | Author and edit the fixture with the Write/Edit tools, never a Bash heredoc; record this in the fixture's own header so a later editor is not mystified |
| A text-level shape test cannot parse shell structure: a `sleep` and a loop belonging to unrelated statements in one command could false-positive | M | L | Documented limitation in the hook header; the third conjunction leg (a name-match **process** test) makes the coincidence implausible; a refusal is recoverable by using the canonical idiom, and never silently swallows the command |
| Silent drift between this hook's inventory and `claude-refresh.sh`'s Family B classifier, which is asymmetric in **both** directions (the reaper misses `pgrep`; this hook deliberately does not classify log-sentinel polls the reaper does) | M | M | Header cross-reference naming `build_waiter_family()` and both asymmetries explicitly; Phase 3 carries an explicit decision point on adding the reciprocal pointer |
| Concurrent sibling dispatched this same cycle (task 302, plan phase) on this shared tree | L | L | Its `file_scope` is disjoint from all four of this task's files; still re-read each file immediately before editing and stage only this task's own hunks |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Author the blocking hook [COMPLETED]

**Goal**: `hooks/validate-bounded-waiter.sh` exists and, driven by hand with synthetic payloads,
refuses every must-block shape with exit 2 and an actionable stderr block, allows every
must-allow shape, and fails open on every internal error. Both in-task rulings are recorded in
its header.

**Tasks**:
- [x] Create `agent-system/extensions/core/hooks/validate-bounded-waiter.sh`, Class A
      (`set -euo pipefail`) per `context/standards/shell-strict-mode.md`, modeled on
      `validate-no-task-references.sh`'s single-hazard-class shape: one stdin parse, one match
      test, one `exit 2` block. Inherit `guard-destructive-git.sh`'s PreToolUse contract verbatim
      (exit 2 + stderr, never `permissionDecision: deny`, which is documented-buggy for
      allow-listed tool calls). *(completed)*
- [x] Read `.tool_input.command` from stdin. Append `|| true` to **every** `jq` invocation — this
      is not stylistic: `jq` exits 2 on usage/system errors, and a `set -e` abort propagates that
      code, which PreToolUse reads as BLOCK. Gate on `command -v jq` before any use. *(completed)*
- [x] Fail open with `exit 0` on each of: `jq` absent, stdin absent or empty, payload unparseable,
      `.tool_input.command` empty or missing. Each case gets its own explicit guard rather than
      relying on fall-through. *(completed)*
- [x] Implement the blocking conjunction — **all three** legs required:
      (a) a loop construct: the `until` or `while` keyword;
      (b) a `sleep` call;
      (c) a name-match liveness test: `pgrep` at a word boundary, **or** a `ps` invocation piped
      into `grep`. *(completed)*
- [x] Do **not** inspect the `grep` pattern's contents. The `[b]racket` variant then blocks by
      construction with no special case — and a hook that treated the bracket form as safe would
      reproduce the exact bug it exists to stop, since the bracket only stops `grep` matching
      itself, never the parent shell. *(completed)*
- [x] **Ruling to implement and record: match `pgrep` as a bare word, with any flags or none — do
      not narrow leg (c) to a `-f`/`--full` flag test.** Rule 2's own text forbids "any
      process-name-matching test"; the three-way conjunction already supplies all the
      false-positive safety needed; and a bare-token match makes every flag-clustering variant
      (`-af`, `-fa`, `-x -f`, `--full`) a non-issue by construction instead of an enumerated flag
      list that must be kept current. This is deliberately stricter than the research report's
      flag-narrowed recommendation and violates none of the task's must-allow cases, all of which
      lack at least one conjunction leg. *(completed)*
- [x] Do **not** classify, and record each as a deliberate exclusion in the header: a bare
      `pgrep` or `ps aux | grep` with no loop and no `sleep`; a one-shot name-match conditional
      outside a loop; `ps -p "$pid"` in a loop (a PID test, not a name match); a log-sentinel poll
      such as `until grep -q DONE log; do sleep 10; done` (no process-name match, no self-match
      mechanism — and the reaper's Family B *does* classify this, which is one half of the
      inventory asymmetry below); no-op filler (`echo idle`, bare `true`) and absent-waiter
      parking, both of which are adjacent tasks' territory. *(completed)*
- [x] Note in the header that the presence of `kill -0` in a command grants **no** exemption: a
      command carrying both `kill -0` and a name-match test inside a loop still blocks. *(completed)*
- [x] Write the `exit 2` stderr block: one line stating what was blocked and the self-match
      mechanism (the polling shell's own argv contains the pattern it searches for, so the test
      matches the waiter itself and never resolves); one line naming `bounded-build-waiter.md`
      Rule 2; and the canonical idiom INLINE, verbatim:
      `cmd >log 2>&1 & pid=$!` / `timeout N bash -c 'while kill -0 "$1" 2>/dev/null; do sleep 10; done' _ "$pid"`. *(completed)*
- [x] Record the **shared-pattern-library ruling** in the header: rejected. A library sourced by
      only this hook is not shared; the only candidate second consumer is `claude-refresh.sh`,
      which is both outside this task's `file_scope` and an explicit non-goal to modify; and the
      two consumers receive different input shapes (a `ps -eo args` column at reap time vs. a
      `tool_input.command` string at write time), which is a harder split than the
      `task-reference-patterns.sh` precedent whose two consumers both receive plain text. Close
      the drift path with a cross-reference naming `build_waiter_family()` and **both**
      asymmetries: the reaper requires the literal substring `grep -q` and so misses `pgrep`
      entirely (zero occurrences in that file, re-derived) and also misses a `ps aux | grep -i`
      loop with no `-q`; and this hook deliberately does not classify the log-sentinel polls the
      reaper lumps into the same family. *(completed)*
- [x] Record the **Rule 4 ruling** in the header: the "one waiter per log" leg is scoped out of
      this hook, because a PreToolUse hook observes waiter STARTS and never waiter EXITS, so any
      "this log already has a waiter" record goes stale the instant that waiter exits with no
      event to clear it, and would falsely refuse a legitimate sequential wait on the same log — a
      false positive, which this task treats as worse than no hook. A fixed TTL does not rescue
      it: Rule 1 sizes the legitimate wait to the command's own expected run time, so no single
      bound is safely shorter than every legitimate wait and longer than every dead-waiter gap.
      Point at `claude-refresh.sh`'s `BUILD_WAITER_REAP_MIN`-gated `run_build_waiter_pass` as where
      the rule is already enforced — at reap time, against a live process snapshot, where the
      liveness signal write-time observation structurally cannot have actually exists. *(completed)*
- [x] Note the known limitation in the header: this is a text-level shape test, not a shell
      parser, so a `sleep` and a loop keyword in unrelated statements of one command string will
      match. *(completed)*
- [x] `chmod +x` the hook. *(completed)*
- [x] Use no task-number references anywhere in the file — cite by filename, command, rule number,
      or concept (`.claude/rules/no-task-references-in-deliverables.md`). *(completed)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts the hook is one new file with no sourced library and no
other file changed. Confirm with `git status --short` showing exactly one new path under
`agent-system/extensions/core/hooks/`. It also carries two figures from the research report that
were re-derived at plan-authoring time and are asserted here as verified, not carried: zero
`pgrep` occurrences in `scripts/claude-refresh.sh`, and `build_waiter_family()`'s Family B test
being `(until|while) && *"grep -q"* && *sleep*`. Re-confirm both with
`grep -c pgrep agent-system/extensions/core/scripts/claude-refresh.sh` and a read of
`build_waiter_family()` before writing the header cross-reference that cites them.

**Tier Justification**: `suite_selection_select` returns the `__FULL_SWEEP__` sentinel for this
brand-new basename — no suite covers it yet, and the justification must not claim one — so the
honest covering check is the gate subset `bash .claude/scripts/verify-deploy.sh --only-gate 22`
(shellcheck lint, whose sanctioned entry point is `scripts/lint/lint-shellcheck.sh --verbose`)
together with hand-driven `jq -n --arg`-built payloads exercising each block and allow shape
directly against the new file.

**Files to modify**:
- `agent-system/extensions/core/hooks/validate-bounded-waiter.sh` - new PreToolUse Bash hook: the
  three-way conjunction matcher, the exit-2 stderr block carrying the canonical idiom inline, the
  layered fail-open guards, and the two in-task rulings plus the Family B cross-reference in its
  header

**Verification**:
- `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh --verbose` exits 0 (check the
  exit status, not only a diff of its findings output — a broken lint can print nothing and look
  clean).
- `test -x agent-system/extensions/core/hooks/validate-bounded-waiter.sh` succeeds.
- Hand-driven, asserting on exit status: each of
  `until ! pgrep -f 'x/check.sh' >/dev/null 2>&1; do sleep 20; done`,
  `while pgrep -f 'x/check.sh'; do sleep 20; done`,
  `until ! ps aux | grep -q 'bash check.sh'; do sleep 8; done`,
  `until ! ps -ef | grep -q 'bash check.sh'; do sleep 8; done`, and
  `until ! ps aux | grep -q '[b]ash check.sh'; do sleep 8; done`
  exits 2 with stderr containing `kill -0`.
- Hand-driven, asserting exit 0: a bare `pgrep -f x`; a bare `ps aux | grep x`; a one-shot
  `if pgrep -f x; then echo up; fi`; the canonical
  `timeout 300 bash -c 'while kill -0 "$1" 2>/dev/null; do sleep 10; done' _ "$pid"`;
  `until ! ps -p "$pid" >/dev/null; do sleep 5; done`; and
  `until grep -q DONE build.log; do sleep 10; done`.
- Hand-driven fail-open: an empty payload, a non-JSON payload, and a payload with no
  `tool_input.command` each exit 0.

---

### Phase 2: Fixture suite [NOT STARTED]

**Goal**: `scripts/tests/test-validate-bounded-waiter.sh` drives the hook as a real subprocess and
proves, by fixture rather than by prose, every acceptance claim: all five must-block shapes
refused with exit 2 and a `kill -0`-carrying stderr message, every must-allow shape permitted, and
fail-open on internal error. Any matcher defect the fixtures expose is fixed in the hook.

**Tasks**:
- [ ] Create `agent-system/extensions/core/scripts/tests/test-validate-bounded-waiter.sh` per
      `context/standards/shell-script-testing.md`: Class B (`set -uo pipefail`), `pass()`/`fail()`/
      `info()` helpers with counters, a fresh `mktemp -d` workdir with `trap cleanup EXIT`, and the
      hook resolved source-store-first so the suite never silently tests a stale deployed copy.
- [ ] Drive the hook as a real subprocess with a `jq -n --arg`-built PreToolUse payload on stdin.
      Never instrument or modify the hook under test.
- [ ] Assert on **exit code** primarily (2 = blocked, 0 = allowed) — the
      `test-guard-destructive-git.sh` convention, correct here because this hook's only output
      channel is stderr; `test-detect-noop-bash.sh`'s stdout-JSON assertions do not apply. Assert
      additionally that each blocked case's **stderr** carries the `kill -0` idiom.
- [ ] Must-block cases, each exit 2 + `kill -0` in stderr: `until ! pgrep -f ...; do sleep ...; done`;
      the `while pgrep -f ...; do sleep ...; done` positive-test variant;
      `until ! ps aux | grep ...; do ... done`; `until ! ps -ef | grep ...; do ... done`; and the
      `[b]racket` variant of the `ps | grep` form.
- [ ] Flag-clustering regressions, each exit 2: `pgrep -af`, `pgrep -fa`, `pgrep -x -f`,
      `pgrep --full`, and bare `pgrep` with no flags, each inside a loop with a `sleep`. These
      exist to pin the bare-word ruling from Phase 1 so a future narrowing to an enumerated flag
      list fails loudly.
- [ ] Must-allow cases, each exit 0: a bare `pgrep`; a bare `ps aux | grep`; a one-shot
      `if pgrep -f ...; then ...; fi` outside any loop; the canonical `kill -0` waiter;
      `until ! ps -p "$pid" ...; do sleep ...; done` (a PID test, not a name match); a log-sentinel
      poll `until grep -q DONE log; do sleep 10; done`; and `echo idle` / bare `true` filler
      (asserting this hook does not reach into the adjacent no-op territory at all).
- [ ] Fail-open cases, each exit 0: `jq` masked off `PATH` (following `detect-noop-bash.sh`'s own
      `command -v jq` gate as the shape to replicate); empty stdin; non-JSON stdin; a well-formed
      payload with no `tool_input.command`.
- [ ] Add a one-off case asserting that a command carrying both `kill -0` and a name-match test
      inside a loop still blocks, pinning the no-exemption ruling.
- [ ] Record in the suite's own header that this file must be authored and edited with the
      Write/Edit tools, never a Bash heredoc: once the hook is deployed, a heredoc carrying these
      fixture strings is itself a blockable Bash command.
- [ ] Fix any matcher defect the fixtures expose in `hooks/validate-bounded-waiter.sh`, re-running
      the suite until green.
- [ ] Use no task-number references anywhere in the file.

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts roughly 20 fixture cases across one new suite file, with
the hook touched only for defect fixes. Confirm at implementation time by the suite's own reported
pass count and by `git status --short` showing exactly one new path under `scripts/tests/` plus at
most the already-created hook.

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-validate-bounded-waiter.sh,test-deploy-orphans.sh`
is the complete covering check — `suite_selection_select` resolves the new suite to itself by
self-identity and resolves the hook basename to that suite plus `test-deploy-orphans.sh` (verified
at plan time against the exactly-analogous `hooks/detect-noop-bash.sh` pair, which returns
`test-deploy-orphans.sh` and `test-detect-noop-bash.sh`), and nothing outside the hook and its own
suite is touched.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-validate-bounded-waiter.sh` - new fixture
  suite: must-block, flag-clustering, must-allow, and fail-open cases, driving the hook as a
  subprocess and asserting exit code plus stderr content
- `agent-system/extensions/core/hooks/validate-bounded-waiter.sh` - matcher defect fixes only, if
  the fixtures expose any

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-validate-bounded-waiter.sh` exits 0 with
  zero `FAIL` lines.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-validate-bounded-waiter.sh,test-deploy-orphans.sh`
  exits 0.
- `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh --verbose` exits 0.
- Every acceptance shape the task description enumerates has a named fixture case; confirm by
  enumerating the suite's case labels against that list, not by assertion.

---

### Phase 3: Registration and manifest wiring [NOT STARTED]

**Goal**: The hook is registered BARE in the one surface that reaches an already-deployed repo,
under the exact-string `"Bash"` matcher, and both the hook and its suite are declared in
`manifest.json`.

**Tasks**:
- [ ] Re-read `agent-system/extensions/core/merge-sources/settings-hooks.json` immediately before
      editing (a sibling task is dispatched on this same tree this cycle).
- [ ] Append one entry to the **existing** `hooks.PreToolUse` block whose `matcher` is exactly
      `"Bash"` — the block that today carries `guard-destructive-git.sh`. Do not create a new
      block; `deep_merge` dedupes on exact string equality and the merge is add-only, so any other
      spelling produces a second live registration nothing can later remove.
- [ ] Register BARE: `bash "$CLAUDE_PROJECT_DIR"/.claude/hooks/validate-bounded-waiter.sh`, with
      **no** `2>/dev/null || echo '{}'` wrapper. That wrapper converts exit 2 into exit 0 and
      silently disables the block. The PostToolUse entries in this same file do use it — copying
      the wrong neighbor is the silent failure to avoid.
- [ ] Add nothing to `root-files/settings.json`. Record the ruling: it is install-once
      (`INSTALL_ONCE_ROOT_FILES` in the loader), so an entry there reaches only a fresh install and
      can never be delivered into an already-deployed repo; a second copy there would be inert
      duplication, not consistency. `verify-deploy.sh`'s Gate 2 remediation string states the same
      direction verbatim.
- [ ] Add `validate-bounded-waiter.sh` to `manifest.json`'s `provides.hooks` array, alphabetically
      placed (between `validate-no-task-references.sh`... confirm the live ordering at edit time
      rather than trusting a precomputed slot).
- [ ] Declare the new suite in `manifest.json`'s `provides.scripts` by running the sanctioned
      derivation rather than hand-editing: `bash agent-system/extensions/core/scripts/sync-manifest-scripts.sh --check`
      to see the gap, then `--write` to insert it. `provides.scripts` is derived, not curated.
- [ ] **Decision point, to be ruled in-phase and recorded**: whether to add a reciprocal
      one-line cross-reference comment to `claude-refresh.sh`'s Family B header. Recommendation:
      add it, because a one-directional pointer leaves exactly the silent-drift path the
      acceptance criteria require closed — an editor of the reaper never sees the hook's comment.
      It is comment-only and changes no reaper behavior, so it does not breach the non-goal; it
      does require `bash .claude/scripts/update-task-status.sh --file-scope-add` first, which is
      the sanctioned mid-run re-scope path. If declined instead, state the reason and say
      explicitly what drift remains possible.
- [ ] Use no task-number references in either file.

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: interface

**Scope Hypothesis**: This phase asserts the change is two appended list entries plus one appended
registration object across two files — the regions task 282 and the other overlapping tasks do not
touch, so a rebase is trivial. Confirm with `git diff --stat` on the two files showing only
additions, and with `jq empty` on both files before committing.

**Tier Justification**: The changed region is two appended list entries and one appended
registration object whose enumerated direct dependents are exactly the three checks
`bash .claude/scripts/verify-deploy.sh --only-gate 2,21` (deployed hook-registration presence and
the hook-registration path lint) and
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-manifest-scripts-sync.sh,test-lint-hook-registration-paths.sh`
cover; nothing beyond that one-hop consumer set reads these two files' changed regions.

**Files to modify**:
- `agent-system/extensions/core/merge-sources/settings-hooks.json` - one bare entry appended to the
  existing exact-string `"Bash"` PreToolUse block
- `agent-system/extensions/core/manifest.json` - `validate-bounded-waiter.sh` added to
  `provides.hooks`; `tests/test-validate-bounded-waiter.sh` added to `provides.scripts` via
  `sync-manifest-scripts.sh --write`

**Verification**:
- `jq empty agent-system/extensions/core/merge-sources/settings-hooks.json` and
  `jq empty agent-system/extensions/core/manifest.json` both exit 0.
- `jq -r '.hooks.PreToolUse[] | select(.matcher=="Bash") | .hooks[].command' agent-system/extensions/core/merge-sources/settings-hooks.json`
  lists the new command, and the matched line contains neither `|| echo` nor `2>/dev/null`.
- The number of `hooks.PreToolUse` blocks is unchanged (no new matcher key created):
  `jq '.hooks.PreToolUse | length'` still reports 3.
- `bash agent-system/extensions/core/scripts/sync-manifest-scripts.sh --check` exits 0.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-manifest-scripts-sync.sh,test-lint-hook-registration-paths.sh`
  exits 0.
- The reciprocal-comment decision is recorded with its reason either way.

---

### Phase 4: Deploy, prove the hook fires, and run the full gate set [NOT STARTED]

**Goal**: The registration is verified BARE in the **deployed** `.claude/settings.json`, the
deployed hook is observed to actually block and to actually allow, every acceptance criterion is
discharged against evidence, and the complete gate set is green.

**Tasks**:
- [ ] Re-read both Phase 3 files immediately before deploying, in case a sibling has changed them.
- [ ] Deploy: `bash .claude/scripts/deploy-headless.sh`.
- [ ] Verify the entry reached the deployed file in bare form:
      `jq -r '.hooks.PreToolUse[] | select(.matcher=="Bash") | .hooks[].command' .claude/settings.json`
      contains the `validate-bounded-waiter.sh` line, and that line contains neither `|| echo` nor
      `2>/dev/null`. Assert on the grep's exit status, not on eyeballed output.
- [ ] Verify exactly ONE registration of this hook across the whole deployed settings file (no
      duplicate block created by a mis-spelled matcher): the count must be 1.
- [ ] Verify `.claude/hooks/validate-bounded-waiter.sh` exists, is executable, and is
      byte-identical to the source-store copy.
- [ ] Live-fire the DEPLOYED copy directly: pipe a `jq -n`-built payload carrying
      `until ! pgrep -f 'distsys/check.sh' >/dev/null 2>&1; do sleep 20; done` into
      `.claude/hooks/validate-bounded-waiter.sh`; assert exit 2 and stderr containing `kill -0`.
      Then pipe the canonical `kill -0` waiter and assert exit 0.
- [ ] Prove the **registration** fires end to end, not merely that the script works: issue one
      real Bash tool call whose command is
      `timeout 5 bash -c "until ! pgrep -f 'nonexistent-sentinel-xyz'; do sleep 1; done"` and
      observe the hook's stderr block and the refusal. The `timeout 5` wrapper is load-bearing: if
      the hook does **not** fire, that command self-matches and would spin, so the wrapper bounds
      the cost of a negative result to five seconds instead of a hang.
- [ ] Run the complete gate set: `bash .claude/scripts/verify-deploy.sh`, and confirm exit 0.
- [ ] Confirm the net pattern-document count did not increase: `git status --short` shows no new
      file under `agent-system/extensions/core/context/patterns/` and no modification to
      `bounded-build-waiter.md` (unless the Phase 3 decision point added a `file_scope` entry and
      a cross-reference, in which case state that it is a comment/cross-reference only and
      relaxes no rule).
- [ ] Confirm no task-number references landed outside `specs/**`:
      `bash .claude/scripts/check-task-references.sh` exits 0.
- [ ] Record in the implementation summary, as discharged rulings rather than observations: the
      Rule 4 scope-out with its lifecycle reason; the shared-library rejection with its reason and
      the drift-closure mechanism actually chosen; the governing-registration-surface answer with
      its three confirmations; the Family B inventory asymmetry in both directions; and the
      neighbor-status correction (the completed adjacent task left `detect-noop-bash.sh`
      PostToolUse and advisory, so no gate collision exists). Record the out-of-scope
      recommendation that the sibling record-versioning hook task's declared registration surface
      is the one that cannot reach a deployed repo.

**Timing**: 1 hour

**Depends on**: 2, 3

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts it modifies no source-store file — only `.claude/**`, a
disposable deploy artifact regenerated by the deploy. Confirm with `git status --short` showing no
modification under `agent-system/` attributable to this phase.

**Files to modify**:
- none planned - deploy and verification only; `bash .claude/scripts/deploy-headless.sh`
  regenerates `.claude/**`, which is a disposable deploy artifact and never a hand-edit target

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` exits 0 — the complete gate set this tier requires,
  including Gate 2 (deployed hook registrations), Gate 8 (the full shell-suite battery, which
  includes the new suite), Gate 21 (hook registration path lint) and Gate 22 (shellcheck lint).
  Do not substitute `--skip-slow` or an `--only-gate` subset: a narrowed pass is not evidence the
  full run would be green.
- The deployed-registration greps above all exit 0, with the bare form confirmed by the **absence**
  of `|| echo` on this entry and the registration count equal to 1.
- The deployed hook live-fires: exit 2 with the `kill -0` idiom on the incident command, exit 0 on
  the canonical waiter.
- The real Bash tool call is refused by the registered hook, observed directly.
- `bash .claude/scripts/check-task-references.sh` exits 0.

---

## Testing & Validation

- [ ] All five must-block shapes refused with exit 2 and a stderr message carrying the `kill -0`
      canonical idiom inline, including the `[b]racket` variant — demonstrated by fixture.
- [ ] A bare `pgrep`, a bare `ps aux | grep`, a one-shot name-match conditional outside a loop,
      and the canonical `kill -0` waiter all allowed — demonstrated by fixture, not asserted in
      prose.
- [ ] A `ps -p "$pid"` loop, a log-sentinel poll, and no-op filler commands all allowed —
      demonstrated by fixture, pinning the adjacent-territory boundaries.
- [ ] Flag-clustering variants (`-af`, `-fa`, `-x -f`, `--full`, no flags) all blocked —
      demonstrated by fixture, pinning the bare-word ruling.
- [ ] Fail-open on `jq` absent, empty stdin, non-JSON stdin, and a payload with no
      `tool_input.command` — each exit 0, demonstrated by fixture.
- [ ] `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh --verbose` exits 0 for
      both new files (Class A hook, Class B suite).
- [ ] Registration verified BARE in the **deployed** `.claude/settings.json`, exactly once, under
      the exact-string `"Bash"` matcher, with the hook confirmed to actually fire.
- [ ] `bash .claude/scripts/verify-deploy.sh` exits 0.
- [ ] Net pattern-document count unchanged; no new or amended pattern document.
- [ ] No task-number references in any file landing outside `specs/**`.
- [ ] The Rule 4 ruling and the shared-library ruling are both recorded, each with its reason.

## Artifacts & Outputs

- `agent-system/extensions/core/hooks/validate-bounded-waiter.sh` - the blocking PreToolUse Bash
  hook
- `agent-system/extensions/core/scripts/tests/test-validate-bounded-waiter.sh` - the fixture suite
- `agent-system/extensions/core/merge-sources/settings-hooks.json` - one bare registration appended
- `agent-system/extensions/core/manifest.json` - hook and suite declared
- `specs/347_self_match_waiter_pretooluse_block_hook/summaries/01_self-match-waiter-hook-summary.md` -
  implementation summary carrying the four recorded rulings
- No new `context/` or pattern document, by design

## Rollback/Contingency

The hook is inert until registered, and the registration is one appended object, so rollback is
cheap at every stage:

- **A false positive observed after deploy** (the one outcome this task treats as worse than no
  hook): remove the `validate-bounded-waiter.sh` entry from
  `agent-system/extensions/core/merge-sources/settings-hooks.json` and from the deployed
  `.claude/settings.json`, then re-run `bash .claude/scripts/deploy-headless.sh`. The hook file and
  its `provides.hooks` declaration may stay — an unregistered hook present on disk is inert and is
  not a lint violation. Then add the false-positive command as an allow fixture and re-tighten the
  conjunction before re-registering.
- **A source-store defect found before deploy**: `git revert` the phase commits for the two new
  files and the two wiring files. No deployed state is involved.
- **A genuine working-tree rollback is needed**: take a snapshot first per
  `context/contracts/recovery.md`'s rollback rung, using the invocation shape recorded there
  (including its out-of-scope override flag for a deliberate whole-tree case). Do not emit a bare
  reverting `git-snapshot.sh` call as a routine checkpoint; for an ordinary defensive checkpoint
  before Phase 4's deploy, use the `--no-revert` form instead.
- **Deploy produced a duplicate registration** (a mis-spelled matcher): the add-only merge cannot
  remove it, so this requires a manual edit of the deployed `.claude/settings.json` to delete the
  stray block plus a correction in the source fragment. Phase 4's count-equals-1 assertion exists
  to catch this at the moment it happens rather than later.
