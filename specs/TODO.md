---
next_project_number: 168
---

# TODO

## Task Order

*Updated 2026-09-07. Generated from state.json dependency graph.*

**Dependency Waves**:
| Wave | Tasks | Blocked by | Topics |
|------|-------|------------|--------|
| 1 | 22,29,39,43,44,45,51,74,88,89,127,136,137,139,151,152,157,161,162,163,166,167 | -- | core-agent-system, extensions, literature, ... |
| 2 | 14,30,75,76,129,140,142,150,155,164 | 29,74,88,137,139,162 | core-agent-system, extensions, file-scope-lifecycle |
| 3 | 156,165 | 155,163,164 | extensions, file-scope-lifecycle |

**Grouped by Topic** (indented = depends on parent):

### Core Agent System

44 [PLANNED] — LOWER PRIORITY (per-invocation cost, not per-session). `commands/
51 [NOT STARTED] — Stop session-scoped orchestration runtime files from accumulating
88 [NOT STARTED] — === ADDENDUM 2026-09-02 (team mode deleted; dry-run report retire
  └─ 14 [NOT STARTED] — === REVISED 2026-08-24 (refactor survey) ===
  └─ 129 [NOT STARTED] — Audit every `\b` word-boundary construct used in a grep pattern a
  └─ 142 [NOT STARTED] — === REVISED 2026-09-02 (thin-lead path: narrowed to measure-and-l
  └─ 150 [NOT STARTED] — Research on demand: let the planner decide whether a research pha
89 [NOT STARTED] — Apply the mode-gated section convention to the two remaining larg
127 [NOT STARTED] — === REVISED 2026-09-01 (backlog streamline: absorbs the present-r
136 [NOT STARTED] — PRODUCER-SIDE root cause of the malformed plan-level Status line 
137 [IMPLEMENTING] — The lean extension's research and implementation agents have no a
139 [NOT STARTED] — Bare git history rewrites (`git commit --amend`, `git reset` with
  └─ 14 [NOT STARTED] — === REVISED 2026-08-24 (refactor survey) === (see above)
  └─ 140 [NOT STARTED] — Give agent-system/extensions/core/hooks/guard-destructive-git.sh 
151 [NOT STARTED] — Two verify-deploy.sh gate failures are live in this repo today, b
152 [NOT STARTED] — An unrelated multi-task /orchestrate batch was fully blocked by t
157 [NOT STARTED] — The "Grouped by Topic" summary lines in TODO.md are cut with a bl
161 [NOT STARTED] — Settle the unattended-refresh policy and update the systemd, skil
166 [NOT STARTED] — DEFECT: a produced research report used section headings that are

### Extensions

29 [NOT STARTED] — TOPIC CORRECTION (backlog streamline 2026-09-01): re-topiced core
  └─ 30 [NOT STARTED] — TOPIC CORRECTION (backlog streamline 2026-09-01): re-topiced core
43 [NOT STARTED] — TOPIC CORRECTION (backlog streamline 2026-09-01): re-topiced core
74 [NOT STARTED] — Build a shared, task-type-agnostic guard script that detects a us
  └─ 75 [NOT STARTED] — Wire the shared LaTeX build guard into the latex extension's life
  └─ 76 [NOT STARTED] — Close the coverage gap that the latex-extension wiring cannot rea
167 [NOT STARTED] — Make continuous-build (vimtex `latexmk -pvc`) safety guidance alw
155 [NOT STARTED] — BACKGROUND (verified 2026-09-07, shared by all Comparator tasks).
  └─ 156 [NOT STARTED] — BACKGROUND (verified 2026-09-07, shared by all Comparator tasks).

### Literature

39 [PLANNED] — Upgrade the literature extension's Zotero integration beyond bare

### Neovim

45 [NOT STARTED] — TOPIC CORRECTION + BACKFILL NOTE (task-116 audit). This task carr

### Opencode

22 [RESEARCHING] — === REVISED 2026-09-01 (backlog streamline: .opencode declared FR

### File Scope Lifecycle

162 [NOT STARTED] — Populate `file_scope` at PLAN time by formalizing an existing, un
  └─ 164 [NOT STARTED] — One-shot backfill of `file_scope` for existing tasks that lack a 
    └─ 165 [NOT STARTED] — Settle whether an ABSENT `file_scope` should be admission-relevan
163 [NOT STARTED] — Make an ABSENT or EMPTY `file_scope` visible. Today it is invisib
  └─ 165 [NOT STARTED] — Settle whether an ABSENT `file_scope` should be admission-relevan (see above)

## Tasks

### 167. Make vimtex continuous-build safety always-in-effect via the latex extension rule
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: None

**Description**: Make continuous-build (vimtex `latexmk -pvc`) safety guidance always-in-effect for every agent and command, not only latex-typed dispatches, by extending the latex extension's EXISTING deployed rule file rather than adding a new mechanism.

=== MOTIVATING INCIDENT (2026-09-07, PossibleWorlds paper repo, JPL/ subdirectory) ===

Command-line `latexmk -pdf` runs issued during an ordinary editing conversation (NOT a latex-typed task) raced a running vimtex `latexmk -pvc` watcher on the same shared build/ directory.

Symptoms: empty .aux file; deleted PDF; spurious "Build failed" entries appended to build/compile.log by the .latexmkrc $failure_cmd; bibtex reporting "I found no \citation commands"; latexmk exit code 12 despite ZERO LaTeX errors in the log. The exit-12-with-clean-log signature was misread as a LaTeX error, prompting repeated rebuilds that compounded the race.

Verified during diagnosis:
  - `pgrep -af 'latexmk'` showed the vimtex process with flags:
      -pvc -pvctimeout- -view=none -outdir=build -emulate-aux-dir -auxdir=build
  - An isolated build succeeded cleanly and was the correct verification path:
      latexmk -pdf -outdir=$SCRATCH -auxdir=$SCRATCH -r /dev/null file.tex
  - A direct `pdflatex -output-directory=build` also exited 0, confirming the source was fine
    and the failure was latexmk-level contention, not a LaTeX error.

=== ROOT-CAUSE FINDING (drives the recommendation) ===

The rule `agent-system/extensions/latex/rules/latex.md` ALREADY exists, ALREADY declares
`paths: "**/*.tex"`, and is ALREADY deployed to the paper repo as `.claude/rules/latex.md`
(confirmed present). Because the incident conversation was editing `JPL/possible_worlds.tex`,
that rule was almost certainly auto-loaded at the time.

The rule was therefore not silent -- it was the proximate source of the harmful advice. Its
"Build Commands" section currently prescribes, with no watcher guard whatsoever:

    latexmk -pdf document.tex
    latexmk -c

These are exactly the two commands that must NOT be run against a shared -outdir while a
`-pvc` watcher owns it. Separately, `context/project/latex/tools/compilation-guide.md:215`
documents `latexmk -pdf -pvc` as something to run, with no note that an agent must never
start, kill, or race one.

So the lowest-impact fix is not to add a mechanism. It is to correct an existing file that
already fires on the right trigger and currently says the wrong thing.

=== RECOMMENDED MECHANISM (minimal pair -- option (a) primary + option (b) one-pointer) ===

PRIMARY (option a) -- edit `agent-system/extensions/latex/rules/latex.md`:
  1. Widen the frontmatter glob from `paths: "**/*.tex"` to also cover build/aux surfaces that
     a bare compile command references without touching a .tex file, e.g.
     `**/*.tex`, `**/*.latexmkrc`, `**/build/**`, `**/*.bib`.
     (Confirm the deployer's supported frontmatter syntax for multiple globs before writing --
     every current rule in the source store uses a single-string `paths:` value, so a list form
     must be validated against the loader, not assumed.)
  2. Insert a "Continuous Build Safety" section ABOVE the existing "Build Commands" section, so
     the guard is read before the commands it constrains.
  3. Repair the existing "Build Commands" and "Validation Checklist" blocks so they no longer
     present bare `latexmk -pdf` / `latexmk -c` / "Builds successfully with pdflatex" as
     unconditional instructions.

COMPLEMENT (option b) -- add 3-4 lines to `agent-system/extensions/latex/EXTENSION.md`, the merge
source for the CLAUDE.md "LaTeX Extension" section (merge_targets.claudemd, section_id
`extension_latex`). This is a POINTER ONLY, not a copy of the rule. Rationale: it closes the one
residual gap where an agent issues a bare `latexmk` Bash call having never touched or referenced
any .tex/build path in the session, so no paths-glob match ever fires. Keep it to a few lines --
this text lands in the eager session prefix, which the system explicitly budgets (see
`measure-eager-context.sh` / `measure-eager-surface.sh`).

Also update `context/project/latex/tools/compilation-guide.md` (around the `-pvc` line, ~215) with
a one-line cross-reference to the new rule section, so the lazily-loaded guide does not contradict
the eagerly-loaded rule.

=== ACCEPTANCE CRITERIA (the five behavioral points; the rule text must make each actionable) ===

AC1. DETECT BEFORE COMPILING. Before any latexmk/pdflatex/xelatex/lualatex invocation, check for a
     running continuous watcher on the same source:
         pgrep -af 'latexmk.*-pvc'
     and/or any latexmk/pdflatex process whose arguments name the same .tex file or the same
     -outdir. The rule must give the literal command, not a paraphrase.

AC2. IF A WATCHER IS RUNNING, DO NOT CONTEND. Never run latexmk/pdflatex into the shared build/
     (or whatever -outdir the watcher uses). Never kill, stop, or restart the watcher. Never run
     `latexmk -C` or `latexmk -c` against the shared directory.

AC3. USE A NON-CONTENDING PATH INSTEAD. Either (i) make the edit and let vimtex rebuild -- it is
     already watching the file -- or (ii) verify compilation with an isolated build into the
     session scratchpad and inspect the log there:
         latexmk -pdf -outdir="$SCRATCH" -auxdir="$SCRATCH" -r /dev/null file.tex
     `-r /dev/null` bypasses the project .latexmkrc (which is what appends the spurious
     "Build failed" entries via $failure_cmd).

AC4. REPORT, DO NOT REPAIR. Report the isolated build's result. If the shared build directory
     looks broken (missing PDF, empty .aux, "Build failed" entries in build/compile.log), tell the
     user to run `:VimtexClean` then `:VimtexCompile`. Do not attempt repairs against the shared
     directory.

AC5. CLASSIFY THE FAILURE BEFORE RERUNNING. When diagnosing a nonzero latexmk exit code,
     distinguish latexmk-level failure (exit 12, bibtex/aux complaints such as "I found no
     \citation commands") from an actual LaTeX error (a `^!` line, or a file-line-error
     `file.tex:N:` line) BEFORE rerunning anything. A clean log with a nonzero exit code is a
     contention signal, not a source error.

AC6. NO DUPLICATION. The guidance lives in exactly one authoritative place (the rule). EXTENSION.md
     and compilation-guide.md carry pointers, not restatements.

AC7. VERIFY THE TRIGGER, DO NOT ASSUME IT. Before closing, empirically confirm whether the widened
     paths glob actually fires for a Bash tool call that merely names a .tex path in its command
     string, versus only for Read/Edit/Write on that path. This determines whether the option (b)
     pointer is load-bearing or merely belt-and-braces, and the finding must be recorded in the
     task report either way.

=== OPTION ANALYSIS (rationale for rejecting the alternatives) ===

(a) RULE FILE via provides.rules with a paths glob -- CHOSEN.
    Already exists, already deployed, already fires on .tex touches, already declared in
    manifest.json provides.rules (["latex.md"]). No manifest change, no new file, no deploy
    topology change. Precedent for the pattern: lean's rules/lean4.md with `paths: "**/*.lean"`.
    Fires regardless of task type -- the harness paths-glob mechanism is independent of task
    routing, of index.json, and of any @-import list (see
    `context/patterns/context-discovery.md`, "Rule Loading: Two Independent Paths").
    Residual gap: a bare Bash `latexmk` that references no matching path -- covered by (b).

(b) MERGE-SOURCE ADDITION to EXTENSION.md -> CLAUDE.md -- CHOSEN AS MINIMAL COMPLEMENT, pointer only.
    Always in the eager session prefix whenever the latex extension is loaded, so it is
    unconditionally task-type-independent and has no trigger dependency at all. Cost: eager
    context bytes, which the system budgets. Hence a pointer, not a copy.

(c) PREFLIGHT LIFECYCLE HOOK in the manifest `hooks` object -- REJECTED. CONFIRMED to fail the
    requirement. Lifecycle hooks run only at skill lifecycle stages via skill-base.sh
    (preflight/context_injection/verification/postflight), so they fire only inside a dispatched
    skill. The motivating incident occurred in an ordinary editing conversation with no skill
    lifecycle active -- exactly the case a lifecycle hook cannot reach. The latex manifest
    currently has `provides.hooks: []` and no top-level `hooks` object.

(d) CONTEXT FILE under context/project/latex/ -- REJECTED. CONFIRMED to fail the requirement.
    Every latex entry in `index-entries.json` is gated on `load_when.task_types: ["latex"]` and
    on the latex agents, making it lazily loaded and task-typed -- precisely the two properties
    the requirement excludes. compilation-guide.md, which already contains the only `-pvc` mention
    in the extension, was NOT loaded during the incident for exactly this reason.

(e) PreToolUse Bash-matcher HOOK via settings-fragment.json -- CONSIDERED AND REJECTED as
    disproportionate, though it is the only mechanism that fires with certainty on a bare
    `latexmk` Bash call carrying no path reference. Precedent exists: the email extension
    registers `mail-guard.sh` as a PreToolUse "Bash" matcher through its settings-fragment.json
    plus `provides.hooks`. Rejected because it requires a new script, a new settings-fragment.json
    for an extension that has none, a manifest provides.hooks change, and it imposes a hook
    invocation on EVERY Bash call system-wide to guard one narrow case. Record this as the
    documented escalation path if AC7 shows the paths glob does not fire for Bash-only references
    and the (b) pointer proves insufficient in practice.

COMPLEMENT, OUT OF SCOPE FOR THIS TASK: the PossibleWorlds paper repo's own CLAUDE.md already has
a "Build Workflow: Preventing Aux File Corruption" section documenting this exact race from the
latexmk side. A short pointer there is warranted, but that file belongs to the paper repo, not to
this source store, and is user-owned. Note it in the report as a follow-up suggestion; do not edit
it from this task.

=== SCOPE BOUNDARY ===

All edits target the SOURCE STORE at `agent-system/extensions/latex/**`. Never hand-author
anything under `.claude/**` -- that tree is a disposable deploy artifact regenerated from source
(see `.claude/rules/source-store-deploy-boundary.md`). Verify the change by redeploying and
confirming the regenerated `.claude/rules/latex.md` and the CLAUDE.md `extension_latex` section
carry the new text.

---

### 166. Stop research reports drifting from validate-artifact.sh's required section headings
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None

**Description**: DEFECT: a produced research report used section headings that are semantically correct but lexically non-conforming, so validate-artifact.sh's required-section check failed on an artifact whose authoring agent ALREADY carries a conforming skeleton. This is NOT the "agent has no skeleton at all" class addressed by the lean/formal skeleton work -- here the skeleton is present and correct, and the produced artifact drifted from it.

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

---

### 165. Decide and implement the admission posture for an absent file_scope in orchestrate-batch-admit.sh
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: file-scope-lifecycle
- **Dependencies**: Task 163, Task 164

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

---

### 164. Backfill file_scope for existing tasks and decide the disposition for plan-less tasks
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: file-scope-lifecycle
- **Dependencies**: Task 162

**Description**: One-shot backfill of `file_scope` for existing tasks that lack a usable one, plus an explicit ruling on the tasks the backfill CANNOT reach.

WHY THIS IS REACHABLE: because `**Files to modify**:` is an already-universal convention (10/10 plan files locally, 11/12 in ~/Projects/BimodalLogic, emitted by the planner template at agents/planner-agent.md:259), any task that HAS a plan can be backfilled by reusing the harvester built alongside plan-format formalization. This is not a from-scratch inference problem for that population.

REUSE, DO NOT DUPLICATE: the derivation logic belongs to the harvester script (anticipated agent-system/extensions/core/scripts/plan-file-scope-harvest.sh). The backfill script must call or source it, never re-implement path extraction -- two divergent parsers for one convention is precisely the defect this chain exists to remove.

THE HARD PART -- PLAN-LESS TASKS (decide and record, do not silently leave uncovered): a task with NO plan yet has no "Files to modify" list to harvest, so the plan-based route cannot reach it. In BimodalLogic this is the MAJORITY of the 22 affected tasks -- most are status `not_started` and will never have had a plan. Options to weigh explicitly:
  (a) leave them absent and let plan-time population (the formalized harvest) cover them naturally when they are eventually planned -- zero risk, but leaves the gap open for however long they sit unplanned;
  (b) infer a provisional file_scope from the task description/title, accepting that it is a guess -- note the schema already frames file_scope as "prospective, not filesystem-validated", so a provisional value is not a category error, but a WRONG one is worse than absence because it produces false confidence in the collision guard;
  (c) write an explicit sentinel (e.g. `[]`) to distinguish "deliberately unknown" from "never considered" -- but see the empty-vs-absent distinction, since an empty array may read as "touches nothing" and would suppress the very warning that should stay lit.
RECORD THE CHOSEN DISPOSITION AND ITS REASONING. Leaving this population undiscussed is the failure mode this paragraph exists to prevent.

SAFETY: the backfill mutates specs/state.json across repos. It MUST write via state-write.sh (the single mutex-guarded writer; hand-rolled `jq ... > tmp && mv` sequences are exactly what that script was built to eliminate). It MUST offer a dry-run that prints the proposed per-task diff without writing, and MUST be idempotent -- a second run over an already-backfilled state changes nothing. It must never overwrite a task that already has a non-empty file_scope.

CROSS-REPO SCOPE: decide whether the script targets only the invoking repo or accepts a `--state-file` / repo argument. The measured need is largely in ~/Projects/BimodalLogic, not here, so a repo-local-only tool would not address the motivating case. Note state-write.sh already supports `--state-file` for non-default targets.

ORDERING: this task is a prerequisite for making an absent file_scope admission-relevant. Backfilling before any enforcement tightens is the mitigation that keeps legacy tasks from being blocked.

ACCEPTANCE: dry-run prints an accurate per-task diff and writes nothing; a real run raises this repo's coverage to 38/38 and BimodalLogic's toward 49/49 for the plan-bearing population; re-running is a no-op; tasks with an existing non-empty file_scope are untouched; the plan-less disposition is implemented and its reasoning recorded; shellcheck clean per context/standards/shell-strict-mode.md.

CANONICAL SOURCE CONSTRAINT (binding): all edits target /home/benjamin/.config/nvim/agent-system/extensions/core/. Never hand-edit any deployed .claude/** tree -- it is gitignored, disposable, and regenerated from the source store by the loader, so edits there are silently wiped. Backfilled DATA under specs/** is exempt from this rule -- specs/** is the legitimate write target for task-management artifacts. DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 163. Surface missing and empty file_scope in validate-state.sh and orchestrate-predispatch-review.sh
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: file-scope-lifecycle
- **Dependencies**: None

**Description**: Make an ABSENT or EMPTY `file_scope` visible. Today it is invisible everywhere, by construction.

VERIFIED GAP -- both existing checks skip exactly the entries that lack the field:
1. agent-system/extensions/core/scripts/validate-state.sh Check 8 (coarse whole-directory-root declarations, ~line 460) and Check 9 (duplicate entries within one task's array, ~line 501) are BOTH WARN-only AND both guard with `select(has("file_scope"))`. An entry with no file_scope key is silently skipped by both. There is no missing/empty check anywhere in the script.
2. agent-system/extensions/core/scripts/orchestrate-predispatch-review.sh Class B (~line 236) iterates `["dependencies", "file_scope", "title", "topic"]` and matches with `select(($entry | has($field)) and ($entry[$field] == null))`. Its own comment states the intent verbatim: "A genuinely absent key is NOT flagged -- only a present-but-literal-null value is the anomaly this class exists to surface." So absence is skipped BY DESIGN, not by oversight.

These two are consolidated into one task deliberately: both are WARN-shaped detection edits in the same layer, and splitting them would force two tasks to independently re-derive the same WARN-vs-block conclusion.

WORK: add a missing/empty file_scope check to validate-state.sh; extend predispatch-review to surface an absent file_scope. For the latter, DECIDE whether to widen Class B or add a NEW class -- widening Class B changes the documented meaning of an established class (its comment explicitly scopes it to literal-null) and Class B feeds `--repair`, which normalizes null to []. Note that an absent key and a literal-null value are NOT equivalent for repair purposes: normalizing an absent key to `[]` would manufacture an empty declaration that then looks deliberate, which is arguably worse than absence. A new class avoids both hazards. Record the ruling either way.

ENFORCEMENT LEVEL -- PRIOR ART, FOLLOW IT: plan-format.md:259-266 records the Verification Tier rollout as the in-repo precedent for exactly this decision. Quoted: per-phase tier enforcement in validate-artifact.sh is "advisory-first: a missing `**Verification Tier**:` field emits a warning, not an error, so default-mode validation of plans authored before this vocabulary existed continues to pass. `--strict` mode enforces it today. Promotion criterion: promote the warning to an error once no non-terminal plan under specs/ lacks the field. This is recorded here for a future task to execute; it is not done by the task that introduced this vocabulary."

Apply that same three-part pattern here: (a) start WARN in default mode; (b) WRITE DOWN an explicit promotion criterion in the script's own header comment; (c) do NOT promote in this task. Consider whether `--strict` should enforce it immediately, as validate-artifact.sh does. Do not invent a different enforcement philosophy -- this precedent exists and is load-bearing.

EMPTY vs ABSENT: treat `file_scope: []` and a missing key as distinct states and decide whether both warn. An explicit empty array may be a deliberate "this task touches nothing" assertion; a missing key is an omission. Record the distinction.

MEASUREMENT VALUE: this task is what makes the problem measurable. Local coverage is 37/38 active tasks with a non-empty file_scope; ~/Projects/BimodalLogic is 27/49, with 22 lacking a usable value (17 missing the key, 5 literal null) spanning 2026-05-11 through 2026-08-26 -- longstanding, not a recent regression. The check must reproduce those counts.

ACCEPTANCE: validate-state.sh reports the missing/empty count and exits 0 in default mode; the promotion criterion is written into the script header; predispatch-review surfaces absent file_scope with the class decision documented; `--repair` does not manufacture `[]` on absent keys; both scripts shellcheck clean per context/standards/shell-strict-mode.md; running against this repo's specs/state.json yields the expected 1-of-38 figure.

CANONICAL SOURCE CONSTRAINT (binding): all edits target /home/benjamin/.config/nvim/agent-system/extensions/core/. Never hand-edit any deployed .claude/** tree -- it is gitignored, disposable, and regenerated from the source store by the loader, so edits there are silently wiped. DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 162. Formalize the existing Files to modify convention in plan-format and harvest it into file_scope at plan postflight
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: file-scope-lifecycle
- **Dependencies**: None

**Description**: Populate `file_scope` at PLAN time by formalizing an existing, universally-followed convention and making it reliably machine-harvestable.

FRAMING -- THIS IS NOT A GREENFIELD FIELD. `**Files to modify**:` is already a de facto universal convention. Verified: present in 10/10 plan files under specs/*/plans/ in this repo (11/12 in ~/Projects/BimodalLogic); already EMITTED by the planner's own phase template at agent-system/extensions/core/agents/planner-agent.md:259 (`**Files to modify**:` followed by `- `path/to/file` - {what changes}`). What is missing is only its FORMALIZATION: context/formats/plan-format.md's per-phase field list (lines 76-95: Goal, Tasks, Timing, Depends on, Verification Tier, Commit Mode, Scope Hypothesis, Owner) does not enumerate it. The task is to formalize the convention and pin a stable grammar, NOT to invent a carrier.

CONSEQUENCE: the harvest has near-total existing coverage to work against immediately, making this substantially lower-risk than a greenfield field would be. Do not design for a sparse-adoption rollout; design for a convention already in place.

COMPATIBILITY CONSTRAINTS (binding -- three existing consumers reference this by name; any grammar settled on MUST keep all three working):
1. agent-system/extensions/core/agents/general-implementation-agent.md:65 -- reads "Files to modify/create per phase" when extracting from the plan.
2. agent-system/extensions/core/skills/skill-orchestrate/SKILL.md:1274,1280 -- the H1 territory block sets `"owned_files": "derive from plan_path's Phase N \"Files to modify\" list"`.
3. agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh:1335 -- the same territory derivation, ported verbatim.

IMPORTANT NUANCE about consumers 2 and 3: neither parses the list itself. Per the comment at SKILL.md:1274, "The orchestrator does not parse the plan's 'Files to modify' list itself -- it points the agent at the plan/phase location" and the agent derives owned_files from the phase section. So the constraint these two impose is HEADING-NAME STABILITY (the literal string is embedded in a prompt directive handed to an agent), not parser grammar. Changing the heading text would silently break the directive with no parse error. Treat the name as frozen.

GRAMMAR: two punctuation variants exist in practice -- `**Files to modify**:` (64 occurrences) and `**Files to modify:**` (6). This matches plan-format.md's already-documented "Field-punctuation tolerance" rule for per-phase field labels, which states both forms are accepted; the harvester MUST accept both. Settle the list-item grammar against the planner template's emitted shape (`- `path/to/file` - {what changes}`), tolerating the backtick-quoted path and the trailing ` - {description}`.

SCOPE-HYPOTHESIS ALIGNMENT: plan-format.md:251 defines any plan-asserted file list as "a hypothesis requiring implementation-time confirmation, never a fact". The state schema (context/schemas/state-schema.json:227) independently describes file_scope as "prospective, not filesystem-validated". These align: harvesting a plan-time hypothesis into a prospective field is coherent, and the harvest MUST NOT filesystem-validate the paths or drop ones that do not yet exist (new files are exactly what a plan creates). Where a phase carries a `**Scope Hypothesis:**` line, decide whether it informs the harvest or is ignored, and record the ruling.

WORK: (1) add `**Files to modify**:` to plan-format.md's per-phase field list with its grammar, marking it required-or-advisory deliberately; (2) record the three consumers above in plan-format.md as compatibility constraints so a future format change accounts for them, mirroring how that file already lists the three consumers of the phase-heading contract; (3) build the harvester (anticipated: agent-system/extensions/core/scripts/plan-file-scope-harvest.sh) that unions every phase's list into a deduplicated file_scope; (4) wire it into plan postflight, writing via state-write.sh (the single mutex-guarded writer -- do not hand-roll a jq read-modify-write).

DECIDE, DO NOT ASSUME: whether harvest OVERWRITES an existing file_scope or unions into it; whether a plan revision (/revise, a new MM_ plan round) re-harvests; whether a harvest failure is fatal to postflight or a warning (note update-task-status.sh's and state-write.sh --regen-todo's existing posture is a loud warning, not a hard failure).

ACCEPTANCE: plan-format.md enumerates the field with its grammar and its three named consumers; the harvester extracts the correct union from all 10 local plan files under specs/*/plans/ and accepts both punctuation variants; a plan postflight on a task with a plan populates a non-empty file_scope; the three existing consumers are demonstrably unbroken (the heading string is unchanged); shellcheck clean per context/standards/shell-strict-mode.md.

CANONICAL SOURCE CONSTRAINT (binding): all edits target /home/benjamin/.config/nvim/agent-system/extensions/core/. Never hand-edit any deployed .claude/** tree -- it is gitignored, disposable, and regenerated from the source store by the loader, so edits there are silently wiped. DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 161. Settle the unattended-refresh policy and update the systemd, skill, and command surfaces
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 160

**Description**: Settle the unattended-refresh policy and update the systemd, skill, and command surfaces.

POLICY IS ALREADY LARGELY SETTLED -- CONFIRM, DO NOT RE-LITIGATE: claude-refresh.service already runs --dry-run, and its comment block states verbatim that "this unattended, hourly, no-confirmation cadence is intentionally non-destructive -- it reports/logs found orphans rather than terminating them. A matcher bug must never again be amplifiable into unattended hourly kills, regardless of how correct the matcher looks at review time." So the open question is narrow: confirm that the new passes added by the earlier tasks in this chain require NO unit change -- expected, since the timer never terminates anything -- and record that reasoning in the unit comment so a future reader does not re-open it.

DEPLOY-PATH DECISION: ExecStart points at %h/.config/nvim/.claude/scripts/claude-refresh.sh, inside the gitignored, regenerated deploy tree. That is arguably correct for a unit installed on a machine, but it means the unit silently breaks whenever the deploy tree is absent. Decide explicitly whether to keep it as-is, add a ConditionPathExists, or document the dependency -- and record the choice.

SURFACES: finish by making skill-refresh/SKILL.md and commands/refresh.md describe the full pass inventory coherently -- orphaned Claude processes, ~/.claude/ cleanup, orphaned postflight markers, stale task .lock dirs, Lean LSP reclamation, MCP fan-out reporting, zombie reporting -- each with its gate and whether it is destructive, rather than as four bolted-on additions to a document written for the original four.

FILES: agent-system/extensions/core/systemd/claude-refresh.service; agent-system/extensions/core/systemd/claude-refresh.timer; agent-system/extensions/core/skills/skill-refresh/SKILL.md; agent-system/extensions/core/commands/refresh.md; possibly agent-system/extensions/core/scripts/claude-refresh.sh for --help text only.

ACCEPTANCE: `systemd-analyze verify` passes on both units; the service comment states the ruling on new destructive passes and the deploy-path dependency; SKILL.md documents every pass with its gate and destructiveness; `/refresh --dry-run` help text matches the documented inventory; the doc-lint script check-extension-docs.sh exits zero.

TOOLING-AVAILABILITY RISK: this task's acceptance depends on `systemd-analyze verify` and check-extension-docs.sh both being available in the implementing agent's environment. If either is absent, REPORT THE GATE AS UNRUN rather than assumed-green. A truthful "could not verify" is the correct outcome; silently treating an unavailable check as passing is not.

CANONICAL SOURCE CONSTRAINT (binding): all edits target /home/benjamin/.config/nvim/agent-system/extensions/core/. Never hand-edit any deployed .claude/** tree -- it is gitignored (.gitignore line 6: `/.claude/`), disposable, and regenerated from the source store by the loader, so edits there are silently wiped. DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 160. Add report-only refresh passes for unused MCP fan-out and unreaped child processes
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 159
- **Research**: [160_report_only_mcp_and_zombie_passes/reports/01_mcp-fanout-and-zombie-passes.md]
- **Plan**: [160_report_only_mcp_and_zombie_passes/plans/01_mcp-fanout-and-zombie-passes.md]
- **Summary**: [160_report_only_mcp_and_zombie_passes/summaries/01_mcp-fanout-and-zombie-passes-summary.md]

**Description**: Add report-only refresh passes for unused MCP fan-out and unreaped child processes.

Two non-destructive diagnostic passes, independently gated; neither ever terminates anything.

(a) UNUSED PER-SESSION MCP FAN-OUT: ~/.claude.json defines lean-lsp and playwright at USER scope, so every session inherits both unconditionally -- 5 sessions x 3 procs = 15 procs / 346 MB. playwright-mcp was running in all 5 sessions having spawned ZERO browsers (no chromium/headless_shell present anywhere on the system). Detect user-scope servers running with no evidence of use, report them, and advise per-project scoping where a server is genuinely repo-local.

SCOPING TRADE-OFF -- STATE IT ACCURATELY (this corrects a false premise this task previously carried): there is NO categorical barrier preventing dispatched subagents from reaching project-scoped .mcp.json servers. That claim is disproven -- demonstrated directly, twice, including via the general-research-agent class this system actually dispatches, with permission pre-granted so permission was not a confound. See context/patterns/mcp-server-ownership.md, sections "The session-start snapshot trap" and preceding. The real, honest cost of project scope is WORKSPACE TRUST: an untrusted workspace requires a one-time interactive approval before a project-scoped server is used, and a cloned repository cannot pre-authorize its own servers from inside the repo. That is a one-time setup cost, not a per-call or per-session obstacle, and it is not a reason to avoid project scope for repo-local servers. The advisory output MUST cite the trust cost, and MUST NOT reproduce the subagent-barrier claim.

RELATED CORRECTION IN SCOPE: docs/docs-README.md line 78 still asserts "Custom subagents cannot access project-scoped MCP servers (.mcp.json). For subagent access, configure servers in user scope" -- the same disproven claim, and the source from which it propagated. Correct it to state the trust cost instead, and point to context/patterns/mcp-server-ownership.md as the authority. Leaving a known-false claim in the docs while this task reports on MCP scoping would be incoherent.

TESTING NOTE (avoids reproducing the original false negative): a session's tool registry is a snapshot taken at startup, so an already-running session cannot see a server added to .mcp.json after it started -- this affects the MAIN session identically and is not subagent-specific. Any re-verification of registration or reachability MUST use a fresh session (or claude -p), never an already-running one.

(b) UNREAPED CHILDREN / ZOMBIES: lean-lsp-mcp never wait()s its lake child, leaving `lake <defunct>`; speech-dispatcher has leaked 7 sd_* zombies over 6 days. Cosmetic -- PID slots only -- but should be reported, never silently ignored.

Both passes report memory using the VmSwap-aware accounting from the earlier task in this chain.

CROSS-REFERENCE, NO DEPENDENCY: tasks #29 (generate_mcp_json_from_extension_manifests) and #30 (register_obsidian_memory_mcp_server) both concern GENERATING .mcp.json from extension manifests -- #29 the deploy-engine mechanism, #30 registering obsidian-memory through it. This task only REPORTS unused user-scope fan-out and touches no manifest or deploy-engine code, so there is no file overlap and deliberately no dependency edge; blocking a report-only change behind a deploy-engine rewrite would be wrong. The relationship runs the useful direction: the empirical finding here -- that user-scope servers fan out unconditionally into every session at real memory cost -- is direct evidence for the premise behind that other work.

SEQUENCING NOTE: this task's dependency on the Lean reclamation task is FILE-OVERLAP SERIALIZATION, not a logical prerequisite. Both edit claude-refresh.sh. The user explicitly chose to keep all passes in claude-refresh.sh rather than extracting them into a separate sourced file, so the serialization stands.

FILES: agent-system/extensions/core/scripts/claude-refresh.sh (two passes + predicates); agent-system/extensions/core/scripts/tests/test-claude-refresh-matcher.sh; agent-system/extensions/core/skills/skill-refresh/SKILL.md; agent-system/extensions/core/commands/refresh.md; agent-system/extensions/core/docs/docs-README.md (line 78 correction only).

ACCEPTANCE: both passes produce identical output under --dry-run and --force, proving non-destructiveness; zombie detection distinguishes `Z` state from live processes; the MCP pass reports server name, session count, and aggregate memory via the VmSwap-aware accounting; the scoping advisory cites the workspace-trust cost and contains no subagent-barrier claim -- grep the emitted advisory text to confirm the phrase does not reappear; docs-README.md line 78 no longer asserts a subagent barrier; no code path in either pass reaches a signal call -- verify by grep, not by inspection.

CANONICAL SOURCE CONSTRAINT (binding): all edits target /home/benjamin/.config/nvim/agent-system/extensions/core/. Never hand-edit any deployed .claude/** tree -- it is gitignored (.gitignore line 6: `/.claude/`), disposable, and regenerated from the source store by the loader, so edits there are silently wiped. DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 159. Add an independently-gated reclamation pass for orphaned Lean LSP process trees
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 158
- **Research**: [159_orphaned_lean_lsp_reclamation_pass/reports/01_lean-lsp-reclamation-pass.md]
- **Plan**: [159_orphaned_lean_lsp_reclamation_pass/plans/01_lean-lsp-reclamation-pass.md]
- **Summary**: [159_orphaned_lean_lsp_reclamation_pass/summaries/01_lean-lsp-reclamation-pass-summary.md]

**Description**: Add an independently-gated reclamation pass for orphaned Lean LSP process trees.

PROBLEM: lean-lsp-mcp spawns `lake serve` -> `lean --server` -> one `lean --worker` per file opened, and source grep shows teardown ONLY at shutdown (lean_lsp_mcp/client_utils.py:196 `_close_client`). There is no idle timeout and no LRU eviction, so workers live as long as the Claude session does. Observed: a tree idle 13h holding 2.06 GiB of swap. Reclaimed live during diagnosis via SIGTERM children-first with zero loss -- lean-lsp-mcp respawns a fresh tree on the next tool call.

WORK: implement this as a NEW, SEPARATELY-GATED detection pass with its own predicate. Detection keys: comm in (`lake serve`, `lean --server`, `lean --worker`), 0% CPU, and idle beyond a configurable threshold. Reuse the existing is_system_slice_cgroup and is_owned_by_current_uid exclusions as defense in depth. Report memory using the VmSwap-aware accounting from the prerequisite task.

HARD SAFETY CONSTRAINT -- MUST NOT BE VIOLATED: the claude-refresh.sh header documents is_claude_executable_comm as a deliberate narrow executable allow-list that trades recall for safety, stating verbatim "Do not widen `is_claude_executable_comm` to match on a bare argv substring -- that is exactly the defect this rewrite removes." DO NOT loosen or widen that matcher. The new Lean predicate is separate and independently gated. Preserve the existing --dry-run/--force contract and the AskUserQuestion confirmation flow; the new pass must be dry-run-clean.

TERMINATION ORDER: strictly workers -> server -> `lake serve`. Killing the parent first orphans workers into PID 1.

FILES: agent-system/extensions/core/scripts/claude-refresh.sh (new predicate + pass + termination ordering); agent-system/extensions/core/scripts/tests/test-claude-refresh-matcher.sh; agent-system/extensions/core/skills/skill-refresh/SKILL.md (pass description, AskUserQuestion option); agent-system/extensions/core/commands/refresh.md.

ACCEPTANCE: the new predicate has its own test block asserting it matches the three Lean comms and rejects the existing Claude comms, and vice versa -- no cross-contamination between the two matchers; --dry-run lists a Lean tree without terminating anything; --force on a fixture tree terminates in the documented order, verified by an ORDERING assertion, not merely final state; the existing --dry-run/--force contract and confirmation flow are unchanged; is_claude_executable_comm is byte-identical to its pre-task form.

THRESHOLD RISK: the 13h idle observation is a single data point. A threshold set too low will reclaim a tree the user is about to reuse -- recoverable, since the MCP respawns, but it costs a rebuild. Default conservatively and make the threshold configurable.

CANONICAL SOURCE CONSTRAINT (binding): all edits target /home/benjamin/.config/nvim/agent-system/extensions/core/. Never hand-edit any deployed .claude/** tree -- it is gitignored (.gitignore line 6: `/.claude/`), disposable, and regenerated from the source store by the loader, so edits there are silently wiped. DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 158. Make refresh memory accounting VmSwap-aware so zram-compressed idle bloat stops reading as harmless
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None
- **Research**: [158_vmswap_aware_refresh_memory_accounting/reports/01_vmswap_aware_memory_accounting.md]
- **Plan**: [158_vmswap_aware_refresh_memory_accounting/plans/01_vmswap-aware-memory-accounting.md]
- **Summary**: [158_vmswap_aware_refresh_memory_accounting/summaries/01_vmswap-aware-memory-accounting-summary.md]

**Description**: Make refresh memory accounting VmSwap-aware so zram-compressed idle bloat stops reading as harmless.

PROBLEM: the snapshot field list in claude-refresh.sh is `pid,ppid,uid,tty,etimes,rss,comm,cgroup:200,args` -- RSS only. Live diagnosis found Lean workers at ~2 MB RSS holding ~1.2 GB VmSwap each, because the kernel had compressed untouched pages into zram (zramctl showed 9.1 GB data in 2.3 GB of RAM). Any threshold or report built on RSS alone classifies these as harmless. This is a cross-cutting concern: it changes how every other refresh pass reports memory, which is why it is sequenced first.

WORK: add a swap-reading helper alongside format_memory() that reads VmSwap from /proc/PID/status, and thread combined RSS+swap through all existing reporting output.

INVARIANT RULING REQUIRED: the script header (lines 12-17) documents that a single atomic `ps -eo` snapshot is taken once per invocation and that no candidate PID is ever re-queried live, which is the basis of its race-freedom argument. A per-candidate /proc read is the first thing to touch that invariant. Decide and RECORD IN THE HEADER COMMENT whether this breaches it; the defensible position is that it does not, because it is a reporting-only read that never gates a termination decision -- but it must be argued in the header, not silently assumed. Handle missing VmSwap (no swap configured, or the process exited between snapshot and read) without failing the run.

FILES: agent-system/extensions/core/scripts/claude-refresh.sh (snapshot fields, format_memory, new helper, header invariant comment); agent-system/extensions/core/scripts/tests/test-claude-refresh-matcher.sh (new cases).

ACCEPTANCE: --dry-run output shows RSS and swap for every listed process; a process with zero or absent VmSwap renders cleanly rather than erroring; a synthetic fixture with a known VmSwap value formats correctly; existing matcher tests still pass unchanged; `bash -n` clean; the header comment states the snapshot-invariant ruling.

CANONICAL SOURCE CONSTRAINT (binding): all edits target /home/benjamin/.config/nvim/agent-system/extensions/core/. Never hand-edit any deployed .claude/** tree -- it is gitignored (.gitignore line 6: `/.claude/`), disposable, and regenerated from the source store by the loader, so edits there are silently wiped. DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 157. Fix TODO.md summary lines: prefer .title, and stop the blind slice from splitting inline-code spans
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None

**Description**: The "Grouped by Topic" summary lines in TODO.md are cut with a blind character slice
that can land inside an inline-code span, leaving an unclosed backtick that corrupts markdown
highlighting for the rest of the line. Separately and more consequentially, those lines slice
.description when 23 of 29 active tasks carry a purpose-written .title the generator never
consults. Observed on screen by the operator, then confirmed against the live file; not inferred.

ROOT CAUSE, VERIFIED 2026-09-07.
scripts/generate-task-order.sh:155 populates the task_desc map that every summary emit site
reads:
    "\(.project_number)|\((.description // .project_name) | ltrimstr(" ") | .[0:65])"
`.[0:65]` is a blind character slice. Nothing balances markdown inline formatting across the cut.

EVIDENCE -- exactly one line in the current TODO.md carries an odd backtick count, and it is the
one that renders wrong:
    44 [PLANNED] -- LOWER PRIORITY (per-invocation cost, not per-session). `commands/
One backtick, never closed, so the span bleeds onward. Two neighbouring lines survive only by
luck of where character 65 happened to fall:
    139 ... Bare git history rewrites (`git commit --amend`, `git reset` with     -- 4, balanced
    129 ... Audit every `\b` word-boundary construct used in a grep pattern a     -- 2, balanced
This is therefore intermittent by position, not by content, which is why it reads as a random
highlighting glitch rather than a bug.

SECOND, COMPOUNDING SLICE SITE. scripts/generate-task-order.sh:592 applies `${desc:0:40}` to the
ALREADY-SLICED value for cross-topic "(see above)" annotations. A pair the first cut left intact
can be split by the second. Both sites need the same treatment; there is no third slice -- the
other emit sites at :593, :600 and :766 all consume task_desc unmodified, so fixing :155 fixes
them.

THE LARGER DEFECT UNDERNEATH. Line 155 reads `(.description // .project_name)` and never consults
`.title`. Coverage measured on the live state.json: 29 active non-terminal tasks, 23 with a
non-empty title. The six without are 29, 30, 45, 51, 89 and 127. What the section shows today
versus what was already available:
    44   shown: LOWER PRIORITY (per-invocation cost, not per-session). `commands/
         title: Slim commands/task.md, the largest per-invocation context contributor
    88   shown: === ADDENDUM 2026-09-02 (team mode deleted; dry-run report retire
         title: Delete the single-task engine and rewrite skill-orchestrate as the four-move loop
    137  shown: The lean extension's research and implementation agents have no a
         title: Give the lean research and implementation agents the artifact skeletons their
                general-* counterparts already have
Every truncated fragment the operator observed on screen -- "larg", "present-r", "auxili",
"have no a", and the "=== REVISED" / "=== ADDENDUM" administrative preambles for 127 and 88 --
is this same cause: the top of a long prose description shown where a written summary existed.

WORK -- three independent sub-fixes, all at scripts/generate-task-order.sh:155, plus :592.

  (a) PREFER .title. Change the source expression to `(.title // .description // .project_name)`.
      .description remains the fallback for the six title-less tasks. Note honestly that this
      CHANGES WHAT ~23 LINES SAY, not merely how they are cut -- it is a content change to the
      section, and the regenerated output must be eyeballed, not just diffed for line count.

  (b) MAKE TRUNCATION MARKDOWN-SAFE. Strip inline-code backticks before slicing rather than
      trying to balance them after. Stripping eliminates the whole class -- backticks, and also
      `*`, `_` and unclosed `[` -- where a parity check only handles the one symptom observed.
      Record the rejected alternative and why: appending a closing backtick when the count is odd
      preserves code styling but fabricates a span around a truncated fragment, rendering
      `commands/` as though it named a real path when the actual content was longer. At a 65
      character budget the styling buys nothing. If the implementer disagrees after looking at
      real output, they may choose the parity approach instead, but must say why in the summary.

  (c) CUT ON A WORD BOUNDARY AND SIGNAL TRUNCATION. Back off to the last space at or before the
      budget and append an ellipsis. Nothing currently signals that a line was cut at all, which
      is why the fragments read as corrupted text rather than as elisions.

A composed form satisfying all three (illustrative, not prescriptive -- verify against real data
before committing to it):
    "\(.project_number)|\((.title // .description // .project_name)
       | ltrimstr(" ") | gsub("`";"") | gsub("\n";" ")
       | if length > 65 then (.[0:65] | sub(" [^ ]*$";"")) + "..." else . end)"
Note it contains no `!=`, so it is clear of the jq escaping hazard documented in CLAUDE.md's
"jq Command Safety" section. Confirm that holds for whatever is finally written.

TEST COVERAGE. scripts/tests/ currently contains NO test for generate-task-order.sh or
generate-todo.sh -- verified by listing the directory. A regression this cheap to assert should
not go back in uncovered. Add scripts/tests/test-generate-task-order.sh following the conventions
of the existing tests in that directory.

CONSTRAINTS.
  - Edit agent-system/extensions/core/scripts/**, never .claude/**. The deployed
    .claude/scripts/generate-task-order.sh is regenerated and any edit there is wiped.
  - TODO.md is wholly generated from state.json by generate-todo.sh (which delegates the Task
    Order section to generate-task-order.sh --print). Do NOT hand-edit TODO.md to fix the
    rendering; that would be papered over on the next regeneration.
  - No file_scope collision was found: no other active task lists generate-task-order.sh or
    generate-todo.sh in its file_scope, checked 2026-09-07.

ACCEPTANCE.
  - Every line of the regenerated "Grouped by Topic" section has an EVEN backtick count,
    asserted mechanically over the whole section, not spot-checked. The task-44 line is the
    specific regression witness and must be shown before and after.
  - A description crafted to place a backtick exactly at the cut boundary produces a balanced
    line. This is the case the current code fails, so a test that only uses today's data proves
    nothing -- construct the adversarial input deliberately.
  - Lines for tasks WITH a title show the title; lines for the six WITHOUT one still render from
    .description and are not made worse. Both directions demonstrated.
  - No line exceeds the budget, and every truncated line ends at a word boundary with a
    truncation marker; untruncated lines carry no marker.
  - The second slice at :592 is covered by the same guarantees, demonstrated on a cross-topic
    "(see above)" line rather than assumed to follow from the :155 fix.
  - A test exists under scripts/tests/ and fails against the pre-fix script.

DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 156. Surface a Comparator doctor mode and document what a green result does and does not certify
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: Task 155

**Description**: BACKGROUND (verified 2026-09-07, shared by all Comparator tasks).
leanprover/comparator (Apache-2.0, github.com/leanprover/comparator, default branch master,
lean-toolchain leanprover/lean4:v4.34.0-rc2, last push 2026-08-30) is a trustworthy judge for
Lean proofs from untrusted sources, built by Lean FRO with AIMO feedback expressly to enable
trustworthy LLM Lean evaluation. Given a trusted Challenge.lean (statements, bodies may be
sorry), an untrusted Solution.lean, and a JSON config naming challenge_module, solution_module,
theorem_names, permitted_axioms (and optionally definition_names and external_kernels), it:
  1. builds Challenge with lake inside a landrun sandbox, then runs lean4export on the .olean
  2. repeats build-sandboxed and export-sandboxed for Solution
  3. verifies every declaration used in the STATEMENT of each named theorem is identical between
     the Challenge and Solution environments
  4. verifies the bodies of the named theorems use no axioms outside permitted_axioms
  5. replays the Solution environment into the Lean kernel (optionally also external kernels)
It deliberately never loads .olean files, on the stated grounds that they are mmapped into the
address space and dereferenced and are therefore an attack surface.

WHY THIS MATTERS TO THIS AGENT SYSTEM. lean-implementation-agent is precisely an untrusted
LLM proof producer, and its Final Verification Stage currently gates on four text heuristics,
each with a hole Comparator closes:
  - plan compliance (agents/lean-implementation-agent.md, Final Verification Stage step 5) greps
    only that a declaration NAMED X exists in Theories/. It never checks that X states what the
    plan intended. Statement weakening -- adding a hypothesis, specialising a quantifier,
    restating a weaker claim -- passes this gate silently. Comparator step 3 is exactly the
    missing check.
  - the new-axiom gate is `grep -rn "^axiom " Theories/ | wc -l`, a textual match on one source
    form. It does not see sorryAx, axioms reached transitively through imports, or the axioms
    native_decide introduces. Comparator step 4 is a transitive check against a whitelist.
  - the vacuous-definition gate is a single-line grep for `:= True|Unit|trivial|Trivial`; the
    agent file itself already records that multi-line vacuous definitions require manual review.
  - `lake build` elaborates but never replays into the kernel, and it runs agent-authored Lean
    UNSANDBOXED. Elaboration executes arbitrary code (#eval, initialize, run_cmd, macros,
    native_decide plugins). Comparator steps 1-2 sandbox both builds and step 5 replays.
So the role Comparator serves is specific and bounded: it upgrades the "did the agent cheat?"
question from grep heuristics to a kernel-backed guarantee. It is the natural terminal gate for
context/project/lean4/standards/proof-debt-policy.md's zero-debt completion requirement, which
today is enforced by exactly those greps.

FOUR CONSTRAINTS ANY INTEGRATION MUST HANDLE (all read off the tool's own README).
  C1 NO CHALLENGE EXISTS TODAY. Comparator's guarantee is relative to a Challenge you trust.
     Plans in this system name goal IDENTIFIERS, not statements (context/formats/plan-format.md
     defines only `- **Goals**: ...` under `## Goals & Non-Goals`). Something must fix the
     intended statements before the agent works.
  C2 ASSUMPTION 2 IS VIOLATED BY THE NORMAL WORKFLOW. The README requires that you have not
     previously tried to compile the Solution file, "as that might compromise your Challenge file
     to make it seem like you are looking for a different proof than you actually are". The
     implementation agent compiles continuously. The README does bless a mitigation: with a fully
     pre-built .lake obtained without compromising the checking environment, Solution.lean is not
     rebuilt.
  C3 VERSION COUPLING. lean4export must match the Lean version of the TARGET project, not
     Comparator's own v4.34.0-rc2.
  C4 COST. Two sandboxed full builds plus two exports plus a kernel replay. On a Mathlib
     dependant project this is minutes to tens of minutes. Opt-in only, scoped to named theorems.

ENVIRONMENT AS MEASURED ON THIS MACHINE 2026-09-07: lake, lean, elan present (~/.elan/bin);
landrun, lean4export, nanoda_bin, comparator ALL MISSING. landrun is in nixpkgs at 0.1.15. The
kernel is Linux 7.1.3, past the landrun issue the README's systemd-run wrapper guards against
("will be fixed in Linux 7.1") -- the wrapper is still required for portability, not for this
host.

GATE STRENGTH DECISION (already made by the operator, do not relitigate): ADVISORY FIRST. A
Comparator rejection records its finding and surfaces it prominently, but MUST NOT set
verification_passed false, MUST NOT downgrade status to partial, and MUST NOT block completion.
Promotion to a hard gate is a separate, later decision to be taken on evidence from real runs.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

WORK -- make the trust boundary legible to a human, and give the environment a doctor.

  (a) DOCTOR MODE. Add a Comparator mode to commands/lean.md alongside check/upgrade/rollback,
      routed through skills/skill-lean-version/SKILL.md (which is already the direct-execution
      home for toolchain-version concerns and already reads lean-toolchain and elan state). It
      probes for landrun, lean4export, comparator and optionally nanoda_bin; reports which are
      present and via which env var each may be overridden; and CHECKS THE C3 VERSION MATCH --
      lean4export must match the target project's lean-toolchain, not Comparator's own. A doctor
      that only reports presence and not version match will pass on a setup that cannot work.
  (b) TRUST-MODEL DOCUMENT at context/project/lean4/tools/comparator-guide.md. This is the
      important half of the task. It must state, plainly and without overclaiming, WHAT A GREEN
      COMPARATOR RESULT DOES AND DOES NOT CERTIFY:
        - it certifies the named theorems prove the Challenge's statements, use no axioms outside
          the whitelist, and are accepted by the kernel;
        - it does NOT certify that the Challenge asked the right question;
        - it does NOT certify definition-hole solutions -- the tool's own README requires an
          additional, potentially human, verifier for those, and gives the RiemannHypothesis
          gaming example;
        - its guarantee is conditional on the README's six assumptions, of which at least two are
          live concerns here: that the Solution was not previously compiled in the checking
          environment, and that landrun sandboxes correctly on the host;
        - the trusted computing base includes the OS, the hardware, and landrun's sandboxing.
      Register the file in index-entries.json with an accurate line_count and link it from
      context/project/lean4/README.md.
  (c) POLICY UPDATE. context/project/lean4/standards/proof-debt-policy.md states a zero-debt
      completion requirement enforced today by greps. Record what Comparator adds, and be
      explicit that while --compare is advisory the greps remain the operative gate. Do not write
      the policy as though the hard gate already exists.
  (d) EXTENSION SURFACE. Update EXTENSION.md, README.md, manifest.json and index-entries.json to
      reflect the new command mode, script(s) and context file. check-extension-docs.sh Rule R
      compares declared line_count against actual, so a stale declaration here will fail the
      doc-lint gate.

ACCEPTANCE.
  - The doctor reports correctly in three distinct states: all binaries present and versions
    matched; a binary missing; a binary present but lean4export mismatched against the project
    toolchain. The third state is the one that matters and must be demonstrated, not assumed.
  - comparator-guide.md contains an explicit "what this does not certify" section naming the
    definition-hole caveat and the previously-compiled-Solution assumption.
  - A fresh deploy passes check-extension-docs.sh with the new entries registered.
  - No task-number references appear in any of these deliverables (all live outside specs/).

---

### 155. Thread an advisory --compare flag through the lean implementation path
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: Task 137, Task 153, Task 154

**Description**: BACKGROUND (verified 2026-09-07, shared by all Comparator tasks).
leanprover/comparator (Apache-2.0, github.com/leanprover/comparator, default branch master,
lean-toolchain leanprover/lean4:v4.34.0-rc2, last push 2026-08-30) is a trustworthy judge for
Lean proofs from untrusted sources, built by Lean FRO with AIMO feedback expressly to enable
trustworthy LLM Lean evaluation. Given a trusted Challenge.lean (statements, bodies may be
sorry), an untrusted Solution.lean, and a JSON config naming challenge_module, solution_module,
theorem_names, permitted_axioms (and optionally definition_names and external_kernels), it:
  1. builds Challenge with lake inside a landrun sandbox, then runs lean4export on the .olean
  2. repeats build-sandboxed and export-sandboxed for Solution
  3. verifies every declaration used in the STATEMENT of each named theorem is identical between
     the Challenge and Solution environments
  4. verifies the bodies of the named theorems use no axioms outside permitted_axioms
  5. replays the Solution environment into the Lean kernel (optionally also external kernels)
It deliberately never loads .olean files, on the stated grounds that they are mmapped into the
address space and dereferenced and are therefore an attack surface.

WHY THIS MATTERS TO THIS AGENT SYSTEM. lean-implementation-agent is precisely an untrusted
LLM proof producer, and its Final Verification Stage currently gates on four text heuristics,
each with a hole Comparator closes:
  - plan compliance (agents/lean-implementation-agent.md, Final Verification Stage step 5) greps
    only that a declaration NAMED X exists in Theories/. It never checks that X states what the
    plan intended. Statement weakening -- adding a hypothesis, specialising a quantifier,
    restating a weaker claim -- passes this gate silently. Comparator step 3 is exactly the
    missing check.
  - the new-axiom gate is `grep -rn "^axiom " Theories/ | wc -l`, a textual match on one source
    form. It does not see sorryAx, axioms reached transitively through imports, or the axioms
    native_decide introduces. Comparator step 4 is a transitive check against a whitelist.
  - the vacuous-definition gate is a single-line grep for `:= True|Unit|trivial|Trivial`; the
    agent file itself already records that multi-line vacuous definitions require manual review.
  - `lake build` elaborates but never replays into the kernel, and it runs agent-authored Lean
    UNSANDBOXED. Elaboration executes arbitrary code (#eval, initialize, run_cmd, macros,
    native_decide plugins). Comparator steps 1-2 sandbox both builds and step 5 replays.
So the role Comparator serves is specific and bounded: it upgrades the "did the agent cheat?"
question from grep heuristics to a kernel-backed guarantee. It is the natural terminal gate for
context/project/lean4/standards/proof-debt-policy.md's zero-debt completion requirement, which
today is enforced by exactly those greps.

FOUR CONSTRAINTS ANY INTEGRATION MUST HANDLE (all read off the tool's own README).
  C1 NO CHALLENGE EXISTS TODAY. Comparator's guarantee is relative to a Challenge you trust.
     Plans in this system name goal IDENTIFIERS, not statements (context/formats/plan-format.md
     defines only `- **Goals**: ...` under `## Goals & Non-Goals`). Something must fix the
     intended statements before the agent works.
  C2 ASSUMPTION 2 IS VIOLATED BY THE NORMAL WORKFLOW. The README requires that you have not
     previously tried to compile the Solution file, "as that might compromise your Challenge file
     to make it seem like you are looking for a different proof than you actually are". The
     implementation agent compiles continuously. The README does bless a mitigation: with a fully
     pre-built .lake obtained without compromising the checking environment, Solution.lean is not
     rebuilt.
  C3 VERSION COUPLING. lean4export must match the Lean version of the TARGET project, not
     Comparator's own v4.34.0-rc2.
  C4 COST. Two sandboxed full builds plus two exports plus a kernel replay. On a Mathlib
     dependant project this is minutes to tens of minutes. Opt-in only, scoped to named theorems.

ENVIRONMENT AS MEASURED ON THIS MACHINE 2026-09-07: lake, lean, elan present (~/.elan/bin);
landrun, lean4export, nanoda_bin, comparator ALL MISSING. landrun is in nixpkgs at 0.1.15. The
kernel is Linux 7.1.3, past the landrun issue the README's systemd-run wrapper guards against
("will be fixed in Linux 7.1") -- the wrapper is still required for portability, not for this
host.

GATE STRENGTH DECISION (already made by the operator, do not relitigate): ADVISORY FIRST. A
Comparator rejection records its finding and surfaces it prominently, but MUST NOT set
verification_passed false, MUST NOT downgrade status to partial, and MUST NOT block completion.
Promotion to a hard gate is a separate, later decision to be taken on evidence from real runs.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

WORK -- thread `--compare` end to end, ADVISORY ONLY.

  (a) FLAG SPINE. Add COMPARE_FLAG to core/scripts/parse-command-args.sh. Model it on LIT_FLAG
      and CLEAN_FLAG (boolean mode hints), NOT on EFFORT_FLAG: --compare must compose with --hard
      rather than compete with it. The file's header comment block enumerates every exported
      variable and is load-bearing documentation -- extend it, do not just add the assignment.
  (b) SKILL THREADING. skills/skill-lean-implementation/SKILL.md and
      skills/skill-lean-implementation-hard/SKILL.md pass the flag into the delegation context
      they hand to the Agent tool. Both, not just the standard one.
  (c) AGENT GATE. In agents/lean-implementation-agent.md, add a Comparator step to the Final
      Verification Stage, and the same in agents/lean-implementation-hard-agent.md. The step
      invokes lean-comparator-run.sh against the snapshot Challenge and the implemented Solution,
      scoped to the theorem names the plan declares. It runs ONLY when --compare was passed.
  (d) METADATA. Record a `comparator` block in .return-meta.json carrying the verdict category,
      the theorem names checked, the axiom whitelist used, and the runtime. Update
      core/context/formats/return-metadata-file.md so the block is part of the documented schema
      rather than an undeclared field. The verification block's existing keys
      (verification_passed, sorry_count, vacuous_count, axiom_count, build_passed) are NOT
      touched by this task.
  (e) POSTFLIGHT SURFACE. The skill's postflight reads the comparator block and surfaces it in
      the returned summary. Per the operator's decision it MUST NOT downgrade status. Note that
      skill postflight is bound by context/standards/postflight-tool-restrictions.md -- the skill
      READS the agent's recorded result and must not re-run the check itself, exactly as it
      already reads compliance_check at Stage 6b rather than re-running the grep.

ADVISORY MEANS ADVISORY. The failure mode to design against is not a false block, it is a finding
nobody ever reads. Make a rejection loud in the returned summary and in the written summary
artifact. Record, in the implementation summary, what the promotion criteria to a hard gate would
be, so that decision later has evidence to stand on rather than being taken on vibes.

FILE COLLISION, READ BEFORE STARTING: the lean artifact-skeletons task is in [IMPLEMENTING] and
edits agents/lean-implementation-agent.md and lean-research-agent.md. This task is dependency
ordered behind it for that reason. Re-read those files at dispatch time rather than working from
the state described here.

ACCEPTANCE.
  - A lean4 dispatch WITHOUT --compare behaves exactly as today: no Comparator invocation, no new
    metadata block, no runtime cost. Demonstrated, because a mode hint that fires unconditionally
    is a regression for every existing task.
  - A dispatch WITH --compare on an honest implementation records a `verified` verdict and
    completes normally.
  - A dispatch WITH --compare on an implementation that weakened a statement records the
    rejection, surfaces it in the summary, and STILL COMPLETES -- proving the advisory contract
    holds in the direction that actually tests it.
  - --compare --hard routes to the hard agent AND runs the Comparator step, proving composition.
  - Missing binaries produce a reported comparator_unavailable, not a silent pass and not a
    block.

---

### 152. Stop hand-maintained line_count drift and unrelated red gates from blocking task completion and whole batches
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None

**Description**: An unrelated multi-task /orchestrate batch was fully blocked by three stale line_count integers. This entry addresses the CLASS of defect, not the instances (a sibling task fixes the two live remaining gate failures).

WHAT HAPPENED, verified.
index-entries.json declares a line_count per context entry, hand-maintained, and check-extension-docs.sh Rule R fails when a declaration drifts from the file's actual line count. Three entries had drifted:
  core/index-entries.json  patterns/postflight-control.md   declared 318, actual 405
  core/index-entries.json  schemas/state-schema.json        declared 267, actual 271
  literature/index-entries.json  project/literature/patterns/zotero-item-creation.md  declared 208, actual 234
In every case the FILE was unchanged (byte-identical across many commits) and only the DECLARATION was stale; the last commits touching those files belonged to unrelated earlier tasks. The failing declarations had nothing to do with the work in flight.

THE COUPLING THAT TURNED THREE INTEGERS INTO A FULL BATCH STALL.
  1. check-extension-docs.sh Rule R fails on the drift.
  2. verify-deploy.sh gate 3 (doc-lint) therefore fails.
  3. deploy-headless.sh runs verify-deploy.sh after deploying and exits non-zero on ANY gate failure.
  4. skill-orchestrate's inter-cycle redeploy checkpoint (scripts/orchestrate-cycle-plan.sh, the `if bash deploy-headless.sh; then ... else` branch) treats a non-zero deploy-headless exit as a deploy FAILURE and moves EVERY remaining task into deferred_deploy_checkpoint, stopping the batch.
Note the asymmetry that makes this worse than it needs to be: that checkpoint ALREADY has a pre-existing-baseline branch (compare pre- and post-redeploy findings; proceed when 0 are newly introduced, recording a verify_deploy_baseline_notices entry). But that branch lives INSIDE the deploy-succeeded arm, so it is unreachable whenever deploy-headless.sh itself exits non-zero -- which is exactly what a pre-existing verify failure causes. The tolerance mechanism that was built for this situation cannot fire in this situation.
Independently confirmed: the completion-deploy gate (update-task-status.sh exit 6) checks only per-task deploy FRESHNESS, not whole-repo verify health -- after a successful resync it passed and both blocked tasks completed, even with two unrelated gates still failing. So the batch-level stall was strictly harsher than the per-task gate required.

WORK -- two independent axes; both are in scope, and each should be justified separately.

(a) STOP HAND-MAINTAINING line_count. A declared integer that must be manually kept in sync with a file's length is a drift generator: it carries no information a reader needs that `wc -l` cannot produce on demand, and every edit to any indexed file is a chance to forget it. Evaluate, and pick with stated reasoning: (i) derive line_count at deploy/index-generation time instead of declaring it, (ii) keep the declaration but auto-repair it (the codebase already has a --fix idiom in validate-artifact.sh; note that the auto-repair-reporting task decided in-place repair must be REPORTED, never silent -- honor that precedent), or (iii) drop line_count entirely if nothing consumes it for more than display. DETERMINE WHAT ACTUALLY READS line_count before choosing (iii); do not assume it is unused.

(b) DECOUPLE unrelated gate health from task completion and batch progress. A pre-existing failure in a gate that has nothing to do with the changed files should not deny an unrelated task its completion transition, nor defer an entire batch. Evaluate, with reasoning: extending the checkpoint's existing pre-existing-baseline tolerance to cover a non-zero deploy-headless exit (so the baseline comparison decides, rather than being skipped); and/or having deploy-headless.sh distinguish "the deploy itself failed" from "the deploy succeeded but a pre-existing, unrelated gate is red", which are today the same exit code. A THIRD, ALREADY-OBSERVED confound belongs in this analysis: deploy-headless.sh also exits 3 merely because OTHER consumer repos are stale, a condition it explicitly refuses to act on ("this script never redeploys into a consumer") and which says nothing about this repo's deploy health.

CONSTRAINTS.
  - All edits target agent-system/extensions/**, never .claude/**.
  - Do NOT make gates non-blocking wholesale. The goal is that a failure blocks what it is actually evidence about, not everything. A genuinely broken deploy must still stop the batch.
  - scripts/orchestrate-cycle-plan.sh and update-task-status.sh are orchestrator-critical paths; expect the self-modification ordering gate to apply.

ACCEPTANCE.
  - A line_count drift can no longer occur silently, by whichever mechanism (a) selects; demonstrated by editing an indexed file and showing the gate stays green without a manual declaration edit.
  - A pre-existing, unrelated red gate no longer defers an entire /orchestrate batch; demonstrated against a deliberately-introduced pre-existing failure, showing the baseline branch fires and the batch proceeds with a recorded notice.
  - A genuinely NEW failure introduced by the batch's own changes still stops it; demonstrated, so the tolerance is proven narrow rather than assumed narrow.
  - The three confounded exit-3 causes (deploy failed / pre-existing red gate / stale consumer repos) are distinguishable by a caller.

---

### 151. Fix the two pre-existing verify-deploy gate failures (state-writer boundary, whole-tree orphan)
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None

**Description**: Two verify-deploy.sh gate failures are live in this repo today, both PRE-EXISTING and unrelated to whatever task happens to be running when they surface. They were observed blocking an unrelated multi-task /orchestrate batch: verify-deploy.sh reported "FAIL -- 3 of 29 check(s) failed", deploy-headless.sh therefore exited 3, and the orchestrator's inter-cycle redeploy checkpoint deferred EVERY task in the batch. One of the three (doc-lint, stale index-entries.json line_count declarations) was fixed at that time; these two remain.

FAILURE 1 -- STATE-WRITER BOUNDARY LINT (gate 12).
scripts/lint/lint-state-writer-boundary.sh reports "Found 4 hand-rolled state.json write(s)", all four in ONE file:
  agent-system/extensions/core/scripts/tests/test-force-phases.sh:261
    jq '.active_projects[0].status = "planned"' specs/state.json > specs/state.json.tmp && mv specs/state.json.tmp specs/state.json
  agent-system/extensions/core/scripts/tests/test-force-phases.sh:307
    jq '.active_projects[0].next_artifact_number = 2' "$WORKDIR/specs/state.json" > "$WORKDIR/specs/state.json.tmp" && mv ...
  agent-system/extensions/core/scripts/tests/test-force-phases.sh:317  (same shape as :307, .status = "planned")
  agent-system/extensions/core/scripts/tests/test-force-phases.sh:327  (same shape as :307, .status = "planned")
Last commit touching that file is an earlier, unrelated task's phase-7 work; the file appears in NO recent task's modified_files. These are test-fixture writes against a scratch $WORKDIR, not production state mutations -- which is precisely the judgment call this task must make explicitly rather than reflexively rewriting them.

DECIDE, do not assume: is the correct remedy (a) route these through state-write.sh like production callers, (b) add a scoped allowlist entry for test-fixture writes against a scratch WORKDIR (the lint already has a file-level allowlist mechanism, used by task.md, todo.md, validation.md, jq-escaping-workarounds.md, vault-operation.sh and the lint's own header), or (c) narrow the lint's own detection so a non-specs/ scratch path is not matched? Note that :261 writes the REAL specs/state.json path, while :307/:317/:327 write "$WORKDIR/specs/state.json" -- these two shapes may not deserve the same answer. State the choice and its reasoning; do not silently weaken a boundary lint that exists to protect the single-writer invariant.

FAILURE 2 -- WHOLE-TREE ORPHAN DETECTION (gate 13).
verify-deploy.sh reports "whole-tree orphan detection reported 1 finding(s)" (find_orphans: deployed-but-undeclared files, ghost index rows). The specific finding was NOT captured at observation time -- the detail run exceeds a 120s timeout because the gate suite runs the full shell test suite. RESEARCH MUST establish what the single finding actually is before planning a fix; do not assume it is the same class as FAILURE 1. Remedy pointer named by the gate output itself: context/patterns/deploy-orphan-detection.md. Re-run detail with: bash agent-system/extensions/core/scripts/verify-deploy.sh (without --quiet), allowing several minutes.

CONSTRAINTS.
  - All edits target agent-system/extensions/**, never .claude/** (deploy artifact).
  - Do not weaken a gate merely to make it pass. If a finding is a genuine false positive, fix the DETECTION and say so; if it is a real violation, fix the violation.
  - Redeploy and confirm verify-deploy.sh reports 0 failures afterwards.

ACCEPTANCE.
  - lint-state-writer-boundary.sh --verbose reports 0 violations, with the chosen remedy and its reasoning recorded in the summary.
  - Whole-tree orphan detection reports 0 findings, with the finding's actual identity documented (not merely made to disappear).
  - bash verify-deploy.sh completes with all gates passing.
  - A regression note explains why each fix will not silently re-break.

RELATED, not a dependency: the sibling task on line_count/gate-coupling brittleness addresses the CLASS of problem (why an unrelated pre-existing lint failure can gate every task's completion). This task fixes the two live instances; that one changes the coupling. Either can land first.

---

### 150. Research on demand: planner-first lifecycle with research only when the planner asks or --research forces it
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 88

**Description**: Research on demand: let the planner decide whether a research phase is needed, and run one only when it asks for it or when --research forces it. Decided 2026-09-02 (specs/PATH.md, Decisions). Stage A.8 of specs/PATH.md. SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**).

WHY. Every task runs research -> plan -> implement today, yet most filings in this system are already specifications: they carry the defect, the measured evidence, the work list and the acceptance bar. A research dispatch on such a task re-derives what the description states and costs a full agent run plus a cycle. The decision whether research is needed belongs to an agent, not to the orchestrator and not to a keyword heuristic.

DESIGN (binding; the planner of this task refines mechanics, not the shape).
(a) Default lifecycle becomes plan -> implement. A task at [NOT STARTED] with no report is dispatched to the PLANNER first. The planner's contract gains an opening step: assess whether the description plus what it can read in the codebase suffices to write a plan that meets plan-format.md. If yes, plan as today; status advances to [PLANNED] (the [RESEARCHED] state is simply not visited). If no, it writes no plan and returns verdict `needs_research` in its return metadata with a focused list of the questions research must answer; it does not attempt partial planning.
(b) orchestrate-cycle-plan.sh / orchestrate-triage-classify.sh: a `needs_research` verdict recorded by the postflight script routes the task to the research phase on the next cycle, with the planner's questions carried into the dispatch file as the research focus; after research, the task returns to plan as today. `--research` (the phase-forcing flag) forces the research phase first exactly as it does now and bypasses the planner's assessment. A task that already has a report is never asked again.
(c) orchestrate-cycle-postflight.sh: relay `needs_research` as a verdict (no status regression; the task stays [NOT STARTED] or [RESEARCHING]-equivalent by the existing vocabulary -- decide and record which); record nothing as a defect.
(d) Contracts and docs: planner-agent.md (and extension planner agents, swept with negatives) gain the assessment step and the bar for asking -- research is requested only when the plan would otherwise rest on guesses about facts an agent can establish (external APIs, unfamiliar code paths, literature), never as a default; the research-agent contract is unchanged except that the dispatch file may now carry the planner's question list; status-markers.md and the state-machine doc describe the two-phase default with research on demand; the return-metadata format gains the verdict field.
(e) Memory retrieval and --lit still run at every dispatch through the dispatch builder, so a planner dispatched first receives the same context a research dispatch would.

MUST NOT: skip research when `--research` is passed; let the orchestrator decide (the classifier only routes on the recorded verdict); weaken plan-format.md's requirements to make planning-without-research easier.

ACCEPTANCE: a specification-shaped task goes [NOT STARTED] -> [PLANNED] -> [COMPLETED] in two dispatches with a plan that passes validate-artifact.sh; a task whose planner returns `needs_research` is shown routing to research with the question list in its dispatch file and then back to plan; `--research` on a fresh task runs research first; fixture tests for both routes; full gate run green.

DELIVERABLE RULE: no task-number references in deliverables outside specs/**.
REFERENCE: specs/PATH.md, "Decisions".

---

### 142. Orchestrator context budget: measure and lock
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 88

**Description**: === REVISED 2026-09-02 (thin-lead path: narrowed to measure-and-lock; absorbs the context-budget gate) ===
SUPERSEDING SCOPE. The sweep described below is now the Stage A chain in specs/PATH.md (slim command, dispatch builder, cycle-plan, cycle-postflight, feature port, engine deletion). This task is the measurement and the lock, and it absorbs the warning-first context-budget gate from the abandoned verify-deploy context-gates task (its broken-@-ref half already holds and needs no work).

BASELINE (measured 2026-09-02; record in this task's report before anything else): skills/skill-orchestrate/SKILL.md 293,977 B; commands/orchestrate.md 46,874 B; eager session load 63,973 B / ~16k tokens (measure-eager-context.sh); eager load before the first /orchestrate dispatch ~405 KB / ~100k tokens; lead-authored prompt text per 5-task cycle 25-60 KB (task descriptions average 4,612 B, max 11,598 B, interpolated inline).

WORK.
(1) Re-measure the four figures after each Stage A task lands; final before/after table in the summary.
(2) Extend verify-deploy.sh with a warning-first context-budget gate: the eager-load ceiling from measure-eager-context.sh (fail above the recorded baseline, print the number on every run so drift direction is visible), plus per-file ceilings for skills/skill-orchestrate/SKILL.md (20,000 B) and commands/orchestrate.md (8,000 B) read from a small config file in the source store. Warn tier first; promote to hard failure once the warning has been stable across a stated number of deploys. Volatile files in the eager set remain an unconditional failure.
(3) A per-cycle growth probe: a test or a documented procedure that measures the lead's context growth on a 3-task batch (bytes of cycle-plan JSON + pointer prompts + postflight JSON) and records it, so the "~1 KB per task per cycle" target is a number, not a claim.
(4) Correct the Context Flatness prose wherever it survives (state-machine doc) to state the measured figure.

MUST NOT DAMAGE (unchanged from the original): the four admission gates and their defer-not-fail semantics; the handoff staleness and dispatch_seq identity gates; per-task scoped commits; the inter-cycle redeploy checkpoint; task-lock acquire/heartbeat/release.

ACCEPTANCE: the before/after table; both gates wired, exercised on a fixture that exceeds each ceiling, and green on the real tree; Gate 19 green; full gate run green.

REFERENCE: specs/PATH.md, "Budgets".
=== ORIGINAL DESCRIPTION FOLLOWS ===Reduce the orchestrator's own token consumption so that multi-task /orchestrate runs can proceed much further before exhausting context. Review-and-optimize task: identify every optimization available WITHOUT damaging functionality, quantify each, and land the safe ones.

PROBLEM. The orchestrator lead is the context bottleneck in multi-task runs. Its eager load is dominated by two runtime-loaded .md files read IN FULL on every invocation: commands/orchestrate.md and skills/skill-orchestrate/SKILL.md (the latter alone is ~190k characters as deployed). The lead then accumulates further context per cycle from admission verdicts, classifier NDJSON, handoff/return-meta reads, and its own warning text. Observed in practice: a 5-task batch consumed a large fraction of available context before the second dispatch completed.

RELATIONSHIP TO EXISTING WORK (do not duplicate). Task 87 landed the mode-gated section loading convention plus a lint (verify-deploy Gate 19) for exactly this defect class. Task 88 already owns the single largest instance -- extracting skill-orchestrate/SKILL.md's `## Multi-Task Mode` section (103,462 B, 55% of the file). This task is the BROADER sweep that those two do not cover; it must build on the convention rather than re-deciding it, and must not re-do task 88's extraction.

SCOPE TO INVESTIGATE.
1. Remaining mutually-exclusive branch sections in skill-orchestrate/SKILL.md beyond the multi-task one: the Stage 3.6/3.6a team fan-out (fires only under --team), Stage 5a vs Stage 5b (mutually exclusive on hard_mode by construction), and any hard-mode-gated regions that survive the hard-mode deletion work.
2. Procedural bash currently inline in SKILL.md. The convention notes that moving procedural bash to scripts/ removes it from context ENTIRELY, whereas moving prose to context/ saves only on invocations that do not need it -- so bash extraction is the strictly stronger lever and should be enumerated first.
3. commands/orchestrate.md itself, which carries large bash blocks its own text explicitly labels illustrative-not-executed (the runtime wave-split check, the consolidated-output template). These cost tokens on every invocation and execute never.
4. Per-cycle growth: measure actual per-cycle context cost against the ~450 tokens/cycle the Context Flatness Constraint claims, and identify what exceeds it (verdict JSON, classifier output, repeated warning prose, re-read state).
5. Further delegation of lead work to scripts that return compact decision JSON -- the pattern orchestrate-stage5-gates.sh and orchestrate-stage5-postflight.sh already establish. Enumerate what remains inline in the lead that could follow the same shape.

METHOD. Establish a measured baseline first (scripts/measure-eager-context.sh exists), quantify each candidate in bytes/tokens, and rank by saving-per-unit-risk. Report measured numbers, not estimates.

MUST NOT DAMAGE. These are load-bearing safety mechanisms and must survive unchanged in behavior: the four admission gates and their defer-not-fail semantics; the handoff staleness and dispatch_seq identity gates; per-task scoped commits (never a batch commit); the inter-cycle redeploy checkpoint; task-lock acquire/heartbeat/release. An optimization that weakens any of these is out of scope regardless of its saving.

ACCEPTANCE. Measured before/after numbers for the orchestrator's eager load, the safe optimizations landed, Gate 19 green, and full gate run green.

---

### 140. Add a concurrency-gated history-rewrite predicate to guard-destructive-git.sh
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 139

**Description**: Give agent-system/extensions/core/hooks/guard-destructive-git.sh a SECOND, INDEPENDENT predicate that blocks or loudly warns on history rewrites (`git commit --amend`, `git reset` without `--hard`) when evidence of a concurrent writer exists. This is the enforcement half of the policy its predecessor task establishes in the rules and agent contracts.

WHY A SECOND PREDICATE AND NOT AN EXTENSION OF THE FIRST. The hook's entire existing design is built around ONE hazard: discarding UNCOMMITTED working-tree changes. Its header states the premise directly -- "block destructive git commands when the working tree is dirty" (lines 3-5) -- and its first live check is the clean-tree exemption, "working tree is already clean (git status --porcelain is empty)" / "Clean tree -> nothing to lose" (lines 19-23, check at lines 61-64). The hazard this task addresses is a different class: rewriting ALREADY-COMMITTED history owned by a concurrent writer. Both commands involved are non-destructive to the working tree, so the clean-tree exemption would have ACTIVELY WAVED THEM THROUGH. Merely adding `--amend` to the existing dirty-tree predicate would still not fire. The new predicate must therefore not consult tree dirtiness at all. Verified: the file matches `amend` 0 times and `mixed` 0 times today.

MOTIVATING INCIDENT (real, observed 2026-09-02, multi-task /orchestrate run, five concurrent implementation agents committing to master). An agent ran bare `git commit --amend` intending its own commit; a sibling agent's commit had landed on top in the interim, so the amend rewrote the sibling's commit, preserving its file content but overwriting its message. A follow-up `git reset --mixed <own-sha>` rewound HEAD past three further legitimate commits and intermingled their changes in the working tree. Recovered via reflog: trees identical, zero content lost, residual damage exactly one mislabeled commit message. Reconstructible evidence: 539561c39 (correct), 9c5b790b6 (orphaned original), fd50fabfd (tree-identical to 9c5b790b6, wrong message).

THE DESIGN TENSION TO RESOLVE, NOT PAPER OVER. The hook observes only the literal top-level tool_input.command string. It cannot see intent. An over-broad rule blocks legitimate solo interactive `--amend`, which is explicitly permitted. Research must select and justify a concurrency signal, weighing false-positive and false-negative cost. Candidate signals, none pre-committed:
  - a live entry in specs/.task-locks/ held by a session other than the caller's;
  - an in-flight session-registry entry belonging to a different session;
  - HEAD having moved since the calling agent's own last commit (directly diagnostic of the incident, but requires per-session commit-sha state the hook does not currently keep).
Also decide the response: hard refusal (exit 2 + stderr, matching the existing block mechanism -- note the header's warning that `permissionDecision: deny` is documented-buggy for allow-listed Bash(git:*) commands, GH #4669/#13214/#18312) versus a loud non-blocking warning. These may differ per signal strength.

DESIGN CONSTRAINTS.
  - The new predicate must be structurally independent of the clean-tree exemption; that exemption currently returns exit 0 before any detector runs, so predicate ordering is load-bearing.
  - `git-commit-scoped.sh` must remain unblocked. Note the existing header's observation-boundary argument (lines 41-47): a git command run as a subprocess inside a wrapper script never appears in tool_input.command, so wrapper-internal git is structurally invisible to this hook. Follow that established pattern rather than special-casing.
  - Reuse the file's existing argv-anchoring scan-string machinery (COMMAND_SCAN, quoted-span and comment stripping, lines 67+) so a commit message containing the text "--amend" cannot trigger a false positive.
  - The refusal message must point at the rule section its predecessor task adds, so a blocked agent can read the rationale.

WORK.
(a) Implement the concurrency-gated history-rewrite predicate in hooks/guard-destructive-git.sh.
(b) Update the hook's header comment block, which currently documents a single-hazard design and would otherwise misdescribe the file.
(c) Update context/standards/git-safety.md for the new hazard class and the chosen signal.
(d) Update rules/git-workflow.md's enumeration of what the hook enforces (its "enforced by" framing) so rules and implementation stay in agreement.
(e) Verify with concrete cases: a bare `--amend` under a foreign task lock is refused; the same command with no concurrent writer is permitted; a git-commit-scoped.sh invocation is permitted; a commit message containing the literal string "--amend" does not trigger.

NON-GOALS (explicit).
  - Do NOT forbid `--amend` unconditionally for single-session interactive use.
  - Do NOT attempt retroactive repair of the mislabeled commit fd50fabfd.

ACCEPTANCE. A bare `git commit --amend` or `git reset` issued by a dispatched agent while another session holds a task lock is refused or loudly warned; the rationale is reachable from the message; compliant git-commit-scoped.sh use remains unblocked; solo use is unaffected.

SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/. Never edit .claude/ directly. Redeploy and confirm the hook survives regeneration and actually fires from the deployed copy.

DEPENDENCY RATIONALE. Depends on its predecessor task on two grounds: that task settles the policy this one mechanizes and supplies the rationale text this hook's refusal message points at; and both tasks touch rules/git-workflow.md, so the file-footprint admission gate serializes them regardless.

---

### 139. Forbid concurrent-writer history rewrites in git rules and agent contracts
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 146

**Description**: Bare git history rewrites (`git commit --amend`, `git reset` without `--hard`) are forbidden nowhere in the agent system, and the one place that looks like a prohibition is scoped so that it structurally cannot fire on the hazard that actually occurred. Add the prohibition to the rules and to the agent contracts, and correct the existing mis-scoped bullet rather than merely adding alongside it.

MOTIVATING INCIDENT (real, observed 2026-09-02 during a multi-task /orchestrate run with five concurrent implementation agents committing to master). An agent ran bare `git commit --amend` to add an attribution trailer to what it believed was its own commit. Between its commit and the amend, a DIFFERENT agent's commit landed on top, so the amend rewrote the sibling's commit instead -- preserving that sibling's file content but overwriting its message. The agent then ran `git reset --mixed <own-sha>` to undo, which rewound HEAD past three further legitimate commits and dumped their changes into the working tree intermingled. It caught this and restored HEAD via reflog. Verified afterward: trees identical, zero content lost; residual damage is exactly one mislabeled commit message still in history. Reconstructible reflog evidence: commits 539561c39 (correct), 9c5b790b6 (orphaned original), fd50fabfd (tree-identical to 9c5b790b6, wrong message).

WHY THIS IS A NEW PREDICATE, NOT A WIDENED OLD ONE -- the load-bearing finding. ALL THREE layers of the existing mechanism share one identical blind spot: each is scoped by dirtiness-of-tree, and the incident's hazard is concurrency-of-writers. Both commands involved are non-destructive to the working tree, so every existing guard would have actively waved them through.

  1. HOOK. agent-system/extensions/core/hooks/guard-destructive-git.sh states its own premise in its header: "PreToolUse Bash hook: block destructive git commands when the working tree is dirty" (lines 3-5), with the exemption "working tree is already clean (git status --porcelain is empty)" -- annotated in the file as "Clean tree -> nothing to lose" (lines 19-23, and the live check at lines 61-64). Verified: the file matches `amend` 0 times and `mixed` 0 times. It blocks only `reset --hard`, `checkout -- <path>`, `restore <path>`, `clean -f -d`, `stash drop`/`clear`, and forced `checkout`/`switch`.
  2. RULES. agent-system/extensions/core/rules/git-workflow.md's "Never Run" list (line 77) covers `push --force`, `reset --hard` on uncommitted work, `rebase -i`, `add -A`, `commit -am` -- but NOT `commit --amend` and NOT non-hard `reset`. Its sibling section at line 89 is titled "No Destructive Git on Uncommitted Work"; that title and framing structurally exclude already-committed history.
  3. AGENT CONTRACTS. agent-system/extensions/core/agents/general-implementation-agent.md carries no prohibition at all. Its `-hard` sibling (general-implementation-hard-agent.md, ~line 63, Recovery Ladder) says "Never `git reset`/`git checkout -- <path>`/`git restore` WHILE UNCOMMITTED CHANGES EXIST" -- the prohibition is itself gated on the dirty-tree predicate, so it too would have permitted this. This phrasing must be CORRECTED, not merely supplemented.

Verified across agent-system/extensions/core/{rules,context,agents}/: `--amend` has ZERO occurrences. It is forbidden nowhere.

WORK (contract and documentation layer only; the hook predicate is a separate task).
(a) rules/git-workflow.md: add `git commit --amend` and non-hard `git reset` to the "Never Run" list.
(b) rules/git-workflow.md: add a SIBLING section to "No Destructive Git on Uncommitted Work" covering rewrites of already-committed history under concurrent writers. Place it so a reader arriving at the uncommitted-work rule finds it -- the current title is precisely what makes this case invisible. Include the incident rationale and the concurrency-vs-dirtiness distinction.
(c) agents/general-implementation-agent.md: add a MUST NOT bullet against bare history rewrites, directing all commits through scripts/git-commit-scoped.sh, which serializes on the commit mutex and path-scopes staging. Empirical support: in the motivating run, four of five agents used git-commit-scoped.sh exclusively and had zero incidents; the one that did not caused the entire incident.
(d) agents/general-implementation-hard-agent.md: correct the Recovery Ladder bullet's "while uncommitted changes exist" scoping so the prohibition also covers committed-history rewrites under concurrent writers.

NON-GOALS (explicit).
  - Do NOT forbid `--amend` unconditionally for single-session interactive use. The discriminating variable is a concurrent writer, not the command itself.
  - Do NOT attempt retroactive repair of the mislabeled commit fd50fabfd. That is a separate operator decision to be made when the branch is quiet.

ACCEPTANCE.
  - `git commit --amend` and non-hard `git reset` appear in the "Never Run" list with the concurrency qualifier.
  - The rationale is documented where a reader looking at the uncommitted-work rule will find it.
  - general-implementation-agent.md carries an explicit git-commit-scoped.sh mandate.
  - general-implementation-hard-agent.md no longer scopes its git prohibition solely by tree dirtiness.
  - Compliant git-commit-scoped.sh use remains unrestricted.

SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/. Never edit .claude/ directly (it is a regenerated deploy artifact). Redeploy and confirm the change survives regeneration.

RELATED, NOT DUPLICATE. Task 72 covers teammate .return-meta.json ownership and marker correlation -- a different concern entirely.

---

### 137. Give the lean research and implementation agents the artifact skeletons their general-* counterparts already have
- **Status**: [IMPLEMENTING]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None
- **Research**: [137_lean_agent_artifact_skeletons/reports/01_lean-agent-artifact-skeletons.md]
- **Plan**: [137_lean_agent_artifact_skeletons/plans/01_lean-agent-artifact-skeletons.md]
- **Summary**: [137_lean_agent_artifact_skeletons/summaries/01_lean-agent-artifact-skeletons-summary.md]

**Description**: The lean extension's research and implementation agents have no artifact skeletons, so the artifacts they author fail validate-artifact.sh on required sections that their general-* counterparts get right by construction. Observed on a real completed task, not inferred.

OBSERVED FAILURES (BimodalLogic task 507, gate-out validation output, 2026-09-01):
  summaries/01_frame-level-validity-indexing-summary.md -> [FAIL] 6 error(s)
      Missing required section: ## Overview, ## What Changed, ## Decisions, ## Impacts, ## Follow-ups, ## References
      (4 metadata fields -- Started, Completed, Artifacts, Standards -- were auto-repaired to "TBD" placeholders)
  reports/01_frameclass-indexed-validity.md -> [FAIL] 13 error(s), 1 warning
      [WARN] Cannot auto-fix: no existing metadata lines found to anchor insertion
The report case is the worse of the two: with zero conforming metadata lines present, validate-artifact.sh's --fix path has no anchor to insert against and gives up entirely. The artifact is left non-conforming with no repair path.

ROOT CAUSE -- MISSING TEMPLATES, NOT MISBEHAVING AGENTS.
extensions/core/agents/general-implementation-agent.md carries a full inline summary skeleton (around :468-482): the metadata block, the bracketed Status vocabulary spelled out ("Use `**Status**: [COMPLETED]` when every plan phase is done, `**Status**: [IN PROGRESS]` on a partial run, `**Status**: [BLOCKED]` when blocked, matching summary-format.md's declared vocabulary"), and the required sections. An agent handed that template produces a conforming artifact without needing to consult the format spec.
The lean agents carry no such thing:
  extensions/lean/agents/lean-implementation-agent.md  -- grep for summary-format / ## What Changed / ## Decisions / ## Impacts / ## Follow-ups / ## References returns ZERO hits (its own `## Overview` at :9 is the agent file's own document heading, not a template)
  extensions/lean/agents/lean-research-agent.md        -- grep for report-format / ## Findings / ## Executive Summary / `**Task**:` returns ZERO hits
The agents are behaving reasonably given what they were handed. The defect is the missing contract.

AUTHORITATIVE REQUIREMENTS (from extensions/core/scripts/validate-artifact.sh, lines 19-44 -- transcribe from the script, do not retype from this description):
  REPORT_METADATA   = Task, Started, Completed, Effort, Dependencies, Sources/Inputs, Artifacts, Standards
  REPORT_SECTIONS   = Executive Summary, Context & Scope, Findings, Decisions, Recommendations
  SUMMARY_METADATA  = Task, Status, Started, Completed, Artifacts, Standards
  SUMMARY_SECTIONS  = Overview, What Changed, Decisions, Impacts, Follow-ups, References
  SUMMARY_SECTIONS_OPTIONAL = Plan Deviations
  Note the script's own comment: SUMMARY_SECTIONS is a required MINIMUM, not an exhaustive whitelist.
The prose specs are extensions/core/context/formats/summary-format.md (its Example Skeleton section) and the report-format equivalent.

WORK.
(a) Add an inline summary skeleton to extensions/lean/agents/lean-implementation-agent.md, modelled on general-implementation-agent.md's, including the explicit bracketed-Status vocabulary sentence -- that sentence is why the general agent's summaries carry a well-formed Status line, and its absence is directly implicated in the sibling defect this task's peer covers.
(b) Add an inline report skeleton to extensions/lean/agents/lean-research-agent.md covering REPORT_METADATA and REPORT_SECTIONS.
(c) SWEEP the other extensions' agents for the same gap rather than assuming lean is the only one. Known candidates to CHECK (not assume defective): extensions/lean/agents/lean-implementation-hard-agent.md, lean-research-hard-agent.md, and the formal extension's research agents. Report what was checked and what was found, including negatives.
(d) Where a skeleton already exists but is incomplete, prefer amending it over replacing it.

EXPLICIT NON-GOAL. Do not weaken validate-artifact.sh's required-section lists to make existing non-conforming artifacts pass. The artifacts are wrong, not the validator. Task 136 is separately TIGHTENING that validator; a loosening here would fight it directly.

ACCEPTANCE.
  - A lean-language task run end to end produces a summary and a report that both pass validate-artifact.sh with zero errors and zero auto-repairs -- demonstrated on a real dispatch, not on a hand-written fixture.
  - The sweep in (c) is reported with explicit negatives ("checked X, already conforming") so a later reader knows the search happened.
  - Redeploy and confirm the fix survives regeneration (.claude/ is a deploy artifact; the edit target is agent-system/extensions/lean/).

RELATED, NOT DUPLICATE. Task 13 (instrument_gate_out_auto_repair_reporting) covers REPORTING of auto-repair counts through command-gate-out.sh and skill-base.sh, and flags the silent-in-place-mutation hazard. It does not add any missing agent template. This task removes the need for those repairs at the source; 13 makes the repairs visible when they still happen. Both are worth having.

PROVENANCE. Surfaced 2026-09-01 by gate-out validation during an /orchestrate 507 run in the BimodalLogic repo. The validation warnings are non-blocking, which is why this had gone unnoticed: the task completed successfully with two non-conforming artifacts on disk.

---

### 136. Stop implementation agents hand-writing the plan-level Status field, and make the validator catch it
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 91, Task 146

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

---

### 129. Empirically audit \b word-boundary grep patterns for compositional failure under the deployed grep
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 88, Task 128

**Description**: Audit every `\b` word-boundary construct used in a grep pattern across the source store, empirically, against the grep actually deployed, and record portable-construct guidance so the class does not recur. Surfaced by the adversarial-verification gate failure (evt_1788245094839_eybEyC); that gate is fixed separately and is NOT in this task's scope.

THE DEFECT IS COMPOSITIONAL, NOT A MISSING FEATURE. State this precisely; the imprecise version of this finding is what would sink the audit itself. The deployed grep is ugrep 7.8.4 (built with PCRE2 available: `-P:pcre2jit`). Its POSIX/DFA `-E` engine does NOT simply ignore `\b`. Every fragment of the failing pattern matches in isolation against the literal header line `| Claim | Source / counterexample | Verification method | Confidence |`:

  PATTERN                                                          RESULT
  \bclaim\b                                                        MATCH
  claim                                                            MATCH
  \|[^|]*\bclaim\b[^|]*\|                                          MATCH
  [^|]*\bclaim\b                                                   MATCH
  \bclaim\b[^|]*                                                   MATCH
  \bsource\b[^|]*\bcounterexample\b                                MATCH
  \|[^|]*\bclaim\b[^|]*\|[^|]*\bsource\b                           MATCH

The full composed pattern nevertheless fails, and bisection localizes it:

  \|[^|]*\bclaim\b[^|]*\|[^|]*\bsource\b[^|]*\bcounterexample\b[^|]*\|   NOMATCH   (production form)
  \|[^|]*\bclaim\b[^|]*\|[^|]*\bsource\b[^|]*\bcounterexample\b          NOMATCH
  \|[^|]*\bclaim\b[^|]*\|[^|]*\bsource\b[^|]*counterexample              MATCH     (dropped \b around counterexample)
  \|[^|]*\bclaim\b[^|]*\|[^|]*source[^|]*\bcounterexample\b              NOMATCH   (dropped \b around source)
  \|[^|]*claim[^|]*\|[^|]*\bsource\b[^|]*\bcounterexample\b              NOMATCH   (dropped \b around claim)

and the unmodified production pattern under `-P` (PCRE2) returns MATCH.

So the engine mis-evaluates a `\b` that appears DOWNSTREAM of an earlier `\b`-anchored subexpression separated by a `[^|]*` run. Whether a given `\b` works depends on what else is in the pattern.

BINDING CONSTRAINT ON HOW THIS AUDIT IS PERFORMED. Because the failure is compositional, spot-testing a fragment in isolation does NOT prove the production pattern works in situ. Every site must be executed as its full, unmodified production pattern against a real positive input under the deployed grep, and the observed result recorded. Reasoning about whether a construct "should" work, testing a simplified stand-in, or generalizing from one site's result to another's are all forbidden -- they are precisely the trap this defect sets.

FOR THE SAME REASON, THIS IS NOT A MECHANICAL FIND-AND-REPLACE. A blanket `\b` removal would be wrong: `\b` carries real semantics, and several high-stakes sites were spot-verified as CURRENTLY WORKING under the deployed grep -- guard-destructive-git.sh's `--hard\b` and `(drop|clear)\b` both match (that guard is live, not silently dead), the sorry census's `\bsorry\b` matches, and literature-audit.sh's `\b(Definition|Lemma|Theorem|Proposition|Corollary|Remark|Example)\s+[0-9]+(\.[0-9]+)*\b` matches. Rewriting working patterns risks introducing false positives in a destructive-git guard, which is a worse outcome than the defect being audited.

SCOPE. Roughly 26 grep-adjacent `\b` sites across the source store, spanning literature scripts, lean scripts, core scripts, lint scripts, test harnesses, and hooks. For each: run the production pattern against a real positive input under the deployed grep; classify as WORKING or BROKEN on the evidence; repair only the broken ones, choosing per-site between dropping `\b` where surrounding delimiters already provide the boundary and switching that invocation to `-P`; and leave working sites alone with a one-line note recording that they were tested rather than assumed.

DELIVERABLE BEYOND THE REPAIRS. A short portability guidance note under the core standards context directory covering: that the deployed grep may be ugrep rather than GNU grep; that `\b` under `-E` is compositionally unreliable there while `-P` is reliable; that delimiter-anchored alternatives are preferred where the surrounding pattern already bounds the token; and that any new `\b` pattern must be executed against a real input before being committed. Without this note the class recurs the next time someone writes a plausible-looking boundary pattern.

SEQUENCING. Depends on the adversarial-gate fix purely to avoid a file-footprint collision: skill-orchestrate/SKILL.md is itself one of the sites, and that task owns the gate's pattern. This task covers every other site and must not touch the gate.

ACCEPTANCE: every site is accompanied by a recorded empirical result under the deployed grep; no working pattern is rewritten; each repaired pattern is demonstrated to match a real positive input AND to reject a real negative input; and the guidance note exists.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

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

### 88. Delete the single-task engine and rewrite skill-orchestrate as the four-move loop
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 148

**Description**: === ADDENDUM 2026-09-02 (team mode deleted; dry-run report retired) ===
Team rows no longer exist (team mode is deleted by an earlier Stage A task); item (6)'s `--team` notice removal is already done by that deletion. The loop's dry-run path is `orchestrate-cycle-plan.sh --dry-run` (the standalone report is retired by the cycle-plan task). Research on demand (a later task) changes only the phase the planner is dispatched in; this rewrite must not hardcode research-first anywhere -- the loop dispatches whatever phase the cycle plan names.
=== REVISED 2026-09-02 (thin-lead path: engine deletion replaces mode-gating) ===
SUPERSEDING SCOPE. The premise below -- that single-task /orchestrate is the hot path and should stop loading the multi-task section -- is the inverse of how the system is used: the default is many tasks at once, and "batch of one" is the decided design (specs/PATH.md). Mode-gating would keep both engines on disk and the parity-drift defect class alive. This task instead deletes the single-task engine and rewrites the skill as the four-move loop. Stage A.6 of specs/PATH.md. The file has grown to 293,977 B since the figures below were taken.

WORK.
(1) Delete single-task Stages 1-8 (~183,000 B) outright; the feature-port predecessor has already made them unreachable.
(2) Rewrite skills/skill-orchestrate/SKILL.md as the loop: call orchestrate-cycle-plan.sh -> issue every dispatch row as a pointer-prompt Agent call in ONE message (team rows via orchestrate-team-fanout.sh) -> call orchestrate-cycle-postflight.sh per returned task -> branch: continue; on any `ask_user` verdict, AskUserQuestion once per question, batched at the end of the cycle after every other task's postflight has run, writing answers to specs/{NNN}_{slug}/.decisions.json for the next dispatch file; on `stop`, print the consolidated output and exit. Nothing else. The orchestrator never asks except to relay an agent-surfaced decision, and never reads a description, report, plan, summary, handoff prose, or context file during the loop.
(3) Move narration, incident history, and exception taxonomies to docs/architecture/orchestrate-state-machine.md and handoff-schema.md. The `## MUST NOT` sections become a list of at most ~1,500 B.
(4) Target: SKILL.md <= 20,000 B. Its Context References cite only the three cycle scripts, the fan-out script, and the state-machine doc.
(5) Update context/reference/orchestrator-critical-paths.json labels, docs/architecture/orchestrate-state-machine.md, and every test that greps SKILL.md structure (enumerate by grep for skill-orchestrate/SKILL.md under scripts/tests and scripts/lint).
(6) Retire the accepted-and-ignored notices for `--team` and phase-forcing flags in multi-task mode; both are per-row now.

MUST NOT: change any decision the scripts make; reintroduce any inline jq beyond the loop; keep a second engine.

ACCEPTANCE: measured SKILL.md bytes before/after; a live 5-task batch completes end to end with the lead's per-cycle context growth measured (cycle-plan JSON + pointer prompts + postflight JSON; target on the order of 1 KB per task per cycle); a single-task-number invocation completes through the same path; an agent-surfaced user_decision is shown reaching AskUserQuestion and its answer reaching the next dispatch file; all orchestrate tests green; full gate run green.

DELIVERABLE RULE: no task-number references in deliverables outside specs/**.
REFERENCE: specs/PATH.md, "Target design: the thin lead".
=== ORIGINAL DESCRIPTION FOLLOWS ===Apply the mode-gated section convention to the largest single instance in the system. skill-orchestrate/SKILL.md is 188,284 B; its `## Multi-Task Mode` section measures 103,462 B -- 55% of the file -- and is entered ONLY when multi_task_mode=true. Stage 0 states it explicitly: 'If multi_task_mode is true: skip Stages 1-8 entirely and proceed to Stage MT-1.' Every single-task /orchestrate N therefore loads ~26k tokens of text it will never execute, on the command intended for the longest, most context-hungry runs.

Section breakdown of the file: ## Multi-Task Mode 103,462 (only ~11% bash) | ## Execution Flow 71,570 | ## MUST NOT (Context Flatness) 8,932 | remainder ~2,500.

ESTIMATED SAVING: ~26,000 tokens per single-task /orchestrate invocation, taking its budget from ~83.5k toward ~57k. This is the single largest measured token item in the system and it is a pure move -- the section is self-contained and the branch is already explicit, so no prose rewriting is required.

Secondary, separable lever recorded here so it is not lost: this file carries 5 bash blocks of >=20 lines totalling 39,275 B, and skill-orchestrate-hard carries 9 such blocks totalling 63,892 B. Bash moved into a standalone script costs ZERO context because the script source is never loaded. That is a bigger per-token win than prose extraction and is already the established pattern here (~20 orchestrate-*.sh scripts exist). Do it in a follow-up rather than widening this work.

BEWARE the fence-interior heading trap: naive '^## ' section splitting can match headings inside fenced code blocks and silently truncate. The slim-task-command plan documents this exact hazard and mandates bottom-up extraction so earlier line numbers do not drift. Reuse that approach.

ACCEPTANCE: single-task /orchestrate no longer loads the multi-task section; multi-task /orchestrate still works end to end; measured budget reduction reported against the 83.5k baseline.

---

### 76. Close task-type-keyed hook gap for non-latex agents that compile .tex
- **Effort**: 3 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: Task 74, Task 146

**Description**: Close the coverage gap that the latex-extension wiring cannot reach: agents that compile .tex files under a task type OTHER than `latex` currently get no build-guard protection at all, because the extension hook mechanism is keyed on task_type.

DEPENDS ON the core guard script task. This task is NOT redundant with the latex-extension wiring task -- it covers a disjoint set of dispatches, and skipping it would leave the exact incident that prompted this work uncovered.

THE GAP, VERIFIED PRECISELY. `skill_run_extension_hook()` in `agent-system/extensions/core/scripts/skill-base.sh` resolves which extension's hooks to run by calling `skill_get_extension_dir "$task_type"`, which maps a task type to `.claude/extensions/<ext_name>`. It then reads `.hooks[<stage>]` from THAT extension's manifest. Consequence: a preflight hook declared in the latex manifest fires if and only if `task_type == "latex"`. It never fires for any other task type. Additionally, when no extension matches the task type, `skill_get_extension_dir` returns empty and the function returns 0 immediately -- so core-typed tasks (`general`, `meta`, `markdown`) run NO lifecycle hooks whatsoever, from any extension.

WHY THIS MATTERS CONCRETELY. `agent-system/extensions/formal/manifest.json` routes ALL of `formal`, `formal:logic`, `formal:math`, and `formal:physics` implement operations to `skill-implementer` / `general-implementation-agent`. Philosophy and logic paper repositories are precisely where .tex files live, and `formal`-typed paper tasks are a normal, expected shape. The formal manifest declares NO top-level `hooks` object at all (verified: `.hooks` is null, `provides.scripts` is an empty array). So a `formal`-typed task that builds a .tex file receives zero protection from a latex-extension-only fix. The user flagged this explicitly: a latex-extension-only fix would not have covered the live incident that prompted this work. The same reasoning applies to `general`-typed tasks that happen to touch LaTeX.

DECISION TO MAKE -- WHERE THE UNCONDITIONAL PATH LIVES. Two structurally different options; choose one and record why:

  (i) AGENT-CONTRACT MANDATE. Add the guard obligation to `agent-system/extensions/core/agents/general-implementation-agent.md` and its twin `general-implementation-hard-agent.md`: before running any `pdflatex`/`latexmk` invocation, run the shared guard. Cheap, no harness change, and it composes with the "detect and refuse" mechanism (a contract can refuse; a non-blocking hook cannot). Weakness: it is instruction text an agent may skip, and it must be duplicated across the two twins.

  (ii) CORE-LEVEL UNCONDITIONAL CHECK. Add a task-type-independent guard invocation into `skill-base.sh` itself, running regardless of extension. Strongest coverage, and it survives agents ignoring instructions. Weaknesses: it touches the shared lifecycle spine that every skill in every repository depends on; it would run for every task type including ones that never touch LaTeX (mitigated if the guard is cheap and silent when no .tex conflict exists -- an explicit acceptance requirement of the core guard task); and, because hook/preflight failures are deliberately non-blocking, it still cannot ENFORCE a refusal on its own.

  A defensible outcome is BOTH: (ii) for detection and reporting, (i) for the refusal obligation. The user's framing invites exactly this ("the latex extension, a shared preflight hook, or both"). Do not silently pick the cheaper option without recording the tradeoff.

  A third possibility worth evaluating and rejecting explicitly: giving the formal extension its own preflight hook that delegates to the shared guard. This closes the `formal` case specifically but leaves `general`/`meta`/`markdown` uncovered and does not generalize -- it invites one hook per extension forever.

TWIN-FILE DISCIPLINE (binding). If option (i) is chosen, `general-implementation-agent.md` and `general-implementation-hard-agent.md` MUST be edited together in this task. A one-sided edit between engine twins is a known recurring defect class in this system. Do not assume the two files are line-symmetric; locate each site by content.

BLAST-RADIUS WARNING. If option (ii) is chosen, `skill-base.sh` is the shared lifecycle spine sourced by essentially every skill and deployed to roughly ten repositories. Changes there must be additive, must not alter existing hook ordering or the existing non-blocking semantics, and must be exercised against `agent-system/extensions/core/scripts/tests/test-skill-base-lifecycle.sh`, which already covers the hook-invocation contract.

FILE-SCOPE NOTE. This task's scope includes `agent-system/extensions/core/scripts/skill-base.sh`, which falls under the `agent-system/extensions/core/scripts/**` scope of the prerequisite core-guard task. That overlap is already serialized by the declared dependency, so no additional ordering constraint is needed -- but the two tasks must not be run concurrently.

SOURCE-STORE RULE (binding): all edits target `agent-system/extensions/core/**` (and `agent-system/extensions/formal/**` only if the rejected third option is nonetheless adopted). Never edit a deployed `.claude/**` tree.
DELIVERABLE RULE (binding): no task-number references in any file outside specs/.

ACCEPTANCE: a task-type-independent path exists by which an agent about to compile a .tex file consults the shared guard, demonstrably covering `formal`-typed and `general`-typed tasks; the (i)/(ii)/both decision is recorded with reasons, and the rejected per-extension-hook option is explicitly rejected in writing; if agent contracts were edited, both twins carry equivalent obligations; if `skill-base.sh` was edited, the change is additive, preserves existing hook ordering and non-blocking semantics, and the lifecycle test suite passes; no `.claude/**` file is modified.

---

### 75. Wire build guard into latex extension preflight hook and agent contracts
- **Effort**: 2 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: Task 74

**Description**: Wire the shared LaTeX build guard into the latex extension's lifecycle and contracts, so that `latex`-typed research and implementation dispatches detect (and, per the chosen mechanism, stop) a competing vimtex continuous build before the agent runs its own.

DEPENDS ON the core guard script task: this task consumes the script and its chosen mechanism, and must not re-litigate the mechanism decision.

HOOK MECHANISM (verified). `skill_run_extension_hook()` in `agent-system/extensions/core/scripts/skill-base.sh` (lines ~89-126) dispatches four lifecycle stages -- preflight, context_injection, verification, postflight -- to a script named in the extension's manifest under a TOP-LEVEL `hooks` object. This is distinct from `provides.hooks`, which is a file-copy target list; do not confuse the two. The preflight hook is invoked from `skill_preflight_update()` (line ~225) AFTER the status update. Hooks are non-blocking by design: a non-zero exit is caught and downgraded to a `[skill-base] WARNING` line, and execution continues. THIS IS A REAL CONSTRAINT ON THIS TASK -- if the chosen mechanism is "detect and refuse", a preflight hook CANNOT enforce the refusal on its own, because the harness ignores its exit code. In that case the refusal must additionally be carried in the agent contract text (the agent declines to build), with the hook serving as the detector and reporter. Resolve this explicitly rather than assuming a non-zero exit will stop anything.

REFERENCE IMPLEMENTATION. `agent-system/extensions/nix/scripts/nix-preflight.sh` is the only existing preflight hook in the source store and shows the exact contract: five positional args (`task_number`, `task_type`, `task_dir`, `session_id`, `operation`), `set -euo pipefail`, warnings to stderr, and `exit 0` even when warnings fired. The nix manifest declares it as `"hooks": {"preflight": "scripts/nix-preflight.sh", "context_injection": "scripts/nix-context.sh"}`. Only two extensions (nix, nvim) declare top-level hooks today, so this is a lightly-trodden path -- read both before writing.

DELIVERABLES.
  1. A new `agent-system/extensions/latex/scripts/` directory (it does NOT exist yet -- latex's `provides.scripts` is currently an empty array) containing a preflight hook that calls the shared core guard. The hook should be a thin adapter, not a reimplementation.
  2. `agent-system/extensions/latex/manifest.json`: add the top-level `hooks` object (preflight, and postflight if the restore/report decision requires it), and add the new script(s) to `provides.scripts`. Note the manifest currently has `"hooks": []` nested inside `provides` -- the new object is a SIBLING of `provides`, not a replacement for that field.
  3. `agent-system/extensions/latex/agents/latex-implementation-agent.md`: the build guidance is concentrated at lines ~38-62 ("Build Tools (via Bash)", listing `pdflatex`, `latexmk -pdf`, `latexmk -c`, with worked multi-pass examples) and recurs at lines ~97, ~134, and ~175 as bare build instructions. Line numbers verified at task-creation time and may drift; locate by content. Add the guard obligation, and add a MUST NOT item against running a build without first invoking the guard -- MUST NOT is the strongest lever these contracts have, and advisory prose buried mid-file is what gets skipped.
  4. `agent-system/extensions/latex/rules/latex.md`: the build-command block at lines ~74-93 presents `pdflatex`/`latexmk -pdf` with no concurrency caveat. Point it at the guard.
  5. `agent-system/extensions/latex/context/project/latex/tools/compilation-guide.md`: add a build-coordination section. This file already has "Automated Build", "Using latexmk", and ".latexmkrc Configuration" sections (lines ~46-60) that discuss latexmk without mentioning the watcher conflict, so it is the natural anchor. Per this extension's convention, put the explanatory prose HERE ONCE and have the agent/rules files reference it by path rather than restating it.

NO -HARD TWIN. Unlike the lean extension, latex declares no `routing_hard`/`routing_agents_hard` block and has no `-hard` agent variants, so there is no twin-file discipline burden here. `latex-research-agent.md` is a lighter touch -- research dispatches rarely build, but should not be silently exempt if the hook is manifest-level (the hook fires for ALL latex-typed operations, research included, since `operation` is only passed as an argument, not filtered on). Decide whether the hook self-filters on the `operation` argument.

SCOPE BOUNDARY. This task covers `latex`-TYPED tasks only. Coverage for agents that build .tex files under other task types is a separate task and must not be absorbed here.

SOURCE-STORE RULE (binding): all edits target `agent-system/extensions/latex/**`. Never edit a deployed `.claude/**` tree.
DELIVERABLE RULE (binding): no task-number references in any file outside specs/.

ACCEPTANCE: a latex preflight hook exists, is executable, is declared in the manifest's top-level `hooks` object, and is listed in `provides.scripts`; it delegates to the shared core guard rather than duplicating detection logic; the agent, rules, and compilation-guide files carry the obligation with prose stated once in compilation-guide.md and referenced elsewhere; the non-blocking-hook constraint is explicitly resolved (either the mechanism does not need enforcement, or the enforcement is carried in contract text); the operation-filtering decision is recorded; no `.claude/**` file is modified.

---

### 74. Add shared LaTeX build-conflict guard script (detect competing vimtex latexmk -pvc)
- **Effort**: 3 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: Task 130, Task 148

**Description**: Build a shared, task-type-agnostic guard script that detects a user-owned LaTeX continuous-build watcher (`latexmk -pvc`, typically driven by nvim's vimtex plugin) competing for the same .tex target an agent is about to build, and that can report, stop, and restore it. This task delivers the MECHANISM only; wiring it into lifecycle stages is handled by the two dependent tasks.

PROBLEM (observed live, not hypothetical). An agent ran `latexmk -pdf possible_worlds.tex` in a paper repo while the user's nvim vimtex continuous-mode compile was watching the same file. The two builds raced and corrupted aux files (null bytes, `^^@`). The failure mode is already documented in that repo's own CLAUDE.md under "Build Workflow: Preventing Aux File Corruption" -- but that documentation instructs a HUMAN to run `:VimtexStop` by hand. Nothing in the agent system detects, prevents, or even warns about it, so the user must notice and intervene manually every time an agent begins LaTeX work.

WHY THE EXISTING DEBOUNCE DOES NOT COVER THIS. The paper repo carries a `.latexmkrc` with `$sleep_time = 5` and a `$compiling_cmd` that pre-scans `build/*.aux` for null bytes and unlinks corrupted files. NOTE TWO CORRECTIONS TO THE ORIGINATING PROMPT, both verified at task-creation time: the file is at `JPL/.latexmkrc`, NOT the repo root; and the value is `$sleep_time = 5`, NOT the `2` that repo's CLAUDE.md claims (that CLAUDE.md is stale on this point -- do not propagate the wrong number). More importantly, `$sleep_time` debounces the file watcher WITHIN a single latexmk instance. It provides no coordination whatsoever between two SEPARATE latexmk processes, which is precisely the race here. The `$compiling_cmd` null-byte sweep is a post-hoc corruption cleanup, not prevention. Neither existing mechanism can solve this; a new one is required.

MECHANISM DECISION -- THIS IS THE CORE RESEARCH QUESTION. An agent cannot invoke a Vim command directly, so the shutdown path is non-obvious. Three candidates, to be evaluated and one (or a documented layering) chosen:

  (a) PROCESS TERMINATION. Detect a running `latexmk -pvc` whose target resolves to the .tex file about to be built, and SIGTERM it. Most reliable, most destructive -- it kills a process the user owns, and vimtex's own state will not know its child died, potentially leaving the plugin's status display stale or its callback machinery confused.

  (b) EDITOR REMOTE CONTROL. Use `nvim --server <socket> --remote-expr` (or `--remote-send`) against the live nvim instance to invoke VimtexStop. VERIFIED FEASIBLE IN THIS ENVIRONMENT: four live sockets were present at task-creation time under `/run/user/1000/` in the form `nvim.<PID>.0` (XDG_RUNTIME_DIR). This is the only option that leaves vimtex's internal state consistent, because vimtex itself performs the stop. Costs: it requires mapping socket -> the nvim instance that actually owns the target buffer (a socket exists per nvim instance, and most of them will be unrelated); `--remote-expr` executes arbitrary expressions in the user's editor, which is a real side effect deserving explicit justification; and it depends on vimtex being loaded in that instance.

  (c) DETECT AND REFUSE. Detect the conflict and emit a clear, actionable message -- naming the PID, the target file, and the exact `:VimtexStop` remedy -- then either warn-and-continue or refuse to build. Zero side effects on user-owned processes and zero remote editor control. The user's explicit steer is to PREFER THE LEAST DESTRUCTIVE OPTION THAT RELIABLY PREVENTS THE RACE, and to weigh killing a user process or driving their editor remotely against simply refusing with a clear message. Research should take that steer seriously rather than defaulting to (a) because it is easiest to implement. A defensible outcome is (b) with (c) as fallback when no owning socket can be identified, or (c) alone.

RESTORE-VS-REPORT DECISION. Also decide whether the agent restores continuous mode on exit or merely reports that it stopped it. The user's stated position: an agent that silently leaves the user's watch mode off is its own (smaller) annoyance. At minimum, whatever is stopped must be REPORTED. Restoration is materially easier under mechanism (b) (re-invoke VimtexCompile over the same socket) than under (a) (the script would have to reconstruct and relaunch a latexmk invocation it did not create -- generally a bad idea). Note that this decision is coupled to the mechanism decision and should not be made independently of it.

REUSABLE PATTERN -- `agent-system/extensions/core/scripts/claude-refresh.sh`. That script already solves the hard parts of safe process handling and should be read before writing anything new. It takes a single atomic `ps -eo` snapshot per invocation rather than re-querying live; it applies exclusion regexes so the script can never target itself or its own ancestry; it gates destructive action behind an explicit `--force` (the calling skill handles confirmation separately); and it escalates SIGTERM (`kill -15`) -> liveness recheck (`kill -0`) -> SIGKILL (`kill -9`) rather than killing outright.

SELF-MATCH HAZARD (verified concretely, do not skip). During task creation, a plain `pgrep -af latexmk` returned exactly one "match" -- the task-creating agent's OWN bash wrapper command, whose argv merely CONTAINED the string `latexmk`. A naive detector would therefore report a phantom conflict, and under mechanism (a) would attempt to kill the agent's own shell. Detection must match on the actual executable and its `-pvc` flag, resolve the build target, and exclude self/ancestry, exactly as claude-refresh.sh does. This is not a theoretical edge case; it fired on the first probe.

DELIVERABLE. A new executable script under `agent-system/extensions/core/scripts/` (suggested name `latex-build-guard.sh`; final name to be fixed during planning). Placement in CORE, not in the latex extension, is DELIBERATE and load-bearing: the two dependent tasks show that non-latex-typed tasks also run LaTeX builds, so the mechanism cannot live behind the latex extension's task-type gate. Suggested subcommand shape (refine during planning): a `detect` mode that reports conflicts and exits non-zero, a `stop` mode implementing the chosen mechanism, and a `restore`/`report` mode for the exit path. Modes should be separable so callers can adopt detect-only first.

The script must be registered in `agent-system/extensions/core/manifest.json` under `provides.scripts` alongside the ~124 existing entries so it is deployed.

SOURCE-STORE RULE (binding): all edits target `agent-system/extensions/core/**`. Never edit a deployed `.claude/**` tree -- those are disposable artifacts regenerated on reload, so such an edit silently vanishes.
DELIVERABLE RULE (binding): no task-number references in any file outside specs/.

ACCEPTANCE: the script exists, is executable, and is registered in core's `provides.scripts`; the chosen mechanism is implemented and the rejected candidates are recorded WITH REASONS in the task's artifacts; detection correctly distinguishes a real `latexmk -pvc` on the target .tex from a process whose argv merely contains the string, and never matches itself or its own ancestry; the restore-vs-report decision is recorded and implemented; whatever the script stops is always reported to the user; the script is safe and silent (exit 0, no output) when no conflict exists, since it will run on every applicable build.

---

### 51. Move session state files out of specs root
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 143

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

---

### 45. Global update extension repo registry
- **Status**: [NOT STARTED]
- **Task Type**: general
- **Topic**: neovim
- **Dependencies**: None

**Description**: TOPIC CORRECTION + BACKFILL NOTE (task-116 audit). This task carried topic core-agent-system, but its real scope (the <leader>al extension picker's 'Global Update' action) is nvim-config Lua UI code at lua/neotex/plugins/ai/claude/commands/picker/** and lua/neotex/plugins/ai/shared/extensions/**, NOT agent-system/extensions/** -- it is unrelated to the orchestrate-engine collapse. Re-topiced to neovim; file_scope backfilled from description evidence (was previously empty). Original description follows.\n\nImplement <leader>al repo registration and 'Global Update' action: when <leader>al loads extensions into other repos, register those repos and their loaded extensions in this nvim repo; add a 'Global Update' entry (similar to 'Reload All') that reloads all extensions already loaded in each registered repo, reporting any failures in a message and otherwise success as a count of the total

---

### 44. Slim commands/task.md, the largest per-invocation context contributor
- **Effort**: 2-4 hours
- **Status**: [PLANNED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 87, Task 149
- **Research**: [044_slim_task_command_body/reports/01_command-body-extraction-approach.md]
- **Plan**: [044_slim_task_command_body/plans/01_task-command-mode-extraction.md]

**Description**: LOWER PRIORITY (per-invocation cost, not per-session). `commands/task.md` measures 37,465 bytes (~9.4k tokens) loaded on every `/task` invocation, plus ~2.8k tokens of imports it pulls in — the largest single per-invocation context contributor found by the context-loading audit. Slim the command body by moving reference material (long option tables, worked examples, edge-case narratives) into lazily-loaded context files under the core extension's context tree, keeping the command body to the decision logic and dispatch instructions an invocation actually needs. Preserve behavior: every mode (--recover, --expand, --sync, --abandon, multi-task creation) must remain fully specified — either inline or via an explicit pointer the executing agent is instructed to follow. Measure before/after bytes and record them in the implementation summary. CONSTRAINTS: all edits target agent-system/extensions/core/** (source store), never the deployed .claude/** tree; no task-number references in deliverables outside specs/**; do not change command behavior, only where its prose lives.

---

### 43. Decide and implement how email safety context actually reaches agents (live defect: five inert safety pointers)
- **Effort**: 1-3 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: None

**Description**: TOPIC CORRECTION (backlog streamline 2026-09-01): re-topiced core-agent-system -> extensions. This is email-extension-internal context-loading work, classified extension-internal by the consolidation audit, and is unrelated to the orchestrate-engine collapse. Original description follows.LIVE DEFECT, not an efficiency item: the email extension's five 'non-negotiable' safety context pointers (safety-invariants.md, wrapper-contracts.md, index-architecture.md, staleness-detection.md, archive-mode-risk.md) were written as `@.claude/context/...` imports in the merge-source era — a form that resolves to a nonexistent path and silently loads NOTHING. They have since been normalized to plain backticked paths (still non-loading by design), so the question the audit deferred is now unavoidable: how does safety-invariants.md actually reach an agent before it mutates a mailbox? Decide deliberately between: (a) making the safety pointers genuinely eager in the email extension's CLAUDE.md contribution, accepting roughly 13k tokens of every-session cost in deploys where email is loaded; (b) establishing that the wrapper contracts (five nix-built wrapper binaries as the only mutation path) plus the email skills'/agent's own explicit context-loading instructions already carry the enforcement, and recording that as the documented decision; or (c) a middle path such as eager-loading ONLY safety-invariants.md (the smallest, most critical file) while the rest stay lazy. Verify empirically what skill-email-cleanup, skill-email-sync, and email-implementation-agent load today before choosing. Whatever the choice, record it in the email extension's docs so the next audit does not re-litigate. CONSTRAINTS: all edits target agent-system/extensions/** (source store); no volatile files in any eager prefix; no task-number references in deliverables outside specs/**.

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

### 30. Register obsidian memory mcp server
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: Task 29

**Description**: TOPIC CORRECTION (backlog streamline 2026-09-01): re-topiced core-agent-system -> extensions, alongside its prerequisite (the .mcp.json generation mechanism). Unrelated to the orchestrate-engine collapse. Original description follows.Register the obsidian-memory MCP server through the new manifest-driven .mcp.json mechanism, and grant its tools at the matching scope.

CURRENT STATE: memory/settings-fragment.json carries a dead `mcpServers` block declaring obsidian-memory (npx -y @anthropic-ai/obsidian-claude-code-mcp@latest, with env OBSIDIAN_WS_PORT). It registers nothing, because settings files are not a registration surface. The memory extension IS loaded in this repository, so unlike the five retired servers this one is wanted and should be made to work.

WORK: move the declaration to the new merge target so it lands in .mcp.json, with an explicit "type": "stdio". Then determine the server's ACTUAL tool names and add matching permission grants to the fragment, applying the grant-at-registration-scope rule. Do NOT guess the tool names and do NOT copy them from any existing documentation: enumerate them empirically by starting the server and issuing a tools/list request. This system has already shipped documentation instructing agents to call MCP tools that never existed, and a naming mismatch between a declared server name and its granted mcp__<name>__* prefix has already been found in another extension -- verify both the server name and every tool name against the running server.

RUNTIME PREREQUISITE, DO NOT PAPER OVER: this server needs OBSIDIAN_WS_PORT set and a running Obsidian instance with the companion plugin. If that prerequisite cannot be satisfied in this environment, wire the declaration correctly, document the prerequisite plainly in the memory extension README, and report the tool-name enumeration as NOT VERIFIED rather than inventing plausible names. A truthful 'could not verify' is the correct outcome here; a fabricated tool list is not.

VERIFICATION: .mcp.json contains the entry after a fixture deploy; `jq empty` on both edited files; doc-lint passes for the memory extension; every granted mcp__ tool name either matches a name observed from the running server or is explicitly marked unverified with the reason. SOURCE-STORE RULE (binding): all edits target /home/benjamin/.config/nvim/agent-system/extensions/**. Never hand-edit any deployed .claude/** tree -- it is gitignored, disposable, and regenerated from the source store. DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 29. Generate mcp json from extension manifests
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: None

**Description**: TOPIC CORRECTION (backlog streamline 2026-09-01): re-topiced core-agent-system -> extensions. This is deploy-engine (lua merge-path) and manifest-surface work for extension MCP registration, unrelated to the orchestrate-engine collapse; the consolidation audit confirmed no overlap with the routing ladder it carries forward. Original description follows.Build the deploy-engine mechanism that lets an extension declare an MCP server and have it actually registered, by generating a project-scoped .mcp.json.

WHY THIS IS NEEDED: extensions currently express server declarations as `mcpServers` keys inside settings-fragment.json, which register nothing -- settings files are not a registration surface. Project-scoped .mcp.json IS a real registration surface, and it IS reachable by dispatched subagents (verified by direct experiment; the earlier belief to the contrary rested on a session-start snapshot confound). So the fix is to route declarations to a surface that works, not to abandon the idea of extensions declaring servers.

WORK: add a new manifest merge target -- e.g. `merge_targets.mcp` with a source file per extension -- that the deploy engine collects across all LOADED extensions and writes to the repository-root .mcp.json. Mirror the existing settings merge path (process_merge_targets / merge_settings in merge.lua) rather than inventing a second idiom: the existing path is an additive, idempotent deep-merge that does not clobber pre-existing content, and it deliberately targets a file that is NOT install-once, which is exactly the property needed here. Extend manifest_spec.lua so the new key validates.

REQUIREMENTS THE MECHANISM MUST SATISFY: (a) each generated server entry carries an explicit "type" field -- as of Claude Code v2.1.202 a remote server lacking an explicit type fails fast rather than failing silently, and all current declarations omit it; (b) unloading an extension must REMOVE its servers from .mcp.json, because an additive deep-merge alone never retracts, and a stale grant surviving an unload is an already-observed defect class in this system; (c) the operation must be idempotent -- deploying twice yields a byte-identical .mcp.json; (d) hand-written entries a user added to .mcp.json themselves must survive regeneration, or the file must clearly declare itself generated. Decide (d) explicitly and record the choice.

IMPORTANT CONTEXT: a project-scoped .mcp.json server requires workspace-trust approval before `claude mcp list` will read it (v2.1.196+), and a server added to .mcp.json is invisible to any ALREADY-RUNNING session. Both facts must be documented for users, or the mechanism will be reported as broken when it is working correctly. Verify against a fresh session or `claude -p`, never against the current one.

VERIFICATION: build a scratchpad fixture project, load an extension declaring a trivial stdio server, and confirm .mcp.json is generated correctly; confirm a second deploy is a no-op; confirm unloading removes the entry; confirm `claude mcp get <name>` in the fixture reports Scope: Project config. Do NOT deploy against this repository as part of verification. SOURCE-STORE RULE (binding): all edits target /home/benjamin/.config/nvim/agent-system/extensions/**. Never hand-edit any deployed .claude/** tree -- it is gitignored, disposable, and regenerated from the source store. DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 22. Freeze .opencode: silence fragment validation spam and record the frozen-mirror policy
- **Status**: [RESEARCHING]
- **Task Type**: meta
- **Topic**: opencode
- **Dependencies**: None

**Description**: === REVISED 2026-09-01 (backlog streamline: .opencode declared FROZEN) ===
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

---

### 14. Prevent implementation-agent fan-out from returning non-terminal status and stale plan markers
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 88, Task 139

**Description**: === REVISED 2026-08-24 (refactor survey) ===
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
