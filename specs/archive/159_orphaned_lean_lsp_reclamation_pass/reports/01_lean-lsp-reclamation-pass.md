# Research Report: Task #159

**Task**: 159 - Add an independently-gated reclamation pass for orphaned Lean LSP process trees
**Started**: 2026-09-07T19:00:00Z
**Completed**: 2026-09-07T19:50:00Z
**Effort**: Medium
**Dependencies**: Task 158 (VmSwap-aware refresh memory accounting) — completed, provides `get_vmswap_kb`/`format_memory`
**Sources/Inputs**:
- Codebase: `agent-system/extensions/core/scripts/claude-refresh.sh`, `tests/test-claude-refresh-matcher.sh`, `skills/skill-refresh/SKILL.md`, `commands/refresh.md`
- Live system: `ps` inspection of a real, currently-running `lean-lsp-mcp` process tree
- Third-party source: `leanclient` and `lean_lsp_mcp` packages installed at `~/.local/share/uv/tools/lean-lsp-mcp/lib/python3.1{2,3}/site-packages/`
- Prior task artifacts: `specs/158_vmswap_aware_refresh_memory_accounting/{reports,plans,summaries}/01_*`
**Artifacts**:
- This report
**Standards**: report-format.md, subagent-return.md, shell-script-testing.md

## Executive Summary

- **Predicate must combine `comm` with an `args` pattern, not `comm` alone.** Live inspection
  proves `ps`'s `comm` field for these processes is just `lake` or `lean` — the three-way
  distinction (`lake serve` vs `lean --server` vs `lean --worker`) only exists in `args`. The
  dispatch's phrasing ("comm in (`lake serve`, `lean --server`, `lean --worker`)") is shorthand;
  the actual predicate needs the same two-part shape `is_claude_executable_comm`'s `node` branch
  already uses (comm gate + argv substring gate).
- **The new pass needs its own, separately-scoped `ps` snapshot** (`ps -C lake,lean -o ...`),
  not a widened version of the existing `SNAPSHOT_PS_FIELDS`. Widening the shared snapshot to add
  a `pcpu` column would force every fixture `ps` stub in `test-claude-refresh-matcher.sh`
  (three of them) to emit an extra column merely to keep the *existing* Claude-matcher tests
  parsing correctly — a large, unnecessary blast radius for a feature the dispatch already calls
  "independently-gated." A `ps -C lake,lean -o pid,ppid,uid,etimes,rss,pcpu,cgroup:200,comm,args
  --no-headers` scan is confirmed to work standalone (verified live) and keeps the two passes'
  data fully decoupled.
- **`0% CPU` should read `ps`'s own `pcpu` column** (a recent/decaying average on Linux
  `procps-ng`, not a lifetime-since-boot average), combined with `etimes >= threshold` from the
  same one-shot snapshot. This avoids a second live poll and stays inside the existing
  single-atomic-snapshot safety philosophy (applied per-pass, not globally).
- **Termination must be tree-aware, not row-independent.** Unlike the existing Claude-process
  loop (each PID judged and killed independently), a Lean tree has a strict 3-level hierarchy
  (`lake serve` → `lean --server` → N × `lean --worker`) captured via `pid`/`ppid` in the same
  snapshot. The safe design evaluates the idle/CPU gate against **every member of a tree**
  (root + server + all workers) before touching any of it — a single freshly-spawned worker
  (small `etimes`) should protect the whole tree, not just itself, matching the THRESHOLD RISK
  concern in the dispatch.
- **A live zombie (`[lake] <defunct>`) was observed during this research** with `comm` rendered
  as `lake <defunct>` by `ps`, not `lake`. An exact-match `case` predicate (`lake)` /`lean)`)
  naturally and correctly excludes it already — no special-case code is needed, but this is worth
  recording as a confirmed-safe edge case rather than an accidental oversight.
- **`skill-refresh/SKILL.md`'s process-cleanup step has no explicit `AskUserQuestion` JSON block
  today** (only the directory-cleanup age-selector in Step 7 does); the script's own comment says
  "skill will prompt with AskUserQuestion" but Step 2 just stores output. The dispatch's request
  for a new "AskUserQuestion option" should close this pre-existing gap for the combined
  Claude+Lean orphan report, not merely bolt something onto documentation prose.

## Context & Scope

Task 158 (completed, see `specs/158_vmswap_aware_refresh_memory_accounting/`) deliberately
confined itself to adding VmSwap-aware memory *reporting* (`get_vmswap_kb`, `format_memory`
widened to a 5-field row) and explicitly deferred "tuning any memory-based threshold" — i.e. this
task — to "a later, explicitly sequenced task." This task is that sequel: a **new**, independently
gated detection+termination pass for orphaned Lean LSP process trees (`lake serve` → `lean
--server` → `lean --worker`*), living alongside (not replacing) the existing Claude-process
orphan pass in the same script.

Hard constraint carried into every design decision below: `is_claude_executable_comm` must remain
byte-identical, and the existing `--dry-run`/`--force` contract and confirmation flow for the
Claude pass must be unchanged. The new Lean predicate is a parallel, independent code path.

## Findings

### Codebase Patterns

**`claude-refresh.sh` structure** (451 lines): a single atomic `ps -eo pid,ppid,uid,tty,etimes,
rss,comm,cgroup:200,args --no-headers` snapshot (`SNAPSHOT_PS_FIELDS`, `take_snapshot()`), four
independently-callable predicates (`is_claude_executable_comm`, `is_system_slice_cgroup`,
`is_owned_by_current_uid`, `is_live_inhibitor_target`) plus zero-query self-exclusion (`pid`/`ppid`
== `$$`), a reporting-only `get_vmswap_kb()` (task 158's addition), and a `main()` that loops the
snapshot once, classifies each row, and — in `--force` mode — SIGTERMs each orphan PID
independently (`kill -15`, `sleep 0.5`, escalate to `kill -9` if still alive). The termination loop
(lines 408-436) has no ordering concept today because the Claude-process design is flat: every
orphan PID is judged and killed independently, with no parent/child relationship modeled.

**`is_claude_executable_comm`'s two-part predicate shape is the template to reuse.** Its `node`
branch already demonstrates comm-gate-plus-argv-pattern:
```bash
node|nodejs)
    case "$args" in
        *claude-code*|*/claude|*/claude\ *)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
    ;;
```
The new Lean predicate needs the identical shape for `lake`/`lean`, since (see Live Verification
below) `comm` alone cannot distinguish `lean --server` from `lean --worker` — both report `comm`
== `lean`.

**Test suite structure** (`test-claude-refresh-matcher.sh`, 426 lines): sources the script under
test (copied into a `mktemp -d`) so predicates are called directly by name; assertions (a)-(e)
cover the four predicates plus VmSwap accounting; assertion (d-2) and the assertion-(e)
output-shape case establish the precedent for driving a **fake `ps` on `PATH`** (with a companion
fake `kill` would be the natural extension for an ordering assertion — see Recommendations); a
mutation check pins a pre-fix commit (`7e79b2695`) and asserts the suite is non-vacuous against
it. This mutation-check pattern will need a new pinned-commit-style non-vacuousness proof (or an
equivalent structural argument) for the new predicate's own test block, per
`shell-script-testing.md`'s "Mutation checks for regex-shaped fixes."

**`skill-refresh/SKILL.md`** Step 2 runs `claude-refresh.sh` once, forwarding `--dry-run`/
`--force`, and stores output for display — no explicit `AskUserQuestion` JSON block exists for
process cleanup (only Step 7's directory-cleanup age-threshold selector does), despite the skill's
frontmatter declaring `AskUserQuestion` as an allowed tool and the script's own comment ("skill
will prompt with AskUserQuestion and re-run with --force if confirmed") implying one should exist.
The "Safety Measures" > "Process Safety" section (lines 412-440) enumerates the four existing
predicates in prose; a fifth bullet describing the new Lean predicate belongs here, mirroring
`refresh.md`'s parallel "Process Protection" section (lines 124-145) which will need the same
addition.

### Live System Verification (ground truth, not assumed)

A real `lean-lsp-mcp` process tree was inspected live during this research (project:
`~/Projects/BimodalLogic`), confirming the dispatch's problem statement and correcting one detail:

```
PID     PPID    COMM   %CPU  ETIME(s)  RSS(KB)  TTY      ARGS
2657915 2519245 lake    0.0     3007    10396  pts/11   .../bin/lake serve -- -Dserver.reportDelayMs=0
2657988 2657915 lean    0.4     3007   677100  pts/11   .../bin/lean --server -Dserver.reportDelayMs=0
2659336 2657988 lean    0.0     3004    35556  ?        .../bin/lean --worker ... file://.../Completeness.lean
2662770 2657988 lean    0.1     2998   115312  ?        .../bin/lean --worker ... file://.../CompletenessDedekind.lean
2668121 2657988 lean    0.1     2990   114340  ?        .../bin/lean --worker ... file://.../StrongCompleteness.lean
3744087 3557690 lake <defunct> 0.0   58164        0  pts/2    [lake] <defunct>
```

Key corrections/confirmations to the dispatch's problem statement:

1. **`comm` is `lake` or `lean`, never `lake serve`/`lean --server`/`lean --worker` verbatim.**
   The three-way distinction requires an `args` substring match in addition to the comm gate
   (`--server` vs `--worker`; `lake` needs an args check for ` serve` to avoid matching some other
   future `lake` subcommand, e.g. `lake build`/`lake exe cache get`, which `base_client.py` also
   invokes via `subprocess.run`, confirmed at `leanclient/base_client.py:51-57,128-131`).
2. **`lake serve` and `lean --server` retain a controlling TTY** (`pts/11` above) inherited from
   the pty of whatever spawned `lean-lsp-mcp`, while `lean --worker` children already show `?`.
   This means the existing script's `tty != "?"` "active session" gate (line 333) **cannot be
   reused** for the Lean pass's candidacy decision — a Lean tree can be fully orphaned (its owning
   Claude Code session long gone) while `lake serve`/`lean --server` still show a non-`?` tty
   inherited from a pty that itself may no longer be attached to a live foreground session. The
   new pass must gate on its own predicate (comm+args+cpu+age), not on TTY.
3. **A zombie (`<defunct>`) Lean process was observed in the wild** (PID 3744087, parent PID
   3557690 — a still-alive `lean-lsp-mcp` python process, `etimes` ~85610s / ~23.8h). `ps`
   renders its `comm` as `lake <defunct>`, which an exact `case "$comm" in lake) ...` match
   naturally rejects — confirmed safe by construction, not something to special-case, since
   sending a signal to an already-dead (zombie) process reclaims nothing; only its parent's
   `wait()` can reap it. Recommend explicitly excluding rows with `<defunct>` in `comm` (or `Z` in
   a `stat` column) as a documented, deliberate exclusion rather than an accidental side effect,
   so a future refactor doesn't inadvertently start matching on a substring that would defeat it.
4. **Termination hierarchy confirmed structurally**: `lake serve` (root) → `lean --server`
   (single child observed) → N × `lean --worker` (leaf children, one per open file). `ppid` of
   each worker equals the server's `pid`; `ppid` of the server equals `lake serve`'s `pid`. This
   validates the dispatch's stated termination order (workers → server → `lake serve`) as
   directly derivable from `pid`/`ppid` in a single Lean-scoped snapshot — no additional process
   tree walk (e.g. via `pstree` or `/proc/*/status`'s `PPid:`) is needed.
5. **A separately-scoped snapshot works and is simpler than widening the shared one.** Verified
   live: `ps -C lake,lean -o pid,ppid,uid,etimes,rss,pcpu,comm,cgroup:200,args --no-headers`
   returns exactly the Lean-family rows (note: `-C` must not be combined with `-e` in the same
   invocation — `ps -eo ... -C lake,lean` silently ignores the `-C` filter and returns the entire
   process table; `ps -C lake,lean -o ...` is the correct, order-sensitive form). This confirmed
   command is the recommended basis for the new pass's own `take_lean_snapshot()`-style function,
   independent of `SNAPSHOT_PS_FIELDS`/`take_snapshot()`.

### `lean_lsp_mcp` / `leanclient` Source Confirmation

Read directly from the installed packages (`~/.local/share/uv/tools/lean-lsp-mcp/lib/python3.13/
site-packages/`):

- `leanclient/base_client.py:61-67` spawns the LSP server via
  `subprocess.Popen(["lake", "serve", "--", "-Dserver.reportDelayMs=0"], ...)` — confirming the
  exact argv the new predicate's `lake` branch must match against.
- `lean_lsp_mcp/client_utils.py` defines `_close_client()` (line 65) and calls it only from three
  sites: an LRU-eviction-adjacent path (line 135, restart), a failed-restart path (line 152), and
  MCP server shutdown (line 196) — confirming the dispatch's claim that teardown happens **only**
  at shutdown/explicit eviction, never on an idle timer. No idle-timeout or LRU-by-inactivity
  mechanism exists in the installed version; the "eviction" at line 135 is keyed to server-restart
  logic, not wall-clock idleness. This is external, third-party behavior outside this repo's
  control — the reclamation pass is the correct (and only) place to add idle-based teardown.

### External Resources

No web research was needed for this task: it is entirely internal shell-script/process-management
work grounded in this repo's own script, its existing test suite's conventions, and directly
observable live process state plus the installed third-party package's source — consistent with
the `meta` task type's routing (context files + existing skills; no web search required for pure
`.claude/`-system shell work).

### Recommendations

1. **New predicate function `is_lean_lsp_executable_comm(comm, args)`** (naming parallel to
   `is_claude_executable_comm`), returning which of `lake_serve`/`lean_server`/`lean_worker` (or
   none) a row is — e.g. via a global result variable or three separate boolean predicates
   (`is_lean_serve_comm`, `is_lean_server_comm`, `is_lean_worker_comm`), whichever the plan phase
   finds more testable in isolation (the existing suite's per-predicate-function assertions favor
   three small functions over one multi-valued one, for parity with how `is_claude_executable_comm`
   itself is tested as a single yes/no gate per call).
2. **Separate snapshot function** (e.g. `take_lean_snapshot()`) using the verified
   `ps -C lake,lean -o pid,ppid,uid,etimes,rss,pcpu,cgroup:200,comm,args --no-headers` form,
   reusing `is_system_slice_cgroup`/`is_owned_by_current_uid` unchanged (per the dispatch's
   "reuse as defense in depth" instruction) and `get_vmswap_kb`/`format_memory` from task 158
   unchanged for reporting.
3. **Idle gate**: `pcpu` (from the snapshot, procps-ng's recent/decaying-average CPU%, not a
   lifetime average) at/near `0` AND `etimes >= LEAN_IDLE_THRESHOLD_MIN * 60` (env-overridable,
   default conservative — existing repo precedent uses 240 minutes for comparable
   reap-threshold env vars, e.g. `ORCHESTRATOR_SESSION_REAP_MIN`,
   `TASK_LOCK_REAP_MIN`/`SESSION_REGISTRY_REAP_MIN`; the dispatch's single 13h data point argues
   for something well below 13h but still generous — 240 min / 4h is a defensible, precedented
   default to propose to the plan phase, not a final number this report is locking in).
4. **Tree-wide gating, not per-row**: for each `lake serve` root, walk its `ppid`-linked
   `lean --server` child (if any) and that server's `ppid`-linked `lean --worker` children (if
   any) entirely from the one Lean snapshot's in-memory rows (no live re-query); the tree is a
   reclamation candidate only if **every** member (root + server + all workers) independently
   passes the idle+cpu gate and the two reused exclusion predicates. A tree with zero workers
   (server with no open files) or a `lake serve` with no discovered server child are edge cases
   the plan should decide how to handle (likely: still eligible if idle, since a done-but-not-yet-
   torn-down `lake serve` with no server is itself reclaimable).
5. **Termination order implementation**: reuse (factor out, don't duplicate) the existing
   SIGTERM→sleep→SIGKILL escalation loop (lines 408-436) as a shared `terminate_pid()` helper
   called first for every worker PID in a tree, then the server PID, then the `lake serve` PID —
   satisfying "workers → server → `lake serve`" strictly, and per-tree (independent trees, if
   multiple `lean-lsp-mcp` instances are running, are handled one at a time, each with its own
   ordering).
6. **Ordering assertion for the acceptance bar**: extend the fake-`ps`-on-`PATH` fixture pattern
   already used for assertion (d-2)/(e) with a companion fake `kill` on `PATH` that appends
   `"$2 (signal $1)"`-style lines to a `mktemp` log file instead of actually signaling anything;
   assert the log's PID order is workers (any order among siblings), then server, then `lake
   serve` — proving ORDER, not merely that all four are eventually reported terminated.
7. **`SKILL.md`/`refresh.md` doc updates**: add a fifth bullet to both files' parallel
   "Process Safety"/"Process Protection" sections describing the new predicate, the reused
   defense-in-depth exclusions, the configurable idle threshold, and the strict termination
   order — mirroring the existing four-bullet prose exactly in style. Additionally close the
   pre-existing gap noted in Findings: Step 2 has no explicit `AskUserQuestion` JSON block despite
   the tool being declared allowed; the new pass is a natural trigger to add one (a single
   combined confirmation covering both Claude and Lean orphans, or two distinct prompts — a plan
   decision, not resolved here).
8. **`--dry-run`-clean requirement**: the new pass's default/`--dry-run` path must only ever
   report (println candidate trees + reclaimable VmSwap-aware memory), matching the existing
   Claude pass's identical no-flag/`--dry-run` equivalence (lines 376-399) — no new flag is needed
   for the Lean pass specifically; it participates in the same `--dry-run`/`--force` contract.

## Decisions

- The new pass will NOT reuse `SNAPSHOT_PS_FIELDS`/`take_snapshot()`; it takes its own
  `ps -C lake,lean -o ...` snapshot. Rationale: avoids touching three existing test fixtures'
  fake-`ps` scripts and keeps the two passes verifiably independent, matching "NEW,
  SEPARATELY-GATED" in the dispatch.
- The new pass will NOT use the existing `tty != "?"` branch as any part of its candidacy logic
  (confirmed live: `lake serve`/`lean --server` retain a non-`?` tty even when fully orphaned).
- `is_system_slice_cgroup` and `is_owned_by_current_uid` will be called, unmodified, against Lean
  candidate rows — no changes to either function's body.
- `is_claude_executable_comm` will not be touched in any way (hard constraint, verified
  byte-identical is achievable since the new code is fully additive).

## Risks & Mitigations

- **Threshold-too-low risk** (named explicitly in the dispatch): mitigated by defaulting
  conservatively (proposed 240 min, matching existing repo precedent for comparable reap
  thresholds) and making it env-overridable; costs a rebuild (MCP respawns automatically) if wrong,
  never data loss — confirmed by the dispatch's own framing and by `_close_client`'s clean-teardown
  behavior in `client_utils.py`.
- **Misclassifying a busy tree as idle**: mitigated by the tree-wide (all-members-must-pass) gate
  recommended above — a single actively-computing worker (low `etimes` or nonzero recent `pcpu`)
  protects its entire tree from reclamation, not just itself.
- **Zombie/defunct rows**: confirmed harmless by construction (exact-`case` match already excludes
  `"lake <defunct>"`/`"lean <defunct>"`); recommend a code comment recording this as deliberate,
  not accidental, so a future refactor doesn't "fix" it into matching zombies.
- **Ordering-not-verified test gap**: mitigated by the fake-`kill`-on-`PATH` fixture pattern
  recommended above, directly extending this suite's own established fake-`ps` precedent.
- **Test-suite mutation-check gap**: the existing suite's mutation check pins a pre-fix commit
  hash specific to the VmSwap-accounting rewrite; the new predicate's tests will need their own
  non-vacuousness argument (either a similarly pinned pre-task commit once this task lands, or —
  since predicate functions are new, not modified — a simpler "function does not exist before this
  change" absence check, mirroring the existing suite's own reasoning for why a dynamic re-run
  isn't attempted).

## Context Extension Recommendations

- **Topic**: Lean LSP process-tree shape and its interaction with `claude-refresh.sh`'s
  TTY-based candidacy heuristic.
- **Gap**: No context file documents that `lake serve`/`lean --server` retain a controlling TTY
  inherited from their spawning pty even once fully orphaned — a fact this research had to
  establish via live `ps` inspection rather than any existing doc. Everything else here is either
  inline in `claude-refresh.sh`'s own header/comments (which is the existing, correct home for
  this kind of detail) or in task 158's already-completed artifacts.
- **Recommendation**: once this task's plan/implementation phases land, the new predicate's
  header comment (following this script's own established convention of documenting *why*, not
  just *what*, directly above the predicate) is the right place for this fact — no standalone
  context file is warranted for a single script's internal design rationale, consistent with how
  the existing four predicates are documented today (inline, not in a separate context doc).

## Appendix

### Search queries / commands used

- `grep -n "VmSwap\|is_system_slice_cgroup\|is_owned_by_current_uid\|is_claude_executable_comm" agent-system/extensions/core/scripts/claude-refresh.sh`
- `ps -eo pid,ppid,comm,etimes,rss,args --no-headers | grep -iE "lake|lean"`
- `ps -eo pid,ppid,comm,pcpu,etimes,time,tty,args --no-headers -p <lean-tree-pids>`
- `ps -C lake,lean -o pid,ppid,uid,etimes,rss,pcpu,comm,cgroup:200,args --no-headers` (confirmed
  working; the `-eo ... -C ...` combined form was tried first and confirmed NOT to filter)
- `grep -n "Popen\|subprocess" leanclient/base_client.py`
- `grep -n "_close_client" lean_lsp_mcp/client_utils.py`
- `grep -n "REAP_MIN\|THRESHOLD" agent-system/extensions/core/scripts/reap-session-runtime-files.sh`, `context/patterns/task-lock.md`

### References

- `agent-system/extensions/core/scripts/claude-refresh.sh` (451 lines, current)
- `agent-system/extensions/core/scripts/tests/test-claude-refresh-matcher.sh` (426 lines, current)
- `agent-system/extensions/core/skills/skill-refresh/SKILL.md`
- `agent-system/extensions/core/commands/refresh.md`
- `agent-system/extensions/core/context/standards/shell-script-testing.md`
- `specs/158_vmswap_aware_refresh_memory_accounting/{reports,plans,summaries}/01_*`
- `~/.local/share/uv/tools/lean-lsp-mcp/lib/python3.13/site-packages/leanclient/base_client.py`
- `~/.local/share/uv/tools/lean-lsp-mcp/lib/python3.13/site-packages/lean_lsp_mcp/client_utils.py`
