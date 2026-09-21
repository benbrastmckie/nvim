# Research Report: Task #172

**Task**: 172 - Define a canonical bounded-wait idiom for detached builds
**Started**: 2026-09-21T00:00:00Z
**Completed**: 2026-09-21T00:00:00Z
**Effort**: 2-3 hours
**Dependencies**: None
**Sources/Inputs**: Codebase (agent-system/extensions/core, agent-system/extensions/lean),
specs/state.json and specs/TODO.md task descriptions (172, 173, 174), existing sibling pattern
files
**Artifacts**: - `specs/172_bounded_build_waiter_idiom/reports/01_bounded-build-waiter-idiom.md`
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The gap is real and already half-acknowledged in the source store: `external-process-wait.md`
  (the remote-wait sibling, task-created earlier) already names `bounded-build-waiter.md` twice
  — in its `Related:` header and in a dedicated "Local vs. Remote Waits" section — but that file
  was never written. The pointer currently dead-ends. This task's deliverable fills that hole
  rather than inventing a new anchor slot.
- The safe local-wait idiom is not novel to invent: `lake-build-guard.sh`'s own header and
  `print_help()` already document and mandate exactly this shape for waiting on **its own**
  in-flight build record — `while kill -0 "$holder_pid" 2>/dev/null; do sleep 1; done`, with an
  explicit prohibition on `pgrep -f` self-matching. The new pattern file should state this as the
  canonical general idiom (generalized to "a detached local command", not guard-specific) and
  cite the guard as prior art, adding the two properties the guard's own idiom does not yet state
  for the general case: a hard timeout and one-waiter-per-log enforcement.
- Three evidence rounds converge on four mandatory properties, not three as originally scoped:
  (1) hard timeout, (2) writer-liveness via captured PID (`kill -0 "$pid"`, never `ps`/`pgrep`
  name-matching — sharpened explicitly by the third evidence round's self-matching `ps aux | grep`
  hang), (3) one-waiter-per-log enforcement, and a required disposition for what a second
  would-be waiter does (attach vs. fail loudly) given the "Monitor is already watching" turn-ending
  incident. The turn-ending failure mode (agent stops instead of polling) must be named in the
  pattern file as the second symptom of the same missing affordance, even though its *contract*
  enforcement (MUST NOT end a turn on a background wait) is explicitly out of scope here and
  belongs to dependent tasks.
- Recommended structure for the new file mirrors `external-process-wait.md` almost exactly
  (Purpose/Audience/Related header, "The Defect" section synthesizing all three evidence rounds,
  "Required Rules" enumerated 1-N, a generalization section, a "Local vs. Remote Waits" reciprocal
  section, "Related Documentation"). This keeps the two sibling files visually and structurally
  paired, which is itself a reader aid given how closely they are cross-referenced.
- Two low-risk, in-scope wiring opportunities beyond the mandatory long-builds.md pointer: (a)
  `external-process-wait.md`'s existing "Local vs. Remote Waits" section already asserts the
  file's existence — no edit needed there once bounded-build-waiter.md exists, only a check that
  its description of the sibling stays accurate; (b) the index-entries.json registration pattern
  used for `external-process-wait.md` is a direct template to copy for the new file's own entry.
- Recommend the reaper task (174) and guard task (173) each get a one-line pointer added to their
  own descriptions confirming they will consume this file's process-signature and PID-based
  liveness contract — this is advisory only; no other task's files should be touched by this
  dispatch.

## Context & Scope

**What was researched**: the existing long-builds.md mandate and its stated gap; the sibling
`external-process-wait.md` file's structure, its existing (currently dead) pointer to
`bounded-build-waiter.md`, and its "single-statement-plus-pointer" convention exemplified by
`dispatch-report-not-termination.md`; the guard script's own already-documented `kill -0`
idiom and `pgrep -f` self-match prohibition; the three evidence rounds embedded in this task's
own description (BimodalLogic unreapable-poll-loop incident, BimodalLogic turn-ending incident,
Logos/Verification name-based-poll self-match incident); the dependent reaper (174) and guard
(173) task descriptions, to confirm this task's deliverable is what they expect to consume; the
`index-entries.json` registration convention for context pattern files.

**Constraints carried over from the dispatch** (restated here because they bound the report's
recommendations, not because they are new): do not modify `lake-build-guard.sh`,
`claude-refresh.sh`, or any agent file; scope the new pattern file generically (not Lean-only);
state the turn-ending symptom alongside the poll-loop symptom but leave its MUST-NOT contract
enforcement to dependent tasks; follow the existing single-statement-plus-pointer convention for
the `long-builds.md` wiring, i.e. do not restate the waiter model there.

## Findings

### Codebase Patterns

- **`agent-system/extensions/lean/context/project/lean4/operations/long-builds.md`** (154 lines):
  mandates detach (`Bash(run_in_background: true)`) + guard (`lake-build-guard.sh`) for every
  `lake build`, and its "Passive progress checks" section (lines 101-124) explicitly labels all
  four checks (`.olean` mtime frontier, live PID cmdline, accumulated CPU time, `VmRSS` trend) as
  liveness-only, closing with: "these checks... are not a substitute for waiting on that
  notification". There is no section describing how to *block* on the detached build from within
  the same dispatch when the dispatch cannot simply end its turn and wait for the harness
  notification (e.g. because more phases in the same dispatch depend on the build's outcome).
  This confirms the dispatch's framing: the file's only sanctioned discipline is "wait for the
  notification", which is not always compatible with a dispatch's shape.
- **`agent-system/extensions/core/context/patterns/external-process-wait.md`** (129 lines,
  created 2026-09-18 per its own header): the direct structural sibling for this task's
  deliverable. Its `Related:` line and its dedicated "Local vs. Remote Waits" section (lines
  108-115) both already name `bounded-build-waiter.md` as "the complementary local case — a
  detached build with a local log file, where writer-liveness is checked via `kill -0` and a
  one-waiter-per-log convention applies." This is independent confirmation, written before this
  task existed as a distinct dispatch, of the exact three properties this task's description
  lists. The file this pointer names does not exist yet — the pointer dead-ends today.
- **`external-process-wait.md`'s own structure** is the concrete template to mirror: a header
  block (Created/Purpose/Audience/Related), "## The Defect" (a narrated incident, numbered
  contributing causes), "## Required Rules" (numbered, each with a rationale subsection where
  needed — e.g. Rule 1's "Why 540 < 600" explanation), a "## Generalizing Beyond ..." section, the
  reciprocal "## Local vs. Remote Waits" section, and "## Related Documentation" listing every
  cross-reference with a one-line reason. `bounded-build-waiter.md` should reuse this exact shape
  for symmetry — the two files are cross-referenced tightly enough that a reader jumping between
  them benefits from matching structure.
- **`agent-system/extensions/core/scripts/lake-build-guard.sh`**: already documents, in its own
  header comment (lines ~80-87) and in `print_help()` (lines ~232-235), the canonical
  writer-liveness idiom for waiting on *its own* recorded `holder_pid`:
  ```
  while kill -0 "$holder_pid" 2>/dev/null; do sleep 1; done
  ```
  paired with an explicit prohibition: "Do NOT use `pgrep -f \"lake-build-guard.sh build\"` (or
  any `pgrep -f` variant naming this script) to wait for it to finish — a polling shell whose own
  argv contains that same string self-matches its own `pgrep -f` and the loop never terminates."
  This is prior art already accepted into the source store; it does not yet state a hard timeout
  or a one-waiter-per-log rule, and it is scoped to the guard's own PID field rather than to "a
  detached local command" generically. The new pattern file should present the generalized
  version of this exact idiom (with a timeout wrapper added) as canonical, and can cite the guard
  as an existing conforming example rather than inventing a competing idiom.
- **`agent-system/extensions/core/index-entries.json`**: `external-process-wait.md`'s entry
  (path, domain, subdomain, summary, line_count, keywords, topics, `load_when`) is a direct,
  ready-to-copy template for a new `patterns/bounded-build-waiter.md` entry — same domain/core,
  subdomain/patterns shape, `on_demand`-style loading (no eager `agents`/`task_types`/`commands`
  entries needed, matching the sibling).
- **Dependent task descriptions already assume this file's contents**: task 173 (the guard task,
  `specs/TODO.md` line ~600) explicitly states "The bounded-waiter dependency task owns the
  blocking-wait contract (hard timeout, writer-liveness check, one-waiter-per-log) and the
  teardown dependency task owns tearing a waiter down" — confirming the three (now four, see
  below) properties are already treated as settled elsewhere and this task must deliver them.
  Task 174 (the reaper task) explicitly plans to reuse "the process signature settled by the
  bounded-waiter contract" to identify orphaned waiters for reaping — so the pattern file's
  waiter shape should be concrete and greppable enough (a recognizable process signature) to
  support that downstream reaper design, not merely prose guidance.
- **No existing doc addresses "Monitor is already watching"**: a repo-wide search found no prior
  documentation of what a second waiter should do when a log/build is already watched. This is a
  genuine gap this task's pattern file is the first to need to close (at least at the
  policy-statement level — the mechanical enforcement is explicitly a dependent task's job per
  this task's own "CONTRACT HALF STAYS WITH THE DEPENDENT TASKS" framing).

### External Resources

Not applicable — this is a meta task scoped entirely to this source store's own conventions and
existing incident evidence; no external documentation search was warranted or performed.

### Recommendations

1. **Write `agent-system/extensions/core/context/patterns/bounded-build-waiter.md`** following
   `external-process-wait.md`'s structural template:
   - Header: Created (today's date), Purpose (state the defect class once, canonically; define
     the safe local-detached-command waiter), Audience ("Any dispatched agent — not Lean-only —
     that detaches a local command and must block on it within the same dispatch"), Related
     (`external-process-wait.md`, `long-builds.md`, `lake-build-guard.sh`'s own header idiom,
     `dispatch-report-not-termination.md`, `anti-stop-patterns.md` for the turn-ending symptom).
   - "The Defect" section: synthesize all three evidence rounds as named sub-incidents (the
     22-loop BimodalLogic sentinel-poll; the BimodalLogic turn-ending stop, described as the same
     missing affordance expressed as "end the turn" rather than "poll forever"; the
     Logos/Verification five-hang `ps aux | grep` self-match). State the defect class once:
     "a poll loop whose exit condition is a sentinel written by a process that may die first has
     no bounded termination" plus "a liveness test keyed on a process NAME rather than a captured
     PID is self-referential whenever the polling shell's own argv contains the search pattern."
   - "Required Rules" (four, sharpened from the task description's three):
     1. **Hard timeout** — wrap the wait in `timeout N` so the waiter cannot outlive the writer
        even if the liveness check is somehow defeated; N should be the same order of magnitude
        as the guarded operation's own expected bound (e.g. `--timeout 1800` mirrors
        long-builds.md's guard-lock-wait value, but the waiter's timeout is a *wait-duration*
        bound, not a lock-wait bound — name this distinction explicitly, since long-builds.md
        already had to disambiguate an analogous lock-wait-vs-build-duration confusion for
        `--timeout`).
     2. **Writer-liveness via captured PID, never process-name matching** — canonical idiom:
        ```bash
        cmd >log 2>&1 & pid=$!
        timeout 3000 bash -c 'while kill -0 "$1" 2>/dev/null; do sleep 10; done' _ "$pid"
        ```
        (or the simpler foreground-under-`timeout` form when the command fits the Bash tool's own
        limit). Explicitly prohibit `ps aux | grep`, `pgrep -f`, and any pattern-matching
        liveness test, citing both the guard's own existing prohibition and the
        Logos/Verification `[b]ash framed_channel/check.sh` self-match as concrete evidence that
        the bracket trick only protects the search command from matching itself, not from
        matching the *launching* shell's own argv when that shell is also the one polling.
     3. **One-waiter-per-log enforcement** — before spawning a new waiter for a given log, check
        whether one already exists (e.g. a recorded PID/lock file per log path); if a waiter for
        this log is already active, the new caller must either **attach** to the existing wait
        (poll the same recorded PID/condition without spawning a second independent loop) or
        **fail loudly** with a clear message identifying the existing waiter — never silently
        stop and hand back the turn. State this as the resolution to the "Monitor is already
        watching" incident: silently ending the turn is the wrong default; attach-or-fail-loudly
        is the sanctioned pair of correct responses.
     4. **A dead writer terminates the wait immediately** — restate/cross-link property 2's
        consequence explicitly as its own numbered rule if the file's authors judge it needs
        separate emphasis (it is arguably already implied by 2, but the task description lists it
        as a distinct property from the original three; a short explicit callout costs little and
        matches the task description's own enumeration).
   - A short "Two Symptoms, One Missing Affordance" section naming the turn-ending stop as the
     second symptom (per the second evidence round), explicitly deferring its MUST-NOT contract
     enforcement to dependent agent-contract/guard tasks, with a one-line forward pointer.
   - "Local vs. Remote Waits" reciprocal section (mirroring `external-process-wait.md`'s existing
     section of the same name) — this is what closes the dead-end pointer symmetrically.
   - "Related Documentation" list.
2. **Add the `long-builds.md` pointer** as a new, short section (e.g. "## Blocking on a detached
   build") stating only: "When a dispatch must block on a detached build within the same turn
   rather than ending it to await the harness notification, see
   `context/patterns/bounded-build-waiter.md` for the sanctioned bounded-wait idiom (hard timeout,
   PID-captured writer-liveness, one-waiter-per-log)." — one to two sentences, no restatement of
   the model, matching `dispatch-report-not-termination.md`'s citation convention exactly.
3. **Register the new file in `agent-system/extensions/core/index-entries.json`**, copying
   `external-process-wait.md`'s entry shape (domain `core`, subdomain `patterns`, an accurate
   `line_count`, keywords such as `bounded-wait`, `kill-0`, `writer-liveness`, `detached-build`,
   `one-waiter-per-log`, topics `workflow`/`orchestration`, empty `load_when.agents/task_types/
   commands` to keep it on-demand like its sibling).
4. **No change needed to `external-process-wait.md` itself** — verify at implementation time that
   its existing description of the sibling file (bullet under "Local vs. Remote Waits") still
   matches what gets written; if wording drifts, a one-line factual correction there is in scope
   as part of "wiring the new anchor," but no structural rewrite is warranted.
5. **Do not touch `orchestrate-build-dispatch.sh`, `lake-build-guard.sh`, `claude-refresh.sh`, or
   any agent file** in this task, per the explicit MUST NOT — the observation that
   `orchestrate-build-dispatch.sh`'s unconditional "Wait Discipline" block is the cheapest carrier
   to reach `general-implementation-agent` is recorded here for the **planning phase** to weigh,
   not for this research report to act on. If the plan chooses that route, it becomes a small,
   separate edit to that script's dispatch-file template (adding a one-line
   `bounded-build-waiter.md` reference alongside the existing `external-process-wait.md` one) —
   still not an agent file and not one of the three explicitly forbidden files, so it appears to
   be in scope for a future phase of *this* task, but the research report flags it as a decision
   point rather than pre-deciding it, since the task description also says scope is "the canonical
   pattern file and the long-builds.md pointer" only.

## Decisions

- Treat `external-process-wait.md` as the structural and citation template for the new file;
  no alternative structure was considered necessary given how tightly the two files already
  cross-reference each other.
- Treat `lake-build-guard.sh`'s existing `kill -0 "$holder_pid"` idiom as the canonical PID-based
  liveness primitive to generalize, rather than inventing a new one — this keeps the new pattern
  consistent with an idiom already accepted and tested in this source store.
- Recommend four explicitly stated properties (hard timeout, PID-captured liveness /
  never-name-matching, one-waiter-per-log with an attach-or-fail-loudly disposition, dead-writer
  terminates immediately) rather than folding all four into three, because the third evidence
  round's sharpening ("NEVER by process-NAME matching") is materially different guidance from a
  generic "writer-liveness check" and deserves its own explicit prohibition given it already
  caused five hangs in one run.
- Whether to also edit `orchestrate-build-dispatch.sh`'s Wait Discipline block to add a
  `bounded-build-waiter.md` line is left as an open decision for the planning phase rather than
  resolved here, since it sits at the edge of this task's stated file_scope (which currently lists
  only `bounded-build-waiter.md` and `long-builds.md`).

## Risks & Mitigations

- **Risk**: stating the waiter idiom in a way that's too Lean-specific (e.g. defaulting the
  timeout example to `1800`, matching `long-builds.md`'s guard-lock value) could accidentally
  narrow the "detached local command" framing the third evidence round explicitly required.
  **Mitigation**: use a generic example command (`cmd >log 2>&1 & pid=$!`) as the primary
  illustration, and cite the Lean guard invocation only as one conforming example among others
  (the general-implementation-agent gate-script case from the third evidence round is an
  equally valid second example to include).
- **Risk**: the "attach or fail loudly" resolution for one-waiter-per-log is a policy choice this
  report is recommending without a mechanical enforcement design (that's explicitly a dependent
  task's job). If the pattern file states this too prescriptively, it could clash with whatever
  the guard/reaper tasks later decide is mechanically feasible.
  **Mitigation**: state the policy at the level of "what should NOT happen" (silent stop) plus
  "what the two acceptable responses are" (attach; fail loudly with identification), without
  prescribing a specific lock-file mechanism — leave the mechanism to the guard-side dependent
  task, consistent with this task's own "contract half stays with the dependent tasks" framing
  applied by analogy to the mechanism half.
- **Risk**: scope creep into `orchestrate-build-dispatch.sh` or agent files during implementation.
  **Mitigation**: the plan phase should explicitly re-confirm file_scope before touching anything
  beyond `bounded-build-waiter.md` and `long-builds.md`; this report flags the script as a
  discussion point, not an instruction to edit it.

## Context Extension Recommendations

- **Topic**: local-detached-command bounded waiting (generic, non-Lean).
- **Gap**: prior to this task, the only local-wait guidance lived inside `lake-build-guard.sh`'s
  own header/help text (guard-specific) and `long-builds.md` (Lean-specific, liveness-only). No
  generic, cross-domain anchor existed, which is exactly why the third evidence round's
  general-implementation-agent (task_type `general`, no Lean involvement) had no sanctioned
  idiom to reach for and improvised a self-matching `ps aux | grep`.
- **Recommendation**: this task's own deliverable closes the gap; no further context file is
  needed beyond it. A possible follow-up (not created here, per Stage 4.5's "do not create tasks
  for context gaps" instruction): once the guard/reaper/agent-contract dependent tasks land,
  consider whether `long-builds.md`'s "Passive progress checks" section should also gain a
  pointer distinguishing "liveness" checks from the new file's bounded-wait idiom, since both
  now live in the same document.

## Appendix

- Files read in full: `agent-system/extensions/lean/context/project/lean4/operations/
  long-builds.md`; `agent-system/extensions/core/context/patterns/external-process-wait.md`;
  `agent-system/extensions/core/context/patterns/dispatch-report-not-termination.md` (partial,
  header + "Where This Is Referenced"); `agent-system/extensions/core/context/patterns/
  anti-stop-patterns.md` (partial, header + forbidden-patterns table).
- Files grepped: `agent-system/extensions/core/scripts/lake-build-guard.sh` (holder_pid / kill -0
  / pgrep-self-match passages); `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh`
  (Wait Discipline block, lines ~40-70 and ~505-530); `agent-system/extensions/core/index-entries.json`
  (external-process-wait.md and dispatch-report-not-termination.md entries); `specs/TODO.md`
  (task 172, 173, 174 full descriptions); `specs/state.json` (task 172 record).
- No web search performed (meta task, source-store-internal scope).
