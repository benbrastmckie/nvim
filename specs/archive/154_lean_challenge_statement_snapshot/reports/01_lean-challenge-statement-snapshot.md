# Research Report: Task #154

**Task**: 154 - Make lean plans carry exact theorem statements and emit an immutable trusted Challenge snapshot
**Started**: 2026-09-07T00:00:00Z
**Completed**: 2026-09-07T00:00:00Z
**Effort**: Medium (one new script + one new plan-format section + one rule amendment)
**Dependencies**: None (wave 1; task 155 and 156 depend on this task's output shape)
**Sources/Inputs**: Codebase (lean-comparator-run.sh, its design record, its test fixtures, plan-format.md, plan-compliance.md, lean-implementation-agent.md, proof-debt-policy.md), state.json (sibling tasks 153/155/156)
**Artifacts**: specs/154_lean_challenge_statement_snapshot/reports/01_lean-challenge-statement-snapshot.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Decision: R1, additive-only, not R2.** The Challenge is generated from a new, lean-only plan
  section (`## Lean Challenge Statements`) carrying literal `` ```lean ``-fenced signatures with
  forced `sorry` bodies. R2 (extracting whatever already sits in the git tree at the
  plan-approval commit) is demoted to an optional, loudly-degraded fallback for legacy plans
  only, never the primary route, because it structurally cannot serve a greenfield theorem — the
  exact case this whole task exists to close.
- The new section is **additive to plan-format.md**, gated on `task_type: lean`/`lean4`, so
  every non-lean plan's shape is provably untouched — this directly answers the dispatch's stated
  cost concern about touching a format "consumed by every task type."
- **Immutability is a git-history property, not a filesystem-permission property.**
  `lean-comparator-run.sh` already takes `--commit REF` and checks out a `git worktree` at that
  exact SHA — a Challenge is only ever as mutable as the commit graph. `lean-challenge-snapshot.sh`
  therefore *commits* the snapshot as its own commit, records the resulting SHA in a small
  manifest under `specs/`, and refuses to re-run once the task's `state.json` status has advanced
  past `planned` — so "regeneration after implementation started" is a loud, gated refusal, not a
  silent overwrite, and even a bypassed refusal cannot retroactively change a SHA already recorded
  in the manifest.
- `plan-compliance.md` **should** gain a statement-fidelity clause: today it makes the plan's
  *decomposition* the contract but is silent on whether a declaration's *signature* is part of
  that contract. A `## Lean Challenge Statements` block, once it exists, is exactly the missing
  textual contract, and a mechanical (grep/diff) fidelity check against it is available as a cheap
  interim gate independent of whether Comparator is ever wired in — the task description's stated
  "independent value."
- Task boundary: this task owns the Challenge module and its theorem-name/commit manifest only.
  Synthesizing a `Solution.lean` module from the implemented `Theories/` declarations and invoking
  `lean-comparator-run.sh` is explicitly task 155's concern (`--compare` flag threading); this
  report flags the interface task 155 will need but does not design it.

## Context & Scope

The task sits in the Comparator integration wave (`leanprover/comparator`, vendored/wrapped by
task 153's `lean-comparator-run.sh`, already merged). Comparator requires a **trusted Challenge**
— a module naming the exact intended theorem statements, bodies optionally `sorry` — against
which an untrusted `Solution.lean` is compared. Nothing in this codebase produces that Challenge
today (constraint C1 in the shared task background): plans record goal *identifiers* only
(`- **Goals**: ... proves \`comm\` ...`), and `lean-implementation-agent.md`'s own compliance
check is a name-existence grep, not a statement check. This is also independently the system's
weakest verification gate regardless of whether Comparator is ever promoted to a hard gate: a
weakened restatement with the same name passes silently today.

Scope for this task, per `file_scope` in `state.json`: the new snapshot script and its test,
`rules/plan-compliance.md`, `context/formats/plan-format.md` (core, shared), and
`lean/manifest.json` (registration). Out of scope: wiring the snapshot into any completion gate
(task 155/156), and provisioning any of the still-missing Comparator binaries (a separate,
already-noted non-goal on the sibling tasks).

## Findings

### Codebase Patterns

**How `lean-comparator-run.sh` actually consumes a Challenge** (read directly from the script and
its design record, `agent-system/extensions/lean/context/project/lean4/domain/comparator-integration.md`):

- `--project-root DIR --commit REF` selects a `git worktree add --detach $WORKDIR $COMMIT_REF` —
  **one commit ref for the whole worktree**. Both `--challenge-module NAME` and
  `--solution-module NAME` name files/lean_libs that must **already exist in that commit's git
  tree**; the runner never creates their `.lean` content itself, only a `lakefile.toml`
  declaring them as `lean_lib` targets when the project's own lakefile does not already do so.
  Concretely, this means a Challenge is real Lean source, tracked and committed in the target
  project's own repository — not a specs-side artifact copied in at check time.
- The vendored/authored fixtures (`tests/fixtures/comparator/{simple_match,def_hole_axiom_issue,statement_weakened}/Challenge.lean`)
  confirm the module shape: a small, standalone file containing only the named declarations
  (bodies `sorry` in every Challenge fixture), no unrelated content.
- The design record's clean-room decision already establishes the immutability primitive this
  task needs: checking out `--commit REF` retrieves exactly the bytes committed at that SHA
  regardless of what the working tree or `HEAD` looks like afterward. This task does not need to
  invent an immutability mechanism from scratch — it needs to *use* the one `lean-comparator-run.sh`
  already assumes, by committing the Challenge and recording the SHA.

**How goal identifiers are read today** (`lean-implementation-agent.md`'s Final Verification
Stage, step 5): `sed -n '/^\*\*Goals\*\*:/,/^\*\*[^G]/p' "$plan_file" | grep -oP '`[a-zA-Z_][a-zA-Z0-9_'"'"']*`'`
— a backtick-delimited identifier list under the plan's `**Goals**:` bullet block (per
`plan-format.md`'s `## Goals & Non-Goals` structure). This regex is the existing, load-bearing
convention for "which declarations does this plan promise" and is reused unchanged as the source
of `theorem_names` in this task's design (see Decisions) — no new identifier-naming convention is
introduced.

**No genuine lean theorem-proving plan currently exists in this repository's `specs/` tree** —
every plan matching `task_type: lean` found in this pass (`153`, `137`) is itself a meta task
*about* lean tooling, not a proof task. This means there is no live example of a
`**Goals**:` block naming real theorem identifiers to check the new section against; the design
below is validated against the script/fixture contract instead, and the plan phase should budget
for constructing (or reusing) a real target Lean project (e.g. one of
`~/Projects/{BimodalLogic,cslib}`, both of which have real `.lean` sources and git history) for
the acceptance demonstrations the dispatch requires.

**`proof-debt-policy.md`** already states the zero-debt completion requirement this task's
statement-fidelity work is one layer of enforcement for, but currently only names sorries, axioms,
and build-pass as gated properties — it does not mention statement fidelity at all, confirming the
gap named in the dispatch.

### External Resources

- Upstream `leanprover/comparator` README (already fully digested by task 153's design record;
  no new upstream reading was needed for this task — the two open questions this task must answer,
  R1-vs-R2 and immutability, are both about *this* system's plan/state machinery, not about
  Comparator's own contract).

### Recommendations

**1. R1 vs R2 — decision and reasoning.**

| | R1 (plan-declared) | R2 (git-baseline extraction) |
|---|---|---|
| Greenfield theorem (no existing declaration) | Works — the plan is written before any code exists | **Cannot work** — nothing to extract; the dispatch itself names this as R2's fallback-requiring gap |
| Cost to shared format | Touches `plan-format.md`, but additively and gated on task type | None to `plan-format.md` |
| Fidelity to planner intent | Exact — the planner writes the literal signature | Only as good as whatever partial/sorry declaration already happens to sit in the tree; a plan that *changes* an existing signature (e.g., generalizing a hypothesis) would extract the **old**, wrong statement |
| Mechanism complexity | A markdown section + fenced-block extraction (text parsing, well-trodden in this codebase — same class of operation as the existing Goals regex) | A git-history walk plus a declaration-boundary extractor from raw Lean source (harder: brace/`:=`-balanced parsing, multi-line signatures, attributes/`@[...]` prefixes) |
| Requires import-context reconstruction | Planner supplies imports directly in the fenced block | Extractor must also lift the source file's own `import` lines, or the extracted signature may not type-check standalone |

R1 wins primarily because **R2 cannot serve the greenfield case at all**, and the dispatch's own
framing makes clear this is not a corner case — most proof tasks in this system start from a goal
identifier with no existing partial declaration. A route that only sometimes produces a Challenge
is not a foundation task 155/156 can build a uniform `--compare` flag on top of.

**Decision (recommended for the plan phase): R1 primary, R2 demoted to an explicitly-logged,
loudly-degraded fallback** — used only when a lean plan predates this feature (no
`## Lean Challenge Statements` section present) *and* every named goal identifier already exists
as a declaration in the target project's tree at the plan's approval commit. When a name is
missing from both the plan section and the tree, the snapshot script must fail loudly
(`config_error`-shaped exit) rather than silently omitting that theorem from the Challenge — an
incomplete Challenge that Comparator would silently accept as "no theorem named here to check" is
worse than an explicit refusal.

**2. The new plan section (R1 mechanism).**

Add `## Lean Challenge Statements` to `context/formats/plan-format.md` as a **new, additive**
top-level section, documented as present only when the plan's `task_type` is `lean`/`lean4`
(mirroring how `## Planned Strategic Sorries` is already gated on `plan_metadata.skeleton` —
precedent for a conditionally-present section already exists in this exact file). Shape:

```
## Lean Challenge Statements

```lean
import Mathlib.Algebra.Group.Basic

theorem comm (n m : Nat) : n + m = m + n := sorry
```
```

One or more fenced ```lean blocks; concatenated in order they form the Challenge module body.
Every identifier that appears in this section's declarations MUST be a subset of (recommendation:
exactly equal to) the identifiers already named under `**Goals**:` — the plan phase should decide
whether to make this a hard planner-time validation or a snapshot-time warning; this research task
does not need to settle it, only flag it as a phase-1 decision point.

**Why an additive new section beats amending `**Goals**:` itself**: `**Goals**:` bullets are prose
today and are consumed by every task type's plan-format contract, including non-lean ones. A new,
independently-gated section leaves that shared bullet format completely untouched, which is the
literal cost concern the dispatch asks to be addressed ("touches a core format consumed by every
task type, so scope the change so non-lean plans are unaffected").

**3. `lean-challenge-snapshot.sh` design.**

```
lean-challenge-snapshot.sh <task_number> <project_root> [--commit REF] [--challenge-module NAME] [--force]
```

Flow:
1. Resolve the task's plan file the same way `lean-implementation-agent.md` already does
   (`specs/{padded}_{slug}/plans/*.md`, `sort -V | tail -1`).
2. Read `state.json`'s status for `task_number`. **Refuse to write or overwrite an existing
   snapshot manifest whenever status is anything past `planned`** (i.e. `implementing`,
   `pr_ready`, `completed`, ...), unless `--force` is passed. Even with `--force`, a status past
   `planned` should print a loud, named warning naming exactly the risk (the demonstration the
   dispatch's acceptance criteria call for) — never a silent success.
3. Extract identifiers from `**Goals**:` via the existing backtick regex (reused verbatim, not
   reinvented) — this is `theorem_names`.
4. **R1 primary path**: extract every ```lean fenced block under `## Lean Challenge Statements`
   and concatenate as the Challenge module body.
   **R2 fallback path** (only when step 4's section is absent): for each name in `theorem_names`,
   resolve the commit at which the plan file was last modified (`git log -1 --format=%H -- <plan_path>`)
   and `git show <that-commit>:<path>` the declaration containing it, forcing its body to `sorry`
   regardless of what is actually there (a Challenge pins statements only, never a body — this
   also sidesteps ever accidentally leaking a real, already-known proof into a "trusted" artifact
   whose only job is the statement). A name resolvable in neither path is a hard failure naming the
   specific missing identifier, not a partial Challenge.
5. Write the assembled module as `Challenge.lean` at the target project's root (or wherever
   `--challenge-module` names, matching `lean-comparator-run.sh`'s own module-name argument) and
   `git add` + `git commit` it as an isolated commit, message
   `task {N}: snapshot lean challenge statements` (fits the existing git-workflow convention for
   task-scoped commits).
6. Record a manifest at `specs/{NNN}_{SLUG}/challenge/manifest.json`:
   `{commit, challenge_module, theorem_names, created_at, plan_path}` — this is the file task 155's
   `--compare` step reads to populate `lean-comparator-run.sh --commit/--challenge-module/--theorems`.
   The manifest itself is also refused-to-overwrite under the same status gate as step 2, so even a
   bypassed script re-run cannot retroactively change what an already-recorded SHA points to for a
   caller that keeps using the recorded value.

**Where it is stored, and what stops it being regenerated from post-hoc sources** (the dispatch's
explicit question): the authoritative artifact is the **git commit itself** — content-addressed,
outside this system's control once made, and referenced by SHA from `specs/`'s manifest. The
*specs-side* manifest is a pointer, not the trust boundary; the trust boundary is that
`lean-comparator-run.sh --commit <SHA>` will always retrieve the exact committed bytes regardless
of what anyone does to the working tree or `HEAD` afterward. What stops regeneration is the
status-gate refusal in step 2/6 (process-level: the tool itself declines once the task has moved
past `planned`) plus the git-SHA pinning (mechanism-level: even a successful, illicit second commit
cannot rewrite the meaning of a SHA a manifest already named). Demonstrating this for the
acceptance criteria means: (a) run the snapshot script once at `planned`, succeed; (b) transition
the task to `implementing`; (c) re-run the script and show the refusal message; (d) show that even
force-bypassing (or manually committing a different `Challenge.lean`) leaves the original
manifest's recorded SHA — and therefore anything that already consumed it — unaffected, by
`git show`-ing the original SHA's content against the mutated working tree.

**4. `plan-compliance.md` — should it gain a statement-fidelity notion? Yes.**

Today the rule states "the plan is the contract" for `.lean` files but scopes that contract to
*decomposition* (lemma structure, proof order, which helper lemmas) — its "Forbidden Patterns"
list has nothing that would flag a same-named, weaker restatement. Once
`## Lean Challenge Statements` exists, it is the natural place to hang a fidelity clause: add a
"Statement Fidelity" subsection stating that when a plan carries this section, the named
declarations' **signatures** (not just their names) are part of the contract, and add "Weakening a
recorded Challenge statement (adding a hypothesis, specializing a quantifier, restating a
strictly weaker claim)" to the existing Forbidden Patterns list, cross-referenced to the same
escalate-rather-than-substitute behavior the rule already mandates. This gives the system a cheap,
mechanical (diff/grep against the snapshot text) interim check for exactly the failure mode the
dispatch calls "the system's single largest verification hole" — independently of whether
Comparator is ever wired in, matching the dispatch's own "Independent Value" framing.

## Decisions

- **R1 (plan-declared, additive new section) is the primary Challenge source; R2 (git extraction)
  is a logged, degraded fallback for legacy plans only, never silent.** Reasoning: R2 structurally
  cannot serve a greenfield theorem, which the dispatch itself identifies as the case this task
  must not leave unhandled.
- **The new plan section is `## Lean Challenge Statements`, gated on lean/lean4 task type**, added
  to `plan-format.md` additively rather than amending the shared `**Goals**:` bullet, to leave
  every non-lean plan's format contract untouched.
- **Immutability is achieved by committing the Challenge to the target project's own git history
  and pinning callers to the resulting SHA**, not by filesystem permissions or by any mechanism
  internal to this system alone — this reuses `lean-comparator-run.sh`'s own existing `--commit`
  contract rather than inventing a parallel one.
- **A status-gate refusal (task status must still be `planned`) is the process-level guard against
  regeneration**; the git-SHA pin is the mechanism-level guard that holds even if the process-level
  guard is bypassed.
- **`plan-compliance.md` should gain a Statement Fidelity subsection** once `## Lean Challenge
  Statements` exists, naming statement-weakening as a forbidden pattern alongside the rule's
  existing decomposition-fidelity requirements.
- **Solution-module synthesis is out of this task's scope** — task 155 owns turning the
  implemented `Theories/` declarations into a `Solution.lean` module at a commit that also
  contains this task's `Challenge.lean`; this report only flags the interface (the manifest's
  `commit`/`challenge_module`/`theorem_names` fields) task 155 will need to consume.

## Risks & Mitigations

- **Risk**: a planner (human or agent) writes a `## Lean Challenge Statements` block whose
  identifiers drift from `**Goals**:`'s identifier list, producing a Challenge that doesn't match
  what compliance-checking expects. **Mitigation**: snapshot-time validation that the two
  identifier sets agree, failing loudly on mismatch rather than silently unioning or intersecting
  them (left as an explicit phase-1 decision for the plan, per Recommendation 2).
- **Risk**: the R2 fallback's declaration-boundary extraction is textually fragile (multi-line
  signatures, attributes, `noncomputable`/`private` modifiers) and could silently mis-extract.
  **Mitigation**: treat R2 extraction failures as hard errors (matching this task's general
  fail-loud posture), and since R2 is a fallback rather than the primary path, its extractor need
  only handle the common declaration shapes already reflected in this codebase's own conventions
  (`lean4-style-guide.md`), not every possible Lean declaration syntax.
- **Risk**: no real lean proof-task plan exists in this repository today to validate the new
  section against end-to-end. **Mitigation**: the plan phase should target one of the operator's
  real Lean projects (`~/Projects/BimodalLogic` or `~/Projects/cslib`, both confirmed to have
  tracked `.lean` sources and git history) for the acceptance demonstrations, rather than a
  synthetic fixture-only proof.
- **Risk**: `--force`-bypassing the status gate could become a normalized workaround if it's too
  easy to reach for. **Mitigation**: the loud warning on `--force` past `planned` should be
  specific enough (naming the task, its current status, and the fact that any prior manifest's SHA
  is now stale for callers still holding it) that it reads as an incident, not a convenience flag.

## Context Extension Recommendations

None — this is a meta task whose findings live in the report and feed directly into the plan
phase rather than into `.claude/context/`.

## Appendix

### Files read

- `agent-system/extensions/lean/scripts/lean-comparator-run.sh` (full)
- `agent-system/extensions/lean/context/project/lean4/domain/comparator-integration.md` (full)
- `agent-system/extensions/lean/scripts/tests/test-lean-comparator-run.sh` (header + fixture helpers)
- `agent-system/extensions/lean/scripts/tests/fixtures/comparator/**` (Challenge.lean fixtures, config.json, README.md)
- `agent-system/extensions/core/context/formats/plan-format.md` (structure, Planned Strategic Sorries precedent)
- `agent-system/extensions/lean/rules/plan-compliance.md` (full)
- `agent-system/extensions/lean/agents/lean-implementation-agent.md` (Final Verification Stage, goal-identifier regex)
- `agent-system/extensions/lean/context/project/lean4/standards/proof-debt-policy.md` (partial)
- `agent-system/extensions/lean/manifest.json` (scripts/rules registration shape)
- `specs/state.json` (task 154/155 records), `specs/TODO.md` (task 153/155/156 descriptions)
- `specs/153_lean_comparator_clean_room_runner/plans/01_lean-comparator-clean-room-runner.md` (Goals section shape)

### Queries / searches used

- Codebase grep for `comparator`/`challenge` across `agent-system/extensions/lean`
- Grep across `specs/*/plans/*.md` for `^\*\*Goals\*\*:` to check for an existing real lean-plan
  example (none found — all matches are meta tasks)
- `find` for any live Lean project (`Theories/`, `*.lean`) confirming real target projects exist
  outside this repo (`~/Projects/BimodalLogic`, `~/Projects/cslib`)
