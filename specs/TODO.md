---
next_project_number: 223
---

# TODO

## Task Order

*Updated 2026-09-16. Generated from state.json dependency graph.*

**Dependency Waves**:
| Wave | Tasks | Blocked by | Topics |
|------|-------|------------|--------|
| 1 | 22,29,39,43,45,74,89,127,129,166,167,168,172,177,184,185,187,188,194,200,202,206,207,209,213,222 | -- | core-agent-system, extensions, literature, ... |
| 2 | 30,51,75,76,136,139,163,173,174,175,198,208,210,214 | 29,74,166,172,188,194,207,209,213 | core-agent-system, extensions, literature, ... |
| 3 | 14,162,193,211,212,216,217,220 | 139,173,174,194,210,214 | core-agent-system, file-scope-lifecycle |
| 4 | 44,164,182,195,199,215,218,221 | 162,175,193,211,212,216,217,220 | core-agent-system, file-scope-lifecycle |
| 5 | 140,165,170,219 | 139,163,164,206,215,218 | core-agent-system, file-scope-lifecycle |
| 6 | 190 | 165 | core-agent-system |

**Grouped by Topic** (indented = depends on parent):

### Core Agent System

89 [NOT STARTED] — Apply the mode-gated section convention to the two remaining...
127 [NOT STARTED] — === REVISED 2026-09-01 (backlog streamline: absorbs the...
129 [NOT STARTED] — Empirically audit \b word-boundary grep patterns for...
166 [NOT STARTED] — Stop research reports drifting from validate-artifact.sh's...
  └─ 136 [NOT STARTED] — Stop implementation agents hand-writing the plan-level Status...
172 [NOT STARTED] — Define a canonical bounded-wait idiom for detached builds
  └─ 173 [NOT STARTED] — Guarantee lake-build-guard.sh writes a terminal record on...
    └─ 220 [NOT STARTED] — Make a guarded Lean build verdict machine-readable so a...
      └─ 221 [NOT STARTED] — Correct the Lean build-verification contracts: never a piped...
  └─ 174 [NOT STARTED] — Add a self-excluding orphaned-build-waiter reaper pass to...
    └─ 217 [NOT STARTED] — Replace RSS+VmSwap over-count with PSS-based reclaimable...
      └─ 218 [NOT STARTED] — Track Lean tree idleness by CPU delta and gate reclamation on...
        └─ 219 [NOT STARTED] — Prompt via desktop notification before killing idle costly...
  └─ 175 [NOT STARTED] — Enforce waiter teardown in the agent contracts that spawn...
    └─ 221 [NOT STARTED] — Correct the Lean build-verification contracts: never a piped... (see above)
184 [NOT STARTED] — Decide the disposition of the Lean/formal skeleton-plan...
185 [NOT STARTED] — Retarget the remaining historical "Stage N" and "Stage MT-N"...
187 [NOT STARTED] — Decide and enforce one commit-attribution convention across...
188 [RESEARCHED] — Fix orchestrate-predispatch-review.sh Class A false positive:...
194 [NOT STARTED] — Align lifecycle agent contracts on .orchestrator-handoff.json...
  └─ 139 [NOT STARTED] — Forbid concurrent-writer history rewrites in git rules and...
    └─ 14 [NOT STARTED] — Prevent implementation-agent fan-out from returning...
    └─ 140 [NOT STARTED] — Add a concurrency-gated history-rewrite predicate to...
  └─ 212 [NOT STARTED] — Detect and recover research dispatches that skip their report...
    └─ 195 [NOT STARTED] — Replace iscontractualhandoffwriter allowlist with a...
200 [NOT STARTED] — Close the consumer-repo deploy propagation gap that leaves...
206 [NOT STARTED] — SOURCE STORE IS THE EDIT TARGET:...
  └─ 170 [NOT STARTED] — Audit and isolate shell test suites from ambient host state...
209 [NOT STARTED] — Set up a fresh repo specs/ state and runtime-file ignore...
  └─ 51 [NOT STARTED] — Stop session-scoped orchestration runtime files from...
  └─ 210 [NOT STARTED] — Fix topic assignment order and zero-topic picker in /task...
    └─ 211 [NOT STARTED] — Stop /task task-type detection from matching incidental keywords
      └─ 44 [PLANNED] — Slim commands/task.md, the largest per-invocation context...
213 [NOT STARTED] — Pass /orchestrate focus text through to the dispatch file
  └─ 214 [NOT STARTED] — Make forced orchestrate phases stop as documented instead of...
    └─ 14 [NOT STARTED] — Prevent implementation-agent fan-out from returning... (see above)
    └─ 193 [NOT STARTED] — Carry concurrent-sibling territory in base-mode dispatch...
      └─ 182 [NOT STARTED] — Add a durable redeploy ledger with content-hash and recency...
      └─ 199 [NOT STARTED] — Decide and implement the working-tree and build isolation...
    └─ 212 [NOT STARTED] — Detect and recover research dispatches that skip their report... (see above)
    └─ 216 [NOT STARTED] — Reset the /orchestrate cycle bound on each run and admit...
      └─ 215 [NOT STARTED] — Add a sanctioned undo for a prepared but never-run...
        └─ 140 [NOT STARTED] — Add a concurrency-gated history-rewrite predicate to... (see above)
        └─ 170 [NOT STARTED] — Audit and isolate shell test suites from ambient host state... (see above)
190 [NOT STARTED] — Fix cross-session admission blindness for self-modifying...

### Extensions

29 [NOT STARTED] — TOPIC CORRECTION (backlog streamline 2026-09-01): re-topiced...
  └─ 30 [NOT STARTED] — TOPIC CORRECTION (backlog streamline 2026-09-01): re-topiced...
43 [NOT STARTED] — Decide and implement how email safety context actually...
74 [NOT STARTED] — Add shared LaTeX build-conflict guard script (detect...
  └─ 75 [NOT STARTED] — Wire build guard into latex extension preflight hook and...
  └─ 76 [NOT STARTED] — Close task-type-keyed hook gap for non-latex agents that...
167 [NOT STARTED] — Make vimtex continuous-build safety always-in-effect via the...
222 [RESEARCHED] — Add a Rust extension to the agent system, modeled on the...

### Literature

39 [PLANNED] — Upgrade Zotero metadata resolution and plan the Zotero 10...
207 [NOT STARTED] — Fix silent truncation in zotero-generate-export.sh Path 1...
  └─ 208 [NOT STARTED] — Explain Path 1 pagination shortfall or revisit Zotero export...

### Neovim

45 [NOT STARTED] — TOPIC CORRECTION + BACKFILL NOTE (task-116 audit). This task...
202 [NOT STARTED] — Make the picker's Reload All] and Regenerate] entries honest...

### Opencode

22 [RESEARCHING] — Freeze .opencode: silence fragment validation spam and record...
168 [NOT STARTED] — Correct the disproven project-scoped MCP claim in the...

### File Scope Lifecycle

162 [RESEARCHED] — Formalize the existing Files to modify convention in...
  └─ 164 [NOT STARTED] — Backfill filescope for existing tasks and decide the...
    └─ 165 [NOT STARTED] — Decide and implement the admission posture for an absent...
163 [NOT STARTED] — Surface missing and empty filescope in validate-state.sh and...
  └─ 165 [NOT STARTED] — Decide and implement the admission posture for an absent... (see above)

### Lean Extension

177 [NOT STARTED] — Add a dependency-tracing recipe to the lean4 extension context
198 [NOT STARTED] — Mandate git-snapshot --no-revert in the lean implementation...

## Tasks

### 222. Add rust extension to agent system
- **Status**: [RESEARCHED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: None
- **Research**: [222_add_rust_extension_to_agent_system/reports/01_add_rust_extension.md]

**Description**: Add a Rust extension to the agent system, modeled on the python and nix extensions, including research into the optimal toolchain and agent configuration for Rust development with AI coding agents like Claude Code, keeping the implementation lean and adding nothing not well-motivated

---

### 221. Correct the Lean build-verification contracts: never a piped status, never a self-matching process scan
- **Effort**: 3 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 220, Task 172, Task 175

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/lean/ (never .claude/**, a disposable deploy artifact regenerated from it).

DEFECT CLASS (both halves observed live in one two-task /orchestrate run against ~/Projects/BimodalLogic): an agent verified its work with an instrument that could not report failure, so correct work looked broken and broken work looked correct. Neither half is a Lean defect.

HALF 1 -- a process-liveness test that can never return empty. `pgrep -f 'lake-build-guard.sh'` matches the polling shell's OWN argv, because the pattern appears in the command line of the shell running the wait. Consequences: two implementation dispatches idled roughly 56 minutes on a build that had already finished green, because the watcher never terminated; a subagent independently cited non-zero "guard: N" process counts as evidence the build was still alive, when every one of those counts was matching the orchestrator's own watcher loops rather than any real guard; and the orchestrator propagated the broken test to a subagent as recommended practice before the subagent caught it. One broken instrument corrupted two agents' evidence.

HALF 2 -- see the dependency task on the guard for the pipe-masked exit code; this task lands the CONSUMER-side half of that fix.

WHAT IS ALREADY COVERED ELSEWHERE, AND WHAT IS LEFT (verified against the current source store, do not re-do the covered part): the guard's own header and `print_help()` ALREADY carry the `pgrep -f` self-match prohibition and the `while kill -0 "$holder_pid"` idiom, and the suite's case 21 already asserts that help text. The bounded-waiter dependency task owns the blocking-wait contract (hard timeout, writer-liveness check, one-waiter-per-log) and the teardown dependency task owns tearing a waiter down. What NO existing task covers is the VERIFICATION-EVIDENCE question: how an agent decides that a finished build passed, and why a process count is never an answer to it. The lean extension's contracts currently leave that vacuum open in four specific, checked places.

WORK.
(a) agent-system/extensions/lean/context/project/lean4/operations/long-builds.md -- add a "Reading the build's verdict" section stating the evidence hierarchy that actually held up in the observed run, strongest last: (1) the guard's own exit code, captured un-piped, or the guard's new `result` mode from the dependency task; (2) the explicit `Build completed successfully (N jobs)` line in the guard's captured output file TOGETHER WITH `grep -c 'error:'` returning 0 over both the captured stdout and the captured stderr; (3) an `.olean`-newer-than-source check per touched module, which proves the module's PRESENCE in the build rather than the mere absence of a complaint and is therefore the strongest of the three. State the prohibition explicitly and once: never pipe the guard invocation into `tail`/`head`/`grep` and then read `$?` -- that is the pipe's exit code, not the guard's; redirect to a log file and capture `GUARD_EXIT=$?` instead. Keep to this file's established single-statement-plus-pointer convention and point at the guard's own documented capture paths rather than restating them.
(b) Same file, "Passive progress checks" -- close the PID vacuum that invites the broken test. The four existing checks all take a `<PID>` the section never tells the reader how to obtain, which is exactly the gap an improvised `pgrep -f` fills. Name the source: `holder_pid` from the guard's record, or `status --verbose`. Add the prohibition that any `pgrep -f` pattern naming the guard, the watcher, or the wrapper script self-matches the polling shell's own argv and can never return empty while the watcher lives; where a real-worker match is genuinely needed, use a non-self-matching pattern (the bracket trick, e.g. `pgrep -f '[b]in/lake build'`, or matching `[c]heck-module-invariants`). Strengthen the existing "liveness caveat" with the sharper statement the run demonstrated: a process count is never evidence of a build's OUTCOME, and a count that cannot go to zero is not evidence of anything at all.
(c) agent-system/extensions/lean/rules/lean4.md -- the "Build Commands" section's canonical invocation shape carries no exit-code discipline. Add the un-piped capture form and a pointer to (a). Do not restate the contract.
(d) agent-system/extensions/lean/agents/lean-implementation-agent.md (step 4 of the verification block) and agent-system/extensions/lean/agents/lean-implementation-hard-agent.md (phase-completion step D and verification step 4) -- all three sites today say `Record: build_passed (true/false)` while specifying no method for determining it. That unspecified predicate is where the false green entered. Replace each with the determination method from (a), pointing at the anchor rather than duplicating the hierarchy.

NOTE ON A NON-DEFECT (checked, do not "fix"): agent-system/extensions/lean/skills/skill-lake-repair/SKILL.md uses `build_output=$(... 2>&1)` followed by `build_exit_code=$?`, which correctly captures the guard's own exit code -- command substitution is not a pipeline. Leave it alone.

MUST NOT. Edit .claude/** (deploy artifact). Edit lake-build-guard.sh or its test suite (the dependency task owns those). Restate the bounded-waiter contract or the teardown rule in these files -- point at their anchors. Duplicate the evidence hierarchy into more than one file.

ACCEPTANCE. No file in the lean extension recommends, or leaves room for, a `pgrep -f` pattern that names the thing doing the polling; every site that records a build verdict names how that verdict is obtained; a reader of the passive-progress section can get a PID without inventing a process scan; redeploy and confirm the deployed tree matches.

DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 220. Make a guarded Lean build verdict machine-readable so a pipeline cannot mask it
- **Effort**: 3 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 173

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**, a disposable deploy artifact regenerated from it).

DEFECT (observed live in a two-task /orchestrate run against ~/Projects/BimodalLogic): an agent reported a Lean build as "exit 0" when it had in fact failed on a module error. The invocation was of the shape `bash lake-build-guard.sh build --timeout 1800 -- build 2>&1 | tail -60`, whose `$?` is `tail`'s exit code, not the guard's. The agent caught and retracted the claim itself, but the orchestrator had already relayed the false green to a sibling dispatch. The instrument could not report failure, so a broken build looked correct.

WHY THIS IS NOT ALREADY FIXED BY THE SIBLING GUARD TASK: the dependency task ("Guarantee lake-build-guard.sh writes a terminal record on every exit path") makes the record TERMINAL so a waiter can always drain -- it is about waiter termination, not about a consumer reading a verdict. Verified against the current source store: `write_inflight_record()`/`finalize_record()` do already record `state=`, `exit_status=`, `holder_pid=`, `log_path=`, and `run_as_holder()` already captures build stdout/stderr to `<root>/.lake/build-guard.stdout` and `.build-guard.stderr`. NONE of those four paths is documented anywhere a consumer would find them: the header's non-goals list mentions only "lock/result/log/capture files under the resolved project's own .lake/ directory" without naming them, and `print_help()` names none of them. There is also no read path -- `main()` dispatches exactly `status|preflight|build`, and `status` reports in-flight state only, never a finished build's verdict. So the machine-readable verdict exists on disk today and is unreachable by contract, which is precisely what pushes a consumer back onto parsing a pipeline's text.

WORK.
(a) Add a `result` subcommand (`lake-build-guard.sh result [--dir DIR] [--verbose]`) that reads `<root>/.lake/build-guard.result` and reports the recorded `state`, `exit_status`, `holder_pid`, `start_epoch`/`end_epoch`, `scope_key`, and the absolute stdout/stderr/log capture paths. Design the exit-code band so the BUILD'S OWN VERDICT is carried by the guard's exit code and never has to be scraped out of text: distinguish at minimum no-record-present, non-terminal (`state=in_flight`, plus whatever terminal-abort state the dependency task introduces), terminal-with-zero, and terminal-with-nonzero. Follow the existing house style for a detect-only mode (see `cmd_status()`: 0 / 10, report on stdout) rather than inventing a new one, and do NOT collide with the reserved 75-79 guard band.
(b) Add an assertion facility so a caller can prove the record describes ITS OWN build rather than a concurrent sibling's. The record is per-project and overwritten by each holder, so a bare read is ambiguous under exactly the concurrency this guard exists to serialize. Evaluate `--expect-pid PID` and `--expect-scope` (matching the caller's own normalized lake argument vector via the existing `compute_scope_key()`); refuse loudly on mismatch rather than reporting a sibling's verdict.
(c) Emit one terminal, stably-prefixed status line on the holder path (house style: the existing `lake-build-guard:` stderr prefix, e.g. `lake-build-guard: STATUS: exit_status=N`), so that even a consumer that ignores (a) and pipes the invocation still sees an unambiguous status token inside its own captured text. This is the belt-and-braces half of the structural fix; it must not appear on the REPLAY path in a way that breaks the existing byte-equality assertions on replayed stdout/stderr (suite cases 1/3).
(d) Document all of it: name `.lake/build-guard.result`, `.lake/build-guard.stdout`, `.lake/build-guard.stderr`, and the log path explicitly in both `print_help()` and the file header, add a `result` row to the USAGE block and the EXIT CODES block, and state in one place that a consumer MUST read the verdict via `result` or an un-piped `$?` and never from a pipeline's last stage.
(e) Extend agent-system/extensions/core/scripts/tests/test-lake-build-guard.sh in its existing numbered-case style: `result` against no record, against an in_flight record, against a terminal-zero record, against a terminal-nonzero record; `--expect-pid`/`--expect-scope` mismatch refusal; the STATUS line present on a fresh build and absent-or-harmless on a replay; and a help-text assertion for the newly documented capture paths in the style of the suite's existing case 21 (which greps `--help` for the `kill -0` and `pgrep` guidance). Add the suite's customary mutation-kill notes explaining which deletion breaks which case.

PRESERVE (existing documented contracts, all verified present): the three-mode subcommand shape, the reserved 75-79 band with its stated meanings, the exit-code passthrough guarantee for a validated lake argument vector, the LAKE_SUBCOMMANDS allowlist behaviour including exit 77, the five-condition staleness policy in `decide_sharing()`, the `lake-build-guard: REPLAY:` marker contract, `--timeout` as a lock-WAIT budget only, and the rule that `cmd_status()` never scans the process table.

MUST NOT. Edit .claude/** (deploy artifact). Change the staleness policy or the sharing decision. Add a second concurrency mechanism. Parse `lake`'s own output format inside the guard (explicitly rejected upstream: the job-count line is a property of lake's text, not of anything the guard records). Touch any file outside this task's file_scope -- the consumer-side contract corrections are a separate dependent task.

ACCEPTANCE. `bash agent-system/extensions/core/scripts/tests/test-lake-build-guard.sh` passes; shellcheck clean; `--help` names all four capture paths and the `result` mode; a caller can obtain a finished build's pass/fail from the guard's own exit code with no text parsing and no pipeline in the invocation.

DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 219. Prompt via desktop notification before killing idle costly Lean trees, with re-verified targeted kill and snooze
- **Effort**: 4 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 218

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**, a disposable deploy artifact).

OBSERVED LIVE (2026-09-15): a Lean LSP tree was reported as "15.1 GB" reclaimable while earlyoom showed 14-16.6 GB available throughout; real reclaim was ~2.3 GB swap plus a little anon. User policy: idle trees that cost nothing may stay; trees that cost memory get a prompt (never a silent kill) after being idle a while. Memory floor 1 GB approved.

WORK (builds on the cost gate and per-tree state file).
(a) Prompt path: when the headless hourly run (--dry-run) finds an eligible tree that is not snoozed or already prompted, launch a detached `systemd-run --user --unit=claude-refresh-prompt-<rootpid>-<starttime>` (the unit name must NOT match claude-*.scope, which the user's claude-session-reaper stops) running `notify-send -a claude-refresh -u critical -t 0 -A default=Kill --wait "Idle Lean tree (<project>)" "idle Xh, N GB reclaimable -- click to kill, dismiss to keep 4h"` (or equivalent that blocks on the chosen action). Project = lake serve cwd (/proc/PID/cwd).
    DESIGN REFINEMENT (notification daemon): the user runs mako with no dmenu-style action launcher, so named notify-send actions cannot be selected by clicking. Therefore use a single `-A default=Kill` action (mako left-click invokes the default action) and treat dismiss / right-click / expiry / no action returned as "Keep" (snooze). Pass `-t 0` so the notification does not auto-expire. The complementary mako rule ([app-name=claude-refresh] default-timeout=0) and the NixOS home-manager install of the timer/service with a correct PATH are handled by a separate ~/.dotfiles task (external, not in this repo).
(b) On the default action ("Kill", i.e. left-click): run `claude-refresh.sh --lean-tree <pid>:<starttime> --force`. The new --lean-tree mode re-verifies starttime identity, still idle, and still over the floor before the existing ordered workers -> server -> root termination; if anything changed, skip and log.
(c) On dismiss / right-click / expiry / any non-default outcome (treated as "Keep"): record snooze_until = now + LEAN_LSP_SNOOZE_MIN (default 240) in the state file. Dedupe so a tree is prompted at most once per snooze window (record prompted state before launching).
(d) Degrade gracefully when notify-send, systemd-run, or a DBus session bus is absent: log only, never kill.
(e) The hourly unit (systemd/claude-refresh.service) ExecStart stays --dry-run; prompting happens only in the separate transient unit. Keep generic units portable, but document that Environment=PATH=/usr/bin:/bin is broken on NixOS and that NixOS installs these units via home-manager (the dotfiles change is a separate task).
(f) Interactive /refresh keeps its AskUserQuestion prompt with the shared gate and numbers.
(g) Tests (fixture /proc via PROC_ROOT, stubbed notify-send/systemd-run on PATH): stubbed notify-send printing "default" -> kill path, printing nothing/other -> snooze path, starttime re-verification refusal (pid reused), still-idle/still-over-floor re-check refusal, snooze dedupe (no second prompt inside window, prompt again after expiry), missing notify-send/systemd-run/DBus degrades to log-only, unit name never matches claude-*.scope.
(h) Docs: commands/refresh.md and skills/skill-refresh/SKILL.md (Pass Inventory rows, --lean-tree flag, env vars LEAN_LSP_IDLE_THRESHOLD_MIN / LEAN_LSP_MEM_FLOOR_MB / LEAN_LSP_SNOOZE_MIN, prompt flow, NixOS note).

MUST NOT. Kill without explicit user action. Change UID/system-slice predicates or termination ordering. Edit .claude/**.

ACCEPTANCE. Tests pass; shellcheck clean; redeploy and confirm; a manual end-to-end check shows one notification per snooze window and a left-click Kill that refuses when the tree became active, and a dismiss that records a 4h snooze.

DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 218. Track Lean tree idleness by CPU delta and gate reclamation on a memory floor
- **Effort**: 3 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 217

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**, a disposable deploy artifact).

OBSERVED LIVE (2026-09-15): a Lean LSP tree was reported as "15.1 GB" reclaimable while earlyoom showed 14-16.6 GB available throughout; real reclaim was ~2.3 GB swap plus a little anon. User policy: idle trees that cost nothing may stay; trees that cost memory get a prompt (never a silent kill) after being idle a while. Memory floor 1 GB approved.

DEFECT. lean_row_is_idle uses ps etimes (process AGE) plus ps pcpu, which in procps-ng is lifetime cputime/elapsed. Any long-lived tree reads <1%, so an actively used 5h-old tree counts as "idle".

WORK (consumes the reclaimable figure from the PSS memory helper, hence the dependency).
(a) CPU-delta idle tracking: per-tree state in ~/.local/state/claude-refresh/lean-trees.json keyed by root pid + process starttime (/proc/PID/stat field 22). Each run, store the summed utime+stime of all tree members; if it increased since the last run, reset last_active; idle_for = now - last_active. Replace the pcpu/etimes gate entirely. Hourly run granularity is acceptable. Prune entries for trees that no longer exist.
(b) State file writes atomic (tmp + mv). Tolerate a missing or corrupt file: treat as first sighting, NEVER as idle.
(c) Cost gate: a tree is prompt-eligible only when idle_for >= LEAN_LSP_IDLE_THRESHOLD_MIN (default 240) AND reclaimable >= LEAN_LSP_MEM_FLOOR_MB (default 1024). Otherwise report it as "idle, cheap, kept" (or active). Interactive /refresh uses this same gate and the same numbers for its existing AskUserQuestion prompt.
(d) Tests (fixture /proc via PROC_ROOT, fixture state dir): CPU-delta idle state machine (first sighting not idle; unchanged cputime accrues idle_for; increased cputime resets), pid reuse with different starttime treated as a new tree, corrupt/missing state file, floor gate both sides of the threshold.
(e) Update Pass Inventory rows in commands/refresh.md and skills/skill-refresh/SKILL.md for the new idle definition and cost gate.

MUST NOT. Kill anything silently. Change UID/system-slice predicates or termination ordering. Edit .claude/**.

ACCEPTANCE. Active 5h-old tree whose cputime grows is never idle; a tree idle >=240 min with <1 GB reclaimable is reported kept; tests pass; shellcheck clean; redeploy and confirm.

DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 217. Replace RSS+VmSwap over-count with PSS-based reclaimable memory in claude-refresh passes
- **Effort**: 2 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 174

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**, a disposable deploy artifact).

OBSERVED LIVE (2026-09-15): a Lean LSP tree was reported as "15.1 GB" reclaimable while earlyoom showed 14-16.6 GB available throughout; real reclaim was ~2.3 GB swap plus a little anon. User policy: idle trees that cost nothing may stay; trees that cost memory get a prompt (never a silent kill) after being idle a while. Memory floor 1 GB approved.

DEFECT. run_claude_pass and run_lean_pass in scripts/claude-refresh.sh both sum per-process RSS + VmSwap (get_vmswap_kb). Lean workers share mmapped Mathlib .olean files (5.6 GB lib), so shared pages are counted once per worker, and file-backed pages are evictable page cache anyway.

WORK.
(a) Add one shared memory helper used by BOTH passes: read $PROC_ROOT/PID/smaps_rollup; reclaimable = Pss_Anon + SwapPss. Report Pss_File separately as "shared cache (not counted)". When smaps_rollup is unreadable, fall back to RSS + VmSwap and label the figure approximate. Read only for candidates (not every process).
(b) Update both passes' report format to show reclaimable (and approximate marker) plus shared cache.
(c) Correct the in-script pcpu comment: procps-ng ps pcpu is lifetime cputime/elapsed, NOT a decaying average. (The idle gate itself is replaced by a follow-on task; only fix the comment here.)
(d) Tests in scripts/tests/test-claude-refresh-matcher.sh: fixture-based /proc via PROC_ROOT covering smaps_rollup parsing (Pss_Anon, SwapPss, Pss_File), shared-page de-duplication across multiple workers, and the unreadable fallback label.

MUST NOT. Change UID/system-slice safety predicates or termination ordering. Edit .claude/**.

ACCEPTANCE. Fixture of N workers sharing a large Pss_File reports reclaimable = sum(Pss_Anon+SwapPss) and shared cache separately; fallback path labeled approximate; test suite passes; shellcheck clean; redeploy and confirm.

DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 216. Reset the /orchestrate cycle bound on each run and admit forced phases by artifact, not status
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 214

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**).

INTENT (user, 2026-09-14). A typical workflow is `/orchestrate N --research` several times, then `/orchestrate N --plan`, then more plan revisions, and only then `/orchestrate N` or `/orchestrate N --implement`. The cycle bound exists only to stop unbounded work WITHIN one run (e.g. a hard Lean proof). It must reset on every /orchestrate run. Forced phases must be admitted by artifacts, not status. Design for simplicity: one admission rule, no status special-case matrix.

CURRENT BEHAVIOUR (verified in the source store).
  - The counter carries over between runs, on purpose. orchestrate-cycle-plan.sh section (a2) loads cycle_counts[t] from the saved ${TASK_DIR}/.orchestrator-loop-guard (orchestrate-loop-guard-init.sh --seed). It adds 1 on every dispatch and saves it back (--flush). The limit is 5 per task, 13 with --hard. --continue-budget is the only way past it: it archives the exhausted guard to .exhausted-loop-guard-<ts>.json and resets. context/standards/orchestrator-runtime-files.md ("cycle_count semantics and the budget-continuation override (Defect B)") records "cumulative across invocations, by design", and test-session-runtime-files.sh Case 3 guards it. docs/architecture/orchestrate-state-machine.md contradicts this ("Maximum dispatch cycles per /orchestrate invocation"). Result: a few forced research/plan runs exhaust the budget and later runs are refused with MAX_CYCLES.
  - Forced phases already override status routing (section (f)), and task_has_forced_phase admits terminal tasks. But a forced implement never checks that a plan exists: orchestrate-build-dispatch.sh finds the plan with `ls plans/*.md | sort -V | tail -1` and sends an empty plan_path when there is none.
  - A plan dispatch sets research_artifact to `.[0]` of the task's report artifacts. Every artifact writer removes older links of the same type before adding the new one (state-management.md, "Artifacts Are Append-Only (With Same-Type Supersession)"), so that should already be the newest report. No known defect; (c) only pins it with a test.
  - /orchestrate has no --revise. /revise N is a separate command that works at any status. orchestrate-cycle-plan.sh can already dispatch reviser-agent (the plan-revision aux kind).

WORK.
(a) Counter resets on each run. cycle_counts starts at 0 in each run's multi-state file; the saved cycle_count is no longer read or written for budgeting. The saved guard file keeps only what must persist: dispatch_seq_counter (must never repeat within a task), pending_dispatch and detected_defects. Remove --continue-budget end to end (parse-command-args.sh, commands/orchestrate.md, SKILL.md Move 1, orchestrate-cycle-plan.sh, including the exhausted-guard archive path and the MAX_INFRA_FAILURES override). Re-running /orchestrate is the explicit way to continue. Keep the per-run bound (5, or 13 with --hard) and the max_cycles stop reason. Replace the Defect B section in orchestrator-runtime-files.md with the per-run contract and why. Invert test-session-runtime-files.sh Case 3, and retire or rework test-loop-guard-budget-override.sh.
(b) One admission rule for forced phases, keyed on artifacts:
    - research: always admitted, at any status.
    - plan: always admitted, at any status. If the task already has a plan (plans/*.md exists), dispatch reviser-agent (plan revision, a new plan in the current round, same as /revise). Otherwise dispatch planner-agent. There is no separate --revise flag; /revise N stays as the standalone command, unchanged.
    - implement: admitted whenever plans/*.md exists, at any status (researched, planned, partial, completed, ...). With no plan, emit a blocked[] row ("no plan artifact; run --plan first") and dispatch nothing.
    Dependency gating, file_scope admission and the monotonic-max status clamp are unchanged. Runs without a forcing flag keep today's status routing.
(c) Add a test that a plan dispatch (planner or reviser) names the NEWEST report after several research rounds. Change code only if that test fails.
(d) Record the loop-guard staleness detector's disposition: it is moot once no counter is carried between runs, because nothing stale is trusted for budgeting any more. Record it in orchestrator-runtime-files.md next to the existing detector text, not only in a summary.
(e) Make commands/orchestrate.md (the --research/--plan/--implement rows, the removed --continue-budget row, error handling), merge-sources/claudemd.md (the /orchestrate row), skills/skill-orchestrate/SKILL.md and docs/architecture/orchestrate-state-machine.md agree with (a)-(c).

MUST NOT. Do not let dispatch_seq_counter reset or repeat. Do not change routing for runs without a forcing flag. Do not add a status matrix; (b) is the whole rule. Do not edit .claude/**.

ACCEPTANCE.
  - Fixture: six forced runs in a row on one task (separate sessions) are never refused for budget, and within ONE run the bound still stops the task at 5 (13 with --hard).
  - --implement on a RESEARCHED task that has a plan dispatches implement; --implement on a task with no plan yields a blocked[] row and no dispatch file, lock or status write.
  - --plan on a task with an existing plan dispatches reviser-agent and produces a revised plan in the current round; --plan with no plan dispatches planner-agent and creates one. Both are admitted at any status, including terminal.
  - A plan dispatch after two research rounds names the newest report.
  - dispatch_seq never repeats across runs.
  - --continue-budget is gone (grep finds nothing in the source store outside history).
  - shellcheck clean. Redeploy and confirm in a consumer repo.

DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 215. Add a sanctioned undo for a prepared but never-run orchestrate dispatch
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 214, Task 216

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**).

GAP. There is no supported way to undo a dispatch that orchestrate-cycle-plan.sh prepared but that was never run (no Agent call, no postflight). The live pass changes six things before any agent runs: the preflight status write (status, last_updated, session_id), the task lock, the .dispatch/{seq}.md file, the dispatch_seq counter, the per-task cycle count in .orchestrator-loop-guard (with its pending_dispatch record), and the multi-state file. When such a dispatch is unwanted, the user has to reverse all of it by hand. guard-destructive-git.sh correctly blocks git-based undo on a dirty tree, so hand edits are the only option today.

OBSERVED LIVE (2026-09-14, ~/Projects/Logos/Verification). A stray plan dispatch was prepared on a RESEARCHED task. The user restored the status, rebuilt TODO.md, and deleted the dispatch file, lock and cycle count by hand. The stray last_updated and session_id stayed in specs/state.json and were never committed or reverted, and the deleted lock file was left as an uncommitted deletion.

EXISTING PIECES TO REUSE. orchestrate-cycle-plan.sh already records `pending_dispatch` {seq, phase, forced, dispatch_file, recorded_at} through `orchestrate-loop-guard-init.sh --record-pending`, and already detects an "UNCONSUMED DISPATCH REPLAY" by checking that the recorded dispatch_file still exists. task-lock.sh has `release`. update-task-status.sh and state-write.sh are the sanctioned state writers. git-commit-scoped.sh is the sanctioned path-scoped committer.

WORK.
(a) Add scripts/orchestrate-unwind-dispatch.sh <task_number> --session SID [--dry-run]. It refuses unless a pending_dispatch exists whose dispatch_file is still on disk and no postflight has consumed it. It then restores the earlier status and the earlier last_updated/session_id (record them at preflight if they are not recorded yet; decide where, e.g. in the pending_dispatch record), releases the lock only if this session holds it, deletes the dispatch file, rolls back the cycle count and clears pending_dispatch, fixes the multi-state file if it is present, regenerates TODO.md, and optionally commits only the paths it touched with git-commit-scoped.sh. It must not use destructive git.
(b) Document it as the sanctioned recovery path in docs/architecture/orchestrate-state-machine.md and context/standards/git-safety.md (next to the guard-destructive-git.sh explanation), and point to it from the SKILL.md "Move 1" stop handling.
(c) Decide whether the orchestrating session should call it automatically when a prepared dispatch row is never issued (e.g. a crash between Move 1 and Move 2, or a plan that is intentionally abandoned), or only by hand. Justify the choice.

MUST NOT. Do not add an exemption to guard-destructive-git.sh. Do not unwind a dispatch that an agent has started or that postflight has consumed. Do not edit .claude/**.

ACCEPTANCE. A fixture test prepares a live plan dispatch on a RESEARCHED task, runs the unwind script, and asserts state.json matches the pre-dispatch entry exactly (status, last_updated, session_id), TODO.md is regenerated, the lock is released, the dispatch file is gone, the loop-guard cycle count and pending_dispatch match their earlier values, and `git status --porcelain -- specs/` shows no leftovers after the scoped commit. A second case asserts it refuses once postflight has consumed the dispatch. shellcheck clean. Redeploy and confirm.

DELIVERABLE RULE: no task numbers in deliverables outside specs/**.


AMENDMENT (2026-09-14). A follow-on task (this task now depends on it) makes the cycle counter reset on each run: cycle_counts lives only in the run's multi-state file, and the saved guard file no longer carries cycle_count. So DROP "rolls back the cycle count" from WORK (a), and change ACCEPTANCE from "the loop-guard cycle count and pending_dispatch match their earlier values" to "pending_dispatch and dispatch_seq_counter in the loop-guard file match their earlier values". Everything else stands.

---

### 214. Make forced orchestrate phases stop as documented instead of dispatching the next phase
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 213

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**).

DEFECT. A phase-forcing flag (`--research`/`--plan`/`--implement`) is documented to STOP after the last named phase, but orchestrate-cycle-plan.sh falls through to normal status-based dispatch once the forced queue is empty. Any later call on the same session, including a "check" call, starts the next lifecycle phase for real.

OBSERVED LIVE (2026-09-14, ~/Projects/Logos/Verification). After a forced research round finished and the task was RESEARCHED, the orchestrating session re-ran orchestrate-cycle-plan.sh as a final check, without the research-only flag. It moved the task to [PLANNING], wrote a new .dispatch/{seq}.md, took the task lock, added to the task's cycle count, and wrote a new last_updated/session_id into state.json. The user had to restore the status by hand, rebuild TODO.md and delete the dispatch file, lock and cycle count.

ROOT CAUSE (verified in the source store).
  - Contract: commands/orchestrate.md (`--research` row: "STOPS after the last named phase") and the merge-sources/claudemd.md /orchestrate row ("stopping after the last named phase rather than falling through to status-derived dispatch").
  - Code: section (f) "Per-task force_phases consumption" sets `effective_group[t] = triage_group[t]` whenever `force_phases_remaining[t]` is empty. The live pass empties the queue as it dispatches (`.force_phases_remaining[$t][1:]`), and seeding uses `//=`, so later cycles never refill it. After the forced phase is dispatched, a RESEARCHED task routes to plan whether or not the flag is passed again. Nothing records that this session was a forced round.
  - A read-only `--dry-run` already exists, but skills/skill-orchestrate/SKILL.md never says that a re-check or status probe must use it (or read mt_state_file) instead of a live call, and docs/architecture/orchestrate-state-machine.md does not document what happens after the queue empties.
  - The contradiction also exists in docs: the CLAUDE.md multi-task paragraph says tasks fall "through to ordinary status-derived classification once its own forced sequence is exhausted". Settle on one contract.

WORK.
(a) Persist per-task "forced round" state in the multi-state file (e.g. record the original forced sequence when it is seeded). When that queue is empty, the task must be excluded from dispatch (terminal for this session, with a clear stop or skip reason) rather than routed by status. This must hold even when a later invocation omits --force-phases.
(b) Settle the contradiction in favour of the documented STOP contract (or, if research shows fall-through is relied on, pick explicitly and fix every doc). Update commands/orchestrate.md, merge-sources/claudemd.md, docs/architecture/orchestrate-state-machine.md and SKILL.md so they agree.
(c) SKILL.md: add a MUST NOT for live re-invocation of orchestrate-cycle-plan.sh purely to inspect state. Name `--dry-run` (or reading mt_state_file) as the only sanctioned check, and require the loop to stop on the plan's stop verdict.
(d) Check whether an unforced live call on a forced session's mt_state_file can still charge a cycle, take a lock or write a preflight status; after the fix it must do none of these.

MUST NOT. Do not change unforced behaviour for sessions that never used a forcing flag (normal lifecycle progression must continue). Do not regress status on terminal tasks (keep the monotonic-max clamp). Do not edit .claude/**.

ACCEPTANCE. A regression test in scripts/tests/test-force-phases.sh reproduces the observed case: a RESEARCHED task with `--force-phases research`, research dispatched and postflighted, then (1) a second live call with the flag and (2) a live call without it. Both produce no dispatch rows, leave status RESEARCHED, write no dispatch file, take no lock, and leave cycle_counts unchanged. The test fails against the current script. An unforced multi-phase session still advances research -> plan -> implement. shellcheck clean. Redeploy and confirm in a consumer repo.

DELIVERABLE RULE: no task numbers in deliverables outside specs/**.


AMENDMENT (2026-09-14, alongside the per-run cycle-bound task). Scope the "forced round" state from (a) to ONE run's multi-state file (one session_id). A NEW /orchestrate run with a new forcing flag (e.g. --research, then later --plan) must start clean and be admitted. The stop-after-last-forced-phase guarantee applies within a run only. A follow-on task will make cycle_counts reset on each run and admit forced phases by artifact (research/plan always; implement when a plan exists; --plan revises when a plan exists), so do not add status-based admission here. The acceptance assertion "cycle_counts unchanged" still stands within the run.

---

### 213. Pass /orchestrate focus text through to the dispatch file
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**).

DEFECT. The focus text after the task number (e.g. `/orchestrate N --research "<questions>"`) never reaches the dispatch file. The agent is dispatched without the user's questions.

OBSERVED LIVE (2026-09-14, ~/Projects/Logos/Verification). A forced research round was run with quoted focus text. The generated .dispatch/{seq}.md had no "User focus:" block, so the user had to add the questions to the dispatch file by hand before the agent read it.

ROOT CAUSE (verified in the source store).
  - commands/orchestrate.md parses `$2+` as FOCUS_PROMPT and passes `focus_prompt=` to skill-orchestrate.
  - skills/skill-orchestrate/SKILL.md "Move 1: Plan the cycle" calls scripts/orchestrate-cycle-plan.sh with every other flag (--force-phases, --model, --clean, --lit, --hard, --fast, ...) but NOT the focus text.
  - orchestrate-cycle-plan.sh has no --focus flag at all (its argument parser rejects unknown flags). In its live pass, section (l), it builds `--focus` for orchestrate-build-dispatch.sh ONLY from the task's own `research_questions` field, and only for research dispatches. Its own comment says a task forced by --research "passes no --focus flag at all".
  - orchestrate-build-dispatch.sh already accepts `--focus "..."` and already renders "User focus:" (and feeds memory retrieval for research). No change is needed there.

WORK.
(a) Add `--focus "<text>"` to orchestrate-cycle-plan.sh: parse it, document it in the usage block and header, and include it in the plan-cache key if that cache would otherwise replay a composition built without it.
(b) In section (l), pass --focus for research dispatches. When both user focus text and research_questions exist, combine them into one clearly labelled string; neither may silently replace the other. Decide and document whether plan (and implement) dispatches should also carry user focus text. Check orchestrate-build-dispatch.sh's phase gate and the single-task path, and make the behavior match the `$2+` contract in commands/orchestrate.md ("Applies to all tasks in multi-task mode").
(c) Pass `--focus "$focus_prompt"` in SKILL.md Move 1, using the same pattern the other flags use (omit the flag when the value is empty), with quoting safe for text containing spaces and quotes.
(d) Make --dry-run show that focus text was received, so a user can check it before a live run.

MUST NOT. Do not change the research_questions path for tasks without user focus text (keep that output byte-for-byte). Do not edit .claude/**.

ACCEPTANCE. A fixture test in scripts/tests/test-orchestrate-cycle-plan.sh runs a forced research cycle with `--focus "Q1? Q2?"` and asserts that the built dispatch file contains a "User focus:" block with that text; a second case with both focus text and research_questions asserts both appear; a case with no focus text matches the current output. shellcheck clean. Redeploy and confirm in a consumer repo that `/orchestrate N --research "..."` produces the block without hand edits.

DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 212. Detect and recover research dispatches that skip their report file
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 194, Task 213, Task 214

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**).

DEFECT. Research subagents sometimes skip their only required deliverable, the report file plus
.return-meta.json, and send their findings by message instead, citing an instruction that doesn't
exist.

OBSERVED (2026-09-01, /orchestrate batch of 7 tasks, session sess_1788267679_adbb09; the repo
wasn't recorded, so find it by grepping consumer repos' specs/ for that session id). Seven
general-research-agent subagents ran concurrently with prompts requiring a report and
.return-meta.json. 5 of 7 wrote neither file. Three explained why by citing rules that don't
exist:
  - research-128: "No files were written -- per this session's operating notes, findings were
    delivered directly to team-lead via SendMessage rather than as report artifacts"
  - research-133: "no `.return-meta.json` written by this research pass per this session's
    no-report-file instruction"
  - research-120: "No files were modified -- this was research only."
research-123 and research-130 wrote both files correctly with the same prompt structure, so
nothing in the environment blocked writes. Checked and absent: no such instruction in
.claude/settings.json, settings.local.json, ~/.claude/settings.json hooks, the agent definition or
the dispatch prompts. The findings themselves were high quality; only the files were lost.

POSSIBLE CAUSE (unconfirmed). The session's bypass-permissions preamble ("do your work through the
Bash tool wherever it can accomplish the job", "Do not call the AgentTool unless the user
requested it") may have been over-generalized by subagents into a ban on writing files.

WORK.
(a) Check the current behavior first. When a research dispatch returns without the report or
    .return-meta.json, does skill-orchestrate's postflight (or the dispatch validation) detect it
    today, and what happens: re-dispatch, [PARTIAL], or silently accepted? Report what you find
    before designing anything.
(b) If there's no check, add a hard gate after dispatch: a missing or empty report file or
    .return-meta.json fails the dispatch. Keep any findings the agent returned by message: write
    them into the report path, marked as recovered from the agent's message, then re-dispatch or
    mark [PARTIAL] per context/contracts/recovery.md. Findings must never be lost.
(c) Harden general-research-agent.md (and the other research agents and the shared research
    contract): writing the report file is mandatory, no session-level note overrides it, and
    "findings delivered by message" does not count as completion.
(d) If feasible, try to reproduce the cause: several concurrent research dispatches under
    bypass-permissions. Record the outcome whether or not it reproduces.

MUST NOT. Do not discard findings that arrived only by message. Do not serialize batch research
dispatch as the fix; concurrency is intended. Do not weaken the .return-meta.json shape contract.

ACCEPTANCE. A fixture simulates a research dispatch that returns findings by message with no
report file. The orchestrator detects it, keeps the findings in the report path, and marks the
dispatch failed/partial or re-dispatches, and never records the research phase as complete.
Agent definitions state that the report file is mandatory. shellcheck clean for any shell touched.
Redeploy and confirm.

DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 211. Stop /task task-type detection from matching incidental keywords
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 210

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ and
agent-system/extensions/literature/ (never .claude/**).

DECIDE, THEN IMPLEMENT: how should /task pick a task_type when a routing keyword appears in a
description only in passing?

DEFECT. commands/task.md step 4 picks the type from the first keyword match, and three rules
misroute real descriptions:
  (a) Step 4a (line ~121): "meta", "agent", "command", "skill" anywhere in the description ->
      `meta`, with no exceptions. Here "agent" means an AI agent, not this repo's agent system.
      Observed 2026-09-14, ~/Projects/Logos/Verification: "research and revise the AI agent
      objectives ... training models ... agent harnesses" would have become a meta task.
  (b) Step 4d, first row: "lean", "proof", etc. -> `lean4`. Observed the same day: a
      business-strategy description asking "Why Lean over Rocq when there are more resources for
      software verification in Rocq?" would have been routed to the Lean agents, and a
      description mentioning "the Logos proof theory" matches "proof". In both cases the
      maintainer overrode the type to `general` by judgment, which the command doesn't allow for.
  (c) Step 4b: the literature extension's manifest.json has
      `keyword_overrides: {"meta": {"keywords": ["literature","zotero","bibliography","citation"]}}`
      (verified still present in the source store). Step 4b treats the key as the task_type, so
      any description containing the word "literature" becomes meta. Observed 2026-09-03 on a
      lean4 formalization task. context/guides/extension-development.md (~lines 103-108) already
      warns that single common words are prone to false positives.

PRIOR WORK. The earlier fix that limited typst/latex task types to formatting-only work solved
this problem for step 4d's tool-name rows only (by putting content rows first). It did not touch
step 4a, the lean4 row or extension overrides.

OPTIONS TO WEIGH (score each against all three observed cases):
  1. Narrower keywords: 4a matches only agent-system signals (".claude/", "agent system",
     "slash command", "SKILL.md", a named skill or agent), not bare words.
  2. Confirmation: when the match comes from one keyword in a long or mixed description, show the
     detected type, the keyword that caused it, and one or two alternatives in a question to the
     user. Needs a fixed default for autonomous callers (see topic-assignment-pattern.md's
     Autonomous Context section).
  3. Content scoring: count signals per type across the whole description, not first-match-wins.
  A mix of these is fine. Define the exact rule.

WORK.
(a) Fix the literature manifest: remove the override or map it to the correct type, and document
    that keyword_overrides keys ARE task types (check the other manifests for the same mistake).
(b) Implement the chosen detection rule in commands/task.md and in every other place that repeats
    the table (grep for it; /fix-it, /review, /spawn and /meta may have copies), ideally from one
    shared definition.
(c) Update the CLAUDE.md merge source for the Task-Type-Based Routing section if its description
    changes.

MUST NOT. Do not change how /meta sets task_type directly. Do not make detection ask questions
in autonomous contexts. Do not remove the rule that genuine agent-system descriptions resolve to
meta.

ACCEPTANCE. A fixture test runs the detection rule on: the two Verification descriptions above
(expected: general), the Sep 3 lean4-with-"literature" description (expected: lean4),
"Update skill-orchestrate's dispatch to pass --lit" (expected: meta), and "Prove soundness lemma
in Metalogic/Soundness.lean" (expected: lean4). All pass from the deployed copy.

DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 210. Fix topic assignment order and zero-topic picker in /task create mode
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 209

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**).

DEFECT. Topic assignment in /task create mode has three problems:
  (a) Wrong order. commands/task.md step 4.5 (line ~209) runs
      `bash .claude/scripts/manage-topics.sh set "$next_num" "$topic"` BEFORE step 6 adds the
      task to state.json. manage-topics.sh `set` exits 4 (task-not-found, line ~160) when the task
      doesn't exist, so as written the step always fails.
  (b) Topic never registered. Step 6's state-write.sh filter sets the task's `topic` field but
      does not add the topic to `active_topics`. Following the steps as written leaves
      active_topics empty. Observed 2026-09-14 in ~/Projects/Logos/Verification: after step 6,
      `jq .active_topics` was [] until manage-topics.sh add/set was run by hand afterwards.
  (c) Picker breaks with no topics. When active_topics is empty (every fresh repo's first task),
      the Mode A picker in context/patterns/topic-assignment-pattern.md produces just
      ["New topic..."]. The AskUserQuestion tool requires 2-4 options, each with a label and a
      description. The pattern doc's templates also use a `"type": "select"` / `"freeText"` shape
      that doesn't match the tool's real schema, so every caller has to improvise.

For comparison, Expand Mode and Review Mode already call `set` after the state write. Only create
mode has the order wrong, which suggests an editing slip rather than a design choice.

WORK.
(a) Move the manage-topics.sh call in create mode to after step 6's write, or add the topic to
    active_topics inside step 6's filter and drop the separate call. Pick one approach and use it
    everywhere a task is created (create, expand, review follow-ups, recover, and /spawn, /fix-it,
    /review, /meta). Check each caller's order; don't assume.
(b) Rewrite the AskUserQuestion templates in topic-assignment-pattern.md to match the tool's real
    schema (question, header, multiSelect, and options as {label, description}).
(c) Define what happens with zero existing topics. For example, offer 1-2 topic names suggested
    from the description plus "New topic...", or go straight to free-text input. Keep the rule
    that topic assignment is mandatory: no Skip option, and the "Defer" option stays exclusive to
    --sync backfill.
(d) Add a fixture test: create mode on a state with zero topics and on a state with existing
    topics. Both leave the task's topic and active_topics set, with no non-zero exit from
    manage-topics.sh.

MUST NOT. Do not add a Skip or Defer option to any creation path. Do not change manage-topics.sh's
exit-code contract; callers depend on exit 4.

ACCEPTANCE. Following commands/task.md create mode exactly as written on a fresh state.json
produces a task with its topic set and the topic listed in active_topics, and no step exits
non-zero. The pattern doc's templates are valid AskUserQuestion inputs. Fixture tests cover both
cases. shellcheck clean for any shell changed. Redeploy and confirm.

DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 209. Set up a fresh repo specs/ state and runtime-file ignore rules automatically
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**).

DEFECT. A consumer repo that has never used the task system has no specs/ state and no ignore
rules for runtime files. Two things break the first time /task runs there:
  (a) /task create mode assumes specs/state.json exists. Its first command
      (`jq -r '.next_project_number' specs/state.json`) fails with "No such file or directory",
      and no documented step creates specs/state.json, specs/archive/state.json or specs/TODO.md.
      The agent has to build them by hand from context/schemas/state-schema.json.
  (b) The repo's .gitignore has none of the runtime-file patterns, so every
      `git-commit-scoped.sh ... -- specs/` commit picks up the system's own lock and session files.

OBSERVED LIVE (2026-09-14, ~/Projects/Logos/Verification, fresh repo; root .gitignore is only
`/.claude` and `/.agent-logs`).
  - Commit 37544c5 (first task creation) added specs/.commit-lock/{owner,claimed_at,stale_sec}.
    The script then released the lock, which deleted those files from disk and left three unstaged
    deletions. Commit 76aac71 cleaned them up by hand.
  - Commit 4b8541d (second task creation) did the same thing again (cleanup commit 9ac4674). It
    also picked up a concurrent session's specs/.events.lock,
    specs/.orchestrator-multi-state-sess_*.json, specs/.sessions/sess_*.json,
    specs/001_*/.dispatch/2.md and specs/tmp/claude-tts-notify.log.
  The scoped-commit form was used correctly each time. The files simply weren't ignored.

WHY EARLIER FIXES DIDN'T HELP. scripts/lib/runtime-file-patterns.sh already defines the full
runtime-file list, including `**/.commit-lock/`, and runtime_ignore_block() prints it. But
context/standards/orchestrator-runtime-files.md's "Consumer Repo Setup" section still treats
adding it to a repo as a manual paste into the repo-root .gitignore. A fresh repo never gets it.
The earlier ignore-list work ruled out delivering a repo-root .gitignore from the source store,
because root_files deploys into .claude/. That limitation does not apply to specs/.gitignore:
patterns in that file are relative to specs/, so it can be written directly.
Separately, specs/tmp/ is not in the runtime-file list at all.

WORK.
(a) Add one idempotent setup script (e.g. scripts/init-specs.sh). It creates specs/,
    specs/archive/, a schema-valid specs/state.json (next_project_number 1, empty
    active_projects and active_topics), specs/archive/state.json and a generated specs/TODO.md.
    It MUST NOT overwrite anything that already exists.
(b) Have the same script write or refresh specs/.gitignore from runtime-file-patterns.sh,
    converted to patterns relative to specs/. Decide whether to use a marked managed block (so
    user-added lines survive) or to own the whole file, and justify the choice.
(c) Call the script from /task create mode before step 1, and from any other command that can
    be the first to touch specs/ (/orchestrate, /meta, /fix-it, /review, /spawn; check the list,
    don't assume it). Also decide whether deploy (the extension loader and deploy-headless.sh)
    should run it, and respect .syncprotect if it does.
(d) Add specs/tmp/ (or whatever the TTS notify hook's log directory really is; find its writer)
    to runtime-file-patterns.sh, so every place that uses the list stays in agreement.
(e) Update orchestrator-runtime-files.md's Consumer Repo Setup section: the specs/ ignore rules
    are now installed automatically, and any remaining manual step is stated plainly.
(f) Make check-runtime-file-tracking.sh accept specs/.gitignore as valid coverage, not just the
    repo-root .gitignore.

COORDINATION. The task that moves session state files out of the specs/ root
(move_session_state_files_out_of_specs_root) edits the same list and standards file. Whichever
lands second must re-check that the generated specs/.gitignore covers the new paths.

MUST NOT. Do not add .orchestrator-handoff.json or .return-meta.json to any ignore list; the
standards file says they must stay tracked. Do not write or modify the consumer's repo-root
.gitignore. Do not overwrite existing specs/ state. Do not rewrite history in any consumer repo.

ACCEPTANCE. In a scratch git repo with no specs/, running /task's create path from the deployed
copy creates valid state files and specs/.gitignore. A following git-commit-scoped.sh commit of
specs/ contains no .commit-lock/, .events.lock, .sessions/, orchestrator multi-state or tmp files,
and the working tree is clean afterwards (demonstrated with a fixture test). Running the setup
script again changes nothing. check-runtime-file-tracking.sh passes on that repo.
shellcheck clean per context/standards/shell-strict-mode.md. Redeploy and confirm in a consumer
repo.

DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

=== AMENDED 2026-09-14 (orchestrate focus/stray-dispatch survey) ===
SECOND OBSERVATION, SAME REPO. Later /orchestrate runs in ~/Projects/Logos/Verification show that runtime files are ALREADY TRACKED, which a new ignore file alone will not fix, because git keeps tracking files that match an ignore rule. Tracked there: specs/.commit-lock/{owner,claimed_at,stale_sec}, specs/.events.lock, three specs/.orchestrator-multi-state-sess_*.json, per-task .orchestrator-loop-guard files, and per-task .lock/holder.json and .dispatch/*.md files (their deletions later showed up as uncommitted " D" entries in git status). Newer multi-state and .return-meta-multi-*.json files are untracked but not ignored.
ADDED WORK.
(g) The setup script (or a clearly named companion step it calls) must find already-tracked files matching runtime-file-patterns.sh under specs/ and untrack them with `git rm --cached` (never deleting the working copy), then leave the change staged for the caller's scoped commit or report it. Run it idempotently wherever (c) calls the setup script, and never on .orchestrator-handoff.json or .return-meta.json.
(h) check-runtime-file-tracking.sh must report already-tracked runtime files as a failure, even when specs/.gitignore covers them.
ADDED ACCEPTANCE. In a scratch repo where .commit-lock/, .events.lock, a .lock/holder.json, a .dispatch/1.md, a .orchestrator-loop-guard and a multi-state file are committed, running the setup path untracks all of them while leaving the files on disk; the next scoped commit plus the lock release leaves `git status --porcelain -- specs/` empty.

---

### 208. Explain Path 1 pagination shortfall or revisit Zotero export path-preference order
- **Effort**: 2-4 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: literature
- **Dependencies**: Task 207

**Description**: Explain the Path 1 pagination shortfall in zotero-generate-export.sh -- or, if Path 1 cannot reach parity with sqlite reconstruction, change the path-preference order with a documented rationale.

=== THE OPEN QUESTION (flagged as unknown, NOT guessed -- do not assume a cause) ===

Even with the accumulator truncation fixed, Path 1 pagination terminates at 481 items: at start=400
the API returns 81 items, which is < limit, so the loop treats it as end-of-pagination. But the same
local API's own Total-Results header reports 4042 for the same library. Those two numbers disagree
and the reason is UNKNOWN.

Candidate directions to investigate (none verified, none preferred):
  - csljson format filtering interacting with limit/start applied PRE-filter, so each page is
    silently thinned after the window is computed;
  - a local-API pagination quirk specific to the csljson format or to Zotero 7's local endpoint;
  - attachment/note items inflating Total-Results (the library has 1473 PDF attachments and 62 notes,
    while the bibliographic item count is 4049).

Verify empirically against the live API. Do NOT settle this from reasoning alone, and do not treat
any of the three candidates as the answer before measuring.

=== PRECONDITION: REQUIRES ZOTERO RUNNING ===

Path 1 exists only while Zotero is open -- the local API at localhost:23119 is served by the running
application. A probe during task creation returned HTTP 000 (unreachable) because Zotero was
deliberately quit so Path 3 could produce the complete export. WHOEVER PICKS THIS UP MUST OPEN ZOTERO
FIRST, then confirm the API is reachable before starting. This is a setup step, not a blocker.

=== REFERENCE POINT ===

Path 3 (direct sqlite reconstruction, Zotero closed) produced a complete, verified 4049-item export
matching `select count(*) from items` exactly. That export is the ground truth to compare Path 1
against: /home/benjamin/Projects/Literature/zotero-library.json, 4049 items, source
"sqlite-reconstruction" per its .zotero-library.meta.json stamp. Note $LITERATURE_DIR
(/home/benjamin/Projects/Literature) is OUTSIDE this repo -- the export is never in the repo, and
resolve_library_path() resolves it (tier 1 $ZOTERO_LIBRARY, then $LITERATURE_DIR).

=== WORK ITEMS ===

1. Measure the actual relationship between Total-Results, the csljson page contents, and the
   bibliographic item count against the live API. Determine whether limit/start are applied before
   or after format filtering, and whether attachments/notes are counted in Total-Results.

2. Either (a) explain the 481-vs-4042 discrepancy and fix Path 1 so it reaches parity with Path 3,
   or (b) if Path 1 provably cannot reach parity, change the Path 1 > Path 3 preference order in the
   generation control flow and document why. Option (b) is a legitimate outcome, not a failure --
   the current preference order was chosen on the assumption that a live API pull is more current
   than a sqlite read, and that assumption is what this task tests.

3. If the preference order changes, update the affected docs and the script's own header rationale
   comments so the ordering and its justification stay discoverable. Verified doc touchpoints
   (zotero-integration.md and tools/zotero-scripts.md do NOT mention this script -- zero grep hits):
     context/project/literature/patterns/zotero-pdf-resolution.md
     context/project/literature/domain/literature-index.md
     context/project/literature/domain/corpus-directory-conventions.md
     commands/literature.md

=== ACCEPTANCE CRITERIA ===

1. The 481-vs-4042 discrepancy is either explained with empirical evidence, or the path-preference
   order is changed with a documented rationale.
2. If Path 1 is fixed, a full export via Path 1 matches the sqlite-reconstruction item count.
3. Whichever outcome, the resulting path-selection behavior is documented where a future reader will
   find it, including the reason.

=== DEPENDENCY RATIONALE ===

Depends on the Path 1 accumulator fix. This is substantive, not bookkeeping: (a) both tasks modify
fetch_path1 in the same file, and (b) pagination termination cannot be observed cleanly while the
accumulator is still silently discarding pages and the error-swallowing fallback is masking failures.
Measure only after the truncation fix is in place.

=== BINDING RULES ===

SOURCE-STORE RULE: all edits target agent-system/extensions/literature/**. NEVER edit the deployed
.claude/** tree -- it is a gitignored, disposable deploy artifact wiped by the next regeneration.
DELIVERABLE RULE: no task-number references in deliverables outside specs/**.

---

### 207. Fix silent truncation in zotero-generate-export.sh Path 1 accumulator
- **Effort**: 2-3 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: literature
- **Dependencies**: None

**Description**: Fix the silent-truncation data-loss defect in zotero-generate-export.sh's Path 1 (Zotero 7 local API pull), and add a shrink guard so a truncated pull can never again overwrite a complete export.

=== VERIFIED DEFECT (diagnosed empirically with an instrumented trace, not hypothesized) ===

fetch_path1()'s accumulator passes the entire growing JSON array as a single jq argv string:

    all_items="$(jq -n --argjson a "$all_items" --argjson b "$filtered" '$a + $b' 2>/dev/null || echo "$all_items")"

At ~200 accumulated items the string reaches 152KB and jq dies with "Argument list too long". The cause is Linux MAX_ARG_STRLEN: a SINGLE argument is capped at 128KiB (32 x 4KiB pages), independent of ARG_MAX (2MB on this machine). The trailing `2>/dev/null || echo "$all_items"` then swallows the error and yields the prior value, so the loop keeps fetching pages 3..41 and silently discards every one, then exits 0 printing a success message ("wrote 200 entries").

Instrumented trace output:

    start=0   page_len=100 filtered_len=100   accum: 0 -> 100
    start=100 page_len=100 filtered_len=100   accum: 100 -> 200
    start=200 page_len=100 filtered_len=100   accum: 200 -> 200   !!! ACCUMULATION FAILED
    start=300 page_len=100 filtered_len=100   accum: 200 -> 200   !!! ACCUMULATION FAILED

Deterministic; reproduced twice. Affects any library past ~200 items -- not user- or data-specific.

REAL-WORLD IMPACT (already occurred, actual data loss): a regeneration run with Zotero open overwrote a good 4046-item export with a 200-item one and reported success. Recovered only because the pre-state item count had been captured beforehand; the export is not git-tracked and had no backup. Which path runs decides the outcome: Zotero closed -> Path 3 sqlite reconstruction (correct); Zotero open -> Path 1 (truncates to 200). The failure is invisible in the common case and catastrophic in the other.

=== WORK ITEMS ===

1. TEMP-FILE ACCUMULATOR. Write each fetched page to $tmpdir/page_N.json and combine once at the end with `jq -s 'add'`, so neither a page nor the accumulator ever transits argv. Retain the existing attachment/note CSL-type filter (currently applied per-page at the `filtered` step). Clean up $tmpdir on all exit paths.

2. MAKE FAILURE LOUD. A failed fetch OR a failed accumulation must abort with a non-zero return and NO write, rather than `break` into a partial that looks complete. Remove the error-swallowing `2>/dev/null || echo "$all_items"` fallback entirely -- it discards the only evidence anything went wrong, and today the break path is indistinguishable from normal pagination completion. Distinguish the three terminal conditions explicitly: genuine end-of-pagination (short page), max_pages guard hit, and error.

3. SHRINK GUARD. Refuse to overwrite an existing export with one containing dramatically fewer items unless explicitly forced. This alone would have prevented the data loss. `--force` is ALREADY TAKEN for the staleness/exists override (see the existing arg parser and exit code 3), so the guard needs its own opt-out flag or a distinct threshold semantic -- resolve which during planning and state the rationale.

   SHRINK-GUARD SPEC NOTE (verified live state, do not re-derive): the export currently on disk is
   /home/benjamin/Projects/Literature/zotero-library.json -- 2099350 bytes, 4049 items, source
   "sqlite-reconstruction" per its .zotero-library.meta.json stamp. $LITERATURE_DIR is
   /home/benjamin/Projects/Literature, which is OUTSIDE this repo; the export is never in the repo,
   and resolve_library_path() resolves it (tier 1 $ZOTERO_LIBRARY, then $LITERATURE_DIR). So the
   guard has a real, complete 4049-item file to protect on the very next run -- its primary and
   immediately-live scenario is exactly the one that already caused loss. Design a no-existing-export
   branch too (a legitimate case), but do NOT frame the guard as "first regeneration is unguarded by
   construction" -- that is only true of a genuinely absent export, which is not the state here.
   The prior truncated 200-item file is NOT on disk (it was overwritten by the successful Path 3
   regeneration); generate a truncated fixture rather than expecting to find one.

4. REGRESSION COVERAGE for the >128KiB accumulator boundary specifically, since that exact threshold is what made this invisible. Also cover the shrink guard blocking a catastrophic overwrite.

   SPECIFIED TEST MECHANISM (verified feasible offline -- do NOT conclude a live API is needed and
   skip the test): scripts/tests/curl-stub.sh is already a PATH-shadowing curl stub, and
   zotero-generate-export.sh calls bare `curl` (never an absolute path, never `command curl`), so a
   PATH-shadowing stub genuinely intercepts it. Extend the stub to dispatch on localhost:23119 and
   serve synthetic paged csljson bodies large enough to cross the 128KiB single-arg boundary. This
   needs no live API and no running Zotero.

5. DOC UPDATE for the changed contract, using these VERIFIED touchpoints.

   CORRECTED DOC TARGETS (verified by grep -- use these, not zotero-integration.md or
   tools/zotero-scripts.md, NEITHER of which mentions zotero-generate-export.sh at all: zero hits):
     context/project/literature/patterns/zotero-pdf-resolution.md
     context/project/literature/domain/literature-index.md
     context/project/literature/domain/corpus-directory-conventions.md
     commands/literature.md
   Deliberately avoiding zotero-integration.md also keeps this task at ZERO file overlap with the
   active zotero-metadata-resolution task (see SCOPE BOUNDARIES below).

=== ALREADY-VERIFIED NEGATIVE RESULT -- DO NOT RE-RUN THIS SWEEP ===

The sibling-script sweep for the same MAX_ARG_STRLEN bug is COMPLETE. Every script under the
literature extension was grepped for `--argjson` accumulation in a loop. RESULT: line 258 of
zotero-generate-export.sh is the ONLY genuine argv-accumulation instance in the extension. Every
other accumulator pipes the GROWING value through stdin and passes only the single new item via
argv, so MAX_ARG_STRLEN does not apply to any of them:
    cite-extract.sh:259, zotero-search.sh:422, literature-discover.sh:280,
    zotero-generate-export.sh:484
This negative result is recorded so a later reader does not re-fund the sweep as a research phase.

=== ADJACENT-CODE WARNING (do not misfire here) ===

Line 484 in synthesize_citekeys:

    result="$(echo "$result" | jq --argjson e "$entry" '. + [$e]' 2>/dev/null || echo "$result")"

This is NOT an instance of the same bug and is NOT a data-loss path. It pipes the growing
accumulator via stdin; only the single small `$entry` crosses argv. It runs on EVERY path including
Path 3, which is consistent with Path 3 having correctly produced the complete 4049-item export. It
is O(n^2) and it does swallow errors, but fixing it is OUT OF SCOPE for this task. Do not rewrite it
as though it shared the MAX_ARG_STRLEN cause -- that is exactly the adjacent-code misfire an
implementer makes when handed a MAX_ARG_STRLEN brief.

=== ACCEPTANCE CRITERIA ===

1. A >200-item library exports completely via Path 1, or fails loudly with a non-zero exit and NO write.
2. No silent-truncation path remains in fetch_path1 -- specifically, no error-swallowing
   `2>/dev/null ||` fallback that can return a short result as success.
3. The shrink guard blocks a catastrophic overwrite of the existing complete export and is exercised
   by a test; its opt-out mechanism is distinct from the existing --force staleness override, with a
   documented rationale for the chosen semantic.
4. Regression coverage exists for the >128KiB accumulator boundary specifically, implemented offline
   via the PATH-shadowing curl stub.
5. The changed contract is reflected in the four verified doc touchpoints.

=== SCOPE BOUNDARIES ===

No dependency on the active zotero-metadata-resolution task: its file_scope covers the WRITE /
metadata-resolution path (literature-ingest-online.sh, literature-discover.sh, zotero-item-creation.md,
zotero-integration.md, README.md) and excludes zotero-generate-export.sh entirely -- a different
concern from this export READ path. Keeping doc edits off zotero-integration.md leaves zero file
overlap, deliberately so this urgent data-loss fix is not serialized behind that task's larger scope.

Standing operational rule until this task lands: any regeneration must be done with Zotero CLOSED,
so Path 3 sqlite reconstruction runs instead of the truncating Path 1.

=== BINDING RULES ===

SOURCE-STORE RULE: all edits target agent-system/extensions/literature/**. NEVER edit the deployed
.claude/** tree -- it is a gitignored, disposable deploy artifact wiped by the next regeneration.
DELIVERABLE RULE: no task-number references in deliverables outside specs/**.

---

### 206. Fix test fixtures missing task lookup lib
- **Status**: [NOT STARTED]
- **Task Type**: general
- **Topic**: core-agent-system
- **Dependencies**: None

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**).

DEFECT. Three core shell test suites are red on master. The original title names only the first
(a test fixture missing lib/task-lookup-lib.sh); the other two surfaced alongside it and are in
this task's file_scope, so all three are in scope:
  (1) scripts/tests/test-postflight-deploy-gate.sh - 7 FAIL. The fixture builds a minimal script
      tree from an explicit lib list and that list is missing lib/task-lookup-lib.sh.
  (2) scripts/tests/test-lint-json-channel-discipline.sh - 2 FAIL. The real-corpus pass reports a
      VIOLATION in orchestrate-triage-classify.sh.
  (3) scripts/tests/test-gate-out-repair-reporting.sh - 4 FAIL. Cause not yet diagnosed.

VERIFIED EVIDENCE (run 2026-09-14 on master).
  (1) test-postflight-deploy-gate.sh line ~85: REQUIRED_LIBS=(common.sh phase-heading-patterns.sh
      status-vocabulary.sh file-scope-overlap.sh). It omits task-lookup-lib.sh, which
      task-lock.sh:197 sources unconditionally (added with the shared archive-aware task-lookup
      library). The fixture's task-lock.sh fails to load, so update-task-status.sh exits 2 in
      cases c2-c5 and c7.
  (2) test-lint-json-channel-discipline.sh flags orchestrate-triage-classify.sh:225,
      `printf '%s' "$archived_projects_json" > "$archived_projects_tmpfile"`, as an "unredirected
      stdout write in a script whose header declares a JSON-on-stdout contract" (line added by
      commit 3d100ff42). The write IS redirected to a file, so this looks like a false positive
      in the lint predicate (it probably does not recognise a redirect to a variable-named path).
  (3) test-gate-out-repair-reporting.sh: Case 3 expects SKILL_VALIDATE_FIXES=2 and gets 0; Case 4
      reads fixes=0 errors=1; Case 6 (stale globals check) reads fixes=0. This fixture copies
      lib/*.sh wholesale from the deploy tree, so it is NOT the missing-lib cause. A candidate
      (unconfirmed) is the archive-aware changes to skill-base.sh / dispatch validation in
      commits f6051c255 and 5a446d6e1.
  A quick grep shows other suites under scripts/tests/ that reference task-lock.sh,
  skill-base.sh or update-task-status.sh together with explicit lib names (e.g.
  test-update-task-status.sh, test-git-commit-scoped.sh, test-phase-heartbeat.sh,
  test-corroborate-phase-counts.sh, test-resume-scan-nonconformance.sh); they have not been
  checked for the same gap. The eight orchestrate suites that source task-lookup-lib.sh directly
  were verified green and are not in scope.

WORK.
(a) Suite (1): add task-lookup-lib.sh to the fixture's REQUIRED_LIBS (plus anything else it
    transitively needs; check by running, don't assume). Keep the fixture's explicit list rather
    than switching to a wholesale copy unless you justify the change.
(b) Suite (2): decide between fixing the lint predicate so a redirect to a file path held in a
    variable is not flagged, allowlisting this line with a stated reason, or changing the code.
    Record the decision and why. If the predicate is fixed, add a lint fixture case covering
    `> "$var"` redirects so the false positive cannot come back, and confirm genuine unredirected
    stdout writes are still caught.
(c) Suite (3): diagnose the root cause first and write it down (which change altered
    SKILL_VALIDATE_FIXES counting or reporting, and whether the test or the code is now wrong).
    Then fix the side that is actually wrong. If the code behaviour changed on purpose, update
    the test's expectations only with a written justification tied to that design change.
(d) Audit every test fixture under core/scripts/tests/ that copies task-lock.sh, skill-base.sh or
    update-task-status.sh using an EXPLICIT lib list, for the same missing-lib gap. Fix any gaps
    found, and record the audit result (suites checked, gaps found, fixes made) in the
    implementation summary.

COORDINATION. A later task isolating shell suites from host state
(isolate_shell_suites_from_host_state) depends on this one and edits core/scripts/tests/. Keep
fixture changes minimal and local so that work lands cleanly on top.

MUST NOT. Do not weaken or delete assertions to get suites green. Do not hand-edit .claude/**. Do
not make task-lock.sh's source of task-lookup-lib.sh silently optional (it is a critical path)
unless that is justified and recorded as a deliberate design decision.

ACCEPTANCE. All three suites pass run from the source store and from the deployed .claude/ copy
after redeploy. The fixture audit result is recorded. The suite (2) decision and the suite (3)
root cause are recorded. shellcheck clean per context/standards/shell-strict-mode.md for every
shell file touched.

DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 202. Make the picker's [Reload All] and [Regenerate] entries honest and self-documenting, and rule on their redundancy
- **Status**: [NOT STARTED]
- **Task Type**: general
- **Topic**: neovim
- **Dependencies**: None

**Description**: Fix the <leader>al picker's [Reload All] / [Regenerate] entries: a factually wrong one-line description, an absent Command Details preview for both, and an undecided redundancy question.

EDIT TARGET: lua/neotex/plugins/ai/claude/commands/picker/** and lua/neotex/plugins/ai/shared/extensions/**. This is nvim-config Lua UI code, NOT agent-system/extensions/**; nothing here touches the deployed .claude/ tree.

=== VERIFIED CURRENT BEHAVIOUR (read from source, not inferred) ===

The two entries are DIFFERENT operations, and both act on the CURRENT REPO ONLY (cwd):

[Reload All] (picker/init.lua:159-286) opens a vim.ui.select submenu with four choices --
"Reload All", "Unload All", "Step Through", "Cancel". The "Reload All" choice calls
exts.resync_all(), whose own doc comment at shared/extensions/init.lua:895-898 states: "Never
unloads: each extension is re-loaded in place via manager.load(..., {force = true}), so there is
no destructive intermediate 'everything unloaded' state." It force-resyncs every CURRENTLY LOADED
extension in Kahn's-algorithm dependency order. Non-destructive. No confirmation prompt.
("Step Through" is currently a no-op that just reopens the picker.)

[Regenerate] (picker/init.lua:110-156) calls exts.wipe({project_dir = vim.fn.getcwd()}), which
runs vim.fn.delete(target_dir, "rf") at shared/extensions/init.lua:1253 -- snapshot ->
rm -rf base_dir -> regenerate from the surviving project-root extension manifest -> restore
settings.local.json and .syncprotect-listed paths -> clear staging. Destructive. Confirmation
required.

=== DEFECT 1: THE [Reload All] ONE-LINER DESCRIBES [Regenerate], NOT ITSELF ===

display/entries.lua:980-982 renders [Reload All] with the trailing text:

    "Wipe and reload all loaded extensions"

It does not wipe. resync_all never unloads and never deletes. The word "Wipe" belongs to
[Regenerate], whose own one-liner at entries.lua:995-997 ("Wipe and rebuild from the extension
manifest") is accurate. So the picker currently presents two adjacent entries whose visible
descriptions both begin "Wipe and ...", one of which is false -- which is precisely the confusion
that motivated this task: an operator reaching for a rebuild picked [Reload All] on the strength
of that line.

Note the contradiction is already internal to the codebase: display/previewer.lua:129-130
describes the same entry correctly as "Force-resyncs every currently loaded extension in
dependency order (non-destructive)." Two descriptions of one entry disagree.

=== DEFECT 2: NEITHER ENTRY HAS A Command Details PREVIEW ===

Both entries are created with entry_type = "special" plus a boolean flag (is_reload_all,
is_regenerate) at entries.lua:974-999. The previewer's define_preview dispatch chain
(previewer.lua:628-661) branches on is_heading, is_help, and then eleven entry_type values --
skill, hook_event, lib, script, test, template, doc, command, extension, agent, root_file. There
is NO branch for is_reload_all, is_regenerate, or entry_type == "special". Both therefore fall to
the terminal else at previewer.lua:658-659, which writes the single line "Unknown entry type"
into the "Command Details" pane.

So the pane is not blank -- it renders a developer-facing error string for two entries that are
working as designed. The real documentation for both operations exists, but it is buried inside
preview_help (previewer.lua:129-135), reachable only by selecting the separate [Keyboard
Shortcuts] entry.

DECIDE, do not assume: whether to add a dedicated preview_special branch keyed on the two boolean
flags, or to give special entries a shared preview keyed on entry_type == "special" that reads a
per-entry description field. Either way, the terminal else branch should stop being reachable for
entries the picker itself ships -- consider whether "Unknown entry type" is the right fallback at
all, or whether it should name the offending entry so the next gap is diagnosable.

=== DEFECT 3: THE REDUNDANCY QUESTION, UNDECIDED ===

There is genuine partial overlap: [Regenerate]'s wipe-and-rebuild reloads the same extension set
[Reload All] resyncs, so it subsumes the OUTCOME while differing in method, risk, and guarantees.
Whether that justifies two entries is a real design call, not an obvious yes or no. Weigh at
least: (a) keep both, with corrected descriptions that make the destructive/non-destructive
distinction the FIRST thing each line says; (b) collapse [Regenerate] into the [Reload All]
submenu as a fourth, confirmation-gated choice alongside Unload All, giving one entry point for
all bulk extension operations; (c) keep both but rename them so neither reads as a synonym of the
other. Record the ruling and its reasoning.

While deciding (b), note the [Reload All] submenu already contains a dead choice: "Step Through"
(init.lua:180-185) does nothing but reopen the picker. Decide its disposition too -- implement or
remove; do not leave a menu item that silently no-ops.

=== A CORRECTION TO THE OPERATOR'S MENTAL MODEL, WORTH RECORDING IN THE PREVIEW TEXT ===

[Regenerate] is sometimes remembered as "run Reload All across every repo that has loaded the
agent system, preserving each repo's own loaded extension set". It does NOT do that, and never
has -- it is single-repo, scoped to vim.fn.getcwd(), exactly like [Reload All].

That cross-repo capability is a DIFFERENT, already-filed, not-yet-started piece of work: the
task titled "Implement <leader>al repo registration and 'Global Update' action" describes
registering repos that <leader>al loads extensions into, and adding a 'Global Update' entry
"similar to 'Reload All'" that reloads all extensions already loaded in each registered repo.
Coordinate with it rather than implementing cross-repo behaviour here; this task's job is to make
the two EXISTING single-repo entries honest and self-documenting. Whichever of the two lands
second should make sure all three entries read as a coherent set.

=== ACCEPTANCE ===

- [Reload All]'s visible one-liner no longer claims it wipes, and states its non-destructive
  force-resync nature; [Regenerate]'s continues to state its destructive nature. The two lines are
  distinguishable at a glance.
- Selecting either entry renders real content in the "Command Details" pane -- what it does, what
  it touches, whether it is destructive, whether it prompts -- and "Unknown entry type" is no
  longer reachable for any entry the picker ships.
- The entries.lua one-liner and the previewer text for a given entry agree with each other and
  with the implementation; a check or comment records that they must be kept in sync.
- The redundancy ruling is recorded with reasoning, and "Step Through" is either implemented or
  removed.
- Verified by opening <leader>al and selecting each entry, not by reading the diff alone.

---

### 200. Close the consumer-repo deploy propagation gap that leaves fixed defects live in deployed trees
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**).

DEFECT. A defect fixed in the source store and marked completed can remain live indefinitely in a consumer repository's deployed `.claude/` tree, where it continues to mislead every agent that reads it. Nothing enforces propagation, and the only detector is opt-in and report-only.

OBSERVED LIVE (2026-09-09). A lean-implementation-agent dispatch in ~/Projects/BimodalLogic followed its own deployed agent definition's documented build command and got exit 77 (`build mode requires a lake subcommand`), because the deployed copy read `lake-build-guard.sh build --timeout 1800 -- 2>&1` -- an empty lake-argument vector that can never launch a build.

THAT EXACT DEFECT WAS ALREADY FIXED AND CLOSED. Task 176 ("Fix the documented lake-build-guard full-build invocation across the lean extension") corrected precisely these call sites and is marked completed. Verified by direct comparison:

  agent-system/extensions/lean/agents/lean-implementation-agent.md:253   (SOURCE, correct)
    bash .claude/scripts/lake-build-guard.sh build --timeout 1800 -- build 2>&1
  /home/benjamin/Projects/BimodalLogic/.claude/agents/lean-implementation-agent.md:253   (DEPLOYED, stale/broken)
    bash .claude/scripts/lake-build-guard.sh build --timeout 1800 -- 2>&1

The same divergence holds for lean-implementation-hard-agent.md:392, rules/lean4.md:51, and skills/skill-lake-repair/SKILL.md:81. So no documentation fix is needed in the source store -- it is already correct. The defect is entirely one of PROPAGATION. Do not "re-fix" the source store; confirm it is correct and leave it alone.

THE STALENESS IS PARTIAL, WHICH IS THE DANGEROUS PART. In the same deployed tree, `core/scripts/git-snapshot.sh` is BYTE-IDENTICAL between source and deploy, while `lean/agents/lean-implementation-agent.md` differs. An operator (or agent) who spot-checks one file and concludes "the deploy is fresh, so the source store is the right edit target" reaches a correct conclusion about the edit target for the wrong reason, and will not suspect that a DIFFERENT file in the same tree is months out of date. This exact reasoning was performed during the observing session. Any remedy must make partial staleness visible, not just whole-tree staleness.

ROOT CAUSE, CONFIRMED IN THE SOURCE. The detector exists but is deliberately inert by default:
  - `agent-system/extensions/core/scripts/check-consumer-freshness.sh` exists and can report STALE/CANNOTVERIFY rows per consumer repo.
  - In `deploy-headless.sh` it fires ONLY behind `--consumer-report` (`CONSUMER_REPORT=false` by default). Task 180 made it opt-in on purpose, for a good reason: on the blocking redeploy-checkpoint path it walked ~50 repositories, cost ~10 minutes of wall clock, and produced output the gate could not act on.
  - The script's own comments state the scan "is report-only and can NEVER change this script's exit code", and that deploy-headless.sh never redeploys into a consumer -- the documented remedy is for a human to run the deploy manually in each stale repo.
So the design is: detect only if asked, never act, and rely on a human remembering. The observed defect is that design working exactly as specified.

THIS IS NOT A REQUEST TO REVERT TASK 180. Putting a 10-minute unactionable walk back on a blocking gate would re-create a worse problem. The question is how to close the propagation gap WITHOUT that cost. Weigh at least these, and recommend:
  (a) PULL-SIDE FRESHNESS CHECK. Have the consuming repo verify its own `.claude/` tree against the source store at a cheap, natural moment -- e.g. skill preflight in `core/scripts/skill-base.sh`, or dispatch time -- rather than having the source repo push-scan 50 consumers. This inverts the cost: each repo checks only itself, only when it is actually being used. Strongly consider this as the primary direction.
  (b) CHEAP WHOLE-TREE FINGERPRINT. A single content hash or manifest digest per deployed extension, so "is this tree current?" is one comparison instead of a file walk -- and so PARTIAL staleness is caught, which a timestamp or a single-file spot-check will not catch.
  (c) MAKE THE SIGNAL ACTIONABLE. If a stale consumer is detected at dispatch time, decide what happens: warn loudly in the dispatch brief, auto-redeploy, or refuse the dispatch. An unactionable warning is what already exists and it did not work.
Do not pre-commit to one; measure the cost of the cheap check and justify the choice.

SCOPE BOUNDARY. Detection and signalling of consumer staleness, plus whatever minimal action the recommendation supports. Not in scope: re-fixing the lean docs (already correct at source), and redeploying every consumer repo as a data-migration exercise. Bringing ~/Projects/BimodalLogic's tree current is a reasonable one-line verification step at acceptance time, not the deliverable.

MUST NOT. Do not put an unbounded consumer walk back on any blocking gate path. Do not edit `.claude/**` in any repo by hand -- a stale deployed tree is fixed by redeploying it, never by hand-patching it, and hand-patching would additionally mask the very divergence this task exists to detect. Do not change the lean extension's already-correct source documentation.

ACCEPTANCE. A consuming repo whose deployed `.claude/` tree diverges from the source store in even ONE file is detected, cheaply, at a moment when the information can still change what an agent does -- demonstrated by a fixture that reproduces the observed shape (one file identical, one file stale, in the same tree). The chosen remedy's wall-clock cost is measured and shown not to reintroduce the regression task 180 removed. The recommendation and its rejected alternatives are recorded. shellcheck clean per context/standards/shell-strict-mode.md. Finally, verify by redeploying into ~/Projects/BimodalLogic that the four stale lean call sites there now match source.

DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 199. Decide and implement the working-tree and build isolation posture for concurrent same-repo dispatches
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 191, Task 192, Task 193, Task 213, Task 214

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ and agent-system/extensions/lean/ (never .claude/**).

DECIDE, THEN IMPLEMENT: should concurrent same-repo /orchestrate dispatches keep sharing one working tree and one build directory, or should each dispatch get an isolated one? Weigh the options against the accumulated evidence; do not presuppose either.

=== THE ROOT CAUSE PRODUCES THREE DISTINCT FAILURE MODES ===

All three were observed live on 2026-09-09 in ~/Projects/BimodalLogic, tasks 574 and 575 dispatched concurrently as lean-implementation-agent into ONE shared working tree. They share a single root cause -- concurrent dispatch onto shared mutable resources -- but each has its own mechanism, and no single per-mechanism patch addresses more than one of them. This taxonomy is the core input to the decision.

  MODE 1a -- WORKING-TREE REVERT. The 575 dispatch ran `git-snapshot.sh 575` in DEFAULT mode while 574 was editing the same tree. Default mode runs `git stash push -u` repo-globally with NO pathspec, stashing away the sibling's uncommitted work (574's `.return-meta.json`, `.claude-extensions.json`, 7 lines of `specs/events.jsonl`). Detected and restored from `stash@{0}` by the agent noticing -- nothing at any layer would have caught it otherwise. Corroboration that this recurs: `git stash list` holds 44 entries, 32 named `git-snapshot-*`.
    Fixed by: auto/mandated `--no-revert`. Does NOT fix 1b or 2.

  MODE 1b -- CROSS-TASK COMMIT BLEED. VERIFIED DIRECTLY. Commit 08936bfbb ("task 574 phase 5: TM-star ledger rows and declaration-site Paper: lines") carries THREE task-575 rows in docs/theorem-index.md -- `isPlusStateLocal_of_stateLocal`, `plusStateLocal_plusValid_iff_stab`, `stateLocal_ofPlus_iff` -- plus a table header. Reproduce with `git show 08936bfbb -- docs/theorem-index.md`. Self-reported by the 574 dispatch and confirmed by the 575 dispatch. Both agreed nothing should be reverted, because reverting would delete 575's legitimate rows from HEAD. Recorded as cross-task bleed, NOT misattributed authorship.
    Fixed by: nothing currently filed. See the next section -- this is the mode that breaks the existing mitigation.

  MODE 2 -- BUILD CONTENTION. The 575 dispatch lost two builds to concurrent `lake` processes sharing one `.lake` directory. One was self-inflicted: it ran `scripts/check-module-invariants.sh` alongside a guarded build.
    Fixed by: a build mutex. Does NOT fix 1a or 1b.

=== WHY MODE 1b IS THE DECISIVE EVIDENCE: IT DEFEATS THE EXISTING MITIGATION ===

core/rules/git-workflow.md forbids `git add -A` and `git commit -am` for exactly this hazard -- pulling in "concurrent-session or unrelated stray edits" -- and prescribes targeted explicit-path staging as the remedy. The 574 dispatch FOLLOWED that prescription. It staged docs/theorem-index.md by explicit whole path, correctly, and bled anyway.

The reason is structural and cannot be patched at the staging layer as currently designed: EXPLICIT-PATH STAGING CANNOT SPLIT A FILE. Path granularity is the file. Two dispatches touching one shared file bleed into each other's commits no matter how carefully each one stages. In this repo several files are shared by construction -- docs/theorem-index.md, README.md, scripts/check-module-invariants.sh -- so the collision surface is not incidental.

INTERACTION WITH THE OVER-STAGING WORK (task 192) -- IMPORTANT, READ IT. That task widens the over-staging predicate to catch directory pathspecs, and its MUST NOT correctly protects "an explicit list of named file paths" as the sanctioned form that agents are told to use. Nothing here contradicts that: the explicit list must indeed remain permitted, because blocking it would leave agents with no compliant way to commit at all. What mode 1b establishes is narrower and does not overturn task 192: the sanctioned form is SUFFICIENT against over-broad staging and INSUFFICIENT against concurrent same-file dispatch. These are different hazards. Do not re-decide task 192's predicate here; do record this qualification so the rules stop implying that explicit-path staging is a complete answer under concurrency.

=== THE OPTIONS TO WEIGH ===

Produce an explicit recommendation with reasoning; the deciding artifact is as much the deliverable as the code. Score each option against ALL THREE failure modes above -- an option that fixes one mode and leaves two open should be scored as such.

  OPTION 1 -- KEEP THE SHARED TREE, PATCH PER MECHANISM. Continue dispatching siblings into one working tree and one `.lake`, closing holes individually. Already filed on this branch: task 191 (git-snapshot revert, mode 1a), task 192 (directory-pathspec over-staging), task 193 (territory in briefs). This task's contribution would be hardening mutex participation for mode 2.
    Score honestly: this branch has no answer to mode 1b at all. It is also the fourth-plus patch against one root cause, each closing an enumerated hole -- note the pattern already recorded in task 192, where a refusal that enumerated forms simply taught the enumeration and the agent reached for the nearest unnamed form.

  OPTION 2 -- PER-DISPATCH GIT WORKTREE ISOLATION. Give each concurrent implement dispatch its own `git worktree` (and therefore its own `.lake`), merging results back at commit time.
    Weigh honestly: it is the only option that addresses all three modes at once -- no shared tree means no sibling revert (1a) and no shared working copy to bleed from (1b); no shared `.lake` means no build contention (2) -- and it does so WITHOUT reducing concurrency. Against that: each worktree pays a full cold build, potentially very expensive for this repo (MEASURE IT, do not assume); merge-back at commit time is new machinery and does not make same-file conflicts vanish, it converts them from silent bleed into an explicit merge that someone or something must resolve -- cost that honestly, it is the main weakness of this option; the harness already exposes a worktree isolation mode for subagents, so check what is reusable before building. Prior art exists in the source store under the lean and cslib extensions (comparator runs, lint-fix wave assignment) -- read it before designing.

  OPTION 3 -- NARROWER STAGING-LAYER ALTERNATIVE, WORTH COSTING BEFORE COMMITTING TO 2. Either (i) teach `core/scripts/git-commit-scoped.sh` to stage by HUNK rather than by path, so a dispatch commits only its own edits within a shared file; or (ii) have it REFUSE a shared file while a sibling dispatch holds uncommitted edits in it, forcing explicit sequencing. This targets mode 1b directly and is far cheaper than worktrees.
    Weigh honestly: (i) needs a reliable way to attribute a hunk to a dispatch, which the system may not have -- establish whether it does before recommending it. (ii) needs live sibling-edit knowledge at commit time, which relates to what task 193 makes available; say so and do not duplicate that work. Neither variant addresses modes 1a or 2.

  A SPLIT VERDICT IS AN ACCEPTABLE OUTCOME -- e.g. worktree isolation for lean4/cslib implement dispatches where builds are expensive and collisions frequent, shared tree plus option 3 for cheap doc/meta dispatches. If that is the recommendation, define the predicate that selects between them.

=== NOT A CONTRADICTION OF TASK 193 ===

That task's MUST NOT says "do not serialize all multi-task dispatch as the fix; concurrency is the design". No option here proposes running the batch sequentially: worktree isolation preserves full concurrency and removes the shared resource instead. Coordinate rather than re-decide -- task 193 decides what a dispatch is TOLD, this decides what a dispatch RUNS IN. Note also that informing agents is demonstrably insufficient on its own for mode 1b: both dispatches here ended up fully aware of each other and the bleed still landed in history.

=== CORRECTION TO THE ORIGINAL MODE-2 DIAGNOSIS: THE BUILD MUTEX ALREADY EXISTS ===

Mode 2 was initially reported as "needs a build mutex in lake-build-guard.sh". Verified against the source: agent-system/extensions/core/scripts/lake-build-guard.sh ALREADY implements a `flock`-based mutex on `$GUARD_LAKE_DIR/build-guard.lock`, with lock-wait timeout (exit 75), abandoned-lock recovery via flock's automatic release on process exit, and result sharing between waiter and holder. It degrades audibly when `flock` is absent rather than silently running unserialized. The mutex is not missing.

WHAT IS MISSING IS THAT IT IS OPT-IN. The guard's header states it: "any other consumer must opt in explicitly by invoking `lake-build-guard.sh build ...`". Any process running bare `lake` bypasses the lock. The self-inflicted collision is exactly this -- /home/benjamin/Projects/BimodalLogic/scripts/check-module-invariants.sh calls bare `lake build` and `lake build BimodalTest` (around lines 638/644) with no guard. The failure mode is BYPASS, not absence. Note that this same script is itself one of the shared-by-construction files implicated in mode 1b (it was modified in commit 08936bfbb).
  OWNERSHIP: check-module-invariants.sh is a BimodalLogic project-local script, NOT an agent-system file. Fixing that call site is OUT OF SCOPE. In scope is the general question it exposes: how does the agent system get unguarded lake-invoking callers to participate in the mutex, given that it cannot edit every consumer repo's scripts?

=== WORK ===

  (a) Measure before deciding: cold-build cost for this repo under a fresh worktree; observed frequency of guard-lock contention versus outright bypass; whether per-dispatch hunk attribution is even available (gates option 3(i)).
  (b) Produce the written recommendation scoring every option against all three failure modes, recorded in the task summary and in core/context/patterns/batch-orchestration-guardrails.md.
  (c) Implement the chosen option.
  (d) Whichever option wins, document (i) the mutex's opt-in nature and the bypass hazard, in lean/rules/lean4.md's build section and the guard's header if the participation contract changes; and (ii) the mode-1b qualification -- that explicit-path staging does not protect against concurrent same-file dispatch -- wherever the rules currently present targeted staging as the concurrency remedy.

=== MUST NOT ===

Do not edit core/scripts/git-snapshot.sh, core/rules/git-workflow.md or the plan format (task 191 owns those; the mode-1b rules qualification in (d)(ii) must be coordinated with that task rather than written directly into git-workflow.md here). Do not edit hooks/guard-destructive-git.sh or re-decide the over-staging predicate (task 192). Do not block explicit multi-file path staging -- it must remain the sanctioned form. Do not implement the territory payload (task 193). Do not edit any BimodalLogic project-local script. Do not remove or weaken the existing flock mutex under any option. Do not attempt retroactive repair of commit 08936bfbb -- both dispatches deliberately agreed against reverting, because the bled rows are legitimate content.

=== FOOTPRINT NOTE ===

file_scope overlaps tasks 182, 193 and 197 on orchestrate-cycle-plan.sh, and task 191 conceptually on the staging rules; the file-footprint admission gate will serialize the overlapping ones. Whichever lands last reconciles the header contracts.

=== ACCEPTANCE ===

A written, evidence-backed recommendation exists naming the chosen posture, scoring every option against modes 1a, 1b and 2 explicitly, with the cold-build measurement and the hunk-attribution feasibility finding that informed it. The chosen option is implemented. A fixture reproduces the observed batch shape -- two concurrent lean4 implement dispatches in one repo, both editing one shared markdown file, one of them invoking an unguarded `lake` -- and demonstrates that cross-task bleed into a commit no longer occurs (or, if option 1 was chosen, documents plainly that it still can and why that was accepted). The opt-in nature of the build mutex is documented where an agent will read it. shellcheck clean per context/standards/shell-strict-mode.md for any shell touched. Redeploy and confirm the change is live in a consumer repo.

DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 198. Mandate git-snapshot --no-revert in the lean implementation agent contracts
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: lean-extension
- **Dependencies**: Task 191, Task 194

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/lean/ (never .claude/**).

DEFECT. The lean implementation agent contracts say NOTHING about git-snapshot.sh. Verified by grep against the source store: `orchestrator_mode`, `git-snapshot` and `no-revert` each appear ZERO times in agent-system/extensions/lean/agents/lean-implementation-agent.md. A lean implementation dispatch that reaches for a pre-work backup therefore finds no guidance at all and lands on the script's DEFAULT mode, which reverts the working tree repo-globally.

OBSERVED LIVE (2026-09-09, ~/Projects/BimodalLogic, tasks 574 and 575 dispatched concurrently as lean-implementation-agent into ONE shared working tree). The 575 dispatch ran `git-snapshot.sh 575` in default mode while the 574 dispatch was concurrently editing the same tree. Default mode runs `git stash push -u` repo-globally with NO pathspec, so it stashed away the SIBLING dispatch's uncommitted work: 574's `.return-meta.json`, `.claude-extensions.json`, and 7 lines of `specs/events.jsonl`. The 575 dispatch noticed the over-capture and restored from `stash@{0}` (kept, not dropped), so nothing was ultimately lost -- but detection and repair depended ENTIRELY on the agent happening to notice. A less attentive dispatch proceeds on a silently reverted tree with no error at any layer.

THIS IS A CALLING-CONVENTION GAP, NOT A SCRIPT BUG. git-snapshot.sh already documents the hazard loudly in its own header ("WARNING: default and --branch modes REVERT the working tree"; "Despite the name, this script is NOT read-only in its default or --branch modes") and already implements the correct alternative: `--no-revert`, which builds a durable stash object via `git stash create` + `git stash store` WITHOUT touching the working tree, described in the header as the mode for "when you want a durable backup and intend to KEEP WORKING". agent-system/extensions/core/agents/general-implementation-agent.md ALREADY calls it correctly with `--no-revert` and explains why. The lean agents were simply never given the same bullet.

CORROBORATION THAT THIS RECURS. `git stash list` in ~/Projects/BimodalLogic currently holds 44 entries, 32 of them named `git-snapshot-*`, accumulated across many sessions. This is not a one-off.

SCOPE -- DELIBERATELY SMALL, SHIPS ON ITS OWN. Add to both lean implementation agent contracts an explicit instruction that `git-snapshot.sh` MUST be invoked with `--no-revert` whenever the dispatch is running under `orchestrator_mode` (i.e. whenever a concurrent sibling dispatch may share the working tree), and SHOULD be preferred generally when the agent intends to keep working after the snapshot. State the reason in one line -- default mode reverts the tree repo-globally and will capture a sibling's in-flight edits -- so the bullet teaches the hazard rather than only the incantation. Mirror the wording already used in core/agents/general-implementation-agent.md rather than inventing a second phrasing.

RELATIONSHIP TO OTHER FILED WORK -- READ BEFORE STARTING.
  - Task 191 ("Stop plan-mandated git-snapshot from reverting task-unrelated uncommitted work") owns the SCRIPT-LEVEL remedy in core/scripts/git-snapshot.sh plus core/rules/git-workflow.md and the plan-format/planner emission path. This task deliberately does NOT touch any of those files. A contract bullet is the cheap interim mitigation that can land immediately; it is explicitly NOT a substitute for the runtime guard, because a bullet can be forgotten. Both are wanted.
  - Task 191's currently-recorded design direction keys the proposed refusal on "tracked paths OUTSIDE the task's declared file_scope". Note for that task, and record it in this task's summary: that predicate does not cleanly cover the concurrent-sibling case observed here, where a sibling's edits may fall INSIDE an overlapping declared scope. A live-concurrent-dispatch predicate is a distinct condition from an out-of-file_scope predicate. Surface this; do not implement it here.

MUST NOT. Do not edit core/scripts/git-snapshot.sh, core/rules/git-workflow.md, or the plan format -- those belong to task 191 and would collide. Do not weaken or remove `--no-revert`. Do not `git stash drop`/`clear` any existing entry.

ACCEPTANCE. Both lean implementation agent contracts instruct `--no-revert` under orchestrator_mode, with the one-line rationale. The wording matches the existing core agent contract. The lean extension is redeployed and the regenerated `.claude/**` copies carry the bullet (see the deploy-propagation task -- a source-store fix that never reaches the consuming repo changes nothing for a running agent).

DELIVERABLE RULE: no task numbers in deliverables outside specs/**.


SCOPE CEILING -- KNOW WHAT THIS DOES NOT FIX. The concurrent-dispatch root cause produces three distinct failure modes: working-tree revert (this one), cross-task commit bleed via whole-path staging on a shared file, and .lake build contention. The isolation-posture task enumerates all three with verified evidence and decides the structural remedy. This contract bullet addresses ONLY the working-tree revert mode, and only by convention rather than by construction. Do not let it close out the other two, and do not let its landing be read as evidence that the shared-tree posture is safe.

---

### 195. Replace is_contractual_handoff_writer allowlist with a dispatch-derived predicate
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 162, Task 194, Task 212, Task 213, Task 214

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**, a disposable deploy tree regenerated from the source store; hand edits there are silently wiped). Consumer repos pick the fix up via their own redeploy.

DEFECT. is_contractual_handoff_writer() in agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh returns 0 for exactly two hard-mode agents:

  is_contractual_handoff_writer() {
    case "$1" in
      cslib-implementation-hard-agent|lean-implementation-hard-agent) return 0 ;;
      *) return 1 ;;
    esac
  }

Every other agent falls through to `return 1` and is treated as a non-writer. Consequently all base-mode implementation agents -- general-implementation-agent (the default for general/meta/markdown and, via noncore-exact routing, formal task types), lean-implementation-agent, typst-implementation-agent -- plus every research and plan agent are excused when .orchestrator-handoff.json is absent. No HANDOFF_STALE_OR_ABSENT defect is recorded via system-defect-record.sh, and a real failure goes unattributed.

OBSERVED LIVE (evidence, not hypothesis). An /orchestrate implement dispatch to general-implementation-agent died on context exhaustion ('Prompt is too long') without writing a handoff. Postflight emitted verbatim:

  [orchestrate] WARN: agent name 'general-implementation-agent' is not on the contractual handoff-writer allowlist -- treated as a non-writer, no defect recorded for the absent handoff. If 'general-implementation-agent' is a genuine new hard-mode writer, add it to is_contractual_handoff_writer() in this script.

The run then degraded silently to heading-scan recovery (plan headings showed 16/16 phases closed) and no defect row was recorded.

THE DECISION IS NOT PRE-MADE -- WEIGH (a) AGAINST (b) IN RESEARCH.
  (a) Extend the hardcoded allowlist to cover every lifecycle agent.
  (b) Invert the predicate so writer status derives from whether the dispatch supplied a handoff_path, eliminating the agent-name list entirely and making the contract self-maintaining as new agents and extensions are added.

Option (b) is FAVORED but must be justified, not assumed. The case for it: the existing list has already drifted behind the agent roster, which is the proximate cause of the observed miss. The structural support: skill-orchestrate/SKILL.md Move 3 loops over .dispatch[] rows ONLY and states outright that an aux_dispatch[] row never reaches Move 3; Move 2 supplies handoff_path to every dispatch[] row and deliberately omits the key for aux rows. So every agent that reaches postflight is, by construction, a handoff-expected dispatch.

THE WRINKLE THAT MUST BE RESOLVED. Postflight does not receive handoff_path as an argument. It derives handoff_file itself from --task-dir. Option (b) therefore requires choosing between two concrete shapes, and the research phase must pick one and record why:
  - Treat 'reached postflight at all' as the predicate (simplest; correct today given the Move 3 dispatch[]-only loop, but silently depends on that invariant holding).
  - Thread an explicit --handoff-expected true|false flag from the dispatch row through skill-orchestrate's Move 3 call site (more plumbing; preserves the distinction explicitly if an aux row ever starts reaching postflight).
Assess both against how postflight actually receives dispatch metadata today -- its full CLI contract is documented in its own header Usage block.

SCOPE. Implement the chosen fix. Replace the now-misleading WARN text at the fall-through branch, which currently instructs the reader to 'add it to is_contractual_handoff_writer() in this script' -- guidance that will be wrong under either fix. Update the D1 header comment block, which asserts the allowlist is 'the complete, closed set of contractual writers today'. Add fixture coverage to scripts/tests/test-orchestrate-cycle-postflight.sh for the absent-handoff branch under a base-mode lifecycle agent, which is the exact case that produced no defect row in the observed run.

DEPENDS ON the lifecycle-agent contract alignment task, which must land first: widening detection ahead of the stated obligation would record defects against agents whose contracts never asked them to write a handoff.

MUST NOT. Do not weaken the mtime staleness gate, the dispatch_seq identity gate, or the fail-closed 9999999999 sentinel -- this change concerns only the ABSENT-handoff branch, never the present-but-stale or present-but-mismatched branches, which already record unconditionally. Do not edit agent contract files (the companion task's territory; the file scopes are deliberately disjoint). Do not write task numbers into any script or skill deliverable (see .claude/rules/no-task-references-in-deliverables.md).

ACCEPTANCE. An absent .orchestrator-handoff.json from any lifecycle dispatch -- base mode included -- records a HANDOFF_STALE_OR_ABSENT defect. An aux dispatch still records none. The fixture reproduces the observed general-implementation-agent case and demonstrates the defect row is now written. The WARN text and D1 header comment no longer instruct the reader toward a removed or superseded mechanism. shellcheck clean per context/standards/shell-strict-mode.md.

---

### 194. Align lifecycle agent contracts on .orchestrator-handoff.json writing
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/*/agents/ (never .claude/**, a disposable deploy tree regenerated from the source store; hand edits there are silently wiped).

DEFECT. The handoff-writing obligation is asserted by orchestrate-cycle-postflight.sh's detection logic but is NOT uniformly stated in the agent contracts it judges. Several agents that are routinely dispatched through a dispatch[] row -- and therefore reach postflight, where an absent .orchestrator-handoff.json is a real failure signal -- carry no statement of the obligation at all.

STARTING EVIDENCE (measured 2026-09-09 by counting '.orchestrator-handoff.json' occurrences in each agent's own contract file under agent-system/extensions/*/agents/):
  - planner-agent: 0
  - lean-implementation-agent: 0
  - typst-implementation-agent: 0
  - general-research-agent: 2
  - general-implementation-agent: 5
  - lean-implementation-hard-agent: 7

THIS COUNT IS A STARTING POINT, NOT A VERIFIED-COMPLETE ROSTER. It samples six agents only. The audit must independently enumerate EVERY agent reachable via a dispatch[] row -- research, plan, and implement phases, across core and all loaded extensions -- rather than trusting the six above. Use skill-orchestrate/SKILL.md Move 2 and the routing tables in each extension manifest.json (routing_agents / routing_agents_hard) to derive the true reachable set; a mention count of zero is evidence of a missing contract statement, and a nonzero count is not by itself evidence that the statement is correct or complete.

WHY THIS COMES FIRST. The companion task widens postflight's contractual-writer predicate so that an absent handoff from a lifecycle agent is recorded as a HANDOFF_STALE_OR_ABSENT defect instead of being silently excused. Widening detection BEFORE the contracts state the obligation would flood errors.json with defect rows attributed to agents that were never told to write a handoff -- correct detection against an unstated obligation. This task establishes the obligation so the widened detection lands on a contract that actually exists.

SCOPE. For each agent in the reachable set that lacks the obligation, add an explicit contract statement: it MUST write .orchestrator-handoff.json to the task directory named by its dispatch context's handoff_path, on every dispatch where orchestrator_mode is true. Match the wording and placement already used by the agents that state it correctly (general-implementation-agent and lean-implementation-hard-agent are the fullest existing examples) rather than inventing a new phrasing. Note the asymmetry to preserve: an aux_dispatch[] row is deliberately given NO handoff_path key and never writes a handoff -- any contract wording must not oblige an agent dispatched in that mode.

MUST NOT. Do not modify orchestrate-cycle-postflight.sh or the predicate itself -- that is the companion task's territory and the two file scopes are deliberately disjoint. Do not weaken or restate the aux-dispatch exemption. Do not write task numbers into any agent contract (see .claude/rules/no-task-references-in-deliverables.md).

ACCEPTANCE. Every agent reachable via a dispatch[] row carries an explicit, consistently-worded handoff-writing obligation naming .orchestrator-handoff.json and its handoff_path source. The audit records the full enumerated reachable set and the derivation method, so a future reader can re-verify completeness without re-deriving it. The aux-dispatch exemption remains intact and is stated where relevant.

---

### 193. Carry concurrent-sibling territory in base-mode dispatch briefs, the only channel that reaches a running dispatch
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 197, Task 213, Task 214

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**).

DEFECT. In BASE-MODE multi-task /orchestrate, a dispatched agent is never told that concurrent sibling dispatches exist, which files they own, or how it must sequence against them -- and the orchestrator cannot tell it later, because messages sent to a running dispatch do not arrive until after it finishes. The dispatch brief is therefore the ONLY channel that reaches a concurrent agent, and it currently carries no territory information at all.

THE MECHANISM ALREADY EXISTS AND IS WIRED FOR HARD MODE ONLY -- THIS IS NOT NEW FUNCTIONALITY. orchestrate-build-dispatch.sh already accepts `--territory` and emits a "## Territory" section into the brief (lines 392-399), and already pulls in context/contracts/territory.md as a core contract when it is set (line 263). The contract file exists. But orchestrate-cycle-plan.sh populates it at exactly one call site (line 1735) from `h1_territory`, and that whole block is gated on hard mode: line 1555 `if [ "$hard_mode" = "true" ]`, line 1561 `[ "$hard_mode" != "true" ] && continue`. The script's own comment at lines 1731-1733 states it outright: "only ever set for a hard-mode implement candidate ... absent from every base-mode call." So the default concurrent path -- plain `/orchestrate A,B,C` -- dispatches siblings onto one shared working tree with each one structurally unaware of the others.

OBSERVED LIVE (2026-09-08, ~/Projects/BimodalLogic, `/orchestrate 562,542,193`, base mode). Two lean4 implementation dispatches ran concurrently on one tree with no territory in either brief. Consequences, all traceable to that single gap:
  - A tree-wide rename dispatch and a two-file proof-tactic sweep collided on FormalSystem/Metalogic/Soundness.lean. Commits absorbed each other's uncommitted work in both directions (ea1a561c9, 357212808).
  - One dispatch ran git-snapshot.sh in its reverting default mode and reverted the other's in-flight edits plus unrelated user files.
  - One dispatch reported the other for a file_scope breach that had not happened; the three files it cited were its own rename, identifiable by `git log -1`. It had no way to know a sibling existed, let alone what that sibling owned.
  - Full-package builds from one dispatch elaborated the other's uncommitted broken edits, so build results were unattributable in both directions, and one dispatch's build held the guard lock while the other's queued behind it.
The orchestrator detected every one of these and sent corrective messages mid-flight. ALL FIVE were delivered to the dispatch in a single batch AFTER it had completed all twelve of its phases and committed. The agent confirmed it never saw any of them during execution. Corrections that arrive after completion are not corrections.

THE TWO HALVES, BOTH IN SCOPE.
(1) POPULATE TERRITORY IN BASE MODE. Decide what a base-mode territory payload should contain and emit it. At minimum the concurrently-dispatched sibling task numbers and their declared file_scope; consider also the sequencing rationale when one sibling's work is non-idempotent over another's. Note the h1 payload's shape at orchestrate-cycle-plan.sh:1615 as prior art, but do not assume the hard-mode payload is the right base-mode payload -- hard mode's H7 territory is about parallel phase ownership within one task, which is a different fact from cross-task concurrency within one batch.
(2) THE UNDECLARED-SCOPE CASE. A task with `file_scope: null` contributes nothing to any territory payload and is invisible to the overlap gate -- in the observed batch, the tree-wide rename declared no scope, so the gate deferred a third task four times over one directory while the 97-file rename overlapped with nothing. Coordinate with the already-filed work on absent-file_scope admission posture rather than re-deciding it here; this task consumes whatever that one rules, and should say so.

CONSIDER, DO NOT PRE-COMMIT. Whether the delivery limitation itself is fixable (can a dispatched agent drain its mailbox at tool-round boundaries during a long Bash call?) is worth a bounded look, but must NOT be this task's dependency. Even with working mid-flight delivery, constraints known at dispatch time belong in the brief; a message is a worse channel for a fact that was already knowable.

MUST NOT. Do not make base-mode territory a hard-mode-only feature by another name -- the observed harm is entirely in the base-mode path. Do not serialize all multi-task dispatch as the fix; concurrency is the design and the remedy is informing the agents, not abandoning it. Do not duplicate the absent-file_scope ruling.

ACCEPTANCE. A base-mode multi-task dispatch brief names its concurrent siblings and their declared file territory, and the territory.md contract is pulled in as it already is for hard mode. A fixture reproduces the observed batch shape -- two concurrent implement dispatches, one with a declared narrow scope and one with none -- and demonstrates the brief now carries what the agents lacked. The behaviour change is documented in the header contracts of both orchestrate-cycle-plan.sh and orchestrate-build-dispatch.sh. shellcheck clean per context/standards/shell-strict-mode.md.

DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 190. Fix cross-session admission blindness for self-modifying candidates
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 165

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**).

DEFECT. Two SELF-MODIFYING tasks running in SEPARATE concurrent /orchestrate sessions are mutually invisible to every admission gate. Each is admitted solo; neither sees the other; they proceed to edit the same orchestrator-critical file concurrently.

OBSERVED LIVE (2026-09-08, this repository, not hypothetical). Two /orchestrate sessions ran concurrently under the same ancestor pid:
  sess_1788883218_cb46bc  /orchestrate 180,181,182
  sess_1788889066_9309df  /orchestrate 189
Both batches claimed agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh. Three commits landed on that file from the 189 session while the other session was in cycle-6 planning for 182. No gate fired. The collision was caught only by a human reading a task notification. 182 had not yet dispatched, so no clobber occurred -- this was luck, not a gate.

MEASURED EVIDENCE (direct probe, reproducible):
  bash .claude/scripts/orchestrate-batch-admit.sh --session-id <A> 182
    -> {"decision":"admit","self_modifying":true}
  bash .claude/scripts/orchestrate-batch-admit.sh --session-id <B> 189
    -> {"decision":"admit","self_modifying":true}
  bash .claude/scripts/orchestrate-batch-admit.sh --session-id <B> 182 189   # SAME batch
    -> 182 admit; 189 DEFER, defer_reason self_modifying, full critical_path + ordering reason
  bash .claude/scripts/orchestrate-batch-admit.sh --session-id <A> 157       # NOT self-modifying
    -> admit + idle_overlap_advisory naming out-of-batch task 170, collision_scope cross_batch

WHAT THIS ISOLATES. The in-batch tie-breaker works correctly. The cross-batch file_scope scan also works -- it fired for the NON-self-modifying candidate (157) against an out-of-batch task. But for a SELF-MODIFYING candidate dispatched solo, the verdict carries no cross-batch collision result and no session-registry result at all. The self-modification branch appears to admit early and short-circuit the file_scope_collision and session_active passes that would have caught the overlap. Confirm that reading against the script's own documented pass ordering (self-mod, then file_scope_collision, then session_active, the last two reached only when the prior finds no hit) before changing anything.

CONTRIBUTING FACTOR, ALREADY REMEDIED, DO NOT RE-FILE. Task 189 carried no file_scope at all, so its session registered an empty covered scope. That was repaired by hand during the incident and is not the root cause: with all 11 paths populated AND the session registry re-registered to match, the solo verdicts above STILL admit. Absent metadata made it worse; it did not cause it.

MUST NOT. Do not make the solo self-modifying candidate DEFER -- that would mean zero dispatch on every solo run of a self-modifying task, which is the exact regression the pre-existing tie-breaker design avoids. The admission DECISION is defensible; what is missing is that the verdict does not carry, and the caller cannot see, a live cross-session collision. Do not change the collision predicate or the verdict schema's existing fields in ways that break orchestrate-predispatch-review.sh, which is a consumer.

ACCEPTANCE. With two live registered sessions whose covered scopes overlap on at least one path, a solo self-modifying candidate in one of them produces a verdict that names the overlap (defer, or admit carrying an explicit cross-session hazard field that orchestrate-predispatch-review.sh renders). A fixture test reproduces the two-session case above and fails against the current script.

NOTE ON LIVENESS DETECTION. Both sessions in the incident reported the SAME pid with pid_source ancestor-claude, because two /orchestrate runs inside one Claude Code process share an ancestor. Any self-exclusion keyed on pid rather than session_id would treat a foreign session as self and silently disable cross-session detection for the most common case. Verify which key the exclusion actually uses; if it is pid, that alone may be the whole defect.

---

### 188. Predispatch review archived dependency false positive
- **Status**: [RESEARCHED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 197
- **Research**: [188_predispatch_review_archived_dependency_false_positive/reports/01_archived-dependency-false-positive.md]

**Description**: Fix orchestrate-predispatch-review.sh Class A false positive: archived completed dependencies reported as nonexistent. MEASURED STATE (observed live in the BimodalLogic repository): the Class A dependency-edge classifier resolves a task dependencies[] against specs/state.json active_projects[] ONLY. A dependency that was completed and then archived by /todo is moved out of active_projects[] into specs/archive/{NNN}_{slug}/, so the classifier reports it as `nonexistent` -- the loudest verdict it has -- when the dependency is in fact SATISFIED. Measured there: 37 unique dependency numbers flagged nonexistent across roughly 30 tasks; ALL 37 resolve to a directory under specs/archive/, and ZERO are genuinely absent. The advisory is therefore ~100 percent false-positive noise on a mature repository, which trains an operator to ignore Class A entirely and would mask a real dangling edge when one finally appears. WORK: teach the Class A classifier a third verdict distinguishing (a) satisfied-and-archived -- resolvable under specs/archive/ -- from (b) genuinely nonexistent -- resolvable nowhere. Report (a) at informational volume or not at all; reserve the loud `nonexistent` wording for (b). Confirm the archive lookup matches the directory naming /todo actually writes (zero-padded {NNN}_{slug}), and decide whether a completed-but-not-yet-archived dependency warrants its own verdict. Check whether scripts/orchestrate-batch-admit.sh and scripts/orchestrate-triage-classify.sh share the same active_projects-only assumption and need the same correction -- the eligibility path narrows out-of-batch edges separately, so a false `nonexistent` there could have different consequences than in the advisory. EDIT TARGET: agent-system/extensions/core/scripts/orchestrate-predispatch-review.sh (this repository is the source store; consuming repositories only carry a gitignored deployed copy under .claude/, so a fix authored there is wiped by the next regeneration). ACCEPTANCE: running the review against a state file whose dependencies point at archived tasks reports zero `nonexistent` findings and classifies those edges as satisfied; a synthetic dependency on a number present in neither active_projects[] nor specs/archive/ still reports loudly as `nonexistent`; the deployed copy in a consuming repo reproduces both outcomes after redeploy.

---

### 187. Unify commit attribution convention
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None

**Description**: Decide and enforce one commit-attribution convention across scripted and hand-written agent commits.

OBSERVED. Across the 16 commits of a single completed task, exactly one commit carried the session-attribution trailer and 15 did not. The one that carried it (2d09265cc) was hand-written by an implementation agent using git directly; the other 15 were produced by scripts/git-commit-scoped.sh, which composes its own commit message from --message plus a Session: line and never picks up harness-supplied attribution guidance. The result is a single task whose history is inconsistent for no principled reason.

NOT A SECURITY ISSUE. During the same run a subagent flagged the attribution guidance as a suspected prompt injection. That was investigated and NOT substantiated: no file in the repository contains the trailer strings or the notice's phrasing, and the guidance arrived alongside a genuine /remote-control invocation that also enabled session-linked tooling. The finding here is consistency, not compromise. Record this explicitly so the earlier false positive is not rediscovered and re-escalated.

THE REAL QUESTION. git-commit-scoped.sh is the single sanctioned committing implementation, and agent contracts direct agents to it -- but agents still sometimes commit with raw git (as 2d09265cc did), and only those commits pick up ambient attribution. Decide which of these is intended: (a) git-commit-scoped.sh should accept and emit session attribution so scripted commits match hand-written ones; (b) attribution belongs only on interactive commits and agent commits should carry none; (c) the divergence is acceptable and should be documented rather than fixed. Do not pre-commit to an option.

CONSIDER ALSO. Whether the raw-git commit is itself the defect worth addressing -- rules/git-workflow.md and the scoped-commit boundary lint already push all task committing through git-commit-scoped.sh, so a hand-written agent commit may indicate a gap in that enforcement independent of attribution.

ACCEPTANCE: a recorded decision with rationale; whichever option is chosen is reflected in git-commit-scoped.sh, the git-workflow rule, or both; a task run end to end afterwards produces commits with a single consistent attribution shape.

---

### 185. Retarget stage citations to move vocabulary
- **Status**: [NOT STARTED]
- **Task Type**: markdown
- **Topic**: core-agent-system
- **Dependencies**: None

**Description**: Retarget the remaining historical "Stage N" and "Stage MT-N" citations to the four-move loop vocabulary.

CONTEXT. skill-orchestrate/SKILL.md was rewritten from a two-engine, Stage-numbered state machine (single-task Stages 0-8; multi-task Stages MT-1 through MT-5) into a single four-move loop whose sections are named Move 1 through Move 4. Roughly 120 citations of the old vocabulary remain across 9 context/ and docs/ files. They now point at section names that no longer exist in the file they cite.

KNOWN SITES (from the rewrite's own survey; re-verify by grep rather than trusting this list):
  context/patterns/batch-orchestration-guardrails.md  -- 34 occurrences, the largest single concentration
  docs/architecture/handoff-schema.md
  docs/architecture/orchestrate-cycle-postflight.md
  docs/architecture/batch-admit-schema.md
  context/patterns/orchestrate-batch-results-template.md
  plus four further context/ and docs/ files

WHY IT WAS DEFERRED. The rewrite judged a ~120-citation mechanical sweep disproportionate to its core scope and recorded it as a follow-up rather than attempting it inline.

SCOPE AND CARE. This is a mechanical retarget, not a rewrite of the surrounding prose. Two hazards to respect: (1) some citations are historical-by-intent -- they describe what a now-deleted engine did, in a decision record or incident narrative, and must keep naming the old stage rather than being rewritten to a Move that never had that behavior; distinguish "cites a live section" from "narrates history" before editing. (2) Edit the source store under agent-system/extensions/** and never the deployed .claude/ tree (see rules/source-store-deploy-boundary.md).

ACCEPTANCE: every citation that refers to a LIVE section names the correct Move; every historical citation is either left intact or explicitly marked as historical; a grep for "Stage MT-" and for single-task "Stage [0-8]" returns only intentional historical references; deploy and the full gate run stay green.

---

### 184. Decide lean skeleton plan completion routing
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None

**Description**: Decide the disposition of the Lean/formal skeleton-plan completion routing lost with the single-task engine.

CONTEXT. The deleted single-task /orchestrate engine carried a skeleton-exhaustion completion branch: when no incomplete phase heading remained AND the last handoff declared skeleton=true, it derived a follow-up task list from the handoff's sorry_inventory[].follow_up_task entries, routed the task to completion via update-task-status.sh postflight with the pr_ready target and --allow-pr-ready, and reported the pending follow-ups. The surviving batch engine has no equivalent branch.

WHY THIS ONE NEEDS A DECISION AND HAS NOT HAD ONE. The rewrite recorded TWO capability losses. The loop-guard staleness detector got an explicit recommended follow-up. This one was recorded as a permanent loss with NO follow-up named at all -- it is the only deviation in that summary left without a next step. Lean and formal work is live in this repository, so silent acceptance should be a deliberate choice rather than an oversight.

SCOPE. Determine whether strategic-sorry skeleton plans can still reach a correct terminal status under the batch engine, and if not, what should happen. Evaluate at least: (a) port the skeleton-exhaustion branch into orchestrate-cycle-plan.sh or orchestrate-cycle-postflight.sh; (b) require skeleton plans to close through a different, already-supported path; (c) accept the loss explicitly and document how a skeleton plan is expected to terminate now. Do not pre-commit to an option.

EVIDENCE. The assertions covering this mechanism (.skeleton / last_skeleton and .sorry_inventory / follow_up_tasks) were removed from scripts/tests/test-handoff-reader-parity.sh. Recorded under "Plan Deviations" in specs/088_mode_gate_skill_orchestrate_multi_task_section/summaries/01_four-move-loop-rewrite-summary.md. Related policy: the strategic-sorry skeleton allowance in context/contracts/recovery.md.

ACCEPTANCE: a recorded decision with rationale; if a gap is confirmed, either a working path to terminal status for skeleton plans with test coverage, or documentation naming the expected terminus.

---

### 183. Decide loop guard staleness detector disposition
- **Status**: [ABANDONED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 182, Task 213, Task 214

**Description**: Decide whether to port the hard-mode loop-guard operational-staleness detector into orchestrate-cycle-plan.sh, or record its removal as accepted.

CONTEXT. The single-task /orchestrate engine (skill-orchestrate/SKILL.md Stages 0-8) was deleted when SKILL.md was rewritten as the four-move loop. That engine carried a 3-signal operational-staleness detector for .orchestrator-loop-guard, gated on hard mode only. It has NO equivalent in the surviving batch engine (orchestrate-cycle-plan.sh), so /orchestrate --hard no longer detects a stale-but-syntactically-valid loop guard at all.

WHAT WAS LOST (the detector's own contract, for reference when deciding):
  Signal 1 -- schema/version drift: guard .max_cycles differs from the live MAX_CYCLES.
  Signal 2 -- plan-lineage drift: guard .plan_version differs from the newest plans/*.md basename. Skipped when either side is empty or "none" (an absent plans/ directory is never itself evidence of staleness).
  Signal 3 -- mtime-age backstop: guard older than ORCHESTRATOR_LOOP_GUARD_STALE_DAYS (default 7). An unreadable mtime (stat returns 0) is treated as NOT stale.
  Any one signal tripping was sufficient. On trip: archive the guard aside to .stale-loop-guard-<ts>.json (never delete), co-archive .orchestrator-churn-state.json under the same timestamp if present, then fall through to fresh init at cycle 0.

THIS IS A DECISION TASK, NOT A PORT TASK. The prior engine's own comments recorded that whether BASE mode should gain the detector unconditionally was already an open, undecided question. Deleting the hard-mode copy did not settle that question -- it removed the only implementation. Evaluate at least: (a) port into orchestrate-cycle-plan.sh for all effort modes; (b) port hard-mode-only, preserving the old asymmetry; (c) accept the loss and sweep the retired test's remaining references. Do not pre-commit to an option.

EVIDENCE. The retired test scripts/tests/test-loop-guard-staleness.sh was removed from git tracking in commit 2d09265cc. The capability loss is recorded under "Plan Deviations" and "Follow-ups" in specs/088_mode_gate_skill_orchestrate_multi_task_section/summaries/01_four-move-loop-rewrite-summary.md.

ACCEPTANCE: a recorded decision with rationale; if ported, the detector works under the batch engine and has test coverage; if accepted as lost, the removal is documented where a future reader will find it rather than surviving only as summary prose.

ABANDONED (2026-09-14): superseded by "Reset the /orchestrate cycle bound on each run and admit forced phases by artifact, not status". Once cycle_count is no longer carried between runs, a stale guard file can no longer be trusted for budgeting, so the staleness detector has nothing to protect. That task records this outcome in context/standards/orchestrator-runtime-files.md.

---

### 182. Add a durable redeploy ledger with content-hash and recency skip to the checkpoint
- **Effort**: 4 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 181, Task 193, Task 213, Task 214

**Description**: Give the /orchestrate inter-cycle redeploy checkpoint a durable run ledger so it stops re-running a full redeploy that just happened.

OBSERVED COST. In session sess_1788827855_dfff06 the checkpoint consumed roughly 10 minutes of wall clock in a single cycle and ended by deferring BOTH tasks in the batch (deferred_deploy_checkpoint: [155,156]) -- leaving one task stranded at [IMPLEMENTING] despite 6/6 plan phases closed and committed, and the other never dispatched at all. There is no durable record of when a redeploy last ran, against which source-store content, or with what verify outcome, so the checkpoint cannot skip a redeploy that just succeeded.

=== CORRECTION TO THE ORIGINAL DIAGNOSIS: deployed_critical_paths IS MIS-SCOPED, NOT DEAD ===

The field was initially suspected of never being written, which would make it a dead field. That is NOT what the code does. Verified:
  - It IS written, on the two SUCCESS branches of the checkpoint: the verify-clean branch and the pre-existing-findings-proceed branch (branch (c)). Both do .deployed_critical_paths = ((.deployed_critical_paths + $mp) | unique).
  - It is NEVER written on the DEFER branch. The observed empty [] is therefore fully explained by the run having deferred -- the field did exactly what it was coded to do.
  - Decisively, it lives in the mt_state_file, whose filename is session-scoped (specs/.orchestrator-multi-state-sess_<id>.json). It resets on every /orchestrate invocation.

CONCLUSION. deployed_critical_paths is a WITHIN-INVOCATION re-deploy suppressor, working as designed for that narrower purpose. It is not, and cannot be, the cross-invocation ledger described here. This task must therefore introduce genuinely NEW durable state rather than attempt to repair that field. Decide during planning whether the existing field is subsumed by the new ledger or retained alongside it for its narrower within-invocation role; do not silently redefine its semantics in place.

=== WHAT TO BUILD ===

Persist a last-deploy record spanning invocations: timestamp, source-store content hash, and verify outcome. Skip the redeploy when the source-store hash is unchanged since the recorded successful deploy, or when the record is recent enough -- i.e. run the redeploy when it is genuinely needed or when it has been a while, not on every qualifying cycle.

The record must capture the verify OUTCOME, whose definition is settled by the prerequisite gate-depth task. That is the primary reason for the dependency ordering: writing a ledger against outcome semantics that the next task redefines would require rewriting it.

=== NAMED ACCEPTANCE CRITERION: THE SELF-MODIFYING-TASK CLASS ===

A task whose own file_scope IS the orchestrator source store necessarily stales the deploy that its own completion gate then checks. This is exactly what happened in the observed session: the batch edited agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh -- the very script running the checkpoint that then blocked it. This class of task hits the checkpoint EVERY SINGLE TIME by construction, so it must be designed for explicitly, not treated as an edge case.

CRITICAL CONSEQUENCE FOR THE DESIGN: a content-hash skip does NOT help this class, because the hash always changes by construction -- the task's own edits are what change it. Only a recency window, or a 'the redeploy that just landed was mine' ledger check that recognizes the last successful deploy already incorporated this batch's changes, addresses it. The content-hash skip and the recency/attribution skip are therefore NOT redundant alternatives; the hash skip covers the ordinary case and the recency/attribution skip covers the self-modifying case. Shipping only the hash skip leaves the observed failure mode fully intact.

This must be a named acceptance criterion with test coverage: a simulated self-modifying task (file_scope overlapping the orchestrator's own scripts) must not incur a redundant full redeploy on every cycle.

=== SCOPE ===

Extend scripts/tests/test-orchestrate-cycle-plan.sh with coverage for: skip on unchanged hash; skip within the recency window; NO skip when the source store genuinely changed outside the window; and the self-modifying-task case above. Update the 'The Inter-Cycle Redeploy Checkpoint' subsection of context/patterns/batch-orchestration-guardrails.md, which currently defers this work explicitly -- it names the deployed_critical_paths idempotence backing store as 'its own task'. That note is closed by this task and must be replaced with the real contract, including the corrected description of the existing field's within-invocation scope.

DO NOT SIMPLY DISABLE THE GATE. Skipping must be justified by evidence in the ledger that the deploy is current. A skip on no evidence is a disabled gate wearing a ledger's clothes.

SOURCE STORE. All edits land under agent-system/extensions/core/** at the GLOBAL root /home/benjamin/.config/nvim. Never edit .claude/**, which is a regenerated deploy artifact -- see rules/source-store-deploy-boundary.md.

DEPENDENCY. Depends on the gate-depth task both by file footprint (both modify orchestrate-cycle-plan.sh) and semantically (the ledger stores a verify outcome whose definition that task changes).

---

### 177. Add a dependency-tracing recipe to the lean4 extension context
- **Effort**: 2-3 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: lean-extension
- **Dependencies**: None

**Description**: Add a dependency-tracing recipe to the lean4 extension context: how to mechanically answer "does X depend on Y?" in a Lean 4 environment, and why `#print axioms` cannot answer it.

WHY THIS EXISTS. A trace task in ~/Projects/BimodalLogic had to answer whether a decision procedure depended on a set of theorems whose hypotheses had been refuted. The task's own description demanded a MECHANICAL trace ("a prose argument that it probably doesn't is not the deliverable"), and no recipe existed -- the probes were invented from scratch. They worked, are re-runnable, and generalize. The finished probes and their verbatim output live at `~/Projects/BimodalLogic/specs/549_trace_decide_dependency_on_vacuous_run_theorems/probes/` (`DepTrace.lean`, `DepTrace2.lean`, `RevDep.lean`, `Widen.lean`, `Ax.lean`, `Exists.lean`, plus `probe-evidence.md`). Harvest them from there; do not re-derive.

THE LOAD-BEARING CAVEAT, and the reason this is worth writing down at all. `#print axioms` is NOT a dependency tracer. In the observed case the decision procedure, its soundness theorem, AND the vacuous theorem under suspicion all reported the same `[propext, Classical.choice, Quot.sound]`. An axiom check answers "is this sound?", never "what does this rest on?" -- yet it is the first probe most people reach for, and it would have returned a confidently useless answer. State this explicitly and early in the recipe.

FOUR PROBE SHAPES TO DOCUMENT AS REUSABLE TEMPLATES:
1. Forward transitive closure over the environment -- `Expr.getUsedConstants` over both type and value, iterated to a fixed point from a named entry point, then intersected with a suspect set. This is the primary tool.
2. The module-index variant -- resolve which module each reached constant came from, and count the hits attributable to a target module. Answers "how much of module M does X touch?" in one number.
3. Whole-environment reverse-dependency scan -- iterate every declaration in the environment and report those whose closure contains a suspect. Answers "what would break if I deleted this?", which is the question a retirement decision actually needs.
4. Import-closure check -- whether the target's module is even reachable via transitive imports. Distinguishes "unused" from "unavailable", a meaningfully stronger result.

ALSO WORTH RECORDING: run probes with `lake env lean` against existing oleans rather than a full `lake build` -- the observed trace needed no rebuild at all. And note the failure mode that bit the source task: line numbers cited in a research report go stale quickly in a large file, so probes should resolve declarations by name.

SCOPE. Create `agent-system/extensions/lean/context/project/lean4/patterns/dependency-tracing.md` in the SOURCE STORE (never `.claude/**`, which is a regenerated deploy artifact -- see rules/source-store-deploy-boundary.md). Wire it into the lean4 context index the way sibling pattern files are wired; follow the existing single-statement-plus-pointer convention rather than restating the model at the pointer site.

PRIORITY: low, and genuinely optional. This is a recipe harvested from one successful use, not a defect fix -- nothing is broken without it. Its value is that the next such trace does not start from zero, and that the `#print axioms` trap is documented before someone falls into it.

ACCEPTANCE. The four probe shapes are reproduced as templates a reader can adapt without access to the originating repository. The `#print axioms` caveat is stated explicitly, with the concrete observation that three declarations at different dependency depths all reported identical axioms.

---

### 175. Enforce waiter teardown in the agent contracts that spawn build waiters
- **Effort**: 1-2 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 172

**Description**: Wire the already-written teardown rule into the specific contracts whose agents actually spawn build waiters, so the leak is prevented at its source rather than only cleaned up afterward. Investigation finding: the governing rule already exists and was violated. agent-system/extensions/core/context/patterns/dispatch-report-not-termination.md carries a normative section titled 'Tear Down Watchers/Monitors Before Reporting' stating that every agent which arms a watcher/monitor process during its own dispatch MUST tear it down before reporting a terminal result. The 22 leaked waiters are a direct violation of that existing rule -- so this is an enforcement-and-wiring problem, not a missing-prose problem. That file's own 'Where This Is Referenced' section lists exactly three fix sites today (skill-orchestrate's Stage 5 staleness-gate comment block, context/contracts/territory.md's Territory Declaration Template, and context/standards/orchestrator-runtime-files.md), none of which covers a build waiter armed by a dispatched implementation agent. Scope: (1) extend the teardown rule to name the supersession case explicitly -- a waiter must be torn down not only before REPORTING but before its watched build is cancelled or superseded, which is the transition that actually orphaned the observed loops -- and add the new fix sites to its 'Where This Is Referenced' list; (2) add the corresponding one-line pointer obligations to the agent contracts that dispatch guarded builds, i.e. the lean implementation agents (agent-system/extensions/lean/agents/lean-implementation-agent.md and lean-implementation-hard-agent.md), pointing at the bounded-waiter anchor and the teardown rule rather than restating either. Follow the established single-statement-plus-pointer convention: the model lives in one file, fix sites point at it. Do not duplicate the waiter contract text into the agent files.

---

### 174. Add a self-excluding orphaned-build-waiter reaper pass to /refresh
- **Effort**: 3-4 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 172

**Description**: Give the system a way to clean up waiters that already leaked, correct by construction against the self-match bug observed while cleaning up manually. Second observed defect, same bug class as the primary one: an ad-hoc cleanup command of the form `pgrep -f 'until grep' | ... kill` matched ITS OWN command line -- the command string contained the very pattern it was searching for -- and killed its own shell (exit 144). This happened twice. Any reaper for this must exclude itself and its own process group, or it kills the reaper. Investigation finding: agent-system/extensions/core/scripts/claude-refresh.sh already solves exactly this, and the fix should reuse its architecture rather than invent a new one. It takes a single atomic `ps -eo` snapshot per invocation (take_snapshot()) with every exclusion evaluated against that frozen snapshot, and it already implements what its own header calls zero-query self-exclusion -- `if [ "$pid" = "$$" ] || [ "$ppid" = "$$" ]; then` skip -- applied in both the Claude-process pass and the Lean-LSP pass. That idiom is known at parse time, needs no second query, and is race-free; it is the correct-by-construction answer to the pgrep self-match bug. Scope: add a new pass that identifies orphaned build-waiter poll loops (matching the process signature settled by the bounded-waiter contract) whose watched log has a dead or absent writer, reusing the existing snapshot and the existing self-exclusion, and extend the exclusion to the reaper's own process group as well as its pid/ppid. Decide and document the pass's gate class explicitly -- the existing passes are split between interactive-confirm (rows 1-2), report-only-always (rows 3-4), and age-threshold-only (rows 5-8); an age-threshold-only gate matching the stale-lock passes is the closest existing precedent, since these waiters are 0% CPU and provably unreapable rather than merely idle. Then update the pass inventory in BOTH places that must agree row-for-row on gate and destructiveness: agent-system/extensions/core/commands/refresh.md ('What It Cleans' table plus a new owning subsection) and agent-system/extensions/core/skills/skill-refresh/SKILL.md (its Pass Inventory table). State whether the new pass is reached by the hourly claude-refresh.timer cadence -- only the four passes internal to claude-refresh.sh currently are.

---

### 173. Guarantee lake-build-guard.sh writes a terminal record on every exit path
- **Effort**: 3-4 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 172

**Description**: Make the guard-side analogue of the poll-loop leak impossible, so that any correctly-written waiter can always drain. Investigation finding: lake-build-guard.sh does NOT write the observed `EXIT=` sentinel at all -- that was agent-side. What it does write is a structured record at <root>/.lake/build-guard.result via two functions: write_inflight_record() emits `state=in_flight`, `holder_pid=$$`, `start_epoch=`, empty `exit_status=`, and `log_path=`; finalize_record() rewrites it as `state=complete` with the real `exit_status=`. The defect: finalize_record() is reached only on the normal return path out of run_as_holder(). There is no trap, so if the holder shell is killed, cancelled, or superseded (exactly the lock-contention scenario that triggered the observed leak), the record is left permanently at `state=in_flight` with a `holder_pid` that names a dead process. A waiter consuming that record has no terminal transition to observe -- the same unbounded-termination defect, one layer down. Fix directions to evaluate (not prescriptive): install an EXIT/INT/TERM trap in run_as_holder() that finalizes the record with a distinguishable terminal state (e.g. state=aborted with a reserved exit_status) so existing waiters drain rather than hang; confirm holder_pid is documented as the liveness handle that the bounded-waiter contract's `kill -0` check reads, since it is already written and is the natural handle; and make sure the waiter/sharing path in cmd_build treats an in_flight record whose holder_pid is dead as stale rather than as a live build to wait behind. Preserve the guard's existing documented contracts: the subcommand shape (status/preflight/build), the reserved 77 usage band, exit 75 on lock-wait timeout, the five-condition staleness policy on the sharing decision, and the `--timeout` semantics (a lock-WAIT budget, never a build-duration limit). Extend agent-system/extensions/core/scripts/tests/test-lake-build-guard.sh with coverage for the killed-holder case: a holder killed mid-build must leave a terminal record, and a waiter must not block on a record whose holder_pid is dead. Land the fix in the nvim source store only.

---

### 172. Define a canonical bounded-wait idiom for detached builds
- **Effort**: 2-3 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None

**Description**: Close the taught-pattern gap that produced 22 unreapable poll loops during a multi-task /orchestrate run in ~/Projects/BimodalLogic. Investigation finding: the observed waiter shape `until grep -q "^EXIT=" <log>; do sleep ...; done` appears NOWHERE in this source store -- it is agent-improvised. Two forces create it: (a) the harness's own Bash guidance blocks foreground `sleep` and points agents at a Monitor until-loop to wait on a condition, and (b) extensions/lean/context/project/lean4/operations/long-builds.md mandates `Bash(run_in_background: true)` detachment for every `lake build` but offers no sanctioned way to BLOCK on a detached build -- its only stated discipline is 'wait for the harness completion notification', with four Passive progress checks explicitly labeled liveness-only. An agent that needs to block therefore invents an unbounded sentinel poll. The defect class: a poll loop whose exit condition is a sentinel written by a process that may die first has no bounded termination. In the observed run the agent-side wrapper was of the form `cmd > b2b.log 2>&1; echo "EXIT=$?" >> b2b.log`; when the guarded build was cancelled/superseded by lock contention with a concurrent session, the `echo` never ran, so the sentinel became unwritable by construction. 22 loops watched the same b2b.log (2 more watched b9b.log), aged 24-55 minutes, at 0% CPU -- the cost is background-shell-slot exhaustion and operator confusion, not throughput. Deliverable: a new core context pattern file (suggested agent-system/extensions/core/context/patterns/bounded-build-waiter.md) stating the defect class once, canonically, and defining a safe waiter with three mandatory properties -- (1) a hard timeout so the waiter cannot outlive its writer, (2) a writer-liveness check (`kill -0 <pid>`) rather than sentinel-polling alone, so a dead writer terminates the wait immediately, and (3) one-waiter-per-log enforcement, so a superseded build's waiter is reaped before a replacement waiter is spawned. Wire the new anchor into long-builds.md with a one-line pointer under a new section covering the blocking case (do NOT restate the model there -- follow the existing single-statement-plus-pointer convention used by context/patterns/dispatch-report-not-termination.md). This task is foundational: it settles the waiter/writer contract that the guard-side, reaper-side, and agent-contract tasks all consume. Do not modify lake-build-guard.sh, claude-refresh.sh, or any agent file here -- those are separate dependent tasks.

---

### 170. Audit and isolate shell test suites from ambient host state (memory and timing axes), and record the convention
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 151, Task 169, Task 206, Task 215

**Description**: Audit all shell test suites in the source store for assertions whose outcome depends on ambient host state, isolate each at the script-under-test's own documented env seams (or, where no seam is possible, by a technique appropriate to the axis), and record the isolation convention in `context/standards/shell-script-testing.md` so future suites inherit it by default.

=== TWO CONFIRMED INSTANCES -- THE DEFECT CLASS IS NOT A SINGLE-SUITE ANOMALY ===

Both were observed live. They sit on DIFFERENT axes and need DIFFERENT remedies.

--- INSTANCE A (memory axis) -- `test-lake-build-guard.sh`, cases 1, 3, 11 ---

Failed because `lake-build-guard.sh` read the REAL `/proc/pressure/memory` and `/proc/meminfo`,
and the host was swapping at 57% of SwapTotal -- over the guard's own
`SWAP_USED_RATIO_THRESHOLD=50`. Cases 1 and 3 assert byte-identical transparency on the guard's
clean path; case 11 asserts preflight exits 0 when the PSI path is unavailable. All three pass on
an idle machine and fail on a busy one -- and a busy machine is exactly what a multi-task
`/orchestrate` batch produces.

ALREADY FIXED -- DO NOT REDO. Commit `878043472` isolates this suite suite-wide by redirecting
`LAKE_BUILD_GUARD_PSI_PATH` and `LAKE_BUILD_GUARD_MEMINFO_PATH` to clean fixture files in the
suite's own mktemp workdir, via the script's documented env seams. Verified 27/27 pass and
verified non-vacuous. This suite is the EXEMPLAR the audit generalizes from, not work to repeat.
The separate positive-direction case for it is tracked as its own prerequisite task (this task
depends on it) -- do not duplicate that either.

--- INSTANCE B (timing axis) -- `test-four-tier-conflict.sh`, case 6 "budget-bound" ---

CONFIRMED AFFECTED, NOT YET FIXED. This one is the task's primary unsolved exemplar.

Evidence, all observed live:
  - Pre-fix full `run-all.sh`: this suite PASSED (only `test-lake-build-guard.sh` failed).
  - Post-fix full `run-all.sh`: this suite FAILED with
      `6: budget-bound -- rc=1 elapsed_ms=2989 budget_ms=1000`
  - Immediate ISOLATED re-run of the same suite: PASSED, with
      `6: budget-bound -- exhaustion elapsed 1752ms within [1000ms, 2000ms)`

Commit `878043472` touched exactly one file (`test-lake-build-guard.sh`), so it cannot have
caused this. The discriminating fact is the isolated re-run passing. The assertion at
`test-four-tier-conflict.sh:294` is a wall-clock window:

    [ "$rc6" -eq 1 ] && [ "$elapsed6_ms" -ge "$BUDGET_MS" ] && [ "$elapsed6_ms" -lt $(( BUDGET_MS * 2 )) ]

with `BUDGET_MS=1000`. The window `[1000ms, 2000ms)` holds on an unloaded machine and breaks under
concurrent load. Same "outcome determined by ambient host state" shape as instance A, on the
timing axis instead of the memory axis.

ADJACENT, SAME SUITE, LIKELY SAME DEFECT: case 5 (`test-four-tier-conflict.sh:271`) asserts
`elapsed5_ms -lt 500` as a proxy for "the retry loop was never entered". That is the same
wall-clock-as-proxy shape and is expected to flake under load for the same reason; triage it
alongside case 6 rather than treating case 6 as isolated. Case 1 also reports elapsed wall
clock -- check whether it merely reports or actually asserts on it.

--- WHAT THE SECOND INSTANCE CHANGES ABOUT SCOPING ---

1. The audit premise is confirmed empirically, not speculative.
2. The timing axis is genuinely represented, so the audit MUST cover wall-clock windows and
   elapsed-time proxies, not only `/proc` reads.
3. The shell-test-suite gate is currently FLAKY, not simply red: `run-all.sh` has now failed
   twice in a row for two DIFFERENT single-suite reasons. Acceptance is set accordingly below.

=== BLAST RADIUS (why this warrants a dedicated audit, not a one-off patch) ===

A single suite failure fails `verify-deploy.sh`'s shell-test-suite gate (1 of 30 checks), which
fails `deploy-headless.sh`, which makes `skill-orchestrate`'s inter-cycle redeploy checkpoint
defer an ENTIRE orchestrate batch. One host-coupled assertion in one suite stalls unrelated work.
The defect class is load-bearing on throughput, not merely on test hygiene. A flaky gate is worse
than a red one: it defers batches nondeterministically and trains readers to re-run rather than
diagnose.

=== THE DEFECT CLASS TO HUNT ===

Any assertion whose outcome depends on ambient host state:
  - memory (`/proc/meminfo`, `/proc/pressure/memory`, swap usage, `free`)          [instance A]
  - wall-clock timing (elapsed-time windows, `sleep`-dependent ordering,
    `date +%s` / `%N` deltas, `SECONDS`, `timeout` values tuned to a fast machine)  [instance B]
  - load / CPU count (`/proc/loadavg`, `nproc`, `getconf`, `uptime`)
  - network reachability (`curl`, `wget`, `ping`, DNS, any live API)
  - free disk (`df`)
  - the process table (`pgrep`, `ps`, PID reuse, pre-existing processes matching a pattern)
  - anything else read from the live host rather than from a fixture

=== SURVEY ALREADY PERFORMED (starting point, NOT the answer) ===

72 files match `test*.sh` under `agent-system/extensions/**`. A keyword grep over the signals
above flagged 25. Ordered by raw hit count:

  13  core/scripts/test-four-tier-conflict.sh               (INSTANCE B -- confirmed affected)
  12  core/scripts/tests/test-lake-build-guard.sh           (INSTANCE A -- already isolated)
   6  literature/scripts/test-lit-pipeline.sh
   6  core/scripts/tests/test-validate-state.sh
   6  core/scripts/tests/test-claude-refresh-matcher.sh
   4  core/scripts/test-state-write-concurrency.sh
   3  literature/scripts/tests/test-literature-convert.sh
   3  lean/scripts/tests/test-lean-comparator-run.sh
   3  core/scripts/tests/test-loop-guard-budget-override.sh
   2  literature/scripts/tests/test-literature-discover-tier3.sh
   2  core/scripts/tests/test-subagent-postflight-marker.sh
   2  core/scripts/tests/test-lint-branch-gated-sections.sh
   2  core/scripts/tests/test-handoff-dispatch-identity.sh
   2  core/scripts/test-state-write-regen-timing.sh
   2  core/scripts/test-session-registry.sh
   2  core/scripts/test-conflict-predicate.sh
   1  each: core/scripts/test-task-lock-reap.sh, core/scripts/test-session-runtime-files.sh,
          core/scripts/tests/{test-validate-return-meta,test-status-vocabulary,
          test-skill-base-lifecycle,test-phase-heartbeat,test-phase-heading-patterns,
          test-guard-destructive-git,test-common-lib}.sh

Both confirmed instances rank first and second, which is mild evidence the ranking carries signal
-- but RAW HIT COUNT IS NOT SEVERITY, and this list is neither sound nor complete:
  - FALSE POSITIVES ARE EXPECTED. A `sleep` inside a concurrency suite that deliberately
    exercises lock contention may be legitimate; `pgrep` inside a suite whose subject IS process
    matching (`test-claude-refresh-matcher.sh`, `test-task-lock-reap.sh`) may be exercising the
    real behavior under test. Triage each hit; do not mechanically "fix" every match.
  - FALSE NEGATIVES ARE LIKELY. The grep cannot see host coupling entering through a library the
    suite sources, through the script under test rather than the suite itself (exactly how
    instance A arrived), or through a helper that shells out. Read the scripts under test, not
    only the suites. Suites absent from this list are NOT thereby cleared.
  - Names containing `timing`, `concurrency`, `heartbeat`, `budget`, `reap`, or `staleness` are
    prior-suspect on the timing axis regardless of hit count.

=== REQUIRED APPROACH -- SEAM-FIRST, BUT DO NOT PRESUME THE SEAM REMEDY TRANSFERS ===

For state READ FROM A FILE OR COMMAND (the memory/`proc`/disk/network/process axes), instance A's
remedy is the model:
  1. Identify the script-under-test's OWN documented env seam (`lake-build-guard.sh` provides
     `LAKE_BUILD_GUARD_PSI_PATH` / `LAKE_BUILD_GUARD_MEMINFO_PATH`). Prefer an existing seam.
  2. If none exists, adding one to the script under test is in scope -- but it must be a genuine,
     documented override point with a real-host default, NEVER a test-only branch or an
     "if running under test" conditional.
  3. Point the seam at a fixture authored into the suite's own mktemp workdir, per the existing
     fixture convention in `context/standards/shell-script-testing.md` (heredoc-authored, fresh
     per case where staleness would otherwise mask behavior, never resolved against the live tree).

For WALL-CLOCK TIMING (instance B), THE SEAM REMEDY MAY NOT APPLY AT ALL. There may be nothing to
redirect: the quantity is elapsed real time, not a readable input. Do not force the memory-case
technique onto it. Evaluate at least these, per assertion, and justify the choice:
  - Inject the clock -- give the script under test a seam for its time source so the suite can
    drive elapsed time deterministically. Strongest option where feasible.
  - Assert ORDERING or CAUSALITY instead of elapsed wall clock -- e.g. for case 6, that the retry
    loop terminated on budget exhaustion rather than on a lock acquisition, and for case 5, that
    the retry loop was never entered at all. Both are the property the elapsed-time window is
    only a PROXY for; asserting the property directly removes the host coupling without weakening
    anything. Prefer this where the underlying property is observable (a counter, a log line, a
    return path).
  - Widen the window to generous-but-still-bounded ONLY as a last resort, and only when the
    widened bound still falsifies the failure mode the assertion exists to catch (for case 6:
    "nowhere near a minutes-scale wait"). A bound that no longer discriminates is a deleted test.
    This option requires explicit justification in the summary naming what it still catches.

NON-VACUOUSNESS CHECK PER ISOLATED SUITE, MANDATORY on every axis. After isolating, demonstrate
the logic under test is still genuinely exercised -- typically by driving the opposite direction
with a fixture or condition that SHOULD trip the behavior and confirming it does. An isolation
that makes a suite assert nothing is worse than the host coupling it replaced. Record each check.

=== CONSTRAINTS ===

- All edits target `agent-system/extensions/**` ONLY. Never hand-author anything under
  `.claude/**`; that tree is a disposable deploy artifact regenerated from source
  (see `.claude/rules/source-store-deploy-boundary.md`).
- NEVER weaken, raise, or bypass a guard threshold, loosen an assertion into vacuity, or mark a
  case skipped to make a suite pass. Isolate the INPUT; do not relax the ASSERTION. The
  last-resort window-widening above is a bounded, justified exception on the timing axis only --
  it is NOT licence to relax thresholds generally, and never applies to a guard's own constants.
- Where a suite legitimately depends on real host state and cannot be isolated, use the loud-skip
  discipline already documented in `shell-script-testing.md` rather than a silent skip, and
  justify the exemption in the summary.

=== DELIVERABLE: THE CONVENTION ===

Extend `agent-system/extensions/core/context/standards/shell-script-testing.md` (127 lines;
existing sections: Location rule, Helper-naming convention, Fixture convention including "Never
resolve a path against the live tree", Loud-skip discipline, Mutation checks for regex-shaped
fixes, Registration, Related). Add an ambient-host-state isolation section that:
  - names the defect class and why it is load-bearing (the deploy-gate blast radius above),
    citing both confirmed instances as the worked examples -- one per axis;
  - states the seam-first rule for readable-input axes, and the bar for adding a new seam;
  - states separately that the timing axis needs a different technique, with the
    inject-clock / assert-causality / bounded-widening ladder and the rule that elapsed wall
    clock must not be used as a proxy for a property that is directly observable;
  - requires the per-suite non-vacuousness check;
  - forbids threshold relaxation as a remedy;
  - cross-references the existing Fixture convention and Loud-skip discipline sections rather
    than restating them.
Place it so it composes with, not duplicates, what is already there.

=== ACCEPTANCE ===

- Every one of the 72 suites has been triaged, with a recorded verdict: affected-and-isolated,
  false-positive-with-reason, or legitimately-host-dependent-and-loud-skipped.
- Instance B (`test-four-tier-conflict.sh` cases 6 and 5) is fixed, with the chosen technique
  justified against the ladder above.
- Each isolated suite carries a demonstrated non-vacuousness check.
- REPEATED-RUN ACCEPTANCE, NOT A SINGLE GREEN RUN. "run-all.sh passes once" is too weak: the gate
  has already failed twice consecutively for two different single-suite reasons, and instance B
  passes in isolation while failing in a full run. Require instead:
    (a) `run-all.sh` green across multiple consecutive runs (at least 3);
    (b) at least one of those runs under DELIBERATE concurrent load -- both memory pressure above
        the lake guard's own threshold and CPU/IO contention sufficient to have reproduced the
        case 6 failure, verified by first confirming the load reproduces the ORIGINAL failures on
        a pre-fix checkout;
    (c) full-run and isolated-run results agreeing for every suite -- a suite that passes alone
        but fails in the batch is still affected.
  Record the load-generation method used so the check is reproducible.

---

### 168. Correct opencode mcp scoping claim
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: opencode
- **Dependencies**: None

**Description**: Correct the disproven project-scoped MCP claim in the OpenCode doc tree.

An earlier task verified against Claude Code's actual behavior that there is NO categorical subagent barrier to project-scoped MCP servers (.mcp.json) -- the real constraint is one-time workspace trust, not per-call access -- and landed the corrected wording in agent-system/extensions/core/docs/docs-README.md (see its "MCP Configuration" section). Two tracked, live files in the parallel OpenCode tree still carry the disproven claim verbatim and were explicitly scoped OUT of that task under its canonical-source constraint:
  .opencode/extensions/core/docs/README.md:227
  .opencode/docs/README.md:227
The two are currently byte-identical. Establish which is source and which is deployed BEFORE editing, and edit the source, not the deploy.

STALE TEXT (both files):
  "Custom subagents cannot access project-scoped MCP servers (`.mcp.json`). For subagent access, configure servers in user scope (`~/.claude.json`)."

WHY THIS MATTERS. The earlier task's research documented that this specific false claim had already propagated into research findings, implementation plans, and user-facing handoffs, each concluding that subagents were barred from project scope. It is a decision-corrupting premise with a demonstrated track record, not a cosmetic doc nit.

SCOPE. Correct the claim and align it with the corrected core wording. context/patterns/mcp-server-ownership.md already carries the accurate framing and needs NO edits -- consult it, do not modify it. Do NOT re-derive or re-litigate the underlying MCP behavior; it is already verified, and this is a propagation fix, not a research question. Keep the correction proportionate to the one-line defect: do not restructure the surrounding "MCP Configuration" section.

ACCEPTANCE.
  - Repo-wide grep for "cannot access project-scoped MCP" returns zero hits outside historical specs/ artifacts.
  - Both OpenCode files carry wording consistent with the corrected core version.
  - If the two files are in a source/deploy relationship, the deployed copy is REGENERATED rather than hand-edited.

---

### 167. Make vimtex continuous-build safety always-in-effect via the latex extension rule
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: None

**Description**: Make continuous-build (vimtex `latexmk -pvc`) safety guidance always-in-effect for every agent and command, not only latex-typed dispatches, by extending the latex extension's EXISTING deployed rule file rather than adding a new mechanism.

=== MOTIVATING INCIDENT (2026-09-07, PossibleWorlds paper repo, JPL/ subdirectory) ===

Command-line `latexmk -pdf` runs issued during an ordinary editing conversation (NOT a latex-typed task) raced a running vimtex `latexmk -pvc` watcher on the same shared build/ directory.

Symptoms: empty .aux file; deleted PDF; spurious "Build failed" entries appended to build/compile.log by the .latexmkrc $failure_cmd; bibtex reporting "I found no \citation commands"; latexmk exit code 12 despite ZERO LaTeX errors in the log. The exit-12-with-clean-log signature was misread as a LaTeX error, prompting repeated rebuilds that compounded the race.

Verified during diagnosis:
  - `pgrep -af 'latexmk'` showed the vimtex process with flags:
      -pvc -pvctimeout- -view=none -outdir=build -emulate-aux-dir -auxdir=build
  - An isolated build succeeded cleanly and was the correct verification path:
      latexmk -pdf -outdir=$SCRATCH -auxdir=$SCRATCH -r /dev/null file.tex
  - A direct `pdflatex -output-directory=build` also exited 0, confirming the source was fine
    and the failure was latexmk-level contention, not a LaTeX error.

=== ROOT-CAUSE FINDING (drives the recommendation) ===

The rule `agent-system/extensions/latex/rules/latex.md` ALREADY exists, ALREADY declares
`paths: "**/*.tex"`, and is ALREADY deployed to the paper repo as `.claude/rules/latex.md`
(confirmed present). Because the incident conversation was editing `JPL/possible_worlds.tex`,
that rule was almost certainly auto-loaded at the time.

The rule was therefore not silent -- it was the proximate source of the harmful advice. Its
"Build Commands" section currently prescribes, with no watcher guard whatsoever:

    latexmk -pdf document.tex
    latexmk -c

These are exactly the two commands that must NOT be run against a shared -outdir while a
`-pvc` watcher owns it. Separately, `context/project/latex/tools/compilation-guide.md:215`
documents `latexmk -pdf -pvc` as something to run, with no note that an agent must never
start, kill, or race one.

So the lowest-impact fix is not to add a mechanism. It is to correct an existing file that
already fires on the right trigger and currently says the wrong thing.

=== RECOMMENDED MECHANISM (minimal pair -- option (a) primary + option (b) one-pointer) ===

PRIMARY (option a) -- edit `agent-system/extensions/latex/rules/latex.md`:
  1. Widen the frontmatter glob from `paths: "**/*.tex"` to also cover build/aux surfaces that
     a bare compile command references without touching a .tex file, e.g.
     `**/*.tex`, `**/*.latexmkrc`, `**/build/**`, `**/*.bib`.
     (Confirm the deployer's supported frontmatter syntax for multiple globs before writing --
     every current rule in the source store uses a single-string `paths:` value, so a list form
     must be validated against the loader, not assumed.)
  2. Insert a "Continuous Build Safety" section ABOVE the existing "Build Commands" section, so
     the guard is read before the commands it constrains.
  3. Repair the existing "Build Commands" and "Validation Checklist" blocks so they no longer
     present bare `latexmk -pdf` / `latexmk -c` / "Builds successfully with pdflatex" as
     unconditional instructions.

COMPLEMENT (option b) -- add 3-4 lines to `agent-system/extensions/latex/EXTENSION.md`, the merge
source for the CLAUDE.md "LaTeX Extension" section (merge_targets.claudemd, section_id
`extension_latex`). This is a POINTER ONLY, not a copy of the rule. Rationale: it closes the one
residual gap where an agent issues a bare `latexmk` Bash call having never touched or referenced
any .tex/build path in the session, so no paths-glob match ever fires. Keep it to a few lines --
this text lands in the eager session prefix, which the system explicitly budgets (see
`measure-eager-context.sh` / `measure-eager-surface.sh`).

Also update `context/project/latex/tools/compilation-guide.md` (around the `-pvc` line, ~215) with
a one-line cross-reference to the new rule section, so the lazily-loaded guide does not contradict
the eagerly-loaded rule.

=== ACCEPTANCE CRITERIA (the five behavioral points; the rule text must make each actionable) ===

AC1. DETECT BEFORE COMPILING. Before any latexmk/pdflatex/xelatex/lualatex invocation, check for a
     running continuous watcher on the same source:
         pgrep -af 'latexmk.*-pvc'
     and/or any latexmk/pdflatex process whose arguments name the same .tex file or the same
     -outdir. The rule must give the literal command, not a paraphrase.

AC2. IF A WATCHER IS RUNNING, DO NOT CONTEND. Never run latexmk/pdflatex into the shared build/
     (or whatever -outdir the watcher uses). Never kill, stop, or restart the watcher. Never run
     `latexmk -C` or `latexmk -c` against the shared directory.

AC3. USE A NON-CONTENDING PATH INSTEAD. Either (i) make the edit and let vimtex rebuild -- it is
     already watching the file -- or (ii) verify compilation with an isolated build into the
     session scratchpad and inspect the log there:
         latexmk -pdf -outdir="$SCRATCH" -auxdir="$SCRATCH" -r /dev/null file.tex
     `-r /dev/null` bypasses the project .latexmkrc (which is what appends the spurious
     "Build failed" entries via $failure_cmd).

AC4. REPORT, DO NOT REPAIR. Report the isolated build's result. If the shared build directory
     looks broken (missing PDF, empty .aux, "Build failed" entries in build/compile.log), tell the
     user to run `:VimtexClean` then `:VimtexCompile`. Do not attempt repairs against the shared
     directory.

AC5. CLASSIFY THE FAILURE BEFORE RERUNNING. When diagnosing a nonzero latexmk exit code,
     distinguish latexmk-level failure (exit 12, bibtex/aux complaints such as "I found no
     \citation commands") from an actual LaTeX error (a `^!` line, or a file-line-error
     `file.tex:N:` line) BEFORE rerunning anything. A clean log with a nonzero exit code is a
     contention signal, not a source error.

AC6. NO DUPLICATION. The guidance lives in exactly one authoritative place (the rule). EXTENSION.md
     and compilation-guide.md carry pointers, not restatements.

AC7. VERIFY THE TRIGGER, DO NOT ASSUME IT. Before closing, empirically confirm whether the widened
     paths glob actually fires for a Bash tool call that merely names a .tex path in its command
     string, versus only for Read/Edit/Write on that path. This determines whether the option (b)
     pointer is load-bearing or merely belt-and-braces, and the finding must be recorded in the
     task report either way.

=== OPTION ANALYSIS (rationale for rejecting the alternatives) ===

(a) RULE FILE via provides.rules with a paths glob -- CHOSEN.
    Already exists, already deployed, already fires on .tex touches, already declared in
    manifest.json provides.rules (["latex.md"]). No manifest change, no new file, no deploy
    topology change. Precedent for the pattern: lean's rules/lean4.md with `paths: "**/*.lean"`.
    Fires regardless of task type -- the harness paths-glob mechanism is independent of task
    routing, of index.json, and of any @-import list (see
    `context/patterns/context-discovery.md`, "Rule Loading: Two Independent Paths").
    Residual gap: a bare Bash `latexmk` that references no matching path -- covered by (b).

(b) MERGE-SOURCE ADDITION to EXTENSION.md -> CLAUDE.md -- CHOSEN AS MINIMAL COMPLEMENT, pointer only.
    Always in the eager session prefix whenever the latex extension is loaded, so it is
    unconditionally task-type-independent and has no trigger dependency at all. Cost: eager
    context bytes, which the system budgets. Hence a pointer, not a copy.

(c) PREFLIGHT LIFECYCLE HOOK in the manifest `hooks` object -- REJECTED. CONFIRMED to fail the
    requirement. Lifecycle hooks run only at skill lifecycle stages via skill-base.sh
    (preflight/context_injection/verification/postflight), so they fire only inside a dispatched
    skill. The motivating incident occurred in an ordinary editing conversation with no skill
    lifecycle active -- exactly the case a lifecycle hook cannot reach. The latex manifest
    currently has `provides.hooks: []` and no top-level `hooks` object.

(d) CONTEXT FILE under context/project/latex/ -- REJECTED. CONFIRMED to fail the requirement.
    Every latex entry in `index-entries.json` is gated on `load_when.task_types: ["latex"]` and
    on the latex agents, making it lazily loaded and task-typed -- precisely the two properties
    the requirement excludes. compilation-guide.md, which already contains the only `-pvc` mention
    in the extension, was NOT loaded during the incident for exactly this reason.

(e) PreToolUse Bash-matcher HOOK via settings-fragment.json -- CONSIDERED AND REJECTED as
    disproportionate, though it is the only mechanism that fires with certainty on a bare
    `latexmk` Bash call carrying no path reference. Precedent exists: the email extension
    registers `mail-guard.sh` as a PreToolUse "Bash" matcher through its settings-fragment.json
    plus `provides.hooks`. Rejected because it requires a new script, a new settings-fragment.json
    for an extension that has none, a manifest provides.hooks change, and it imposes a hook
    invocation on EVERY Bash call system-wide to guard one narrow case. Record this as the
    documented escalation path if AC7 shows the paths glob does not fire for Bash-only references
    and the (b) pointer proves insufficient in practice.

COMPLEMENT, OUT OF SCOPE FOR THIS TASK: the PossibleWorlds paper repo's own CLAUDE.md already has
a "Build Workflow: Preventing Aux File Corruption" section documenting this exact race from the
latexmk side. A short pointer there is warranted, but that file belongs to the paper repo, not to
this source store, and is user-owned. Note it in the report as a follow-up suggestion; do not edit
it from this task.

=== SCOPE BOUNDARY ===

All edits target the SOURCE STORE at `agent-system/extensions/latex/**`. Never hand-author
anything under `.claude/**` -- that tree is a disposable deploy artifact regenerated from source
(see `.claude/rules/source-store-deploy-boundary.md`). Verify the change by redeploying and
confirming the regenerated `.claude/rules/latex.md` and the CLAUDE.md `extension_latex` section
carry the new text.

---

### 166. Stop research reports drifting from validate-artifact.sh's required section headings
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 196

**Description**: DEFECT: a produced research report used section headings that are semantically correct but lexically non-conforming, so validate-artifact.sh's required-section check failed on an artifact whose authoring agent ALREADY carries a conforming skeleton. This is NOT the "agent has no skeleton at all" class addressed by the lean/formal skeleton work -- here the skeleton is present and correct, and the produced artifact drifted from it.

VERIFIED EVIDENCE.
1. THE CHECK. agent-system/extensions/core/scripts/validate-artifact.sh:20 declares
     REPORT_SECTIONS=("Executive Summary" "Context & Scope" "Findings" "Decisions" "Recommendations")
   and :170-173 matches each with `grep -qE "^##+ ${section}"` -- an any-depth heading PREFIX match, unanchored at the end.
2. THE ARTIFACT. ~/Projects/BimodalLogic specs/461_acquire_goldblatt_1989_varieties_of_complex_algebras/reports/01_acquisition-verified-corpus-status.md, authored 2026-09-07 12:39 -- AFTER that repo's agent reload at 11:13, so by the current deployed agent. task_type=general, therefore written by general-research-agent. `validate-artifact.sh <path> report` without --fix: FAIL, 1 error, "Missing required section: ## Recommendations".
3. WHY IT FAILED. The report does address recommendations, under two headings:
     :331  ## Context Extension Recommendations
     :337  ## Recommended Next Steps (for the plan phase)
   Neither matches `^##+ Recommendations`: the first because the text after "## " begins "Context", the second because "Recommended" is not "Recommendations". Both directions verified by running the validator's exact regex against both literal strings.
4. THE SKELETON IS NOT THE DEFECT. agent-system/extensions/core/agents/general-research-agent.md:277 carries a report skeleton that DOES include a conforming `### Recommendations`, which satisfies `^##+ Recommendations`. The agent departed from its own template when writing a real report.

TWO CONTRIBUTING FACTORS TO EVALUATE (do not assume either is the cause).
(a) BURIAL. In the skeleton, `### Recommendations` is a third-level subsection of `## Findings`, sitting alongside `### Codebase Patterns` and `### External Resources`. Every other required section is top-level. An agent restructuring Findings for a real report gets no signal that this one subsection is load-bearing for validation.
(b) NEAR-MISS TRAP. The same skeleton separately contains `## Context Extension Recommendations`. An agent writing that heading may reasonably believe the Recommendations requirement is met. The observed artifact contains exactly that heading.

DECIDE, do not assume. Candidate remedies, each with a real cost:
  (i)   AGENT-SIDE: state the five required heading strings verbatim in the agent contract and mark them non-paraphrasable. Cheapest; relies on instruction-following, which is precisely what failed here.
  (ii)  SKELETON-SIDE: promote `### Recommendations` to a top-level `## Recommendations`. Structurally removes factor (a); changes the report shape.
  (iii) VALIDATOR-SIDE: relax matching. DANGEROUS -- a substring match would let `## Context Extension Recommendations` satisfy `Recommendations`, converting a true failure into a false pass. Do not weaken a check to make it green.
State the ruling and its reasoning. Combining (i) and (ii) is permitted; (iii) requires an explicit argument that it creates no false passes.

SCOPE. Determine whether this is general-research-agent alone or a shared shape. Enumerate every core agent carrying a report or summary skeleton and machine-check each skeleton's headings against REPORT_SECTIONS/SUMMARY_SECTIONS using the validator's own regex -- not by eye.

NOT IN SCOPE: pre-existing non-conforming artifacts authored before their agent gained a conforming skeleton. Those fail for a different reason and are a separate backfill question.

ACCEPTANCE.
  - The exact failure is reproduced in a fixture (a report carrying `## Recommended Next Steps` and `## Context Extension Recommendations` but no `## Recommendations`) and shown to pass after the chosen remedy.
  - The chosen remedy is recorded with reasoning, including why the validator was or was not changed.
  - If the validator is touched, a fixture proves `## Context Extension Recommendations` ALONE still fails.
  - An enumeration of all core report/summary-writing agent skeletons, machine-checked against the validator's own regex, with any further gaps listed.
  - A real general-type research dispatch produces a report validating with 0 errors and 0 auto-repairs.

CANONICAL SOURCE CONSTRAINT (binding): all edits target /home/benjamin/.config/nvim/agent-system/extensions/core/. Never hand-edit any deployed .claude/** tree -- it is gitignored, disposable, and regenerated from the source store by the loader. DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 165. Decide and implement the admission posture for an absent file_scope in orchestrate-batch-admit.sh
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: file-scope-lifecycle
- **Dependencies**: Task 163, Task 164

**Description**: Settle whether an ABSENT `file_scope` should be admission-relevant in agent-system/extensions/core/scripts/orchestrate-batch-admit.sh, or remain purely advisory -- and implement the ruling.

THE MOTIVATING HARM (observed live in ~/Projects/BimodalLogic, not hypothetical):
- `/orchestrate 530,531` correctly deferred one task cross-batch for overlapping a live task at README.md -- the collision guard working exactly as designed.
- `/orchestrate 544,545` dispatched BOTH with ZERO collision-guard coverage, purely because neither declares a file_scope at all. A live concurrent task held a broad scope (FormalSystem/, Tests/, docs/, typst/, README.md) and one of the dispatched pair worked the same naming domain that live task was mid-rename on. Nothing would have caught a conflicting concurrent edit.
The guard did not fail. It was never consulted, because the predicate has nothing to compare. An undeclared scope is currently indistinguishable from a scope that provably collides with nothing.

THE TRADEOFF (this is the decision, state it explicitly): treating absence as a defer reason closes the silent-passage hole but risks blocking legitimate work on legacy tasks that predate any file_scope discipline. That risk is what the sequencing mitigates -- this task is gated behind both the detection work and the backfill precisely so the legacy population is already covered before absence can block anything. Verify that mitigation actually landed before tightening; if backfill coverage is incomplete, prefer the softer posture and say why.

EXISTING MECHANICS TO WORK WITHIN (the script's own documented contract): `defer_reason` currently admits "self_modifying", "file_scope_collision", and "session_active". A `file_scope_collision` defer carries `colliding_task_number`, `colliding_task_status`, `overlapping_path`, `collision_scope`, and `corroborated_by`. An absent-scope defer has NO colliding task and NO overlapping path, so it does not fit that payload shape -- it is a different kind of fact (missing information, not detected conflict). If a defer is chosen, it likely needs its OWN reason value rather than being forced into file_scope_collision, whose fields would all be empty. Note also the documented override asymmetry: file_scope_collision and session_active have specific override semantics -- decide where a new reason sits in that hierarchy.

ENFORCEMENT LEVEL -- PRIOR ART, FOLLOW IT: plan-format.md:259-266 records the Verification Tier rollout as the in-repo precedent. Quoted: enforcement is "advisory-first: a missing field emits a warning, not an error, so default-mode validation of plans authored before this vocabulary existed continues to pass. `--strict` mode enforces it today. Promotion criterion: promote the warning to an error once no non-terminal plan under specs/ lacks the field." The same three-part pattern applies: start advisory, WRITE DOWN the promotion criterion, promote only once coverage is complete. A defensible outcome for this task is explicitly deciding NOT to make absence blocking yet, and recording the coverage threshold at which it should become blocking -- that is a real decision, not a deferral, and it must be written into the script header either way.

OPTIONS TO WEIGH: (a) advisory only -- surface in the review, never affect admission; (b) a new non-blocking `defer_reason` visible in output but overridable; (c) a genuine defer gated on a coverage precondition; (d) blocking only when a live task holds a broad scope, i.e. treat absence as risky only in the presence of an actual concurrent hazard, which directly matches the observed harm and is the narrowest fix.

ACCEPTANCE: the ruling and its reasoning are recorded in the script's header contract alongside the existing defer_reason documentation; if a new reason value is added, its payload fields and override semantics are documented to the same standard as the existing three; the observed harm scenario is reproduced as a test case and the chosen posture demonstrably changes its outcome (or is documented as deliberately unchanged); shellcheck clean per context/standards/shell-strict-mode.md.

CANONICAL SOURCE CONSTRAINT (binding): all edits target /home/benjamin/.config/nvim/agent-system/extensions/core/. Never hand-edit any deployed .claude/** tree -- it is gitignored, disposable, and regenerated from the source store by the loader, so edits there are silently wiped. DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 164. Backfill file_scope for existing tasks and decide the disposition for plan-less tasks
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: file-scope-lifecycle
- **Dependencies**: Task 162

**Description**: One-shot backfill of `file_scope` for existing tasks that lack a usable one, plus an explicit ruling on the tasks the backfill CANNOT reach.

WHY THIS IS REACHABLE: because `**Files to modify**:` is an already-universal convention (10/10 plan files locally, 11/12 in ~/Projects/BimodalLogic, emitted by the planner template at agents/planner-agent.md:259), any task that HAS a plan can be backfilled by reusing the harvester built alongside plan-format formalization. This is not a from-scratch inference problem for that population.

REUSE, DO NOT DUPLICATE: the derivation logic belongs to the harvester script (anticipated agent-system/extensions/core/scripts/plan-file-scope-harvest.sh). The backfill script must call or source it, never re-implement path extraction -- two divergent parsers for one convention is precisely the defect this chain exists to remove.

THE HARD PART -- PLAN-LESS TASKS (decide and record, do not silently leave uncovered): a task with NO plan yet has no "Files to modify" list to harvest, so the plan-based route cannot reach it. In BimodalLogic this is the MAJORITY of the 22 affected tasks -- most are status `not_started` and will never have had a plan. Options to weigh explicitly:
  (a) leave them absent and let plan-time population (the formalized harvest) cover them naturally when they are eventually planned -- zero risk, but leaves the gap open for however long they sit unplanned;
  (b) infer a provisional file_scope from the task description/title, accepting that it is a guess -- note the schema already frames file_scope as "prospective, not filesystem-validated", so a provisional value is not a category error, but a WRONG one is worse than absence because it produces false confidence in the collision guard;
  (c) write an explicit sentinel (e.g. `[]`) to distinguish "deliberately unknown" from "never considered" -- but see the empty-vs-absent distinction, since an empty array may read as "touches nothing" and would suppress the very warning that should stay lit.
RECORD THE CHOSEN DISPOSITION AND ITS REASONING. Leaving this population undiscussed is the failure mode this paragraph exists to prevent.

SAFETY: the backfill mutates specs/state.json across repos. It MUST write via state-write.sh (the single mutex-guarded writer; hand-rolled `jq ... > tmp && mv` sequences are exactly what that script was built to eliminate). It MUST offer a dry-run that prints the proposed per-task diff without writing, and MUST be idempotent -- a second run over an already-backfilled state changes nothing. It must never overwrite a task that already has a non-empty file_scope.

CROSS-REPO SCOPE: decide whether the script targets only the invoking repo or accepts a `--state-file` / repo argument. The measured need is largely in ~/Projects/BimodalLogic, not here, so a repo-local-only tool would not address the motivating case. Note state-write.sh already supports `--state-file` for non-default targets.

ORDERING: this task is a prerequisite for making an absent file_scope admission-relevant. Backfilling before any enforcement tightens is the mitigation that keeps legacy tasks from being blocked.

ACCEPTANCE: dry-run prints an accurate per-task diff and writes nothing; a real run raises this repo's coverage to 38/38 and BimodalLogic's toward 49/49 for the plan-bearing population; re-running is a no-op; tasks with an existing non-empty file_scope are untouched; the plan-less disposition is implemented and its reasoning recorded; shellcheck clean per context/standards/shell-strict-mode.md.

CANONICAL SOURCE CONSTRAINT (binding): all edits target /home/benjamin/.config/nvim/agent-system/extensions/core/. Never hand-edit any deployed .claude/** tree -- it is gitignored, disposable, and regenerated from the source store by the loader, so edits there are silently wiped. Backfilled DATA under specs/** is exempt from this rule -- specs/** is the legitimate write target for task-management artifacts. DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 163. Surface missing and empty file_scope in validate-state.sh and orchestrate-predispatch-review.sh
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: file-scope-lifecycle
- **Dependencies**: Task 188

**Description**: Make an ABSENT or EMPTY `file_scope` visible. Today it is invisible everywhere, by construction.

VERIFIED GAP -- both existing checks skip exactly the entries that lack the field:
1. agent-system/extensions/core/scripts/validate-state.sh Check 8 (coarse whole-directory-root declarations, ~line 460) and Check 9 (duplicate entries within one task's array, ~line 501) are BOTH WARN-only AND both guard with `select(has("file_scope"))`. An entry with no file_scope key is silently skipped by both. There is no missing/empty check anywhere in the script.
2. agent-system/extensions/core/scripts/orchestrate-predispatch-review.sh Class B (~line 236) iterates `["dependencies", "file_scope", "title", "topic"]` and matches with `select(($entry | has($field)) and ($entry[$field] == null))`. Its own comment states the intent verbatim: "A genuinely absent key is NOT flagged -- only a present-but-literal-null value is the anomaly this class exists to surface." So absence is skipped BY DESIGN, not by oversight.

These two are consolidated into one task deliberately: both are WARN-shaped detection edits in the same layer, and splitting them would force two tasks to independently re-derive the same WARN-vs-block conclusion.

WORK: add a missing/empty file_scope check to validate-state.sh; extend predispatch-review to surface an absent file_scope. For the latter, DECIDE whether to widen Class B or add a NEW class -- widening Class B changes the documented meaning of an established class (its comment explicitly scopes it to literal-null) and Class B feeds `--repair`, which normalizes null to []. Note that an absent key and a literal-null value are NOT equivalent for repair purposes: normalizing an absent key to `[]` would manufacture an empty declaration that then looks deliberate, which is arguably worse than absence. A new class avoids both hazards. Record the ruling either way.

ENFORCEMENT LEVEL -- PRIOR ART, FOLLOW IT: plan-format.md:259-266 records the Verification Tier rollout as the in-repo precedent for exactly this decision. Quoted: per-phase tier enforcement in validate-artifact.sh is "advisory-first: a missing `**Verification Tier**:` field emits a warning, not an error, so default-mode validation of plans authored before this vocabulary existed continues to pass. `--strict` mode enforces it today. Promotion criterion: promote the warning to an error once no non-terminal plan under specs/ lacks the field. This is recorded here for a future task to execute; it is not done by the task that introduced this vocabulary."

Apply that same three-part pattern here: (a) start WARN in default mode; (b) WRITE DOWN an explicit promotion criterion in the script's own header comment; (c) do NOT promote in this task. Consider whether `--strict` should enforce it immediately, as validate-artifact.sh does. Do not invent a different enforcement philosophy -- this precedent exists and is load-bearing.

EMPTY vs ABSENT: treat `file_scope: []` and a missing key as distinct states and decide whether both warn. An explicit empty array may be a deliberate "this task touches nothing" assertion; a missing key is an omission. Record the distinction.

MEASUREMENT VALUE: this task is what makes the problem measurable. Local coverage is 37/38 active tasks with a non-empty file_scope; ~/Projects/BimodalLogic is 27/49, with 22 lacking a usable value (17 missing the key, 5 literal null) spanning 2026-05-11 through 2026-08-26 -- longstanding, not a recent regression. The check must reproduce those counts.

ACCEPTANCE: validate-state.sh reports the missing/empty count and exits 0 in default mode; the promotion criterion is written into the script header; predispatch-review surfaces absent file_scope with the class decision documented; `--repair` does not manufacture `[]` on absent keys; both scripts shellcheck clean per context/standards/shell-strict-mode.md; running against this repo's specs/state.json yields the expected 1-of-38 figure.

CANONICAL SOURCE CONSTRAINT (binding): all edits target /home/benjamin/.config/nvim/agent-system/extensions/core/. Never hand-edit any deployed .claude/** tree -- it is gitignored, disposable, and regenerated from the source store by the loader, so edits there are silently wiped. DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 162. Formalize the existing Files to modify convention in plan-format and harvest it into file_scope at plan postflight
- **Status**: [RESEARCHED]
- **Task Type**: meta
- **Topic**: file-scope-lifecycle
- **Dependencies**: Task 197, Task 213, Task 214
- **Research**: [162_formalize_files_to_modify_and_harvest_file_scope/reports/01_files-to-modify-harvest.md]

**Description**: Populate `file_scope` at PLAN time by formalizing an existing, universally-followed convention and making it reliably machine-harvestable.

FRAMING -- THIS IS NOT A GREENFIELD FIELD. `**Files to modify**:` is already a de facto universal convention. Verified: present in 10/10 plan files under specs/*/plans/ in this repo (11/12 in ~/Projects/BimodalLogic); already EMITTED by the planner's own phase template at agent-system/extensions/core/agents/planner-agent.md:259 (`**Files to modify**:` followed by `- `path/to/file` - {what changes}`). What is missing is only its FORMALIZATION: context/formats/plan-format.md's per-phase field list (lines 76-95: Goal, Tasks, Timing, Depends on, Verification Tier, Commit Mode, Scope Hypothesis, Owner) does not enumerate it. The task is to formalize the convention and pin a stable grammar, NOT to invent a carrier.

CONSEQUENCE: the harvest has near-total existing coverage to work against immediately, making this substantially lower-risk than a greenfield field would be. Do not design for a sparse-adoption rollout; design for a convention already in place.

COMPATIBILITY CONSTRAINTS (binding -- three existing consumers reference this by name; any grammar settled on MUST keep all three working):
1. agent-system/extensions/core/agents/general-implementation-agent.md:65 -- reads "Files to modify/create per phase" when extracting from the plan.
2. agent-system/extensions/core/skills/skill-orchestrate/SKILL.md:1274,1280 -- the H1 territory block sets `"owned_files": "derive from plan_path's Phase N \"Files to modify\" list"`.
3. agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh:1335 -- the same territory derivation, ported verbatim.

IMPORTANT NUANCE about consumers 2 and 3: neither parses the list itself. Per the comment at SKILL.md:1274, "The orchestrator does not parse the plan's 'Files to modify' list itself -- it points the agent at the plan/phase location" and the agent derives owned_files from the phase section. So the constraint these two impose is HEADING-NAME STABILITY (the literal string is embedded in a prompt directive handed to an agent), not parser grammar. Changing the heading text would silently break the directive with no parse error. Treat the name as frozen.

GRAMMAR: two punctuation variants exist in practice -- `**Files to modify**:` (64 occurrences) and `**Files to modify:**` (6). This matches plan-format.md's already-documented "Field-punctuation tolerance" rule for per-phase field labels, which states both forms are accepted; the harvester MUST accept both. Settle the list-item grammar against the planner template's emitted shape (`- `path/to/file` - {what changes}`), tolerating the backtick-quoted path and the trailing ` - {description}`.

SCOPE-HYPOTHESIS ALIGNMENT: plan-format.md:251 defines any plan-asserted file list as "a hypothesis requiring implementation-time confirmation, never a fact". The state schema (context/schemas/state-schema.json:227) independently describes file_scope as "prospective, not filesystem-validated". These align: harvesting a plan-time hypothesis into a prospective field is coherent, and the harvest MUST NOT filesystem-validate the paths or drop ones that do not yet exist (new files are exactly what a plan creates). Where a phase carries a `**Scope Hypothesis:**` line, decide whether it informs the harvest or is ignored, and record the ruling.

WORK: (1) add `**Files to modify**:` to plan-format.md's per-phase field list with its grammar, marking it required-or-advisory deliberately; (2) record the three consumers above in plan-format.md as compatibility constraints so a future format change accounts for them, mirroring how that file already lists the three consumers of the phase-heading contract; (3) build the harvester (anticipated: agent-system/extensions/core/scripts/plan-file-scope-harvest.sh) that unions every phase's list into a deduplicated file_scope; (4) wire it into plan postflight, writing via state-write.sh (the single mutex-guarded writer -- do not hand-roll a jq read-modify-write).

DECIDE, DO NOT ASSUME: whether harvest OVERWRITES an existing file_scope or unions into it; whether a plan revision (/revise, a new MM_ plan round) re-harvests; whether a harvest failure is fatal to postflight or a warning (note update-task-status.sh's and state-write.sh --regen-todo's existing posture is a loud warning, not a hard failure).

ACCEPTANCE: plan-format.md enumerates the field with its grammar and its three named consumers; the harvester extracts the correct union from all 10 local plan files under specs/*/plans/ and accepts both punctuation variants; a plan postflight on a task with a plan populates a non-empty file_scope; the three existing consumers are demonstrably unbroken (the heading string is unchanged); shellcheck clean per context/standards/shell-strict-mode.md.

CANONICAL SOURCE CONSTRAINT (binding): all edits target /home/benjamin/.config/nvim/agent-system/extensions/core/. Never hand-edit any deployed .claude/** tree -- it is gitignored, disposable, and regenerated from the source store by the loader, so edits there are silently wiped. DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 140. Add a concurrency-gated history-rewrite predicate to guard-destructive-git.sh
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 139, Task 215

**Description**: Give agent-system/extensions/core/hooks/guard-destructive-git.sh a SECOND, INDEPENDENT predicate that blocks or loudly warns on history rewrites (`git commit --amend`, `git reset` without `--hard`) when evidence of a concurrent writer exists. This is the enforcement half of the policy its predecessor task establishes in the rules and agent contracts.

WHY A SECOND PREDICATE AND NOT AN EXTENSION OF THE FIRST. The hook's entire existing design is built around ONE hazard: discarding UNCOMMITTED working-tree changes. Its header states the premise directly -- "block destructive git commands when the working tree is dirty" (lines 3-5) -- and its first live check is the clean-tree exemption, "working tree is already clean (git status --porcelain is empty)" / "Clean tree -> nothing to lose" (lines 19-23, check at lines 61-64). The hazard this task addresses is a different class: rewriting ALREADY-COMMITTED history owned by a concurrent writer. Both commands involved are non-destructive to the working tree, so the clean-tree exemption would have ACTIVELY WAVED THEM THROUGH. Merely adding `--amend` to the existing dirty-tree predicate would still not fire. The new predicate must therefore not consult tree dirtiness at all. Verified: the file matches `amend` 0 times and `mixed` 0 times today.

MOTIVATING INCIDENT (real, observed 2026-09-02, multi-task /orchestrate run, five concurrent implementation agents committing to master). An agent ran bare `git commit --amend` intending its own commit; a sibling agent's commit had landed on top in the interim, so the amend rewrote the sibling's commit, preserving its file content but overwriting its message. A follow-up `git reset --mixed <own-sha>` rewound HEAD past three further legitimate commits and intermingled their changes in the working tree. Recovered via reflog: trees identical, zero content lost, residual damage exactly one mislabeled commit message. Reconstructible evidence: 539561c39 (correct), 9c5b790b6 (orphaned original), fd50fabfd (tree-identical to 9c5b790b6, wrong message).

THE DESIGN TENSION TO RESOLVE, NOT PAPER OVER. The hook observes only the literal top-level tool_input.command string. It cannot see intent. An over-broad rule blocks legitimate solo interactive `--amend`, which is explicitly permitted. Research must select and justify a concurrency signal, weighing false-positive and false-negative cost. Candidate signals, none pre-committed:
  - a live entry in specs/.task-locks/ held by a session other than the caller's;
  - an in-flight session-registry entry belonging to a different session;
  - HEAD having moved since the calling agent's own last commit (directly diagnostic of the incident, but requires per-session commit-sha state the hook does not currently keep).
Also decide the response: hard refusal (exit 2 + stderr, matching the existing block mechanism -- note the header's warning that `permissionDecision: deny` is documented-buggy for allow-listed Bash(git:*) commands, GH #4669/#13214/#18312) versus a loud non-blocking warning. These may differ per signal strength.

DESIGN CONSTRAINTS.
  - The new predicate must be structurally independent of the clean-tree exemption; that exemption currently returns exit 0 before any detector runs, so predicate ordering is load-bearing.
  - `git-commit-scoped.sh` must remain unblocked. Note the existing header's observation-boundary argument (lines 41-47): a git command run as a subprocess inside a wrapper script never appears in tool_input.command, so wrapper-internal git is structurally invisible to this hook. Follow that established pattern rather than special-casing.
  - Reuse the file's existing argv-anchoring scan-string machinery (COMMAND_SCAN, quoted-span and comment stripping, lines 67+) so a commit message containing the text "--amend" cannot trigger a false positive.
  - The refusal message must point at the rule section its predecessor task adds, so a blocked agent can read the rationale.

WORK.
(a) Implement the concurrency-gated history-rewrite predicate in hooks/guard-destructive-git.sh.
(b) Update the hook's header comment block, which currently documents a single-hazard design and would otherwise misdescribe the file.
(c) Update context/standards/git-safety.md for the new hazard class and the chosen signal.
(d) Update rules/git-workflow.md's enumeration of what the hook enforces (its "enforced by" framing) so rules and implementation stay in agreement.
(e) Verify with concrete cases: a bare `--amend` under a foreign task lock is refused; the same command with no concurrent writer is permitted; a git-commit-scoped.sh invocation is permitted; a commit message containing the literal string "--amend" does not trigger.

NON-GOALS (explicit).
  - Do NOT forbid `--amend` unconditionally for single-session interactive use.
  - Do NOT attempt retroactive repair of the mislabeled commit fd50fabfd.

ACCEPTANCE. A bare `git commit --amend` or `git reset` issued by a dispatched agent while another session holds a task lock is refused or loudly warned; the rationale is reachable from the message; compliant git-commit-scoped.sh use remains unblocked; solo use is unaffected.

SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/. Never edit .claude/ directly. Redeploy and confirm the hook survives regeneration and actually fires from the deployed copy.

DEPENDENCY RATIONALE. Depends on its predecessor task on two grounds: that task settles the policy this one mechanizes and supplies the rationale text this hook's refusal message points at; and both tasks touch rules/git-workflow.md, so the file-footprint admission gate serializes them regardless.

---

### 139. Forbid concurrent-writer history rewrites in git rules and agent contracts
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 146, Task 194

**Description**: Bare git history rewrites (`git commit --amend`, `git reset` without `--hard`) are forbidden nowhere in the agent system, and the one place that looks like a prohibition is scoped so that it structurally cannot fire on the hazard that actually occurred. Add the prohibition to the rules and to the agent contracts, and correct the existing mis-scoped bullet rather than merely adding alongside it.

MOTIVATING INCIDENT (real, observed 2026-09-02 during a multi-task /orchestrate run with five concurrent implementation agents committing to master). An agent ran bare `git commit --amend` to add an attribution trailer to what it believed was its own commit. Between its commit and the amend, a DIFFERENT agent's commit landed on top, so the amend rewrote the sibling's commit instead -- preserving that sibling's file content but overwriting its message. The agent then ran `git reset --mixed <own-sha>` to undo, which rewound HEAD past three further legitimate commits and dumped their changes into the working tree intermingled. It caught this and restored HEAD via reflog. Verified afterward: trees identical, zero content lost; residual damage is exactly one mislabeled commit message still in history. Reconstructible reflog evidence: commits 539561c39 (correct), 9c5b790b6 (orphaned original), fd50fabfd (tree-identical to 9c5b790b6, wrong message).

WHY THIS IS A NEW PREDICATE, NOT A WIDENED OLD ONE -- the load-bearing finding. ALL THREE layers of the existing mechanism share one identical blind spot: each is scoped by dirtiness-of-tree, and the incident's hazard is concurrency-of-writers. Both commands involved are non-destructive to the working tree, so every existing guard would have actively waved them through.

  1. HOOK. agent-system/extensions/core/hooks/guard-destructive-git.sh states its own premise in its header: "PreToolUse Bash hook: block destructive git commands when the working tree is dirty" (lines 3-5), with the exemption "working tree is already clean (git status --porcelain is empty)" -- annotated in the file as "Clean tree -> nothing to lose" (lines 19-23, and the live check at lines 61-64). Verified: the file matches `amend` 0 times and `mixed` 0 times. It blocks only `reset --hard`, `checkout -- <path>`, `restore <path>`, `clean -f -d`, `stash drop`/`clear`, and forced `checkout`/`switch`.
  2. RULES. agent-system/extensions/core/rules/git-workflow.md's "Never Run" list (line 77) covers `push --force`, `reset --hard` on uncommitted work, `rebase -i`, `add -A`, `commit -am` -- but NOT `commit --amend` and NOT non-hard `reset`. Its sibling section at line 89 is titled "No Destructive Git on Uncommitted Work"; that title and framing structurally exclude already-committed history.
  3. AGENT CONTRACTS. agent-system/extensions/core/agents/general-implementation-agent.md carries no prohibition at all. Its `-hard` sibling (general-implementation-hard-agent.md, ~line 63, Recovery Ladder) says "Never `git reset`/`git checkout -- <path>`/`git restore` WHILE UNCOMMITTED CHANGES EXIST" -- the prohibition is itself gated on the dirty-tree predicate, so it too would have permitted this. This phrasing must be CORRECTED, not merely supplemented.

Verified across agent-system/extensions/core/{rules,context,agents}/: `--amend` has ZERO occurrences. It is forbidden nowhere.

WORK (contract and documentation layer only; the hook predicate is a separate task).
(a) rules/git-workflow.md: add `git commit --amend` and non-hard `git reset` to the "Never Run" list.
(b) rules/git-workflow.md: add a SIBLING section to "No Destructive Git on Uncommitted Work" covering rewrites of already-committed history under concurrent writers. Place it so a reader arriving at the uncommitted-work rule finds it -- the current title is precisely what makes this case invisible. Include the incident rationale and the concurrency-vs-dirtiness distinction.
(c) agents/general-implementation-agent.md: add a MUST NOT bullet against bare history rewrites, directing all commits through scripts/git-commit-scoped.sh, which serializes on the commit mutex and path-scopes staging. Empirical support: in the motivating run, four of five agents used git-commit-scoped.sh exclusively and had zero incidents; the one that did not caused the entire incident.
(d) agents/general-implementation-hard-agent.md: correct the Recovery Ladder bullet's "while uncommitted changes exist" scoping so the prohibition also covers committed-history rewrites under concurrent writers.

NON-GOALS (explicit).
  - Do NOT forbid `--amend` unconditionally for single-session interactive use. The discriminating variable is a concurrent writer, not the command itself.
  - Do NOT attempt retroactive repair of the mislabeled commit fd50fabfd. That is a separate operator decision to be made when the branch is quiet.

ACCEPTANCE.
  - `git commit --amend` and non-hard `git reset` appear in the "Never Run" list with the concurrency qualifier.
  - The rationale is documented where a reader looking at the uncommitted-work rule will find it.
  - general-implementation-agent.md carries an explicit git-commit-scoped.sh mandate.
  - general-implementation-hard-agent.md no longer scopes its git prohibition solely by tree dirtiness.
  - Compliant git-commit-scoped.sh use remains unrestricted.

SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/. Never edit .claude/ directly (it is a regenerated deploy artifact). Redeploy and confirm the change survives regeneration.

RELATED, NOT DUPLICATE. Task 72 covers teammate .return-meta.json ownership and marker correlation -- a different concern entirely.

---

### 136. Stop implementation agents hand-writing the plan-level Status field, and make the validator catch it
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 91, Task 146, Task 166

**Description**: PRODUCER-SIDE root cause of the malformed plan-level Status line that task 91 handles from the consumer side. Task 91 makes update-plan-status.sh diagnose the malformed line loudly; this task stops the line being written in the first place, and makes the validator catch it if it ever is.

EVIDENCE (git history of a real plan file, BimodalLogic repo, specs/507_parameterize_validity_by_frameclass/plans/02_frame-level-validity-indexing.md):
  bd68091cb  - **Status**: [NOT STARTED]     planner-agent, conforming
  b35d5c043  - **Status**: [IMPLEMENTING]    lifecycle transition, conforming
  463b00103  - **Status**: [IMPLEMENTING]    still conforming after phase 8
  3d50e2583  - **Status**: COMPLETED         <-- lean-implementation-agent hand-edit, BRACKETS LOST
  b7ccf6702  - **Status**: [COMPLETED]       manual orchestrator repair
The malformed line is authored by an IMPLEMENTATION AGENT, not by any script and not by the planner. update-plan-status.sh cannot produce an unbracketed line (its sed both requires and writes brackets), and plan-format.md is correct and unambiguous (bracketed form specified at lines 6, 16, 372). The plan format file is NOT the defect.

DEFECT 1 -- NO OWNERSHIP BOUNDARY IN AGENT CONTRACTS.
Implementation agents are told, emphatically, to Edit PHASE HEADING markers in the plan file:
  extensions/lean/agents/lean-implementation-agent.md:80   "**CRITICAL**: You MUST update phase status markers in the plan file at phase boundaries."
  extensions/lean/agents/lean-implementation-agent.md:99   new_string: "### Phase {P}: {exact_phase_name} [COMPLETED]"
  extensions/lean/agents/lean-implementation-agent.md:437  "**ALWAYS update plan file phase markers with Edit tool**"
  extensions/lean/agents/lean-implementation-agent.md:450  (forbids) "Leave plan file with stale status markers"
NOWHERE does any implementation-agent contract state that the plan-level metadata field `- **Status**:` is a DIFFERENT field with a DIFFERENT owner (update-plan-status.sh, driven by postflight via update-task-status.sh). An agent told "ALWAYS update plan file status markers" and "never leave stale status markers" generalizes from the phase headings to the metadata field -- which is exactly what happened -- and hand-typing loses the brackets.
Verified absent by grep for `update-plan-status|plan-level status|metadata Status` across:
  extensions/lean/agents/lean-implementation-agent.md          (zero hits)
  extensions/lean/agents/lean-implementation-hard-agent.md     (zero hits)
  extensions/core/agents/general-implementation-agent.md       (zero hits; its only `- **Status**: [COMPLETED]` at :476 is inside the SUMMARY template, a field the agent legitimately owns)
Note the asymmetry worth preserving: the general agent's summary template DOES spell out the bracketed vocabulary inline ("Use `**Status**: [COMPLETED]` when every plan phase is done..."). The plan-level field has no equivalent statement anywhere.

DEFECT 2 -- VALIDATOR CHECKS PRESENCE, NOT GRAMMAR.
extensions/core/scripts/validate-artifact.sh:120-124 is the entire metadata check:
  for field in "${metadata_fields[@]}"; do
    if ! grep -qF "**${field}**:" "$artifact_path"; then ... log_error "Missing metadata field" ...
It tests only that the substring `**Status**:` EXISTS. The bracketed-value grammar is never checked, for plans, reports, or summaries. Consequence, observed: the task-507 plan carrying `- **Status**: COMPLETED` validated as `[PASS] plan artifact is valid (0 warning(s))` while being unstampable by update-plan-status.sh. The validator is the layer that should have caught this before postflight did.

WORK.
(a) Add an explicit ownership boundary to every implementation-agent contract that instructs phase-marker editing. State that `- **Status**:` in the plan METADATA block is owned by update-plan-status.sh (invoked from update-task-status.sh postflight) and MUST NOT be hand-edited, and that the agent's plan-file write authority is limited to `### Phase N: ... [MARKER]` headings and checklist items. Apply to at minimum: extensions/lean/agents/lean-implementation-agent.md, extensions/lean/agents/lean-implementation-hard-agent.md, extensions/core/agents/general-implementation-agent.md, extensions/core/agents/general-implementation-hard-agent.md. SWEEP for other agents carrying phase-marker instructions (cslib-implementation-agent.md is a known candidate) rather than assuming the list above is complete.
(b) Add a Status-line GRAMMAR check to validate-artifact.sh, so a non-conforming value is an error, not a pass. Must cover the three malformed shapes task 91 enumerates: missing brackets, trailing text after the closing bracket, missing `- ` prefix.
(c) Decide whether the grammar check participates in --fix (in-place repair) or reports only. NOTE THE INTERACTION: task 13 (instrument_gate_out_auto_repair_reporting) is separately deciding whether --fix should remain in-place-mutating on the gate-out path at all. Do not silently add a new in-place mutation while that decision is open -- state the choice and its reasoning explicitly.

DEPENDENCY ON 91 -- LOAD-BEARING, NOT ADMINISTRATIVE. Task 91's deliverable (b) decides the tolerance policy for trailing text after the closing bracket: either accept `- **Status**: [IMPLEMENTING] (resumed; Phases 1R-10R closed)` by rewriting only the bracketed token, or reject it as malformed. The validator grammar in (b) above must ENFORCE whatever 91 decides. Implementing this task first would hardcode a guess and then need reworking. Sequence behind 91.

SCOPE BOUNDARY. This task does NOT touch update-plan-status.sh, update-task-status.sh, or context/formats/plan-format.md -- all three belong to task 91's file_scope. If documenting the ownership boundary in plan-format.md proves necessary, hand that edit to 91 rather than widening this task's scope into a file_scope collision.

ACCEPTANCE.
  - Every implementation agent carrying phase-marker instructions also carries the plan-level-Status ownership boundary; verified by grep, not by assumption.
  - validate-artifact.sh rejects all three malformed Status shapes on a plan artifact and passes the conforming shape, consistent with 91's trailing-text policy.
  - The --fix participation decision is stated in the summary with its reasoning, and is consistent with whatever task 13 concluded (or explicitly notes 13 as still open).
  - Redeploy and confirm the fix survives regeneration (.claude/ is a deploy artifact; the edit target is agent-system/extensions/).

PROVENANCE. Root-caused 2026-09-01 during an /orchestrate 507 run in the BimodalLogic repo, where the postflight status transition failed with "Failed to update status in .../plans/02_frame-level-validity-indexing.md" and the orchestrator repaired the line by hand. Consumer-side handling is task 91; this entry covers the producer and validator ends, which 91's file_scope excludes.

---

### 129. Empirically audit \b word-boundary grep patterns for compositional failure under the deployed grep
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 88, Task 128

**Description**: Audit every `\b` word-boundary construct used in a grep pattern across the source store, empirically, against the grep actually deployed, and record portable-construct guidance so the class does not recur. Surfaced by the adversarial-verification gate failure (evt_1788245094839_eybEyC); that gate is fixed separately and is NOT in this task's scope.

THE DEFECT IS COMPOSITIONAL, NOT A MISSING FEATURE. State this precisely; the imprecise version of this finding is what would sink the audit itself. The deployed grep is ugrep 7.8.4 (built with PCRE2 available: `-P:pcre2jit`). Its POSIX/DFA `-E` engine does NOT simply ignore `\b`. Every fragment of the failing pattern matches in isolation against the literal header line `| Claim | Source / counterexample | Verification method | Confidence |`:

  PATTERN                                                          RESULT
  \bclaim\b                                                        MATCH
  claim                                                            MATCH
  \|[^|]*\bclaim\b[^|]*\|                                          MATCH
  [^|]*\bclaim\b                                                   MATCH
  \bclaim\b[^|]*                                                   MATCH
  \bsource\b[^|]*\bcounterexample\b                                MATCH
  \|[^|]*\bclaim\b[^|]*\|[^|]*\bsource\b                           MATCH

The full composed pattern nevertheless fails, and bisection localizes it:

  \|[^|]*\bclaim\b[^|]*\|[^|]*\bsource\b[^|]*\bcounterexample\b[^|]*\|   NOMATCH   (production form)
  \|[^|]*\bclaim\b[^|]*\|[^|]*\bsource\b[^|]*\bcounterexample\b          NOMATCH
  \|[^|]*\bclaim\b[^|]*\|[^|]*\bsource\b[^|]*counterexample              MATCH     (dropped \b around counterexample)
  \|[^|]*\bclaim\b[^|]*\|[^|]*source[^|]*\bcounterexample\b              NOMATCH   (dropped \b around source)
  \|[^|]*claim[^|]*\|[^|]*\bsource\b[^|]*\bcounterexample\b              NOMATCH   (dropped \b around claim)

and the unmodified production pattern under `-P` (PCRE2) returns MATCH.

So the engine mis-evaluates a `\b` that appears DOWNSTREAM of an earlier `\b`-anchored subexpression separated by a `[^|]*` run. Whether a given `\b` works depends on what else is in the pattern.

BINDING CONSTRAINT ON HOW THIS AUDIT IS PERFORMED. Because the failure is compositional, spot-testing a fragment in isolation does NOT prove the production pattern works in situ. Every site must be executed as its full, unmodified production pattern against a real positive input under the deployed grep, and the observed result recorded. Reasoning about whether a construct "should" work, testing a simplified stand-in, or generalizing from one site's result to another's are all forbidden -- they are precisely the trap this defect sets.

FOR THE SAME REASON, THIS IS NOT A MECHANICAL FIND-AND-REPLACE. A blanket `\b` removal would be wrong: `\b` carries real semantics, and several high-stakes sites were spot-verified as CURRENTLY WORKING under the deployed grep -- guard-destructive-git.sh's `--hard\b` and `(drop|clear)\b` both match (that guard is live, not silently dead), the sorry census's `\bsorry\b` matches, and literature-audit.sh's `\b(Definition|Lemma|Theorem|Proposition|Corollary|Remark|Example)\s+[0-9]+(\.[0-9]+)*\b` matches. Rewriting working patterns risks introducing false positives in a destructive-git guard, which is a worse outcome than the defect being audited.

SCOPE. Roughly 26 grep-adjacent `\b` sites across the source store, spanning literature scripts, lean scripts, core scripts, lint scripts, test harnesses, and hooks. For each: run the production pattern against a real positive input under the deployed grep; classify as WORKING or BROKEN on the evidence; repair only the broken ones, choosing per-site between dropping `\b` where surrounding delimiters already provide the boundary and switching that invocation to `-P`; and leave working sites alone with a one-line note recording that they were tested rather than assumed.

DELIVERABLE BEYOND THE REPAIRS. A short portability guidance note under the core standards context directory covering: that the deployed grep may be ugrep rather than GNU grep; that `\b` under `-E` is compositionally unreliable there while `-P` is reliable; that delimiter-anchored alternatives are preferred where the surrounding pattern already bounds the token; and that any new `\b` pattern must be executed against a real input before being committed. Without this note the class recurs the next time someone writes a plausible-looking boundary pattern.

SEQUENCING. Depends on the adversarial-gate fix purely to avoid a file-footprint collision: skill-orchestrate/SKILL.md is itself one of the sites, and that task owns the gate's pattern. This task covers every other site and must not touch the gate.

ACCEPTANCE: every site is accompanied by a recorded empirical result under the deployed grep; no working pattern is rewritten; each repaired pattern is demonstrated to match a real positive input AND to reject a real negative input; and the guidance note exists.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 127. Collapse routing ladder to routing agents
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 121, Task 124, Task 125

**Description**: === REVISED 2026-09-01 (backlog streamline: absorbs the present-routing residue) ===
ADDITIONAL WORK ITEMS, absorbed from the abandoned present-extension routing task: (5) while rewriting the manifests, resolve present/manifest.json's colon-suffixed compound values -- its routing.implement block ("present:grant" -> "skill-grant:assemble" style) disappears with the collapse, mooting the skill-name half of the original defect, but audit routing_agents for any analogous colon-suffixed AGENT value encoding workflow_type into a name no consumer splits, and settle the encoding (drop the suffix and carry workflow_type another way, or make the resolver split and expose it as a sub-mode variable). (6) extend lint-routing-wiring.sh so any routing_agents value naming a nonexistent agent file fails verify-deploy -- the original defect (a manifest naming a nonexistent dispatch target, shipped silently) must be impossible to reintroduce under the collapsed model.
=== ORIGINAL DESCRIPTION FOLLOWS ===
Collapse the routing ladder to routing_agents-only across all 19 extension manifests; retire command-route-skill.sh.

CONTEXT. Every extension manifest may declare up to four routing blocks today (routing, routing_hard, routing_agents, routing_agents_hard), resolved by the shared five-step ladder in scripts/lib/manifest-routing-lib.sh. Once /research, /plan, /implement are deleted (no skill layer left to route to) and the hard-mode collapse lands (no separate hard-routing table needed -- hard mode becomes a dispatch-prep injection, not a different resolved agent file), only routing_agents remains meaningful.

WORK. (1) Remove the routing and routing_hard blocks from every extension manifest that declares them, retaining only routing_agents (plus any extension-specific op like present's critique). (2) Retire command-route-skill.sh -- confirm no remaining caller (only the now-deleted /research, /plan, /implement, /revise-adjacent paths called it; /revise itself does not use this resolver and is unaffected). (3) Update context/guides/manifest-routing-schema.md to document the collapsed two-block model (down from four), including the completeness-lint contract re-scoped to check only routing_agents completeness against itself. (4) Re-scope lint-routing-wiring.sh's Checks A/C accordingly.

DEPENDS ON both the command deletions (routing/skill-dispatch has no remaining caller) and the hard-mode file deletions (routing_hard/routing_agents_hard has no remaining caller) having already landed.

SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/*/manifest.json (all 19), agent-system/extensions/core/scripts/command-route-skill.sh, agent-system/extensions/core/context/guides/manifest-routing-schema.md, agent-system/extensions/core/scripts/lint/lint-routing-wiring.sh (never .claude/**).
DELIVERABLE RULE: no task-number references in any deliverable outside specs/**.

REFERENCE: specs/116_core_agent_system_consolidation/reports/03_target-state-design.md (A3).

---

### 89. Mode gate literature and distill skills
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 87

**Description**: Apply the mode-gated section convention to the two remaining large instances, after the pilot proves it.

skill-literature/SKILL.md, 84,265 B total, 64.5% fenced bash. Seven mutually exclusive mode sections of which exactly ONE fires per invocation: Mode: Rebuild 20,170 | Mode: Convert 17,534 | Mode: Search 10,043 | Mode: Validate 5,989 | Mode: Import Pipeline 5,785 | Mode: Index 5,234 | Mode: Ingest 1,917 = ~65,772 B, 78% of the file. Cleanly '## Mode:'-delimited, so the split is mechanical. Estimated ~14,000 tokens per /literature invocation, taking it from ~46.2k toward ~32k.

skill-distill/SKILL.md, 93,044 B total, only 1.9% bash -- essentially pure prose. `## Auto Distill Complete` is 43,254 B, 46% of the file, and is an OUTPUT TEMPLATE used by --auto alone. It belongs in context/formats/, not in a skill body loaded on every /distill invocation. Estimated ~10,800 tokens per non---auto /distill, taking it from ~42.4k toward ~32k.

Combined estimated saving ~24,800 tokens across the two commands' invocations.

Both carry the same fence-interior heading hazard as the orchestrate application -- '## Mode:' and '## Auto' strings can appear inside fenced examples. Split bottom-up and verify each extracted section round-trips.

ACCEPTANCE: each mode section loads only when its mode is selected; all seven literature modes and both distill paths verified working; measured reductions reported against the 46.2k and 42.4k baselines.

---

### 76. Close task-type-keyed hook gap for non-latex agents that compile .tex
- **Effort**: 3 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: Task 74, Task 146

**Description**: Close the coverage gap that the latex-extension wiring cannot reach: agents that compile .tex files under a task type OTHER than `latex` currently get no build-guard protection at all, because the extension hook mechanism is keyed on task_type.

DEPENDS ON the core guard script task. This task is NOT redundant with the latex-extension wiring task -- it covers a disjoint set of dispatches, and skipping it would leave the exact incident that prompted this work uncovered.

THE GAP, VERIFIED PRECISELY. `skill_run_extension_hook()` in `agent-system/extensions/core/scripts/skill-base.sh` resolves which extension's hooks to run by calling `skill_get_extension_dir "$task_type"`, which maps a task type to `.claude/extensions/<ext_name>`. It then reads `.hooks[<stage>]` from THAT extension's manifest. Consequence: a preflight hook declared in the latex manifest fires if and only if `task_type == "latex"`. It never fires for any other task type. Additionally, when no extension matches the task type, `skill_get_extension_dir` returns empty and the function returns 0 immediately -- so core-typed tasks (`general`, `meta`, `markdown`) run NO lifecycle hooks whatsoever, from any extension.

WHY THIS MATTERS CONCRETELY. `agent-system/extensions/formal/manifest.json` routes ALL of `formal`, `formal:logic`, `formal:math`, and `formal:physics` implement operations to `skill-implementer` / `general-implementation-agent`. Philosophy and logic paper repositories are precisely where .tex files live, and `formal`-typed paper tasks are a normal, expected shape. The formal manifest declares NO top-level `hooks` object at all (verified: `.hooks` is null, `provides.scripts` is an empty array). So a `formal`-typed task that builds a .tex file receives zero protection from a latex-extension-only fix. The user flagged this explicitly: a latex-extension-only fix would not have covered the live incident that prompted this work. The same reasoning applies to `general`-typed tasks that happen to touch LaTeX.

DECISION TO MAKE -- WHERE THE UNCONDITIONAL PATH LIVES. Two structurally different options; choose one and record why:

  (i) AGENT-CONTRACT MANDATE. Add the guard obligation to `agent-system/extensions/core/agents/general-implementation-agent.md` and its twin `general-implementation-hard-agent.md`: before running any `pdflatex`/`latexmk` invocation, run the shared guard. Cheap, no harness change, and it composes with the "detect and refuse" mechanism (a contract can refuse; a non-blocking hook cannot). Weakness: it is instruction text an agent may skip, and it must be duplicated across the two twins.

  (ii) CORE-LEVEL UNCONDITIONAL CHECK. Add a task-type-independent guard invocation into `skill-base.sh` itself, running regardless of extension. Strongest coverage, and it survives agents ignoring instructions. Weaknesses: it touches the shared lifecycle spine that every skill in every repository depends on; it would run for every task type including ones that never touch LaTeX (mitigated if the guard is cheap and silent when no .tex conflict exists -- an explicit acceptance requirement of the core guard task); and, because hook/preflight failures are deliberately non-blocking, it still cannot ENFORCE a refusal on its own.

  A defensible outcome is BOTH: (ii) for detection and reporting, (i) for the refusal obligation. The user's framing invites exactly this ("the latex extension, a shared preflight hook, or both"). Do not silently pick the cheaper option without recording the tradeoff.

  A third possibility worth evaluating and rejecting explicitly: giving the formal extension its own preflight hook that delegates to the shared guard. This closes the `formal` case specifically but leaves `general`/`meta`/`markdown` uncovered and does not generalize -- it invites one hook per extension forever.

TWIN-FILE DISCIPLINE (binding). If option (i) is chosen, `general-implementation-agent.md` and `general-implementation-hard-agent.md` MUST be edited together in this task. A one-sided edit between engine twins is a known recurring defect class in this system. Do not assume the two files are line-symmetric; locate each site by content.

BLAST-RADIUS WARNING. If option (ii) is chosen, `skill-base.sh` is the shared lifecycle spine sourced by essentially every skill and deployed to roughly ten repositories. Changes there must be additive, must not alter existing hook ordering or the existing non-blocking semantics, and must be exercised against `agent-system/extensions/core/scripts/tests/test-skill-base-lifecycle.sh`, which already covers the hook-invocation contract.

FILE-SCOPE NOTE. This task's scope includes `agent-system/extensions/core/scripts/skill-base.sh`, which falls under the `agent-system/extensions/core/scripts/**` scope of the prerequisite core-guard task. That overlap is already serialized by the declared dependency, so no additional ordering constraint is needed -- but the two tasks must not be run concurrently.

SOURCE-STORE RULE (binding): all edits target `agent-system/extensions/core/**` (and `agent-system/extensions/formal/**` only if the rejected third option is nonetheless adopted). Never edit a deployed `.claude/**` tree.
DELIVERABLE RULE (binding): no task-number references in any file outside specs/.

ACCEPTANCE: a task-type-independent path exists by which an agent about to compile a .tex file consults the shared guard, demonstrably covering `formal`-typed and `general`-typed tasks; the (i)/(ii)/both decision is recorded with reasons, and the rejected per-extension-hook option is explicitly rejected in writing; if agent contracts were edited, both twins carry equivalent obligations; if `skill-base.sh` was edited, the change is additive, preserves existing hook ordering and non-blocking semantics, and the lifecycle test suite passes; no `.claude/**` file is modified.

---

### 75. Wire build guard into latex extension preflight hook and agent contracts
- **Effort**: 2 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: Task 74

**Description**: Wire the shared LaTeX build guard into the latex extension's lifecycle and contracts, so that `latex`-typed research and implementation dispatches detect (and, per the chosen mechanism, stop) a competing vimtex continuous build before the agent runs its own.

DEPENDS ON the core guard script task: this task consumes the script and its chosen mechanism, and must not re-litigate the mechanism decision.

HOOK MECHANISM (verified). `skill_run_extension_hook()` in `agent-system/extensions/core/scripts/skill-base.sh` (lines ~89-126) dispatches four lifecycle stages -- preflight, context_injection, verification, postflight -- to a script named in the extension's manifest under a TOP-LEVEL `hooks` object. This is distinct from `provides.hooks`, which is a file-copy target list; do not confuse the two. The preflight hook is invoked from `skill_preflight_update()` (line ~225) AFTER the status update. Hooks are non-blocking by design: a non-zero exit is caught and downgraded to a `[skill-base] WARNING` line, and execution continues. THIS IS A REAL CONSTRAINT ON THIS TASK -- if the chosen mechanism is "detect and refuse", a preflight hook CANNOT enforce the refusal on its own, because the harness ignores its exit code. In that case the refusal must additionally be carried in the agent contract text (the agent declines to build), with the hook serving as the detector and reporter. Resolve this explicitly rather than assuming a non-zero exit will stop anything.

REFERENCE IMPLEMENTATION. `agent-system/extensions/nix/scripts/nix-preflight.sh` is the only existing preflight hook in the source store and shows the exact contract: five positional args (`task_number`, `task_type`, `task_dir`, `session_id`, `operation`), `set -euo pipefail`, warnings to stderr, and `exit 0` even when warnings fired. The nix manifest declares it as `"hooks": {"preflight": "scripts/nix-preflight.sh", "context_injection": "scripts/nix-context.sh"}`. Only two extensions (nix, nvim) declare top-level hooks today, so this is a lightly-trodden path -- read both before writing.

DELIVERABLES.
  1. A new `agent-system/extensions/latex/scripts/` directory (it does NOT exist yet -- latex's `provides.scripts` is currently an empty array) containing a preflight hook that calls the shared core guard. The hook should be a thin adapter, not a reimplementation.
  2. `agent-system/extensions/latex/manifest.json`: add the top-level `hooks` object (preflight, and postflight if the restore/report decision requires it), and add the new script(s) to `provides.scripts`. Note the manifest currently has `"hooks": []` nested inside `provides` -- the new object is a SIBLING of `provides`, not a replacement for that field.
  3. `agent-system/extensions/latex/agents/latex-implementation-agent.md`: the build guidance is concentrated at lines ~38-62 ("Build Tools (via Bash)", listing `pdflatex`, `latexmk -pdf`, `latexmk -c`, with worked multi-pass examples) and recurs at lines ~97, ~134, and ~175 as bare build instructions. Line numbers verified at task-creation time and may drift; locate by content. Add the guard obligation, and add a MUST NOT item against running a build without first invoking the guard -- MUST NOT is the strongest lever these contracts have, and advisory prose buried mid-file is what gets skipped.
  4. `agent-system/extensions/latex/rules/latex.md`: the build-command block at lines ~74-93 presents `pdflatex`/`latexmk -pdf` with no concurrency caveat. Point it at the guard.
  5. `agent-system/extensions/latex/context/project/latex/tools/compilation-guide.md`: add a build-coordination section. This file already has "Automated Build", "Using latexmk", and ".latexmkrc Configuration" sections (lines ~46-60) that discuss latexmk without mentioning the watcher conflict, so it is the natural anchor. Per this extension's convention, put the explanatory prose HERE ONCE and have the agent/rules files reference it by path rather than restating it.

NO -HARD TWIN. Unlike the lean extension, latex declares no `routing_hard`/`routing_agents_hard` block and has no `-hard` agent variants, so there is no twin-file discipline burden here. `latex-research-agent.md` is a lighter touch -- research dispatches rarely build, but should not be silently exempt if the hook is manifest-level (the hook fires for ALL latex-typed operations, research included, since `operation` is only passed as an argument, not filtered on). Decide whether the hook self-filters on the `operation` argument.

SCOPE BOUNDARY. This task covers `latex`-TYPED tasks only. Coverage for agents that build .tex files under other task types is a separate task and must not be absorbed here.

SOURCE-STORE RULE (binding): all edits target `agent-system/extensions/latex/**`. Never edit a deployed `.claude/**` tree.
DELIVERABLE RULE (binding): no task-number references in any file outside specs/.

ACCEPTANCE: a latex preflight hook exists, is executable, is declared in the manifest's top-level `hooks` object, and is listed in `provides.scripts`; it delegates to the shared core guard rather than duplicating detection logic; the agent, rules, and compilation-guide files carry the obligation with prose stated once in compilation-guide.md and referenced elsewhere; the non-blocking-hook constraint is explicitly resolved (either the mechanism does not need enforcement, or the enforcement is carried in contract text); the operation-filtering decision is recorded; no `.claude/**` file is modified.

---

### 74. Add shared LaTeX build-conflict guard script (detect competing vimtex latexmk -pvc)
- **Effort**: 3 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: Task 130, Task 148

**Description**: Build a shared, task-type-agnostic guard script that detects a user-owned LaTeX continuous-build watcher (`latexmk -pvc`, typically driven by nvim's vimtex plugin) competing for the same .tex target an agent is about to build, and that can report, stop, and restore it. This task delivers the MECHANISM only; wiring it into lifecycle stages is handled by the two dependent tasks.

PROBLEM (observed live, not hypothetical). An agent ran `latexmk -pdf possible_worlds.tex` in a paper repo while the user's nvim vimtex continuous-mode compile was watching the same file. The two builds raced and corrupted aux files (null bytes, `^^@`). The failure mode is already documented in that repo's own CLAUDE.md under "Build Workflow: Preventing Aux File Corruption" -- but that documentation instructs a HUMAN to run `:VimtexStop` by hand. Nothing in the agent system detects, prevents, or even warns about it, so the user must notice and intervene manually every time an agent begins LaTeX work.

WHY THE EXISTING DEBOUNCE DOES NOT COVER THIS. The paper repo carries a `.latexmkrc` with `$sleep_time = 5` and a `$compiling_cmd` that pre-scans `build/*.aux` for null bytes and unlinks corrupted files. NOTE TWO CORRECTIONS TO THE ORIGINATING PROMPT, both verified at task-creation time: the file is at `JPL/.latexmkrc`, NOT the repo root; and the value is `$sleep_time = 5`, NOT the `2` that repo's CLAUDE.md claims (that CLAUDE.md is stale on this point -- do not propagate the wrong number). More importantly, `$sleep_time` debounces the file watcher WITHIN a single latexmk instance. It provides no coordination whatsoever between two SEPARATE latexmk processes, which is precisely the race here. The `$compiling_cmd` null-byte sweep is a post-hoc corruption cleanup, not prevention. Neither existing mechanism can solve this; a new one is required.

MECHANISM DECISION -- THIS IS THE CORE RESEARCH QUESTION. An agent cannot invoke a Vim command directly, so the shutdown path is non-obvious. Three candidates, to be evaluated and one (or a documented layering) chosen:

  (a) PROCESS TERMINATION. Detect a running `latexmk -pvc` whose target resolves to the .tex file about to be built, and SIGTERM it. Most reliable, most destructive -- it kills a process the user owns, and vimtex's own state will not know its child died, potentially leaving the plugin's status display stale or its callback machinery confused.

  (b) EDITOR REMOTE CONTROL. Use `nvim --server <socket> --remote-expr` (or `--remote-send`) against the live nvim instance to invoke VimtexStop. VERIFIED FEASIBLE IN THIS ENVIRONMENT: four live sockets were present at task-creation time under `/run/user/1000/` in the form `nvim.<PID>.0` (XDG_RUNTIME_DIR). This is the only option that leaves vimtex's internal state consistent, because vimtex itself performs the stop. Costs: it requires mapping socket -> the nvim instance that actually owns the target buffer (a socket exists per nvim instance, and most of them will be unrelated); `--remote-expr` executes arbitrary expressions in the user's editor, which is a real side effect deserving explicit justification; and it depends on vimtex being loaded in that instance.

  (c) DETECT AND REFUSE. Detect the conflict and emit a clear, actionable message -- naming the PID, the target file, and the exact `:VimtexStop` remedy -- then either warn-and-continue or refuse to build. Zero side effects on user-owned processes and zero remote editor control. The user's explicit steer is to PREFER THE LEAST DESTRUCTIVE OPTION THAT RELIABLY PREVENTS THE RACE, and to weigh killing a user process or driving their editor remotely against simply refusing with a clear message. Research should take that steer seriously rather than defaulting to (a) because it is easiest to implement. A defensible outcome is (b) with (c) as fallback when no owning socket can be identified, or (c) alone.

RESTORE-VS-REPORT DECISION. Also decide whether the agent restores continuous mode on exit or merely reports that it stopped it. The user's stated position: an agent that silently leaves the user's watch mode off is its own (smaller) annoyance. At minimum, whatever is stopped must be REPORTED. Restoration is materially easier under mechanism (b) (re-invoke VimtexCompile over the same socket) than under (a) (the script would have to reconstruct and relaunch a latexmk invocation it did not create -- generally a bad idea). Note that this decision is coupled to the mechanism decision and should not be made independently of it.

REUSABLE PATTERN -- `agent-system/extensions/core/scripts/claude-refresh.sh`. That script already solves the hard parts of safe process handling and should be read before writing anything new. It takes a single atomic `ps -eo` snapshot per invocation rather than re-querying live; it applies exclusion regexes so the script can never target itself or its own ancestry; it gates destructive action behind an explicit `--force` (the calling skill handles confirmation separately); and it escalates SIGTERM (`kill -15`) -> liveness recheck (`kill -0`) -> SIGKILL (`kill -9`) rather than killing outright.

SELF-MATCH HAZARD (verified concretely, do not skip). During task creation, a plain `pgrep -af latexmk` returned exactly one "match" -- the task-creating agent's OWN bash wrapper command, whose argv merely CONTAINED the string `latexmk`. A naive detector would therefore report a phantom conflict, and under mechanism (a) would attempt to kill the agent's own shell. Detection must match on the actual executable and its `-pvc` flag, resolve the build target, and exclude self/ancestry, exactly as claude-refresh.sh does. This is not a theoretical edge case; it fired on the first probe.

DELIVERABLE. A new executable script under `agent-system/extensions/core/scripts/` (suggested name `latex-build-guard.sh`; final name to be fixed during planning). Placement in CORE, not in the latex extension, is DELIBERATE and load-bearing: the two dependent tasks show that non-latex-typed tasks also run LaTeX builds, so the mechanism cannot live behind the latex extension's task-type gate. Suggested subcommand shape (refine during planning): a `detect` mode that reports conflicts and exits non-zero, a `stop` mode implementing the chosen mechanism, and a `restore`/`report` mode for the exit path. Modes should be separable so callers can adopt detect-only first.

The script must be registered in `agent-system/extensions/core/manifest.json` under `provides.scripts` alongside the ~124 existing entries so it is deployed.

SOURCE-STORE RULE (binding): all edits target `agent-system/extensions/core/**`. Never edit a deployed `.claude/**` tree -- those are disposable artifacts regenerated on reload, so such an edit silently vanishes.
DELIVERABLE RULE (binding): no task-number references in any file outside specs/.

ACCEPTANCE: the script exists, is executable, and is registered in core's `provides.scripts`; the chosen mechanism is implemented and the rejected candidates are recorded WITH REASONS in the task's artifacts; detection correctly distinguishes a real `latexmk -pvc` on the target .tex from a process whose argv merely contains the string, and never matches itself or its own ancestry; the restore-vs-report decision is recorded and implemented; whatever the script stops is always reported to the user; the script is safe and silent (exit 0, no output) when no conflict exists, since it will run on every applicable build.

---

### 51. Move session state files out of specs root
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 143, Task 209

**Description**: Stop session-scoped orchestration runtime files from accumulating at the specs/ root, and make the existing reap path actually run. Originally scoped as "move the files into a dot-prefixed directory"; widened after a manual cleanup swept 79 stranded files across 5 repos (oldest dated 2026-07-11), because relocation alone hides the clutter without stopping the growth.

Three parts:

(1) Relocation (original scope). Move .orchestrator-multi-state-{sid}.json and .return-meta-multi-{sid}.json out of the specs/ root into a dot-prefixed subdirectory (e.g. specs/.orchestration/), or handle otherwise as most appropriate. Must update every writer/reader, the reaper's glob roots, .gitignore patterns, check-runtime-file-tracking.sh's probe paths, and context/standards/orchestrator-runtime-files.md's Class Table.

(2) Reaper glob coverage gap. scripts/reap-session-runtime-files.sh sweeps ONLY the current hyphen-separated shapes (specs/.orchestrator-multi-state-*.json, specs/.return-meta-multi-*.json). Three superseded naming generations are therefore permanently unreapable and had to be deleted by hand:
  - un-suffixed:     .orchestrator-multi-state.json / .return-meta-multi.json
  - dot-separator:   .orchestrator-multi-state.sess_{sid}.json
  - .prev- variant:  .orchestrator-multi-state.prev-sess_{sid}.json
Additionally .return-meta-meta.json, .return-meta-meta-sess_{sid}.json, and .meta-return.json have NO writer or reader anywhere in agent-system/ or .claude/ (orphans of a superseded convention; .meta-return.json was also tracked in git and has since been removed). Decide per shape whether to widen the reaper's globs or to add a one-shot legacy-name migration, and ensure any relocation in part (1) does not create a fourth orphaned generation.

(3) Automatic invocation (root cause). The reaper is correct and works -- it cleared 41 of 41 files on first run -- but its ONLY trigger is a manual /refresh, so litter grows unbounded between refreshes. Wire reap into /todo, which is run far more often and is already the repo's housekeeping command. Call both scripts/reap-session-runtime-files.sh and task-lock.sh session-reap (stale .sessions/ registry entries accumulate identically -- 9 dead-pid entries were swept in nvim alone). Suggested hook point: a new stage between skill-todo's stage 10 ArchiveTasks and stage 15 GitCommit, so reaped paths land in the same commit; alternatively fold the reporting half into stage 3 DetectOrphans. Must stay non-blocking and honor the existing ORCHESTRATOR_SESSION_REAP_MIN threshold (default 240min) so in-flight batch runs are never reaped; echo the reaper's own output verbatim the way skill-refresh already does. Keep /refresh's invocation working unchanged.

Affected repos observed: nvim, BimodalLogic, cslib, ModelChecker, PersonalWebsite -- so the fix belongs in the core extension source store, not any single repo's deploy.

---

### 45. Global update extension repo registry
- **Status**: [NOT STARTED]
- **Task Type**: general
- **Topic**: neovim
- **Dependencies**: None

**Description**: TOPIC CORRECTION + BACKFILL NOTE (task-116 audit). This task carried topic core-agent-system, but its real scope (the <leader>al extension picker's 'Global Update' action) is nvim-config Lua UI code at lua/neotex/plugins/ai/claude/commands/picker/** and lua/neotex/plugins/ai/shared/extensions/**, NOT agent-system/extensions/** -- it is unrelated to the orchestrate-engine collapse. Re-topiced to neovim; file_scope backfilled from description evidence (was previously empty). Original description follows.\n\nImplement <leader>al repo registration and 'Global Update' action: when <leader>al loads extensions into other repos, register those repos and their loaded extensions in this nvim repo; add a 'Global Update' entry (similar to 'Reload All') that reloads all extensions already loaded in each registered repo, reporting any failures in a message and otherwise success as a count of the total

---

### 44. Slim commands/task.md, the largest per-invocation context contributor
- **Effort**: 2-4 hours
- **Status**: [PLANNED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 87, Task 149, Task 211
- **Research**: [044_slim_task_command_body/reports/01_command-body-extraction-approach.md]
- **Plan**: [044_slim_task_command_body/plans/01_task-command-mode-extraction.md]

**Description**: LOWER PRIORITY (per-invocation cost, not per-session). `commands/task.md` measures 37,465 bytes (~9.4k tokens) loaded on every `/task` invocation, plus ~2.8k tokens of imports it pulls in — the largest single per-invocation context contributor found by the context-loading audit. Slim the command body by moving reference material (long option tables, worked examples, edge-case narratives) into lazily-loaded context files under the core extension's context tree, keeping the command body to the decision logic and dispatch instructions an invocation actually needs. Preserve behavior: every mode (--recover, --expand, --sync, --abandon, multi-task creation) must remain fully specified — either inline or via an explicit pointer the executing agent is instructed to follow. Measure before/after bytes and record them in the implementation summary. CONSTRAINTS: all edits target agent-system/extensions/core/** (source store), never the deployed .claude/** tree; no task-number references in deliverables outside specs/**; do not change command behavior, only where its prose lives.

---

### 43. Decide and implement how email safety context actually reaches agents (live defect: five inert safety pointers)
- **Effort**: 1-3 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: None

**Description**: TOPIC CORRECTION (backlog streamline 2026-09-01): re-topiced core-agent-system -> extensions. This is email-extension-internal context-loading work, classified extension-internal by the consolidation audit, and is unrelated to the orchestrate-engine collapse. Original description follows.LIVE DEFECT, not an efficiency item: the email extension's five 'non-negotiable' safety context pointers (safety-invariants.md, wrapper-contracts.md, index-architecture.md, staleness-detection.md, archive-mode-risk.md) were written as `@.claude/context/...` imports in the merge-source era — a form that resolves to a nonexistent path and silently loads NOTHING. They have since been normalized to plain backticked paths (still non-loading by design), so the question the audit deferred is now unavoidable: how does safety-invariants.md actually reach an agent before it mutates a mailbox? Decide deliberately between: (a) making the safety pointers genuinely eager in the email extension's CLAUDE.md contribution, accepting roughly 13k tokens of every-session cost in deploys where email is loaded; (b) establishing that the wrapper contracts (five nix-built wrapper binaries as the only mutation path) plus the email skills'/agent's own explicit context-loading instructions already carry the enforcement, and recording that as the documented decision; or (c) a middle path such as eager-loading ONLY safety-invariants.md (the smallest, most critical file) while the rest stay lazy. Verify empirically what skill-email-cleanup, skill-email-sync, and email-implementation-agent load today before choosing. Whatever the choice, record it in the email extension's docs so the next audit does not re-litigate. CONSTRAINTS: all edits target agent-system/extensions/** (source store); no volatile files in any eager prefix; no task-number references in deliverables outside specs/**.

---

### 39. Upgrade Zotero metadata resolution and plan the Zotero 10 backend swap
- **Effort**: 3-6 hours
- **Status**: [PLANNED]
- **Task Type**: meta
- **Topic**: literature
- **Dependencies**: None
- **Research**: [039_zotero_metadata_resolution_upgrade/reports/02_zotero-metadata-resolution-design.md]
- **Plan**: [039_zotero_metadata_resolution_upgrade/plans/02_zotero-metadata-resolution.md]

**Description**: Upgrade the literature extension's Zotero integration beyond bare write-path activation: add a real metadata-resolution step for web-discovered sources, decide the MCP question, gate auto-attach on storage quota, and record the Zotero 10 backend-swap plan. Grounded in verified Aug-2026 tooling research — see the seed report before re-deriving any landscape claim.

=== WORK ITEMS ===

1. TRANSLATION-SERVER INTEGRATION (the pipeline's thinnest point today). The online ingest bridge currently relies on `zot add --pdf`'s DOI-from-PDF extraction for metadata, which fails on books, preprints without embedded DOIs, and scans. Integrate the official `zotero/translation-server` (HTTP, port 1969; service provisioning is the ~/.dotfiles repo's job — its task 129): call `POST /search` (DOI/ISBN/arXiv ID, preferred when Tier-3 discovery already has an identifier) or `POST /web` (URL fallback) to resolve full Zotero JSON BEFORE item creation, and pass that metadata through the create path. Degrade gracefully (current behavior) when the service is down, and surface which resolution path produced the record.

2. ZOTERO-MCP ADOPTION DECISION. Evaluate adding 54yyyu/zotero-mcp (de-facto standard, ~4.6k stars, hybrid mode = local-API reads + Web-API writes, add-by-DOI/URL/ISBN, OA-PDF cascade) as an INTERACTIVE complement for `/research --lit` sessions. The deterministic scripts remain the pipeline of record — community practice in 2026 is exactly this split. Deliverable is a recorded decision (adopt/defer with reasons); if adopted, registration scope and permission grants follow the grant-at-registration-scope principle already established for MCP servers in the ~/.dotfiles Claude configuration, and the registration itself lands there, not here.

3. STORAGE-QUOTA GATE. Stored-file uploads via the Web API count against the zotero.org 300 MB free tier (948 attachments already exist locally; the account's plan/usage is unverified). Verify quota state and encode an explicit auto-attach policy in the ingest bridge rather than discovering the ceiling by failure. Note the upload flow's `{"exists": 1}` content-hash dedup for PDF bytes.

4. ZOTERO 10 BACKEND-SWAP PLAN (plan, do NOT implement while 10 is beta). Zotero 10 ships native local writes (items + file upload) at `localhost:23119/api/` with consent-based local API keys via `POST /api/local/authorize` — eliminating cloud round-trips and the storage quota for attached files. Record the swap plan against the single write choke-point (`zotero-write.sh`) so callers never change; explicitly reject `/connector/saveItems` as a write contract (undocumented internal protocol).

=== ACCEPTANCE CRITERIA ===

1. Web-discovered sources get translation-server-resolved metadata when an identifier or URL is available, with honest surfacing of which resolution path was used and graceful degradation when the service is unreachable.
2. The MCP decision is recorded with reasons; no MCP registration or grants are hand-edited in this repo either way.
3. Auto-attach policy is explicit and quota-aware; no silent quota-exhaustion failure mode remains.
4. The Zotero 10 swap plan exists in the extension's context docs, names the choke-point, and states what stays constant for callers.

=== BINDING RULES ===

SOURCE-STORE RULE: all edits target agent-system/extensions/literature/**. NEVER edit the deployed .claude/** tree.
DELIVERABLE RULE: no task-number references in deliverables outside specs/**.

---

### 30. Register obsidian memory mcp server
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: Task 29

**Description**: TOPIC CORRECTION (backlog streamline 2026-09-01): re-topiced core-agent-system -> extensions, alongside its prerequisite (the .mcp.json generation mechanism). Unrelated to the orchestrate-engine collapse. Original description follows.Register the obsidian-memory MCP server through the new manifest-driven .mcp.json mechanism, and grant its tools at the matching scope.

CURRENT STATE: memory/settings-fragment.json carries a dead `mcpServers` block declaring obsidian-memory (npx -y @anthropic-ai/obsidian-claude-code-mcp@latest, with env OBSIDIAN_WS_PORT). It registers nothing, because settings files are not a registration surface. The memory extension IS loaded in this repository, so unlike the five retired servers this one is wanted and should be made to work.

WORK: move the declaration to the new merge target so it lands in .mcp.json, with an explicit "type": "stdio". Then determine the server's ACTUAL tool names and add matching permission grants to the fragment, applying the grant-at-registration-scope rule. Do NOT guess the tool names and do NOT copy them from any existing documentation: enumerate them empirically by starting the server and issuing a tools/list request. This system has already shipped documentation instructing agents to call MCP tools that never existed, and a naming mismatch between a declared server name and its granted mcp__<name>__* prefix has already been found in another extension -- verify both the server name and every tool name against the running server.

RUNTIME PREREQUISITE, DO NOT PAPER OVER: this server needs OBSIDIAN_WS_PORT set and a running Obsidian instance with the companion plugin. If that prerequisite cannot be satisfied in this environment, wire the declaration correctly, document the prerequisite plainly in the memory extension README, and report the tool-name enumeration as NOT VERIFIED rather than inventing plausible names. A truthful 'could not verify' is the correct outcome here; a fabricated tool list is not.

VERIFICATION: .mcp.json contains the entry after a fixture deploy; `jq empty` on both edited files; doc-lint passes for the memory extension; every granted mcp__ tool name either matches a name observed from the running server or is explicitly marked unverified with the reason. SOURCE-STORE RULE (binding): all edits target /home/benjamin/.config/nvim/agent-system/extensions/**. Never hand-edit any deployed .claude/** tree -- it is gitignored, disposable, and regenerated from the source store. DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 29. Generate mcp json from extension manifests
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: None

**Description**: TOPIC CORRECTION (backlog streamline 2026-09-01): re-topiced core-agent-system -> extensions. This is deploy-engine (lua merge-path) and manifest-surface work for extension MCP registration, unrelated to the orchestrate-engine collapse; the consolidation audit confirmed no overlap with the routing ladder it carries forward. Original description follows.Build the deploy-engine mechanism that lets an extension declare an MCP server and have it actually registered, by generating a project-scoped .mcp.json.

WHY THIS IS NEEDED: extensions currently express server declarations as `mcpServers` keys inside settings-fragment.json, which register nothing -- settings files are not a registration surface. Project-scoped .mcp.json IS a real registration surface, and it IS reachable by dispatched subagents (verified by direct experiment; the earlier belief to the contrary rested on a session-start snapshot confound). So the fix is to route declarations to a surface that works, not to abandon the idea of extensions declaring servers.

WORK: add a new manifest merge target -- e.g. `merge_targets.mcp` with a source file per extension -- that the deploy engine collects across all LOADED extensions and writes to the repository-root .mcp.json. Mirror the existing settings merge path (process_merge_targets / merge_settings in merge.lua) rather than inventing a second idiom: the existing path is an additive, idempotent deep-merge that does not clobber pre-existing content, and it deliberately targets a file that is NOT install-once, which is exactly the property needed here. Extend manifest_spec.lua so the new key validates.

REQUIREMENTS THE MECHANISM MUST SATISFY: (a) each generated server entry carries an explicit "type" field -- as of Claude Code v2.1.202 a remote server lacking an explicit type fails fast rather than failing silently, and all current declarations omit it; (b) unloading an extension must REMOVE its servers from .mcp.json, because an additive deep-merge alone never retracts, and a stale grant surviving an unload is an already-observed defect class in this system; (c) the operation must be idempotent -- deploying twice yields a byte-identical .mcp.json; (d) hand-written entries a user added to .mcp.json themselves must survive regeneration, or the file must clearly declare itself generated. Decide (d) explicitly and record the choice.

IMPORTANT CONTEXT: a project-scoped .mcp.json server requires workspace-trust approval before `claude mcp list` will read it (v2.1.196+), and a server added to .mcp.json is invisible to any ALREADY-RUNNING session. Both facts must be documented for users, or the mechanism will be reported as broken when it is working correctly. Verify against a fresh session or `claude -p`, never against the current one.

VERIFICATION: build a scratchpad fixture project, load an extension declaring a trivial stdio server, and confirm .mcp.json is generated correctly; confirm a second deploy is a no-op; confirm unloading removes the entry; confirm `claude mcp get <name>` in the fixture reports Scope: Project config. Do NOT deploy against this repository as part of verification. SOURCE-STORE RULE (binding): all edits target /home/benjamin/.config/nvim/agent-system/extensions/**. Never hand-edit any deployed .claude/** tree -- it is gitignored, disposable, and regenerated from the source store. DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 22. Freeze .opencode: silence fragment validation spam and record the frozen-mirror policy
- **Status**: [RESEARCHING]
- **Task Type**: meta
- **Topic**: opencode
- **Dependencies**: None

**Description**: === REVISED 2026-09-01 (backlog streamline: .opencode declared FROZEN) ===
POLICY SETTLED BY USER DECISION: .opencode/ is FROZEN -- not maintained, not generated, not deleted. No sync mechanism will be built (the sibling sync-mechanism task is abandoned with a pointer here); the tree is preserved intact for possible future refactoring, exactly as this task's binding constraint already required. This settles the reframed design question below ("SHOULD opencode-agents.json fragments reference a per-project deploy tree at all?"): under a frozen mirror, no path corrections are owed and defect class (1) breakage is expected and tolerated -- the fix is to stop the noise and record the policy, not to repair paths that will drift again.

REVISED SCOPE, absorbing the narrowed remainder of the abandoned sync-mechanism task:
1. SILENCE THE SPAM (original core): gate or suppress the ~60-notification validation spam on <leader>al reload (emitter: M.generate_opencode_json / validate_opencode_fragment in lua/neotex/plugins/ai/shared/extensions/merge.lua). Under the frozen policy, missing {file:} deploy targets are an EXPECTED state; the validator must not shout about them on every reload. Prefer gating generation/validation behind the frozen policy (skip, or a single-line summary) over deleting the mechanism -- the binding constraint that no opencode fragment, validator function, or .opencode/ file is deleted still holds.
2. FIX THE ONE FAKE-TOOL LINE (from the absorbed task): .opencode/extensions/web/agents/web-implementation-agent.md still teaches browser_verify_text_visible as a real tool; the source store explicitly retracts it. A frozen mirror may drift, but it must not actively teach a nonexistent tool. One-line fix, editing .opencode/** directly (it has no source-store counterpart; the source-store/deploy-boundary rule does not apply to this tree).
3. RECORD THE POLICY where the next person will look (e.g. a note in .opencode/ and/or the extensions docs): the tree is frozen, unmaintained, drift-expected, and preserved for future refactoring.
ACCEPTANCE: a <leader>al reload from a project carrying an opencode.json.managed marker produces no validation-failure spam; the fake tool name no longer appears as usable guidance in .opencode/; the frozen policy is written down; nothing under .opencode/ is deleted.
=== ORIGINAL DESCRIPTION FOLLOWS ===
=== REVISED 2026-08-24 (refactor survey) ===
SUBSTANTIALLY OVERTAKEN, and the remaining half got worse. Re-verified today:
- Defect class (3) is FIXED. merge.lua:1002-1041 now degrades per-agent-key, reports every missing key rather than only the first, and no longer discards a whole fragment. Close it out; do not re-fix.
- Defect class (2) MOVED rather than got fixed. The archived path-fix work changed the lean fragment to reference .claude/agents/lean-research-agent.md instead of .claude/extensions/lean/agents/... -- but that path does not exist either.
- Defect class (1) is WORSE: 30 of 34 {file:} refs across all fragments now point at nonexistent files (was 16 of 18). Only nvim and nix resolve, because those are the extensions loaded in this repo -- which is itself the clue.
REFRAME around the one live question rather than patching paths again: SHOULD opencode-agents.json fragments reference a per-project deploy tree at all? Every {file:} ref is per-repo-deploy-dependent by construction, so any path fix is correct only for the extension set of whichever repo it was fixed in. That is why class (1) keeps regrowing. Answer the design question first; the path corrections fall out of it.
=== ORIGINAL DESCRIPTION FOLLOWS ===
Silence and correct opencode-agents.json fragment validation spam on extension reload.

SYMPTOM (observed live): reloading .claude/ via <leader>al from a project with an
opencode.json.managed marker emits ~60 WARN notifications of the form "Extension 'X'
opencode-agents.json validation failed: Agent 'Y' references missing file: Z. Skipping
fragment." before "Resynced 12 extension(s)".

EMITTER: M.generate_opencode_json in lua/neotex/plugins/ai/shared/extensions/merge.lua
(vim.notify at ~line 994), gated on an opencode.json.managed marker check (~line 931), with
per-fragment validation by M.validate_opencode_fragment (~line 887), which resolves each agent
prompt's {file:PATH} against project_dir.

THREE DISTINCT DEFECT CLASSES (measured against a live project, not assumed):

(1) MISSING DEPLOY TARGETS -- 16 of 18 {file:} refs across python (2), present (5), nix (2),
and filetypes (7) point at .opencode/agent/subagents/*-agent.md files that were never
deployed. The .opencode/agent/subagents/ directory DOES exist and holds 15 agent files
(core, lean, latex, typst, math, logic, physics, formal, meta-builder, planner,
code-reviewer), but none for those four extensions. So this is a partial-deploy gap, not a
wholly absent tree.

(2) LEAN WRONG-PATH BUG (independent of any opencode policy decision) --
agent-system/extensions/lean/opencode-agents.json is the ONLY fragment using a .claude/ path
shape. It references .claude/extensions/lean/agents/lean-research-agent.md and
.claude/extensions/lean/agents/lean-implementation-agent.md, neither of which exists anywhere,
while the CORRECT files .opencode/agent/subagents/lean-research-agent.md and
.opencode/agent/subagents/lean-implementation-agent.md ALREADY EXIST on disk. This is a plain
mis-pathed reference, fixable on its own merits regardless of what is decided about opencode.

(3) NOTIFICATION SPAM AND SIMULTANEOUS UNDER-REPORTING -- the same 5 messages repeat ~12 times
because generation runs once per resynced extension rather than once per reload. Separately,
validate_opencode_fragment iterates with pairs() and returns on the FIRST missing ref, so only
one broken ref per extension is ever named, and WHICH one varies nondeterministically between
runs (python alternates python-research/python-implementation; filetypes alternates
scrape/filetypes-spreadsheet). The true breakage (18 refs) is therefore both over-announced in
aggregate and under-reported per message.

BINDING CONSTRAINT (from the user): .opencode/ is NOT currently used and may be excluded from
scope, BUT the fix MUST NOT damage or delete .opencode/ infrastructure. The opencode-agents.json
fragments, the validator function, the managed-marker gating, and the existing .opencode/ tree
must all survive intact so .opencode/ can be refactored in the future. Prefer suppressing or
gating the noise over removing the mechanism.

ACCEPTANCE: a <leader>al reload from a project carrying an opencode.json.managed marker
produces no validation-failure spam; the lean fragment's two refs resolve to real files;
whatever gating approach is chosen is documented; and no opencode fragment, no validator
function, and no .opencode/ file is deleted.

SOURCE-STORE RULE (binding): edit lua/** for the Lua emitter and agent-system/extensions/** for
the JSON fragments; never edit .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 14. Prevent implementation-agent fan-out from returning non-terminal status and stale plan markers
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 88, Task 139, Task 213, Task 214

**Description**: === REVISED 2026-08-24 (refactor survey) ===
NARROWED: roughly half of this task already landed with the handoff-identity work and must not be redone. skill-orchestrate/SKILL.md:2374,2384 now treats in_progress (and null/empty) as OFF-SCHEMA rather than routing it toward failed_tasks, and orchestrate-recover-outcome.sh:233 emits a clean STATUS_IN_PROGRESS verdict. Verified in the source store today.
WHAT REMAINS is the AGENT-CONTRACT side only, and it is untouched: general-implementation-agent.md contains NO fan-out prohibition, and NO requirement that a sub-agent which commits a phase must update that phase's marker in the same commit. Both gaps are what produced the original symptom -- dispatches fanning out to phase sub-agents and terminating before writing a terminal status, leaving plan markers reading [NOT STARTED] against landed commits.
Rescope to those two contract additions. Do not re-litigate the status-vocabulary half.
=== ORIGINAL DESCRIPTION FOLLOWS ===
Two dispatches in a single batch fanned out to phase sub-agents and terminated before writing a terminal status, costing a recovery cycle each. Recorded as err_1786344051474_RcIhk6.

OBSERVED FAILURE MODE: a dispatched implementation agent spawned per-phase sub-agents, returned while they were still running, and left .return-meta.json at status=in_progress. Per context/formats/return-metadata-file.md that value is early-metadata-only and never a legal terminal dispatch outcome, so orchestrate-recover-outcome.sh correctly declines it (reason STATUS_IN_PROGRESS). The orchestrator contract for an unresolvable dispatch is failed_tasks - which would have been WRONG here, since 6 of 10 phases had in fact been committed. Correct handling came from rules/error-handling.md Delegation Interrupted Recovery (keep status, resume), not from the orchestrator stage contract.

COMPOUNDING DEFECT - STALE PLAN MARKERS: the sub-agents committed phases 3, 4, 5 and 7 but left every one of those phase markers reading [NOT STARTED]. Because the orchestrator phase-marker recovery grep reads exactly those markers, it would have reported 2/10 against a true 6/10. A resume driven by markers alone would have redone committed work. Recovery only succeeded because the actual state was reconstructed from git log and diffs instead.

TWO INDEPENDENT QUESTIONS, BOTH IN SCOPE:
  1. Should a dispatched implementation agent fan out to sub-agents at all? If yes, it must still write a terminal status covering its childrens work; if no, the prohibition belongs in the agent contract, not in per-dispatch prompt text (the workaround used during the incident).
  2. Should a sub-agent that commits a phase be required to update that phases marker in the same commit? Markers and commits diverging silently is the deeper defect - it degrades the recovery path for every future interrupted dispatch, not just fan-out ones.

CONSIDER ALSO: whether the orchestrator should treat status=in_progress plus evidence of committed phase work as PARTIAL/resume rather than routing it toward failed_tasks, so correct handling does not depend on an operator noticing.

ACCEPTANCE: an interrupted fan-out dispatch is either impossible by contract, or leaves markers and terminal status accurate enough that resume needs no manual git archaeology.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

=== REVISED 2026-08-24 (second live occurrence, extension-agent gap) ===
RECURRED, AND THE CONTRACT GAP IS WIDER THAN THIS TASK'S CURRENT SCOPE. A seven-task lean4 batch
orchestrated in a separate consumer repo reproduced this exact failure mode TWICE in one
implementation cycle: two of seven dispatches performed real work, committed it, and then
terminated WITHOUT writing a terminal handoff, leaving .return-meta.json at status=in_progress.
orchestrate-recover-outcome.sh correctly declined both (STATUS_IN_PROGRESS); both needed a
re-dispatch cycle to resolve, exactly as the original incident did.

SCOPE CORRECTION (the actionable part). Both offending dispatches ran
extensions/lean/agents/lean-implementation-agent.md, NOT
extensions/core/agents/general-implementation-agent.md -- the only agent contract this task's
file_scope currently names. The terminal-status requirement is therefore missing from the
EXTENSION implementation agents as well as the core one, and fixing only the core file would
leave the reproducing path untouched. file_scope is extended accordingly to the lean pair. Treat
the core agent as the normative contract and the extension agents as required conformers; if a
shared include or a single normative statement referenced by all implementation agents is the
better mechanism, prefer that over copying the same paragraph into four files.

MARKER DIVERGENCE RECURRED IN THE OPPOSITE DIRECTION -- fold into question 2, do not treat as a
separate concern. The original incident recorded markers UNDER-claiming (phases committed, markers
still [NOT STARTED]). This batch recorded the inverse: one task's plan carried five of seven
phases marked [COMPLETED] while its sole declared file_scope target was UNMODIFIED against HEAD --
markers OVER-claiming against work that had not landed. A resume driven by those markers would
have skipped real work rather than redone it. Both signs share one root cause, which question 2
already names: markers and committed reality are allowed to diverge silently. Any fix must be
bidirectional -- a marker must not be promotable without the corresponding work being verifiable,
and committed work must not leave its marker unpromoted. The over-claim direction was only caught
because the orchestrator cross-checked the marker count against the working tree; a fix that
merely tightens promotion-on-commit would not have caught it.

WHAT IS ALREADY GOOD AND MUST NOT BE UNDONE. The re-dispatch path worked: both tasks resumed from
their real state and completed, and the resumed dispatches -- when explicitly instructed to write
the handoff FIRST and to re-verify prior phase markers with a real build rather than trust them --
both reported correctly and downgraded nothing falsely. That per-dispatch prompt text is the
workaround this task exists to retire; it is evidence the contract wording works, not a substitute
for putting it in the contract.

ACCEPTANCE (extends, does not replace, the original): the terminal-status requirement and the
fan-out resolution apply to extension implementation agents as well as the core one, demonstrated
against a lean4 dispatch; and marker/reality divergence is caught in BOTH directions.
