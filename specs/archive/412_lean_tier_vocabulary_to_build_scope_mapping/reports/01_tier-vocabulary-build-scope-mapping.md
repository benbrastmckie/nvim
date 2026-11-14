# Research Report: Map core verification tiers to Lean build scopes

**Task**: 412 - Map core verification tiers to Lean build scopes
**Started**: 2026-11-11T00:00:00Z
**Completed**: 2026-11-11T00:00:00Z
**Effort**: ~1 hour (research only)
**Dependencies**: 396 (completed)
**Sources/Inputs**:
- Codebase: `agent-system/extensions/core/context/formats/plan-format.md`, `agent-system/extensions/lean/context/project/lean4/agents/lean-implementation-flow.md`, `agent-system/extensions/lean/agents/lean-implementation-agent.md`, `agent-system/extensions/lean/context/project/lean4/operations/long-builds.md`, `agent-system/extensions/lean/context/project/lean4/patterns/plan-authoring-gate-collisions.md`, `agent-system/extensions/core/context/workflows/task-breakdown.md`, `agent-system/extensions/core/scripts/lib/suite-selection-lib.sh`
- `specs/state.json` / `specs/archive/state.json` for task 396's completed record
- `git log` for the hard-mode agent-file deletion history
**Artifacts**:
- This report: `specs/412_lean_tier_vocabulary_to_build_scope_mapping/reports/01_tier-vocabulary-build-scope-mapping.md`
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Task 396 (completed 2026-11-05) already settled the phase-commit gating question this task is
  forbidden from relitigating: **every** Lean phase-end commit — not only the final phase — is
  gated on a full `lake build` of the whole library, because a scoped `lake build Module.Name`
  cannot see cross-module declaration-name clashes (the measured counterexample: a scoped
  `Periodic.lean` build passed while the full build failed on a `dualStructure` clash with
  `WeakCanonical.dualStructure`). This is already landed, unconditionally, in
  `lean-implementation-flow.md` Stage 4C and `lean-implementation-agent.md`'s Phase Checkpoint
  Protocol item 3 / MUST DO item 7.
- Consequence for the mapping this task must write: for Lean, `full` is not one option among
  four at the phase-CLOSING boundary — it is the **only** tier that ever discharges a phase-end
  commit, because the blind spot it closes (a declaration colliding with an identically-named
  one anywhere else in the project) is present in essentially every phase that adds or renames a
  declaration, not a rare cross-cutting exception. `prose`, `local`, and `interface` remain
  meaningful, but only as the **in-phase, non-gating** verification density core's tiering
  vocabulary is actually about ("how often and how broadly verification runs *during* a phase" —
  `plan-format.md`'s own "Non-negotiable invariant" wording) — never as a substitute for the
  phase-end full build.
- `agent-system/extensions/lean/agents/lean-implementation-hard-agent.md`, named in task 412's
  own `file_scope` in `specs/state.json`, no longer exists: it was deleted on 2026-11-09 (commit
  `749c660a4`, "task {N} phase 6: delete the six hard agent files...") as part of the
  architecture change already recorded in `.claude/CLAUDE.md`'s `## Hard Mode (--hard)` section
  ("`--hard` dispatches the SAME agent as standard mode — there is no separate `-hard`-suffixed
  agent any more"). The two files to edit are `lean-implementation-flow.md` (primary target) and
  the single `lean-implementation-agent.md` (hard-mode contracts are injected into it at dispatch
  time, not carried by a second file).
- Core's own generic Tier-Justification honesty mechanism (`suite_selection_select` matched
  against the phase's `Files to modify`) has no entries for `.lean` paths at all — confirmed by
  reading `scripts/lib/suite-selection-lib.sh`, which contains zero Lean-related mappings — so
  for a Lean-only phase it would always return the `__FULL_SWEEP__` sentinel, which is not
  actually honest for Lean source files (they do have elaboration surface; the sentinel's three
  documented sub-cases (a)/(b)/(c) are all about non-Lean paths). `plan-format.md`'s own
  "Unmappable criterion" paragraph (Batch-aware deferral section) is the sanctioned hook for
  exactly this: "the implementer runs the named check directly instead of either narrowing
  invocation... and records that direct run as the scoped discharge." This is the textual basis
  for the lean extension defining its own concrete per-tier actions rather than deferring to
  core's shell-suite mechanism.
- `check-module-invariants.sh` and `module-invariants-allowlist.txt` are consumer-repo scripts
  (e.g. in a BimodalLogic-style Lean project's own `scripts/`), not files in this source store;
  this report could not inspect an actual `--build-enabled`-shaped flag from here. The dispatch's
  phrase "build-enabled mode" is asserted, not independently verifiable from this repository —
  flagged as a gap below.

## Context & Scope

Task 412 asks the lean extension to state, once, in the shared flow document both lean
implementation agents reference, what core's four Verification Tier values
(`prose < local < interface < full`, defined in `plan-format.md`'s `## Verification Tiers`
section) concretely mean as Lean build/verification actions — so a lean plan's
`**Tier Justification**:` line for a non-final phase carries real information instead of being a
reflex declaration of `full`. The task explicitly forbids deciding, or relitigating, the
phase-commit gating question — that question belongs to, and was already settled by, task 396 —
and forbids touching `lake-build-guard.sh`, `plan-format.md`, or any deployed `.claude/` tree.

This report covers only the research phase: it surveys what already exists, what task 396
settled, and what the eventual mapping should say, consistent with that settlement. It does not
write the mapping into the source-store files — that is plan/implement work.

## Findings

### Codebase Patterns

**1. Task 396 already settled phase-commit gating, unconditionally, for every phase.**
`lean-implementation-flow.md` Stage 4C ("Verify Phase Completion") reads, verbatim:

> Run a full `lake build` of the whole library through the build guard — never `lake build
> Module.Name` — ... This is the only build that satisfies phase-end verification: a
> module-scoped build cannot see cross-module name clashes or downstream breakage...

and Stage 4D gates `[COMPLETED]` on a green full build. `lean-implementation-agent.md`'s Phase
Checkpoint Protocol step 3 and MUST DO items 7-8 and MUST NOT item 3 restate the identical rule:
a scoped build is "never sufficient at phase-end or at the final stage; only a full `lake build`
is mandatory at either point." None of this is conditioned on whether the phase touches a
"shared" surface — it applies to every phase unconditionally, because (per the rationale already
recorded) any new or renamed Lean declaration can collide with an identically-named one anywhere
else in the whole project; this is not an edge case the way a "shared tactic or core type" is in
core's generic model — it is the ordinary case for Lean, since Lean's declaration namespace is
global across the whole library regardless of which module(s) a phase's signature changes are
confined to.

**2. The `prose`/`local`/`interface` vocabulary does not currently exist anywhere in the lean
extension.** A repo-wide search for `"Verification Tier"` under
`agent-system/extensions/lean/` returns exactly one hit — a cross-reference to core's own
`plan-format.md` section inside `plan-authoring-gate-collisions.md`'s Condition 2 — never a
lean-local definition. This confirms the dispatch's framing: the gap is not a missing rule (core
already requires the `**Tier Justification**:` field on every non-final phase) but a missing
*definition* of what each tier means in Lean terms, so a lean plan author has nothing concrete to
cite and defaults to `full` with no meaningful justification, and core's honesty requirement does
no work.

**3. Core's generic tier table, read literally, assumes signature-visibility bounds blast
radius — which does not hold for Lean's phase-end commit gate.** `plan-format.md`'s table
(`local` = "no change to any externally visible signature" -> "build or lint of that single
module only"; `interface` = "call sites span multiple files" -> "build of the changed module plus
its enumerated direct dependents") is built around a world where files/modules not referencing a
changed signature are provably unaffected. Lean's name-collision blind spot described in finding
1 is orthogonal to signature visibility: two modules that never import each other, and whose
signatures never change, can still clash if they introduce declarations under the same name,
because Lean's declaration namespace is project-wide. This is why task 396 concluded `full` is
the mandatory phase-end gate unconditionally, rather than "only when the phase touches a shared
surface" the way core's generic worked example in `task-breakdown.md` frames a non-final `full`
phase (Phase 3, "touches shared token generation, email delivery, and auth state").

**4. The vocabulary nonetheless has a genuine, already-partially-documented meaning as
*in-phase, non-gating* verification density** — which is what core's tiering is actually about
("how often and how broadly verification runs *during* a phase", `plan-format.md`'s
"Non-negotiable invariant" paragraph), as distinct from what gates the phase's own close/commit:
- Per-step verification (Stage 4B item 5 / MUST DO item 4-6) already uses `lean_goal` +
  `lean_verify` and explicitly does **not** run `lake build` per step.
- A scoped `lake build Module.Name` is already explicitly sanctioned as "a fast, explicitly
  non-gating interim check mid-phase" (Stage 4C, MUST DO item 7) — it simply never substitutes
  for the phase-end full build.
- `long-builds.md`'s "Scoped builds are covered too" section independently confirms scoped
  invocation "remains preferable to a full build wherever it applies — it is simply doing less
  work" — consistent with treating scoped builds as the right *interim* tool, while being clear
  they are "never a basis for skipping either the detachment or the guard obligation," and never
  a basis for skipping the phase-end full build either.

**5. `check-module-invariants.sh` and `module-invariants-allowlist.txt` are consumer-repository
scripts, not source-store files.** `plan-authoring-gate-collisions.md` documents several of its
checks (C5, C15, C26, C33, the `FAIL INV` inventory check) as things a Lean *plan author* must
anticipate, but the script itself lives under a Lean project's own `scripts/` directory (e.g.
BimodalLogic), outside `agent-system/`. A repo-wide grep for `"build-enabled"` across the lean
extension returns zero hits: this phrase appears only in task 412's own dispatch/description
text, not in any existing documentation this report could independently verify. The dispatch's
instruction to "preserve... check-module-invariants.sh in build-enabled mode" should be read as:
whatever existing invocation of that script already requires a completed build (as opposed to a
pure-text check) stays folded into the `full` tier's covering-check list — but this report cannot
confirm the exact flag name from this repository, since the script is not part of this source
store.

**6. The "olean-freshness" check the dispatch asks to preserve is already documented, under a
different label, in `long-builds.md`.** "Reading the build's verdict" item 3 — "an `.olean`
-newer-than-source check per touched module... the module's PRESENCE in the build... stronger
evidence than either tier above" — is the mechanism the dispatch calls "the
olean-freshness-for-every-touched-module tier." This is not a fifth Verification Tier; it is the
strongest of three verdict-reading mechanisms already defined for the `full`-tier build itself,
and the mapping should cite it by its existing name in `long-builds.md` rather than invent a new
term.

**7. `file_scope` for task 412 (in `specs/state.json`) names a deleted file.**
`agent-system/extensions/lean/agents/lean-implementation-hard-agent.md` does not exist on disk;
`git log --diff-filter=D` shows it (and five sibling hard-agent files, plus the stale cslib-hard
fixture) was deleted in a commit titled "...delete the six hard agent files..." dated 2026-11-09,
before this task's dispatch_start_ts. `.claude/CLAUDE.md`'s `## Hard Mode (--hard)` section
documents the resulting architecture directly: `--hard` now dispatches the *same* agent as
standard mode, with behavioral contracts injected into the dispatch prompt rather than carried by
a dedicated `-hard`-suffixed agent file. The task's own description text ("the two lean
implementation agent files already reference") is written loosely enough to survive this (it
never names the hard-agent file directly, unlike the sibling research task 397's analogous
`file_scope` entry for `lean-research-hard-agent.md`), but the state.json `file_scope` array
itself is stale and should not be treated as requiring an edit to a nonexistent file.

**8. Core already sanctions a domain owning its own concrete per-tier actions when its generic
narrowing mechanisms cannot express the covering check.** The "Unmappable criterion" paragraph in
`plan-format.md`'s Batch-aware deferral section states this generally: when neither
`run-all.sh --only SUITE` nor `verify-deploy.sh --only-gate N` can name a phase's actual covering
check, "the implementer runs the named check directly instead... and records that direct run as
the scoped discharge." This is the textual hook the lean extension's own tier-to-action mapping
should cite as its authority, rather than appearing to freelance a parallel vocabulary.

### External Resources

Not applicable — this is a pure source-store documentation task; no external library or API
research was needed.

## Recommendations

1. **Write the mapping once, in `lean-implementation-flow.md`**, as a new section (e.g. directly
   above or inside Stage 4C, since that stage is already the phase-end-verification authority),
   stating the four tiers in Lean terms along these lines (content guidance, not final prose):
   - `prose` — edits confined to comments/docstrings/markdown inside a `.lean` file (or a
     lean-adjacent `.md` file) with zero compile surface. In-phase check: diff read-through, same
     as core's row. **Caution to carry into the mapping**: `long-builds.md`'s "The trigger is
     ordinary" section notes Lean hashes whole files for cache invalidation, so even a
     comment-only edit upstream invalidates downstream `.olean`s — this affects build *cost*, not
     whether `prose` is the right tier for the edit itself; the phase-end gate is still `full`
     regardless of which tier the in-phase work used.
   - `local` — a proof/definition confined to one module, no externally visible signature change.
     In-phase check: `lean_goal` + `lean_verify` per step (already mandated), optionally a scoped
     `lake build Module.Name` as the existing non-gating interim sanity check.
   - `interface` — a symbol's name/type/arity/argument order changes with call sites spanning
     multiple files. In-phase check: scoped `lake build Module.Name1 Module.Name2 ...` across the
     changed module plus its enumerated direct dependents, still explicitly non-gating.
   - `full` — the **only** tier that ever discharges a Lean phase's close/commit, per task 396:
     the full project `lake build` (detached + guarded, per `long-builds.md`'s preference order)
     plus the build-dependent `check-module-invariants.sh` checks and the
     `.olean`-newer-than-source freshness check per touched module (already named in
     `long-builds.md`'s "Reading the build's verdict" item 3).
2. **State the standing justification once, and have every non-final `full` phase in a lean plan
   point at it** rather than re-deriving the cross-module-clash rationale ad hoc each time — this
   is exactly the "point that survives either outcome" the dispatch names, and exactly the
   worked-example shape `task-breakdown.md`'s Phase 3 already models for core's generic case
   (one sentence naming the cross-cutting surface). For Lean the surface is: *the project-wide
   Lean declaration namespace — any new or renamed declaration can collide with an identically
   named one anywhere else in the library, invisible to any module-scoped build.*
3. **Have both the (single, surviving) `lean-implementation-agent.md` point at the new section
   rather than restating it**, consistent with how it already points at `long-builds.md` for the
   detach/guard mechanics rather than re-deriving them.
4. **Do not introduce a fifth tier or rename any of the four core values.** The
   `.olean`-freshness check and any `check-module-invariants.sh` build-dependent checks are
   covering checks *within* the `full` tier's action list, not separate tiers — consistent with
   `plan-format.md`'s explicit ruling that `--skip-slow` and subset narrowing are "never a fifth
   tier."
5. **Flag the "build-enabled mode" phrase as unverified from this repository** when writing the
   mapping — either confirm the actual flag/behavior against a real consumer repo's
   `check-module-invariants.sh` before citing a specific flag name, or describe it functionally
   ("whichever of this script's checks require a completed build, as opposed to a pure source-text
   scan") rather than asserting an unconfirmed flag.
6. **Correct `file_scope` for task 412** at plan time to drop the nonexistent
   `lean-implementation-hard-agent.md` entry (or replace it with nothing, since hard-mode
   contracts are injected rather than carried by a second file) rather than carrying the stale
   path forward into the plan.

## Decisions

- None made in this research phase — the dispatch explicitly withholds the mapping's actual
  authoring from research, and the phase-commit gating question itself was already decided by
  task 396 and is adopted here, not re-decided.

## Risks & Mitigations

- **Risk**: writing the mapping in a way that implies `local`/`interface` can gate a Lean phase's
  close/commit would silently reopen the cross-module-clash hole task 396 closed.
  **Mitigation**: recommendation 1 above states `full` as the sole phase-end-gating tier for
  Lean and frames `local`/`interface` purely as in-phase, non-gating density — matching the
  already-landed, unconditional wording in `lean-implementation-flow.md` Stage 4C and
  `lean-implementation-agent.md`'s MUST NOT item 3.
- **Risk**: citing an unverified "build-enabled mode" flag name for `check-module-invariants.sh`
  that does not actually exist, or exists under a different name, in a given consumer repo.
  **Mitigation**: recommendation 5 — describe the mechanism functionally unless a specific
  consumer repo's script can be inspected to confirm the flag.
- **Risk**: the plan phase edits the now-deleted `lean-implementation-hard-agent.md` because
  `file_scope` still names it. **Mitigation**: recommendation 6 — flag this explicitly so the
  plan phase corrects `file_scope` rather than attempting to write to a path that no longer
  exists (or silently widening scope without declaring it).

## Context Extension Recommendations

- **Topic**: Lean-specific Verification Tier definitions.
  **Gap**: `agent-system/extensions/lean/` has no file defining what core's four tiers mean for
  Lean; the only existing occurrence of the phrase is a cross-reference to core's own generic
  definition.
  **Recommendation**: this task's own planned edit to `lean-implementation-flow.md` (per
  Recommendations above) is the correct remedy — no separate context file is needed beyond what
  this task will produce.

## Appendix

**Search queries / commands used**:
- `jq` queries against `specs/state.json` and `specs/archive/state.json` for task 412's and task
  396's full records (dependencies, file_scope, completion_summary).
- `git log --diff-filter=D --follow --name-only -- agent-system/extensions/lean/agents/lean-implementation-hard-agent.md`
  (and the research-hard-agent counterpart) to confirm deletion provenance.
- `grep -rn "Verification Tier"` / `grep -rn "build-enabled"` / `grep -rn "check-module-invariants\|olean-freshness"`
  across `agent-system/extensions/` to establish what currently exists versus what the dispatch
  asserts.
- Read in full: `plan-format.md`'s `## Verification Tiers` section (lines ~351-540),
  `lean-implementation-flow.md` (all 225 lines), `long-builds.md` (all 240 lines),
  `plan-authoring-gate-collisions.md` (all 210 lines), and the relevant `lean-implementation-agent.md`
  phase-checkpoint and MUST-DO/MUST-NOT sections (lines ~640-780).

**References**:
- `agent-system/extensions/core/context/formats/plan-format.md` (`## Verification Tiers`)
- `agent-system/extensions/core/context/workflows/task-breakdown.md` (worked non-final `full`
  example, Phase 3)
- `agent-system/extensions/lean/context/project/lean4/agents/lean-implementation-flow.md` (Stage
  4C/4D)
- `agent-system/extensions/lean/agents/lean-implementation-agent.md` (Phase Checkpoint Protocol,
  MUST DO/MUST NOT lists)
- `agent-system/extensions/lean/context/project/lean4/operations/long-builds.md` (detach/guard
  contract, verdict-reading mechanisms)
- `agent-system/extensions/lean/context/project/lean4/patterns/plan-authoring-gate-collisions.md`
  (Condition 2, `check-module-invariants.sh` checks)
- `specs/archive/state.json` completed record for task 396
- `.claude/CLAUDE.md` `## Hard Mode (--hard)` section
