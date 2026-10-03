# Implementation Plan: Collapse Routing Ladder to routing_agents

- **Task**: 127 - Collapse routing ladder to routing agents
- **Status**: [IMPLEMENTING]
- **Effort**: 6.5 hours
- **Dependencies**: None outstanding (task 121 hard-mode file deletions and task 125 command deletions confirmed landed by research)
- **Research Inputs**: specs/127_collapse_routing_ladder_to_routing_agents/reports/01_routing-ladder-collapse.md
- **Artifacts**: plans/01_routing-ladder-collapse.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Remove the two skill-side routing blocks (`routing`, `routing_hard`) from every extension
manifest that still declares them, retire `command-route-skill.sh`, and re-scope every validator
and document that currently describes or reads those blocks. The ordering is driven by one
constraint discovered during planning: two validators **hard-fail** the moment the `routing`
block disappears, so the validator re-scope must land *before* the manifest edits, not after.
`routing_agents` and `routing_agents_hard` are untouched throughout — the post-task shape is a
two-routing-block model (`routing_agents` + `routing_agents_hard`, alongside the separate
one-level `hard_contracts` key), not a one-block model.

### Research Integration

Key findings carried into this plan:

- **`/epi` is a live caller of `command-route-skill.sh`** (`epidemiology/commands/epi.md` Step 2
  sources it). Retiring the script without migrating `epi.md` first breaks `/epi {N}` resume at
  runtime. Research verified the migration is behavior-identical: the manifest's declared value
  (`skill-epi-research`) is the same string already passed as the call's own `default_skill`
  argument. This becomes Phase 1 and strictly precedes the deletion.
- **Exact removal scope**: `routing` from 17 manifests (every non-core, non-`routing_exempt`
  extension); `routing_hard` from 2 (`cslib`, `lean`). Re-verified during planning against all
  20 manifests.
- **Work item 5 (colon-suffixed agent values) has zero live instances.** A `contains(":")` sweep
  of `routing_agents`/`routing_agents_hard` across all 20 manifests returns nothing.
  `present`'s only colon-suffixed values live in `routing.implement` (skill names) and vanish
  with the block. Resolution is to record the negative audit result, not to build an encoding.
- **Work item 6 is already implemented.** `lint-routing-wiring.sh` Check B already fails on any
  `routing_agents`/`routing_agents_hard` value naming a nonexistent agent file, and is already
  wired as `verify-deploy.sh` gate 7 (hard fail). Resolution is confirm-and-note, not build.
- **`routing_agents_hard` is out of scope for removal** — it remains live for `cslib`/`lean`
  until a separate, not-yet-dispatched follow-on migrates them onto `hard_contracts`.

Two findings this plan adds beyond the research report, established by direct inspection during
planning:

1. **`check-extension-docs.sh`'s `check_routing_block()` hard-fails on routing absence.** It
   asserts that any non-`routing_exempt` manifest declaring `provides.skills` non-empty must
   have a `routing` block, and `check-extension-docs.sh` is `verify-deploy.sh` **gate 3**
   (hard fail). Sixteen non-exempt extensions declare skills, so removing `routing` without
   re-scoping this predicate first produces sixteen gate-3 failures. The research report
   classified this file as deferrable dead code; that holds for its Rule B/C `routing_targets`
   paths but **not** for `check_routing_block`, which is blocking. This is why validator
   re-scope (Phase 2) precedes manifest edits (Phase 3).
2. **`manifest-routing-lib.sh`'s `routing_manifest_for_task_type()` has no live caller** and
   reads only `.routing.{research,plan,implement}`. Post-removal it returns empty
   unconditionally. Greps across the source store and the deployed tree found only documentation
   mentions. It is pruned in Phase 4 as part of retiring the skill-side resolution path.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch; ROADMAP.md was not consulted.

## Goals & Non-Goals

**Goals**:

- Every extension manifest declares at most `routing_agents`, `routing_agents_hard`, and
  `hard_contracts` — no `routing`, no `routing_hard`.
- `command-route-skill.sh` no longer exists, and no file sources it.
- Every validator that previously derived coverage from `routing`/`routing_hard` validates
  `routing_agents`/`routing_agents_hard` against itself instead, with no vacuously-passing check
  left behind.
- Every document that states the four-block model or the existence of `command-route-skill.sh`
  as current fact is corrected, including the CLAUDE.md merge source read every session.
- Work items 5 and 6 are closed with their audit results recorded in
  `manifest-routing-schema.md`.

**Non-Goals**:

- Removing `routing_agents_hard` from `cslib`/`lean`, or migrating them onto `hard_contracts`.
  That is a separate follow-on; `verify-deploy.sh` gate 16's warning is expected to keep firing
  for those two extensions after this task.
- Deleting the `cslib`/`lean` hard-mode SKILL.md files. They lose their routing provenance here
  but their deletion belongs to the same follow-on.
- Fixing `epi.md`'s unrelated pre-existing doc rot (prose elsewhere in the file still telling the
  user to run the deleted `/research`, `/plan`, `/implement`). Explicitly excluded — see
  Exclusions below.

## Exclusions (named, not silently dropped)

Per the research report's triage, these adjacent items are deliberately deferred. Each is
low-visibility and non-blocking; none is a correctness risk after this task lands.

| Deferred item | Why deferred |
|---|---|
| `epi.md`'s stale `/research`//`plan`//`implement` prose (outside Step 2) | Pre-existing doc rot from the command deletions, independent of routing. Fixing it would widen a load-bearing one-block edit into an unrelated rewrite. |
| `check-extension-docs.sh` Rule B/C `routing_targets` / `hard_targets` jq readers | Re-scoped in Phase 2 rather than deferred (see Phase 2) — listed here only to record that the research report's deferral recommendation was overridden, with reason. |
| `verify-deploy.sh` gate 16's *jq logic* | Needs no change: it correctly keeps warning on `cslib`/`lean`'s surviving `routing_agents_hard`. Only its comment prose is corrected (Phase 4). |

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Deleting `command-route-skill.sh` breaks `/epi {N}` resume | H | H if unsequenced | Phase 1 migrates `epi.md` first; Phase 4 gates the deletion on a repo-wide grep showing zero remaining `source`-lines |
| Removing `routing` hard-fails `verify-deploy` gate 3 (`check_routing_block`) | H | Certain if unsequenced | Phase 2 re-scopes the predicate to `routing_agents` before Phase 3 touches any manifest; Phase 2's verification asserts green with `routing` both present and absent |
| Re-scoped Check A either stops catching real gaps or false-positives on legitimately asymmetric declarations | M | M | Planning already enumerated every manifest's per-op `routing_agents` key sets. Exactly one asymmetry exists today (`present.plan` has an extra bare `slides` key absent from research/implement). The rule is therefore **research-anchored and one-directional** (research keys must appear in plan and implement; plan/implement extras are REPORTed, not failed) — which passes `present` today while still catching the silent-gap class |
| Deleting `routing_manifest_for_task_type()` breaks an unseen caller | M | L | Phase 4 re-runs the caller grep across both the source store and the deployed tree immediately before deleting, and the full gate set after |
| Scope creep from the seven-item documentation fallout list | M | M | Items folded in are enumerated per phase; items deferred are named in the Exclusions table above |
| Sibling-task contention on the shared working tree | M | L | No declared sibling `file_scope` entry intersects this task's file set (verified against the dispatch territory block). Re-read each file immediately before editing; stage explicit per-file lists only |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 2 |
| 3 | 4 | 1, 3 |
| 4 | 5, 6 | 4 (and 3, for Phase 5) |
| 5 | 7 | 5, 6 |

Phases within the same wave can execute in parallel.

### Phase 1: Migrate `/epi` off `command-route-skill.sh` [COMPLETED]

**Goal**: `/epi {N}` task-number resume resolves its research skill without the soon-retired
resolver, with identical resulting `skill_name`.

**Tasks**:
- [x] Re-read `agent-system/extensions/epidemiology/commands/epi.md` Step 2 (around line 362-372) *(completed)*
- [x] Replace the two-line `source .claude/scripts/command-route-skill.sh "research" "$task_type" "skill-epi-research" "${effort_flag:-}"` + `skill_name="$SKILL_NAME"` block with a direct `skill_name="skill-epi-research"` assignment *(completed)*
- [x] Update the prose immediately above the block (and the matching "canonical router (`command-route-skill.sh`)" sentence near line 249) to state that `epi`/`epi:study`/`epidemiology` all dispatch to the one research skill directly, with no router indirection *(completed)*
- [x] Confirm `epi` declares no `routing_hard` entry (verified during planning: it does not), so dropping `effort_flag` handling loses no behavior *(completed: confirmed via jq, manifest has no routing_hard key)*
- [x] Grep `epi.md` for any other `command-route-skill` occurrence *(completed: 0 occurrences remain)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Files to modify**:
- `agent-system/extensions/epidemiology/commands/epi.md` - replace Step 2's router `source` with a direct skill assignment; correct the two prose references to the router

**Verification**:
- `grep -c 'command-route-skill' agent-system/extensions/epidemiology/commands/epi.md` returns 0
- `bash agent-system/extensions/core/scripts/check-extension-docs.sh --quiet` is green for `epidemiology` (unchanged from before the edit)

---

### Phase 2: Re-scope the routing validators to `routing_agents` [COMPLETED]

**Goal**: Every routing validator derives its coverage from `routing_agents`/`routing_agents_hard`
alone, and passes identically whether or not a `routing` block is present. This phase is the
prerequisite that makes Phase 3 safe.

**Tasks**:
- [x] `lint-routing-wiring.sh` — replace Check A with a **research-anchored internal completeness
      check on `routing_agents`**: for each manifest, every task_type key present under
      `routing_agents.research` MUST also be present under `routing_agents.plan` and
      `routing_agents.implement` (FAIL on absence). Keys present in `plan`/`implement` but not in
      `research`, and extension-specific ops (e.g. `present`'s `critique`), are REPORTed, never
      failed *(completed)*
- [x] `lint-routing-wiring.sh` — re-scope Check C to `routing_agents_hard`'s own internal
      completeness: every task_type declared under any `routing_agents_hard.{op}` MUST have a
      same-op `routing_agents.{op}` counterpart (a hard-mode entry for a task_type standard mode
      cannot route is the gap this now catches). Do NOT require `plan` parity in
      `routing_agents_hard` — `cslib` and `lean` legitimately declare `research` + `implement`
      only *(completed)*
- [x] `lint-routing-wiring.sh` — update the script header comment block and `--help` text so the
      documented A/B/C/D contract matches the new predicates *(completed)*
- [x] `check-extension-docs.sh` — re-scope `check_routing_block()` (around line 458-479): require
      a `routing_agents` block when the manifest declares a non-empty `provides.skills` **or**
      non-empty `provides.agents`, instead of requiring `routing`. Update the failure message
      *(completed)*
- [x] `check-extension-docs.sh` — re-point Rule B/C's `routing_targets`/`hard_targets` jq readers
      (around lines 907 and 931) from `.routing`/`.routing_hard` to
      `.routing_agents`/`.routing_agents_hard`, validating against `provides.agents` + deployed
      agent files, preserving the existing three-way severity shape (not-resolvable = FAIL;
      resolvable but undeployed with extension installed = FAIL; undeployed with extension not
      installed = WARN). Update the long rationale comment block above it (around lines 838-850),
      which currently explains the severity choice in terms of `command-route-skill.sh`
      *(completed: also fixed a bug found during verification — provides.agents entries carry a
      `.md` suffix that provides.skills entries don't, so target_resolvable() now appends `.md`
      when comparing)*
- [x] Run both validators against the **current** (pre-removal) manifest state and confirm green
      *(completed: lint-routing-wiring.sh --verbose exits 0; check-extension-docs.sh's only 3
      remaining FAILs are pre-existing sibling-territory drift in claude-refresh.sh and
      literature's index-entries.json/SKILL.md -- task 217 and task 89's declared file_scope
      respectively -- not routing-related)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: Planning established that (a) exactly one per-op asymmetry exists in
`routing_agents` today — `present.plan`'s extra bare `slides` key — and (b) every non-exempt
extension already declares a `routing_agents` block, so the re-scoped `check_routing_block`
predicate passes for all 16 without further manifest edits. Confirm both at implementation time
by re-running the per-manifest key-set enumeration (`jq` over `(.routing_agents // {})` per op)
and the `provides.skills`/`provides.agents`/`has("routing_agents")` sweep before finalizing the
predicates; if a second asymmetry has appeared since, decide FAIL-vs-REPORT for it explicitly
rather than silently loosening the rule.

**Files to modify**:
- `agent-system/extensions/core/scripts/lint/lint-routing-wiring.sh` - rewrite Checks A and C; update header and `--help` contract text
- `agent-system/extensions/core/scripts/check-extension-docs.sh` - re-scope `check_routing_block()`; re-point Rule B/C target readers and their rationale comment

**Verification**:
- `bash agent-system/extensions/core/scripts/lint/lint-routing-wiring.sh --verbose` exits 0 with the current manifests; its Check A output names real `routing_agents` keys (not `routing.` keys)
- `bash agent-system/extensions/core/scripts/check-extension-docs.sh --quiet` exits 0
- Negative control: temporarily delete a `routing_agents.plan` key in a scratch copy of one manifest and confirm re-scoped Check A FAILs on it; temporarily delete a manifest's whole `routing_agents` block in a scratch copy and confirm `check_routing_block` FAILs. Restore both (scratch copies only — never the tracked manifests)
- `bash agent-system/extensions/core/scripts/tests/test-routing-resolution.sh` still passes

---

### Phase 3: Remove `routing` and `routing_hard` from every manifest [COMPLETED]

**Goal**: No extension manifest declares `routing` or `routing_hard`; `routing_agents`,
`routing_agents_hard`, and `hard_contracts` are byte-identical to before.

**Tasks**:
- [x] Re-run the block inventory sweep to confirm the 17 + 2 target set has not shifted since planning *(completed: matched exactly)*
- [x] Delete the `routing` key from each of the 17 manifests: `cslib`, `email`, `epidemiology`, `filetypes`, `formal`, `founder`, `latex`, `lean`, `memory`, `nix`, `nvim`, `present`, `python`, `rust`, `typst`, `web`, `z3` *(completed)*
- [x] Delete the `routing_hard` key from `cslib` and `lean` *(completed)*
- [x] Confirm `present`'s `routing_agents.critique` survives untouched (its `routing.critique` sibling goes with the block) *(completed: confirmed via jq)*
- [x] Confirm `core`, `literature`, `slidev` need no edit (core already collapsed; the other two are `routing_exempt`) *(completed: confirmed via has() sweep)*
- [x] Re-validate every edited manifest parses as JSON and that no sibling key was reformatted by the edit *(completed: all 17 valid JSON; rust/manifest.json's hand-compacted keywords array was incidentally reformatted by jq's pretty-printer on the first pass and rewritten by hand to restore it -- see progress file approaches_tried)*

**Timing**: 0.75 hours

**Depends on**: 2

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: 17 manifests carry `routing`; 2 of those (`cslib`, `lean`) additionally
carry `routing_hard`; `literature` and `slidev` are `routing_exempt` and `core` is already
collapsed. Confirm at implementation time with
`for m in agent-system/extensions/*/manifest.json; do jq -r '[input_filename, (has("routing")|tostring), (has("routing_hard")|tostring)] | @tsv' "$m"; done` before and after, and reconcile any discrepancy against this list before proceeding.

**Files to modify**:
- `agent-system/extensions/cslib/manifest.json` - drop `routing` and `routing_hard`
- `agent-system/extensions/lean/manifest.json` - drop `routing` and `routing_hard`
- `agent-system/extensions/email/manifest.json` - drop `routing`
- `agent-system/extensions/epidemiology/manifest.json` - drop `routing`
- `agent-system/extensions/filetypes/manifest.json` - drop `routing`
- `agent-system/extensions/formal/manifest.json` - drop `routing`
- `agent-system/extensions/founder/manifest.json` - drop `routing`
- `agent-system/extensions/latex/manifest.json` - drop `routing`
- `agent-system/extensions/memory/manifest.json` - drop `routing`
- `agent-system/extensions/nix/manifest.json` - drop `routing`
- `agent-system/extensions/nvim/manifest.json` - drop `routing`
- `agent-system/extensions/present/manifest.json` - drop `routing` (including its `critique` op); keep `routing_agents.critique`
- `agent-system/extensions/python/manifest.json` - drop `routing`
- `agent-system/extensions/rust/manifest.json` - drop `routing`
- `agent-system/extensions/typst/manifest.json` - drop `routing`
- `agent-system/extensions/web/manifest.json` - drop `routing`
- `agent-system/extensions/z3/manifest.json` - drop `routing`

**Verification**:
- `jq -e 'has("routing") or has("routing_hard")' agent-system/extensions/*/manifest.json` matches nothing *(confirmed: 0)*
- `jq -e . agent-system/extensions/*/manifest.json > /dev/null` on every manifest (valid JSON) *(confirmed)*
- `git diff` on each manifest shows removed `routing`/`routing_hard` hunks only — no `routing_agents` line touched *(confirmed; rust/manifest.json needed a hand-rewrite to avoid jq's pretty-printer reformatting an unrelated inline array — see progress file)*
- `bash agent-system/extensions/core/scripts/lint/lint-routing-wiring.sh --verbose` and `bash agent-system/extensions/core/scripts/check-extension-docs.sh --quiet` both still exit 0 (this is the Phase 2 pre-work paying off) *(confirmed at deploy time: lint-routing-wiring.sh exits 0; check-extension-docs.sh gate 3 was PASS in the deploy-headless.sh run captured below. A later ad hoc re-run showed 2 FAILs, both `scripts/claude-refresh.sh`/`scripts/tests/test-claude-refresh-matcher.sh` deployed-content-drift from task 217's concurrently in-flight source edits -- declared sibling territory, not routing-related, not a regression from this phase)*
- Full gate set: deploy + `bash .claude/scripts/verify-deploy.sh` (gate 3 and gate 7 green; gate 16 still warns for `cslib`/`lean`, which is expected) *(confirmed via deploy-headless.sh: gate 3 PASS, gate 7 PASS, gate 16 WARN for `lean` (`cslib` is not a loaded/installed extension in this deploy so emits no row); the run's only 2 failures were sibling-territory drift as above)*

---

### Phase 4: Retire `command-route-skill.sh` and prune the dead skill-side resolution path [COMPLETED]

**Goal**: The skill-side resolver, its manifest declaration, its now-callerless library helper,
and the one-line references to it in enumerations are gone; the resolution test is retargeted
rather than left silently hollow.

**Tasks**:
- [x] Re-run `grep -rn 'command-route-skill' agent-system/` and confirm the only remaining
      occurrences are the ones this phase deletes or rewrites (Phase 1 cleared `epi.md`;
      Phases 5-6 own the documents) *(completed: 13 non-.sh occurrences remain; 10 match the
      plan's named Phase 5/6 files exactly, but 3 extra files were NOT accounted for by either
      phase's Files-to-modify list -- research-flow-example.md, adding-domains.md,
      extension-development.md. Recorded as a deviation in the progress file; deferred to Phase
      6's scope since Phase 6's own verification requires zero occurrences repo-wide)*
- [x] Delete `agent-system/extensions/core/scripts/command-route-skill.sh` *(completed)*
- [x] Remove `"command-route-skill.sh"` from `core/manifest.json`'s `provides.scripts` array *(completed)*
- [x] Delete `routing_manifest_for_task_type()` from `manifest-routing-lib.sh` (no live caller;
      reads only the now-deleted `routing` block) and remove its usage-example line from the
      library header *(completed)*
- [x] Update `manifest-routing-lib.sh`'s header prose that describes the ladder as serving
      `command-route-skill.sh` and `.routing`/`.routing_hard` *(completed: also fixed 2 more
      header mentions beyond the ones the plan called out, at the "Manifest source" and
      `routing_trace` comments)*
- [x] Retarget `test-routing-resolution.sh`: remove Assert 1 (it built its matrix from
      `.routing`/`.routing_hard` and exercised the deleted resolver), keep Assert 2
      (`routing_agents`/`routing_agents_hard` via `command-route-agent.sh`), and update the
      file header plus the now-obsolete "one surviving `command-route-skill.sh` caller" comment
      *(completed)*
- [x] Remove `scripts/command-route-skill.sh` from `shell-strict-mode.md`'s sourced-scripts enumeration *(completed)*
- [x] Correct `verify-deploy.sh` gate 16's comment prose (around lines 886-890) so it no longer
      claims both blocks are consulted by `command-route-skill.sh`; state that only
      `routing_agents_hard` survives and name the remaining follow-on as the gate's destination.
      Leave the gate's jq logic unchanged *(completed; jq logic untouched)*
- [x] Confirm the deleted script is absent from `script-inventory.sh` and
      `utility-scripts-inventory.md` (verified during planning: it is not listed in either, and
      both files belong to a concurrent sibling's territory — do not edit them) *(completed:
      confirmed via grep, zero hits; no edit made)*
- [x] *(deviation: added -- not in original task list)* Reword 3 comment-only
      `command-route-skill.sh` mentions in `command-route-agent.sh` and 1 in
      `test-routing-resolution.sh`'s own new header comment, discovered necessary because this
      phase's own verification requires zero `command-route-skill` occurrences in any `.sh` file
      repo-wide, not only in the deleted script itself

**Timing**: 1 hour

**Depends on**: 1, 3

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: `routing_manifest_for_task_type()` has zero live callers and
`command-route-skill.sh` has exactly one live source-line caller (cleared in Phase 1), with all
other occurrences being documentation. Confirm at implementation time by re-running
`grep -rn 'routing_manifest_for_task_type' agent-system/ .claude/` and
`grep -rn 'command-route-skill' agent-system/` immediately before each deletion, and stop if
either turns up an executable caller this plan has not accounted for.

**Files to modify**:
- `agent-system/extensions/core/scripts/command-route-skill.sh` - delete
- `agent-system/extensions/core/manifest.json` - drop `command-route-skill.sh` from `provides.scripts`
- `agent-system/extensions/core/scripts/lib/manifest-routing-lib.sh` - delete `routing_manifest_for_task_type()`; correct header prose
- `agent-system/extensions/core/scripts/tests/test-routing-resolution.sh` - drop Assert 1, keep Assert 2, update header and stale caller comment
- `agent-system/extensions/core/context/standards/shell-strict-mode.md` - remove the script from the sourced-scripts enumeration
- `agent-system/extensions/core/scripts/verify-deploy.sh` - correct gate 16's comment prose only
- *(deviation: added)* `agent-system/extensions/core/scripts/command-route-agent.sh` - reword 3 comment-only `command-route-skill.sh` mentions (required for the "zero in any .sh file" verification bullet below)
- *(deviation: added)* `agent-system/extensions/cslib/skills/skill-cslib-research-hard/SKILL.md`, `skill-cslib-implementation-hard/SKILL.md`, `agent-system/extensions/lean/skills/skill-lean-research-hard/SKILL.md`, `skill-lean-implementation-hard/SKILL.md` - pulled forward from Phase 6: corrected the 4 stale routing-provenance lines (the plan's own Phase 6 wording), because leaving them unedited broke `check-extension-docs.sh`'s undeclared-script-reference check the moment `command-route-skill.sh` was deleted, failing this phase's own "full gate set green" criterion

**Verification**:
- `grep -rn 'command-route-skill' agent-system/` returns only occurrences owned by Phases 5-6 (schema doc, hard-mode guide, claudemd merge source, creating-commands, command-template, index-entries), and zero in any `.sh` file *(confirmed, after also fixing command-route-agent.sh's 3 comments and this file's own new header comment -- see progress file deviations. Note: 3 further non-.sh occurrences exist beyond the plan's named list -- research-flow-example.md, adding-domains.md, extension-development.md -- deferred to Phase 6, recorded as a separate deviation)*
- `grep -rn 'routing_manifest_for_task_type' agent-system/` returns only the schema-doc mentions Phase 5 rewrites *(confirmed: exactly 1 hit, manifest-routing-schema.md)*
- `bash -n` clean on every edited shell script; `bash agent-system/extensions/core/scripts/tests/test-routing-resolution.sh` passes *(confirmed: 13/13 assertions pass)*
- Full gate set: deploy + `bash .claude/scripts/verify-deploy.sh` green (confirms `provides.scripts` no longer references a missing file) *(confirmed: gate 3, gate 7, and gate 13 (orphan detection) all green after also removing the stale deployed `.claude/scripts/command-route-skill.sh`, which the additive-only copy engine left behind -- see progress file deviations; gate 16 WARN for `lean` as expected. The only 2 remaining FAILs are task 217's in-flight `claude-refresh.sh`/`test-claude-refresh-matcher.sh` content drift, confirmed sibling territory)*

---

### Phase 5: Rewrite `manifest-routing-schema.md` and the CLAUDE.md merge source [COMPLETED]

**Goal**: The authoritative routing schema document and the highest-visibility generated prose
(read every session via CLAUDE.md) describe the collapsed model, and the work-item 5/6 audit
results are recorded where a future reviewer will find them.

**Tasks**:
- [x] `manifest-routing-schema.md` — retitle and rewrite "The Five Blocks" (line 17) as the
      surviving three keys: `routing_agents`, `routing_agents_hard`, `hard_contracts`. State
      explicitly that this is **two routing blocks plus one unrelated one-level key**, so a
      future reader is not left reconciling "two-block" against a three-row table *(completed)*
- [x] `manifest-routing-schema.md` — rewrite "The Single Five-Step Ladder" (line 87) and the
      `-hard` append-fallback subsection (line 112) to drop skill resolution and
      `command-route-skill.sh`'s Step 4e, which no longer exists *(completed)*
- [x] `manifest-routing-schema.md` — replace the completeness-rule paragraph with the Phase 2
      re-scoped Check A/C contract (research-anchored `routing_agents` completeness;
      `routing_agents_hard` counterpart check), so doc and lint agree *(completed)*
- [x] `manifest-routing-schema.md` — rewrite "`.task_type` (singular) vs. `.routing.{op}` keys"
      (line 144) in terms of `routing_agents.{op}` keys, and drop the two
      `routing_manifest_for_task_type()` references (lines 150, 158) now that the helper is gone *(completed)*
- [x] `manifest-routing-schema.md` — under "Agent Names Are Declared, Never Derived" (line 164),
      record the **work item 5 negative audit result**: no `routing_agents`/`routing_agents_hard`
      value anywhere carries a colon suffix, and the sweep to re-run
      (`contains(":")` over both blocks across all manifests) before re-opening the question *(completed)*
- [x] `manifest-routing-schema.md` — record the **work item 6 confirmation**: Check B plus
      `verify-deploy` gate 7 already make a nonexistent-agent declaration a hard deploy failure *(completed)*
- [x] `manifest-routing-schema.md` — update "Adding Routing to a New Extension" (line 196) so its
      sample JSON shows `routing_agents` only, and "Related Files" (line 221) so it no longer
      lists `command-route-skill.sh` or the deleted commands *(completed)*
- [x] `merge-sources/claudemd.md` — rewrite the "Routing Mechanism" section (around lines
      215-222): drop `command-route-skill.sh`, correct the block count, and keep the pointer to
      `manifest-routing-schema.md` and `hard-mode-routing.md` *(completed: also corrected an
      adjacent stale "routing_hard" mention in the Composability bullet -- see progress file)*
- [x] `core/index-entries.json` — update the `guides/manifest-routing-schema.md` and
      `guides/hard-mode-routing.md` entries (around lines 2733-2763): drop the
      `command-route-skill` keyword from both and rewrite the hard-mode-routing summary that
      currently describes it as "used by command-route-skill.sh for --hard" *(completed; also
      updated manifest-routing-schema.md's line_count to 269 to match its rewritten length)*

**Timing**: 1 hour

**Depends on**: 3, 4

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: the schema document's edit surface is the seven sections enumerated above
(lines 17, 87, 112, 144, 164, 196, 221 in the current file) and the two `index-entries.json`
objects at lines 2733-2763. Confirm at implementation time by re-grepping
`routing\b|routing_hard|command-route-skill|Five Blocks|routing_manifest_for_task_type` across
both files and reconciling every hit against this list before declaring the phase done — line
numbers will have shifted if a sibling touched these files.

**Files to modify**:
- `agent-system/extensions/core/context/guides/manifest-routing-schema.md` - rewrite to the collapsed model; record the item-5 and item-6 audit results
- `agent-system/extensions/core/merge-sources/claudemd.md` - correct the generated "Routing Mechanism" section
- `agent-system/extensions/core/index-entries.json` - correct the two routing-guide entries' summary and keywords

**Verification**:
- `grep -n 'command-route-skill\|routing_hard\|routing_manifest_for_task_type' agent-system/extensions/core/context/guides/manifest-routing-schema.md` returns only intentional historical/`routing_agents_hard` mentions *(confirmed: 5 hits, all historical-context prose explaining what was retired)*
- `jq -e . agent-system/extensions/core/index-entries.json > /dev/null` *(confirmed valid)*
- `bash agent-system/extensions/core/scripts/validate-context-index.sh` passes *(confirmed: 286 entries, 0 errors, 0 warnings)*
- `bash agent-system/extensions/core/scripts/check-task-references.sh` clean (no task numbers introduced into any deliverable) *(confirmed: 0 occurrences)*
- Deploy and confirm the generated `.claude/CLAUDE.md` "Routing Mechanism" section reads correctly *(confirmed: reads correctly, references command-route-agent.sh only)*

---

### Phase 6: Scoped rewrite of `hard-mode-routing.md` and the command-authoring guidance [COMPLETED]

**Goal**: No document teaches an author to write against the retired resolver or to add a
`routing_hard` block; the surviving `routing_agents_hard` semantics stay documented.

**Tasks**:
- [x] `hard-mode-routing.md` — strip the `command-route-skill.sh`/`routing_hard` content: the
      skill half of "5-Step Resolution Precedence" (line 29), the "SKILL.md Existence Safety Gate
      (Step 4e Only)" section (line 85) and its code block, and the "Adding routing_hard Entries"
      how-to (line 138), which would otherwise teach an author to populate a block no consumer
      reads *(completed)*
- [x] `hard-mode-routing.md` — keep and tighten the still-accurate agent-side content:
      `routing_agents_hard` resolution semantics, the `-hard` agent fallback, the
      "Extension Overrides Core" rule (line 62), and "Orchestrate Hard Mode: One Engine,
      Effort-Gated" (line 127). Update "Deployed Hard Skills (current inventory)" (line 107) and
      "Related Files" (line 164) accordingly *(completed)*
- [x] `hard-mode-routing.md` — add a one-line pointer stating that `routing_agents_hard` is
      transitional for `cslib`/`lean` and that `hard_contracts` is its successor mechanism, so
      `verify-deploy` gate 16's warning has a discoverable destination *(completed)*
- [x] `docs/guides/creating-commands.md` (around lines 103-107) — replace the
      `source command-route-skill.sh` + Skill-tool "STAGE 2: DELEGATE" pattern with the live
      `command-route-agent.sh` + direct-agent-dispatch convention *(completed)*
- [x] `docs/templates/command-template.md` (around line 53) — same replacement, so a copied
      template produces a working command *(completed)*
- [x] Check the four `cslib`/`lean` hard SKILL.md provenance lines that cite
      `command-route-skill.sh`/`routing_hard` as their routing source. Correct each to state the
      skill is no longer routing-reachable and is pending the `hard_contracts` follow-on — a
      prose-only provenance correction; do NOT delete the skills or touch their behavior
      *(completed: pulled forward into Phase 4 already, re-verified here with no re-edit needed)*
- [x] *(deviation: added)* Fixed 7 additional files carrying stale `command-route-skill`/
      `routing_hard` mentions beyond the plan's named Files-to-modify lists, discovered by the
      final repo-wide grep sweep: `research-flow-example.md`, `adding-domains.md`,
      `extension-development.md` (carried forward from a Phase 4 deviation), plus
      `cslib/README.md`, `copy-claude-directory.md`, `check-extension-docs.sh`'s Rule B/C
      index-comment, and `manifest-routing-lib.sh`'s two header comments. Also reworded 4
      literal `command-route-skill.sh` name mentions inside `manifest-routing-schema.md`/
      `hard-mode-routing.md`'s own historical-explanation prose, since this phase's own
      verification requires true zero occurrences repo-wide (stricter than Phase 4/5's
      "only historical mentions" carve-out) — see progress file for full detail

**Timing**: 1 hour

**Depends on**: 4

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: six files carry author-facing `command-route-skill.sh`/`routing_hard`
guidance: `hard-mode-routing.md`, `creating-commands.md`, `command-template.md`, and the four
`cslib`/`lean` hard SKILL.md files (seven files counting all four skills). Confirm at
implementation time with `grep -rln 'command-route-skill\|routing_hard' agent-system/` after
Phase 5 lands and reconcile the result against this list; any additional hit is either a
Phase 5 file or an unaccounted-for occurrence to triage explicitly.

**Files to modify**:
- `agent-system/extensions/core/context/guides/hard-mode-routing.md` - strip skill-side/`routing_hard` sections; keep and tighten `routing_agents_hard` content; add the `hard_contracts` successor pointer
- `agent-system/extensions/core/docs/guides/creating-commands.md` - replace the delegate pattern with `command-route-agent.sh` + direct agent dispatch
- `agent-system/extensions/core/docs/templates/command-template.md` - same replacement
- `agent-system/extensions/cslib/skills/skill-cslib-research-hard/SKILL.md` - correct the routing-provenance line
- `agent-system/extensions/cslib/skills/skill-cslib-implementation-hard/SKILL.md` - correct the routing-provenance line
- `agent-system/extensions/lean/skills/skill-lean-research-hard/SKILL.md` - correct the routing-provenance line
- `agent-system/extensions/lean/skills/skill-lean-implementation-hard/SKILL.md` - correct the routing-provenance line
- *(deviation: added)* `agent-system/extensions/core/docs/examples/research-flow-example.md`, `agent-system/extensions/core/docs/guides/adding-domains.md`, `agent-system/extensions/core/context/guides/extension-development.md`, `agent-system/extensions/cslib/README.md`, `agent-system/extensions/core/docs/guides/copy-claude-directory.md`, `agent-system/extensions/core/scripts/check-extension-docs.sh`, `agent-system/extensions/core/scripts/lib/manifest-routing-lib.sh` - fixed additional stale `command-route-skill`/`routing_hard` mentions not named in the plan's own file lists (see progress file deviations)

**Verification**:
- Diff read-through confirming every changed hunk is prose or a non-executing fenced example *(confirmed via git diff read-through of all 12 touched files)*
- `grep -rn 'command-route-skill' agent-system/` returns zero occurrences repo-wide *(confirmed: 0, after also rewording 4 literal mentions in manifest-routing-schema.md/hard-mode-routing.md's own historical prose -- see progress file)*
- `grep -rn 'routing_hard' agent-system/` returns only `routing_agents_hard` matches *(confirmed: remaining 11 hits are all historical-explanation prose co-occurring with `routing_agents_hard` on the same line/paragraph, or provenance corrections)*
- `bash agent-system/extensions/core/scripts/check-extension-docs.sh --quiet` exits 0 (catches broken cross-references in the edited docs) *(the only FAIL present is task 217's in-flight test-claude-refresh-matcher.sh content drift -- confirmed sibling territory, not routing-related)*
- `bash agent-system/extensions/core/scripts/check-task-references.sh` clean *(confirmed: 0 occurrences)*

---

### Phase 7: Final verification and audit closure [NOT STARTED]

**Goal**: The whole collapse is verified end to end under the real gate set, and the two
audit-only work items are closed with recorded evidence.

**Tasks**:
- [ ] Deploy the source store and run `bash .claude/scripts/verify-deploy.sh` in full; confirm
      gates 3, 7, and 16 behave as designed (3 and 7 green; 16 warning only for `cslib`/`lean`)
- [ ] Run `lint-routing-wiring.sh --verbose`, `check-extension-docs.sh`,
      `test-routing-resolution.sh`, `validate-context-index.sh`, and `check-task-references.sh`
- [ ] Re-run the work-item-5 sweep (`contains(":")` over `routing_agents` and
      `routing_agents_hard` across all manifests) and record the result; confirm it still matches
      the note written in Phase 5
- [ ] Re-confirm work item 6: temporarily point one manifest's `routing_agents` value at a
      nonexistent agent in a scratch copy, confirm Check B FAILs and that `verify-deploy` gate 7
      would fail on it, then restore
- [ ] Confirm `/epi {N}` resume reads correctly end to end (Step 2's direct assignment plus the
      Skill-tool invocation it feeds)
- [ ] Confirm no deliverable outside `specs/**` gained a task-number reference

**Timing**: 0.75 hours

**Depends on**: 5, 6

**Verification Tier**: full

**Commit Mode**: per-substep

**Files to modify**:
- none planned (verification-only; any file touched here is a defect fix attributed to its owning phase)

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` exits 0
- All five lint/test scripts above exit 0
- Negative-control checks for Check A, `check_routing_block`, and Check B each FAIL on an injected scratch-copy defect and pass once restored

---

## Testing & Validation

- [ ] `jq -e 'has("routing") or has("routing_hard")'` matches zero manifests
- [ ] `grep -rn 'command-route-skill' agent-system/` returns zero occurrences
- [ ] `grep -rn 'routing_manifest_for_task_type' agent-system/ .claude/` returns zero occurrences
- [ ] `bash .claude/scripts/verify-deploy.sh` exits 0 (gate 3 and gate 7 green; gate 16 warns for `cslib`/`lean` only)
- [ ] `lint-routing-wiring.sh --verbose` exits 0 and its Check A/C output names `routing_agents`/`routing_agents_hard` keys
- [ ] Re-scoped Check A, `check_routing_block`, and Check B each FAIL on an injected scratch-copy defect (negative controls)
- [ ] `test-routing-resolution.sh`, `check-extension-docs.sh`, `validate-context-index.sh`, `check-task-references.sh` all pass
- [ ] Every edited manifest and `index-entries.json` is valid JSON
- [ ] Generated `.claude/CLAUDE.md` "Routing Mechanism" section describes the collapsed model

## Artifacts & Outputs

- 17 manifests with `routing` removed; 2 of those additionally with `routing_hard` removed
- `command-route-skill.sh` deleted and de-declared from `core/manifest.json`
- `routing_manifest_for_task_type()` removed from `manifest-routing-lib.sh`
- Re-scoped `lint-routing-wiring.sh` Checks A and C; re-scoped `check-extension-docs.sh`
  `check_routing_block()` and Rule B/C readers
- `test-routing-resolution.sh` retargeted to agent-side resolution only
- Rewritten `manifest-routing-schema.md` (collapsed model + item-5/item-6 audit records),
  corrected `merge-sources/claudemd.md`, scoped-rewritten `hard-mode-routing.md`, corrected
  `creating-commands.md`, `command-template.md`, `shell-strict-mode.md`, `verify-deploy.sh`
  gate-16 comment, `index-entries.json`, `epi.md`, and the four `cslib`/`lean` hard-skill
  provenance lines
- Task summary artifact at implementation close

## Rollback/Contingency

- Every phase is its own commit (`per-substep` throughout), so any single phase reverts with a
  targeted `git revert` of its commits without disturbing the others.
- If the Phase 2 re-scope proves wrong after Phase 3 has landed, the recovery is forward:
  correct the predicate, not restore the manifest blocks (the blocks have no consumer left once
  Phase 4 lands).
- If an unaccounted-for executable caller of `command-route-skill.sh` surfaces during Phase 4,
  stop before the deletion, migrate that caller the same way Phase 1 migrated `epi.md`, and
  resume. Phases 1-3 are independently valuable and need no rollback in that case.
- Before any risky edit, take a non-reverting checkpoint
  (`bash .claude/scripts/git-snapshot.sh 127 --no-revert`); the reverting default form is for a
  genuine rollback only.
