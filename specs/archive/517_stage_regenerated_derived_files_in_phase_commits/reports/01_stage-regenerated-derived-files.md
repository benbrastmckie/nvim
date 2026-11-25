# Research Report: Task #517

- **Task**: 517 - Stage regenerated derived files in phase commits
- **Started**: 2026-11-22T00:00:00Z
- **Completed**: 2026-11-22T00:00:00Z
- **Effort**: ~1 hour
- **Dependencies**: #455 (preflag_module_wiring_invariant_failures) — SEMANTIC predecessor,
  serialization-only edge via shared `agents/general-implementation-agent.md`. #455 completed
  during this same session (2026-11-22); its findings are incorporated below. #513 — NO EDGE,
  confirmed (no shared files; adjacent subject only).
- **Sources/Inputs**: Codebase read (`agent-system/extensions/core/**`), direct `jq` checks
  against `~/Projects/BimodalLogic/.claude-extensions.json` and its archived
  `specs/archive/867_formalize_gabbay_separation_ztime/issues.jsonl`, archived task artifacts
  for #381, #455.
- **Artifacts**: `reports/01_stage-regenerated-derived-files.md` (this file)
- **Standards**: report-format.md, subagent-return.md
- **Type**: meta

## Executive Summary

- The four cited recurrences are re-derived and confirmed exactly as described (class
  gate-collision x3 / tooling x1, severity minor, phase implement, `dispatch_seq` 7, 17, 17, 18
  in `~/Projects/BimodalLogic/specs/archive/867_formalize_gabbay_separation_ztime/issues.jsonl`).
  The first entry (`dispatch_seq` 7) shows the agent already self-discovering and self-applying,
  ad hoc, exactly the standing rule decision (a) would mandate — strong evidence the gap is a
  missing *standing instruction*, not a missing capability.
- **No existing mechanism in `agent-system/**` already closes the execution half.** The
  checkpoint-commit protocol (`checkpoint-commit.md` Step 1, mirrored by
  `general-implementation-agent.md`'s Phase Checkpoint Protocol step 5 via
  `git-commit-phase.sh`) stages whatever the agent reports in `files_touched`/`modified_files`;
  nothing anywhere instructs the agent to re-run a regeneration entry point before that staging
  happens.
- **Decision: (c), both halves, narrowly scoped.** (a) is adopted as the rule: a short,
  generic obligation added to `checkpoint-commit.md`'s Step 1 (anchor) with a one-line pointer
  from `general-implementation-agent.md` (never a verbatim copy — see Recommendations).
  (b) is adopted as a minimal backstop: an additive, non-blocking call to the ALREADY-BUILT
  `derived_probe_run_all` (from `scripts/lib/derived-artifact-probe-lib.sh`) at
  `git-commit-phase.sh`'s phase-commit site, in addition to its two existing implement-postflight
  call sites — no new schema, no new field, no promotion work.
- **Critical caveat, re-derived live**: `~/Projects/BimodalLogic/.claude-extensions.json`
  declares **neither** `derived_artifact_probes` **nor** `coupled_generated_surfaces`. Per the
  hard constraint that the new obligation be expressed purely in terms of *declared* derived
  surfaces, **neither (a) nor (b) has any effect on the real incident by itself.** A companion
  consumer-repo task declaring `coupled_generated_surfaces` for BimodalLogic's two surfaces is
  the other half of a complete fix, and per this record's own repository-boundary constraint
  that task must be filed in BimodalLogic, not built here.
- The absence is a **separate consumer-repo gap** (an opt-in declaration nobody has populated),
  not evidence the mechanism is too obscure to use once known — `repo-level-declarations.md`
  documents the schema completely. The only real discoverability nit is that the mechanism is
  silent and opt-in with no proactive nudge toward a repo exhibiting this exact friction pattern;
  noted as a Context Extension Recommendation, not built here.

## Context & Scope

Researched the EXECUTION HALF of a two-half friction: declaring a derived-output surface (file
scope / `Files to modify`) does not, by itself, cause the surface to be regenerated and staged
within the phase that staled it. The DECLARATION HALF is explicitly out of scope (owned by #455,
which completed earlier in this same session — see Findings). Scope was held to the three
hard constraints: stay inert in a repo declaring no surfaces, never require a full build, and
never name a consumer repository's own generator scripts in a core file.

## Findings

### Codebase Patterns

- **`checkpoint-commit.md` Step 1** (`Determine Targeted Scope`, lines ~7-27) computes the
  staging list from the task directory, `TODO.md`/`state.json`, the plan file, and the agent's
  self-reported `modified_files` — nothing here re-runs anything; it only *reads* what the agent
  already reports as touched.
- **`general-implementation-agent.md`'s Phase Checkpoint Protocol** (step 5, ~line 1026) commits
  via `git-commit-phase.sh`, which derives its stage list from the phase's own progress-file
  `files_touched` union and performs the **Phase-Commit Containment Self-Check** (documented at
  ~line 403): any `files_touched` path not contained in the task's declared `file_scope` is
  **dropped with a warning**, not staged. This means even a dutiful, un-prompted regeneration by
  the agent is actively undone at commit time unless the regenerated path is already inside
  `file_scope` — the execution half and the declaration half are *coupled* at this exact site,
  which is why the dispatch's ordering edge to #455 is real, not cosmetic.
- **`derived-artifact-probe-lib.sh`** (`derived_artifact_probes` key) is a pure **staleness
  check** (`check_command`, explicitly required to be build-free and read-only — "never a
  command that regenerates, writes, or otherwise mutates anything"). It has no
  regeneration-entry-point field and no source/trigger correlation; its two existing consumers
  (`orchestrate-cycle-postflight.sh`, `command-gate-out.sh`) both run it unconditionally, once,
  at the END of the whole plan (implement-postflight), explicitly because "probes are build-free
  by declaration, so probe selection buys nothing" (#381's plan, Decision 1) — a reasoning valid
  at postflight (every probe should be green by then regardless of which phase caused what) but
  that does not automatically transfer to mid-plan phase-commit time (see Risks).
- **`coupled_generated_surfaces`** (schema: `trigger_glob`, `generated_paths`,
  `commit_blocking`, `note`) is the more precisely-targeted existing mechanism: it correlates a
  SOURCE glob to the GENERATED paths it stales, exactly the "edited X, did Y also get touched?"
  question this record is about. Today it has **exactly one reader**, an inline helper in
  `validate-artifact.sh` consulted only at **plan-acceptance** time against the plan's declared
  `Files to modify` *prose* — never against a phase's actual `files_touched` at commit time. Its
  own documentation (`repo-level-declarations.md`) already names "a second consumer" as the
  recorded trigger to promote this inline helper to `scripts/lib/`. The matching logic itself is
  pure bash-glob/string comparison against already-known data — **no command execution at all**,
  so it is strictly cheaper/safer than `derived_artifact_probes`' `check_command` and needs no
  `postflight-tool-restrictions.md` exception if later consumed from agent-side code (that
  standard scopes only the skill-postflight boundary, not agent-invoked work inside a dispatch —
  confirmed by its own "Scope" paragraph).
- **`commit_blocking` is currently inert**: `validate-artifact.sh` reads it only to adjust the
  advisory WARNING TEXT ("this surface is commit-blocking, so same-phase regeneration is owed,
  not merely the declaration") — it never actually refuses anything, because plan-acceptance
  time is structurally before any commit exists. Hoisting a `coupled_generated_surfaces` check
  to actual phase-commit time would be the *first* place in the system where honoring
  `commit_blocking: true` as a genuine refusal would be semantically meaningful — flagged as a
  natural future step, explicitly **not** built here (scope discipline; see Recommendations).
- **`plan-format.md`'s "Coupled-generated-surface declaration obligation"** (already existing,
  confirmed landed before this task) requires a PLAN's phase to schedule same-phase
  regeneration when the detecting check is commit-blocking — but this is a planning-time prose
  instruction with only an advisory enforcement (the warning above) that the *declaration* was
  made; nothing checks whether the scheduled task was actually *executed*, and nothing fires
  independently of whether the plan happened to include it. This record's new obligation is
  deliberately sited at the generic **implementation-time** checkpoint protocol instead, so it
  applies regardless of whether a given plan remembered to schedule the step.
- **#455 (completed earlier this session)** re-validated that `plan-file-scope-harvest.sh`'s
  generated-surface appending stage already correctly computes and persists both missing
  surfaces for the cited incident shape; the real residual #455 found and deliberately left
  as a follow-up is that `orchestrate-build-dispatch.sh` never reads the dispatching task's own
  `file_scope` into the dispatch prompt — a *pipeline-visibility* gap, distinct from both halves
  framed by this record. The obligation this record adds should read `.claude-extensions.json`'s
  declared surfaces directly (a repo-root file any agent can read) rather than depend on that
  pipeline-visibility gap being closed first.

### External Resources

Not applicable — this is a pure agent-system (meta) task; no external documentation consulted.

## Recommendations

1. **Adopt (c): add decision (a) as the rule, decision (b) as a minimal backstop — narrowly
   scoped, not the full engineering lift either option could grow into.**
   - **(a) — the rule.** Add 3-5 sentences to `checkpoint-commit.md`'s Step 1
     ("Determine Targeted Scope"), stating: before computing/staging this phase's scope, check
     whether any touched path is a declared derived-output surface for this repository (a
     `derived_artifact_probes.derived_output_dirs` prefix, or a `coupled_generated_surfaces`
     entry whose `trigger_glob` this phase's touched paths match); if so, re-run that surface's
     own sanctioned regeneration entry point now and include its output among the paths staged
     in this same commit. Phrase it entirely in terms of the two already-documented
     `.claude-extensions.json` keys — never name a consumer repo's own script.
   - **Pointer, not copy, into `general-implementation-agent.md`.** This repo's own
     `anchor-pointer-convention.md` ("Created 2026-11-05") is explicit: a block restated across
     files should collapse to a one-line pointer naming the anchor's path and heading, not a
     verbatim restatement. The dispatch's framing ("mirror into general-implementation-agent.md's
     phase-commit prose") should be read as *pointer*, not *copy* — add one line at the Phase
     Checkpoint Protocol's step 3/5 referencing `checkpoints/checkpoint-commit.md`'s new
     paragraph by heading, exactly the shape the convention's own worked example uses. This also
     sidesteps the VERIFY section's "does not self-trip any verbatim-fragment check" condition
     cleanly, since `lint-anchor-pointer-collapse.sh` only polices *registered* collapsed files —
     a fresh pointer never regresses a registry row, but a hand-duplicated paragraph in two files
     is exactly the shape that convention exists to avoid growing further.
   - **(b) — minimal mechanical backstop.** Add one additional, additive call to
     `derived_probe_run_all` (already-built, already-tested, already-fail-open) from
     `git-commit-phase.sh`'s phase-commit path, non-blocking: on a non-zero result, emit the
     same style of named warning the Phase-Commit Containment Self-Check already uses and record
     it via `issue-record.sh`, but never refuse the commit. This is additive only — no new
     schema/field, no promotion work, reusing the exact existing function at a third call site
     (today it has two, both implement-postflight). Keep it **non-blocking** deliberately: an
     unscoped `derived_probe_run_all` call cannot distinguish staleness THIS phase caused from
     pre-existing staleness an earlier, unrelated phase left behind (see Risks), so escalating it
     to a second ever-blocking gate at every phase commit is out of scope for this minor item.
   - **Not adopted now (explicit non-goal)**: promoting `coupled_generated_surfaces`'s inline
     helper to `scripts/lib/` and wiring a SECOND, source-correlated backstop into
     `git-commit-phase.sh` against actual `files_touched` (rather than only the plan's prose).
     This would be the more precisely-targeted mechanical answer (no misattribution risk, no
     command execution at all, and it is the one place `commit_blocking` could finally become a
     real refusal) — but it is a full phase of new engineering (promotion + new call site + new
     tests) for an item explicitly flagged as minor. Recorded here as a well-scoped future
     enhancement, not built.
2. **File a companion record in `~/Projects/BimodalLogic`** (not here — repository-boundary
   constraint) directing it to declare `coupled_generated_surfaces` entries in its own
   `.claude-extensions.json` for its two known coupled pairs: `*.lean` edits →
   `README.md`/`FormalSystem/README.md`/`FormalSystem/Metalogic/README.md` inventory blocks, and
   the same trigger → `typst/generated/status.typ`. This is the only action that gives either
   (a) or (b) any actual effect on the cited incident, since both are deliberately scoped to
   DECLARED surfaces only and the repository currently declares none. `coupled_generated_surfaces`
   needs no new script in BimodalLogic (unlike `derived_artifact_probes`, whose `check_command`
   field requires an existing build-free check command — BimodalLogic does have
   `check-module-invariants.sh`/`typst-sync-check.sh --counts-only` already, so either key is
   viable there; `coupled_generated_surfaces` is the cheaper one to populate since it needs no
   command field, only glob/path strings).

## Decisions

- **Decision 1 (the record's own ruling): (c), scoped as in Recommendation 1.** (a) alone was
  considered sufficient per the dispatch's own stated bar ("three sentences of prose... a
  complete and successful outcome"), but the ALREADY-BUILT, ALREADY-TESTED, zero-marginal-schema
  cost of adding one more call site to `derived_probe_run_all` makes the minimal backstop cheap
  enough that declining it would be leaving free detection on the table for no real savings.
  Declined the fuller `coupled_generated_surfaces`-promotion backstop as disproportionate to a
  minor, four-recurrence item.
- **Decision 2: the mirrored prose in `general-implementation-agent.md` is a pointer, not a
  verbatim copy**, per `anchor-pointer-convention.md`. This reinterprets the dispatch's literal
  "mirror ... prose" instruction in light of this repository's own documented convention,
  discovered during research; it does not change the obligation's substance, only where its full
  text lives.
- **Decision 3 (subsidiary question answered): the absence of either declaration in
  BimodalLogic is a separate consumer-repo gap, not evidence the declaration mechanism is too
  obscure to use.** `repo-level-declarations.md` documents both schemas completely and is
  reachable from `index-entries.json`; the actual failure mode is that the mechanism is silent
  and opt-in, with nothing in the system today proactively suggesting it to a repository that
  is already exhibiting the exact recurring-gate-collision pattern it exists to solve. This is
  named as a Context Extension Recommendation below, not built.
- **Decision 4: no edit to `plan-file-scope-harvest.sh`, `#455`'s files, `contracts/phase-closure.md`,
  or any `#513`-declared file.** Confirmed no file overlap and no contention; agreement with
  #455's landed finding (the harvester already computes both surfaces correctly) is incorporated
  into Finding 6 above rather than re-litigated.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Decision (a)'s prose is read but not internalized (an agent skips the check) | M | L | Decision (b)'s backstop gives independent, mechanical detection even if the prose is skipped — non-blocking, so it cannot itself deadlock a dispatch. |
| Hoisting `derived_probe_run_all` unconditionally to every phase commit flags a PRE-EXISTING, unrelated staleness at an uninvolved early phase (misattribution) | L | M | Kept strictly non-blocking (warn + issue-record only, never a commit refusal) — the only cost of a misattributed hit is an earlier, slightly-noisy detection, which is a net positive relative to discovering it only at the end of the whole plan. |
| A future maintainer reads the new obligation as licensing a full build at every phase commit | M | L | The prose must say "build-free regeneration entry point" explicitly and cite the Hard Constraint directly; `derived_artifact_probes.check_command`'s own "must be build-free" requirement is the closest existing analogy to copy the wording from. |
| Neither (a) nor (b) has any practical effect on BimodalLogic without a companion declaration | H | H (confirmed, not hypothetical) | Recommendation 2: name the companion consumer-repo task explicitly; do not treat this record as "done" in isolation from it, even though building that task is out of this record's repository-boundary scope. |
| Mirroring prose verbatim into `general-implementation-agent.md` grows exactly the duplication `anchor-pointer-convention.md` exists to prevent | L | M | Decision 2: pointer, not copy. |

## Context Extension Recommendations

- **Topic**: proactive discovery of `derived_artifact_probes`/`coupled_generated_surfaces` for a
  repository already exhibiting the recurring-gate-collision pattern.
- **Gap**: both declaration mechanisms are complete and correctly documented
  (`repo-level-declarations.md`), but entirely silent and opt-in — nothing in the system today
  nudges a repository that has logged several `class: gate-collision` issue-log entries toward
  declaring either key.
- **Recommendation**: a future, separately-scoped record could have `/telemetry --review` or an
  orchestrate-cycle heuristic recognize a repeated `gate-collision` class in a repo's own
  `issues.jsonl` and surface a one-line suggestion naming `repo-level-declarations.md`. Not
  built here — speculative, and outside this record's own minor, narrowly-scoped mandate.

## Appendix

- Search/verification commands used:
  - `jq -r '.extensions.core.source_dir' .claude-extensions.json`
  - `grep -n "Generated-surface\|generated_surfaces_available\|BEGIN GENERATED"
    scripts/plan-file-scope-harvest.sh`
  - `grep -n "Coupled-generated-surface\|coupled_generated_surfaces" -r
    context/formats/plan-format.md context/standards/repo-level-declarations.md`
  - `jq -r '.derived_artifact_probes // "ABSENT", .coupled_generated_surfaces // "ABSENT"'
    ~/Projects/BimodalLogic/.claude-extensions.json` → both `ABSENT`, confirmed live.
  - `jq -c --arg id "$id" 'select(.entry_id==$id)'
    ~/Projects/BimodalLogic/specs/archive/867_formalize_gabbay_separation_ztime/issues.jsonl`
    for all four cited entry ids — all four re-derived successfully, matching the dispatch's
    description exactly (class/severity/phase/dispatch_seq).
- References: `agent-system/extensions/core/context/checkpoints/checkpoint-commit.md`,
  `agent-system/extensions/core/agents/general-implementation-agent.md` (Phase-Commit
  Containment Self-Check, Phase Checkpoint Protocol), `agent-system/extensions/core/scripts/lib/derived-artifact-probe-lib.sh`,
  `agent-system/extensions/core/scripts/validate-artifact.sh` (coupled-generated-surfaces
  check), `agent-system/extensions/core/context/standards/repo-level-declarations.md`,
  `agent-system/extensions/core/context/standards/anchor-pointer-convention.md`,
  `agent-system/extensions/core/context/standards/postflight-tool-restrictions.md`,
  `specs/455_preflag_module_wiring_invariant_failures/summaries/01_preflag-module-wiring-invariants-summary.md`,
  `specs/archive/381_implement_postflight_derived_artifact_staleness/plans/01_postflight-derived-artifact-staleness.md`.
