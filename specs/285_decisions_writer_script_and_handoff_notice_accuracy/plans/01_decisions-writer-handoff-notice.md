# Implementation Plan: Task #285

- **Task**: 285 - Decisions writer script and handoff notice accuracy
- **Status**: [IMPLEMENTING]
- **Effort**: 8 hours
- **Dependencies**: None (task 334 is a concurrent sibling with no file overlap)
- **Research Inputs**: `specs/285_decisions_writer_script_and_handoff_notice_accuracy/reports/01_decisions-writer-handoff-notice.md`
- **Artifacts**: plans/01_decisions-writer-handoff-notice.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, shell-strict-mode.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Two lead-facing contract-surface defects in the `/orchestrate` loop are closed independently.
Defect 1 replaces hand-authored `.decisions.json` JSON with a single-writer script
(`orchestrate-record-decision.sh`), modelled on `errors-append.sh`'s flock/atomic-`mv` mechanics
and `system-defect-record.sh`'s surrounding shell, then repoints `skill-orchestrate/SKILL.md`
Move 4 at the script so the lead never needs the schema. Defect 2 corrects a postflight
recovery notice whose parenthetical is false for the plan and implement phases, splitting it by
severity so the one genuinely expected no-handoff path (research) reads as informational while an
unexpected absence keeps the `RECOVERY:` label.

Every edit target is under `agent-system/extensions/core/**` (the source store resolved from
`.claude-extensions.json`'s `source_dir`), never `.claude/**`.

### Research Integration

The report settles four things this plan builds on directly:

1. `.decisions.json` is a **bare top-level JSON array** (`handoff-schema.md:962-1001`), four
   required fields per entry (`question`, `answer`, `cycle` integer, `timestamp` ISO 8601 UTC) —
   *not* an object wrapper like `errors.json`'s `{"errors": [...]}`. The merge jq is
   `. += [$entry]` on the document root and the lazy-create default is `[]`.
2. The write-mechanics precedent is `errors-append.sh:262-291` (flock held across read -> merge ->
   validate-merged-document -> atomic `mv`, lazy file creation, `jq -c -n` record construction);
   the surrounding-shell precedent is `system-defect-record.sh` (manual `while`-loop argument
   parsing, fail-loud validation before any work, `source lib/common.sh` then
   `. deploy-root-guard.sh || exit 1`, non-fatal-call convention documented in the header).
   `events-append.sh` is explicitly *not* the mechanics precedent (JSONL line-append, no
   read-modify-write).
3. Task-number-to-directory resolution sources `scripts/lib/task-lookup-lib.sh`
   (`task_lookup_entry`, `task_lookup_dir`) rather than shelling out to `task-lock.sh`.
4. The notice's phase claim is **false for plan and implement**: every research agent carries an
   identical "research agents never write one" prohibition (any mode), while every
   implementation agent and the shared `planner-agent` carry an identical MUST-write whenever
   `orchestrator_mode: true` — an `orchestrator_mode` gate, not a hard/base-mode gate.

This plan adds four findings from its own grounding pass that the report did not cover, each of
which changes the work:

- **The notice is duplicated.** The identical message also sits at
  `scripts/orchestrate-stage5-gates.sh:171`. That script has **zero call sites**
  (`docs/architecture/orchestrate-cycle-postflight.md`'s "What Remains Orphaned" section) and its
  positional interface carries no `phase` argument, so it gets a reduced, interface-preserving
  fix (Phase 6), not the full phase-conditional split.
- **The falsehood is also documented, not just emitted.** `docs/architecture/handoff-schema.md`
  asserts it as a deliberate architecture decision at four sites (lines ~446, ~476, ~521, ~609 —
  "One channel per mode, by decision ... base-mode research/plan/implement write
  `.return-meta.json` and only that"); `context/patterns/infra-failure-discrimination.md:26`
  restates it; and `context/schemas/orchestrator-handoff-schema.json`'s own top-level
  `description` encodes it as binding decision (1), "this artifact is hard-mode-implement-only".
  Correcting the emitted message while leaving these in place would make the fixed message look
  like the error. Phase 6 corrects the factual claim at each site, bounded (see its Non-Goal note).
- **The predicate holds far more widely than the report's seven files.** 68 agent files across
  all extensions mention `.orchestrator-handoff.json`. A mechanical sweep confirms the predicate
  universally: every `*research*` agent carries "never write one" with zero exceptions, and every
  `*implement*`/planner agent carries the `orchestrator_mode: true` MUST-write except
  `cslib-implementation-hard-agent.md`, which writes inline unconditionally (hard-mode-only, so
  it still writes). Phase 5 re-runs this sweep as its own verification rather than trusting the
  report.
- **A new lock file needs ignore coverage.** `.events.lock` and `.errors.lock` are both declared
  members of `scripts/lib/runtime-file-patterns.sh`'s ephemeral-pattern set. A new
  `.decisions.lock` is not covered by any existing pattern, so it would surface in the loop's own
  `git status --porcelain -- specs/` residue check and is committable by accident. Phase 1 adds
  it as a declared member, matching `.errors.lock` exactly.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch and no roadmap consultation applies.

## Goals & Non-Goals

**Goals**:

- A lead can record a user decision with **one documented script call** and no knowledge of the
  `.decisions.json` JSON shape.
- A malformed `.decisions.json` is unreachable through the sanctioned path: the writer validates
  the merged document before the atomic `mv` and leaves any pre-existing valid array byte-identical
  on any failure.
- `orchestrate-record-decision.sh` is registered in `manifest.json`'s `provides.scripts` and in
  `docs/reference/utility-scripts-inventory.md`.
- `skill-orchestrate/SKILL.md` Move 4 cites the script instead of the prose schema, without
  pushing the file back over its context-budget ceiling.
- The postflight no-handoff notice's phase claim is verified against the writers and matches them,
  and the expected (research) and unexpected (plan/implement) cases are distinguishable at a glance.
- Every touched shell script is `shellcheck` clean per `context/standards/shell-strict-mode.md`.

**Non-Goals**:

- **Not fixing the reader.** The `jq 'length'` type-safety gate at
  `orchestrate-build-dispatch.sh:389-392` is recorded elsewhere as a jq type-safety instance. This
  task owns the **authoring** surface only. Both should land; neither blocks the other.
- **Not redesigning `handoff-schema.md`'s outcome-channel architecture.** Phase 6 corrects the
  per-phase writer *predicate* where it is stated as fact and points at the agent contracts as the
  source of truth. It does **not** re-derive whether one-channel-per-mode is still the right
  design, nor restructure the "Outcome Channels" narrative beyond what accuracy requires.
- **Not reviving `orchestrate-stage5-gates.sh`.** Its notice is de-falsified in place without
  adding a `phase` argument to its positional interface; deleting the orphan is out of scope.
- **Not fixing the "hard-mode-implement-only" phrasing** inside the five research agents' own
  "never write one" subsections (a second, smaller inaccuracy the dispatch does not name).
- **Not deploying.** Regeneration of `.claude/` is manual-only
  (`context/patterns/regeneration-is-manual-only.md`). The source-store edits are the deliverable;
  the `specs/.gitignore` managed-block refresh (Phase 1) only takes effect after a later redeploy
  runs `init-specs.sh`, and that is noted, not performed.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Writer over-copies `errors-append.sh` and produces `{"decisions": [...]}` — the exact shape the observed failure wrote | H | M | Phase 2 validates `type == "array"` on the document **root** (never `.decisions \| type`); Phase 3 asserts the on-disk top-level type explicitly, and asserts the reader at `orchestrate-build-dispatch.sh` renders the written file |
| `handoff-schema.md` documents base-mode plan/implement as non-writers "by decision", contradicting the agent contracts and the live evidence (seq 4 and seq 5 both wrote handoffs) | H | H (already true) | Phase 5 establishes truth from the writers and the live evidence, not the docs; Phase 6 corrects the documented claim and cites the agent contracts as the authority. The broader design question is logged as an explicit Non-Goal, not silently resolved |
| SKILL.md Move 4 edit pushes `skill-orchestrate/SKILL.md` back over its context-budget ceiling (a ceiling it was only just brought under) | M | M | Phase 4 requires the replacement to be no longer than the text it replaces, and runs the context-budget gate before closing |
| `.decisions.lock` placed inside the task's existing ignored `.lock/` directory would break `rmdir`-based task-lock release and permanently lock the task | H | L (avoided by design) | Phase 1 declares a dedicated `**/.decisions.lock` file pattern; reusing `.lock/` is explicitly rejected in that phase's notes |
| Phase 1 touches a 6-parallel-array shared lib; a missed array leaves the arrays length-mismatched | M | M | Phase 1 verification runs `test-runtime-file-tracking.sh` and `test-init-specs.sh`, both of which exercise the arrays, and re-greps the three verbatim-block carriers |
| Concurrent sibling task 334 edits `agent-system/extensions/books/**` on the same cycle and shared tree | L | M | No file overlap with `extensions/core/**`. Re-read every file immediately before editing; stage explicit file lists only, never a directory or glob `git add`; never run `git-snapshot.sh` in its reverting default mode |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 5 | -- |
| 2 | 2, 6 | 1 (for 2), 5 (for 6) |
| 3 | 3, 4 | 2 |
| 4 | 7 | 1, 2, 3, 4, 5, 6 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Declare `.decisions.lock` as a Runtime Ephemeral Pattern [COMPLETED]

**Goal**: `specs/{NNN}_{slug}/.decisions.lock` is a declared member of the runtime ephemeral
pattern set, so the writer's lock file is ignore-covered the same way `.errors.lock` is and never
appears as `specs/` residue.

**Tasks**:
- [x] Re-read `scripts/lib/runtime-file-patterns.sh` and locate every parallel array that carries
      the existing `errors-lock` member (expected: `RUNTIME_FILE_KEYS`-style name list,
      `RUNTIME_FILE_PATTERNS`, `RUNTIME_FILE_PROBES`, `RUNTIME_FILE_B_REGEX`, `RUNTIME_FILE_IS_DIR`,
      `RUNTIME_FILE_DIR_BASENAME`). *(completed)*
- [x] Add one new member, `decisions-lock`, at the index immediately after `errors-lock`, with:
      pattern `**/.decisions.lock`; probe `specs/000_probe/.decisions.lock`; Check B regex
      `\.decisions\.lock$`; `IS_DIR` `"0"`; `DIR_BASENAME` `""`. *(completed: added across all six
      parallel arrays, verified length 20 after sourcing)*
- [x] Update the `runtime_ignore_block` header comment's pattern count (currently "all 19
      patterns") to match the new member count. *(completed: "19 total"->"20 total",
      "19th member"->"20th member" comment added, "19-member"->"20-member")*
- [x] Update the three verbatim-block carriers found by
      `grep -rln '^\*\*/\.errors\.lock$' --include=*.md --include=*.sh agent-system/`:
      `context/standards/orchestrator-runtime-files.md` (its fenced block **and** its per-file
      table, adding a `specs/{NNN}_{slug}/.decisions.lock` row mirroring the `specs/.errors.lock`
      row), and `scripts/tests/test-orchestrate-unwind-dispatch.sh`'s fixture block. *(completed;
      also updated a 4th site found during verification: test-runtime-file-tracking.sh Case 5's
      hardcoded "19 class members" assertion, which would otherwise regress after this change)*
- [x] Do **not** hand-edit the live `specs/.gitignore` managed block — it is generated. Note in the
      phase's commit message that the refresh happens on the next deploy's `init-specs.sh` run.
      *(completed: not touched; refresh deferred to next deploy's init-specs.sh run)*

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: interface

**Scope Hypothesis**: the member count is 19 -> 20 across exactly 6 parallel arrays, and exactly
3 files carry the block verbatim. Both are grep-derived hypotheses; confirm by re-running the
carrier grep above and by counting array members after the edit, rather than trusting these
numbers.

**Files to modify**:
- `agent-system/extensions/core/scripts/lib/runtime-file-patterns.sh` - add the `decisions-lock`
  member across every parallel array; update the pattern-count comment
- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` - add the pattern
  to the fenced block and a table row for the new lock file
- `agent-system/extensions/core/scripts/tests/test-orchestrate-unwind-dispatch.sh` - add the
  pattern to the fixture gitignore block

**Verification**:
- `bash -n` clean on both touched shell files; `shellcheck` clean on
  `scripts/lib/runtime-file-patterns.sh`.
- All six arrays have equal length (assert mechanically, e.g. by echoing `${#ARRAY[@]}` for each
  after sourcing the lib).
- `bash scripts/tests/test-runtime-file-tracking.sh` passes.
- `bash scripts/tests/test-init-specs.sh` passes.
- `bash scripts/tests/test-orchestrate-unwind-dispatch.sh` passes.

**Why not reuse `.lock/`**: the task's existing `.lock/` directory is already ignored via
`**/.lock/`, but it is a `mkdir`-exclusivity mutex released by `rmdir`. A stray file inside it
would make the `rmdir` fail and leave the task permanently locked. A dedicated file pattern is the
correct and precedent-matching choice.

---

### Phase 2: Add `orchestrate-record-decision.sh` [COMPLETED]

**Goal**: one sanctioned writer appends exactly one schema-valid entry to
`specs/{NNN}_{slug}/.decisions.json`, creating the file when absent, additively, under a lock, with
the pre-existing file left byte-identical on any failure.

**Tasks**:
- [x] Write `scripts/orchestrate-record-decision.sh` with CLI
      `--task N --session SID --cycle C --question TEXT --answer TEXT` (plus `-h|--help`).
      *(completed)*
- [x] Header comment in the `system-defect-record.sh` house style: purpose, usage block, per-argument
      documentation, the "NOT RUNNABLE FROM THE SOURCE STORE" note, the exit-code table, and the
      non-fatal-call convention for call sites. *(completed)*
- [x] `set -euo pipefail` (Class A per `shell-strict-mode.md`'s default-for-new-scripts rule).
      *(completed)*
- [x] Manual `while`-loop argument parsing; unknown argument is a loud failure, never a silent skip.
      *(completed)*
- [x] Validate before any work: all five arguments non-empty; `--task` matches `^[0-9]+$`;
      `--cycle` matches `^[0-9]+$`; `--session` matches the `sess_` convention loosely enough not
      to reject a valid id. *(completed)*
- [x] `SCRIPT_DIR` resolution, `source "${SCRIPT_DIR}/lib/common.sh"`,
      `PROJECT_ROOT="$(common_repo_root "$SCRIPT_DIR" 2)"`, then
      `. "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1` — in that order, matching
      `system-defect-record.sh:195-198`. *(completed)*
- [x] Resolve the task directory by sourcing `scripts/lib/task-lookup-lib.sh` and calling
      `task_lookup_entry` then `task_lookup_dir`; fail loudly (nonzero, nothing written) when the
      task number resolves to no entry. *(completed)*
- [x] Build the entry with `jq -c -n` and four fields: `question` (string), `answer` (string),
      `cycle` (**number**, via `--argjson`), `timestamp` (`common_timestamp_iso`). Never string
      concatenation. *(completed)*
- [x] Append under `flock -x 200` against `${task_dir}/.decisions.lock`, holding the lock across the
      whole read -> merge -> validate -> `mv` sequence, mirroring `errors-append.sh:262-291`:
      lazy-create the data file with `[]`; refuse when the existing document fails
      `jq -e 'type == "array"'` on the **root**; merge via `jq --argjson rec ... '. += [$rec]'` into
      a `$$`-suffixed temp file sibling to the data file; validate the merged document with
      `jq -e '(type == "array") and (length >= 1)'`; `mv` only then; `rm -f` the temp and exit
      nonzero on any failure. *(completed; validated with 10-way concurrent-append smoke test, no
      loss)*
- [x] Register `orchestrate-record-decision.sh` in `manifest.json`'s `provides.scripts`, in the
      existing `orchestrate-*` alphabetical neighbourhood. *(completed)*

**Timing**: 2 hours

**Depends on**: 1

**Verification Tier**: full

**Scope Hypothesis**: ~120-150 lines, one new file plus one `manifest.json` line. If the script
exceeds ~200 lines, stop and confirm the extra surface is required by the contract rather than
accreted; the precedent scripts' validated/append core is well under that.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-record-decision.sh` - **new**: the writer
- `agent-system/extensions/core/manifest.json` - register the script in `provides.scripts`

**Verification**:
- `bash -n` and `shellcheck` both clean (no suppression directives added to pass).
- Functional smoke in a scratch sandbox (the harness Phase 3 formalizes): create
  `<scratch>/.claude/scripts/` with the script, `deploy-root-guard.sh`, `lib/common.sh`, and
  `lib/task-lookup-lib.sh` copied in so `deploy-root-guard.sh`'s `*/.claude` case matches; run the
  script twice against a scratch task; assert the resulting file satisfies
  `jq -e 'type == "array" and length == 2'` and that entry 1 is byte-unchanged by the second append.
- A missing or malformed required argument exits nonzero and writes nothing.
- The script is never invoked against the live repo's own `specs/` during this phase.

---

### Phase 3: Regression Suite for the Writer [COMPLETED]

**Goal**: the writer's two load-bearing claims are proven mechanically — concurrent invocation
neither loses nor corrupts an entry, and malformed input is rejected with the target file left
byte-identical.

**Tasks**:
- [x] Write `scripts/tests/test-orchestrate-record-decision.sh`, structurally modelled on
      `scripts/tests/test-errors-append.sh`: `set -uo pipefail` (Class B per `shell-strict-mode.md`'s
      test-suite admission), `pass()`/`fail()`/`info()` helpers, `PASSED`/`FAILED` counters,
      exit 0 all-pass / 1 any-fail / 2 environment error. *(completed)*
- [x] Reuse that suite's script-under-test resolution (deploy-tree-first, source-store fallback) and
      its `git rev-parse --show-toplevel`-first `REPO_ROOT` derivation, so the suite runs from both
      the deployed and the source-store copy. *(completed)*
- [x] Reuse its scratch-sandbox harness: `mktemp -d` project root with
      `<scratch>/.claude/scripts/` populated so `deploy-root-guard.sh` matches and `PROJECT_ROOT`
      resolves to the scratch root. Never touch the live `specs/`. *(completed; also populates a
      scratch specs/state.json + task directory, since the writer resolves tasks via
      task-lookup-lib.sh rather than a bare file path)*
- [x] Cases, at minimum: (a) first append lazily creates the file as a **bare top-level array**;
      (b) a second append is additive and leaves entry 1 byte-identical; (c) all four fields present
      with `cycle` a JSON **number** and `timestamp` ISO 8601 UTC; (d) concurrent appends
      (background invocations, then `wait`) lose nothing; (e) a pre-existing object-wrapped
      `{"decisions": [...]}` file is **refused** with the file left byte-identical — the exact
      observed failure shape; (f) a missing required argument exits nonzero and writes nothing;
      (g) a non-integer `--cycle` is refused; (h) the file the writer produces is rendered correctly
      by the reader's own jq expression from `orchestrate-build-dispatch.sh`. *(completed; added a
      9th case beyond the plan's named eight: an unresolvable task number exits nonzero and writes
      nothing)*
- [x] Register `tests/test-orchestrate-record-decision.sh` in `manifest.json`'s `provides.scripts`,
      alongside the other `tests/test-orchestrate-*.sh` entries. *(completed)*

**Timing**: 1.75 hours

**Depends on**: 2

**Verification Tier**: full

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-orchestrate-record-decision.sh` - **new**
- `agent-system/extensions/core/manifest.json` - register the test in `provides.scripts`

**Verification**:
- `bash scripts/tests/test-orchestrate-record-decision.sh` exits 0 with every case PASS and a
  nonzero case count (a suite that silently runs zero cases is a failure, not a pass).
- `shellcheck` clean.
- Deliberately break one assertion locally, confirm the suite reports FAILED and exits 1, then
  restore — proving the suite can actually fail.

---

### Phase 4: Repoint the Authoring Surface at the Script [COMPLETED]

**Goal**: the lead is instructed to call the script, never to hand-author the JSON; the schema
section survives as reader reference; the script is discoverable in the utility inventory.

**Tasks**:
- [x] In `skills/skill-orchestrate/SKILL.md`'s batched `AskUserQuestion` relay (Move 4, the sentence
      at ~line 272), replace "Append each answer to that task's
      `specs/{padded}_{project}/.decisions.json` per `handoff-schema.md`'s 'Decisions File Schema'
      section" with an instruction to call
      `bash .claude/scripts/orchestrate-record-decision.sh --task N --session SID --cycle C
      --question "..." --answer "..."` once per answered question. State plainly that the lead never
      hand-authors this file. *(completed: replaced with "Per answer, call
      `bash .claude/scripts/orchestrate-record-decision.sh` (see its usage for flags); never
      hand-author this file. Clear `pending_ask_user` for that task." — shortened to fit the
      byte-budget constraint below while pointing to the script's own usage block for the full
      flag list rather than restating it)*
- [x] Keep the replacement **no longer than the text it replaces** — `skill-orchestrate/SKILL.md`
      sits under a context-budget ceiling it was only recently brought back under. Prefer shorter.
      *(completed: old sentence 179 bytes, new 166 bytes; file measured 19,921 B via `wc -c`,
      79 B under the 20,000 B ceiling in context/config/orchestrator-context-budget.json)*
- [x] In `docs/architecture/handoff-schema.md`'s "Decisions File Schema" section, amend the
      **Writer** paragraph only: the loop's branch move remains the writer, now mediated through
      `scripts/orchestrate-record-decision.sh` rather than hand-authored JSON. Leave the shape
      documentation, the example, and the field list unchanged — they remain the reader's reference.
      *(completed)*
- [x] Add one bullet to `docs/reference/utility-scripts-inventory.md` naming the script, its full
      CLI shape, the append-only/lazy-create/lock semantics, and a short inclusion-criterion note
      modelled on the `validate-return-meta.sh` entry (it is lifecycle-adjacent, invoked from
      SKILL.md Move 4, yet registered here per this task's explicit instruction). *(completed)*

**Timing**: 1 hour

**Depends on**: 2

**Verification Tier**: interface

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - Move 4 cites the script
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` - Writer paragraph names the
  script; schema/shape text untouched
- `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md` - one new bullet
- `agent-system/extensions/core/index-entries.json` - *(deviation: altered — discovered during
  this phase's `check-extension-docs.sh` run, not named in the plan: Phase 1's 2-line growth of
  `context/standards/orchestrator-runtime-files.md` left its registered `line_count` (539) stale
  against the actual 541. Corrected via the documented source-store bypass
  `REPO_ROOT=$(pwd) bash .../generate-context-line-counts.sh --check`, confirmed exact, then
  hand-applied the single-field value it would have written (the script itself requires a
  deployed tree it cannot reach from here))*

**Verification**:
- The replaced Move 4 text's byte length is less than or equal to the original's (measure, do not
  estimate). *(confirmed: 179 B -> 166 B)*
- `bash scripts/tests/test-verify-deploy-context-budget.sh` passes (or the equivalent
  `verify-deploy.sh` context-budget gate), confirming SKILL.md is still under its ceiling.
  *(confirmed via direct `wc -c`: 19,921 B / 20,000 B ceiling. The suite itself reports 14/15
  passed both before and after this task's edits — the one pre-existing failure, "baseline
  fixture is not clean", reproduces identically against HEAD before any edit in this task and is
  unrelated to skill-orchestrate/SKILL.md; the SKILL.md-specific case2 passes in both runs)*
- `grep -n 'decisions.json' skills/skill-orchestrate/SKILL.md` shows no remaining instruction to
  hand-author the file; the only surviving `.decisions.json` mentions are the dispatch-rendering
  reference at ~line 64 and the new script call. *(confirmed: exactly one surviving literal
  mention, at line 64; the new instruction uses "this file" rather than repeating the literal
  filename)*
- `bash .claude/scripts/check-extension-docs.sh` passes. *(the `core` extension reports FAILs,
  all of them expected deploy-drift from this task's deliberate non-deployment — see the plan's
  own Non-Goal "Not deploying" — plus two "never deployed" advisories for the two new scripts;
  no FAIL is attributable to a defect in this phase's edits. Re-verified in Phase 7's gate sweep)*
- `bash .claude/scripts/check-task-references.sh` reports no new occurrence (none of these files is
  under `specs/**`).

---

### Phase 5: Establish the Writer Predicate and Fix the Live Notice [COMPLETED]

**Goal**: `orchestrate-cycle-postflight.sh`'s no-handoff notice states a verified, phase-specific
truth, and the expected and unexpected cases are distinguishable at a glance.

**Tasks**:
- [x] **Verify first, do not restate.** Re-derive the predicate mechanically across **every**
      extension, not just the loaded ones: for every `agents/*research*.md` that mentions
      `orchestrator-handoff`, confirm the "never write one" prohibition is present; for every
      `agents/*implement*.md` plus `agents/planner-agent.md`, confirm the
      `orchestrator_mode: true` MUST-write is present. Record the counts and any exception in the
      phase's commit message. *(completed: 22 research agents swept, all 22 carry the "never
      write one, in any mode" prohibition with zero exceptions; 20 implement/planner agents
      swept, 19 carry the `orchestrator_mode: true` MUST-write, 1 exception
      (`cslib-implementation-hard-agent.md`) writes inline and unconditionally — matches the
      plan's hypothesis exactly)*
- [x] Expected result (a hypothesis to confirm, not a fact to assume): **research never writes a
      handoff, in any mode; plan and implement always write one when `orchestrator_mode: true`,
      independent of hard/base mode.** The sole structural exception is
      `cslib-implementation-hard-agent.md`, which writes inline and unconditionally — still a
      writer. If the sweep contradicts this, fix the message to match the sweep, not this plan.
      *(confirmed, not contradicted)*
- [x] At `scripts/orchestrate-cycle-postflight.sh:693`, split the single `echo` on the already-
      validated, already-in-scope `$phase` local (`research|plan|implement`, enforced at
      `:289-291`) — no new argument, no new plumbing:
      - `research`: an **informational** tag (not `RECOVERY:`), stating that the research phase
        writes no handoff by design, in any mode, and naming `.return-meta.json` as the source the
        outcome was recovered from.
      - `plan` / `implement`: keep the `RECOVERY:` label and its prominence, naming the specific
        phase and stating that the absence is unexpected because that phase's writer is
        contractually required to write one on every `orchestrator_mode: true` dispatch.
      *(completed: `if [ "$phase" = "research" ]` branch, verified `$phase` in scope at this
      point by re-reading :289-291 before relying on it)*
- [x] Keep the existing recovery sentence (`status=${dispatch_status}`; "recovering the dispatch
      outcome from it") verbatim in both branches. Only the lead-in label and claim change.
      *(completed)*
- [x] Add a one-line code comment beside the branch pointing at the agent contract sections
      (`.orchestrator-handoff.json — research agents never write one` /
      `.orchestrator-handoff.json (orchestrator-mode dispatches)`) as the source of truth, so a
      future drift has one place to re-check instead of 68 files to re-derive from. *(completed)*
- [x] Choose an informational tag already in this script's vocabulary where one fits rather than
      inventing a new one; if none fits, use a plainly non-`RECOVERY` prefix and keep it consistent
      with the file's surrounding notice style. *(completed: none of the existing tags
      (ADVISORY/ERROR/EVIDENCE/WARN/WARNING) fit without semantic collision — ADVISORY is already
      claimed for the unrelated file_scope-excursion detection-only finding — so a new, plainly
      non-RECOVERY `NOTE:` tag was introduced, matching the file's `${notice_prefix} TAG:` shape)*

**Timing**: 1.25 hours

**Depends on**: none

**Verification Tier**: full

**Scope Hypothesis**: one `echo` becomes one `case`/`if` over `$phase` emitting two messages, in
one file, with no interface change. Confirm `$phase` is genuinely in scope at the edited line
before relying on it (it is set and validated well above, but re-read rather than assume).

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` - phase-conditional,
  severity-split notice at the `recovered=true` branch (~line 693), plus the source-of-truth comment

**Verification**:
- `bash -n` and `shellcheck` clean.
- `bash scripts/tests/test-orchestrate-cycle-postflight.sh` passes (2452 lines; no case currently
  asserts the message text, so a regression here means a real behavioral change, not a fixture drift).
- Exercise both branches: a research-phase recovery emits no `RECOVERY:` token; a plan-phase and an
  implement-phase recovery each emit `RECOVERY:` and name their own phase.
- No message generalizes across all three phases any more:
  `grep -c 'research/plan/implement never write' scripts/orchestrate-cycle-postflight.sh` is 0.

---

### Phase 6: De-falsify the Orphaned Copy and the Documented Claim [NOT STARTED]

**Goal**: no remaining surface asserts that base-mode plan or implement never writes a handoff.

**Tasks**:
- [ ] Re-grep the falsehood's full footprint before editing:
      `grep -rn 'never write one\|research/plan/implement' --include=*.sh --include=*.md
      agent-system/extensions/core/` and work from what that returns, not from this list.
- [ ] `scripts/orchestrate-stage5-gates.sh:171` (orphaned, **zero call sites**, no `phase` in its
      positional interface): remove the false parenthetical and keep the message truthful and
      phase-agnostic — the handoff is absent and the outcome was recovered from `.return-meta.json`.
      Do **not** add a `phase` argument to a script with no caller.
- [ ] `docs/architecture/handoff-schema.md`: correct the per-phase writer predicate at each site
      where it is stated as fact — the "Handoff Writers" table row (~line 446, currently "Never
      writes a handoff, by design" for `planner-agent`/`general-implementation-agent`), the
      base-mode aside (~line 476), the "Outcome Channels" assertion (~line 521), and the "When to
      Write" paragraph (~line 609). Each correction states the verified predicate and cites the
      agent contract sections as the authority.
- [ ] `context/patterns/infra-failure-discrimination.md:26`: correct the same claim in place.
- [ ] `context/schemas/orchestrator-handoff-schema.json`: its top-level `description` states the
      same falsehood as binding decision (1) — "this artifact is hard-mode-implement-only --
      base-mode research/plan/implement return via `.return-meta.json` ... never this file".
      Correct that clause to the verified predicate. Change **only** the prose `description`
      strings; touch no `required`, `enum`, `type`, or property definition, so no consumer's
      validation behavior changes. Re-validate with `jq empty` afterwards.
- [ ] Where a corrected statement conflicts with the surrounding one-channel-per-mode design
      narrative, state the divergence explicitly and briefly (the agent contracts and the live
      evidence are the authority for what the writers do) rather than silently rewriting the
      decision record. If the correction cannot be made without restructuring that narrative, make
      the minimal factual fix and record the restructuring as an observation in the phase's commit
      message — it is an explicit Non-Goal of this task.

**Timing**: 1 hour

**Depends on**: 5

**Verification Tier**: interface

**Scope Hypothesis**: 1 shell site plus 6 documentation statements across 3 files (4 in
`handoff-schema.md`, 1 in `infra-failure-discrimination.md`, 1 in the handoff JSON schema's
`description`). Confirm by the two greps in the first task above — including
`grep -rln 'hard-mode-implement-only' context/ docs/`, which is what surfaced the schema site; if
the footprint is materially larger, report the count rather than silently expanding the phase.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-stage5-gates.sh` - drop the false parenthetical
  from the orphaned notice (no interface change)
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` - correct the per-phase writer
  predicate at each factual site
- `agent-system/extensions/core/context/patterns/infra-failure-discrimination.md` - correct the
  restated claim
- `agent-system/extensions/core/context/schemas/orchestrator-handoff-schema.json` - correct the
  `description` prose only; no structural key changes

**Verification**:
- `bash -n` and `shellcheck` clean on `orchestrate-stage5-gates.sh`.
- `grep -rn 'base-mode research/plan/implement never write' agent-system/extensions/core/` returns
  nothing, and `grep -rn 'hard-mode-implement-only' agent-system/extensions/core/` returns nothing
  (or only an occurrence whose surrounding text now states the verified predicate).
- `jq empty agent-system/extensions/core/context/schemas/orchestrator-handoff-schema.json` passes,
  and a `git diff` of that file shows changes to `description` strings only.
- Every corrected statement agrees with Phase 5's recorded sweep — read them side by side, do not
  assume.
- `bash .claude/scripts/check-extension-docs.sh` passes.
- `bash .claude/scripts/check-task-references.sh` reports no new occurrence.

---

### Phase 7: Full Gate Sweep [NOT STARTED]

**Goal**: every acceptance criterion is demonstrated by a command, not by inspection.

**Tasks**:
- [ ] `shellcheck` over every shell file this task touched or created (the writer, its suite,
      `runtime-file-patterns.sh`, `orchestrate-cycle-postflight.sh`, `orchestrate-stage5-gates.sh`,
      `test-orchestrate-unwind-dispatch.sh`) — clean, with no suppression directive added to
      achieve it.
- [ ] `bash -n` over the same set.
- [ ] Run the four affected suites: `test-orchestrate-record-decision.sh`,
      `test-orchestrate-cycle-postflight.sh`, `test-runtime-file-tracking.sh`,
      `test-init-specs.sh`, plus `test-orchestrate-unwind-dispatch.sh`.
- [ ] `bash .claude/scripts/check-extension-docs.sh` (Rule Q: both new scripts registered in
      `provides.scripts`).
- [ ] `bash .claude/scripts/script-inventory.sh --check` — confirm the new writer is
      manifest-registered and has a non-zero inbound caller census (its caller is SKILL.md Move 4
      from Phase 4).
- [ ] `bash .claude/scripts/lint/lint-agent-contracts.sh` and
      `bash .claude/scripts/lint/lint-routing-wiring.sh`.
- [ ] `bash .claude/scripts/check-task-references.sh` — no task-number reference anywhere outside
      `specs/**`.
- [ ] `jq empty agent-system/extensions/core/manifest.json`.
- [ ] Walk the dispatch's acceptance sentence item by item and record, for each, the command that
      demonstrates it.
- [ ] Note in the summary that `.claude/` regeneration and the `specs/.gitignore` managed-block
      refresh are manual follow-ups, not part of this task.

**Timing**: 0.75 hours

**Depends on**: 1, 2, 3, 4, 5, 6

**Verification Tier**: full

**Files to modify**:
- None (verification only)

**Verification**:
- Every command above exits 0 (or, for the `--check`-style probes, reports no finding attributable
  to this task's changes).
- Any pre-existing failure unrelated to this task's files is reported as such, with evidence that
  it predates these edits — never silently absorbed and never "fixed" opportunistically.

---

## Testing & Validation

- [ ] `.decisions.json` written by the script satisfies `jq -e 'type == "array"'` on the document
      root after one append and after two.
- [ ] A second append leaves the first entry byte-identical (additive-only).
- [ ] A pre-existing object-wrapped `{"decisions": [...]}` file is refused and left byte-identical.
- [ ] Concurrent appends lose no entry.
- [ ] A missing or malformed argument exits nonzero with nothing written.
- [ ] The reader's own jq expression from `orchestrate-build-dispatch.sh` renders the written file.
- [ ] The research-phase no-handoff notice carries no `RECOVERY:` token; the plan and implement
      notices do, and each names its own phase.
- [ ] No surface in `agent-system/extensions/core/**` still claims base-mode plan or implement never
      writes a handoff.
- [ ] `shellcheck` clean across every touched shell file.
- [ ] `skill-orchestrate/SKILL.md` remains under its context-budget ceiling.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/orchestrate-record-decision.sh` (new)
- `agent-system/extensions/core/scripts/tests/test-orchestrate-record-decision.sh` (new)
- Edits: `scripts/lib/runtime-file-patterns.sh`, `scripts/orchestrate-cycle-postflight.sh`,
  `scripts/orchestrate-stage5-gates.sh`, `scripts/tests/test-orchestrate-unwind-dispatch.sh`,
  `manifest.json`, `skills/skill-orchestrate/SKILL.md`,
  `docs/architecture/handoff-schema.md`, `docs/reference/utility-scripts-inventory.md`,
  `context/standards/orchestrator-runtime-files.md`,
  `context/patterns/infra-failure-discrimination.md`
- `specs/285_decisions_writer_script_and_handoff_notice_accuracy/summaries/01_*-summary.md`
- **Follow-ups deliberately not performed here**: `.claude/` regeneration (manual-only), the
  consequent `specs/.gitignore` managed-block refresh via `init-specs.sh`, the reader-side jq
  type-safety gate at `orchestrate-build-dispatch.sh:389-392` (owned elsewhere), the
  "hard-mode-implement-only" phrasing inside the five research agents' own subsections, and any
  reconciliation of `handoff-schema.md`'s one-channel-per-mode design narrative beyond the factual
  corrections in Phase 6.

## Rollback/Contingency

Every phase is a small, independently revertable commit, and the two defects share no files:
Phases 1-4 (Defect 1) and Phases 5-6 (Defect 2) can be reverted independently of each other.

- Phases 2 and 3 add new files only; `git rm` plus reverting the two `manifest.json` lines restores
  the prior state exactly.
- Phase 4's SKILL.md edit is the only change that alters live lead behavior. If the script proves
  unusable, revert Phase 4 alone and the lead falls back to the documented schema — the
  pre-existing (defective) state, not a worse one.
- Phase 1 is additive to parallel arrays; reverting the single commit restores the 19-member set.
- Phases 5 and 6 are message- and prose-only; reverting restores the prior (false) text with no
  behavioral change to any status transition or exit code.
- Nothing in this plan migrates or rewrites existing data. Any `.decisions.json` already on disk is
  only ever appended to, and never by a code path that can leave it invalid: a failed append leaves
  the pre-existing file byte-identical by construction.
- Before any intentional rollback that a guard would otherwise block, run
  `bash .claude/scripts/git-snapshot.sh 285` first. Never run `git-snapshot.sh` in its reverting
  default mode as a routine checkpoint; use `--no-revert` for a defensive checkpoint before risky
  work.
