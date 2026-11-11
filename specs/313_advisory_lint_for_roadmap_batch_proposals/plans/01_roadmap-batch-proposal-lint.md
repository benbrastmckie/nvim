# Implementation Plan: Task #313

- **Task**: 313 - Advisory lint for hand-authored /orchestrate batch proposals in ROADMAP.md
- **Status**: [IMPLEMENTING]
- **Effort**: 8.25 hours
- **Dependencies**: 306 (completed), 328 (completed), 344 (completed), 387 (completed), 401 (completed), 402 (completed)
- **Research Inputs**: specs/313_advisory_lint_for_roadmap_batch_proposals/reports/01_roadmap-batch-lint-seam-selection.md
- **Artifacts**: plans/01_roadmap-batch-proposal-lint.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Build `scripts/lint/lint-roadmap-batch-proposals.sh` in the core extension's source store: a
purely ADVISORY lint over the hand-authored `/orchestrate` batch proposals in a repository's
`specs/ROADMAP.md`, reporting four finding classes — (a) territory under-inclusion, (c) batch
over the `MAX_TASKS=8` cap, (d) a cited task that is terminal or nonexistent, (f) an unresolvable
cited repository path — plus one declarative statement, finding (e), added to the format contract.
The lint never blocks: its exit code is unaffected by findings. It never proposes or ranks a batch;
it validates only what a human already typed. It is wired into the `/orchestrate` conclusion
stage, the single live, command-reachable, roadmap-touching seam, and registered in
`manifest.json` with a `scripts/tests/test-*.sh` companion like every sibling lint.

Done when: the real observed failure reproduces as a fixture that finding (a) flags; a
dependent-with-no-territory-overlap fixture produces NO finding (demonstrating rejected finding
(b) is genuinely absent); (c), (d) and (f) each have fixtures including (f)'s false-positive pair;
no copy of the overlap predicate exists in the new code; the Consumers list in
`file-footprint-overlap.md` names this lint; and the complete gate set is green against the
deployed tree.

### Research Integration

The research report settled the open seam question and is carried in whole. Its load-bearing
conclusions, used directly below:

- **Seam**: LIVE SEAM 1 — `context/contracts/conclusion-stage.md`, hooked after Step 5
  (`roadmap-integration.sh --regenerate`) and before Step 7. Both original seam candidates are
  dead (`commands/review.md` is slated for removal; the `/review` rewiring that Seam A assumed was
  abandoned), and LIVE SEAM 2 (`/orient`) does not exist. Confirmed live this dispatch: the
  `/orient` record (436) itself *depends on* 313, so choosing Seam 2 would be circular.
- **No `/roadmap` command exists today**, so hand-editing the markdown is literally the only
  authoring path; a check that runs once per `/orchestrate` invocation is the closest
  practically-achievable approximation to authoring time that the live system admits.
- **`roadmap-integration.sh` is a monolithic executable, never sourced**, so its `detect_layout()`
  cannot be spliced. The layout sniff is re-implemented from the two structural predicates
  `roadmap-format.md` already specifies as prose — a different, much smaller piece of logic than
  the overlap predicate, which stays spliced unconditionally.
- **An absent `file_scope` is "no evidence of overlap"** — a settled, landed ruling
  (`batch-admit-schema.md`'s v6 `absent_scope_advisory`), not an open question. Finding (a) cannot
  fire on it, and the script header records the assumed posture.
- **An unwired lint script has live precedent**: of 22 `scripts/lint/*.sh`, three are registered
  and tested but deliberately outside the `verify-deploy.sh` battery. This lint joins them; its
  test suite still reaches Gate 8 via `run-all.sh`'s auto-discovery.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_flag` was set on this dispatch, so no roadmap review/update phases are added.
`specs/ROADMAP.md` is nevertheless this lint's subject: its live `## Next` section is the corpus
Phase 3 verifies against, and the `roadmap-as-generated-artifact` objective (record 603) is the
named follow-up risk below.

### Carried-Figure Discipline

Every trigger-class line the dispatch extracted was re-checked against live state this dispatch.
Results, stated explicitly even where they confirm the description:

| Carried claim | Verdict | Live measurement |
|---|---|---|
| `roadmap-format.md` is "65 lines with zero occurrences of Run" | **STALE** (already flagged in the description's own re-measurement) | 261 lines; `## Next Grammar` specifies the Run-line regex `^/orchestrate ([\d, ]+)(\s+(-\S.*?))?(\s{3}# (.+))?$`, stated twice, plus a two-layout (`classic`/`stage`/`unknown`) detection contract |
| The consumer repo "uses a literal `**Run**:` marker" | **STALE** | Zero `**Run**` occurrences in the live `specs/ROADMAP.md`; the markers are the `## Next` header and the fenced block |
| "the ten existing `scripts/lint/*.sh`" | **STALE** | 22 scripts live; 15 carry `set -euo pipefail`, 7 carry `set -uo pipefail` |
| `MAX_TASKS=8` at `commands/orchestrate.md:232` | **VALUE CORRECT, CITATION DRIFTED** | `MAX_TASKS=8` is live at `commands/orchestrate.md:255`, under the "MAX_TASKS Guard" heading citing `orchestrate-state-machine.md`'s `### Batch Size Cap`. Cite by heading, never by line number |
| Task 402 is a concurrent sibling with a mandatory `conclusion-stage.md` territory collision (research Risk 2) | **RESOLVED** | 402 is `completed`; the `dependencies[]` edge 313 -> 402 is already present. This cycle's only concurrent sibling is 412, whose `file_scope` is entirely Lean-extension files with zero overlap |
| Research Recommendation 2's `file_scope` swap is still pending | **HALF-APPLIED** | `conclusion-stage.md` is already present in 313's `file_scope`; `commands/review.md` is still present and must be removed (Phase 1) |
| 603 will retire the `## Next` prose grammar | **CONFIRMED STILL PENDING** | 603 is `not_started`; the live `## Next` grammar this lint parses is unchanged. The user's recorded decision to proceed now therefore still discharges its stated obligation — no new blocking decision is raised |
| All findings are ADVISORY; a prose markdown file is never dispatched | **CONFIRMED** | Unchanged; corroborated by `batch-admit-schema.md`'s `idle_overlap_advisory` being advisory on exactly this reasoning |
| "`generate-task-order.sh`'s `compute_waves` must be reused for any wave reasoning" | **CONDITION NOT MET** | With finding (b) rejected and finding (e) declarative, no finding requires wave reasoning. The directive is discharged vacuously: nothing is consumed from, and nothing is modified in, `generate-task-order.sh`. See Decision D5 |

## Goals & Non-Goals

**Goals**:
- A standalone, advisory `scripts/lint/lint-roadmap-batch-proposals.sh` reporting findings (a),
  (c), (d) and (f) over a repository's own `specs/ROADMAP.md` and `specs/state.json`.
- Finding (e)'s one declarative sentence plus pointer added to `roadmap-format.md`'s Next Grammar.
- A `scripts/tests/test-lint-roadmap-batch-proposals.sh` companion whose fixtures include the real
  observed failure and the two negative cases the acceptance criteria name.
- Registration in `manifest.json`; `file-footprint-overlap.md`'s Consumers list names this lint;
  `roadmap-update.md`'s forward-reference to "a separate, advisory lint" names the real script.
- The lint invoked from the `/orchestrate` conclusion stage after Step 5.

**Non-Goals**:
- **Proposing, authoring, suggesting or ranking a batch.** This is a validator. Batch *selection*
  belongs to `orchestrate-suggest-next-batch.sh` (Step 7) and the topic-orchestrator work; a
  second copy of an admission predicate drifts from the real one.
- **Finding (b)** — a non-terminal dependent of an in-batch prerequisite that is absent from the
  batch. Rejected in the task record, including its weaker informational variant. Not re-proposed.
- Any edit to `generate-task-order.sh`, `roadmap-integration.sh`, or `scripts/lib/file-scope-overlap.sh`.
- Wiring into `verify-deploy.sh` as a numbered gate (its subject is a consumer repo's
  `specs/ROADMAP.md`, the wrong fit for that battery; precedent exists for staying unwired).
- Future-proofing the lint against record 603's eventual landing. Accepted as a named follow-up
  cost by the user's recorded decision.
- Editing `orchestrate-batch-results-template.md`. See Decision D4.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Record 603 retires the `## Next` prose grammar this lint parses | H | M | Accepted by the user's recorded decision (proceed now, rescope later). Phase 5 adds an explicit note to the script header naming 603's objective as the foreseeable rescoping trigger, so the next reader is not surprised |
| Finding (a) is noisy on a dense graph (150 open records, shared `manifest.json`-class territory) and trains operators to ignore advisories | H | H | Dedupe per (Run line, absent task, overlapping path); render grouped by Run line; emit at most one line per absent task per batch with the first overlapping path, full detail only under `--verbose`. Rule 1 is unconditional, so no edge-based suppression is added — but absent-`file_scope` tasks and terminal tasks never fire, which removes the bulk of the population |
| Linting machine-generated lines instead of authored ones | H | H | The coverage appendix under `**Coverage appendix (uncovered tasks)**:` is GENERATED by `roadmap-integration.sh`. Parsing stops at that header; only authored Run lines above it are linted. Verified live: 20 `/orchestrate` lines in the file, 11 authored, 9 generated |
| Finding (f) false positives drown the signal | M | H | Two guards, both from the task record's measured experience: a citation must carry path structure (at least one `/`), never a bare backticked basename; and a path qualified for another repository (`~/...`, absolute, or any other-root prefix) is skipped explicitly and counted, never resolved against the wrong root |
| The layout sniff diverges from `roadmap-integration.sh`'s `detect_layout()` | M | M | Both predicates are specified as prose in `roadmap-format.md` and transcribed from it, not from the script. An `unknown` layout produces a loud named note and parses nothing — never a silent no-op, mirroring the generator's own refusal-over-guessing stance |
| Editing `roadmap-format.md` (record 603's territory) or `conclusion-stage.md` (558/562/602's) collides with another task | M | M | Phase 1 adds the serializing `dependencies[]` edges before any such edit, the guardrails doc's stated default move on an unordered overlap. All affected records are `not_started`, so 313 running first is the correct direction |
| An advisory lint that exits 0 on findings diverges from the sibling lints' exit-1 convention and is mistaken for broken | L | M | Stated in the script header as a deliberate divergence with its reason, and pinned by a test case asserting exit 0 with findings present |

## Decisions

- **D1 — The overlap predicate is spliced once, as a single `jq -n` program.** The script sources
  `scripts/lib/file-scope-overlap.sh` and splices `$FILE_SCOPE_OVERLAP_JQ_DEFS` into ONE `jq -n`
  program covering the whole cross-product, the shape `orchestrate-batch-admit.sh` uses — not
  per-pair `scopes_overlap()` shell-outs, which would mean thousands of `jq` invocations on a
  150-record state file. `norm`, `scopes_overlap_first` and `whole_tree_claim_sentinel` are used
  exactly as defined. Nothing about the algorithm is restated, re-derived or "improved" locally;
  `scopes_overlap_first` stays glob-free and symmetric.
- **D2 — Task lookup goes through `scripts/lib/task-lookup-lib.sh`.** Finding (d) must distinguish
  "terminal" from "nonexistent", and `/todo` moves terminal records into `archive/state.json`. The
  archive-aware `task_lookup_entry` is the single source of truth, and `lint-task-lookup-adoption.sh`
  fails loudly on a hand-rolled `.active_projects[] | select(.project_number ==` lookup.
- **D3 — Class A strict mode (`set -euo pipefail`).** The documented default for a new script;
  every command whose non-zero exit is legitimate (a `grep` with no match, a path-resolution test)
  is explicitly guarded with `if`/`||`. The Class B counter-idiom admission is deliberately not
  claimed: findings are accumulated into an array and rendered at the end, so there is no
  first-failure truncation hazard.
- **D4 — Findings surface with Step 5's own output, not as a new Step 6 report section.** Research
  Recommendation 1 suggested folding into Step 6's report; Step 6 renders per
  `orchestrate-batch-results-template.md`, so a new report section would require editing that
  template — a wider footprint for no behavioral gain. Instead the lint runs at Step 5 and its
  advisory lines are surfaced verbatim there, with one line in Step 6 recording that they appear
  with Step 5's output. The contract text states explicitly that these findings are NOT a fourth
  channel: they derive from `specs/ROADMAP.md`, carry no `AskUserQuestion` gate, and the
  Exactly-One-Channel and Hint-Versus-Decision rules do not apply to them — the identical posture
  Step 7 already carries. Integrating into the report template is recorded as an optional
  follow-up, not done here.
- **D5 — No wave reasoning, so nothing is consumed from `generate-task-order.sh`.** The reuse
  directive is conditional ("for any wave reasoning"). Finding (b) is rejected and finding (e) is
  declarative, so no finding reasons about waves. Consuming `compute_waves` anyway would add a
  dependency on another task's territory for no check. Recorded here so a reader does not read the
  absence as an oversight.
- **D6 — `specs/state.json` is NOT declared in `file_scope`.** Phases 1's state mutations go
  through the sanctioned writers (`update-task-status.sh`, `state-write.sh`) and are ordinary
  state-management operations, exactly like every task's own status transitions — which no task
  declares. Declaring `specs/state.json` would manufacture a territory overlap with every record
  that touches state, for no protection the mutex-guarded writer does not already provide.

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4, 5 | 3 |
| 5 | 6 | 4, 5 |

Phases within the same wave can execute in parallel.

### Phase 1: Territory hygiene and premise re-confirmation [COMPLETED]

**Goal**: The task's declared territory matches what this plan will actually touch, and every
serializing `dependencies[]` edge the plan's later edits require exists before those edits land.

**Tasks**:
- [x] Re-confirm the live premises this plan rests on, and state each result explicitly (even when
      it only confirms): `specs/ROADMAP.md` classifies `classic` (all eight `CLASSIC_HEADERS`
      present); its `## Next` fenced block holds authored `/orchestrate` Run lines above a
      `**Coverage appendix (uncovered tasks)**:` header; record 603 is still `not_started`;
      record 402 is `completed`. *(completed: all four premises confirmed live — classic layout,
      11 authored Run lines above the coverage appendix at line 297, 603 not_started, 402 completed)*
- [x] Remove the stale `agent-system/extensions/core/commands/review.md` entry from this task's
      `file_scope`. `--file-scope-add` is additive-only and can never remove an entry, so use the
      sanctioned mutex-guarded writer directly:
      `bash .claude/scripts/state-write.sh '(.active_projects[] | select(.project_number == 313) | .file_scope) |= map(select(. != "agent-system/extensions/core/commands/review.md"))' --session-id "$session_id"`.
      The file is being removed outright by record 436, which already depends on 313.
      *(completed)*
- [x] Add the serializing edge onto record 603, which owns `context/formats/roadmap-format.md`
      (Phase 5 edits it): `bash .claude/scripts/update-task-status.sh preflight 603 edge_only "$session_id" --depends-on-add='[313]'`.
      Direction per that flag's documented rule: the positional number is the task that GAINS the
      dependency, so 603 gains a dependency on 313 and runs after it. *(completed)*
- [x] Re-derive the live set of non-terminal records declaring
      `agent-system/extensions/core/context/contracts/conclusion-stage.md` in their own
      `file_scope`, and add the same `preflight ... edge_only --depends-on-add='[313]'` edge to
      each one still non-terminal and still declaring it. Measured at planning time: 558, 562, 602,
      all `not_started` (402 also declares it but is `completed`, and the 313 -> 402 edge already
      exists). Re-derive rather than trusting this list — the graph moves.
      *(completed: re-derived set exactly matched the planning-time hypothesis — 558, 562, 602,
      all still not_started)*
- [x] After adding the edges, confirm the graph still drains:
      `bash .claude/scripts/orchestrate-cycle-plan.sh --dry-run --state-file specs/state.json 313`.
      Each `--depends-on-add` call runs its own mandatory write-time cycle refusal, so a cycle is
      refused at the write rather than discovered here; this check confirms the intended batch
      still plans. *(completed: 0 blocked, 0 cycles, stop=none; one benign self-contention
      deferral against this session's own sibling task 397 on `__WHOLE_TREE__`, expected for
      concurrent whole-tree-claimant siblings and not a cycle)*

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: Exactly three non-terminal records (558, 562, 602) other than 313 declare
`conclusion-stage.md`, and exactly one (603) declares `roadmap-format.md` — measured against
`specs/state.json` on 2026-11-11. Confirm by re-running the per-file `file_scope` query at
implementation time before adding any edge; if the set has moved, act on the live set, not on
these numbers.

**Tier Justification**: The edit surface is `specs/state.json` alone, and the covering check is
`bash .claude/scripts/validate-state.sh --deep specs/state.json`, which each `--depends-on-add`
call additionally runs against a scratch copy before writing.

**Files to modify**:
- none planned - this phase performs state-management operations only, through the sanctioned
  mutex-guarded writers (`state-write.sh`, `update-task-status.sh`); per Decision D6
  `specs/state.json` is deliberately not declared as territory

**Verification**:
- `jq '[.active_projects[] | select(.project_number == 313) | .file_scope[]]' specs/state.json`
  no longer contains `agent-system/extensions/core/commands/review.md`, and still contains
  `context/contracts/conclusion-stage.md`, `context/patterns/file-footprint-overlap.md`,
  `manifest.json`, and the two new script paths.
- `jq '[.active_projects[] | select(.project_number == 603) | .dependencies[]]' specs/state.json`
  contains `313`; same for each conclusion-stage claimant re-derived above.
- `bash .claude/scripts/validate-state.sh --deep specs/state.json` reports no new finding
  attributable to this phase.

---

### Phase 2: Lint skeleton, layout detection, Run-line parse, and findings (c), (d), (f) [COMPLETED]

**Goal**: `scripts/lint/lint-roadmap-batch-proposals.sh` exists, parses only the authored Run
lines of either supported layout, and reports findings (c), (d) and (f) — advisory, exit code
unaffected.

**Tasks**:
- [x] Create `agent-system/extensions/core/scripts/lint/lint-roadmap-batch-proposals.sh` with a
      header that states, in this order: the advisory contract ("the exit code is never affected
      by findings; 0 means the scan completed, not that nothing was found") and why (a prose
      markdown file is never dispatched, so an under-inclusive batch causes no silent concurrent
      write; the real admission gate still fires at dispatch time); the deliberate divergence from
      the sibling lints' exit-1-on-violation convention; the validator-never-proposer constraint;
      the ABSENT-`file_scope` POSTURE assumed (absent scope means "no evidence of overlap", so
      finding (a) cannot fire on it — recorded so the ruling can be reconciled later); and the
      note that finding (f)'s scan scope is the WHOLE file, not just the batch block, despite the
      script's batch-oriented name. *(completed)*
- [x] Shell contract per Decision D3: `set -euo pipefail`, every legitimately-non-zero command
      explicitly guarded. CLI: `[--verbose] [--roadmap PATH] [--state PATH]`, defaulting to
      `specs/ROADMAP.md` and `specs/state.json` under the resolved repo root. Exit codes: `0`
      whenever the scan completes (findings or not); `2` for a usage or environment error only
      (missing `jq`, unreadable roadmap). There is no exit `1`. *(completed: also discovered and
      guarded a `set -e` hazard in sourcing `file-scope-overlap.sh` — its own `read -r -d ''`
      heredoc assignment always returns exit 1 at EOF; guarded with the same `if ! . file; then`
      idiom `task-lock.sh`/`orchestrate-batch-admit.sh` already use around this same library)*
- [x] Implement the layout sniff, transcribed from `context/formats/roadmap-format.md`'s own prose
      predicates, not from `roadmap-integration.sh` (which is a monolithic executable and cannot be
      sourced): `classic` iff all eight literal `CLASSIC_HEADERS` are present; `stage` iff a
      `^## Stage [0-9]+` header is present AND some `## ` section's body holds a fenced block
      containing at least one `^/orchestrate ` line; otherwise `unknown`. On `unknown`, emit one
      loud named line (`NOTE: layout=unknown; no batch block parsed`) and exit 0 — never a silent
      no-op, and never a guess at one of the two layouts. *(completed: verified against the live
      classic corpus and a hand-built stage fixture)*
- [x] Extract the authored batch block: the `## Next` section on `classic`, the first section
      matching the fenced-`/orchestrate` predicate on `stage`. Parse Run lines with the format
      contract's own regex `^/orchestrate ([\d, ]+)(\s+(-\S.*?))?(\s{3}# (.+))?$`. **Stop at the
      `**Coverage appendix (uncovered tasks)**:` header**: everything below it is generated by
      `roadmap-integration.sh`, and linting machine output would be pure noise. *(completed: live
      run confirms exactly 11 authored lines parsed, the 9 generated coverage-appendix lines
      excluded)*
- [x] Finding (c): report a Run line whose id count exceeds `MAX_TASKS=8` (`commands/orchestrate.md`'s
      "MAX_TASKS Guard"; contract at `orchestrate-state-machine.md`'s "Batch Size Cap"). The
      message states the count and the cap, and states that any trim must preserve
      territory-mandatory groups per the guardrails document's truncation precedence rule. It MUST
      NOT emit a trimmed list — that would be proposing a batch. *(completed)*
- [x] Finding (d): for each cited id, resolve via `task-lookup-lib.sh`'s `task_lookup_entry`
      (Decision D2), and report when the id resolves to nothing at all, or resolves to a terminal
      status (`completed`/`abandoned`/`expanded`, including the archive-normalized forms that
      helper already maps). Distinguish the two cases in the message text. *(completed: live run
      against `specs/ROADMAP.md` correctly flagged Run 1's six now-completed tasks — a real,
      current transient-staleness signal, not a test artifact)*
- [x] Finding (f): scan the whole file for cited repository paths, outside fenced code blocks,
      taking inline backtick-delimited code spans as the citation candidates. Apply both guards
      from the task record's measured experience: (1) a candidate must carry path structure (at
      least one `/`) to count as a citation — a bare backticked basename (`ci.yml`,
      `MintBound.lean`) is prose shorthand and is never reported; (2) a candidate qualified for
      another repository (leading `~/`, leading `/`, or any other explicit root prefix) is SKIPPED
      explicitly and counted, never resolved against the local root. Skip candidates containing a
      placeholder or glob token (`{`, `}`, `*`, `<`). Report a surviving candidate that does not
      resolve on disk relative to the repo root. Under `--verbose`, print the skipped-cross-repo
      and skipped-shorthand counts so the guards are observable rather than invisible. *(completed:
      a first live pass against the real corpus produced 40 findings, mostly false — paths
      authored relative to `.claude/` or to a source-store extension directory with the
      "agent-system/extensions/" prefix dropped. Added multi-root resolution [PROJECT_ROOT,
      PROJECT_ROOT/.claude, PROJECT_ROOT/agent-system/extensions], a whitespace-is-not-a-path
      guard, and a literal-"..."-elision guard, reducing to 14 — 2 a genuine already-known-defect
      true positive, the rest a documented residual class [deeper prefix-dropping, placeholder
      words, transient runtime paths] recorded in the script header rather than chased further,
      to avoid over-fitting the two named guards to one corpus document)*
- [x] Render findings grouped by Run line, one line per finding, each naming the finding letter;
      print a trailing summary count. Every finding line goes to stdout; diagnostics go to stderr.
      *(completed)*

**Timing**: 2 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: `suite_selection_select` returns the sentinel `__FULL_SWEEP__` for this
not-yet-suite-mapped new script, so no suite covers it yet; the covering checks are `bash -n` on
the new file plus `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh agent-system/extensions/core/scripts/lint/lint-roadmap-batch-proposals.sh`.

**Files to modify**:
- `agent-system/extensions/core/scripts/lint/lint-roadmap-batch-proposals.sh` - new file: header,
  CLI, layout sniff, authored-Run-line parse, findings (c), (d), (f)

**Verification**:
- `bash -n` on the new script is clean, and
  `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh agent-system/extensions/core/scripts/lint/lint-roadmap-batch-proposals.sh`
  reports no finding.
- Run against the live `specs/ROADMAP.md`: the script reports `layout=classic`, parses exactly the
  11 authored Run lines above the coverage appendix (not the 9 generated ones below it), and exits
  0 regardless of how many findings it printed.
- An `unknown`-layout fixture produces the named note and exit 0, not a silent clean report.

---

### Phase 3: Finding (a) — territory under-inclusion [NOT STARTED]

**Goal**: The primary finding works: a non-terminal task whose declared `file_scope` overlaps an
in-batch task but which is absent from that batch is reported, using the one shared overlap
predicate and no local copy of it.

**Tasks**:
- [ ] Source `scripts/lib/file-scope-overlap.sh` and splice `$FILE_SCOPE_OVERLAP_JQ_DEFS` into a
      single `jq -n` program covering the whole cross-product (Decision D1) — the
      `orchestrate-batch-admit.sh` shape, never per-pair `scopes_overlap()` shell-outs. Use `norm`
      and `scopes_overlap_first` exactly as defined; do not restate, fork, or locally "improve"
      the predicate, which is deliberately glob-free and symmetric.
- [ ] For each authored Run line: collect the in-batch tasks' declared `file_scope` entries, then
      compare every OTHER non-terminal record's `file_scope` against them. Report each absent task
      that overlaps, naming the absent task, the in-batch task it overlaps, and the overlapping
      path — the same three facts `idle_overlap_advisory` already emits at dispatch time, which is
      what makes this the authoring-time analogue of a shipped mechanism rather than a new claim.
- [ ] Suppress by construction, each for its own stated reason: a terminal record (nothing to
      batch); a record with an absent or empty `file_scope` (no evidence of overlap — the settled
      posture recorded in the header); the task's own in-batch members. Do NOT suppress on the
      presence of a `dependencies[]` edge: rule 1's territory requirement is unconditional, and an
      edge-based suppression would re-admit exactly the reasoning the observed failure used.
- [ ] Dedupe per (Run line, absent task) and print one line per pair with the first overlapping
      path; full per-path detail only under `--verbose`. Note in a comment that the reserved
      `__WHOLE_TREE__` sentinel is inert against real paths and matches only another declarant of
      the same sentinel — that hit is the intended same-claim detection signal, not a false
      positive.
- [ ] Add a one-paragraph comment recording the real observed failure this finding exists for: a
      task was REMOVED from a hand-authored batch because it depended on another task already in
      that batch; the two also shared file territory, which makes batching them mandatory. The
      reasoning was wrong on both counts, and nothing caught it.

**Timing**: 1.25 hours

**Depends on**: 2

**Verification Tier**: local

**Scope Hypothesis**: Finding (a) run against the live `specs/ROADMAP.md` will fire on a non-zero
but operator-readable number of its 11 authored batches — shared `manifest.json`-class territory
is common in this backlog. Confirm by running it and reading the output; if the volume is such
that the signal is unreadable, tighten the rendering (grouping, `--verbose` gating) rather than
weakening the predicate, and record the measured count in the phase notes.

**Tier Justification**: `suite_selection_select` returns `__FULL_SWEEP__` for this script (no
suite maps to it until Phase 4's companion suite exists), so the covering checks are the
shellcheck lint on the file plus a by-hand run against the live `specs/ROADMAP.md` corpus and the
Phase 3 fixtures.

**Files to modify**:
- `agent-system/extensions/core/scripts/lint/lint-roadmap-batch-proposals.sh` - add finding (a):
  the spliced overlap cross-product, the three suppressions, the dedupe and render

**Verification**:
- `grep -c 'startswith' agent-system/extensions/core/scripts/lint/lint-roadmap-batch-proposals.sh`
  finds no hand-written directory-prefix comparison: the only overlap logic present arrives via
  the spliced `$FILE_SCOPE_OVERLAP_JQ_DEFS`.
- A hand-built fixture reproducing the real observed failure (two tasks sharing three files under
  one component's `certificate/` directory, one of them omitted from the batch) produces exactly
  one finding (a), naming both tasks and one shared path.
- A fixture whose only omitted task is a DEPENDENT of an in-batch task, with no territory overlap,
  produces NO finding — demonstrating rejected finding (b) is genuinely absent.
- The script still exits 0 with findings present.
- `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh` on the file is clean.

---

### Phase 4: Test suite, fixtures, and manifest registration [NOT STARTED]

**Goal**: Every finding has a fixture, both required negative cases are pinned, and the script and
its suite are registered in `manifest.json` like every sibling lint.

**Tasks**:
- [ ] Create `agent-system/extensions/core/scripts/tests/test-lint-roadmap-batch-proposals.sh`
      following the live convention (`test-lint-json-channel-discipline.sh` is the nearest model):
      `source "$SCRIPT_DIR/../lib/common.sh"`, `common_test_repo_root`,
      `common_test_resolve_subject` with `deploy-tree-first`, `common_test_declare_subject`,
      `common_test_workdir_init`, `common_test_pass`/`fail`/`info`, and PASSED/FAILED counters with
      an end-of-run summary. Do not define local `pass()`/`fail()`/`info()` alongside the shared
      harness — `lint-test-harness-adoption.sh` fails on that shape.
- [ ] Fixture: the real observed failure — a ROADMAP batch omitting a task whose `file_scope`
      overlaps an in-batch task — asserts exactly one finding (a).
- [ ] Fixture: an omitted DEPENDENT with no territory overlap — asserts zero findings.
- [ ] Fixture: a Run line with nine ids — asserts one finding (c), and asserts the message contains
      no trimmed-batch suggestion.
- [ ] Fixtures: a Run line citing a terminal task, and one citing a nonexistent id — assert one
      finding (d) each, with distinguishable messages.
- [ ] Fixture pair for finding (f): one file with a genuinely unresolvable `specs/{NNN}_{slug}/...`
      citation (the archival-move defect class) asserts one finding; one file containing BOTH
      false-positive classes — a backticked bare basename, and a path qualified for another
      repository — asserts zero findings.
- [ ] Fixture: an `unknown`-layout file — asserts the named note on stderr and exit 0.
- [ ] Fixture: a `stage`-layout file whose run-order section holds Run lines — asserts the lines
      are parsed, so the lint does not silently no-op on the non-`classic` shape.
- [ ] Assertion: with findings present, the exit code is 0. This pins the advisory contract
      mechanically rather than only in prose.
- [ ] Assertion: run the lint with no explicit paths against the real repo corpus and assert it
      completes and exits 0 (the real-corpus case every sibling lint suite carries).
- [ ] Register both files in `agent-system/extensions/core/manifest.json`, in sorted position:
      `"lint/lint-roadmap-batch-proposals.sh"` in `provides.scripts`, and
      `"tests/test-lint-roadmap-batch-proposals.sh"` in the tests array.

**Timing**: 2 hours

**Depends on**: 3

**Scope Hypothesis**: Nine fixtures and two assertions, over two new files plus two
one-line `manifest.json` insertions. The fixture count follows from the acceptance criteria and
may grow during authoring; confirm by enumerating the acceptance criteria against the finished
suite before closing the phase, and do not drop a criterion to hold the count.

**Verification Tier**: local

**Tier Justification**: `suite_selection_select` over this phase's whole path set returns the
`__FULL_SWEEP__` sentinel — no suite covers it, because the fixture file this phase creates is
itself unmappable — so the covering check is that sentinel's gate subset,
`bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`,
run together with a direct by-path invocation of the fixture suite this phase creates.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-lint-roadmap-batch-proposals.sh` - new fixture suite
- `agent-system/extensions/core/manifest.json` - register the lint script and its test companion
- `agent-system/extensions/core/scripts/lint/lint-roadmap-batch-proposals.sh` - any correction the
  fixtures surface

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-lint-roadmap-batch-proposals.sh` passes
  every case, and its summary line reports zero FAILED.
- `bash agent-system/extensions/core/scripts/tests/test-manifest-scripts-sync.sh` and
  `bash agent-system/extensions/core/scripts/tests/test-script-inventory.sh` are green, confirming
  both manifest entries match what is on disk.
- `jq -e '.provides.scripts | index("lint/lint-roadmap-batch-proposals.sh")' agent-system/extensions/core/manifest.json`
  succeeds, and the same for the tests entry.

---

### Phase 5: Finding (e), the call-site wiring, and the Consumers/forward-reference edits [NOT STARTED]

**Goal**: The format contract states plainly that an intra-batch dependency edge never disqualifies
a task from a batch; the lint is invoked from the conclusion stage; and the two documents that
name this algorithm's callers and this lint's existence point at the real script.

**Tasks**:
- [ ] Finding (e) — in `context/formats/roadmap-format.md`'s `## Next Grammar` section, add one
      short paragraph: a Run line's `{task_list}` MAY name tasks carrying `dependencies[]` edges
      among themselves, because `/orchestrate` dispatches dependency-aware waves, so an intra-batch
      edge sequences the two tasks into successive waves rather than disqualifying either; whether
      a dependent joins its predecessor's batch is the author's judgment, and a dependency edge is
      never grounds for REMOVING a task from a batch. Cite — do not re-explain —
      `context/patterns/batch-orchestration-guardrails.md`'s Gate Catalogue, which already
      classifies an unmet predecessor as an ORDERING CONSTRAINT cleared automatically once the
      predecessor reaches a terminal state. This is a pointer plus one statement, never new
      doctrine, and it must not assert the rejected finding (b)'s mandate in prose form.
- [ ] Call site — in `context/contracts/conclusion-stage.md`'s Step 5, after the existing
      `roadmap-integration.sh --regenerate` invocation and its scoped commit, add the lint
      invocation (`bash .claude/scripts/lint/lint-roadmap-batch-proposals.sh`) with one sentence
      stating that its output is advisory, that its exit code is never acted on, and that it is
      explicitly NOT a fourth channel — it derives from `specs/ROADMAP.md`, carries no
      `AskUserQuestion` gate, and the Exactly-One-Channel and Hint-Versus-Decision rules do not
      apply to it, the same posture Step 7 already carries. Add one line to Step 6 recording that
      the advisory lines appear with Step 5's output rather than as a report section (Decision D4).
      Re-read the file immediately before editing: it has four other declared claimants.
- [ ] `context/patterns/file-footprint-overlap.md` — add this lint to the `## Consumers` list as a
      new, named caller, and update the list's own count sentence ("three active callers") to match
      the new total. State the consumption shape precisely: it splices
      `$FILE_SCOPE_OVERLAP_JQ_DEFS` into a single `jq -n` program, like the batch-admission-level
      caller, and its subject is a hand-authored batch proposal rather than a dispatch candidate.
- [ ] `context/patterns/roadmap-update.md` — its "Live Callers" section currently anticipates this
      lint in prose ("A separate, advisory lint over hand-authored `## Next` batch proposals is
      already planned as dependent work elsewhere") with no path. Replace that forward reference
      with a named pointer to the real script and its conclusion-stage call site. Confirm the
      sentence is still present and still unnamed before editing; if it has already been changed,
      make the pointer consistent with whatever is there rather than restoring the old wording.
- [ ] Add the 603 follow-up note to the lint script's header: record 603's roadmap-as-generated-artifact
      objective will move batch membership out of `## Next` prose into `state.json`, at which point
      this lint's parse layer needs rescoping. Name the objective by its durable description, never
      by task number (this file is outside `specs/**`).

**Timing**: 1.25 hours

**Depends on**: 3

**Verification Tier**: prose

**Tier Justification**: Every edit is source-store markdown with no compile surface, and
`suite_selection_select` over this phase's whole path set returns the `__FULL_SWEEP__` sentinel —
no suite covers it — so the covering check is that sentinel's sub-case (b) gate subset,
`bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`,
run together with the `prose` row's diff read-through.

**Files to modify**:
- `agent-system/extensions/core/context/formats/roadmap-format.md` - finding (e)'s declarative paragraph in `## Next Grammar`
- `agent-system/extensions/core/context/contracts/conclusion-stage.md` - the Step 5 lint invocation and the Step 6 note
- `agent-system/extensions/core/context/patterns/file-footprint-overlap.md` - this lint added to the Consumers list, with the count sentence corrected
- `agent-system/extensions/core/context/patterns/roadmap-update.md` - the Live Callers forward reference replaced with a named pointer
- `agent-system/extensions/core/scripts/lint/lint-roadmap-batch-proposals.sh` - the header follow-up note

**Verification**:
- `grep -n 'lint-roadmap-batch-proposals' agent-system/extensions/core/context/patterns/file-footprint-overlap.md agent-system/extensions/core/context/patterns/roadmap-update.md agent-system/extensions/core/context/contracts/conclusion-stage.md`
  returns a hit in each of the three files.
- `context/formats/roadmap-format.md`'s `## Next Grammar` section states that an intra-batch
  dependency edge sequences rather than disqualifies, and cites the guardrails Gate Catalogue
  without restating it.
- `bash .claude/scripts/check-task-references.sh` reports no task-number reference in any file
  touched by this phase (all are outside `specs/**`).
- Run `bash agent-system/extensions/core/scripts/tests/test-roadmap-generation.sh` and
  `bash agent-system/extensions/core/scripts/tests/test-orchestrate-conclusion-aggregate.sh`
  directly (named here because they exercise these two files' contracts, not because the suite
  selector returned them): both are green, so the format-contract paragraph and the Step 5
  addition break neither the generator's parse nor the conclusion aggregate's own contract tests.

---

### Phase 6: Deploy, run the complete gate set, and record the outcome [NOT STARTED]

**Goal**: The source-store change is deployed into the live `.claude/` tree, the complete gate set
is green, and the implementation summary records what landed.

**Tasks**:
- [ ] Re-read `git status --short` and confirm no foreign uncommitted modification has appeared in
      this task's own files. Concurrent siblings run on this shared tree; a foreign commit, a
      foreign uncommitted modification, or a running build this dispatch did not start is a STOP
      condition to report after checking `git log`, not noise to dismiss.
- [ ] Run `bash /home/benjamin/.config/nvim/.claude/scripts/deploy-headless.sh` and confirm the
      emitted marker is `RESULT=landed_verify_clean` (exit 0). `RESULT=not_landed` (exit 1/2),
      `RESULT=landed_verify_red` (exit 3), and `RESULT=landed_verify_skipped` (exit 4) are each a
      phase failure, not a partial success; on `landed_verify_red`, fix forward from the reported
      gate rather than discarding the deploy.
- [ ] Confirm the lint is callable from the deployed tree:
      `bash /home/benjamin/.config/nvim/.claude/scripts/lint/lint-roadmap-batch-proposals.sh`
      completes against the live `specs/ROADMAP.md` and exits 0.
- [ ] Confirm `test-lint-roadmap-batch-proposals.sh` is discovered and green from the deployed tree
      (`run-all.sh` auto-discovers `.claude/scripts/tests/test-*.sh`, which is how this unwired
      lint still reaches Gate 8).
- [ ] Confirm `next_project_number` in `specs/state.json` is unchanged by any part of this work.
- [ ] Write the implementation summary to
      `specs/313_advisory_lint_for_roadmap_batch_proposals/summaries/`, recording the gate outcome,
      the finding counts the lint reports against the live corpus, and the named 603 follow-up.
- [ ] Record any pre-existing gate failure as a reasoned exclusion with its evidence rather than
      claiming it as this task's own — and never weaken a gate to pass it.

**Timing**: 1 hour

**Depends on**: 4, 5

**Verification Tier**: full

**Files to modify**:
- `__WHOLE_TREE__` - `deploy-headless.sh` regenerates the entire deployed `.claude/` tree from the
  source store; this phase claims whole-tree regeneration and declares the reserved sentinel so a
  concurrently-admitted task that would also regenerate the tree is serialized against it
- `specs/313_advisory_lint_for_roadmap_batch_proposals/summaries/` - the implementation summary

**Verification**:
- `bash /home/benjamin/.config/nvim/.claude/scripts/deploy-headless.sh` emits
  `[deploy-headless] RESULT=landed_verify_clean` and exits 0.
- The complete gate set is green: `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh`
  (run by `deploy-headless.sh` itself as part of reaching `landed_verify_clean`; run standalone if
  the marker is anything else), including Gate 8's full `run-all.sh` battery with the new suite
  discovered.
- `bash /home/benjamin/.config/nvim/.claude/scripts/lint/lint-roadmap-batch-proposals.sh` runs from
  the deployed path and exits 0.

---

## Testing & Validation

- [ ] The real observed failure reproduces as a fixture and finding (a) flags it.
- [ ] A fixture whose only omitted task is a dependent with no territory overlap produces NO
      finding, demonstrating rejected finding (b) is genuinely absent.
- [ ] Findings (c) and (d) each have a fixture; (d) distinguishes terminal from nonexistent.
- [ ] Finding (f) has a fixture pair: one genuinely unresolvable path that fires, and one file
      carrying both false-positive classes (bare backticked basename; path qualified for another
      repository) that produces no finding.
- [ ] No copy of the overlap predicate exists anywhere in the new code — the lint splices
      `scripts/lib/file-scope-overlap.sh`.
- [ ] `context/patterns/file-footprint-overlap.md`'s Consumers list names this lint, with its count
      sentence corrected.
- [ ] Every finding is advisory: a test asserts exit 0 with findings present, and the header states
      the contract.
- [ ] Registered in `manifest.json` with a `scripts/tests/test-*.sh` companion, matching the
      existing lint-script convention.
- [ ] shellcheck clean per `context/standards/shell-strict-mode.md`.
- [ ] `unknown` layout produces a loud named note and exit 0, never a silent no-op; `stage` layout
      is parsed rather than skipped.
- [ ] Complete gate set green from the deployed tree.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/lint/lint-roadmap-batch-proposals.sh` (new)
- `agent-system/extensions/core/scripts/tests/test-lint-roadmap-batch-proposals.sh` (new)
- `agent-system/extensions/core/manifest.json` (two registration entries)
- `agent-system/extensions/core/context/formats/roadmap-format.md` (finding (e))
- `agent-system/extensions/core/context/contracts/conclusion-stage.md` (call site)
- `agent-system/extensions/core/context/patterns/file-footprint-overlap.md` (Consumers list)
- `agent-system/extensions/core/context/patterns/roadmap-update.md` (named forward pointer)
- `specs/313_advisory_lint_for_roadmap_batch_proposals/summaries/` (implementation summary)
- Serializing `dependencies[]` edges onto the records that share this task's declared territory

## Rollback/Contingency

Each phase commits independently, so the ordinary contingency is to stop at the last green phase
and report rather than to revert. The new script and its suite are additive: deleting both files
and reverting the two `manifest.json` lines restores the prior state with no other consumer
affected, since the lint is deliberately not wired into `verify-deploy.sh` as a numbered gate. The
four markdown edits in Phase 5 are each a self-contained addition that can be reverted
individually.

If a genuine rollback of uncommitted work becomes necessary, follow `context/contracts/recovery.md`'s
rollback rung for the snapshot-then-rollback invocation shape, including its out-of-scope override
flag — never discard uncommitted changes to reach a passing build, and never emit a bare,
precautionary `git-snapshot.sh` in its default reverting mode as a start-of-phase checkpoint. For
an ordinary defensive checkpoint before Phase 6's deploy, use the non-reverting
`bash .claude/scripts/git-snapshot.sh 313 --no-revert` form.

Phase 1's state mutations are reversible but should not be casually reverted: the serializing
edges reflect real shared territory, and removing one re-opens the collision it was added to
order.
