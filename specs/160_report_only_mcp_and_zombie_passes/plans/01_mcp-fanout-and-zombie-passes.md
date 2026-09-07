# Implementation Plan: Report-Only MCP Fan-Out and Zombie Passes

- **Task**: 160 - Add report-only refresh passes for unused MCP fan-out and unreaped child processes
- **Status**: [IMPLEMENTING]
- **Effort**: 5 hours
- **Dependencies**: 159 (Lean LSP reclamation pass) — file-overlap serialization on `claude-refresh.sh` only, not a logical prerequisite
- **Research Inputs**: specs/160_report_only_mcp_and_zombie_passes/reports/01_mcp-fanout-and-zombie-passes.md
- **Artifacts**: plans/01_mcp-fanout-and-zombie-passes.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add two strictly additive, report-only diagnostic passes to `claude-refresh.sh` — one reporting
unused per-session MCP server fan-out with VmSwap-aware memory accounting, one reporting unreaped
`<defunct>` children — plus the documentation correction that removes the disproven
subagent-cannot-reach-project-scope claim from `docs-README.md`. Neither new pass ever reaches a
signal call; both follow the two-pass `run_claude_pass`/`run_lean_pass` precedent exactly, taking
their own independent `ps` snapshots and reusing `get_vmswap_kb`/`format_memory`/`get_process_age`
unmodified. Definition of done: both passes produce byte-identical output under `--dry-run` and
`--force` (modulo the existing `[DRY RUN]` banner), the test suite proves zombie-state
discrimination and the absence of any `kill` in either new function by grep, and the scoping
advisory cites workspace trust while containing no subagent-barrier claim.

### Research Integration

Findings from `reports/01_mcp-fanout-and-zombie-passes.md` that shape this plan directly:

- `context/patterns/mcp-server-ownership.md` already carries the corrected position in its
  "Workspace trust" and "The session-start snapshot trap" sections; **only** `docs-README.md`
  lags. Phase 1 mirrors that document's wording rather than inventing new phrasing.
- No generic cross-server "evidence of use" heuristic exists. The detector must be server-shaped:
  `playwright` has an unambiguous zero-evidence signal (no `chromium`/`headless_shell` process
  anywhere on the system); `lean-lsp` was observed live *in genuine use* backing a real
  `lake serve` tree, so a correctly discriminating detector must NOT flag it. Phase 3 scopes the
  pass to what is concretely detectable today and leaves headroom rather than promising
  false precision.
- `mcp-server-ownership.md` classifies both currently-registered servers as legitimately
  user-scoped today (per-project computed args; genuine machine capability). The advisory must
  therefore be **conditional** ("if this server is genuinely repo-local…"), surfacing the tension
  without unilaterally resolving it.
- Session counts and memory totals must be computed live, never hard-coded: research observed 6
  sessions / 18 procs / ~976 MB combined where the task description recorded 5 / 15 / 346 MB —
  a swap-pressure and session-count difference, not a discrepancy.
- Task 159 set the precedent of taking a *separate* `ps` snapshot (`LEAN_SNAPSHOT_PS_FIELDS`)
  rather than widening the Claude pass's fields, precisely to avoid breaking synthetic fixtures
  that `read` a fixed field count. Phase 2 follows it.
- The test suite's mutation check contains an exact-count guard
  (`[ ${#MISSING_IN_PREFIX[@]} -eq 14 ] || [ ... -eq 15 ]`). Adding function names to its loop
  changes that count; Phase 4 must update the guard and its message together or the check fails.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found (`specs/ROADMAP.md` does not exist); no roadmap phases added.

## Goals & Non-Goals

**Goals**:
- Add `run_mcp_fanout_pass` reporting, per user-scope MCP server, the server name, live session
  count, and aggregate RSS+VmSwap memory via the existing VmSwap-aware accounting.
- Emit a conditional scoping advisory that names the workspace-trust cost as the real cost of
  project scope and contains no subagent-access-barrier claim.
- Add `run_zombie_pass` reporting `<defunct>` processes grouped by parent, distinguishing `Z`
  state from live processes, with ages via `get_process_age`.
- Guarantee non-destructiveness mechanically: no code path in either pass reaches a signal call,
  verified by grep in the test suite rather than by inspection.
- Correct the disproven MCP-scoping claim in `docs-README.md` and point to
  `context/patterns/mcp-server-ownership.md` as the authority.

**Non-Goals**:
- Terminating, signalling, or reaping anything — including the zombies themselves (only their
  parents can reap them, and that is out of scope).
- Any change to `run_claude_pass` or `run_lean_pass` detection, termination, or gating logic.
- Any manifest or deploy-engine change (`.mcp.json` generation is separate work; deliberately no
  dependency edge in either direction).
- Correcting the same false claim in the OpenCode mirror (`.opencode/**/docs/README.md`) — out of
  scope per the canonical-source constraint; recorded in Phase 1 as a known unaddressed duplicate.
- Any `AskUserQuestion` confirmation wiring for the new passes — they offer no action to confirm.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| An over-generic "evidence of use" detector false-flags a legitimately idle mid-session server (e.g. `lean-lsp` between tool calls) | H | M | Server-shaped detectors only, starting with the concretely-detectable `playwright` case; a server with no available evidence signal is reported as "no use signal available", never as "unused" |
| Widening `SNAPSHOT_PS_FIELDS` or adding a `stat` column silently breaks synthetic fixtures that `read` a fixed field count | H | M | Take a separate, independent `ps` snapshot for the zombie pass (`ZOMBIE_SNAPSHOT_PS_FIELDS`), mirroring the task-159 precedent |
| `jq` absent from a deployment environment causes silent skip of the MCP pass | M | L | Guard `jq` availability at the top of `run_mcp_fanout_pass` and fail loudly with a named message, matching `take_snapshot`'s fail-loudly convention |
| The mutation check's exact-count guard (14/15) fails after new function names are added to its loop | M | H | Phase 4 updates the count guard, its pass message, and its explanatory comment in the same edit as the loop |
| A future edit reintroduces a signal call into a new pass | H | L | Structural grep assertion in the test suite scoped to the two new function bodies, not a one-off manual check |
| Observed memory/session figures baked into code, comments, or docs go stale immediately | M | M | Never hard-code observed figures; all counts and totals computed live per invocation, as the existing passes already do |
| Advisory text drifts back toward the subagent-barrier claim | M | L | Acceptance grep over emitted advisory text for the banned phrasing, run in Phase 6 |
| Edits land in the gitignored deployed `.claude/` tree and are silently wiped | H | L | All edits target `agent-system/extensions/core/`; Phase 6 verifies no `.claude/**` file was modified |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 2 |
| 3 | 4, 5 | 3 |
| 4 | 6 | 1, 4, 5 |

Phases within the same wave can execute in parallel. Phases 2 and 3 are serialized purely by
file overlap on `claude-refresh.sh`, not by logical dependency; Phase 1 touches a disjoint file
and is genuinely parallel to Phase 2.

---

### Phase 1: Correct the MCP scoping claim in docs-README.md [COMPLETED]

**Goal**: Remove the disproven "custom subagents cannot access project-scoped MCP servers" claim
and replace it with the accurate workspace-trust cost, pointing to the authority document.

**Tasks**:
- [x] Read the `### MCP Configuration` section of
      `agent-system/extensions/core/docs/docs-README.md` (immediately before `## Guides`) *(completed)*
- [x] Replace the two-sentence claim with text stating: project-scoped `.mcp.json` servers are
      fully reachable by dispatched subagents once the workspace is trusted; the real cost is a
      one-time interactive trust approval in an untrusted workspace, and a cloned repository
      cannot pre-authorize its own servers from inside the repo — a one-time setup cost, not a
      per-call or per-session obstacle *(completed)*
- [x] Mirror the wording of `context/patterns/mcp-server-ownership.md`'s "Workspace trust"
      section rather than inventing new phrasing *(completed)*
- [x] Add a pointer naming `context/patterns/mcp-server-ownership.md` as the authority *(completed)*
- [x] Add a one-line note that a session's tool registry is a startup snapshot, so any
      re-verification must use a fresh session or `claude -p` — this affects the main session
      identically and is not subagent-specific *(completed)*
- [x] Confirm by grep that no subagent-barrier phrasing remains anywhere under
      `agent-system/extensions/core/` *(completed: grep returns no matches)*

**Timing**: 0.25 hours

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: Research asserts `docs-README.md` carries exactly one occurrence of the
false claim in scope, and that the two `.opencode/**/docs/README.md` occurrences are out of
scope. Confirm at implementation time with
`grep -rn "cannot access project-scoped" --include="*.md" agent-system/` — if more than one
in-scope hit appears, correct every in-scope hit and record the widened set in the phase
verification notes rather than silently editing only the first.

**Files to modify**:
- `agent-system/extensions/core/docs/docs-README.md` - replace the `### MCP Configuration`
  claim with the workspace-trust framing plus authority pointer

**Verification**:
- `grep -rn "cannot access project-scoped\|subagents cannot access" agent-system/extensions/core/`
  returns no matches
- The replacement text mentions workspace trust and names
  `context/patterns/mcp-server-ownership.md`
- Diff read-through confirms every changed hunk lies inside prose

---

### Phase 2: Zombie / unreaped-child reporting pass [COMPLETED]

**Goal**: Add `run_zombie_pass` to `claude-refresh.sh`, detecting `<defunct>` processes by `stat`
state, grouping them by parent, and reporting them without ever signalling anything.

**Tasks**:
- [x] Add a `ZOMBIE_SNAPSHOT_PS_FIELDS`-style constant and a `take_zombie_snapshot` function
      taking its own independent `ps -eo pid,ppid,stat,etimes,comm` snapshot — do NOT widen
      `SNAPSHOT_PS_FIELDS` or the Lean pass's fields *(completed)*
- [x] Add a `zombie_row_is_defunct` predicate matching a `stat` field containing `Z` (covering
      both `Z` and `Z+`), and rejecting live states (`S`, `R`, `D`, `T`, `I` and their suffixed
      forms) — an independent detection axis not reused by any existing predicate *(completed)*
- [x] Add `run_zombie_pass "$FORCE" "$DRY_RUN"` grouping defunct rows by `ppid`, resolving each
      parent's `comm`, and reporting per parent: parent comm, parent PID, zombie child count,
      the child `comm` names, and the oldest child's age via the existing `get_process_age` *(completed)*
- [x] Report zombie memory as zero-cost explicitly (a zombie holds a PID slot and exit-status
      record, no pages) so the output cannot be misread as reclaimable memory *(completed)*
- [x] Emit a clean "No unreaped child processes found." line when none are present, matching the
      existing passes' no-findings line convention *(completed)*
- [x] Branch on `$DRY_RUN` only for the `[DRY RUN]` banner line; take no `$FORCE` branch at all *(completed)*
- [x] Wire `run_zombie_pass "$FORCE" "$DRY_RUN"` into `main()` after `run_lean_pass`, using the
      same calling convention for symmetry *(completed)*
- [x] Confirm `terminate_pid` and `kill` appear nowhere in the new function bodies *(completed: verified by grep)*

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: Research observed 7 `sd_*` zombies under `speech-dispatcher` and one
`lake <defunct>` under a `lean-lsp-mcp` process. These are live-snapshot observations, not
targets: confirm at implementation time with `ps -eo pid,ppid,stat,comm | awk '$3 ~ /Z/'`, and
verify the pass reports whatever is present then — never hard-code counts, parent names, or ages
into the implementation or its comments.

**Files to modify**:
- `agent-system/extensions/core/scripts/claude-refresh.sh` - add zombie snapshot constant,
  `take_zombie_snapshot`, `zombie_row_is_defunct`, `run_zombie_pass`; add one `main()` call

**Verification**:
- `bash -n agent-system/extensions/core/scripts/claude-refresh.sh` passes
- `claude-refresh.sh --dry-run` and `claude-refresh.sh --force` produce identical zombie-pass
  output apart from the `[DRY RUN]` banner (diff the two captured sections)
- `sed`-extracted bodies of `take_zombie_snapshot`/`zombie_row_is_defunct`/`run_zombie_pass`
  contain no `kill`, no `terminate_pid`
- Manual run reports the live zombies present at the time, grouped by parent, with ages

---

### Phase 3: MCP fan-out reporting pass and scoping advisory [COMPLETED]

**Goal**: Add `run_mcp_fanout_pass` reporting each user-scope MCP server's live session count and
aggregate VmSwap-aware memory, flagging servers with no evidence of use and emitting the
conditional scoping advisory.

**Tasks**:
- [x] Guard `jq` availability at the top of `run_mcp_fanout_pass`; on absence, print a named
      failure line and return — fail loudly, never silently skip *(completed)*
- [x] Read user-scope server names from `~/.claude.json`'s top-level `mcpServers` via `jq`;
      handle the absent-file and empty-object cases with an explicit no-findings line *(completed)*
- [x] Take an independent `ps` snapshot and attribute each server's processes to a session,
      computing the session count dynamically — never hard-code a count *(completed: ppid-chain
      connected-component grouping)*
- [x] Aggregate memory per server as RSS + VmSwap using the existing `get_vmswap_kb` and
      `format_memory` helpers, unmodified *(completed)*
- [x] Implement the evidence-of-use check as a **per-server** discriminator, not a generic
      heuristic: for `playwright`, absence of any `chromium`/`headless_shell` process anywhere on
      the system is the zero-evidence signal; for `lean-lsp`, presence of its `lake serve` tree
      (reusing the Lean pass's existing detection) counts as evidence of use; a server with no
      available signal is reported as "no use signal available", explicitly NOT as unused *(completed:
      verified live -- playwright flagged, lean-lsp not flagged)*
- [x] Emit the report: one row per server with name, session count, process count, and aggregate
      memory, plus a total *(completed)*
- [x] Emit the conditional scoping advisory only for servers flagged as showing no evidence of
      use. It MUST: be conditional ("if this server is genuinely repo-local, consider project
      scope in `.mcp.json`"); state that the cost of project scope is a one-time interactive
      workspace-trust approval, and that a cloned repository cannot pre-authorize its own
      servers; and MUST NOT assert or imply that subagents cannot reach project-scoped servers *(completed)*
- [x] Point the advisory at `context/patterns/mcp-server-ownership.md` as the authority, and note
      that document classifies some user-scope registrations as correct by design *(completed)*
- [x] Branch on `$DRY_RUN` only for the `[DRY RUN]` banner; take no `$FORCE` branch at all *(completed)*
- [x] Wire `run_mcp_fanout_pass "$FORCE" "$DRY_RUN"` into `main()` after `run_zombie_pass` *(completed)*
- [x] Confirm `terminate_pid` and `kill` appear nowhere in the new function bodies *(completed:
      verified by grep)*

**Timing**: 1.5 hours

**Depends on**: 2

**Verification Tier**: local

**Scope Hypothesis**: Research asserts `~/.claude.json` registers exactly two user-scope servers
(`lean-lsp`, `playwright`), fanning out 3 processes per session across 6 sessions (~976 MB
combined). Confirm at implementation time with `jq '.mcpServers | keys' ~/.claude.json` and a
live `ps` count; the implementation must iterate whatever servers are registered and compute
whatever counts are live, so a different result changes only the verification narrative, never
the code. If a third server is registered, verify it lands in the "no use signal available"
branch rather than being mis-flagged as unused.

**Files to modify**:
- `agent-system/extensions/core/scripts/claude-refresh.sh` - add `run_mcp_fanout_pass` and its
  per-server evidence predicates; add one `main()` call

**Verification**:
- `bash -n agent-system/extensions/core/scripts/claude-refresh.sh` passes
- `--dry-run` and `--force` MCP-pass output identical apart from the `[DRY RUN]` banner
- Emitted advisory text greps clean for `cannot access project-scoped` / `subagents cannot` and
  greps positive for workspace-trust wording
- With the live snapshot, `playwright` is flagged (no browser processes) and `lean-lsp` is not
  flagged while its `lake serve` tree is present
- `sed`-extracted `run_mcp_fanout_pass` body contains no `kill`, no `terminate_pid`

---

### Phase 4: Test-suite assertions for both passes [NOT STARTED]

**Goal**: Extend `test-claude-refresh-matcher.sh` with lettered assertion blocks proving zombie
discrimination, MCP aggregation and discrimination, and — by grep — the absence of any signal
call in either new pass.

**Tasks**:
- [ ] Add assertion block (h): zombie-state discrimination using **synthetic fixture rows**
      (not real zombies, which may not exist at test time) — `Z` and `Z+` rows accepted, `S`,
      `R`, `S+`, `Ss`, `Rl` rows rejected by `zombie_row_is_defunct`
- [ ] Add assertion block (h) continuation: full `--dry-run` output shape for the zombie pass
      over a synthetic snapshot — grouping by parent, correct child count, age reported
- [ ] Add assertion block (i): MCP pass per-server session-count and memory-aggregation
      arithmetic over synthetic rows with known RSS/VmSwap values
- [ ] Add assertion block (i) continuation: the evidence-of-use discriminator — a fixture with a
      chromium-like row present (not flagged) versus absent (flagged)
- [ ] Add assertion block (j): structural grep assertion that the extracted bodies of
      `run_mcp_fanout_pass` and `run_zombie_pass` (and their helper predicates) contain zero
      `kill` / `terminate_pid` invocations — this is the acceptance bar's "verify by grep, not by
      inspection" discharged in the suite
- [ ] Add assertion block (j) continuation: the advisory text emitted by `run_mcp_fanout_pass`
      contains no subagent-barrier phrasing and does contain workspace-trust phrasing
- [ ] Extend the mutation check's function-name loop with the new function names
      (`take_zombie_snapshot`, `zombie_row_is_defunct`, `run_zombie_pass`,
      `run_mcp_fanout_pass`, plus any new predicate helpers actually added)
- [ ] Update the mutation check's exact-count guard (`-eq 14` / `-eq 15`) and its pass/fail
      message text to the new expected count in the same edit — the existing pinned
      `PREFIX_COMMIT` stays valid and needs no new pin, since it predates this task entirely
- [ ] Run the full suite and confirm zero failures

**Timing**: 1.25 hours

**Depends on**: 3

**Verification Tier**: full

**Scope Hypothesis**: The mutation check currently expects 14 or 15 absent markers. The new count
is 14/15 plus the number of new function names actually added (four is the planned figure).
Confirm at implementation time by counting the loop's entries after editing rather than assuming
four — the helper set may differ once the passes are written, and a stale guard silently converts
the check into a hard failure.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-claude-refresh-matcher.sh` - new assertion
  blocks (h), (i), (j); extended mutation-check loop and count guard

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-claude-refresh-matcher.sh` exits 0 with
  `Failed: 0`
- Mutation check reports the new expected marker count and passes
- New assertions fail (RED) if either new function is removed from the script — spot-check by
  temporarily renaming one function in a scratch copy

---

### Phase 5: Skill and command documentation for both passes [NOT STARTED]

**Goal**: Document both new passes in `SKILL.md` and `refresh.md` as report-only advisories,
explicitly stating they never terminate anything and need no confirmation wiring.

**Tasks**:
- [ ] Add a "MCP fan-out reporting pass (report-only)" bullet under `### Process Safety` in
      `agent-system/extensions/core/commands/refresh.md`, matching the existing Lean bullet's
      gate/mechanism/recoverability shape but stating that nothing is ever terminated
- [ ] Add a matching "Unreaped-child (zombie) reporting pass (report-only)" bullet in the same
      section
- [ ] Add the same two bullets to `agent-system/extensions/core/skills/skill-refresh/SKILL.md`'s
      `### Process Safety` section
- [ ] Update `SKILL.md`'s Step 2 narrative to state explicitly that the two new passes are NOT
      part of the `AskUserQuestion` confirmation trigger — the prompt logic keys only on the
      Claude-pass and Lean-pass no-findings lines, and must not be extended to the new passes
      since neither offers a terminate action to confirm
- [ ] Verify no observed memory or session figures are baked into either doc

**Timing**: 0.5 hours

**Depends on**: 3

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/commands/refresh.md` - two `### Process Safety` bullets
- `agent-system/extensions/core/skills/skill-refresh/SKILL.md` - two `### Process Safety`
  bullets plus a Step 2 clarification

**Verification**:
- Both files describe both passes as report-only and state they never terminate anything
- `SKILL.md` Step 2 confirmation logic is unchanged in behavior and explicitly scoped to the two
  destructive passes
- Diff read-through confirms every changed hunk is prose

---

### Phase 6: Acceptance verification [NOT STARTED]

**Goal**: Discharge every acceptance criterion mechanically and record the evidence.

**Tasks**:
- [ ] Capture `claude-refresh.sh --dry-run` and `claude-refresh.sh --force` output; diff the two
      new passes' sections and confirm they are identical apart from the `[DRY RUN]` banner
- [ ] `grep -n 'kill\|terminate_pid'` over the extracted bodies of both new passes and their
      helpers — confirm zero matches (grep, not inspection)
- [ ] Grep the emitted advisory text for `cannot access project-scoped` / `subagents cannot` —
      confirm the phrase does not appear
- [ ] Grep the emitted advisory text for workspace-trust wording — confirm it does appear
- [ ] Confirm the zombie pass distinguishes `Z` from live states in the running output
- [ ] Confirm the MCP pass reports server name, session count, and aggregate memory computed via
      the VmSwap-aware path (spot-check one server's total against a manual
      `/proc/PID/status` VmSwap + RSS sum)
- [ ] `grep -rn "cannot access project-scoped" agent-system/extensions/core/docs/docs-README.md`
      returns nothing
- [ ] Run the full test suite one final time; confirm `Failed: 0`
- [ ] `git status --short` shows no modified file under `.claude/` — confirm every edit landed in
      `agent-system/extensions/core/`
- [ ] Confirm no task-number references were introduced outside `specs/**`

**Timing**: 0.5 hours

**Depends on**: 1, 4, 5

**Verification Tier**: full

**Files to modify**:
- None (verification only; any defect found routes back to the owning phase)

**Verification**:
- Every checklist item above passes with captured command output recorded in the summary

---

## Testing & Validation

- [ ] `bash -n agent-system/extensions/core/scripts/claude-refresh.sh` — syntax clean
- [ ] `bash agent-system/extensions/core/scripts/tests/test-claude-refresh-matcher.sh` — exits 0,
      `Failed: 0`, including the extended mutation check
- [ ] `--dry-run` vs `--force` output for both new passes byte-identical modulo the `[DRY RUN]`
      banner (the mechanical proof of non-destructiveness)
- [ ] Zero `kill` / `terminate_pid` occurrences in either new pass, proven by grep in the suite
- [ ] Zombie detection accepts `Z`/`Z+` and rejects live states over synthetic fixtures
- [ ] MCP evidence discriminator flags the zero-evidence fixture and not the in-use fixture
- [ ] Advisory text greps clean for subagent-barrier phrasing and positive for workspace trust
- [ ] `docs-README.md` no longer asserts a subagent barrier anywhere
- [ ] No file under `.claude/` modified

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/claude-refresh.sh` — `take_zombie_snapshot`,
  `zombie_row_is_defunct`, `run_zombie_pass`, `run_mcp_fanout_pass` (+ per-server evidence
  predicates), two new `main()` calls
- `agent-system/extensions/core/scripts/tests/test-claude-refresh-matcher.sh` — assertion blocks
  (h), (i), (j) and an extended mutation check
- `agent-system/extensions/core/skills/skill-refresh/SKILL.md` — two Process Safety bullets plus
  a Step 2 clarification
- `agent-system/extensions/core/commands/refresh.md` — two Process Safety bullets
- `agent-system/extensions/core/docs/docs-README.md` — corrected MCP Configuration section
- `specs/160_report_only_mcp_and_zombie_passes/summaries/01_*-summary.md` — execution summary

## Rollback/Contingency

Every change is additive and file-scoped. Rollback is per-phase: revert the phase's commit(s)
with `git revert`, since each phase commits independently and no phase modifies existing pass
logic. Specifically:

- Phases 2/3 add new functions plus one `main()` call line each — removing the call line disables
  a pass without touching any existing behavior, a minimal-risk partial rollback if a pass proves
  noisy in practice.
- Phase 1 and Phase 5 are prose-only and revert cleanly in isolation.
- Phase 4's mutation-check count guard must be reverted together with whichever of Phases 2/3 it
  covers — reverting a pass without reverting its loop entry leaves the guard expecting a
  function that no longer exists.

If the MCP pass's evidence discriminator proves unreliable in real use, the contingency is to
demote its output to a pure fan-out report (server, sessions, memory) and drop the unused-flag
and advisory entirely, rather than widening the heuristic.
