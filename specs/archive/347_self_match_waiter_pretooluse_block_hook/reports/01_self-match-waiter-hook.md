# Research Report: Task #347

**Task**: 347 - Turn bounded-build-waiter.md Rule 2 into a blocking PreToolUse Bash hook
**Started**: 2026-10-11
**Completed**: 2026-10-11
**Effort**: medium (one hook + fixture test + manifest/registration wiring; no new pattern doc)
**Dependencies**: None (task 282's file_scope overlap on the same two files is deliberately
un-sequenced per the task description; task 282 is still `not_started`, confirmed below)
**Sources/Inputs**: Codebase (agent-system/extensions/core/hooks/, scripts/claude-refresh.sh,
merge-sources/settings-hooks.json, root-files/settings.json, manifest.json,
context/patterns/bounded-build-waiter.md, lua/neotex/plugins/ai/shared/extensions/merge.lua,
specs/state.json)
**Artifacts**: This report (`specs/347_self_match_waiter_pretooluse_block_hook/reports/01_self-match-waiter-hook.md`)
**Standards**: report-format.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md,
shell-script-testing.md, shell-strict-mode.md

## Executive Summary

- The mechanism precedent (`hooks/guard-destructive-git.sh`) and the enforcement-shape precedent
  (`hooks/validate-no-task-references.sh`) are both PreToolUse, block via `exit 2` + stderr, fail
  open, and are registered **bare**. The new hook should structurally mirror
  `validate-no-task-references.sh` most closely: a single-purpose argv/content scan with no
  hazard-class branching, which is a better-fitting precedent than the multi-hazard
  `guard-destructive-git.sh`.
- **Registration target is settled and already reflected in task 347's `file_scope`**:
  `agent-system/extensions/core/merge-sources/settings-hooks.json`, under the existing exact-string
  `"Bash"` matcher block (which already carries `guard-destructive-git.sh`) — confirmed against
  `scripts/verify-deploy.sh`'s own remediation string and the `INSTALL_ONCE_ROOT_FILES` semantics
  in `loader.lua`. `root-files/settings.json` is a first-install-only template; a registration
  placed there cannot reach an already-deployed consumer repo's `.claude/settings.json`.
- **Hook and test filenames are already fixed** in `specs/state.json`'s `file_scope` for this task:
  `hooks/validate-bounded-waiter.sh` and `scripts/tests/test-validate-bounded-waiter.sh`. No naming
  decision remains open.
- **Finding with plan-level consequence**: `scripts/claude-refresh.sh`'s Family B classifier
  (`build_waiter_family()`, ~line 1655) matches only `(until|while) + "grep -q" + sleep`. Its own
  header comment names `until ! ps aux | grep -q ...` as a covered shape, but the **actual
  motivating incident command**, `until ! pgrep -f 'distsys/check.sh' ...; do sleep 20; done`,
  contains no `grep -q` substring at all (`pgrep -f` != `grep -q`) and is **not** matched by the
  existing reaper classifier. "Derive the hook's matcher from that inventory" is therefore only
  partially satisfiable — `pgrep -f` detection cannot be copied from claude-refresh.sh; it must be
  added independently to the new hook.
- Task 282 (the closest sibling in shape — a bare-registered PreToolUse exit-2 hook with a
  fail-open guard and fixture test) is confirmed still `not_started` in `specs/state.json`. There
  is no landed house pattern to defer to; this task establishes it.
- Rule 4 ("one waiter per log") is enforceable only at reap time, not at PreToolUse write time,
  for a concrete, evidenced reason (see Findings) — recommend scoping it out of the hook with that
  stated reason, pointing at claude-refresh.sh's existing staleness-bounded reaper as where the
  enforcement already lives.
- A true shared pattern-inventory library (the `task-reference-patterns.sh` precedent) is not
  achievable within this task's declared `file_scope`, because the second "consumer" would be
  `scripts/claude-refresh.sh`, which is both out of scope and an explicit non-goal to modify.
  Recommend rejecting the shared-library option with a stated reason, and closing the
  silent-drift risk via a documented cross-reference comment instead of shared code.

## Context & Scope

Researched what the implementation phase needs to build, register, and test a BLOCKING
PreToolUse Bash hook enforcing `bounded-build-waiter.md` Rule 2 (never use `pgrep -f`/`ps | grep`
liveness tests inside a wait loop), per the dispatch's deliverables, acceptance criteria, and
explicit non-goals (no new pattern document; no change to `bounded-build-waiter.md`,
`claude-refresh.sh`'s reaper, or the consumer repo's gate script). Research covered: the two
candidate structural precedents named in the dispatch and their actual exit/registration
contracts; the two candidate registration surfaces and which one is live for an already-deployed
tree; the existing Family B pattern inventory in `claude-refresh.sh` and whether it actually
covers the shapes this hook must block; the status of the sibling task (282) whose file_scope
overlaps this one; and the Rule 4 ("one waiter per log") lifecycle question the dispatch requires
an explicit ruling on. No code was written; this is a research-only dispatch.

## Findings

### Codebase Patterns

**`hooks/guard-destructive-git.sh`** (named as the MECHANISM precedent) is a multi-hazard-class
guard: it blocks several independent destructive-git shapes (reset --hard, checkout -- discard,
stash drop, over-staging, forced checkout/switch, plus a separately-gated history-rewrite
predicate), each with its own `REASON`/`OVERSTAGE_REASON` variable, ending in a shared
`echo "BLOCKED: $REASON" >&2; exit 2` block. It fails open on empty `tool_input.command` (non-Bash
tool or parse failure) and supports a snapshot-marker exemption mechanism this task's hook has no
analog for (there is no "fresh snapshot" concept for a wait-loop command). Confirmed: registered
bare, no `2>/dev/null || echo '{}'` wrapper, in both `merge-sources/settings-hooks.json` and
`root-files/settings.json` under `matcher: "Bash"`.

**`hooks/validate-no-task-references.sh`** (the dispatch's "live demonstration of the target
convention") is structurally the **closer** fit for this task: single hazard class (task-number
citation), parses stdin once, delegates all pattern/exemption logic to a sourced shared library
(`scripts/lib/task-reference-patterns.sh`), fails open on three independent conditions (library
missing, library fails to source, no file_path resolved / no content captured), and on a match
prints a multi-line actionable stderr block naming the rule file, the mechanism, and the
remediation path, then calls `system-defect-record.sh` (non-fatally) before `exit 2`. Unlike
`guard-destructive-git.sh` it has exactly one match surface (content against two patterns) and no
internal hazard-class branching — this task's hook (one conjunction: loop + name-match + sleep)
should follow this shape rather than `guard-destructive-git.sh`'s multi-branch one. Both
precedents agree on the core contract the dispatch already states: `exit 2` + stderr (never
`permissionDecision: deny`), bare registration, fail open on internal error.

**`hooks/detect-noop-bash.sh`** (named by the originating request, and correctly disclaimed by
the dispatch) confirms by contrast why it is the wrong mechanism model: it is PostToolUse,
unconditionally `exit 0`, and its only output channel is `{}` or `{additionalContext: ...}` on
stdout — it structurally cannot block anything. It remains a useful reference for the
per-session state-file idiom (`NOOP_BASH_STATE_DIR`, `.claude/tmp/<purpose>-<session>` precedent)
relevant to the Rule 4 assessment below, and for the "fresh `mktemp -d` test workdir,
`trap cleanup EXIT`, `pass`/`fail`/`info` counters" fixture-testing convention both
`test-detect-noop-bash.sh` and `test-guard-destructive-git.sh` share.

**Test-fixture convention** (`scripts/tests/test-detect-noop-bash.sh`,
`scripts/tests/test-guard-destructive-git.sh`): both drive the hook as a real subprocess via a
`jq -n --arg`-built synthetic payload on stdin, never instrument or modify the hook under test,
and follow `context/standards/shell-script-testing.md`'s `pass()/fail()/info()` + counter
convention. Critically, `test-guard-destructive-git.sh` asserts on **exit code** (2 = blocked, 0 =
allowed), not stdout, because its hook's only output channel is stderr diagnostics — this is the
correct template for `test-validate-bounded-waiter.sh` (a blocking, exit-2-based hook), not
`test-detect-noop-bash.sh`'s stdout-JSON-based assertions. `test-guard-destructive-git.sh` also
notes a load-bearing environmental precondition it must self-check first (a genuinely dirty git
repo, since the hook vacuously allows on a clean tree) — this task's hook has an analogous
precondition risk worth flagging for the plan: none of its block/allow predicates depend on
working-tree state, so no equivalent fixture precondition is needed, but the malformed/absent-
dependency fail-open case (required by the dispatch's acceptance criteria) does need a deliberate
fixture (e.g. simulate a missing `jq` on `PATH`, following `detect-noop-bash.sh`'s own
`command -v jq` fail-open gate as the shape to replicate).

**`manifest.json` wiring precedent**: `provides.hooks` and the tests list are flat, alphabetically
ordered arrays of bare filenames (hooks) / `tests/<name>.sh` paths (tests). `detect-noop-bash.sh`
sits at line ~322 in `hooks`, `tests/test-detect-noop-bash.sh` at line ~228 in the tests list — a
one-line addition to each, alphabetically placed (`validate-bounded-waiter.sh` sorts after
`update-task-status.sh`/`uninstall-extension.sh` and before `verify-deploy.sh` in the tests-adjacent
scripts list context, and among the hooks array alongside `validate-no-task-references.sh`/
`please-grant.sh`/etc. — exact alphabetical slot to be confirmed at edit time against the live
array, not pre-computed here).

**Registration surface — settled, with independent confirmation beyond the dispatch's own
correction note**: `agent-system/extensions/core/merge-sources/settings-hooks.json`'s
`hooks.PreToolUse` array already contains an exact-string `"Bash"` matcher block (currently
`guard-destructive-git.sh` only) and a separate `"Write|Edit"` block
(`validate-no-task-references.sh`) — confirming the dispatch's claim that this file omits the
bare `"Write"` block present in `root-files/settings.json`. The deployed `.claude/settings.json`
in this repo was read directly and matches `root-files/settings.json`'s block set exactly
(`Write`, `Bash`, `Write|Edit`, `Bash|Write|Edit`) — confirming the dispatch's observation that the
match is coincidental (first-install snapshot), not evidence of which surface governs updates.
`scripts/verify-deploy.sh` (~line 331-332) independently states, in its own NOT-registered
remediation string: *"add it to merge-sources/settings-hooks.json, not root-files/settings.json"*.
`lua/neotex/plugins/ai/shared/extensions/merge.lua`'s `deep_merge`/matcher-normalization logic
(confirmed by reading `normalize`/merge functions around lines 255-340, 499-531) dedupes
`hooks.PreToolUse` blocks by **exact string-equal `matcher`** and concatenates each matching
block's `hooks` array in first-appearance order — confirming the correction note's claim that the
matcher string must be spelled exactly `"Bash"` (not `"Bash "`, not a different casing/ordering in
a compound matcher) or a second, never-mergeable block would be created.

**`specs/state.json` already reflects the registration-surface correction**: task 347's
`file_scope` is `["agent-system/extensions/core/hooks/validate-bounded-waiter.sh",
"agent-system/extensions/core/scripts/tests/test-validate-bounded-waiter.sh",
"agent-system/extensions/core/merge-sources/settings-hooks.json",
"agent-system/extensions/core/manifest.json"]` — `root-files/settings.json` is correctly absent.
No further file_scope action is needed on this point.

**Task 282 status** — confirmed via `specs/state.json`: `project_number: 282`,
`status: "not_started"`. Tasks 280 (`completed`), 281 (`not_started`), 313 (`not_started`). The
dispatch's "check whether it has landed before designing from scratch" is answered: it has not.
This task is free to establish the house pattern without reconciling against an already-landed
282 implementation.

**`bounded-build-waiter.md` Rule 2/3/4 and canonical idiom** (read directly, lines ~16-74):
confirmed verbatim against the dispatch's citations. Symptom 3 (`[b]ash check.sh` bracket trick)
explicitly states the bracket only stops grep from matching itself, not the parent shell — the
hook's matcher must not special-case a bracketed grep pattern as "safe," it must simply not
require an *unbracketed* pattern to recognize the `ps ... | grep` shape in the first place (the
shape-level conjunction test below doesn't need to inspect the grep pattern's contents at all).

### Claude-Refresh.sh Family B Classifier — Gap Finding

`build_waiter_family()` (scripts/claude-refresh.sh, function starting ~line 1648, confirmed by
direct read) is:

```
if [[ "$args" == *"kill -0"* && "$args" == *"sleep"* ]]; then ... Family A ...
if [[ ( "$args" == *"until"* || "$args" == *"while"* ) && "$args" == *"grep -q"* && "$args" == *"sleep"* ]]; then ... Family B ...
```

A direct `grep -n "pgrep"` over the whole 2444-line file returns exactly **one** hit — the header
comment at line 1577, which is prose only. There is no code branch recognizing `pgrep -f` at all.
The motivating incident command literally contains neither `grep -q` nor any token matching
`*"grep -q"*` — `pgrep -f 'distsys/check.sh'` has no `-q` flag and the substring `pgrep -f` does
not contain `grep -q` as a contiguous substring. **The existing, "already-validated" pattern
inventory does not catch the shape this task exists to prevent.** This is recorded as an issue
(`issue-record.sh`, class `requirement_gap`, severity `costly`) during this research dispatch.

Consequence for the plan: the new hook cannot simply port `build_waiter_family()`'s Family B
branch — it must independently add `pgrep -f`/`pgrep -af`/`pgrep -fa`-style flag detection (any
ordering/clustering that includes `-f`) alongside the `ps aux | grep` / `ps -ef | grep` shape
`build_waiter_family` already covers via its generic `"grep -q"` substring test. Note also that
`build_waiter_family`'s test is itself narrower than `ps | grep` in general — it requires the
literal substring `grep -q`, so a `ps aux | grep -i 'bash check.sh'` (no `-q`) wait loop would
*also* already evade the existing reaper classifier. This is additional evidence that treating
the reaper's inventory as a complete, reusable source is unsafe; it is directional guidance (the
three named shape *families*), not a drop-in regex set.

### External Resources

None consulted — this is an internal-codebase-only mechanism task; no external documentation was
relevant to hook structure, jq payload parsing, or Claude Code's PreToolUse contract beyond what
is already recorded in the two precedent hooks and `context/patterns/bounded-build-waiter.md`.

## Decisions

- **Structural model**: follow `validate-no-task-references.sh`'s single-hazard-class shape
  (parse stdin once, one conjunction test, one `exit 2` + multi-line stderr block, fail open on
  every parse/dependency failure) rather than `guard-destructive-git.sh`'s multi-branch
  hazard-class structure — the latter exists to handle several *independent* destructive shapes
  sharing one file; this task has exactly one shape (a 3-way conjunction: loop keyword + sleep +
  name-match liveness test), which does not need that branching.
- **Registration target**: `merge-sources/settings-hooks.json`'s existing exact-string `"Bash"`
  matcher block, confirmed by three independent sources (dispatch correction, `verify-deploy.sh`'s
  own remediation string, `loader.lua`'s `INSTALL_ONCE_ROOT_FILES` semantics) — not re-litigated
  here, only re-confirmed per the dispatch's own "CONFIRM rather than assume" instruction.
  `root-files/settings.json` should receive **no** corresponding entry: it is a first-install
  template only, and adding the entry there would create a second, non-governing copy with no
  update path into an already-deployed tree — not a consistency requirement, but a known-inert
  duplication to avoid.
- **Shared pattern-inventory library**: **rejected** for this task. The `task-reference-patterns.sh`
  precedent requires a second real consumer to source the same file; the only candidate second
  consumer is `scripts/claude-refresh.sh`, which is both outside this task's `file_scope` and an
  explicit non-goal ("Do NOT change claude-refresh.sh's reaper behavior"). Building a library file
  that only the new hook sources is not a "shared" library at all — it would be an unused
  abstraction. Recommend instead: a header-comment cross-reference in the new hook naming
  `claude-refresh.sh`'s `build_waiter_family()` by name/line and explicitly stating the two
  inventories are independently maintained and the `pgrep -f` gap found during research — this
  closes the "cannot silently drift apart" requirement via documentation that is *read by a future
  editor of either file*, which is the realistic drift-prevention mechanism available without
  touching an out-of-scope file. If a future task wants a true shared library, it would need to
  add `claude-refresh.sh` to its own `file_scope` and accept sourcing a library from a
  `ps -eo args`-column context (reap time) and a `tool_input.command`-string context (write time)
  — two different input shapes feeding one matcher, which is more involved than the
  `task-reference-patterns.sh` precedent (both of whose consumers already receive plain text).
- **Rule 4 ("one waiter per log")**: scope out of the PreToolUse hook, with the lifecycle reason
  the dispatch anticipates — a PreToolUse hook observes only waiter *starts*, never waiter *exits*,
  so any "this log/PID already has a waiter" record it writes goes stale the instant that waiter
  exits, with no event to clear it. A naive record would falsely reject a legitimate second,
  *sequential* wait on the same log — exactly the false-positive class this task treats as worse
  than no hook. A short-TTL staleness bound does not resolve this cleanly either: the legitimate
  wait duration varies by build/gate size (the task's own Rule 1 sizes `timeout N` to "the
  command's expected run time"), so no fixed TTL is safely shorter than every legitimate wait and
  longer than every dead-waiter gap. Recommend recording this as the stated reason and pointing at
  `claude-refresh.sh`'s existing `BUILD_WAITER_REAP_MIN`-gated reaper (default 60 minutes,
  `run_build_waiter_pass`) as where "one waiter per log" is already enforced in practice — at reap
  time, against a live process snapshot, where a true liveness/idleness signal exists that
  write-time observation structurally cannot have.
- **Hook/test filenames**: already fixed by `specs/state.json`'s `file_scope` —
  `hooks/validate-bounded-waiter.sh`, `scripts/tests/test-validate-bounded-waiter.sh`. No
  alternative naming should be introduced.

## Recommendations

1. Implement `agent-system/extensions/core/hooks/validate-bounded-waiter.sh` as a `set -euo
   pipefail` (Class A per `context/standards/shell-strict-mode.md`) PreToolUse hook that: reads
   `tool_input.command` from stdin via `jq` (fail open on missing `jq`, empty command, or parse
   failure — mirroring `validate-no-task-references.sh`'s layered fail-open checks); classifies
   the command as blocking **only** when all three of (a) a `until`/`while` loop keyword, (b) a
   `sleep` call, and (c) a name-match liveness test (`pgrep` with a `-f` flag in any
   ordering/clustering, OR a `ps` invocation — `aux`/`-ef`/other column forms — piped into `grep`)
   are present in the same command text; and treats a bracket-obfuscated grep pattern (e.g.
   `grep '[b]ash check.sh'`) identically to an unbracketed one (the shape test does not need to
   inspect the grep pattern's contents at all, so there is nothing to special-case).
2. On a match, `exit 2` with a stderr block that: states what was blocked and why (the self-match
   mechanism, in one line); names `bounded-build-waiter.md` Rule 2 by filename; and inlines the
   canonical idiom verbatim (`cmd >log 2>&1 & pid=$!` / `timeout N bash -c 'while kill -0 "$1"
   2>/dev/null; do sleep 10; done' _ "$pid"`) — not merely a pointer to it, per the dispatch's
   explicit requirement.
3. On any internal error (missing `jq`, malformed/absent stdin, unexpected payload shape), `exit
   0` — fail open, matching every precedent hook's contract.
4. Add a header-comment cross-reference to `claude-refresh.sh`'s `build_waiter_family()` (by
   function name and approximate line) recording: (a) this hook's matcher and the reaper's Family
   B classifier are independently maintained, not shared code, with the Decisions-section
   rationale restated briefly; (b) the `pgrep -f` gap found during this research, so a future
   reader of either file does not assume the two already agree.
5. Write `scripts/tests/test-validate-bounded-waiter.sh` following `test-guard-destructive-git.sh`'s
   exit-code-assertion convention (not `test-detect-noop-bash.sh`'s stdout-JSON convention), via a
   `jq -n --arg`-built PreToolUse payload subprocess call. Required cases per the dispatch's
   acceptance criteria: each of the four MUST-block shapes (`until`/`while` × `pgrep -f` and `ps
   aux|/-ef| grep`, including the bracket variant) rejected with exit 2 and stderr carrying the
   `kill -0` idiom; a bare `pgrep -f ...` (no loop, no sleep) allowed; a bare `ps aux | grep ...`
   (no loop, no sleep) allowed; a one-shot `if pgrep -f ...; then ...; fi` (no loop keyword)
   allowed; the canonical `kill -0` waiter allowed; and a fail-open case (simulate missing `jq` on
   `PATH`, following `detect-noop-bash.sh`'s own `command -v jq` gate) exiting 0.
6. Register the hook in `agent-system/extensions/core/merge-sources/settings-hooks.json`'s existing
   exact-string `"Bash"` matcher block (append a second entry to that block's `hooks` array,
   alongside `guard-destructive-git.sh`) — bare, no `2>/dev/null || echo '{}'` wrapper. Do not add
   anything to `root-files/settings.json`.
7. Add `validate-bounded-waiter.sh` to `manifest.json`'s `provides.hooks` array and
   `tests/test-validate-bounded-waiter.sh` to its tests list, alphabetically placed among the
   existing entries.
8. Verify by deploying (the repo's own deploy/reload path) and grepping the resulting
   `.claude/settings.json` for the new entry under the `"Bash"` matcher in bare form (no `|| echo`
   wrapper nearby), confirming the hook actually fires — per the dispatch's acceptance criteria,
   this is a required verification step, not optional.
9. Record Rule 4 as explicitly scoped out of this hook, with the lifecycle reason above, in the
   plan/implementation artifacts — this is a ruling the task owes per its own acceptance criteria,
   not a silent omission.
10. Run `shellcheck` against the new hook and test file per `context/standards/shell-strict-mode.md`
    (Class A for the hook; the test file should default to Class B — `set -uo pipefail` with
    `PASSED`/`FAILED` counters — matching `test-guard-destructive-git.sh`/`test-detect-noop-bash.sh`'s
    own classification).

## Risks & Mitigations

- **False positive on a legitimate one-shot diagnostic.** Mitigated by requiring the full 3-way
  conjunction (loop keyword + sleep + name-match test) rather than any single element; every
  required-block example in the dispatch already contains all three, and every required-allow
  example lacks at least one.
- **Flag-clustering evasion for `pgrep -f`** (e.g. `-af`, `-fa`, `-x -f`, a long-form `--full`
  variant). Recommend the implementation phase test these clustering variants explicitly rather
  than relying on a single literal-substring check; this is a plan-level detail, not resolved in
  this research pass.
- **Registering in the wrong surface silently disables the hook.** Mitigated by the triple
  confirmation above (dispatch correction, `verify-deploy.sh` remediation string, `loader.lua`
  semantics) and by the explicit deploy-and-grep verification step (Recommendation 8), which the
  dispatch's acceptance criteria already requires.
- **Treating `claude-refresh.sh`'s inventory as authoritative would under-build the hook.**
  Mitigated by the Family B gap finding above and by not porting that classifier verbatim.
- **A future shared-library refactor silently drifting the two inventories apart.** Mitigated by
  the recommended cross-reference comment (Recommendation 4), which is the realistic
  drift-prevention mechanism available given `claude-refresh.sh` is out of this task's file_scope.

## Context Extension Recommendations

None. The dispatch's explicit non-goal ("Do NOT add a new context/pattern document, and do not
restate Rule 2 in new prose") applies with equal force to context-extension proposals — this
section records that the non-goal was considered and deliberately not acted on, not that no gap
exists to note.

## Appendix

- Files read directly: `agent-system/extensions/core/hooks/guard-destructive-git.sh`,
  `agent-system/extensions/core/hooks/validate-no-task-references.sh`,
  `agent-system/extensions/core/hooks/detect-noop-bash.sh`,
  `agent-system/extensions/core/scripts/claude-refresh.sh` (lines ~1550-1690),
  `agent-system/extensions/core/scripts/tests/test-detect-noop-bash.sh`,
  `agent-system/extensions/core/scripts/tests/test-guard-destructive-git.sh`,
  `agent-system/extensions/core/context/patterns/bounded-build-waiter.md` (lines 1-90),
  `agent-system/extensions/core/context/standards/shell-strict-mode.md`,
  `agent-system/extensions/core/scripts/lib/task-reference-patterns.sh`,
  `agent-system/extensions/core/manifest.json` (hooks/tests arrays),
  `agent-system/extensions/core/merge-sources/settings-hooks.json`,
  `agent-system/extensions/core/root-files/settings.json`, deployed `.claude/settings.json`,
  `lua/neotex/plugins/ai/shared/extensions/merge.lua` (matcher-dedup logic),
  `agent-system/extensions/core/scripts/verify-deploy.sh` (remediation string),
  `specs/state.json` (task 347, 282, 280, 281, 313 entries).
- Shell commands used: direct `grep -n "pgrep\|ps aux\|ps -ef"` over the full
  `scripts/claude-refresh.sh` to establish the Family B gap; `jq` queries against
  `.claude-extensions.json` and `specs/state.json`.
- Issue recorded: `requirement_gap` / `costly` — claude-refresh.sh Family B classifier does not
  match the `pgrep -f` shape (see Findings).
