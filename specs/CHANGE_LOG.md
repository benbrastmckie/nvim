# Change Log

All notable changes to the OpenCode system.

## Format

Each entry includes:
- Date
- Task number and name
- Type of change
- Brief description

---

### 2026-09-07

**Task 154: lean_challenge_statement_snapshot**
- Status: completed
- Type: meta
- Summary: Delivered lean-challenge-snapshot.sh establishing an immutable, git-SHA-pinned trusted
  Challenge module from a plan's new '## Lean Challenge Statements' section (R1), with a
  git-baseline fallback (R2), a Comparator-independent --check statement-drift mode, and a
  plan-compliance.md Statement Fidelity clause. Demonstrated on a real Lean project (cslib):
  statement drift detected in both directions and the immutability status-gate refusal, all
  verified with real commit SHAs and content hashes.

**Task 153: lean_comparator_clean_room_runner**
- Status: completed
- Type: meta
- Summary: Built agent-system/extensions/lean/scripts/lean-comparator-run.sh (clean-room wrapper
  around leanprover/comparator: git-worktree materialisation, config.json synthesis,
  README-mandated systemd-run+lake-build-guard.sh sandbox invocation, and a 9-value verdict
  classifier), its regression suite (22 passing assertions, 1 skip-with-report, live mutation
  check), vendored/authored fixtures with attribution, a design record capturing the clean-room
  trust chain and verdict-string table, and manifest.json wiring. All 8 plan phases COMPLETED.
  Advisory-only gate strength preserved as bound by the operator decision.

**Task 148: port_single_task_features_to_batch_engine**
- Status: completed
- Type: meta
- Summary: Completed all 8 phases porting single-task-only orchestrator features (hard-mode
  churn/three-strikes/burnout counters, per-task cumulative cycle budget, the four aux_dispatch[]
  auxiliary flows, and a single-task-through-the-batch-path opt-in flag) into the multi-task batch
  engine. Phase 8's live acceptance runs discovered and fixed a genuine placement bug in
  aux_dispatch[] emission, then re-verified all three acceptance cases end-to-end. Full gate
  green: run-all.sh 70/70. (Status reconciled from stranded `implementing` to `completed` during
  archival — plan showed 8/8 phases closed and the summary artifact was already linked.)

**Task 143: mt_handoff_staleness_and_dispatch_seq_gates**
- Status: completed
- Type: meta
- Summary: Cut both /orchestrate engines (single-task Stage 5, multi-task Stage MT-4) over to
  orchestrate-cycle-postflight.sh, the single shared per-task postflight script -- closing the
  originally-scoped defect (Stage MT-4 trusting any handoff without the mtime staleness gate or
  dispatch_seq identity gate) by construction. Absorbed the stray-handoff sweep into the script
  for both engines, added halt/infra_exempt_cycle output fields, and threaded a force field
  through orchestrate-cycle-plan.sh's dispatch rows. Full gate run: run-all.sh 68/68,
  lint-agent-contracts.sh 101/101, verify-deploy.sh 27/29 (one finding fixed, two pre-existing and
  unrelated).

**Task 134: tag_branch_reachability_gate**
- Status: completed
- Type: meta
- Summary: Closed the third and last uncovered gate in the /tag release preflight by adding an
  ahead-of-remote REFUSE check to Step 2 (reusing the existing fetch/remote_sha), documenting the
  new failure mode in SKILL.md's Error Handling section, syncing commands/tag.md, and verifying
  behaviorally against a real bare-origin/clone fixture including the literal
  `git merge-base --is-ancestor` assertion the consuming repo's release.yml preflight uses.

**Task 91: fail_loudly_on_nonconforming_plan_status_line**
- Status: completed
- Type: meta
- Summary: Replaced update-plan-status.sh's single generic failure message with three classified,
  line-numbered diagnostics (missing prefix, missing brackets, text before bracket); made the
  mutating sed preserve trailing annotations after the closing bracket so resumed plans are
  stampable; corrected the idempotent no-op path to echo the plan path; documented the policy in
  plan-format.md; added a 28-case fixture-driven test suite; and redeployed, confirming the fix
  survives regeneration via a live acceptance walk against the deployed script.

**Task 13: instrument_gate_out_auto_repair_reporting**
- Status: completed
- Type: meta
- Summary: Propagated validate-artifact.sh's fix/error/warning counts through
  skill_validate_task_artifacts via four caller-visible globals, added an always-on gate-out
  console report plus a durable specs/events.jsonl row, wrote a fixture-driven regression suite
  proving both acceptance directions, deployed, and demonstrated both directions live against the
  real command-gate-out.sh.

**Orphan directories tracked:** 4 (031_opencode_extensions_sync_mechanism,
094_wire_lit_flag_through_team_skills, 115_mirror_model_flag_into_hard_orchestrate,
132_register_ambient_binding_defect_class) -- already present in specs/archive/ with no
archive/state.json entry; added `orphan_archived` entries via the orphan recovery path.

**Status reconciliation:** Task 148 promoted `implementing` -> `completed` (stranded with a
linked summary artifact and an already-COMPLETED plan status). Task 137 was also checked but the
phase-accounting backstop correctly refused promotion (6/7 phases closed) and it remains
`implementing`, not archived this run.

---

### 2026-08-24

**Deploy: `agent-system/extensions/**` source store resynced to `.claude/` (16 files, 4 previously-completed fixes made live)**
- Status: completed
- Type: meta
- Summary: Ran `deploy-headless.sh` after 12 commits / 16 files of accumulated drift under
  `agent-system/`. All 16 files reconcile byte-identical between source and deployed tree
  post-deploy. The following work was authored earlier (in separately completed task directories)
  but only became **live at this deploy** — recorded here so a future reader does not misdate
  when these fixes actually took effect in the running system:
  - **`skill_orchestrate_mint_dispatch_seq` persisted-counter fix** in `scripts/skill-base.sh` —
    now derives the new dispatch sequence via `jq -r '(.dispatch_seq_counter // 0) + 1'` read back
    from the loop-guard file, instead of an ambient shell variable that collapsed to empty under
    `set -u` in a fresh shell/subprocess. Regression suite `scripts/tests/test-mint-dispatch-seq.sh`
    went from 4 failing cases (B, C, D, E, F) pre-deploy to 14/14 passing post-deploy.
  - **Literature conversion quality-gate hardening** (`literature-convert.sh`,
    `literature_quality_gate.py`) against control-character/mojibake PDF-extraction output —
    **HIGH severity**, a corpus-corruption vector on the pymupdf fallback conversion tier that
    could previously let unextractable PDFs pass silently into the global corpus and FTS index.
  - **Discovery tier-starvation and silent Tier-3-failure fix** in `literature-discover.sh` —
    Tier 3 (Semantic Scholar) failures were previously swallowed silently, and Tier 1 local-corpus
    hits could starve Tiers 2/3 under the default result limit; now surfaces failure notices and
    reserves per-tier quotas.
  - **Validate-mode directory-path false-positive fix** (the `-d` vs `-f` branch) in
    `skill-literature` validate mode, plus a `--dry-run` flag/doc mismatch fix in
    `literature-normalize-authors.sh`.
- Post-deploy `verify-deploy.sh` comparison against the pre-deploy baseline (captured verbatim
  before the deploy ran) found zero net functional regressions from this deploy: 29 findings
  resolved (the drift/missing-script findings above and the mint-dispatch-seq case failures); the
  10 pre-existing gate3 index-entries.json line-count mismatches and the pre-existing gate8
  single-source-assertion cluster survived unchanged, as expected. One additional finding newly
  appeared (`gate3` Rule S: `context/project/literature/patterns/shared-module-extraction-for-gate-checks.md`
  has no `index-entries.json` registration) but investigation traced it to the source store itself
  (the entry is also missing in `agent-system/extensions/literature/index-entries.json`, predating
  this deploy) — the same defect class as the already-known, out-of-scope
  `return-meta-artifacts-template.md` Rule S gap, made visible only because this deploy was the
  file's first-ever deployment. Not fixed here; belongs to a future source-store pass.

**Hand-edit: removed stale `mcp__lean-lsp__*` grant from the deployed `.claude/settings.json`**
- Status: completed
- Type: meta
- Summary: `.claude/settings.json` deploys under **install-once** semantics
  (`INSTALL_ONCE_ROOT_FILES` in `loader.lua`; copy-skip on existing target; unload-exclusion in
  `init.lua`), so once a project has its own copy, no redeploy ever overwrites it — the deploy
  above confirmed this empirically (the grant survived the full resync untouched). This makes
  `settings.json` effectively **user state**, not a regenerable deploy artifact, which is why
  hand-editing it here is the single sanctioned exception to the general rule that `.claude/**` is
  a disposable, source-store-regenerated tree. Removed the single `"mcp__lean-lsp__*"` array
  element (structure-aware edit; it was the last element of its array, so a bare line deletion
  would have left a trailing comma and produced invalid JSON — verified with `jq empty` and an
  exact element-count check, 24 to 23). The source copy
  (`agent-system/extensions/core/root-files/settings.json`) was already correct and was left
  untouched throughout. Note: the `validate-meta-write.sh` advisory hook, expected to fire and
  flag this as a boundary-rule warning, did **not** fire — its `is_meta_path` path-pattern list
  covers only `.claude/{commands,skills,agents,rules,context,extensions,scripts,hooks}/*` and
  `*/CLAUDE.md`, which does not include root-level files like `settings.json`. This is a real
  coverage gap in the advisory layer for install-once root files, observed but not fixed here
  (fixing the hook is out of scope for this deploy-and-remediate work).

---

### 2026-05-12

**Task 556: literature_awareness_planner_research**
- Status: completed
- Type: meta
- Summary: Added literature awareness to planner-agent.md (Stage 4.5), lean-research-agent.md (Literature Extraction Protocol), lean4.md (Literature Fidelity section)

**Task 555: update_proof_workflow_literature**
- Status: completed
- Type: meta
- Summary: Added literature-first stages to lean-implementation-flow.md, end-to-end-proof-workflow.md, and proof-construction.md

**Task 554: literature_fidelity_formal_policy**
- Status: completed
- Type: meta
- Summary: Created literature-fidelity-policy.md (257 lines) for formal extension with 5 anti-patterns, escalation protocol, domain guidance for logic/math/physics

**Task 553: literature_fidelity_lean_policy**
- Status: completed
- Type: meta
- Summary: Created literature-fidelity-policy.md (126 lines) for Lean extension with 4 anti-patterns, escalation protocol, usage checklist

**Task 551: fix_discord_link_session_discovery**
- Status: completed
- Type: neovim
- Summary: Fixed discord-link.lua session discovery to use correct opencode CLI field names

**Task 550: unify_ctrl_cr_toggle_and_agent_picker**
- Status: completed
- Type: neovim
- Summary: Fixed C-CR toggle for ClaudeCode, added leader-ac agent picker keymap

**Task 549: audit_relocate_temp_files**
- Status: completed
- Type: meta
- Summary: Relocated ~50 /tmp/ path references to specs/tmp/ across 14 files

**Task 547: research_mobile_agent_management**
- Status: completed
- Type: meta
- Summary: Implemented Neovim-side Discord integration with session linking and Telescope session picker

Memory harvest: 2 memories created (1 CONFIG, 1 INSIGHT) from task 547

---

### 2026-03-06

**Task OC_150: fix_todo_orphan_detection_completed_tasks**
- Status: completed
- Type: meta
- Summary: Fixed /todo orphan detection to properly handle completed tasks that appear in TODO.md but have been removed from state.json

**Artifacts:**
- specs/archive/OC_150_fix_todo_orphan_detection/reports/research-001.md - Analysis of orphan detection gap
- specs/archive/OC_150_fix_todo_orphan_detection/reports/research-002.md - Comparative analysis of .claude/ vs .opencode/ implementations
- specs/archive/OC_150_fix_todo_orphan_detection/plans/implementation-002.md - 5-phase implementation plan
- specs/archive/OC_150_fix_todo_orphan_detection/summaries/implementation-summary-20260305.md - Implementation summary

**Task OC_149: review_update_opencode_documentation_readme_files**
- Status: completed
- Type: meta
- Summary: Created 183 new README.md files achieving 100% coverage across 197 directories in .opencode/

**Artifacts:**
- specs/archive/OC_149_review_update_opencode_documentation_readme_files/reports/research-001.md - Comprehensive audit
- specs/archive/OC_149_review_update_opencode_documentation_readme_files/plans/implementation-001.md - 6-phase plan
- specs/archive/OC_149_review_update_opencode_documentation_readme_files/summaries/implementation-summary-20260305.md - Implementation summary

**Task OC_140: document_progressive_disclosure_patterns (TODO.md orphan)**
- Status: completed
- Type: meta
- Summary: Documentation task for progressive disclosure patterns from OC_137

**Artifacts:**
- specs/archive/OC_140_document_progressive_disclosure_patterns/reports/research-001.md - Documentation requirements

**Task OC_139: implement_stage_progressive_loading_demo (TODO.md orphan)**
- Status: completed
- Type: meta
- Summary: Research on stage-progressive loading for 40-50% context reduction

**Artifacts:**
- specs/archive/OC_139_implement_stage_progressive_loading_demo/reports/research-001.md - POC for progressive context loading
- specs/archive/OC_139_implement_stage_progressive_loading_demo/reports/research-002.md - Systematic review of 11 skills
- specs/archive/OC_139_implement_stage_progressive_loading_demo/plans/implementation-001.md - 3-phase implementation plan

**Task OC_138: fix_plan_metadata_status_synchronization (TODO.md orphan)**
- Status: completed
- Type: meta
- Summary: Research on three-way status synchronization gap between state.json, TODO.md, and plan files

**Artifacts:**
- specs/archive/OC_138_fix_plan_metadata_status_synchronization/reports/research-001.md - Root cause analysis

**Task OC_145: restore_settings_json_and_state_sync (ORPHAN)**
- Status: orphan_deleted
- Type: meta
- Summary: Empty orphaned directory with no state.json entry, removed during archival

**Directory Operations:**
- Moved 5 task directories to specs/archive/
- Deleted 1 empty orphaned directory (OC_145)

---

### 2026-03-05

**Task OC_142: implement_knowledge_capture_system**
- Status: completed
- Type: meta
- Summary: Implemented comprehensive knowledge capture system with three integrated features

**Changes:**
1. **Renamed /learn to /fix** (clean-break, NO backwards compatibility)
   - Removed: .opencode/commands/learn.md
   - Removed: .opencode/skills/skill-learn/
   - Created: .opencode/commands/fix.md
   - Created: .opencode/skills/skill-fix/
   - Updated: All documentation references across codebase
   - Migration: Use `/fix` instead of `/learn`

2. **Added task mode to /remember**
   - New syntax: `/remember --task OC_N`
   - Scans task artifacts (reports/, plans/, summaries/, code/)
   - Interactive artifact selection with multiSelect
   - 5-category classification taxonomy:
     * [TECHNIQUE] - Reusable method or approach
     * [PATTERN] - Design or implementation pattern  
     * [CONFIG] - Configuration or setup knowledge
     * [WORKFLOW] - Process or procedure
     * [INSIGHT] - Key learning or understanding
     * [SKIP] - Not valuable for memory

3. **Enhanced /todo with skill-todo**
   - Extracted embedded logic into dedicated skill
   - Added automatic CHANGE_LOG.md updates on archival
   - Added memory harvest suggestions from completed task artifacts
   - Interactive memory creation from task insights

**Breaking Changes:**
- `/learn` command completely removed (use `/fix` instead)
- No aliases, fallbacks, or backwards compatibility
- Muscle memory will need retraining

**Artifacts:**
- .opencode/commands/fix.md - New command (renamed from learn.md)
- .opencode/skills/skill-todo/SKILL.md - New skill definition
- .opencode/skills/skill-fix/SKILL.md - New skill (renamed from skill-learn)
- .opencode/commands/remember.md - Updated with --task mode
- .opencode/skills/skill-remember/SKILL.md - Updated with task mode
- specs/CHANGE_LOG.md - New changelog file

**Documentation Updated:**
- .opencode/commands/README.md
- .opencode/README.md
- .opencode/docs/guides/user-guide.md
- .opencode/docs/guides/component-selection.md
- .opencode/docs/guides/documentation-audit-checklist.md

---

### 2026-03-05

**Task OC_143: fix_skill_researcher_todo_linking**
- Status: completed
- Type: meta
- Summary: Fixed regression in skill-researcher where research reports were not being linked in TODO.md

**Root Cause:**
Missing `metadata_file_path` parameter in Stage 3 delegation prompt. The general-research-agent requires this parameter to know where to write its `.return-meta.json` file.

**Fix Applied:**
Added JSON delegation context to skill-researcher/SKILL.md Stage 3 including:
- `task_context` with task number, name, and language
- `metadata` with session_id, delegation_depth, and delegation_path
- `metadata_file_path` pointing to expected metadata file location

**Files Modified:**
- .opencode/skills/skill-researcher/SKILL.md - Added metadata_file_path parameter (lines 78-108)

**Memories Harvested:**
- [PATTERN] Metadata Delegation Pattern with .return-meta.json

---

### 2026-09-17

**Task 222: add_rust_extension_to_agent_system**
- Status: completed
- Type: meta
- Summary: Created agent-system/extensions/rust/ (manifest, EXTENSION.md, README.md,
  index-entries.json, opencode-agents.json, research/implementation agents with a cargo
  check/clippy/fmt/test verification loop, two wrapper skills, one context README), registered
  it in the extensions README table and the agent-contracts lint in-scope list, and verified
  with lint-routing-wiring.sh and lint-agent-contracts.sh (both pass with zero new failures).

**Task 219: refresh_idle_lean_tree_notify_prompt**
- Status: abandoned
- Type: meta
- Summary: Prompt via desktop notification before killing idle costly Lean trees, with
  re-verified targeted kill and snooze. Abandoned in seventh-pass backlog consolidation.

**Task 218: refresh_lean_cpu_delta_idle_cost_gate**
- Status: abandoned
- Type: meta
- Summary: Track Lean tree idleness by CPU delta and gate reclamation on a memory floor.
  Abandoned in seventh-pass backlog consolidation.

**Task 214: stop_forced_phase_fallthrough_dispatch**
- Status: abandoned
- Type: meta
- Summary: Make forced orchestrate phases stop as documented instead of dispatching the next
  phase. Abandoned in seventh-pass backlog consolidation.

**Task 211: fix_task_type_keyword_false_positives**
- Status: abandoned
- Type: meta
- Summary: Stop /task task-type detection from matching incidental keywords. Abandoned in
  seventh-pass backlog consolidation.

**Task 187: unify_commit_attribution_convention**
- Status: abandoned
- Type: meta
- Summary: Decide and enforce one commit-attribution convention across scripted and
  hand-written agent commits. Abandoned 2026-09-17 (seventh-pass consolidation): cosmetic --
  the harness now supplies commit attribution and git-commit-scoped.sh composes its own
  Session trailer; inconsistent trailers affect no behaviour.

**Task 183: decide_loop_guard_staleness_detector_disposition**
- Status: abandoned
- Type: meta
- Summary: Decide whether to port the hard-mode loop-guard operational-staleness detector into
  orchestrate-cycle-plan.sh. Abandoned 2026-09-14: superseded by task 216 (reset the
  /orchestrate cycle bound each run) -- once cycle_count is no longer carried between runs, a
  stale guard file can no longer be trusted for budgeting.

**Task 175: enforce_waiter_teardown_contracts**
- Status: abandoned
- Type: meta
- Summary: Enforce waiter teardown in the agent contracts that spawn build waiters. Abandoned
  in seventh-pass backlog consolidation.

**Task 168: correct_opencode_mcp_scoping_claim**
- Status: abandoned
- Type: meta
- Summary: Correct the disproven project-scoped MCP claim in the OpenCode doc tree. Abandoned
  2026-09-17 (seventh-pass consolidation): a doc correction inside .opencode/, a tree the user
  declared FROZEN (task 22's policy: not maintained, not generated, not deleted).

**Task 14: prevent_implementation_agent_nonterminal_fanout**
- Status: abandoned
- Type: meta
- Summary: Prevent implementation-agent fan-out from returning non-terminal status and stale
  plan markers. Abandoned in seventh-pass backlog consolidation.

**Task 164: backfill_file_scope_for_existing_tasks**
- Status: abandoned
- Type: meta
- Summary: Backfill file_scope for existing tasks and decide the disposition for plan-less
  tasks. Abandoned in seventh-pass backlog consolidation.

**Task 195: replace_handoff_writer_allowlist_predicate**
- Status: abandoned
- Type: meta
- Summary: Replace is_contractual_handoff_writer allowlist with a dispatch-derived predicate.
  Abandoned in seventh-pass backlog consolidation.

**Task 198: lean_agents_mandate_no_revert_snapshot**
- Status: abandoned
- Type: meta
- Summary: Mandate git-snapshot --no-revert in the lean implementation agent contracts.
  Abandoned in seventh-pass backlog consolidation.

**Task 216: per_run_cycle_bound_artifact_admission**
- Status: abandoned
- Type: meta
- Summary: Reset the /orchestrate cycle bound on each run and admit forced phases by artifact,
  not status. Abandoned in seventh-pass backlog consolidation.

**Task 220: guard_machine_readable_build_status**
- Status: abandoned
- Type: meta
- Summary: Make a guarded Lean build verdict machine-readable so a pipeline cannot mask it.
  Abandoned in seventh-pass backlog consolidation.

**Task 225: please_command_rule_and_docs**
- Status: abandoned
- Type: meta
- Summary: Add the user-only /please command, its never-list, the pr-prohibition exception and
  the CLAUDE.md command entry. Abandoned in seventh-pass backlog consolidation.

**Task 229: carry_reason_on_dependency_edges**
- Status: abandoned
- Type: meta
- Summary: Carry a reason on each dependency edge so a hard ordering constraint is
  distinguishable from a soft preference. Abandoned in seventh-pass backlog consolidation.

**Task 230: decide_disposition_for_terminal_dependency_edges**
- Status: abandoned
- Type: meta
- Summary: Decide and implement the disposition for dependency edges pointing at terminal or
  archived tasks. Abandoned in seventh-pass backlog consolidation.

**Task 231: post_creation_burst_dependency_analysis_pass**
- Status: abandoned
- Type: meta
- Summary: Establish a post-creation-burst dependency-analysis pass, extending the existing
  pre-dispatch review rather than forking it. Abandoned in seventh-pass backlog consolidation.

**Task 232: surface_dependency_graph_health_metrics**
- Status: abandoned
- Type: meta
- Summary: Surface dependency-graph health metrics alongside the computed wave schedule.
  Abandoned in seventh-pass backlog consolidation.

**Task 233: file_scope_derived_dependency_edge_inference**
- Status: abandoned
- Type: meta
- Summary: Infer missing dependency edges from overlapping file_scope declarations, consuming
  the absent-scope ruling rather than re-deciding granularity. Abandoned in seventh-pass
  backlog consolidation.

---
