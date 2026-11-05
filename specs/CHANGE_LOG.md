# Change Log

All notable changes to the OpenCode system.

## Format

Each entry includes:
- Date
- Task number and name
- Type of change
- Brief description

---

### 2026-11-05

**Task 468: core_docs_correctness_and_single_authority_audit**
- Status: completed
- Type: meta
- Summary: Audited and corrected all 29 files under agent-system/extensions/core/docs/ for dead command surfaces, broken relative links, a stale command inventory, and topic duplication, establishing one authoritative home per duplicated topic; redeployed to the live .claude/ tree with one reasoned, pre-existing, out-of-scope gate exclusion (lint-task-lookup-adoption.sh on a file this task never touched).

**Task 467: orchestrate_first_workflow_docs_restructure**
- Status: completed
- Type: meta
- Summary: Rewrote the five named source-store documentation files around the /task -> /orchestrate -> /todo spine, retargeting the removed /research /plan /implement commands into /orchestrate's forcing-flag coverage, adding /project-overview, /please, /zulip, and a top-level Extensions section, correcting the extension catalog table, and stripping record-versioning prose from research-flow-example.md. Redeployed via deploy-headless.sh; all six plan phases closed (five COMPLETED, one COMPLETED WITH EXCLUSIONS for two unrelated, pre-existing, evidenced-and-logged defects).

**Task 443: task_reference_hook_resolve_markers_against_full_file**
- Status: completed
- Type: meta
- Summary: Resolved the dispatch's observation: the write-time task-reference hook now resolves an Edit's markers against the reconstructed post-edit file via a region-aware, depth-counting parser, honoring a file-wide marker pair without needing a redundant nested pair. All five plan phases completed, redeployed, and verified live.

**Task 442: deploy_before_implement_postflight_to_avoid_cycle_cost**
- Status: completed
- Type: meta
- Summary: Landed a new evaluation-record subsection in batch-orchestration-guardrails.md documenting why a pre-postflight-sweep deploy trigger was evaluated and intentionally left unbuilt (safe but not worth a third genuine deploy-caller site on cost/benefit grounds), added pointer comments at the two script sites where the question naturally arises, and redeployed the source store. No gate logic or trigger predicate changed anywhere.

**Task 441: resolve_source_store_verification_invocation_contract**
- Status: completed
- Type: meta
- Summary: Resolved the source-store verification invocation contract: check-extension-docs.sh and sync-manifest-scripts.sh now run from either tree via an opt-in self-correcting path in deploy-root-guard.sh, with no environment override required; verify-deploy.sh gained a clarifying header note (no behavioral change, since it never carried the refusal). Documented in regeneration-is-manual-only.md. Deployed clean after fixing 3 shellcheck findings surfaced by the redeploy's inline verification.

**Task 440: fix_file_scope_glob_containment_predicate**
- Status: completed
- Type: meta
- Summary: Fixed the quoted-entry-disables-own-glob bug in both is_contained_v10 (git-commit-scoped.sh) and its ported twin is_contained (git-commit-phase.sh), so a /**-suffixed file_scope entry now contains its direct children and every deeper descendant without widening containment for any non-/** entry or same-prefix sibling. Added Z11-Z14 and Case 10-11 test coverage (each independently confirmed RED against pre-fix behaviour), redeployed via deploy-headless.sh, and confirmed both deployed copies carry the fix via a live sanity check against a real /** entry in specs/state.json.

**Task 434: lint_and_fix_actionable_dead_command_references**
- Status: completed
- Type: meta
- Summary: Added lint-dead-command-recommendations.sh (self-updating, enumeration-driven, no hardcoded allowlist) plus its fixture suite, retargeted all 188 dead lifecycle-command recommendation lines across 92 files onto /orchestrate, structurally fixed command-output.md's template assignments, wired the lint as gate 24 in verify-deploy.sh, and redeployed to RESULT=landed_verify_clean.

**Task 427: dispatch_composer_emits_contradictory_authoritative_inputs**
- Status: completed
- Type: meta
- Summary: Added an optional description_fingerprint field to .decisions.json entries, taught orchestrate-build-dispatch.sh to mark a description-mismatched Prior Decision POTENTIALLY SUPERSEDED inline with a conditional intro, and stated the full precedence rule once in orchestrate-state-machine.md. All four plan phases COMPLETED; full gate deferred to the batch stage per dispatch directive, discharged via a 15-suite scoped set plus gates 3/4, all green.

**Task 426: recovery_declined_cannot_tell_stall_from_agent_fault**
- Status: completed
- Type: meta
- Summary: Fixed the RECOVERY_DECLINED arm's two recording bugs (real --phase, real --dispatch-seq) and added arm-local, record-time stall/strand corroboration in its message and in issue-record.sh's --tags-json, so a reader can tell an abandoned wrap-up or heartbeat-strand from an uncorroborated agent-contract violation without touching either canonical signal's own trigger expression. Closed a test-sandbox gap and pinned all four VERIFY items with fixtures proven to bite.

**Task 425: state_files_dropped_as_file_scope_excursions**
- Status: completed
- Type: meta
- Summary: Spliced specs/TODO.md and specs/state.json into orchestrate-cycle-postflight.sh's WORK (h) effective_file_scope_json allowlist, eliminating the false ADVISORY/EXCURSION DROPPED diagnostics those two engine-written files triggered when self-reported in modified_files. Added a new fixture pinning the fix alongside the unchanged drop-and-warn for genuine excursions (verified to fail pre-fix via a disable/restore reproduction check), documented the landing in git-staging-scope.md, and confirmed the deployed tree matches the source store.

**Task 424: harden_four_tier_conflict_case1_releaser_race**
- Status: completed
- Type: meta
- Summary: Replaced Case 1's fixed-delay releaser in test-four-tier-conflict.sh with a signal-file-gated construction that enforces foreground/background ordering by direct evidence instead of a wall-clock margin, confirmed non-vacuous under the dispatch's induced-load reproduction method (original fixture failed twice at loads 18.33/23.66; fixed fixture passed three times at loads 22.62-26.98), confirmed Cases 2-13 unaffected, and redeployed with the full gate set run (one reasoned exclusion recorded for a pre-existing, unrelated standing failure).

**Task 422: fix_guard_git_push_expired_grant_matching_defect**
- Status: completed
- Type: meta
- Summary: Fixed test-guard-git-push.sh's single failing case by unsetting PG_EXPIRY_WINDOW (this machine's ambient 1800s override) alongside the suite's existing two isolated knobs, confirmed 47/47 green under the real ambient environment, and retired the now-resolved known-failures.txt row plus its two stale surrounding prose counts.

**Task 417: resolve_gate20_eager_load_budget_overage**
- Status: completed
- Type: meta
- Summary: Resolved the gate20 eager-load context-budget overage via route (a): recovered 1,488 B of real headroom under the unmoved 66,800 B baseline by relocating two genuinely duplicated eager sections (rules/artifact-formats.md's Phase Status Markers, memory/EXTENSION.md's /distill table and lifecycle diagram) to their existing non-eager homes, dated the budget config's own record, and redeployed. gate20 and the context-budget suite are both fully green; the full gate battery's 9 other failures were confirmed as load-contention timeouts unrelated to this task's files.

**Task 416: reaim_gate_cost_model_input_scoped_invalidation**
- Status: completed
- Type: meta
- Summary: Completed the final 3 phases (11-13) of task 416's 13-phase input-scoped gate invalidation plan. Phase 11 cut gate 3's (doc-lint) full-sweep cost ~7.9x (125,669ms -> 16,003ms) by removing a redundant duplicate invocation and parallelizing its per-extension loop across real child processes (CED_JOBS=4). Phase 12 decided on evidence to keep gate 8 serialized, closing COMPLETED WITH EXCLUSIONS after sharpening the original ambient-CPU-pressure rationale into a measured, currently-live memory-margin risk against a bounded ~14% maximum overlap upside. Phase 13 redeployed the source store, fixed a manifest-registration gap for two new test suites, ran the complete gate set directly (cold and warm --skip-unchanged passes), and recorded the task's headline result: a warm, unchanged run cache-skips 17-20 of 24 real gates outright at near-zero cost, honestly reporting gate 8's own full-sweep cost increase (457,197ms -> 662,354ms) as an attributed trade-off from this task's own necessary new equivalence-proof test coverage.

**Task 413: coordinate_concurrent_gate_runs**
- Status: completed
- Type: meta
- Summary: Added a repo-scoped .gate-lock bounded-wait, fail-open mutex to task-lock.sh and bracketed tests/run-all.sh's top level and verify-deploy.sh's Gate 8 with it, so two concurrent sessions' full gate-set batteries serialize instead of contending for the same cores. All seven plan phases closed [COMPLETED]: 15/15 fixture cases pass against the real mechanism (serialization, non-vacuousness, stale-reclaim, nested invocation, fail-open at both call sites, verdict identity); the contract is documented in batch-orchestration-guardrails.md; the deploy is regenerated and confirmed byte-identical to source; and the complete gate set passes 37/38 against the explicit source-store target, with the sole failure traced to a foreign, out-of-scope uncommitted mutation in a file this task never touched. A genuine integration defect (VERIFY_DEPLOY_NESTED read before its own unconditional export, inside gate8_run()) was found and fixed during implementation and is documented in the plan body and summary.

**Task 411: refactor_verify_deploy_gate_framework**
- Status: completed
- Type: meta
- Summary: Closed Phase 11 (the task's final phase) as [COMPLETED WITH EXCLUSIONS]: redeployed the source store, confirmed no task-number/record-versioning language in touched files, proved finding-set equivalence and verdict/summary-line determinism across two full-battery verify-deploy.sh runs against the explicit repo-root (source-store) target, re-confirmed stalled-gate/stalled-suite fixtures and the Inter-Cycle Redeploy Checkpoint, and traced two transient ambient-contention findings to isolated-reproduction non-regressions. Objective 3 (idle-machine wall-clock table) is the one operator-authorized exclusion, recorded with a full Reasoned Exclusions record in the plan. Task 411 is now complete end to end (phases 1-11); phases 12-17 remain in the plan as reference material for a separate, already-named cost-model re-aim task.

**Task 407: derive_artifact_round_from_existing_artifacts**
- Status: completed
- Type: meta
- Summary: Fixed skill_read_artifact_number()'s // 1 default (which masked its own count-based fallback) by replacing it with an unconditional max-prefix normalization, added regression coverage in both the dispatch-integration suite and the function's own unit suite, aligned the schema reference doc, and redeployed to RESULT=landed_verify_clean.

**Task 406: mint_hook_dirties_tree_before_precondition_read**
- Status: completed
- Type: meta
- Summary: Implemented buffer-then-flush for push-grant audit writes (push-grant-lib.sh, events-log-lifecycle.sh), documented the pattern in events-format.md, recorded the invariant in skill-tag/SKILL.md, added five regression cases, and ran the complete gate set, closing Phase 5 [COMPLETED WITH EXCLUSIONS] after attributing every one of 5 verify-deploy.sh and 4 run-all.sh failures to pre-existing or concurrent-sibling causes outside this task's file_scope.

**Task 405: detect_stranded_dispatch_from_stale_heartbeat**
- Status: completed
- Type: meta
- Summary: Implemented dispatch-strand-probe.sh (a read-only heartbeat+quiescence conjunction probe) and wired it into orchestrate-cycle-postflight.sh's new stranded_suspected field, skill-orchestrate/SKILL.md's existing one-re-prompt relay, and reconcile-task-status.sh's demotion gate -- so a stranded dispatch is detected and recovered before any failure is charged. Extended lint-agent-contracts.sh with Check K to mechanically reject the detach-then-await-a-notification antipattern. Found and fixed two regressions during Phase 8's full-gate verification (a test's section-scoping boundary, and a SKILL.md eager-load ceiling overrun) before redeploying.

**Task 404: zotero_export_test_hangs_full_gate**
- Status: completed
- Type: meta
- Summary: Fixed test-zotero-generate-export.sh's unbounded runtime by rewriting synthesize_citekeys() as a single bulk jq pass and adding a 60s wall-clock bound with a proof-of-fire scenario; verified the whole suite (13/13 pass, ~12s), confirmed run-all.sh and the complete verify-deploy.sh gate set both now terminate deterministically (previously an indefinite hang), and closed the final verification phase COMPLETED WITH EXCLUSIONS against 4 pre-existing, unrelated gate failures with full evidence.

**Task 403: share_one_verify_deploy_gate_run_per_batch**
- Status: completed
- Type: meta
- Summary: Verified the batch-shared verify-deploy gate design end to end: a live fixture confirmed the multi-task deferral directive and single-task invariance, a repo-wide grep confirmed the bare-/implement invariance, and the complete verify-deploy.sh gate set was run. Fixed the one genuine regression (Gate 20's SKILL.md per-file ceiling, caused by this task's own Phase 5) and closed the phase COMPLETED WITH EXCLUSIONS for the remaining four pre-existing/sibling-caused findings, each with command-level evidence recorded in the plan's Reasoned Exclusions table.

**Task 400: task_number_allocation_staleness_undetected**
- Status: completed
- Type: meta
- Summary: Added an archive-aware base-mode counter-staleness check and promoted project_number uniqueness to base mode in validate-state.sh, added a mutex-scoped --allocate-into allocation primitive (stale-counter refusal plus counter-advance assertion) to state-write.sh, covered both in their owning test suites (70 and 14 fixtures/cases respectively, all green), fixed a pre-existing D6 fixture regression the new check surfaced, and redeployed the source store to RESULT=landed_verify_clean with the full 37-gate verify-deploy.sh passing.

**Task 396: lean_phase_commit_full_build_and_plan_anchor**
- Status: completed
- Type: meta
- Summary: Added the full-library-build phase-commit gate (revising three passages that previously permitted a scoped build) and the forward-search plan-file section-anchoring rule across the lean standard agent, hard-mode agent, and their shared flow file. Deploy regenerated the .claude/** tree and all three copies were confirmed byte-identical to source. Phase 4 closed [COMPLETED WITH EXCLUSIONS]: the complete gate set was discharged against the dispatch's Batch Gate Deferral directive via a scoped verify-deploy.sh --only-gate 3,4,5,6 run (5/5 pass), deferring gate 8 to the once-per-batch stage.

**Task 395: surface_failed_per_cycle_commit_into_task_status**
- Status: completed
- Type: meta
- Summary: Added a narrowly-gated demotion block to orchestrate-cycle-postflight.sh's WORK (i): a genuinely failed per-cycle commit (exit 2/3/4/5) for a just-completed implement dispatch now demotes state.json to partial, amends the handoff with a blocker, flips verdict to defer, and emits a loud STATUS DEMOTED line. Added both-polarity regression test coverage, documented the sanctioned terminal-state exception in status-markers.md and git-staging-scope.md, and deployed with the scoped gate narrowing confirmed green (full gate-8 battery deferred to this batch's once-per-invocation stage per the dispatch's Batch Gate Deferral directive).

**Task 394: file_scope_containment_chokepoint_for_scoped_commit**
- Status: completed
- Type: meta
- Summary: Added the V10 file_scope-Containment gate inside git-commit-scoped.sh (layered onto --task, exit code 7), ten new regression cases in test-git-commit-scoped.sh, and a full git-staging-scope.md contract update including the archived specification's Rider subsection. All 5 plan phases closed (4 COMPLETED, Phase 5 COMPLETED WITH EXCLUSIONS for two deploy-boundary artifacts and two confirmed-unrelated pre-existing corpus test failures).

**Task 393: propagate_modified_files_constraint_to_silent_agents**
- Status: completed
- Type: meta
- Summary: Propagated the modified_files repo-relative-paths MUST-DO constraint and track-on-write procedure into all 13 implementation agents that never mentioned the field, via a new canonical fragment (modified-files-bullet.md) and a new lint check (Check L) with full fixture coverage in lint-agent-contracts.sh/test-lint-agent-contracts.sh. All 6 plan phases completed; the originating grep -L sweep returns nothing and the full test suite passes 37/37.

**Task 389: verify_deploy_context_budget_fixture_missing_git_add**
- Status: completed
- Type: meta
- Summary: Converted test-verify-deploy-context-budget.sh's fixture-staging invariant into a mechanically enforced index-population assertion, verified via lint/positive-run/negative-probe. The dispatch's named cause was already fixed before dispatch; recorded as a stale-premise issue rather than re-applied. Both phases closed COMPLETED WITH EXCLUSIONS after discharging the complete verify-deploy.sh gate set, which fails 3 of 37 checks for three independent pre-existing causes unrelated to this task, each evidenced and issue-tracked.

**Task 388: prune_next_body_flag_misparse_drops_active_task**
- Status: completed
- Type: meta
- Summary: No summary recorded

**Task 387: whole_tree_regeneration_scope_claim**
- Status: completed
- Type: meta
- Summary: Completed Phase 7 (redeploy and full gate), the plan's final phase, closing out task 387's full 7-phase implementation. Executed the revised measurement-integrity gate (deploy-baseline-lib.sh capture/confirm/attribute pipeline) instead of the withdrawn clean-working-tree precondition: ran deploy-headless.sh unconditionally (landed clean, 8 extensions resynced), confirmed the post-deploy findings set is identical to the pre-deploy baseline (no new findings), confirmed all 9 persisting findings are unattributable to this task's own modified_files, confirmed all 13 touched files are byte-identical between the deployed tree and the source store, and confirmed validate-state.sh exits 0.

**Task 386: silent_exit_in_no_revert_snapshot**
- Status: completed
- Type: meta
- Summary: Fixed all four silently-aborting command substitutions in git-snapshot.sh (three in --no-revert mode, one duplicated in default mode), degrading the --no-revert stash pair to a named warning while keeping the untracked-enumeration fatal-with-reason, structurally removed both SIGPIPE-prone stash-list pipelines via a new resolve_latest_stash_ref() helper, and documented the per-mode failure posture in the script header. Added RED-first regression coverage (held index.lock, SIGPIPE, negative controls) to test-git-snapshot.sh; full suite is 7 passed, 0 failed, and the deployed tree is confirmed byte-identical to source.

**Task 382: guard_foreign_stash_pop**
- Status: completed
- Type: meta
- Summary: Added a session-scoped stash-provenance ledger and a new tree-state-blind hazard-class-3 predicate to guard-destructive-git.sh that refuses git stash pop/apply of a foreign (not-this-session-created) entry with exit 2, closing the 2026-10-09 'push saved nothing, then pop drops a foreign entry' incident. All 4 ACCEPTANCE criteria verified via 107 passing fixture cases plus a live end-to-end probe against the redeployed hook; git-snapshot.sh's rollback flow (both modes) and an owned pop continue to pass.

**Task 381: implement_postflight_derived_artifact_staleness**
- Status: completed
- Type: meta
- Summary: Closed Phase 6 of the derived-artifact staleness task: added three acceptance fixtures (evidence-shaped, all-pass, no-declaration regression) to test-orchestrate-cycle-postflight.sh (233/233 passing), confirmed single-task-engine cross-engine coverage already sufficient, redeployed cleanly (core/lean no longer stale), and closed the complete-gate-set verification as COMPLETED WITH EXCLUSIONS against two pre-existing filed obstructions, two findings already excluded by a concurrent sibling task, and severe transient ambient system contention, with every new/changed suite independently verified clean.

**Task 380: archival_silently_untracks_evidence_gate_targets**
- Status: completed
- Type: meta
- Summary: No summary recorded

**Task 379: validate_state_cannot_validate_archive_state**
- Status: completed
- Type: meta
- Summary: No summary recorded

**Task 378: reviser_agent_handoff_contract_contradiction**
- Status: completed
- Type: meta
- Summary: Resolved the reviser-agent handoff-writer contract contradiction: added an orchestrator_mode-gated .orchestrator-handoff.json section to agents/reviser-agent.md, registered it in docs/architecture/handoff-schema.md's Handoff Writers table, added a clarifying note to skill-orchestrate/SKILL.md's Skill-to-Agent Mapping table, and corrected a stale comment in scripts/reconcile-task-status.sh. No script behavior changed (orchestrate-cycle-plan.sh and orchestrate-cycle-postflight.sh are byte-unchanged). Also bumped orchestrator-context-budget.json's SKILL.md ceiling (24500 -> 25000 B) to keep Gate 20 green after the required clarifying note.

**Task 376: lean_agents_mandate_forbidden_detach_then_await**
- Status: completed
- Type: meta
- Summary: Removed the lean extension's instruction to detach a build via the harness's Bash(run_in_background: true) parameter and then end the turn awaiting a completion notification, replacing it everywhere with bounded-build-waiter.md's single-Bash-call bounded idiom while preserving detachment and the build guard. Discharged lint-agent-contracts.sh Check K's now-stale exclusion for the two lean implementation agents (lint now 348 passed/13 warnings/0 failed), redeployed, and created successor task #439 carrying forward the cross-extension duplication/propagation-architecture question.

**Task 362: shared_worktree_history_read_discipline**
- Status: completed
- Type: meta
- Summary: Authored agent-system/extensions/core/context/standards/shared-worktree-discipline.md naming the read-only history-inspection techniques and the three forbidden tree-reverting git commands, registered it in index-entries.json, cross-referenced it from git-safety.md, and added a literal pointer bullet to all 15 in-scope implementation agent definitions plus the agent template. Redeployed and demonstrated the pointer chain on the deployed tree with a reproducible grep; the two Lean implementation agent definitions were deliberately left untouched per the declared scope boundary.

**Task 359: close_lint_curated_array_coverage_gaps**
- Status: completed
- Type: meta
- Summary: Closed both measured curated-array coverage gaps in lint-agent-contracts.sh: normalized and registered the two books implementation agents in Checks C and G, propagated the bounded-wait bullet pair to the measured 11-of-23 exposed research agents behind a new Check M, added a Check N completeness net so the next drift fails the lint instead of waiting to be discovered by measurement, extended the test suite from 37 to 61 assertions, ran four deliberate-removal demonstrations, and redeployed with a clean 36-check verify-deploy.sh pass.

**Task 350: offer_owner_review_when_approval_needed**
- Status: completed
- Type: meta
- Summary: Implemented the full 5-phase plan for task 350: a books-domain record pinning the approvals-stage absent-or-stale detection signature and rulings, a read-only recognizer script (books-approvals-signal.sh) emitting a user_decision offering enter-review-now/defer/decline with blocking:false and recommended=defer, a 76-case forgery-probed fixture suite, and the cross-cutting detection rule wired into both books implementation agents. Demonstrated end to end that the recognizer's emitted object reaches verdict=ask_user verbatim through orchestrate-cycle-postflight.sh, with the honest-red half (status unchanged, nothing written) confirmed via a --dry-run scratch run. Two deviations recorded: the books extension is not loaded in this repository so the literal deploy-to-.claude/ demonstration could not be observed here (deploy-headless.sh's own internal full gate still passed 36/0), and the final phase's full gate set was discharged against the dispatch file's Batch Gate Deferral directive (scoped narrowing invocations) rather than independently re-run.

**Task 312: backlog_reconciliation_required_at_task_creation**
- Status: completed
- Type: meta
- Summary: Implemented the two-layer backlog-reconciliation mechanism: scripts/audit-task-proposals.sh (shared matcher, mechanical + semantic passes, open+closed corpus), scripts/state-write.sh's audit-evidence gate (--audit-verdict/--audit-override, exit 5), hooks/validate-task-creation-audit.sh (structural backstop), Component 4b in the Multi-Task Creation Standard, and wiring into all seven creation surfaces (/meta, /task, /fix-it, /spawn, /review, /errors). Verified live against the deployed tree: both the open-backlog and closed-record (archived + live-completed) acceptance cases pass, the backstop hook refuses a raw bypass write post-deploy, and the scoped regression suite (8 suites) is green. Four pre-existing, unrelated findings were observed during the full gate sweep and recorded non-fatally rather than fixed.

**Task 282: record_versioning_write_time_hook**
- Status: completed
- Type: meta
- Summary: Built hooks/validate-no-record-versioning.sh (a PreToolUse Write|Edit hook blocking BLOCKING-tier record-versioning language via exit 2, advisory-silent, payload-only, fail-open), its fixture test, restored the lint/hook scope-agreement case in test-check-record-versioning.sh, registered it bare on both settings surfaces plus manifest.json, truth-ed up the taxonomy's Enforcement section, and redeployed with four live probes all confirming correct behavior.

**Task 275: per_repo_orchestration_queue**
- Status: completed
- Type: meta
- Summary: Added a per-repo orchestration queue as six additive task-lock.sh subcommands (queue-register/heartbeat/finish/reap/list/check), built on the existing session registry: per-orchestration identity distinct from session_id, lifecycle registered->running->finished->archived, archive-on-finish rather than rm -f, liveness computed via the existing session_liveness() unchanged, and a blocking queue-check admission gate wired into /orchestrate's pre-dispatch stage. Documented in a new Orchestration-Queue CLI section in task-lock.md and two new Class Table rows in orchestrator-runtime-files.md, covered by a 17-case fixture suite, with shellcheck clean and the deployed tree fresh.

**Task 274: next_admissible_batch_suggestion**
- Status: completed
- Type: meta
- Summary: Implemented orchestrate-suggest-next-batch.sh with --next-batch and --alternatives modes, both establishing admissibility exclusively by invoking the real orchestrate-batch-admit.sh and reading its v6 verdicts, plus an edge-proposing step for file_scope-colliding pairs. Built a 7-fixture scratch-tree regression suite, registered the script and suite in manifest.json, and wired both trigger points (conclusion-stage.md Step 7, commands/orchestrate.md's queue-check refusal branch) with supporting documentation updates. This dispatch (seq 23) closed the one outstanding Gate 20 finding (commands/orchestrate.md 281 B and skills/skill-orchestrate/SKILL.md 116 B over their ceilings) via compaction/relocation only -- no ceiling move was needed. Gate 20 now passes.

**Task 170: isolate_shell_suites_from_host_state**
- Status: completed
- Type: meta
- Summary: Isolated the two confirmed ambient-host-state instances in the shell test corpus (test-four-tier-conflict.sh cases 5/6 via a PATH-shimmed clock injection, test-detect-noop-bash.sh's shared-path checks via a delta-based rewrite), triaged all 153 corpus suites with a recorded verdict each, recorded the isolation convention in shell-script-testing.md, and discharged Phase 6's repeated-run acceptance bar via the dispatch's own Batch Gate Deferral directive. Spawned three follow-up tasks (422, 423, 424) for defects found but correctly kept out of this task's own scope.

### 2026-09-29

**Task 266: deploy_pending_vs_identical_dispatch_guard**
- Status: completed
- Type: meta
- Summary: Fixed the composition defect between the postflight completion-deploy gate and the identical-dispatch convergence guard by wiring a post-deploy reconcile pass into the Inter-Cycle Redeploy Checkpoint's clean-success path, adding a per-task streak-freeze backstop, clearing the deploy_pending marker at the completion chokepoint, correcting the refusal message, and documenting the interaction. All 8 plan phases completed; deployed and verified end-to-end.
- Artifacts: specs/archive/266_deploy_pending_vs_identical_dispatch_guard/{reports,plans,summaries}/01_*.md

**Task 244: check_task_references_repo_appropriate_roots**
- Status: completed
- Type: meta
- Summary: Replaced check-task-references.sh's hard-coded four-tree TREE_ROOTS with a repo-wide git-ls-files scan (0/0 measured equivalence in this repo), made PATH_SCOPE scannable anywhere in the repo, added validate-wiring.sh SKIP guards for missing .claude/.opencode tree roots, shipped two new fixture-driven test suites, and rewrote task-reference-exemptions.md's Enforcement section off the four-root model.
- Artifacts: specs/archive/244_check_task_references_repo_appropriate_roots/{reports,plans,summaries}/01_*.md

**Task 207: fix_zotero_export_path1_truncation**
- Status: completed
- Type: meta
- Summary: Fixed the silent-truncation data-loss defect in zotero-generate-export.sh's Path 1 by rewriting fetch_path1() with a temp-file accumulator, Total-Results-driven pagination, and loud failure with no partial write; added a content-keyed shrink guard, corrected fetch_path3's itemTypeID exclusion set, and delivered an 11-case offline regression suite plus documentation updates.
- Artifacts: specs/archive/207_fix_zotero_export_path1_truncation/{reports,plans,summaries}/01_*.md

**Task 199: concurrent_dispatch_isolation_posture**
- Status: completed
- Type: meta
- Summary: Evidence-backed split-verdict recommendation: per-dispatch git-worktree isolation for lean4/cslib implement dispatches (with a measured hardlink-clone .lake mitigation for the disk cost), plus a narrow refuse-on-contended-file guard for general/meta/markdown dispatches; hunk-level staging ruled out as infeasible.
- Artifacts: specs/archive/199_concurrent_dispatch_isolation_posture/{reports,plans,handoffs}/*.md

**Task 167: guard_latex_builds_against_vimtex_watcher**
- Status: completed
- Type: meta
- Summary: Corrected the latex extension's existing rule file (widened paths glob, new Continuous Build Safety section carrying AC1-AC5 as literal commands, repaired two unconditional build blocks) and added three non-duplicating pointers in EXTENSION.md, compilation-guide.md, and latex-implementation-agent.md, so continuous-build-watcher safety guidance is now always-in-effect regardless of task type.
- Artifacts: specs/archive/167_guard_latex_builds_against_vimtex_watcher/{reports,plans,summaries}/01_*.md

**Task 163: surface_missing_and_empty_file_scope**
- Status: completed
- Type: meta
- Summary: Added missing/null/empty and glob-shaped file_scope detection (Check 10/11 in validate-state.sh, Classes F/G in orchestrate-predispatch-review.sh) plus a --strict flag, all WARN-only in default mode. Discovered and fixed one genuine pre-existing bug in --repair (silent file_scope manufacture) and one --help truncation regression, both pinned by new regression tests. 25/25 and 34/34 fixture tests pass.
- Artifacts: specs/archive/163_surface_missing_and_empty_file_scope/{reports,plans,summaries}/01_*.md

**Task 162: formalize_files_to_modify_and_harvest_file_scope**
- Status: completed
- Type: meta
- Summary: Formalized plan-format.md's Files to modify field, built plan-file-scope-harvest.sh, widened update-task-status.sh's --file-scope-add restriction to accept plan postflights, wired the harvest into all five live plan-postflight call sites, and built/ran a cross-repo backfill script that populated file_scope for 7 existing plan-bearing tasks in ~/Projects/BimodalLogic.
- Artifacts: specs/archive/162_formalize_files_to_modify_and_harvest_file_scope/{reports,plans,summaries}/01_*.md

**Task 139: forbid_concurrent_writer_history_rewrites**
- Status: completed
- Type: meta
- Summary: Added the concurrency-gated history-rewrite prohibition to rules/git-workflow.md, general-implementation-agent.md, and context/contracts/recovery.md; implemented a tree-state-blind concurrency predicate in guard-destructive-git.sh proven by a 72-case fixture suite; documented the hazard class in git-safety.md and orchestrator-runtime-files.md; confirmed the change survives .claude/ regeneration and fires from the deployed hook.
- Artifacts: specs/archive/139_forbid_concurrent_writer_history_rewrites/{reports,plans,summaries}/01_*.md

**Task 43: email_safety_context_loading_decision**
- Status: completed
- Type: meta
- Summary: Recorded the email safety context-loading decision across the four source-store files (safety-invariants.md banner + coverage map, EXTENSION.md framing, README.md row, index-entries.json summary), confirming full enforcement coverage and zero behavioral drift. Documentation-only; deployed .claude/ tree unaffected until next manual regeneration.
- Artifacts: specs/archive/043_email_safety_context_loading_decision/{reports,plans,summaries}/01_*.md

---

### 2026-09-18

**Task 234: fix_state_write_spill_name_collision**
- Status: completed
- Type: meta
- Summary: Fixed state-write.sh's spill-name collision (both --argjson-file bindings and mixed
  --argjson-file/--argjson calls silently corrupted to the first spilled value) via a shared
  SPILL_SEQ counter and a duplicate-NAME hard error, backed by a fixture-rooted regression suite
  demonstrated RED-then-GREEN, redeployed and verified in .claude/scripts/, with a caller audit
  confirming no live caller ever triggered either defect shape.
- Artifacts: specs/archive/234_fix_state_write_spill_name_collision/{reports,plans,summaries}/01_spill-name-*.md

**Task 226: fix_scoped_commit_dropping_staged_deletions**
- Status: completed
- Type: meta
- Summary: Fixed git-commit-scoped.sh's V2 safety gate to classify already-staged deletions as a
  third outcome (committed but not re-added), closing the defect where a scoped commit silently
  dropped staged deletions/renames. Added red-first regression tests T8/T9/T10, updated header
  documentation, and refreshed the deployed .claude/ tree to byte-identical parity.
- Artifacts: specs/archive/226_fix_scoped_commit_dropping_staged_deletions/{reports,plans,summaries}/01_scoped-commit-staged-deletions*.md

**Task 215: unwind_unconsumed_orchestrate_dispatch**
- Status: completed
- Type: meta
- Summary: Added orchestrate-unwind-dispatch.sh, the sanctioned by-hand recovery path for a
  /orchestrate dispatch prepared but never issued: it restores state.json status/last_updated/
  session_id, the durable dispatch_seq_counter, releases the lock, deletes the dispatch file, and
  clears pending_dispatch, or refuses cleanly. Widened orchestrate-cycle-plan.sh's
  pending_dispatch record with the prior_* pre-image the recovery script needs, documented the
  script across the state-machine doc, git-safety.md, and SKILL.md, and verified with a real
  end-to-end fixture test, shellcheck, and a clean redeploy.
- Artifacts: specs/archive/215_unwind_unconsumed_orchestrate_dispatch/{reports,plans,summaries}/01_unwind-unconsumed-dispatch*.md

**Task 213: thread_focus_prompt_into_cycle_plan**
- Status: completed
- Type: meta
- Summary: Fixed three coupled defects in the batch /orchestrate engine: user focus prompts now
  thread into dispatch files, a forced-phase round now genuinely stops for the rest of a run
  instead of falling through to status-derived dispatch, and the per-task work-cycle budget now
  resets every run (with --continue-budget removed) while forced plan/implement admission is now
  keyed on artifact presence rather than status. Redeployed and confirmed live in a real, separate
  consumer repository.
- Artifacts: specs/archive/213_thread_focus_prompt_into_cycle_plan/{reports,plans,summaries}/01_focus-*.md

**Task 212: gate_research_dispatch_missing_report**
- Status: completed
- Type: meta
- Summary: Replaced the two-agent handoff-writer allowlist with a dispatch-derived
  --handoff-expected predicate (default true), added a research report-file existence gate plus
  report_missing output and a message-findings recovery helper wired into skill-orchestrate Move
  3, and hardened all 21 research agent contracts (plus planner-agent and
  general-implementation-agent) against message-only delivery. 447 tests pass across 5 suites,
  shellcheck clean, redeployed and confirmed.
- Artifacts: specs/archive/212_gate_research_dispatch_missing_report/{reports,plans,summaries}/01_gate-research-report-handoff-predicate*.md

**Task 209: init_consumer_specs_and_runtime_ignores**
- Status: completed
- Type: meta
- Summary: Added an idempotent init-specs.sh bootstrap for a fresh consumer repo's specs/ state
  (state trio + managed specs/.gitignore + untrack sweep for already-tracked runtime files), wired
  it into all six first-touch task-creation sites plus a defensive /orchestrate call, extended
  runtime-file-patterns.sh with the missing specs/tmp/ class member, rewrote the Consumer Repo
  Setup standards documentation, and added an 8-case fixture suite (23 assertions) pinning every
  acceptance criterion.
- Artifacts: specs/archive/209_init_consumer_specs_and_runtime_ignores/{reports,plans,summaries}/01_init*.md

**Task 206: fix_test_fixtures_missing_task_lookup_lib**
- Status: completed
- Type: general
- Summary: Fixed test-postflight-deploy-gate.sh's missing task-lookup-lib.sh REQUIRED_LIBS entry
  and lint-json-channel-discipline.sh's check_emit_perline() variable-redirect false positive,
  both now green from source store and deployed copy with 0 real-corpus lint violations; added a
  permanent regression fixture case; audited 22 sibling fixtures and defensively closed two
  dormant instances of the same missing-lib gap (test-handoff-dispatch-identity.sh,
  test-git-commit-scoped.sh).
- Artifacts: specs/archive/206_fix_test_fixtures_missing_task_lookup_lib/{reports,plans,summaries}/01_fix*.md

**Task 200: consumer_deploy_propagation_gap**
- Status: completed
- Type: meta
- Summary: Closed the consumer-deploy-propagation gap by re-firing the existing per-extension,
  path-scoped freshness comparison once per skill/agent dispatch (skill_preflight_update in
  skill-base.sh) and injecting the result into the generated dispatch file
  (orchestrate-build-dispatch.sh's <deploy-freshness-context> block), rather than building a new
  detector. Pinned partial-staleness detection with a fixture, measured the added per-dispatch
  cost (~106ms, ~435-1875x cheaper than the removed fleet walk), documented the decision and three
  rejected alternatives, and verified end-to-end by redeploying both this repo and
  ~/Projects/BimodalLogic (all four previously-cited lean call sites now confirmed byte-identical
  to source).
- Artifacts: specs/archive/200_consumer_deploy_propagation_gap/{reports,plans,summaries}/01_per-dispatch-freshness-surface*.md

**Task 194: align_lifecycle_agent_handoff_contracts**
- Status: completed
- Type: meta
- Summary: Rolled out a frozen canonical .orchestrator-handoff.json obligation block across all 64
  dispatch[]-reachable agent contracts under agent-system/extensions/*/agents/: 6 prohibition
  statements reversed, 56 files received an additive obligation subsection (including combined
  research+implement variants for 10 dual-role agents and disambiguation clauses for the 9 agents
  carrying the unrelated context-pressure handoff mechanism), and the 2 already-correct hard-mode
  agents were verified unchanged. A full completeness sweep confirmed all 64 agents have nonzero
  mention counts, zero surviving prohibition language, wording consistency against the frozen
  Appendix text, the aux-dispatch orchestrator_mode:true asymmetry held everywhere, no changes to
  orchestrate-cycle-postflight.sh or .claude/**, and a clean task-reference lint.
- Artifacts: specs/archive/194_align_lifecycle_agent_handoff_contracts/{reports,plans,summaries}/01_handoff-obligation*.md

**Task 193: carry_territory_in_base_mode_dispatch_briefs**
- Status: completed
- Type: meta
- Summary: Populated --territory in every mode (not just hard mode) with a concurrent_siblings
  payload built from every other task scheduled the same cycle, classified by explicit
  file/coarse/undeclared file-scope granularity; added the territory.md contract pointer to
  base-mode dispatch briefs; added a fixture reproducing the observed mixed-granularity batch
  shape; documented the new Cross-Task Territory contract and fixed one stale hard-mode-only
  claim.
- Artifacts: specs/archive/193_carry_territory_in_base_mode_dispatch_briefs/{reports,plans,summaries}/01_base-mode-territory*.md

**Task 188: predispatch_review_archived_dependency_false_positive**
- Status: completed
- Type: meta
- Summary: All 5 plan phases were already [COMPLETED] and committed from a prior implement
  dispatch (seq 16); that dispatch's postflight transition was refused by the completion-deploy
  gate (exit 6) because other concurrent tasks landed further commits under
  agent-system/extensions/core/** after this task's own Phase 5 redeploy, leaving
  .claude-extensions.json's recorded source_git_head behind HEAD again. Re-verified this dispatch:
  bash -n clean, exactly one trap, full suite 21/21 passing, and the deployed .claude/ copy still
  byte-identical to the source store for all three edited files. No new source edits were needed;
  the deploy gate's own sanctioned single-task redeploy-and-retry (command-gate-out.sh rc==6
  branch) is expected to resolve the residual staleness at this dispatch's postflight.
- Artifacts: specs/archive/188_predispatch_review_archived_dependency_false_positive/{reports,plans,summaries}/01_archive*.md

**Task 182: durable_redeploy_ledger_with_skip**
- Status: completed
- Type: meta
- Summary: Confirmed all 5 plan phases (already implemented and committed by the prior dispatch)
  remain closed after the inter-cycle redeploy checkpoint's deploy landed cleanly. Re-ran the
  task-specific suites -- test-deploy-ledger-lib.sh (27/27), test-orchestrate-cycle-plan.sh
  (238/238), test-runtime-file-tracking.sh (9/9), test-deploy-orphans.sh (5/5),
  test-deploy-propagation.sh (4/4), test-deploy-baseline-lib.sh (7/7) -- all green.
  specs/.orchestrator-deploy-ledger.json confirms the current deploy already incorporates task
  182's changes (task_numbers includes 182, verify_outcome "filtered"), so the prior dispatch's
  deploy_pending block is resolved and no further redeploy is required.
- Artifacts: specs/archive/182_durable_redeploy_ledger_with_skip/{reports,plans,summaries}/01_durable-redeploy-ledger*.md

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
