---
next_project_number: 286
---

# TODO

## Task Order

*Updated 2026-09-30. Generated from state.json dependency graph.*

**Dependency Waves**:
| Wave | Tasks | Blocked by | Topics |
|------|-------|------------|--------|
| 1 | 22,39,44,89,127,165,184,217,241,263,265,268,270,272,277,279,280,283,284,285 | -- | core-agent-system, extensions, literature, ... |
| 2 | 29,185,250,251,271,275,276,281 | 22,44,127,184,241,265,272,277,279,280 | core-agent-system, extensions, orchestrator |
| 3 | 170,273,282 | 184,250,251,271,281 | core-agent-system, orchestrator |
| 4 | 274 | 165,273,275 | orchestrator |

**Grouped by Topic** (indented = depends on parent):

### Core Agent System

44 [PLANNED] — Slim commands/task.md, the largest per-invocation context...
  └─ 251 [NOT STARTED] — Context-corpus reachability probe (filename, directory,...
    └─ 170 [NOT STARTED] — Audit and isolate shell test suites from ambient host state...
89 [NOT STARTED] — Apply the mode-gated section convention to the two remaining...
127 [NOT STARTED] — === REVISED 2026-09-01 (backlog streamline: absorbs the...
  └─ 251 [NOT STARTED] — Context-corpus reachability probe (filename, directory,... (see above)
184 [NOT STARTED] — Surface skeleton-plan follow-ups at completion under the...
  └─ 185 [NOT STARTED] — Retarget the remaining historical "Stage N" and "Stage MT-N"...
217 [NOT STARTED] — Cost-aware idle Lean tree reclamation in /refresh: PSS...
263 [PLANNED] — Consent-gated git push: grant semantics and enforcement mechanism
265 [PLANNED] — Run Gate 8 in parallel inside verify-deploy.sh via run-all.sh...
  └─ 250 [NOT STARTED] — Script-corpus inventory probe, then cut tests/run-all.sh...
    └─ 170 [NOT STARTED] — Audit and isolate shell test suites from ambient host state... (see above)
268 [IMPLEMENTING] — SOURCE STORE IS THE EDIT TARGET:...
280 [NOT STARTED] — Forbid record-versioning language in deliverables: the rule,...
  └─ 281 [NOT STARTED] — Repo-wide record-versioning lint with a blocking/advisory...
    └─ 282 [NOT STARTED] — Write-time PreToolUse hook blocking record-versioning...
283 [IMPLEMENTING] — Fix the agent-system test harness...
284 [NOT STARTED] — Exempt a task’s own directory from the postflight filescope...
285 [NOT STARTED] — Add the missing .decisions.json writer script and correct the...

### Extensions

241 [PLANNED] — Reconcile MCP registration surfaces: redundant playwright...
  └─ 29 [NOT STARTED] — Generate .mcp.json from extension manifests, then register...

### Literature

39 [PLANNED] — Upgrade Zotero metadata resolution and plan the Zotero 10...

### Neovim

22 [NOT STARTED] — Freeze .opencode: silence fragment validation spam and record...

### File Scope Lifecycle

165 [PLANNED] — Admission gates in orchestrate-batch-admit.sh: posture for an...
270 [NOT STARTED] — Re-runnable null-safety audit of jq mutation sites across...

### Orchestrator

272 [NOT STARTED] — Honest session liveness for concurrent same-repo batches:...
  └─ 275 [NOT STARTED] — Per-repo orchestration queue: registered, live, archived on...
    └─ 274 [NOT STARTED] — Next-admissible-batch suggestion and...
277 [NOT STARTED] — git-commit-scoped.sh cannot commit inside a dispatch...
  └─ 276 [NOT STARTED] — Stop releasing a dirty worktree on a nothingtoland verdict:...
279 [PLANNED] — Reconcile state-schema.json with the live fields the...
  └─ 271 [NOT STARTED] — Finish the parenttask edge: declare it in the schema,...
    └─ 273 [NOT STARTED] — Three-channel orchestration conclusion stage with per-channel...
      └─ 274 [NOT STARTED] — Next-admissible-batch suggestion and... (see above)

## Tasks

### 285. Add the missing .decisions.json writer script and correct the postflight handoff-recovery notice
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/** (never .claude/**), per
rules/source-store-deploy-boundary.md.

Close two lead-facing contract-surface defects in the /orchestrate loop: .decisions.json has a
documented writer but no writer script, and the postflight handoff-recovery notice is both
mislabelled and factually wrong about which phases write a handoff.

Both observed live 2026-09-30, ~/Projects/Logos/Verification, session sess_1790791567_96a2e0.
They are grouped because they share one root: the orchestrate contract tells the LEAD either to
do something, or what just happened, and the instruction is unexecutable as written or untrue.

--- DEFECT 1: A DOCUMENTED WRITER WITH NO WRITER ---

docs/architecture/handoff-schema.md's "Decisions File Schema" section names the loop's own
branch move as the writer of specs/{NNN}_{slug}/.decisions.json, and
skills/skill-orchestrate/SKILL.md Move 4 instructs the lead to "Append each answer to that
task's specs/{padded}_{project}/.decisions.json per handoff-schema.md's 'Decisions File Schema'
section". No script implements it. Every comparable state write in this system goes through one
-- state-write.sh is the mutex-guarded single writer for state.json, update-task-status.sh for
status transitions -- so .decisions.json is the sole place a lead is told to hand-author JSON.

It is additionally the only place where the instruction and the schema live in DIFFERENT files:
Move 4 does not restate the shape, and the shape (a FLAT array of objects carrying question,
answer, cycle, timestamp) sits at handoff-schema.md circa line 960. A lead that follows Move 4
without opening that second file is guessing.

OBSERVED CONSEQUENCE. The lead wrote {"decisions":[...]} instead of [...]. The reader
(orchestrate-build-dispatch.sh:389-392) aborted; that script exited 5; orchestrate-cycle-plan.sh
deferred the task on two consecutive cycles of a five-cycle run with the message
`orchestrate-build-dispatch.sh failed; deferring to a later cycle`, naming neither the file nor
the expectation. Work-cycle budget was consumed for zero work, and the cause was found only by
re-running the planner with stderr captured.

DELIVERABLE 1a. Add the writer. The natural shape is
scripts/orchestrate-record-decision.sh --task N --session SID --cycle C --question TEXT
--answer TEXT, appending exactly one schema-valid entry, creating the file when absent, and
additive only -- handoff-schema.md is explicit that existing entries are never removed or
rewritten by a later append. scripts/system-defect-record.sh, already in this directory, is the
precedent to follow for an append-one-entry-to-a-JSON-file writer. Register the new script in
docs/reference/utility-scripts-inventory.md.
DELIVERABLE 1b. Repoint SKILL.md Move 4 at the script rather than at the prose schema, so the
lead never hand-authors this file. Keep the schema section as the reference for readers.
NOTE THE SPLIT, DO NOT DUPLICATE IT. The reader-side hardening at
orchestrate-build-dispatch.sh:389-392 -- a `length` gate that establishes neither emptiness nor
type before iterating -- is recorded on task 270 as a jq type-safety instance, with the evidence
from this same session. This task owns the AUTHORING surface only. Both should land; neither
blocks the other.

--- DEFECT 2: A RECOVERY NOTICE THAT IS MISLABELLED AND WRONG ---

scripts/orchestrate-cycle-postflight.sh:598 emits, on the research postflight:
  "RECOVERY: no handoff written for this dispatch -- expected outcome for this phase's writer
   (base-mode research/plan/implement never write one). .return-meta.json (fresh, within this
   dispatch window) reports status=researched; recovering the dispatch outcome from it."
Two problems in one sentence. (i) It carries the RECOVERY label, which the script also uses for
genuine degradation, while simultaneously declaring itself the EXPECTED outcome -- so a lead
cannot distinguish a normal path from a fault. (ii) The parenthetical is FALSE. In this same run
the base-mode PLAN dispatch and the base-mode IMPLEMENT dispatch each wrote a handoff, both
confirmed by the script's own following line, "dispatch_seq match (4) -- handoff confirmed as
this dispatch's own report", and the same at seq 5. So base-mode plan and implement do write
handoffs; on this evidence it is research alone that does not.

DELIVERABLE 2. Establish which phases actually write .orchestrator-handoff.json in base mode by
reading the writers -- do not trust this message and do not restate it. Then: correct the
parenthetical to match what the writers do; and split the notice by severity, so the expected
no-handoff path reads as an ordinary informational fallback naming the source it recovered from,
while a genuinely unexpected absence keeps the RECOVERY label and its current prominence. If the
answer is phase-dependent, name the phases in the message itself rather than generalising.

ACCEPTANCE. A lead can record a user decision with one documented script call and no knowledge
of the JSON shape, and a malformed .decisions.json is no longer reachable through the sanctioned
path. The new script is registered in the utility-scripts inventory, and SKILL.md Move 4 cites it
instead of the prose schema. The handoff notice's phase claim is verified against the writers and
matches them, and the expected and unexpected cases are distinguishable at a glance. shellcheck
clean per context/standards/shell-strict-mode.md.

DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 284. Exempt a task’s own directory from the postflight file_scope excursion advisory, so the aggregator signal it was built for is visible
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/** (never .claude/**), per
rules/source-store-deploy-boundary.md.

Make the postflight modified_files-vs-file_scope excursion advisory carry signal, by exempting
the dispatching task's own task directory -- which the lifecycle REQUIRES it to write.

DEFECT (observed live 2026-09-30, ~/Projects/Logos/Verification, session sess_1790791567_96a2e0,
an ordinary single-task /orchestrate run). The advisory fired on EVERY phase, each time naming
only the artifact that phase had been dispatched to produce:
  - research postflight: ["specs/160_.../reports/01_recentre-task-graph-three-layer-aim.md"]
  - plan postflight:     ["specs/160_.../plans/01_recentre-task-graph-three-layer-aim.md"]
Both are the canonical artifact paths mandated by CLAUDE.md's "Artifact Paths" section and
rules/artifact-formats.md. A task cannot close a phase WITHOUT writing them, so no task can ever
avoid the advisory: it is unconditional, and therefore carries zero information while training
the reader to ignore the channel.

SITE. scripts/orchestrate-cycle-postflight.sh:1121-1132. The excursion predicate at lines
1128-1129 compares reported modified_files against the declared file_scope alone; there is no
implicit member for the dispatching task's own specs/{NNN}_{slug}/ tree.

READ THE PROVENANCE BEFORE DESIGNING -- THIS IS NOT COSMETIC. This advisory is direction (a) of
task 100 (close_aggregator_file_scope_blind_spot), now ABANDONED and held in
specs/archive/state.json. Its purpose was specific and narrow: make an AGGREGATOR edit outside a
declared scope visible, after two lean4 tasks were each found editing a module aggregator that
appeared nowhere in their file_scope (one adding `import` plus a docstring index entry to
Metalogic/BXCanonical.lean, the other to Semantics.lean), where the omitted edit was
structurally required for the new module to be reachable from the build. Its acceptance read:
"an aggregator edit made outside a task's declared file_scope is no longer silent -- at minimum
it is reported against that task." As shipped, that genuine aggregator signal arrives in the
same channel as, and is outnumbered by, every task's own required artifacts on every phase. The
detection direction the abandoned task chose was sound; the filter is what defeats it.

ALSO REPAIR A DANGLING CROSS-REFERENCE. Task 270's "RELATED, DELIBERATELY NOT MERGED" paragraph
states that this excursion check's advisory-vs-blocking question "was recorded separately". The
separate record is abandoned task 100, so the follow-on is not live and the pointer misleads a
reader into believing it is. Repoint 270 at this task, or restate the status there.

DELIBERATELY NOT BUNDLED INTO 270. Task 270 owns the same file and says explicitly "Touching the
same file is not a reason to bundle it." Its subject is null/type-safety in jq guards; this is
filter correctness and signal quality. Honour that boundary in both directions: if 270's audit
finds null-safety problems INSIDE lines 1121-1132 it fixes those and leaves this filter alone.

DELIVERABLE. Exempt the dispatching task's own task directory from the excursion comparison. The
natural form is to add the resolved specs/{NNN}_{slug}/ prefix as an implicit file_scope member
for the duration of the check, so that no task ever has to declare its own artifact home. Decide
and RECORD whether the exemption covers the whole task directory or only the sanctioned artifact
subdirectories plus runtime dotfiles (reports/, plans/, summaries/, .dispatch/,
.return-meta.json, .orchestrator-handoff.json, .decisions.json); prefer the whole directory
unless there is a concrete reason that a task writing elsewhere beneath its own tree is worth
surfacing. Note that an archived task's directory moves to specs/archive/{NNN}_{slug}/ -- a
forced round dispatched against an archived task writes there, so resolve the exemption from the
task directory the dispatch actually used rather than assuming the active path.

SECOND, SEPARABLE QUESTION -- ANSWER IT OR DEFER IT EXPLICITLY. Once the channel is quiet, is
advisory still the right enforcement level, or should a genuine excursion gate? Task 165's
recorded prior art is the pattern: advisory-first, write down the promotion criterion, promote
only once coverage is complete. Deciding to STAY advisory and recording the threshold is a
defensible outcome and a real decision -- but it goes in the script header either way. Do NOT
promote to blocking in the same change that fixes the filter: a gate sitting on a
known-false-positive predicate would block correct work.

ACCEPTANCE. A single-task /orchestrate run through research, plan and implement produces ZERO
excursion advisories when every modified file is either inside the declared file_scope or inside
the task's own directory. A task that genuinely edits an undeclared file outside its own tree --
the aggregator case -- still produces exactly one advisory naming that file, demonstrated with a
concrete case rather than argued. The enforcement-level ruling and its reasoning sit in the
script header alongside the existing documentation. shellcheck clean per
context/standards/shell-strict-mode.md.

DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 283. Test harness name failures baseline wall clock
- **Status**: [IMPLEMENTING]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None
- **Research**: [283_test_harness_name_failures_baseline_wall_clock/reports/01_test-harness-defects-research.md]
- **Plan**: [283_test_harness_name_failures_baseline_wall_clock/plans/01_harness-roster-baseline-wall-clock.md]
- **Summary**: [283_test_harness_name_failures_baseline_wall_clock/summaries/01_harness-roster-baseline-wall-clock-summary.md]

**Description**: Fix the agent-system test harness (agent-system/extensions/core/scripts/tests/run-all.sh), which is a systemic bottleneck for refactor work in three compounding ways. Research the harness and address all three.

DEFECT 1 -- FAILING SUITES ARE NEVER NAMED. run-all.sh prints a tally ("97 passed, 8 failed, 0 skipped, 105 total") but emits NO per-suite failure line. Measured in an 855-line real run log: 110 "[run-all] [RUN]" markers, 97 "[run-all] [PASS]" markers, and ZERO "[FAIL]" markers of any kind. The identities of the 8 failing suites are recoverable ONLY by set-differencing unique [RUN] paths against [PASS] paths. This is the root cause of the orchestration cost below: an agent that sees "8 failed" cannot tell whether a failure is its own or pre-existing, so it must either block on work it cannot diagnose or commit on a green it has not established. FIX: emit an explicit, greppable per-suite failure line naming each failing suite path, plus an end-of-run failure roster.

DEFECT 2 -- NO KNOWN-FAILING BASELINE. There is no committed manifest of already-failing suites, so "my change broke this" is indistinguishable from "this was already red" without a clean-tree control run (which costs another full suite -- see Defect 3). FIX: a committed baseline/quarantine manifest that run-all.sh reads, so a run can report "8 failed, 8 expected-failing, 0 NEW" and a gate can fail only on NEW failures.

THE 8 CURRENTLY-FAILING SUITES (recovered by set difference; 7 of 8 are core orchestrator tests):
  core/scripts/tests/test-gate-out-repair-reporting.sh
  core/scripts/tests/test-handoff-dispatch-identity.sh
  core/scripts/tests/test-lint-json-channel-discipline.sh
  core/scripts/tests/test-orchestrate-context-growth.sh
  core/scripts/tests/test-orchestrate-recover-message-findings.sh
  core/scripts/tests/test-run-all-parallel.sh
  core/scripts/tests/test-verify-deploy-context-budget.sh
  typst/scripts/tests/test-typst-element-lint.sh
Triage each: fix, or quarantine into the baseline manifest with a reason and an owning task. Note test-handoff-dispatch-identity.sh is failing while the handoff-identity contract it covers was simultaneously violated in a live orchestration run (an implementation dispatch terminated without writing its handoff, so postflight read 0/0 phases against 4 committed phases) -- check whether the red test describes a real live defect rather than being merely stale.

DEFECT 3 -- WALL CLOCK. A full run takes ~4.5 minutes, measured twice on the same machine (4m35s and 4m32s). A separate "run-all.sh --quiet" verification sweep invoked from inside orchestrate-cycle-plan.sh's own inter-cycle checkpoint exceeded 8m27s and was still running when observed. 5 suites are declared load-sensitive and excluded from the parallel pool entirely, so they serialize: core/scripts/tests/test-lake-build-guard.sh, core/scripts/tests/test-run-all-parallel.sh, core/scripts/test-four-tier-conflict.sh, core/scripts/test-state-write-concurrency.sh, core/scripts/test-state-write-regen-timing.sh. Research whether these genuinely require serialization or whether isolation (per-suite temp roots, distinct lock paths) would let them join the pool. FIX candidates: a fast-subset gate mode; a changed-files-to-affected-suites selector so a phase gate runs only relevant suites instead of all 105; caching or budget-capping the timing-sensitive suites.

MEASURED COST. In one real implementation dispatch, the agent ran the full 105-suite harness twice as a phase gate and the orchestrator's own Move 1 checkpoint ran it a third time. Combined with the agent repeatedly idling on background-completion notifications, that single dispatch consumed roughly 45 minutes of wall clock and still terminated without writing its handoff. Because the 8 failures were unnamed, whether they were pre-existing could not be settled during the run and had to be recorded as an unresolved gap.

SCOPE NOTE: all edits belong in the source store under agent-system/extensions/**, never hand-authored under .claude/** (see rules/source-store-deploy-boundary.md). Any fix to run-all.sh's own reporting needs a regression test asserting that a deliberately-failing fixture suite IS named in the output -- the current absence of [FAIL] lines would otherwise silently regress.

---

### 282. Write-time PreToolUse hook blocking record-versioning language, registered bare so exit 2 survives
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 280, Task 281

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**, a disposable
deploy artifact -- see rules/source-store-deploy-boundary.md).

GOAL. Build the write-time enforcement consumer for the record-versioning rule: a PreToolUse hook
that blocks a Write/Edit introducing forbidden record-version language into a deliverable, driven
ENTIRELY by the shared pattern library, plus its fixture test and its settings.json registration.

DELIVERABLES:
(1) hooks/validate-no-record-versioning.sh -- modeled on hooks/validate-no-task-references.sh, whose
    header records three non-obvious contracts this hook must inherit verbatim:
      - BLOCK VIA EXIT CODE 2 + a stderr message, NOT via `permissionDecision: deny`, which is
        documented-buggy for allow-listed Write/Edit tool calls (settings.json carries bare
        "Write"/"Edit" permissions.allow entries; upstream issues #4669, #13214, #18312).
      - FAIL OPEN (exit 0, with a WARNING on stderr) if the shared library is missing OR fails to
        source. The sibling guards BOTH cases explicitly, because under `set -e` an unguarded `.`
        failure would abort before reaching the fallthrough. A broken guard must never block every
        write in the repo.
      - Resolve the library relative to the hook's own directory via BASH_SOURCE, so resolution is
        independent of the tool's cwd.
(2) hooks/... registration in root-files/settings.json, appended to the existing PreToolUse
    "Write|Edit" matcher block that already carries validate-no-task-references.sh. REGISTER IT BARE
    -- no `2>/dev/null || echo '{}'` wrapper. That wrapper converts exit 2 into exit 0 and silently
    disables the block; the sibling's header calls this out as a specific trap, and the PostToolUse
    entries in the same file DO use that wrapper, so the contrast is easy to get wrong by copying the
    wrong neighbor.
(3) scripts/tests/test-validate-no-record-versioning.sh -- fixture test modeled on
    scripts/tests/test-validate-no-task-references.sh.

=== THE ADVISORY TIER AT WRITE TIME -- RESOLVE THIS EXPLICITLY ===
A hook has only two outcomes (block or allow), so the taxonomy's advisory tier has no direct
write-time expression. Decide and RECORD the posture rather than leaving it implicit: the default
recommendation is that the hook blocks on BLOCKING-tier findings only and stays SILENT on advisory
ones, leaving advisory surfacing to the repo-wide lint. A hook that printed advisory noise on every
Write would train users to ignore it. If research concludes advisory findings warrant a
non-blocking stderr note instead, say so in the hook header and in the taxonomy's Enforcement
section, and keep the two documents consistent.

=== DEPENDENCY NOTE ===
Edges on both prior tasks. On the rule/taxonomy/library task: substantive -- there is no library to
source and no tier to honor until it exists. On the lint task: partly substantive, partly footprint.
Substantive because the lint is where the discriminator gets its first real-corpus exercise, and a
write-time blocker inheriting an unvalidated discriminator would block legitimate writes across the
repo -- the highest-cost failure mode in this batch. Footprint because both touch manifest.json.

=== WIRING ===
  - manifest.json: add the hook to provides.hooks and the test to the tests list (the sibling's
    entries are the `validate-no-task-references.sh` and `tests/test-validate-no-task-references.sh`
    lines).

ACCEPTANCE. Hook shellcheck clean per context/standards/shell-strict-mode.md. Fixture test covers:
blocking finding denied with exit 2 and an actionable stderr message naming the rule; a specs/**
path allowed; an advisory-only finding allowed; marker-exempted content allowed; and a
deliberately-broken/absent library failing OPEN with exit 0. settings.json registration verified
bare (grep the deployed-form command string for the absence of `|| echo` on this entry). After
registration, confirm an ordinary Write to a docs/ file carrying only durable-axis version language
(a toolchain pin, a schema filename, a CI cache key) is NOT blocked -- a false positive here is
worse than no hook. No task-number references in deliverables outside specs/**.

---

### 281. Repo-wide record-versioning lint with a blocking/advisory tier split, driven by the shared pattern library
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 280

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**, a disposable
deploy artifact -- see rules/source-store-deploy-boundary.md).

GOAL. Build the repo-wide lint consumer for the record-versioning rule: a script that scans every
git-tracked file outside specs/** for unexempted record-version language, driven ENTIRELY by the
shared pattern library, plus its fixture test.

DELIVERABLES:
(1) scripts/check-record-versioning.sh -- modeled line-for-line on scripts/check-task-references.sh,
    which is the established shape for this class of lint and already solves several problems worth
    inheriting rather than rediscovering:
      - scans via `git ls-files`, so gitignored/vendored/generated paths are excluded by
        construction (this is what keeps .claude/** out of scope automatically)
      - three exit codes with distinct meanings: 0 clean, 1 findings, 2 environment/usage error, so
        a broken invocation is never mistaken for a clean tree
      - `--quiet` summary mode and an optional positional PATH_SCOPE argument scoping the scan to a
        subtree or single file, where a nonexistent PATH_SCOPE prints [SKIP] and exits 0
      - a `REPO_ROOT=$(pwd)` source-store invocation override, required because
        .claude/scripts/... does not exist until a deploy runs
      - NO hard-coded directory list: the sibling's own header records "Default to Repo-Wide Scope,
        Never a Hard-Coded Directory List" as a design principle, so a consumer repo with any layout
        is scanned in full rather than scanning nothing.
(2) scripts/tests/test-check-record-versioning.sh -- fixture test modeled on
    scripts/tests/test-check-task-references.sh.

=== BLOCKING VS ADVISORY -- THE ONE GENUINELY NEW DESIGN SURFACE ===
The sibling lint has a single severity. This one does not: the tiering decided in the taxonomy means
findings split into BLOCKING (affect the exit code) and ADVISORY (reported, never affect the exit
code). Implement the tier split by consuming the library's per-category tier rather than
re-classifying here, and make the reporting format state the tier per finding. The precedent for
exactly this two-tier reporting contract already exists in this repo -- see
scripts/chapter-quality-check.sh and scripts/typst-element-lint.sh, both of which report advisory
findings without affecting the exit code -- so follow that established convention rather than
inventing a third.

=== DEPENDENCY NOTE ===
Edge on the rule/taxonomy/library task is SUBSTANTIVE, not merely footprint: this script defines
none of its own patterns, exemptions, or tiers, so there is nothing to consume until the library
exists and the taxonomy has fixed the per-category tiers. file_scope also overlaps on manifest.json
and on the library itself (tier refinement driven by what the real scan finds), and the edge
serializes that overlap rather than leaving it to chance.

=== WIRING ===
  - manifest.json: add the script to provides.scripts and the test to the tests list (the sibling's
    entries are the `check-task-references.sh` and `tests/test-check-task-references.sh` lines).
  - docs/reference/utility-scripts-inventory.md: catalogue the new lint there -- that file is the
    documented home for standalone repo-health/doc-lint scripts not invoked in the normal
    research/plan/implement lifecycle, per the CLAUDE.md "Utility Scripts" pointer.

ACCEPTANCE. Script shellcheck clean per context/standards/shell-strict-mode.md. All four sibling
behaviors present and exercised by the fixture test: clean tree, blocking finding, advisory finding
that does NOT change the exit code, and marker-exempted content. Running the lint with no arguments
against the Verification repo returns exit 0 (the de-versioning sweep is committed; a nonzero exit
means either a real miss in the sweep or a discriminator bug -- resolve which, do not relax the
pattern to make it green). Running it against docs/ci.md, docs/consuming.md,
docs/stability-and-versioning-policy.md and docs/setup-without-nix.md individually produces zero
BLOCKING findings, since those carry only durable-axis version language. No task-number references
in deliverables outside specs/**.

---

### 280. Forbid record-versioning language in deliverables: the rule, its exemption taxonomy, and the shared pattern library that discriminates draft history from durable version axes
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**, a disposable
deploy artifact -- see rules/source-store-deploy-boundary.md).

GOAL. State the policy that deliverables outside specs/ describe the CURRENT DESIGN ONLY and never
narrate their own draft history, and build the single mechanical source of truth that this rule's
two enforcement consumers (repo-wide lint, write-time hook) will both consume. This task produces
policy plus mechanism; the consumers are separate tasks and deliberately come later.

DELIVERABLES (three files plus wiring):
(1) rules/no-record-versioning-in-deliverables.md -- the rule, shaped EXACTLY like its sibling
    rules/no-task-references-in-deliverables.md: a "## Path Pattern" section, a "## Principle"
    section, an explicit exceptions list, and a closing pointer to the fuller taxonomy under
    context/standards/. Carry the sibling's deliberate no-`paths:`-frontmatter HTML comment
    rationale if the same universal-scope reasoning applies (it does: any deliverable in any
    location could receive version language).
(2) context/standards/record-version-exemptions.md -- the full taxonomy and enforcement narrative,
    the lazy companion the rule points at.
(3) scripts/lib/record-version-patterns.sh -- the ONLY place detection patterns, axis
    discrimination, and exemption logic are defined. Both later consumers source it and neither
    defines any of that locally. Model its header, its exported-variable shape, its
    `is_exempt_path`, and its `strip_exempt_regions` stdin/stdout filter on
    scripts/lib/task-reference-patterns.sh.

=== SUBSTANCE OF THE RULE -- RULED, DO NOT RE-OPEN ===
Deliverable files (docs/**, README.md, code, and other work product) must state the current design
only and must never narrate their own draft history. Specifically FORBIDDEN in deliverables:
  - page-level version labels in titles or status lines: "The X convention (v2)";
    "**Status**: v2, accepted <date>; supersedes v1"
  - "this is the second version" / "supersedes v1" framing
  - supersession or disposition tables mapping an earlier draft's decisions onto the current ones
  - "(v1 Decision N)" attributions attached to rejected alternatives
  - phrasing relative to an unstated past: "no longer", "previously", "formerly", "used to",
    "carried forward from v1", "withdrawn", "every v1 field removed"

Rejected alternatives are KEPT -- they are the point of a decision record -- but stated on their own
merits rather than attributed to an earlier draft of the same document.

=== EXEMPT ZONES -- RULED, VERSION LANGUAGE IS PERMITTED, NO MARKER NEEDED ===
1. Everything under specs/** -- task descriptions, plans, reports, summaries, `completion_summary`
   fields, TODO.md, state.json, ROADMAP.md. THIS IS THE PRIMARY EXEMPTION and was confirmed
   explicitly by the owner.
2. Git commit messages; PR/branch metadata.
3. Three DURABLE NON-RECORD version axes that are not draft history:
   (a) software/toolchain versions -- `Lean v4.31.0`, `actions/checkout@v4`, `schema = 2` semantics
   (b) file-format and schema versions -- `book.toml` `schema = 2`, `books/schema/book-toml-v2.md`,
       `book-cert-v2.md`
   (c) CI cache-key epoch segments -- `pnpm-v1-`, `lake-recheck-v3-` in docs/ci.md
4. An explicit, DATED cross-document amendment note in a decision record, recording that a decision
   the record OWNS was amended -- docs/architecture-decisions.md's "**Amended by** <doc>, <date>:"
   house style. This records a real change to an accepted decision, not a draft lineage, and MUST
   stay permitted. (Verified present: docs/architecture-decisions.md carries exactly one such note.)

Beyond these four, an exception requires EXPLICIT USER PERMISSION. Provide a marker convention for a
user-permitted exception mirroring the sibling's `task-ref-ok` marker: a block form
(`version-ok:begin` ... `version-ok:end`, matched as plain substrings so comment syntax is
irrelevant) and an inline form, both requiring a trailing reason naming a taxonomy category. Name
the marker in the taxonomy and implement its stripping in the shared library, not in either
consumer.

=== THE HARD DESIGN PROBLEM -- THIS IS WHAT THE TASK IS ACTUALLY ABOUT ===
The forbidden vocabulary OVERLAPS HEAVILY with the legitimate uses in exempt zone 3: `v1`/`v2`
appear in toolchain pins, CI cache keys and schema filenames, so a naive regex is noisy. The shared
library must DISCRIMINATE the record-version axis from the three durable axes. Verified footprint in
the Verification repo at the time of writing: eight files under docs/ plus README.md match a bare
`\bv[0-9]\b`, and docs/book-convention.md still legitimately carries 4 such mentions AFTER the sweep
-- so the discriminator's job is to return zero findings on that already-clean tree while still
catching the patterns in the FORBIDDEN list above. It is ACCEPTABLE for some categories to be
ADVISORY rather than BLOCKING; decide the tier per category in the taxonomy and encode the tiering
in the library so both consumers inherit it rather than each choosing. The bare-past-tense
vocabulary ("no longer", "previously", "formerly", "used to", "withdrawn") is the most
false-positive-prone category and is the leading advisory candidate.

=== RATIONALE TO RECORD IN THE RULE (cite durable anchors, no task numbers) ===
docs/book-convention.md shipped carrying 68 v1/v2 mentions across 1,705 lines, a 22-line "How this
record relates to v1" supersession table with 15 disposition rows, eight "(v1 Decision N)"-attributed
rejected alternatives, and an "Every v1 field removed" migration table -- while BOTH "versions" were
dated the same day and nothing in the repository had ever been built against v1 (no `book.toml`
existed anywhere). The file documented its own authoring process rather than its design, and the
label leaked outward into docs/architecture-decisions.md (5 references), docs/README.md,
specs/ROADMAP.md and eight open task descriptions in state.json. It was also off house style: every
other decision record in docs/architecture-decisions.md carries a bare "**Status**: accepted, <date>"
with no page version. The de-versioning sweep is already committed -- see the commit titled "docs:
state the book convention without version history" -- and this rule is the durable guard against
recurrence.

=== WIRING (do not skip; the sibling occupies all of these surfaces) ===
  - manifest.json: add the rule to provides.rules, the standard to provides.context, and the library
    to provides.scripts (the sibling's entries are at the `no-task-references-in-deliverables.md`,
    `standards/task-reference-exemptions.md` and `lib/task-reference-patterns.sh` lines -- follow
    their exact shape).
  - index-entries.json: add a discovery entry for the standard, modeled on the existing
    `standards/task-reference-exemptions.md` entry (path, summary, keywords).
  - merge-sources/claudemd.md: add the rule to the "Rules References" core-rules list beside the
    `no-task-references-in-deliverables.md` line, so the deployed CLAUDE.md advertises it.

ACCEPTANCE. Rule file structurally parallel to its sibling (same four sections, same pointer
discipline). Taxonomy standard enumerates every category with its blocking/advisory tier and
documents the marker convention. Shared library is shellcheck clean per
context/standards/shell-strict-mode.md, exports its patterns and both exemption helpers, and is
sourceable standalone. All three manifest/index/claudemd surfaces wired. A one-off manual run of the
library's discriminator over the Verification repo's docs/ and README.md returns zero BLOCKING
findings (the sweep is committed, so a green tree is the expected baseline and any finding is either
a real miss in the sweep or a discriminator bug -- resolve which before closing). No task-number
references in deliverables outside specs/**.

---

### 279. Reconcile state-schema.json with the live fields the orchestrator reads: rule per field (widen, migrate, or retire), and fix the blockers reader/comment contradiction
- **Status**: [PLANNED]
- **Task Type**: meta
- **Topic**: orchestrator
- **Dependencies**: None
- **Research**: [279_state_schema_rejects_live_orchestration_fields/reports/01_state-schema-field-ruling.md]
- **Plan**: [279_state_schema_rejects_live_orchestration_fields/plans/01_widen-state-schema-fields.md]

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/context/schemas/state-schema.json, plus any migration script, under agent-system/extensions/core/ (never .claude/**, a disposable deploy artifact regenerated by the loader -- see rules/source-store-deploy-boundary.md).

CONSUMER-REPO STATE IS THE EVIDENCE, NOT THE EDIT TARGET. The failure was observed in ~/Projects/BimodalLogic. Land nothing there: it is a separate repository with its own task system. Any DATA migration of that repo's specs/state.json is a separate consumer-side action for its owner to run, after this task ships the schema decision and (if one is warranted) the migration tool.

URGENCY. `bash .claude/scripts/validate-state.sh` in that repo FAILS: 8 passed, 13 warnings, 9 FAILED. Any gate that depends on validate-state.sh is therefore currently RED in that repo. Confirmed not an artifact of running the wrong copy -- the repo's own deployed validator and the global-root one produce identical results, and `jq -r '.properties|keys'` on the deployed and the source-store state-schema.json returns an identical key list, so the two schemas are in sync and the failure is genuine. Entirely PRE-EXISTING: all four unknown top-level fields are present at commit 1db84f6eb, before the observing session began.

THE DEFECT. state-schema.json sets `additionalProperties: false` at BOTH the top level and on definitions.projectEntry, and its allowed sets omit fields that carry LIVE, NON-NULL data -- some of which the orchestrator itself reads.

Schema's allowed TOP-LEVEL set (verified): active_projects, active_topics, completed_projects, default_task_type, memory_health, next_project_number, repository_health, vault_count, vault_history, version.
Schema's allowed projectEntry set (verified): artifacts, completion_summary, created, dependencies, description, effort, file_scope, last_updated, memory_candidates, next_artifact_number, priority, project_name, project_number, reflection, research_questions, roadmap_items, session_id, status, task_type, title, topic.

REJECTED TOP-LEVEL FIELDS, with their live values in the consumer repo:
  active_goal   -- a real goal string: "Close the residual repository-hygiene backlog"
  artifacts     -- a populated array (length 1)
  metadata      -- a populated object: {generated_at, last_sync, total_tasks}
  last_updated  -- a real timestamp: 2026-09-29T05:45:37Z
Note `artifacts` and `last_updated` are already modelled AT ENTRY level but not at top level, so the rejection is a scope mismatch rather than an unknown concept. `metadata` looks like generator bookkeeping; check whether generate-todo.sh or a sync path is its writer before assuming it is inert.

REJECTED ENTRY FIELDS, with the entries carrying them:
  blockers         -- 298, 257, 428, 481
  previous_status  -- 428 ("implementing"), 481 ("partial")
  researched       -- 298, 428 (both hold a TIMESTAMP, e.g. 2026-06-09T06:07:43Z -- a phase-completion time, NOT a boolean flag)
  resume_phase     -- 257 (value 1; that task's status is `blocked`, so this is a live resume point for a task that is waiting)

THIS IS A DECISION, NOT A MECHANICAL FIX. Per field, rule between:
  (a) WIDEN state-schema.json to model it, with a type and a documented purpose in
      context/reference/state-management-schema.md;
  (b) MIGRATE the data into an already-modelled field and remove it, with the migration NAMED and
      the information PRESERVED -- not dropped;
  (c) DECLARE IT LEGACY and removable, which requires FIRST establishing that nothing reads it and
      that no information is lost.
HARD CONSTRAINT ON ANY OUTCOME: no resolution may delete a non-null value without this task
recording, in writing, where that information went. A field holding real data is not stale junk
merely because the schema does not know about it.

TWO FIELDS HAVE LIVE READERS -- (c) IS NOT AVAILABLE FOR THEM WITHOUT REMOVING THE READER FIRST:

1. `blockers` -- READ by scripts/orchestrate-cycle-postflight.sh:1273:
     '.active_projects[] | select(.project_number == $num) | .blockers // "Unspecified blocker"'
   ... while the comment at lines 1276-1277, in the ELSE branch of the very same conditional,
   asserts the opposite: "`.active_projects[].blockers` is never written by any script (would
   degrade to \"Unspecified blocker\" every time)". So one branch reads the field and the sibling
   branch's comment denies it exists. RESOLVE THIS CONTRADICTION EITHER WAY -- one of the two is
   wrong today, and consumer state proves the field IS populated in practice, so the comment's
   factual claim is the one that fails. If the comment is right about intent, the reader at 1273 is
   dead code and should go; if the reader is right, the comment must be corrected and the field
   modelled.
   TYPE INCONSISTENCY TO SETTLE AS PART OF (a) OR (b): live `blockers` values have TWO SHAPES --
   a plain STRING on 298/257/428, and an ARRAY on 481 (["Phase 6: universeClosedAt_signedUniver..."]).
   The reader at 1273 uses `.blockers // "Unspecified blocker"`, which renders a string correctly
   but would emit a raw JSON array for 481. Any widening must pick one shape and any migration must
   normalize the other; a schema that accepts both would preserve the reader bug.

2. `previous_status` -- READ by scripts/orchestrate-triage-classify.sh:459
     (`($entry.previous_status // null) as $prev`, where `$entry` is bound at line 401 to
     `[$all[] | select(.project_number == $c)] | first`, i.e. an active_projects ENTRY).
   This is NOT incidental: that script's header documents a `previous_status`-routed discharge
   mechanism at lines 32, 85-89, 127-130 and 145 ("When discharged, BOTH engines converge: route the
   candidate's `previous_status` through the SAME not_started/researched/planned-or-implementing/
   researching/planning logic already applied to a live `status`"), and it has explicit named
   fallbacks at 495 and 507 for a missing or unrecognized value ("cannot determine discharge phase,
   needs human"). In the consumer repo, BOTH entries carrying `previous_status` (428, 481) have
   `status: blocked` -- exactly the state where this routing fires. Removing the field would
   silently degrade both of those blocked tasks to `needs_human` on discharge. (a) is the strongly
   indicated answer here, and the field should be documented as load-bearing for blocked-task
   discharge routing, not as bookkeeping.

NO WRITER FOUND IN THE AGENT SYSTEM for `active_goal`, `resume_phase`, or entry-level `researched`
(grep over agent-system/extensions/core/ returns nothing that writes them). That makes them
plausibly legacy or externally written -- but "no writer" is NOT sufficient for (c). Establish
separately that nothing READS them and that no information is lost, and account for the fact that
`resume_phase: 1` on a BLOCKED task is exactly the kind of value whose loss is invisible until
someone tries to resume.

`parent_task` IS DELIBERATELY EXCLUDED FROM THIS TASK -- it is already owned elsewhere. Task 271
("Finish the parent_task edge") has state-schema.json and validate-state.sh in its file_scope and
its work item (1) already declares the field in the schema; that IS outcome (a) for it. Do not
duplicate it here. BUT NOTE, and 271 has been annotated to match: 271's description asserts "NO
MIGRATION BURDEN. Live count of entries carrying `parent_task` in this repo: 0". That is true of
the agent-system repo and FALSE of consumer repos -- BimodalLogic has SIX entries carrying
`parent_task: 165` (410, 411, 412, 428, 429, 430), recording real expansion lineage. 271's
orphaned-parent and cyclic-parentage checks must therefore be designed against a real population,
and its no-backfill premise re-examined.

WORK ITEMS.
(1) Rule on each of the eight fields (4 top-level, 4 entry) with (a)/(b)/(c) and a written rationale.
(2) Apply the ruling to context/schemas/state-schema.json and document every widened field in
    context/reference/state-management-schema.md.
(3) Resolve the postflight:1273 reader vs. :1276 comment contradiction, and settle the blockers
    shape (string vs array).
(4) If any field is migrated or retired, ship the migration as a script under
    agent-system/extensions/core/ that a consumer repo owner can run, and state what it preserves.
    Do not hand-edit any consumer repo's state.json from this task.
(5) Add validator coverage under scripts/tests/test-validate-state.sh pinning the ruling, so a
    future schema edit cannot silently re-reject a modelled field.
(6) Consider whether `additionalProperties: false` is the right posture at all for a schema that
    must tolerate state written by older versions of itself and by consumer-side tooling. An
    advisory-first warning for an unknown field, with `--strict` enforcing, is the precedent this
    repo already uses elsewhere (see 271's work item 2 and the plan-format.md Verification Tier
    rollout). Ruling either way should be recorded, since it determines whether this class of
    failure can recur with the next field someone adds.

ACCEPTANCE. All nine validate-state.sh failures in the consumer repo are explained and each is
either modelled, migrated (with the migration shipped and the destination named), or retired with
its no-information-loss argument written down; no non-null value is deleted without a written
record of where it went; the postflight reader/comment contradiction is resolved; validator tests
pin the ruling; shellcheck clean per context/standards/shell-strict-mode.md. No task-number
references in deliverables outside specs/**.

FILE FOOTPRINT / COORDINATION NOTES (no hard dependency edges declared -- file_scope-driven
serialization at admission is the designed mechanism, and this task fixes a RED gate, so holding it
behind unrelated work would be the wrong trade):
- context/schemas/state-schema.json and scripts/validate-state.sh overlap task 271, and
  validate-state.sh also overlaps task 269 (a one-line null-safety fix). This task sets the
  per-field policy that 271's work item (1) should follow; if 271 lands first, re-derive the
  widening against its already-declared parent_task entry rather than assuming the original shape.
- scripts/orchestrate-cycle-postflight.sh overlaps tasks 184, 263, 273 and the `nothing_to_land`
  dirty-worktree task. The edit here is a small comment/reader correction near line 1273, far from
  the worktree-landing block near line 836, but whichever lands second should re-read the file.
- scripts/orchestrate-triage-classify.sh appears in no other active task's file_scope.


=== TWO TOP-LEVEL FIELDS SETTLED BY HAND 2026-09-30 (outcome (a)); RE-DERIVE, DO NOT RE-LITIGATE ===
Observed in ~/Projects/Logos/Verification (a DIFFERENT consumer repo from the BimodalLogic
evidence above), where validate-state.sh --deep reported exactly two failures, both top-level
unknown fields: `active_goal` and `deployment_versions`. Both are now modelled in
context/schemas/state-schema.json and documented in
context/reference/state-management-schema.md. Nothing was deleted; no data moved.

`deployment_versions` IS THE STRONGEST CASE OF ALL EIGHT FIELDS, AND THIS TASK'S FIELD LIST DID
NOT CONTAIN IT. The BimodalLogic snapshot that produced the list above had never run `/tag`, so
the field never appeared. It has a live writer INSIDE the agent system:
skills/skill-tag/SKILL.md circa lines 509-545 both creates the object when absent and updates
`last_deployed`, `last_deployed_at` and a ten-deep `deployment_history` on every tag. So
`additionalProperties: false` was rejecting a top-level field one of the system's own skills
produces -- meaning every consumer repo that had ever run `/tag` failed the
unknown-top-level-field check through no fault of its own, and would fail again on the next tag
no matter what a consumer-side migration did. Outcome (c) was never available here and outcome
(b) had nowhere to migrate to, so (a) was forced rather than chosen. Modelled with the exact
sub-shape skill-tag writes, including the [0:9] history cap.

`active_goal` was modelled, not retired, deliberately. This task's own finding stands -- no
writer or reader in the agent system -- but that is not sufficient for (c) under this task's
hard constraint, and the Verification repo's value is a real multi-sentence goal string. Note a
CROSS-REPO COORDINATION POINT this task should not be surprised by: that repo's task 155 owns its
`active_goal` content and its description offers two options, "rewrite it as the three-layer aim,
or remove it, since validate-state.sh reports it as an unknown top-level field". Modelling the
field here makes both of 155's options gate-clean, which is the point: 155 should choose on
content grounds, not to appease a validator. Had this task ruled (c) while 155 chose "rewrite",
the two repos would have deadlocked on the same failure.

WHAT REMAINS THIS TASK'S: the other six fields (`artifacts` and `metadata` and `last_updated` at
top level; `blockers`, `previous_status`, `researched`, `resume_phase` at entry level -- seven
counting `metadata`), the postflight:1273-reader-versus-:1276-comment contradiction, the
`blockers` string-versus-array shape, validator test coverage, and above all WORK ITEM (6), the
`additionalProperties: false` posture. Work item (6) is untouched and is arguably now better
motivated, not less: the two fields settled here were both false failures, and one of them was
the system rejecting its own output, which is exactly the recurrence argument (6) exists to weigh.
Work item (5)'s test coverage should pin these two alongside whatever else is ruled.

FILE FOOTPRINT NOTE: context/schemas/state-schema.json and
context/reference/state-management-schema.md were edited by hand for this, so re-read both before
applying this task's own ruling rather than assuming the shapes recorded earlier in this
description.

---

### 278. Forbid forwarding the Agent tool isolation parameter in skill-orchestrate Move 2, and mark plan.sh isolation/worktree_path fields descriptive
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: orchestrator
- **Dependencies**: None
- **Research**: [278_forbid_agent_isolation_forwarding_in_move_2/reports/01_forbid-isolation-forwarding.md]
- **Plan**: [278_forbid_agent_isolation_forwarding_in_move_2/plans/01_forbid-isolation-forwarding.md]
- **Summary**: [278_forbid_agent_isolation_forwarding_in_move_2/summaries/01_forbid-isolation-forwarding-summary.md]

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/skills/skill-orchestrate/SKILL.md and agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh (never .claude/**, a disposable deploy tree). Documentation-and-contract change only; no executable logic changes.

VERIFIED IN THE SOURCE STORE. `grep -n isolation` over skills/skill-orchestrate/SKILL.md returns NOTHING: Move 2 does not forbid passing the Agent tool's harness-level `isolation` parameter. Meanwhile orchestrate-cycle-plan.sh emits `isolation` and `worktree_path` on EVERY `dispatch[]` row (documented in its own output-schema header block, and produced identically in both the live and --dry-run row builders). A dispatching lead reading a dispatch row that says `isolation: "worktree"` is actively invited to forward it to the Agent tool as that tool's own `isolation` argument. Nothing at the point of use tells it not to.

WHY FORWARDING IS DESTRUCTIVE. Forwarding stacks a SECOND harness checkout on top of the worktree that dispatch-worktree.sh already provisioned. The harness then refuses all cross-checkout git BY DESIGN, while still permitting file writes and `lake` runs. The agent therefore authors work, verifies it green, and then cannot commit it -- the worst possible split, because every signal short of the commit says success.

OBSERVED EVIDENCE. During a multi-task /orchestrate run of task 703 in the BimodalLogic repository, this cost one dispatch 20 of its 21 phases. Treat that repository as read-only evidence: land nothing there.

WHERE THE PROHIBITION CURRENTLY LIVES. Only as rationale prose in context/patterns/batch-orchestration-guardrails.md under "Deliberate Divergences" (around line 1492). That is a file a dispatching lead has no reason to open mid-dispatch. A prohibition that exists only in a rationale document adjacent to the decision, and not at the point of use, is not an enforced prohibition.

PROPOSED FIX, two edits plus an optional third:

(a) skills/skill-orchestrate/SKILL.md, Move 2: add an explicit MUST NOT line forbidding the `isolation` parameter (and `worktree_path`) in the Agent call. The Agent-call shape shown there already omits an `isolation` key, but only IMPLICITLY -- an omission in an example is not a rule, and a lead reconciling that example against a dispatch row carrying `isolation: "worktree"` will reasonably conclude the example is simply abbreviated. State the consequence in one clause (a second stacked checkout; harness refuses cross-checkout git; work authored and verified but uncommittable) so the rule is self-justifying at the point of use.

(b) orchestrate-cycle-plan.sh header: document that `isolation` and `worktree_path` are DESCRIPTIVE dispatch-site wiring -- they RECORD a posture already in effect (the worktree was provisioned before the row was emitted) and are NEVER arguments to forward to the Agent tool. The existing header already calls `isolation` "dispatch-site wiring"; that phrase is too weak to carry the prohibition, since it reads as a description of what the field configures rather than a statement that the field configures nothing at the Agent call.

(c) Optional: leave a one-line pointer from batch-orchestration-guardrails.md's "Deliberate Divergences" passage to the new MUST NOT line, so the rationale and the rule stay linked in both directions and a future edit to one surfaces the other.

CONSIDER GENERALIZING: check whether other harness-level Agent parameters are exposed the same way by any dispatch-row schema, and whether the MUST NOT should be phrased as a category ("no field of a dispatch row is an Agent-tool argument unless Move 2 names it") rather than enumerating `isolation` alone.

FILE FOOTPRINT / COORDINATION NOTES (no hard dependency edges declared -- file_scope-driven serialization at admission is the designed mechanism, and hard edges here would block a small documentation fix behind five unrelated tasks):
- skills/skill-orchestrate/SKILL.md also appears in the file_scope of tasks 263, 273, 274 and 275.
- orchestrate-cycle-plan.sh also appears in the file_scope of tasks 250, 165, 265 and 272. Task 250 in particular DECOMPOSES this file, which will move or rewrite the header block that edit (b) targets. 250 is currently blocked behind six dependencies (199, 245, 249, 259, 265, 266), so serializing this task behind it would be the wrong order; do this first and expect 250 to carry the note forward. If 250 happens to land first, re-derive where the header note belongs in the decomposed layout rather than assuming the original location.

---

### 277. git-commit-scoped.sh cannot commit inside a dispatch worktree: let the caller target one, and make an unresolvable pathspec a hard error
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: orchestrator
- **Dependencies**: Task 278

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/scripts/git-commit-scoped.sh (never .claude/**, a disposable deploy tree).

VERIFIED IN THE SOURCE STORE. git-commit-scoped.sh -- the single sanctioned, mutex-serialized, path-scoped commit path used by every skill postflight -- cannot commit inside a dispatch worktree, and FAILS AS A FALSE NEGATIVE that reads as success to its caller.

THE MECHANISM. Near the top of the script: `PROJECT_ROOT="$(common_repo_root "$SCRIPT_DIR" 2)"`, derived from `BASH_SOURCE[0]` and then used for the `cd`. The script therefore always operates on the MAIN tree regardless of the caller's cwd, and offers no flag to retarget: there is no `--repo-root` and no `--worktree` in its argument parser (verified by reading the parse loop; the only flags are `--message`, `--session`, `--honest-index-rows`, `--task`, and `--`).

Invoked from a dispatch worktree, the consequences compose into silence:
- The worktree's new/modified files are not present at PROJECT_ROOT, so each pathspec falls through to the unmatched-pathspec branch, which WARNs and DROPS it: "git-commit-scoped.sh dropping unmatched pathspec '...' (no such file/directory on disk and not tracked by git); this path will NOT be part of the commit." A dropped pathspec is not an error and does not affect the exit status.
- With every pathspec dropped there is nothing staged, so the script reaches "NOTE: Nothing to commit or git commit failed (non-blocking)" and returns success.

A caller sees a zero exit and no failure. The work is simply not committed.

OBSERVED EVIDENCE. During a multi-task /orchestrate run of task 703 in the BimodalLogic repository, a dispatched agent hit exactly this and fell back to a plain `git -C <worktree> commit` with an explicit file list. Commit b6f5c8c2e in that run consequently LACKS its `Co-Authored-By` and `Claude-Session` trailers, because the fallback path does not carry them. That missing-trailer commit is the durable fingerprint of this defect. Treat that repository as read-only evidence: land nothing there.

PROPOSED FIX, two parts:

(a) Let the caller target a worktree. Either honor cwd when it resolves inside a REGISTERED worktree of the SAME repository (compare `git rev-parse --git-common-dir` / `--show-toplevel` against the main tree's, and refuse a cwd that resolves to an unrelated repo), or add an explicit `--repo-root` / `--worktree` flag, or both. Prefer whichever keeps the refusal surface small and auditable.

(b) Make an unresolvable pathspec a HARD ERROR rather than a silent skip. The WARN-and-drop behavior is what converts a wrong-tree invocation into a false success; without (b), any future retargeting bug degrades the same silent way.

HARD CONSTRAINT: this script is the sanctioned commit path for ordinary main-tree skill postflights. The fix MUST NOT change its behavior for those callers. In particular, (b) has a behavioral-compatibility question that planning must settle before implementation: existing main-tree callers may be relying, knowingly or not, on the drop-and-continue posture for pathspecs that legitimately do not exist yet (e.g. a postflight passing `specs/` plus an artifact path that a phase did not produce). Audit the call sites before making the drop fatal, and consider gating the hard error behind the new worktree-targeting mode, or distinguishing "pathspec matched nothing but its parent exists" from "pathspec is outside the repo".

TESTS. agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh already exists. Add cases for: (i) invocation from inside a registered worktree commits into that worktree's branch and carries the trailers; (ii) invocation from an unrelated repository is refused rather than silently committing nothing; (iii) whatever posture (b) settles on, pinned as an explicit assertion so it cannot regress. Note that test-lint-scoped-commit-boundary.sh also constrains this script's boundary -- check it still passes.

FILE FOOTPRINT / COORDINATION NOTES: git-commit-scoped.sh appears in NO other active task's declared file_scope, so this task has a clean footprint. Task 263 (consent-gated git push) concerns the adjacent push path and mentions this script in prose only; no edge declared.

---

### 276. Stop releasing a dirty worktree on a nothing_to_land verdict: convert silent destruction of uncommitted work into a BLOCKED verdict
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: orchestrator
- **Dependencies**: Task 277

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh and agent-system/extensions/core/scripts/dispatch-worktree.sh (never .claude/**, a disposable deploy tree).

HIGHEST SEVERITY: SILENT DATA LOSS, VERIFIED IN THE SOURCE STORE. A dispatch that authored verified work but failed to commit it has that work destroyed, with no error raised anywhere.

THE MECHANISM (both halves confirmed by reading the source, not the deployed copy):

1. orchestrate-cycle-postflight.sh, in its `phase = "implement"` worktree-landing block, folds two verdicts into ONE success branch: `case "$land_verdict" in landed|nothing_to_land)`. That branch immediately runs `dispatch-worktree.sh release "$task_number"`, deleting the worktree.

2. dispatch-worktree.sh `land` returns `nothing_to_land` from a pure BRANCH-ancestry test: `if git -C "$PROJECT_ROOT" merge-base --is-ancestor "$branch" HEAD` then `{verdict: "nothing_to_land", branch: $branch}` and return 0. It never inspects the worktree's working tree. UNCOMMITTED worktree content is therefore completely invisible to it -- a worktree whose branch never diverged from HEAD reports `nothing_to_land` no matter how much uncommitted verified work it holds.

Composed: uncommitted work + a non-diverged branch => `nothing_to_land` => release => destroyed.

OBSERVED EVIDENCE. During a multi-task /orchestrate run of task 703 in the BimodalLogic repository, this would have destroyed 456 verified, sorry-free, build-green Lean lines. It was caught ONLY because the orchestrator inspected the worktree by hand and committed before running postflight. Nothing in the system would have reported the loss. Treat that checkout as read-only evidence: land nothing there; it is a separate repository with its own task system.

PROPOSED FIX. Before accepting a `nothing_to_land` verdict, check `git status --porcelain` in the worktree; if non-empty, emit a loud BLOCKED verdict that PRESERVES the branch and the worktree instead of releasing. Reuse the shape of the existing land-blocked path in the same file: the `conflict|refused_specs_paths|refused_dirty_overlap` branch sets `worktree_land_blocked=true` and a `worktree_land_reason`, and the `implemented)` status arm then sets `implemented_gate_passed=false`, performs NO state.json transition, and leaves the branch and worktree in place for human resolution. That is exactly the posture wanted here.

Decide during planning WHERE the dirty check belongs. Preferred: inside `dispatch-worktree.sh land` itself, as a new verdict (e.g. `refused_dirty_uncommitted`) added to the blocked set that postflight already handles -- `land` owns the worktree knowledge, and every future caller then inherits the protection rather than each re-implementing it. The alternative (checking in postflight before the release call) protects only this one call site.

WHY THIS FRAMING MATTERS: the fix must convert the whole failure CLASS from silent destruction into a visible block, whatever the cause of the missing commit. Do not narrow it to the one cause observed in this run. A missing commit can come from an agent that forgot, an agent that crashed, a commit path that silently no-oped (see the separately-tracked git-commit-scoped.sh worktree defect), or a harness refusal. All of them must block, not release.

REGRESSION TEST. Add coverage under agent-system/extensions/core/scripts/tests/ (test-dispatch-worktree.sh already exists and is the natural home) for a DIRTY worktree whose branch IS already an ancestor of HEAD -- the precise combination that currently returns `nothing_to_land`. Assert the verdict is blocking and that the worktree still exists afterward.

FILE FOOTPRINT / COORDINATION NOTES (one hard dependency edge declared: this task depends on the git-commit-scoped.sh worktree-targeting task, which itself depends on the Move 2 isolation-forwarding contract fix. That chain is deliberate -- the trigger closes first, then the commit path this fix attests to is repaired, then the destructive release branch is removed -- and file_scope overlap alone would not have ordered it, since the three footprints are disjoint. All other coordination below remains file_scope-driven serialization at admission):
- orchestrate-cycle-postflight.sh also appears in the file_scope of tasks 184, 263 and 273.
- dispatch-worktree.sh appears in NO other active task's declared file_scope, BUT task 268's fix (the lake-build-guard false-green replay, whose newly-identified mechanism is dispatch-worktree.sh's `cp -al` clone of .lake/) will touch this same file in its `provision` path. 268 currently has a null file_scope, so admission cannot see that overlap. The two edits are in different functions (`land`/release handling here vs. `provision`'s clone there), but whichever lands second should re-read the file.

---

### 275. Per-repo orchestration queue: registered, live, archived on finish, and consumed by admission
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: orchestrator
- **Dependencies**: Task 272, Task 51

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**, a disposable deploy artifact -- see rules/source-store-deploy-boundary.md).

GOAL. Register orchestrations in a per-repo queue whose metadata stays current, archive them when
they finish, and expose the queue as an admission input so a new orchestration runs when it does
not conflict and is refused with named alternatives when it does.

=== SEMANTICS -- RULED, DO NOT RE-OPEN ===
REGISTRY PLUS IMMEDIATE REFUSAL. The queue is a live record of in-flight orchestrations plus an
archive of finished ones. A conflicting new orchestration is REFUSED IMMEDIATELY, with the conflict
named and alternatives suggested. There is NO WAITING QUEUE, NO SCHEDULER, NO AUTO-START and NO
UNATTENDED EXECUTION. Do not design enqueue-and-wake machinery. "Queue" here means the registry and
its archive, not a work queue that something drains.

SCOPE -- RULED: PER-REPO. One queue per repository, living beside the existing session registry. No
cross-repo global queue and no global-ready schema requirement: file_scope conflicts are inherently
per-repo, so a global queue would carry no information the per-repo one lacks.

=== WHAT THIS OWNS ===
The record schema; the lifecycle states registered -> running -> finished -> archived; keeping the
record's metadata current while an orchestration runs; archiving on completion; and exposing the
queue as an admission input.

This task TAKES OVER PIECE 4 OF TASK 272 IN FULL: per-orchestration identity distinct from
`session_id`, so two batches in two sessions of one repo keep separate
metadata/artifacts/return-meta rather than a single shared in-flight record. That piece has been
removed from 272's scope and lives here.

=== VERIFIED GROUNDING IN THE SOURCE STORE ===
(1) THERE IS NO ORCHESTRATION-LEVEL RECORD TODAY, AND NO HISTORY WHATSOEVER. task-lock.sh's
    `cmd_session_release` is a bare `rm -f "$sessions_dir/${session_id}.json"` -- a finished
    session's entry is DELETED, not archived. Nothing anywhere records that an orchestration ever
    ran. The archive half of this task is therefore genuinely new construction, unlike the live
    half.
(2) NO `orchestration_id` CONCEPT EXISTS anywhere in scripts/, context/, skills/ or commands/
    (measured: zero occurrences). The unit of identity today is `session_id`, and ONE SESSION CAN
    COVER SEVERAL TASK NUMBERS -- observed live, a single session covering 696, 701, 703, 704, 649
    and 650 in one repo. That many-to-one relation is exactly why an orchestration-level id is
    needed and why `session_id` cannot serve as one.
(3) BUILD ON THE EXISTING SESSION REGISTRY, DO NOT REPLACE IT. specs/.sessions/{session_id}.json
    with session-register / session-heartbeat / session-release / session-reap / session-list is
    the substrate.
(4) REUSE THE EXISTING LIVENESS VOCABULARY -- DO NOT TRANSCRIBE A SECOND COPY. `session_liveness()`
    already computes six reasons: `corrupt`, `dead-pid`, `dead-pid-within-grace`, `stale-heartbeat`,
    `pid-alive`, `undeterminable`, governed by two thresholds
    (SESSION_REGISTRY_DEAD_PID_MIN, SESSION_REGISTRY_REAP_MIN) in a documented evaluation order
    (dead-pid tested first). Its own header records that it was factored out precisely so
    cmd_session_list and session_contention() consume the IDENTICAL verdict rather than a second
    transcription. A queue entry's liveness must consume that verdict for the same reason.
(5) ARCHIVAL LOCATION MUST BE SETTLED WITH TASK 51, which relocates the per-session runtime files
    out of the specs root and owns scripts/reap-session-runtime-files.sh,
    context/standards/orchestrator-runtime-files.md and scripts/check-runtime-file-tracking.sh.
    Task 51's own text warns against creating a fourth orphaned naming generation -- an
    independently-chosen archive path here would be exactly that. ALSO check how skills/skill-todo/
    archives tasks, so orchestration archival follows the established convention rather than
    inventing a new one.

=== DEPENDENCY NOTES ===
Edge on 272 is SUBSTANTIVE, not footprint: a queue whose metadata silently stops updating is worse
than no queue at all, so the zero-heartbeat defect (272's piece 1) must be diagnosed before this
queue relies on heartbeat-driven currency. Edge on 51 is substantive too: it relocates the runtime
files this queue lives among and owns the relevant standard. Both droppable per the standing
convention if either stalls -- but if 272 is dropped, record what currency guarantee the queue
assumes in its absence.

file_scope OVERLAP IS DELIBERATE: this task shares scripts/task-lock.sh,
scripts/command-gate-in.sh and context/patterns/task-lock.md with 272. The dependency edge on 272
serializes that overlap rather than leaving it to chance.

NEW SCRIPTS: add a queue script and its test under scripts/ if research concludes one is warranted.
Name them in the plan; do not pre-commit to them here.

ACCEPTANCE. A record schema with its lifecycle states documented to the standard of the existing
session-registry contract in context/patterns/task-lock.md; finished orchestrations demonstrably
archived rather than rm -f'd, at a location agreed with task 51's relocation; queue-entry liveness
shown to consume `session_liveness()`'s verdict rather than recomputing it; the queue readable as an
admission input; a fixture test covering registered -> running -> finished -> archived and the
refusal path. Shellcheck clean per context/standards/shell-strict-mode.md. No task-number references
in deliverables outside specs/**.

---

### 274. Next-admissible-batch suggestion and alternatives-on-conflict, both computed by invoking the real admission script
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: orchestrator
- **Dependencies**: Task 272, Task 273, Task 275, Task 165

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**, a disposable deploy artifact -- see rules/source-store-deploy-boundary.md).

GOAL. The orchestration concludes by suggesting the next most natural batch of tasks to run after
clearing context, computed from the dependency DAG PLUS file_scope disjointness -- i.e. a batch that
scripts/orchestrate-batch-admit.sh would ACTUALLY ADMIT together, so the user can open a fresh
session and run it directly.

=== TWO MODES, ONE PREDICATE ===
MODE A -- NEXT-BATCH AT CONCLUSION (the original scope above): at the end of an orchestration,
suggest the next most natural batch to run after clearing context.

MODE B -- ALTERNATIVES ON CONFLICT (added): when an orchestration is REFUSED for conflicting with
an in-flight one, suggest nearby task sets that could run in parallel instead. Same predicate as
mode A, DIFFERENT TRIGGER -- refusal time rather than conclusion time. Alternatives are drawn from
the orchestration queue (task 275), which is why this task depends on it.

WHAT THE ADMISSION SCRIPT DOES AND DOES NOT GIVE YOU. scripts/orchestrate-batch-admit.sh emits a
PER-CANDIDATE verdict and, for an idle overlapping task, an `idle_overlap_advisory` naming the
colliding task, its status, the overlapping path and the collision scope. It has NO NOTION OF
ALTERNATIVES: it answers "may this candidate set run?", never "what else could run instead?".
The alternatives search is therefore a NEW CALLER-SIDE LOOP over candidate sets, NOT a change to
the script's verdict schema. Do not extend the schema to carry alternatives.

BINDING CONSTRAINT ON HOW THE SUGGESTION IS COMPUTED. The predicate must be established by ACTUALLY
INVOKING scripts/orchestrate-batch-admit.sh over candidate sets and reading its v5 verdicts --
never by re-implementing, approximating, or duplicating its logic. A second copy of the admission
predicate would drift from the real one, and a suggestion the real script then refuses is worse
than no suggestion at all. Respect the existing verdict schema and its consumers
(scripts/orchestrate-predispatch-review.sh is one) rather than extending the schema.

DEPENDENCY NOTES.
- Edge on task 275 (hard, substantive): mode B's alternatives are drawn from the orchestration
  queue, so there is nothing to draw from until 275 exists.
- The existing edge on task 272 is now TRANSITIVELY REDUNDANT, since 275 itself depends on 272.
  It is left in place deliberately -- a redundant edge is harmless and costs only a wave, whereas
  removing it would obscure why live registry scope matters to this task. Do not "clean it up".
- Edge on task 272 (hard, substantive): the suggestion is only trustworthy if the session
  registry's file_scope is LIVE rather than frozen at register time, and if a live-but-stale lock
  is visible as held. Computing a "safe next batch" against a stale registry snapshot produces
  confidently wrong suggestions -- worse than offering none.
- Edge on task 273 (hard): this suggestion is rendered by 273's conclusion stage, and both tasks
  edit skills/skill-orchestrate/SKILL.md, so the edge is footprint-corroborated as well as logical.
- Edge on task 165 (hard, substantive): 165 rules on whether an ABSENT file_scope is
  admission-relevant. That ruling directly changes which batches this task would suggest -- today a
  task with no declared scope is indistinguishable from one that provably collides with nothing, so
  a suggester built before the ruling would confidently propose batches the post-ruling script
  refuses. 165 also owns orchestrate-batch-admit.sh, this task's primary input. Per the standing
  convention, DROP THE EDGE rather than hold this task if 165 stalls -- but if it is dropped, record
  which absent-file_scope posture the suggester assumed.

ACCEPTANCE. A suggested batch is verified by running the real admission script over it and showing
every member admitted; a fixture where two candidates collide on file_scope demonstrably does NOT
appear as a joint suggestion; no copy of the admission predicate exists anywhere in the new code;
shellcheck clean per context/standards/shell-strict-mode.md. No task-number references in
deliverables outside specs/**.

---

### 273. Three-channel orchestration conclusion stage with per-channel approval, as a distinct post-postflight stage
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: orchestrator
- **Dependencies**: Task 271, Task 184

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**, a disposable deploy artifact -- see rules/source-store-deploy-boundary.md).

GOAL. Every orchestration concludes by proposing three channels of follow-on work, each fired ONLY
on that channel's own separate explicit user approval:
  (a) DIRECT FIXES to make now, executed by a final cleanup agent;
  (b) AGENT-SYSTEM CHANGES, routed to meta-builder-agent;
  (c) FOLLOW-UP TASKS to create, routed to a task agent, recorded as CHILDREN of the originating
      task via the `parent_task` edge.
No channel may fire on another channel's approval, and none may fire without one.

ANTI-BYPASS CONSTRAINT ON CHANNEL (b) -- NOT RELAXED BY THIS FEATURE. meta-builder-agent must keep
CREATING TASKS rather than editing .claude/ or the source store directly. The constraint in
commands/meta.md and skills/skill-meta/SKILL.md stands unchanged: the conclusion stage may hand it
a change request, but it still produces tasks in specs/, never implementation.

THIS MUST BE A DISTINCT POST-POSTFLIGHT STAGE WITH ITS OWN BOUNDARY CONTRACT -- NOT SMUGGLED INTO
POSTFLIGHT. context/standards/postflight-tool-restrictions.md today prohibits Edit on *.md outside
specs/ and on .claude/** non-specs, and confines postflight Bash to state-write.sh, git add/commit,
and two `rm -f` marker deletions; AskUserQuestion is likewise outside that contract.
skills/skill-orchestrate/SKILL.md:287 carries a `## MUST NOT (Postflight Boundary)` section.
Channels (a) and (b) would violate both if folded into postflight. The new stage therefore needs
its own explicitly written allowed/prohibited table in that standard, stating that it runs AFTER
postflight has closed state and committed.

=== OPEN QUESTION FOR THE RESEARCH PHASE: RECONCILE WITH TASK 184'S RULING ===
THIS MUST BE SETTLED WITH A WRITTEN VERDICT BEFORE PLANNING. The contradiction may NOT be left
standing in both task descriptions.

Task 184's ruling of 2026-09-22 states verbatim:
    "do NOT auto-create tasks: the report is the handoff and the user files them with /task"
Channel (c) as requested REVERSES that operative clause. Both candidate resolutions are live:

  RESOLUTION A -- NARROW OVERTURN. The ruling's implicit premise was that auto-creation is
  UNAPPROVED creation. Per-channel explicit approval removes that premise: user-approved creation
  is not auto-creation. On this reading 184 was right for a report-only postflight (where
  AskUserQuestion is outside the boundary contract anyway) and wrong for an interactively-gated
  post-postflight stage. 184's scope would be rewritten to match rather than left contradictory.

  RESOLUTION B -- SCOPE-LIMITED COEXISTENCE. Task 184 governs one specific payload (skeleton-plan
  sorry_inventory[].follow_up_task entries surfaced from orchestrate-cycle-postflight.sh, reported
  plus recorded in an append-only state.json field), while this task governs conclusion-stage
  follow-ups generally. The two stay distinct. Cost: two adjacent mechanisms produce follow-ups by
  two different routes, and someone reconciles them later regardless.

PRIOR ANALYSIS, RECORDED AS A RECOMMENDATION AND NOT AS THE DECISION: the /meta prompt-mode
analysis that filed this task recommended Resolution A ("overturns, narrowly"), on the grounds
stated above, and judged that the reversal should be named plainly as a reversal rather than
presented as an extension. The research phase is not bound by that recommendation and must reach
its own verdict.

DEPENDENCY NOTE. The edge on task 184 is a HARD dependency: shared footprint on
scripts/orchestrate-cycle-postflight.sh and context/standards/status-markers.md, plus the
substantive ruling conflict above. Its own dependency chain was verified CLEAR at filing time --
242, 243, 258 and 259 are all in specs/archive/ (directories
242_orchestrate_partial_with_blocker_stops_redispatch,
243_reconcile_research_handoff_writer_contract,
258_fix_postflight_recovery_decline_attribution,
259_allow_completion_on_a_gate_skipped_plan_branch), each carrying an implementation summary rather
than an abandonment note, and 266 is completed -- so nothing unresolved is inherited. Per the
standing convention, DROP THE EDGE rather than hold this task if 184 stalls.

The edge on task 271 is also hard and is NOT droppable: channel (c) creates tasks AS CHILDREN, which
is structurally impossible before the `parent_task` edge is declared, validated and rendered.
Without 271 this stage would write a field nothing reads.

ACCEPTANCE. A written verdict on the 184 reconciliation before planning begins, with the losing
resolution's rationale recorded. The stage's own allowed/prohibited table lands in
postflight-tool-restrictions.md to the same standard as the existing postflight table. Each of the
three channels demonstrably cannot fire without its own approval, covered by a test. The
meta-builder-agent anti-bypass constraint is shown still to hold for channel (b). Documented in
docs/architecture/orchestrate-state-machine.md. Shellcheck clean per
context/standards/shell-strict-mode.md. No task-number references in deliverables outside specs/**.

---

### 272. Honest session liveness for concurrent same-repo batches: diagnose why the wired heartbeat never fires, add a live-but-stale lock state, re-derive registry scope, and give each orchestration its own identity
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: orchestrator
- **Dependencies**: Task 51

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**, a disposable deploy artifact -- see rules/source-store-deploy-boundary.md).

GOAL. Let different batches of tasks be orchestrated CONCURRENTLY in different sessions of the same
repo when there is no file_scope collision and no dependency edge between them, with each
orchestration keeping distinct metadata rather than sharing one in-flight record.

THE DECISION LAYER IS ALREADY SOUND -- DO NOT REWORK IT. Measured live in ~/Projects/BimodalLogic:
scripts/orchestrate-batch-admit.sh returned a correct v5 verdict for a real candidate,
  {"decision":"defer","defer_reason":"file_scope_collision", plus colliding_task_number,
   colliding_task_status, overlapping_path, "collision_scope":"cross_batch",
   "corroborated_by":["non_terminal_status","session_registry"]}
alongside an `idle_overlap_advisory` for an idle overlapping task. The gap is the layer BENEATH
this verdict. MUST NOT modify scripts/orchestrate-batch-admit.sh -- that surface belongs to
task 165, which is already scoped to it.

=== PIECE 1 (SCOPE-DETERMINING, DO THIS FIRST): IS THE HEARTBEAT SILENCE A ROUTING REGRESSION OR A DESIGN GAP? ===

THE MECHANISM ALREADY EXISTS AND IS WIRED. DO NOT BUILD A SECOND ONE. The per-task heartbeat is
called at scripts/update-phase-status.sh:223:
    hb_out=$(bash "$tl_path" heartbeat "$task_number" "$hb_sid" 2>&1) || hb_rc=$?
seventeen lines above the `session-heartbeat` call at line 240, in the same function, with its own
`_hb_trace "heartbeat" "$hb_verdict"` verdict line and its own no-op classifier (`no-lock`,
`session-mismatch`, `unknown`). It is invisible to a naive grep only because the script path is
held in the variable "$tl_path". An implementer who believes the mechanism is missing will build a
redundant second one alongside it.

MEASURED EVIDENCE (the function writes ${repo_root}/.agent-logs/heartbeat-trace.log):
  ~/Projects/BimodalLogic: 580 trace lines, 580 of them `heartbeat ok`, covering 26 task numbers
      -- ALL from EARLIER sessions.
  ~/.config/nvim:          2740 trace lines, 2723 `ok`, 15 `noop:no-entry`, 2 `noop:no-holder`.
  BUT: ZERO trace lines for EITHER in-flight task of the currently-running BimodalLogic session --
      neither the modal-substrate task (lock acquired 2026-09-29T14:57:11Z) nor the Typst
      lean-code-environment task in that same session produced a single line, despite eleven
      phase-completion commits having landed for the former.
  AND: its .lock/holder.json shows acquired_at == heartbeat_at == 2026-09-29T14:57:11Z exactly, so
      `never_heartbeated=true` is literal, not approximate.
  AND: the `noop:session-mismatch` verdict exists in the classifier but appears ZERO times in
      either repo's log -- so the no-op paths are NOT absorbing these calls. The function is not
      being ENTERED at all.

WHY THIS ORDERING MATTERS. The silence is SESSION- or DISPATCH-PATH-scoped, not task-scoped: two
in-flight tasks in one session both traced zero while every earlier session traced cleanly. Cadence
therefore cannot explain it for either task. A routing regression in the currently-running
orchestrate loop is a SMALL fix; a design gap is not. ESTABLISH WHICH BEFORE SCOPING THE REST OF
THIS PIECE. Secondary and genuinely real regardless of that answer: the heartbeat is reachable only
via a phase-status change, so a task sitting in one long phase emits nothing between transitions --
close that with a time-based or dispatch-boundary trigger. Also consider consuming the `_hb_trace`
verdicts, which are written today and read by nothing.

=== PIECE 2: A THIRD LOCK STATE FOR STALE-HEARTBEAT-BUT-PID-ALIVE ===
Observed live: `task-lock.sh check <N>` reported `held-stale session=... heartbeat_age_min=33
threshold_min=30 never_heartbeated=true` while `session-list` reported that SAME session
`live:true, liveness_reason:"pid-alive"` (pid 1015099). cmd_acquire's held-lock overlap pass
degrades to WARN-and-proceed on a stale lock, so a lock belonging to a demonstrably LIVE session
became advisory purely because its heartbeat drifted. Decide whether stale-but-pid-alive should be
a THIRD state distinct from both `held` and `held-stale`, and implement the ruling.

PRECEDENT TO REUSE, NOT TO INVENT AROUND. The distinction piece 2 needs ALREADY EXISTS one level
up: `session_liveness()` computes six reasons -- `corrupt`, `dead-pid`, `dead-pid-within-grace`,
`stale-heartbeat`, `pid-alive`, `undeterminable` -- governed by two thresholds
(SESSION_REGISTRY_DEAD_PID_MIN, SESSION_REGISTRY_REAP_MIN) in a documented evaluation order, and
its own header records that it was factored out so cmd_session_list and session_contention()
consume the IDENTICAL verdict rather than a second transcription. THE GAP IS THAT THE PER-TASK
LOCK HAS NO SUCH DISTINCTION: cmd_check emits only `held-fresh` (line 1033) and `held-stale`
(line 1036), each carrying heartbeat_age_min, threshold_min and never_heartbeated but NO
pid-liveness dimension at all. So piece 2 is bringing an existing, tested session-level vocabulary
down to the per-task lock -- a smaller and better-shaped change than inventing a third state from
scratch. Consume `session_liveness()`'s verdict; do not transcribe it.

CRITICAL CONSTRAINT -- KEY ON session_id, NEVER ON pid. Task 165's absorbed text records that both
sessions in its incident reported the SAME pid with pid_source `ancestor-claude`, because two
/orchestrate runs inside one Claude Code process share an ancestor. The failing task's own
holder.json likewise shows pid_source `ancestor-claude`. A self-exclusion keyed on pid would treat
a foreign session as self and silently disable cross-session detection for the most common case.

=== PIECE 3: RE-DERIVE THE REGISTRY'S file_scope ON HEARTBEAT ===
scripts/command-gate-in.sh:106 registers the session with a task-number CSV, and the union
file_scope is computed AT REGISTER TIME ONLY; `session-heartbeat` refreshes heartbeat_at and
nothing else. So widening a task's file_scope after registration leaves the registry snapshot
permanently narrow. Observed live: the registered scope lacked
FormalSystem/Metalogic/Decidability/PlusWitnessFamily/Incompleteness.lean, which that task's
state.json file_scope does declare. Decide whether the registry should re-derive on heartbeat and
implement it.

=== PIECE 4 HAS MOVED OUT OF THIS TASK ===
Per-orchestration identity (an orchestration-id distinct from session_id, with per-orchestration
metadata/artifacts/return-meta rather than one shared in-flight record) was originally piece 4 of
this task. It now lives IN FULL in task 275, the per-repo orchestration queue, which DEPENDS on
this task. Do not implement it here. This task is pieces 1-3 only: diagnose the unreachable
heartbeat, add the live-but-stale lock state, re-derive registry scope on heartbeat.

DEPENDENCY NOTE. The edge on task 51 is substantive, not merely footprint serialization: 51
relocates the per-session orchestration runtime files (specs/.orchestrator-multi-state-*.json,
specs/.return-meta-multi-*.json) that Piece 4's per-orchestration metadata extends, and it owns the
same two files this task edits (scripts/task-lock.sh,
context/standards/orchestrator-runtime-files.md). Building Piece 4 before 51 lands risks creating
exactly the fourth orphaned naming generation that 51's own text warns against.

ACCEPTANCE. Piece 1's routing-regression-versus-design-gap question answered in writing before any
fix lands, with the answer visible in the trace log or an equivalent probe. A fixture test
reproduces the two-live-sessions overlap case and the stale-but-pid-alive case, and fails against
the current scripts. No change to orchestrate-batch-admit.sh. Existing consumers of task-lock.sh's
output lines (which read them as prefixes/substrings) keep working. Shellcheck clean per
context/standards/shell-strict-mode.md. No task-number references in deliverables outside specs/**.

---

### 271. Finish the parent_task edge: declare it in the schema, validate it, render it in TODO, and make it survive renumbering
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: orchestrator
- **Dependencies**: Task 269, Task 279

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**, a disposable deploy artifact regenerated by the loader -- see rules/source-store-deploy-boundary.md).

GOAL. Finish the `parent_task` edge so that follow-up and spawned tasks can be recorded as CHILDREN of their originating task, as a parent/child relation DISTINCT from the existing `dependencies[]` array.

THIS IS NOT GREENFIELD -- IT IS A HALF-BUILT FIELD WITH TWO PRODUCERS AND ZERO CONSUMERS. Verified in the source store:
  PRODUCERS (already write it):
    - skills/skill-spawn/SKILL.md:380  ("parent_task": $parent)
    - commands/task.md:833             (/task --review follow-up creation)
    plus declared intent in commands/spawn.md:117, agents/spawn-agent.md:176,195
      (as `parent_task_number`), context/orchestration/delegation.md:657,673
  CONSUMERS (all absent -- measured, 0 occurrences each):
    - context/schemas/state-schema.json          0  (field is written but UNDECLARED)
    - scripts/validate-state.sh                  0  (no orphan/cycle checking)
    - scripts/generate-todo.sh                   0  (invisible in TODO.md)
    - context/reference/state-management-schema.md 0 (undocumented)
  NOT A CONSUMER DESPITE APPEARANCES: scripts/generate-task-order.sh has 10 "parent" hits, but
  they are union-find / graph-parent identifiers (lines 459, 464-468, 479, 486) plus two display
  strings ("indented = depends on parent", lines 513 and 881). None reads `parent_task`.

NO MIGRATION BURDEN. Live count of entries carrying `parent_task` in this repo: 0, across both
`active_projects` and `completed_projects`. There is no legacy population to backfill, which makes
this a clean moment to declare the field properly rather than after it has accumulated data.

PREMISE CORRECTION (added after the paragraph above; that paragraph is REPO-LOCAL and does not
generalize). The "live count 0 / no legacy population to backfill" finding holds for THIS
repository only. In the BimodalLogic consumer repo, SIX active entries carry `parent_task: 165`
-- 410, 411, 412, 428, 429 and 430 -- recording real expansion lineage (which task each was split
from). So a deployed consumer repo DOES have a population, and two consequences follow for the
work items above:
  - Work item (2)'s orphaned-parent and cyclic-parentage checks must be designed against a real
    population, not a greenfield one. Note in particular that `parent_task: 165` points at a task
    that is itself still active in that repo, and that four of the six children are `not_started`
    while 428 is `blocked` -- so the checks will encounter live, mid-lifecycle parentage, not just
    settled history.
  - The "clean moment to declare the field properly rather than after it has accumulated data"
    framing no longer applies globally: the data has already accumulated somewhere the loader
    deploys to. Decide whether declaring the field needs an accompanying consumer-side backfill or
    validation pass, and whether an entry whose `parent_task` points at an ARCHIVED or renumbered
    task is an error, a warning, or expected.
Evidence gathered read-only from that repo; it is a separate repository with its own task system
and is not an edit target for this task.

RELATED, SEPARATELY TRACKED. `parent_task` is one of NINE state-schema.json validation failures in
that same consumer repo (`validate-state.sh`: 8 passed, 13 warnings, 9 failed). The other eight
fields -- top-level `active_goal`, `artifacts`, `last_updated`, `metadata`, and entry-level
`blockers`, `previous_status`, `researched`, `resume_phase` -- are ruled on by their own task,
which deliberately EXCLUDES `parent_task` because this task already owns it. That task sets a
per-field widen/migrate/retire policy and a hard constraint that no non-null value may be deleted
without recording where the information went; this task's work item (1) should follow that policy
rather than deciding independently. The two tasks share state-schema.json and validate-state.sh in
their file_scope, so whichever lands second must re-read both files.

WORK ITEMS.
(1) Declare `parent_task` in context/schemas/state-schema.json and document it in
    context/reference/state-management-schema.md, stating explicitly that it is NOT a dependency
    edge: a parent may complete before its children, and parentage must never affect dispatch
    eligibility or the Kahn-algorithm dependency waves.
(2) Add orphaned-parent and cyclic-parentage checks to scripts/validate-state.sh. Follow the
    ADVISORY-FIRST precedent recorded at plan-format.md:259-266 (the Verification Tier rollout):
    a missing or dangling value emits a warning rather than an error, `--strict` enforces, and the
    PROMOTION CRITERION is written down at the same time as the check.
(3) Decide what scripts/generate-task-order.sh and scripts/generate-todo.sh render for parentage.
    CONSTRAINT: generate-task-order.sh's existing indentation already means "depends on parent" in
    the DEPENDENCY sense (its own display strings say so). Parentage rendering must not collide
    with or be mistaken for that. Consider whether parentage belongs in the Task Order tree at all
    versus the per-task TODO.md entry.
(4) Settle renumber survival. scripts/deprecated/vault-operation.sh step 5 renumbers active tasks
    by subtracting 1000 and rewrites `dependencies`, but nothing anywhere handles `parent_task`, so
    a renumber would silently dangle every parentage edge. PRIOR QUESTION TO ANSWER FIRST: that
    script lives under scripts/deprecated/, so establish whether renumbering is a live path at all
    before writing code for it. If it is dead, say so and record that parentage stability rests on
    numbers never being rewritten; if it is live, fix it.

DEPENDENCY NOTE. The edge on task 269 is a FOOTPRINT-SERIALIZATION edge only, on
scripts/validate-state.sh, not a substantive dependency: 269 is a one-line null-safety fix
(presence test -> type test) in that same file. Per the standing convention, DROP THE EDGE rather
than hold this task if 269 stalls.

ACCEPTANCE. The field is declared in the schema and documented; validate-state.sh detects an
orphaned parent and a parentage cycle, advisory-first with a written promotion criterion; the TODO
rendering decision is recorded with its rationale (including a decision NOT to render, if that is
the ruling); the renumber question is answered either way in writing; shellcheck clean per
context/standards/shell-strict-mode.md. No task-number references in deliverables outside specs/**.

RENDERER QUIRK TO FOLD IN (observed 2026-09-29, not a separate task). The Task Order tree
already renders the string "parenttask" -- the underscore stripped by generate-task-order.sh's own
truncation path -- while state.json and the TODO.md task heading both hold "parent_task" correctly.
This is a pre-existing defect in the very script this task is scoped to touch, so fix it as part of
the rendering work item rather than filing it separately.

---

### 270. Re-runnable null-safety audit of jq mutation sites across core scripts, then decide whether a shared guard idiom belongs in scripts/lib/
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: file-scope-lifecycle
- **Dependencies**: Task 269

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/** (never .claude/**), per rules/source-store-deploy-boundary.md.

WHY THIS IS SEPARATE FROM THE VALIDATE-STATE FIX. The sibling task repairs one mutation site. This task establishes whether that site was an isolated slip or an instance of a systematic pattern, and leaves behind a mechanism so the answer stays true. The signature to hunt is a REPORT-GUARDED / WRITE-UNGUARDED SPLIT: a read/report filter that correctly null-guards a field with `// []`, paired with a mutation filter over the same field that tests only for KEY PRESENCE via `has("...")` and then iterates with a bare `.[]`, `reduce`, or `map`. `has()` is true for a literal-null value, so the pairing is silently unsafe on exactly the data the report filter was written to tolerate.

STARTING INVENTORY (gathered during triage; VERIFY rather than trust -- the corpus moves, and this list was not produced by a tool that can be re-run). Every file_scope mutation site outside the sibling task's already-identified one appeared null-safe on first pass, which is the outcome that makes a re-runnable check valuable rather than redundant:
  - scripts/orchestrate-predispatch-review.sh, circa lines 421 and 430, uses the EXPLICIT form `has("dependencies") and .dependencies == null` / `has("file_scope") and .file_scope == null` and then assigns `[]`. This is correct and deliberate -- it is a null-to-empty repair, not a dedup, and it must keep distinguishing null from absent. Do not "simplify" it into a type test; a type test would change its meaning.
  - scripts/update-task-status.sh, circa lines 704 and 775, uses `((. // []) + $add | unique)`. Null-safe. Note it uses `unique` deliberately, on a DIFFERENT contract from the order-preserving D3 dedup -- do not unify the two.
  - scripts/backfill-file-scope.sh, circa line 234, uses `((.file_scope // []) + $updates[...] | unique)`. Null-safe.
  - scripts/orchestrate-batch-admit.sh, circa lines 547 and 570, uses `(($e.file_scope // []) | length)`. Null-safe.
  - scripts/task-lock.sh, circa line 1380, slurps with `add | unique`. Check its behavior on a null element, not merely on an empty input.
  - scripts/orchestrate-cycle-postflight.sh, circa line 1059, pipes `jq 'length'` over a file_scope JSON value. `length` on null yields 0 rather than aborting, so this is safe today -- but record WHY it is safe, because that safety is incidental to jq's semantics rather than intentional in the code.
Extend the sweep past file_scope to every array-valued field that can legitimately be null or absent in practice -- dependencies, artifacts, memory_candidates, modified_files, and any state.json or errors.json field with the same exposure.

DELIVERABLE 1 -- A RE-RUNNABLE CHECK, NOT A ONE-TIME SWEEP. A prose findings list decays immediately. Add a check script alongside the existing repo-health lints (scripts/check-task-references.sh, check-runtime-file-tracking.sh, check-extension-docs.sh are the shape and exit-code convention to follow) that flags the presence-vs-type asymmetry mechanically. The hard part is the false-positive rate: a bare `has("x")` is entirely legitimate as a shape ASSERTION (scripts/validate-return-meta.sh circa line 216 pairs it WITH a type test, which is the correct idiom; the test suites under scripts/tests/ use it as an assertion throughout). Flag only the dangerous pairing -- presence test guarding an ITERATION -- and give the check an explicit, documented exemption mechanism for the deliberate null-vs-absent discriminators named above, so the check can be run at full strength without maintainers learning to ignore it. Register the new script in docs/reference/utility-scripts-inventory.md.

DELIVERABLE 2 -- DECIDE, WITH A RECORDED RATIONALE, WHETHER A SHARED GUARD IDIOM BELONGS IN scripts/lib/. A genuine decision, not a foregone conclusion: if the audit finds the single already-known site, a helper is over-engineering and the check script plus a documented idiom is the proportionate answer. If it finds several, scripts/lib/file-scope-overlap.sh is the precedent to follow -- it already exports jq `def` source text as FILE_SCOPE_OVERLAP_JQ_DEFS via a quoted heredoc for splicing into callers' own jq programs, and its header records exactly why that shape beat a standalone .jq file. A dedup/guard def could ride the same mechanism. Record the decision either way so a future reader does not re-litigate it.

RELATED, DELIBERATELY NOT MERGED. scripts/orchestrate-cycle-postflight.sh's modified_files-vs-file_scope excursion check (circa lines 1053-1069) is detection-only, emitting a stderr advisory where it should be an enforcement gate. That is a genuine follow-on but a DIFFERENT defect class -- advisory-vs-blocking, not null-safety -- and it was recorded separately. Touching the same file is not a reason to bundle it. If the audit turns up null-safety problems inside that same excursion block, fix those here and leave the enforcement-gate question to its own task.

=== ADDITIONAL EVIDENCE (2026-09-30, ~/Projects/Logos/Verification, session sess_1790791567_96a2e0) ===
A LIVE ABORT FROM THIS DEFECT CLASS, AT A SITE THIS TASK'S INVENTORY DID NOT SURVEY, PLUS A
CORRECTION TO ONE OF THAT INVENTORY'S SAFETY CLAIMS.

SITE: scripts/orchestrate-build-dispatch.sh:389-392, the Prior Decisions read path over
specs/{NNN}_{slug}/.decisions.json.

MECHANISM (observed, not derived). An /orchestrate lead wrote .decisions.json as an OBJECT
wrapper, {"decisions":[...]}, rather than the flat array the schema in
docs/architecture/handoff-schema.md's "Decisions File Schema" section requires. Then:
  - line 389: `jq 'length'` over the file returned 1 -- the KEY count of an object, not an
    element count -- which passed the `-gt 0` gate on line 390;
  - lines 391-392: `.[] | "... \(.question) ..."` iterated the object's VALUES, yielding the
    inner array, and indexing that array with a string aborted jq:
    `jq: error (at <stdin>:13): Cannot index array with string ("timestamp")`.
Line 389 carries `2>/dev/null || decisions_count=0`; line 391 carries NO guard, so the abort
propagated and the script exited 5.

BLAST RADIUS -- AN ADVISORY SECTION BLOCKED DISPATCH ENTIRELY. Prior Decisions is context
enrichment, not a gate. Yet orchestrate-cycle-plan.sh reported only
`orchestrate-build-dispatch.sh failed; deferring to a later cycle` and deferred the task on two
consecutive cycles (2 and 3 of a five-cycle run), consuming work-cycle budget for zero work,
with nothing in either the plan JSON or stderr naming the malformed file or the expected schema.
Worth weighing as part of DELIVERABLE 2: a type-guard that degrades to "omit the section" would
have turned this abort into a warning.

CORRECTION TO THIS TASK'S STARTING INVENTORY. That inventory records of
scripts/orchestrate-cycle-postflight.sh circa line 1059: "pipes `jq 'length'` over a file_scope
JSON value. `length` on null yields 0 rather than aborting, so this is safe today -- but record
WHY it is safe, because that safety is incidental to jq's semantics rather than intentional in
the code." The incidental safety is NARROWER than stated. `length` is total over null and over
objects alike, and on an object it returns a POSITIVE key count. A `length`-based gate therefore
establishes NEITHER emptiness NOR type, and is unsafe for any value that could arrive
object-shaped. The postflight site is safe only because its producer is jq-generated and cannot
hand it an object; record that as the reason, not `length` itself.

SIGNATURE TO ADD TO DELIVERABLE 1's HUNT. Alongside the has()-presence-vs-iteration pairing,
flag COUNT-GUARDED / TYPE-UNGUARDED iteration: any `length`-or-count gate followed by `.[]`,
`map`, or `reduce` over a value whose type was never asserted. The correct idiom is an explicit
type test (`jq -e 'type == "array"'`) before iterating, never a count. Extend the sweep beyond
state.json and errors.json to the other lead- and agent-authored JSON the orchestrator reads:
.decisions.json, .return-meta.json, .orchestrator-handoff.json, .drift-inspection.json -- these
are hand- or agent-written, so unlike jq-generated values they can legitimately arrive
object-shaped, which is exactly the exposure `length` does not cover.

SCOPE NOTE. This is the type-safety half only. The companion defects at the same site -- that
.decisions.json has a documented writer but no writer script, and that its schema lives in a
different file from the Move 4 instruction to write it -- are an authoring-surface gap rather
than a jq guard, and are recorded on their own task.

---

### 269. validate-state.sh --fix: replace the presence test with a type test so a null file_scope cannot abort the repair
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: file-scope-lifecycle
- **Dependencies**: None
- **Research**: [269_validate_state_fix_null_file_scope_crash/reports/01_null-file-scope-fix-crash.md]
- **Plan**: [269_validate_state_fix_null_file_scope_crash/plans/01_null-file-scope-fix-crash.md]
- **Summary**: [269_validate_state_fix_null_file_scope_crash/summaries/01_null-file-scope-fix-crash-summary.md]

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/scripts/validate-state.sh (never .claude/**). The deployed copy at a consumer repo's .claude/scripts/validate-state.sh was confirmed byte-for-byte identical (diff -q) and is listed in .claude-extensions.json's installed_files under the core extension, so it is a deploy artifact only -- fix at source and redeploy, per rules/source-store-deploy-boundary.md.

CONFIRMED DEFECT, ALREADY MECHANICALLY REPRODUCED. `validate-state.sh --fix` aborts with `jq: error (at <stdin>:1): Cannot iterate over null (null)` on any state.json holding an active_projects entry whose file_scope is literal null. Net effect: --fix REPORTS its findings correctly and then repairs NOTHING, because state-write.sh sees the jq transform fail and correctly refuses the write. The refusal is working as designed; the defect is strictly upstream of it.

ROOT CAUSE -- A PRESENCE-TEST vs TYPE-TEST ASYMMETRY BETWEEN TWO FILTERS THAT MUST AGREE. Inside the --fix block, the report filter (circa line 305) is correctly null-guarded with `($t.file_scope // []) as $fs`, but the mutation filter handed to state-write.sh (circa line 322) is not:

  .active_projects = [.active_projects[] | if has("file_scope") then .file_scope |= (reduce .[] as $x ([]; if index($x) then . else . + [$x] end)) else . end]

`has("file_scope")` returns TRUE when the value is literal null, because the KEY exists. The reduce then iterates over null and jq aborts. Reproduction:

  $ echo '{"active_projects":[{"project_number":1,"file_scope":null}]}' | jq -c '.active_projects = [.active_projects[] | if has("file_scope") then .file_scope |= (reduce .[] as $x ([]; if index($x) then . else . + [$x] end)) else . end]'
  jq: error (at <stdin>:1): Cannot iterate over null (null)

The type-test form is correct and idempotent, leaving null-valued and absent entries byte-identical:

  $ echo '{"active_projects":[{"project_number":1,"file_scope":null}]}' | jq -c '.active_projects = [.active_projects[] | if (.file_scope|type) == "array" then .file_scope |= (reduce .[] as $x ([]; if index($x) then . else . + [$x] end)) else . end]'
  {"active_projects":[{"project_number":1,"file_scope":null}]}

INVARIANTS THE FIX MUST PRESERVE (all three are load-bearing and documented in the comment block above the filter):
  1. D3 order-preserving dedup. jq's `unique` SORTS and must not be substituted for the reduce.
  2. The filter must never introduce a `file_scope: []` field on an entry that never had one. A type test satisfies this for free: a null-valued entry keeps its null, an absent-key entry stays absent.
  3. Idempotence -- an entry whose file_scope already has no duplicates is left byte-identical.
Update that comment block too: it currently explains and endorses the `has("file_scope")` form, so leaving it in place would re-document the defect.

REGRESSION TEST. scripts/tests/test-validate-state.sh already carries a --fix fixture block (FIX_FIXTURE_DIR, circa line 600) and is the natural home; do not add a new test file. The fixture must drive a null-bearing state.json through --fix end to end and assert (a) exit status is success, (b) genuinely duplicated file_scope arrays elsewhere in the same fixture were actually deduplicated -- proving the write landed rather than merely that nothing crashed, and (c) the null-valued and absent-key entries are untouched, still null and still absent respectively. Note the existing suite already probes `has("file_scope")` on fixtures at test-validate-state.sh circa line 807 as an ASSERTION about state shape; that usage is legitimate and is not what this task changes.

PROVENANCE. Encountered live during an /orchestrate implement dispatch. Five projects in the ~/Projects/BimodalLogic consumer repo's specs/state.json currently carry literal-null file_scope, so the crash triggers there today. That dispatch worked around it with an equivalent project-scoped null-safe filter applied through state-write.sh and deliberately did NOT hand-patch the deployed copy. The broader missing-or-null file_scope visibility class in that repo is 28 entries -- a different and larger set than the null-valued subset; do not conflate the two figures. The --fix block's Check 8/9 lineage traces to the completed task that surfaced missing and empty file_scope in validate-state.sh and orchestrate-predispatch-review.sh.

---

### 268. Lake build guard false green scope key
- **Status**: [IMPLEMENTING]
- **Task Type**: general
- **Topic**: core-agent-system
- **Dependencies**: None
- **Research**: [268_lake_build_guard_false_green_scope_key/reports/01_false_green_scope_key_defect.md]
- **Plan**: [268_lake_build_guard_false_green_scope_key/plans/01_cross-tree-guard-state-clone.md]

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/scripts/lake-build-guard.sh (never .claude/**).

REPORTED DEFECT. During a multi-task /orchestrate run in the BimodalLogic repository, a Lean implementation agent observed lake-build-guard.sh replay a stale result across a differently-scoped build: it reported 'Build completed successfully (1200 jobs)' while writing no .olean for the module actually requested. The agent worked around it by passing --no-share on every subsequent build, and all of its later builds were genuine. A false green is the dangerous direction of wrong for this guard: it would let a broken module pass a gate that believes it built.

DO NOT ASSUME THE DEFECT IS REAL -- REPRODUCE FIRST. The scope_key result-sharing condition that would prevent exactly this replay is ALREADY IMPLEMENTED in the guard and predates the observation. See decide_sharing(), whose scope condition is labelled 'Defect B' and reads: a missing or empty recorded scope_key is treated as NOT shareable (fail closed); and compute_scope_key(), which hashes the invocation's lake argument vector with a NUL-separated sha256. The STALENESS POLICY header block states the five sharing conditions, of which scope_key is condition 3. So this is not simply the known defect recurring.

DETERMINE WHICH OF THESE HOLDS:
(a) compute_scope_key has a residual normalization gap that lets a scoped build (lake build Foo.Bar) and a full build (lake build) hash to the same key -- e.g. argument-vector construction differing between the two call paths before hashing, so the guard believes the scopes match when they do not;
(b) the observed replay came from a record written before scope_key existed, and the documented fail-closed branch did not actually fire -- i.e. get_record_field returning something non-empty for an absent key, or the record being read by a path that bypasses decide_sharing;
(c) the report was a misdiagnosis and some other mechanism produced the appearance of a successful build with no .olean written.

(d) MOST LIKELY EXPLANATION FOR A WORKTREE-HOSTED OBSERVATION -- CROSS-TREE RECORD REPLAY VIA THE cp -al CLONE. Identified with direct source evidence after the original report, and NOT covered by (a), (b) or (c). agent-system/extensions/core/scripts/dispatch-worktree.sh hardlink-clones .lake/ into every dispatch worktree: `if [ -d "$PROJECT_ROOT/.lake" ]; then cp -al "$PROJECT_ROOT/.lake" "$worktree_path/.lake"; fi`, immediately after the same treatment of .claude/ (`cp -al "$PROJECT_ROOT/.claude" "$worktree_path/.claude"`). Because `cp -al` creates HARDLINKS, the worktree and the main tree share the SAME INODE for .lake/build-guard.result, .log, .lock, .stdout and .stderr -- they are one file under two paths, not two files. The guard's own replay policy in decide_sharing() keys on state, post-build fingerprint, scope_key and age, and has NO notion of WHICH TREE produced the record. So a build run inside a dispatch worktree can LEGITIMATELY satisfy all five documented sharing conditions against a record written by the main tree, and replay it -- reporting exit_status=0 for a module that never compiled and for which no .olean was written in that tree. This is consistent with the original report in every detail and explains it WITHOUT requiring any scope_key bug, which matters because the scope_key condition it would otherwise have to implicate was already implemented and fail-closed before the observation.

Corroborating detail from the same /orchestrate run of task 703: --no-share had to be passed on EVERY build after the first, which is the signature of a shared record being replayed rather than of a per-invocation scoping error.

PROPOSED FIX FOR (d), either:
  - exclude build-guard.* from the `cp -al` clone in dispatch-worktree.sh (clone .lake/ but not the guard's own state files), or
  - include TREE IDENTITY in the written record and in the share decision -- `git rev-parse --show-toplevel`, or the `--git-common-dir` relationship -- so a cross-tree record is never replayable.
Prefer whichever keeps the guard's record format forward-compatible; if tree identity is added to the record, decide explicitly what an OLD record with no tree-identity field means, and fail closed on it (the same posture the scope_key condition already takes for a missing key).

--no-share MUST NOT remain the only defence. It depends on every caller remembering to pass it, and in the observed run every build after the first had to -- that is a workaround the system imposed on an agent, not a guarantee the system provides.

If (a), (b) or (d), fix at source and add a regression test under agent-system/extensions/core/scripts/tests/ covering the scoped-vs-full collision directly. If (c), record the real cause; a false-green report against this guard should not be left unexplained.

REPRODUCTION ENVIRONMENT. This repository contains no Lean project (no lakefile.toml anywhere under it), so the guard cannot be exercised end to end here. Reproduction needs a real Lean project with a lake build; ~/Projects/BimodalLogic is where the observation occurred and is the natural harness. Treat that checkout as read-only test fixture: land no change there, and note it is a separate repository with its own task system.

Note the guard is deployed into consumer repositories at .claude/scripts/lake-build-guard.sh. Never hand-patch a deployed copy -- fix the source above and redeploy, per the source-store/deploy-boundary rule.

REPRODUCTION IS AVAILABLE, AND FOR MECHANISM (d) NEEDS NO LEAN AT ALL. The named harness (~/Projects/BimodalLogic) is available and remains the right fixture for any end-to-end check -- still read-only, still a separate repository with its own task system, land nothing there. But (d) is reproducible in this repository with no Lean project whatsoever: create two git worktrees, `cp -al` a .lake/ directory between them, and make two guard invocations -- one writing a record from the first tree, one reading it from the second. Assert the second does not replay. That makes a regression test for (d) cheap and hostable under agent-system/extensions/core/scripts/tests/ (test-lake-build-guard.sh and test-dispatch-worktree.sh both already exist), which removes the reproduction blocker this task was otherwise gated on. Establish (d) or rule it out this way BEFORE investing in an end-to-end Lean reproduction for (a) or (b).

FILE FOOTPRINT NOTE: this task's file_scope is currently null, and mechanism (d)'s fix targets agent-system/extensions/core/scripts/dispatch-worktree.sh in addition to lake-build-guard.sh. dispatch-worktree.sh is ALSO the edit target of the separately-tracked `land`/release silent-data-loss task (the `nothing_to_land` verdict released a dirty worktree). The two edits sit in different functions -- `provision`'s clone here, `land`/release handling there -- but admission cannot serialize them while this file_scope stays null, so whichever lands second must re-read the file. Setting this task's file_scope at planning time would make that serialization automatic.

---

### 265. Run Gate 8 in parallel inside verify-deploy.sh via run-all.sh --jobs
- **Status**: [PLANNED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 266
- **Research**: [265_parallelize_gate8_shell_test_suite/reports/01_gate8-parallel-and-inline-verify.md]
- **Plan**: [265_parallelize_gate8_shell_test_suite/plans/01_gate8-jobs-and-inline-verify.md]

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**).

=== WHAT TO CHANGE ===
scripts/verify-deploy.sh line 558 (gate8) currently invokes the shell test suite with no --jobs:

  run_all_output=$(cd "$TARGET" && bash "$TARGET/agent-system/extensions/core/scripts/tests/run-all.sh" --quiet 2>&1)

so it inherits run-all.sh's JOBS=1 default and runs fully sequentially. Make Gate 8 use the
opt-in parallelism that already exists in run-all.sh.

=== MEASURED FACTS (already committed, do not re-measure from scratch) ===
- Gate 8 alone costs ~9m21s of an ~11m03s full verify-deploy.sh run (~86% of the run).
- The shell-test-suite parallelism task added opt-in `--jobs N|auto` to run-all.sh, with a
  JOBS_CAP (4), longest-first scheduling, deterministic output ordering, and a nested-invocation
  guard that forces JOBS=1 when run-all.sh is reached from inside a suite that itself calls
  verify-deploy.sh (see run-all.sh header lines 34-140). Measured 449s -> 187s at --jobs 4 (58%
  reduction) with an identical pass/fail set to --jobs 1.

=== WHY THIS MECHANISM AND NOT THE OTHER ONE (record this reasoning) ===
The sibling redundant-verify-passes task attacked the same cost differently: capture Gate 8 ONCE
per redeploy checkpoint and share the snapshot across the pre/post/confirm passes. That was
REJECTED in its Phase 1 precondition audit because Gate 8 is NOT invariant across a
deploy-headless.sh call -- 41 of 73 files under scripts/tests/ prefer the DEPLOYED copy of their
subject-under-test over the source-store copy, so a pre-deploy snapshot and a post-deploy
snapshot are legitimately measuring different things. The rejected design and its evidence are
recorded in context/patterns/batch-orchestration-guardrails.md; read it before proposing
anything snapshot-shaped here.

Making each Gate 8 run FASTER requires no invariance premise at all, so it sidesteps the exact
reason the sharing design failed. That is the justification for this task existing, and it
should survive into the plan's rationale section.

=== CRITICAL DEPENDENCY TO RESOLVE, NOT ASSUME ===
Parallel-run safety is NOT yet empirically established. The parallelism task's Phase 6 was the
flakiness decision gate -- 3 repeated full-suite runs at --jobs 4, checked against Phase 1's
recorded baseline pass/fail set and against a named set of load-sensitive suites -- and it did
NOT complete: it was interrupted by genuine system-wide memory pressure. That task remains
PARTIAL with Phases 6 and 7 outstanding, and the user has chosen NOT to resume it for now.

Therefore this task must choose ONE of:
  (a) carry that 3-run validation itself, as an explicit EARLY phase that gates every later
      phase, before line 558 is touched at all; or
  (b) declare a hard dependency on the parallelism task's Phase 6 completing.

DECIDE THIS IN RESEARCH/PLANNING. Do not pre-decide it, and under no circumstances change
line 558 on unvalidated parallel safety. No dependency edge is recorded on this task's
`dependencies` field precisely because recording one would pre-decide option (b).

=== ALSO SETTLE ===
- What job count Gate 8 should request: a fixed N, `auto`, or inherit from an env var. Note that
  `auto` resolves to nproc capped at JOBS_CAP=4 (run-all.sh:121-130).
- Whether an environment override is needed for CI or low-memory hosts, and if so its name,
  precedence, and documented default.
- The load-sensitive suites named by the parallelism task's Phase 4 audit -- carry that list
  forward rather than rediscovering it.
- That test-run-all-parallel.sh's own timing assertions were ALREADY redesigned from absolute
  thresholds to load-tolerant relative ratios after flaking under ambient host load. Do not
  regress them to absolute timings, and do not read a ratio-based assertion as a weakened one.
- Interaction with run-all.sh's nested-invocation guard: verify-deploy.sh IS reached from inside
  some suites, so confirm the guard still forces JOBS=1 on those paths and that the new call site
  does not defeat it.

=== VERIFICATION ===
1. The pass/fail set under the new invocation is IDENTICAL to the sequential baseline set. Report
   both sets, not just a count.
2. Report before/after wall times for a full verify-deploy.sh run (no --skip-slow), measured on
   the same host.
3. --skip-slow still skips Gate 8 entirely (verify-deploy.sh:551) -- unchanged.
4. The deploy-consumer and missing-run-all.sh branches (verify-deploy.sh:553-556) are unchanged.
5. scripts/tests/ passes, including test-deploy-verify-wiring.sh,
   test-verify-deploy-gate-selection.sh, and test-run-all-parallel.sh. No test may be weakened,
   skipped, or deleted to make the change pass.


=== ABSORBED 2026-09-28 (path review, fifth pass) from former task 267 (suppress_inline_verify_in_deploy_headless); that task is abandoned into this one. Its text follows verbatim; where it names "the dependency task" or "the sibling task", read this task's other sections. ===

SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**).

=== THE REDUNDANCY ===
scripts/deploy-headless.sh runs its OWN inline verification after deploying ("Verifying deploy
(fast gates; shell test suite deferred)") -- a `verify-deploy.sh --skip-slow` pass, measured at
~1m35s (deploy-headless.sh:402 `local -a VERIFY_ARGS=(--skip-slow)`, invoked at :406).

When deploy-headless.sh is called from scripts/orchestrate-cycle-plan.sh's Inter-Cycle Redeploy
Checkpoint, the checkpoint then runs its OWN pre/post/confirm verify-deploy.sh passes. The inline
pass is duplicated work on that path.

=== THIS WAS ALREADY EVALUATED AND DEFERRED -- CONFRONT THE REASONS, DO NOT REPEAT THEM ===
The redundant-verify-passes task explicitly considered this and ruled it OUT OF SCOPE for two
stated reasons. Both are real and both must be answered here, not rediscovered:

1. deploy-headless.sh was not in that task's declared file_scope. (Procedural only -- it IS in
   this task's file_scope.)
2. Its exit-3 contract has many callers that depend on it. Exit 3 means RESULT=landed_verify_red:
   the deploy LANDED but the resulting tree FAILS verification (deploy-headless.sh:96, :108,
   :160, :454). That exit code is derived from precisely the inline run being discussed, so the
   inline verify cannot simply be deleted. The checkpoint's own branch contract consumes exit 3.

=== POINTS TO SETTLE -- DO NOT PRE-DECIDE ===
- Whether to add an OPT-IN `--no-verify` / `--skip-verify` flag that ONLY the redeploy checkpoint
  passes, leaving every other caller's exit-3 contract byte-identical. Opt-in (rather than
  opt-out) is the shape that makes "no other caller changes" a structural guarantee instead of a
  claim, but argue it rather than assuming it.
- What EXIT CODE a deploy-with-verification-suppressed should return, such that no caller can
  silently misread it as verified-green. A suppressed verify is not a passed verify, and 0 may be
  the wrong answer. Consider a distinct RESULT= token alongside whatever code is chosen, matching
  the existing RESULT= convention at :108.
- ENUMERATE EVERY CALLER of deploy-headless.sh and state what each does with exit 3. The known
  set of source files referencing it includes: verify-deploy.sh, orchestrate-cycle-plan.sh,
  orchestrate-build-dispatch.sh, orchestrate-batch-admit.sh, command-gate-out.sh, skill-base.sh,
  deploy-root-guard.sh, check-deploy-freshness.sh, check-consumer-freshness.sh,
  check-extension-docs.sh, validate-state.sh, git-snapshot.sh, task-lock.sh,
  measure-eager-context.sh, system-defect-record.sh, lib/deploy-baseline-lib.sh, plus tests
  (test-deploy-verify-wiring.sh, test-postflight-deploy-gate.sh, test-deploy-propagation.sh,
  test-deploy-orphans.sh, test-deploy-freshness.sh, test-lint-deploy-caller-wrap.sh,
  test-double-loading-check.sh, test-orchestrate-build-dispatch.sh, test-orchestrate-cycle-plan.sh,
  test-validate-state.sh) and docs (architecture/extension-system.md,
  architecture/orchestrate-state-machine.md, reference/utility-scripts-inventory.md). Verify that
  list rather than trusting it -- some references are mentions, not invocations, and the
  distinction matters.
- Whether run-all.sh's new `--only-gate` flag makes a CHEAPER TARGETED inline verify a better
  answer than suppression outright. A narrowed inline verify keeps the exit-3 contract meaningful
  while removing most of the duplicated cost, which may dominate suppression on every axis. Weigh
  it explicitly and record the comparison either way.
- Note that test-lint-deploy-caller-wrap.sh exists specifically to police how callers wrap
  deploy-headless.sh; any new flag or exit code must satisfy it, or the lint must be extended
  deliberately and with reasoning, never relaxed.

=== VERIFICATION ===
1. Every caller NOT passing the new flag observes byte-identical behavior and exit codes,
   including exit 3. Demonstrate this, do not assert it.
2. The redeploy checkpoint's total wall time is measured before and after, on a checkpoint that
   actually fires (cycle_modified_files touching agent-system/**). Report both numbers.
3. A deploy whose tree genuinely fails verification is still detectable by the checkpoint --
   suppression must not create a path where a red tree is treated as green.
4. The suppressed-verify exit code / RESULT token is distinguishable from verified-green in a
   test.
5. scripts/tests/ passes, including test-deploy-verify-wiring.sh,
   test-lint-deploy-caller-wrap.sh, and test-orchestrate-cycle-plan.sh. No test may be weakened
   or deleted to make the change pass.

=== FILE-FOOTPRINT DEPENDENCIES (auto-added, overlap-derived) ===
This task's file_scope overlaps both sibling tasks: scripts/tests/test-deploy-verify-wiring.sh is
shared with the Gate 8 parallelization task, and scripts/orchestrate-cycle-plan.sh plus
scripts/tests/test-orchestrate-cycle-plan.sh are shared with the deploy-pending/dispatch-guard
task. Both edges are serialization-only, not semantic -- rebase on whatever they land.

=== PATH REVIEW 2026-09-28 (fifth pass): premise update and ordering ===
The parallelism task this text calls PARTIAL is COMPLETED (2026-09-26): its Phase 6 flakiness gate ran three repeated --jobs 4 full-suite runs, found two load-sensitive suites unreliable only under sustained heavy contention (five concurrent agent sessions), and closed COMPLETED WITH EXCLUSIONS without flipping the serial default. Option (b) above is therefore already satisfied; do not re-run a 3-run gate from scratch -- cite that task's recorded pass/fail sets and carry its named load-sensitive suites forward.
WHY THIS IS HIGH LEVERAGE (measured 2026-09-28): the Inter-Cycle Redeploy Checkpoint in orchestrate-cycle-plan.sh takes its pre/post (and confirm) findings snapshots at FULL depth -- never --skip-slow -- so Gate 8 (~9 min of an ~11 min run) is paid two to three times per checkpoint fire, on top of deploy-headless.sh's own inline --skip-slow pass (~1.5 min). Every self-modifying task in this repo fires that checkpoint. The checkpoint runs at the one boundary with no dispatch in flight, so ambient agent load there is minimal -- the condition under which --jobs 4 reproduced the sequential pass/fail set exactly.
PHASES: (A) Gate 8 --jobs (choose a conservative default plus an env override; document; verify --skip-slow and nested-guard paths unchanged); (B) the absorbed inline-verify question in deploy-headless.sh (opt-in flag vs. --only-gate-narrowed inline verify; exit-code contract preserved for every other caller). Serialized behind the deploy-pending/identical-dispatch fix because both touch orchestrate-cycle-plan.sh's checkpoint.

---

### 263. Consent-gated git push: grant semantics and enforcement mechanism
- **Status**: [PLANNED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 139
- **Research**: [263_consent_gated_git_push/reports/01_consent-gated-push-design.md]
- **Plan**: [263_consent_gated_git_push/plans/01_consent-gated-push-enforcement.md]

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**, a disposable
deploy artifact -- see rules/source-store-deploy-boundary.md).

=== GOAL ===
Make `git push` permissible by an agent ONLY after the user answers an interactive
AskUserQuestion gate granting permission for that specific push. The prohibition stays the
DEFAULT. Permission must never be inferred from a task description, from a prior approval in
another context, or from a user message that merely sounds permissive.

=== CURRENT STATE (verified 2026-09-25, source store) ===
rules/pr-prohibition.md has frontmatter `paths: "**/*"` (with a why-eager comment explaining the
universal glob is deliberate), so it applies repo-wide. It bans three classes:
  1. PR/MR creation (`gh pr create`, `glab mr create`, any API/wrapper equivalent)
  2. `git push` in ALL forms, explicitly including `--force`, `--set-upstream`, `-u`
  3. autonomous `/merge` invocation
Its "Required Behavior" section says agents MUST stop at `[PR READY]`, report readiness, and wait
for the user to invoke `/merge`, and states verbatim: "Never push branches or create PRs even if
asked to in task descriptions or user messages." That sentence is the one this change must
narrow -- carefully, because it is also the sentence that currently makes the rule
un-social-engineerable.

Other places the prohibition is asserted, all of which must stay consistent:
  - rules/git-workflow.md "Git Safety > Never Run" bullet: "`git push --force` to main/master"
  - merge-sources/claudemd.md: `/merge` and `/tag` marked "(user-only)" in the command table
    (lines ~111, ~114), `skill-tag | (user-only)` in the skill table (~153), and the
    "User-Only Skills" note (~165)
  - context/standards/git-integration.md and git-safety.md contain NO push references (checked) --
    so the rule surface is narrower than it might appear; do not assume otherwise without
    re-checking.

=== MECHANISMS THAT ALREADY EXIST AND SHOULD BE EXTENDED, NOT REINVENTED ===
  - scripts/git-commit-scoped.sh -- the single sanctioned path-scoped, mutex-serialized committer.
    This is the structural model for a push wrapper: one sanctioned entry point, everything else
    blocked.
  - hooks/guard-destructive-git.sh -- an existing PreToolUse Bash hook that already blocks two
    command classes (destructive-on-dirty-tree, and over-staging). Read its header in full: it
    documents that it blocks via `exit 2` + stderr, NOT `permissionDecision: deny`, because the
    latter is documented-buggy for allow-listed `Bash(git:*)` commands (GH #4669, #13214, #18312).
    Any new push guard must use the same blocking mechanism for the same reason.
    It also documents a critical asymmetry to respect: the snapshot-marker exemption applies to
    the destructive class but is FORBIDDEN from exempting the over-staging class, because a
    snapshot makes data loss recoverable while over-staging is a scope problem a snapshot does
    not make acceptable. Decide deliberately which side a push grant resembles.
  - scripts/git-snapshot.sh -- its marker-file contract is a working precedent for a ONE-SHOT
    authorization token: a fresh marker (<=120s) authorizes exactly one destructive command and is
    CONSUMED (deleted) on use. Evaluate this as the grant-token shape before designing a new one.
    Note its known observation boundary, documented in guard-destructive-git.sh: a hook only ever
    sees the top-level `tool_input.command` string, so a `git push` run as a subprocess inside a
    wrapper script is structurally invisible to the hook. That is what makes the
    wrapper-plus-hook pair work, and it is also the bypass to reason about.
  - context/standards/interactive-selection.md -- the AskUserQuestion schema and option-
    construction standard the gate must conform to.

=== DESIGN QUESTIONS TO SETTLE (these are the research/plan work; they are deliberately NOT
pre-decided) ===
  1. GRANT SCOPE: one push only, or session-scoped, or task-scoped? What INVALIDATES an existing
     grant -- new commits after the grant, a different branch, a different remote, a change from
     non-force to force? State the invalidation predicate precisely enough to implement.
  2. WHETHER PR/MR CREATION AND `/merge` FOLLOW THE SAME GATE OR STAY FULLY USER-ONLY. Working
     assumption to ARGUE FOR OR AGAINST, not to assume: push is the narrow case being opened;
     PR creation and `/merge` stay prohibited. Whichever way this lands, say why.
  3. CATEGORICAL EXCLUSIONS: are `--force` and `--force-with-lease`, and pushes to the default
     branch (master), outside what ANY grant can cover? Note the repo's default branch is master
     and rules/git-workflow.md already singles out force-push-to-master as a "Never Run".
  4. WHERE THE GATE LIVES SO IT CANNOT BE BYPASSED. A rule edit alone is documentation, not
     enforcement -- this is the central requirement. Design the enforcement pair: a wrapper/guard
     script analogous to git-commit-scoped.sh, plus a PreToolUse hook blocking bare `git push`
     call sites the way guard-destructive-git.sh already blocks its two classes. Confirm the hook
     registration shape in manifest.json against the existing registered hooks.
  5. DURABLE AUDIT RECORD: how the grant request and the user's actual answer are recorded so the
     consent is auditable after the fact. Candidates: a `.decisions.json` entry per the handoff
     schema's Decisions File Schema, and/or a specs/events.jsonl record. Record enough to
     reconstruct WHAT was authorized (remote, branch, commit sha, force-or-not) and WHEN, not
     merely that someone said yes.

=== EXPLICIT NON-GOALS ===
Do not implement the orchestrator-dispatch path here -- a dispatched subagent cannot call
AskUserQuestion, and routing that request is the companion task's scope. This task must, however,
define the grant semantics and guard interface that companion task consumes, and should state
that interface explicitly rather than leaving it implicit.

=== VERIFICATION ===
1. A bare `git push` from an agent is BLOCKED by the hook, with a stderr message naming the
   sanctioned path. Demonstrate the block, do not merely assert it.
2. A push attempted with NO grant present is blocked.
3. A push attempted with an INVALID grant (per whichever invalidation predicate is chosen --
   e.g. stale, wrong branch, wrong remote, commits added since) is blocked. Test each
   invalidation condition the design defines.
4. A categorically excluded push (force, and/or default-branch, per decision 3) is blocked EVEN
   WITH an otherwise-valid grant.
5. A push with a valid, in-scope grant succeeds through the sanctioned wrapper.
6. The audit record is written and contains enough to reconstruct what was authorized.
7. The fail-safe direction is BLOCK: an unreadable, absent, malformed, or unverifiable grant
   must block, never permit. Test the malformed case explicitly.
8. `git push` remains prohibited by default with no grant mechanism invoked -- i.e. existing
   agent behavior is unchanged unless a user actively grants.
9. Re-run the shell test suite under scripts/tests/. No existing test may be weakened or deleted
   to make this pass; a test that asserts the OLD blanket prohibition must be updated
   deliberately, with its new assertion stated in the summary.

=== VERIFIED MECHANISM MAP (surveyed 2026-09-25; use these, do not re-derive) ===
THE PROHIBITION IS CURRENTLY RULE TEXT ONLY -- THERE IS NO MECHANICAL ENFORCEMENT AT ALL.
This is the single most important finding and it reframes the work. Verified:
  - `grep -rln "git push|gh pr create|glab mr create" hooks/ scripts/` over the source store
    returns EMPTY. No hook, script, or lint blocks any of the three prohibited classes.
  - No test under scripts/tests/ (76 files) invokes `git push` or `gh pr create` against a hook to
    assert blocking. Matches for "push" there are incidental (`git stash push`; "push bytes past a
    ceiling"; an unrelated "hand-patch prohibition" string in test-orchestrate-build-dispatch.sh).
  - scripts/check-extension-docs.sh Rule H `check_undeclared_rules()` (~line 508-524) asserts only
    STRUCTURAL registration -- that rules/pr-prohibition.md is declared in manifest.json's
    `provides.rules` so it propagates to consumers. Its motivating comment records that the rule
    once existed on disk while absent from provides.rules, so it "never propagated downstream".
    That is a propagation check, not a behavioral one.
  So the guard being added here is NET-NEW enforcement, not a modification of existing
  enforcement. Consequence worth stating plainly in the plan: this change can leave the system
  STRICTER than it found it (a real hook where there was only text), even while narrowing the
  rule's stated scope. Design for that outcome deliberately.

HOOK REGISTRATION -- the wiring is NOT where you would first look:
  - manifest.json `provides.hooks` (~line 260-280) is a FLAT FILENAME LIST only
    ("guard-destructive-git.sh" among ~19 others). It carries no PreToolUse wiring.
  - merge-sources/settings-hooks.json (the deep-merge fragment applied into a consumer repo's
    .claude/settings.json) registers only `matcher: "Write|Edit"` ->
    validate-no-task-references.sh. It carries NO Bash-matcher entry.
  - root-files/settings.json is the template that actually carries the Bash-matcher registration
    for guard-destructive-git.sh (~line 44-52), shaped as a PreToolUse array entry with
    `matcher: "Bash"` and one `{"type":"command","command":"bash .claude/hooks/<script>.sh"}`.
  A new push guard must be added in BOTH manifest.json `provides.hooks` (so it deploys) AND the
  correct settings template (so it is wired). Missing either yields a silently inert hook -- which
  is precisely the failure mode Rule H exists to catch for rules.

ONE-SHOT MARKER CONTRACT (the reusable grant-token precedent), verified in
scripts/git-snapshot.sh + hooks/guard-destructive-git.sh:
  - Path: `specs/{NNN}_{SLUG}/.git-snapshot-marker`, task-scoped, gitignored via
    `**/.git-snapshot-marker`.
  - Format: line-oriented KEY=VALUE, minimally `TIMESTAMP=<epoch seconds>`, plus tool-specific
    payload fields (HEAD_SHA, PATCH_PATH, STASH_REF, BRANCH_NAME, UNTRACKED_BACKUP).
  - Freshness: `FRESHNESS_WINDOW=120` seconds. The consuming hook does
    `find specs -maxdepth 3 -name ".git-snapshot-marker" -type f`, picks newest by TIMESTAMP, and
    honors it only if `0 <= (NOW - TIMESTAMP) <= 120`.
  - Consumption: `rm -f "$BEST_MARKER"; exit 0` (guard-destructive-git.sh ~line 287-292) -- delete
    on use, so one marker authorizes exactly one gated command.
  A push grant token needs MORE payload than this marker does (remote, branch, sha, force-or-not)
  precisely so it cannot be replayed against a different push. A bare TIMESTAMP-only token would
  be a blank cheque for any push within the window -- do not reuse the shape uncritically.

scripts/git-commit-scoped.sh interface, for the wrapper to be modeled on:
  - `git-commit-scoped.sh --message <msg> --session <sid> [--honest-index-rows <task_number>]
    -- <pathspec>...`
  - PROJECT_ROOT: `SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)`, source lib/common.sh,
    `PROJECT_ROOT="$(common_repo_root "$SCRIPT_DIR" 2)"`, then `. deploy-root-guard.sh`.
  - Mutex: serializes via `specs/.commit-lock/` through `task-lock.sh commit-acquire/commit-release`,
    released in an EXIT trap; `COMMIT_MUTEX_HELD` lets a nested caller reuse the lock as a guest.
  - IMPORTANT DIVERGENCE: it fails OPEN on mutex-acquire failure (proceeds unserialized with a loud
    WARNING), reasoning the worst residual case is a safe index.lock race, not misattribution. A
    PUSH guard must fail CLOSED -- an unavailable lock or unverifiable grant must refuse the push.
    Do not inherit the fail-open direction; state this divergence explicitly in the code comments.
  - Shape to mirror: usage/flag parsing -> PROJECT_ROOT resolution -> mutex acquire/release via
    task-lock.sh verbs -> guarded git operation -> bounded retry on index.lock. Safety gates
    V2/V3/V4 (unmatched-path classification, exclude-only-pathspec refusal, nothing-to-commit
    exit 1) are the precedent for refusing ambiguous input rather than guessing.

AUDIT WRITER: scripts/events-append.sh is the sanctioned specs/events.jsonl writer (analogous to
state-write.sh): builds the line via `jq -c -n`, appends under `flock` on specs/.events.lock.
Required flags `--event-type --category --session --message`; optional `--task --checkpoint
--duration --detail-json --error-ref --cwd --cc-session-id`. `--category` is an enum:
deviation|blocker|milestone|success -- pick the fitting one and justify it. Record fields and the
draft-07 schema live in context/formats/events-format.md and context/schemas/events-schema.json,
which MUST stay in sync with each other. Never hand-append to events.jsonl.

DANGLING REFERENCE TO RESOLVE (small, real, in scope): hooks/guard-destructive-git.sh line 6 says
it is "Modeled line-for-line on .claude/hooks/block-pr-submission.sh", but NO file named
block-pr-submission.sh exists anywhere in the source store, and manifest.json has no
provides.hooks entry for it. It is a deploy-side-only artifact, i.e. either an orphan that
source-store regeneration will wipe or a stale reference to something already gone. Determine
which and fix the reference. Do not leave a header comment pointing at a file the source store
does not contain.


=== ABSORBED 2026-09-28 (path review, fifth pass) from former task 224 (please_grant_integrity_and_git_guards); that task is abandoned into this one. Its text follows verbatim; where it names "the dependency task" or "the sibling task", read this task's other sections. ===

Add a tamper-resistant single-use /please grant mechanism, a new git push guard, and grant checks in the destructive-git guard. Only agent-system/extensions/core/ is edited (hooks/, scripts/tests/, root-files/settings.json and/or merge-sources/settings-hooks.json, context/standards/git-safety.md), never .claude/.

(1) GRANT HOOK. A UserPromptSubmit hook that, when the literal user prompt starts with "/please", writes one grant (request text, timestamp, 10-minute expiry). Research must first verify what the hook payload actually contains (raw "/please ..." text or the expanded command body) and that subagent- or model-generated prompts can never trigger UserPromptSubmit.

(2) INTEGRITY, TO BE SETTLED IN RESEARCH. "The model must not be able to create grants" and "forged grant file rejected" require a real integrity mechanism: a gitignored file the model can Write to is forgeable. Starting point: an HMAC over each grant using a secret key stored outside the model-reachable/writable paths (or readable only by the hook), plus a PreToolUse guard blocking Write/Edit/Bash writes to the grant file and the key path. State the threat model honestly: a same-user shell process can in principle read any file the hook can read, so this raises the bar rather than proving user intent; name the residual risk. Decide whether the grant belongs outside the repo (e.g. $XDG_STATE_HOME) or in a gitignored in-repo path (the repo .gitignore currently ignores /.claude/ and /specs/tmp; root-files/.gitignore only covers .claude/).

(3) MATCHING RULE, TO BE SETTLED IN RESEARCH. Define how the free-text request is matched to the concrete command, e.g. action class (force-push, reset --hard, clean -fd, ...) plus remote/branch extracted from both. Ambiguous or partial matches are refused; one grant covers one action class and one target.

(4) PUSH GUARD. No push guard exists today (rules/pr-prohibition.md is advisory only; root-files/settings.json allow-lists Bash(git:*)). Create a new PreToolUse Bash hook (e.g. hooks/guard-git-push.sh) that blocks git push without a matching unexpired grant, via exit 2 + stderr like guard-destructive-git.sh (permissionDecision: deny is documented-buggy for allow-listed git commands). Research decides whether it also covers gh pr create / glab mr create and how /merge own push stays working.

(5) DESTRUCTIVE-GIT GUARD. hooks/guard-destructive-git.sh allows a matched action only with a matching unexpired grant, consuming it on use (mirror the existing .git-snapshot-marker consume-on-use pattern). Without a grant, behavior is unchanged. Preserve the clean-tree early exit and the COMMAND_SCAN quote/comment-stripping; a grant must never exempt the over-staging detectors. Decide where the grant check sits relative to the clean-tree early exit.

(6) REGISTRATION. Register the new hooks in the source-store settings file(s) research identifies (PreToolUse Bash hooks currently live in root-files/settings.json; UserPromptSubmit hooks in merge-sources/settings-hooks.json).

(7) TESTS in scripts/tests/ following context/standards/shell-script-testing.md and the fixture style of test-guard-destructive-git.sh (hook run as a subprocess against a synthetic dirty repo, asserting exit codes): forged grant rejected, expired grant rejected, grant consumed after one use, mismatched action/target rejected, no-grant behavior unchanged for both guards, writes to grant file and key path blocked.

OVERLAP NOTE (no dependency edge, by user decision): the pending history-rewrite predicate work on guard-destructive-git.sh also edits hooks/guard-destructive-git.sh, rules/git-workflow.md and context/standards/git-safety.md. Structure predicate ordering so the two additions compose; the file-footprint admission gate serializes them if run concurrently.

Redeploy afterwards and confirm the hooks fire from the deployed copies.

=== ABSORBED 2026-09-17 from former task 225 (/please command, never-list, pr-prohibition exception, docs); that task is abandoned into this one. Its text follows verbatim; where it names "the dependency task" or "the sibling task", read this task's other sections. ===
Add the user-only /please command, its never-list, the pr-prohibition exception, and the CLAUDE.md command-reference entry. Only agent-system/extensions/core/ is edited (commands/please.md, commands/README.md, rules/pr-prohibition.md, merge-sources/claudemd.md), never .claude/. Builds on the grant mechanism and guards from the predecessor task (dependency).

(1) commands/please.md, user-only, modeled on commands/merge.md and commands/tag.md: authorizes one otherwise-blocked action per invocation (e.g. "/please force-push main to origin"). Parse the requested action; show the exact command and its effect (for pushes: local vs remote SHAs); confirm with AskUserQuestion before any irreversible step; prefer safe forms (--force-with-lease=<ref>:<observed remote SHA> over --force); do only the literal request; log the action to specs/events.jsonl via scripts/events-append.sh. Caveat to state in the command: the grant proves the user typed /please, not that the command the agent then runs is the one meant, so the confirmation step is mandatory for anything irreversible.

(2) NEVER-LIST, refused regardless of wording and enforced in the command: credential/secret access, deletion outside the repo, .git internals, disabling/editing/removing hooks or hook settings.

(3) rules/pr-prohibition.md: add a /please exception scoped to the single action of that one invocation, reconciled explicitly with the existing "never push even if asked in user messages" language.

(4) merge-sources/claudemd.md: add a /please row to the Command Reference table beside /tag and /merge, marked user-only; add a row to commands/README.md.

Redeploy and confirm the generated .claude/CLAUDE.md shows the new row.

=== ABSORBED 2026-09-28 (path review, fifth pass) from former task 264 (relay_push_consent_through_user_decision); that task is abandoned into this one. Its text follows verbatim; where it names "the dependency task" or "the sibling task", read this task's other sections. ===

SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**, a disposable
deploy artifact -- see rules/source-store-deploy-boundary.md).

DEPENDS ON the consent-gated-push design task, for two independent reasons: (1) semantic -- this
task routes a push REQUEST through the orchestrator and mints the grant its guard consumes, which
is impossible until that task settles the grant semantics, the invalidation predicate, and the
wrapper's interface; (2) file-footprint overlap -- both touch rules/pr-prohibition.md and
manifest.json. Rebase on whatever that task lands.

=== GOAL ===
Two things: (a) define how an agent running in a fire-and-forget dispatch REQUESTS a push, since it
cannot call AskUserQuestion itself, and how the user's answer becomes a grant the guard honors;
(b) sweep the codebase so nothing still asserts the blanket prohibition the companion task
narrowed.

=== (a) THE DISPATCH PATH -- EXTEND THE EXISTING CHANNEL, DO NOT INVENT ONE ===
A dispatched subagent cannot call AskUserQuestion. Verified concretely: while these tasks were
being created, the dispatched agent doing so had NO AskUserQuestion tool available -- a
ToolSearch for it returned "No matching deferred tools found". So the request must be relayed.

The channel exists and this case is already inside its stated remit.
context/standards/user-decision-contract.md defines an agent-authored `user_decision`, and
context/formats/return-metadata-file.md (~line 507, "### user_decision (optional)") gives its
shape: a TOP-LEVEL object on `.return-meta.json`, producer-owned by the agent that sets it,
`{question, options: [...], recommended, blocking: true|false}`, mirrored onto
`.orchestrator-handoff.json` when that dispatch also writes one. Later writers must merge without
touching it. The contract's enumerated qualifying shape 2 is, verbatim: "An external cost or risk
the user must accept -- spending money, granting a credential, deleting data, or taking an action
outside this repository that the agent cannot verify is already sanctioned." A push to a remote is
squarely an action outside this repository. Treat that as the designed home for this request.

VERIFIED RELAY PATH (use these call sites; do not re-derive):
  - scripts/orchestrate-cycle-postflight.sh, "WORK (e): user_decision relay" (~lines 1073-1096):
    reads `.orchestrator-handoff.json` first when fresh (`handoff_stale != true`), else
    `.return-meta.json`; a non-null value sets `verdict="ask_user"`, which "takes precedence over
    every other signal". The script relays and NEVER resolves (its line-68 comment:
    "user_decision is RELAYED, never resolved") and explicitly never writes .decisions.json
    (~line 1088).
  - skills/skill-orchestrate/SKILL.md Move 3 "Postflight" (~lines 208-213) ACCUMULATES rather than
    asking per task: `.pending_ask_user = ((.pending_ask_user // []) + [{"task": $tn,
    "decision": $q}])`.
  - Move 4 "Branch" batched relay (~lines 256-263): if `pending_ask_user[]` is non-empty, call
    AskUserQuestion once per entry (question/options/recommended from `.decision`), all batched at
    the single Move-4 boundary -- "never mid-cycle, never one call per task". Non-blocking
    decisions proceed on the agent's recommendation and are only surfaced in output.
  - Move 4 then appends each answer to `specs/{padded}_{project}/.decisions.json` and clears that
    task's `pending_ask_user`.

*** CRITICAL DESIGN HAZARD -- THE EXISTING REPLAY CHANNEL ***
`.decisions.json` is not inert. Schema in docs/architecture/handoff-schema.md (~lines 951-991):
a JSON array of `{question, answer, cycle, timestamp}` at
`specs/{NNN}_{slug}/.decisions.json`, absent until the first decision is answered, additive only.
scripts/orchestrate-build-dispatch.sh (~lines 38-42, 367-377, 511-518) READS it when building the
NEXT dispatch for the same task and emits a `## Prior Decisions` section so the answer is not
re-asked. That mechanism is desirable for ordinary design decisions and DANGEROUS here: a recorded
"yes, push" would be replayed into every subsequent dispatch for that task as standing prior
approval -- which is exactly the failure the requirement forbids ("permission must never be
inferred from a prior approval in another context"). Resolve this explicitly. Either exclude push
grants from the `## Prior Decisions` injection, or record them in a form that is self-evidently
non-reusable (bound to a specific sha/branch/remote that a later cycle cannot satisfy), or both.
Do NOT leave the default replay behavior in place for this decision class. Whatever is chosen,
verify it with a test that runs two cycles and confirms the second does not inherit the grant.

Also establish:
  - How the push request is expressed in the `user_decision` payload with enough specificity that
    the answer authorizes ONE identifiable push (remote, branch, commit sha, force-or-not). A
    vague "may I push?" the guard then interprets broadly would defeat the design. The payload's
    `options`/`recommended` fields must make the exact target legible to the user at the moment
    they answer -- consent to an unspecified push is not consent.
  - Whether such a request may ever be `blocking: false`. It almost certainly must always be
    `blocking: true`, since the non-blocking path proceeds on the AGENT's recommendation without
    asking -- which would be an agent authorizing its own push. Confirm and enforce this.
  - The RETURN LEG, which has no existing precedent: the relay today surfaces decisions to the
    user; it does not mint an authorization token a later subprocess consumes. Design how a YES
    becomes a grant the guard script honors, and where that token lives.
  - What happens when the request is relayed but the run ENDS before an answer, and when the user
    answers NO. Both must leave the task clean with no push performed.
  - Whether a granted push may carry across a later cycle in the same run, or dies with the
    dispatch that requested it. Must be answered consistently with the companion task's
    grant-scope decision.

Constraint to preserve: the contract's core invariant is that the orchestrator never asks on its
own and never decides on the user's behalf, and that agents decide everything else themselves. A
push request must not become a prompt agents raise reflexively; it qualifies only when a push is
genuinely the task's sanctioned endpoint.

=== (b) CONSISTENCY SWEEP ===
Note up front, verified: there is NO existing lint or test asserting behavioral push/PR blocking,
so this sweep is about DOCUMENT consistency plus ADDING the missing tests, not about repairing
broken assertions. The only structural check is scripts/check-extension-docs.sh Rule H
`check_undeclared_rules()`, which asserts rules/pr-prohibition.md is declared in manifest.json's
`provides.rules`; keep that satisfied.

Files to reconcile:
  - rules/pr-prohibition.md -- the narrowing lands in the companion task; verify no stale absolute
    language survives, especially "Never push branches or create PRs even if asked to in task
    descriptions or user messages", which must still hold verbatim for everything the new gate
    does NOT cover. Its `paths: "**/*"` frontmatter and why-eager comment stay.
  - rules/git-workflow.md -- the "Git Safety > Never Run" bullet on `git push --force` to
    main/master, and the "Enforced by guard-destructive-git.sh" note if a new guard joins it.
  - merge-sources/claudemd.md -- this is the GENERATED-FROM source for the deployed
    .claude/CLAUDE.md; edit here, never the deployed file. Reconcile the `/merge` and `/tag`
    "(user-only)" command-table markings (~lines 111, 114), `skill-tag | (user-only)` in the skill
    table (~153), and the "User-Only Skills" note (~165). If the companion task decided PR
    creation and `/merge` stay prohibited, these stay and should be reinforced, not loosened.
  - commands/merge.md and skills/skill-tag/SKILL.md -- both reference the prohibition; check both.
  - context/standards/status-markers.md -- confirm whether a consented push changes when a task
    reaches `[PR READY]`. Most likely it does not; say so explicitly rather than leaving it
    unexamined.
  - If a new audit event type is introduced, context/formats/events-format.md and
    context/schemas/events-schema.json must stay in sync with each other.

=== VERIFICATION ===
1. A dispatched subagent needing a push emits a well-formed top-level `user_decision` with
   `blocking: true` and does NOT push.
2. postflight sets `verdict="ask_user"`; Move 3 accumulates it into `pending_ask_user`; Move 4
   relays it in the batch with the specific push identified (remote, branch, sha, force-or-not).
3. A NO answer results in no push and a clean task state.
4. A run ending before an answer results in no push and a clean task state.
5. A YES produces a grant the guard honors for exactly that push and no other: verify a replay
   against a different branch, a different remote, and a later commit is each refused.
6. TWO-CYCLE TEST for the hazard above: after a granted push in cycle N, cycle N+1's dispatch does
   NOT inherit standing permission via `## Prior Decisions`.
7. `grep` the source store for remaining blanket-prohibition language; list every file changed and
   every file deliberately left unchanged, with reasons.
8. Re-run scripts/tests/ plus the check-*.sh lints, including check-extension-docs.sh Rule H. No
   test weakened or deleted; any test whose assertion changed is named in the summary with its old
   and new assertion. New tests must cover items 1-6.

=== PATH REVIEW RULING 2026-09-28 (fifth pass) -- ONE grant mechanism, not three ===
Three tasks (this one, the absorbed /please task, and the absorbed user_decision relay task) each designed a git-push grant. They are now one task with three phases, and the following is settled rather than re-litigated:
  1. INTEGRITY DECIDES THE MINT PATH. A grant file the model can Write after reading an AskUserQuestion answer is forgeable by construction -- exactly the artifact the absorbed /please text rejects. So the tamper-resistant mint path is the /please UserPromptSubmit hook (the harness fires it only on a literal user prompt; research item (1) of the absorbed text must still VERIFY the payload shape and that model- or subagent-generated prompts never trigger it). AskUserQuestion is the confirmation surface, never the mint.
  2. THE TOKEN CARRIES THE TARGET. Whatever the /please grant records, it must bind action class + remote + branch + commit sha + force-or-not (this task's design questions 1 and 3), single-use, short expiry, fail-CLOSED on any unreadable/malformed/mismatched grant. The bare TIMESTAMP-only snapshot-marker shape is explicitly insufficient.
  3. THE DISPATCH PATH ONLY RELAYS. A dispatched agent emits a blocking user_decision whose options make the exact push legible; Move 4 relays it once at cycle end (settled decision: the orchestrator never asks on its own and never decides). A YES does NOT mint anything -- the relayed text tells the user the exact /please line to type, and the guard consumes that grant. This closes the .decisions.json replay hazard for free: nothing replayable is ever recorded, but the two-cycle test in the absorbed text still ships to prove it.
  4. PR/MR creation and /merge stay user-only. Force-push and pushes to master are outside any grant unless the /please never-list explicitly admits a --force-with-lease form; decide and record.
  5. skills/skill-orchestrate/SKILL.md sits at 17 B under its 20,000 B ceiling (measured 2026-09-28). Any relay text added there must be offset byte-for-byte (mode-gate it or move it to a context file) -- verify-deploy Gate 20 will otherwise refuse the redeploy.
PHASES: (A) grant token + /please hook + integrity + push guard + destructive-git grant check + tests; (B) /please command, never-list, rule exception, docs sweep (the absorbed consistency sweep); (C) dispatch relay + two-cycle test. Depends on the history-rewrite task (guard-destructive-git.sh, git-safety.md, git-workflow.md are shared; its predicate ordering must compose with the grant check).

---

### 255. Reconcile typst extension scope ownership and fix chapter-quality-check.sh Rule 1.3 bib resolution
- **Effort**: 3-6 hours
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: None
- **Research**: [255_typst_scope_and_chapter_quality_bib_resolution/reports/01_typst-scope-bib-resolution.md]
- **Plan**: [255_typst_scope_and_chapter_quality_bib_resolution/plans/01_typst-scope-bib-resolution.md]
- **Summary**: [255_typst_scope_and_chapter_quality_bib_resolution/summaries/01_typst-scope-bib-resolution-summary.md]

**Description**: Reconcile the typst extension's declared scope with what it actually owns, and fix chapter-quality-check.sh silently skipping BLOCKING Rule 1.3

SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/typst/ (never .claude/**). This extension deploys to at least 5 repos (Logos/Verification, Logos/ModelChecker, BimodalLogic, SPSDemo, plus the source store), so every edit must land in the source store and reach deployed trees only by regeneration.

WHY THESE TWO DEFECTS ARE ONE TASK. Both make the extension's chapter-quality machinery fail to engage, at two consecutive points in the same pipeline. Defect 1 stops the right agents from being dispatched at all: chapter-content work self-detects as `general`, so general-research-agent/general-implementation-agent run instead of the typst agents, and those agents never execute the chapter-quality gates. Defect 2 stops a BLOCKING rule from being evaluated even once the typst agents DO run. Fixing only one leaves the machinery half-connected: fix routing alone and the gate still under-enforces; fix the gate alone and most chapter work never reaches it. The two halves have disjoint file scopes and should be separate implementation phases, but they share a single acceptance question -- does chapter-quality enforcement actually fire end to end?

=== PART 1: SCOPE NOTE AND keyword_overrides CONTRADICT THE EXTENSION'S OWN STANDARD ===

EXTENSION.md lines 5-9 ("### Scope") currently state: "This extension covers formatting, compilation, styling, and structural concerns for existing document content. Content-creation work (proofs, theorems, chapters, textbook prose) routes to `lean4`, `formal`, or `general` as appropriate, not to `typst`."

This is contradicted by what the extension actually ships.

THE CONTRADICTION IS BROADER THAN chapter-quality.md ALONE -- verified by direct inspection of the source store, and the single most important finding to carry forward. Beyond context/project/typst/standards/chapter-quality.md (which is entirely about chapter CONTENT quality across four dimensions: SOURCE GROUNDING, ANTI-FLUFF DENSITY, PRESENTATION CLARITY, OPEN-QUESTION HONESTY), the extension also ships:
  - context/project/typst/standards/textbook-standards.md
  - context/project/typst/standards/type-theory-foundations.md
  - context/project/typst/patterns/theorem-environments.md
  - context/project/typst/templates/chapter-template.md
So the phrase "Content-creation work (proofs, theorems, chapters, textbook prose) ... not to `typst`" contradicts roughly a third of the extension's own context corpus, naming four categories (proofs, theorems, chapters, textbook prose) of which at least three have dedicated context files INSIDE this extension. Do not scope the reconciliation to chapter-quality.md alone; audit the full context/project/typst/ tree and state a boundary that matches it.

The contradiction is also enforced in code, not merely documented: scripts/chapter-quality-check.sh is executed as a gate by agents/typst-implementation-agent.md at Stage 4C and Stage 5 (MUST DO items 7-8), and agents/typst-research-agent.md loads chapter-quality.md as calibration context.

OBSERVED CONSEQUENCE (live, not hypothetical): a task to review and condense typst manual chapters was detected as task_type `general` and had to be re-routed to `typst` by hand.

manifest.json keyword_overrides.typst.keywords currently holds 8 phrases, every one formatting/compilation-shaped:
  "typst formatting", "typst compile", "typst compilation", "typst package",
  "typst template", "typst style", "typst layout", "fletcher diagram"
Nothing matches "typst chapter", "typst manual", "chapter quality", or "chapter prose", which is why detect_task_type() falls through to `general`.

REQUIRED:
  1. Decide and state the REAL boundary between `typst` and `lean4`/`formal`/`general`. Chapter-quality and chapter-prose work IS in scope for this extension -- the question to answer is where proofs and theorems sit, given that theorem-environments.md and type-theory-foundations.md ship here. A defensible split is likely "typst owns presentation and quality of prose/chapters including their theorem PRESENTATION; lean4/formal own mathematical CONTENT and correctness" -- but argue it, do not assume it.
  2. Rewrite EXTENSION.md's Scope section to match. NOTE THE DEPLOY PATH: EXTENSION.md is the claudemd merge source (manifest.json merge_targets.claudemd -> .claude/CLAUDE.md, section_id `extension_typst`), so the deployed CLAUDE.md section regenerates from it. Edit EXTENSION.md, never the deployed section.
  3. Extend manifest.json keyword_overrides.typst.keywords so chapter/manual-quality work self-detects as `typst`.

KEYWORD SAFETY CONSTRAINT: check every added keyword against scripts/lib/task-type-detect.sh's resolution ladder. Extension keyword_overrides are step 2; the FIRST whole-word match in alphabetical directory order wins and is FINAL. An over-broad keyword (e.g. a bare "chapter" or bare "manual") could hijack tasks meant for other extensions, since `typst` sorts early alphabetically. Prefer qualified multi-word phrases ("typst chapter", "chapter quality", "typst manual") over bare nouns, and verify no collision with other loaded extensions' keyword sets.

=== PART 2: chapter-quality-check.sh SILENTLY DISABLES BLOCKING RULE 1.3 ===

Rule 1.3 (citation keys resolve in the .bib) is BLOCKING, but is routinely never evaluated.

Location: scripts/chapter-quality-check.sh -- resolve_bibliography() at lines 347-370, call site at lines 634-640, documented contract in the header at lines 99-101.

Current logic: (a) grep `#bibliography("...")` in the CHECKED FILE; else (b) accept the single *.bib found by `find "$root" -type f -name '*.bib'`. Zero or multiple candidates => Rule 1.3 NOT EVALUATED.

BUG 2a -- MULTI-FILE MANUALS CAN NEVER MATCH BRANCH (a). In any multi-file manual, chapters are `#include`d into a root document that owns the `#bibliography(...)` declaration. The chapter file itself never carries the declaration, so branch (a) can never match for a chapter file -- exactly the file type this checker exists to check. Needs resolution via the including/root document, or a nearest-ancestor search.

BUG 2b -- BRANCH (b) COUNTS VENDORED .bib FILES. The find has no exclusion for vendored or build directories. Reproduced in Logos/Verification: typst/manual/bibliography.bib plus a vendored framed_channel/aeneas/.lake/packages/mathlib/docs/references.bib makes the candidate count 2, so the single-candidate test fails and the rule is skipped. ANY repo with a vendored dependency carrying a .bib hits this. Exclusions likely needed for at least .lake/, .git/, node_modules/, target/, build/.

NARROWING FINDING -- resolve_bibliography() ALREADY HANDLES DECLARED PATHS. Lines 355-358 already contain a `filedir` fallback: when a `#bibliography("...")` declaration IS present but the path does not resolve against the repo root, it retries against the checked file's own directory. That branch is sound and needs no work. ONLY the undeclared and multi-candidate branches need fixing. Do not rewrite the declared-path branch.

VERIFIED REPRODUCTION, from /home/benjamin/Projects/Logos/Verification:
  bash .claude/scripts/chapter-quality-check.sh --verbose typst/manual/chapters/01-introduction.typ
Emits:
  [INFO] Rule 1.3 NOT EVALUATED: no resolvable .bib file (no #bibliography(...) declaration and zero or multiple *.bib candidates under /home/benjamin/Projects/Logos/Verification)
  SCORE ...: MECHANICAL 4/6 | BLOCKING 0 | ADVISORY 4 | JUDGED 12 prompts pending
  CHAPTER QUALITY CHECK PASSED
...and exits 0.

SEVERITY AND THE SURFACING QUESTION: a BLOCKING rule becomes unenforced while the script still prints "CHAPTER QUALITY CHECK PASSED". It is quiet rather than fully silent -- it does emit an [INFO] NOT EVALUATED line and drops the score to MECHANICAL 4/6 -- but the PASSED banner is misleading to anyone reading only the last line, which is the common case in agent gate output. Part of this task is to DECIDE whether an unevaluated BLOCKING rule warrants louder surfacing than [INFO] (e.g. a [WARN] tier, or qualifying the PASSED banner when any BLOCKING rule was skipped). Note this is a judgement call with a real tradeoff: the current [INFO]/never-fail posture is deliberate per the header contract, so any change to it must be argued and the header updated to match.

=== TESTS ===

scripts/tests/test-chapter-quality-check.sh (317 lines) needs cases for both 2a and 2b.

CRITICAL -- AN EXISTING TEST ASSERTS THE BUGGY BEHAVIOR. Case-f at lines 168-181 ("unresolvable bibliography") currently ASSERTS exit 0 plus "NOT EVALUATED" for a file with no declaration and no .bib. That assertion must be REVISITED, not merely supplemented with new cases. A researcher or implementer who only adds new cases will leave a test actively contradicting the fix, and the suite will either fail or silently pin the old behavior. Decide whether case-f remains valid (a genuinely bib-less repo arguably should still be NOT EVALUATED) or must be re-scoped so it no longer covers the multi-candidate/include-root paths the fix now resolves.

Related existing fixtures to check for interaction: case-a (lines 65-81, compliant fixture with declared refs.bib), case-e (lines 144-165, Rule 1.3 violation with a declared bib), and the dirscan fixture at line 304 which copies refs.bib into a second directory -- that last one may already be sensitive to candidate-counting changes.

HEADER CONTRACT MUST BE UPDATED IN THE SAME COMMIT. Header lines 99-101 document the current (a)/(b) resolution contract verbatim. The script header states the rule inventory must never drift from the standard, so any behavior change here requires the header updated in the same commit as the code.

=== ACCEPTANCE ===
  1. EXTENSION.md's Scope section is consistent with every file under context/project/typst/ -- no category is disclaimed that the extension actually ships context for.
  2. A task phrased like "review and condense the typst manual chapters" self-detects as task_type `typst` via detect_task_type(), demonstrated by running the detection, not asserted.
  3. No added keyword hijacks a task belonging to another extension; verified against the alphabetical-first-match ladder in scripts/lib/task-type-detect.sh.
  4. Rule 1.3 evaluates for a chapter file that is `#include`d into a root document carrying the `#bibliography(...)` declaration.
  5. Rule 1.3 evaluates in a repo containing a vendored .bib under .lake/ (or equivalent) alongside the real bibliography -- demonstrated against the Logos/Verification reproduction above.
  6. scripts/tests/test-chapter-quality-check.sh green, with case-f explicitly re-examined and its disposition recorded.
  7. Header lines 99-101 match the implemented resolution contract.
  8. No test weakened or deleted to make the change pass.

=== SCOPE DISCIPLINE ===
  - Edits land ONLY in agent-system/extensions/typst/. Do not edit any deployed .claude/ tree, in this repo or any of the 5 consumer repos.
  - Do not touch scripts/typst-element-lint.sh or its tests; it is a separate gate with its own contract.
  - Part 1 and Part 2 have disjoint file scopes (EXTENSION.md + manifest.json vs. scripts/chapter-quality-check.sh + its test). Keep them as separate phases so each can be committed green independently.

---

### 251. Context-corpus reachability probe (filename, directory, index.json), then act on dead and overlapping files
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 249, Task 44, Task 127

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**).

MOTIVATION. Same structural gap as the script-corpus task: defect-driven intake surfaces only
what breaks, and an unreachable or redundant context file breaks nothing -- it just costs bytes,
deploy time and reader attention. Existing tasks slim SPECIFIC oversized files (commands/task.md,
the literature and distill skills) or collapse ONE mechanism (the routing ladder). Nothing
reviews the corpus, and -- the sharper problem -- nothing in the repo can currently ANSWER what
is reachable.

MEASURED 2026-09-22 (re-measure before acting; standing rule 3).
  - 523 .md files under agent-system/extensions/**/context/**, 3,583,550 B (~3.6 MB) total.
  - A naive basename-grep reachability check over the whole source store returned: 39 files not
    referenced from outside context/, of which 16 were referenced NOWHERE at all.
  - ALL 16 WERE FALSE POSITIVES. Every one is a present-extension slide template under
    context/project/present/talk/contents/**, referenced by DIRECTORY from the present agents
    (`talk/contents/title/`, `talk/contents/methods/`, ...) rather than by filename.
  - CONCLUSION, STATED PLAINLY SO NOBODY RE-DERIVES IT: there are ZERO confirmed dead context
    files today. The finding is not "delete 16 files" -- it is that the naive check is INADEQUATE
    and no adequate one exists. Do not open this task by deleting anything.

THREE REFERENCE STYLES THE PROBE MUST UNDERSTAND (the naive check saw only the first):
  1. by filename -- a backticked or plain path naming the file;
  2. by directory -- a reference to the containing directory, which reaches every file under it
     (the present templates; treat a directory reference as covering its whole subtree);
  3. via index.json -- context indices that enumerate entries the loader resolves at runtime.
A probe that misses any of these produces false orphans, and acting on false orphans deletes live
content. Prove the probe against the present-templates cluster as a REGRESSION FIXTURE: a correct
probe reports all 16 reachable.

PHASE 1 -- THE PROBE (mechanical, becomes permanent).
Add a standing reachability/inventory probe following the EXISTING convention of
scripts/assess-repo-health.sh and scripts/measure-eager-context.sh (JSON to stdout, --check mode,
no side effects, reads the SOURCE STORE not .claude/**). Per context file report:
  - bytes; owning extension; reachable yes/no and by WHICH of the three styles;
  - eager vs lazy -- whether it loads on every session (the eager channels measure-eager-context.sh
    already models: parent chain, assembled CLAUDE.md, @-imports, path-matched rules) or only on
    demand. Reuse that script's channel model; do not build a second, divergent one.
  - inbound reference count, so single-referrer files that could be inlined are visible.
Register it in docs/reference/utility-scripts-inventory.md alongside the other probes.

PHASE 2 -- THE STRONGER EVIDENCE: TELEMETRY, NOT ONLY STATIC ANALYSIS.
Static reachability answers "could this be loaded". The better question is "has any dispatch
ACTUALLY loaded it". The repo already carries the data: specs/events.jsonl, the memory
extension's history.jsonl, and the telemetry tiers the distill review mode queries. Determine
whether load events are recorded at context-file granularity; if they are, cross the probe's
static verdict against observed loads and report files that are statically reachable but never
actually loaded. If they are NOT recorded at that granularity, say so explicitly in the summary
and state what instrumentation would be needed -- that is a legitimate finding, not a failure.

PHASE 3 -- ACT ON THE RANKING.
Only after Phases 1-2 produce evidence: remove confirmed-dead files; merge pairs whose content
substantially overlaps; and for files that are live but oversized, apply the established
rule-or-command -> lazy-narrative split (rules/git-workflow.md -> context/standards/
git-workflow-narrative.md is the worked example). Every removal cites the probe's verdict AND
the telemetry verdict where available. A file that is reachable by any of the three styles is NOT
dead, however unloved it looks.

SCOPE DISCIPLINE -- READ BEFORE DECLARING file_scope.
This task's INITIAL file_scope is the new probe, its test, and the inventory doc ONLY. Do NOT
declare `context/` or any whole-directory or glob entry: coarse entries draw validate-state.sh
warnings and defer unrelated tasks in the dry run -- a mistake already corrected once in this
backlog by narrowing a task that had three whole-directory entries. Phase 3's actual edit targets
MUST be named individually and ADDED to file_scope at plan time, after Phase 1 has ranked them.

ACCEPTANCE.
  1. The probe runs clean, is registered, and reports all 16 present-extension templates as
     REACHABLE (the regression fixture above).
  2. Its output is reproducible across two runs and does not read .claude/**.
  3. The eager/lazy classification agrees with measure-eager-context.sh's totals -- two probes
     must not disagree about what is eager.
  4. Every file removed in Phase 3 has a recorded probe verdict and a stated reference-style check
     against all three styles.
  5. run-all.sh green -- read the summary line AND the exit code, and do NOT pipe it through
     tail/head.
  6. verify-deploy.sh --skip-slow no worse than at task start.

DEPENDENCIES AND WHY.
  - The eager-context budget task performs exactly the rule -> lazy-narrative split this task's
    Phase 3 generalizes, and CREATES a new context/standards file. Measuring the corpus before it
    lands measures a state about to change, and its split is the worked exemplar to follow.
  - The task.md slimming task moves reference material into six new lazily loaded context/patterns
    files. A corpus inventory taken before those exist is stale on arrival.
  - The routing-ladder collapse removes a routing mechanism and may orphan its context; measuring
    before it lands would miss exactly the kind of dead content this task exists to find.

DELIVERABLE RULE: no task numbers in deliverables outside specs/** (no-task-references-in-deliverables.md).

---

### 250. Script-corpus inventory probe, then cut tests/run-all.sh runtime and decompose orchestrate-cycle-plan.sh
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 199, Task 245, Task 249, Task 259, Task 265, Task 266

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**).

MOTIVATION -- A GAP IN THE INTAKE MECHANISM, NOT A SINGLE DEFECT. Tasks in this repo are filed by hand from defects hit live during /orchestrate runs. That intake only ever surfaces what BROKE. Needless complexity, duplicated logic and poor division of labor never break anything -- they only cost -- so they are invisible to the filing process by construction and will not self-correct. Every existing script-touching task is a point fix on one file. Nothing reviews the corpus. This task closes that gap with a standing probe, not a one-off reading pass.

MEASURED 2026-09-22 (re-measure before acting; standing rule 3).
  - 182 non-test .sh files under agent-system/extensions/**, 63,740 lines total.
  - The orchestrate engine alone: 8,207 lines across 14 orchestrate-*.sh scripts.
  - orchestrate-cycle-plan.sh: 2,279 lines -- 27.8% of the engine in ONE file, and 6.5x the
    351-line median of its own 14-script family (next largest: cycle-postflight at 1,256).
  - scripts/lib/ already holds 14 extracted libraries totalling 2,564 lines (common.sh,
    file-scope-overlap.sh, manifest-routing-lib.sh, task-lookup-lib.sh, ...). The extraction
    pattern is ESTABLISHED and working; it simply has never been applied to the largest file.

ANTI-ANALYSIS CONSTRAINT -- READ THIS BEFORE PLANNING. A "review all 182 scripts" pass that
emits a report and no diff is the failure mode this repo's own hard-mode contract names (H2:
forbidden analysis-only outputs, analysis-paralysis signal). This task is therefore explicitly
two-part: build a MECHANICAL probe, then act on its RANKED output. Any phase whose only artifact
is prose is out of contract. The probe is the deliverable that outlives the task.

PHASE 1 -- THE PROBE (mechanical, becomes permanent).
Add a standing inventory probe following the EXISTING convention of scripts/assess-repo-health.sh
and scripts/measure-eager-context.sh (JSON to stdout, --check mode, no side effects, reads the
SOURCE STORE not .claude/**). Per non-test script it must report at minimum:
  - line count and byte count;
  - inbound caller count (how many skills, agents, commands, manifests, hooks and other scripts
    reference it) -- a script with zero callers is a finding in itself;
  - whether a test suite covers it (pair against scripts/tests/ and flat scripts/test-*.sh);
  - duplicated-block detection ACROSS scripts, so copy-paste that belongs in lib/ is visible;
  - whether it is registered in the owning manifest's provides.scripts (the same class of drift
    check-extension-docs.sh already performs -- reuse, do not reimplement).
Register it in docs/reference/utility-scripts-inventory.md alongside the other repo-health probes.
Emit a stable ranked ordering so Phase 2+ targets are chosen by evidence, not by preference.

PHASE 2+ -- ACT ON THE RANKING, HIGHEST FIRST.
Decompose orchestrate-cycle-plan.sh into lib/ extractions, following the shape the 14 existing
libs already demonstrate. This is a BEHAVIOR-PRESERVING refactor:
  - the --dry-run JSON payload and the human table must be byte-identical before and after for a
    representative multi-task invocation (capture the baseline FIRST, diff at the end);
  - md5sum specs/state.json unchanged across a --dry-run call, as today;
  - scripts/tests/test-orchestrate-cycle-plan.sh green throughout, and green after each extraction
    rather than only at the end (commit-per-green-substep, per rules/git-workflow.md).
Size each extraction to one agent run. Do NOT attempt the whole 2,279 lines in a single phase.

SCOPE DISCIPLINE.
  - Phase 2 targets orchestrate-cycle-plan.sh ONLY among the engine scripts. Do NOT edit
    orchestrate-batch-admit.sh (owned by the admission tasks), orchestrate-predispatch-review.sh,
    or orchestrate-cycle-postflight.sh in this task -- each is another open task's declared scope,
    and editing them here reintroduces exactly the undeclared-overlap deferral the batch engine
    exists to prevent.
  - If Phase 1's ranking names further scripts worth decomposing, ADD them to file_scope at plan
    time (the convention already used elsewhere in this backlog) or file them as separate tasks.
    Do NOT declare a whole-directory or glob file_scope entry: coarse entries draw
    validate-state.sh warnings and defer unrelated tasks in the dry run.
  - Never weaken or delete a test to make a refactor pass.

ACCEPTANCE.
  1. The probe runs clean, is registered, and its output is reproducible across two runs.
  2. Every script with zero inbound callers is either removed or justified in the summary.
  3. orchestrate-cycle-plan.sh is materially smaller, with the extracted logic in lib/ and each
     extraction covered by the existing suite.
  4. Byte-identical --dry-run output vs. the captured pre-refactor baseline.
  5. run-all.sh green -- read the summary line AND the exit code, and do NOT pipe it through
     tail/head (that masks both; it is how a red run read as green on 2026-09-22).
  6. verify-deploy.sh --skip-slow no worse than at task start.

DEPENDENCIES AND WHY.
  - 199 declares orchestrate-cycle-plan.sh in its own file_scope and decides the working-tree /
    build isolation posture. Decomposing the file while another task is changing its behavior is
    a guaranteed conflict; 199 lands first.
  - The in-flight admission task rewrites orchestrate-batch-admit.sh, which cycle-plan calls.
    Refactoring the caller across a changing callee contract is the same hazard.

DELIVERABLE RULE: no task numbers in deliverables outside specs/** (no-task-references-in-deliverables.md).

=== WORKED EXAMPLE ADDED 2026-09-22: tests/run-all.sh IS THE FIRST PHASE-2 TARGET ===

Reported by the user as "runs very slow", then profiled. This is the concrete exemplar for what
Phase 1's probe should surface and what Phase 2 should do about it. Every number below was
measured on 2026-09-22 by timing each suite individually; re-measure before acting (standing
rule 3).

MEASUREMENT: 92 suites, 557.1 s (9.3 min) end to end, strictly serial.

  329,016 ms  test-verify-deploy-context-budget.sh   <- 59.1% OF THE ENTIRE RUN, and it is the
   39,778 ms  test-orchestrate-cycle-plan.sh             one suite currently FAILING
   21,828 ms  test-literature-convert.sh
   19,160 ms  test-git-commit-scoped.sh
   13,835 ms  test-roadmap-argv-ceiling.sh
   11,728 ms  test-orchestrate-cycle-postflight.sh
   11,086 ms  test-state-write-concurrency.sh

  Top 5 = 76.0% of total. Top 10 = 83.7%. 56 of the 92 suites finish in under 1 second.

This is an extreme long-tail profile, and it dictates the ORDER of the work.

FINDING 1 -- THE LONG POLE, AND WHY IT COSTS 329 s.
test-verify-deploy-context-budget.sh builds its fixture by rsync-ing the ENTIRE
agent-system/extensions/ tree (17 MB) into a mktemp mirror (its line 74). It does this because a
minimal fixture makes verify-deploy.sh's gates 3-13 SKIP, which would make the suite vacuous --
that is a deliberate, correct design decision, documented in the suite's own header, and it must
NOT be "fixed" by shrinking the fixture back into vacuity. It then runs verify-deploy.sh over
that full-size mirror several times; verify-deploy's own header measures a --skip-slow run at
roughly 50-70 s, and N x ~55 s accounts for the observed 329 s almost exactly. The suite already
uses --skip-slow correctly (its header notes gate 8 "would otherwise recurse"), and it has
already been hand-optimized once (three fixture mutations combined into a single invocation).
The remaining cost is structural, not sloppiness.

FINDING 2 -- THE HIGHEST-LEVERAGE FIX: verify-deploy.sh HAS NO GATE SELECTOR.
verify-deploy.sh accepts [--quiet] [--findings] [--skip-slow] [--minimal-init DIR] [TARGET_REPO]
and nothing else -- there is no --only-gate / --gate / GATE_FILTER. This suite exercises GATE 20
(the orchestrator context budget) and needs the other ~19 gates only so they do not SKIP the
fixture into vacuity. Adding a gate selector to verify-deploy.sh, and having this suite request
only the gate it asserts on, is the single largest available win in the whole harness: it should
take the suite from ~329 s toward tens of seconds, and run-all.sh from ~557 s to roughly ~250 s
on its own. Confirm by measurement, not by assumption, and confirm the suite stays non-vacuous
(the selector must not become a way to skip the gates that give the fixture its realism).

FINDING 3 -- SERIAL BY CONSTRUCTION, WITH ONE STRUCTURAL BLOCKER.
The runner loop (run-all.sh:148) executes `bash "$suite"` one suite at a time: no `&`, no `wait`,
no `xargs -P`, no job control anywhere in the file. The blocker to changing that is concrete: a
SINGLE shared `SUITE_OUT="$(mktemp)"` (line 145) is written by every suite (line 157) and
truncated between them (line 169). Per-suite output files are the prerequisite for any
parallelism. The runner also accepts only `--quiet` -- there is no `--jobs`, no `--filter`, no
`--changed`, so a developer touching one script cannot run only its suite and must pay the full
9.3 minutes.

ORDERING IS LOAD-BEARING -- DO NOT PARALLELIZE FIRST. Parallelism cannot reduce total wall time
below the longest single suite. While the long pole is 329 s, even infinite parallelism leaves
run-all.sh at 329 s -- a 41% improvement at best. Fix the long pole FIRST (Finding 2): that takes
the serial total to ~228 s, after which parallelism has a ~40 s floor (the next-longest suite)
and becomes worth doing. Sequence: gate selector -> re-measure -> per-suite output files ->
parallelism -> selective execution.

PARALLELISM MUST SHIP OPT-IN, SERIAL BY DEFAULT. The shell-test-isolation task in this backlog
already documents, with live evidence, that some suites pass in isolation and fail in a full run
because their assertions are coupled to ambient host state on the TIMING axis (a wall-clock
window that holds on an idle machine and breaks under load). Parallel execution increases
exactly that contention. That task DEPENDS on this one, so this task lands first -- therefore
ship `--jobs` defaulting to 1 (serial, today's behavior byte for byte) and leave flipping the
default to the isolation work. Do NOT make parallel the default here; doing so converts a slow
but honest gate into a fast flaky one, which the isolation task's own description argues is
strictly worse.

WHY THIS MATTERS BEYOND DEVELOPER PATIENCE. run-all.sh is verify-deploy.sh's gate 8. A slow or
flaky gate 8 slows verify-deploy, which gates deploy-headless.sh, which makes the orchestrator's
inter-cycle redeploy checkpoint defer an entire batch. Test-harness latency is on the critical
path for throughput, not merely on developer comfort.

METHOD WARNING -- THREE PLAUSIBLE-LOOKING LEADS THAT ARE FALSE. All three were checked and
refuted on 2026-09-22. Do not re-derive them, and do not let the probe in Phase 1 emit them:
  1. "~225 s of hard-coded sleeps across 32 call sites." FALSE. Those are fixture STRING LITERALS
     -- test-claude-refresh-matcher.sh synthesizes fake `ps` output containing `sleep 10`, and
     test-detect-noop-bash.sh passes "sleep 30" as a CLASSIFIER INPUT. The suite with the largest
     apparent sleep total (158 s) measures 6.9 s. A static `grep sleep` sum is meaningless here.
  2. "43 verify-deploy invocations across the suites." FALSE. That counted every textual mention
     including comments. Real executable invocations are single digits, roughly half already pass
     --skip-slow, and all target fixtures rather than the real source store -- so gate 8 never
     re-enters and there is no recursion bug to find.
  3. "Gate 8 is 43-83% of verify-deploy's runtime." FALSE. That comment in
     test-claude-refresh-matcher.sh states the FAILURE RATE of a flaky reap mechanism, not a
     runtime share.
  The general lesson, which Phase 1's probe must honor: counting occurrences of a token in shell
  source over-reports, because comments, heredocs and fixture literals are indistinguishable from
  code to grep. Where the probe reports a cost, it must measure it.

ACCEPTANCE ADDITIONS FOR THIS EXAMPLE.
  a. run-all.sh total wall time is re-measured before and after, with the per-suite breakdown
     recorded, and the improvement stated as a measured ratio rather than an estimate.
  b. Suite PASS/FAIL outcomes are identical before and after for all 92 suites -- a speedup that
     changes an outcome is a regression, not an optimization.
  c. `--jobs` (if added) defaults to 1 and serial output is byte-identical to today's.
  d. The long-pole suite remains non-vacuous: it must still fail when the eager budget is
     breached and pass when it is not. Demonstrate both directions explicitly.
  e. run-all.sh's exit code still propagates failure (it correctly exits 1 today; a parallel
     rewrite must not lose that through a pipeline or a subshell).

=== EVIDENCE ADDENDUM (2026-09-22, measured live) ===

RUN-ALL.SH WALL-CLOCK, MEASURED: ~40 minutes for a single full `run-all.sh --quiet` over the
source-store copy, with concurrent agent activity on the machine. Observed during an
/orchestrate implement dispatch, where the dispatched agent backgrounded the run and then
stopped and resumed THREE times waiting on it (cumulative agent durations 384s / 1077s / 2287s
across the stop/resume rounds) before the suite exited.

WHY THIS MATTERS BEYOND COST. The runtime is not merely expensive, it is behaviour-changing:
  - It pushed the dispatched agent into a repeated stop/park/resume cycle, which is a
    reliability problem for autonomous orchestration, not just a slow gate.
  - The load the long run generates is itself implicated in ambient-state test failures --
    `test-lake-build-guard.sh` failed inside this run and then passed 47/47 in isolation
    immediately afterwards (recorded in the shell-test-isolation task's own evidence addendum).
    So run-all.sh's runtime and its concurrency are jointly producing false reds.

SUGGESTED MEASUREMENT FOR PHASE 1'S PROBE: capture per-suite wall-clock in the inventory probe
output, not just line/byte/caller counts. The ranking for "what to speed up" needs per-suite
timing, and that data is currently collected nowhere.

=== PATH REVIEW 2026-09-28 (fifth pass): the run-all.sh worked example is CLOSED -- do not redo it ===
The test-suite runtime task completed on 2026-09-26 and delivered exactly the sequence the worked example above prescribes: verify-deploy.sh gained --only-gate; test-verify-deploy-context-budget.sh collapsed to one full battery (391 s -> ~103 s); run-all.sh gained opt-in --jobs N|auto (serial default, JOBS_CAP 4, longest-first, deterministic output, nested-invocation guard) and a durable per-suite timing baseline in that task's report. run-all.sh, test-verify-deploy-context-budget.sh and verify-deploy.sh were removed from this task's file_scope accordingly (verify-deploy.sh now belongs to the Gate 8 parallelism task).
WHAT REMAINS: Phase 1 (the standing script-inventory probe, which must reuse that task's timing baseline as its per-suite wall-clock input rather than re-measuring) and Phase 2 (the behaviour-preserving decomposition of orchestrate-cycle-plan.sh into lib/). Ordered behind the isolation-posture decision, the deploy-pending/identical-dispatch fix and the checkpoint-cost task, so the file is quiet when it is decomposed. Re-measure the 2,279-line figure first.

---

### 241. Reconcile MCP registration surfaces: redundant playwright grants, dead manifest mcp_servers fields, ownership doc and nix README
- **Status**: [PLANNED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: None
- **Research**: [241_reconcile_mcp_registration_surfaces/reports/01_reconcile-mcp-surfaces.md]
- **Plan**: [241_reconcile_mcp_registration_surfaces/plans/01_reconcile-mcp-surfaces.md]

**Description**: Reconcile the MCP registration/permission documentation and dead declaration surfaces in the agent-system source store. Four items, one coherent change: three follow-ups that agent-system/extensions/core/context/patterns/mcp-server-ownership.md records but never corrects, plus a fourth stale surface found during task research.

SOURCE-STORE RULE (binding): all edits target /home/benjamin/.config/nvim/agent-system/extensions/**. Never hand-edit any deployed .claude/** tree -- it is gitignored, disposable, and regenerated from the source store. Do NOT edit the ~/.dotfiles repository; its own separate task owns the machine-scope grants, the home-manager activation block, and the nixos registration. Do NOT touch per-project lean-lsp registrations.

ITEM 1 -- REMOVE THE REDUNDANT PLAYWRIGHT ENUMERATIONS.
agent-system/extensions/web/settings-fragment.json and agent-system/extensions/present/settings-fragment.json each carry an identical 9-entry safe-tier playwright grant list (browser_navigate, browser_snapshot, browser_take_screenshot, browser_console_messages, browser_network_requests, browser_click, browser_type, browser_find, browser_wait_for; verified byte-identical between the two). The playwright MCP server is registered at USER scope by a home-manager activation block in the separate ~/.dotfiles repository, so per this system's own governing rule -- grant permissions at the same scope where the server is registered -- the grant belongs at user scope only. Machine-scope grants for exactly these nine tools are already written into ~/.dotfiles/config/claude/settings.json and are live. Removing the two extension copies leaves one list instead of three, eliminating the drift hazard the ownership doc's "Wildcard over enumeration" section warns about: a newly added safe tool currently requires three synchronized edits, and a missed one silently reintroduces prompting with no error.

HARD PRECONDITION, RE-VERIFY AT IMPLEMENTATION TIME (not merely at task creation): the user-scope grants must be LIVE, not just committed to the dotfiles source. Run:
  jq '[.permissions.allow[]? | select(test("playwright"))] | length' ~/.claude/settings.json
The result MUST be 9 before performing any item 1 deletion. At task-creation time this returned 9 and ~/.claude.json showed playwright registered at user scope, but a home-manager rebuild between creation and implementation could regress it. If the count is not 9, DO NOT perform item 1: report it as a blocked item, leave both fragments untouched, and complete items 2-4, which have no such dependency. Removing the extension grants while user scope is empty would make every playwright call prompt in web/present projects and DENY outright in headless runs.

NO WILDCARD REPLACEMENT (binding): do NOT replace the removed enumerations with an mcp__playwright__* wildcard anywhere. The enumeration exists specifically to withhold browser_evaluate, browser_run_code_unsafe and browser_file_upload, which execute arbitrary code or read arbitrary local files onto a page and MUST keep prompting. This is the documented safe/unsafe carve-out to the wildcard preference, not an oversight to simplify.

ITEM 2 -- DELETE THE FIVE DEAD manifest.json mcp_servers FIELDS.
agent-system/extensions/{filetypes,founder,lean,memory,nix}/manifest.json each carry an mcp_servers field. Nothing in the loader reads it to write ~/.claude.json, so it registers nothing; it is inert dead weight that reads as working configuration to a future maintainer. Verified present in exactly these five and no others. This is a pure removal: no grant changes accompany it.

Task research already confirmed there is NO dangling reader: a sweep of every .sh/.py/.lua/.json/.md in the source store found no loader, lint, or verify-deploy script reading the field. The only references are documentation that already describes it as inert (core/docs/architecture/extension-system.md lines 227 and 498, core/docs/guides/creating-extensions.md lines 103 and 120, core/docs/guides/adding-domains.md line 115, core/templates/extension-readme-template.md line 68); those stay correct after deletion and need no follow-on edits. Re-confirm this sweep before deleting, and if a reader has appeared since, update it in the same task rather than leaving it dangling.

Two specifics worth preserving: nix's block declares the server under the trap name mcp-nixos, which would produce mcp__mcp-nixos__* tools and break the existing mcp__nixos__nix / mcp__nixos__nix_versions grants and every doc cross-reference -- deleting it removes a live footgun, and the correct registration under the name nixos now lives in the dotfiles activation block. lean's block is likewise inert: lean-lsp is registered per-project in LOCAL scope by a SessionStart hook, not by any manifest.

OUT OF SCOPE, DO NOT CONFLATE: agent-system/extensions/memory/settings-fragment.json's mcpServers block is a DIFFERENT file and a DIFFERENT mechanism from the manifest.json mcp_servers fields. It is owned by existing task 30 (register obsidian memory mcp server). Leave it exactly as it is -- it is the only remaining mcpServers block anywhere in the source store. Item 2 removes memory's manifest.json mcp_servers field only.

COMPLEMENTARY, NOT CONFLICTING: existing task 29 (generate mcp json from extension manifests) introduces a NEW merge_targets.mcp key with a per-extension source file, and explicitly routes away from both dead surfaces. Deleting mcp_servers now does not conflict with it and creates no dependency in either direction. Recorded here so a future reader does not re-litigate it.

ITEM 3 -- CORRECT THE OWNERSHIP DOC, WHICH IS NOW STALE.
agent-system/extensions/core/context/patterns/mcp-server-ownership.md is the SOURCE. (~/.dotfiles/.claude/context/patterns/mcp-server-ownership.md is a deploy copy that regenerates and must NOT be hand-edited.) Four passages:

(a) Its "Grant permissions at the same scope where the server is registered" section calls playwright "the live counter-example -- registered in user scope, but its 9-tool safe-tier enumeration appears only inside the web and present extensions' settings-fragment.json files, with zero mcp__playwright__* entries in ~/.claude/settings.json itself", and says fixing the asymmetry is "a separate follow-up, not performed here -- it is recorded, not corrected, by this document". Once the dotfiles grants are live and item 1 lands, this is resolved. Rewrite to describe the corrected end state, KEEPING playwright as a worked example of correct user-scope grant placement rather than deleting the passage -- the reasoning is still instructive. If item 1 was blocked by its precondition, leave passage (a) unchanged and say so explicitly in the summary.

(b) Its "Known gaps" section says five extensions "additionally carry the identical dead declaration in their manifest.json mcp_servers field" and calls correcting it "a recorded follow-up, not performed by this document's own edits". Item 2 performs it; update accordingly.

(c) Its "Wildcard over enumeration" section describes the lean-lsp triple duplication (a wildcard in core's root-files/settings.json, a 21-entry enumeration in lean's settings-fragment.json, and a dead mcpServers block) and states "The correct end state is one wildcard in lean's own fragment and nothing in core." That end state has ALREADY been reached -- verified live during task research: core's root-files/settings.json has 0 lean entries, lean's settings-fragment.json has exactly one (the mcp__lean-lsp__* wildcard), and the dead mcpServers block is gone. The doc still describes it in the present tense as an outstanding defect. Rewrite to record it as a completed worked example rather than a pending one.

(d) Its "Known gaps" section lists memory (obsidian-memory) carrying a dead mcpServers block in its settings-fragment.json as "a genuine, still-open gap". That block IS still present and existing task 30 covers registering that server properly, so this entry STAYS OPEN. Do NOT mark it resolved.

ITEM 4 -- CORRECT THE NIX README REGISTRATION PASSAGE.
agent-system/extensions/nix/README.md lines 26-34 assert that mcp-nixos is "not currently registered by anything in this repository", that "no such mechanism exists yet for this server", and that "Registering this server in user scope is a pending follow-up". All three are now false: ~/.claude.json registers nixos at user scope via the home-manager activation block in ~/.dotfiles -- precisely the mechanism the passage names as hypothetical. The same passage also refers to "The mcpServers block that may appear in this extension's settings-fragment.json"; nix's settings-fragment.json contains no such block (memory's is the only one left in the source store), so that sentence is a dangling reference and should simply be dropped rather than rewritten. Net effect today: a reader of this README is told to expect the WebSearch/CLI degradation path as the normal case when the MCP path is in fact live.

Rewrite the passage to record user-scope registration under the name nixos, and to reinforce why the trap name mcp-nixos is being deleted from the manifest in item 2.

DO NOT BLANKET-RENAME (binding): only the registration passage at lines 26-34 changes. The other six occurrences of mcp-nixos in this README (lines 3, 18, 23, 92, 101, 195) are the upstream project/package name -- the uvx mcp-nixos invocation, the tools column, and the GitHub project URL -- and are all correct as-is. Only the SERVER REGISTRATION NAME is nixos. Conflating the two would reintroduce the same class of confusion item 2's deletion removes. The README's conditional "when MCP is unavailable" degradation framing also stays as-is.

DO NOT EDIT: agent-system/extensions/nix/context/project/nix/tools/mcp-nixos-integration.md was read in full during task research and needs NO correction. It is written conditionally throughout ("When configured, it lets agents verify...", "Agents gracefully degrade to WebSearch and CLI commands when MCP is unavailable"), and already uses the correct tool names mcp__nixos__nix and mcp__nixos__nix_versions, never the trap name. It is properly future-proofed and now simply describes the live state.

FILE SCOPE (nine files, all under agent-system/extensions/):
- web/settings-fragment.json, present/settings-fragment.json  (item 1)
- filetypes/manifest.json, founder/manifest.json, lean/manifest.json, memory/manifest.json, nix/manifest.json  (item 2)
- core/context/patterns/mcp-server-ownership.md  (item 3)
- nix/README.md  (item 4)

VERIFICATION: jq empty on all seven edited JSON files; confirm zero mcp__playwright__* entries remain in the web and present fragments and that no wildcard was introduced in their place; confirm zero mcp_servers fields remain in any agent-system/extensions/*/manifest.json; confirm memory/settings-fragment.json's mcpServers block is byte-identical to its pre-change state; confirm ownership doc Known-gap (d) still reads as open; doc-lint passes for core, nix, web and present; run bash .claude/scripts/deploy-headless.sh and confirm it lands green.

DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 223. Record the Comparator-on-NixOS fixes in the lean extension
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: lean-extension
- **Dependencies**: None
- **Research**: [223_record_comparator_nixos_fixes_in_lean_extension/reports/01_comparator-nixos-fixes.md]
- **Plan**: [223_record_comparator_nixos_fixes_in_lean_extension/plans/01_comparator-nixos-fixes.md]

**Description**: Record the Comparator-on-NixOS fixes in the lean extension source store (~/.config/nvim/agent-system/extensions/lean, not .claude/): update context/project/lean4/domain/comparator-integration.md, context/project/lean4/tools/comparator-guide.md and scripts/lean-comparator-run.sh (with scripts/tests/test-lean-comparator-run.sh) so a Comparator run works on this host. Fixes found while certifying framed_channel: (1) put the pinned toolchain bin/ before the elan shim on PATH, since landrun cannot execute the shim (the `lake: Permission denied` failure the design record notes but never explains); (2) invoke as `lake env comparator config.json`; (3) point TMPDIR inside the writable .lake directory because bv_decide writes SAT files to /tmp, which the sandbox makes read-only; (4) grant --rox on git's nix store libraries, otherwise Lake decides the package URL changed and deletes .lake/packages/<dep>. Also document: lean4export panics when permitted_axioms names an axiom absent from the Challenge (handle a flagged bv_decide row by permitting only the trusted axioms and requiring the exact Illegal axiom rejection, which still proves the statement matches); `lake update` in a tool-pinning package silently rewrites lean-toolchain unless --keep-toolchain; batched Lean4Lean runs can exceed 19 GB and trigger earlyoom, so run one module per process; an outer landrun around lake env and Comparator itself. Reference implementation: framed_channel/recheck-comparator.sh, recheck-revs.sh and comparator-configs.sh in this repository, and the task 32 report and summary. Redeploy .claude/ afterwards.

ORIGIN: moved from the ~/Projects/Logos/Verification task list, where it was researched; the research report was copied here as reports/01_comparator-nixos-fixes.md. The reference implementation it transcribes lives in ~/Projects/Logos/Verification/framed_channel/ (recheck-comparator.sh, recheck-revs.sh, comparator-configs.sh). Task numbers inside the report refer to that repository's task list.

=== ABSORBED 2026-09-28 (path review, fifth pass) from former task 177 (lean4_dependency_tracing_recipe); that task is abandoned into this one. Its text follows verbatim; where it names "the dependency task" or "the sibling task", read this task's other sections. ===

Add a dependency-tracing recipe to the lean4 extension context: how to mechanically answer "does X depend on Y?" in a Lean 4 environment, and why `#print axioms` cannot answer it.

WHY THIS EXISTS. A trace task in ~/Projects/BimodalLogic had to answer whether a decision procedure depended on a set of theorems whose hypotheses had been refuted. The task's own description demanded a MECHANICAL trace ("a prose argument that it probably doesn't is not the deliverable"), and no recipe existed -- the probes were invented from scratch. They worked, are re-runnable, and generalize. The finished probes and their verbatim output live at `~/Projects/BimodalLogic/specs/549_trace_decide_dependency_on_vacuous_run_theorems/probes/` (`DepTrace.lean`, `DepTrace2.lean`, `RevDep.lean`, `Widen.lean`, `Ax.lean`, `Exists.lean`, plus `probe-evidence.md`). Harvest them from there; do not re-derive.

THE LOAD-BEARING CAVEAT, and the reason this is worth writing down at all. `#print axioms` is NOT a dependency tracer. In the observed case the decision procedure, its soundness theorem, AND the vacuous theorem under suspicion all reported the same `[propext, Classical.choice, Quot.sound]`. An axiom check answers "is this sound?", never "what does this rest on?" -- yet it is the first probe most people reach for, and it would have returned a confidently useless answer. State this explicitly and early in the recipe.

FOUR PROBE SHAPES TO DOCUMENT AS REUSABLE TEMPLATES:
1. Forward transitive closure over the environment -- `Expr.getUsedConstants` over both type and value, iterated to a fixed point from a named entry point, then intersected with a suspect set. This is the primary tool.
2. The module-index variant -- resolve which module each reached constant came from, and count the hits attributable to a target module. Answers "how much of module M does X touch?" in one number.
3. Whole-environment reverse-dependency scan -- iterate every declaration in the environment and report those whose closure contains a suspect. Answers "what would break if I deleted this?", which is the question a retirement decision actually needs.
4. Import-closure check -- whether the target's module is even reachable via transitive imports. Distinguishes "unused" from "unavailable", a meaningfully stronger result.

ALSO WORTH RECORDING: run probes with `lake env lean` against existing oleans rather than a full `lake build` -- the observed trace needed no rebuild at all. And note the failure mode that bit the source task: line numbers cited in a research report go stale quickly in a large file, so probes should resolve declarations by name.

SCOPE. Create `agent-system/extensions/lean/context/project/lean4/patterns/dependency-tracing.md` in the SOURCE STORE (never `.claude/**`, which is a regenerated deploy artifact -- see rules/source-store-deploy-boundary.md). Wire it into the lean4 context index the way sibling pattern files are wired; follow the existing single-statement-plus-pointer convention rather than restating the model at the pointer site.

PRIORITY: low, and genuinely optional. This is a recipe harvested from one successful use, not a defect fix -- nothing is broken without it. Its value is that the next such trace does not start from zero, and that the `#print axioms` trap is documented before someone falls into it.

ACCEPTANCE. The four probe shapes are reproduced as templates a reader can adapt without access to the originating repository. The `#print axioms` caveat is stated explicitly, with the concrete observation that three declarations at different dependency depths all reported identical axioms.

---

### 217. Cost-aware idle Lean tree reclamation in /refresh: PSS accounting, CPU-delta idleness, notify-before-kill
- **Effort**: 2 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 174

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**, a disposable deploy artifact).

OBSERVED LIVE (2026-09-15): a Lean LSP tree was reported as "15.1 GB" reclaimable while earlyoom showed 14-16.6 GB available throughout; real reclaim was ~2.3 GB swap plus a little anon. User policy: idle trees that cost nothing may stay; trees that cost memory get a prompt (never a silent kill) after being idle a while. Memory floor 1 GB approved.

DEFECT. run_claude_pass and run_lean_pass in scripts/claude-refresh.sh both sum per-process RSS + VmSwap (get_vmswap_kb). Lean workers share mmapped Mathlib .olean files (5.6 GB lib), so shared pages are counted once per worker, and file-backed pages are evictable page cache anyway.

WORK.
(a) Add one shared memory helper used by BOTH passes: read $PROC_ROOT/PID/smaps_rollup; reclaimable = Pss_Anon + SwapPss. Report Pss_File separately as "shared cache (not counted)". When smaps_rollup is unreadable, fall back to RSS + VmSwap and label the figure approximate. Read only for candidates (not every process).
(b) Update both passes' report format to show reclaimable (and approximate marker) plus shared cache.
(c) Correct the in-script pcpu comment: procps-ng ps pcpu is lifetime cputime/elapsed, NOT a decaying average. (The idle gate itself is replaced by a follow-on task; only fix the comment here.)
(d) Tests in scripts/tests/test-claude-refresh-matcher.sh: fixture-based /proc via PROC_ROOT covering smaps_rollup parsing (Pss_Anon, SwapPss, Pss_File), shared-page de-duplication across multiple workers, and the unreadable fallback label.

MUST NOT. Change UID/system-slice safety predicates or termination ordering. Edit .claude/**.

ACCEPTANCE. Fixture of N workers sharing a large Pss_File reports reclaimable = sum(Pss_Anon+SwapPss) and shared cache separately; fallback path labeled approximate; test suite passes; shellcheck clean; redeploy and confirm.

DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

=== ABSORBED 2026-09-17 from former task 218 (CPU-delta idleness and the memory-floor cost gate); that task is abandoned into this one. Its text follows verbatim; where it names "the dependency task" or "the sibling task", read this task's other sections. ===
SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**, a disposable deploy artifact).

OBSERVED LIVE (2026-09-15): a Lean LSP tree was reported as "15.1 GB" reclaimable while earlyoom showed 14-16.6 GB available throughout; real reclaim was ~2.3 GB swap plus a little anon. User policy: idle trees that cost nothing may stay; trees that cost memory get a prompt (never a silent kill) after being idle a while. Memory floor 1 GB approved.

DEFECT. lean_row_is_idle uses ps etimes (process AGE) plus ps pcpu, which in procps-ng is lifetime cputime/elapsed. Any long-lived tree reads <1%, so an actively used 5h-old tree counts as "idle".

WORK (consumes the reclaimable figure from the PSS memory helper, hence the dependency).
(a) CPU-delta idle tracking: per-tree state in ~/.local/state/claude-refresh/lean-trees.json keyed by root pid + process starttime (/proc/PID/stat field 22). Each run, store the summed utime+stime of all tree members; if it increased since the last run, reset last_active; idle_for = now - last_active. Replace the pcpu/etimes gate entirely. Hourly run granularity is acceptable. Prune entries for trees that no longer exist.
(b) State file writes atomic (tmp + mv). Tolerate a missing or corrupt file: treat as first sighting, NEVER as idle.
(c) Cost gate: a tree is prompt-eligible only when idle_for >= LEAN_LSP_IDLE_THRESHOLD_MIN (default 240) AND reclaimable >= LEAN_LSP_MEM_FLOOR_MB (default 1024). Otherwise report it as "idle, cheap, kept" (or active). Interactive /refresh uses this same gate and the same numbers for its existing AskUserQuestion prompt.
(d) Tests (fixture /proc via PROC_ROOT, fixture state dir): CPU-delta idle state machine (first sighting not idle; unchanged cputime accrues idle_for; increased cputime resets), pid reuse with different starttime treated as a new tree, corrupt/missing state file, floor gate both sides of the threshold.
(e) Update Pass Inventory rows in commands/refresh.md and skills/skill-refresh/SKILL.md for the new idle definition and cost gate.

MUST NOT. Kill anything silently. Change UID/system-slice predicates or termination ordering. Edit .claude/**.

ACCEPTANCE. Active 5h-old tree whose cputime grows is never idle; a tree idle >=240 min with <1 GB reclaimable is reported kept; tests pass; shellcheck clean; redeploy and confirm.

DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

=== ABSORBED 2026-09-17 from former task 219 (notify-before-kill prompt path with snooze); that task is abandoned into this one. Its text follows verbatim; where it names "the dependency task" or "the sibling task", read this task's other sections. ===
SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**, a disposable deploy artifact).

OBSERVED LIVE (2026-09-15): a Lean LSP tree was reported as "15.1 GB" reclaimable while earlyoom showed 14-16.6 GB available throughout; real reclaim was ~2.3 GB swap plus a little anon. User policy: idle trees that cost nothing may stay; trees that cost memory get a prompt (never a silent kill) after being idle a while. Memory floor 1 GB approved.

WORK (builds on the cost gate and per-tree state file).
(a) Prompt path: when the headless hourly run (--dry-run) finds an eligible tree that is not snoozed or already prompted, launch a detached `systemd-run --user --unit=claude-refresh-prompt-<rootpid>-<starttime>` (the unit name must NOT match claude-*.scope, which the user's claude-session-reaper stops) running `notify-send -a claude-refresh -u critical -t 0 -A default=Kill --wait "Idle Lean tree (<project>)" "idle Xh, N GB reclaimable -- click to kill, dismiss to keep 4h"` (or equivalent that blocks on the chosen action). Project = lake serve cwd (/proc/PID/cwd).
    DESIGN REFINEMENT (notification daemon): the user runs mako with no dmenu-style action launcher, so named notify-send actions cannot be selected by clicking. Therefore use a single `-A default=Kill` action (mako left-click invokes the default action) and treat dismiss / right-click / expiry / no action returned as "Keep" (snooze). Pass `-t 0` so the notification does not auto-expire. The complementary mako rule ([app-name=claude-refresh] default-timeout=0) and the NixOS home-manager install of the timer/service with a correct PATH are handled by a separate ~/.dotfiles task (external, not in this repo).
(b) On the default action ("Kill", i.e. left-click): run `claude-refresh.sh --lean-tree <pid>:<starttime> --force`. The new --lean-tree mode re-verifies starttime identity, still idle, and still over the floor before the existing ordered workers -> server -> root termination; if anything changed, skip and log.
(c) On dismiss / right-click / expiry / any non-default outcome (treated as "Keep"): record snooze_until = now + LEAN_LSP_SNOOZE_MIN (default 240) in the state file. Dedupe so a tree is prompted at most once per snooze window (record prompted state before launching).
(d) Degrade gracefully when notify-send, systemd-run, or a DBus session bus is absent: log only, never kill.
(e) The hourly unit (systemd/claude-refresh.service) ExecStart stays --dry-run; prompting happens only in the separate transient unit. Keep generic units portable, but document that Environment=PATH=/usr/bin:/bin is broken on NixOS and that NixOS installs these units via home-manager (the dotfiles change is a separate task).
(f) Interactive /refresh keeps its AskUserQuestion prompt with the shared gate and numbers.
(g) Tests (fixture /proc via PROC_ROOT, stubbed notify-send/systemd-run on PATH): stubbed notify-send printing "default" -> kill path, printing nothing/other -> snooze path, starttime re-verification refusal (pid reused), still-idle/still-over-floor re-check refusal, snooze dedupe (no second prompt inside window, prompt again after expiry), missing notify-send/systemd-run/DBus degrades to log-only, unit name never matches claude-*.scope.
(h) Docs: commands/refresh.md and skills/skill-refresh/SKILL.md (Pass Inventory rows, --lean-tree flag, env vars LEAN_LSP_IDLE_THRESHOLD_MIN / LEAN_LSP_MEM_FLOOR_MB / LEAN_LSP_SNOOZE_MIN, prompt flow, NixOS note).

MUST NOT. Kill without explicit user action. Change UID/system-slice predicates or termination ordering. Edit .claude/**.

ACCEPTANCE. Tests pass; shellcheck clean; redeploy and confirm; a manual end-to-end check shows one notification per snooze window and a left-click Kill that refuses when the tree became active, and a dismiss that records a 4h snooze.

DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 185. Retarget stage citations to move vocabulary
- **Status**: [NOT STARTED]
- **Task Type**: markdown
- **Topic**: core-agent-system
- **Dependencies**: Task 266, Task 199, Task 184

**Description**: Retarget the remaining historical "Stage N" and "Stage MT-N" citations to the four-move loop vocabulary.

CONTEXT. skill-orchestrate/SKILL.md was rewritten from a two-engine, Stage-numbered state machine (single-task Stages 0-8; multi-task Stages MT-1 through MT-5) into a single four-move loop whose sections are named Move 1 through Move 4. Roughly 120 citations of the old vocabulary remain across 9 context/ and docs/ files. They now point at section names that no longer exist in the file they cite.

KNOWN SITES (from the rewrite's own survey; re-verify by grep rather than trusting this list):
  context/patterns/batch-orchestration-guardrails.md  -- 34 occurrences, the largest single concentration
  docs/architecture/handoff-schema.md
  docs/architecture/orchestrate-cycle-postflight.md
  docs/architecture/batch-admit-schema.md
  context/patterns/orchestrate-batch-results-template.md
  plus four further context/ and docs/ files

WHY IT WAS DEFERRED. The rewrite judged a ~120-citation mechanical sweep disproportionate to its core scope and recorded it as a follow-up rather than attempting it inline.

SCOPE AND CARE. This is a mechanical retarget, not a rewrite of the surrounding prose. Two hazards to respect: (1) some citations are historical-by-intent -- they describe what a now-deleted engine did, in a decision record or incident narrative, and must keep naming the old stage rather than being rewritten to a Move that never had that behavior; distinguish "cites a live section" from "narrates history" before editing. (2) Edit the source store under agent-system/extensions/** and never the deployed .claude/ tree (see rules/source-store-deploy-boundary.md).

ACCEPTANCE: every citation that refers to a LIVE section names the correct Move; every historical citation is either left intact or explicitly marked as historical; a grep for "Stage MT-" and for single-task "Stage [0-8]" returns only intentional historical references; deploy and the full gate run stay green.

=== PATH REVIEW 2026-09-28: scope and ordering ===
file_scope now names the five known sites; research MUST add the remaining files (a grep for 'Stage MT-' and single-task 'Stage [0-8]' matched 72 files under core/context, docs, skills and commands on 2026-09-28, most of them historical-by-intent) to file_scope before the implement dispatch. Ordered behind the three engine tasks that are actively editing batch-orchestration-guardrails.md and handoff-schema.md, so the mechanical sweep runs over settled text.

---

### 184. Surface skeleton-plan follow-ups at completion under the batch engine (ruled: port the sorry_inventory follow-up report, not pr_ready routing)
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 242, Task 243, Task 258, Task 259, Task 266

**Description**: === RULED 2026-09-22 (eighth-pass phase 0) ===
Disposition: option (a), narrowed to what was actually lost. The single-task engine's skeleton-exhaustion branch did three things: (1) routed the task to completion via the pr_ready target, (2) propagated a completion summary, (3) derived and reported follow-up tasks from sorry_inventory[].follow_up_task. Under the batch engine (1) is moot: pr_ready is a type=pr-only terminus, and every other task completes through orchestrate-cycle-postflight.sh's completion-claim gate, which a skeleton plan with all phases complete already reaches (orchestrate-cycle-plan.sh's 'no OPEN heading' fallthrough, ~line 2003, and the porting note at ~line 1921). (2) is owned by postflight generally. Only (3) is lost: a skeleton plan completes with its sorry_inventory silently dropped, so the strategic sorries never become tasks.

SCOPE (now concrete; no further decision phase). In orchestrate-cycle-postflight.sh, when the final implement handoff carries skeleton=true and a non-empty sorry_inventory[]: (i) print the follow_up_task entries in the cycle's stderr report and include them in the task's completion summary section; (ii) record them on the state.json entry in an append-only field (research picks the field -- a skeleton_follow_ups array or reuse of the memory_candidates shape -- and state-management-schema.md documents it); (iii) do NOT auto-create tasks: the report is the handoff and the user files them with /task. Document in status-markers.md and handoff-schema.md how a skeleton plan terminates now (through the completion-claim gate, follow-ups reported). Regression test in scripts/tests/test-orchestrate-cycle-postflight.sh with a skeleton=true fixture whose sorry_inventory has two entries. Options (b) and (c) of the original text are closed by this ruling. ORDERING: after 242 (same postflight script and test) and 243 (handoff-schema.md), recorded as dependency edges. The original decision text follows for the record.

Decide the disposition of the Lean/formal skeleton-plan completion routing lost with the single-task engine.

CONTEXT. The deleted single-task /orchestrate engine carried a skeleton-exhaustion completion branch: when no incomplete phase heading remained AND the last handoff declared skeleton=true, it derived a follow-up task list from the handoff's sorry_inventory[].follow_up_task entries, routed the task to completion via update-task-status.sh postflight with the pr_ready target and --allow-pr-ready, and reported the pending follow-ups. The surviving batch engine has no equivalent branch.

WHY THIS ONE NEEDS A DECISION AND HAS NOT HAD ONE. The rewrite recorded TWO capability losses. The loop-guard staleness detector got an explicit recommended follow-up. This one was recorded as a permanent loss with NO follow-up named at all -- it is the only deviation in that summary left without a next step. Lean and formal work is live in this repository, so silent acceptance should be a deliberate choice rather than an oversight.

SCOPE. Determine whether strategic-sorry skeleton plans can still reach a correct terminal status under the batch engine, and if not, what should happen. Evaluate at least: (a) port the skeleton-exhaustion branch into orchestrate-cycle-plan.sh or orchestrate-cycle-postflight.sh; (b) require skeleton plans to close through a different, already-supported path; (c) accept the loss explicitly and document how a skeleton plan is expected to terminate now. Do not pre-commit to an option.

EVIDENCE. The assertions covering this mechanism (.skeleton / last_skeleton and .sorry_inventory / follow_up_tasks) were removed from scripts/tests/test-handoff-reader-parity.sh. Recorded under "Plan Deviations" in specs/088_mode_gate_skill_orchestrate_multi_task_section/summaries/01_four-move-loop-rewrite-summary.md. Related policy: the strategic-sorry skeleton allowance in context/contracts/recovery.md.

ACCEPTANCE: a recorded decision with rationale; if a gap is confirmed, either a working path to terminal status for skeleton plans with test coverage, or documentation naming the expected terminus.

---

### 170. Audit and isolate shell test suites from ambient host state (memory and timing axes), and record the convention
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 51, Task 129, Task 151, Task 169, Task 206, Task 215, Task 250, Task 251

**Description**: Audit all shell test suites in the source store for assertions whose outcome depends on ambient host state, isolate each at the script-under-test's own documented env seams (or, where no seam is possible, by a technique appropriate to the axis), and record the isolation convention in `context/standards/shell-script-testing.md` so future suites inherit it by default.

=== TWO CONFIRMED INSTANCES -- THE DEFECT CLASS IS NOT A SINGLE-SUITE ANOMALY ===

Both were observed live. They sit on DIFFERENT axes and need DIFFERENT remedies.

--- INSTANCE A (memory axis) -- `test-lake-build-guard.sh`, cases 1, 3, 11 ---

Failed because `lake-build-guard.sh` read the REAL `/proc/pressure/memory` and `/proc/meminfo`,
and the host was swapping at 57% of SwapTotal -- over the guard's own
`SWAP_USED_RATIO_THRESHOLD=50`. Cases 1 and 3 assert byte-identical transparency on the guard's
clean path; case 11 asserts preflight exits 0 when the PSI path is unavailable. All three pass on
an idle machine and fail on a busy one -- and a busy machine is exactly what a multi-task
`/orchestrate` batch produces.

ALREADY FIXED -- DO NOT REDO. Commit `878043472` isolates this suite suite-wide by redirecting
`LAKE_BUILD_GUARD_PSI_PATH` and `LAKE_BUILD_GUARD_MEMINFO_PATH` to clean fixture files in the
suite's own mktemp workdir, via the script's documented env seams. Verified 27/27 pass and
verified non-vacuous. This suite is the EXEMPLAR the audit generalizes from, not work to repeat.
The separate positive-direction case for it is tracked as its own prerequisite task (this task
depends on it) -- do not duplicate that either.

--- INSTANCE B (timing axis) -- `test-four-tier-conflict.sh`, case 6 "budget-bound" ---

CONFIRMED AFFECTED, NOT YET FIXED. This one is the task's primary unsolved exemplar.

Evidence, all observed live:
  - Pre-fix full `run-all.sh`: this suite PASSED (only `test-lake-build-guard.sh` failed).
  - Post-fix full `run-all.sh`: this suite FAILED with
      `6: budget-bound -- rc=1 elapsed_ms=2989 budget_ms=1000`
  - Immediate ISOLATED re-run of the same suite: PASSED, with
      `6: budget-bound -- exhaustion elapsed 1752ms within [1000ms, 2000ms)`

Commit `878043472` touched exactly one file (`test-lake-build-guard.sh`), so it cannot have
caused this. The discriminating fact is the isolated re-run passing. The assertion at
`test-four-tier-conflict.sh:294` is a wall-clock window:

    [ "$rc6" -eq 1 ] && [ "$elapsed6_ms" -ge "$BUDGET_MS" ] && [ "$elapsed6_ms" -lt $(( BUDGET_MS * 2 )) ]

with `BUDGET_MS=1000`. The window `[1000ms, 2000ms)` holds on an unloaded machine and breaks under
concurrent load. Same "outcome determined by ambient host state" shape as instance A, on the
timing axis instead of the memory axis.

ADJACENT, SAME SUITE, LIKELY SAME DEFECT: case 5 (`test-four-tier-conflict.sh:271`) asserts
`elapsed5_ms -lt 500` as a proxy for "the retry loop was never entered". That is the same
wall-clock-as-proxy shape and is expected to flake under load for the same reason; triage it
alongside case 6 rather than treating case 6 as isolated. Case 1 also reports elapsed wall
clock -- check whether it merely reports or actually asserts on it.

--- WHAT THE SECOND INSTANCE CHANGES ABOUT SCOPING ---

1. The audit premise is confirmed empirically, not speculative.
2. The timing axis is genuinely represented, so the audit MUST cover wall-clock windows and
   elapsed-time proxies, not only `/proc` reads.
3. The shell-test-suite gate is currently FLAKY, not simply red: `run-all.sh` has now failed
   twice in a row for two DIFFERENT single-suite reasons. Acceptance is set accordingly below.

=== BLAST RADIUS (why this warrants a dedicated audit, not a one-off patch) ===

A single suite failure fails `verify-deploy.sh`'s shell-test-suite gate (1 of 30 checks), which
fails `deploy-headless.sh`, which makes `skill-orchestrate`'s inter-cycle redeploy checkpoint
defer an ENTIRE orchestrate batch. One host-coupled assertion in one suite stalls unrelated work.
The defect class is load-bearing on throughput, not merely on test hygiene. A flaky gate is worse
than a red one: it defers batches nondeterministically and trains readers to re-run rather than
diagnose.

=== THE DEFECT CLASS TO HUNT ===

Any assertion whose outcome depends on ambient host state:
  - memory (`/proc/meminfo`, `/proc/pressure/memory`, swap usage, `free`)          [instance A]
  - wall-clock timing (elapsed-time windows, `sleep`-dependent ordering,
    `date +%s` / `%N` deltas, `SECONDS`, `timeout` values tuned to a fast machine)  [instance B]
  - load / CPU count (`/proc/loadavg`, `nproc`, `getconf`, `uptime`)
  - network reachability (`curl`, `wget`, `ping`, DNS, any live API)
  - free disk (`df`)
  - the process table (`pgrep`, `ps`, PID reuse, pre-existing processes matching a pattern)
  - anything else read from the live host rather than from a fixture

=== SURVEY ALREADY PERFORMED (starting point, NOT the answer) ===

72 files match `test*.sh` under `agent-system/extensions/**`. A keyword grep over the signals
above flagged 25. Ordered by raw hit count:

  13  core/scripts/test-four-tier-conflict.sh               (INSTANCE B -- confirmed affected)
  12  core/scripts/tests/test-lake-build-guard.sh           (INSTANCE A -- already isolated)
   6  literature/scripts/test-lit-pipeline.sh
   6  core/scripts/tests/test-validate-state.sh
   6  core/scripts/tests/test-claude-refresh-matcher.sh
   4  core/scripts/test-state-write-concurrency.sh
   3  literature/scripts/tests/test-literature-convert.sh
   3  lean/scripts/tests/test-lean-comparator-run.sh
   3  core/scripts/tests/test-loop-guard-budget-override.sh
   2  literature/scripts/tests/test-literature-discover-tier3.sh
   2  core/scripts/tests/test-subagent-postflight-marker.sh
   2  core/scripts/tests/test-lint-branch-gated-sections.sh
   2  core/scripts/tests/test-handoff-dispatch-identity.sh
   2  core/scripts/test-state-write-regen-timing.sh
   2  core/scripts/test-session-registry.sh
   2  core/scripts/test-conflict-predicate.sh
   1  each: core/scripts/test-task-lock-reap.sh, core/scripts/test-session-runtime-files.sh,
          core/scripts/tests/{test-validate-return-meta,test-status-vocabulary,
          test-skill-base-lifecycle,test-phase-heartbeat,test-phase-heading-patterns,
          test-guard-destructive-git,test-common-lib}.sh

Both confirmed instances rank first and second, which is mild evidence the ranking carries signal
-- but RAW HIT COUNT IS NOT SEVERITY, and this list is neither sound nor complete:
  - FALSE POSITIVES ARE EXPECTED. A `sleep` inside a concurrency suite that deliberately
    exercises lock contention may be legitimate; `pgrep` inside a suite whose subject IS process
    matching (`test-claude-refresh-matcher.sh`, `test-task-lock-reap.sh`) may be exercising the
    real behavior under test. Triage each hit; do not mechanically "fix" every match.
  - FALSE NEGATIVES ARE LIKELY. The grep cannot see host coupling entering through a library the
    suite sources, through the script under test rather than the suite itself (exactly how
    instance A arrived), or through a helper that shells out. Read the scripts under test, not
    only the suites. Suites absent from this list are NOT thereby cleared.
  - Names containing `timing`, `concurrency`, `heartbeat`, `budget`, `reap`, or `staleness` are
    prior-suspect on the timing axis regardless of hit count.

=== REQUIRED APPROACH -- SEAM-FIRST, BUT DO NOT PRESUME THE SEAM REMEDY TRANSFERS ===

For state READ FROM A FILE OR COMMAND (the memory/`proc`/disk/network/process axes), instance A's
remedy is the model:
  1. Identify the script-under-test's OWN documented env seam (`lake-build-guard.sh` provides
     `LAKE_BUILD_GUARD_PSI_PATH` / `LAKE_BUILD_GUARD_MEMINFO_PATH`). Prefer an existing seam.
  2. If none exists, adding one to the script under test is in scope -- but it must be a genuine,
     documented override point with a real-host default, NEVER a test-only branch or an
     "if running under test" conditional.
  3. Point the seam at a fixture authored into the suite's own mktemp workdir, per the existing
     fixture convention in `context/standards/shell-script-testing.md` (heredoc-authored, fresh
     per case where staleness would otherwise mask behavior, never resolved against the live tree).

For WALL-CLOCK TIMING (instance B), THE SEAM REMEDY MAY NOT APPLY AT ALL. There may be nothing to
redirect: the quantity is elapsed real time, not a readable input. Do not force the memory-case
technique onto it. Evaluate at least these, per assertion, and justify the choice:
  - Inject the clock -- give the script under test a seam for its time source so the suite can
    drive elapsed time deterministically. Strongest option where feasible.
  - Assert ORDERING or CAUSALITY instead of elapsed wall clock -- e.g. for case 6, that the retry
    loop terminated on budget exhaustion rather than on a lock acquisition, and for case 5, that
    the retry loop was never entered at all. Both are the property the elapsed-time window is
    only a PROXY for; asserting the property directly removes the host coupling without weakening
    anything. Prefer this where the underlying property is observable (a counter, a log line, a
    return path).
  - Widen the window to generous-but-still-bounded ONLY as a last resort, and only when the
    widened bound still falsifies the failure mode the assertion exists to catch (for case 6:
    "nowhere near a minutes-scale wait"). A bound that no longer discriminates is a deleted test.
    This option requires explicit justification in the summary naming what it still catches.

NON-VACUOUSNESS CHECK PER ISOLATED SUITE, MANDATORY on every axis. After isolating, demonstrate
the logic under test is still genuinely exercised -- typically by driving the opposite direction
with a fixture or condition that SHOULD trip the behavior and confirming it does. An isolation
that makes a suite assert nothing is worse than the host coupling it replaced. Record each check.

=== CONSTRAINTS ===

- All edits target `agent-system/extensions/**` ONLY. Never hand-author anything under
  `.claude/**`; that tree is a disposable deploy artifact regenerated from source
  (see `.claude/rules/source-store-deploy-boundary.md`).
- NEVER weaken, raise, or bypass a guard threshold, loosen an assertion into vacuity, or mark a
  case skipped to make a suite pass. Isolate the INPUT; do not relax the ASSERTION. The
  last-resort window-widening above is a bounded, justified exception on the timing axis only --
  it is NOT licence to relax thresholds generally, and never applies to a guard's own constants.
- Where a suite legitimately depends on real host state and cannot be isolated, use the loud-skip
  discipline already documented in `shell-script-testing.md` rather than a silent skip, and
  justify the exemption in the summary.

=== DELIVERABLE: THE CONVENTION ===

Extend `agent-system/extensions/core/context/standards/shell-script-testing.md` (127 lines;
existing sections: Location rule, Helper-naming convention, Fixture convention including "Never
resolve a path against the live tree", Loud-skip discipline, Mutation checks for regex-shaped
fixes, Registration, Related). Add an ambient-host-state isolation section that:
  - names the defect class and why it is load-bearing (the deploy-gate blast radius above),
    citing both confirmed instances as the worked examples -- one per axis;
  - states the seam-first rule for readable-input axes, and the bar for adding a new seam;
  - states separately that the timing axis needs a different technique, with the
    inject-clock / assert-causality / bounded-widening ladder and the rule that elapsed wall
    clock must not be used as a proxy for a property that is directly observable;
  - requires the per-suite non-vacuousness check;
  - forbids threshold relaxation as a remedy;
  - cross-references the existing Fixture convention and Loud-skip discipline sections rather
    than restating them.
Place it so it composes with, not duplicates, what is already there.

=== ACCEPTANCE ===

- Every one of the 72 suites has been triaged, with a recorded verdict: affected-and-isolated,
  false-positive-with-reason, or legitimately-host-dependent-and-loud-skipped.
- Instance B (`test-four-tier-conflict.sh` cases 6 and 5) is fixed, with the chosen technique
  justified against the ladder above.
- Each isolated suite carries a demonstrated non-vacuousness check.
- REPEATED-RUN ACCEPTANCE, NOT A SINGLE GREEN RUN. "run-all.sh passes once" is too weak: the gate
  has already failed twice consecutively for two different single-suite reasons, and instance B
  passes in isolation while failing in a full run. Require instead:
    (a) `run-all.sh` green across multiple consecutive runs (at least 3);
    (b) at least one of those runs under DELIBERATE concurrent load -- both memory pressure above
        the lake guard's own threshold and CPU/IO contention sufficient to have reproduced the
        case 6 failure, verified by first confirming the load reproduces the ORIGINAL failures on
        a pre-fix checkout;
    (c) full-run and isolated-run results agreeing for every suite -- a suite that passes alone
        but fails in the batch is still affected.
  Record the load-generation method used so the check is reproducible.


=== SCOPE NARROWED 2026-09-22 (eighth-pass phase 0) ===
The three whole-directory file_scope entries (core/scripts/tests/, lean/scripts/tests/, literature/scripts/) were removed: they deferred 207, 217, 223 and 244 in the dry run and drew two validate-state.sh coarse-scope warnings spanning 11 tasks. The named test-*.sh files, task-lock.sh and shell-script-testing.md stay. Research MUST name the specific suites the audit will edit and ADD them to file_scope before the implement dispatch (the convention the 224 narrowing followed on 2026-09-17). ORDERING: after 51 (task-lock.sh, test-session-runtime-files.sh) and 129 (test-session-runtime-files.sh, test-lake-build-guard.sh), recorded as dependency edges.

=== DEPENDENCY ADDED 2026-09-22 (new suites enter the triage set) ===
Two newly created tasks each add a standing repo-health probe WITH ITS OWN TEST SUITE (test-script-inventory.sh and test-context-reachability.sh). This task's acceptance criterion is that EVERY suite has a recorded triage verdict, so the audit must run after those suites exist or it certifies a set it no longer covers. Dependency edges recorded accordingly; the survey count above ("72 files match test*.sh") is the 2026-09-22 figure and MUST be re-derived at research time rather than trusted -- the corpus grows.

=== EVIDENCE ADDENDUM (2026-09-22, observed live) ===

INSTANCE A IS NOT CLOSED BY THE EXISTING FIX -- the defect class is still live post-878043472.

During an /orchestrate implement dispatch, a full `run-all.sh` over the SOURCE STORE copy
reported `test-lake-build-guard.sh` FAILING. An isolated re-run of the same suite immediately
afterwards, on the same machine and same commit, reported `Passed: 47  Failed: 0`.

This is the SAME discriminating shape already recorded for Instance B
(`test-four-tier-conflict.sh` case 6): fails inside a loaded full-suite run, passes in
isolation. It confirms that the env-seam redirection in 878043472 (LAKE_BUILD_GUARD_PSI_PATH /
LAKE_BUILD_GUARD_MEMINFO_PATH to fixture files) did NOT make the suite fully load-independent --
some assertion in it still reads ambient state, or is timing-sensitive, on an axis the fixture
redirection does not cover.

IMPLICATION FOR THIS TASK'S SCOPE: the "ALREADY FIXED -- DO NOT REDO" note above should be read
as "the memory axis was isolated", NOT as "this suite is now load-independent". The audit must
re-examine this suite rather than treating it purely as the exemplar to generalize from.
Determining WHICH case fails under load is the first concrete step -- the full-suite run does
not name it, so the failing case must be captured by re-running under induced load with
per-case output retained.

Contemporaneous context that plausibly supplied the load: the same run-all.sh invocation took
~40 minutes of wall clock with concurrent agent activity on the machine.

---

### 165. Admission gates in orchestrate-batch-admit.sh: posture for an absent file_scope, then cross-session visibility for self-modifying candidates
- **Status**: [PLANNED]
- **Task Type**: meta
- **Topic**: file-scope-lifecycle
- **Dependencies**: Task 162, Task 163, Task 245
- **Research**: [165_admission_posture_for_absent_file_scope/reports/01_admission-posture-absent-scope.md]
- **Plan**: [165_admission_posture_for_absent_file_scope/plans/01_admission-posture-absent-scope.md]

**Description**: Settle whether an ABSENT `file_scope` should be admission-relevant in agent-system/extensions/core/scripts/orchestrate-batch-admit.sh, or remain purely advisory -- and implement the ruling.

THE MOTIVATING HARM (observed live in ~/Projects/BimodalLogic, not hypothetical):
- `/orchestrate 530,531` correctly deferred one task cross-batch for overlapping a live task at README.md -- the collision guard working exactly as designed.
- `/orchestrate 544,545` dispatched BOTH with ZERO collision-guard coverage, purely because neither declares a file_scope at all. A live concurrent task held a broad scope (FormalSystem/, Tests/, docs/, typst/, README.md) and one of the dispatched pair worked the same naming domain that live task was mid-rename on. Nothing would have caught a conflicting concurrent edit.
The guard did not fail. It was never consulted, because the predicate has nothing to compare. An undeclared scope is currently indistinguishable from a scope that provably collides with nothing.

THE TRADEOFF (this is the decision, state it explicitly): treating absence as a defer reason closes the silent-passage hole but risks blocking legitimate work on legacy tasks that predate any file_scope discipline. That risk is what the sequencing mitigates -- this task is gated behind both the detection work and the backfill precisely so the legacy population is already covered before absence can block anything. Verify that mitigation actually landed before tightening; if backfill coverage is incomplete, prefer the softer posture and say why.

EXISTING MECHANICS TO WORK WITHIN (the script's own documented contract): `defer_reason` currently admits "self_modifying", "file_scope_collision", and "session_active". A `file_scope_collision` defer carries `colliding_task_number`, `colliding_task_status`, `overlapping_path`, `collision_scope`, and `corroborated_by`. An absent-scope defer has NO colliding task and NO overlapping path, so it does not fit that payload shape -- it is a different kind of fact (missing information, not detected conflict). If a defer is chosen, it likely needs its OWN reason value rather than being forced into file_scope_collision, whose fields would all be empty. Note also the documented override asymmetry: file_scope_collision and session_active have specific override semantics -- decide where a new reason sits in that hierarchy.

ENFORCEMENT LEVEL -- PRIOR ART, FOLLOW IT: plan-format.md:259-266 records the Verification Tier rollout as the in-repo precedent. Quoted: enforcement is "advisory-first: a missing field emits a warning, not an error, so default-mode validation of plans authored before this vocabulary existed continues to pass. `--strict` mode enforces it today. Promotion criterion: promote the warning to an error once no non-terminal plan under specs/ lacks the field." The same three-part pattern applies: start advisory, WRITE DOWN the promotion criterion, promote only once coverage is complete. A defensible outcome for this task is explicitly deciding NOT to make absence blocking yet, and recording the coverage threshold at which it should become blocking -- that is a real decision, not a deferral, and it must be written into the script header either way.

OPTIONS TO WEIGH: (a) advisory only -- surface in the review, never affect admission; (b) a new non-blocking `defer_reason` visible in output but overridable; (c) a genuine defer gated on a coverage precondition; (d) blocking only when a live task holds a broad scope, i.e. treat absence as risky only in the presence of an actual concurrent hazard, which directly matches the observed harm and is the narrowest fix.

ACCEPTANCE: the ruling and its reasoning are recorded in the script's header contract alongside the existing defer_reason documentation; if a new reason value is added, its payload fields and override semantics are documented to the same standard as the existing three; the observed harm scenario is reproduced as a test case and the chosen posture demonstrably changes its outcome (or is documented as deliberately unchanged); shellcheck clean per context/standards/shell-strict-mode.md.

CANONICAL SOURCE CONSTRAINT (binding): all edits target /home/benjamin/.config/nvim/agent-system/extensions/core/. Never hand-edit any deployed .claude/** tree -- it is gitignored, disposable, and regenerated from the source store by the loader, so edits there are silently wiped. DELIVERABLE RULE: no task numbers in deliverables outside specs/**.


=== ADDITIONAL EVIDENCE (2026-09-21, ~/Projects/Logos/Verification, session sess_1790009936_0a5e95) ===
A SECOND, LARGER INSTANCE OF THE MOTIVATING HARM -- IN-BATCH, NOT CROSS-SESSION. `/orchestrate
66,70,72,76,77,81,84,85` (8 tasks, all task_type general, all created without file_scope) reached
the implement phase with every task planned. `orchestrate-cycle-plan.sh --dry-run` reported:
Dispatch = all 8, Deferred = 0, Blocked = 0 -- i.e. it would have run 8 implementers concurrently
in ONE working tree. The plans themselves showed heavy real overlap, found only by an operator
reading them:
  - framed_channel/check.sh edited by 3 tasks (one a 9-phase refactor of it);
  - .github/workflows/verify.yml: one task edited the comparator-arm job while another DELETED it;
  - docs/ci.md edited by 4 tasks;
  - 4 tasks ran the full local verification gate, which regenerates the committed certificate --
    concurrent gate runs over a tree other agents are mid-edit would have produced wrong results.
The collision guard did not fail; as in the BimodalLogic case it was never consulted, because
every candidate's file_scope was absent.

OPERATOR REMEDY THAT WORKED (and what it implies for the ruling): the operator hand-populated
file_scope for all 8 tasks from each plan's "Files to modify" lists and re-ran the dry-run. The
existing in_batch predicate then serialized correctly (cycle 3: 2 admitted, 6 deferred with
accurate overlap reasons), and the batch completed across 6 implement cycles with zero
cross-task clobbers, all eight committing cleanly. Two implications:
  1. The information needed was already on disk at plan time (every plan listed its files) --
     direct support for harvesting file_scope from plans (the formalize/harvest task) as the
     primary fix, with this task's posture as the backstop.
  2. For the in_batch case specifically, the "defer on absence" posture is cheap: an absent-scope
     task in a multi-task batch has no evidence it is disjoint from its siblings, and the cost of
     wrongly serializing is extra cycles, while the cost of wrongly parallelizing was (here)
     concurrent edits to the same gate script and concurrent certificate-regenerating gate runs.
     Consider ruling separately for in_batch (strict: absent scope => serialize against every
     sibling, or refuse admission until scope is declared) vs cross_batch (the tradeoff already
     stated above).


=== ABSORBED 2026-09-22 from former task 190 (Fix cross-session admission blindness for self-modifying candidates); that task is abandoned into this one. Its text follows verbatim; where it names "the dependency task" or "the sibling task", read this task's other sections. ===

SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**).

DEFECT. Two SELF-MODIFYING tasks running in SEPARATE concurrent /orchestrate sessions are mutually invisible to every admission gate. Each is admitted solo; neither sees the other; they proceed to edit the same orchestrator-critical file concurrently.

OBSERVED LIVE (2026-09-08, this repository, not hypothetical). Two /orchestrate sessions ran concurrently under the same ancestor pid:
  sess_1788883218_cb46bc  /orchestrate 180,181,182
  sess_1788889066_9309df  /orchestrate 189
Both batches claimed agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh. Three commits landed on that file from the 189 session while the other session was in cycle-6 planning for 182. No gate fired. The collision was caught only by a human reading a task notification. 182 had not yet dispatched, so no clobber occurred -- this was luck, not a gate.

MEASURED EVIDENCE (direct probe, reproducible):
  bash .claude/scripts/orchestrate-batch-admit.sh --session-id <A> 182
    -> {"decision":"admit","self_modifying":true}
  bash .claude/scripts/orchestrate-batch-admit.sh --session-id <B> 189
    -> {"decision":"admit","self_modifying":true}
  bash .claude/scripts/orchestrate-batch-admit.sh --session-id <B> 182 189   # SAME batch
    -> 182 admit; 189 DEFER, defer_reason self_modifying, full critical_path + ordering reason
  bash .claude/scripts/orchestrate-batch-admit.sh --session-id <A> 157       # NOT self-modifying
    -> admit + idle_overlap_advisory naming out-of-batch task 170, collision_scope cross_batch

WHAT THIS ISOLATES. The in-batch tie-breaker works correctly. The cross-batch file_scope scan also works -- it fired for the NON-self-modifying candidate (157) against an out-of-batch task. But for a SELF-MODIFYING candidate dispatched solo, the verdict carries no cross-batch collision result and no session-registry result at all. The self-modification branch appears to admit early and short-circuit the file_scope_collision and session_active passes that would have caught the overlap. Confirm that reading against the script's own documented pass ordering (self-mod, then file_scope_collision, then session_active, the last two reached only when the prior finds no hit) before changing anything.

CONTRIBUTING FACTOR, ALREADY REMEDIED, DO NOT RE-FILE. Task 189 carried no file_scope at all, so its session registered an empty covered scope. That was repaired by hand during the incident and is not the root cause: with all 11 paths populated AND the session registry re-registered to match, the solo verdicts above STILL admit. Absent metadata made it worse; it did not cause it.

MUST NOT. Do not make the solo self-modifying candidate DEFER -- that would mean zero dispatch on every solo run of a self-modifying task, which is the exact regression the pre-existing tie-breaker design avoids. The admission DECISION is defensible; what is missing is that the verdict does not carry, and the caller cannot see, a live cross-session collision. Do not change the collision predicate or the verdict schema's existing fields in ways that break orchestrate-predispatch-review.sh, which is a consumer.

ACCEPTANCE. With two live registered sessions whose covered scopes overlap on at least one path, a solo self-modifying candidate in one of them produces a verdict that names the overlap (defer, or admit carrying an explicit cross-session hazard field that orchestrate-predispatch-review.sh renders). A fixture test reproduces the two-session case above and fails against the current script.

NOTE ON LIVENESS DETECTION. Both sessions in the incident reported the SAME pid with pid_source ancestor-claude, because two /orchestrate runs inside one Claude Code process share an ancestor. Any self-exclusion keyed on pid rather than session_id would treat a foreign session as self and silently disable cross-session detection for the most common case. Verify which key the exclusion actually uses; if it is pid, that alone may be the whole defect.

---

### 136. Implementation-agent contract corrections: plan-level Status ownership, no fan-out, marker/commit sync, validator catch
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 139
- **Research**: [136_enforce_plan_status_field_ownership/reports/01_plan-status-field-ownership.md]
- **Plan**: [136_enforce_plan_status_field_ownership/plans/01_plan-status-field-ownership.md]
- **Summary**: [136_enforce_plan_status_field_ownership/summaries/01_plan-status-field-ownership-summary.md]

**Description**: PRODUCER-SIDE root cause of the malformed plan-level Status line that task 91 handles from the consumer side. Task 91 makes update-plan-status.sh diagnose the malformed line loudly; this task stops the line being written in the first place, and makes the validator catch it if it ever is.

EVIDENCE (git history of a real plan file, BimodalLogic repo, specs/507_parameterize_validity_by_frameclass/plans/02_frame-level-validity-indexing.md):
  bd68091cb  - **Status**: [NOT STARTED]     planner-agent, conforming
  b35d5c043  - **Status**: [IMPLEMENTING]    lifecycle transition, conforming
  463b00103  - **Status**: [IMPLEMENTING]    still conforming after phase 8
  3d50e2583  - **Status**: COMPLETED         <-- lean-implementation-agent hand-edit, BRACKETS LOST
  b7ccf6702  - **Status**: [COMPLETED]       manual orchestrator repair
The malformed line is authored by an IMPLEMENTATION AGENT, not by any script and not by the planner. update-plan-status.sh cannot produce an unbracketed line (its sed both requires and writes brackets), and plan-format.md is correct and unambiguous (bracketed form specified at lines 6, 16, 372). The plan format file is NOT the defect.

DEFECT 1 -- NO OWNERSHIP BOUNDARY IN AGENT CONTRACTS.
Implementation agents are told, emphatically, to Edit PHASE HEADING markers in the plan file:
  extensions/lean/agents/lean-implementation-agent.md:80   "**CRITICAL**: You MUST update phase status markers in the plan file at phase boundaries."
  extensions/lean/agents/lean-implementation-agent.md:99   new_string: "### Phase {P}: {exact_phase_name} [COMPLETED]"
  extensions/lean/agents/lean-implementation-agent.md:437  "**ALWAYS update plan file phase markers with Edit tool**"
  extensions/lean/agents/lean-implementation-agent.md:450  (forbids) "Leave plan file with stale status markers"
NOWHERE does any implementation-agent contract state that the plan-level metadata field `- **Status**:` is a DIFFERENT field with a DIFFERENT owner (update-plan-status.sh, driven by postflight via update-task-status.sh). An agent told "ALWAYS update plan file status markers" and "never leave stale status markers" generalizes from the phase headings to the metadata field -- which is exactly what happened -- and hand-typing loses the brackets.
Verified absent by grep for `update-plan-status|plan-level status|metadata Status` across:
  extensions/lean/agents/lean-implementation-agent.md          (zero hits)
  extensions/lean/agents/lean-implementation-hard-agent.md     (zero hits)
  extensions/core/agents/general-implementation-agent.md       (zero hits; its only `- **Status**: [COMPLETED]` at :476 is inside the SUMMARY template, a field the agent legitimately owns)
Note the asymmetry worth preserving: the general agent's summary template DOES spell out the bracketed vocabulary inline ("Use `**Status**: [COMPLETED]` when every plan phase is done..."). The plan-level field has no equivalent statement anywhere.

DEFECT 2 -- VALIDATOR CHECKS PRESENCE, NOT GRAMMAR.
extensions/core/scripts/validate-artifact.sh:120-124 is the entire metadata check:
  for field in "${metadata_fields[@]}"; do
    if ! grep -qF "**${field}**:" "$artifact_path"; then ... log_error "Missing metadata field" ...
It tests only that the substring `**Status**:` EXISTS. The bracketed-value grammar is never checked, for plans, reports, or summaries. Consequence, observed: the task-507 plan carrying `- **Status**: COMPLETED` validated as `[PASS] plan artifact is valid (0 warning(s))` while being unstampable by update-plan-status.sh. The validator is the layer that should have caught this before postflight did.

WORK.
(a) Add an explicit ownership boundary to every implementation-agent contract that instructs phase-marker editing. State that `- **Status**:` in the plan METADATA block is owned by update-plan-status.sh (invoked from update-task-status.sh postflight) and MUST NOT be hand-edited, and that the agent's plan-file write authority is limited to `### Phase N: ... [MARKER]` headings and checklist items. Apply to at minimum: extensions/lean/agents/lean-implementation-agent.md, extensions/lean/agents/lean-implementation-hard-agent.md, extensions/core/agents/general-implementation-agent.md, extensions/core/agents/general-implementation-hard-agent.md. SWEEP for other agents carrying phase-marker instructions (cslib-implementation-agent.md is a known candidate) rather than assuming the list above is complete.
(b) Add a Status-line GRAMMAR check to validate-artifact.sh, so a non-conforming value is an error, not a pass. Must cover the three malformed shapes task 91 enumerates: missing brackets, trailing text after the closing bracket, missing `- ` prefix.
(c) Decide whether the grammar check participates in --fix (in-place repair) or reports only. NOTE THE INTERACTION: task 13 (instrument_gate_out_auto_repair_reporting) is separately deciding whether --fix should remain in-place-mutating on the gate-out path at all. Do not silently add a new in-place mutation while that decision is open -- state the choice and its reasoning explicitly.

DEPENDENCY ON 91 -- LOAD-BEARING, NOT ADMINISTRATIVE. Task 91's deliverable (b) decides the tolerance policy for trailing text after the closing bracket: either accept `- **Status**: [IMPLEMENTING] (resumed; Phases 1R-10R closed)` by rewriting only the bracketed token, or reject it as malformed. The validator grammar in (b) above must ENFORCE whatever 91 decides. Implementing this task first would hardcode a guess and then need reworking. Sequence behind 91.

SCOPE BOUNDARY. This task does NOT touch update-plan-status.sh, update-task-status.sh, or context/formats/plan-format.md -- all three belong to task 91's file_scope. If documenting the ownership boundary in plan-format.md proves necessary, hand that edit to 91 rather than widening this task's scope into a file_scope collision.

ACCEPTANCE.
  - Every implementation agent carrying phase-marker instructions also carries the plan-level-Status ownership boundary; verified by grep, not by assumption.
  - validate-artifact.sh rejects all three malformed Status shapes on a plan artifact and passes the conforming shape, consistent with 91's trailing-text policy.
  - The --fix participation decision is stated in the summary with its reasoning, and is consistent with whatever task 13 concluded (or explicitly notes 13 as still open).
  - Redeploy and confirm the fix survives regeneration (.claude/ is a deploy artifact; the edit target is agent-system/extensions/).

PROVENANCE. Root-caused 2026-09-01 during an /orchestrate 507 run in the BimodalLogic repo, where the postflight status transition failed with "Failed to update status in .../plans/02_frame-level-validity-indexing.md" and the orchestrator repaired the line by hand. Consumer-side handling is task 91; this entry covers the producer and validator ends, which 91's file_scope excludes.

=== ABSORBED 2026-09-17 from former task 14 (no fan-out, terminal status, marker/commit sync in implementation agents); that task is abandoned into this one. Its text follows verbatim; where it names "the dependency task" or "the sibling task", read this task's other sections. ===
=== REVISED 2026-08-24 (refactor survey) ===
NARROWED: roughly half of this task already landed with the handoff-identity work and must not be redone. skill-orchestrate/SKILL.md:2374,2384 now treats in_progress (and null/empty) as OFF-SCHEMA rather than routing it toward failed_tasks, and orchestrate-recover-outcome.sh:233 emits a clean STATUS_IN_PROGRESS verdict. Verified in the source store today.
WHAT REMAINS is the AGENT-CONTRACT side only, and it is untouched: general-implementation-agent.md contains NO fan-out prohibition, and NO requirement that a sub-agent which commits a phase must update that phase's marker in the same commit. Both gaps are what produced the original symptom -- dispatches fanning out to phase sub-agents and terminating before writing a terminal status, leaving plan markers reading [NOT STARTED] against landed commits.
Rescope to those two contract additions. Do not re-litigate the status-vocabulary half.
=== ORIGINAL DESCRIPTION FOLLOWS ===
Two dispatches in a single batch fanned out to phase sub-agents and terminated before writing a terminal status, costing a recovery cycle each. Recorded as err_1786344051474_RcIhk6.

OBSERVED FAILURE MODE: a dispatched implementation agent spawned per-phase sub-agents, returned while they were still running, and left .return-meta.json at status=in_progress. Per context/formats/return-metadata-file.md that value is early-metadata-only and never a legal terminal dispatch outcome, so orchestrate-recover-outcome.sh correctly declines it (reason STATUS_IN_PROGRESS). The orchestrator contract for an unresolvable dispatch is failed_tasks - which would have been WRONG here, since 6 of 10 phases had in fact been committed. Correct handling came from rules/error-handling.md Delegation Interrupted Recovery (keep status, resume), not from the orchestrator stage contract.

COMPOUNDING DEFECT - STALE PLAN MARKERS: the sub-agents committed phases 3, 4, 5 and 7 but left every one of those phase markers reading [NOT STARTED]. Because the orchestrator phase-marker recovery grep reads exactly those markers, it would have reported 2/10 against a true 6/10. A resume driven by markers alone would have redone committed work. Recovery only succeeded because the actual state was reconstructed from git log and diffs instead.

TWO INDEPENDENT QUESTIONS, BOTH IN SCOPE:
  1. Should a dispatched implementation agent fan out to sub-agents at all? If yes, it must still write a terminal status covering its childrens work; if no, the prohibition belongs in the agent contract, not in per-dispatch prompt text (the workaround used during the incident).
  2. Should a sub-agent that commits a phase be required to update that phases marker in the same commit? Markers and commits diverging silently is the deeper defect - it degrades the recovery path for every future interrupted dispatch, not just fan-out ones.

CONSIDER ALSO: whether the orchestrator should treat status=in_progress plus evidence of committed phase work as PARTIAL/resume rather than routing it toward failed_tasks, so correct handling does not depend on an operator noticing.

ACCEPTANCE: an interrupted fan-out dispatch is either impossible by contract, or leaves markers and terminal status accurate enough that resume needs no manual git archaeology.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

=== REVISED 2026-08-24 (second live occurrence, extension-agent gap) ===
RECURRED, AND THE CONTRACT GAP IS WIDER THAN THIS TASK'S CURRENT SCOPE. A seven-task lean4 batch
orchestrated in a separate consumer repo reproduced this exact failure mode TWICE in one
implementation cycle: two of seven dispatches performed real work, committed it, and then
terminated WITHOUT writing a terminal handoff, leaving .return-meta.json at status=in_progress.
orchestrate-recover-outcome.sh correctly declined both (STATUS_IN_PROGRESS); both needed a
re-dispatch cycle to resolve, exactly as the original incident did.

SCOPE CORRECTION (the actionable part). Both offending dispatches ran
extensions/lean/agents/lean-implementation-agent.md, NOT
extensions/core/agents/general-implementation-agent.md -- the only agent contract this task's
file_scope currently names. The terminal-status requirement is therefore missing from the
EXTENSION implementation agents as well as the core one, and fixing only the core file would
leave the reproducing path untouched. file_scope is extended accordingly to the lean pair. Treat
the core agent as the normative contract and the extension agents as required conformers; if a
shared include or a single normative statement referenced by all implementation agents is the
better mechanism, prefer that over copying the same paragraph into four files.

MARKER DIVERGENCE RECURRED IN THE OPPOSITE DIRECTION -- fold into question 2, do not treat as a
separate concern. The original incident recorded markers UNDER-claiming (phases committed, markers
still [NOT STARTED]). This batch recorded the inverse: one task's plan carried five of seven
phases marked [COMPLETED] while its sole declared file_scope target was UNMODIFIED against HEAD --
markers OVER-claiming against work that had not landed. A resume driven by those markers would
have skipped real work rather than redone it. Both signs share one root cause, which question 2
already names: markers and committed reality are allowed to diverge silently. Any fix must be
bidirectional -- a marker must not be promotable without the corresponding work being verifiable,
and committed work must not leave its marker unpromoted. The over-claim direction was only caught
because the orchestrator cross-checked the marker count against the working tree; a fix that
merely tightens promotion-on-commit would not have caught it.

WHAT IS ALREADY GOOD AND MUST NOT BE UNDONE. The re-dispatch path worked: both tasks resumed from
their real state and completed, and the resumed dispatches -- when explicitly instructed to write
the handoff FIRST and to re-verify prior phase markers with a real build rather than trust them --
both reported correctly and downgraded nothing falsely. That per-dispatch prompt text is the
workaround this task exists to retire; it is evidence the contract wording works, not a substitute
for putting it in the contract.

ACCEPTANCE (extends, does not replace, the original): the terminal-status requirement and the
fan-out resolution apply to extension implementation agents as well as the core one, demonstrated
against a lean4 dispatch; and marker/reality divergence is caught in BOTH directions.


=== ABSORBED 2026-09-28 (path review, fifth pass) from former task 166 (enforce_required_section_heading_conformance); that task is abandoned into this one. Its text follows verbatim; where it names "the dependency task" or "the sibling task", read this task's other sections. ===

DEFECT: a produced research report used section headings that are semantically correct but lexically non-conforming, so validate-artifact.sh's required-section check failed on an artifact whose authoring agent ALREADY carries a conforming skeleton. This is NOT the "agent has no skeleton at all" class addressed by the lean/formal skeleton work -- here the skeleton is present and correct, and the produced artifact drifted from it.

VERIFIED EVIDENCE.
1. THE CHECK. agent-system/extensions/core/scripts/validate-artifact.sh:20 declares
     REPORT_SECTIONS=("Executive Summary" "Context & Scope" "Findings" "Decisions" "Recommendations")
   and :170-173 matches each with `grep -qE "^##+ ${section}"` -- an any-depth heading PREFIX match, unanchored at the end.
2. THE ARTIFACT. ~/Projects/BimodalLogic specs/461_acquire_goldblatt_1989_varieties_of_complex_algebras/reports/01_acquisition-verified-corpus-status.md, authored 2026-09-07 12:39 -- AFTER that repo's agent reload at 11:13, so by the current deployed agent. task_type=general, therefore written by general-research-agent. `validate-artifact.sh <path> report` without --fix: FAIL, 1 error, "Missing required section: ## Recommendations".
3. WHY IT FAILED. The report does address recommendations, under two headings:
     :331  ## Context Extension Recommendations
     :337  ## Recommended Next Steps (for the plan phase)
   Neither matches `^##+ Recommendations`: the first because the text after "## " begins "Context", the second because "Recommended" is not "Recommendations". Both directions verified by running the validator's exact regex against both literal strings.
4. THE SKELETON IS NOT THE DEFECT. agent-system/extensions/core/agents/general-research-agent.md:277 carries a report skeleton that DOES include a conforming `### Recommendations`, which satisfies `^##+ Recommendations`. The agent departed from its own template when writing a real report.

TWO CONTRIBUTING FACTORS TO EVALUATE (do not assume either is the cause).
(a) BURIAL. In the skeleton, `### Recommendations` is a third-level subsection of `## Findings`, sitting alongside `### Codebase Patterns` and `### External Resources`. Every other required section is top-level. An agent restructuring Findings for a real report gets no signal that this one subsection is load-bearing for validation.
(b) NEAR-MISS TRAP. The same skeleton separately contains `## Context Extension Recommendations`. An agent writing that heading may reasonably believe the Recommendations requirement is met. The observed artifact contains exactly that heading.

DECIDE, do not assume. Candidate remedies, each with a real cost:
  (i)   AGENT-SIDE: state the five required heading strings verbatim in the agent contract and mark them non-paraphrasable. Cheapest; relies on instruction-following, which is precisely what failed here.
  (ii)  SKELETON-SIDE: promote `### Recommendations` to a top-level `## Recommendations`. Structurally removes factor (a); changes the report shape.
  (iii) VALIDATOR-SIDE: relax matching. DANGEROUS -- a substring match would let `## Context Extension Recommendations` satisfy `Recommendations`, converting a true failure into a false pass. Do not weaken a check to make it green.
State the ruling and its reasoning. Combining (i) and (ii) is permitted; (iii) requires an explicit argument that it creates no false passes.

SCOPE. Determine whether this is general-research-agent alone or a shared shape. Enumerate every core agent carrying a report or summary skeleton and machine-check each skeleton's headings against REPORT_SECTIONS/SUMMARY_SECTIONS using the validator's own regex -- not by eye.

NOT IN SCOPE: pre-existing non-conforming artifacts authored before their agent gained a conforming skeleton. Those fail for a different reason and are a separate backfill question.

ACCEPTANCE.
  - The exact failure is reproduced in a fixture (a report carrying `## Recommended Next Steps` and `## Context Extension Recommendations` but no `## Recommendations`) and shown to pass after the chosen remedy.
  - The chosen remedy is recorded with reasoning, including why the validator was or was not changed.
  - If the validator is touched, a fixture proves `## Context Extension Recommendations` ALONE still fails.
  - An enumeration of all core report/summary-writing agent skeletons, machine-checked against the validator's own regex, with any further gaps listed.
  - A real general-type research dispatch produces a report validating with 0 errors and 0 auto-repairs.

CANONICAL SOURCE CONSTRAINT (binding): all edits target /home/benjamin/.config/nvim/agent-system/extensions/core/. Never hand-edit any deployed .claude/** tree -- it is gitignored, disposable, and regenerated from the source store by the loader. DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

=== PATH REVIEW 2026-09-28: why the research-report heading task was folded in ===
Both halves are 'an agent skeleton/contract drifts from what validate-artifact.sh enforces': the implementation side (plan-level Status grammar, fan-out, marker/commit sync) and the research side (required-section headings). They serialize on validate-artifact.sh and share one remedy shape (fix the contract text AND make the validator reject the drift), so they are one task with two phases -- research phase first (independent of the git-safety task), implementation-agent phase after the history-rewrite task lands on general-implementation-agent.md.

---

### 127. Collapse routing ladder to routing agents
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 121, Task 124, Task 125

**Description**: === REVISED 2026-09-01 (backlog streamline: absorbs the present-routing residue) ===
ADDITIONAL WORK ITEMS, absorbed from the abandoned present-extension routing task: (5) while rewriting the manifests, resolve present/manifest.json's colon-suffixed compound values -- its routing.implement block ("present:grant" -> "skill-grant:assemble" style) disappears with the collapse, mooting the skill-name half of the original defect, but audit routing_agents for any analogous colon-suffixed AGENT value encoding workflow_type into a name no consumer splits, and settle the encoding (drop the suffix and carry workflow_type another way, or make the resolver split and expose it as a sub-mode variable). (6) extend lint-routing-wiring.sh so any routing_agents value naming a nonexistent agent file fails verify-deploy -- the original defect (a manifest naming a nonexistent dispatch target, shipped silently) must be impossible to reintroduce under the collapsed model.
=== ORIGINAL DESCRIPTION FOLLOWS ===
Collapse the routing ladder to routing_agents-only across all 19 extension manifests; retire command-route-skill.sh.

CONTEXT. Every extension manifest may declare up to four routing blocks today (routing, routing_hard, routing_agents, routing_agents_hard), resolved by the shared five-step ladder in scripts/lib/manifest-routing-lib.sh. Once /research, /plan, /implement are deleted (no skill layer left to route to) and the hard-mode collapse lands (no separate hard-routing table needed -- hard mode becomes a dispatch-prep injection, not a different resolved agent file), only routing_agents remains meaningful.

WORK. (1) Remove the routing and routing_hard blocks from every extension manifest that declares them, retaining only routing_agents (plus any extension-specific op like present's critique). (2) Retire command-route-skill.sh -- confirm no remaining caller (only the now-deleted /research, /plan, /implement, /revise-adjacent paths called it; /revise itself does not use this resolver and is unaffected). (3) Update context/guides/manifest-routing-schema.md to document the collapsed two-block model (down from four), including the completeness-lint contract re-scoped to check only routing_agents completeness against itself. (4) Re-scope lint-routing-wiring.sh's Checks A/C accordingly.

DEPENDS ON both the command deletions (routing/skill-dispatch has no remaining caller) and the hard-mode file deletions (routing_hard/routing_agents_hard has no remaining caller) having already landed.

SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/*/manifest.json (all 19), agent-system/extensions/core/scripts/command-route-skill.sh, agent-system/extensions/core/context/guides/manifest-routing-schema.md, agent-system/extensions/core/scripts/lint/lint-routing-wiring.sh (never .claude/**).
DELIVERABLE RULE: no task-number references in any deliverable outside specs/**.

REFERENCE: specs/116_core_agent_system_consolidation/reports/03_target-state-design.md (A3).

---

### 89. Mode gate literature and distill skills
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 87

**Description**: Apply the mode-gated section convention to the two remaining large instances, after the pilot proves it.

skill-literature/SKILL.md, 84,265 B total, 64.5% fenced bash. Seven mutually exclusive mode sections of which exactly ONE fires per invocation: Mode: Rebuild 20,170 | Mode: Convert 17,534 | Mode: Search 10,043 | Mode: Validate 5,989 | Mode: Import Pipeline 5,785 | Mode: Index 5,234 | Mode: Ingest 1,917 = ~65,772 B, 78% of the file. Cleanly '## Mode:'-delimited, so the split is mechanical. Estimated ~14,000 tokens per /literature invocation, taking it from ~46.2k toward ~32k.

skill-distill/SKILL.md, 93,044 B total, only 1.9% bash -- essentially pure prose. `## Auto Distill Complete` is 43,254 B, 46% of the file, and is an OUTPUT TEMPLATE used by --auto alone. It belongs in context/formats/, not in a skill body loaded on every /distill invocation. Estimated ~10,800 tokens per non---auto /distill, taking it from ~42.4k toward ~32k.

Combined estimated saving ~24,800 tokens across the two commands' invocations.

Both carry the same fence-interior heading hazard as the orchestrate application -- '## Mode:' and '## Auto' strings can appear inside fenced examples. Split bottom-up and verify each extracted section round-trips.

ACCEPTANCE: each mode section loads only when its mode is selected; all seven literature modes and both distill paths verified working; measured reductions reported against the 46.2k and 42.4k baselines.

---

### 51. Move session runtime files out of the specs root and make the reap path run
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 143, Task 209
- **Research**: [051_move_session_state_files_out_of_specs_root/reports/01_relocate-widen-reap-wire-todo.md]
- **Plan**: [051_move_session_state_files_out_of_specs_root/plans/01_relocate-widen-reap-wire-todo.md]
- **Summary**: [051_move_session_state_files_out_of_specs_root/summaries/01_relocate-widen-reap-wire-todo-summary.md]

**Description**: Stop session-scoped orchestration runtime files from accumulating at the specs/ root, and make the existing reap path actually run. Originally scoped as "move the files into a dot-prefixed directory"; widened after a manual cleanup swept 79 stranded files across 5 repos (oldest dated 2026-07-11), because relocation alone hides the clutter without stopping the growth.

Three parts:

(1) Relocation (original scope). Move .orchestrator-multi-state-{sid}.json and .return-meta-multi-{sid}.json out of the specs/ root into a dot-prefixed subdirectory (e.g. specs/.orchestration/), or handle otherwise as most appropriate. Must update every writer/reader, the reaper's glob roots, .gitignore patterns, check-runtime-file-tracking.sh's probe paths, and context/standards/orchestrator-runtime-files.md's Class Table.

(2) Reaper glob coverage gap. scripts/reap-session-runtime-files.sh sweeps ONLY the current hyphen-separated shapes (specs/.orchestrator-multi-state-*.json, specs/.return-meta-multi-*.json). Three superseded naming generations are therefore permanently unreapable and had to be deleted by hand:
  - un-suffixed:     .orchestrator-multi-state.json / .return-meta-multi.json
  - dot-separator:   .orchestrator-multi-state.sess_{sid}.json
  - .prev- variant:  .orchestrator-multi-state.prev-sess_{sid}.json
Additionally .return-meta-meta.json, .return-meta-meta-sess_{sid}.json, and .meta-return.json have NO writer or reader anywhere in agent-system/ or .claude/ (orphans of a superseded convention; .meta-return.json was also tracked in git and has since been removed). Decide per shape whether to widen the reaper's globs or to add a one-shot legacy-name migration, and ensure any relocation in part (1) does not create a fourth orphaned generation.

(3) Automatic invocation (root cause). The reaper is correct and works -- it cleared 41 of 41 files on first run -- but its ONLY trigger is a manual /refresh, so litter grows unbounded between refreshes. Wire reap into /todo, which is run far more often and is already the repo's housekeeping command. Call both scripts/reap-session-runtime-files.sh and task-lock.sh session-reap (stale .sessions/ registry entries accumulate identically -- 9 dead-pid entries were swept in nvim alone). Suggested hook point: a new stage between skill-todo's stage 10 ArchiveTasks and stage 15 GitCommit, so reaped paths land in the same commit; alternatively fold the reporting half into stage 3 DetectOrphans. Must stay non-blocking and honor the existing ORCHESTRATOR_SESSION_REAP_MIN threshold (default 240min) so in-flight batch runs are never reaped; echo the reaper's own output verbatim the way skill-refresh already does. Keep /refresh's invocation working unchanged.

Affected repos observed: nvim, BimodalLogic, cslib, ModelChecker, PersonalWebsite -- so the fix belongs in the core extension source store, not any single repo's deploy.

=== EVIDENCE REFRESHED 2026-09-22 (post-/todo measurement) ===
The stranded-file count in THIS repo alone is now 48 (.orchestrator-multi-state-*.json and .return-meta-multi-*.json at the specs/ root), up from 25 measured on 2026-09-08 -- nearly doubled in two weeks, with the oldest surviving entries still present. No reaper ran in between, which is precisely the point: part (3) above is the load-bearing half of this task. Relocation (part 1) and glob widening (part 2) both leave the growth rate untouched; only wiring the reaper into /todo changes it. Treat part (3) as the acceptance-critical deliverable, not as the third of three equals.

=== EVIDENCE REFRESHED 2026-09-28 ===
67 stranded session files at this repo's specs/ root (48 on 2026-09-22, 25 on 2026-09-08), including one .meta-return-sess_*.json written by the superseded convention this task already names as orphaned. Twelve completed tasks await /todo, which is the housekeeping command part (3) wires the reaper into.

---

### 44. Slim commands/task.md, the largest per-invocation context contributor
- **Effort**: 2-4 hours
- **Status**: [PLANNED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 87, Task 149, Task 210
- **Research**: [044_slim_task_command_body/reports/01_command-body-extraction-approach.md]
- **Plan**: [044_slim_task_command_body/plans/01_task-command-mode-extraction.md]

**Description**: LOWER PRIORITY (per-invocation cost, not per-session). `commands/task.md` measures 37,465 bytes (~9.4k tokens) loaded on every `/task` invocation, plus ~2.8k tokens of imports it pulls in — the largest single per-invocation context contributor found by the context-loading audit. Slim the command body by moving reference material (long option tables, worked examples, edge-case narratives) into lazily-loaded context files under the core extension's context tree, keeping the command body to the decision logic and dispatch instructions an invocation actually needs. Preserve behavior: every mode (--recover, --expand, --sync, --abandon, multi-task creation) must remain fully specified — either inline or via an explicit pointer the executing agent is instructed to follow. Measure before/after bytes and record them in the implementation summary. CONSTRAINTS: all edits target agent-system/extensions/core/** (source store), never the deployed .claude/** tree; no task-number references in deliverables outside specs/**; do not change command behavior, only where its prose lives.

---

### 39. Upgrade Zotero metadata resolution and plan the Zotero 10 backend swap
- **Effort**: 3-6 hours
- **Status**: [PLANNED]
- **Task Type**: meta
- **Topic**: literature
- **Dependencies**: None
- **Research**: [039_zotero_metadata_resolution_upgrade/reports/02_zotero-metadata-resolution-design.md]
- **Plan**: [039_zotero_metadata_resolution_upgrade/plans/02_zotero-metadata-resolution.md]

**Description**: Upgrade the literature extension's Zotero integration beyond bare write-path activation: add a real metadata-resolution step for web-discovered sources, decide the MCP question, gate auto-attach on storage quota, and record the Zotero 10 backend-swap plan. Grounded in verified Aug-2026 tooling research — see the seed report before re-deriving any landscape claim.

=== WORK ITEMS ===

1. TRANSLATION-SERVER INTEGRATION (the pipeline's thinnest point today). The online ingest bridge currently relies on `zot add --pdf`'s DOI-from-PDF extraction for metadata, which fails on books, preprints without embedded DOIs, and scans. Integrate the official `zotero/translation-server` (HTTP, port 1969; service provisioning is the ~/.dotfiles repo's job — its task 129): call `POST /search` (DOI/ISBN/arXiv ID, preferred when Tier-3 discovery already has an identifier) or `POST /web` (URL fallback) to resolve full Zotero JSON BEFORE item creation, and pass that metadata through the create path. Degrade gracefully (current behavior) when the service is down, and surface which resolution path produced the record.

2. ZOTERO-MCP ADOPTION DECISION. Evaluate adding 54yyyu/zotero-mcp (de-facto standard, ~4.6k stars, hybrid mode = local-API reads + Web-API writes, add-by-DOI/URL/ISBN, OA-PDF cascade) as an INTERACTIVE complement for `/research --lit` sessions. The deterministic scripts remain the pipeline of record — community practice in 2026 is exactly this split. Deliverable is a recorded decision (adopt/defer with reasons); if adopted, registration scope and permission grants follow the grant-at-registration-scope principle already established for MCP servers in the ~/.dotfiles Claude configuration, and the registration itself lands there, not here.

3. STORAGE-QUOTA GATE. Stored-file uploads via the Web API count against the zotero.org 300 MB free tier (948 attachments already exist locally; the account's plan/usage is unverified). Verify quota state and encode an explicit auto-attach policy in the ingest bridge rather than discovering the ceiling by failure. Note the upload flow's `{"exists": 1}` content-hash dedup for PDF bytes.

4. ZOTERO 10 BACKEND-SWAP PLAN (plan, do NOT implement while 10 is beta). Zotero 10 ships native local writes (items + file upload) at `localhost:23119/api/` with consent-based local API keys via `POST /api/local/authorize` — eliminating cloud round-trips and the storage quota for attached files. Record the swap plan against the single write choke-point (`zotero-write.sh`) so callers never change; explicitly reject `/connector/saveItems` as a write contract (undocumented internal protocol).

=== ACCEPTANCE CRITERIA ===

1. Web-discovered sources get translation-server-resolved metadata when an identifier or URL is available, with honest surfacing of which resolution path was used and graceful degradation when the service is unreachable.
2. The MCP decision is recorded with reasons; no MCP registration or grants are hand-edited in this repo either way.
3. Auto-attach policy is explicit and quota-aware; no silent quota-exhaustion failure mode remains.
4. The Zotero 10 swap plan exists in the extension's context docs, names the choke-point, and states what stays constant for callers.

=== BINDING RULES ===

SOURCE-STORE RULE: all edits target agent-system/extensions/literature/**. NEVER edit the deployed .claude/** tree.
DELIVERABLE RULE: no task-number references in deliverables outside specs/**.

---

### 29. Generate .mcp.json from extension manifests, then register obsidian-memory through it
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: Task 210, Task 22, Task 241

**Description**: TOPIC CORRECTION (backlog streamline 2026-09-01): re-topiced core-agent-system -> extensions. This is deploy-engine (lua merge-path) and manifest-surface work for extension MCP registration, unrelated to the orchestrate-engine collapse; the consolidation audit confirmed no overlap with the routing ladder it carries forward. Original description follows.Build the deploy-engine mechanism that lets an extension declare an MCP server and have it actually registered, by generating a project-scoped .mcp.json.

WHY THIS IS NEEDED: extensions currently express server declarations as `mcpServers` keys inside settings-fragment.json, which register nothing -- settings files are not a registration surface. Project-scoped .mcp.json IS a real registration surface, and it IS reachable by dispatched subagents (verified by direct experiment; the earlier belief to the contrary rested on a session-start snapshot confound). So the fix is to route declarations to a surface that works, not to abandon the idea of extensions declaring servers.

WORK: add a new manifest merge target -- e.g. `merge_targets.mcp` with a source file per extension -- that the deploy engine collects across all LOADED extensions and writes to the repository-root .mcp.json. Mirror the existing settings merge path (process_merge_targets / merge_settings in merge.lua) rather than inventing a second idiom: the existing path is an additive, idempotent deep-merge that does not clobber pre-existing content, and it deliberately targets a file that is NOT install-once, which is exactly the property needed here. Extend manifest_spec.lua so the new key validates.

REQUIREMENTS THE MECHANISM MUST SATISFY: (a) each generated server entry carries an explicit "type" field -- as of Claude Code v2.1.202 a remote server lacking an explicit type fails fast rather than failing silently, and all current declarations omit it; (b) unloading an extension must REMOVE its servers from .mcp.json, because an additive deep-merge alone never retracts, and a stale grant surviving an unload is an already-observed defect class in this system; (c) the operation must be idempotent -- deploying twice yields a byte-identical .mcp.json; (d) hand-written entries a user added to .mcp.json themselves must survive regeneration, or the file must clearly declare itself generated. Decide (d) explicitly and record the choice.

IMPORTANT CONTEXT: a project-scoped .mcp.json server requires workspace-trust approval before `claude mcp list` will read it (v2.1.196+), and a server added to .mcp.json is invisible to any ALREADY-RUNNING session. Both facts must be documented for users, or the mechanism will be reported as broken when it is working correctly. Verify against a fresh session or `claude -p`, never against the current one.

VERIFICATION: build a scratchpad fixture project, load an extension declaring a trivial stdio server, and confirm .mcp.json is generated correctly; confirm a second deploy is a no-op; confirm unloading removes the entry; confirm `claude mcp get <name>` in the fixture reports Scope: Project config. Do NOT deploy against this repository as part of verification. SOURCE-STORE RULE (binding): all edits target /home/benjamin/.config/nvim/agent-system/extensions/**. Never hand-edit any deployed .claude/** tree -- it is gitignored, disposable, and regenerated from the source store. DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

=== ABSORBED 2026-09-22 from former task 30 (register_obsidian_memory_mcp_server); that task is abandoned into this one. Its text follows verbatim; where it names "the dependency task" or "the sibling task", read this task's other sections. ===

TOPIC CORRECTION (backlog streamline 2026-09-01): re-topiced core-agent-system -> extensions, alongside its prerequisite (the .mcp.json generation mechanism). Unrelated to the orchestrate-engine collapse. Original description follows.Register the obsidian-memory MCP server through the new manifest-driven .mcp.json mechanism, and grant its tools at the matching scope.

CURRENT STATE: memory/settings-fragment.json carries a dead `mcpServers` block declaring obsidian-memory (npx -y @anthropic-ai/obsidian-claude-code-mcp@latest, with env OBSIDIAN_WS_PORT). It registers nothing, because settings files are not a registration surface. The memory extension IS loaded in this repository, so unlike the five retired servers this one is wanted and should be made to work.

WORK: move the declaration to the new merge target so it lands in .mcp.json, with an explicit "type": "stdio". Then determine the server's ACTUAL tool names and add matching permission grants to the fragment, applying the grant-at-registration-scope rule. Do NOT guess the tool names and do NOT copy them from any existing documentation: enumerate them empirically by starting the server and issuing a tools/list request. This system has already shipped documentation instructing agents to call MCP tools that never existed, and a naming mismatch between a declared server name and its granted mcp__<name>__* prefix has already been found in another extension -- verify both the server name and every tool name against the running server.

RUNTIME PREREQUISITE, DO NOT PAPER OVER: this server needs OBSIDIAN_WS_PORT set and a running Obsidian instance with the companion plugin. If that prerequisite cannot be satisfied in this environment, wire the declaration correctly, document the prerequisite plainly in the memory extension README, and report the tool-name enumeration as NOT VERIFIED rather than inventing plausible names. A truthful 'could not verify' is the correct outcome here; a fabricated tool list is not.

VERIFICATION: .mcp.json contains the entry after a fixture deploy; `jq empty` on both edited files; doc-lint passes for the memory extension; every granted mcp__ tool name either matches a name observed from the running server or is explicitly marked unverified with the reason. SOURCE-STORE RULE (binding): all edits target /home/benjamin/.config/nvim/agent-system/extensions/**. Never hand-edit any deployed .claude/** tree -- it is gitignored, disposable, and regenerated from the source store. DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 22. Freeze .opencode: silence fragment validation spam and record the frozen-mirror policy
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: neovim
- **Dependencies**: None

**Description**: === STATUS REPAIRED 2026-09-22 (eighth-pass phase 0): researching -> not_started. No specs/022_* directory, no artifacts and no dispatch record exist in the live tree or the archive; the status was left by a dispatch that never wrote anything (last touched 2026-09-01). It deferred tasks 29 and 45 in every dry run via merge.lua. Nothing else changed. ===

=== REVISED 2026-09-01 (backlog streamline: .opencode declared FROZEN) ===
POLICY SETTLED BY USER DECISION: .opencode/ is FROZEN -- not maintained, not generated, not deleted. No sync mechanism will be built (the sibling sync-mechanism task is abandoned with a pointer here); the tree is preserved intact for possible future refactoring, exactly as this task's binding constraint already required. This settles the reframed design question below ("SHOULD opencode-agents.json fragments reference a per-project deploy tree at all?"): under a frozen mirror, no path corrections are owed and defect class (1) breakage is expected and tolerated -- the fix is to stop the noise and record the policy, not to repair paths that will drift again.

REVISED SCOPE, absorbing the narrowed remainder of the abandoned sync-mechanism task:
1. SILENCE THE SPAM (original core): gate or suppress the ~60-notification validation spam on <leader>al reload (emitter: M.generate_opencode_json / validate_opencode_fragment in lua/neotex/plugins/ai/shared/extensions/merge.lua). Under the frozen policy, missing {file:} deploy targets are an EXPECTED state; the validator must not shout about them on every reload. Prefer gating generation/validation behind the frozen policy (skip, or a single-line summary) over deleting the mechanism -- the binding constraint that no opencode fragment, validator function, or .opencode/ file is deleted still holds.
2. FIX THE ONE FAKE-TOOL LINE (from the absorbed task): .opencode/extensions/web/agents/web-implementation-agent.md still teaches browser_verify_text_visible as a real tool; the source store explicitly retracts it. A frozen mirror may drift, but it must not actively teach a nonexistent tool. One-line fix, editing .opencode/** directly (it has no source-store counterpart; the source-store/deploy-boundary rule does not apply to this tree).
3. RECORD THE POLICY where the next person will look (e.g. a note in .opencode/ and/or the extensions docs): the tree is frozen, unmaintained, drift-expected, and preserved for future refactoring.
ACCEPTANCE: a <leader>al reload from a project carrying an opencode.json.managed marker produces no validation-failure spam; the fake tool name no longer appears as usable guidance in .opencode/; the frozen policy is written down; nothing under .opencode/ is deleted.
=== ORIGINAL DESCRIPTION FOLLOWS ===
=== REVISED 2026-08-24 (refactor survey) ===
SUBSTANTIALLY OVERTAKEN, and the remaining half got worse. Re-verified today:
- Defect class (3) is FIXED. merge.lua:1002-1041 now degrades per-agent-key, reports every missing key rather than only the first, and no longer discards a whole fragment. Close it out; do not re-fix.
- Defect class (2) MOVED rather than got fixed. The archived path-fix work changed the lean fragment to reference .claude/agents/lean-research-agent.md instead of .claude/extensions/lean/agents/... -- but that path does not exist either.
- Defect class (1) is WORSE: 30 of 34 {file:} refs across all fragments now point at nonexistent files (was 16 of 18). Only nvim and nix resolve, because those are the extensions loaded in this repo -- which is itself the clue.
REFRAME around the one live question rather than patching paths again: SHOULD opencode-agents.json fragments reference a per-project deploy tree at all? Every {file:} ref is per-repo-deploy-dependent by construction, so any path fix is correct only for the extension set of whichever repo it was fixed in. That is why class (1) keeps regrowing. Answer the design question first; the path corrections fall out of it.
=== ORIGINAL DESCRIPTION FOLLOWS ===
Silence and correct opencode-agents.json fragment validation spam on extension reload.

SYMPTOM (observed live): reloading .claude/ via <leader>al from a project with an
opencode.json.managed marker emits ~60 WARN notifications of the form "Extension 'X'
opencode-agents.json validation failed: Agent 'Y' references missing file: Z. Skipping
fragment." before "Resynced 12 extension(s)".

EMITTER: M.generate_opencode_json in lua/neotex/plugins/ai/shared/extensions/merge.lua
(vim.notify at ~line 994), gated on an opencode.json.managed marker check (~line 931), with
per-fragment validation by M.validate_opencode_fragment (~line 887), which resolves each agent
prompt's {file:PATH} against project_dir.

THREE DISTINCT DEFECT CLASSES (measured against a live project, not assumed):

(1) MISSING DEPLOY TARGETS -- 16 of 18 {file:} refs across python (2), present (5), nix (2),
and filetypes (7) point at .opencode/agent/subagents/*-agent.md files that were never
deployed. The .opencode/agent/subagents/ directory DOES exist and holds 15 agent files
(core, lean, latex, typst, math, logic, physics, formal, meta-builder, planner,
code-reviewer), but none for those four extensions. So this is a partial-deploy gap, not a
wholly absent tree.

(2) LEAN WRONG-PATH BUG (independent of any opencode policy decision) --
agent-system/extensions/lean/opencode-agents.json is the ONLY fragment using a .claude/ path
shape. It references .claude/extensions/lean/agents/lean-research-agent.md and
.claude/extensions/lean/agents/lean-implementation-agent.md, neither of which exists anywhere,
while the CORRECT files .opencode/agent/subagents/lean-research-agent.md and
.opencode/agent/subagents/lean-implementation-agent.md ALREADY EXIST on disk. This is a plain
mis-pathed reference, fixable on its own merits regardless of what is decided about opencode.

(3) NOTIFICATION SPAM AND SIMULTANEOUS UNDER-REPORTING -- the same 5 messages repeat ~12 times
because generation runs once per resynced extension rather than once per reload. Separately,
validate_opencode_fragment iterates with pairs() and returns on the FIRST missing ref, so only
one broken ref per extension is ever named, and WHICH one varies nondeterministically between
runs (python alternates python-research/python-implementation; filetypes alternates
scrape/filetypes-spreadsheet). The true breakage (18 refs) is therefore both over-announced in
aggregate and under-reported per message.

BINDING CONSTRAINT (from the user): .opencode/ is NOT currently used and may be excluded from
scope, BUT the fix MUST NOT damage or delete .opencode/ infrastructure. The opencode-agents.json
fragments, the validator function, the managed-marker gating, and the existing .opencode/ tree
must all survive intact so .opencode/ can be refactored in the future. Prefer suppressing or
gating the noise over removing the mechanism.

ACCEPTANCE: a <leader>al reload from a project carrying an opencode.json.managed marker
produces no validation-failure spam; the lean fragment's two refs resolve to real files;
whatever gating approach is chosen is documented; and no opencode fragment, no validator
function, and no .opencode/ file is deleted.

SOURCE-STORE RULE (binding): edit lua/** for the Lua emitter and agent-system/extensions/** for
the JSON fragments; never edit .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

=== ABSORBED 2026-09-28 (path review, fifth pass) from former task 45 (global_update_extension_repo_registry); that task is abandoned into this one. Its text follows verbatim; where it names "the dependency task" or "the sibling task", read this task's other sections. ===

TOPIC CORRECTION + BACKFILL NOTE (task-116 audit). This task carried topic core-agent-system, but its real scope (the <leader>al extension picker's 'Global Update' action) is nvim-config Lua UI code at lua/neotex/plugins/ai/claude/commands/picker/** and lua/neotex/plugins/ai/shared/extensions/**, NOT agent-system/extensions/** -- it is unrelated to the orchestrate-engine collapse. Re-topiced to neovim; file_scope backfilled from description evidence (was previously empty). Original description follows.\n\nImplement <leader>al repo registration and 'Global Update' action: when <leader>al loads extensions into other repos, register those repos and their loaded extensions in this nvim repo; add a 'Global Update' entry (similar to 'Reload All') that reloads all extensions already loaded in each registered repo, reporting any failures in a message and otherwise success as a count of the total

=== ABSORBED 2026-09-22 from former task 202 (Make the picker's [Reload All] and [Regenerate] entries honest and self-documenting, and rule on their redundancy); that task is abandoned into this one. Its text follows verbatim; where it names "the dependency task" or "the sibling task", read this task's other sections. ===

Fix the <leader>al picker's [Reload All] / [Regenerate] entries: a factually wrong one-line description, an absent Command Details preview for both, and an undecided redundancy question.

EDIT TARGET: lua/neotex/plugins/ai/claude/commands/picker/** and lua/neotex/plugins/ai/shared/extensions/**. This is nvim-config Lua UI code, NOT agent-system/extensions/**; nothing here touches the deployed .claude/ tree.

=== VERIFIED CURRENT BEHAVIOUR (read from source, not inferred) ===

The two entries are DIFFERENT operations, and both act on the CURRENT REPO ONLY (cwd):

[Reload All] (picker/init.lua:159-286) opens a vim.ui.select submenu with four choices --
"Reload All", "Unload All", "Step Through", "Cancel". The "Reload All" choice calls
exts.resync_all(), whose own doc comment at shared/extensions/init.lua:895-898 states: "Never
unloads: each extension is re-loaded in place via manager.load(..., {force = true}), so there is
no destructive intermediate 'everything unloaded' state." It force-resyncs every CURRENTLY LOADED
extension in Kahn's-algorithm dependency order. Non-destructive. No confirmation prompt.
("Step Through" is currently a no-op that just reopens the picker.)

[Regenerate] (picker/init.lua:110-156) calls exts.wipe({project_dir = vim.fn.getcwd()}), which
runs vim.fn.delete(target_dir, "rf") at shared/extensions/init.lua:1253 -- snapshot ->
rm -rf base_dir -> regenerate from the surviving project-root extension manifest -> restore
settings.local.json and .syncprotect-listed paths -> clear staging. Destructive. Confirmation
required.

=== DEFECT 1: THE [Reload All] ONE-LINER DESCRIBES [Regenerate], NOT ITSELF ===

display/entries.lua:980-982 renders [Reload All] with the trailing text:

    "Wipe and reload all loaded extensions"

It does not wipe. resync_all never unloads and never deletes. The word "Wipe" belongs to
[Regenerate], whose own one-liner at entries.lua:995-997 ("Wipe and rebuild from the extension
manifest") is accurate. So the picker currently presents two adjacent entries whose visible
descriptions both begin "Wipe and ...", one of which is false -- which is precisely the confusion
that motivated this task: an operator reaching for a rebuild picked [Reload All] on the strength
of that line.

Note the contradiction is already internal to the codebase: display/previewer.lua:129-130
describes the same entry correctly as "Force-resyncs every currently loaded extension in
dependency order (non-destructive)." Two descriptions of one entry disagree.

=== DEFECT 2: NEITHER ENTRY HAS A Command Details PREVIEW ===

Both entries are created with entry_type = "special" plus a boolean flag (is_reload_all,
is_regenerate) at entries.lua:974-999. The previewer's define_preview dispatch chain
(previewer.lua:628-661) branches on is_heading, is_help, and then eleven entry_type values --
skill, hook_event, lib, script, test, template, doc, command, extension, agent, root_file. There
is NO branch for is_reload_all, is_regenerate, or entry_type == "special". Both therefore fall to
the terminal else at previewer.lua:658-659, which writes the single line "Unknown entry type"
into the "Command Details" pane.

So the pane is not blank -- it renders a developer-facing error string for two entries that are
working as designed. The real documentation for both operations exists, but it is buried inside
preview_help (previewer.lua:129-135), reachable only by selecting the separate [Keyboard
Shortcuts] entry.

DECIDE, do not assume: whether to add a dedicated preview_special branch keyed on the two boolean
flags, or to give special entries a shared preview keyed on entry_type == "special" that reads a
per-entry description field. Either way, the terminal else branch should stop being reachable for
entries the picker itself ships -- consider whether "Unknown entry type" is the right fallback at
all, or whether it should name the offending entry so the next gap is diagnosable.

=== DEFECT 3: THE REDUNDANCY QUESTION, UNDECIDED ===

There is genuine partial overlap: [Regenerate]'s wipe-and-rebuild reloads the same extension set
[Reload All] resyncs, so it subsumes the OUTCOME while differing in method, risk, and guarantees.
Whether that justifies two entries is a real design call, not an obvious yes or no. Weigh at
least: (a) keep both, with corrected descriptions that make the destructive/non-destructive
distinction the FIRST thing each line says; (b) collapse [Regenerate] into the [Reload All]
submenu as a fourth, confirmation-gated choice alongside Unload All, giving one entry point for
all bulk extension operations; (c) keep both but rename them so neither reads as a synonym of the
other. Record the ruling and its reasoning.

While deciding (b), note the [Reload All] submenu already contains a dead choice: "Step Through"
(init.lua:180-185) does nothing but reopen the picker. Decide its disposition too -- implement or
remove; do not leave a menu item that silently no-ops.

=== A CORRECTION TO THE OPERATOR'S MENTAL MODEL, WORTH RECORDING IN THE PREVIEW TEXT ===

[Regenerate] is sometimes remembered as "run Reload All across every repo that has loaded the
agent system, preserving each repo's own loaded extension set". It does NOT do that, and never
has -- it is single-repo, scoped to vim.fn.getcwd(), exactly like [Reload All].

That cross-repo capability is a DIFFERENT, already-filed, not-yet-started piece of work: the
task titled "Implement <leader>al repo registration and 'Global Update' action" describes
registering repos that <leader>al loads extensions into, and adding a 'Global Update' entry
"similar to 'Reload All'" that reloads all extensions already loaded in each registered repo.
Coordinate with it rather than implementing cross-repo behaviour here; this task's job is to make
the two EXISTING single-repo entries honest and self-documenting. Whichever of the two lands
second should make sure all three entries read as a coherent set.

=== ACCEPTANCE ===

- [Reload All]'s visible one-liner no longer claims it wipes, and states its non-destructive
  force-resync nature; [Regenerate]'s continues to state its destructive nature. The two lines are
  distinguishable at a glance.
- Selecting either entry renders real content in the "Command Details" pane -- what it does, what
  it touches, whether it is destructive, whether it prompts -- and "Unknown entry type" is no
  longer reachable for any entry the picker ships.
- The entries.lua one-liner and the previewer text for a given entry agree with each other and
  with the implementation; a check or comment records that they must be kept in sync.
- The redundancy ruling is recorded with reasoning, and "Step Through" is either implemented or
  removed.
- Verified by opening <leader>al and selecting each entry, not by reading the diff alone.
