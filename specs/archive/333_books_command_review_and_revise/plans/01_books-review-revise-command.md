# Implementation Plan: Task #333

- **Task**: 333 - The /books command with --review and --revise
- **Status**: [COMPLETED]
- **Effort**: 7.75 hours
- **Dependencies**: Task 332 (books-observe.sh post-task observer) — complete
- **Research Inputs**: specs/333_books_command_review_and_revise/reports/01_books-review-revise-command.md
- **Artifacts**: plans/01_books-review-revise-command.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Build a new `/books` command with two sub-modes — `--review` (strictly read-only convention
performance review) and `--revise` (interactive proposal of research-and-revision tasks) — by
reproducing `/distill`'s proven three-layer split exactly: flag parsing in the command file, a
shared sub-mode skeleton plus thin stub pointers in a single direct-execution skill, and all
sub-mode-specific detail in two new context pattern files. The work is entirely markdown and JSON
authoring inside the **source store** (`agent-system/extensions/books/`), followed by registration
across four already-settled registration surfaces and a full extension-doc gate run. No Lean, no
shell script, and no edit to the books convention itself is in scope.

### Research Integration

The research report settled every design choice this plan sequences, and each is carried forward
by name rather than re-derived:

- **Three-layer split, re-measured**: `skill-distill/SKILL.md`'s `## Shared Sub-Mode Skeleton`
  occupies lines 278–321, immediately followed by `### Purge Sub-Mode` at line 322 — confirmed
  independently during this planning pass. Stub pointers take the exact verbatim form
  `READ .claude/context/project/memory/patterns/distill-<name>-submode.md now and follow it exactly.`
  (observed at `SKILL.md:700-720`). The new skill reproduces this form.
- **Single skill, two sub-modes** (research Decision 1): one `skill-books-review/SKILL.md` holds
  the skeleton and dispatches both sub-modes, exactly as one `skill-distill` backs twelve.
- **All interactive gates inline in the direct-execution skill** (Decision 2), matching the
  dispatch's measured constraint that `AskUserQuestion` is unreachable from a dispatched subagent.
- **Registration follows the memory manifest's template** (Decision 3): no `routing_agents` rows
  for a maintenance command outside the task lifecycle.
- **The validation marker is the `- **Validated by**:` line** at the head of each numbered Decision
  in the consuming repository's `docs/book-convention.md`, in its three-form vocabulary
  (`none yet [-- reason]` / `partially, <instances>` / named-outright = **binding**) (Decision 4).
- **Binding-clause proposals are filed as research-and-escalate tasks** expressed as a description
  convention on an ordinarily-typed task, never a new `task_type` or state field (Decision 5) —
  grounded in the research finding that no such primitive exists anywhere in this agent system.
- **Watermark** is a `specs/books-evidence/revise-log.json` cursor sibling to the existing
  `observations.jsonl`/`runs.jsonl` (Decision 6), not a `.memory/`-dependent store.
- **Cost figures come from the observation record's `generic` join group**, carrying an explicit
  capture-time caveat (Decision 7).

Two open questions the report deliberately escalated to this phase are resolved here: bare `/books`
with no flag **prints a usage message and exits non-zero rather than defaulting to `--review`**
(the report's own recommendation, since no "books health report" analogue is specified anywhere in
this deliverable set), and `books-revise-submode.md` **cites `telemetry-guardrails.md` by path while
restating only the two directly-applicable principles** (evaluator-outside-the-loop, CAPTURE ONLY)
in a short dedicated subsection — silent duplication without citation is the one option the report
ruled out.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch; no roadmap phases are included.

## Goals & Non-Goals

**Goals**:

- A `/books` command surface with `--review` and `--revise`, structurally mirroring `/distill`.
- `--review` as a strictly read-only, per-dimension performance review that names what is
  unmeasured, reports cost from captured records with the capture-time caveat stated, ranks
  recurring issue classes, pairs burdens created against burdens lifted, and funnels to `--revise`
  without ever proposing a task itself.
- `--revise` as an interactive proposer whose every candidate names its convention clause by
  durable heading text and quotes that clause's current validation marker verbatim, forks
  binding-clause candidates to research-and-escalate, reconciles against the open backlog before
  creating anything, runs every gate in the lead session, and advances a watermark so a second run
  does not re-propose the first run's evidence.
- Registration consistent with `check-extension-docs.sh`, including the EXTENSION.md 60-line cap.

**Non-Goals**:

- Editing the books convention (`docs/book-convention.md`) or any consuming-repository record.
- Building the repo-side snapshot probe or `specs/books-evidence/runs.jsonl` producer — the
  observation-record standard's Probe Ownership Boundary already makes those `absent` by design,
  and `--review` reports them as absent rather than synthesizing them.
- Adding a new `task_type`, state.json field, or `routing_agents` row.
- Any hand-authored file under `.claude/**`. That tree is a disposable deploy artifact; every edit
  in this plan targets `agent-system/extensions/books/`.
- Creating `specs/books-evidence/revise-log.json` as a committed file. Its schema is *specified*
  in the revise pattern file; the file itself is runtime state a consuming repository creates on
  first `--revise` run.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `EXTENSION.md` is already at exactly 60 lines (measured: `wc -l` = 60), the hard Rule U cap, so any added row breaks the gate | H | H | Phase 5 treats compression as a required sub-step, not a contingency: fold the two new rows in while compressing existing prose, then re-measure with `wc -l` before moving on |
| Hand-authoring under `.claude/**` instead of the source store, silently wiped by the next deploy | H | M | Every phase's file targets are source-store paths; Phase 6 greps the working tree for any `.claude/**` modification as an explicit gate |
| `index-entries.json` `line_count` drift failing Rule R | M | H | Phase 5 ends by running `generate-context-line-counts.sh --write` rather than hand-computing counts |
| Task-number references leaking into source-store deliverables | M | M | Phase 6 runs `check-task-references.sh`; durable anchors (filenames, Decision heading text) are used throughout |
| Re-inventing the sub-mode shape instead of mirroring `/distill`, the dispatch's single loudest prohibition | H | M | Phases 1–4 each name the specific `/distill` file and section they mirror, and Phase 2 reproduces the stub-pointer sentence form verbatim |
| Conflating the `observations.jsonl` digest with the canonical per-task record, double-counting a figure | M | M | Both new pattern files repeat the observation-record standard's own framing ("explicitly a pointer/derived index … never a second source of truth") with citation |
| `--revise` drifting into editing the convention or bypassing escalation | H | L | Both prohibitions are written as explicit, labelled prohibition clauses in `books-revise-submode.md`, and Phase 6 verifies each against the acceptance list |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3, 4 | 2 |
| 4 | 5 | 1, 2, 3, 4 |
| 5 | 6 | 5 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Command file — `commands/books.md` [COMPLETED]

**Goal**: A `/books` command file that parses `--review`/`--revise` (plus `--dry-run`/`--verbose`)
into a `sub_mode` and delegates to one direct-execution skill, mirroring `distill.md`'s
argument-parsing shape, and rejecting a bare invocation with a usage message.

**Tasks**:
- [x] Read `agent-system/extensions/memory/commands/distill.md` in full as the structural model
      (frontmatter `description:`, the `# Command:` header with Purpose/Layer/Delegates To/Input,
      the `<argument_parsing>` block with its numbered Sub-Mode Dispatch list and pseudocode).
- [x] Write `agent-system/extensions/books/commands/books.md` with that same section order.
- [x] Sub-Mode Dispatch: `--review` -> `review`, `--revise` -> `revise`. **No default**: a bare
      `/books` prints a usage message naming both flags and exits without delegating. State this as
      a deliberate divergence from `distill.md`'s bare-invocation report mode, with the reason (no
      books health-report analogue is specified), so a future reader does not "fix" it.
- [x] Additional flags: `--dry-run` (shows candidates, writes nothing — meaningful for `--revise`,
      an accepted no-op for the already-read-only `--review`) and `--verbose`.
- [x] Declare the delegation payload exactly once: `skill-books-review` with
      `mode=books, sub_mode={review|revise}` plus the two additional flags, as the contract Phase 2
      consumes.
- [x] Mirror `distill.md`'s read-only/mutating annotation so the reader can see at a glance that
      `--review` writes only its own report and `--revise` creates tasks.

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/books/commands/books.md` — new file

**Verification**:
- File exists and is non-empty; `grep -c` confirms both `--review` and `--revise` appear in the
  Sub-Mode Dispatch block.
- The bare-invocation branch is present and does **not** assign a `sub_mode`.
- The delegation line names `skill-books-review` and `mode=books`.
- Section order matches `distill.md`'s (diff the two files' `grep -n '^#\|^<'` outlines).

---

### Phase 2: Skill — `skills/skill-books-review/SKILL.md` [COMPLETED]

**Goal**: One direct-execution skill holding a shared sub-mode skeleton for the books domain plus
two one-line stub pointers, reproducing `skill-distill/SKILL.md`'s hub shape without duplicating
sub-mode detail.

**Tasks**:
- [x] Read `skill-distill/SKILL.md` lines 278–321 (`## Shared Sub-Mode Skeleton`) and lines 700–720
      (the stub-pointer block) — re-measure both ranges before relying on them; the line numbers
      here are a hypothesis (see Scope Hypothesis).
- [x] Create `agent-system/extensions/books/skills/skill-books-review/SKILL.md`. Frontmatter:
      `name`, `description`, and `allowed-tools: Bash, Grep, Read, Write, Edit, AskUserQuestion` —
      deliberately **no `Agent` tool**, so no interactive gate can be pushed into a subagent.
      Model the frontmatter field set on `skill-books-certify/SKILL.md` (45 lines, the books
      extension's own direct-execution precedent).
- [x] Write a short `## Mode: books` section stating the shared data path once: enumerate
      books-topic tasks from the append-only digest `specs/books-evidence/observations.jsonl`, then
      dereference each line's `record_path` for the canonical per-task
      `specs/{NNN}_{SLUG}/book.observation.json`. Quote the observation-record standard's own
      framing that the digest is "explicitly a pointer/derived index … never a second source of
      truth", citing `context/project/books/standards/observation-record.md`.
- [x] Write the `## Shared Sub-Mode Skeleton` section as the books-domain analogue of distill's
      seven steps: Edge Case Checks, Candidate Identification, Dry-Run, Interactive Selection
      (MANDATORY STOP), Execution, Watermark Advance (the books analogue of distill's Batch Index
      Regeneration — batched once after the confirmed set, never per-candidate), Log Entry.
- [x] State the MANDATORY-STOP exemption **explicitly** for `--review`, as a named sanctioned
      deviation rather than a silent omission — the exact discipline `distill-review-submode.md`
      and the distill skeleton's own `auto`/`report` exemptions already use.
- [x] Add an explicit lead-session clause: every `AskUserQuestion` multiSelect, per-candidate
      choice, and confirmation gate executes in the lead session; only a bounded non-interactive
      research or aggregation pass may be delegated.
- [x] Add the two stub pointers verbatim in form:
      `### Sub-Mode: review` / `READ .claude/context/project/books/patterns/books-review-submode.md now and follow it exactly.`
      and `### Sub-Mode: revise` / `READ .claude/context/project/books/patterns/books-revise-submode.md now and follow it exactly.`
- [x] Keep the skill thin: no sub-mode-specific candidate logic, prompt text, or output shape in
      this file.

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: interface

**Scope Hypothesis**: The distill skeleton is asserted to occupy `skill-distill/SKILL.md:278-321`
and the stub pointers `:700-720`. Confirm at implementation time with
`grep -n '^## Shared Sub-Mode Skeleton\|^### Purge Sub-Mode\|^### Sub-Mode:' agent-system/extensions/memory/skills/skill-distill/SKILL.md`
before quoting either range; use whatever the grep reports, not these numbers.

**Files to modify**:
- `agent-system/extensions/books/skills/skill-books-review/SKILL.md` — new file

**Verification**:
- Frontmatter `allowed-tools` includes `AskUserQuestion` and excludes `Agent`.
- Exactly two `READ … now and follow it exactly.` stub pointers, whose paths match the filenames
  Phases 3 and 4 create character-for-character.
- The `sub_mode` values the skill dispatches on (`review`, `revise`) match Phase 1's declared
  payload exactly — grep both files and compare.
- The `--review` MANDATORY-STOP exemption appears as explicit text.
- No sub-mode-specific candidate or output logic present (the file stays near
  `skill-books-certify/SKILL.md`'s order of magnitude, not distill's 836 lines).

---

### Phase 3: `context/project/books/patterns/books-review-submode.md` [COMPLETED]

**Goal**: The complete and only specification for the strictly read-only `--review` sub-mode,
structured off `distill-review-submode.md`.

**Tasks**:
- [x] Read `distill-review-submode.md` (91 lines) in full as the structural model, then open the
      opening sentence with the same "the COMPLETE and ONLY specification for this sub-mode" framing
      both distill pattern files use.
- [x] State the read-only posture in the opening: `--review` never proposes and never writes, with
      its single sanctioned write — its own dated report — named explicitly, and the MANDATORY-STOP
      exemption restated as an explicit exemption.
- [x] **Edge Case Checks**: zero digest-log lines, a digest line whose `record_path` does not
      resolve, and a record present but with every dimension unmeasured — each with its own named
      early-return message string rather than a generic failure.
- [x] **Candidate Identification** as a **per-dimension access table**, one row per each of the
      seven dimensions spelled verbatim from the observation-record standard — `maintainability`,
      `cross_pollination`, `guardrails_qa`, `token_cost_efficiency`, `readability`,
      `intuitive_exposure`, `compiling_composing` (the last with its two first-class sub-fields
      `import_weight` and `compilation_weight`). Each row carries: the record field path it reads,
      and a **named degraded-behavior string** for when that dimension has no data yet. Never
      respell or abbreviate a dimension name.
- [x] Specify the report's **WHAT IS UNMEASURED** section as a required section, not a conditional
      one: every dimension with no data is listed by name. State the rule that a review silently
      omitting an unmeasured dimension is a defect.
- [x] Specify signal reporting as **figures and trends, not adjectives**: per dimension, positive
      and negative signal counts by `polarity` (exactly `positive` or `negative`, no default), with
      `untagged` signals counted as `untagged` and never defaulted onto a dimension.
- [x] Specify **cost per task and per phase kind** from the observation record's `generic` join
      group (`dispatch_count`, `phases`, `outcomes`, `wall_clock_seconds_total`), aggregated across
      every task reached via the digest log. Include a required, verbatim-ish capture-time caveat
      sentence: these figures reflect what was captured at each task's postflight, not live
      telemetry, citing `context/formats/dispatch-metrics.md`'s own "CAPTURE ONLY — No Reporting
      Here" framing and its 30-day transcript window.
- [x] Specify **recurring issue classes, ranked**, read from the per-task `issue_counts` /
      `issues_present` fields of the `generic` group.
- [x] Specify **burdens created versus burdens lifted** as the paired-signal report the schema
      guarantees: `burdens_created[]` and `burdens_lifted[]` are both always present (defaulting to
      `[]`, never one without the other), each entry naming its bearing Decision by durable heading
      text (e.g. `"Decision 13: Exposure policy"`).
- [x] State **omit-never-zero (D5)** as a reporting rule: an underivable figure is omitted, never
      rendered as a fabricated `0`; `absent` is used only for the two fields the standard names
      (`vacuous_passes`, `snapshot_delta`). Report `verification_tiers`/`certifier_outcomes` as
      absent where the consuming repository has not built the probe, per the standard's Probe
      Ownership Boundary — never synthesize one.
- [x] Note that vacuous passes are first-class and never inferred by negating an ordinary pass.
- [x] **Dry-Run**: an accepted no-op (nothing to suppress), stated explicitly.
- [x] **Output**: a dated report written under the consuming repository's `specs/` tree, plus a
      terminal summary. Specify the report path shape and the date format; the report is the sub-
      mode's only write.
- [x] **Funnel rule**, as an explicit closing section: the report ends by naming the strongest
      candidates and telling the user to run `/books --revise`. `--review` performs none of those
      follow-on actions itself and proposes no task.
- [x] **Log Entry**: optional and lightweight, mirroring distill's read-only convention (identical
      pre/post metrics), explicitly not required for the sub-mode to function.

**Timing**: 1.5 hours

**Depends on**: 2

**Verification Tier**: local

**Scope Hypothesis**: Seven dimensions and their exact field spellings are asserted from
`context/project/books/standards/observation-record.md`. Confirm each spelling by grepping that
standard before writing the access table; if the standard names a different count or spelling, the
standard wins and the table follows it.

**Files to modify**:
- `agent-system/extensions/books/context/project/books/patterns/books-review-submode.md` — new file

**Verification**:
- All seven dimension names appear verbatim; `grep` each against `observation-record.md`.
- A `WHAT IS UNMEASURED` section exists and is described as required, not conditional.
- The capture-time caveat sentence is present and cites the dispatch-metrics "CAPTURE ONLY" framing.
- A funnel section exists naming `--revise`, and the file contains no task-creation or
  task-proposal instruction anywhere (grep for proposal/create-task language and confirm each hit
  is a prohibition, not an instruction).
- Exactly one write target is described (the dated report).

---

### Phase 4: `context/project/books/patterns/books-revise-submode.md` [COMPLETED]

**Goal**: The complete and only specification for `--revise`: candidate evaluation since the
watermark, the mandatory decision-record research step, clause-and-marker naming, the
binding-clause escalation fork, backlog reconciliation, lead-session gates, and the watermark
advance.

**Tasks**:
- [x] Read `distill-meta-submode.md` (205 lines) and `distill-revise-submode.md`'s watermark
      mechanism as the structural models; open with the same "COMPLETE and ONLY specification"
      framing.
- [x] **Books telemetry posture** subsection: cite
      `context/project/memory/telemetry-guardrails.md` by path and restate only the two directly
      applicable principles — **evaluator outside the loop** (propose-then-human-review, never
      auto-apply) and **CAPTURE ONLY** (the records are what postflight captured, not live
      telemetry). Citation plus brief restatement; neither silent duplication nor a bare pointer.
- [x] **Edge Case Checks**: no digest log; every digest line already at or behind the watermark
      (named early-return message: nothing new to consider); the consuming repository's
      `docs/book-convention.md` not found (hard early return — without the decision record no
      proposal can name its clause, so none may be proposed).
- [x] **Candidate Identification**: read only digest-log lines whose `recorded_at` is strictly
      after the stored watermark cursor; group candidates by `convention_decision` (durable heading
      text) and by dimension; rank by recurrence and by paired-burden asymmetry (burdens created
      without a matching lift). State a closed discovery rule and explicitly refuse to invent new
      detection logic beyond it, mirroring `--meta`'s own refusal clause.
- [x] **Mandatory preliminary research step**, stated as a precondition on presenting *any*
      candidate: read the consuming repository's `docs/book-convention.md` and, for every Decision a
      candidate touches, capture that Decision's durable heading text and its current
      `- **Validated by**:` marker **verbatim**. Document the three-form vocabulary
      (`none yet [-- reason]` / `partially, <instances>` / anything else named outright = binding)
      and name `books/scripts/lint-validated-by.sh` as its mechanical linter. State the bar
      directly: a proposal that cannot name its clause and quote that clause's marker is not ready
      to be proposed and is dropped, not guessed at. Cite
      `context/project/books/domain/known-gap-register.md` as a navigation aid only, noting it is a
      dated projection whose live authority is the convention's markers themselves.
- [x] **Interactive Selection (MANDATORY STOP)**, all in the **lead session**: (a)
      `AskUserQuestion` with `multiSelect: true` over candidates, each option's `description`
      carrying the Decision's durable heading text, its marker verbatim, and the evidence citations;
      (b) a per-candidate choice of Create as task / Note in report only / Skip; (c) a second,
      explicit confirmation gate before anything is written. Add a prominent clause: these gates
      MUST NOT be delegated to a subagent — `AskUserQuestion` is not reachable from one on this
      harness; only non-interactive research or aggregation may be delegated.
- [x] **Dry-Run**: display the candidate set with clause and marker per candidate, then return
      early. No task created, and the watermark is **not** advanced.
- [x] **Execution — binding-clause fork**, placed before backlog reconciliation: a candidate whose
      Decision's marker is **binding** is filed as a **research-and-escalate task** — a task whose
      description states explicitly that its phases perform research only and surface findings for
      the repository owner's ruling, never implement a convention change. Specify this as a
      description-text convention on an ordinarily-typed task (`task_type: meta`), explicitly **not**
      a new `task_type`, state field, or enum value, and say why (nothing mechanically reads such a
      field today). Every non-binding candidate follows the ordinary path.
- [x] **Two prohibitions**, as labelled prohibition clauses: (1) `--revise` NEVER edits the
      convention — it proposes tasks and the tasks do the work through the normal lifecycle;
      (2) `--revise` NEVER bypasses the consuming repository's escalation protocol.
- [x] **Backlog reconciliation**, after the create/note/skip choice and before the final
      confirmation gate: compare each proposed task against the open backlog (`specs/state.json`
      `active_projects`) and apply `docs/reference/standards/multi-task-creation-standard.md`'s
      Component 0 (one task per finding unless a closed reason justifies splitting), Component 4a
      (file-footprint overlap adds a dependency edge), and Component 7 (final user confirmation).
      Enumerate the four admissible outcomes per comparison: create, widen an open task, add a
      dependency edge, or narrow a file scope.
- [x] Specify that task creation delegates to the existing `/task` primitive rather than
      reimplementing it inline, mirroring `--meta`'s delegation discipline, and that a candidate
      whose remedy is a prose edit is a report-only finding, never auto-applied.
- [x] **Watermark Advance**: specify `specs/books-evidence/revise-log.json` (sibling to
      `observations.jsonl`/`runs.jsonl`) with its schema — per-run entries carrying
      `considered_through: {recorded_at, record_path}` plus a proposals rollup
      (`surfaced`, `created_as_task`, `noted_only`, `skipped`, `task_numbers_created`), modelled on
      distill's `meta-log.json`. Advance the cursor once, after the confirmed batch, never
      per-candidate; do not advance on a dry run or an aborted confirmation. State the consequence
      plainly: without this, a second run re-proposes the first run's evidence.
- [x] Repeat the digest-is-a-pointer framing with citation, as in Phase 2.

**Timing**: 2 hours

**Depends on**: 2

**Verification Tier**: local

**Scope Hypothesis**: The `Validated by` three-form vocabulary and the claim that the convention
carries eighteen Decisions with two binding are asserted from
`context/project/books/domain/known-gap-register.md`'s dated census. Confirm the vocabulary forms
against that register at implementation time, and write the pattern file so it reads the **live**
markers rather than hard-coding any census figure — no count from the register is to appear as a
fact in the deliverable.

**Files to modify**:
- `agent-system/extensions/books/context/project/books/patterns/books-revise-submode.md` — new file

**Verification**:
- The mandatory decision-record read is stated as a precondition on presenting any candidate, and
  the "cannot name its clause -> not proposed" bar appears explicitly.
- The three marker forms appear verbatim, and the binding fork to a research-and-escalate task is
  present with its description-convention (not new-task_type) framing.
- Both prohibitions appear as labelled clauses.
- Backlog reconciliation is positioned after create/note/skip and before the confirmation gate, and
  names Components 0, 4a, and 7.
- The watermark schema is specified, with explicit non-advance on dry-run/abort.
- A lead-session clause forbidding delegation of any gate is present.
- No census figure from the known-gap register appears as an asserted fact.

---

### Phase 5: Registration and documentation [COMPLETED]

**Goal**: Register the new command, skill, and two context files across all four registration
surfaces so that `check-extension-docs.sh` passes, including the EXTENSION.md 60-line cap.

**Tasks**:
- [x] `agent-system/extensions/books/manifest.json`: add `"books.md"` to `provides.commands` and
      `"skill-books-review"` to `provides.skills`. Add **no** `routing_agents` or
      `routing_agents_hard` entry — `/books` is a direct-execution maintenance command outside the
      research/plan/implement lifecycle, exactly as `/distill` and `/learn` carry none in the memory
      manifest. Validate the file parses (`python3 -c 'import json,sys;json.load(open(...))'`).
- [x] `agent-system/extensions/books/index-entries.json`: add one entry per new pattern file, using
      the existing per-entry field set only (`path`, `line_count`, `load_when` with keys drawn from
      `agents`/`commands`/`task_types`/`always`, optional `on_demand`, `domain`, `subdomain`,
      `topics`, `summary`, `keywords`). Do **not** add a `description` or `tags` key — Rule T
      forbids both. Set `domain: "project"`, `subdomain: "books"`, and mark both `on_demand: true`
      following the sibling pattern files' convention.
- [x] Update the existing `project/books/README.md` index entry's `summary`, which currently says
      "a sixteen-row table" — make it agree with the nav table as it stands after this phase.
- [x] `agent-system/extensions/books/EXTENSION.md` (**at exactly 60 lines, zero headroom**): add a
      `/books` row to the `### Commands` table and a `skill-books-review | (direct execution)` row
      to `### Skill-Agent Mapping`, then compress existing prose by at least the number of lines
      added so `wc -l` stays `<= 60`. Also correct the closing Context Pointers line, which states
      the corpus holds "eighteen docs". Re-measure with `wc -l` as the last step of this sub-task.
- [x] `agent-system/extensions/books/README.md` (no line cap): add a `/books` row to its
      `## Commands` table and a `skill-books-review` row to its Skill-Agent Mapping, mention the
      two sub-modes, update the directory-map comment on `commands/` and the
      `context/project/books/` "eighteen documents" count, and briefly note the watermark store.
      The gate checks that every manifest command is mentioned in this README.
- [x] `agent-system/extensions/books/context/project/books/README.md`: add navigation rows for the
      two new pattern files, with a "Read this when" phrasing matching the existing rows' voice.
      While here, note that the nav table is missing rows for `standards/observation-record.md` and
      `patterns/signal-tagging.md` (16 rows against 18 docs on disk — a pre-existing gap found
      during planning); add those two rows as well so the table is truthful, and update the
      document count in the README's own prose.
- [x] Run `bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --write` to set
      every `line_count` mechanically rather than by hand.

**Timing**: 1.5 hours

**Depends on**: 1, 2, 3, 4

**Verification Tier**: interface

**Scope Hypothesis**: `EXTENSION.md` is asserted to be exactly 60 lines (at the Rule U cap),
`index-entries.json` to hold 19 entries, and the domain `README.md` nav table to hold 16 rows
against 18 docs on disk. Re-measure all four with `wc -l`, a `json` entry count, and a row count
before editing; the compression requirement in particular stands or falls on the first measurement.

**Files to modify**:
- `agent-system/extensions/books/manifest.json` — `provides.commands`, `provides.skills`
- `agent-system/extensions/books/index-entries.json` — two new entries, one summary correction
- `agent-system/extensions/books/EXTENSION.md` — two table rows plus compression to stay `<= 60`
- `agent-system/extensions/books/README.md` — command row, skill row, counts, directory map
- `agent-system/extensions/books/context/project/books/README.md` — four nav rows, prose count

**Verification**:
- `manifest.json` and `index-entries.json` both parse as JSON.
- `wc -l agent-system/extensions/books/EXTENSION.md` reports `<= 60`.
- `grep -c '/books' agent-system/extensions/books/README.md` is non-zero (the manifest-command
  mention check).
- Every `line_count` in `index-entries.json` matches `wc -l` of its source file (re-run
  `generate-context-line-counts.sh` and confirm it reports no change).
- No `description` or `tags` key in either new index entry.
- No `routing_agents` change in the diff.

---

### Phase 6: Final gate and acceptance verification [COMPLETED]

**Goal**: Prove the full gate set passes and every acceptance clause in the dispatch is satisfied
by the written files.

**Tasks**:
- [x] Run `bash .claude/scripts/verify-deploy.sh` (source-store path:
      `agent-system/extensions/core/scripts/verify-deploy.sh`) — the complete gate set — and resolve
      every failure it reports.
- [x] Run `bash agent-system/extensions/core/scripts/check-extension-docs.sh` and confirm the books
      extension raises no Rule A / K / R / T / U finding.
- [x] Run `bash agent-system/extensions/core/scripts/check-task-references.sh` and confirm no
      task-number reference landed in any source-store file written by this task.
- [x] Confirm `git status --short` shows **no** modification under `.claude/**` — every edit must be
      in `agent-system/extensions/books/`.
- [x] Walk the dispatch's acceptance list clause by clause against the written files, recording the
      file and section that satisfies each: `--review` writes only its dated report and proposes
      nothing; `--review` names unmeasured dimensions explicitly; every `--revise` proposal names a
      convention clause and that clause's validation marker; a binding-clause proposal is filed as
      research-and-escalate; the watermark prevents re-proposal across two consecutive runs; backlog
      reconciliation precedes creation; every interactive gate sits in the lead session;
      registration files are consistent with `check-extension-docs.sh`.
- [x] Record any gate collision, deviation, or unusually smooth result via
      `bash .claude/scripts/issue-record.sh` as it arises (non-fatal).

**Timing**: 0.75 hours

**Depends on**: 5

**Verification Tier**: full

**Scope Hypothesis**: The dispatch's acceptance list is read here as eight clauses. Re-read the
dispatch's `== ACCEPTANCE ==` block and walk whatever clauses it actually contains; the count is a
convenience, not a contract, and a clause omitted because it did not fit the number is a failure.

**Files to modify**:
- None (verification only; any failure is fixed in the owning phase's files)

**Verification**:
- `verify-deploy.sh` exits 0, or every reported finding is resolved and it is re-run to 0.
- `check-extension-docs.sh` reports no books-extension failure.
- `check-task-references.sh` reports no new violation.
- `git status --short` has zero `.claude/` entries.
- An eight-clause acceptance walk is recorded, each clause mapped to a file and section.

---

## Testing & Validation

- [x] `verify-deploy.sh` passes (full gate set).
- [x] `check-extension-docs.sh` raises no books-extension Rule A/K/R/T/U finding.
- [x] `EXTENSION.md` is at most 60 lines.
- [x] `manifest.json` and `index-entries.json` parse, and no `routing_agents` row was added.
- [x] `check-task-references.sh` reports no new violation.
- [x] No file under `.claude/**` was modified.
- [x] Each of the eight dispatch acceptance clauses maps to a named file and section.
- [x] The command/skill/pattern-file cross-references resolve: Phase 1's delegation payload matches
      Phase 2's dispatch values, and Phase 2's two stub-pointer paths match the Phase 3/4 filenames
      exactly.

## Artifacts & Outputs

- `agent-system/extensions/books/commands/books.md`
- `agent-system/extensions/books/skills/skill-books-review/SKILL.md`
- `agent-system/extensions/books/context/project/books/patterns/books-review-submode.md`
- `agent-system/extensions/books/context/project/books/patterns/books-revise-submode.md`
- Updated: `manifest.json`, `index-entries.json`, `EXTENSION.md`, `README.md`,
  `context/project/books/README.md`
- `specs/333_books_command_review_and_revise/summaries/01_*-summary.md` (implementation phase)

## Rollback/Contingency

All four new files are additive and all five edited files are registration surfaces, so rollback is
a clean revert: `git checkout -- agent-system/extensions/books/` restores the registration files and
the new, untracked files can be removed. Nothing in this plan touches the deployed `.claude/` tree,
any consuming repository's convention record, or any runtime state, so an abandoned implementation
leaves no partially-migrated artifact behind. If Phase 5's EXTENSION.md compression cannot reach
`<= 60` lines without losing load-bearing content, stop and surface it rather than exceeding the
cap: the correct remedy is a separate `extension-slim-standard.md` conversation, not a silently
over-cap file.
