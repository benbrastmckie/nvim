# Research Report: Task #625

**Task**: 625 - Roadmap preflight approval gate
**Started**: 2026-11-14T03:00:00Z
**Completed**: 2026-11-14T03:34:00Z
**Effort**: medium (one new library, two gated callers, two doc updates, one test file)
**Dependencies**: None
**Sources/Inputs**:
- `agent-system/extensions/core/scripts/roadmap-integration.sh` (full read: `detect_layout`,
  `CLASSIC_HEADERS`, `refuse_unrecognised_layout`, `mode_regenerate`, library-sourcing convention)
- `agent-system/extensions/core/context/formats/roadmap-format.md` (Section Order, classic/stage
  layouts, Destructive-Overwrite Refusal)
- `agent-system/extensions/core/context/patterns/roadmap-update.md` (per-mode caller contract,
  Live Callers)
- `agent-system/extensions/core/skills/skill-roadmap/SKILL.md` (full read)
- `agent-system/extensions/core/agents/roadmap-agent.md` (full read, Write Contract)
- `agent-system/extensions/core/context/contracts/conclusion-stage.md` (Step 5, Allowed Tool
  Surface pointer)
- `agent-system/extensions/core/context/standards/postflight-tool-restrictions.md` (Conclusion
  Stage Move 5 Tool Restrictions table)
- `agent-system/extensions/core/docs/reference/standards/agent-frontmatter-standard.md` (Tool
  Withholding from Dispatched Subagents)
- `agent-system/extensions/core/skills/skill-meta/SKILL.md` Section 2 (pre-delegation
  `AskUserQuestion` reference shape)
- `agent-system/extensions/core/context/formats/issue-log.md` (16-class seed enum, Extensibility
  Rule)
- `agent-system/extensions/core/scripts/issue-record.sh` (CLI contract, `--task-dir` resolution)
- `agent-system/extensions/core/scripts/tests/test-roadmap-generation.sh` (structural model,
  source-store-first resolution convention)
- `agent-system/extensions/core/scripts/lib/status-vocabulary.sh` ("one sourced shared library,
  many consumers" header convention)
- `specs/state.json` (tasks 558, 562 — co-batch file-territory check, read-only)
- `/home/benjamin/.dotfiles/specs/ROADMAP.md` (out-of-scope reference file, read-only — the
  hand-migrated classic exemplar named in the dispatch's OUT OF SCOPE note)
**Artifacts**:
- This report: `specs/625_roadmap_preflight_approval_gate/reports/01_roadmap-preflight-gate.md`
**Standards**: report-format.md, source-store-deploy-boundary.md

## Executive Summary

- `detect_layout()` (`scripts/roadmap-integration.sh:436-451`) is a self-contained, side-effect-
  free function with no top-level dependency on the script's own argument parsing. It should be
  **extracted** into the new `scripts/lib/roadmap-preflight-lib.sh`, along with `CLASSIC_HEADERS`
  and its two fence-detection helpers, with `roadmap-integration.sh` sourcing the library back —
  the same "one sourced shared library, many consumers" shape `status-vocabulary.sh` already
  uses. **Sourcing the whole `roadmap-integration.sh` file is unsafe**: it parses `$@` and calls
  `exit` at its own top level, outside any function or `BASH_SOURCE`-guard.
- The generator's `detect_layout` only distinguishes `classic`/`stage`/`unknown` for a file that
  already exists; `absent` is a separate, prior check (`[[ ! -f "$ROADMAP_PATH" ]]`,
  `mode_regenerate` line ~735). The new library's public entry point must wrap both checks into
  one four-way verdict (`absent`/`unknown`/`classic`/`stage`) so neither caller re-derives the
  file-existence check independently.
- The gate is needed ONLY for `absent` and `unknown` — `classic` and `stage` both already
  round-trip through `--regenerate` with no approval needed. Deliverable 2's skeleton scaffold
  therefore fires on exactly those two verdicts: create-from-nothing for `absent`, repair-in-
  place for `unknown`.
- `skill-roadmap/SKILL.md`'s real write-mode call is NOT in that skill file at all — it is
  `roadmap-agent.md`'s own `Write Contract` final step (`roadmap-integration.sh --regenerate`,
  invoked by the dispatched agent, which cannot use `AskUserQuestion`). The dispatch's "Stage 1
  and Stage 3" framing maps onto: **Stage 1** (pre-dispatch) is where the new interactive gate
  must run, classifying the file and asking approval *before* `roadmap-agent` is ever dispatched,
  so that by the time the agent's own `--regenerate` call runs, the file already round-trips.
  **Stage 3** (the skill's postflight dry-run check) currently only echoes a soft `WARNING:` and
  needs no structural change to its check itself, but its surfaced text should name the gate
  explicitly as the first thing to re-verify if the dry-run still mismatches.
- `/orchestrate`'s conclusion stage (Move 5, Step 5) is the one genuinely non-interactive caller.
  Its `Bash` allow-list (`postflight-tool-restrictions.md:149`) currently permits
  `roadmap-integration.sh --regenerate` but **not** the new preflight library/script, nor
  `issue-record.sh` — both must be added. A structural tension exists for the `issue-record.sh`
  half of Deliverable 3(b): that script is fundamentally per-task (`--task-dir`/`--task N`
  required, directory must exist), while Move 5 itself is explicitly **not** task-scoped (its own
  channels (b)/(c) already route non-task-scoped evidence to `events-append.sh` →
  `specs/events.jsonl` for exactly this reason). See Decisions below for the recommended
  resolution.
- None of the 16 seed `issue-log.md` classes precisely fits "a write needing approval was
  blocked because no interactive surface exists at this call site." `infrastructure/transport
  unavailable` (the dispatch's named candidate) is a poor fit — it describes an external system
  being unreachable, not an internal approval gate with no answerer. `gate collision` is the
  closest existing seed class but is a stretch. The Extensibility Rule explicitly sanctions
  minting a new, precisely-named class on first use; recommended below.

## Context & Scope

Researched the full call-site topology for `roadmap-integration.sh --regenerate` (the only write
mode in scope — `--prune` is a deprecated alias and out of scope per `conclusion-stage.md`'s own
D3), the generator's existing layout-classification machinery, the two places `AskUserQuestion`
can and cannot run, the non-interactive degrade mechanism available at the conclusion stage, and
the exact doc/test files the dispatch names for updates. Scope excludes any implementation —
this is the research phase only. Scope also excludes redoing the `.dotfiles` hand-migration
(explicitly out of scope in the dispatch) and excludes converting the 558/562 file-territory
overlap into a dependency edge (explicitly a co-batch/ordering note, not a dependency).

## Findings

### 1. `detect_layout` is cleanly extractable, not shelled-out-only

`scripts/roadmap-integration.sh:436-451` (`detect_layout`) depends only on:
- `CLASSIC_HEADERS` (array literal, lines 391-400)
- `body_has_orchestrate_fence` / `roadmap_has_orchestrate_fence` (lines 404-417, pure functions)

None of the three touch `$MODE`, `$ROADMAP_PATH`-as-global, or any other script-level state
beyond the `FILE` argument passed in. The script's own top-level body (lines 70-100+) parses
`$@` directly and calls `exit 1` on bad input, **outside any function and with no
`[[ "${BASH_SOURCE[0]}" == "${0}" ]]` run-as-script guard**. Sourcing the whole file from a
second script or from an interactive skill's own shell context would therefore re-run that
argument parser against whatever `$@`/no-args state the sourcing context happens to have, and
any resulting `exit` would terminate the *sourcing* shell, not just the sub-invocation. Shelling
out (`bash roadmap-integration.sh --print 2>&1 | grep ...`) would work but adds a process fork
and stdout/stderr scraping for a decision that is three small functions.

**Conclusion**: extract `CLASSIC_HEADERS`, `body_has_orchestrate_fence`,
`roadmap_has_orchestrate_fence`, and `detect_layout` into
`scripts/lib/roadmap-preflight-lib.sh`; have `roadmap-integration.sh` source it back at line ~52
(immediately after its existing `source "${SCRIPT_DIR}/lib/status-vocabulary.sh"`, following the
exact convention already used for that library). This satisfies "do NOT duplicate the eight-
header list in two places" by construction — there is exactly one copy, and the generator reads
it from the library rather than the library reading it from the generator.

### 2. The verdict space is 4-way, but `detect_layout` itself only produces 3

`detect_layout` returns `classic`/`stage`/`unknown` for a file it is handed — it has no file-
existence check of its own. The `absent` case is checked by the *caller*
(`mode_regenerate`, `scripts/roadmap-integration.sh` line ~735:
`if [[ ! -f "$ROADMAP_PATH" ]]; then echo "NOTE: no roadmap tracked..." ; return 0; fi`) before
`detect_layout` is ever invoked. The new library's public entry point (e.g.
`roadmap_preflight_classify PATH` → prints exactly one of `absent|unknown|classic|stage` to
stdout) must perform the existence check itself and only fall through to the extracted
`detect_layout` when the file exists — otherwise every caller of the new library has to
re-implement the existence check independently, which is the same duplication risk the dispatch
warns against for the header list.

### 3. The gate fires on exactly two of the four verdicts

Per `roadmap-format.md`'s Destructive-Overwrite Refusal and Section Order:
- `classic` and `stage` both already round-trip through `--regenerate` with **no approval
  needed** — `--regenerate` on either succeeds today (idempotently) with no gate.
- `unknown` is the loud refusal case (`refuse_unrecognised_layout`, non-zero exit, no write).
- `absent` is today's **silent, successful no-op** (`NOTE: ...`, exit 0) — not a failure, but
  also not a rendered file; the dispatch's problem statement names it alongside `unknown`
  because both leave `roadmap_batches`/`roadmap_notes` judgment stuck in `state.json` with no
  rendered file to show it.

So the approval gate (both arms of Deliverable 3) is needed only when the classify verdict is
`absent` or `unknown`; `classic`/`stage` pass straight through to `--regenerate` with no gate at
all. This directly grounds Deliverable 2's two scaffold cases: **create** (verdict `absent`,
nothing to preserve) and **repair** (verdict `unknown`, authored prose must be preserved).

### 4. The real write-mode call under `skill-roadmap` lives in `roadmap-agent.md`, not the skill

`skill-roadmap/SKILL.md`'s own Stage 3 ("Postflight — Verify") only ever calls
`roadmap-integration.sh --regenerate --dry-run` (read-only) as an idempotence sanity check, and
degrades today to a soft `echo "WARNING: ..."` when the dry-run doesn't report
`no content change`. The **actual** write-mode `--regenerate` call is `roadmap-agent.md`'s own
`Write Contract` final step, executed inside the dispatched `roadmap-agent` subagent — which
categorically cannot call `AskUserQuestion` (measured, `agent-frontmatter-standard.md`'s "Tool
Withholding from Dispatched Subagents": withheld regardless of `tools:`/`disallowedTools:`
configuration, confirmed across five live dispatch configurations).

This means the dispatch's "Stage 1 and Stage 3" framing for `skill-roadmap/SKILL.md` maps onto
the skill's own stages as follows:
- **Stage 1** (session id / argument parsing, today's only content) is the right place to
  *insert* the new interactive gate: classify the file there, and if the verdict is `absent` or
  `unknown`, run `AskUserQuestion` for approval **before Stage 2 ever dispatches
  `roadmap-agent`** — exactly the "collect every user-choice point before the `Agent`-tool
  dispatch" shape `skill-meta/SKILL.md`'s Section 2 already proves out (see Finding 5). On
  approval, write the scaffold skeleton immediately in this same pre-dispatch stage (never
  inside the agent), so that `roadmap-agent`'s own later `--regenerate` call lands on an already-
  `classic` file and succeeds without needing any gate of its own.
- **Stage 3** (postflight verify) keeps its existing dry-run check unchanged in mechanism, but
  its `WARNING:` text should be updated to point at the new Stage 1 gate as the first thing to
  check if the mismatch recurs — since after this task, a Stage-3 mismatch should be rare (Stage
  1 already pre-empted the refusal case) and more likely indicates a race or a scaffold defect
  than the original, now-fixed "nobody escalated the refusal" problem.

### 5. `skill-meta/SKILL.md` Section 2 is a proven, literal template for this exact shape

Section 2 ("Run the Interview (Pre-Delegation — `AskUserQuestion` Runs Here)") opens with the
identical justification this task needs almost verbatim: *"`AskUserQuestion` is measured
categorically withheld from every `Agent`-tool dispatch of a named `subagent_type`... Every
user-choice point this command needs must therefore be collected in *this skill's own
execution*, before [dispatch]."* It then holds every collected answer for the delegation
context, and the dispatched agent "performs no further asking — it receives these answers
already resolved." The new `skill-roadmap` Stage 1 gate should follow this shape exactly: ask,
write the scaffold (or decline), and pass only the resolved outcome into `roadmap-agent`'s
dispatch prompt — never a flag telling the agent to ask anything itself.

### 6. The conclusion stage's non-interactive degrade has a structural scoping tension

`conclusion-stage.md` Step 5 currently calls `roadmap-integration.sh --regenerate` unconditionally
and commits `specs/ROADMAP.md` alone. `postflight-tool-restrictions.md`'s Move 5 `Bash` allow-
list (line 149) permits exactly that invocation and five other named scripts — **it does not yet
permit the new preflight library/script, nor `issue-record.sh`**. Both additions are required for
Deliverable 3(b) to be executable at all under the existing tool-restriction gate.

A second, more structural issue: `issue-record.sh` requires `--task-dir PATH` (an existing
directory) or `--task N` (resolved via `task-lookup-lib.sh`) — it is fundamentally a per-task
log writer (`${TASK_DIR}/issues.jsonl`). Move 5 itself is **explicitly not task-scoped** for
exactly this reason in its own existing design: channels (b) and (c) (its two other evidence-
recording paths) both write to `specs/events.jsonl` via `events-append.sh`, not to any per-task
`issues.jsonl`, specifically because Move 5 runs once per batch rather than once per task.
However, Move 5 *does* already carry "every task this invocation touched" as a resolved list (its
`Read` allowance is scoped exactly that way), so a per-task-dir loop is mechanically available if
wanted.

### 7. No seed `issue-log.md` class is a precise fit; the Extensibility Rule covers this directly

Reviewed all 16 seed classes against the actual failure shape ("approval required, no answerer
present, write is correctly withheld — this is not infrastructure being down, and not two
mechanical gates disagreeing"):
- `infrastructure/transport unavailable` (dispatch's named candidate): poor fit — its gloss is
  explicit that it records "infrastructure being unavailable, not the task's own work failing";
  here the task's own gate logic is working exactly as designed, nothing external is down.
- `gate collision` ("Two verification gates... disagreed or blocked each other"): the closest
  existing seed, but a stretch — there is one gate (the approval requirement) and one missing
  precondition (an interactive surface), not two gates in disagreement.
- No other seed class references approval, human-in-the-loop, or interactive-surface absence at
  all.
`issue-log.md`'s own Extensibility Rule states plainly: *"a genuinely new failure mode must be
recordable the first time it is hit, not only after a schema revision adds it."* `issue-record.sh`
accepts any `--class` value (warns to stderr on an unrecognized one, never refuses). This is
exactly that situation — see Decisions below for the recommended new class string.

### 8. `roadmap-update.md`'s "Live Callers" section is already stale, independent of this task

`context/patterns/roadmap-update.md`'s "Live Callers" section states `--regenerate` "has exactly
one live caller today: `/orchestrate`'s conclusion stage." This is inaccurate as of
`roadmap-agent.md`'s existing `Write Contract` (which also invokes `--regenerate` directly, as a
second live caller, independent of anything this task adds). This task's own ALSO-UPDATE scope
already covers `roadmap-update.md` ("document the preflight as part of every write-mode caller's
obligation") — the plan phase should fold this pre-existing inaccuracy into the same edit pass
rather than treating it as a separate finding needing its own task, since it is the same section,
the same sentence's premise, and the same file this task already touches.

### 9. Scaffold content precedent for the six authored-verbatim sections

The out-of-scope `.dotfiles` hand-migration (read-only reference) shows the lived convention for
the two measured-content sections: `## Goal` carries a short owner-authored mission statement
(never fabricated by a script), and `## Gate state` carries `"Not yet measured."` as its
placeholder when no check has been run yet — exactly the kind of honest, non-invented stub a
*mechanical* scaffolder (never an agent making judgment calls, per the HARD CONSTRAINT) can
safely emit for a verdict-absent file. `## Unfiled observations (none worth a task yet)` is
described in `roadmap-format.md` itself as "a scratch list, deliberately unstructured" — the
natural landing spot for an `unknown`-verdict file's non-conforming authored prose that the
scaffold must preserve rather than discard (see Decisions below).

## Decisions

1. **Library placement and sourcing mechanism**: `scripts/lib/roadmap-preflight-lib.sh` will hold
   `CLASSIC_HEADERS`, `body_has_orchestrate_fence`, `roadmap_has_orchestrate_fence`, and
   `detect_layout`, extracted verbatim from `roadmap-integration.sh`. `roadmap-integration.sh`
   sources this library back (after its existing `lib/status-vocabulary.sh` source line),
   replacing its own in-file copies. The library additionally exposes one new public entry point,
   `roadmap_preflight_classify PATH` (prints `absent|unknown|classic|stage`, exit 0 always —
   classification never fails), performing the file-existence check itself before delegating to
   `detect_layout` for an existing file. This is the single function both gated callers invoke;
   neither re-implements the existence check or the header list.
2. **Gate applicability**: the approval gate (both arms) fires only on verdict `absent` or
   `unknown`. Verdict `classic`/`stage` proceed straight to `--regenerate`, unchanged, no gate.
3. **`skill-roadmap/SKILL.md` placement of the interactive arm**: insert the gate at the skill's
   existing Stage 1 (before Stage 2's `roadmap-agent` dispatch), modeled directly on
   `skill-meta/SKILL.md` Section 2's pre-delegation interview shape — classify, `AskUserQuestion`
   if gated, write the scaffold on approval (in the skill's own execution, never inside the
   dispatched agent), then proceed to dispatch with the file already `classic`. Stage 3's
   existing dry-run check stays mechanically the same; only its `WARNING:` text is updated to
   name Stage 1's gate as the first thing to check on a recurrence.
4. **Conclusion-stage (non-interactive) degrade mechanism**: add the new library/script and
   `issue-record.sh` to `postflight-tool-restrictions.md`'s Move 5 `Bash` allow-list. For the
   actual degrade action when verdict is `absent`/`unknown` at Step 5: emit the named structured
   warning in Step 5's own report output (loud, not silent), record it durably via
   `events-append.sh` → `specs/events.jsonl` (the mechanism Move 5 already uses for its own
   non-task-scoped evidence, for the identical structural reason: Move 5 is not task-scoped), and
   additionally loop `issue-record.sh` once per task-dir in the current invocation's own
   already-resolved task list (the same set its `Read` allowance already names) — satisfying the
   dispatch's explicit instruction to use `issue-record.sh` while resolving the task-dir
   requirement in a way consistent with Move 5's existing per-task evidence pattern, rather than
   inventing a non-task-scoped exception to that script's contract. **Never** call
   `--regenerate` and never auto-write the scaffold at this call site when gated — the write is
   simply skipped for this cycle, loudly reported, and `specs/ROADMAP.md` stays as it is.
5. **New `issue-record.sh` `--class` value**: mint a new class rather than force-fitting an
   imprecise seed one, per the Extensibility Rule. Recommended string:
   `"roadmap regenerate blocked, no approval surface"` — precise, distinguishes itself cleanly
   from `infrastructure/transport unavailable` (nothing external is down) and from `gate
   collision` (one gate, one missing precondition, not two disagreeing gates). Suggested
   `--severity costly` (matches the measured consequence: judgment stuck in `state.json` for
   weeks, unrendered) and `--resolution open` (the write is deferred, not abandoned — the next
   interactive `/roadmap` run resolves it).
6. **Scaffold placeholder content**: for verdict `absent`, the six authored-verbatim/measured-
   by-hand sections get minimal, honest, non-fabricated placeholders (e.g. `## Gate state`:
   "Not yet measured."; the remaining four: "None yet." or an equivalent short stub) — never an
   invented mission statement or rule, consistent with the HARD CONSTRAINT against an agent
   hand-authoring roadmap content. `## Next` and `## Open work` get a trivial placeholder body
   (e.g. empty, or a one-line "(rendered by --regenerate)") since `--regenerate` overwrites both
   immediately after approval, in the same gated flow. For verdict `unknown`, the same eight-
   header skeleton is written, but the **original file's full prior content** (whatever it was —
   it did not parse into either recognized vocabulary) is preserved by appending it verbatim
   under `## Unfiled observations (none worth a task yet)`, the section `roadmap-format.md`
   itself already describes as "a scratch list, deliberately unstructured" — the correct home for
   salvaged content that does not fit the structured sections, rather than silently discarding it.
7. **`roadmap-update.md` edit scope**: the plan phase's edit to this file (already in scope per
   ALSO UPDATE) should also correct the "Live Callers" section's inaccurate "exactly one live
   caller" claim (Finding 8) in the same pass, since `roadmap-agent.md` is a second, pre-existing
   live caller independent of anything this task adds.

## Recommendations

1. Implement `scripts/lib/roadmap-preflight-lib.sh` first (Deliverable 1), with its own unit-test
   file (or an added section in `scripts/tests/test-roadmap-generation.sh` — see Recommendation 4)
   covering all four verdicts against synthetic fixtures, before touching either caller — both
   gated callers depend on its exact function signature and output contract.
2. Refactor `roadmap-integration.sh` to source the new library and remove its now-duplicated
   `CLASSIC_HEADERS`/`detect_layout`/fence-helper definitions in the same commit as the library's
   introduction, not as a later cleanup pass — leaving two copies live even briefly reintroduces
   exactly the duplication risk the dispatch calls out.
3. Build the `skill-roadmap/SKILL.md` Stage 1 gate as a literal structural mirror of
   `skill-meta/SKILL.md` Section 2 (ask before dispatch, hold the resolved outcome, pass it into
   the delegation context, dispatch `roadmap-agent` only after) rather than inventing a new shape
   for an already-proven pattern.
4. Extend `scripts/tests/test-roadmap-generation.sh`'s existing structural model (mktemp scratch
   tree, source-store-first resolution for the file under test, checksum guard on the real
   `specs/state.json`/`specs/ROADMAP.md`) to add preflight-lib coverage, rather than starting a
   parallel test harness — the dispatch's required cases (absent, unknown, classic, stage,
   scaffold-then-regenerate idempotence) all fit this suite's existing fixture-building helpers.
5. In the same implementation pass, update `postflight-tool-restrictions.md`'s Move 5 `Bash`
   allow-list table (two new entries: the preflight library/script, `issue-record.sh`) — omitting
   this leaves Deliverable 3(b) blocked by the tool-restriction gate even after the code exists.
6. Treat Decision 5's new `--class` string as a recommendation for the plan/implementation phase
   to adopt or revise, not a final mechanical answer — the planner should re-confirm against
   `issue-log.md`'s current seed list at implementation time in case a closer-fitting class has
   been added since this research pass.

## Risks & Mitigations

- **Risk**: a future edit to `roadmap-integration.sh` re-inlines `detect_layout` logic (e.g. a
  quick bugfix patched directly in the script rather than in the library) and the two copies
  drift. **Mitigation**: the extraction should leave a one-line header comment in
  `roadmap-integration.sh` at the `source` line pointing back at the library as the sole owner,
  mirroring `status-vocabulary.sh`'s own "single source of truth" framing.
- **Risk**: the conclusion-stage per-task `issue-record.sh` loop (Decision 4) silently does
  nothing when the current invocation's task list is empty or unresolved (an edge case this
  research did not exercise against a live Move 5 run). **Mitigation**: the `events-append.sh`
  write in the same decision is the durable record regardless of task-list resolution, so the
  per-task loop is additive evidence, not the sole record — a planner should confirm this
  ordering (events-append first, issue-record loop best-effort second) in the implementation.
- **Risk**: scaffolding an `unknown` file and dumping its full prior content under `## Unfiled
  observations` could produce a very large section if the prior file was substantial (e.g. a
  hand-authored stage-layout draft that just missed the structural predicate by one fenced
  block). **Mitigation**: this is explicitly the safer failure mode (nothing lost, visibly
  flagged for human triage) versus any alternative that discards content; no mitigation beyond
  that is warranted here, but the plan phase should state this tradeoff explicitly rather than
  silently accepting it.

## Context Extension Recommendations

- **Topic**: non-task-scoped evidence writers at the conclusion stage.
- **Gap**: `conclusion-stage.md` and `postflight-tool-restrictions.md` document channels (b)/(c)'s
  `events-append.sh` pattern for non-task-scoped evidence, but nothing yet states the general
  principle (stated ad hoc in this report's Finding 6) that `issue-record.sh`'s per-task
  directory requirement makes it structurally unsuited to a batch-level, non-task-scoped caller
  without an explicit per-task-dir loop.
- **Recommendation**: once this task's implementation settles the conclusion-stage degrade
  pattern in practice, consider adding a short cross-reference in `issue-log.md` itself (near its
  existing per-task framing) naming Move 5's dual-write (events.jsonl + per-task loop) as the
  precedent for any future non-task-scoped caller of `issue-record.sh`, so the next such caller
  does not have to re-derive this reasoning from scratch.

## Appendix

- Script under research: `agent-system/extensions/core/scripts/roadmap-integration.sh`
  (`detect_layout` lines 436-451; `CLASSIC_HEADERS` lines 391-400; `mode_regenerate` lines
  ~735-752; library-sourcing convention lines 47-51).
- `grep -n "detect_layout\|unknown\|ERROR:\|NOTE: no roadmap\|classic\|stage\b"
  scripts/roadmap-integration.sh` — located every classification/refusal call site.
- `grep -n "Move 5" -A 60 context/contracts/conclusion-stage.md` — located Step 5's executable
  body and the Roadmap Generator Caller Status section.
- `grep -n "Conclusion Stage" -A 60 context/standards/postflight-tool-restrictions.md` — located
  the Move 5 Allowed Tool Surface table (line 149) and Commit Surface table.
- `grep -n "Tool Withholding" -A 40 docs/reference/standards/agent-frontmatter-standard.md` —
  confirmed the measured `AskUserQuestion` withholding across five dispatch configurations.
- `sed -n '92,148p' skills/skill-meta/SKILL.md` — Section 2's pre-delegation interview shape,
  the reference template named in the dispatch.
- `grep -n "class\|enum" -A2 context/formats/issue-log.md` and the seed-class table — basis for
  Finding 7 / Decision 5.
- `jq -r '.active_projects[] | select(.project_number==558 or .project_number==562) | ...'
  specs/state.json` — confirmed the co-batch file-territory note's two referenced tasks, read-only,
  no edge added (per the dispatch's explicit instruction not to convert this into a dependency).
