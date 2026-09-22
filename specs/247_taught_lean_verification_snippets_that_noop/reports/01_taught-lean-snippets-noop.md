# Research Report: Task #247

**Task**: 247 - Taught Lean verification snippets that no-op
**Started**: 2026-09-22T01:00:00Z
**Completed**: 2026-09-22T01:15:00Z
**Effort**: medium
**Dependencies**: task 221 (build-verdict/exit-code capture, landed), task 173 (guard `result`/STATUS, landed) — both confirmed complete and merged (see Decisions)
**Sources/Inputs**: Codebase grep/read of `agent-system/extensions/lean/**`, `agent-system/extensions/core/scripts/lake-build-guard.sh`, live `lakefile.toml` in two real consuming repos (`~/Projects/BimodalLogic`, `~/Projects/cslib`)
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- HALF 1 (guard invocation missing lake subcommand): re-derived against current source
  (post-task-221/173 landing). **3 of the 4 previously-verified broken sites are still broken**
  at drifted line numbers; the 4th flagged item is two placeholder occurrences that still need a
  judgment call. One new site not in the dispatch's list was found and ruled *not* a defect
  (`comparator-integration.md`'s `-- env <comparator> config.json` — `env` is a valid
  `LAKE_SUBCOMMANDS` entry).
- HALF 2 (hardcoded `Theories/`): confirmed by direct code reading that
  `lean-sorry-census.sh` silently exits 0 with `sorry_count: 0` when its target directory does
  not exist or contains zero `.lean` files (lines 92-95) — this is the exact "clean pass on
  nothing scanned" defect, mechanically confirmed, not just hypothesized.
- Both `~/Projects/BimodalLogic` and `~/Projects/cslib` ship `lakefile.toml` (not
  `lakefile.lean`), and their `[[lean_lib]]` / `defaultTargets` stanzas are directly readable
  with Python's stdlib `tomllib` — BimodalLogic already has its own project-local precedent
  script (`scripts/lake_targets.py`) doing exactly this kind of resolution, which is strong
  design grounding for Half 2(a)/(b) but is NOT itself reusable (it is project-local, not part
  of the agent-system source store, and cannot be assumed present in every consuming repo).
- Recommended approach: a new resolver script in `agent-system/extensions/lean/scripts/`
  (e.g. `lean-src-roots.sh`) that (1) tries `lakefile.toml` parsing via a small embedded Python
  `tomllib` reader mirroring `lake_targets.py`'s default-application logic (`srcDir` default
  `"."`, `roots` default `[name]`), falling back to (2) one documented `LEAN_SRC_ROOTS`
  environment/config value when no parseable `lakefile.toml` exists (covers `lakefile.lean`
  repos), and which itself performs the loud-failure check from Half 2(c) so every caller gets
  it for free by using the resolver's output.

## Context & Scope

This is a `meta` task editing `agent-system/extensions/lean/**` only (never `.claude/**`,
which is a disposable deploy artifact — confirmed no writes were made there). The task
description names two independent defect classes sharing an edit target
(`lean-implementation-hard-agent.md`), discovered from repeated hand-workarounds across a
7-task `/orchestrate` run against `~/Projects/BimodalLogic`. Both named dependency tasks (221,
221's sibling 173) have already landed (`git log` shows `task 173: complete implementation` and
four `task 221: complete/create ...` commits, both ahead of this task's dispatch), so the
dispatch's instruction to "re-derive the line numbers above AFTER #221 has landed" applies now.
This report re-verifies every site against the current tree rather than trusting the dispatch's
original line numbers.

## Findings

### Codebase Patterns — HALF 1 (guard invocation shape)

`LAKE_SUBCOMMANDS` (in `agent-system/extensions/core/scripts/lake-build-guard.sh`, line 252):
```
new init build query exe check-build test check-test lint check-lint clean env lean update pack unpack upload cache script scripts run translate-config serve
```
The guard validates `lake_args[0]` (the first token after `--`) against this allowlist in
build mode; a non-matching first token exits 77 before any build launches (confirmed via
`scripts/lake-build-guard.sh` lines 964-971, not reproduced in full here — out of scope, owned
by task 173).

Full current inventory of every `-- <...>` guard-invocation vector in the lean extension
(`grep -rn "lake-build-guard.sh\|build --timeout" agent-system/extensions/lean/`):

| File:Line | Vector | Verdict |
|---|---|---|
| `agents/lean-implementation-agent.md:295` | `-- build 2>&1` | OK |
| `rules/lean4.md:48` | `-- Module.Name` | **BROKEN** — first token is a module name, not a subcommand |
| `rules/lean4.md:51` | `-- build` | OK |
| `rules/lean4.md:71` | `-- <lake args>` | Placeholder — judge (see Decisions) |
| `rules/lean4.md:76` | `-- <lake args> > <log> 2>&1` | Placeholder — same block, judge together |
| `agents/lean-implementation-hard-agent.md:237` | `-- ModuleName 2>&1` | **BROKEN** — same class as above |
| `agents/lean-implementation-hard-agent.md:405` | `-- build 2>&1` | OK |
| `context/project/lean4/operations/long-builds.md:75` | `-- <lake args>` | Placeholder — judge (canonical-invocation block, copied verbatim by the two rules/lean4.md sites above per its own comment) |
| `context/project/lean4/domain/comparator-integration.md:82,89` | `-- env <comparator> config.json` | OK — `env` is an allowlisted subcommand; NOT a defect (not in original dispatch list either) |
| `skills/skill-lake-repair/SKILL.md:79` | `-- "$module"` | **BROKEN** — `$module` substitutes to a bare module name at runtime |
| `skills/skill-lake-repair/SKILL.md:81` | `-- build 2>&1` | OK |
| `scripts/lean-sorry-census.sh:194-208` (`"$GUARD_BIN" build -- build`) | `-- build` | OK, not in dispatch's list, confirmed fine |

**Confirmed still-broken (3 concrete sites, matching the dispatch's claim modulo line drift from
task 221's edits, which added lines earlier in these same files):**
1. `agent-system/extensions/lean/rules/lean4.md:48`
2. `agent-system/extensions/lean/agents/lean-implementation-hard-agent.md:237`
3. `agent-system/extensions/lean/skills/skill-lake-repair/SKILL.md:79`

**Placeholder sites requiring an explicit decision (not a mechanical fix):**
`rules/lean4.md:71` and `:76` (one "Canonical invocation shape" code block, `<lake args>` used
twice) and `context/project/lean4/operations/long-builds.md:75` (the same canonical block,
which `rules/lean4.md`'s own prose says every contract site copies verbatim). Since all three
placeholder occurrences trace back to one canonical block in `long-builds.md` that `lean4.md`
duplicates, fixing the wording in one place (or in both, since `lean4.md` quotes it inline
rather than by reference) closes all three at once.

**Not a defect, no change needed:** `comparator-integration.md:82,89` — `env` is a valid Lake
subcommand per the allowlist above; this call site is already correct and was correctly absent
from the dispatch's verified-sites list.

### Codebase Patterns — HALF 2 (hardcoded `Theories/`)

**Mechanical confirmation that a missing/empty scan root is a silent clean pass.** Read
`agent-system/extensions/lean/scripts/lean-sorry-census.sh` lines 72-95:
```bash
if [[ ${#TARGETS[@]} -eq 0 ]]; then
  echo "Usage: lean-sorry-census.sh <dir-or-file> [<dir-or-file> ...] [--cross-check]" >&2
  exit 64
fi
# Collect .lean files from the targets (directories are scanned recursively).
LEAN_FILES=()
for target in "${TARGETS[@]}"; do
  if [[ -d "$target" ]]; then
    while IFS= read -r -d '' f; do
      LEAN_FILES+=("$f")
    done < <(find "$target" -type f -name '*.lean' -print0)
  elif [[ -f "$target" ]]; then
    LEAN_FILES+=("$target")
  else
    echo "Warning: '$target' is not a file or directory, skipping" >&2
  fi
done

if [[ ${#LEAN_FILES[@]} -eq 0 ]]; then
  echo "sorry_count: 0"
  echo "sorry_inventory:"
  exit 0
fi
```
A nonexistent `Theories/` prints one `Warning:` line to stderr (easily lost/ignored, especially
if the call site captures/pipes output) and then exits 0 with `sorry_count: 0` — indistinguishable
from a genuinely clean, fully-scanned project. This is the exact "verification instrument that
cannot report failure" the dispatch names, confirmed by reading the code rather than inferred.
The script itself is otherwise already generic/parameterized (its own usage examples show both
`Cslib/` and `Theories/` as illustrative arguments; nothing internal to the script is
BimodalLogic-specific) — the defect is entirely in what callers pass it, and in the exit-0
fallthrough above.

**Full current inventory of `Theories/` occurrences** (`grep -rn "Theories/" agent-system/extensions/lean/`):

Taught/executable snippet sites requiring the fix (route through the new resolver):
- `agents/lean-implementation-agent.md`: lines 277 (sorry census), 283 (vacuous-def grep), 289
  (axiom grep), 327/330 (plan-compliance existence grep + echo text), 338 (replacement-target
  grep), 406, 417 (comparator preflight solution-module discovery, duplicated block)
- `agents/lean-implementation-hard-agent.md`: lines 382 (sorry census), 393 (vacuous-def grep),
  399 (axiom grep), 421 (prose pointer to the same check), 475, 486 (comparator preflight,
  same duplicated block as above)
- `skills/skill-lean-implementation/SKILL.md:304` — **different in kind**: this is not a
  `lean-sorry-census.sh`/grep call at all, it is the `git-commit-scoped.sh -- "Theories/" ...`
  staging path list at Stage 8 (git commit). A hardcoded `"Theories/"` here means the commit
  silently stages nothing from the source tree in a repo where the root differs — same defect
  class (silent no-op), different call site shape. Needs to resolve to the same value the
  verification steps use.
- `skills/skill-lean-implementation-hard/SKILL.md:447` — identical git-commit-scoped.sh site,
  hard-agent skill variant.
- `scripts/lean-sorry-census.sh:26` — usage-example comment only (`bash
  .claude/scripts/lean-sorry-census.sh Theories/ --cross-check`); update once (a)/(b) land so
  the example itself doesn't re-teach the hardcoded literal.
- `context/project/lean4/domain/challenge-snapshot.md:20` — prose description ("own compliance
  check is a name-existence grep over `Theories/`"); update to describe the resolved-root
  behavior once implemented.

Explicitly out of scope (test fixtures, confirmed, leave alone):
- `scripts/tests/test-lean-challenge-snapshot.sh` (lines 160, 170, 184, 293, 303, 313, 323) —
  all create/copy/reference a literal `Theories/Basic.lean` as a **test fixture path**, not a
  taught instruction. `lean-challenge-snapshot.sh` itself (the script under test) contains zero
  `Theories/` references — confirmed by direct grep, it takes its module/path arguments as
  parameters and has no hardcoding of its own.

Prose/illustrative, judged fine as-is (no fix needed — read directly, not assumed):
- `context/contracts/context-hygiene.md:34,69` and `agents/lean-research-hard-agent.md:135` /
  `agents/lean-implementation-hard-agent.md:117` all use the parallel phrasing
  `` `Theories/`/`Cslib/` `` as a read-budget discipline example (bounding whole-file reads),
  already presented as two illustrative alternatives rather than a single hardcoded instruction
  — this phrasing already implicitly acknowledges repo-specific roots and needs no change.
- `context/contracts/anti-analysis.md:57` — one example preamble string ("Phase scope:
  Ns.inductive_step and Ns.main_theorem in Theories/Ns.lean") illustrating phase-scope
  reporting format, not an executable instruction; fine as a generic example.

No plan-template site was found: `find agent-system/extensions/lean -iname "*template*"` turned
up only `context/project/lean4/templates/{definition,new-file,proof-structure}-template.md`,
none of which reference `lake-build-guard.sh` or `Theories/`.

### External Resources — real consuming-repo `lakefile.toml` shapes

Read directly (not inferred) from the two repos named in the dispatch/task history:

`~/Projects/BimodalLogic/lakefile.toml`:
```toml
defaultTargets = ["FormalSystem"]
...
[[lean_lib]]
name = "FormalSystem"
...
[[lean_lib]]
name = "BimodalTest"
srcDir = "Tests"
...
[[lean_lib]]
name = "BimodalTools"       # deliberately absent from defaultTargets
...
[[lean_lib]]
name = "BimodalToolsTest"
srcDir = "Tests"
```
Matches the dispatch's claim exactly: library root `FormalSystem/`, tests under `Tests/`
(here, `Tests/BimodalTest/` and `Tests/BimodalToolsTest/` given Lake's `roots` default of
`[name]` composed with `srcDir`).

`~/Projects/cslib/lakefile.toml`:
```toml
defaultTargets = ["Cslib"]
[[lean_lib]]
name = "Cslib"
[[lean_lib]]
name = "CslibTests"
```
Matches the dispatch's claim: library root `Cslib/`.

**Existing precedent for parsing this file**: `~/Projects/BimodalLogic/scripts/lake_targets.py`
(project-local, NOT part of the agent-system source store) is a small stdlib-`tomllib` reader
that applies exactly Lake's own defaults (`srcDir` default `"."`, `lean_lib` `roots` default
`[name]`) and exits 2 with a stderr message when the lakefile is missing, unparseable, or
declares no target of the requested kind — i.e. it already implements the "loud failure, name
the file" contract Half 2(c) asks for, just for a different failure mode (missing lakefile
entries, not missing source directories). This is strong existing-pattern evidence for design
choice (a) in the dispatch (derive from `lakefile.toml` rather than a second, competing
per-repo config), and for modeling the new resolver's error-handling on this script's shape —
but it cannot simply be reused, since it lives outside the agent-system source store and cannot
be assumed to exist in every consuming repo (nor does the source store have any mechanism to
depend on a project-local script).

### Recommendations

1. **Half 1 fix**: for the 3 confirmed-broken sites, change `--` + module-name-only to
   `-- build <module-or-project-arg>` (matching the already-correct sibling invocations
   immediately adjacent in the same files, e.g. `rules/lean4.md:51`, `lean-implementation-hard-agent.md:405`,
   `skill-lake-repair/SKILL.md:81`). For the placeholder trio (`rules/lean4.md:71,76` and
   `long-builds.md:75`), the dispatch requires an explicit decision, not silence — recommend
   changing the placeholder text itself to `-- build <lake args>` or `-- <lake subcommand>
   [args]` (self-documenting either way) since both `lean4.md`'s two concrete examples already
   bracket the canonical block with an actual `-- build` invocation, making the abstract
   placeholder inconsistent with its own neighbors.
2. **Half 2 fix**: build one resolver (script or shell function) in
   `agent-system/extensions/lean/scripts/`, e.g. `lean-src-roots.sh`, that: (a) if
   `lakefile.toml` exists at the repo root, parses `defaultTargets` (or all `[[lean_lib]]`
   entries, per plan-time decision) applying Lake's own `srcDir`/`roots` defaults exactly as
   `lake_targets.py` does; (b) otherwise falls back to a single documented config value (e.g.
   `LEAN_SRC_ROOTS` env var or a `.lean-src-roots` dotfile) — never a second competing
   mechanism; (c) itself performs the loud-failure check (nonexistent or zero-`.lean`-file root
   -> non-zero exit naming the root) so callers inherit it for free rather than each
   re-implementing it. Route every taught snippet in the "requiring the fix" list above (both
   `lean-implementation*-agent.md` files, both `skill-lean-implementation*` SKILL.md commit
   stages, `lean-sorry-census.sh`'s own usage text, `challenge-snapshot.md`'s prose) through
   this one resolver's output rather than a literal `Theories/`.
3. Additionally, `lean-sorry-census.sh`'s own exit-0-on-empty behavior (lines 92-95) is itself a
   defect independent of any caller: MUST become a non-zero exit naming the target(s) that
   produced zero files, per Half 2(c)'s acceptance criterion — this is a script-level fix, not
   only a caller-level one, since anyone invoking the script directly (bypassing the resolver)
   would still get a silent pass otherwise.
4. Acceptance criterion 4 (plant a real sorry in BimodalLogic, run unmodified, confirm it's
   caught) and criterion 5 (redeploy, confirm `.claude/**` regenerates) are execution-time
   verification steps for the implementation phase, not research; flagging them here so the
   plan allocates explicit verification phases for both.

## Decisions

- Treated task 221 and task 173 as landed dependencies (confirmed via `git log`), so this
  report re-derives every line number against the current tree rather than trusting the
  dispatch's original (pre-#221) line numbers, per the dispatch's own instruction.
- Judged `comparator-integration.md`'s `-- env <comparator> config.json` sites as NOT part of
  Half 1's defect (`env` is an allowlisted lake subcommand) — consistent with the dispatch's own
  verified-sites list, which did not include this file.
- Judged the `Theories/`/`Cslib/` prose sites in `context-hygiene.md`, `anti-analysis.md`,
  `lean-research-hard-agent.md`, and `lean-implementation-hard-agent.md`'s read-budget bullet as
  requiring no change — they are already dual-alternative illustrative phrasing, not
  single-literal instructions, and do not reproduce the "verification that cannot fail" defect
  class (they are prose about read discipline, not executable checks).
- Did not attempt to design the resolver's exact parsing algorithm (TOML library choice,
  `lakefile.lean` fallback mechanics) in full — left as a planning-phase decision per the
  dispatch's own framing ("Decide during planning whether that helper is a new script, a
  function inside lean-sorry-census.sh, or a documented variable... record the decision and the
  reason").

## Risks & Mitigations

- **Risk**: `lake_targets.py`-style TOML parsing assumes Python 3.11+ (`tomllib` is stdlib only
  from 3.11). Mitigation: verify the Python version available in typical consuming-repo/agent
  execution environments during planning; both `~/Projects/BimodalLogic` and `~/Projects/cslib`
  already carry a project-local script depending on it, suggesting the environment already
  satisfies this, but this should be confirmed rather than assumed.
- **Risk**: some future consuming repo might use `lakefile.lean` (Lean-syntax, not TOML) instead
  of `lakefile.toml`. Both currently-known consuming repos (BimodalLogic, cslib) use TOML, so
  this is not blocking, but the resolver's documented single-config-value fallback (per the
  dispatch's "acceptable fallback") is the safety valve for this case — plan should make the
  fallback path exercised by a test, not just described.
- **Risk**: fixing the two "Plan compliance spot-check" / "Comparator preflight" blocks touches
  the same duplicated grep pattern in two files (`lean-implementation-agent.md` and
  `lean-implementation-hard-agent.md`) each appearing twice per file — four total edit sites
  per pattern-family across two files. Mitigation: since all four sites resolve to the same
  literal-replacement pattern (`Theories/` -> `$(resolver output)`), a single sed-style pass
  scoped to `Theories/` occurrences (excluding the git-commit-scoped.sh sites, which need a
  slightly different treatment — array/string, not grep target) should suffice; flag for the
  planner to scope as one phase per file rather than one phase per occurrence.
- **Risk (already flagged by dispatch, restated for plan visibility only)**: this task's file
  scope overlaps task 221/173's files (`lean4.md`, `lean-implementation-agent.md`,
  `lean-implementation-hard-agent.md`, `long-builds.md`). Both dependencies are confirmed landed
  (see Decisions), so the serialization concern is resolved — no blocking risk remains, but the
  plan should still diff against the current (post-221/173) file content rather than any earlier
  snapshot, which this report has already done.

## Context Extension Recommendations

None — this is a `meta` task and the two defect classes are fully scoped by the dispatch and
this report; no new `.claude/context/` documentation gap was identified beyond what the
recommended fix itself will produce (the resolver's own contract doc, which is implementation
work, not a context-extension gap).

## Appendix

### Search queries used
- `grep -rn "lake-build-guard.sh" agent-system/extensions/lean/`
- `grep -rn "build --timeout" agent-system/extensions/lean/`
- `grep -n "LAKE_SUBCOMMANDS" -A 5 agent-system/extensions/core/scripts/lake-build-guard.sh`
- `grep -rln "lake-build-guard\|GUARD_BIN\|guard.sh build" agent-system/extensions/lean/`
- `grep -rn "Theories/" agent-system/extensions/lean/`
- `grep -n "Theories" agent-system/extensions/lean/scripts/lean-challenge-snapshot.sh`
- `find agent-system/extensions/lean -iname "*planner*" -o -iname "*template*"`
- `grep -l "lake-build-guard\|Theories/" agent-system/extensions/lean/context/project/lean4/templates/*.md`
- Direct `Read`/`sed -n` of every matched line's surrounding context (not spot-checked in
  isolation) in: `rules/lean4.md`, `agents/lean-implementation-agent.md`,
  `agents/lean-implementation-hard-agent.md`, `skills/skill-lake-repair/SKILL.md`,
  `skills/skill-lean-implementation/SKILL.md`, `skills/skill-lean-implementation-hard/SKILL.md`,
  `scripts/lean-sorry-census.sh`, `context/project/lean4/domain/challenge-snapshot.md`,
  `context/project/lean4/domain/comparator-integration.md`,
  `context/project/lean4/operations/long-builds.md`, `context/contracts/context-hygiene.md`,
  `context/contracts/anti-analysis.md`, `agents/lean-research-hard-agent.md`
- `cat ~/Projects/BimodalLogic/lakefile.toml`, `cat ~/Projects/cslib/lakefile.toml`,
  `cat ~/Projects/BimodalLogic/scripts/lake_targets.py`
- `git log --oneline -10` (confirmed tasks 173 and 221 landed ahead of this dispatch)

### References
- `agent-system/extensions/core/scripts/lake-build-guard.sh` (owned by task 173; read-only
  reference here, not edited)
- `agent-system/extensions/lean/scripts/lean-sorry-census.sh` (edit target for Half 2(c))
- `~/Projects/BimodalLogic/scripts/lake_targets.py` (external precedent, not part of this
  repo's source store, read-only reference)
