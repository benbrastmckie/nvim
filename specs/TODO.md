---
next_project_number: 784
---

# TODO

## Task Order

*Updated 2026-06-30. Generated from state.json dependency graph.*

**Dependency Waves**:
| Wave | Tasks | Blocked by | Topics |
|------|-------|------------|--------|
| 1 | 78,87,772,775,777,778,780,782,783 | -- | agent-system, literature, Terminal UI, ... |
| 2 | 773,774,776,779,781 | 772,775,778,780 | agent-system, literature |

**Grouped by Topic** (indented = depends on parent):

### Agent System

772 [NOT STARTED] — [--hard IMPLEMENTATION leg: focus each agent round on an INDIVIDU
  └─ 773 [NOT STARTED] — The anti-analysis contract (H2, .claude/context/contracts/anti-an
777 [NOT STARTED] — [--hard RESEARCH leg: more effort, higher standards for quality, 
778 [NOT STARTED] — [--hard CORE EFFECT: relax the zero-debt policy to permit STRATEG
  └─ 774 [NOT STARTED] — [--hard PLANNING leg: make phases SMALLER and divide work into a 
  └─ 779 [NOT STARTED] — [--hard recovery discipline] Define an unambiguous recovery contr
780 [NOT STARTED] — [Working-tree preservation] Prevent agents from destroying uncomm
  └─ 779 [NOT STARTED] — [--hard recovery discipline] Define an unambiguous recovery contr (see above)
  └─ 781 [NOT STARTED] — [Context-overflow safety] Dispatched agents must detect context p
782 [NOT STARTED] — [Formal-domain context hygiene] Reduce the context that lean4/for
783 [NOT STARTED] — Fix the sorry-census methodology in the review/vet agent tooling 

### Literature

775 [NOT STARTED] — [--lit, NO SILENT FALLBACK] When --lit is used but no per-repo sp
  └─ 776 [NOT STARTED] — Two coupled fixes so --lit works outside the formal /research N -

### Terminal UI

87 [RESEARCHED] — Investigate why the terminal working directory changes to a proje

### Email Integration

78 [PLANNED] — Fix Gmail SMTP authentication failure when sending emails via Him

## Tasks

### 783. Fix sorry-census to exclude comment/docstring lines (count only live proof debt)
- **Effort**: 1-2 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None

**Description**: Fix the sorry-census methodology in the review/vet agent tooling so it stops counting Lean comment/docstring lines as proof debt. Root cause surfaced by cslib task 431 (origin repo: ~/Projects/cslib): the health-review census is a raw grep for 'sorry' over Cslib/**.lean, which swept up 7 docstring/comment occurrences (e.g. 'sorry-free', 'removing the sorry') plus a commented-out TODO stub, producing false 'unowned foundational sorry' findings. Moving to word-boundary 'sorry' did not help -- it still matches inside docstrings. Fix: make the census count only live proof debt -- strip Lean line comments (--) and block comments (/- -/) before matching, and/or cross-check against the compiler 'declaration uses sorry' warnings or #print axioms sorryAx. Update whichever shared agent-system tooling performs the census (the /review and/or /vet skills/scripts under .claude/). Evidence: cslib specs/431_audit_unowned_foundational_sorries/reports/01_unowned-sorries-audit.md, specs/reviews/review-2026-06-30.md, review-2026-06-30-2.md. Moved here from cslib (was task 437) because it is an agent-system change.

---

### 782. Formal-domain context hygiene: minimize goal-state context for lean4 agents
- **Effort**: 2-4 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None

**Description**: [Formal-domain context hygiene] Reduce the context that lean4/formal-proof agents consume per step so enormous goal states do not overflow the window. MOTIVATING FAILURE: five dispatches on Lean tableau proofs overflowed because goal states are enormous and were repeatedly pulled into context. Scope (lean4 / formal domains -- applies to lean-*/cslib-* and formal hard agents and their context/contracts): (1) Goal-state query discipline: prefer TARGETED lean-lsp queries (lean_goal at a specific position, lean_minimal_hypotheses, lean_term_goal) over dumping full goal states; do NOT paste entire goal states into reasoning repeatedly; summarize the goal in a few lines and re-query precisely when needed. (2) File-read discipline: avoid re-reading whole large proof files; read only the region around the active proof; use lean_file_outline / targeted offset reads. (3) Hypothesis pruning: work from minimal hypotheses; avoid carrying large unused contexts forward. (4) Encode these as a formal-domain CONTEXT CONTRACT (an extension context file analogous to the lean4 override of anti-analysis.md) consumed by the lean/formal research + implementation hard agents. (5) Combine with checkpoint-before-overflow (task 781): hygiene lowers the baseline context; checkpointing handles the residual. SCOPE NOTE: this is domain-specific. If the lean/cslib extension lives in a separate repo, author the contract here and FLAG it for sync to that extension (do not assume the shared repo is the only consumer). Pairs with task 781. Goal: a single large goal state is handled by targeted querying and summarization rather than overflowing the agent's context.

---

### 781. Agent context-overflow safety: checkpoint + handoff before the hard limit
- **Effort**: 3-6 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 780

**Description**: [Context-overflow safety] Dispatched agents must detect context pressure and CHECKPOINT before hitting the hard context limit, instead of crashing mid-work. MOTIVATING FAILURE: five agent dispatches on Lean tableau proofs (enormous goal states) hit 'Prompt is too long'; on overflow an agent crashes WITHOUT writing a handoff, leaving a stale handoff and a RED working tree -- which then triggers the revert/work-loss failure (the next agent sees RED and reverts). Scope (general -- all dispatched implementation/research agents): (1) Wire the existing context-exhaustion-detection.md into the dispatched implementation and research agents (general-implementation-hard-agent, general-research-hard-agent, and base variants), not just the orchestrator -- they must monitor context-pressure signals (large tool outputs, repeated reads, growing goal states, high tool-call count) and treat approaching the limit as a STOP condition. (2) Define the CHECKPOINT-BEFORE-OVERFLOW procedure: at the pressure threshold, STOP taking new work -> commit the current green state (or snapshot via task 780 if RED) -> write a complete H9 handoff (.orchestrator-handoff.json + continuation markdown) naming the exact next action -> terminate cleanly. Never crash mid-edit; never leave a stale handoff. (3) Ensure the handoff captures enough for a FRESH agent to resume with minimal context (the continuation-handoff markdown already specifies this), so work is divided across agents by CONTEXT BUDGET, not lost. (4) Coordinate with the small-phase/skeleton work (774/778): if a phase's single goal state is too large to fit, the agent lands a strategic-sorry skeleton (778) and hands off rather than overflowing. Pairs with task 780 (snapshot) and task 779 (resume must fix-forward, not revert). Goal: context overflow degrades gracefully to a clean handoff + recoverable checkpoint, never a crash that loses uncommitted progress. Depends on task 780 (snapshot mechanism for the RED-checkpoint path).

---

### 780. Agent git-safety: preserve uncommitted work, guard destructive git ops
- **Effort**: 3-6 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None

**Description**: [Working-tree preservation] Prevent agents from destroying uncommitted progress via destructive git operations, and require a recoverable snapshot before any rollback. MOTIVATING FAILURE: an implementation agent ran a revert-to-last-green-commit that discarded uncommitted forward progress (FreshAbove scaffolding + an 8->4 sorry reduction); the work existed only in the working tree and was lost. Two layers: (1) RULE (behavioral): extend .claude/rules/git-workflow.md with a 'no destructive git on uncommitted work' rule -- agents MUST NOT run git operations that discard working-tree changes (git reset --hard, git checkout -- <path>, git checkout/switch that would overwrite changes, git restore <path>, git clean -fd, git stash drop/clear) while uncommitted changes exist, UNLESS a snapshot was just taken. Before any intentional rollback the agent MUST snapshot recoverably: a WIP commit on a scratch/throwaway branch, OR a .patch artifact under specs/{NNN}_{SLUG}/ (e.g. working-progress-{ts}.patch), OR at minimum git stash (without drop). (2) HOOK (enforced): add a PreToolUse hook (registered via settings.json / the hooks system, e.g. .claude/scripts/guard-destructive-git.sh) that intercepts Bash tool calls, detects the destructive git patterns above, and BLOCKS them (deny / non-zero) with corrective context UNLESS (a) the working tree is clean, or (b) a snapshot marker shows a snapshot was just created. The hook returns guidance pointing to the snapshot-first procedure. Model it after the existing PostToolUse validators (e.g. validate-meta-write.sh) and the hooks registration pattern in .claude/. (3) Provide a tiny helper the agent calls to snapshot (write the .patch + record the marker the hook checks). Scope: applies to ALL agents (not just hard-mode) -- accidental destruction is universal -- but keep it lightweight so legitimate clean-tree operations (e.g. checkout on a clean tree) are not blocked. Pairs with task 779 (snapshot-before-rollback is rung c of the recovery ladder). Goal: a misread or mistaken instruction can never irreversibly destroy uncommitted agent work.

---

### 779. Hard-mode: fix-forward recovery contract (disambiguate 'restore green')
- **Effort**: 2-4 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 778, Task 780

**Description**: [--hard recovery discipline] Define an unambiguous recovery contract so 'reach green' / 'restore green' / 'get back to green' ALWAYS means FIX FORWARD (make the current working tree green by adding/correcting code) and NEVER means revert/reset/checkout to a prior green commit. MOTIVATING FAILURE: an orchestrator instruction 'if RED, first restore green' was misread by an implementation agent as 'revert to last green commit', discarding uncommitted forward progress (new FreshAbove scaffolding AND an 8->4 sorry reduction); the working tree was reset to the committed baseline and the progress was lost. Scope of changes: (1) Create/extend a recovery contract (e.g. .claude/context/contracts/recovery.md, or a section in wrap-up.md) stating: 'green' is reached by FIXING FORWARD only; an agent MUST NOT discard uncommitted work to reach green. (2) Define the canonical RECOVERY LADDER for a RED state: (a) fix forward; (b) if a sub-goal is genuinely blocked, land a documented STRATEGIC-SORRY skeleton (task 778) so the build goes green WITHOUT losing structure; (c) only if a rollback is truly required, SNAPSHOT first (task 780) then roll back, preferring the smallest revert scope. (3) Bake this into the hard-mode implementation contract (anti-analysis / wrap-up, consumed by general-implementation-hard-agent and skill-implementer-hard) and into skill-orchestrate-hard's dispatch prompt construction, so the orchestrator emits the disambiguated phrasing BY DEFAULT and does not rely on ad-hoc wording. (4) Align error-handling.md Build Error Recovery ('Keep source unchanged' / 'Never lose completed work') with the fix-forward language so guidance is consistent across docs. Scope: hard-mode primarily, but the fix-forward phrasing must be safe for standard mode too. Depends on task 778 (strategic-sorry skeleton = ladder rung b) and task 780 (snapshot-before-rollback = ladder rung c). Goal: a single ambiguous recovery instruction can never again be read as 'destroy uncommitted progress.'

---

### 778. Hard-mode: relax zero-debt for strategic-sorry skeletons (division mechanism)
- **Effort**: 3-6 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None

**Description**: [--hard CORE EFFECT: relax the zero-debt policy to permit STRATEGIC SORRIES forming a SKELETON that divides the task into parts.] A primary effect of --hard is that the standard zero-debt / build-green completeness requirement is RELAXED to allow deliberately-placed, documented 'strategic' sorries (placeholder stubs) that scaffold a skeleton of the overall objective. The skeleton's strategic sorries are the DIVISION POINTS: each becomes a discrete part / follow-up task. This is the mechanism that connects the planning leg (task 774: skeleton + follow-up tasks) to the implementation leg (task 772: one phase per round). Scope of changes (hard-mode ONLY): (1) Relax zero-debt enforcement under --hard -- update the wrap-up build-green invariant (.claude/context/contracts/wrap-up.md, 'No leftover scaffolding' clause) and the anti-analysis Sub-Sorry Policy (.claude/context/contracts/anti-analysis.md) so a documented strategic-sorry skeleton is an ACCEPTABLE dispatch outcome under --hard. Under STANDARD mode, zero-debt still holds unchanged. (2) Define what makes a sorry 'strategic' and acceptable: a deliberate division boundary on the skeleton (NOT an abandoned proof), tightly scoped, documented with (a) what it assumes, (b) why deferred, (c) which follow-up task/part will discharge it. (3) Require every strategic sorry to map to a TRACKED part -- a follow-up task (created by planner-hard, task 774) or a sub-phase -- so relaxed zero-debt is VISIBLE and TRACKED, never silently abandoned. (4) Update the hard implementer/agent verification (skill-implementer-hard / general-implementation-hard-agent) and the handoff sorry_inventory so a documented strategic-sorry skeleton is reported as 'implemented (skeleton)' rather than 'failed/partial', while the sorry_inventory MUST enumerate every strategic sorry and its owning follow-up task. (5) Build-green still holds: the skeleton with strategic sorries must still compile/typecheck (sorries are valid placeholders), so 'green build with tracked strategic sorries' is the hard-mode skeleton-completion bar. Domain note: Lean4 'sorry' is the canonical strategic placeholder; the same idea applies to other domains (stubbed functions, 'admit', NotImplemented). CONTEXT: on task 305 the zero-debt expectation (no incomplete proofs) combined with an oversized phase pushed the orchestrator to try to fully prove a research-grade lemma in one round, driving burnout; allowing a strategic-sorry skeleton would have let it land the structure and divide the remaining proof obligations into tracked parts. Foundational --hard policy that the planning leg (774) and implementation leg (772) build on.

---

### 777. Hard-mode research: more effort, higher quality and verification standards
- **Effort**: 3-6 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None

**Description**: [--hard RESEARCH leg: more effort, higher standards for quality, consistency, and verification of findings.] Strengthen hard-mode research (skill-researcher-hard / general-research-hard-agent, and domain research-hard agents where applicable) so --hard research is materially more rigorous than standard research, not just a relabel. (1) Raise the effort/coverage bar: require broader source coverage and deeper investigation before concluding (more searches, cross-checking multiple independent sources, no single-source conclusions). (2) Higher quality + consistency standards: require findings to be internally consistent and cross-validated; surface and RESOLVE contradictions rather than reporting them flatly. (3) Harden VERIFICATION of findings: extend the existing H4 adversarial self-verification and H3 reference grounding so every load-bearing claim is verified against a concrete source or counterexample before it ships, and uncertain claims are explicitly marked with confidence levels. (4) Encode the higher standard as enforceable CONTRACT language (analogous to the anti-analysis contract), in the research-hard skill/agent and any research-hard contract file, not just prose. Scope: hard-mode only; do NOT change standard research. CONTEXT: completes the three-leg --hard model alongside the implementation leg (task 772) and the planning leg (task 774). Motivating evidence: in transcript .claude/output/lit.md a hasty inline (non-hard) research conclusion was later found UNSOUND by a more careful standard-mode audit -- hard research should make that level of verification the default, raising confidence in the findings that drive planning and implementation.

---

### 776. Make --lit navigation work for ad-hoc dispatch and sync stale CLAUDE.md docs
- **Effort**: 3-6 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: literature
- **Dependencies**: Task 775

**Description**: Two coupled fixes so --lit works outside the formal /research N --lit command path and is documented accurately. (1) Ad-hoc dispatch directive: create a reusable 'literature navigation directive' that the primary/orchestrator agent injects when the user asks for --lit conversationally (not via skill Stage 4a). When no per-repo sub-index exists, this path must surface the SAME interactive question defined in task 775 (create curation task vs use global now) -- it must NOT silently inject nothing and must NOT silently auto-search. Once a path is chosen, the dispatched agent receives the <literature-briefing> navigation instructions (run literature-search.sh against the chosen corpus, Read the relevant segmented chunk files). Reference how Stage 4a generates lit_context. (2) CLAUDE.md doc sync: the 'Literature Mode (--lit)' section still describes the DEPRECATED static-dump model (literature-retrieve.sh, <literature-context>, 'reads all .md and .txt files from specs/literature/', TOKEN_BUDGET=4000/MAX_FILES=10). Rewrite the 'What --lit Does' and 'Interactive Sub-Index Setup Detection' subsections to describe (i) the live navigate-on-demand briefing (literature-briefing.sh -> <literature-briefing>) against the global segmented corpus, and (ii) the interactive no-silent-fallback behavior from task 775 (create-curation-task vs use-global-now). Reconcile the token-budget drift (literature-retrieve.sh header 8000, CLAUDE.md 4000, global index.json 8000). Root causes: G3 (navigation reachable only from skill Stage 4a), G4 (stale CLAUDE.md misdocuments --lit). Depends on task 775 (documents the interactive behavior 775 implements).

---

### 775. --lit: interactive prompt when no per-repo sub-index (no silent fallback)
- **Effort**: 3-6 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: literature
- **Dependencies**: None

**Description**: [--lit, NO SILENT FALLBACK] When --lit is used but no per-repo specs/literature-index.json sub-index exists, the system MUST present an INTERACTIVE question (AskUserQuestion) -- never silently do nothing, and never silently auto-search. The question asks the user to choose between: (a) CREATE A TASK to curate a per-repo sub-index (so future --lit runs use a focused, repo-specific selection from the global corpus), or (b) POINT TO THE GLOBAL corpus now (run a relevance search against the global ~/Projects/Literature FTS5 index via literature-search.sh, keyed by the task description, and build a <literature-briefing> from the top-N matching segments for this run). (1) literature-briefing.sh must accept the task description/query (it currently takes no arguments) and support a global-corpus briefing mode used by option (b). (2) Wire the interactive prompt into the skill Stage 4a callers (skill-researcher, skill-researcher-hard, skill-planner, skill-planner-hard, skill-implementer, skill-implementer-hard) -- reconcile with / replace the existing 3-option Stage 4a flow (Skip / Create setup task / Create+run) so the choice is clearly 'create curation task' vs 'use global now', and NO branch silently yields an empty briefing. (3) Either briefing path always carries the 'How to Use' footer directing the agent to run literature-search.sh and Read the relevant segmented chunk files. (4) DESIGN QUESTION to resolve during /plan: define the default for autonomous contexts (e.g. /orchestrate) where AskUserQuestion cannot prompt -- it must be a VISIBLE, logged choice (e.g. default to global with a logged notice, or create-and-defer), never a silent no-op. Root causes: G1 (hard gate + silent empty exit), G2 (no global-corpus option). SUPERSEDES the earlier non-interactive auto-fallback design per user direction: 'I don't like fallbacks which are silent.' CONTEXT: transcript .claude/output/lit.md -- no sub-index existed, briefing silently exited empty, the agent got nothing from --lit and fell back to web/training knowledge; the segmented global corpus (222 entries + queryable FTS5 .literature.db via literature-search.sh) was never explored.

---

### 774. Hard-mode planning: smaller phases + skeleton plan with follow-up tasks
- **Effort**: 3-6 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 778

**Description**: [--hard PLANNING leg: make phases SMALLER and divide work into a SKELETON plan + follow-up tasks.] Revise hard-mode planning (skill-planner-hard / planner-hard-agent) so that under --hard the plan is decomposed into genuinely small phases, each completable in one bounded agent round, rather than one large open-ended plan ('Phase 1 strike 3: prove merge_forward_succ' was research-grade). (1) Tighten H8 phase sizing so each phase is a minimal bounded unit (e.g. one lemma / one checklist sub-item / ~100-300 lines output), not a multi-part objective. (2) Add a SKELETON-PLUS-FOLLOW-UP decomposition: when the full objective exceeds what a few small phases can cover, planner-hard produces a SKELETON plan covering the core/critical path and SPAWNS follow-up tasks (via the task-spawn / multi-task-creation mechanism) for the remaining work, instead of inflating phases. The skeleton plan and its follow-up tasks are linked via state.json dependencies. (3) The SKELETON is realized with STRATEGIC SORRIES per the relaxed zero-debt policy (task 778): planner-hard plans the skeleton so that deliberately-placed, documented sorries sit at the DIVISION BOUNDARIES, and EACH strategic sorry maps to a follow-up task/part. The division into follow-up tasks is therefore concretely driven by where strategic sorries are placed on the skeleton -- each sorry's deferral comment names the follow-up task that will discharge it. (4) Ensure the resulting small phases feed the implementation leg (task 772) so each implement round handles exactly one phase. (5) Extend the handoff schema (.claude/context/contracts/wrap-up.md) as needed to track skeleton-vs-follow-up status and the strategic-sorry-to-task mapping, and update skill-implementer-hard Stage 3b to consume the smaller phases. Root cause: RC4 (phases not regimented; oversized open-ended phases drove orchestrator burnout on task 305). Scope: hard-mode only. CONTEXT: part of making --hard proceed in regimented bounded chunks (transcript /orchestrate 305 --hard --lit, .claude/output/hard.md). This is the PLANNING leg of the three-leg --hard model (research=task 777, planning=this task, implementation=task 772), built on the relaxed zero-debt / strategic-sorry policy (task 778). Depends on task 778.

---

### 773. Add orchestrator-role discipline contract and burnout circuit-breaker
- **Effort**: 3-6 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 772

**Description**: The anti-analysis contract (H2, .claude/context/contracts/anti-analysis.md) is injected only into IMPLEMENT dispatches via build_hard_mode_prompt_context -- the orchestrator ROLE itself is ungoverned, which is why burnout happened in the orchestrator's own context. Create a new contract (e.g. .claude/context/contracts/orchestrator-discipline.md) binding the orchestrator role: NO inline design/proof analysis, NO reading implementation source, NO running builds, NO strategy reconsideration; when a phase cannot complete in a bounded dispatch, the only allowed responses are (a) dispatch a fresh research/audit agent, or (b) escalate via the blocker ladder -- NEVER absorb the work. Wire this contract into skill-orchestrate-hard so it is referenced/enforced at the top of the state-machine loop (analogous to anti-analysis.md injection into implement dispatches). Add a burnout circuit-breaker: detect orchestrator context-exhaustion signals (repeated re-reads of the same file, multiple consecutive inline-reasoning turns with no Agent dispatch, mid-analysis strategy reversal) and force a handoff/dispatch instead of continuing inline. Reference existing context-exhaustion-detection.md if present. Root causes: RC2 (orchestrator role ungoverned by H2), RC5 (no burnout circuit-breaker). Scope: hard-mode only. CONTEXT: burnout signatures in transcript -- circular reconsideration (built renameNF_eval_dup -> doubted it -> abandoned -> re-added -> stripped -> re-added a hypothesis), explicit 'before I concede... ONE more time' (line 2009); ended marking phase BLOCKED with an UNSOUND inline conclusion later caught by a standard-mode audit.

---

### 772. Make hard-mode orchestrator a pure dispatcher (strip implementation capability)
- **Effort**: 3-6 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None

**Description**: [--hard IMPLEMENTATION leg: focus each agent round on an INDIVIDUAL PHASE, never the entire plan.] Make skill-orchestrate-hard structurally incapable of doing implementation work itself, forcing per-phase delegation. (1) Remove `Edit` from skill-orchestrate-hard `allowed-tools` (currently `Agent, Bash, Read, Edit`) so the orchestrator cannot directly modify source files -- it used Update ~10 times on task 305. (2) Constrain Bash to orchestration-only operations (jq/state.json reads, git status/log, status-sync scripts) and explicitly forbid build/test/compiler invocations (lake build, lean-lsp, etc.) in the orchestrator context. (3) Require BLOCKING, foreground single-phase dispatch: exactly one Agent call per cycle, wait for its handoff return, never interleave the orchestrator's own work -- forbid background/parallel dispatch of implementation agents (root cause: transcript line 92 'launched it in the background and will continue the orchestration'). (4) Restrict orchestrator Reads to handoff JSON, state.json, and plan files ONLY -- forbid reading implementation source files. (5) Under the relaxed zero-debt policy (task 778), a VALID outcome of an implementation round is a green-building strategic-sorry SKELETON for the phase -- each strategic sorry documented and mapped to a tracked follow-up part -- rather than a fully complete phase; the orchestrator must ACCEPT and route such skeleton handoffs (reading the sorry_inventory) as progress, not demand completeness in one round. Root causes: RC1 (orchestrator had Edit + unrestricted Bash), RC3 (H1 not enforced as a hard loop boundary; background dispatch). Scope: hard-mode only; do NOT modify base skill-orchestrate. CONTEXT: /orchestrate 305 --hard --lit (transcript .claude/output/hard.md) -- the orchestrator became the implementation agent (lines 954-2700: zero implementation dispatches, only inline proof reasoning + ~10 direct Update/lake-build/lean-lsp calls). Goal: each --hard implementation round dispatches exactly ONE phase to a bounded sub-agent; the orchestrator never takes the plan as a whole. Pairs with the planning leg (task 774), which produces the small phases / strategic-sorry skeleton this leg consumes, and the relaxed-debt policy (task 778).

---

### 87. Investigate terminal directory change when opening neovim in wezterm
- **Effort**: TBD
- **Status**: [RESEARCHED]
- **Task Type**: neovim
- **Topic**: Terminal UI
- **Dependencies**: None
- **Research**: [087_investigate_wezterm_terminal_directory_change/reports/research-001.md]

**Description**: Investigate why the terminal working directory changes to a project root when opening neovim sessions in wezterm from the home directory (~). Determine whether this behavior is caused by neovim or wezterm (configured in ~/.dotfiles/config/). Identify if any functionality depends on this behavior before modifying it. Goal is to avoid changing the terminal directory unless necessary.

---

### 78. Fix Himalaya SMTP authentication failure when sending emails
- **Effort**: 1-2 hours
- **Status**: [PLANNED]
- **Task Type**: neovim
- **Topic**: Email Integration
- **Dependencies**: None
- **Research**: [078_fix_himalaya_smtp_authentication_failure/reports/research-001.md]
- **Plan**: [078_fix_himalaya_smtp_authentication_failure/plans/implementation-001.md]

**Description**: Fix Gmail SMTP authentication failure when sending emails via Himalaya (<leader>me). Error: Authentication failed: Code: 535, Enhanced code: 5.7.8, Message: Username and Password not accepted. The error occurs with TLS connection attempts and persists through multiple retry attempts. Identify and fix the root cause of the SMTP credential configuration.
