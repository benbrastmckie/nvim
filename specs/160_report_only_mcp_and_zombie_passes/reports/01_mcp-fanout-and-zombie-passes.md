# Research Report: Report-Only MCP Fan-Out and Zombie Passes

- **Task**: 160 - Add report-only refresh passes for unused MCP fan-out and unreaped child processes
- **Started**: 2026-09-07T20:18:53Z
- **Completed**: 2026-09-07T20:25:00Z
- **Effort**: ~1 hour (research only)
- **Dependencies**: 159 (Lean LSP reclamation pass) — file-overlap serialization only, not a logical prerequisite
- **Sources/Inputs**:
  - `agent-system/extensions/core/scripts/claude-refresh.sh` (939 lines, current state after task 159)
  - `agent-system/extensions/core/scripts/tests/test-claude-refresh-matcher.sh` (746 lines, assertions a-g)
  - `agent-system/extensions/core/skills/skill-refresh/SKILL.md`, `agent-system/extensions/core/commands/refresh.md`
  - `agent-system/extensions/core/docs/docs-README.md` (line 78 false claim)
  - `agent-system/extensions/core/context/patterns/mcp-server-ownership.md` (298 lines, full read)
  - Live process inspection: `ps -eo`, `/proc/PID/status` (VmSwap), `~/.claude.json`
  - `specs/state.json` (task 160 and 159 entries), `specs/TODO.md`
- **Artifacts**: this report
- **Standards**: report-format.md, subagent-return.md

## Executive Summary

- The claimed "subagent barrier" to project-scoped MCP servers is confirmed disproven by
  `context/patterns/mcp-server-ownership.md` itself (its own "session-start snapshot trap" and
  preceding sections); the real cost is one-time workspace trust. `docs-README.md` line 78 still
  states the disproven claim verbatim and is the one file this task must correct.
- Live process inspection reproduces the task's premise almost exactly: 6 active sessions (not
  5 — a live-count difference, not a discrepancy) each fan out `lean-lsp` (1 proc) +
  `playwright` (2 procs: an `npm exec @playwright/mcp@latest` wrapper plus its `node ... MainThread`
  child) = 3 procs/session, 18 procs total, with **zero** `chromium`/`headless_shell` processes
  anywhere on the system — confirming playwright has spawned no browser in any session.
- Combined RSS+VmSwap (the task-158-era VmSwap-aware accounting already in `claude-refresh.sh`)
  across these 18 processes is currently ~976 MB (~147 MB RSS + ~832 MB VmSwap) — most of the
  cost is swapped-out, which is exactly why a naive RSS-only accounting would understate it.
- Both target zombie classes are live and reproducible right now: 7 `sd_*` `<defunct>` children
  of `speech-dispatcher` (PID 2723182, ~6.09 days old) and one `lake <defunct>` child of a
  `lean-lsp-mcp` process (~16.7 hours old) — matching the description's "7 sd_* zombies over 6
  days" and single `lake <defunct>` exactly.
- Critical nuance for the advisory text: `mcp-server-ownership.md` itself classifies `lean-lsp`
  as the worked example of "per-project computed arguments, user scope is correct" and
  `playwright` as the worked example of "genuine machine capability, user scope is correct" — so
  the new pass's advisory must not blanket-recommend moving either server to project scope; it
  should report the finding (idle fan-out + its memory cost) and advise scoping only
  conditionally ("if this server is genuinely repo-local"), consistent with the task description's
  own phrasing.
- Recommended implementation shape follows the existing `run_claude_pass`/`run_lean_pass`
  pattern exactly: two new functions (`run_mcp_fanout_pass`, `run_zombie_pass`) called
  unconditionally from `main()` after the existing two, sharing `get_vmswap_kb`/`format_memory`,
  reusing zero termination logic (`terminate_pid` is never called by either), and reporting
  under both `--force` and `--dry-run` with the identical branch (no separate `$FORCE` code path)
  — which is itself the mechanical proof of non-destructiveness the acceptance bar asks for.

## Context & Scope

This is the third task in a `claude-refresh.sh` chain (158: VmSwap-aware accounting → 159: Lean
LSP reclamation pass → 160, this task: two report-only passes). Scope is strictly additive to
`claude-refresh.sh` plus its test suite, `SKILL.md`, `commands/refresh.md`, and one line of
`docs-README.md`. No manifest/deploy-engine code, no termination logic changes to the two
existing passes. The dispatch's CANONICAL SOURCE CONSTRAINT binds all edits to
`agent-system/extensions/core/`; the deployed `.claude/` tree is gitignored and regenerated, never
hand-edited (`.claude/rules/source-store-deploy-boundary.md`).

## Findings

### The scoping-trade-off correction (already true in the source, only docs-README.md lags)

`context/patterns/mcp-server-ownership.md` already states the corrected position, in two places:

- "Workspace trust (a real friction cost, not a blocker)" (lines 92-105): "**Once a workspace is
  trusted, project-scoped servers are fully reachable by dispatched subagents** — directly
  demonstrated, twice, including via the general-research-agent class this system actually
  dispatches, with the permission pre-granted so permission was not a confound. There is no
  categorical subagent access barrier to project scope." It names the real cost precisely: a
  fresh/untrusted workspace requires one-time interactive trust approval, and "a cloned repository
  cannot approve its own servers — there is no way to pre-authorize trust from inside the repo
  itself," but this "is a one-time setup cost, not a per-call or per-session obstacle."
- "The session-start snapshot trap" (lines 107-118): explains the actual mechanism that produced
  the original false negative — a session's tool registry is a startup snapshot, so an
  already-running session (main OR subagent, identically) cannot see a server added to
  `.mcp.json` after that session started. It explicitly instructs: "Anyone re-verifying
  registration or reachability MUST use a fresh session (or `claude -p`), never an already-running
  one."

So this document is already the authority the dispatch names it as; nothing in it needs
correcting. The lag is entirely in `docs-README.md`.

### `docs-README.md` line 78 — confirmed false claim, confirmed sole target

```
77: ### MCP Configuration
78:
79: Custom subagents cannot access project-scoped MCP servers (`.mcp.json`). For subagent access,
80: configure servers in user scope (`~/.claude.json`).
```

(Line numbers as read; the dispatch's "line 78" refers to the blank line 78 immediately preceding
the claim at 79-80, or counts the section header — either way, this is the single occurrence in
this file, immediately after the "### MCP Configuration" heading, right before the "## Guides"
section.) A repo-wide grep for the same wording found it in exactly one place in scope for this
task:

- `agent-system/extensions/core/docs/docs-README.md:78` — **in scope, per FILES list**.

Two other locations carry the identical (or near-identical) claim but are **out of scope** for
this task under the CANONICAL SOURCE CONSTRAINT (edits bound to
`agent-system/extensions/core/`) and the dispatch's own FILES list (docs-README.md only):

- `.opencode/docs/README.md:227` and `.opencode/extensions/core/docs/README.md:227` — the
  OpenCode-system mirror of this same doc, carrying the same sentence verbatim. Not touched by
  this task; worth a follow-up task if OpenCode's docs are meant to stay in sync with Claude
  Code's corrected position (recorded here, not created as a task per this agent's "no context-gap
  task creation" constraint).
- `.claude/docs/docs-README.md` (deployed, gitignored) — will self-correct automatically the next
  time the deploy tree is regenerated from the corrected source; never hand-edited directly.

Several archived task artifacts (`specs/archive/023_.../`, `specs/archive/028_.../`,
`specs/vault/.../386_.../`) discuss or quote this same claim historically; these are inert
historical records, not live documentation, and are correctly out of scope.

### Live reproduction of the MCP fan-out premise

`~/.claude.json`'s top-level `mcpServers` (user scope) currently registers exactly two servers,
matching the task description:

```json
{
  "lean-lsp": {"type": "stdio", "command": ".../lean-lsp-mcp-wrapper.sh", "args": [...]},
  "playwright": {"type": "stdio", "command": "playwright-mcp", "args": []}
}
```

Live `ps` inspection found **6** active Claude Code sessions (the description's "5" is simply an
earlier live count — sessions come and go; this is not a discrepancy to resolve, and the new
pass must compute this dynamically, never hard-code a count). Each session fans out identically:

- `lean-lsp`: 1 process (`python3.13 .../lean-lsp-mcp --lean-project-path
  /home/benjamin/Projects/BimodalLogic`) per session — 6 total.
- `playwright`: 2 processes per session — an `npm exec @playwright/mcp@latest ...` wrapper and
  its `node .../playwright-mcp ... MainThread` child — 12 total.

18 processes total (matches the description's "3 procs" per session). A system-wide search for
`chromium`/`headless_shell` (the browser playwright-mcp would spawn on first navigation) found
**zero** matches anywhere — direct, current confirmation that playwright has spawned no browser
in any of the 6 sessions, exactly as the task description states.

Combined memory via the existing VmSwap-aware accounting (`get_vmswap_kb` + `rss`, summed across
all 18 PIDs, read live during this research pass):

- RSS total: ~147.3 MB
- VmSwap total: ~832.2 MB
- Combined: ~976 MB (~0.95 GB)

This is a live snapshot, not a number to bake into the implementation — it differs from the
task description's "346 MB" (an earlier observation, likely fewer sessions and/or less swap
pressure at the time) precisely because most of the cost here is swapped-out and swap pressure
varies session-to-session. This is itself the strongest argument for the VmSwap-aware accounting
requirement: an RSS-only view would have reported roughly 1/7th of the true cost.

Note on `lean-lsp`'s current usage: unlike `playwright`, `lean-lsp-mcp` in this live snapshot IS
actively backing a real `lake serve` → `lean --server` → 3x `lean --worker` process tree (the
same tree task 159's reclamation pass targets, currently busy/idle-gated separately) for the
`BimodalLogic` project. So a correctly discriminating "no evidence of use" detector must not
flag `lean-lsp` here — only `playwright` should surface as the unused-fan-out case in this
snapshot, which is a meaningful test case for the new pass's specificity.

### Zombie reproduction

Both target zombie classes are live and directly observable right now:

```
2723196 2723182 Z  sd_voxin <defunct>
2723197 2723182 Z  sd_baratinoo <defunct>
2723199 2723182 Z  sd_cicero <defunct>
2723201 2723182 Z  sd_kali <defunct>
2723202 2723182 Z  sd_festival <defunct>
2723204 2723182 Z  sd_espeak-ng-mb <defunct>
2723306 2723182 Z  sd_openjtalk <defunct>
3744087 3557690 Z+ lake <defunct>
```

- 7 `sd_*` zombies, all children of `speech-dispatcher` (PID 2723182, `elapsed` ≈ 526118s ≈ 6.09
  days) — matches "leaked 7 sd_* zombies over 6 days" exactly. `speech-dispatcher` itself is a
  live, legitimately-running system service (not orphaned) — it simply never `wait()`s these
  particular synthesizer-backend children after they exit.
- 1 `lake <defunct>`, child of a live `lean-lsp-mcp` python process (PID 3557690), `elapsed` ≈
  60031s ≈ 16.7 hours — matches "lean-lsp-mcp never wait()s its lake child, leaving `lake
  <defunct>`" exactly.
- `rss` for a zombie row is 0 (confirmed live) — a zombie holds no memory pages, only a PID slot
  and its exit-status kernel record, confirming the description's "cosmetic — PID slots only."

Zombie state is unambiguously distinguished via `ps`'s `stat` column containing `Z` (`Z` or
`Z+`), which is not reused anywhere else in `claude-refresh.sh`'s existing predicates — a clean,
independent detection axis, and one already partially proven-safe: task 159's own Lean-pass
comment (lines 202-205 in `claude-refresh.sh`) explicitly documents that a defunct row's `comm`
already renders as `lake <defunct>` and that the existing exact-match `case` statement already
excludes it (rejects it as a reclamation candidate) — the codebase already has one data point of
"zombie state must never be treated as a live, signalable candidate."

### Existing code shape to extend (established two-pass precedent)

`claude-refresh.sh` (939 lines) already establishes the exact pattern this task's two new passes
should follow, set by task 159's Lean pass:

- `main()` (lines 903-935) calls two independent, unconditionally-run functions in sequence —
  `run_claude_pass "$FORCE" "$DRY_RUN"` then `run_lean_pass "$FORCE" "$DRY_RUN"` — each of which
  takes its own snapshot, reports under `--dry-run`/no-flag, and only takes destructive action
  under `--force`. Adding a third and fourth pass means two more functions
  (`run_mcp_fanout_pass`, `run_zombie_pass`) called after the existing two, in the same
  `"$FORCE" "$DRY_RUN"` calling convention for symmetry, even though neither will ever act on
  `$FORCE` to signal anything.
- Shared helpers directly reusable, unmodified: `get_vmswap_kb` (lines 553-558),
  `format_memory` (522-536), `get_process_age` (504-520), `is_system_slice_cgroup`/
  `is_owned_by_current_uid` (defense-in-depth exclusions, reusable for the zombie pass's parent
  process if desired — a zombie's own uid/cgroup are frequently unreadable/inherited oddly, so
  the exclusion may be more naturally applied to the *parent*, a design decision for planning).
  `terminate_pid` (605-632) must **not** be called by either new pass — this is precisely what
  "never terminates anything" and the acceptance bar's "no code path in either pass reaches a
  signal call" require, and is grep-verifiable (`grep -n 'kill -' claude-refresh.sh` scoped to
  the new functions should show zero matches, unlike the existing two passes which legitimately
  call `kill` via `terminate_pid`).
- `validate_cgroup_support` (574-584) already runs once in `main()` before any pass; the MCP/
  zombie passes can rely on cgroup data being available without re-validating.
- Test suite precedent: `test-claude-refresh-matcher.sh` (746 lines) uses lettered assertion
  blocks (a) through (g), a `pass()`/`fail()`/`info()` counter harness, a `mktemp -d` sourced-copy
  model, and a mutation check at the end pinning a specific pre-fix commit and asserting the
  count of newly-required function names absent from it. A task-160 addition would add
  assertions (h)/(i) for the MCP and zombie passes respectively (or a combined next letter),
  extend the `MISSING_IN_PREFIX` function-name list with `run_mcp_fanout_pass`/`run_zombie_pass`
  (and any new predicate helpers), and — since this task doesn't touch existing predicates — the
  mutation check's existing pinned commit reasoning stays valid; no new pin needed unless the new
  functions' historical absence needs its own proof point (they trivially don't exist in any
  commit before this task, so the existing "PREFIX_COMMIT predates this task entirely" framing
  extends without modification).
- `SKILL.md`/`refresh.md` precedent: both files carry a "Lean LSP process-tree pass (separately
  gated)" bullet under "Process Safety" describing gate, mechanism, and recoverability. The two
  new passes need equivalent bullets, but since neither is destructive, their bullets should be
  explicit that they are *report-only advisories* — no confirmation-prompt integration is needed
  in `SKILL.md`'s Step 2 (which currently checks output text for "No orphaned processes found."/
  "No idle Lean LSP process trees found." to decide whether to prompt via `AskUserQuestion`) since
  neither new pass ever offers a terminate action to confirm.

## Decisions

- The MCP fan-out pass's "evidence of use" check cannot be one generic heuristic across all
  servers — it is necessarily server-shaped (e.g., for `playwright`: absence of any
  `chromium`/`headless_shell` process is the concrete evidence-of-non-use signal available
  today; for `lean-lsp`: presence/absence of its `lake serve` tree, which task 159's pass already
  detects via `detect_lean_candidate_trees`/`take_lean_snapshot`, is a natural reuse point). This
  is a planning-level design decision, not resolved here, but the research establishes that a
  purely generic "no evidence of use" signal does not exist across arbitrary MCP servers and the
  plan should scope the pass to what is concretely detectable today (starting with `playwright`,
  the one server with an unambiguous zero-evidence signal) rather than promising false precision
  for servers where no such signal exists yet.
- The advisory text must be worded conditionally ("if this server is genuinely repo-local,
  consider project scope; the cost is a one-time workspace-trust approval") rather than
  recommending scoping either currently-registered server outright — `mcp-server-ownership.md`
  itself classifies both `lean-lsp` and `playwright` as legitimately user-scoped today for
  different reasons (per-project computed args; genuine machine capability, respectively). The
  report should surface the *tension* (playwright is user-scope "by design" per that doc, yet
  empirically produces zero evidence of use across every current session) without resolving it
  unilaterally — that is a call for the user, not this pass.
- Session counting must be computed dynamically from the live process snapshot (grouping each
  server's process(es) by session), never hard-coded — the observed "6" here vs. the task
  description's "5" is exactly the kind of number that changes session-to-session.

## Recommendations

1. Add `run_mcp_fanout_pass` to `claude-refresh.sh`: read `~/.claude.json`'s user-scope
   `mcpServers` keys via `jq` (a new, narrowly-scoped external dependency already implicitly
   available — verify `jq` availability at the top of the function, matching this script's
   existing "fail loudly rather than silently degrade" convention seen in `take_snapshot`/
   `take_lean_snapshot`); for each registered server, count sessions and aggregate
   RSS+VmSwap using the same `get_vmswap_kb`/`format_memory` helpers; apply the server-specific
   evidence-of-use check (playwright: no chromium/headless_shell process anywhere); emit the
   report table (server name, session count, aggregate memory) plus the conditional advisory
   text for any server flagged unused. Never call `terminate_pid` or `kill`.
2. Add `run_zombie_pass`: take a `ps -eo pid,ppid,stat,etimes,comm` snapshot (or extend the
   existing `SNAPSHOT_PS_FIELDS` read if it can be reused without perturbing existing tests —
   check field-count assumptions in `test-claude-refresh-matcher.sh`'s synthetic fixtures first),
   filter rows whose `stat` contains `Z`, group by parent (`ppid`) for a readable report (e.g.
   "speech-dispatcher (PID N): 7 zombie children, age ~Xh"), and report age via the existing
   `get_process_age`. Never call `terminate_pid` or `kill`.
3. Call both new functions unconditionally from `main()`, after `run_lean_pass`, in the same
   `"$FORCE" "$DRY_RUN"` convention; since neither branches on `$FORCE` for anything other than
   the identical `[DRY RUN]` banner line the existing passes already print, `--dry-run` and
   `--force` output for these two passes is byte-identical modulo that banner — which is the
   direct, mechanical demonstration of non-destructiveness the acceptance bar names.
4. Extend `test-claude-refresh-matcher.sh` with new lettered assertions covering: zombie-state
   detection (`Z`/`Z+` distinguished from live `S`/`R` rows, using synthetic fixture rows rather
   than relying on real zombies existing at test time), the MCP pass's per-server session-count
   and memory-aggregation arithmetic, the evidence-of-use discriminator (a fixture with a
   chromium-like row present vs. absent), and a grep-based structural assertion that neither new
   function's body contains a `kill -` invocation — satisfying the acceptance bar's "verify by
   grep, not by inspection" instruction directly in the test suite rather than as a one-off manual
   check.
5. Update `SKILL.md` and `commands/refresh.md` with two new "Process Safety" bullets describing
   both passes as report-only advisories, explicitly stating they never terminate anything and
   require no `AskUserQuestion` confirmation wiring (contrast with the Lean/Claude passes' prompt
   integration in `SKILL.md` Step 2).
6. Correct `docs-README.md` lines 78-80: replace the categorical subagent-barrier claim with the
   workspace-trust framing, and add a pointer to
   `context/patterns/mcp-server-ownership.md` as the authority — mirroring that document's own
   "Workspace trust" section wording rather than inventing new phrasing.
7. Do not touch `.opencode/docs/README.md` / `.opencode/extensions/core/docs/README.md` — out of
   scope per the FILES list and CANONICAL SOURCE CONSTRAINT; note it as a known, unaddressed
   duplicate for a future task if OpenCode docs are meant to track this correction.

## Risks & Mitigations

- **Risk**: a generic "evidence of use" detector could be over-engineered or under-specified,
  producing false "unused" reports for a server that is legitimately idle mid-session (e.g. a
  lean-lsp session between tool calls). **Mitigation**: scope the detector per-server rather than
  generically, starting only with the concretely-detectable `playwright` case; leave headroom to
  extend rather than promising a universal heuristic now.
- **Risk**: extending `SNAPSHOT_PS_FIELDS` or adding a new `ps` invocation with a `stat` column
  could silently break existing synthetic test fixtures in `test-claude-refresh-matcher.sh` if
  those fixtures assume a fixed field count via `read`. **Mitigation**: take a separate,
  independent `ps` snapshot for the zombie pass (mirroring how the Lean pass took its own
  `LEAN_SNAPSHOT_PS_FIELDS` rather than widening the Claude pass's fields) — this was already the
  precedent set by task 159 for exactly this reason.
- **Risk**: `jq` may not be assumed available in every deployment environment the way `ps`/`awk`
  are. **Mitigation**: verify `jq` is on `PATH` at the top of `run_mcp_fanout_pass` and fail loudly
  (matching `take_snapshot`'s "fail loudly rather than silently degrade" convention) rather than
  silently skipping the pass.
- **Risk**: reporting a specific memory total in documentation or commit messages could go stale
  immediately (as this report's own ~976 MB figure already will). **Mitigation**: never hard-code
  observed figures into the implementation or its comments; the script must compute them live on
  every invocation, exactly as the existing passes already do.

## Appendix

- Live evidence commands used: `jq '.mcpServers' ~/.claude.json`; `ps -eo pid,ppid,comm,etimes,rss,args`
  filtered for `claude`/`playwright`/`lean`/`lake`; `ps -eo pid,ppid,stat,comm,args` filtered for
  `stat ~ /Z/`; per-PID `awk '/^VmSwap:/ {print $2}' /proc/PID/status`.
- Repo-wide grep for the false claim: `grep -rn "cannot access project-scoped" --include="*.md" .`
- Section/function line references above are to
  `agent-system/extensions/core/scripts/claude-refresh.sh` as of this research pass (939 lines,
  post-task-159 state) and
  `agent-system/extensions/core/scripts/tests/test-claude-refresh-matcher.sh` (746 lines).
