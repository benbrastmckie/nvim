# Research Report: Task #236

**Task**: 236 - Define external process wait pattern
**Started**: 2026-09-18T00:00:00Z
**Completed**: 2026-09-18T00:00:00Z
**Effort**: small
**Dependencies**: None (cross-references task 172, not a dependency)
**Sources/Inputs**: Codebase exploration (agent-system/extensions/core/context/patterns/,
context/contracts/wrap-up.md, index-entries.json, specs/TODO.md)
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- No existing core context pattern states the "bounded external-process wait" discipline. The
  closest neighbors are `checkpoint-before-overflow.md` (context-pressure handoffs, not
  process-wait), `dispatch-report-not-termination.md` (report != termination, root cause for why
  a woken watcher/Monitor is dangerous), and `context/contracts/wrap-up.md`'s "Teardown Precedes
  the Terminal Handoff Write" section (requires tearing down `run_in_background`/watchers before
  the terminal handoff, but says nothing about how to wait in the first place).
- Task 172 ("Define a canonical bounded-wait idiom for detached builds",
  `context/patterns/bounded-build-waiter.md`) is `[NOT STARTED]` and its file does not exist yet.
  Task 236 is landing first, so per the dispatch's cross-reference instruction, 236's new file
  should add the forward pointer to `bounded-build-waiter.md` by filename now (the file need not
  exist yet); task 172, landing second, will add the reciprocal pointer back.
- The exact incident mechanics (harness blocks foreground `sleep`; unbounded `gh run watch` hits
  the 600s Bash tool timeout and gets auto-backgrounded; a Monitor loop that echoes on every poll
  wakes the agent on every UNCHANGED status; ending a turn terminates a subagent, so the agent
  fills gaps with no-op Bash calls) is not documented anywhere in the codebase today — this is
  new content, not a restatement of an existing rule.
- Recommended approach: create `agent-system/extensions/core/context/patterns/external-process-wait.md`
  stating the defect class once, with the six mandatory rules from the dispatch verbatim, add an
  `on_demand: true`, empty-`agents[]` index-entries.json entry (Tier 4 discoverability, matching
  the classification convention already used for `checkpoint-execution.md`,
  `context-discovery.md`, and `early-metadata-pattern.md`), and add a single-line pointer from
  `anti-stop-patterns.md` rather than restating the rules there.

## Context & Scope

Researched what already exists in the core context-pattern layer for (a) bounded waiting on
external/remote processes, (b) the no-op-filler anti-pattern the incident produced, and (c) the
index-entries.json and "single-statement-plus-pointer" conventions the new file and its pointer
must follow. Scope is research only — the actual file writes belong to the plan/implement phases
that follow this dispatch. Per the dispatch: OUT OF SCOPE for this whole task are agent-contract
edits, `orchestrate-build-dispatch.sh`, and any hook.

## Findings

### Codebase Patterns

- **`agent-system/extensions/core/context/patterns/anti-stop-patterns.md`** (174 lines): documents
  the *opposite* failure mode from this task's incident — a subagent stopping too early because it
  returned a forbidden status value/phrase (e.g. `"completed"`). It has an "Enforcement Points"
  section listing 4 fix sites and a "Background References" section citing two prior incident
  reports (`specs/480_.../reports/01_workflow-delegation-research.md`). This is the natural home
  for the dispatch's requested one-line pointer: the new pattern is about *filling gaps while
  legitimately blocked* (never with no-op Bash calls or status-only turns) — a companion defect to
  "premature stop," not the same one. The pointer should distinguish, in one line, "no-op filler to
  avoid looking finished" from "forbidden status value" rather than conflating them.

- **`agent-system/extensions/core/context/patterns/dispatch-report-not-termination.md`** (69
  lines): the exact "single-statement-plus-pointer" convention the dispatch asks the new
  anti-stop-patterns.md pointer to follow. Its own "Where This Is Referenced" section is the model:
  three fix sites, each given one line, e.g. (from `orchestrator-runtime-files.md`):
  `` `context/patterns/dispatch-report-not-termination.md` — see that file rather than restating
  it ``. Also directly relevant substantively: its "Tear Down Watchers/Monitors Before Reporting"
  section already establishes that an agent arming a watcher/Monitor and then reporting leaves a
  dangling wake path — this is the root-cause justification for mandatory rule (3) in the
  dispatch (no `run_in_background`/Monitor for CI waits inside a subagent).

- **`agent-system/extensions/core/context/contracts/wrap-up.md`**, "Teardown Precedes the Terminal
  Handoff Write" (~line 178): requires any `run_in_background` Bash invocation, watcher, or
  monitor loop armed during a dispatch to be torn down before the terminal
  `.orchestrator-handoff.json` write, citing `dispatch-report-not-termination.md`. This is a
  downstream consequence-side rule ("clean up before you report"); it does not itself state how to
  wait, so it is not a duplicate of the new file's mandate — the new file should probably note it
  under "Related" as the file that already forbids leaving such a job running at report time,
  rather than restate the requirement.

- **`agent-system/extensions/core/context/patterns/checkpoint-before-overflow.md`** (178 lines):
  good structural/stylistic template for the new file — `**Created**`/`**Purpose**`/`**Audience**`/
  `**Related**` header block, a decision-table format for branching rules, and a closing "Related
  Documentation" bullet list. No content overlap (it's about context-pressure handoffs, not
  external-process waits), but its header conventions and its own "Research-Shaped Handoff
  Guidance" subsection (distinguishing research-agent handoffs from the H9 hard-mode schema) is a
  good precedent for how the new file's rule (6) TOTAL-WAIT-CAP handoff guidance should be phrased
  (point at `../formats/handoff-artifact.md`, not invent a new schema).

- No file anywhere in `agent-system/extensions/core/` currently mentions `gh run watch`,
  `run_in_background`-for-CI, or a Bash-tool-timeout-vs-inner-timeout relationship (confirmed via
  `grep -rln "gh run watch\|run_in_background" agent-system/extensions/core/` — only
  `context/contracts/wrap-up.md` and one test script matched, both for the generic
  watcher-teardown rule, not CI specifically). The 540s-vs-600s inner/outer timeout relationship
  named in the dispatch is entirely new content.

- **Task 172 status**: `specs/TODO.md` shows `172 [NOT STARTED] — Define a canonical bounded-wait
  idiom for detached builds`, and `context/patterns/bounded-build-waiter.md` does not exist in the
  repo yet (`find` returned nothing). Task 236 (this task) is therefore the one "landing first" of
  the pair; per the dispatch's own instruction ("whichever lands second adds the reciprocal
  pointer"), 236's new file should add the forward pointer to `bounded-build-waiter.md` by filename
  now, and no edit to that (nonexistent) file is needed or possible from this task.

- **index-entries.json schema** (`agent-system/extensions/core/index-entries.json`, confirmed by
  reading several `patterns/*.md` entries): each entry is `{path, domain, subdomain, summary,
  line_count, keywords[], topics[], load_when: {agents[], task_types[], commands[]}, on_demand?}`.
  Entries meant for situational/on-demand loading (not eagerly injected into every agent's
  context) set `"on_demand": true` AND leave `load_when.agents` empty — e.g.
  `checkpoint-execution.md`, `context-discovery.md`, `early-metadata-pattern.md` all follow this
  shape. This matches a retrieved memory from a prior task: *"When classifying context index
  entries as Tier 4 (on-demand), also clear their agents[] array — entries still in agents[] are
  auto-loaded at agent spawn regardless of tier label. Tier labels in index.json are documentation
  only; load_when arrays are the actual enforcement mechanism."* The new entry should follow this
  same shape: `on_demand: true`, `load_when.agents: []` (this is a situational pattern relevant
  only when an agent is actually blocked on a long remote job, not something every dispatch needs
  eagerly), `subdomain: "patterns"`, `domain: "core"`.

### External Resources

Not applicable — this is a purely internal documentation/process-convention task with no external
API or library surface; no web research was needed or performed.

### Recommendations

1. **Create** `agent-system/extensions/core/context/patterns/external-process-wait.md` with this
   header/structure (mirroring `checkpoint-before-overflow.md`'s conventions):
   - `**Created**: 2026-09-18`
   - `**Purpose**`: state the defect class once (no-op filler / premature stop-avoidance during
     long external waits) and the sanctioned wait discipline, generalized beyond GitHub Actions to
     any remote/external job with no local writer to probe.
   - `**Audience**`: any subagent dispatched under `/orchestrate` that must block on a long
     external process (general-implementation-agent primarily; phrase generally, not agent-specific,
     since this is a situational context pattern, not an agent contract).
   - `**Related**`: `dispatch-report-not-termination.md` (why watchers/Monitor left armed are
     dangerous), `context/contracts/wrap-up.md` (teardown-before-report), `checkpoint-before-overflow.md`
     (sibling context-pressure pattern, different trigger), `../formats/handoff-artifact.md` (the
     handoff template rule (6) points at), and — by filename only, file not yet created —
     `bounded-build-waiter.md` (task 172's planned local-detached-build counterpart; note the
     local-writer-probe vs. no-local-writer distinction explicitly, one paragraph, per the
     dispatch's cross-reference instruction).
   - **Incident section**: state the four-part observed defect once, concretely (harness blocks
     foreground `sleep`; unbounded `gh run watch` exceeds the 600s Bash-tool timeout and gets
     auto-backgrounded; a Monitor loop that echoes every poll wakes the agent on every UNCHANGED
     status; a subagent that ends its turn terminates, so it fills gaps with ~130 no-op Bash calls
     plus status-only text turns until manually stopped).
   - **The six mandatory rules**, transcribed from the dispatch verbatim, each as its own
     subsection:
     1. BOUNDED BLOCKING WAIT — exact command `timeout 540 gh run watch ID --interval 60
        --exit-status >/dev/null; gh run view ID --json status,conclusion`, Bash tool timeout
        parameter set to 600000ms, repeated only while status is `in_progress`/`queued`. Explain
        the 540-vs-600 relationship explicitly: the inner `timeout` must fire and return control to
        the agent *before* the harness's own 600s auto-background threshold would otherwise silently
        move the call to the background — giving a ~60s margin so the agent always regains a
        foreground turn to decide whether to loop again, not a background completion it cannot
        see synchronously.
     2. NO NO-OP FILLER — explicit list of forbidden constructs: `:`, `true`, `date`,
        `echo waiting`-style Bash calls, and status-only text turns whose only purpose is to keep a
        turn alive.
     3. NO `run_in_background` AND NO Monitor for CI waits inside a subagent — cite
        `dispatch-report-not-termination.md`'s "Tear Down Watchers/Monitors Before Reporting"
        section as the root-cause explanation (a background completion or Monitor event wakes an
        agent that has nothing left to do, and ending the turn terminates the subagent — so the
        wake either arrives at a dead agent or resurrects a "terminated" one, which is exactly the
        Defect-A/Defect-5 hazard that file names).
     4. Where Monitor IS legitimately used (top-level/orchestrator session, not a dispatched
        subagent): its loop must emit ONLY on a state change, never on every poll — name the
        incident's own Monitor misuse (echo on every 20-90s poll) as the negative example.
     5. DO INDEPENDENT LOCAL WORK FIRST — finish every task step that does not depend on the
        external result before entering the wait; only enter the bounded wait once genuinely
        blocked.
     6. TOTAL-WAIT CAP of about 45 minutes — on reaching it, write a handoff (per
        `../formats/handoff-artifact.md`, the same `partial`/`handoff_path` contract other
        research/implementation handoffs already use) containing a concrete continuation (the run
        ID, the exact resume command, what remains), and return `status: "partial"` rather than
        continuing to wait. Do not use `"completed"` or any anti-stop-forbidden value here — cross
        reference `anti-stop-patterns.md`.
   - **Generalization note**: one short paragraph making explicit that "gh run watch" is the
     concrete first instance but the discipline generalizes to any remote job with no local
     process to `kill -0` — anything polled via a CLI/API status call (other CI systems, remote
     build services, long-running external jobs) should use the same bounded-poll-and-cap shape.

2. **Add an index-entries.json entry** immediately after the existing `patterns/early-metadata-pattern.md`
   entry (alphabetical-ish neighbor grouping already used in that file) or in natural path-sorted
   position among the `patterns/*.md` entries:
   ```json
   {
     "path": "patterns/external-process-wait.md",
     "domain": "core",
     "subdomain": "patterns",
     "summary": "Bounded-wait discipline for a subagent blocked on a long external process (CI runs, remote jobs)",
     "line_count": 0,
     "keywords": ["external-process", "gh-run-watch", "bounded-wait", "monitor", "no-op-filler", "timeout"],
     "topics": ["workflow", "orchestration"],
     "load_when": {
       "agents": [],
       "task_types": [],
       "commands": []
     },
     "on_demand": true
   }
   ```
   (`line_count` should be corrected to the actual written file's line count at implementation
   time — the value above is a placeholder, not a measured figure.)

3. **Add a one-line pointer in `anti-stop-patterns.md`**, following the exact
   single-statement-plus-pointer convention `dispatch-report-not-termination.md` itself uses (see
   Findings above) — do not restate the six rules. Suggested placement: a new short bullet or
   sentence near the "Required Patterns" or "Background References" section, phrased to
   distinguish this defect (no-op filler while legitimately blocked) from the file's own subject
   (forbidden status values causing premature stop) — e.g. a line such as: "A different failure
   mode — filling a legitimate external-process wait with no-op Bash calls or status-only turns
   instead of stopping cleanly — is covered separately; see
   `context/patterns/external-process-wait.md`." Exact wording is an implementation-phase decision;
   this report identifies the placement and convention only.

4. **Cross-reference to task 172 / `bounded-build-waiter.md`**: since that file does not exist yet,
   the new file's `**Related**` header line and/or a short "Related Documentation" bullet should
   name it by filename (`context/patterns/bounded-build-waiter.md`) with a one-sentence scope
   distinction (local detached-build writer-liveness via `kill -0`, one-waiter-per-log, vs. this
   file's remote/external no-local-writer case) so a reader lands on the right pattern. No edit to
   `bounded-build-waiter.md` is possible or required now; task 172 will add the reciprocal pointer
   when it lands.

## Decisions

- The new pattern file's canonical path is `agent-system/extensions/core/context/patterns/external-process-wait.md`
  (source store, never `.claude/**`), matching the dispatch's named deliverable path exactly.
- The index entry will use `on_demand: true` with an empty `load_when.agents` array (Tier 4
  discoverable-on-demand classification), not eager agent-scoped loading — this is a situational
  pattern, not something every dispatch needs injected by default.
- The `anti-stop-patterns.md` edit is a single pointer line, not a restatement — per the dispatch's
  explicit instruction to follow the `dispatch-report-not-termination.md` convention.
- No edit to `bounded-build-waiter.md` is made or attempted (task 172 is `[NOT STARTED]`, file does
  not exist); the new file forward-references it by filename only.

## Risks & Mitigations

- **Risk**: the 540/600 relationship is easy to get backwards or under-explained in the actual
  file. **Mitigation**: the plan/implementation phase should state the arithmetic explicitly (540
  + a ~60s margin < 600s harness auto-background threshold) rather than leaving the reader to infer
  it, exactly as the dispatch itself requires ("Explain why 540 < 600").
- **Risk**: conflating this file's "no-op filler" defect with `anti-stop-patterns.md`'s "forbidden
  status value" defect when writing the pointer line, producing a restatement instead of a pointer.
  **Mitigation**: keep the pointer to one sentence that names the distinct trigger (legitimate
  external wait vs. premature-stop avoidance) and links out, matching the model in Findings above.
- **Risk**: index-entries.json entry drifting from the real line count or from the repo's existing
  key ordering/style, causing an extension-docs gate flag. **Mitigation**: implementation phase
  should measure the actual file's line count and copy the exact key ordering/style of a
  neighboring `on_demand: true` entry (e.g. `early-metadata-pattern.md`) rather than freehand it.
- **Risk (territory)**: sibling tasks 228 and 235 are concurrently dispatched this cycle. Task 228's
  file_scope does not overlap `context/patterns/external-process-wait.md`,
  `context/patterns/anti-stop-patterns.md`, or `index-entries.json`. Task 235 declared no
  file_scope (may touch anything). **Mitigation**: per territory contract, re-read each target file
  immediately before editing/committing in the implementation phase, and stage/commit only this
  task's own hunks.

## Context Extension Recommendations

- **Topic**: bounded-wait idioms for both local (task 172, not yet written) and remote (this task)
  processes are two halves of one conceptual pair with no shared index umbrella today.
  **Gap**: neither file exists to cross-reference the other bidirectionally yet (172 not started).
  **Recommendation**: once task 172 lands, verify its file adds the reciprocal pointer back to
  `external-process-wait.md`, closing the loop this report's Decisions section opened.

## Appendix

- Search queries / commands used: `find ... -iname "*stop*" -o -iname "*dispatch-report*" -o
  -iname "*bounded*"`; `grep -n '"patterns/' index-entries.json`; `grep -rln "gh run watch\|
  run_in_background\|Monitor tool\|background process" agent-system/extensions/core/`; `grep -n
  "172" specs/TODO.md`; `grep -n "dispatch-report-not-termination" context/contracts/territory.md
  context/standards/orchestrator-runtime-files.md`.
- Files read in full or in relevant part: `anti-stop-patterns.md`, `dispatch-report-not-termination.md`,
  `checkpoint-before-overflow.md`, `context/contracts/wrap-up.md` (Teardown section),
  `index-entries.json` (schema sample, `patterns/*` entries), `specs/TODO.md` (task 172 status).
