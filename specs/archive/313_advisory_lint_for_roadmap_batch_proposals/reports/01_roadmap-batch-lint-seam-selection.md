# Research Report: Task #313

**Task**: 313 - Advisory lint for hand-authored /orchestrate batch proposals in ROADMAP.md phase blocks
**Started**: 2026-11-11T21:09:23Z
**Completed**: 2026-11-11T21:16:23Z
**Effort**: medium (seam re-investigation + grammar re-verification; no code written)
**Dependencies**: Task 306 (completed, satisfied), Task 328 (completed), Task 344 (completed), Task 387 (completed), Task 401 (completed)
**Sources/Inputs**: Codebase read (agent-system/extensions/core source store, specs/state.json, specs/ROADMAP.md), no web search needed
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **The seam is settled: LIVE SEAM 1 (`context/contracts/conclusion-stage.md`, Step 5/Step 7, right before Step 6's report).** It is the only live, command-reachable, roadmap-touching call site today. Seam A (a mode on `roadmap-integration.sh` invoked by a `/review` rewiring) and the original Seam B (`commands/review.md`) are both confirmed dead; LIVE SEAM 2 (`/orient`, task 436) does not exist yet and is `not_started` with no dependency edge onto it.
- **The script itself stays a standalone `scripts/lint/lint-roadmap-batch-proposals.sh`**, per the already-declared `file_scope` and the 22-script `scripts/lint/*.sh` naming/registration/test convention (3 of the 22 are already not wired into `verify-deploy.sh`, so an unwired lint script has live precedent).
- **`file_scope` must change**: drop `agent-system/extensions/core/commands/review.md` (the file is slated for removal by the /orient record) and add `agent-system/extensions/core/context/contracts/conclusion-stage.md` (the new call site). This creates a real, mandatory territory overlap with task 402 (`conclusion_channels_become_evidence_only`), a **concurrent sibling in this very dispatch cycle** that also declares `conclusion-stage.md` in its own `file_scope` — see Risks & Mitigations.
- **Major premise risk, not previously flagged**: task 603 ("Make ROADMAP.md a generated artifact rendered from state.json", `not_started`) is scheduled in the roadmap's own next Run batch and will move batch membership/rationale out of `## Next` prose entirely into `state.json` entries maintained by a new `/roadmap` command — obsoleting the exact hand-authored-markdown shape this lint parses. See Risks & Mitigations; a `user_decision` is set on this.
- The dependency-grammar divergence the task description worried about is **resolved, not merely re-measured**: `context/formats/roadmap-format.md` (261 lines) now formally specifies two auto-detected layouts (`classic`, `stage`) covering exactly the two shapes the task description described as "divergent." The lint must call the same `detect_layout()` discrimination `roadmap-integration.sh` uses, not assume one shape.
- All reuse directives (splice `scripts/lib/file-scope-overlap.sh`, consume `generate-task-order.sh --print`, never modify either) remain valid and unobstructed.

## Context & Scope

This is a re-investigation dispatch: the task description already records two rounds of
self-correction (an initial seam pair, both invalidated 2026-11-02; a replacement "LIVE SEAM 1 /
LIVE SEAM 2" pair, left open). Research here (a) re-verifies every measured claim against the
live tree as of 2026-11-11, (b) resolves the LIVE SEAM 1 vs. LIVE SEAM 2 choice, (c) re-derives
the `file_scope` consequences of that choice, and (d) surfaces one new risk the task description
does not mention: an in-flight redesign of `ROADMAP.md` itself that would retire the format this
lint is built to parse.

Findings (a), (c), (d), (e), (f) themselves (what the lint checks) are **not** re-litigated here
— the task description's rulings on scope, finding (b)'s rejection, and the validator-never-
proposer constraint are settled and are treated as given, per the dispatch's own instruction.

## Findings

### Codebase Patterns

**1. `specs/ROADMAP.md` in this repository is `classic` layout, confirmed live.** All eight
`CLASSIC_HEADERS` are present (`## Goal`, `## Gate state`, `## Next`, `## Open work`,
`## Checks before and after every call`, `## Settled decisions (do not re-litigate)`,
`## Standing rules`, `## Unfiled observations (none worth a task yet)`). `## Next` (line 87)
contains exactly the shape `context/formats/roadmap-format.md`'s Next Grammar specifies: a fenced
block of `/orchestrate {ids} {flags}   # {rationale}` lines, followed by authored
`Why this order:` prose. There is **no** literal `**Run**:` marker anywhere in the live file —
the task description's claim that "the consumer repo uses a literal `**Run**:` marker" is stale
and should not be carried into the implementation; the only literal marker is the `## Next`
section header itself plus the fenced block.

**2. The grammar divergence is resolved at the format-contract level, not just re-measured.**
`context/formats/roadmap-format.md` (261 lines, re-read in full) specifies **two** structurally
auto-detected layouts:
   - `classic`: all eight literal headers present; `## Next`'s fenced block holds the Run-line
     grammar (regex `^/orchestrate ([\d, ]+)(\s+(-\S.*?))?(\s{3}# (.+))?$`, stated twice in the
     file).
   - `stage`: a `## Stage N` header plus *any* `## ` section whose body contains a fenced block
     with at least one `/orchestrate ` line (the "run-order section"); every other section is
     retained byte-for-byte. The task description's "global agent-system repo uses `## Call N`"
     shape is exactly what this layout's structural (not enumerated-header) detection was built
     to recognize, including rename drift.
   - An unrecognized vocabulary is `unknown` and both write modes refuse loudly rather than
     guess. This permanent property means the new lint must **not** assume `classic` — it needs
     the same `detect_layout()` branch `roadmap-integration.sh` already implements (functions,
     not a sourced-library export — see Decisions below for the reuse consequence).

**3. `roadmap-integration.sh` has exactly one live, command-reachable caller: `/orchestrate`'s
conclusion stage.** Re-verified via `grep -rln roadmap-integration.sh` across the source store:
every other occurrence is documentation, `manifest.json` registration, a test, or the quarantined
copy under `scripts/deprecated/`. `context/patterns/roadmap-update.md`'s own "Live Callers"
section confirms this explicitly and states the open gap plainly: *"Neither `/todo`'s skill...
nor `/review`... invokes this script... A separate, advisory lint over hand-authored `## Next`
batch proposals is already planned as dependent work elsewhere."* That sentence is this task,
and it is the strongest textual confirmation that Seam 1 (conclusion stage) is where this system
already expects the lint to land.

**4. The exact hook point inside `conclusion-stage.md`**: Step 5 ("Roadmap update") invokes
`roadmap-integration.sh --regenerate` and commits `specs/ROADMAP.md` alone; Step 7 ("Suggest next
batch", deliberately numbered out of document order so its output exists before Step 6 renders
it) runs immediately after; Step 6 ("Report") renders both. `--regenerate` never rewrites the
authored Run lines themselves (only `## Open work` and the coverage appendix) — so by the time
Step 5 finishes, the file's hand-authored batch content is exactly what a human last wrote,
unmodified, and ready to lint. The natural hook is: run the new lint **after Step 5, alongside or
just before Step 7**, folding its advisory findings into Step 6's report. This runs once per
`/orchestrate` invocation — far more frequent than "at dispatch or never," which is the
improvement the task's own GOAL text asks for (it does not ask for literal keystroke-time
linting, which no command-reachable hook exists for today — ROADMAP.md's `## Next` section is
edited by hand outside any command, since no `/roadmap` command exists yet; see Finding 6 below).

**5. LIVE SEAM 2 does not exist and is not a dependency.** `specs/state.json` task 436
(`orient_command_with_scout_agent_retire_review`) is `status: "not_started"`. It is **not** in
task 313's `dependencies[]` array (`[306, 328, 344, 387, 401]`). Choosing Seam 2 today would
require adding a new hard dependency on an entirely un-started record, deferring this task
indefinitely for no immediate benefit over Seam 1 — and the record's own description already
confirms `/review` (the file Seam B originally targeted) is being removed by that same record,
so Seam B is dead for the reason the task description already states.

**6. No `/roadmap` command exists today — hand-editing is literally the only path.** There is no
`commands/roadmap.md`, `skills/skill-roadmap/`, or `agents/roadmap-agent.md` in the source store.
`## Next`'s Run lines are therefore added purely by a human or an agent hand-editing the markdown
file directly, in whatever session happens to be reviewing the roadmap — there is no command
moment to hook "at authoring time" even in principle, today. This makes Seam 1 (checked once per
`/orchestrate` invocation, which is frequent) the closest practically achievable approximation to
"authoring time" that exists in the live system, not a compromise choice among several live
options.

**7. Finding (a)'s dispatch-time analogue, re-confirmed.** `docs/architecture/batch-admit-schema.md`'s
`idle_overlap_advisory` (now documented under schema `orchestrate-batch-admit-v7`, originally
introduced in v5) still emits exactly the fact the task description cites: a `cross_batch`
overlap against a task carrying no execution evidence is surfaced via `idle_overlap_advisory` on
an `admit` verdict, never blocked. The Blocking vs. Advisory Classification Table confirms this
row is `ADVISORY` by construction (condition 2 of the two-condition criterion fails: no second
session is running, so there is no silent concurrent-write harm) — directly corroborating that
finding (a) as an *authoring-time* check must also be advisory, exactly as the task description
already concludes, never a new structural claim.

**8. The "absent `file_scope`" posture this lint should assume is already a landed, settled
ruling**, not an open question this task waits on. `docs/architecture/batch-admit-schema.md`'s v6
ruling: a `cross_batch` comparison against a candidate with an absent `file_scope` is always
`ADVISORY` (`absent_scope_advisory`), never a block — matching the task description's own
assumed posture ("no evidence of overlap" -> finding (a) cannot fire). The task description's
"NOT a dependency, but note" framing for this point is correct: it is settled, requires no
`dependencies[]` edge, and needs no reconciliation beyond the one-line posture note already
specified.

**9. Gate Catalogue citation for finding (e), re-verified.** `context/patterns/batch-orchestration-
guardrails.md`'s Gate Catalogue table lists "Unmet predecessor (dependency-graph eligibility)" as
an **ORDERING CONSTRAINT**, with the stated rationale: *"A task excluded from `eligible_tasks`
because a predecessor is still in-progress is re-admitted automatically once that predecessor
reaches a terminal state — no separate mechanism is needed to clear it."* This is the exact
citation finding (e)'s declarative sentence should point to; no restatement of guardrails doctrine
is needed in the format contract beyond a pointer plus the one sentence the task already drafted.

**10. The `scripts/lint/*.sh` convention has grown since the task description was written.**
Live count: **22** scripts (not the "ten" the OPEN RESEARCH QUESTION section cites), registered
in `manifest.json`'s `provides.scripts` array alongside a `scripts/tests/test-*.sh` companion
(e.g. `lint-dead-command-recommendations.sh` / `tests/test-lint-dead-command-recommendations.sh`).
Of the 22, **19 are wired into `verify-deploy.sh`** and **3 are not**
(`lint-json-channel-discipline.sh`, `lint-test-harness-adoption.sh`,
`lint-unit-integration-boundary.sh`) — so a lint script that is registered in `manifest.json` and
tested, but deliberately *not* wired into the `verify-deploy.sh` battery because its subject
(a consumer repo's `specs/ROADMAP.md`) is the wrong fit for that battery, already has live
precedent and is not a novel shape.

**11. `roadmap-integration.sh` is a monolithic executable, not a sourced library.** It opens with
its own `set -euo pipefail` and is always invoked as `bash scripts/roadmap-integration.sh ...`,
never sourced; its internal functions (`detect_layout`, `extract_section`, `covered_ids_from`,
etc., 1029 lines total) are not exported for another script to splice, unlike
`scripts/lib/file-scope-overlap.sh`'s deliberate `FILE_SCOPE_OVERLAP_JQ_DEFS` export shape. A
new lint consuming layout detection therefore cannot "splice" it the way it splices the overlap
predicate — see Decisions below for the two live options this leaves.

**12. No existing lint checks cited-path resolvability.** Searched `scripts/lint/*.sh` for any
existing "unresolvable path" / "dangling citation" check; none exists. Finding (f) is genuinely
novel, not a near-duplicate of anything live.

### External Resources

Not applicable — this is a pure codebase/state-graph research task; no web search was needed or
performed.

## Recommendations

1. **Call site**: hook the new lint into `context/contracts/conclusion-stage.md`, invoked after
   Step 5 (`roadmap-integration.sh --regenerate`) and before/alongside Step 7, with its advisory
   findings folded into Step 6's report rather than a separate stderr-only channel. This keeps
   the "evidence-cited, gated" shape the conclusion stage already uses for its three channels —
   but note the lint's own findings are **not** routed through the issue-log/channel mechanism at
   all (they are not an `issues.jsonl` entry type); they are a direct, always-rendered advisory
   section in the Step 6 report, parallel to (but structurally separate from) the three gated
   channels.
2. **`file_scope` update**: at planning time, replace `agent-system/extensions/core/commands/
   review.md` with `agent-system/extensions/core/context/contracts/conclusion-stage.md` in task
   313's declared `file_scope`. Also consider adding a one-line pointer edit to
   `context/patterns/roadmap-update.md`'s "Live Callers" section (it already anticipates this
   lint by name in prose; once the lint exists, that prose should name the actual script path) —
   a small, optional, single-line addition, not a reason to delay.
3. **Layout detection**: implement (or call) the identical `classic`/`stage`/`unknown` discrimination
   `roadmap-integration.sh`'s `detect_layout()` uses before parsing `## Next` (or the stage
   layout's run-order section) for batch lines. Since `roadmap-integration.sh` cannot be sourced
   today (Finding 11), the plan phase should pick explicitly between: (a) shelling out to
   `roadmap-integration.sh --print` or an added `--help`-adjacent introspection flag and parsing
   its stderr marker/exit behavior to infer layout indirectly, or (b) a short, independently
   written layout-sniff (the same two structural predicates the format doc already specifies:
   all eight literal headers present, vs. any `## ` section with a fenced `/orchestrate` block) —
   this is NOT a fork of the overlap predicate (which stays spliced from `file-scope-overlap.sh`
   unconditionally) but a second, much smaller piece of parsing logic the format doc already
   fully specifies as plain prose/regex, not executable code owned by another task's file_scope.
   Do not guess a single layout and silently no-op on the other, mirroring
   `roadmap-integration.sh`'s own refusal-over-guessing stance for `unknown`.
4. **Finding (f) scope note**: finding (f) ("unresolvable cited path") is a whole-file citation
   check, broader than the batch-block-specific findings (a)/(c)/(d)/(e). Keep it in the same
   script (the declared `file_scope` names only one new script, and the HARD CONSTRAINT section's
   net-size caution argues against a second file) but document in the script's header comment
   that this one check's scan scope is the whole `ROADMAP.md`, not just `## Next`, so a future
   reader is not confused by the name "lint-roadmap-batch-proposals.sh" covering a broader check.
5. **Shell strict-mode**: default to Class A (`set -euo pipefail`) per
   `context/standards/shell-strict-mode.md` — this is a single-pass reporting script, not a
   counter-idiom harness needing to continue past command failures to produce an accurate
   summary. Guard any command that legitimately returns non-zero on a "no match" condition
   (e.g. `grep` over cited paths) with explicit `|| true`/`if` rather than relying on falling
   through past `-e`.

## Decisions

- **Seam decision (settled this research pass)**: LIVE SEAM 1 — `context/contracts/
  conclusion-stage.md`, hooked after Step 5 / alongside Step 7. LIVE SEAM 2 (`/orient`) is
  rejected for now on the grounds stated in Finding 5 (does not exist, not a dependency, would
  indefinitely defer this task for no corresponding benefit over the live option). This is a
  revision of the already-twice-revised seam question in the task description, not a re-opening
  of the earlier-settled scope ruling or finding (b)'s rejection, both of which stand unchanged.
- **Script shape decision**: unchanged from the task description — a standalone
  `scripts/lint/lint-roadmap-batch-proposals.sh`, following the 22-script `scripts/lint/*.sh`
  convention, registered in `manifest.json`, with a `scripts/tests/test-*.sh` companion. Not
  wired into `verify-deploy.sh` (precedent exists — Finding 10).
- **`commands/review.md` decision**: confirmed dead and removed from the recommended `file_scope`
  (Finding 5; the /orient record removes this file outright). The CROSS-REPO TERRITORY CONSTRAINT
  the task description recorded against `commands/review.md` dissolves with it, exactly as the
  task description's own SEAM INVALIDATION section already anticipated.

## Risks & Mitigations

- **Risk (major, newly surfaced): task 603 is scheduled to retire the artifact shape this lint
  parses.** `specs/state.json` task 603 ("Make ROADMAP.md a generated artifact rendered from
  state.json", `not_started`) will move batch membership, priority, and per-batch rationale out
  of `## Next` prose entirely into `state.json` entries maintained by a new `/roadmap` command,
  skill, and agent (none of which exist yet). `specs/ROADMAP.md`'s own live `## Next` section
  schedules 603 — alongside 602, 507, 391, 402, 528, 532 — as the very next `/orchestrate` Run
  batch for this repository's own backlog ("the roadmap-as-generated-artifact objective; 4 waves,
  probe-verified at MAX_TASKS"). If 603 lands before task 313 is implemented, the hand-authored
  `## Next` prose grammar this lint is built against may no longer be the live authoring surface
  at all, and the lint's natural target would shift to whatever structured representation 603
  introduces. **Mitigation / recommendation**: proceed with implementation now against the
  current, still-live grammar (do not block 313 on 603, which has no `dependencies[]` edge and no
  file_scope overlap with 313 today) — but record this risk explicitly in the plan, and treat a
  near-term rescoping or rewrite of this lint as an accepted, foreseeable follow-up cost once 603
  ships, rather than a surprise. This is exactly the kind of choice the user-decision contract
  reserves for the user's judgment (an external-priority/risk-tolerance call the artifacts cannot
  settle by further reading) — see `.return-meta.json`'s `user_decision` field.
- **Risk (concrete, actionable now): `file_scope` collision with concurrent sibling task 402.**
  Task 402 (`conclusion_channels_become_evidence_only`, `status: researching`, dispatched THIS
  SAME cycle per the dispatch's own Territory block) declares
  `agent-system/extensions/core/context/contracts/conclusion-stage.md` in its own `file_scope`.
  Recommending that file for task 313's `file_scope` (Recommendation 2) creates an exact-file
  overlap with task 402 under the Overlap Rule (`scopes_overlap_first`'s clause 1). Per
  `context/patterns/batch-orchestration-guardrails.md`'s Rule 1 ("shared file territory... is
  unconditional and does not depend on topic cohesion"), this is a **mandatory** territory link,
  not an optional one — the two tasks touch different Steps of the same file (402 touches Step
  4c; this task's hook targets Step 5/7), but Rule 1 is unconditional on which lines within the
  file are touched. **Mitigation**: at plan time (once 313's `file_scope` is finalized to include
  `conclusion-stage.md`), add a serializing `dependencies[]` edge between 313 and 402 via
  `update-task-status.sh --depends-on-add` (the guardrails doc's stated default move on an
  unordered territory overlap — "add an edge and run them as a sequence," never leave it as a bare
  exclusion). This is a plan-time action, not something this research dispatch performs, since
  research does not mutate `state.json`'s task graph.
- **Risk (minor, already mitigated): `roadmap-integration.sh` cannot be sourced for layout
  detection.** See Recommendation 3 — resolved by re-implementing the small, already-fully-
  specified layout-sniff logic rather than the overlap predicate (which remains spliced, never
  forked, exactly as directed).
- **Risk (self-resolving): the task description's own measured figures (ten lint scripts, a
  literal `**Run**:` marker, a 65-line pre-batch-block `roadmap-format.md`) have drifted further**
  since the 2026-11-02 re-measurement already recorded in the description. All corrected in
  Findings 1 and 10 above; no action needed beyond not carrying the stale figures into
  implementation prose.

## Context Extension Recommendations

- **Topic**: `context/patterns/roadmap-update.md`'s "Live Callers" section already anticipates
  this lint in prose ("A separate, advisory lint over hand-authored `## Next` batch proposals is
  already planned as dependent work elsewhere") but names no script. **Gap**: once this lint
  lands, that sentence becomes a dangling forward-reference with no path. **Recommendation**:
  at implementation time, replace that sentence with a named pointer to
  `scripts/lint/lint-roadmap-batch-proposals.sh` and its conclusion-stage.md call site — a small
  documentation-accuracy fix bundled with the task's own implementation, not a separate task.

## Appendix

- Search queries / commands used: `jq` queries against `specs/state.json` and
  `specs/archive/state.json` for tasks 306/328/344/387/401/436/402/391/400/602/603; `grep -rln
  roadmap-integration.sh` across the source store; `grep -n "^## "` against `specs/ROADMAP.md`;
  direct reads of `context/formats/roadmap-format.md` (full, 261 lines), `context/patterns/
  roadmap-update.md` (full), `context/contracts/conclusion-stage.md` (Step listing + Step 5/7
  region), `context/patterns/file-footprint-overlap.md` (full), `scripts/lib/file-scope-
  overlap.sh` (full), `docs/architecture/batch-admit-schema.md` (idle_overlap_advisory /
  absent-scope sections), `context/patterns/batch-orchestration-guardrails.md` (scope note, Rule
  1, Gate Catalogue, Blocking vs. Advisory table, truncation precedence), `commands/
  orchestrate.md` (MAX_TASKS), `docs/architecture/orchestrate-state-machine.md` (Batch Size Cap).
- References: `agent-system/extensions/core/context/formats/roadmap-format.md`,
  `agent-system/extensions/core/context/patterns/roadmap-update.md`,
  `agent-system/extensions/core/context/contracts/conclusion-stage.md`,
  `agent-system/extensions/core/context/patterns/file-footprint-overlap.md`,
  `agent-system/extensions/core/scripts/lib/file-scope-overlap.sh`,
  `agent-system/extensions/core/docs/architecture/batch-admit-schema.md`,
  `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`,
  `specs/ROADMAP.md`, `specs/state.json`.
