# Bounded-Build-Waiter Discipline

**Created**: 2026-09-21
**Purpose**: State, once and canonically, the defect class produced when a dispatched agent
blocks on a detached local command with no bounded, PID-keyed waiter, and define the sanctioned
waiter idiom that avoids it.
**Audience**: Any dispatched agent that detaches a local command (a build, a gate script, a test
run) and must block on it within the same dispatch. This is explicitly not Lean-only — the
defect and the fix generalize to any detached local process with a local log file or PID.
**Related**: `external-process-wait.md`, `dispatch-report-not-termination.md`,
`anti-stop-patterns.md`, `../contracts/wrap-up.md`,
`../../../lean/context/project/lean4/operations/long-builds.md`

---

## The Defect

A poll loop whose exit condition is a sentinel written by a process that may die first has no
bounded termination. A liveness test keyed on a process **name** is self-referential whenever the
polling shell's own argv contains the pattern being searched for — the search matches the search,
not the thing being searched for.

Three repositories hit this gap, in three different shapes:

1. **The sentinel poll.** A wrapper of the form `cmd > log 2>&1; echo "EXIT=$?" >> log` was
   watched by `until grep -q "^EXIT=" log; do sleep ...; done`. When the guarded command was
   cancelled or superseded by lock contention with a concurrent session, the `echo` never ran, so
   the sentinel became unwritable by construction. 22 such loops watched one log file (2 more
   watched a second), aged 24-55 minutes, at 0% CPU — background-shell-slot exhaustion and
   operator confusion, not throughput cost.
2. **The turn-ending stop.** Rather than spin a poll loop, a dispatch simply ended its turn,
   reporting reasons like "waiting for lake build" or "Monitor is already watching." Ending the
   turn ends the dispatch, so this costs a full re-dispatch cycle rather than a background-shell
   slot — see "Two Symptoms, One Missing Affordance" below.
3. **The name-match self-match.** A gate script was launched and awaited in one Bash call:
   `nohup timeout 3000 ... check.sh > log 2>&1 & disown; until ! ps aux | grep -q "[b]ash
   check.sh"; do sleep 8; done`. The `[b]` bracket trick only stops `grep` from matching itself —
   the waiting shell's own command line still contains the literal text `bash check.sh` (it is the
   shell that launched the gate), so the poll matched its own shell forever. The gate finished
   within seconds; the agent sat idle for roughly 13 minutes across five recurrences until an
   operator killed the waiter by hand.

## Two Symptoms, One Missing Affordance

Symptoms 1 and 2 above are the same missing affordance expressed two ways. An agent told to
detach a local command, with no sanctioned way to block on it, has exactly two bad options: poll
an unbounded, possibly-unwritable sentinel forever, or end the turn and hand the dispatch back
unfinished. This file is the missing affordance that removes both options. The explicit
prohibition against ending a turn on an unresolved background wait — and any postflight detection
of a stop lacking a handoff or `.return-meta.json` — belongs at the agent-contract layer, not
here; this file states only the waiter model both symptoms are missing.

## Required Rules

1. **Hard timeout.** Wrap the wait in `timeout N` so the waiter cannot outlive its writer. Size
   `N` to the command's expected run time, within whatever the calling tool allows. This is a
   *wait-duration* bound on the waiter itself — distinct from a lock-acquisition budget such as
   `lake-build-guard.sh --timeout`, which bounds how long the guard waits to acquire a lock, not
   how long the underlying command may run.
2. **Writer liveness by captured PID, never by name.** Capture the writer's PID at launch
   (`pid=$!`) and test liveness with `kill -0 "$pid"`. Never use `ps | grep`, `pgrep -f`, or any
   process-name-matching test — the polling shell's own argv can contain the same text as the
   command it is searching for, producing a self-match that never resolves (symptom 3 above).
   Never poll a sentinel file alone, with no liveness check backing it (symptom 1 above).
3. **A dead writer ends the wait immediately.** The instant `kill -0 "$pid"` fails, the wait is
   over — read the log or exit status at that point. Treat a missing sentinel as "the writer
   died," never as "keep waiting."
4. **One waiter per log.** Before starting a waiter, check whether one already exists for the
   same log or PID. A second would-be waiter either attaches — waiting on the same recorded PID,
   never spinning a second independent loop — or fails loudly, naming the existing waiter. It must
   never silently stop and hand the turn back (symptom 2 above). A superseded build's waiter is
   reaped before a replacement waiter is spawned.

## The Canonical Idiom

```bash
cmd >log 2>&1 & pid=$!
timeout 3000 bash -c 'while kill -0 "$1" 2>/dev/null; do sleep 10; done' _ "$pid"
```

Prefer the simpler foreground form, `timeout 3000 cmd`, whenever the command fits within the
calling tool's own timeout limit — reach for the detach-plus-waiter shape only when it does not.

To read the outcome once the wait ends, either `wait "$pid"` in the same shell that captured
`pid` (if still live), or read an exit-status line the writer itself appended to the log — read
it *after* liveness ends, never polled for during the wait. This idiom's shape (a captured `pid`,
a `kill -0` loop, an outer `timeout`) is the recognizable process signature a reaper can match
against when cleaning up stale waiters. `claude-refresh.sh`'s orphaned build-waiter poll-loop
pass (`run_build_waiter_pass`) is exactly such a reaper, matching this canonical idiom's signature
(its "Family A") as well as the legacy self-match shape it replaced (its "Family B") — see
`commands/refresh.md`'s "Orphaned Build Waiters" section for the full detection and
self-exclusion contract.

## Canonical Agent-Contract Bullet (Generated-Copy Source)

This section is the single authoritative source for the bounded-wait MUST / MUST NOT bullet pair
that every in-scope dispatchable implementation agent carries in its `## Critical Requirements`
list. It exists so the bullet pair has exactly one place to edit, instead of drifting
independently across the agent files that carry a literal copy.

### Generated-Copy Source, Not an `@`-Import

**This section is a generated-copy source, read by a human or a lint script — it is NOT
`@`-imported into agent bodies at spawn time.** `@`-references inside an agent body do not
auto-resolve when Claude Code spawns a subagent, so each in-scope agent body carries a **literal
copy** of the bullet text below; `lint-agent-contracts.sh` Check H keeps every copy in sync by
comparing it against this file, not against a string baked into the lint. This mirrors the
precedent already established twice in this same script, by `no-task-references-bullet.md` (its
own Check C) and `plan-status-ownership.md` (its own Check G).

### Item 1 Ruling: One Shared Home, Rejected Candidates Recorded

This section (an appended section of this already-existing pattern document) is the settled home
for the bullet pair, chosen over two other candidates evaluated and rejected:

- **(a) A shared always-load context pointer every implementation agent already includes** —
  rejected because no such universally-included file exists. The nearest candidates
  (`contracts/phase-closure.md`, `contracts/pre-edit-gate.md`) are each missing from at least two
  of the fourteen target agent files, so even the closest-to-universal pointer would still
  require a fresh addition in the hardest cases. A bare pointer would also not reach a spawned
  subagent in the first place: `@`-references inside an agent body do not auto-resolve when
  Claude Code spawns a subagent (see "Generated-Copy Source, Not an `@`-Import" above), so the
  behavioral MUST/MUST-NOT core must be literal text in each agent body regardless of which file
  states it canonically.
- **(c) Per-agent duplication with no single canonical source at all, as a last resort** —
  rejected because it is the anti-proliferation failure this change exists to close: fourteen
  independently-drifting copies of one prohibition is a maintenance defect in waiting, and a
  future agent addition would miss it again by the exact mechanism that produced the original
  gap. The chosen shape (this generated-copy section, propagated by literal text and verified by
  `lint-agent-contracts.sh` Check H) keeps exactly one edit point while still placing a literal,
  subagent-reachable copy in every carrying agent body.
- **(b) The agent template, `core/context/templates/agent-template.md`** — adopted, but as a
  **forward-looking complement only**, not a substitute for (a) or (c)'s rejection. A template
  change fixes no existing agent file; it only ensures a newly authored implementation agent
  inherits the bullet pair by construction. The fourteen already-existing agent files still
  require the direct literal-copy propagation this section's "Copy this exact text" block below
  describes, and that propagation — not the template edit — is what closes the measured gap.

### Copy this exact text

Copy both bullets below, verbatim and each on a single physical line, into the target agent's
`## Critical Requirements` MUST and MUST NOT lists respectively, as the next sequential item of
each. Do not renumber or reword any surrounding bullet.

MUST bullet:

```
Whenever a local verification/gate/build/test process is backgrounded at all, use bounded-build-waiter.md's canonical idiom VERBATIM: a captured `pid=$!`, a `kill -0 "$pid"` liveness loop, and an outer `timeout N`, all inside one Bash call that does not return control until the wait resolves -- and prefer the plain foreground form `timeout N cmd` whenever the command plausibly fits within the Bash tool's own ceiling
```

MUST NOT bullet:

```
Use `Bash(run_in_background: true)` or arm a `Monitor` to watch a local verification, gate, build, or test process from within this dispatched subagent, and never end the turn on an unresolved local background wait -- the harness's own asynchronous detach-then-await-notification path hands the dispatch back unfinished with nothing guaranteed to resume it
```

### Classification Rule

An agent MUST carry this bullet pair if and only if it is a dispatchable implementation agent
that can run a local verification, gate, build, or test command (every implementation agent
across core and every extension, hard-mode variants included — see the Item 3 ruling below).
Three files are recorded exclusions, each for a per-file reason rather than an oversight:

- `core/agents/general-implementation-agent.md` — the contract's authoritative home. This is the
  full prose block the bullet pair above is condensed from; it is deliberately not edited to
  carry the condensed copy of its own source text.
- `lean/agents/lean-implementation-agent.md` and `lean/agents/lean-implementation-hard-agent.md`
  — these carry a domain-adapted, sanctioned background-build path routed through the Lean build
  guard (`lake-build-guard.sh`), a different legitimate mechanism satisfying the same underlying
  rule rather than an unfixed gap.

A future agent addition must be classified by this rule and added to the lint's curated
in-scope array explicitly — the check does not infer scope from a filename glob.

### Item 3 Ruling: Hard Variants Do Not Inherit

Hard-mode agent files (e.g. `*-implementation-hard-agent.md`) do not inherit this bullet pair
from their non-hard sibling. A hard-mode file's "Extends `{sibling}-implementation-agent`"
language is prose documentation of intent, not a file-inclusion or generation mechanism — nothing
mechanically copies the sibling's `## Critical Requirements` list into the hard variant. The
evidence is direct: both measured hard variants (`books-implementation-hard-agent.md`,
`cslib-implementation-hard-agent.md`) are missing the bullet pair independently of their non-hard
sibling's own coverage state. Each hard-mode agent file therefore carries its own literal copy
and is listed independently in the lint's curated in-scope array.

### Item 4 Ruling: Research Agents Are Out of Scope Here, Not Dismissed

Research agents are plausibly exposed to the identical defect class: `general-research-agent.md`
already carries the external/remote-wait discipline (the `external-process-wait.md` idiom) but
neither half of this local-background bullet pair, and several domain research agents hold Bash
access explicitly for verification or build commands. The Lean research agents'
`run_in_background` occurrences are the separate, sanctioned Lean build-guard path, not partial
coverage of this contract, so they do not change this ruling.

This change rules research-agent propagation **out of its own scope**, not out of relevance: the
measured coverage gap and this change's acceptance surface are implementation-agent-scoped only.
Extending the identical fragment-and-lint-check mechanism to research agents is recorded as a
follow-up recommendation, reusing this same generated-copy section and the same lint shape against
a separately curated research-agent in-scope array.

### Brittleness Note

This section is the single edit point for the bullet pair's wording. A future wording change here
is expected to be followed by a mechanical re-propagation pass across every literal copy — the
same brittleness already accepted for the `no-task-references-bullet.md` and
`plan-status-ownership.md` fragments this section's shape mirrors.

## Conforming Examples

- **`lake-build-guard.sh`** already documents this idiom in its own header and `print_help()`:
  `while kill -0 "$holder_pid" 2>/dev/null; do sleep 1; done`, with an explicit prohibition
  against `pgrep -f "lake-build-guard.sh build"` for the same self-match reason as Rule 2 above.
  It is prior art for Rules 2 and 3, lacking only the outer `timeout` wrapper from Rule 1.
- **A generic gate script**: `nohup timeout 3000 bash gate.sh >log 2>&1 & pid=$!` followed by the
  canonical idiom above, in place of a `ps aux | grep` poll on the script's name.

## Local vs. Remote Waits

This file covers the case where there IS a local writer to probe: a detached command running on
the same host, with a PID the agent captured at launch and, usually, a local log file.
`external-process-wait.md` covers the complementary remote case — a process running somewhere the
agent cannot inspect directly, where the only observable signal is a polled status call (for
example `gh run watch`). Consult this file for a detached local build, gate, or test run; consult
that file for a remote or external job with no local writer.

## Related Documentation

- `external-process-wait.md` — the complementary remote-wait pattern; see "Local vs. Remote
  Waits" above.
- `dispatch-report-not-termination.md` — explains why a dispatch that ends its turn mid-wait
  loses the wait state entirely; supports the turn-ending symptom above.
- `anti-stop-patterns.md` — the forbidden-status-value backdrop to "ending the turn" as a bad
  outcome.
- `../contracts/wrap-up.md` — the general teardown-before-handoff obligation a background wait
  must respect if it cannot resolve within budget.
- `../../../lean/context/project/lean4/operations/long-builds.md` — the Lean-specific
  detach-and-guard mandate this waiter idiom complements; see its "Blocking on a detached build"
  section.
