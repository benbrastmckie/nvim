# Implementation Plan: Task #329

- **Task**: 329 - Per-task issue log: contract, writer and dispatch threading
- **Status**: [IMPLEMENTING]
- **Effort**: 11 hours
- **Dependencies**: Task 285 (completed), Task 326 (completed) — both were file-footprint
  serializations on `orchestrate-cycle-postflight.sh` / `orchestrate-build-dispatch.sh` and have
  both already landed; no live blocker remains. Known non-serialized overlap: task 299 (also
  edits `orchestrate-build-dispatch.sh`, status not_started).
- **Research Inputs**: specs/329_per_task_issue_log_contract_writer_and_threading/reports/01_issue-log-contract-writer-threading.md
- **Artifacts**: plans/01_issue-log-writer-threading.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md,
  shell-strict-mode.md, shell-script-testing.md, source-store-deploy-boundary.md,
  no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Introduce an append-only per-task `specs/{NNN}_{SLUG}/issues.jsonl`, written exclusively by one
new script `issue-record.sh`, and thread the recording instruction to every dispatched agent
through the single existing per-dispatch prompt emitter rather than through any of the 78 agent
definition files. The log is CAPTURE ONLY: no mid-run surfacing, no proposals, no gates, no
status changes, and a recording failure never fails a dispatch. The same pass records, in a new
format doc, an explicit SUBSUME/MIRROR/LEAVE verdict for each of the six surfaces that carry
issue information today, and retires the dead `reflection` field rather than leaving it dead
beside a newly live log.

### Research Integration

The research report's findings are adopted with three concrete refinements this plan locks in:

1. **Three precedents, not one.** `issue-record.sh` takes its JSONL append mechanics
   (`jq -c -n` line construction, `flock -x` + O_APPEND, lazy file creation) from
   `scripts/events-append.sh`; its argument-validation style and non-fatal call-site convention
   from `scripts/system-defect-record.sh` (the writer named in the task description); and its
   per-task-file targeting discipline from `scripts/orchestrate-record-decision.sh`. It does
   **not** take `orchestrate-record-decision.sh`'s read-merge-validate-`mv` array mechanics —
   `issues.jsonl` is append-only-by-line by name and by its durability requirement.
2. **`--task N` resolution is required, not optional.** The research recommended `--task-dir PATH`
   as the sole argument because "every known caller already holds the absolute path". Re-measured
   this session, that is false for one named call site: `orchestrate-cycle-plan.sh`'s loop-guard
   exhaustion block (lines 1569 and 1585, inside the per-candidate eligibility loop) holds only
   the bare task number `$t` and no task directory. `--task-dir PATH` is therefore the preferred
   argument and `--task N` an accepted alternative resolving via `scripts/lib/task-lookup-lib.sh`
   (`task_lookup_entry` / `task_lookup_dir`), exactly as `orchestrate-record-decision.sh` does.
3. **The lock file needs ephemeral-class registration.** Not named in the task description or the
   research report: `.issues.lock` must be registered as a new member of
   `scripts/lib/runtime-file-patterns.sh`'s three parallel arrays (mirroring `.decisions.lock`
   exactly) and the generated `specs/.gitignore` managed block regenerated, or the lock file
   shows up as untracked churn in every `git status`. `issues.jsonl` itself stays **tracked** —
   it is durable, freshness-gated provenance, the same class as `.orchestrator-handoff.json`.

Every line number cited in this plan was re-measured against the source store on 2026-10-03 and
is stated as approximate. Phases 5 and 6 each carry an explicit re-measure step as their first
task, because tasks 285 and 326 already shifted these files once between the task description's
estimate and the research report's own read.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch; no roadmap phases are included.

## Goals & Non-Goals

**Goals**:
- One script, `issue-record.sh`, is the sole writer of `specs/{NNN}_{SLUG}/issues.jsonl`, appending
  exactly one validated line per call, non-fatally.
- An agent dispatched through `orchestrate-build-dispatch.sh` receives a `## Issue Log` instruction
  in its dispatch file, in every phase, without any agent definition file being edited.
- A blocked dispatch, an off-schema return, a declined recovery, and loop-guard exhaustion each
  leave a structured `issues.jsonl` entry rather than only a commit subject line.
- `kind: "win"` entries are recordable on equal footing with `kind: "issue"`.
- The relation of `issues.jsonl` to each of the six existing surfaces is written down as an
  explicit SUBSUME / MIRROR / LEAVE verdict in `context/formats/issue-log.md`.
- `reflection` is either live or gone, not dead — this plan makes it gone.
- All new and modified shell is shellcheck-clean per `context/standards/shell-strict-mode.md`.

**Non-Goals**:
- Any mid-run surfacing, summary, proposal, gate, or status change derived from the log. Review of
  the log belongs exclusively to the separate conclusion-stage backlog item, whose three channels
  are derived from these logs. A mid-run surface is the defect that design exists to avoid.
- Changing the semantics or consumers of `.return-meta.json` `errors[]`, progress-file
  `approaches_tried[]`, handoff `blockers[]`/`dead_ends`, or `system_defect` events. All four are
  MIRROR verdicts: they keep their current writers unchanged.
- A machine-checkable `context/schemas/issue-log-schema.json`. The research flagged the
  prose-plus-schema pairing convention this omission breaks; it is not in this task's acceptance
  bar and is recorded as a follow-up note inside the format doc instead.
- Any closed-enum enforcement of `class`. Unknown classes are accepted with a stderr warning, by
  design — this is the one deliberate divergence from `system-defect-record.sh`'s posture.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Line numbers in this plan have moved again before an implementer reads it (two prior tasks already shifted these files once) | M | H | Every number is marked approximate; Phases 5 and 6 each open with a mandatory re-measure task before any edit, and each carries a Scope Hypothesis line |
| An `issue-record.sh` call added beside a sibling field write drifts out of sync with it in a later edit, becoming a second dead feature like `reflection` | H | M | Co-locate every call immediately adjacent to the sibling write it mirrors, in the same `if`/case arm, so the pair is visibly coupled in any future diff — never in a separate pass or helper |
| `reflection` retirement reaches further than the three sites the task description names (also: state-schema.json, skill-todo, two memory-extension consumers, two doc files) | M | H | Phase 7 opens with a repo-wide `grep -rn reflection` inventory across BOTH extensions and treats the resulting count as a hypothesis to confirm; the state.json field and the event-store event type are retired on deliberately different terms (see Phase 7) |
| Retiring the state.json field breaks the memory extension's `/distill --revise` / `--meta` | H | L | Those two consumers read `reflection`-typed **events**, and `distill-revise-submode.md` already documents in-repo why it uses the event store and not the state field — they are already decoupled; Phase 8 verifies this by reading rather than assuming |
| Task 299 lands in `orchestrate-build-dispatch.sh` concurrently | M | L | Phase 5's re-measure task is the mitigation; whichever lands second re-measures. No serialization edge is added |
| A recording failure fails a dispatch, inverting the whole point | H | L | Every call site uses the documented non-fatal form `bash .../issue-record.sh ... >/dev/null 2>&1 \|\| echo "Note: ... (non-fatal)" >&2`; Phase 3's test suite covers the non-fatal failure path explicitly |
| Unbounded `class` drift into tag soup with nothing ever reviewing it | L | M | Out of scope here (CAPTURE ONLY); recorded as an explicit note in the format doc for the conclusion stage to tally unknown classes as part of its own synthesis |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 7 | 1 |
| 3 | 3, 4, 5, 6, 8 | 2 (phases 3-6), 7 (phase 8) |
| 4 | 9 | 3, 4, 5, 6, 8 |

Phases within the same wave can execute in parallel: their file footprints are disjoint (verified
against the source store this session — Phase 3 owns only the new test file; Phase 4 owns the
runtime-file lib and its two test consumers; Phase 5 owns the dispatch builder and the two
contract includes; Phase 6 owns the two cycle scripts; Phase 8 owns the memory extension plus
`events-format.md`).

**Edit target for every phase**: the source store,
`/home/benjamin/.config/nvim/agent-system/extensions/core/` (and
`.../agent-system/extensions/memory/` for Phase 8). Never `.claude/**` — that tree is a
gitignored, disposable deploy artifact and a hand-authored file there is silently wiped by the
next deploy. All paths below are relative to the relevant extension's source-store root unless
stated otherwise.

**Prohibition that applies to every phase**: no task-number references in any file written into
the source store. Cite durable anchors — a filename, a section heading, a class name from the
taxonomy enum. Task numbers are permitted in this plan, in other `specs/**` artifacts, and in
commit messages, nowhere else.

---

### Phase 1: Author the Issue-Log Format Doc and Record the Six Relation Verdicts [COMPLETED]

**Goal**: `context/formats/issue-log.md` exists as the authoritative contract that every later
phase cites: entry schema, the 15-class seed enum with a one-line gloss each, the chosen severity
scale, the CAPTURE-ONLY boundary, when an agent should record, and an explicit SUBSUME / MIRROR /
LEAVE verdict for each of the six existing surfaces.

**Tasks**:
- [x] Read `context/formats/events-format.md` and `docs/architecture/handoff-schema.md`'s
      "Decisions File Schema" section first, and follow their prose-contract conventions (field
      table with required/type/semantics columns, a worked example line, an explicit producer and
      consumer statement) rather than inventing a new document shape. *(completed)*
- [x] Write the entry field table: `kind` (closed: `issue`|`win`), `class` (open/extensible),
      `severity`, `phase` (`research`|`plan`|`implement`|`conclusion`|`other`), `dispatch_seq`,
      `what_happened` (required, free prose, one paragraph), `evidence_path`, `estimated_cost`,
      `resolution` (`fixed_inline`|`worked_around`|`open`), `suggested_channel`
      (`fix_now`|`follow_up_task`|`agent_system`), `tags` (open object). *(completed)*
- [x] Choose and document the ordered severity scale explicitly, with a one-line admission test
      for each rung so two agents classify the same event the same way. *(completed)*
- [x] Document `estimated_cost` as a `{value, unit}` pair with the unit recorded explicitly
      (minutes, dispatches, or gate runs) rather than forcing everything into minutes. *(completed)*
- [x] Seed the `class` enum with exactly the 15 named classes, each with a one-line gloss:
      design-record defect or ambiguity; gate collision; missing cheap verification tier;
      vacuous or silent pass; tooling bug or gap; resource/OOM including misdiagnosis; plan
      scope-hypothesis wrong; planned feature absent; language or module-system gotcha;
      environment; cross-task ownership/territory; stale deploy or source-store boundary;
      orchestration defect; stale workaround; cost-forced exclusion or substituted verification. *(completed)*
- [x] State the extensibility rule prominently: an unrecognized `class` is accepted with a stderr
      warning, never refused, so a new failure mode is recordable the first time it is hit. Say
      why, so a future reader does not "fix" it into a closed enum by analogy to
      `system-defect-record.sh`. *(completed)*
- [x] State that `tags` is an open object that extensions populate and core neither validates the
      interior of nor depends on — this is the seam an extension's own dimension tagging uses. *(completed)*
- [x] Write the CAPTURE ONLY section: nothing is surfaced mid-run, nothing is acted on, no
      proposal is generated, no gate added, no status changed; review belongs exclusively to the
      conclusion stage; a recording failure never fails a dispatch. *(completed)*
- [x] Write the "when to record" section: record as the event arises, not reconstructed at the
      end. Name the trigger moments (a deviation from plan, a blocker, a workaround, a gate
      collision, an unusually smooth or time-saving result) and state that end-of-dispatch
      reconstruction is exactly what produces the free prose this log replaces. *(completed)*
- [x] Record the six relation verdicts as a table with a stated boundary for each:
      `.return-meta.json` `errors[]` → **MIRROR**; progress-file `approaches_tried[]` →
      **MIRROR** (note: the surface's actual field name is `approaches_tried[]`, not
      `deviations[]` — `progress-file.md` has no `deviations[]` field, and "Plan Deviations" is a
      free-prose heading in the summary artifact, not a progress-file JSON field);
      handoff `blockers[]`/`dead_ends` → **MIRROR**; `system_defect` events → **LEAVE**
      (independent populations and enums; adjacent calls only at the two sites where both already
      fire); state.json `reflection` → **RETIRE**, with `kind: "win"` becoming the live home for
      its positive half and `kind: "issue"` for its negative half. *(completed)*
- [x] Add a short note acknowledging the deliberate absence of a companion
      `context/schemas/issue-log-schema.json`, breaking the prose+schema pairing convention that
      `events-format.md` and `handoff-schema.md` both follow, and recording it as a low-cost
      follow-up rather than a silent omission. *(completed)*
- [x] Add the unknown-class-tally note for the conclusion stage to pick up (the feedback loop that
      eventually promotes a recurring unknown class into the documented seed enum). *(completed)*
- [x] Register the new file in `index-entries.json` for the core extension if that file carries
      per-context-file entries — check first; if it does, add an entry with an accurate summary,
      and leave `agents[]` empty so the doc is not auto-loaded at agent spawn (it is read-on-
      demand reference material). *(completed)*

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: the seed enum is exactly 15 classes and the relation table exactly 6 rows.
Confirm by counting both in the written file before closing the phase; a 14- or 16-row enum means
a class was dropped or invented.

**Files to modify**:
- `context/formats/issue-log.md` - new file; the authoritative contract
- `index-entries.json` - conditional; add a context-index entry only if this file carries
  per-context-file entries for the core extension

**Verification**:
- `context/formats/issue-log.md` exists, contains exactly 15 glossed class entries and exactly 6
  relation verdict rows, each verdict being one of SUBSUME / MIRROR / LEAVE / RETIRE with a stated
  boundary.
- `grep -c` confirms no task-number reference of the form `task [0-9]` in the new file.
- Markdown links and cross-references resolve: every file path cited in the doc exists in the
  source store.

---

### Phase 2: Implement `issue-record.sh`, the Single Writer [COMPLETED]

**Goal**: One script appends exactly one validated JSON line per call to
`${TASK_DIR}/issues.jsonl`, lazily creating the file, guarded by `flock` on
`${TASK_DIR}/.issues.lock`, never refusing an unknown `class`, and never fataling its caller.

**Tasks**:
- [x] Read `scripts/events-append.sh` in full (189 lines), `scripts/system-defect-record.sh` in
      full (357 lines), and `scripts/orchestrate-record-decision.sh` in full (192 lines) before
      writing a line. Follow their conventions; do not invent new ones. *(completed)*
- [x] Write the header comment block in the established house style: single-responsibility
      statement, usage block, exit codes, stdout/stderr contract, and an explicit pointer to
      `context/formats/issue-log.md` for the full field contract. *(completed)*
- [x] Call out in the header, explicitly, that the `class` enum is deliberately OPEN
      (accept-with-warning) and that this is an intentional divergence from
      `system-defect-record.sh`'s closed-enum-refuses-loudly posture — so a future reader does not
      close it by analogy. *(completed)*
- [x] Class A strict mode per `context/standards/shell-strict-mode.md`: `set -euo pipefail` (no
      counter idiom in this script). *(completed)*
- [x] Argument parsing in `system-defect-record.sh`'s style: `--task-dir PATH` (preferred) or
      `--task N` (alternative), `--kind`, `--class`, `--severity`, `--phase`, `--dispatch-seq`,
      `--what-happened`, `--evidence-path`, `--cost-value`, `--cost-unit`, `--resolution`,
      `--suggested-channel`, `--tags-json`, `--session`. *(completed)*
- [x] Resolve the task directory: use `--task-dir` verbatim when absolute, resolve it against
      `$PROJECT_ROOT` when relative, and when only `--task N` was given, source
      `scripts/lib/task-lookup-lib.sh` and resolve via `task_lookup_entry` / `task_lookup_dir`.
      Mirror `orchestrate-record-decision.sh`'s resolution discipline, including its documented
      note that task-directory resolution is NOT done via `task-lock.sh` (a different, unrelated
      mutex). *(completed)*
- [x] Validate before any write: `kind` against the closed set `issue|win`; `what_happened`
      required and non-empty; `phase`, `resolution`, `suggested_channel` against their closed sets
      when present; `--tags-json` parses as a JSON object when present. Refuse (nonzero exit,
      nothing written) on any of these. *(completed)*
- [x] Validate `class` leniently: warn to stderr and proceed when it is outside the 15-class seed
      enum. Keep the seed list in one array in the script with a comment pointing at the format
      doc as the authoritative copy. *(completed)*
- [x] Build exactly one line with `jq -c -n` — never string concatenation — including a generated
      entry id and an ISO8601 timestamp, following `events-append.sh`'s construction shape. *(completed)*
- [x] Append under `flock`: `( flock -x 200; printf '%s\n' "$line" >> "$ISSUES_FILE" ) 200> "$LOCK_FILE"`
      with `ISSUES_FILE="$TASK_DIR/issues.jsonl"` and `LOCK_FILE="$TASK_DIR/.issues.lock"`,
      creating `issues.jsonl` lazily on first use. *(completed)*
- [x] Emit the appended entry's id on stdout and diagnostics on stderr, matching
      `events-append.sh`'s output contract. *(completed)*
- [x] Run `shellcheck` on the new script and resolve every finding. *(completed)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase adds exactly one new file and modifies none. Confirm with
`git status --short` before committing; any modified existing file means scope leaked out of this
phase into Phase 4's or Phase 6's territory.

**Files to modify**:
- `scripts/issue-record.sh` - new file; the single writer

**Verification**:
- `shellcheck scripts/issue-record.sh` is clean.
- A manual smoke call against a throwaway directory appends one line, creates the file and the
  lock file, and the line parses with `jq -e`.
- A call with an unrecognized `--class` value exits 0, warns on stderr, and still appends.
- A call with an empty `--what-happened` exits nonzero and appends nothing.

---

### Phase 3: Test Suite for the Writer [COMPLETED]

**Goal**: `scripts/tests/test-issue-record.sh` covers schema validation, append atomicity, the
unknown-class warning path, and the non-fatal failure path.

**Tasks**:
- [x] Read `scripts/tests/test-orchestrate-record-decision.sh` first — it is the closest sibling
      test and the one to model on. *(completed)*
- [x] Class B strict mode per `context/standards/shell-strict-mode.md`: `set -uo pipefail` (no
      `-e`), with the mandated `pass()` / `fail()` / `info()` helpers and PASSED/FAILED counters
      per `context/standards/shell-script-testing.md`. *(completed)*
- [x] Schema-validation cases: missing `--what-happened` refuses; empty `--what-happened` refuses;
      `--kind` outside `issue|win` refuses; a malformed `--tags-json` refuses; each refusal leaves
      `issues.jsonl` unchanged (byte-for-byte, not merely line-count-equal). *(completed)*
- [x] Append-atomicity case: N concurrent background invocations against one task directory yield
      exactly N well-formed lines, every one parsing with `jq -e`, with no interleaved or
      truncated line. *(completed)*
- [x] Unknown-class case: an unrecognized `--class` exits 0, appends one line carrying that class
      verbatim, and emits a warning on stderr. *(completed)*
- [x] Non-fatal failure case: a call against an unwritable or nonexistent target leaves the
      caller's exit status unaffected when invoked in the documented non-fatal form, and the
      script itself still signals failure via its own exit code when invoked directly. *(completed)*
- [x] `kind: "win"` case: a win entry is accepted and appended on equal footing with an issue. *(completed)*
- [x] `--task N` resolution case: a call with only a bare task number resolves to the right task
      directory via `task-lookup-lib.sh`, and an unresolvable number refuses cleanly. *(completed)*
- [x] Use a scratch task directory under the test harness's own temp area; never write into a real
      `specs/{NNN}_{SLUG}/` directory. *(completed)*
- [x] Run `shellcheck` on the new test file and resolve every finding. *(completed)*

**Timing**: 1 hour

**Depends on**: 2

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: the four named coverage areas expand to roughly 9-11 discrete cases as
enumerated above. Confirm the final case count against the task list before closing; materially
fewer means a coverage area was collapsed rather than covered.

**Files to modify**:
- `scripts/tests/test-issue-record.sh` - new file; the test suite

**Verification**:
- `bash scripts/tests/test-issue-record.sh` exits 0 with every case PASSED and zero FAILED.
- `shellcheck scripts/tests/test-issue-record.sh` is clean.
- The concurrency case is genuinely concurrent (background jobs plus `wait`), not sequential.

---

### Phase 4: Register `.issues.lock` as an Ephemeral Runtime File [NOT STARTED]

**Goal**: `.issues.lock` is gitignored as a new member of the runtime-file ephemeral class,
mirroring `.decisions.lock` exactly, while `issues.jsonl` stays tracked as durable provenance.

**Tasks**:
- [ ] Re-read `scripts/lib/runtime-file-patterns.sh` and confirm the current class-member count
      (measured: 20 members across the parallel `RUNTIME_FILE_IDS`, `RUNTIME_FILE_PATTERNS`,
      `RUNTIME_FILE_PROBES`, and `RUNTIME_FILE_B_REGEX` arrays).
- [ ] Add an `issues-lock` member to every parallel array, keeping index alignment:
      id `issues-lock`; pattern `**/.issues.lock`; probe `specs/000_probe/.issues.lock`; and the
      matching tracked-file regex entry. Place it immediately after `decisions-lock`.
- [ ] Add the explanatory comment for the new member in the same style as the existing
      `decisions-lock` comment (which states it mirrors `.errors.lock` exactly and is never placed
      inside a directory class) — state that `.issues.lock` is the lock for
      `scripts/issue-record.sh` and that `issues.jsonl` is deliberately NOT ignored.
- [ ] Update the embedded expected-block copy inside `runtime-file-patterns.sh` itself (the
      literal block near the end of the file) to include the new pattern line.
- [ ] Update the member-count assertion in `scripts/tests/test-runtime-file-tracking.sh` (measured:
      line ~197, asserting exactly 20 members) to the new count, and extend its enumeration
      comment to name the new member.
- [ ] Update the verbatim block copy in `scripts/tests/test-orchestrate-unwind-dispatch.sh`
      (measured: ~line 90) to include the new pattern line.
- [ ] Update `context/standards/orchestrator-runtime-files.md`: add a row to the ephemeral-class
      table (measured: the `.decisions.lock` row is ~line 56) describing `.issues.lock`'s writer,
      holder, release, and class, and update the embedded block copy (measured: ~line 417).
- [ ] Add a statement to the same standards file that `specs/{NNN}_{SLUG}/issues.jsonl` is
      **durable**, not ephemeral — the same class as `.orchestrator-handoff.json` and
      `.return-meta.json`, which the managed block's own header already calls out as deliberately
      excluded.
- [ ] Regenerate the managed block in `specs/.gitignore` via the sanctioned generator
      (`scripts/init-specs.sh`, which generates the block from the lib) rather than hand-editing
      it — the block's own header says not to hand-edit the pattern list.
- [ ] Run `shellcheck` on every modified shell file.

**Timing**: 1 hour

**Depends on**: 2

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: the `.decisions.lock` pattern appears in exactly 4 files that need a
corresponding `.issues.lock` addition (`scripts/lib/runtime-file-patterns.sh`,
`scripts/tests/test-runtime-file-tracking.sh`, `scripts/tests/test-orchestrate-unwind-dispatch.sh`,
`context/standards/orchestrator-runtime-files.md`), plus the generated `specs/.gitignore`. Confirm
with `grep -rln "decisions.lock"` across the source store before editing; a fifth hit means
another block copy exists that this plan did not find.

**Files to modify**:
- `scripts/lib/runtime-file-patterns.sh` - add the `issues-lock` member to all four parallel
  arrays plus its comment and the embedded block copy
- `scripts/tests/test-runtime-file-tracking.sh` - update the member-count assertion and its
  enumeration comment
- `scripts/tests/test-orchestrate-unwind-dispatch.sh` - update the embedded block copy
- `context/standards/orchestrator-runtime-files.md` - add the ephemeral-class table row, update the
  embedded block copy, and state `issues.jsonl`'s durable classification
- `specs/.gitignore` - regenerated managed block (repo root, not the source store; generated
  output, never hand-edited)

**Verification**:
- `bash scripts/tests/test-runtime-file-tracking.sh` exits 0 with every case PASSED.
- `bash scripts/tests/test-orchestrate-unwind-dispatch.sh` exits 0.
- `git check-ignore -q specs/000_probe/.issues.lock` succeeds.
- `git check-ignore -q specs/000_probe/issues.jsonl` **fails** (the log itself must stay
  trackable).
- `shellcheck` is clean on all modified shell files.

---

### Phase 5: Thread the Instruction to Every Dispatched Agent [NOT STARTED]

**Goal**: A `## Issue Log` section reaches every dispatched agent through the single per-dispatch
prompt emitter, reinforced at the two shared-contract moments where an agent is most likely to
reconstruct-at-the-end instead of record-as-it-happens.

**Tasks**:
- [ ] **Re-measure first.** Run `grep -n '^  echo "## ' scripts/orchestrate-build-dispatch.sh` and
      confirm the `## Handoff` emitter's current location (measured this session: line 499, with
      the section body at 499-503, inside the single `{ ... } > "$dispatch_file"` block spanning
      roughly 420-578 of a 581-line file). Do not edit against this plan's numbers; edit against
      the re-measured ones.
- [ ] Insert a new unconditional `## Issue Log` section emitter immediately after the `## Handoff`
      section's trailing blank line and before the conditional `## Territory` block. It is
      unconditional across every phase, exactly like `## Handoff` and `## Wait Discipline`, so it
      needs no phase branching.
- [ ] The section must emit: the resolved `--task-dir "${TASK_DIR_ABS}"` the agent should pass;
      the exact non-fatal call form; the `kind: issue|win` distinction with a one-line statement
      that wins are recorded on equal footing; the record-as-it-arises instruction; and a pointer
      to `context/formats/issue-log.md` for the full schema and the 15-class enum.
- [ ] Do **not** inline the full schema or the enum in the dispatch file. Every other section in
      this emitter is a pointer, not a copy (the Territory section's pointer to
      `context/contracts/territory.md` is the precedent to follow).
- [ ] Add the recording instruction to `context/contracts/phase-closure.md` — the correct
      both-modes injection site, loaded via an explicit `@`-bullet in
      `agents/general-implementation-agent.md`'s Context References. Place it as its own short
      section or adjacent to "Marker/commit synchrony is bidirectional" (measured: ~line 148), and
      word it as a during-phase obligation: call the writer as soon as a deviation, blocker,
      workaround, gate collision, or unusually smooth result is observed, rather than
      reconstructing it at the final `.return-meta.json` or handoff write.
- [ ] Add the reinforcing instruction to `context/contracts/wrap-up.md`, stating plainly in the
      text that this contract is `--hard`-only (its own header says so) so a reader does not
      mistake it for the universal site. Place it at the `blockers[]` write moment (measured: the
      field-semantics block around lines 66-127) and word it as the MIRROR obligation: a
      `blockers[]` entry about to be written should ALSO be recorded via the writer, because the
      handoff is overwritten on the next dispatch and the log is not.
- [ ] State explicitly in both contract additions that a recording failure is non-fatal and must
      never fail a dispatch or block a phase closure.
- [ ] Run `shellcheck` on `scripts/orchestrate-build-dispatch.sh`.

**Timing**: 1.5 hours

**Depends on**: 1, 2

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: the insertion point is immediately after the `## Handoff` emitter at
approximately line 503 of a 581-line file. Both numbers are hypotheses: two prior tasks already
shifted this file once, and a third task that also edits it is not yet landed. Confirm by the
`grep -n` re-measure in the first task above, never by trusting these numbers.

**Files to modify**:
- `scripts/orchestrate-build-dispatch.sh` - new unconditional `## Issue Log` section emitter,
  inserted after `## Handoff`
- `context/contracts/phase-closure.md` - during-phase recording obligation (both modes)
- `context/contracts/wrap-up.md` - hard-mode reinforcement at the `blockers[]` write moment

**Verification**:
- `shellcheck scripts/orchestrate-build-dispatch.sh` is clean.
- A dry-run or direct invocation of the builder for a scratch task produces a dispatch file
  containing a `## Issue Log` section, for each of `phase=research`, `phase=plan`, and
  `phase=implement` — confirming the section is genuinely unconditional.
- The emitted section's `--task-dir` value is the resolved absolute task directory, not a template
  placeholder and not a bare filename.
- The emitted section contains a pointer to `context/formats/issue-log.md` and does **not** inline
  the 15-class enum.
- Both contract files state the non-fatal rule.

---

### Phase 6: Orchestrator-Side Call Sites [NOT STARTED]

**Goal**: The five anomaly sites in `orchestrate-cycle-postflight.sh` and the two loop-guard
exhaustion sites in `orchestrate-cycle-plan.sh` each leave a structured `issues.jsonl` entry
instead of only a commit subject line.

**Tasks**:
- [ ] **Re-measure every site individually before editing.** The task description's single
      "~1048-1125" range is wrong: the sites are not contiguous. Measured this session in
      `orchestrate-cycle-postflight.sh` (1646 lines): the `RECOVERY_DECLINED` arm ~797-860 (its
      existing `system-defect-record.sh` call at ~829); the `implemented)` gate-refused arm's
      existing defect call at ~1115; the `failed|blocked)` arm ~1123-1125; the `OFF_SCHEMA_STATUS`
      catch-all ~1181-1191; and the `verdict="defer"` resolution sub-paths ~1303-1317. In
      `orchestrate-cycle-plan.sh` (2606 lines): `MAX_INFRA_FAILURES` at ~1569 and `MAX_CYCLES` at
      ~1585. Re-grep each anchor string rather than seeking by line number.
- [ ] `RECOVERY_DECLINED` arm: add an adjacent `issue-record.sh` call in the same arm, immediately
      beside the existing `system-defect-record.sh` call — both logs get an entry for the same
      event, each in its own vocabulary. This is the intended overlap, not duplication.
- [ ] `OFF_SCHEMA_STATUS` catch-all: same treatment, same-site adjacency.
- [ ] `partial)` blocker-gated arm: record `kind=issue`, `resolution=open`, with the blocker detail
      — the "some phases completed, one is externally blocked" case the wrap-up contract documents.
- [ ] `failed|blocked)` arm: record `kind=issue`. This is the clearest case where today's only
      durable trace is the commit subject line, so it is the one the acceptance bar names directly.
- [ ] `verdict="defer"` resolution: record **only** the deploy-pending-refusal sub-path, which is a
      genuine anomaly (the status write itself did not land). Leave the ordinary `partial)` and
      `infra_exempt_cycle` defers unrecorded — they are healthy in-flight continuations, and
      recording them would flood the log with non-anomalous routine volume. State this exclusion
      in a code comment so a later reader does not "complete" the coverage by adding them.
- [ ] `orchestrate-cycle-plan.sh` loop-guard sites: add a call at each of the `MAX_INFRA_FAILURES`
      and `MAX_CYCLES` exhaustion branches. These hold only the bare task number `$t` and no task
      directory, so they must use `--task N` resolution — this is the call site that makes that
      argument form necessary rather than optional.
- [ ] Every call uses `--task-dir "$TASK_DIR"` where a task directory is already in scope
      (`orchestrate-cycle-postflight.sh` sets `TASK_DIR` at ~lines 316-317) and `--task "$t"`
      only where it is not.
- [ ] Every call uses the non-fatal form and is co-located in the same `if`/case arm as the sibling
      write it mirrors — never hoisted into a separate pass or a shared helper. The two writes must
      be visibly paired in any future diff.
- [ ] Respect each site's existing dry-run guard: where a site already prints a
      `[dry-run] would record ...` line instead of writing, the new call must sit inside the same
      guard and gain the same dry-run echo.
- [ ] Run `shellcheck` on both modified scripts.

**Timing**: 1.5 hours

**Depends on**: 2

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: exactly 5 sites in `orchestrate-cycle-postflight.sh` and 2 in
`orchestrate-cycle-plan.sh`, at the approximate lines enumerated above. Every number is a
hypothesis. Confirm by grepping the anchor strings (`RECOVERY_DECLINED`, `OFF_SCHEMA_STATUS`,
`failed|blocked)`, `verdict="defer"`, `MAX_INFRA_FAILURES`, `MAX_CYCLES`) and counting arms before
editing; a different count means the file moved under this plan and the re-measure is the
authority.

**Files to modify**:
- `scripts/orchestrate-cycle-postflight.sh` - five adjacent `issue-record.sh` calls at the
  recovery-declined, gate-refused, partial-with-blockers, failed-or-blocked, and
  deploy-pending-refusal-defer sites
- `scripts/orchestrate-cycle-plan.sh` - two calls at the `MAX_INFRA_FAILURES` and `MAX_CYCLES`
  exhaustion branches, using `--task N` resolution

**Verification**:
- `shellcheck` is clean on both scripts.
- Each new call is syntactically inside the same `if`/case arm as the sibling write it mirrors,
  confirmed by reading the diff rather than by grep count alone.
- A simulated blocked dispatch against a scratch task leaves one well-formed `issues.jsonl` line,
  and that line survives a subsequent overwrite of `.return-meta.json` in the same task directory —
  the acceptance criterion this phase owns.
- Dry-run invocation of the postflight writes nothing to `issues.jsonl` and prints the dry-run
  notice instead.
- No call can fail its caller: each is in the documented non-fatal form.

---

### Phase 7: Record the `errors[]` Verdict and Retire `reflection` in Core [NOT STARTED]

**Goal**: `return-metadata-file.md` states the `errors[]` relation verdict, and the dead
state.json `reflection` field is removed from core end-to-end rather than left dead beside a newly
live log.

**Tasks**:
- [ ] **Inventory first.** Run `grep -rn "reflection"` across BOTH the core and memory extension
      source stores and write the hit list down. The task description names three removal sites;
      the measured footprint is larger. Treat the resulting count as the hypothesis to confirm.
- [ ] Draw and record the boundary between the two distinct `reflection` surfaces before editing:
      (a) the **state.json field**, which is dead — zero writers among the scripts that actually
      run in the live postflight path, its only writer being `scripts/orchestrator-postflight.sh`,
      which `scripts/skill-base.sh` itself already documents in-repo as having no live callers;
      and (b) the **`reflection`-typed event** in the unified event store, which the memory
      extension's `--revise` and `--meta` sub-modes query and which
      `distill-revise-submode.md` already documents as deliberately chosen over the state field.
      This phase retires (a). It does not delete (b)'s documented event type — see the last task
      below and Phase 8.
- [ ] Add the `errors[]` relation verdict to `context/formats/return-metadata-file.md`'s
      `errors[]` section (measured: ~lines 597-609): MIRROR. State that `errors[]` keeps its
      current shape, its four required fields, its per-dispatch overwritten lifetime, and its
      structural consumers unchanged, and that every call site that builds an `errors[]` entry
      should also call the writer with the same `message`/`recommendation` content — that pairing
      is what makes a recorded entry survive the next dispatch's overwrite without touching this
      field's semantics.
- [ ] Remove the `### reflection (optional)` section from `return-metadata-file.md` (measured:
      ~lines 420-452) and every remaining mention of the field in that file (measured: ~lines 72,
      445-457, 499, and the example payload at ~721), replacing each with nothing where the
      sentence survives without it, and leaving no dangling "sibling of `memory_candidates` and
      `reflection`" phrasing.
- [ ] Remove `reflection` from `KNOWN_ENTRY_FIELDS` in `scripts/validate-state.sh` (measured:
      ~line 505, inside the array literal spanning ~503-507). Note that file's own comment: this
      list is hand-synced with `context/schemas/state-schema.json` and has no drift test, so both
      must change together or the validator disagrees with the schema it enforces.
- [ ] Remove the `reflection` property and the `reflectionObject` definition from
      `context/schemas/state-schema.json` (measured: definition at ~line 253, property at
      ~401-402).
- [ ] Remove the `reflection` logic from `scripts/orchestrator-postflight.sh`: the header-comment
      mentions (~lines 31, 34, 40), the variable init and read (~204, 219), the Stage 6b
      reflection event emission (~269-277), the interpolation-avoidance comment reference (~412),
      and the Stage 7d state.json write (~428-443). Leave the rest of that script untouched — it
      is dead by lack of callers, not by this plan, and removing more than the reflection path
      widens scope.
- [ ] Remove or convert to an explicitly historical note the "Reflection Field" subsection of
      `context/reference/state-management-schema.md` (measured: ~lines 287-307) and the
      `reflection` row in its field table (measured: ~line 231). That subsection's prose
      describing a live "Skill postflight reads `reflection` ... and writes it" producer is
      aspirational, not a description of working code, and its own sparsity note already records
      zero occurrences in `specs/state.json` or `specs/archive/state.json`.
- [ ] Retire the `reflection` field-reading harvest in `skills/skill-todo/SKILL.md` (measured:
      Stage 5 harvest ~374-380, display line ~413-414, read-only augmentation ~447-460, and the
      Stage 10 cleanup note ~1018). Replace the harvest's state-field read with nothing rather
      than with an `issues.jsonl` read — surfacing the log is explicitly out of scope and belongs
      to the conclusion stage. State that boundary in a comment at the removal site so a later
      reader does not wire the log in here.
- [ ] Update `.claude/CLAUDE.md`'s generating merge source for the memory section if it carries the
      sentence about `/todo`'s harvest surfacing completion-time reflections — locate the merge
      source under the memory extension and correct it there, never in the deployed
      `.claude/CLAUDE.md`.
- [ ] Add a cross-reference in `context/formats/issue-log.md`'s relation table row for
      `reflection`, pointing at this retirement as the executed verdict rather than a pending one.
- [ ] Run `shellcheck` on both modified shell files; validate `state-schema.json` parses with
      `jq -e`.

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: the state.json `reflection` field's core footprint is 7 files
(`return-metadata-file.md`, `validate-state.sh`, `state-schema.json`,
`orchestrator-postflight.sh`, `state-management-schema.md`, `skill-todo/SKILL.md`, plus one
memory-extension merge source for the generated agent-config section). Confirm against the
`grep -rn "reflection"` inventory in the first task; a hit outside this set is either an
event-store reference (Phase 8's territory, deliberately left live) or a file this plan missed.

**Files to modify**:
- `context/formats/return-metadata-file.md` - add the `errors[]` MIRROR verdict; remove the
  `reflection` section and all remaining mentions
- `scripts/validate-state.sh` - remove `reflection` from `KNOWN_ENTRY_FIELDS`
- `context/schemas/state-schema.json` - remove the `reflection` property and `reflectionObject`
  definition
- `scripts/orchestrator-postflight.sh` - remove the reflection read, event emission, and Stage 7d
  state write
- `context/reference/state-management-schema.md` - remove the field-table row and the "Reflection
  Field" subsection
- `skills/skill-todo/SKILL.md` - remove the reflection harvest, display, augmentation, and cleanup
  references
- `context/formats/issue-log.md` - mark the `reflection` relation row's verdict as executed
- memory-extension merge source for the generated agent-config memory section - conditional;
  correct the `/todo` reflection-harvest sentence if present (exact path to be located by grep)

**Verification**:
- `grep -rn "reflection" <core source store>` returns only event-store references (the
  `events-format.md` rows and the `redeploy-checkpoint-lib.sh` unrelated use of the English word),
  with zero remaining state.json-field references.
- `bash scripts/validate-state.sh` runs clean against the live `specs/state.json`.
- `jq -e . context/schemas/state-schema.json` succeeds.
- `scripts/validate-state.sh`'s `KNOWN_ENTRY_FIELDS` and `state-schema.json`'s project-object
  properties agree field-for-field (checked by hand — the file's own comment says there is no
  drift test for this pair).
- `shellcheck` is clean on both modified shell files.
- `return-metadata-file.md`'s `errors[]` section states MIRROR explicitly.

---

### Phase 8: Memory-Extension Reflection References and the Event-Type Producer Note [NOT STARTED]

**Goal**: No dangling state.json-`reflection` reads remain in the memory extension, and the
`reflection` event type's producer status is stated honestly rather than left silently
producerless.

**Tasks**:
- [ ] Read `extensions/memory/context/project/memory/patterns/distill-revise-submode.md`'s
      "Reflection pull" section (measured: ~lines 52-59) and confirm by reading — not assuming —
      that `--revise` queries `reflection`-typed **events** via `events-query.sh` and not the
      state.json field. That file's own prose already explains why it chose the event store over
      the field; if the read contradicts this, stop and re-scope before editing.
- [ ] Remove the state.json-field read from `extensions/memory/skills/skill-learn/SKILL.md`
      (measured: ~lines 679-696 for the `jq` read and pseudo-artifact construction, ~717-718 for
      the extra option in the option list) and from `extensions/memory/commands/learn.md`
      (measured: ~line 145). Restore the unconditional, file-artifacts-only behavior those files
      already document as the absent-reflection path, so the removal collapses a branch rather
      than leaving a dead flag.
- [ ] Do **not** replace the removed `/learn --task N` reflection segment with an `issues.jsonl`
      read. Surfacing the log is out of scope; state that boundary in a comment at the removal site.
- [ ] Add a producer-status note to `context/formats/events-format.md` in the core source store for
      the `reflection` event-type row (measured: the event-type table row at ~line 112, with
      supporting prose at ~7, ~64, ~138, ~180): the type has no live producer now that the
      reflection write path is retired, `issues.jsonl` `kind: "win"` / `kind: "issue"` is the live
      home for the same signal, and the row is retained because the memory extension's documented
      query recipes reference it. Do not delete the row — deleting it would break those recipes
      with nothing to replace them.
- [ ] Leave `distill-revise-submode.md`, `distill-meta-submode.md`, and `distill-usage.md`'s
      event-store queries functionally unchanged, but add a one-line note in each where it claims
      reflection signal is available, pointing at the producer-status note above so a reader is not
      misled into expecting populated results.
- [ ] Update the memory extension's `index-entries.json` summaries only where a summary's text
      names the retired field directly and would now be inaccurate.

**Timing**: 1 hour

**Depends on**: 7

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: the memory extension holds roughly 5 files referencing `reflection`
(`commands/learn.md`, `skills/skill-learn/SKILL.md`, `patterns/distill-revise-submode.md`,
`patterns/distill-meta-submode.md`, `distill-usage.md`), of which exactly 2 read the state.json
field and the rest read the event store. Confirm by re-running Phase 7's `grep -rn "reflection"`
inventory scoped to the memory extension and classifying each hit field-vs-event before editing.

**Files to modify**:
- `extensions/memory/skills/skill-learn/SKILL.md` - remove the state.json reflection read and the
  pseudo-artifact option
- `extensions/memory/commands/learn.md` - remove the reflection-segment sentence
- `extensions/core/context/formats/events-format.md` - add the `reflection` event-type
  producer-status note
- `extensions/memory/context/project/memory/patterns/distill-revise-submode.md` - add the
  producer-status pointer
- `extensions/memory/context/project/memory/patterns/distill-meta-submode.md` - add the
  producer-status pointer
- `extensions/memory/context/project/memory/distill-usage.md` - add the producer-status pointer
- `extensions/memory/index-entries.json` - conditional; correct any summary naming the retired
  field

**Verification**:
- `grep -rn "\.reflection"` across the memory extension returns zero state.json-field reads.
- `jq -e . extensions/memory/index-entries.json` succeeds.
- `events-format.md`'s `reflection` row is present and carries the producer-status note.
- `/learn --task N`'s documented option list in `skill-learn/SKILL.md` describes exactly the
  file-artifacts-only behavior, with no residual conditional referencing a removed flag.

---

### Phase 9: Register, Deploy, and Verify Against the Acceptance Bar [NOT STARTED]

**Goal**: The new writer is catalogued, the source store is deployed, the full repository gate set
passes, and each acceptance criterion is verified by observation rather than by assertion.

**Tasks**:
- [ ] Register `scripts/issue-record.sh` in `docs/reference/utility-scripts-inventory.md`,
      following the `orchestrate-record-decision.sh` entry as the model — including its stated
      inclusion-criterion note, since the new writer has the same shape: live lifecycle call sites
      plus direct invocation by a dispatched agent from a dispatch-file instruction.
- [ ] Deploy the source store via the sanctioned deploy path (`scripts/deploy-headless.sh`) so the
      `.claude/` tree reflects the source store. Nothing in this task is complete until deployed —
      a source-store edit alone changes no live behavior.
- [ ] Run the full gate set: `bash .claude/scripts/verify-deploy.sh` (source-store path
      `scripts/verify-deploy.sh`). Resolve every finding; a hand-picked subset of validators does
      not satisfy this tier.
- [ ] Run the three touched test suites together: `test-issue-record.sh`,
      `test-runtime-file-tracking.sh`, `test-orchestrate-unwind-dispatch.sh`, plus
      `test-init-specs.sh` (it also asserts on the gitignore managed block).
- [ ] Run `shellcheck` across every shell file this task created or modified, in one sweep.
- [ ] **Acceptance verification, one check per criterion, each by observation**: (a) an agent
      dispatched through the builder receives the `## Issue Log` instruction — inspect a generated
      dispatch file for each of the three phases; (b) a recorded entry survives a subsequent
      dispatch's overwrite of `.return-meta.json` — record an entry in a scratch task directory,
      overwrite `.return-meta.json`, confirm the entry is still there; (c) a blocked dispatch
      leaves a structured entry rather than only a commit subject — exercise the
      `failed|blocked)` arm; (d) wins are recordable — append a `kind=win` entry; (e) the relation
      verdicts are written down — confirm 6 rows in the format doc; (f) `reflection` is gone, not
      dead — `grep` confirms zero state.json-field references across both extensions; (g)
      shellcheck clean per `context/standards/shell-strict-mode.md`.
- [ ] Record the outcome of each acceptance check, including any that could not be verified and
      why, rather than reporting a blanket pass.

**Timing**: 1 hour

**Depends on**: 3, 4, 5, 6, 8

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: the acceptance bar decomposes into exactly the 7 lettered checks above.
Confirm against the task description's ACCEPTANCE section before closing; a missed criterion means
the phase closed early.

**Files to modify**:
- `docs/reference/utility-scripts-inventory.md` - register `issue-record.sh`
- `.claude/**` - regenerated deploy output only; never hand-authored

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` exits 0 with no findings.
- All four named test suites exit 0.
- `shellcheck` is clean across every file this task touched.
- All 7 lettered acceptance checks above are observed to pass, each recorded individually.
- `git status --short` shows no unintended modifications outside this task's declared file set.

---

## Testing & Validation

- [ ] `bash scripts/tests/test-issue-record.sh` — every case PASSED, zero FAILED.
- [ ] `bash scripts/tests/test-runtime-file-tracking.sh` — member-count assertion updated and
      passing.
- [ ] `bash scripts/tests/test-orchestrate-unwind-dispatch.sh` — embedded block copy updated and
      passing.
- [ ] `bash scripts/tests/test-init-specs.sh` — gitignore managed-block assertions passing.
- [ ] `bash scripts/validate-state.sh` — clean against the live `specs/state.json` after the
      `KNOWN_ENTRY_FIELDS` change.
- [ ] `bash .claude/scripts/verify-deploy.sh` — the full repository gate set, clean.
- [ ] `shellcheck` clean on `issue-record.sh`, `test-issue-record.sh`,
      `orchestrate-build-dispatch.sh`, `orchestrate-cycle-postflight.sh`,
      `orchestrate-cycle-plan.sh`, `validate-state.sh`, `orchestrator-postflight.sh`,
      `runtime-file-patterns.sh`, and both modified test files.
- [ ] `jq -e .` parses `state-schema.json` and both touched `index-entries.json` files.
- [ ] `git check-ignore` confirms `.issues.lock` ignored and `issues.jsonl` not ignored.
- [ ] A generated dispatch file contains `## Issue Log` for `phase=research`, `phase=plan`, and
      `phase=implement`.
- [ ] An entry recorded in a scratch task directory survives an overwrite of that directory's
      `.return-meta.json`.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/issue-record.sh` — the single writer (new)
- `agent-system/extensions/core/scripts/tests/test-issue-record.sh` — the test suite (new)
- `agent-system/extensions/core/context/formats/issue-log.md` — the format doc: entry schema,
  15-class enum with glosses, the six recorded relation verdicts, when to record (new)
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` — new unconditional
  `## Issue Log` section
- `agent-system/extensions/core/context/contracts/phase-closure.md`,
  `.../context/contracts/wrap-up.md` — recording instructions
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh`,
  `.../scripts/orchestrate-cycle-plan.sh` — seven orchestrator-side call sites
- `agent-system/extensions/core/context/formats/return-metadata-file.md` — `errors[]` MIRROR
  verdict recorded; `reflection` section removed
- `reflection` retirement across core (`validate-state.sh`, `state-schema.json`,
  `orchestrator-postflight.sh`, `state-management-schema.md`, `skill-todo/SKILL.md`) and the
  memory extension (`skill-learn/SKILL.md`, `commands/learn.md`)
- `agent-system/extensions/core/scripts/lib/runtime-file-patterns.sh` plus its three block-copy
  consumers and the regenerated `specs/.gitignore` managed block — `.issues.lock` ephemeral
  registration
- `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md` — writer registration
- Regenerated `.claude/` deploy tree (output, never hand-authored)
- Per-task `specs/{NNN}_{SLUG}/issues.jsonl` files, created lazily at first record

## Rollback/Contingency

Every phase commits per green sub-step, so the unit of rollback is a single phase's commits, which
can be reverted with `git revert` without touching any other phase — no working-tree-discarding
operation is needed for the ordinary case.

Three contingencies are worth naming:

1. **Phase 7/8 (`reflection` retirement) turns out larger or riskier than its Scope Hypothesis.**
   It is the only phase group whose footprint spans two extensions and whose consumers are
   documentation rather than code. It is also fully separable: Phases 1-6 and 9 deliver the entire
   acceptance bar except the "`reflection` is live or gone, not dead" criterion. If the inventory
   in Phase 7's first task reveals a materially larger footprint than the 7-file hypothesis,
   close Phases 7 and 8 as `[PARTIAL]` with the inventory recorded, and record the overrun as an
   `issues.jsonl` entry — the log this task builds is the right place for it — rather than
   expanding the phase past one agent run.
2. **A deployed `.claude/` tree is wrong after Phase 9's deploy.** Re-run the deploy from the
   source store; `.claude/` is disposable and regenerable by construction, so no revert of it is
   ever needed or meaningful.
3. **An uncommitted working tree must genuinely be discarded.** Follow
   `context/contracts/recovery.md`'s rollback rung for the exact snapshot-then-rollback invocation
   shape, including its out-of-scope override flag for a deliberate whole-tree case. Do not emit a
   bare reverting snapshot as a routine precaution; for an ordinary defensive checkpoint before
   risky work, use the durable non-reverting checkpoint form instead.
