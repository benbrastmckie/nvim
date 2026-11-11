# Research Report: Task #587

**Task**: 587 - Error logging contract and central log
**Started**: 2026-11-11T03:19:34Z
**Completed**: 2026-11-11T03:27:58Z
**Effort**: medium
**Dependencies**: None (coordinates with, but does not depend on, tasks 477, 484, 519)
**Sources/Inputs**:
- Codebase: `agent-system/extensions/core/{rules,scripts,context}` (source store, per
  `rules/source-store-deploy-boundary.md`), `agent-system/extensions/sapience/scripts/`,
  `.claude-extensions.json`, `specs/errors.json`, `specs/events.jsonl`,
  `specs/*/issues.jsonl` (162 files), `~/.sapience/mcp.py` (vendor-owned, read-only), live
  hook/settings merge sources, `~/.local/share/nvim/neotex-ai/extension-repo-registry.json`
- `specs/TODO.md` task entries 477, 484, 519, 543, 562 (full text)
**Artifacts**:
- This report: `specs/587_error_logging_contract_and_central_log/reports/01_error-logging-contract.md`
**Standards**: report-format.md, subagent-return.md, issue-log.md, conclusion-stage.md

## Executive Summary

- **Store consolidation**: reuse `specs/{NNN}_{SLUG}/issues.jsonl` via `issue-record.sh` as the
  single capture store for every error class, Sapience included. `errors.json`/`errors-append.sh`
  has zero production call sites (mechanically verified by grep across every agent, skill, hook,
  command, and script in the source store) and is abandoned in fact, not just stale in content;
  `events.jsonl` has no rotation and no classification/promotion machinery. No new store is
  justified.
- **The documented contract is wrong, not the store**: `rules/error-handling.md`'s "Log the
  Error" section names `errors-append.sh` as *the* error store. Correct that pointer to
  `issue-record.sh`; do not revive `errors-append.sh`.
- **Infra-vs-work class**: add one net-new seed class, `infrastructure/transport unavailable`,
  to `issue-log.md`'s open enum. This is an addition, not a renormalization, and does not
  overlap task 477's fragmentation-cleanup work.
- **Collapse rule**: the existing open `tags` seam on `issue-record.sh` already carries this
  without any schema change — a caller that detects N occurrences of one underlying event before
  its first call writes one line with `tags.occurrence = {count, first_seen, last_seen}`.
  Cross-entry collapse already happens at read time: `orchestrate-conclusion-aggregate.sh`'s
  `group_by(.class)` already groups same-class entries into one proposal — the 123-row case was
  a write-volume and citation-list problem, not an un-grouped-signal problem as initially framed.
- **Capture points are honestly mixed**: `sapience-retrieve.sh` and `sapience-remember.sh`
  already hold the diagnostic body and can capture mechanically with zero added network cost.
  MCP tool failures (the actually-observed Sapience class, and `tool_unavailable`/
  `mcp_abort_error` generally) are NOT mechanically capturable from this repo — verified there is
  no wildcard `PostToolUse` hook in the merged settings, and adding one is out of scope per the
  cost ceiling. This class is agent-cooperation-dependent, honestly, with no code fix available.
- **Push, not pull, for the central log**: the repo registry is even more unusable now (536
  entries, 3 real, up from the measured 313/2) than when the task was filed, which strengthens
  rather than weakens the case against a pull model. Push the write inside the shared
  `issue-record.sh`/`events-append.sh` helpers (never the 34 call sites), skipped when the
  writing repo already is the owning repo.

## Context & Scope

This research settles the design questions (a)-(g) the dispatch requires before any
implementation: store consolidation, class vocabulary, collapse rule, capture points, the
no-task-context case, push-vs-pull, and the cost ceiling. It also states an explicit boundary
against tasks 477, 484, 519, 543, and 562, per the dispatch's instruction not to silently
re-solve their ground. Sapience 503s are the motivating subclass and the acceptance test, but
every decision below is stated and justified for the general error-logging problem first; the
Sapience case is checked against each decision rather than driving it.

Non-goals carried from the dispatch and respected throughout: no Sapience health probe, no
block/retry on Sapience, no vendor-owned `mcp.py` fix, no reporting UI, no repo-registry repair,
no mass call-site rewrite, no historical migration.

## Findings

### The three stores, measured directly in this session

- `specs/errors.json`: 19 records, newest timestamp `2026-09-03T13:17:51.663Z` (over two months
  stale against this session's clock). `rules/error-handling.md`'s "Log the Error" section
  (`.claude/**/*` path scope — loaded by every agent) still names `errors-append.sh append` as
  the mandated write path.
- **Zero production writers, verified by enumeration.** `grep -rl "errors-append.sh"` across
  `agent-system/extensions/core/{agents,skills,hooks,commands}` and the same four directories
  across every other loaded extension returned exactly one hit: `commands/errors.md`, which only
  *reads* `errors.json` (`/errors` triage) and calls `errors-append.sh update` to mark an
  existing record fixed — never `append`. The eleven other hits repo-wide are
  `errors-append.sh` itself, its own test file, five unrelated test files that merely *reference*
  the script name in a comment or a cross-script list, `common.sh` (a comment), and
  `verify-deploy.sh` (a deploy-manifest presence check, not an invocation). **Search pattern used
  for this enumeration**: `grep -rl "errors-append.sh" agent-system --include="*.sh"
  --include="*.md"` (18 files), cross-checked against a second, narrower pattern restricted to
  `agents/skills/hooks/commands` directories only (1 file) — the two patterns agree that no
  agent, skill, hook, or command body issues an `append` call in the ordinary course of a
  dispatch.
- `specs/events.jsonl`: 8249 lines, 3.2 MB. `events-format.md` states explicitly: "No rotation or
  archival strategy is defined for this file. Unbounded growth over a long-lived repository is a
  known, explicitly out-of-scope gap." `task`/`cwd`/`cc_session_id` are all nullable — this file
  is the one of the three that does not require a task directory to write to.
- `specs/{NNN}_{SLUG}/issues.jsonl`: 1448 entries across 162 task directories, single writer
  `issue-record.sh`, mandatory at every dispatch per `context/contracts/phase-closure.md`'s
  "Record issues and wins during the phase" section (research/plan/implement/aux alike, with an
  explicit attestation required when there is nothing to record). Already carries: an open,
  15-class seed enum; a four-rung closed severity scale (`blocking`/`costly`/`minor`/`none`,
  the last reserved for `kind: "win"`); a `resolution` field; a `suggested_channel` *hint*; an
  open `tags` object seam explicitly designed for exactly this kind of extension without a
  schema change; and `orchestrate-conclusion-aggregate.sh`, a working cross-task aggregator with
  `group_by(.class)`, an unknown-class tally, an `implicit_open_count` tally, and a three-channel
  (fix-now / agent-system / follow-up-task) gated promotion path reviewed exactly once per
  `/orchestrate` invocation (`context/contracts/conclusion-stage.md`).
- A fourth, narrower store exists and is explicitly out of scope: `system_defect` events in
  `events.jsonl` (`scripts/system-defect-record.sh`), a closed 16-class enum for mechanically
  detected schema violations only. `issue-log.md`'s own relation table marks this **LEAVE** —
  disjoint population, disjoint enum, two sites already emit both deliberately. 587 does not
  touch it.

### Correcting the signal-destroyed framing

Direct inspection of `orchestrate-conclusion-aggregate.sh`'s `--aggregate` jq pipeline shows
`group_by(.class)` already collapses every entry of one class — however many — into a single
proposal object carrying one `citations[]` array. The 123 "scope excursion" rows from a single
invocation (task 484's evidence) therefore already render as **one** proposal at the conclusion
stage, not 123. What is actually degraded is: (1) write cost — 123 `flock`+`jq`+append
invocations instead of one; (2) raw-log readability — a human who greps `issues.jsonl` directly,
bypassing the aggregator, sees 123 near-identical lines; and (3) that one proposal's own
`citations[]` array is 123 entries long, which is a milder, but real, form of the same noise one
level up. The collapse rule below is scoped to these three costs, not to an aggregation gap that
does not exist.

### `issue-log.md`'s `tags` seam already fits the collapse requirement

`issue-log.md`'s "The `tags` Seam" section documents `tags` as "an open object... the seam an
extension's own dimension-tagging scheme uses to attach extension-specific structured metadata...
without requiring any change to `issue-record.sh`." An occurrence-count convention
(`tags.occurrence = {count, first_seen, last_seen}`) fits this seam exactly, written once by a
caller that has already discovered N repeats of one underlying event before its first
`issue-record.sh` call (the two scope-excursion emitters' per-path loops; a Sapience caller that
observes several identical probes in one dispatch). No schema or script change is required to
adopt this convention for a within-one-caller collapse.

### Capture points, class by class

| Error class | Capture point | Mechanical or agent-dependent | Evidence |
|---|---|---|---|
| `delegation_hang`/`timeout`/`validation_failed`, `status_sync_failure`/`file_not_found`/`parse_error`, `git_commit_failure`/`build_error` | Inline, at the detecting script/agent, already flowing into `issue-record.sh` at existing dispatch call sites | **Mechanical** (already working) | `error-handling.md`'s existing taxonomy; 34 live `issue-record.sh` call sites |
| Sapience retrieval failure (`sapience-retrieve.sh`) | The script already holds `$response` (the HTTP body) before discarding it on any non-2xx/malformed/zero-hit path | **Mechanical** — no new network call, capture only on the already-unhappy exit path | `sapience-retrieve.sh` lines 109-124 read directly |
| Sapience remember failure (`sapience-remember.sh`) | The script already distinguishes `set_aside`/`gated`/`written==0`/`ok!=true` and prints a precise diagnostic to stderr before a non-zero exit | **Mechanical** — caller (postflight wrapup, which has task context) checks `$?` and the stderr text | `sapience-remember.sh` lines 215-234 read directly |
| MCP tool failure — Sapience `mcp__sapience__*` **and** `tool_unavailable`/`mcp_abort_error` generally | Only the agent's own turn, reading the tool-call error surfaced in its transcript | **Not mechanical.** Verified: the merged `settings-hooks.json` carries no wildcard-matcher `PostToolUse` hook; the only `PostToolUse` entry matches `Write` only (a `specs/state.json` validator). `~/.sapience/mcp.py` (2044 lines, vendor-owned) raises `RuntimeError` on every 503/busy/gone path with no repo-side interception point. | Direct read of `mcp.py` lines 190-244 and the live merged hooks block |

The dispatch's own instruction — "do not assume an agent will reliably self-report" — is honored
literally: the MCP-tool-failure row above is recorded as a known, accepted gap, not papered over
with a hook this task's own cost ceiling forbids adding.

### The no-task-context case

`issue-record.sh` hard-requires `--task-dir` or `--task` (refuses, nothing written, otherwise).
A session with no task directory — exactly the ORIGIN story's diagnostic session — structurally
cannot use it. `events-append.sh`, by contrast, requires only `--event-type`, `--category`,
`--session`, and `--message`; `--task` is optional and nullable, and `events-format.md`
documents this nullability as existing precisely for non-task-scoped events (its own example:
"a `/refresh` sweep"). The no-task-context case therefore has a narrower answer than a new store:
route it to `events.jsonl` with `category: "blocker"`, `task: null`, when an agent chooses to
self-report. This still depends on agent cooperation (per the MCP-failure row above), but no
longer needs a task directory to land somewhere durable.

### Push vs. pull, re-measured

The repo registry (`~/.local/share/nvim/neotex-ai/extension-repo-registry.json`) was re-measured
in this session, not assumed from the dispatch's figure: **536 entries now** (up from the
dispatch's measured 313), of which exactly **3** are real repository paths
(`/home/benjamin/Projects/BimodalLogic`, `/home/benjamin/Projects/Logos/Theory`,
`/home/benjamin/Projects/Logos/Vision`) — the rest are `/tmp/tmp.*` fixture residue. The registry
has grown less usable, not more, since the dispatch was authored, reinforcing rather than
weakening its stated preference for a push model that takes on no repo-enumeration dependency.

All repos observed in the registry live on one machine under one user's home directory, so a
"push" is a plain local filesystem append to a fixed, known path
(`$HOME/.config/nvim/specs/...`), not a network call — no added latency, no new remote
dependency.

## Decisions

1. **Store**: `specs/{NNN}_{SLUG}/issues.jsonl` via `issue-record.sh` is the sole capture store
   for every error class in scope, Sapience included, for any failure occurring inside a task
   context. `specs/events.jsonl` via `events-append.sh` is the fallback for the one case
   `issue-record.sh` structurally cannot serve — no task directory exists. `specs/errors.json`
   is not revived.
2. **Contract correction**: `rules/error-handling.md`'s "Log the Error" section is corrected to
   name `issue-record.sh` as the mandated capture call for dispatch-time errors, replacing the
   stale `errors-append.sh` pointer. `errors.json`/`errors-append.sh`/the `/errors` command are
   left as a narrower, explicitly-decoupled triage surface — no longer described as *the*
   error-handling contract's write path. Full retirement of `/errors` is a larger, separate
   decision (it would delete a command and a schema) and is left to a follow-up rather than
   decided here, per the cost ceiling and the non-goal against unscoped rewrites.
3. **New class**: add `infrastructure/transport unavailable` to `issue-log.md`'s seed enum —
   gloss: "An external system genuinely unreachable or self-reporting unavailable (a Sapience
   503, a transport `ESERVFAIL`, a dead MCP connection), charged as infrastructure, not as work
   failed." This is a net-new addition (no existing entries use any spelling of this concept),
   not a renormalization of task 477's 22 identified fragmenting spellings, and does not touch
   `orchestrate-conclusion-aggregate.sh`'s grouping-time folding logic.
4. **Severity for the silently-degraded case**: a Sapience retrieval failure that degrades
   silently (never blocks a dispatch, costs no measurable time) is recorded at severity `minor`
   — the nearest fit on the existing four-rung scale, since `none` is reserved for `kind: "win"`.
   The scale's lack of a clean "zero-cost issue" rung is a real, if minor, gap; this task records
   it rather than editing the shared severity scale's semantics for all 34 existing callers.
5. **Collapse rule, general**: a caller that detects N repeats of one underlying event *before
   its first `issue-record.sh` call* writes exactly one line, carrying
   `tags.occurrence = {count, first_seen, last_seen}` via the existing open `tags` seam — no
   schema or script change required. Cross-entry, cross-dispatch collapse at the conclusion
   stage is **already implemented** (`group_by(.class)`); this task adds a stated citation-list
   render cap (e.g. first 10 + "N more, same class") as the size bound the dispatch asked for,
   since an unusually long outage could otherwise render an unbounded citations list.
6. **Capture-point honesty**: `sapience-retrieve.sh` and `sapience-remember.sh` gain mechanical
   capture on their existing failure paths only (zero added cost on the success path, no new
   network call). MCP tool failures (Sapience and general `tool_unavailable`/`mcp_abort_error`)
   remain agent-cooperation-dependent; the one in-scope, low-cost mitigation is a one-line
   self-report instruction added to the Sapience extension's context pointer, explicitly marked
   best-effort and not a substitute for mechanical capture.
7. **No-task-context routing**: route to `events.jsonl` (`category: "blocker"`, `task: null`)
   rather than inventing a new store, per the dispatch's own preference for the narrower answer.
8. **Push, not pull, for the central log**: the write lives inside the shared
   `issue-record.sh`/`events-append.sh` helpers — never at the 34+ call sites — appending a
   tagged copy to a fixed path under this repository, skipped when the writing repo already is
   the owning repo (avoids self-duplication). Concurrent-append safety is `flock`, mirroring
   every existing writer in this codebase. An absent or unwritable central path is a silent,
   documented no-op (checked via the parent directory's existence, never a `mkdir -p` into a
   stray location), never a retry and never a crash.

## Recommendations

- Implement decision 2 (the `error-handling.md` pointer correction) first — it is a documentation
  edit with no behavioral risk and immediately closes the dispatch's core "contract points at an
  abandoned store" complaint.
- Implement decision 3 (the new seed class) in the same pass as decision 2, in
  `context/formats/issue-log.md`; both are source-store documentation edits, zero call-site
  changes.
- Implement the `sapience-retrieve.sh`/`sapience-remember.sh` capture points (decision 6's
  mechanical half) as small, failure-path-only edits — retain the already-fetched body instead
  of discarding it, and call `issue-record.sh`/`events-append.sh` from the caller context that
  already owns task/session identity (`orchestrate-build-dispatch.sh` Stage 3.5 for retrieval;
  the postflight wrapup call site for remember), rather than plumbing task-dir arguments into the
  Sapience scripts themselves.
- Implement the central-log push (decision 8) inside `issue-record.sh` and `events-append.sh`
  directly, as a second, non-fatal, `flock`-guarded local append — this satisfies the "change the
  shared helper, not each caller" non-goal exactly.
- Leave 477, 484, 519, 543, and 562 untouched by this task's own implementation; carry the
  boundary statements below into the plan so none of their ground is silently re-solved.
- Treat full retirement of `errors.json`/`/errors` as a follow-up candidate, not part of this
  task's plan — flag it for a future task rather than deciding it under this dispatch's cost
  ceiling.

### Boundary against the five named open tasks

- **Task 477** (normalize issue-log class vocabulary / fix the aggregate's malformed
  repeated-flag call): owns folding the 22 *already-fragmenting* class spellings
  (case/separator folding, the `scope excursion` five-way merge, the free-text-sentence cases)
  and the `--tasks` repeated-flag parsing bug, both inside `orchestrate-conclusion-aggregate.sh`.
  This task's one new seed class is a net-new addition with no existing fragmenting spellings to
  fold, so it does not renormalize or preempt any of 477's four required outcomes (1a-1d) or its
  Part 2 flag-parsing fix. This task depends on 477's open-enum *mechanism*, not its pending
  edits.
- **Task 484** (collapse per-path scope-excursion rows into one record per drop event): owns the
  concrete fix at its two named emitter sites (`git-commit-phase.sh`, `git-commit-scoped.sh`).
  This task's general collapse rule (decision 5) is the shape 484's own fix should adopt — 484
  becomes **an application of** this task's general rule at those two sites — but this task does
  not itself edit either emitter script; that remains 484's own implementation.
- **Task 519** (infra-exempt transport-error dispatch deaths): owns the cycle-accounting
  exemption inside `orchestrate-cycle-postflight.sh` — whether a transport-interrupted dispatch
  is charged a failed work cycle. That decision runs on postflight's own transport-exception and
  recovery-decline signals, evaluated before any `issue-record.sh` call could even fire, and
  never reads the `class` vocabulary. This task's new class name gives prose language to the same
  underlying concept 519 independently exempts in cycle accounting, so the two should describe it
  consistently, but 519 does not consume this task's class field and this task does not touch
  `orchestrate-cycle-postflight.sh`'s charge/verdict logic.
- **Task 543** (distrust the inherited error count in the re-prompt relay): an unrelated defect —
  whether a resumed dispatch trusts a failure *count* handed to it by the interrupting context's
  remedy prose. No overlap with error storage, classification, or promotion. Left fully
  untouched.
- **Task 562** (conclusion stage drops null-resolution entries): **the underlying defect is
  already fixed**, verified directly in this session by reading
  `orchestrate-conclusion-aggregate.sh`'s live `--aggregate` pipeline
  (`(.resolution // "open") as $r | ...`) and `conclusion-stage.md`'s Filter Predicate, both of
  which already treat null/omitted `resolution` as `open` and report `implicit_open_count`. The
  task's own "DISPOSITION PENDING 2026-11-04" note confirms this independently. It stays open
  only pending an administrative transplant into a since-closed absorbing record — a bookkeeping
  matter this task does not touch.

## Risks & Mitigations

- **Risk**: correcting `error-handling.md`'s pointer without clarifying `errors.json`'s remaining
  scope could leave a second, smaller divergence (a rule that still half-describes a now-inert
  `/errors` surface). **Mitigation**: decision 2 explicitly states `/errors` as a narrower,
  decoupled triage surface rather than silently dropping any mention of it.
- **Risk**: the one-line agent self-report instruction for MCP tool failures could be read as
  "this is handled" when it is not. **Mitigation**: state explicitly, in the instruction itself
  and in this report, that it is best-effort and not a substitute for mechanical capture.
- **Risk**: the central-log push, if implemented without the owning-repo skip check, would
  duplicate every nvim-repo entry into itself. **Mitigation**: decision 8 states the skip
  condition explicitly as part of the design, not left to implementation discretion.
- **Risk**: an unbounded citations list on a very long outage could still render poorly even with
  the stated cap. **Mitigation**: the cap is a render-time truncation with a stated count,
  never a silent drop — the full set remains in the raw `issues.jsonl` evidence regardless.

## Context Extension Recommendations

- **Topic**: error-logging store topology.
- **Gap**: no existing context file states, in one place, which of the three stores is the
  general-purpose capture surface and which is the narrower/retired surface — a future reader
  re-discovers this the hard way, as this task's own dispatch had to.
- **Recommendation**: once decisions 1-2 above land, add a short section to
  `context/formats/issue-log.md` (or a new short domain note it links) stating the three-store
  topology and the one-line verdict for each, mirroring the clarity of that file's existing
  "Relation to the Six Existing Issue-Bearing Surfaces" table.

## Appendix

### Search queries / commands used

- `grep -rl "errors-append.sh" agent-system --include="*.sh" --include="*.md"` (18 files; cross-
  checked against a narrower `agents|skills|hooks|commands` directory restriction, 1 file)
- `jq '.errors | length' specs/errors.json`; `jq -r '.errors[-1].timestamp' specs/errors.json`
- `wc -l specs/events.jsonl`; `du -h specs/events.jsonl`
- `find specs -name "issues.jsonl" | wc -l`; `find specs -name "issues.jsonl" -exec cat {} \; | wc -l`
- `grep -rl "issue-record.sh" agent-system --include="*.sh" --include="*.md" | wc -l`
- `cat ~/.local/share/nvim/neotex-ai/extension-repo-registry.json | jq '.repos | length'`;
  `... | jq -r '.repos | keys[]' | grep -v '^/tmp'`
- `grep -n "retry_after\|starting\|RuntimeError" ~/.sapience/mcp.py`
- Direct reads: `sapience-retrieve.sh`, `sapience-remember.sh`, `issue-record.sh`,
  `errors-append.sh`, `events-append.sh`, `orchestrate-conclusion-aggregate.sh`,
  `issue-log.md`, `conclusion-stage.md`, `events-format.md`, `error-handling.md` (rule and
  standard), `errors.md` command, merged `settings-hooks.json`

### Durable evidence anchors

- Issue-log entries recorded this phase: see
  `specs/587_error_logging_contract_and_central_log/issues.jsonl`
  (`design-record defect or ambiguity`, one win on the group_by/implicit_open_count finding, one
  issue on the zero-production-writer finding for `errors-append.sh`).
