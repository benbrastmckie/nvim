# Research Report: Task #234

**Task**: 234 - Fix state-write.sh spill name collision
**Started**: 2026-09-17T00:00:00Z
**Completed**: 2026-09-17T00:00:00Z
**Effort**: small (single-file fix + regression test + caller audit)
**Dependencies**: None
**Sources/Inputs**: - Codebase (`agent-system/extensions/core/scripts/state-write.sh` and its 20+
  live callers), git history, a sandboxed reproduction against a throwaway fixture root, and
  `context/standards/shell-script-testing.md` / `shell-strict-mode.md`
**Artifacts**: - `specs/234_fix_state_write_spill_name_collision/reports/01_spill-name-collision.md`
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Root cause confirmed exactly as described in the dispatch, and independently **reproduced
  twice more** in a throwaway fixture root (never touching the real `specs/state.json`): the
  `--argjson-file` branch (`state-write.sh:226`, `private_name="__spill_${#SPILL_FILES[@]}"`)
  never appends to `SPILL_FILES`, so its counter is permanently `0`. A pure multi-`--argjson-file`
  call collapses every binding to the first file's value; a *mixed* `--argjson-file` +
  oversized-`--argjson` call collapses the auto-spilled binding onto the file-spilled one instead
  (reproduced below — the auto-spill binding silently picked up the file's 9-byte value instead
  of its own 110,000-byte payload).
- Underlying jq mechanism confirmed by direct test: `jq --slurpfile s f1.json --slurpfile s
  f2.json '$s'` returns **f1's value** (first-wins), which is why every corrupted binding lands
  on the *first* spilled value, matching the dispatch's "all six records received the FIRST
  description" observation exactly.
- **Caller audit (complete — see Findings): no currently-shipped caller has ever hit this bug.**
  No live `.sh`/`.md` call site outside the script's own test file uses `--argjson-file` at all.
  Every live call site that passes 2+ `--argjson` bindings in one `state-write.sh` invocation
  either (a) is mutually exclusive by construction (`update-task-status.sh`), or (b) pairs one
  large, potentially-spillable value with a small integer (task number) that can never cross the
  100,000-byte `SPILL_THRESHOLD`, so at most one binding can ever spill in those calls. Two
  quarantined dead-code scripts (`scripts/deprecated/vault-operation.sh`,
  `scripts/deprecated/archive-task.sh`) and one live prose call site
  (`commands/todo.md` Step 5.7.8) pass two `--argjson` integers in one call, but both are always
  far under the threshold. **No corrupted `specs/state.json` data was found or is suspected from
  this defect** — the two reproductions in the dispatch's own "OBSERVED" section came from manual,
  deliberate invocation during bug investigation, not from a caller in the wild.
- Existing precedent for the fix's regression test already exists: `test-state-write-large-payload.sh`
  is a byte-for-byte-copy, fixture-rooted suite (copies `state-write.sh`, `task-lock.sh`,
  `generate-todo.sh`, `deploy-root-guard.sh`, `lib/common.sh`, `lib/task-lookup-lib.sh` into a
  `mktemp -d` root) that already exercises `--argjson-file` and the auto-spill path in detail. The
  new regression test should follow this exact pattern (confirmed working below).
- **Location-convention conflict**: the dispatch's ACCEPTANCE text says the test belongs "under
  `scripts/tests/`", but `context/standards/shell-script-testing.md`'s own location rule plus the
  three existing `test-state-write-*.sh` suites' actual location say otherwise — see Decisions.

## Context & Scope

Scope is exactly as stated in the dispatch: repair spill-name allocation in
`agent-system/extensions/core/scripts/state-write.sh` (the deployed `.claude/scripts/` copy is
gitignored and regenerated, never hand-edited), add a regression test proving both the
pure-multi-`--argjson-file` case and the mixed `--argjson-file`+`--argjson` case fail before the
fix and pass after, and audit existing callers for already-corrupted data. Out of scope: mutex
protocol, staging/mv sequence, `--state-file`/`--init`/`--regen-todo` contracts, the jq filter
interface callers rely on (i.e. `$NAME` must keep resolving exactly as today for every existing
caller).

## Findings

### Root cause (confirmed, with exact line numbers)

`agent-system/extensions/core/scripts/state-write.sh`:

- `--argjson` branch (oversized-value auto-spill), lines ~205-213: on spill, computes
  `private_name="__spill_${#SPILL_FILES[@]}"`, forwards `--slurpfile "$private_name" "$spill_file"`,
  **then appends** `spill_file` to `SPILL_FILES`, the private name to `SPILL_PRIVATE_NAMES`, and
  the caller's own name to `SPILL_PUBLIC_NAMES`. Its counter (`${#SPILL_FILES[@]}`) advances
  correctly *for itself*.
- `--argjson-file` branch, lines ~216-227: computes the *same* expression,
  `private_name="__spill_${#SPILL_FILES[@]}"`, and forwards `--slurpfile`, but **never appends to
  `SPILL_FILES`** — there is nothing to `mktemp`/clean up, since the caller supplied the file
  directly. It does append to `SPILL_PRIVATE_NAMES`/`SPILL_PUBLIC_NAMES` (correctly, for the
  `EFFECTIVE_FILTER` prefix-injection loop later). Because `SPILL_FILES` never grows here,
  `${#SPILL_FILES[@]}` is `0` on every `--argjson-file` call, so **every** `--argjson-file`
  binding is named `__spill_0`.
- This also explains the "mixed case" the dispatch calls out as the subtler half: the shared
  expression means an `--argjson-file` binding *consumes* index N (by using it) without
  *advancing* the counter that only the `--argjson` branch increments via `SPILL_FILES`. A
  subsequent `--argjson` auto-spill in the same call then computes the same N and collides with
  the `--argjson-file` binding that already claimed it.
- `EFFECTIVE_FILTER` construction (lines ~230-238) is not itself buggy — it correctly iterates
  `SPILL_PRIVATE_NAMES`/`SPILL_PUBLIC_NAMES` in order and builds one `($priv[0]) as $pub | ...`
  clause per entry. The bug is entirely upstream: those parallel arrays end up holding duplicate
  private names, so the prefix ends up injecting two (or more) `as $NAME` clauses that all read
  from the *same* jq `--slurpfile` binding name.
- jq's own behavior for a duplicate `--slurpfile NAME` across two files: **first occurrence wins**
  (confirmed directly: `jq -n --slurpfile s f1.json --slurpfile s f2.json '$s'` returns `f1`'s
  content). Since `JQ_ARGS` accumulates in call order, the first spilled binding's file always
  wins the collision — exactly matching the dispatch's "all six records received the FIRST
  description" and this report's own reproduction below.

### Reproduction (fixture-rooted, real `specs/state.json` never touched)

Built a throwaway `mktemp -d` root containing copies of `state-write.sh`, `task-lock.sh`,
`generate-todo.sh`, `deploy-root-guard.sh`, `lib/common.sh`, and `lib/task-lookup-lib.sh` (the
full dependency set `task-lock.sh` needs — `test-state-write-large-payload.sh`'s copy list is
missing `lib/task-lookup-lib.sh`, which is needed too; see Decisions), with a synthetic
`specs/state.json` and the fixture's own `PROJECT_ROOT` (self-resolved from `BASH_SOURCE`)
pointing only at that throwaway root:

**Pure multi-file case** — two `--argjson-file` bindings in one call:
```
./.claude/scripts/state-write.sh '. + {"a": $one, "b": $two}' --session-id sess_repro \
  --argjson-file one f1.json --argjson-file two f2.json
# f1.json: "AAAA description"   f2.json: "BBBB description"
```
Result: `{"a": "AAAA description", "b": "AAAA description"}` — `b` silently lost its own value and
took `a`'s. Exit 0, no diagnostic.

**Mixed case** — one `--argjson-file` binding plus one oversized (110,000-byte, over
`SPILL_THRESHOLD=100000`) `--argjson` binding in the *same* call:
```
./.claude/scripts/state-write.sh '. + {"filebind": $one, "argbind": ($two|length)}' \
  --session-id sess_repro3 --argjson-file one f1.json --argjson two "$BIGVAL"
# f1.json: "FROM-FILE" (9 chars)   $two: a 110,000-byte JSON string
```
Result: `{"filebind": "FROM-FILE", "argbind": 9}` — `$two` should report length ~110,000 but
instead reports `9`, i.e. it silently resolved to `$one`'s file content. This is the "consumed
index N without advancing it, then a later auto-spill claims the same N" failure mode the dispatch
flags as the subtler defect — confirmed live, not just by code-reading.

Both reproductions used a throwaway `/tmp/state-write-repro*` root, removed immediately after;
`git status` on `specs/state.json` was clean throughout.

### Caller audit — no corrupted state found

Every `.sh`/`.md` reference to `state-write.sh` across `agent-system/extensions/**` (core-only;
no non-core extension `.sh` file calls it) was enumerated and each call site's `--argjson`/
`--argjson-file` argument count checked:

- **`--argjson-file` usage**: zero live callers. Only `state-write.sh` itself and its own test
  file (`test-state-write-large-payload.sh`) reference the flag at all. The corruption channel the
  dispatch describes as "OBSERVED — REPRODUCED TWICE" came from the implementer's own direct,
  deliberate invocations while investigating the bug (per the dispatch's own "CAUTION FOR THE
  IMPLEMENTER" section about accidentally writing the real `specs/state.json` during that
  investigation, which required a restore from HEAD) — not from any caller in the codebase.
- **Multiple `--argjson` in one call, live call sites**:
  - `orchestrator-postflight.sh` Stage 7c (`memory_candidates`) and Stage 7d (`reflection`), and
    the equivalent `skill-base.sh` functions `skill_propagate_memory_candidates` /
    `skill_propagate_completion_summary` (roadmap_items branch): each pairs one small
    `--argjson num "$task_number"` (an integer, always a few bytes) with one potentially large
    payload (`memory_candidates`, `reflection`, `roadmap_items`). Only the large one can ever
    cross `SPILL_THRESHOLD`; the task-number binding never can. **At most one spill per call —
    safe by construction, never exercises the collision.**
  - `update-task-status.sh`'s `update_state_json()`: builds `jq_args` with `--arg` for
    `num`/`status`/`ts`/`sid` (never spilled — `--arg` has no spill logic at all) and
    *conditionally* adds **either** `--argjson add "$FILE_SCOPE_ADD"` **or**
    `--argjson rq "$RESEARCH_QUESTIONS"`, explicitly documented in-file as "mutually exclusive by
    the flags' own operation/target_status restrictions (never both non-zero on the same
    invocation)". **Never two `--argjson` bindings in the same call — safe by construction.**
  - `commands/todo.md` Step 5.7.8 (live, authoritative prose) and the quarantined dead-code
    `scripts/deprecated/vault-operation.sh` (Step 5.8.7/5.8.8) both pass two `--argjson` integers
    in one call (`old`/`new` project numbers, or `new_next`/`vault_num`). These are task/vault
    sequence numbers — always tiny (a handful of bytes), never anywhere near the 100,000-byte
    threshold, so **no spill is ever triggered and no collision is possible**, even though the
    shape (2 `--argjson` in one call) superficially resembles the risky pattern. Flagged here for
    completeness per the audit requirement, not as a corruption risk.
  - `scripts/deprecated/archive-task.sh` similarly has two-`--argjson`-per-call shapes but is
    confirmed dead code (`scripts/deprecated/README.md`: "zero live callers ... confirmed").
- **Conclusion**: the corruption *mechanism* is real and now reproduced twice more in this report,
  but it has never been triggered by production code. No repair or data-recovery action is
  needed beyond the fix itself and the regression test. This satisfies the ACCEPTANCE bullet
  "any already-corrupted data is identified and reported (not necessarily repaired, but never
  left undiscovered)" — the finding *is* "none identified," reached by exhaustive enumeration
  rather than left unchecked.

### Fix design space (two options named in the dispatch; not pre-committed)

Both options must preserve two things the current code already gets right, which a fix must not
disturb:
1. `SPILL_FILES` must remain scoped to **only** the files this script itself `mktemp`'d (the
   `--argjson` auto-spill branch) — `cleanup()`'s `rm -f "${SPILL_FILES[@]}"` must never be
   allowed to also `rm` a caller-supplied `--argjson-file` PATH. A fix that makes the
   `--argjson-file` branch append its caller-owned path into `SPILL_FILES` "to fix the counter"
   would be a **new, worse bug** (deleting caller data it doesn't own). The private-name counter
   and `SPILL_FILES` (cleanup ownership) must stay decoupled.
2. `EFFECTIVE_FILTER`'s prefix-injection loop (iterating `SPILL_PRIVATE_NAMES`/
   `SPILL_PUBLIC_NAMES` in parallel) is already correct and needs no change — only the *values*
   fed into `SPILL_PRIVATE_NAMES` need to stop colliding.

**Option A — shared explicit counter.** Introduce one monotonic counter (e.g. `SPILL_COUNTER=0`)
incremented by *both* branches every time either allocates a private name
(`private_name="__spill_${SPILL_COUNTER}"; SPILL_COUNTER=$((SPILL_COUNTER + 1))`), independent of
`SPILL_FILES`. Minimal diff, directly repairs the root cause (a counter that only one branch
advanced), preserves index-based names (no failure-message legibility gain), and uniqueness is
guaranteed by construction — no duplicate-detection logic is needed for the counter itself.
Duplicate-*public*-name detection (see below) is still needed regardless of which option is
chosen, since that requirement is about the caller's own `$NAME`, not the private binding scheme.

**Option B — name-derived private names.** Derive the private name from the caller's own public
`NAME` (e.g. `private_name="__spill_${2}"`) instead of a position. More legible in an error
message (`__spill_memory_candidates` reads better than `__spill_3` when something goes wrong).
Requires explicit duplicate detection: before allocating, check whether `$NAME` (or the derived
private name) already appears in `SPILL_PUBLIC_NAMES` (i.e. a caller passed the same public NAME
twice among *any* spilled bindings — via two `--argjson-file`, two oversized `--argjson`, or one
of each with the same NAME) and hard-fail loudly (matching the dispatch's explicit requirement:
"a duplicate private name must become a loud error rather than a silent last-write-wins") rather
than silently overwriting. Note this only catches a duplicate *among spilled* bindings — a
caller passing the same `NAME` twice where neither instance spills is unaffected either way (that
collision exists today, independent of this bug, in plain jq `--arg`/`--argjson` semantics, and
is explicitly out of scope: "Any change to the jq filter interface callers rely on" is prohibited).

**Recommendation for the planning phase**: Option A is the smaller, lower-risk fix that directly
closes the root cause with no new failure surface, and the codebase's own audit above shows no
caller today would benefit from name-derived error messages (no caller has ever hit this path).
Option A plus an explicit duplicate-*public*-NAME guard (needed under either option, and cheap to
add: track seen public names in a set/array across both spill branches, hard error — non-zero
exit with a clear message naming both the NAME and the two PATHs/values in conflict — on a
repeat) satisfies the dispatch's loud-error requirement without taking on Option B's larger
diff. This is a recommendation, not a decision already made in this report per the dispatch's "do
not pre-commit" instruction — the planning phase should make the final call, informed by this
tradeoff.

### Regression test: location, dependencies, and precedent

`context/standards/shell-script-testing.md`'s location rule is scope-based: a **narrow,
fixture-driven suite for a single script** goes in `scripts/tests/<name>.sh`; a **broad
end-to-end/pipeline suite** exercising multiple scripts together stays flat in `scripts/`. All
three existing `state-write.sh` suites (`test-state-write-concurrency.sh`,
`test-state-write-regen-timing.sh`, `test-state-write-large-payload.sh`) are flat in `scripts/`,
not under `scripts/tests/` — because each one, by necessity (state-write.sh's mutex integrates
with `task-lock.sh`, and `--regen-todo` with `generate-todo.sh`), is a multi-script fixture copy,
matching the "broad" branch of the rule, and this is recorded as the deliberate convention in
`shell-strict-mode.md`'s Class B classification list (`test-state-write-concurrency.sh` and
`test-state-write-regen-timing.sh` are named there explicitly as flat `scripts/test-*.sh` Class B
suites).

**This conflicts with the dispatch's ACCEPTANCE text**, which says "A regression test exists
under `scripts/tests/`." Given the documented convention and the unbroken 3-for-3 precedent of
every existing `state-write.sh` suite living flat in `scripts/`, the new suite (e.g.
`scripts/test-state-write-spill-names.sh`, following the existing `test-state-write-*.sh` naming
family) should also live flat in `scripts/`, not `scripts/tests/`. The planning/implementation
phase should follow the documented convention and existing precedent over the dispatch's literal
wording; `run-all.sh` discovers both locations either way (`scripts/tests/test-*.sh` and flat
`scripts/test-*.sh`), so test discovery is unaffected regardless of which is chosen — this is a
convention-consistency question, not a functional one.

**Precedent fixture set** (`test-state-write-large-payload.sh`, confirmed working, with one gap
found and fixed during this report's own reproduction): copy `state-write.sh`, `task-lock.sh`,
`generate-todo.sh`, `deploy-root-guard.sh`, `lib/common.sh` **and `lib/task-lookup-lib.sh`**
(the existing suite's copy list is missing this last dependency — `task-lock.sh` sources it
directly and the suite would fail at runtime without it; this report's own reproduction hit and
fixed exactly this gap) into a `mktemp -d` root's `.claude/scripts/{,lib/}`, with a synthetic
`specs/state.json`, and invoke the fixture's own copy from `cd "$TMPROOT"`. This is the concrete
mechanism the dispatch's caution note demands ("A regression test MUST invoke a copy of the
script rooted inside a fixture tree so its self-resolved `PROJECT_ROOT` points at the fixture,
never the deployed script") — already proven correct twice more in this report's own
reproduction runs, with `git status` confirmed clean on `specs/state.json` before and after.

**Mutation-check requirement** (`shell-script-testing.md`'s "Mutation checks for regex-shaped
fixes"): since this is a logic fix (not a regex fix per se, but the same principle applies to any
targeted bug fix), the new suite must be shown to fail against the current (pre-fix) script before
the fix lands — this report's two reproductions above already demonstrate the exact failing
assertions the new suite's Case-A (pure multi-file) and Case-B (mixed) should encode: `diff`
against each file's own expected value, asserting they differ from each other (not both matching
the first file/binding).

**shellcheck**: not available in this dev environment (`shellcheck` absent from `$PATH`; `nix`
is available, so `nix shell nixpkgs#shellcheck --command shellcheck ...` or an equivalent
`nix-shell -p shellcheck` invocation is the likely path for the implementer to verify
"shellcheck clean per `context/standards/shell-strict-mode.md`"). `state-write.sh` is already
Class A (`set -euo pipefail`), so the fix must stay `-e`-safe: prefer `if`/`||`-guarded array
membership checks for duplicate-name detection over a bare failing test that isn't wrapped, per
the same pattern already used throughout the file (`if VAR=$(cmd); then ... else status=$?; fi`).

## Decisions

- Fix targets `agent-system/extensions/core/scripts/state-write.sh` only (source store), per the
  dispatch's DEPLOY-TREE NOTE; verify post-fix via a redeploy, never hand-edit
  `.claude/scripts/state-write.sh`.
- Regression test should live flat in `scripts/` (e.g.
  `scripts/test-state-write-spill-names.sh`), matching the unbroken precedent of all three
  existing `state-write.sh` suites and `shell-script-testing.md`'s scope-based location rule,
  rather than the dispatch's literal "under `scripts/tests/`" wording — flagged for the planning
  phase to confirm, since it is a documented-convention-vs-dispatch-wording conflict rather than
  something this report can unilaterally overrule.
- Recommend Option A (shared explicit counter, decoupled from `SPILL_FILES`) plus an explicit
  duplicate-public-NAME loud-error guard for the fix itself, over Option B (name-derived private
  names) — see Fix design space above for the full tradeoff; final choice deferred to planning.
- Caller audit is complete and conclusive: no corrupted `specs/state.json` data exists or is
  suspected from this defect; no data-repair task is warranted.

## Risks & Mitigations

- **Risk**: a fix that makes `--argjson-file` append its caller-owned path into `SPILL_FILES` (to
  "share" the counter) would introduce a new bug — `cleanup()`'s `rm -f "${SPILL_FILES[@]}"`
  deleting a file the script doesn't own. **Mitigation**: keep the private-name counter and
  `SPILL_FILES` (cleanup ownership) as two separate concerns; both fix options above already do
  this correctly.
- **Risk**: a duplicate-NAME guard added to satisfy the loud-error requirement could be written in
  a way that isn't `-e`-safe (e.g. a bare `[[ " ${arr[*]} " == *" $x "* ]]` inside `set -e` without
  the result being tested) and silently pass through under `set -euo pipefail`'s edge cases.
  **Mitigation**: follow the file's own existing `if`/`||`-guarded idiom throughout; verify with
  shellcheck before considering the fix complete, per ACCEPTANCE.
- **Risk**: the new suite could be placed under `scripts/tests/` per the dispatch's literal
  wording, creating a 4th, differently-located `state-write.sh` suite than its 3 siblings.
  **Mitigation**: flagged explicitly above for the planning phase; low-cost either way since
  `run-all.sh` discovers both locations, but consistency with existing precedent is preferable.

## Context Extension Recommendations

- **Topic**: none. The relevant conventions (`shell-script-testing.md`'s location rule,
  `shell-strict-mode.md`'s Class A/B/C classification) are already documented and sufficient to
  resolve every question this task raised; no gap found.

## Appendix

- Reproductions performed against throwaway `mktemp -d` roots under `/tmp/state-write-repro*`,
  removed immediately after each run; `git status --porcelain -- specs/state.json` confirmed
  clean (no changes) after every reproduction.
- `jq -n --slurpfile s f1.json --slurpfile s f2.json '$s'` → returns `f1`'s content (first-wins),
  run in a scratch `/tmp` directory unrelated to any project state.
- Searches: `grep -rln "state-write.sh" agent-system/extensions/ --include="*.sh" --include="*.md"`
  (full caller enumeration); `grep -rn "argjson-file" agent-system/extensions/ --include="*.sh"`
  (confirmed zero live callers besides the script and its own test); per-file `--argjson`/`--arg`
  count inspection for every script identified as calling `state-write.sh` with 2+ bindings in one
  invocation.
- `git log --oneline -- agent-system/extensions/core/scripts/state-write.sh`: the defect was
  introduced in the most recent commit touching the file, "Fix 128KB argv ceiling in
  roadmap-integration.sh and state-write.sh" (the commit that added `--argjson-file` and the
  auto-spill logic together). `roadmap-integration.sh` (the sibling script from that same commit)
  was checked and does not share this spill-name pattern at all (no `SPILL_FILES`/`private_name`/
  `__spill` logic present there), so it carries no analogous risk.
