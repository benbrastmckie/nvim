# Research Report: Task #381

**Task**: 381 - Catch stale derived artifacts at implement postflight and never let containment leave HEAD inconsistent
**Started**: 2026-10-14T14:59:00Z
**Completed**: 2026-10-14T15:40:00Z
**Effort**: large (touches two postflight engines, one schema addition, one standards-doc exception)
**Dependencies**: None
**Sources/Inputs**:
- Codebase: `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh`, `command-gate-out.sh`, `skill-base.sh`, `git-commit-scoped.sh`, `orchestrate-batch-admit.sh`
- Codebase: `agent-system/extensions/core/context/standards/postflight-tool-restrictions.md`, `git-staging-scope.md`
- Codebase: `agent-system/extensions/core/docs/guides/creating-extensions.md` (Lifecycle Hooks)
- Codebase: `lua/neotex/plugins/ai/shared/extensions/state.lua` (`.claude-extensions.json` read/write semantics)
- Codebase: `agent-system/extensions/lean/scripts/lean-challenge-snapshot.sh`, `agent-system/extensions/books/context/project/books/{domain,patterns}/*.md`
- Codebase: `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh`
**Artifacts**:
- This report: `specs/381_implement_postflight_derived_artifact_staleness/reports/01_postflight-derived-artifact-staleness.md`
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Central obstacle**: in `orchestrate-cycle-postflight.sh`, the state.json status transition
  to `implemented`/`completed` (WORK (f)) runs and lands **before** this cycle's own git commit
  (WORK (i)). The script's own comments already name this ordering as a known, unresolved gap
  ("monotonic-max prevents a later demotion by construction... The status-demotion half remains
  an open, explicitly named follow-up"). A probe that must run "after the agent's last commit"
  and be able to "fail the phase instead of reporting implemented" cannot simply be appended at
  the end of the script — it must run **before** WORK (f)'s status write, which in turn means it
  must run on the agent's reported `modified_files` / the working tree, not on a commit that does
  not exist yet at that point in execution.
- **Every existing staleness/drift mechanism in this codebase is deliberately advisory-only** —
  the file_scope excursion check (WORK (h)), the extension lifecycle `verification`/`postflight`
  hooks (`skill-base.sh`, `command-gate-out.sh`), and `lean-challenge-snapshot.sh --check`'s own
  drift verdict all explicitly disclaim any gating effect. A blocking probe is a deliberate,
  one-off departure from an established house convention, not an incremental extension of one —
  the plan should treat it as such and state the justification (the evidence's wasted CI cost)
  explicitly rather than silently reusing the `verification` hook name.
- **`.claude-extensions.json` is a safe, durable declaration point**: its Lua read/write path
  (`state.lua`) parses and re-serializes the whole top-level table rather than reconstructing a
  fixed schema, so a hand-authored sibling key next to `extensions`/`version` survives every
  load/unload/redeploy cycle. `project-overview.md` is free-form prose with no machine-parsed
  schema and is the weaker of the two candidates GOAL names.
- GOAL's two sub-problems are complementary, not redundant: (1) catches a component whose
  identity-input changed but whose derived output was **never regenerated at all** (the `distsys`
  half of the evidence incident — nothing was reported modified, so the existing excursion
  mechanism had nothing to drop); (2) stops an already-regenerated derived file from being
  silently dropped while its cause is committed (the `framed_channel` half). Neither alone
  reproduces the evidence incident's full shape.
- The closest existing in-repo precedent for "a file this commit legitimately carries because the
  commit caused it, not because it is in this task's own narrow scope" is `--honest-index-rows`
  (`git-commit-scoped.sh` / `git-staging-scope.md`) — an attribution-honesty mechanism, not a
  scope-widening one, and a good model for how to word GOAL (2)'s fix.

## Context & Scope

Researched the generic agent-system mechanism (source store: `agent-system/extensions/core/**`)
that would let a *consumer* repository declare build-free staleness-check commands per
component, have the implement phase run them, and stop a regenerated derived artifact from being
silently dropped by the existing file_scope containment while the change that caused it is
committed. The evidence is a specific external incident (a Lean book/certificate repo); nothing
in that repo is part of this source tree, so the scope here is the generic hook/declaration/gate
mechanism alone — never any hard-coded component list, script name, or repo path.

Two postflight loci exist in this codebase and both would need the mechanism named explicitly,
since GOAL requires it to work for every task type without agent-system hard-coding anything:

- **Multi-task engine**: `orchestrate-cycle-postflight.sh`, called once per dispatch from
  `skill-orchestrate`'s Move 3. This is the locus exercised by the evidence incident and by this
  task's own `task_type: meta` routing (core task types bypass `skill-base.sh` entirely — see
  `.claude/CLAUDE.md`'s Task-Type-Based Routing table — and dispatch directly via
  `command-route-agent.sh`).
- **Single-task engine**: `command-gate-out.sh` (CHECKPOINT 2), used by `/research`, `/plan`,
  `/implement` run directly (not under `/orchestrate`), which already calls the `verification`
  extension-hook stage.

Not researched: anything inside the external consumer repo itself (its `check.sh`,
`certificate-identity.sh`, or `digests.txt` scripts/files) — those are examples only, outside
this repository.

## Findings

### 1. The status write precedes the commit in both postflight engines — the core design obstacle

In `orchestrate-cycle-postflight.sh` the execution order is: WORK (f) status transition
(`skill_postflight_update`, which calls `update-task-status.sh`/`state-write.sh`) → WORK (h)
file_scope excursion advisory (detection only) → verdict resolution → WORK (k)/WORK (m) → **WORK
(i) per-task scoped commit** (`git-commit-scoped.sh`). For an `implemented` dispatch_status, the
gate that decides whether the status write may proceed (`skill_gate_completion_claim`, producing
`implemented_gate_passed`) is a pure **phase-accounting** check (phases_completed vs
phases_total, plan markers) — it has no visibility into file content, derived artifacts, or
anything a build-free staleness probe would check, and it runs and resolves well before any
commit exists for this cycle.

The script's own comment block (around the `commit_rc` 2–6 handling, right after WORK (i)) names
this gap explicitly, for a structurally identical problem (the commit itself failing after the
status already says "completed"):

> "`verdict` is resolved, and WORK (f)'s status write already landed, both hundreds of lines
> BEFORE this call site — monotonic-max prevents a later demotion by construction... The
> status-demotion half remains an open, explicitly named follow-up rather than a silently dropped
> one."

`command-gate-out.sh` (the single-task engine) has the same shape: `update-task-status.sh`
(the status transition) runs first, and only afterward does it call
`skill_run_extension_hook "verification" ...`, whose own comment states "Disposition:
non-blocking, exactly like every other lifecycle hook stage — gate-out proceeds regardless of
the hook's outcome."

**Implication for the plan phase**: a true "non-zero fails the phase instead of reporting
implemented" gate cannot be bolted on after the existing commit/hook call sites. It has to run
**earlier** — most plausibly alongside (or folded into) the existing phase-accounting gate
(`skill_gate_completion_claim` / `implemented_gate_passed`), evaluated against the agent's
reported `modified_files` and the (as-yet-uncommitted) working tree, before WORK (f)'s status
write. This also resolves the "after the agent's last commit" wording in the task description
literally: in this architecture, nothing the *agent* does is "the last commit" — the per-cycle
postflight (WORK (i)) is what actually creates the commit. The probe's natural trigger point is
therefore "after the agent's edits are known (modified_files reported), before postflight's own
commit and status write," not literally post-commit.

### 2. The existing file_scope excursion mechanism (WORK (h)/WORK (i)) is exactly what produced the incident, working as designed

`orchestrate-cycle-postflight.sh` WORK (h) computes `excursions_json`: any `modified_files` entry
outside the task's declared `file_scope` (plus an implicit own-task-directory member). WORK (i)
then drops each excursion from the staged commit with a loud `EXCURSION DROPPED` warning —
"drop-and-warn, never refuse" is the documented ruling, justified by a stated fail-open
precedent for scope/concurrency guards. This is precisely the mechanism that dropped the four
regenerated `framed_channel` certificate files in the evidence incident: it is advisory-only by
design (`WORK (h)` is explicitly "(detection only — no gate, no exit-code, no verdict effect)"),
so nothing in it was a defect — the incident is a gap in the *design*, not a bug in this code.

GOAL (2) ("regenerated files under a touched component's declared derived-output directory are
either treated as in-scope derived output ... or the phase fails loudly") requires adding a
**second exemption class** ahead of the excursion check: a `modified_files` entry falling under a
declared derived-output directory is never an excursion, regardless of the task's own
`file_scope`. This does not require tracing which component's *source* change caused the
regeneration — it only requires the regenerated file's own path to fall under a pre-declared
directory prefix. That keeps the fix symmetrical with the existing `effective_file_scope_json`
splice (which already widens the comparison set once, for the implicit task-directory member) —
a second splice, widening it again for declared derived-output prefixes, is the minimal change.

### 3. The two GOAL sub-problems are complementary, not redundant

The evidence names two distinct failures that a fix must cover, and they are not interchangeable:

- **`framed_channel` half** (GOAL 2): the certificate *was* regenerated (the gate ran), the
  regenerated files *were* reported in `modified_files`, and they were dropped as excursions
  while `check.sh` (the cause) was committed. A derived-output exemption (Finding 2) fixes this
  half.
- **`distsys` half** (GOAL 1): its gate never ran at all, so nothing was regenerated and nothing
  was reported modified — there is no excursion to exempt, because there is no file to look at.
  Only an independent, declared staleness **probe** (`certificate-identity.sh --check` or
  equivalent) run against the post-change tree can catch this half, since it is a positive check
  ("is the derived output still valid for the current input"), not a containment/attribution
  question.

A plan that implements only one of the two will not close the incident shape the ACCEPTANCE
criterion describes ("an identity input of two components changed, only one gate run, regenerated
certificate outside file_scope" — this sentence names both halves at once).

### 4. `.claude-extensions.json` safely accepts a new top-level, hand-authored key

`lua/neotex/plugins/ai/shared/extensions/state.lua`'s `M.read` parses the whole JSON file into a
Lua table and only *ensures* `state.extensions` exists — it never strips or validates unknown
top-level keys. Every call site in `init.lua`/`merge.lua` follows the same
`local state = state_mod.read(...)` → mutate → `state_mod.write(project_dir, state, config)`
pattern; `M.write` serializes whatever table it is given. Verified (`jq 'keys' .claude-extensions.json`
in this repo) that the file today carries exactly `extensions` and `version` at the top level.
Consequently, a new top-level key — e.g. `derived_artifact_probes` — added by hand (or by a
future `/meta`-driven tool) would survive every extension load/unload/redeploy cycle unmodified,
because nothing in the write path ever reconstructs the file from a closed schema.

`project-overview.md` (`agent-system/extensions/core/context/repo/project-overview.md`), by
contrast, is hand-authored prose generated once by `/project-overview` and consulted by agents as
context, not parsed by any script found in this search for structured fields. It is a weaker
candidate for a value multiple scripts (the new probe runner, the new excursion-exemption
splice) must parse reliably.

A sibling possibility — a new field on the *task's own* `state.json` entry (next to
`file_scope`) — was considered and rejected as the primary declaration point: `file_scope` and
any analogous per-task field describe *that task's own anticipated scope*, not a standing,
repo-wide fact about which components exist and what checks they publish. The declared probes
and derived-output directories are a property of the **repository**, independent of which task
happens to be dispatched against it, which is exactly the scope `.claude-extensions.json`
already occupies (`source_dir` resolution, extension `status`, etc.).

### 5. Extension lifecycle hooks (`manifest.json`'s top-level `hooks`) are the wrong vehicle, on two counts

`agent-system/extensions/core/docs/guides/creating-extensions.md`'s Lifecycle Hooks section
documents a `preflight`/`context_injection`/`verification`/`postflight` hook schema, invoked by
`skill_run_extension_hook` in `skill-base.sh` (lines 478, 541, 719, 1104) and once more from
`command-gate-out.sh` (line 314, `verification` stage). Two mismatches with GOAL:

1. **Scope**: these hooks are declared per-*extension* (`nix/manifest.json`,
   `lean/manifest.json`), not per-*consumer-repo*. GOAL explicitly wants the repo itself —
   independent of which extensions it has loaded — to declare components and probes.
2. **Disposition**: every call site is unconditionally non-blocking by documented contract
   ("Exit non-zero: warning logged (non-blocking, skill continues)" — `skill-base.sh:145`;
   reaffirmed in the creating-extensions guide and at `command-gate-out.sh`'s own call site
   comment). Finding 1 already showed hooks of any kind run after the status write in both
   engines; even moved earlier, the hook mechanism itself has no opt-in blocking mode today.

Core task types (`general`, `meta`, `markdown` — this task's own type) never reach `skill-base.sh`
at all (direct `command-route-agent.sh` dispatch per `.claude/CLAUDE.md`'s routing table), so a
fix anchored only in `skill-base.sh`/hooks would silently exclude the exact task type this
incident's consumer repo most likely uses and the exact engine (`orchestrate-cycle-postflight.sh`)
the evidence names.

### 6. `postflight-tool-restrictions.md` currently prohibits exactly this class of command

The standard's Prohibited Operations table bans `lake build`, `nvim --headless`, `pytest`,
`nix build`, etc. under "Verification is agent work," with the stated rationale that postflight
exists solely for state management, artifact linking, commits, and cleanup. A build-free
staleness check (`certificate-identity.sh --check`, by construction, never rebuilds anything) is
categorically different from the listed commands, but nothing in the current document
distinguishes "build-free check" from "build/test" — a literal reading would forbid the very
probe GOAL (1) asks for. The document already has exactly one sanctioned, narrowly-scoped
exception mechanism for a comparable tension (the D4 message-findings-recovery exception, scoped
to one skill and one script). GOAL (1)'s probe needs an equally explicit, narrowly-scoped sibling
exception — named as build-free, repo-declared, and gating only the declared check command itself
— rather than a silent reading of "build-free" into the existing "Verification is agent work"
language.

### 7. Repo-wide convention: every existing drift/staleness check is advisory-only by deliberate design

Three independent subsystems converge on the same rule, making the convention load-bearing
rather than coincidental:

- WORK (h)'s file_scope excursion check: "(detection only — no gate, no exit-code, no verdict
  effect)".
- The extension lifecycle `verification`/`postflight` hooks: unconditionally non-blocking
  (Finding 5).
- `lean-challenge-snapshot.sh --check`'s own header: "this script's `--check` verdict is ADVISORY
  ONLY... A drift finding (exit 65) MUST NOT be interpreted by any caller as grounds to set
  verification_passed false, downgrade a task's status, or block completion — that promotion is a
  separate, later, not-yet-made decision. This script is... not wired into any completion gate by
  this script or by anything else in this source tree."

GOAL (1) deliberately proposes the first **blocking** staleness gate in this codebase. That is a
legitimate response to the evidence (a wasted, billed CI run), but the plan should name it as a
conscious, justified departure from an established convention — not as "just another hook" or
"the same kind of check as the others, now wired up." Reviewers and future maintainers reading
`lean-challenge-snapshot.sh`'s header or `postflight-tool-restrictions.md` will otherwise read the
new gate as contradicting documented, deliberate prior decisions.

### 8. The closest existing attribution precedent for GOAL (2): `--honest-index-rows`

`git-staging-scope.md` documents `--honest-index-rows` (required at every site staging
`specs/state.json`/`specs/TODO.md`) as the mechanism that honestly labels a commit which
legitimately carries *other tasks'* current index rows, rather than attributing that content
falsely or stripping it. It is an attribution-honesty flag, not a scope-widening one — the content
was always going to be staged; the flag only makes the resulting commit message honest about it.
GOAL (2)'s fix is structurally closer to a scope-widening exemption (content that would otherwise
be *dropped* must instead be *staged*), but the naming convention and the "make this explicit and
auditable rather than silent" spirit of `--honest-index-rows` is a good model for whatever flag or
field marks a derived-output commit as intentionally including component-regenerated content.

### 9. The evidence's domain (per-component certificates/`check.sh`) already has a real analog in this codebase's `books` extension — but it lives in the *consumer* repo, confirming the "never hard-code" requirement

`agent-system/extensions/books/context/project/books/domain/identity-and-versioning.md` and
`patterns/gate-collision-ledger.md` document a structurally similar per-book certificate/identity
scheme (`book.cert.json`, `BookCert` Lean modules, `full-gate.sh`, `check.sh`) for a Lean
book-building consumer repo. Critically, `gate-collision-ledger.md`'s "Collision 4" and related
rows confirm that this check.sh/gate tooling is the **consumer repo's own build infrastructure**,
invoked by implementation agents during ordinary verification — it is not, and should not become,
part of agent-system's generic core. This corroborates GOAL's own "Generic: the agent system
never hard-codes any repo's component list" requirement from an independent angle: even the one
extension in this source tree whose domain looks most like the evidence incident keeps its
gate/certificate scripts entirely on the consumer-repo side.

### 10. Test convention for the acceptance fixture

`test-orchestrate-cycle-postflight.sh` (3284 lines) already covers "the five acceptance
conditions... named by this task's own dispatch ACCEPTANCE line" for a prior convergence, using a
sandbox pattern: real collaborator scripts (`skill-base.sh`, `state-write.sh`,
`git-commit-scoped.sh`, etc.) are copied unmodified into a synthetic `$WORKDIR/.claude/scripts/`
tree so the real call graph runs against synthetic fixtures ("candidate #N", never "task N", per
`rules/no-task-references-in-deliverables.md`). The new acceptance fixture (two-component
identity-input change, one gate run, one dropped-vs-exempted certificate; the no-probe-declared
regression case) fits this same file and sandbox convention rather than a new standalone test
harness.

## Decisions

- Treat GOAL (1) and GOAL (2) as two separate, complementary fixes (Finding 3), both required to
  reproduce/close the evidence incident's full shape — not alternative implementations of one
  fix.
- Recommend `.claude-extensions.json` (a new top-level key, e.g. `derived_artifact_probes`) as the
  declaration point over `project-overview.md` or a per-task `state.json` field, on the basis of
  Finding 4 (survives the read-modify-write cycle unmodified) and the repo-scoped-not-task-scoped
  nature of the fact being declared.
  - Not decided by this research (left for planning): the exact per-entry schema linking a
    component's declared derived-output directories to the source paths that "touch" it for
    GOAL (1)'s probe-selection purpose (versus GOAL (2)'s exemption, which this research found
    does not need that linkage at all — see Finding 2).
- Recommend the gate implied by GOAL (1) be evaluated and resolved **before** `orchestrate-cycle-postflight.sh`'s WORK (f) status write (and, for the single-task engine, before `command-gate-out.sh`'s `update-task-status.sh` call) — not appended after the existing commit or hook call sites — per Finding 1. Both engines need an explicit, named change; neither should be assumed to inherit the other's fix for free.
- Recommend extension lifecycle hooks (`manifest.json`'s top-level `hooks`) be ruled out as the
  implementation vehicle (Finding 5): wrong scope (per-extension, not per-repo) and wrong
  disposition (unconditionally non-blocking today).
- Recommend `postflight-tool-restrictions.md` gain one new, narrowly-scoped Exceptions entry
  (modeled on the existing D4 entry) naming the declared build-free probe command class
  explicitly, rather than relying on an implicit "build-free" reading of the current prohibition
  (Finding 6).
- Recommend the plan explicitly name GOAL (1)'s blocking gate as a deliberate, justified departure
  from this codebase's otherwise-universal "staleness checks are advisory-only" convention
  (Finding 7), rather than presenting it as a routine extension of the pattern.

## Recommendations

1. **Schema**: add one new top-level key to `.claude-extensions.json`, e.g.:
   ```json
   "derived_artifact_probes": [
     {
       "component": "framed_channel",
       "check_command": "components/framed_channel/certificate-identity.sh --check",
       "derived_output_dirs": ["components/framed_channel/cert/"]
     }
   ]
   ```
   An absent or empty key must leave every existing code path byte-for-byte unchanged (mirrors
   the existing `file_scope` length-guard fail-open posture in WORK (h)) — "a repo that declares
   nothing behaves as today" is a hard regression-test requirement, not just a design goal.

2. **GOAL (2) (derived-output exemption)**: in `orchestrate-cycle-postflight.sh`, splice each
   declared `derived_output_dirs` prefix into the excursion comparison set the same way the
   implicit own-task-directory member is already spliced into `effective_file_scope_json` (WORK
   (h), the `effective_file_scope_json` construction) — this requires no new cross-referencing
   between a component's source inputs and its outputs; it is a pure path-prefix exemption,
   independent of `file_scope`'s own length-guard. If, instead, a component's derived output is
   found stale by GOAL (1)'s probe and was never regenerated, that is GOAL (1)'s job, not this
   exemption's.

3. **GOAL (1) (blocking probe)**: run the declared `check_command`s for the implement phase after
   the agent's edits are known (same point `modified_files_json`/`file_scope_json` are already
   read in WORK (h)) and **before** WORK (f)'s status write. A non-zero result from any declared
   probe should produce the same `defer`-shaped outcome `deploy_pending_refusal` already produces
   for a structurally similar "the write didn't really land as claimed" case — reusing that
   established vocabulary rather than inventing a fourth meaning for an existing verdict term.
   Apply the same change to `command-gate-out.sh`'s single-task path, ahead of its
   `update-task-status.sh` call, rather than assuming parity with the multi-task engine.

4. **Standards update**: add one new bullet to `postflight-tool-restrictions.md`'s Exceptions
   section (sibling to the existing D4 entry) naming the declared, build-free probe command
   explicitly as the sole sanctioned exception to the "Verification is agent work" prohibition,
   scoped to exactly the command string the repo declared — never an open-ended "any build-free
   command."

5. **Docs**: name `.claude-extensions.json` as the declaration point in
   `agent-system/extensions/core/docs/guides/creating-extensions.md` or a new sibling doc, per the
   ACCEPTANCE criterion's "docs name the declaration point" requirement.

6. **Tests**: extend `test-orchestrate-cycle-postflight.sh`'s existing sandbox-copy fixture suite
   (Finding 10) with the evidence-shaped fixture (two declared components, one modified_files
   entry under each component's declared derived-output dir vs. one component's check_command
   left failing with nothing regenerated) plus the no-probe-declared regression fixture, rather
   than a new standalone harness.

## Risks & Mitigations

- **Risk**: moving a gate earlier (before WORK (f)) in a 2128-line script with heavy
  ordering-dependency commentary (`set -u`, no `:-` defaults on several variables) risks breaking
  an existing invariant the file's own comments describe as load-bearing.
  **Mitigation**: the plan should isolate the new gate's variable(s) exactly the way
  `deploy_pending_refusal` is already isolated — a single boolean, computed once, read only in the
  verdict `case` block — rather than threading new state through multiple WORK sections.
- **Risk**: declaring the probe command as a raw shell string invites injection or
  environment-dependent behavior when run by postflight (a context with broader trust than an
  agent's own sandboxed Bash calls).
  **Mitigation**: scope this concern explicitly to the planning phase; at minimum, the probe
  should run with the same working directory and privilege as the implementation agent itself,
  never with any elevated postflight-only capability.
- **Risk**: a repo declares a `check_command` that is itself slow or flaky, turning an advisory
  wait into a blocking one on every implement-phase postflight.
  **Mitigation**: GOAL already frames these as "build-free" by definition; the plan should state
  a bounded-wait expectation (see `context/patterns/external-process-wait.md`'s general
  discipline) and treat a probe that does not return promptly as a defect in the repo's own
  declaration, not something postflight should wait on indefinitely.
- **Risk**: fixing only the multi-task engine (`orchestrate-cycle-postflight.sh`, the locus the
  evidence names) leaves the single-task engine (`command-gate-out.sh`) silently uncovered,
  reproducing the exact "generic across the whole system" gap GOAL explicitly calls out.
  **Mitigation**: Recommendation 3 above already names both call sites; the plan's acceptance
  criteria should require a fixture (or explicit scope note) for each engine, not just the one the
  evidence happened to hit.

## Context Extension Recommendations

- **Topic**: repo-level (not per-task, not per-extension) declaration mechanism in
  `.claude-extensions.json`.
  **Gap**: no existing context file documents that `.claude-extensions.json`'s top-level schema
  is open to hand-authored sibling keys beyond `extensions`/`version`, or that the Lua
  read/write path preserves them.
  **Recommendation**: once this task's plan settles the exact schema, add a short subsection to
  `agent-system/extensions/core/docs/guides/creating-extensions.md` (or a new
  `context/standards/repo-level-declarations.md`) documenting the pattern generically, so a
  future repo-level declaration need (not just this one) has a named precedent to follow instead
  of re-deriving the read/write-safety argument from `state.lua` again.

## Appendix

Search queries / probes used (codebase only; no web search was needed for this task):
- `grep -n -i "excursion|file_scope|containment|dropped"` over `orchestrate-cycle-postflight.sh`
- `grep -n -A80 "## Lifecycle Hooks"` over `creating-extensions.md`
- `grep -rn "\"hooks\""` over every `agent-system/extensions/*/manifest.json`
- `grep -n "skill_run_extension_hook"` over `skill-base.sh`, `command-gate-out.sh`
- `jq 'keys' .claude-extensions.json`; read of `lua/neotex/plugins/ai/shared/extensions/state.lua`
- `grep -rln "digests.txt|certificate-identity"` over `agent-system/` (books extension only)
- Read of `postflight-tool-restrictions.md`, `git-staging-scope.md` (`--honest-index-rows`),
  `lean-challenge-snapshot.sh` header, `gate-collision-ledger.md`
- Read of `test-orchestrate-cycle-postflight.sh` header for the existing fixture convention
